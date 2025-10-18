-- Add new fields to appointments table for Aadhar and Primary Doctor details

-- Add Aadhar number column
ALTER TABLE appointments 
ADD COLUMN IF NOT EXISTS aadhar_number VARCHAR(12);

-- Add Primary Doctor related columns
ALTER TABLE appointments 
ADD COLUMN IF NOT EXISTS primary_doctor_name VARCHAR(255);

ALTER TABLE appointments 
ADD COLUMN IF NOT EXISTS primary_doctor_phone VARCHAR(10);

ALTER TABLE appointments 
ADD COLUMN IF NOT EXISTS primary_doctor_location VARCHAR(255);

-- Add comments for documentation
COMMENT ON COLUMN appointments.aadhar_number IS 'Care Seeker Aadhar number (12 digits, validated with Verhoeff algorithm)';
COMMENT ON COLUMN appointments.primary_doctor_name IS 'Name of care seeker primary/family doctor (optional)';
COMMENT ON COLUMN appointments.primary_doctor_phone IS 'Phone number of primary doctor (optional, 10 digits)';
COMMENT ON COLUMN appointments.primary_doctor_location IS 'Clinic location of primary doctor - area and city (optional)';

-- Create index on aadhar_number for faster lookups
CREATE INDEX IF NOT EXISTS idx_appointments_aadhar ON appointments(aadhar_number) WHERE aadhar_number IS NOT NULL;

-- Add check constraint for aadhar format (12 digits)
ALTER TABLE appointments 
ADD CONSTRAINT chk_aadhar_format CHECK (
  aadhar_number IS NULL OR 
  (LENGTH(aadhar_number) = 12 AND aadhar_number ~ '^[2-9][0-9]{11}$')
);

-- Add check constraint for primary doctor phone format (10 digits)
ALTER TABLE appointments 
ADD CONSTRAINT chk_primary_doctor_phone_format CHECK (
  primary_doctor_phone IS NULL OR 
  (LENGTH(primary_doctor_phone) = 10 AND primary_doctor_phone ~ '^[6-9][0-9]{9}$')
);

-- Update RLS policies to allow these new fields (if RLS is enabled)
-- Care Seekers can insert their own appointments with these fields
-- Care Providers can view all fields
