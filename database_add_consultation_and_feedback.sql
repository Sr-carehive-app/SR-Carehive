-- ============================================
-- ADD POST-VISIT CONSULTATION & FEEDBACK SYSTEM
-- ============================================

-- PART 1: Post-Visit Consultation Fields (already exist, ensuring they're present)
ALTER TABLE appointments 
ADD COLUMN IF NOT EXISTS consulted_doctor_name VARCHAR(255),
ADD COLUMN IF NOT EXISTS consulted_doctor_phone VARCHAR(20),
ADD COLUMN IF NOT EXISTS consulted_doctor_specialization VARCHAR(255),
ADD COLUMN IF NOT EXISTS consulted_doctor_clinic_address TEXT,
ADD COLUMN IF NOT EXISTS post_visit_remarks TEXT,
ADD COLUMN IF NOT EXISTS visit_completed_at TIMESTAMP,
ADD COLUMN IF NOT EXISTS visit_completion_enabled BOOLEAN DEFAULT FALSE;

-- Add comments
COMMENT ON COLUMN appointments.consulted_doctor_name IS 'Recommended doctor name after nurse consultation';
COMMENT ON COLUMN appointments.consulted_doctor_phone IS 'Recommended doctor contact number';
COMMENT ON COLUMN appointments.consulted_doctor_specialization IS 'Doctor specialization';
COMMENT ON COLUMN appointments.consulted_doctor_clinic_address IS 'Doctor clinic address';
COMMENT ON COLUMN appointments.post_visit_remarks IS 'Nurse remarks after completing the visit';
COMMENT ON COLUMN appointments.visit_completed_at IS 'Timestamp when nurse completed post-visit consultation';
COMMENT ON COLUMN appointments.visit_completion_enabled IS 'Whether final payment is enabled (set to true when nurse submits post-visit form)';

-- PART 2: Create Feedback Table
CREATE TABLE IF NOT EXISTS appointment_feedback (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  appointment_id UUID NOT NULL REFERENCES appointments(id) ON DELETE CASCADE,
  patient_id UUID REFERENCES patients(id) ON DELETE SET NULL,
  
  -- Ratings (1-5 stars)
  overall_rating INTEGER CHECK (overall_rating >= 1 AND overall_rating <= 5),
  nurse_professionalism_rating INTEGER CHECK (nurse_professionalism_rating >= 1 AND nurse_professionalism_rating <= 5),
  service_quality_rating INTEGER CHECK (service_quality_rating >= 1 AND service_quality_rating <= 5),
  communication_rating INTEGER CHECK (communication_rating >= 1 AND communication_rating <= 5),
  punctuality_rating INTEGER CHECK (punctuality_rating >= 1 AND punctuality_rating <= 5),
  
  -- Feedback text
  positive_feedback TEXT,
  improvement_suggestions TEXT,
  additional_comments TEXT,
  
  -- Service checkboxes
  would_recommend BOOLEAN DEFAULT FALSE,
  satisfied_with_service BOOLEAN DEFAULT FALSE,
  
  -- Metadata
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Create indexes for feedback
CREATE INDEX IF NOT EXISTS idx_feedback_appointment ON appointment_feedback(appointment_id);
CREATE INDEX IF NOT EXISTS idx_feedback_patient ON appointment_feedback(patient_id);
CREATE INDEX IF NOT EXISTS idx_feedback_ratings ON appointment_feedback(overall_rating, created_at DESC);

-- Add comments to feedback table
COMMENT ON TABLE appointment_feedback IS 'Patient feedback and ratings after service completion';
COMMENT ON COLUMN appointment_feedback.overall_rating IS 'Overall service rating (1-5 stars)';
COMMENT ON COLUMN appointment_feedback.nurse_professionalism_rating IS 'Nurse professionalism rating (1-5 stars)';
COMMENT ON COLUMN appointment_feedback.service_quality_rating IS 'Service quality rating (1-5 stars)';
COMMENT ON COLUMN appointment_feedback.communication_rating IS 'Communication rating (1-5 stars)';
COMMENT ON COLUMN appointment_feedback.punctuality_rating IS 'Punctuality rating (1-5 stars)';
COMMENT ON COLUMN appointment_feedback.positive_feedback IS 'What patient liked about the service';
COMMENT ON COLUMN appointment_feedback.improvement_suggestions IS 'Suggestions for improvement';
COMMENT ON COLUMN appointment_feedback.additional_comments IS 'Any additional comments';
COMMENT ON COLUMN appointment_feedback.would_recommend IS 'Whether patient would recommend the service';
COMMENT ON COLUMN appointment_feedback.satisfied_with_service IS 'Whether patient is satisfied with the service';

-- Create view for feedback summary
CREATE OR REPLACE VIEW feedback_summary AS
SELECT 
  af.id,
  af.appointment_id,
  a.full_name as patient_name,
  a.phone as patient_phone,
  a.nurse_name,
  af.overall_rating,
  af.nurse_professionalism_rating,
  af.service_quality_rating,
  af.communication_rating,
  af.punctuality_rating,
  af.positive_feedback,
  af.improvement_suggestions,
  af.additional_comments,
  af.would_recommend,
  af.satisfied_with_service,
  af.created_at as feedback_date,
  a.date as appointment_date,
  a.final_paid_at as service_completed_date
FROM appointment_feedback af
JOIN appointments a ON af.appointment_id = a.id
ORDER BY af.created_at DESC;

COMMENT ON VIEW feedback_summary IS 'Summary view of all patient feedback with appointment details';

-- ============================================
-- MIGRATION COMPLETE! ✅
-- ============================================
-- Features Added:
-- 1. Post-visit consultation fields for nurse to fill
-- 2. Visit completion flag to enable final payment
-- 3. Comprehensive feedback system with ratings
-- 4. Feedback summary view for admin analytics
