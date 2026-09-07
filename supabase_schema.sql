-- =============================================================================
-- CarePharma - Supabase Database Migration & RLS Configuration
-- Run this SQL in your Supabase Project -> SQL Editor
-- URL: https://easjbvwjslirocrsobgt.supabase.co
-- =============================================================================

-- 1. Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 2. Ensure pharmacies table exists with ownership reference
CREATE TABLE IF NOT EXISTS public.pharmacies (
    "UID" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "Name" TEXT NOT NULL DEFAULT 'Apollo Meds & Wellness',
    "Email" TEXT,
    "Phone" TEXT,
    "License" TEXT DEFAULT 'MH-PUN-2024-8891',
    "owner_id" UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    "created_at" TIMESTAMPTZ DEFAULT now()
);

-- Ensure owner_id column exists if table was already present
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'pharmacies' AND column_name = 'owner_id'
    ) THEN
        ALTER TABLE public.pharmacies ADD COLUMN "owner_id" UUID REFERENCES auth.users(id) ON DELETE SET NULL;
    END IF;
END $$;

-- 3. Update medicines table: Add pharmacy_uid and ensure default UID generator
DO $$
BEGIN
    -- Add pharmacy_uid column if not present
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'medicines' AND column_name = 'pharmacy_uid'
    ) THEN
        ALTER TABLE public.medicines ADD COLUMN "pharmacy_uid" UUID REFERENCES public.pharmacies("UID") ON DELETE CASCADE;
    END IF;

    -- Ensure added_by column exists for user audit tracking
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'medicines' AND column_name = 'added_by'
    ) THEN
        ALTER TABLE public.medicines ADD COLUMN "added_by" TEXT;
    END IF;
END $$;

-- Ensure medicines UID has a default generator if none exists
DO $$
BEGIN
    ALTER TABLE public.medicines ALTER COLUMN "UID" SET DEFAULT ('MED-ID-' || substring(gen_random_uuid()::text from 1 for 8));
EXCEPTION
    WHEN OTHERS THEN
        NULL;
END $$;

-- 4. Create an index for fast lookups by pharmacy_uid
CREATE INDEX IF NOT EXISTS idx_medicines_pharmacy_uid ON public.medicines("pharmacy_uid");

-- 5. Helper Function: Get or create pharmacy for the current authenticated user
CREATE OR REPLACE FUNCTION public.get_current_pharmacy_uid()
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_user_email TEXT;
    v_pharmacy_uid UUID;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN NULL;
    END IF;

    v_user_email := auth.jwt()->>'email';

    -- Check if a pharmacy already exists for this owner
    SELECT "UID" INTO v_pharmacy_uid
    FROM public.pharmacies
    WHERE "owner_id" = v_user_id
    LIMIT 1;

    -- If not found, check by Email
    IF v_pharmacy_uid IS NULL AND v_user_email IS NOT NULL THEN
        SELECT "UID" INTO v_pharmacy_uid
        FROM public.pharmacies
        WHERE lower("Email") = lower(v_user_email)
        LIMIT 1;

        -- If found by email, link to current user_id
        IF v_pharmacy_uid IS NOT NULL THEN
            UPDATE public.pharmacies SET "owner_id" = v_user_id WHERE "UID" = v_pharmacy_uid;
        END IF;
    END IF;

    -- If still not found, automatically provision a default pharmacy record for this user
    IF v_pharmacy_uid IS NULL THEN
        INSERT INTO public.pharmacies ("Name", "Email", "owner_id")
        VALUES (
            'Apollo Meds & Wellness',
            COALESCE(v_user_email, 'admin@carepharma.com'),
            v_user_id
        )
        RETURNING "UID" INTO v_pharmacy_uid;
    END IF;

    RETURN v_pharmacy_uid;
END;
$$;

-- Grant execution on the helper function to authenticated users
GRANT EXECUTE ON FUNCTION public.get_current_pharmacy_uid() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_current_pharmacy_uid() TO anon;

