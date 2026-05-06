-- ============================================================
-- Nurse Appointment Feedback Table
-- Healthcare Provider (Nurse) submits feedback about the
-- appointment experience after it is completed.
-- One feedback per appointment (UNIQUE constraint on appointment_id)
-- ============================================================

CREATE TABLE IF NOT EXISTS nurse_appointment_feedback (
  id                        UUID         DEFAULT gen_random_uuid() PRIMARY KEY,
  appointment_id            UUID         NOT NULL,
  nurse_name                TEXT         NOT NULL,
  nurse_email               TEXT         NOT NULL,
  nurse_phone               TEXT,
  nurse_designation         TEXT,

  -- Star ratings (1–5)
  overall_experience_rating INT          CHECK (overall_experience_rating BETWEEN 1 AND 5),
  patient_cooperation_rating INT         CHECK (patient_cooperation_rating BETWEEN 1 AND 5),
  app_platform_rating        INT         CHECK (app_platform_rating BETWEEN 1 AND 5),
  payment_process_rating     INT         CHECK (payment_process_rating BETWEEN 1 AND 5),
  admin_support_rating       INT         CHECK (admin_support_rating BETWEEN 1 AND 5),

  -- Yes / No questions
  faced_any_problem          BOOLEAN     DEFAULT FALSE,
  would_continue_service     BOOLEAN     DEFAULT TRUE,

  -- Optional text fields
  problem_description        TEXT,
  improvement_suggestions    TEXT,  -- client enforces 500-word limit

  created_at                TIMESTAMPTZ DEFAULT NOW(),

  CONSTRAINT unique_nurse_feedback_per_appointment UNIQUE (appointment_id)
);

-- RLS disabled — same policy as all other feedback tables in this project
ALTER TABLE nurse_appointment_feedback DISABLE ROW LEVEL SECURITY;
