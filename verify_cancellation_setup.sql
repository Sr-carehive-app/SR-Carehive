-- ============================================
-- VERIFY CANCELLATION SETUP
-- Run this to check if everything is ready
-- ============================================

-- 1. Check if columns exist
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'appointments' 
AND column_name IN ('cancellation_reason', 'cancelled_at', 'status')
ORDER BY column_name;

-- Expected output:
-- cancellation_reason | text | YES | NULL
-- cancelled_at | timestamp with time zone | YES | NULL
-- status | text | YES | 'pending'

-- 2. Test if you can update a row (replace 'test-id' with real appointment ID)
/*
UPDATE appointments 
SET 
    status = 'cancelled',
    cancellation_reason = 'Test cancellation',
    cancelled_at = NOW()
WHERE id = 'your-appointment-id-here'
RETURNING id, status, cancellation_reason, cancelled_at;
*/

-- 3. Check RLS policies for appointments table
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'appointments';

-- 4. If no policies exist or if update is not allowed, add this policy:
/*
-- Allow authenticated users to update their own appointments
CREATE POLICY "Users can update their own appointments"
ON appointments
FOR UPDATE
TO authenticated
USING (
    auth.uid() IN (
        SELECT user_id FROM patients WHERE id = appointments.patient_id
    )
)
WITH CHECK (
    auth.uid() IN (
        SELECT user_id FROM patients WHERE id = appointments.patient_id
    )
);
*/

-- 5. Check if user can read their appointments
SELECT COUNT(*) as total_appointments
FROM appointments;

-- 6. Verify status enum values (if status is an enum type)
-- If this query returns results, status is an enum
SELECT enumlabel 
FROM pg_enum e
JOIN pg_type t ON e.enumtypid = t.oid
WHERE t.typname = 'appointment_status';

-- If status is enum and 'cancelled' is not in the list, run:
/*
ALTER TYPE appointment_status ADD VALUE IF NOT EXISTS 'cancelled';
*/
