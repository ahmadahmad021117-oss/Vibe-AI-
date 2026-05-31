-- Adds body-progress tracking.
--   * body_measurements — circumferences + body-fat % check-ins. Weight stays
--     in weight_logs; this table is for the other tape-measure metrics.
--   * progress_photos — metadata rows pointing at images in the
--     `progress-photos` storage bucket (one private folder per user).
--
-- Both are free engagement features. RLS mirrors the other user-scoped tables
-- with the (select auth.uid()) initplan form. The storage policies mirror the
-- food-scans bucket: a user may only touch objects under their own uid folder.

set search_path = public;

-- ============================================================
-- body_measurements
-- ============================================================
create table if not exists body_measurements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  waist_cm numeric(5,2) check (waist_cm between 20 and 250),
  hip_cm   numeric(5,2) check (hip_cm   between 20 and 250),
  chest_cm numeric(5,2) check (chest_cm between 20 and 250),
  arm_cm   numeric(5,2) check (arm_cm   between 5  and 100),
  thigh_cm numeric(5,2) check (thigh_cm between 10 and 150),
  body_fat_pct numeric(4,1) check (body_fat_pct between 1 and 75),
  notes text check (notes is null or char_length(notes) <= 500),
  measured_at timestamptz not null default now()
);

create index if not exists body_measurements_user_id_measured_at_idx
  on body_measurements (user_id, measured_at desc);

alter table body_measurements enable row level security;

create policy "body_measurements_select_own" on body_measurements
  for select using ((select auth.uid()) = user_id);
create policy "body_measurements_insert_own" on body_measurements
  for insert with check ((select auth.uid()) = user_id);
create policy "body_measurements_update_own" on body_measurements
  for update using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "body_measurements_delete_own" on body_measurements
  for delete using ((select auth.uid()) = user_id);

-- ============================================================
-- progress_photos
-- ============================================================
create table if not exists progress_photos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  image_path text not null,
  weight_kg numeric(5,2) check (weight_kg between 30 and 300),
  notes text check (notes is null or char_length(notes) <= 500),
  taken_at timestamptz not null default now()
);

create index if not exists progress_photos_user_id_taken_at_idx
  on progress_photos (user_id, taken_at desc);

alter table progress_photos enable row level security;

create policy "progress_photos_select_own" on progress_photos
  for select using ((select auth.uid()) = user_id);
create policy "progress_photos_insert_own" on progress_photos
  for insert with check ((select auth.uid()) = user_id);
create policy "progress_photos_update_own" on progress_photos
  for update using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "progress_photos_delete_own" on progress_photos
  for delete using ((select auth.uid()) = user_id);

-- ============================================================
-- Storage bucket for progress photos. One folder per user (auth.uid()).
-- Private; the app reads via short-lived signed URLs.
-- ============================================================
insert into storage.buckets (id, name, public)
values ('progress-photos', 'progress-photos', false)
on conflict (id) do nothing;

create policy "progress_photos_read_own"
  on storage.objects for select
  using (
    bucket_id = 'progress-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "progress_photos_insert_own"
  on storage.objects for insert
  with check (
    bucket_id = 'progress-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "progress_photos_delete_own"
  on storage.objects for delete
  using (
    bucket_id = 'progress-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
