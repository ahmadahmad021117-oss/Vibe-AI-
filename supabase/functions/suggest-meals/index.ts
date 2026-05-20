// Supabase Edge Function — suggest-meals
// Given remaining macros for the day + dietary pref, returns 3 meal ideas matched to the budget.
// Uses Anthropic Claude with structured tool calling (matches analyze-food).
//
// Deploy: supabase functions deploy suggest-meals
// Required secrets: ANTHROPIC_API_KEY (supabase secrets set ANTHROPIC_API_KEY=...)

import { serve } from 'https://deno.land/std@0.208.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0';
import { z } from 'https://esm.sh/zod@3.23.8';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const RequestSchema = z.object({
  remaining_kcal: z.number().int(),
  remaining_protein_g: z.number().nonnegative(),
  remaining_carbs_g: z.number().nonnegative(),
  remaining_fat_g: z.number().nonnegative(),
  dietary_pref: z.enum(['normal', 'high_protein', 'vegetarian', 'vegan', 'halal', 'keto']),
});

const SuggestionSchema = z.object({
  name: z.string().min(1).max(80),
  description: z.string().min(1).max(200),
  kcal: z.number().int().nonnegative(),
  protein_g: z.number().nonnegative(),
  carbs_g: z.number().nonnegative(),
  fat_g: z.number().nonnegative(),
});

const ResponseSchema = z.object({
  suggestions: z.array(SuggestionSchema).length(3),
});

const SYSTEM_PROMPT = `You are a nutrition coach. Suggest exactly 3 realistic meal ideas that fit the user's
remaining daily macros and dietary preference. Keep names short (under 40 chars). One-sentence description.
Each meal's kcal should be within ±20% of the per-meal target (remaining_kcal / 3).
Call the suggest_meals tool exactly once with all 3 suggestions.`;

const SUGGEST_MEALS_TOOL = {
  name: 'suggest_meals',
  description: 'Return 3 meal suggestions that fit the user\'s remaining daily macros and diet.',
  input_schema: {
    type: 'object',
    properties: {
      suggestions: {
        type: 'array',
        minItems: 3,
        maxItems: 3,
        items: {
          type: 'object',
          properties: {
            name: { type: 'string', maxLength: 80 },
            description: { type: 'string', maxLength: 200 },
            kcal: { type: 'integer', minimum: 0 },
            protein_g: { type: 'number', minimum: 0 },
            carbs_g: { type: 'number', minimum: 0 },
            fat_g: { type: 'number', minimum: 0 },
          },
          required: ['name', 'description', 'kcal', 'protein_g', 'carbs_g', 'fat_g'],
        },
      },
    },
    required: ['suggestions'],
  },
  // Cache prefix — tool schema + system prompt don't change request-to-request.
  cache_control: { type: 'ephemeral' },
};

async function suggest(userPrompt: string): Promise<unknown> {
  const apiKey = Deno.env.get('ANTHROPIC_API_KEY');
  if (!apiKey) throw new Error('ANTHROPIC_API_KEY not configured');

  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      model: 'claude-haiku-4-5-20251001',  // fast + cheap, plenty for this task
      max_tokens: 512,
      system: [
        { type: 'text', text: SYSTEM_PROMPT, cache_control: { type: 'ephemeral' } },
      ],
      tools: [SUGGEST_MEALS_TOOL],
      tool_choice: { type: 'tool', name: 'suggest_meals' },
      messages: [{ role: 'user', content: userPrompt }],
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
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
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
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      return new Response(JSON.stringify({ error: 'unauthenticated' }), {
        status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const parsed = RequestSchema.safeParse(await req.json().catch(() => ({})));
    if (!parsed.success) {
      return new Response(JSON.stringify({ error: 'invalid_request', issues: parsed.error.issues }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    const { remaining_kcal, remaining_protein_g, remaining_carbs_g, remaining_fat_g, dietary_pref } = parsed.data;

    const userPrompt =
      `Remaining today: ${remaining_kcal} kcal, ${remaining_protein_g}g protein, ` +
      `${remaining_carbs_g}g carbs, ${remaining_fat_g}g fat. Diet: ${dietary_pref}.`;

    // Retry once on schema-validation failure (rare with tool calling, but cheap insurance).
    let validated: z.infer<typeof ResponseSchema> | null = null;
    let lastError: unknown = null;
    for (let attempt = 0; attempt < 2 && !validated; attempt++) {
      try {
        const raw = await suggest(userPrompt);
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
      return new Response(JSON.stringify({ error: 'suggestion_failed', detail: lastError }), {
        status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
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
