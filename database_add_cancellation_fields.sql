-- Add cancellation fields to appointments table
-- Run this query in your Supabase SQL Editor

-- Add cancellation_reason column (TEXT, nullable)
ALTER TABLE appointments 
ADD COLUMN IF NOT EXISTS cancellation_reason TEXT;

-- Add cancelled_at column (TIMESTAMP, nullable)
ALTER TABLE appointments 
ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMP WITH TIME ZONE;

-- Add comment for documentation
COMMENT ON COLUMN appointments.cancellation_reason IS 'Optional reason provided by patient when cancelling appointment';
COMMENT ON COLUMN appointments.cancelled_at IS 'Timestamp when appointment was cancelled by patient';

-- FIX: Update status constraint to include 'cancelled'
-- Drop old constraint if exists
ALTER TABLE appointments 
DROP CONSTRAINT IF EXISTS chk_appointment_status;

-- Create new constraint with 'cancelled' included
ALTER TABLE appointments
ADD CONSTRAINT chk_appointment_status 
CHECK (status IN (
    'pending', 'approved', 'rejected', 'booked', 
    'amount_set', 'pre_paid', 'completed', 'cancelled', 'expired'
));

-- Create index for better query performance on cancelled appointments
CREATE INDEX IF NOT EXISTS idx_appointments_cancelled 
ON appointments(cancelled_at) 
WHERE cancelled_at IS NOT NULL;

-- Create index for status filtering (if not exists)
CREATE INDEX IF NOT EXISTS idx_appointments_status 
ON appointments(status);

-- Verify the columns were added
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'appointments' 
AND column_name IN ('cancellation_reason', 'cancelled_at')
ORDER BY column_name;

-- Sample query to check cancelled appointments
-- SELECT id, full_name, status, cancellation_reason, cancelled_at 
-- FROM appointments 
-- WHERE status = 'cancelled' 
-- ORDER BY cancelled_at DESC;
