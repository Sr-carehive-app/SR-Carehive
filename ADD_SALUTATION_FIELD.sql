-- SQL Query to add salutation field to patients table in Supabase
-- Execute this query in your Supabase SQL Editor

-- Add salutation column to patients table
ALTER TABLE patients 
ADD COLUMN IF NOT EXISTS salutation VARCHAR(20);

-- Add a comment to the column for documentation
COMMENT ON COLUMN patients.salutation IS 'Salutation prefix for patient name (Mr., Mrs., Ms., Dr., Prof., Master, Miss)';

-- Optional: Add a check constraint to ensure only valid salutations are stored
ALTER TABLE patients 
ADD CONSTRAINT valid_salutation 
CHECK (salutation IS NULL OR salutation IN ('Mr.', 'Mrs.', 'Ms.', 'Dr.', 'Prof.', 'Master', 'Miss'));

-- Verify the column was added successfully
SELECT column_name, data_type, character_maximum_length 
FROM information_schema.columns 
WHERE table_name = 'patients' AND column_name = 'salutation';
