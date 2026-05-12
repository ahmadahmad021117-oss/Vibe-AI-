// Supabase Edge Function — weekly-progress
// Generates a short progress summary for one user (last 7 days vs expected).
// Invoked by the iOS client when showing the weekly report screen.
//
// Deploy: supabase functions deploy weekly-progress

import { serve } from 'https://deno.land/std@0.208.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return new Response(JSON.stringify({ error: 'unauthenticated' }), {
      status: 401, headers: { ...cors, 'Content-Type': 'application/json' },
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
      status: 401, headers: { ...cors, 'Content-Type': 'application/json' },
    });
  }

  const since = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();

  // Pull last 7 days of logs + weights, latest target.
  const [{ data: logs }, { data: weights }, { data: targetRows }] = await Promise.all([
    supabase.from('food_logs').select('kcal, protein_g, carbs_g, fat_g, logged_at').eq('user_id', user.id).gte('logged_at', since),
    supabase.from('weight_logs').select('weight_kg, logged_at').eq('user_id', user.id).gte('logged_at', since).order('logged_at', { ascending: true }),
    supabase.from('targets').select('kcal, protein_g, inputs_json, computed_at').eq('user_id', user.id).order('computed_at', { ascending: false }).limit(1),
  ]);

  const target = targetRows?.[0];
  if (!target) {
    return new Response(JSON.stringify({ error: 'no_target' }), {
      status: 404, headers: { ...cors, 'Content-Type': 'application/json' },
    });
  }

  const days = 7;
  const avgKcal = (logs ?? []).reduce((a, l) => a + (l.kcal as number), 0) / days;
  const avgProtein = (logs ?? []).reduce((a, l) => a + Number(l.protein_g), 0) / days;
  const adherence = Math.round((avgKcal / target.kcal) * 100);

  const firstW = weights?.[0]?.weight_kg as number | undefined;
  const lastW = weights?.[weights.length - 1]?.weight_kg as number | undefined;
  const actualDeltaKg = (firstW && lastW) ? Number(lastW) - Number(firstW) : null;
  const expectedDeltaKg = (target.inputs_json as Record<string, unknown>)?.weekly_delta_kg as number | undefined ?? null;

  // Flag for adaptive nudge: |actual - expected| > 0.3 kg AND we have both values.
  const adaptiveNudge = (actualDeltaKg !== null && expectedDeltaKg !== null)
    ? Math.abs(Number(actualDeltaKg) - Number(expectedDeltaKg)) > 0.3
    : false;

  return new Response(JSON.stringify({
    days,
    log_count: logs?.length ?? 0,
    avg_kcal: Math.round(avgKcal),
    avg_protein_g: Math.round(avgProtein),
    target_kcal: target.kcal,
    adherence_pct: adherence,
    weight_start_kg: firstW ?? null,
    weight_end_kg: lastW ?? null,
    actual_delta_kg: actualDeltaKg !== null ? Number(Number(actualDeltaKg).toFixed(2)) : null,
    expected_delta_kg: expectedDeltaKg,
    adaptive_nudge: adaptiveNudge,
  }), {
    status: 200, headers: { ...cors, 'Content-Type': 'application/json' },
  });
});
