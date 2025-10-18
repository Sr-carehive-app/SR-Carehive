-- ============================================
-- ADD NURSE CONSULTATION/DOCTOR RECOMMENDATION FIELDS
-- ============================================
-- These fields will store doctor consultation details provided by nurse after visit
-- This information will be shown to patient and sent via email

-- Add consultation/doctor recommendation columns to appointments table
ALTER TABLE appointments 
ADD COLUMN IF NOT EXISTS consulted_doctor_name VARCHAR(255),
ADD COLUMN IF NOT EXISTS consulted_doctor_phone VARCHAR(15),
ADD COLUMN IF NOT EXISTS consulted_doctor_specialization VARCHAR(255),
ADD COLUMN IF NOT EXISTS consulted_doctor_clinic_address TEXT,
ADD COLUMN IF NOT EXISTS post_visit_remarks TEXT,
ADD COLUMN IF NOT EXISTS visit_completed_at TIMESTAMP;

-- Add comments for documentation
COMMENT ON COLUMN appointments.consulted_doctor_name IS 'Doctor name recommended by nurse after visit (for further consultation)';
COMMENT ON COLUMN appointments.consulted_doctor_phone IS 'Contact number of recommended doctor';
COMMENT ON COLUMN appointments.consulted_doctor_specialization IS 'Specialization/branch of recommended doctor (e.g., Cardiologist, Neurologist)';
COMMENT ON COLUMN appointments.consulted_doctor_clinic_address IS 'Full clinic address of recommended doctor';
COMMENT ON COLUMN appointments.post_visit_remarks IS 'Nurse remarks after completing visit - diagnosis, observations, recommendations';
COMMENT ON COLUMN appointments.visit_completed_at IS 'Timestamp when nurse marked visit as completed';

-- Add index for quick filtering
CREATE INDEX IF NOT EXISTS idx_appointments_visit_completed ON appointments(visit_completed_at) WHERE visit_completed_at IS NOT NULL;

-- ============================================
-- UPDATE appointments_history TABLE
-- ============================================
-- Add all new fields to history table to match main appointments table

-- Add new fields from appointments table
ALTER TABLE appointments_history 
-- Aadhar and Primary Doctor fields
ADD COLUMN IF NOT EXISTS aadhar_number VARCHAR(12),
ADD COLUMN IF NOT EXISTS primary_doctor_name VARCHAR(255),
ADD COLUMN IF NOT EXISTS primary_doctor_phone VARCHAR(10),
ADD COLUMN IF NOT EXISTS primary_doctor_location VARCHAR(255),

-- Address and Emergency Contact
ADD COLUMN IF NOT EXISTS address TEXT,
ADD COLUMN IF NOT EXISTS emergency_contact VARCHAR(15),
ADD COLUMN IF NOT EXISTS problem TEXT,

-- 3-Tier Payment System fields
ADD COLUMN IF NOT EXISTS registration_payment_id VARCHAR(255),
ADD COLUMN IF NOT EXISTS registration_receipt_id VARCHAR(255),
ADD COLUMN IF NOT EXISTS registration_paid BOOLEAN,
ADD COLUMN IF NOT EXISTS registration_paid_at TIMESTAMP,

ADD COLUMN IF NOT EXISTS total_amount DECIMAL(10,2),
ADD COLUMN IF NOT EXISTS nurse_remarks TEXT,

ADD COLUMN IF NOT EXISTS pre_payment_id VARCHAR(255),
ADD COLUMN IF NOT EXISTS pre_receipt_id VARCHAR(255),
ADD COLUMN IF NOT EXISTS pre_paid BOOLEAN,
ADD COLUMN IF NOT EXISTS pre_paid_at TIMESTAMP,

ADD COLUMN IF NOT EXISTS final_payment_id VARCHAR(255),
ADD COLUMN IF NOT EXISTS final_receipt_id VARCHAR(255),
ADD COLUMN IF NOT EXISTS final_paid BOOLEAN,
ADD COLUMN IF NOT EXISTS final_paid_at TIMESTAMP,

