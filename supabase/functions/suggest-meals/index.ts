// Supabase Edge Function — suggest-meals
// Given remaining macros for the day + dietary pref, returns 3 meal ideas matched to the budget.

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

const SYSTEM = `You are a nutrition coach. Suggest exactly 3 realistic meal ideas that fit the user's
remaining daily macros and dietary preference. Keep names short. One-sentence description.
Macros should sum within ±20% of the kcal target. Return ONLY JSON:
{ "suggestions": [ { "name": "...", "description": "...", "kcal": 0, "protein_g": 0, "carbs_g": 0, "fat_g": 0 } ] }`;

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
      return new Response(JSON.stringify({ error: 'invalid_request' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    const { remaining_kcal, remaining_protein_g, remaining_carbs_g, remaining_fat_g, dietary_pref } = parsed.data;

    const apiKey = Deno.env.get('OPENAI_API_KEY');
    if (!apiKey) throw new Error('OPENAI_API_KEY not configured');

    const res = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        response_format: { type: 'json_object' },
        temperature: 0.4,
        max_tokens: 500,
        messages: [
          { role: 'system', content: SYSTEM },
          {
            role: 'user',
            content: `Remaining today: ${remaining_kcal} kcal, ${remaining_protein_g}g protein, ${remaining_carbs_g}g carbs, ${remaining_fat_g}g fat. Diet: ${dietary_pref}.`,
          },
        ],
      }),
    });

    if (!res.ok) {
      return new Response(JSON.stringify({ error: 'suggestion_failed' }), {
        status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const json = await res.json();
    const raw = json.choices?.[0]?.message?.content;
    const validated = ResponseSchema.safeParse(JSON.parse(raw));
    if (!validated.success) {
      return new Response(JSON.stringify({ error: 'invalid_model_output' }), {
        status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    return new Response(JSON.stringify(validated.data), {
      status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'unknown';
    return new Response(JSON.stringify({ error: 'server_error', detail: message }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
