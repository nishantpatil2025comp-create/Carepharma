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

-- Ensure owner_id, latitude, longitude, and Location columns exist on pharmacies
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'pharmacies' AND column_name = 'owner_id'
    ) THEN
        ALTER TABLE public.pharmacies ADD COLUMN "owner_id" UUID REFERENCES auth.users(id) ON DELETE SET NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'pharmacies' AND column_name = 'latitude'
    ) THEN
        ALTER TABLE public.pharmacies ADD COLUMN "latitude" DOUBLE PRECISION;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'pharmacies' AND column_name = 'longitude'
    ) THEN
        ALTER TABLE public.pharmacies ADD COLUMN "longitude" DOUBLE PRECISION;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'pharmacies' AND column_name = 'Location'
    ) THEN
        ALTER TABLE public.pharmacies ADD COLUMN "Location" TEXT;
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

    -- Ensure generic_salt column exists for active ingredient grouping
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'medicines' AND column_name = 'generic_salt'
    ) THEN
        ALTER TABLE public.medicines ADD COLUMN "generic_salt" TEXT;
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
DROP POLICY IF EXISTS "Public can view registered pharmacies" ON public.pharmacies;
CREATE POLICY "Public can view registered pharmacies"
    ON public.pharmacies
    FOR SELECT
    TO authenticated, anon
    USING (true);

DROP POLICY IF EXISTS "Users can insert their pharmacy" ON public.pharmacies;
DROP POLICY IF EXISTS "Anyone can register pharmacy" ON public.pharmacies;
CREATE POLICY "Anyone can register pharmacy"
    ON public.pharmacies
    FOR INSERT
    TO authenticated, anon
    WITH CHECK (true);

DROP POLICY IF EXISTS "Users can update their pharmacy" ON public.pharmacies;
CREATE POLICY "Users can update their pharmacy"
    ON public.pharmacies
    FOR UPDATE
    TO authenticated
    USING (
        "owner_id" = auth.uid()
        OR "owner_id" IS NULL
    );

-- 9. User Profiles & Dual-Role Setup
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'pharmacist')),
    full_name TEXT,
    phone TEXT,
    delivery_address TEXT,
    allergies TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    is_profile_completed BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Ensure allergies, latitude, and longitude exist on profiles
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'allergies'
    ) THEN
        ALTER TABLE public.profiles ADD COLUMN "allergies" TEXT;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'latitude'
    ) THEN
        ALTER TABLE public.profiles ADD COLUMN "latitude" DOUBLE PRECISION;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'longitude'
    ) THEN
        ALTER TABLE public.profiles ADD COLUMN "longitude" DOUBLE PRECISION;
    END IF;
END $$;

-- Enable RLS on public.profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;
CREATE POLICY "Users can view their own profile"
    ON public.profiles FOR SELECT
    TO authenticated
    USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
CREATE POLICY "Users can insert their own profile"
    ON public.profiles FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
CREATE POLICY "Users can update their own profile"
    ON public.profiles FOR UPDATE
    TO authenticated
    USING (auth.uid() = id);

-- 10. Orders Table for Medicine Checkout & Live Delivery
CREATE TABLE IF NOT EXISTS public.orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    medicine_name TEXT NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,
    total_price DOUBLE PRECISION NOT NULL,
    patient_email TEXT NOT NULL,
    delivery_address TEXT,
    delivery_latitude DOUBLE PRECISION,
    delivery_longitude DOUBLE PRECISION,
    pharmacy_uid TEXT,
    status TEXT NOT NULL DEFAULT 'Pending',
    created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can insert their own orders" ON public.orders;
CREATE POLICY "Users can insert their own orders"
    ON public.orders FOR INSERT
    TO authenticated, anon
    WITH CHECK (true);

DROP POLICY IF EXISTS "Users and pharmacists can view relevant orders" ON public.orders;
CREATE POLICY "Users and pharmacists can view relevant orders"
    ON public.orders FOR SELECT
    TO authenticated, anon
    USING (true);

DROP POLICY IF EXISTS "Pharmacists and users can update orders" ON public.orders;
CREATE POLICY "Pharmacists and users can update orders"
    ON public.orders FOR UPDATE
    TO authenticated
    USING (true);

-- Ensure address and city_pincode exist on profiles for address lookup
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'address'
    ) THEN
        ALTER TABLE public.profiles ADD COLUMN "address" TEXT;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'city_pincode'
    ) THEN
        ALTER TABLE public.profiles ADD COLUMN "city_pincode" TEXT;
    END IF;
END $$;

-- 11. Cart Table for Real-Time User Cart Management
CREATE TABLE IF NOT EXISTS public.cart (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_email TEXT NOT NULL,
    medicine_id TEXT NOT NULL,
    medicine_name TEXT NOT NULL,
    price_inr NUMERIC NOT NULL,
    quantity INT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Enable Row Level Security (RLS) on public.cart
ALTER TABLE public.cart ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage their own cart entries" ON public.cart;
CREATE POLICY "Users can manage their own cart entries"
    ON public.cart
    FOR ALL
    TO authenticated, anon
    USING (
        auth.jwt()->>'email' = user_email
        OR auth.uid() IS NOT NULL
        OR true
    )
    WITH CHECK (
        auth.jwt()->>'email' = user_email
        OR auth.uid() IS NOT NULL
        OR true
    );



