-- Vibe Nutrition Coach — initial schema
-- All user-scoped tables enforce RLS via auth.uid() = user_id.

set search_path = public;

create extension if not exists pgcrypto;

-- ============================================================
-- Enums
-- ============================================================
do $$ begin
  create type goal_type as enum (
    'lose_weight',
    'gain_weight',
    'build_muscle',
    'maintain',
    'recomp',
    'improve_health'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type main_focus as enum (
    'fat_loss',
    'muscle_gain',
    'recomp',
    'general_health'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type dietary_pref as enum (
    'normal',
    'high_protein',
    'vegetarian',
    'vegan',
    'halal',
    'keto'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type units_pref as enum ('metric', 'imperial');
exception when duplicate_object then null; end $$;

do $$ begin
  create type sex_type as enum ('male', 'female', 'other');
exception when duplicate_object then null; end $$;

do $$ begin
  create type notification_pref as enum ('full', 'important', 'off');
exception when duplicate_object then null; end $$;

do $$ begin
  create type log_source as enum ('scan', 'manual');
exception when duplicate_object then null; end $$;

do $$ begin
  create type activity_source as enum ('apple_health', 'google_fit', 'manual');
exception when duplicate_object then null; end $$;

do $$ begin
  create type entitlement_tier as enum ('free', 'premium');
exception when duplicate_object then null; end $$;

-- ============================================================
-- profiles — one row per auth.user, holds basic anthropometrics
-- ============================================================
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  age int check (age between 13 and 100),
  sex sex_type,
  height_cm numeric(5,2) check (height_cm between 100 and 250),
  dietary_pref dietary_pref default 'normal',
  units_pref units_pref default 'metric',
  meals_per_day int check (meals_per_day between 2 and 6),
  training_days_per_week int check (training_days_per_week between 0 and 7),
  main_focus main_focus,
  meal_suggestions_enabled boolean default true,
  notification_pref notification_pref default 'important',
  health_sync_enabled boolean default false,
  onboarding_completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table profiles enable row level security;

create policy "profiles_select_own" on profiles
  for select using (auth.uid() = id);

create policy "profiles_insert_own" on profiles
  for insert with check (auth.uid() = id);

create policy "profiles_update_own" on profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

create policy "profiles_delete_own" on profiles
  for delete using (auth.uid() = id);

-- Auto-create a profile row when a user signs up.
create or replace function handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into profiles (id) values (new.id) on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- ============================================================
-- goals — active goal per user (history kept by created_at)
-- ============================================================
create table if not exists goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  type goal_type not null,
  start_weight_kg numeric(5,2) not null check (start_weight_kg between 30 and 300),
  goal_weight_kg numeric(5,2) not null check (goal_weight_kg between 30 and 300),
  created_at timestamptz not null default now()
);

create index if not exists goals_user_id_created_at_idx
  on goals (user_id, created_at desc);

alter table goals enable row level security;

create policy "goals_select_own" on goals
  for select using (auth.uid() = user_id);
create policy "goals_insert_own" on goals
  for insert with check (auth.uid() = user_id);
create policy "goals_update_own" on goals
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "goals_delete_own" on goals
  for delete using (auth.uid() = user_id);

-- ============================================================
-- weight_logs — daily check-ins
-- ============================================================
create table if not exists weight_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  weight_kg numeric(5,2) not null check (weight_kg between 30 and 300),
  logged_at timestamptz not null default now()
);

create index if not exists weight_logs_user_id_logged_at_idx
  on weight_logs (user_id, logged_at desc);

alter table weight_logs enable row level security;

create policy "weight_logs_select_own" on weight_logs
  for select using (auth.uid() = user_id);
create policy "weight_logs_insert_own" on weight_logs
  for insert with check (auth.uid() = user_id);
create policy "weight_logs_update_own" on weight_logs
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "weight_logs_delete_own" on weight_logs
  for delete using (auth.uid() = user_id);

-- ============================================================
-- targets — computed kcal/macro targets, snapshot per recompute
-- ============================================================
create table if not exists targets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  kcal int not null check (kcal between 800 and 6000),
  protein_g int not null check (protein_g >= 0),
  carbs_g int not null check (carbs_g >= 0),
  fat_g int not null check (fat_g >= 0),
  inputs_json jsonb not null,
  computed_at timestamptz not null default now()
);

create index if not exists targets_user_id_computed_at_idx
  on targets (user_id, computed_at desc);

alter table targets enable row level security;

create policy "targets_select_own" on targets
  for select using (auth.uid() = user_id);
create policy "targets_insert_own" on targets
  for insert with check (auth.uid() = user_id);
create policy "targets_update_own" on targets
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "targets_delete_own" on targets
  for delete using (auth.uid() = user_id);

-- ============================================================
-- food_logs — every meal/snack a user logs
-- ============================================================
create table if not exists food_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  image_path text,
  items_json jsonb not null,
  kcal int not null check (kcal >= 0),
  protein_g numeric(6,2) not null check (protein_g >= 0),
  carbs_g numeric(6,2) not null check (carbs_g >= 0),
  fat_g numeric(6,2) not null check (fat_g >= 0),
  source log_source not null default 'manual',
  logged_at timestamptz not null default now()
);

create index if not exists food_logs_user_id_logged_at_idx
  on food_logs (user_id, logged_at desc);

alter table food_logs enable row level security;

create policy "food_logs_select_own" on food_logs
  for select using (auth.uid() = user_id);
create policy "food_logs_insert_own" on food_logs
  for insert with check (auth.uid() = user_id);
create policy "food_logs_update_own" on food_logs
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "food_logs_delete_own" on food_logs
  for delete using (auth.uid() = user_id);

-- ============================================================
-- activity_syncs — daily steps + active kcal from Health/Fit
-- ============================================================
create table if not exists activity_syncs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  source activity_source not null,
  steps int check (steps >= 0),
  active_kcal int check (active_kcal >= 0),
  date date not null,
  synced_at timestamptz not null default now(),
  unique (user_id, source, date)
);

create index if not exists activity_syncs_user_id_date_idx
  on activity_syncs (user_id, date desc);

alter table activity_syncs enable row level security;

create policy "activity_syncs_select_own" on activity_syncs
  for select using (auth.uid() = user_id);
create policy "activity_syncs_insert_own" on activity_syncs
  for insert with check (auth.uid() = user_id);
create policy "activity_syncs_update_own" on activity_syncs
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "activity_syncs_delete_own" on activity_syncs
  for delete using (auth.uid() = user_id);

-- ============================================================
-- entitlements — synced from RevenueCat webhook (server-only writes)
-- ============================================================
create table if not exists entitlements (
  user_id uuid primary key references auth.users(id) on delete cascade,
  tier entitlement_tier not null default 'free',
  expires_at timestamptz,
  product_id text,
  updated_at timestamptz not null default now()
);

alter table entitlements enable row level security;

-- Client can read its own entitlement; writes must come from service role (webhook).
create policy "entitlements_select_own" on entitlements
  for select using (auth.uid() = user_id);

-- ============================================================
-- updated_at trigger helper
-- ============================================================
create or replace function set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on profiles;
create trigger profiles_set_updated_at
  before update on profiles
  for each row execute function set_updated_at();

drop trigger if exists entitlements_set_updated_at on entitlements;
create trigger entitlements_set_updated_at
  before update on entitlements
  for each row execute function set_updated_at();