-- NEW: Consultation/Doctor Recommendation fields
ADD COLUMN IF NOT EXISTS consulted_doctor_name VARCHAR(255),
ADD COLUMN IF NOT EXISTS consulted_doctor_phone VARCHAR(15),
ADD COLUMN IF NOT EXISTS consulted_doctor_specialization VARCHAR(255),
ADD COLUMN IF NOT EXISTS consulted_doctor_clinic_address TEXT,
ADD COLUMN IF NOT EXISTS post_visit_remarks TEXT,
ADD COLUMN IF NOT EXISTS visit_completed_at TIMESTAMP;

-- Add comments for history table
COMMENT ON TABLE appointments_history IS 'Archive of completed/past appointments with full details for audit trail';
COMMENT ON COLUMN appointments_history.consulted_doctor_name IS 'Doctor recommended by nurse (archived)';
COMMENT ON COLUMN appointments_history.consulted_doctor_specialization IS 'Doctor specialization/branch (archived)';
COMMENT ON COLUMN appointments_history.post_visit_remarks IS 'Nurse post-visit remarks (archived)';

-- Create indexes for history table
CREATE INDEX IF NOT EXISTS idx_appointments_history_patient_email ON appointments_history(patient_email);
CREATE INDEX IF NOT EXISTS idx_appointments_history_archived_at ON appointments_history(archived_at);
CREATE INDEX IF NOT EXISTS idx_appointments_history_status ON appointments_history(status);

-- ============================================
-- VERIFICATION QUERIES
-- ============================================

-- 1. Check appointments table structure
SELECT column_name, data_type, character_maximum_length, is_nullable
FROM information_schema.columns
WHERE table_name = 'appointments' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- 2. Check appointments_history table structure
SELECT column_name, data_type, character_maximum_length, is_nullable
FROM information_schema.columns
WHERE table_name = 'appointments_history' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- 3. Verify new columns exist
SELECT 
  'appointments' as table_name,
  CASE WHEN EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'appointments' AND column_name = 'consulted_doctor_name'
  ) THEN '✅ consulted_doctor_name' ELSE '❌ consulted_doctor_name MISSING' END as status
UNION ALL
SELECT 
  'appointments',
  CASE WHEN EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'appointments' AND column_name = 'post_visit_remarks'
  ) THEN '✅ post_visit_remarks' ELSE '❌ post_visit_remarks MISSING' END
UNION ALL
SELECT 
  'appointments_history',
  CASE WHEN EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'appointments_history' AND column_name = 'consulted_doctor_name'
  ) THEN '✅ consulted_doctor_name' ELSE '❌ consulted_doctor_name MISSING' END
UNION ALL
SELECT 
  'appointments_history',
  CASE WHEN EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'appointments_history' AND column_name = 'aadhar_number'
  ) THEN '✅ aadhar_number' ELSE '❌ aadhar_number MISSING' END;

-- ============================================
-- NOTES
-- ============================================
/*
NEW WORKFLOW AFTER THIS UPDATE:

1. Patient schedules appointment → Admin/nurse emails sent ✅

2. Nurse approves and assigns → Patient notified ✅

3. Patient pays 50% pre-visit → Admin/nurse emails sent ✅

4. Nurse completes visit → Nurse fills form:
   - Post-visit remarks (observations, diagnosis)
   - Recommended doctor details (if needed):
     * Doctor name
     * Phone number
     * Specialization (e.g., Cardiologist)
     * Clinic address
   
5. System sends email to patient with:
   - Nurse's post-visit remarks
   - Recommended doctor details (if provided)
   - Remaining payment amount
   - Payment link

6. Patient pays final 50% → Service complete ✅
   - Admin/nurse emails sent with full details ✅

7. After expiry → Appointment moves to History section
   - History section now shows ALL fields including:
     * New patient fields (Aadhar, primary doctor)
     * Payment details (all 3 tiers)
     * Consultation details (recommended doctor)
     * Post-visit remarks

HISTORY SECTION:
- Now fully updated with ALL fields
- Shows complete appointment lifecycle
- Includes payment tracking
- Includes consultation recommendations
- Maintains audit trail
*/
