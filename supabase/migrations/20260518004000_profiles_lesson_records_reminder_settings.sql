create table if not exists public.profiles (
  id uuid primary key,
  full_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.lesson_records (
  id uuid primary key,
  teacher_id uuid not null,
  class_name text not null,
  subject text,
  lesson_title text not null,
  lesson_type text not null,
  lesson_date date not null,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.reminder_settings (
  id uuid primary key,
  teacher_id uuid not null,
  reminder_type text not null,
  is_enabled boolean not null default false,
  minutes_offset integer not null default 10,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists lesson_records_teacher_id_idx
  on public.lesson_records (teacher_id);

create index if not exists reminder_settings_teacher_id_idx
  on public.reminder_settings (teacher_id);

create unique index if not exists reminder_settings_teacher_type_unique_idx
  on public.reminder_settings (teacher_id, reminder_type);

alter table public.profiles enable row level security;
alter table public.lesson_records enable row level security;
alter table public.reminder_settings enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'profiles'
      and policyname = 'profiles_select_own'
  ) then
    create policy profiles_select_own
      on public.profiles for select
      using (id = auth.uid());
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'profiles'
      and policyname = 'profiles_insert_own'
  ) then
    create policy profiles_insert_own
      on public.profiles for insert
      with check (id = auth.uid());
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'profiles'
      and policyname = 'profiles_update_own'
  ) then
    create policy profiles_update_own
      on public.profiles for update
      using (id = auth.uid())
      with check (id = auth.uid());
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'lesson_records'
      and policyname = 'lesson_records_select_own'
  ) then
    create policy lesson_records_select_own
      on public.lesson_records for select
      using (teacher_id = auth.uid());
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'lesson_records'
      and policyname = 'lesson_records_insert_own'
  ) then
    create policy lesson_records_insert_own
      on public.lesson_records for insert
      with check (teacher_id = auth.uid());
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'lesson_records'
      and policyname = 'lesson_records_update_own'
  ) then
    create policy lesson_records_update_own
      on public.lesson_records for update
      using (teacher_id = auth.uid())
      with check (teacher_id = auth.uid());
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'lesson_records'
      and policyname = 'lesson_records_delete_own'
  ) then
    create policy lesson_records_delete_own
      on public.lesson_records for delete
      using (teacher_id = auth.uid());
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'reminder_settings'
      and policyname = 'reminder_settings_select_own'
  ) then
    create policy reminder_settings_select_own
      on public.reminder_settings for select
      using (teacher_id = auth.uid());
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'reminder_settings'
      and policyname = 'reminder_settings_insert_own'
  ) then
    create policy reminder_settings_insert_own
      on public.reminder_settings for insert
      with check (teacher_id = auth.uid());
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'reminder_settings'
      and policyname = 'reminder_settings_update_own'
  ) then
    create policy reminder_settings_update_own
      on public.reminder_settings for update
      using (teacher_id = auth.uid())
      with check (teacher_id = auth.uid());
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'reminder_settings'
      and policyname = 'reminder_settings_delete_own'
  ) then
    create policy reminder_settings_delete_own
      on public.reminder_settings for delete
      using (teacher_id = auth.uid());
  end if;
end $$;

notify pgrst, 'reload schema';
