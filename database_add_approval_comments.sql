-- Add approval_comments column to healthcare_providers table
-- This column stores optional comments added by admin when approving a provider

ALTER TABLE healthcare_providers
ADD COLUMN IF NOT EXISTS approval_comments TEXT;

-- Add comment to the column
COMMENT ON COLUMN healthcare_providers.approval_comments IS 'Optional comments or message from admin when approving the application';
