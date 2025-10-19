-- ============================================
-- QUICK SQL QUERIES FOR PAYMENT FLOW & FEEDBACK
-- ============================================
-- Use these queries to check and manage the system

-- 1. CHECK APPOINTMENTS WITH PAYMENT STATUS
-- ============================================
SELECT 
  id,
  full_name,
  phone,
  status,
  registration_paid,
  total_amount,
  pre_paid,
  visit_completion_enabled,
  final_paid,
  created_at::date as appointment_date
FROM appointments
WHERE created_at >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY created_at DESC;


-- 2. CHECK APPOINTMENTS READY FOR FINAL PAYMENT
-- ============================================
SELECT 
  id,
  full_name,
  phone,
  total_amount,
  pre_paid,
  visit_completion_enabled,
  final_paid,
  post_visit_remarks
FROM appointments
WHERE pre_paid = true 
  AND final_paid = false
ORDER BY pre_paid_at DESC;


-- 3. CHECK APPOINTMENTS WHERE NURSE NEEDS TO COMPLETE VISIT
-- ============================================
SELECT 
  id,
  full_name,
  phone,
  nurse_name,
  total_amount,
  pre_paid,
  pre_paid_at,
  visit_completion_enabled,
  post_visit_remarks
FROM appointments
WHERE pre_paid = true 
  AND visit_completion_enabled = false
ORDER BY pre_paid_at ASC;


-- 4. VIEW ALL FEEDBACK WITH RATINGS
-- ============================================
SELECT 
  patient_name,
  nurse_name,
  overall_rating,
  nurse_professionalism_rating,
  service_quality_rating,
  communication_rating,
  punctuality_rating,
  positive_feedback,
  improvement_suggestions,
  would_recommend,
  satisfied_with_service,
  feedback_date
FROM feedback_summary
ORDER BY feedback_date DESC;


-- 5. GET AVERAGE RATINGS
-- ============================================
SELECT 
  COUNT(*) as total_feedbacks,
  ROUND(AVG(overall_rating), 2) as avg_overall_rating,
  ROUND(AVG(nurse_professionalism_rating), 2) as avg_professionalism,
  ROUND(AVG(service_quality_rating), 2) as avg_service_quality,
  ROUND(AVG(communication_rating), 2) as avg_communication,
  ROUND(AVG(punctuality_rating), 2) as avg_punctuality,
  COUNT(CASE WHEN would_recommend = true THEN 1 END) as would_recommend_count,
  COUNT(CASE WHEN satisfied_with_service = true THEN 1 END) as satisfied_count
FROM appointment_feedback
WHERE created_at >= CURRENT_DATE - INTERVAL '30 days';


-- 6. GET NURSE-WISE PERFORMANCE
-- ============================================
SELECT 
  nurse_name,
  COUNT(*) as total_feedbacks,
  ROUND(AVG(overall_rating), 2) as avg_rating,
  ROUND(AVG(nurse_professionalism_rating), 2) as avg_professionalism,
  COUNT(CASE WHEN would_recommend = true THEN 1 END) as recommendations
FROM feedback_summary
WHERE nurse_name IS NOT NULL
GROUP BY nurse_name
ORDER BY avg_rating DESC;


-- 7. MANUALLY ENABLE FINAL PAYMENT (EMERGENCY USE ONLY)
-- ============================================
-- Use this if you need to manually enable final payment for a patient
-- Replace [APPOINTMENT_ID] with actual appointment ID

-- UPDATE appointments 
-- SET 
--   visit_completion_enabled = true,
--   visit_completed_at = NOW(),
--   post_visit_remarks = 'Manually enabled by admin'
-- WHERE id = '[APPOINTMENT_ID]';


-- 8. CHECK PAYMENT PROGRESSION FOR AN APPOINTMENT
-- ============================================
-- Replace [APPOINTMENT_ID] with actual appointment ID

-- SELECT 
--   id,
--   full_name,
--   status,
--   registration_paid,
--   registration_paid_at,
--   total_amount,
--   pre_paid,
--   pre_paid_at,
--   visit_completion_enabled,
--   visit_completed_at,
--   final_paid,
--   final_paid_at,
--   post_visit_remarks,
--   consulted_doctor_name
-- FROM appointments
-- WHERE id = '[APPOINTMENT_ID]';


-- 9. GET APPOINTMENTS COMPLETED TODAY
-- ============================================
SELECT 
  id,
  full_name,
  phone,
  total_amount,
  final_paid_at,
  nurse_name
FROM appointments
WHERE final_paid = true 
  AND final_paid_at::date = CURRENT_DATE
ORDER BY final_paid_at DESC;


-- 10. GET FEEDBACK FOR SPECIFIC APPOINTMENT
-- ============================================
-- Replace [APPOINTMENT_ID] with actual appointment ID

-- SELECT 
--   af.*,
--   a.full_name as patient_name,
--   a.nurse_name
-- FROM appointment_feedback af
-- JOIN appointments a ON af.appointment_id = a.id
-- WHERE af.appointment_id = '[APPOINTMENT_ID]';


-- 11. GET LOW-RATED SERVICES (for improvement)
-- ============================================
SELECT 
  patient_name,
  nurse_name,
  overall_rating,
  improvement_suggestions,
  additional_comments,
  appointment_date,
  feedback_date
FROM feedback_summary
WHERE overall_rating <= 3
ORDER BY feedback_date DESC;


-- 12. GET COMPLETED APPOINTMENTS WITHOUT FEEDBACK
-- ============================================
SELECT 
  a.id,
  a.full_name,
  a.phone,
  a.patient_email,
  a.final_paid_at,
  a.nurse_name
FROM appointments a
LEFT JOIN appointment_feedback af ON a.id = af.appointment_id
WHERE a.final_paid = true
  AND af.id IS NULL
  AND a.final_paid_at >= CURRENT_DATE - INTERVAL '7 days'
ORDER BY a.final_paid_at DESC;


-- 13. DELETE FEEDBACK (if needed)
-- ============================================
-- Replace [FEEDBACK_ID] with actual feedback ID

-- DELETE FROM appointment_feedback 
-- WHERE id = '[FEEDBACK_ID]';


-- 14. UPDATE APPOINTMENT STATUS MANUALLY
-- ============================================
-- Replace [APPOINTMENT_ID] and adjust values as needed

-- UPDATE appointments 
-- SET 
--   status = 'pre_paid',
--   visit_completion_enabled = false
-- WHERE id = '[APPOINTMENT_ID]';


-- 15. GET PAYMENT REVENUE SUMMARY
-- ============================================
SELECT 
  COUNT(*) as total_completed,
  SUM(CASE WHEN registration_paid = true THEN 100 ELSE 0 END) as registration_revenue,
  SUM(CASE WHEN pre_paid = true THEN (total_amount / 2) ELSE 0 END) as pre_payment_revenue,
  SUM(CASE WHEN final_paid = true THEN (total_amount / 2) ELSE 0 END) as final_payment_revenue,
  SUM(CASE WHEN final_paid = true THEN (100 + total_amount) ELSE 0 END) as total_revenue
FROM appointments
WHERE created_at >= CURRENT_DATE - INTERVAL '30 days';
