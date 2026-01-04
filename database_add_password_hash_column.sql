-- ============================================
-- ADD PASSWORD_HASH COLUMN FOR PHONE-ONLY USERS
-- Stores hashed password for users who sign up without email
-- ============================================

-- Add password_hash column to patients table (nullable - only for phone-only users)
ALTER TABLE patients
ADD COLUMN IF NOT EXISTS password_hash TEXT;

-- Add comment to explain usage
COMMENT ON COLUMN patients.password_hash IS 'Hashed password for phone-only users (who do not use Supabase auth). NULL for email/OAuth users.';

-- Verify the column was added
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'patients' AND column_name = 'password_hash';
