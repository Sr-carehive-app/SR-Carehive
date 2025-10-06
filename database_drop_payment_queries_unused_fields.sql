-- Optional cleanup: drop unused columns from payment_queries
-- Run this ONLY if you are sure you don't need the data in these columns.
alter table if exists public.payment_queries drop column if exists method;
alter table if exists public.payment_queries drop column if exists refund_type;
alter table if exists public.payment_queries drop column if exists expected_refund_amount;
alter table if exists public.payment_queries drop column if exists reference_id;
alter table if exists public.payment_queries drop column if exists screenshot_url;
