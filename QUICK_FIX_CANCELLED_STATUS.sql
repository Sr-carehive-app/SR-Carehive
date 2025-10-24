-- ============================================
-- QUICK FIX: Add 'cancelled' to status constraint
-- Run this in Supabase SQL Editor
-- ============================================

-- Drop the old constraint that doesn't include 'cancelled'
ALTER TABLE appointments 
DROP CONSTRAINT IF EXISTS chk_appointment_status;

-- Create new constraint with ALL status values including 'cancelled'
ALTER TABLE appointments
ADD CONSTRAINT chk_appointment_status 
CHECK (status IN (
    'pending',      -- Initial state
    'approved',     -- Nurse approved
    'rejected',     -- Nurse rejected
    'booked',       -- Registration paid
    'amount_set',   -- Total amount set by nurse
    'pre_paid',     -- 50% pre-payment done
    'completed',    -- Final payment done
    'cancelled',    -- Patient cancelled (NEW!)
    'expired'       -- Archived by nurse
));

-- Verify the constraint is updated
SELECT 
    conname AS constraint_name,
    pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'appointments'::regclass
  AND conname = 'chk_appointment_status';

-- You should see 'cancelled' in the list now
