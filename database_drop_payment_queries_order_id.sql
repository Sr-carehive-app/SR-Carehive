-- Optional cleanup: drop order_id column and its index if they were added earlier
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM   pg_indexes
    WHERE  schemaname = 'public'
    AND    indexname = 'idx_payment_queries_order_id'
  ) THEN
    EXECUTE 'DROP INDEX IF EXISTS public.idx_payment_queries_order_id';
  END IF;
END $$;

ALTER TABLE IF EXISTS public.payment_queries DROP COLUMN IF EXISTS order_id;
