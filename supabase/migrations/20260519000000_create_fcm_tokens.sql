create extension if not exists pgcrypto;

create table if not exists public.fcm_tokens (
  id uuid primary key default gen_random_uuid(),
  teacher_id uuid not null,
  token text not null unique,
  platform text not null check (platform in ('android', 'ios')),
  app_version text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);

create index if not exists fcm_tokens_teacher_id_idx
  on public.fcm_tokens (teacher_id);

create index if not exists fcm_tokens_last_seen_at_idx
  on public.fcm_tokens (last_seen_at);

alter table public.fcm_tokens enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'fcm_tokens'
      and policyname = 'fcm_tokens_select_own'
  ) then
    create policy fcm_tokens_select_own
      on public.fcm_tokens
      for select
      using (teacher_id = auth.uid());
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'fcm_tokens'
      and policyname = 'fcm_tokens_insert_own'
  ) then
    create policy fcm_tokens_insert_own
      on public.fcm_tokens
      for insert
      with check (teacher_id = auth.uid());
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'fcm_tokens'
      and policyname = 'fcm_tokens_update_own'
  ) then
    create policy fcm_tokens_update_own
      on public.fcm_tokens
      for update
      using (teacher_id = auth.uid())
      with check (teacher_id = auth.uid());
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'fcm_tokens'
      and policyname = 'fcm_tokens_delete_own'
  ) then
    create policy fcm_tokens_delete_own
      on public.fcm_tokens
      for delete
      using (teacher_id = auth.uid());
  end if;
end $$;

notify pgrst, 'reload schema';
