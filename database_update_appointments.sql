-- Add missing columns to appointments table for enhanced scheduling
ALTER TABLE appointments 
ADD COLUMN IF NOT EXISTS phone TEXT,
ADD COLUMN IF NOT EXISTS address TEXT,
ADD COLUMN IF NOT EXISTS emergency_contact TEXT,
ADD COLUMN IF NOT EXISTS patient_type TEXT DEFAULT 'Yourself',
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'pending',
ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Add comments for better documentation
COMMENT ON COLUMN appointments.phone IS 'Patient phone number';
COMMENT ON COLUMN appointments.address IS 'Patient address';
COMMENT ON COLUMN appointments.emergency_contact IS 'Emergency contact number';
COMMENT ON COLUMN appointments.patient_type IS 'Type of patient: Yourself or Another Person';
COMMENT ON COLUMN appointments.status IS 'Appointment status: pending, confirmed, completed, cancelled';
COMMENT ON COLUMN appointments.created_at IS 'Timestamp when appointment was created';

-- Create index for better query performance
CREATE INDEX IF NOT EXISTS idx_appointments_patient_id ON appointments(patient_id);
CREATE INDEX IF NOT EXISTS idx_appointments_date ON appointments(date);
CREATE INDEX IF NOT EXISTS idx_appointments_status ON appointments(status); 