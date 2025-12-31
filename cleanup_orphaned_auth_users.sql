-- ============================================================================
-- CLEANUP ORPHANED AUTH USERS
-- ============================================================================
-- Purpose: Remove users from auth.users who don't have corresponding patient records
-- Use Case: Failed patient table inserts leave orphaned auth users
-- Date: 2026-01-01
-- ============================================================================

-- Step 1: Find orphaned auth users (users in auth but NOT in patients table)
SELECT 
    au.id as auth_user_id,
    au.email,
    au.created_at,
    au.confirmed_at,
    CASE 
        WHEN p.user_id IS NULL THEN 'ORPHANED - No patient record'
        ELSE 'OK - Has patient record'
    END as status
FROM 
    auth.users au
LEFT JOIN 
    public.patients p ON au.id = p.user_id
WHERE 
    p.user_id IS NULL
ORDER BY 
    au.created_at DESC;

-- ============================================================================
-- CLEANUP SPECIFIC ORPHANED USER (MANUAL EXECUTION)
-- ============================================================================
-- Replace 'dbfb0fc4-c479-42c6-9435-2db674fbcb42' with actual user_id
-- ============================================================================

-- DELETE FROM auth.users 
-- WHERE id = 'dbfb0fc4-c479-42c6-9435-2db674fbcb42'
-- AND NOT EXISTS (
--     SELECT 1 FROM public.patients WHERE user_id = 'dbfb0fc4-c479-42c6-9435-2db674fbcb42'
-- );

-- ============================================================================
-- BULK CLEANUP ALL ORPHANED USERS (USE WITH CAUTION!)
-- ============================================================================
-- Uncomment to execute mass cleanup
-- ============================================================================

-- DELETE FROM auth.users
-- WHERE id IN (
--     SELECT au.id
--     FROM auth.users au
--     LEFT JOIN public.patients p ON au.id = p.user_id
--     WHERE p.user_id IS NULL
-- );

-- ============================================================================
-- VERIFICATION: Count orphaned vs valid users
-- ============================================================================

SELECT 
    COUNT(*) FILTER (WHERE p.user_id IS NULL) as orphaned_users,
    COUNT(*) FILTER (WHERE p.user_id IS NOT NULL) as valid_users,
    COUNT(*) as total_auth_users
FROM 
    auth.users au
LEFT JOIN 
    public.patients p ON au.id = p.user_id;
