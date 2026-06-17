-- ============================================================
-- PropManager — Team / shared-workspace access
-- Run ONCE in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Lets an owner invite people (by email) to read/edit THEIR portfolio,
-- while every other user stays fully isolated. Safe to run more than once.
-- ============================================================

-- 1) Tables ---------------------------------------------------
create table if not exists public.team_members (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  member_id uuid not null references auth.users(id) on delete cascade,
  email text,
  role text not null default 'editor',
  created_at timestamptz default now(),
  unique(owner_id, member_id)
);
create table if not exists public.team_invites (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  email text not null,
  role text not null default 'editor',
  created_at timestamptz default now(),
  unique(owner_id, email)
);

-- 2) Access helper (SECURITY DEFINER avoids RLS recursion) ----
create or replace function public.has_workspace_access(target uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select target = auth.uid()
      or exists(select 1 from public.team_members m
                where m.owner_id = target and m.member_id = auth.uid());
$$;

-- 3) app_data: owner OR granted team member may read/update ---
alter table public.app_data enable row level security;
drop policy if exists "app_data_select_own" on public.app_data;
drop policy if exists "app_data_update_own" on public.app_data;
drop policy if exists "Users can read their own data" on public.app_data;
drop policy if exists "Users can update their own data" on public.app_data;
drop policy if exists "app_data_select_access" on public.app_data;
drop policy if exists "app_data_update_access" on public.app_data;
create policy "app_data_select_access" on public.app_data
  for select using (public.has_workspace_access(user_id));
create policy "app_data_update_access" on public.app_data
  for update using (public.has_workspace_access(user_id))
  with check (public.has_workspace_access(user_id));
-- insert/delete remain owner-only (app_data_insert_own / app_data_delete_own).

-- 4) team_members policies ------------------------------------
alter table public.team_members enable row level security;
drop policy if exists "tm_select" on public.team_members;
drop policy if exists "tm_insert" on public.team_members;
drop policy if exists "tm_delete" on public.team_members;
create policy "tm_select" on public.team_members
  for select using (owner_id = auth.uid() or member_id = auth.uid());
create policy "tm_insert" on public.team_members
  for insert with check (
    owner_id = auth.uid()
    or (member_id = auth.uid() and exists(
        select 1 from public.team_invites i
        where i.owner_id = team_members.owner_id
          and lower(i.email) = lower(coalesce(auth.jwt()->>'email','')))));
create policy "tm_delete" on public.team_members
  for delete using (owner_id = auth.uid() or member_id = auth.uid());

-- 5) team_invites policies ------------------------------------
alter table public.team_invites enable row level security;
drop policy if exists "ti_select" on public.team_invites;
drop policy if exists "ti_insert" on public.team_invites;
drop policy if exists "ti_delete" on public.team_invites;
create policy "ti_select" on public.team_invites
  for select using (owner_id = auth.uid()
                    or lower(email) = lower(coalesce(auth.jwt()->>'email','')));
create policy "ti_insert" on public.team_invites
  for insert with check (owner_id = auth.uid());
create policy "ti_delete" on public.team_invites
  for delete using (owner_id = auth.uid()
                    or lower(email) = lower(coalesce(auth.jwt()->>'email','')));

-- 6) Realtime for live team updates ---------------------------
do $$ begin
  alter publication supabase_realtime add table public.team_members;
exception when duplicate_object then null; end $$;

-- Done. Verify under Database -> Policies.
