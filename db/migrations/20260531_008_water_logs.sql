-- Adds water tracking.
--   * water_logs — one row per "drink" event (amount in millilitres).
--   * profiles.water_goal_ml — the user's daily hydration target.
--
-- Water is a free engagement feature (no entitlement gate): it boosts daily
-- opens and gives the home/lock-screen widgets a second thing to do. RLS
-- mirrors the other user-scoped tables, using the (select auth.uid()) form so
-- the policy is evaluated once per query (auth_rls_initplan, linter 0003).

set search_path = public;

-- Daily hydration goal lives on the profile so it can be set once and read
-- everywhere (dashboard card + widget). 2000 ml is the common default.
alter table profiles
  add column if not exists water_goal_ml int not null default 2000
    check (water_goal_ml between 250 and 10000);

create table if not exists water_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  amount_ml int not null check (amount_ml between 1 and 5000),
  logged_at timestamptz not null default now()
);

create index if not exists water_logs_user_id_logged_at_idx
  on water_logs (user_id, logged_at desc);

alter table water_logs enable row level security;

create policy "water_logs_select_own" on water_logs
  for select using ((select auth.uid()) = user_id);
create policy "water_logs_insert_own" on water_logs
  for insert with check ((select auth.uid()) = user_id);
create policy "water_logs_update_own" on water_logs
  for update using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "water_logs_delete_own" on water_logs
  for delete using ((select auth.uid()) = user_id);
