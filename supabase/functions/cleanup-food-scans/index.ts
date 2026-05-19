// Supabase Edge Function — cleanup-food-scans
// Deletes food-scan images older than the retention window AND nulls out the
// food_logs.image_path reference. Intended to be invoked daily by pg_cron.
//
// Auth: requires a CLEANUP_SECRET shared secret in the Authorization header
//       (Bearer scheme). pg_cron sends this. We do NOT use user JWTs here.
//
// Deploy:    supabase functions deploy cleanup-food-scans --no-verify-jwt
// Secrets:   supabase secrets set CLEANUP_SECRET=$(openssl rand -hex 32)
// Tune:      supabase secrets set FOOD_SCANS_RETENTION_DAYS=7   # optional, default 7
//
// Manual run (after setting the secret):
//   curl -X POST "$SUPABASE_URL/functions/v1/cleanup-food-scans" \
//        -H "Authorization: Bearer $CLEANUP_SECRET"

import { serve } from 'https://deno.land/std@0.208.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const DEFAULT_RETENTION_DAYS = 7;
const BATCH_SIZE = 100; // storage.remove() accepts arrays; keep batches modest.

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });

  // Shared-secret auth. The function is deployed with --no-verify-jwt so it doesn't
  // require a user JWT; instead it requires a Bearer token that matches CLEANUP_SECRET.
  const expected = Deno.env.get('CLEANUP_SECRET');
  if (!expected) {
    return new Response(JSON.stringify({ error: 'misconfigured', detail: 'CLEANUP_SECRET not set' }), {
      status: 500, headers: { ...cors, 'Content-Type': 'application/json' },
    });
  }
  const auth = req.headers.get('Authorization') ?? '';
  if (auth !== `Bearer ${expected}`) {
    return new Response(JSON.stringify({ error: 'forbidden' }), {
      status: 403, headers: { ...cors, 'Content-Type': 'application/json' },
    });
  }

  // Retention window — request body wins over env, env wins over default.
  let retentionDays = Number(Deno.env.get('FOOD_SCANS_RETENTION_DAYS') ?? DEFAULT_RETENTION_DAYS);
  try {
    const body = await req.json();
    if (typeof body?.retention_days === 'number' && body.retention_days > 0) {
      retentionDays = body.retention_days;
    }
  } catch {
    // No body / not JSON — fine, use the env/default.
  }

  const cutoff = new Date(Date.now() - retentionDays * 24 * 60 * 60 * 1000).toISOString();

  const admin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  try {
    // Find rows whose image is past retention. Paginate so we don't OOM on huge tables.
    const PAGE = 500;
    let totalDeleted = 0;
    let totalCleared = 0;
    const errors: string[] = [];

    for (;;) {
      const { data: rows, error: selectErr } = await admin
        .from('food_logs')
        .select('id, image_path')
        .lt('logged_at', cutoff)
        .not('image_path', 'is', null)
        .limit(PAGE);

      if (selectErr) {
        errors.push(`select: ${selectErr.message}`);
        break;
      }
      if (!rows || rows.length === 0) break;

      const paths = rows.map((r) => r.image_path as string).filter(Boolean);
      const ids = rows.map((r) => r.id as string);

      // Delete storage objects in batches.
      for (let i = 0; i < paths.length; i += BATCH_SIZE) {
        const slice = paths.slice(i, i + BATCH_SIZE);
        const { error: rmErr } = await admin.storage.from('food-scans').remove(slice);
        if (rmErr) {
          // Don't bail — keep going so a single bad file doesn't block the sweep.
          errors.push(`storage.remove: ${rmErr.message}`);
        } else {
          totalDeleted += slice.length;
        }
      }

      // Null out image_path on those rows so the UI stops trying to load the image.
      const { error: updateErr } = await admin
        .from('food_logs')
        .update({ image_path: null })
        .in('id', ids);
      if (updateErr) {
        errors.push(`update: ${updateErr.message}`);
      } else {
        totalCleared += ids.length;
      }

      // If we got less than a full page, we're done.
      if (rows.length < PAGE) break;
    }

    return new Response(
      JSON.stringify({
        ok: errors.length === 0,
        retention_days: retentionDays,
        cutoff,
        deleted_objects: totalDeleted,
        cleared_rows: totalCleared,
        errors,
      }),
      { status: 200, headers: { ...cors, 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : 'unknown';
    return new Response(JSON.stringify({ error: 'cleanup_failed', detail: message }), {
      status: 500, headers: { ...cors, 'Content-Type': 'application/json' },
    });
  }
});
