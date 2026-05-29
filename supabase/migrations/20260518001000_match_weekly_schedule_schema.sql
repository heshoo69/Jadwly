-- The app writes to the existing weekly_schedule columns:
-- id, teacher_id, day_of_week, period_number, start_time, end_time,
-- class_name, subject, room, notes, is_active, created_at, updated_at.
-- Do not add class_id or room_number unless the app schema is changed.

create table if not exists public.weekly_schedule (
  id uuid primary key,
  teacher_id uuid not null,
  day_of_week text not null,
  period_number integer not null,
  start_time time not null,
  end_time time not null,
  class_name text not null,
  subject text,
  room text,
  notes text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists weekly_schedule_teacher_id_idx
  on public.weekly_schedule (teacher_id);

alter table public.weekly_schedule enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'weekly_schedule'
      and policyname = 'weekly_schedule_select_own'
  ) then
    create policy weekly_schedule_select_own
      on public.weekly_schedule
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
      and tablename = 'weekly_schedule'
      and policyname = 'weekly_schedule_insert_own'
  ) then
    create policy weekly_schedule_insert_own
      on public.weekly_schedule
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
      and tablename = 'weekly_schedule'
      and policyname = 'weekly_schedule_update_own'
  ) then
    create policy weekly_schedule_update_own
      on public.weekly_schedule
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
      and tablename = 'weekly_schedule'
      and policyname = 'weekly_schedule_delete_own'
  ) then
    create policy weekly_schedule_delete_own
      on public.weekly_schedule
      for delete
      using (teacher_id = auth.uid());
  end if;
end $$;

notify pgrst, 'reload schema';
