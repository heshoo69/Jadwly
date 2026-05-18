-- The app writes to the existing weekly_schedule columns:
-- id, teacher_id, day_of_week, period_number, start_time, end_time,
-- class_name, subject, room, notes, is_active, created_at, updated_at.
-- Do not add class_id or room_number unless the app schema is changed.

create index if not exists weekly_schedule_teacher_id_idx
  on public.weekly_schedule (teacher_id);

notify pgrst, 'reload schema';
