-- SQL Migration for Updated Patient Registration Schema

-- 1. Update patients table with new fields
ALTER TABLE patients
ADD COLUMN IF NOT EXISTS first_name VARCHAR(100),
ADD COLUMN IF NOT EXISTS middle_name VARCHAR(100),
ADD COLUMN IF NOT EXISTS last_name VARCHAR(100),
ADD COLUMN IF NOT EXISTS country_code VARCHAR(10) DEFAULT '+91',
ADD COLUMN IF NOT EXISTS aadhar_linked_phone VARCHAR(15),
ADD COLUMN IF NOT EXISTS alternative_phone VARCHAR(15),
ADD COLUMN IF NOT EXISTS house_number VARCHAR(50),
ADD COLUMN IF NOT EXISTS street VARCHAR(200),
ADD COLUMN IF NOT EXISTS town VARCHAR(100),
ADD COLUMN IF NOT EXISTS city VARCHAR(100),
ADD COLUMN IF NOT EXISTS state VARCHAR(100),
ADD COLUMN IF NOT EXISTS pincode VARCHAR(10),
ADD COLUMN IF NOT EXISTS phone_verified BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS otp_verified_at TIMESTAMP;

-- 2. Create OTP verification table
CREATE TABLE IF NOT EXISTS otp_verifications (
    id SERIAL PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    phone_number VARCHAR(15) NOT NULL,
    email VARCHAR(255) NOT NULL,
    otp_code VARCHAR(6) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP NOT NULL,
    verified BOOLEAN DEFAULT FALSE,
    verified_at TIMESTAMP,
    attempts INT DEFAULT 0,
    CONSTRAINT unique_active_otp UNIQUE(phone_number, email, verified)
);

-- 3. Create index for faster OTP lookups
CREATE INDEX IF NOT EXISTS idx_otp_phone_email ON otp_verifications(phone_number, email, verified);
CREATE INDEX IF NOT EXISTS idx_otp_expires ON otp_verifications(expires_at);

-- 4. Update name field to be computed from first, middle, last
-- This is optional - you can keep both or use a trigger
UPDATE patients 
SET first_name = SPLIT_PART(name, ' ', 1),
    last_name = SPLIT_PART(name, ' ', -1)
WHERE first_name IS NULL AND name IS NOT NULL;

-- 5. Create function to auto-delete expired OTPs
CREATE OR REPLACE FUNCTION delete_expired_otps()
RETURNS void AS $$
BEGIN
    DELETE FROM otp_verifications 
    WHERE expires_at < NOW() 
    AND verified = FALSE;
END;
$$ LANGUAGE plpgsql;

-- 6. Add RLS policies for OTP table
ALTER TABLE otp_verifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can insert their own OTP"
ON otp_verifications FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view their own OTP"
ON otp_verifications FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own OTP"
ON otp_verifications FOR UPDATE
USING (auth.uid() = user_id);

-- 7. Add comments for documentation
COMMENT ON COLUMN patients.first_name IS 'Patient first name';
COMMENT ON COLUMN patients.middle_name IS 'Patient middle name (optional)';
COMMENT ON COLUMN patients.last_name IS 'Patient last name';
COMMENT ON COLUMN patients.country_code IS 'Phone country code (default +91 for India)';
COMMENT ON COLUMN patients.aadhar_linked_phone IS 'Aadhar card linked phone number (primary, OTP verified)';
COMMENT ON COLUMN patients.alternative_phone IS 'Alternative contact number (optional)';
COMMENT ON COLUMN patients.house_number IS 'House/Flat number';
COMMENT ON COLUMN patients.street IS 'Street name';
COMMENT ON COLUMN patients.town IS 'Town/Locality';
COMMENT ON COLUMN patients.city IS 'City';
COMMENT ON COLUMN patients.state IS 'State';
COMMENT ON COLUMN patients.pincode IS 'Postal code/PIN code';
COMMENT ON COLUMN patients.phone_verified IS 'Whether phone number is verified via OTP';
COMMENT ON COLUMN patients.otp_verified_at IS 'Timestamp when OTP verification completed';
