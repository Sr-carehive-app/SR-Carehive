-- FIX FOR HEALTHCARE PROVIDERS DATA NOT SHOWING IN UI
-- Issue: Database has data but UI shows 0 pending applications
-- Root Cause: Missing or incorrect RLS (Row Level Security) policies

-- Step 1: Check current RLS status
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE tablename = 'healthcare_providers';

-- Step 2: List current policies
SELECT * FROM pg_policies WHERE tablename = 'healthcare_providers';

-- Step 3: Disable RLS temporarily to test (ONLY FOR TESTING)
-- ALTER TABLE healthcare_providers DISABLE ROW LEVEL SECURITY;

-- Step 4: PROPER FIX - Set correct RLS policies

-- Enable RLS
ALTER TABLE healthcare_providers ENABLE ROW LEVEL SECURITY;

-- Drop all existing policies
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON healthcare_providers;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON healthcare_providers;
DROP POLICY IF EXISTS "Enable update for authenticated users" ON healthcare_providers;
DROP POLICY IF EXISTS "Allow public read access" ON healthcare_providers;
DROP POLICY IF EXISTS "Allow public insert" ON healthcare_providers;
DROP POLICY IF EXISTS "Allow users to read own data" ON healthcare_providers;
DROP POLICY IF EXISTS "Allow service role full access" ON healthcare_providers;
DROP POLICY IF EXISTS "Allow authenticated read all" ON healthcare_providers;
DROP POLICY IF EXISTS "Allow authenticated update all" ON healthcare_providers;

-- Policy 1: Allow public INSERT (for new provider registration)
CREATE POLICY "healthcare_providers_public_insert"
ON healthcare_providers
FOR INSERT
TO public
WITH CHECK (true);

-- Policy 2: Allow public SELECT (so admin dashboard can read without auth)
-- This is needed because your frontend uses anon key, not authenticated users
CREATE POLICY "healthcare_providers_public_select"
ON healthcare_providers
FOR SELECT
TO public
USING (true);

-- Policy 3: Allow public UPDATE (for admin operations)
CREATE POLICY "healthcare_providers_public_update"
ON healthcare_providers
FOR UPDATE
TO public
USING (true)
WITH CHECK (true);

-- Policy 4: Allow service role FULL access (for backend operations)
CREATE POLICY "healthcare_providers_service_role_all"
ON healthcare_providers
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Step 5: Verify policies are created
SELECT * FROM pg_policies WHERE tablename = 'healthcare_providers';

-- Step 6: Test query (should return data now)
SELECT id, full_name, email, application_status, created_at 
FROM healthcare_providers 
ORDER BY created_at DESC;
