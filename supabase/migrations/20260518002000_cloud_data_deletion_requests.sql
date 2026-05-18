create table if not exists public.cloud_data_deletion_requests (
  teacher_id uuid primary key,
  scheduled_for timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists cloud_data_deletion_requests_scheduled_for_idx
  on public.cloud_data_deletion_requests (scheduled_for);

alter table public.cloud_data_deletion_requests enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'cloud_data_deletion_requests'
      and policyname = 'cloud_data_deletion_requests_select_own'
  ) then
    create policy cloud_data_deletion_requests_select_own
      on public.cloud_data_deletion_requests
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
      and tablename = 'cloud_data_deletion_requests'
      and policyname = 'cloud_data_deletion_requests_insert_own'
  ) then
    create policy cloud_data_deletion_requests_insert_own
      on public.cloud_data_deletion_requests
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
      and tablename = 'cloud_data_deletion_requests'
      and policyname = 'cloud_data_deletion_requests_update_own'
  ) then
    create policy cloud_data_deletion_requests_update_own
      on public.cloud_data_deletion_requests
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
      and tablename = 'cloud_data_deletion_requests'
      and policyname = 'cloud_data_deletion_requests_delete_own'
  ) then
    create policy cloud_data_deletion_requests_delete_own
      on public.cloud_data_deletion_requests
      for delete
      using (teacher_id = auth.uid());
  end if;
end $$;

notify pgrst, 'reload schema';
