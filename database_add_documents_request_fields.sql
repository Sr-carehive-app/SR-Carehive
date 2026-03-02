-- Add document request tracking fields to healthcare_providers table
-- This enables two-stage approval process: 
-- Stage 1: Request additional documents via Google Form
-- Stage 2: Final approval after document verification

-- Add documents_requested flag
ALTER TABLE healthcare_providers
ADD COLUMN IF NOT EXISTS documents_requested BOOLEAN DEFAULT false;

-- Add timestamp for when documents were requested
ALTER TABLE healthcare_providers
ADD COLUMN IF NOT EXISTS documents_requested_at TIMESTAMP WITH TIME ZONE;

-- Add admin comments for document request (optional)
ALTER TABLE healthcare_providers
ADD COLUMN IF NOT EXISTS documents_request_comments TEXT;

-- Add admin comments for final approval (optional, separate from document request comments)
ALTER TABLE healthcare_providers
ADD COLUMN IF NOT EXISTS final_approval_comments TEXT;

-- Add column comments for documentation
COMMENT ON COLUMN healthcare_providers.documents_requested IS 'Indicates if admin has sent document request email with Google Form link';
COMMENT ON COLUMN healthcare_providers.documents_requested_at IS 'Timestamp when admin requested additional documents';
COMMENT ON COLUMN healthcare_providers.documents_request_comments IS 'Optional admin comments when requesting additional documents';
COMMENT ON COLUMN healthcare_providers.final_approval_comments IS 'Optional admin comments when giving final approval';

-- Create index for faster queries on documents_requested status
CREATE INDEX IF NOT EXISTS idx_healthcare_providers_documents_requested 
ON healthcare_providers(documents_requested) 
WHERE documents_requested = true;
