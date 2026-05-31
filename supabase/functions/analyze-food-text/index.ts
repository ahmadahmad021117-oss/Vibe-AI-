// Supabase Edge Function — analyze-food-text
// Accepts a free-text meal description (e.g. "4 eggs and a toast"), calls
// Anthropic Claude, and returns a strictly-validated JSON breakdown — one
// entry per distinct food. Mirrors analyze-food, but text-in instead of image-in.
//
// Deploy: supabase functions deploy analyze-food-text
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
  description: z.string().trim().min(1).max(500),
});

const SYSTEM_PROMPT = `You are a nutrition assistant. Given a short free-text description of a meal
(for example "4 eggs and a toast"), identify each distinct food item the user mentioned.
Honour any quantities or portion words in the text ("4 eggs", "a large bowl", "two slices") and
estimate a realistic portion size in grams for each item. For each item, return calories, protein,
carbs, and fat in grams, plus realistic micronutrient estimates (vitamin D μg, vitamin B12 μg,
vitamin C mg, magnesium mg, iron mg, zinc mg) — use 0 when a nutrient is essentially absent.
Be conservative — under-estimate before over-estimating. Confidence reflects how sure you are (0..1).
If the text is too vague to identify any food, still return your single best guess.
Call the record_meal tool exactly once with all items.`;

// Structured-output tool. Claude is forced to call this (via tool_choice), so the
// response is guaranteed to match the schema — no JSON-mode workarounds needed.
const RECORD_MEAL_TOOL = {
  name: 'record_meal',
  description: 'Record the food items described with macro and micronutrient estimates.',
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

// Ask RevenueCat directly whether this user has an active premium entitlement.
// Used as a fallback when the `entitlements` table says they don't — which
// happens during the window between a successful purchase and the RC → Supabase
// webhook landing (or forever, if the webhook isn't configured for this env).
// Returns the entitlement's expiration date, `null` for lifetime, or `undefined`
// if no active premium entitlement was found.
async function fetchRevenueCatPremium(userId: string): Promise<{ expiresAt: string | null } | undefined> {
  const apiKey = Deno.env.get('REVENUECAT_REST_API_KEY');
  if (!apiKey) return undefined;
  const entitlementId = Deno.env.get('REVENUECAT_PREMIUM_ID') ?? 'premium';

  try {
    const res = await fetch(`https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(userId)}`, {
      headers: { Authorization: `Bearer ${apiKey}` },
    });
    if (!res.ok) return undefined;
    const body = await res.json();
    const ent = body?.subscriber?.entitlements?.[entitlementId];
    if (!ent) return undefined;
    const expiresAt: string | null = ent.expires_date ?? null;
    if (expiresAt && Date.parse(expiresAt) <= Date.now()) return undefined;
    return { expiresAt };
  } catch {
    return undefined;
  }
}

async function analyze(description: string): Promise<unknown> {
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
            { type: 'text', text: `Estimate macros for this meal: ${description}` },
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
    const description = parsed.data.description;

    // ---------------------------------------------------------------
    // Premium gate. AI estimation is a paid feature — there's no free
    // allowance. The 3-day intro-offer free trial counts as active premium
    // (RevenueCat marks the entitlement active for the trial window).
    //
    // We reuse `check_and_record_scan` with `p_daily_limit: 0` so the
    // attempt row is recorded atomically before we call Anthropic — that
    // gives us per-estimate audit history and prevents a retry loop from
    // burning paid AI calls.
    // ---------------------------------------------------------------
    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    const premiumRequiredResponse = () => new Response(
      JSON.stringify({
        error: 'premium_required',
        detail: 'AI estimation requires an active Premium subscription. Start your free trial to continue.',
      }),
      { status: 402, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

    let { data: attemptId, error: quotaError } = await adminClient.rpc(
      'check_and_record_scan',
      { p_user_id: user.id, p_daily_limit: 0 }
    );

    if (quotaError) {
      const msg = quotaError.message ?? '';
      // The RPC still raises 'quota_exceeded' when the free quota is 0 and
      // the user has no premium row — that's now equivalent to "no premium".
      if (msg.includes('quota_exceeded')) {
        // Fallback: ask RevenueCat directly. The `entitlements` table is
        // populated by the RC → Supabase webhook, which can lag behind a
        // successful purchase (or be unconfigured in dev). If RC confirms
        // premium, self-heal the table and let the estimate through.
        const rcPremium = await fetchRevenueCatPremium(user.id);
        if (rcPremium) {
          await adminClient.from('entitlements').upsert({
            user_id: user.id,
            tier: 'premium',
            expires_at: rcPremium.expiresAt,
            updated_at: new Date().toISOString(),
          });
          const retry = await adminClient.rpc(
            'check_and_record_scan',
            { p_user_id: user.id, p_daily_limit: 0 }
          );
          if (!retry.error) {
            attemptId = retry.data;
          } else {
            return premiumRequiredResponse();
          }
        } else {
          return premiumRequiredResponse();
        }
      } else {
        return new Response(
          JSON.stringify({ error: 'quota_check_failed', detail: msg }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
    }

    // Helper: finalise the attempt status so the row doesn't sit in 'pending' forever.
    const finalise = async (status: 'success' | 'failed') => {
      await adminClient.rpc('mark_scan_outcome', {
        p_attempt_id: attemptId,
        p_status: status,
      });
    };

    // Call Claude, retry once on schema-validation failure (model occasionally returns out-of-range values).
    let validated: z.infer<typeof ResponseSchema> | null = null;
    let lastError: unknown = null;
    for (let attempt = 0; attempt < 2 && !validated; attempt++) {
      try {
        const raw = await analyze(description);
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
