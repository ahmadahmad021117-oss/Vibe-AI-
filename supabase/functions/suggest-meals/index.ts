// Supabase Edge Function — suggest-meals
// Given remaining macros for the day + dietary pref + goal direction, returns 3
// meal ideas matched to the budget. Uses Anthropic Claude with structured tool
// calling (matches analyze-food).
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

const GOAL_TYPES = ['lose_weight', 'gain_weight', 'build_muscle', 'maintain', 'recomp', 'improve_health'] as const;

const RequestSchema = z.object({
  remaining_kcal: z.number().int(),
  remaining_protein_g: z.number().nonnegative(),
  remaining_carbs_g: z.number().nonnegative(),
  remaining_fat_g: z.number().nonnegative(),
  dietary_pref: z.enum(['normal', 'high_protein', 'vegetarian', 'vegan', 'halal', 'keto']),
  // Optional so older clients keep working. When absent, the prompt falls back
  // to a goal-neutral framing (no calorie-dense bias either way).
  goal_type: z.enum(GOAL_TYPES).optional(),
  // Optional list of meal names the client already saw. The model is told to
  // avoid these so a "refresh" tap yields genuinely new ideas instead of the
  // same three over and over.
  previous_names: z.array(z.string().min(1).max(80)).max(30).optional(),
});

const IngredientSchema = z.object({
  name: z.string().min(1).max(80),
  // Numeric so the client can scale every ingredient by the chosen portion.
  quantity: z.number().positive(),
  // Free-form unit (g, ml, tbsp, slice, clove, …) — kept short.
  unit: z.string().min(1).max(20),
});

const SuggestionSchema = z.object({
  name: z.string().min(1).max(80),
  description: z.string().min(1).max(200),
  // Floor at 100 kcal: anything below this isn't really a "meal idea" — it's a
  // sip of water. The 0-kcal results users were seeing came from the per-meal
  // budget collapsing to ~0 when they were already at target.
  kcal: z.number().int().min(100),
  protein_g: z.number().nonnegative(),
  carbs_g: z.number().nonnegative(),
  fat_g: z.number().nonnegative(),
  // Ingredients + prep steps describe ONE serving. The client's portion
  // calculator scales quantities and macros from this single-serving baseline.
  ingredients: z.array(IngredientSchema).min(2).max(15),
  steps: z.array(z.string().min(1).max(200)).min(1).max(8),
});

const ResponseSchema = z.object({
  suggestions: z.array(SuggestionSchema).length(3),
});

const SYSTEM_PROMPT = `You are a nutrition coach. Suggest exactly 3 realistic meal ideas that
match the user's remaining daily macros, dietary preference, and weight goal.

RULES (all enforced — never break them):
- Each meal MUST be at least 100 kcal. Never return 0-kcal items. If the user has
  already met their daily calorie budget (remaining_kcal ≤ 300), suggest LIGHT
  snacks of 100–250 kcal each that respect their goal.
- Otherwise, target each meal at roughly remaining_kcal/3, within ±25%.
- Macros must sum coherently: kcal ≈ protein_g*4 + carbs_g*4 + fat_g*9 (±15%).
- Names: under 40 chars, specific (e.g. "Greek chicken bowl" not "Healthy bowl").
- Description: one short sentence with the main ingredients and prep style.
- VARIETY: avoid repeating any name in the user's "avoid these names" list, and
  prefer different cuisines/cooking methods across the 3 suggestions in a single
  response (don't return three variations of the same dish).
- INGREDIENTS: list 2–15 ingredients for ONE serving. Each needs a numeric
  quantity and a short unit (prefer metric: g, ml; otherwise tbsp, tsp, slice,
  clove, piece, cup). Quantities must be realistic and roughly add up to the
  meal's stated macros. No "to taste" — use a small number (e.g. 1 g salt).
- STEPS: 1–8 concise prep steps, imperative voice ("Grill the chicken 6 min").

GOAL TAILORING:
- lose_weight: lean, high-volume, low-calorie-density meals. Lean protein,
  vegetables, sparing healthy fats. Lean toward the lower end of the kcal range.
- gain_weight / build_muscle: calorie-dense, higher portions. Include healthy
  fats (nuts, avocado, olive oil), starchy carbs, and full-fat dairy where
  diet permits. Lean toward the higher end of the kcal range.
- maintain / recomp / improve_health (or unspecified): balanced plates with
  moderate portions of protein, carbs, and fats.

Call the suggest_meals tool exactly once with all 3 suggestions.`;

const SUGGEST_MEALS_TOOL = {
  name: 'suggest_meals',
  description: "Return 3 meal suggestions that fit the user's remaining daily macros, diet, and weight goal.",
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
            kcal: { type: 'integer', minimum: 100 },
            protein_g: { type: 'number', minimum: 0 },
            carbs_g: { type: 'number', minimum: 0 },
            fat_g: { type: 'number', minimum: 0 },
            ingredients: {
              type: 'array',
              minItems: 2,
              maxItems: 15,
              description: 'Ingredients for ONE serving.',
              items: {
                type: 'object',
                properties: {
                  name: { type: 'string', maxLength: 80 },
                  quantity: { type: 'number', minimum: 0 },
                  unit: { type: 'string', maxLength: 20 },
                },
                required: ['name', 'quantity', 'unit'],
              },
            },
            steps: {
              type: 'array',
              minItems: 1,
              maxItems: 8,
              description: 'Concise prep steps in order.',
              items: { type: 'string', maxLength: 200 },
            },
          },
          required: ['name', 'description', 'kcal', 'protein_g', 'carbs_g', 'fat_g', 'ingredients', 'steps'],
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
      // Raised from 768: 3 meals now each carry an ingredient list + prep steps,
      // which can run past the old ceiling and truncate the tool call.
      max_tokens: 2048,
      // Bumped to 1.0 so refresh actually produces different ideas. The old
      // default-temperature calls returned near-identical suggestions every time.
      temperature: 1.0,
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
    const {
      remaining_kcal, remaining_protein_g, remaining_carbs_g, remaining_fat_g,
      dietary_pref, goal_type, previous_names,
    } = parsed.data;

    const avoidLine = previous_names && previous_names.length > 0
      ? `\nAvoid these names (already suggested): ${previous_names.slice(0, 20).join(', ')}.`
      : '';
    const goalLine = goal_type ? `Weight goal: ${goal_type}.` : 'Weight goal: unspecified (treat as maintain).';
    const budgetLine = remaining_kcal <= 300
      ? 'The user is at or near their daily calorie target — suggest 3 LIGHT snacks of 100–250 kcal each.'
      : `Target each meal at roughly ${Math.round(remaining_kcal / 3)} kcal (±25%), minimum 100 kcal.`;

    const userPrompt =
      `Remaining today: ${remaining_kcal} kcal, ${remaining_protein_g}g protein, ` +
      `${remaining_carbs_g}g carbs, ${remaining_fat_g}g fat. Diet: ${dietary_pref}. ${goalLine}\n` +
      budgetLine + avoidLine;

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
