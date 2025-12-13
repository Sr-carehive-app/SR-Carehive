-- SQL Query to create healthcare_providers table in Supabase
-- This table stores all healthcare provider registration applications

CREATE TABLE IF NOT EXISTS healthcare_providers (
    -- Primary Key
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    
    -- Section A: Basic Information
    full_name VARCHAR(255) NOT NULL,
    mobile_number VARCHAR(15) NOT NULL UNIQUE,
    alternative_mobile VARCHAR(15),
    email VARCHAR(255) NOT NULL UNIQUE,
    city VARCHAR(100) NOT NULL,
    password_hash TEXT NOT NULL, -- Store hashed password in production
    
    -- Professional Role
    professional_role VARCHAR(100) NOT NULL,
    other_profession VARCHAR(150), -- For "Other Allied Health Professional"
    doctor_specialty VARCHAR(100), -- For doctors only
    
    -- Qualifications & Registration
    highest_qualification VARCHAR(200) NOT NULL,
    completion_year INTEGER NOT NULL,
    registration_number VARCHAR(100) NOT NULL,
    
    -- Current Work Profile
    current_work_role VARCHAR(150) NOT NULL,
    workplace VARCHAR(255) NOT NULL,
    years_of_experience INTEGER NOT NULL,
    
    -- Section B: Service Preferences
    services_offered TEXT[] NOT NULL, -- Array of selected services
    availability_days TEXT[] NOT NULL, -- Array of days (Monday, Tuesday, etc.)
    time_slots TEXT[] NOT NULL, -- Array of time slots
    community_experience TEXT, -- Optional experience details
    languages TEXT[] NOT NULL, -- Array of languages
    service_areas TEXT NOT NULL, -- Localities/regions covered
    home_visit_fee DECIMAL(10, 2), -- Home visit charge in rupees
    teleconsultation_fee DECIMAL(10, 2), -- Teleconsultation fee in rupees
    
    -- Section C: Consent & Compliance
    agreed_to_declaration BOOLEAN NOT NULL DEFAULT false,
    agreed_to_data_privacy BOOLEAN NOT NULL DEFAULT false,
    agreed_to_professional_responsibility BOOLEAN NOT NULL DEFAULT false,
    agreed_to_terms BOOLEAN NOT NULL DEFAULT false,
    agreed_to_communication BOOLEAN NOT NULL DEFAULT false,
    
    -- Application Status & Metadata
    application_status VARCHAR(20) DEFAULT 'pending' CHECK (application_status IN ('pending', 'under_review', 'approved', 'rejected', 'on_hold')),
    rejection_reason TEXT, -- Reason if rejected
    approved_by UUID, -- Admin user ID who approved
    approved_at TIMESTAMP WITH TIME ZONE,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Verification Status
    email_verified BOOLEAN DEFAULT false,
    mobile_verified BOOLEAN DEFAULT false,
    documents_verified BOOLEAN DEFAULT false,
    
    -- Additional Notes
    admin_notes TEXT, -- Internal notes for admin review
    
    -- Constraints
    CONSTRAINT valid_email CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    CONSTRAINT valid_mobile CHECK (mobile_number ~ '^\d{10,15}$'),
    CONSTRAINT valid_experience CHECK (years_of_experience >= 0 AND years_of_experience <= 70),
    CONSTRAINT valid_year CHECK (completion_year >= 1950 AND completion_year <= EXTRACT(YEAR FROM CURRENT_DATE)),
    CONSTRAINT all_consents_required CHECK (
        agreed_to_declaration = true AND
        agreed_to_data_privacy = true AND
        agreed_to_professional_responsibility = true AND
        agreed_to_terms = true AND
        agreed_to_communication = true
    )
);

-- Create indexes for better query performance
CREATE INDEX idx_healthcare_providers_email ON healthcare_providers(email);
CREATE INDEX idx_healthcare_providers_mobile ON healthcare_providers(mobile_number);
CREATE INDEX idx_healthcare_providers_status ON healthcare_providers(application_status);
CREATE INDEX idx_healthcare_providers_role ON healthcare_providers(professional_role);
CREATE INDEX idx_healthcare_providers_city ON healthcare_providers(city);
CREATE INDEX idx_healthcare_providers_created_at ON healthcare_providers(created_at DESC);

-- Create trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_healthcare_providers_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER healthcare_providers_updated_at_trigger
    BEFORE UPDATE ON healthcare_providers
    FOR EACH ROW
    EXECUTE FUNCTION update_healthcare_providers_updated_at();

-- Enable Row Level Security (RLS)
ALTER TABLE healthcare_providers ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Allow insert for anyone (public registration)
CREATE POLICY "Anyone can register as healthcare provider"
    ON healthcare_providers
    FOR INSERT
    WITH CHECK (true);

-- RLS Policy: Users can view their own application
CREATE POLICY "Users can view own application"
    ON healthcare_providers
    FOR SELECT
    USING (auth.uid() IS NOT NULL AND email = auth.email());

-- RLS Policy: Users can update their own application if pending
CREATE POLICY "Users can update own pending application"
    ON healthcare_providers
    FOR UPDATE
    USING (auth.uid() IS NOT NULL AND email = auth.email() AND application_status = 'pending')
    WITH CHECK (auth.uid() IS NOT NULL AND email = auth.email());

-- Comments for documentation
COMMENT ON TABLE healthcare_providers IS 'Stores healthcare provider registration applications and profiles';
COMMENT ON COLUMN healthcare_providers.application_status IS 'Status: pending, under_review, approved, rejected, on_hold';
COMMENT ON COLUMN healthcare_providers.services_offered IS 'Array of services: Teleconsultation, Home Visits, etc.';
COMMENT ON COLUMN healthcare_providers.availability_days IS 'Array of available days: Monday, Tuesday, etc.';
COMMENT ON COLUMN healthcare_providers.time_slots IS 'Array of time slots: Morning, Afternoon, Evening, etc.';
COMMENT ON COLUMN healthcare_providers.languages IS 'Array of languages provider can communicate in';

-- Sample query to view all pending applications
-- SELECT id, full_name, email, professional_role, city, created_at 
-- FROM healthcare_providers 
-- WHERE application_status = 'pending' 
-- ORDER BY created_at DESC;

-- Sample query to approve an application
-- UPDATE healthcare_providers 
-- SET application_status = 'approved', 
--     approved_at = NOW(), 
--     approved_by = 'admin_uuid_here'
-- WHERE id = 'provider_uuid_here';
