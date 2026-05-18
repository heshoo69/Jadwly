create table if not exists public.teacher_classes (
  id uuid primary key,
  teacher_id uuid not null,
  class_name text not null,
  subject text not null,
  room text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists teacher_classes_teacher_id_idx
  on public.teacher_classes (teacher_id);

create unique index if not exists teacher_classes_teacher_name_unique_idx
  on public.teacher_classes (teacher_id, class_name);

alter table public.teacher_classes enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'teacher_classes'
      and policyname = 'teacher_classes_select_own'
  ) then
    create policy teacher_classes_select_own
      on public.teacher_classes
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
      and tablename = 'teacher_classes'
      and policyname = 'teacher_classes_insert_own'
  ) then
    create policy teacher_classes_insert_own
      on public.teacher_classes
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
      and tablename = 'teacher_classes'
      and policyname = 'teacher_classes_update_own'
  ) then
    create policy teacher_classes_update_own
      on public.teacher_classes
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
      and tablename = 'teacher_classes'
      and policyname = 'teacher_classes_delete_own'
  ) then
    create policy teacher_classes_delete_own
      on public.teacher_classes
      for delete
      using (teacher_id = auth.uid());
  end if;
end $$;

notify pgrst, 'reload schema';
