-- ============================================
-- FIX STATUS CONSTRAINT FOR CANCELLED STATUS
-- ============================================

-- First, let's check what constraint exists
SELECT 
    conname AS constraint_name,
    pg_get_constraintdef(oid) AS constraint_definition
FROM pg_constraint
WHERE conrelid = 'appointments'::regclass
  AND conname LIKE '%status%';

-- SOLUTION 1: If status is a CHECK constraint, drop and recreate it
-- Run this after checking the output above:

-- Step 1: Drop the old constraint
ALTER TABLE appointments 
DROP CONSTRAINT IF EXISTS chk_appointment_status;

-- Step 2: Create new constraint with 'cancelled' included
ALTER TABLE appointments
ADD CONSTRAINT chk_appointment_status 
CHECK (status IN (
    'pending',
    'approved', 
    'rejected',
    'booked',
    'amount_set',
    'pre_paid',
    'completed',
    'cancelled',
    'expired'
));

-- SOLUTION 2: If status is an ENUM type, add the value
-- Check if status is enum:
SELECT 
    t.typname AS enum_name,
    e.enumlabel AS enum_value
FROM pg_type t
JOIN pg_enum e ON t.oid = e.enumtypid
WHERE t.typname LIKE '%status%'
ORDER BY e.enumsortorder;

-- If status is ENUM and 'cancelled' is missing, add it:
-- ALTER TYPE appointment_status ADD VALUE IF NOT EXISTS 'cancelled';

-- ============================================
-- VERIFICATION
-- ============================================

-- Test if 'cancelled' is now allowed:
-- This should NOT error:
/*
UPDATE appointments 
SET status = 'cancelled'
WHERE id = (SELECT id FROM appointments LIMIT 1)
RETURNING id, status;

-- Then rollback if you don't want to actually cancel:
ROLLBACK;
*/

-- Check current constraint:
SELECT 
    conname,
    pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid = 'appointments'::regclass
  AND conname = 'chk_appointment_status';
