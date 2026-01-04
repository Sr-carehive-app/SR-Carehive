-- Migration: Make email field optional in healthcare_providers table
-- This allows providers to register without email (phone-only registration)

-- Step 1: Drop the existing NOT NULL constraint on email
ALTER TABLE healthcare_providers 
ALTER COLUMN email DROP NOT NULL;

-- Step 2: Drop the UNIQUE constraint on email to allow multiple NULLs
-- First, find the constraint name
-- Run this to find the constraint name: 
-- SELECT conname FROM pg_constraint WHERE conrelid = 'healthcare_providers'::regclass AND contype = 'u';

-- Drop the unique constraint (replace 'healthcare_providers_email_key' with actual constraint name if different)
ALTER TABLE healthcare_providers 
DROP CONSTRAINT IF EXISTS healthcare_providers_email_key;

-- Step 3: Modify the email validation constraint to allow NULL
ALTER TABLE healthcare_providers 
DROP CONSTRAINT IF EXISTS valid_email;

-- Add new constraint that allows NULL or valid email format
ALTER TABLE healthcare_providers 
ADD CONSTRAINT valid_email CHECK (
    email IS NULL OR 
    email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
);

-- Step 4: Create a partial unique index to allow multiple NULLs but enforce uniqueness for non-NULL emails
CREATE UNIQUE INDEX IF NOT EXISTS idx_healthcare_providers_email_unique 
ON healthcare_providers(email) 
WHERE email IS NOT NULL;

-- Drop the old full index if it exists
DROP INDEX IF EXISTS idx_healthcare_providers_email;

-- Verification query - Check if email can be NULL now
-- SELECT column_name, is_nullable, data_type 
-- FROM information_schema.columns 
-- WHERE table_name = 'healthcare_providers' AND column_name = 'email';

-- Comment
COMMENT ON COLUMN healthcare_providers.email IS 'Email address (optional) - unique when provided, NULL allowed for phone-only registration';
