-- ============================================
-- ADD UNIQUE CONSTRAINTS ON PATIENTS TABLE
-- For Email and Primary Phone Number
-- ============================================
-- This prevents duplicate registrations with same email or phone
-- Run this SQL in Supabase SQL Editor
-- ============================================

-- STEP 1: Check current state (IMPORTANT - RUN THIS FIRST!)
-- ============================================
-- See what constraints already exist
SELECT 
    conname as constraint_name,
    CASE contype 
        WHEN 'u' THEN 'UNIQUE'
        WHEN 'p' THEN 'PRIMARY KEY'
        WHEN 'f' THEN 'FOREIGN KEY'
        ELSE contype::text 
    END as constraint_type,
    pg_get_constraintdef(oid) as definition
FROM pg_constraint
WHERE conrelid = 'patients'::regclass
ORDER BY conname;


-- STEP 2: Check for existing duplicate EMAILS (MUST CHECK!)
-- ============================================
-- If this returns any rows, you have duplicate emails in database
-- Clean them up BEFORE adding UNIQUE constraint
SELECT email, COUNT(*) as count
FROM patients 
WHERE email IS NOT NULL 
GROUP BY email 
HAVING COUNT(*) > 1
ORDER BY count DESC;

-- If duplicates found, clean them up like this:
-- DELETE FROM patients 
-- WHERE id IN (
--     SELECT id FROM patients 
--     WHERE email = 'duplicate@email.com' 
--     ORDER BY created_at DESC 
--     OFFSET 1  -- Keep first, delete rest
-- );


-- STEP 3: Check for existing duplicate PHONE NUMBERS (MUST CHECK!)
-- ============================================
-- If this returns any rows, you have duplicate phones in database
-- Clean them up BEFORE adding UNIQUE constraint
SELECT phone, COUNT(*) as count
FROM patients 
WHERE phone IS NOT NULL 
GROUP BY phone 
HAVING COUNT(*) > 1
ORDER BY count DESC;

-- If duplicates found, clean them up like this:
-- DELETE FROM patients 
-- WHERE id IN (
--     SELECT id FROM patients 
--     WHERE phone = '1234567890' 
--     ORDER BY created_at DESC 
--     OFFSET 1  -- Keep first, delete rest
-- );


-- ============================================
-- STEP 4: ADD UNIQUE CONSTRAINT ON EMAIL
-- ============================================
-- This ensures one email = one account only
-- Works for both OAuth and plain registration

DO $$ 
BEGIN
    -- Check if constraint already exists
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conrelid = 'patients'::regclass
        AND conname = 'patients_email_unique'
    ) THEN
        -- Add UNIQUE constraint
        ALTER TABLE patients 
        ADD CONSTRAINT patients_email_unique UNIQUE (email);
        
        RAISE NOTICE '✅ SUCCESS: UNIQUE constraint added on patients.email';
    ELSE
        RAISE NOTICE '⚠️ SKIPPED: Email UNIQUE constraint already exists';
    END IF;
EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION '❌ FAILED: Duplicate emails exist in database. Clean them up first using STEP 2 queries.';
    WHEN OTHERS THEN
        RAISE EXCEPTION '❌ ERROR: % - %', SQLERRM, SQLSTATE;
END $$;


-- ============================================
-- STEP 5: ADD UNIQUE CONSTRAINT ON PHONE
-- ============================================
-- This ensures one phone = one account only
-- Alternative phone is NOT affected (can be shared)

DO $$ 
BEGIN
    -- Check if constraint already exists
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conrelid = 'patients'::regclass
        AND conname = 'patients_phone_unique'
    ) THEN
        -- Add UNIQUE constraint
        ALTER TABLE patients 
        ADD CONSTRAINT patients_phone_unique UNIQUE (phone);
        
        RAISE NOTICE '✅ SUCCESS: UNIQUE constraint added on patients.phone';
    ELSE
        RAISE NOTICE '⚠️ SKIPPED: Phone UNIQUE constraint already exists';
    END IF;
EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION '❌ FAILED: Duplicate phones exist in database. Clean them up first using STEP 3 queries.';
    WHEN OTHERS THEN
        RAISE EXCEPTION '❌ ERROR: % - %', SQLERRM, SQLSTATE;
END $$;


-- ============================================
-- STEP 6: ADD INDEXES for faster lookups (RECOMMENDED)
-- ============================================
-- Makes email/phone searches much faster

CREATE INDEX IF NOT EXISTS idx_patients_email 
ON patients(email) 
WHERE email IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_patients_phone 
ON patients(phone) 
WHERE phone IS NOT NULL;

-- Success message
DO $$ 
BEGIN
    RAISE NOTICE '✅ Indexes created for email and phone columns';
END $$;


-- ============================================
-- STEP 7: VERIFY ALL CONSTRAINTS (RUN THIS TO CONFIRM)
-- ============================================
-- This shows the final state - you should see both constraints

SELECT 
    conname as constraint_name,
    CASE contype 
        WHEN 'u' THEN 'UNIQUE'
        WHEN 'p' THEN 'PRIMARY KEY'
        WHEN 'f' THEN 'FOREIGN KEY'
        ELSE contype::text 
    END as constraint_type
FROM pg_constraint
WHERE conrelid = 'patients'::regclass
AND conname IN ('patients_email_unique', 'patients_phone_unique')
ORDER BY conname;

-- Expected result:
-- constraint_name         | constraint_type
-- patients_email_unique   | UNIQUE
-- patients_phone_unique   | UNIQUE


-- ============================================
-- VERIFICATION: Test if it works
-- ============================================
-- Try to insert duplicate email (should FAIL):
-- INSERT INTO patients (email, phone) VALUES ('test@test.com', '1111111111');
-- INSERT INTO patients (email, phone) VALUES ('test@test.com', '2222222222');  -- ❌ Should fail

-- Try to insert duplicate phone (should FAIL):
-- INSERT INTO patients (email, phone) VALUES ('test1@test.com', '3333333333');
-- INSERT INTO patients (email, phone) VALUES ('test2@test.com', '3333333333');  -- ❌ Should fail

-- Try to insert duplicate alternative phone (should SUCCEED):
-- INSERT INTO patients (email, phone, alternative_phone) VALUES ('test3@test.com', '4444444444', '9999999999');
-- INSERT INTO patients (email, phone, alternative_phone) VALUES ('test4@test.com', '5555555555', '9999999999');  -- ✅ Should work


-- ============================================
-- IMPORTANT NOTES:
-- ============================================
-- 1. EMAIL CONSTRAINT:
--    ✅ One email = One account (OAuth or plain)
--    ✅ Backend validates before sending OTP
--    ✅ Database enforces at insertion time
--
-- 2. PHONE CONSTRAINT:
--    ✅ One primary phone = One account
--    ✅ Backend validates before sending OTP
--    ✅ Database enforces at insertion time
--
-- 3. ALTERNATIVE PHONE (NO CONSTRAINT):
--    ✅ Multiple users can share same alternative phone
--    ✅ Intentional design for family emergency contacts
--
-- 4. DUPLICATE CLEANUP:
--    ⚠️ If STEP 2 or STEP 3 show duplicates
--    ⚠️ Migration will FAIL
--    ⚠️ Clean up duplicates manually first
--    ⚠️ Keep most recent account, delete older ones
-- ============================================


-- ============================================
-- ROLLBACK (IF NEEDED - USE WITH CAUTION!)
-- ============================================
-- Only run these if you need to remove the constraints:

-- Remove email constraint:
-- ALTER TABLE patients DROP CONSTRAINT IF EXISTS patients_email_unique;
-- DROP INDEX IF EXISTS idx_patients_email;

-- Remove phone constraint:
-- ALTER TABLE patients DROP CONSTRAINT IF EXISTS patients_phone_unique;
-- DROP INDEX IF EXISTS idx_patients_phone;


-- ============================================
-- SUCCESS CONFIRMATION
-- ============================================
-- If you reached here without errors, you're done! ✅
-- Both email and phone are now UNIQUE in database
-- Backend code will catch duplicates before OTP
-- Database will block duplicates at insertion
-- ============================================
