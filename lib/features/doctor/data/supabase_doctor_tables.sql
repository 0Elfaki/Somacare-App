-- ============================================================================
-- DOCTOR PORTAL - DATABASE MIGRATION
-- ============================================================================
-- Run this SQL in your Supabase SQL Editor to add doctor-specific columns
-- and Row Level Security policies.
-- ============================================================================

-- ── 1. Extend appointments table ─────────────────────────────────────────────
ALTER TABLE appointments
  ADD COLUMN IF NOT EXISTS doctor_id   UUID REFERENCES profiles(id),
  ADD COLUMN IF NOT EXISTS doctor_notes TEXT;

-- ── 2. Extend profiles table ─────────────────────────────────────────────────
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS specialization  TEXT,
  ADD COLUMN IF NOT EXISTS license_number  TEXT,
  ADD COLUMN IF NOT EXISTS working_hours   TEXT DEFAULT '09:00 - 17:00';

-- ── 3. Add doctor_id to prescriptions table ───────────────────────────────────
-- (prescriptions table was created by supabase_prescriptions_tables.sql)
ALTER TABLE prescriptions
  ADD COLUMN IF NOT EXISTS doctor_id UUID REFERENCES profiles(id);

-- ── 4. RLS - Appointments ─────────────────────────────────────────────────────

-- Doctors can SELECT appointments assigned to them (by name or by doctor_id)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'appointments'
      AND policyname = 'Doctors can view their appointments'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "Doctors can view their appointments"
        ON appointments FOR SELECT
        USING (
          doctor_name = (SELECT full_name FROM profiles WHERE id = auth.uid())
          OR doctor_id = auth.uid()
        )
    $policy$;
  END IF;
END $$;

-- Doctors can UPDATE appointments assigned to them
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'appointments'
      AND policyname = 'Doctors can update their appointments'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "Doctors can update their appointments"
        ON appointments FOR UPDATE
        USING (
          doctor_name = (SELECT full_name FROM profiles WHERE id = auth.uid())
          OR doctor_id = auth.uid()
        )
    $policy$;
  END IF;
END $$;

-- ── 5. RLS - Profiles ────────────────────────────────────────────────────────

-- Helper function used below: SECURITY DEFINER means its internal SELECT on
-- profiles bypasses RLS, which is required - a policy on profiles cannot
-- safely subquery profiles directly (Postgres re-applies the same policy to
-- the subquery, causing "infinite recursion detected in policy for
-- relation profiles").
CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$;

GRANT EXECUTE ON FUNCTION public.current_user_role() TO authenticated;

-- Doctors can read any student profile (needed for StudentProfileScreen)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'profiles'
      AND policyname = 'Doctors can view student profiles'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "Doctors can view student profiles"
        ON profiles FOR SELECT
        USING (
          public.current_user_role() = 'doctor'
          AND role = 'student'
        )
    $policy$;
  END IF;
END $$;

-- ── 6. RLS - Prescriptions ───────────────────────────────────────────────────
-- NOTE: doctor_id column must exist on prescriptions before these policies run.
-- The ALTER TABLE above adds it.

-- Doctors can INSERT prescriptions for any student
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'prescriptions'
      AND policyname = 'Doctors can insert prescriptions'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "Doctors can insert prescriptions"
        ON prescriptions FOR INSERT
        WITH CHECK (
          (SELECT role FROM profiles WHERE id = auth.uid()) = 'doctor'
        )
    $policy$;
  END IF;
END $$;

-- Doctors can SELECT prescriptions they wrote
-- (doctor_id column now exists from the ALTER TABLE above)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'prescriptions'
      AND policyname = 'Doctors can view prescriptions they wrote'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "Doctors can view prescriptions they wrote"
        ON prescriptions FOR SELECT
        USING (doctor_id = auth.uid() OR student_id = auth.uid())
    $policy$;
  END IF;
END $$;

-- ── 7. Sample doctor profile (optional - replace UUID with real doctor user ID)
-- UPDATE profiles
--   SET specialization = 'General Practice',
--       license_number = 'LIC-001',
--       working_hours  = '09:00 - 17:00'
-- WHERE id = 'YOUR_DOCTOR_USER_ID';

-- ============================================================================
-- 7. INSERT SAMPLE DOCTOR ACCOUNTS
-- ============================================================================
-- After creating auth users, run these UPDATE statements:
-- 
-- Doctor 1: Dr. Sarah Johnson - General Practice
-- UPDATE profiles SET role = 'doctor', full_name = 'Dr. Sarah Johnson', school = 'SomaCare Medical Center', specialization = 'General Practice', license_number = 'LIC-GP-001', working_hours = '09:00 - 17:00' WHERE email = 'dr.sarah.johnson@somacare.app';
--
-- Doctor 2: Dr. Michael Chen - Pediatrics
-- UPDATE profiles SET role = 'doctor', full_name = 'Dr. Michael Chen', school = 'SomaCare Medical Center', specialization = 'Pediatrics', license_number = 'LIC-PED-002', working_hours = '08:00 - 16:00' WHERE email = 'dr.michael.chen@somacare.app';
--
-- Doctor 3: Dr. Emily Williams - Dermatology
-- UPDATE profiles SET role = 'doctor', full_name = 'Dr. Emily Williams', school = 'SomaCare Medical Center', specialization = 'Dermatology', license_number = 'LIC-DERM-003', working_hours = '10:00 - 18:00' WHERE email = 'dr.emily.williams@somacare.app';
--
-- Doctor 4: Dr. James Anderson - Psychiatry
-- UPDATE profiles SET role = 'doctor', full_name = 'Dr. James Anderson', school = 'SomaCare Medical Center', specialization = 'Psychiatry', license_number = 'LIC-PSY-004', working_hours = '09:00 - 17:00' WHERE email = 'dr.james.anderson@somacare.app';
--
-- Doctor 5: Dr. Lisa Martinez - General Practice
-- UPDATE profiles SET role = 'doctor', full_name = 'Dr. Lisa Martinez', school = 'SomaCare Medical Center', specialization = 'General Practice', license_number = 'LIC-GP-005', working_hours = '08:00 - 15:00' WHERE email = 'dr.lisa.martinez@somacare.app';
-- ============================================================================
