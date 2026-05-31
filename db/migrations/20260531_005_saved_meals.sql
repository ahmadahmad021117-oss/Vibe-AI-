-- Adds saved_meals — a per-user "meal registry".
-- Meals the user keeps from the home-screen Meal Ideas card so they can
-- re-log them later without regenerating suggestions.
--
-- RLS mirrors the other user-scoped tables: owner-only read/write via auth.uid().

set search_path = public;

create table if not exists saved_meals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 200),
  description text not null default '',
  kcal int not null check (kcal >= 0),
  protein_g numeric(6,2) not null default 0 check (protein_g >= 0),
  carbs_g numeric(6,2) not null default 0 check (carbs_g >= 0),
  fat_g numeric(6,2) not null default 0 check (fat_g >= 0),
  created_at timestamptz not null default now()
);

create index if not exists saved_meals_user_id_created_at_idx
  on saved_meals (user_id, created_at desc);

alter table saved_meals enable row level security;

create policy "saved_meals_select_own" on saved_meals
  for select using (auth.uid() = user_id);
create policy "saved_meals_insert_own" on saved_meals
  for insert with check (auth.uid() = user_id);
create policy "saved_meals_update_own" on saved_meals
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "saved_meals_delete_own" on saved_meals
  for delete using (auth.uid() = user_id);
