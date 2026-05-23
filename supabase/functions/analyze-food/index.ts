// Supabase Edge Function — analyze-food
// Accepts a storage path to a user-uploaded food image, calls Anthropic Claude,
// returns a strictly-validated JSON breakdown.
//
// Deploy: supabase functions deploy analyze-food
// Required secrets: ANTHROPIC_API_KEY (supabase secrets set ANTHROPIC_API_KEY=...)

import { serve } from 'https://deno.land/std@0.208.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0';
import { z } from 'https://esm.sh/zod@3.23.8';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

// Schema returned by the model (and accepted by the iOS client).
// Per-item caps clamp obvious model hallucinations.
const FoodItemSchema = z.object({
  name: z.string().min(1).max(80),
  grams: z.number().positive().max(2000),
  kcal: z.number().int().nonnegative().max(5000),
  protein_g: z.number().nonnegative().max(500),
  carbs_g: z.number().nonnegative().max(500),
  fat_g: z.number().nonnegative().max(500),
  confidence: z.number().min(0).max(1).optional(),
  // Optional micronutrients. Units below match the iOS client (`Micronutrients`).
  //  μg = micrograms, mg = milligrams.
  vitamin_d_mcg:   z.number().nonnegative().max(200).optional(),
  vitamin_b12_mcg: z.number().nonnegative().max(200).optional(),
  vitamin_c_mg:    z.number().nonnegative().max(2000).optional(),
  magnesium_mg:    z.number().nonnegative().max(2000).optional(),
  iron_mg:         z.number().nonnegative().max(100).optional(),
  zinc_mg:         z.number().nonnegative().max(100).optional(),
});

const ResponseSchema = z.object({
  items: z.array(FoodItemSchema).min(1).max(20),
});

const RequestSchema = z.object({
  image_path: z.string().min(1),
});

const SYSTEM_PROMPT = `You are a nutrition vision assistant. Given a single photo of food, identify each distinct item.
Estimate portion size in grams as accurately as possible from visual cues (plate size, utensils, hands).
For each item, return calories, protein, carbs, and fat in grams, plus realistic micronutrient
estimates (vitamin D μg, vitamin B12 μg, vitamin C mg, magnesium mg, iron mg, zinc mg) — use 0
when a nutrient is essentially absent. Be conservative — under-estimate before over-estimating.
Confidence reflects how sure you are (0..1).
Call the record_meal tool exactly once with all detected items.`;

// Structured-output tool. Claude is forced to call this (via tool_choice), so the
// response is guaranteed to match the schema — no JSON-mode workarounds needed.
const RECORD_MEAL_TOOL = {
  name: 'record_meal',
  description: 'Record the food items detected in the photo with macro and micronutrient estimates.',
  input_schema: {
    type: 'object',
    properties: {
      items: {
        type: 'array',
        minItems: 1,
        maxItems: 20,
        items: {
          type: 'object',
          properties: {
            name: { type: 'string', maxLength: 80 },
            grams: { type: 'number', minimum: 0, maximum: 2000 },
            kcal: { type: 'integer', minimum: 0, maximum: 5000 },
            protein_g: { type: 'number', minimum: 0, maximum: 500 },
            carbs_g: { type: 'number', minimum: 0, maximum: 500 },
            fat_g: { type: 'number', minimum: 0, maximum: 500 },
            confidence: { type: 'number', minimum: 0, maximum: 1 },
            vitamin_d_mcg:   { type: 'number', minimum: 0, maximum: 200 },
            vitamin_b12_mcg: { type: 'number', minimum: 0, maximum: 200 },
            vitamin_c_mg:    { type: 'number', minimum: 0, maximum: 2000 },
            magnesium_mg:    { type: 'number', minimum: 0, maximum: 2000 },
            iron_mg:         { type: 'number', minimum: 0, maximum: 100 },
            zinc_mg:         { type: 'number', minimum: 0, maximum: 100 },
          },
          required: ['name', 'grams', 'kcal', 'protein_g', 'carbs_g', 'fat_g'],
        },
      },
    },
    required: ['items'],
  },
  // Cache the tool definition — it never changes across requests, so this
  // gives ~90% input-cost savings on the system+tool prefix once it's warm.
  cache_control: { type: 'ephemeral' },
};

