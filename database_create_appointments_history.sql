-- Creates appointments_history table to archive past appointments while keeping core fields for auditing.
-- Run this after ensuring main appointments table exists.
create table if not exists public.appointments_history (
    id bigserial primary key,
    -- Match appointments.id (uuid) so archival insert works
    original_appointment_id uuid not null,
    full_name text,
    patient_email text,
    phone text,
    gender text,
    age int,
    patient_type text,
    -- Keep as text to avoid casting issues if source column is text
    date text,
    time text,
    duration_hours numeric,
    amount_rupees numeric,
    status text,
    order_id text,
    payment_id text,
    nurse_name text,
    nurse_phone text,
    nurse_branch text,
    nurse_comments text,
    nurse_available boolean,
    rejection_reason text,
    created_at timestamptz,
    approved_at timestamptz,
    rejected_at timestamptz,
    archived_at timestamptz default now()
);

create unique index if not exists idx_appointments_history_original_id on public.appointments_history(original_appointment_id);
create index if not exists idx_appointments_history_date on public.appointments_history(date);
