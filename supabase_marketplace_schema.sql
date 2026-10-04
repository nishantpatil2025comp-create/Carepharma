-- =============================================================================
-- CarePharma - Marketplace Extension Schema (Orders, Prescriptions, Delivery)
-- Run this SQL in your Supabase Project -> SQL Editor after supabase_schema.sql
-- =============================================================================

-- 1. Orders Table
CREATE TABLE IF NOT EXISTS public.orders (
    "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "order_code" TEXT NOT NULL UNIQUE DEFAULT ('GM-' || upper(substring(gen_random_uuid()::text from 1 for 6))),
    "user_id" UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    "pharmacy_id" UUID REFERENCES public.pharmacies("UID") ON DELETE SET NULL,
    "status" TEXT NOT NULL DEFAULT 'confirmed' CHECK ("status" IN ('confirmed', 'packing', 'out_for_delivery', 'delivered', 'cancelled')),
    "total_amount" NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    "generic_savings" NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    "delivery_address" TEXT NOT NULL DEFAULT 'Baner, Pune, Maharashtra 411045',
    "is_cold_chain" BOOLEAN NOT NULL DEFAULT false,
    "payment_method" TEXT NOT NULL DEFAULT 'UPI',
    "created_at" TIMESTAMPTZ DEFAULT now(),
    "updated_at" TIMESTAMPTZ DEFAULT now()
);

-- 2. Order Items Table
CREATE TABLE IF NOT EXISTS public.order_items (
    "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "order_id" UUID NOT NULL REFERENCES public.orders("id") ON DELETE CASCADE,
    "medicine_name" TEXT NOT NULL,
    "salt_composition" TEXT,
    "is_generic" BOOLEAN NOT NULL DEFAULT true,
    "quantity" INTEGER NOT NULL DEFAULT 1 CHECK ("quantity" > 0),
    "unit_price" NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    "created_at" TIMESTAMPTZ DEFAULT now()
);

-- 3. Prescriptions Table
CREATE TABLE IF NOT EXISTS public.prescriptions (
    "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "user_id" UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    "file_url" TEXT NOT NULL,
    "file_name" TEXT,
    "patient_name" TEXT DEFAULT 'Self',
    "status" TEXT NOT NULL DEFAULT 'submitted' CHECK ("status" IN ('submitted', 'reviewing', 'approved', 'rejected')),
    "doctor_name" TEXT,
    "rejection_reason" TEXT,
    "created_at" TIMESTAMPTZ DEFAULT now(),
    "reviewed_at" TIMESTAMPTZ
);

-- 4. Delivery Runs (Live GPS & Cold-Chain Tracking)
CREATE TABLE IF NOT EXISTS public.delivery_runs (
    "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "order_id" UUID NOT NULL UNIQUE REFERENCES public.orders("id") ON DELETE CASCADE,
    "runner_name" TEXT NOT NULL DEFAULT 'Ramesh Pawar',
    "runner_phone" TEXT NOT NULL DEFAULT '+91 98234 56789',
    "current_lat" DOUBLE PRECISION NOT NULL DEFAULT 18.5590,
    "current_lng" DOUBLE PRECISION NOT NULL DEFAULT 73.7868,
    "temperature_celsius" NUMERIC(4, 1) DEFAULT 4.2,
    "estimated_minutes" INTEGER DEFAULT 18,
    "updated_at" TIMESTAMPTZ DEFAULT now()
);

-- 5. Enable Row Level Security (RLS)
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.prescriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.delivery_runs ENABLE ROW LEVEL SECURITY;

-- 6. RLS Policies for Orders
CREATE POLICY "Users can view their own orders"
    ON public.orders FOR SELECT
    TO authenticated
    USING ("user_id" = auth.uid());

CREATE POLICY "Pharmacies can view assigned orders"
    ON public.orders FOR SELECT
    TO authenticated
    USING ("pharmacy_id" = public.get_current_pharmacy_uid());

CREATE POLICY "Users can create orders"
    ON public.orders FOR INSERT
    TO authenticated
    WITH CHECK ("user_id" = auth.uid());

CREATE POLICY "Pharmacies can update assigned orders status"
    ON public.orders FOR UPDATE
    TO authenticated
    USING ("pharmacy_id" = public.get_current_pharmacy_uid());

-- 7. RLS Policies for Prescriptions
CREATE POLICY "Users can view their own prescriptions"
    ON public.prescriptions FOR SELECT
    TO authenticated
    USING ("user_id" = auth.uid());

CREATE POLICY "Users can upload their own prescriptions"
    ON public.prescriptions FOR INSERT
    TO authenticated
    WITH CHECK ("user_id" = auth.uid());

CREATE POLICY "Pharmacies can view submitted prescriptions"
    ON public.prescriptions FOR SELECT
    TO authenticated
    USING (public.get_current_pharmacy_uid() IS NOT NULL);

-- 8. Enable Supabase Realtime Replication for Live Tracking
-- In Supabase dashboard: Database -> Publications -> supabase_realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
ALTER PUBLICATION supabase_realtime ADD TABLE public.delivery_runs;

-- 9. Storage Buckets (Run in SQL or create in Supabase Storage UI)
-- Insert prescription and license buckets into storage.buckets if using SQL
INSERT INTO storage.buckets (id, name, public)
VALUES ('prescriptions', 'prescriptions', false)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
VALUES ('pharmacy_licenses', 'pharmacy_licenses', false)
ON CONFLICT (id) DO NOTHING;
