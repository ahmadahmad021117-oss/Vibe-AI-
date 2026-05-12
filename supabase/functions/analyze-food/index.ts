// Supabase Edge Function — analyze-food
// Accepts a storage path to a user-uploaded food image, calls OpenAI Vision,
// returns a strictly-validated JSON breakdown.
//
// Deploy: supabase functions deploy analyze-food
// Required secrets: OPENAI_API_KEY (supabase secrets set OPENAI_API_KEY=...)

import { serve } from 'https://deno.land/std@0.208.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0';
import { z } from 'https://esm.sh/zod@3.23.8';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

// Schema returned by the model (and accepted by the iOS client)
const FoodItemSchema = z.object({
  name: z.string().min(1).max(80),
  grams: z.number().positive().max(2000),
  kcal: z.number().int().nonnegative().max(5000),
  protein_g: z.number().nonnegative().max(500),
  carbs_g: z.number().nonnegative().max(500),
  fat_g: z.number().nonnegative().max(500),
  confidence: z.number().min(0).max(1).optional(),
});

const ResponseSchema = z.object({
  items: z.array(FoodItemSchema).min(1).max(20),
});

const RequestSchema = z.object({
  image_path: z.string().min(1),
});

const SYSTEM_PROMPT = `You are a nutrition vision assistant. Given a single photo of food, identify each distinct item.
Estimate portion size in grams as accurately as possible from visual cues (plate size, utensils, hands).
For each item, return calories, protein, carbs, and fat in grams.
Be conservative — under-estimate before over-estimating. Confidence reflects how sure you are (0..1).

Return ONLY valid JSON matching this exact shape, no prose:
{ "items": [ { "name": "...", "grams": 0, "kcal": 0, "protein_g": 0, "carbs_g": 0, "fat_g": 0, "confidence": 0.0 } ] }`;

async function analyze(imageURL: string): Promise<unknown> {
  const apiKey = Deno.env.get('OPENAI_API_KEY');
  if (!apiKey) {
    throw new Error('OPENAI_API_KEY not configured');
  }

  const res = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'gpt-4o',
      response_format: { type: 'json_object' },
      temperature: 0.1,
      max_tokens: 800,
      messages: [
        { role: 'system', content: SYSTEM_PROMPT },
        {
          role: 'user',
          content: [
            { type: 'text', text: 'Identify and estimate macros for this meal.' },
            { type: 'image_url', image_url: { url: imageURL, detail: 'high' } },
          ],
        },
      ],
    }),
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`OpenAI ${res.status}: ${errText}`);
  }

  const json = await res.json();
  const raw = json.choices?.[0]?.message?.content;
  if (typeof raw !== 'string') {
    throw new Error('OpenAI returned no content');
  }
  return JSON.parse(raw);
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

    // Signed URL for the image — short TTL.
    const { data: signed, error: signError } = await supabase.storage
      .from('food-scans')
      .createSignedUrl(path, 60);
    if (signError || !signed?.signedUrl) {
      return new Response(JSON.stringify({ error: 'image_not_found' }), {
        status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Call OpenAI, retry once on validation failure.
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
      return new Response(
        JSON.stringify({ error: 'analysis_failed', detail: lastError }),
        { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

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
