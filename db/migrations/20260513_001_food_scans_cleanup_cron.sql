-- Schedule the daily food-scans cleanup.
--
-- This migration installs pg_cron + pg_net and registers a cron job that POSTs
-- to the cleanup-food-scans edge function once a day. The function deletes
-- food-scan images older than the retention window (default 7 days) and nulls
-- out the corresponding food_logs.image_path.
--
-- BEFORE APPLYING:
--   1. Deploy the function:   supabase functions deploy cleanup-food-scans --no-verify-jwt
--   2. Set its shared secret: supabase secrets set CLEANUP_SECRET=$(openssl rand -hex 32)
--      Then put the SAME value into the two app.settings.* GUCs below (one-time setup
--      in the Supabase dashboard → Settings → Database → Custom Postgres Config, or
--      via psql with ALTER DATABASE postgres SET ...).
--   3. Fill in the project URL via app.settings.supabase_url.
--
-- One-time GUC setup (run in the SQL editor, replacing placeholders):
--   alter database postgres set app.settings.supabase_url      = 'https://<project-ref>.supabase.co';
--   alter database postgres set app.settings.cleanup_secret    = '<the CLEANUP_SECRET value>';
--   -- Then reconnect (the GUCs are read at session start).

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- Unschedule any prior version of this job so re-running the migration is safe.
do $$
declare
  jobid bigint;
begin
  select j.jobid into jobid from cron.job j where j.jobname = 'cleanup-food-scans-daily';
  if jobid is not null then
    perform cron.unschedule(jobid);
  end if;
end $$;

-- Run every day at 03:17 UTC (avoid top-of-hour congestion).
select cron.schedule(
  'cleanup-food-scans-daily',
  '17 3 * * *',
  $$
  select net.http_post(
    url := current_setting('app.settings.supabase_url') || '/functions/v1/cleanup-food-scans',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.settings.cleanup_secret')
    ),
    body := '{}'::jsonb
  );
  $$
);
