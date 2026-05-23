-- Server-side scan quota for the free-tier.
--
-- Background: the free tier allows N scans per day. Originally the count was
-- derived from saved food_logs rows on the client, but users could bypass it
-- by tapping "Retake" — the AI call was already paid for, but no log row
-- meant no decrement. This migration moves enforcement into the database via
-- an atomic check-and-record function called from the analyze-food edge
-- function BEFORE Anthropic is invoked.
--
-- Quota algebra:
--   used_today = COUNT(scan_attempts WHERE user = me AND status IN ('pending','success')
--                                      AND created_at >= start_of_utc_day)
--   premium users are never gated.
--
-- Failed attempts (Anthropic errored, image not found, etc.) are marked
-- 'failed' by the edge function and do NOT count — so server outages don't
-- burn the user's free scans.

-- ============================================================
-- scan_attempts — one row per analyze-food invocation
-- ============================================================
create table if not exists scan_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  status text not null default 'pending'
    check (status in ('pending', 'success', 'failed'))
);

create index if not exists scan_attempts_user_created_idx
  on scan_attempts (user_id, created_at desc);

-- Partial index optimises the quota count query (today's billable attempts only).
create index if not exists scan_attempts_user_billable_idx
  on scan_attempts (user_id, created_at desc)
  where status in ('pending', 'success');

alter table scan_attempts enable row level security;

-- Clients can read their own attempts (so the UI can show "X scans left today").
create policy "scan_attempts_select_own" on scan_attempts
  for select using (auth.uid() = user_id);

-- Writes are service-role only. No insert/update/delete policy for clients.

-- ============================================================
-- check_and_record_scan — atomic gate + insert
-- ============================================================
-- Returns the new attempt row's id on success, or raises 'quota_exceeded'
-- (SQLSTATE P0001) if the user is over their free daily limit and not
-- premium. The edge function must update the returned row's status to
-- 'success' after Anthropic returns, or 'failed' on error.
--
-- security definer + locked search_path so the function can write to
-- scan_attempts even when called by RLS-restricted roles.
create or replace function check_and_record_scan(
  p_user_id uuid,
  p_daily_limit int
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_is_premium boolean;
  v_count int;
  v_id uuid;
begin
  -- Premium check (lifetime = null expires_at).
  select (tier = 'premium' and (expires_at is null or expires_at > now()))
    into v_is_premium
    from entitlements
    where user_id = p_user_id;
  v_is_premium := coalesce(v_is_premium, false);

  if not v_is_premium then
    select count(*) into v_count
      from scan_attempts
      where user_id = p_user_id
        and status in ('pending', 'success')
        and created_at >= date_trunc('day', now() at time zone 'utc');

    if v_count >= p_daily_limit then
      raise exception 'quota_exceeded' using errcode = 'P0001';
    end if;
  end if;

  insert into scan_attempts (user_id, status)
    values (p_user_id, 'pending')
    returning id into v_id;

  return v_id;
end;
$$;

revoke all on function check_and_record_scan(uuid, int) from public;
grant execute on function check_and_record_scan(uuid, int) to service_role;

-- ============================================================
-- mark_scan_outcome — finalise a recorded attempt
-- ============================================================
-- Called by the edge function after Anthropic responds (or errors).
-- Idempotent: calling it twice with the same outcome is a no-op.
create or replace function mark_scan_outcome(
  p_attempt_id uuid,
  p_status text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_status not in ('success', 'failed') then
    raise exception 'invalid_status: %', p_status;
  end if;

  update scan_attempts
    set status = p_status
    where id = p_attempt_id
      and status = 'pending';
end;
$$;

revoke all on function mark_scan_outcome(uuid, text) from public;
grant execute on function mark_scan_outcome(uuid, text) to service_role;
