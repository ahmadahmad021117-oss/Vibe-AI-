// Supabase Edge Function — delete-account
// Fully purges a user's data + storage objects + auth row.
// Required for App Store §5.1.1(v) compliance.
//
// Deploy: supabase functions deploy delete-account

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

  // Verify the caller with their own JWT first.
  const userClient = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } }
  );
  const { data: { user }, error: authErr } = await userClient.auth.getUser();
  if (authErr || !user) {
    return new Response(JSON.stringify({ error: 'unauthenticated' }), {
      status: 401, headers: { ...cors, 'Content-Type': 'application/json' },
    });
  }

  const uid = user.id;
  // Switch to service role for destructive ops.
  const admin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  try {
    // 1. List & remove storage objects under <uid>/ in every private bucket.
    for (const bucket of ['food-scans', 'progress-photos']) {
      const { data: files } = await admin.storage.from(bucket).list(uid, { limit: 1000 });
      if (files && files.length > 0) {
        const paths = files.map((f) => `${uid}/${f.name}`);
        await admin.storage.from(bucket).remove(paths);
      }
    }

    // 2. Delete from user-scoped tables. ON DELETE CASCADE on auth.users also fires for FK rows.
    //    We delete explicitly anyway to handle any tables added later that may not cascade.
    const tables = [
      'food_logs', 'weight_logs', 'water_logs', 'body_measurements', 'progress_photos',
      'activity_syncs', 'targets', 'goals', 'entitlements', 'profiles',
    ];
    for (const t of tables) {
      await admin.from(t).delete().eq(t === 'entitlements' ? 'user_id' : (t === 'profiles' ? 'id' : 'user_id'), uid);
    }

    // 3. Delete the auth user (this also cascades to anything with FK to auth.users).
    const { error: delErr } = await admin.auth.admin.deleteUser(uid);
    if (delErr) throw delErr;

    return new Response(JSON.stringify({ ok: true }), {
      status: 200, headers: { ...cors, 'Content-Type': 'application/json' },
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'unknown';
    return new Response(JSON.stringify({ error: 'delete_failed', detail: message }), {
      status: 500, headers: { ...cors, 'Content-Type': 'application/json' },
    });
  }
});
