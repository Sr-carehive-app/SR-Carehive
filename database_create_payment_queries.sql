-- Creates table to store refund/payment issue queries
create table if not exists public.payment_queries (
  id uuid primary key default gen_random_uuid(),
  payment_id text not null,
  name text not null,
  email text not null,
  mobile text,
  amount numeric,
  complaint text,
  reason text,
  transaction_date date,
  created_at timestamptz not null default now()
);

create index if not exists idx_payment_queries_payment_id on public.payment_queries(payment_id);
