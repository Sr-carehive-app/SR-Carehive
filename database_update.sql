-- Add profile_image_url column to patients table
ALTER TABLE patients 
ADD COLUMN profile_image_url TEXT;

-- Create Supabase Storage bucket for profile images
-- Note: You'll need to create this bucket manually in Supabase Dashboard
-- Go to Storage > Create a new bucket named 'profile-images'
-- Set it to public and enable RLS 