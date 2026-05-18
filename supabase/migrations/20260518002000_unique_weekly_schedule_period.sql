do $$
begin
  if exists (
    select 1
    from public.weekly_schedule
    group by teacher_id, day_of_week, period_number
    having count(*) > 1
  ) then
    raise exception
      'Cannot add weekly_schedule unique period constraint: duplicate teacher_id/day_of_week/period_number rows exist.';
  end if;
end $$;

create unique index if not exists weekly_schedule_teacher_day_period_unique_idx
  on public.weekly_schedule (teacher_id, day_of_week, period_number);

notify pgrst, 'reload schema';
