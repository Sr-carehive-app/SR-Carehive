-- ============================================================
-- ADD HEALTHCARE PROVIDER (NURSE) FEEDBACK TABLE
-- ============================================================
-- Run this in your Supabase SQL editor.
-- This is SEPARATE from appointment_feedback (patient-experience feedback).
-- This stores ratings the patient gives specifically for the healthcare provider.

-- PART 1: Create the provider_feedback table
CREATE TABLE IF NOT EXISTS provider_feedback (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  appointment_id UUID NOT NULL REFERENCES appointments(id) ON DELETE CASCADE,
  patient_id UUID REFERENCES patients(id) ON DELETE SET NULL,

  -- ── Star Ratings (1–5) ────────────────────────────────────────────────────
  overall_rating INTEGER NOT NULL CHECK (overall_rating >= 1 AND overall_rating <= 5),
  service_behavior_rating INTEGER CHECK (service_behavior_rating >= 1 AND service_behavior_rating <= 5),
  technical_skill_rating INTEGER CHECK (technical_skill_rating >= 1 AND technical_skill_rating <= 5),
  punctuality_rating INTEGER CHECK (punctuality_rating >= 1 AND punctuality_rating <= 5),
  hygiene_cleanliness_rating INTEGER CHECK (hygiene_cleanliness_rating >= 1 AND hygiene_cleanliness_rating <= 5),
  communication_rating INTEGER CHECK (communication_rating >= 1 AND communication_rating <= 5),

  -- ── Yes/No Questions (Boolean) ────────────────────────────────────────────
  faced_any_problem BOOLEAN DEFAULT FALSE,          -- Did you face any problem during the home visit?
  would_recommend_provider BOOLEAN DEFAULT FALSE,   -- Would you recommend this healthcare provider?
  provider_was_professional BOOLEAN DEFAULT TRUE,   -- Was the provider professional?

  -- ── Text Feedback ─────────────────────────────────────────────────────────
  problem_description TEXT,                         -- If faced problem, describe it (optional)
  additional_feedback TEXT,                         -- Additional feedback to help us improve (optional)

  -- ── Denormalized fields for easy admin queries ───────────────────────────
  nurse_name VARCHAR(255),                          -- Healthcare provider name (from appointment)
  patient_name VARCHAR(255),                        -- Patient name (from appointment)

  -- ── Metadata ──────────────────────────────────────────────────────────────
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- PART 2: Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_provider_feedback_appointment ON provider_feedback(appointment_id);
CREATE INDEX IF NOT EXISTS idx_provider_feedback_patient ON provider_feedback(patient_id);
CREATE INDEX IF NOT EXISTS idx_provider_feedback_overall ON provider_feedback(overall_rating, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_provider_feedback_nurse ON provider_feedback(nurse_name, created_at DESC);

-- PART 3: Add comments for documentation
COMMENT ON TABLE provider_feedback IS 'Patient feedback specifically about the healthcare provider (nurse) after service completion';
COMMENT ON COLUMN provider_feedback.overall_rating IS 'Overall rating for the healthcare provider (1–5 stars)';
COMMENT ON COLUMN provider_feedback.service_behavior_rating IS 'Rating for nurse behavior and attitude (1–5 stars)';
COMMENT ON COLUMN provider_feedback.technical_skill_rating IS 'Rating for nurse technical/medical skill (1–5 stars)';
COMMENT ON COLUMN provider_feedback.punctuality_rating IS 'Rating for nurse punctuality (1–5 stars)';
COMMENT ON COLUMN provider_feedback.hygiene_cleanliness_rating IS 'Rating for hygiene and cleanliness maintained (1–5 stars)';
COMMENT ON COLUMN provider_feedback.communication_rating IS 'Rating for communication quality (1–5 stars)';
COMMENT ON COLUMN provider_feedback.faced_any_problem IS 'Whether patient faced any problem during home visit';
COMMENT ON COLUMN provider_feedback.would_recommend_provider IS 'Whether patient would recommend this provider';
COMMENT ON COLUMN provider_feedback.provider_was_professional IS 'Whether provider maintained professionalism';
COMMENT ON COLUMN provider_feedback.problem_description IS 'Description of problem if faced_any_problem is true';
COMMENT ON COLUMN provider_feedback.additional_feedback IS 'Open-ended additional feedback from patient';

-- PART 4: Enable Row Level Security
ALTER TABLE provider_feedback ENABLE ROW LEVEL SECURITY;

-- Policy: Anyone can INSERT (patients submitting feedback)
DO $$
BEGIN
  CREATE POLICY "allow_insert_provider_feedback"
    ON provider_feedback FOR INSERT
    WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN
  NULL; -- Policy already exists, skip
END $$;

-- Policy: Anyone can SELECT (admins and service role can read all)
DO $$
BEGIN
  CREATE POLICY "allow_select_provider_feedback"
    ON provider_feedback FOR SELECT
    USING (true);
EXCEPTION WHEN duplicate_object THEN
  NULL; -- Policy already exists, skip
END $$;


-- PART 5: Create a summary view for admin analytics
CREATE OR REPLACE VIEW provider_feedback_summary AS
SELECT
  pf.id,
  pf.appointment_id,
  pf.patient_id,
  pf.nurse_name,
  pf.patient_name,
  a.date AS appointment_date,
  a.nurse_phone,
  -- Ratings
  pf.overall_rating,
  pf.service_behavior_rating,
  pf.technical_skill_rating,
  pf.punctuality_rating,
  pf.hygiene_cleanliness_rating,
  pf.communication_rating,
  -- Average rating
  ROUND(
    (pf.overall_rating::NUMERIC +
     COALESCE(pf.service_behavior_rating, pf.overall_rating)::NUMERIC +
     COALESCE(pf.technical_skill_rating, pf.overall_rating)::NUMERIC +
     COALESCE(pf.punctuality_rating, pf.overall_rating)::NUMERIC +
     COALESCE(pf.hygiene_cleanliness_rating, pf.overall_rating)::NUMERIC +
     COALESCE(pf.communication_rating, pf.overall_rating)::NUMERIC) / 6, 2
  ) AS average_rating,
  -- Yes/No
  pf.faced_any_problem,
  pf.would_recommend_provider,
  pf.provider_was_professional,
  -- Text
  pf.problem_description,
  pf.additional_feedback,
  pf.created_at AS feedback_date
FROM provider_feedback pf
JOIN appointments a ON pf.appointment_id = a.id
ORDER BY pf.created_at DESC;

COMMENT ON VIEW provider_feedback_summary IS 'Summary view of all healthcare provider ratings with appointment context';

-- ============================================================
-- MIGRATION COMPLETE! ✅
-- ============================================================
-- Features Added:
-- 1. provider_feedback table with star ratings + yes/no questions + text fields
-- 2. Indexes for fast admin queries by appointment, patient, nurse
-- 3. RLS policies (insert/select open for now — tighten in production if needed)
-- 4. provider_feedback_summary view for analytics dashboard