async function analyze(imageURL: string): Promise<unknown> {
  const apiKey = Deno.env.get('ANTHROPIC_API_KEY');
  if (!apiKey) {
    throw new Error('ANTHROPIC_API_KEY not configured');
  }

  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      model: 'claude-sonnet-4-6',
      max_tokens: 1024,
      system: [
        // System prompt is cached alongside the tool definition for the prefix-cache hit.
        { type: 'text', text: SYSTEM_PROMPT, cache_control: { type: 'ephemeral' } },
      ],
      tools: [RECORD_MEAL_TOOL],
      // Force the model to call record_meal — guarantees a structured response.
      tool_choice: { type: 'tool', name: 'record_meal' },
      messages: [
        {
          role: 'user',
          content: [
            { type: 'image', source: { type: 'url', url: imageURL } },
            { type: 'text', text: 'Identify and estimate macros for this meal.' },
          ],
        },
      ],
    }),
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Anthropic ${res.status}: ${errText}`);
  }

  const json = await res.json();
  const toolBlock = json.content?.find((c: { type?: string }) => c?.type === 'tool_use');
  if (!toolBlock || typeof toolBlock.input !== 'object' || toolBlock.input === null) {
    throw new Error('Anthropic response missing tool_use block');
  }
  return toolBlock.input;
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Auth — Supabase functions auto-verify JWT when --no-verify-jwt is NOT set.
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'unauthenticated' }), {
        status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
      { global: { headers: { Authorization: authHeader } } }
    );
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'unauthenticated' }), {
        status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Validate request body
    const body = await req.json().catch(() => ({}));
    const parsed = RequestSchema.safeParse(body);
    if (!parsed.success) {
      return new Response(
        JSON.stringify({ error: 'invalid_request', issues: parsed.error.issues }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Enforce path ownership: image must live under "<uid>/..."
    const path = parsed.data.image_path;
    const expectedPrefix = `${user.id}/`;
    if (!path.startsWith(expectedPrefix)) {
      return new Response(JSON.stringify({ error: 'forbidden_path' }), {
        status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // ---------------------------------------------------------------
    // Quota gate: atomic check-and-record in the DB. This runs BEFORE
    // we sign the URL or call Anthropic, so a free user who's exhausted
    // their daily allowance can't burn paid AI calls by tapping
    // "Retake" — the count is incremented the moment we authorise.
    // ---------------------------------------------------------------
    const FREE_DAILY_SCAN_LIMIT = 3;
    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    const { data: attemptId, error: quotaError } = await adminClient.rpc(
      'check_and_record_scan',
      { p_user_id: user.id, p_daily_limit: FREE_DAILY_SCAN_LIMIT }
    );

    if (quotaError) {
      // Postgres SQLSTATE P0001 with message 'quota_exceeded' = user over free daily limit.
      const msg = quotaError.message ?? '';
      if (msg.includes('quota_exceeded')) {
        return new Response(
          JSON.stringify({
            error: 'quota_exceeded',
            detail: 'Daily free scan limit reached. Upgrade for unlimited scans.',
            daily_limit: FREE_DAILY_SCAN_LIMIT,
          }),
          { status: 402, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
      return new Response(
        JSON.stringify({ error: 'quota_check_failed', detail: msg }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Helper: finalise the attempt status so the row doesn't sit in 'pending' forever.
    const finalise = async (status: 'success' | 'failed') => {
      await adminClient.rpc('mark_scan_outcome', {
        p_attempt_id: attemptId,
        p_status: status,
      });
    };

    // Signed URL for the image — short TTL.
    const { data: signed, error: signError } = await supabase.storage
      .from('food-scans')
      .createSignedUrl(path, 60);
    if (signError || !signed?.signedUrl) {
      await finalise('failed');
      return new Response(JSON.stringify({ error: 'image_not_found' }), {
        status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Call Claude, retry once on schema-validation failure (model occasionally returns out-of-range values).
    let validated: z.infer<typeof ResponseSchema> | null = null;
    let lastError: unknown = null;
    for (let attempt = 0; attempt < 2 && !validated; attempt++) {
      try {
        const raw = await analyze(signed.signedUrl);
        const result = ResponseSchema.safeParse(raw);
        if (result.success) {
          validated = result.data;
        } else {
          lastError = result.error.issues;
        }
      } catch (err) {
        lastError = err instanceof Error ? err.message : String(err);
      }
    }

    if (!validated) {
      // Anthropic failed — refund the attempt so the user isn't charged for our outage.
      await finalise('failed');
      return new Response(
        JSON.stringify({ error: 'analysis_failed', detail: lastError }),
        { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    await finalise('success');
    return new Response(JSON.stringify(validated), {
      status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'unknown';
    return new Response(JSON.stringify({ error: 'server_error', detail: message }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