-- 6. Trigger to automatically assign pharmacy_uid and added_by on INSERT
CREATE OR REPLACE FUNCTION public.trg_set_medicine_ownership()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_pharmacy_uid UUID;
BEGIN
    v_user_id := auth.uid();
    
    -- If user is authenticated, resolve their pharmacy
    IF v_user_id IS NOT NULL THEN
        v_pharmacy_uid := public.get_current_pharmacy_uid();
        
        -- Always enforce pharmacy_uid to match the authenticated user's pharmacy
        NEW."pharmacy_uid" := v_pharmacy_uid;
        NEW."added_by" := COALESCE(auth.jwt()->>'email', v_user_id::text);
    END IF;

    -- Generate UID if not provided
    IF NEW."UID" IS NULL OR NEW."UID" = '' THEN
        NEW."UID" := 'MED-ID-' || substring(gen_random_uuid()::text from 1 for 8);
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS set_medicine_ownership_trigger ON public.medicines;
CREATE TRIGGER set_medicine_ownership_trigger
    BEFORE INSERT ON public.medicines
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_medicine_ownership();

-- 7. Configure Row Level Security (RLS) on public.medicines
ALTER TABLE public.medicines ENABLE ROW LEVEL SECURITY;

-- Drop previous policies to avoid conflicts
DROP POLICY IF EXISTS "Enable read access for all users" ON public.medicines;
DROP POLICY IF EXISTS "Pharmacists can view their pharmacy medicines" ON public.medicines;
DROP POLICY IF EXISTS "Pharmacists can insert their pharmacy medicines" ON public.medicines;
DROP POLICY IF EXISTS "Pharmacists can update their pharmacy medicines" ON public.medicines;
DROP POLICY IF EXISTS "Pharmacists can delete their pharmacy medicines" ON public.medicines;
DROP POLICY IF EXISTS "Public can view catalog medicines" ON public.medicines;

-- POLICY 1: SELECT
-- Pharmacy admins can view medicines for their pharmacy (and unassigned catalog medicines)
CREATE POLICY "Pharmacists can view their pharmacy medicines"
    ON public.medicines
    FOR SELECT
    TO authenticated, anon
    USING (
        "pharmacy_uid" IS NULL
        OR "pharmacy_uid" = public.get_current_pharmacy_uid()
    );

-- POLICY 2: INSERT
-- Pharmacy admins can insert medicines for their assigned pharmacy
CREATE POLICY "Pharmacists can insert their pharmacy medicines"
    ON public.medicines
    FOR INSERT
    TO authenticated
    WITH CHECK (
        "pharmacy_uid" = public.get_current_pharmacy_uid()
        OR public.get_current_pharmacy_uid() IS NOT NULL
    );

-- POLICY 3: UPDATE
-- Pharmacy admins can only update medicines belonging to their own pharmacy
CREATE POLICY "Pharmacists can update their pharmacy medicines"
    ON public.medicines
    FOR UPDATE
    TO authenticated
    USING (
        "pharmacy_uid" = public.get_current_pharmacy_uid()
    )
    WITH CHECK (
        "pharmacy_uid" = public.get_current_pharmacy_uid()
    );

-- POLICY 4: DELETE
-- Pharmacy admins can only delete medicines belonging to their own pharmacy
CREATE POLICY "Pharmacists can delete their pharmacy medicines"
    ON public.medicines
    FOR DELETE
    TO authenticated
    USING (
        "pharmacy_uid" = public.get_current_pharmacy_uid()
    );

-- 8. Configure RLS on public.pharmacies
ALTER TABLE public.pharmacies ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their pharmacy" ON public.pharmacies;
CREATE POLICY "Users can view their pharmacy"
    ON public.pharmacies
    FOR SELECT
    TO authenticated
    USING (
        "owner_id" = auth.uid()
        OR lower("Email") = lower(COALESCE(auth.jwt()->>'email', ''))
    );

DROP POLICY IF EXISTS "Users can insert their pharmacy" ON public.pharmacies;
CREATE POLICY "Users can insert their pharmacy"
    ON public.pharmacies
    FOR INSERT
    TO authenticated
    WITH CHECK (
        "owner_id" = auth.uid()
    );

DROP POLICY IF EXISTS "Users can update their pharmacy" ON public.pharmacies;
CREATE POLICY "Users can update their pharmacy"
    ON public.pharmacies
    FOR UPDATE
    TO authenticated
    USING (
        "owner_id" = auth.uid()
    );

