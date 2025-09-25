-- Add missing columns to appointments table for enhanced scheduling
ALTER TABLE appointments 
ADD COLUMN IF NOT EXISTS phone TEXT,
ADD COLUMN IF NOT EXISTS address TEXT,
ADD COLUMN IF NOT EXISTS emergency_contact TEXT,
ADD COLUMN IF NOT EXISTS patient_type TEXT DEFAULT 'Yourself',
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'pending',
ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS duration_hours INTEGER,
ADD COLUMN IF NOT EXISTS amount_rupees NUMERIC(10,2),
ADD COLUMN IF NOT EXISTS order_id TEXT,
ADD COLUMN IF NOT EXISTS payment_id TEXT;

-- Add comments for better documentation
COMMENT ON COLUMN appointments.phone IS 'Patient phone number';
COMMENT ON COLUMN appointments.address IS 'Patient address';
COMMENT ON COLUMN appointments.emergency_contact IS 'Emergency contact number';
COMMENT ON COLUMN appointments.patient_type IS 'Type of patient: Yourself or Another Person';
COMMENT ON COLUMN appointments.status IS 'Appointment status: pending, confirmed, completed, cancelled';
COMMENT ON COLUMN appointments.created_at IS 'Timestamp when appointment was created';
COMMENT ON COLUMN appointments.duration_hours IS 'Requested service duration in hours (1, 2, 4, 8, 12)';
COMMENT ON COLUMN appointments.amount_rupees IS 'Charged amount in INR (rupees)';
COMMENT ON COLUMN appointments.order_id IS 'Razorpay order id associated with this appointment';
COMMENT ON COLUMN appointments.payment_id IS 'Razorpay payment id after successful capture';

-- Create index for better query performance
CREATE INDEX IF NOT EXISTS idx_appointments_patient_id ON appointments(patient_id);
CREATE INDEX IF NOT EXISTS idx_appointments_date ON appointments(date);
CREATE INDEX IF NOT EXISTS idx_appointments_status ON appointments(status);
CREATE INDEX IF NOT EXISTS idx_appointments_order_id ON appointments(order_id);
CREATE INDEX IF NOT EXISTS idx_appointments_payment_id ON appointments(payment_id); 