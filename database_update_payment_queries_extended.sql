-- Extends payment_queries with trimmed fields used by the Refund form
alter table if exists public.payment_queries add column if not exists reason text;
alter table if exists public.payment_queries add column if not exists transaction_date date;
