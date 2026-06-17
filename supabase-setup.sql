-- ============================================================
-- PropManager — Supabase security setup
-- Run this ONCE in: Supabase Dashboard -> SQL Editor -> New query -> Run
-- It makes every user able to access ONLY their own data.
-- Safe to run more than once (idempotent).
-- ============================================================

-- 1) app_data table: one JSON row per user -------------------
alter table public.app_data enable row level security;

drop policy if exists "app_data_select_own" on public.app_data;
drop policy if exists "app_data_insert_own" on public.app_data;
drop policy if exists "app_data_update_own" on public.app_data;
drop policy if exists "app_data_delete_own" on public.app_data;

create policy "app_data_select_own" on public.app_data
  for select using (auth.uid() = user_id);
create policy "app_data_insert_own" on public.app_data
  for insert with check (auth.uid() = user_id);
create policy "app_data_update_own" on public.app_data
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "app_data_delete_own" on public.app_data
  for delete using (auth.uid() = user_id);

-- Guarantee one row per user (required for the app's upsert).
-- If this raises "could not create unique index" you have duplicate
-- rows for a user_id -- delete the extras, then re-run.
do $$
begin
  alter table public.app_data add constraint app_data_user_id_key unique (user_id);
exception
  when duplicate_object then null;
  when duplicate_table  then null;
end $$;

-- 2) Realtime: lets cross-device sync (UPDATE events) reach clients
do $$
begin
  alter publication supabase_realtime add table public.app_data;
exception
  when duplicate_object then null;
end $$;

-- 3) tenant-docs storage bucket: PRIVATE, per-user folders ---
-- Files are stored under "<user_id>/<tenant_id>/<file>", so the first
-- path segment must equal the logged-in user's id.
insert into storage.buckets (id, name, public)
values ('tenant-docs', 'tenant-docs', false)
on conflict (id) do update set public = false;

drop policy if exists "tenant_docs_select_own" on storage.objects;
drop policy if exists "tenant_docs_insert_own" on storage.objects;
drop policy if exists "tenant_docs_delete_own" on storage.objects;

create policy "tenant_docs_select_own" on storage.objects
  for select using (
    bucket_id = 'tenant-docs'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
create policy "tenant_docs_insert_own" on storage.objects
  for insert with check (
    bucket_id = 'tenant-docs'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
create policy "tenant_docs_delete_own" on storage.objects
  for delete using (
    bucket_id = 'tenant-docs'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Done. Verify under: Authentication -> Policies, and Storage -> Policies.
