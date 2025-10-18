-- ============================================
-- UPDATED BUSINESS MODEL: 3-TIER PAYMENT SYSTEM
-- ============================================
-- Flow: pending → approved → booked (₹100) → amount_set → pre_paid → completed
-- Payments: Registration (₹100) → Pre-visit (50%) → Post-visit (50%)

-- Add new columns for 3-tier payment system
ALTER TABLE appointments 
ADD COLUMN IF NOT EXISTS registration_payment_id VARCHAR(255),
ADD COLUMN IF NOT EXISTS registration_receipt_id VARCHAR(255),
ADD COLUMN IF NOT EXISTS registration_paid BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS registration_paid_at TIMESTAMP,

ADD COLUMN IF NOT EXISTS total_amount DECIMAL(10,2),
ADD COLUMN IF NOT EXISTS nurse_remarks TEXT,

ADD COLUMN IF NOT EXISTS pre_payment_id VARCHAR(255),
ADD COLUMN IF NOT EXISTS pre_receipt_id VARCHAR(255),
ADD COLUMN IF NOT EXISTS pre_paid BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS pre_paid_at TIMESTAMP,

ADD COLUMN IF NOT EXISTS final_payment_id VARCHAR(255),
ADD COLUMN IF NOT EXISTS final_receipt_id VARCHAR(255),
ADD COLUMN IF NOT EXISTS final_paid BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS final_paid_at TIMESTAMP;

-- Add comments for documentation
COMMENT ON COLUMN appointments.registration_payment_id IS 'Razorpay payment ID for ₹100 registration fee';
COMMENT ON COLUMN appointments.registration_receipt_id IS 'Razorpay receipt ID for registration payment';
COMMENT ON COLUMN appointments.registration_paid IS 'Whether ₹100 registration fee is paid';
COMMENT ON COLUMN appointments.registration_paid_at IS 'Timestamp when registration payment was completed';

COMMENT ON COLUMN appointments.total_amount IS 'Total service amount set by nurse after consultation (e.g., ₹1000)';
COMMENT ON COLUMN appointments.nurse_remarks IS 'Nurse comments explaining the total amount breakdown';

COMMENT ON COLUMN appointments.pre_payment_id IS 'Razorpay payment ID for pre-visit payment (50% of total)';
COMMENT ON COLUMN appointments.pre_receipt_id IS 'Razorpay receipt ID for pre-visit payment';
COMMENT ON COLUMN appointments.pre_paid IS 'Whether pre-visit payment (50%) is completed';
COMMENT ON COLUMN appointments.pre_paid_at IS 'Timestamp when pre-visit payment was completed';

COMMENT ON COLUMN appointments.final_payment_id IS 'Razorpay payment ID for final payment (remaining 50%)';
COMMENT ON COLUMN appointments.final_receipt_id IS 'Razorpay receipt ID for final payment';
COMMENT ON COLUMN appointments.final_paid IS 'Whether final payment (50%) is completed';
COMMENT ON COLUMN appointments.final_paid_at IS 'Timestamp when final payment was completed';

-- Create indexes for faster payment queries
CREATE INDEX IF NOT EXISTS idx_appointments_registration_paid ON appointments(registration_paid) WHERE registration_paid = TRUE;
CREATE INDEX IF NOT EXISTS idx_appointments_pre_paid ON appointments(pre_paid) WHERE pre_paid = TRUE;
CREATE INDEX IF NOT EXISTS idx_appointments_final_paid ON appointments(final_paid) WHERE final_paid = TRUE;
CREATE INDEX IF NOT EXISTS idx_appointments_payment_ids ON appointments(registration_payment_id, pre_payment_id, final_payment_id);

-- Update status column to support new statuses
-- Possible values: pending, approved, rejected, booked, amount_set, pre_paid, completed
ALTER TABLE appointments 
ALTER COLUMN status TYPE VARCHAR(50);

-- Add check constraint for valid statuses
ALTER TABLE appointments 
DROP CONSTRAINT IF EXISTS chk_appointment_status;

ALTER TABLE appointments 
ADD CONSTRAINT chk_appointment_status CHECK (
  status IN ('pending', 'approved', 'rejected', 'booked', 'amount_set', 'pre_paid', 'completed', 'cancelled')
);

-- Update RLS policies to allow payment updates
-- Care Seekers can update their own payment information
-- Care Providers can update total_amount and nurse_remarks

-- Create a view for payment summary
CREATE OR REPLACE VIEW appointment_payment_summary AS
SELECT 
  id,
  full_name,
  phone,
  patient_email,
  status,
  date,
  time,
  -- Registration payment
  registration_paid,
  registration_payment_id,
  registration_paid_at,
  -- Total amount
  total_amount,
  nurse_remarks,
  -- Pre-payment
  pre_paid,
  pre_payment_id,
  pre_paid_at,
  CASE WHEN total_amount IS NOT NULL THEN total_amount / 2 ELSE NULL END as pre_amount,
  -- Final payment
  final_paid,
  final_payment_id,
  final_paid_at,
  CASE WHEN total_amount IS NOT NULL THEN total_amount / 2 ELSE NULL END as final_amount,
  -- Total paid
  CASE 
    WHEN final_paid THEN 100 + total_amount
    WHEN pre_paid THEN 100 + (total_amount / 2)
    WHEN registration_paid THEN 100
    ELSE 0
  END as total_paid,
  -- Payment progress
  CASE 
    WHEN final_paid THEN 'Fully Paid'
    WHEN pre_paid THEN 'Pre-Payment Done'
    WHEN registration_paid THEN 'Registration Done'
    ELSE 'Not Paid'
  END as payment_status
FROM appointments;

COMMENT ON VIEW appointment_payment_summary IS 'Summary view of all appointment payments including registration, pre-payment, and final payment';

-- Create function to calculate pending payment amount
CREATE OR REPLACE FUNCTION get_pending_payment(appointment_id INTEGER)
RETURNS DECIMAL(10,2) AS $$
DECLARE
  v_total_amount DECIMAL(10,2);
  v_registration_paid BOOLEAN;
  v_pre_paid BOOLEAN;
  v_final_paid BOOLEAN;
  v_pending DECIMAL(10,2);
BEGIN
  SELECT 
    COALESCE(total_amount, 0),
    COALESCE(registration_paid, FALSE),
    COALESCE(pre_paid, FALSE),
    COALESCE(final_paid, FALSE)
  INTO 
    v_total_amount,
    v_registration_paid,
    v_pre_paid,
    v_final_paid
  FROM appointments 
  WHERE id = appointment_id;
  
  v_pending := 0;
  
  -- Add registration if not paid
  IF NOT v_registration_paid THEN
    v_pending := v_pending + 100;
  END IF;
  
  -- Add pre-payment if not paid
  IF v_total_amount > 0 AND NOT v_pre_paid THEN
    v_pending := v_pending + (v_total_amount / 2);
  END IF;
  
  -- Add final payment if not paid
  IF v_total_amount > 0 AND NOT v_final_paid THEN
    v_pending := v_pending + (v_total_amount / 2);
  END IF;
  
  RETURN v_pending;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_pending_payment IS 'Calculate total pending payment amount for an appointment';
