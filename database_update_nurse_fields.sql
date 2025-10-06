-- Adds nurse assignment fields and admin workflow timestamps to appointments table
-- Safe to run multiple times: checks for column existence when supported by Supabase (Postgres 15)

alter table if exists appointments
  add column if not exists nurse_name text,
  add column if not exists nurse_phone text,
  add column if not exists nurse_branch text,
  add column if not exists nurse_comments text,
  add column if not exists nurse_available boolean,
  add column if not exists approved_at timestamptz,
  add column if not exists rejected_at timestamptz,
  add column if not exists rejection_reason text;

comment on column appointments.nurse_available is 'Whether nurse is available for the requested day/time';
comment on column appointments.nurse_branch is 'Assigned branch/office handling the appointment';

create index if not exists idx_appointments_status_created on appointments(status, created_at desc);