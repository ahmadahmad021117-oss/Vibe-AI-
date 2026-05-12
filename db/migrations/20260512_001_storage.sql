-- Storage bucket for food scan images. One folder per user (auth.uid()).
insert into storage.buckets (id, name, public)
values ('food-scans', 'food-scans', false)
on conflict (id) do nothing;

-- Users can read/write only objects under their own uid folder.
create policy "food_scans_read_own"
  on storage.objects for select
  using (
    bucket_id = 'food-scans'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "food_scans_insert_own"
  on storage.objects for insert
  with check (
    bucket_id = 'food-scans'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "food_scans_delete_own"
  on storage.objects for delete
  using (
    bucket_id = 'food-scans'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
