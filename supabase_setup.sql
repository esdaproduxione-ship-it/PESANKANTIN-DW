-- ═══════════════════════════════════════════════════════════════════
--  KANTIN DW ONLINE — Supabase Database Setup (v2 — Fixed)
--  Jalankan di: Supabase Dashboard → SQL Editor → New Query → Run
--  Aman dijalankan berulang kali (idempotent)
-- ═══════════════════════════════════════════════════════════════════

-- ── LANGKAH 0: Hapus semua policy & trigger lama ─────────────────
-- (agar tidak konflik saat tabel sudah ada sebagian)

DROP TRIGGER  IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;

-- Hapus policy lama semua tabel (aman jika belum ada)
DO $$ DECLARE r RECORD;
BEGIN
  FOR r IN SELECT policyname, tablename FROM pg_policies WHERE schemaname = 'public'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', r.policyname, r.tablename);
  END LOOP;
END $$;

-- ── LANGKAH 1: Tabel PROFILES ────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.profiles (
  id         UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name  TEXT,
  phone      TEXT,
  email      TEXT,
  role       TEXT NOT NULL DEFAULT 'buyer'
                  CHECK (role IN ('buyer','seller','admin')),
  store_id   UUID,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ── LANGKAH 2: Tabel STORES ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.stores (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name         TEXT NOT NULL,
  description  TEXT,
  address      TEXT,
  whatsapp     TEXT,
  qris_url     TEXT,
  jam_buka     TEXT DEFAULT '07:00',
  jam_tutup    TEXT DEFAULT '15:00',
  is_open      BOOLEAN DEFAULT false,
  rating       NUMERIC(3,1) DEFAULT 0,
  total_orders INT DEFAULT 0,
  created_at   TIMESTAMPTZ DEFAULT now()
);

-- Tambah kolom seller_id jika belum ada (fix error utama)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='stores' AND column_name='seller_id'
  ) THEN
    ALTER TABLE public.stores
      ADD COLUMN seller_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;
  END IF;
END $$;

-- ── LANGKAH 3: Tabel PRODUCTS ────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.products (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id    UUID REFERENCES public.stores(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  description TEXT,
  price       INT NOT NULL,
  stock       INT DEFAULT -1,
  status      TEXT DEFAULT 'active' CHECK (status IN ('active','inactive')),
  image_url   TEXT,
  category    TEXT,
  total_sold  INT DEFAULT 0,
  rating      NUMERIC(3,1) DEFAULT 0,
  created_at  TIMESTAMPTZ DEFAULT now()
);

-- ── LANGKAH 4: Tabel ORDERS ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.orders (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_number    TEXT UNIQUE NOT NULL,
  buyer_id        UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  store_id        UUID REFERENCES public.stores(id) ON DELETE SET NULL,
  status          TEXT DEFAULT 'pending'
                       CHECK (status IN ('pending','confirmed','processing',
                                         'ready','delivering','completed','cancelled')),
  subtotal        INT NOT NULL DEFAULT 0,
  ongkir          INT DEFAULT 0,
  total           INT NOT NULL DEFAULT 0,
  payment_method  TEXT DEFAULT 'cash_pickup',
  delivery_method TEXT DEFAULT 'pickup',
  buyer_notes     TEXT,
  created_at      TIMESTAMPTZ DEFAULT now(),
  updated_at      TIMESTAMPTZ DEFAULT now()
);

-- ── LANGKAH 5: Tabel ORDER_ITEMS ─────────────────────────────────
CREATE TABLE IF NOT EXISTS public.order_items (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id      UUID REFERENCES public.orders(id) ON DELETE CASCADE,
  product_id    UUID REFERENCES public.products(id) ON DELETE SET NULL,
  product_name  TEXT NOT NULL,
  product_price INT NOT NULL,
  quantity      INT NOT NULL DEFAULT 1
);

-- ── LANGKAH 6: Tabel ULASAN ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.ulasan (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id   UUID REFERENCES public.orders(id) ON DELETE SET NULL,
  buyer_id   UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  store_id   UUID REFERENCES public.stores(id) ON DELETE SET NULL,
  produk     INT CHECK (produk BETWEEN 1 AND 5),
  penjual    INT CHECK (penjual BETWEEN 1 AND 5),
  kirim      INT CHECK (kirim BETWEEN 1 AND 5),
  layanan    INT CHECK (layanan BETWEEN 1 AND 5),
  thumb      JSONB,
  komentar   TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ── LANGKAH 7: Tabel IURAN ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.iuran (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id   UUID REFERENCES public.stores(id) ON DELETE CASCADE,
  jenis      TEXT CHECK (jenis IN ('sewa','komisi')),
  periode    TEXT,
  jumlah     INT NOT NULL,
  status     TEXT DEFAULT 'belum' CHECK (status IN ('belum','lunas')),
  bayar_at   DATE,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ── LANGKAH 8: Tabel JADWAL_LIBUR (libur mandiri penjual) ────────
CREATE TABLE IF NOT EXISTS public.jadwal_libur (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id   UUID REFERENCES public.stores(id) ON DELETE CASCADE,
  tanggal    DATE NOT NULL,
  keterangan TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (store_id, tanggal)
);

-- ── LANGKAH 9: Trigger handle_new_user (aman) ────────────────────
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, phone, email, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email,'@',1)),
    COALESCE(NEW.raw_user_meta_data->>'phone', ''),
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'role', 'buyer')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ── LANGKAH 10: Aktifkan RLS semua tabel ─────────────────────────
ALTER TABLE public.profiles     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stores       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ulasan       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.iuran        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.jadwal_libur ENABLE ROW LEVEL SECURITY;

-- ── LANGKAH 11: Policy PROFILES ──────────────────────────────────
CREATE POLICY "p_profiles_select_own" ON public.profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "p_profiles_update_own" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "p_profiles_insert_trigger" ON public.profiles
  FOR INSERT WITH CHECK (true);  -- trigger pakai service_role, harus bisa insert

CREATE POLICY "p_profiles_admin_all" ON public.profiles
  FOR ALL USING (
    (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
  );

-- ── LANGKAH 12: Policy STORES ────────────────────────────────────
CREATE POLICY "p_stores_public_read" ON public.stores
  FOR SELECT USING (true);

CREATE POLICY "p_stores_seller_write" ON public.stores
  FOR ALL USING (seller_id = auth.uid());

CREATE POLICY "p_stores_admin_all" ON public.stores
  FOR ALL USING (
    (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
  );

-- ── LANGKAH 13: Policy PRODUCTS ──────────────────────────────────
CREATE POLICY "p_products_public_read" ON public.products
  FOR SELECT USING (true);

CREATE POLICY "p_products_seller_write" ON public.products
  FOR ALL USING (
    store_id IN (SELECT id FROM public.stores WHERE seller_id = auth.uid())
  );

CREATE POLICY "p_products_admin_all" ON public.products
  FOR ALL USING (
    (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
  );

-- ── LANGKAH 14: Policy ORDERS ────────────────────────────────────
CREATE POLICY "p_orders_buyer_own" ON public.orders
  FOR ALL USING (buyer_id = auth.uid());

CREATE POLICY "p_orders_seller_own" ON public.orders
  FOR ALL USING (
    store_id IN (SELECT id FROM public.stores WHERE seller_id = auth.uid())
  );

CREATE POLICY "p_orders_admin_all" ON public.orders
  FOR ALL USING (
    (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
  );

-- ── LANGKAH 15: Policy ORDER_ITEMS ───────────────────────────────
CREATE POLICY "p_order_items_access" ON public.order_items
  FOR ALL USING (
    order_id IN (
      SELECT id FROM public.orders
      WHERE buyer_id = auth.uid()
         OR store_id IN (SELECT id FROM public.stores WHERE seller_id = auth.uid())
    )
  );

CREATE POLICY "p_order_items_admin" ON public.order_items
  FOR ALL USING (
    (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
  );

-- ── LANGKAH 16: Policy ULASAN ────────────────────────────────────
CREATE POLICY "p_ulasan_public_read" ON public.ulasan
  FOR SELECT USING (true);

CREATE POLICY "p_ulasan_buyer_insert" ON public.ulasan
  FOR INSERT WITH CHECK (buyer_id = auth.uid());

CREATE POLICY "p_ulasan_admin_all" ON public.ulasan
  FOR ALL USING (
    (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
  );

-- ── LANGKAH 17: Policy IURAN ─────────────────────────────────────
CREATE POLICY "p_iuran_seller_read" ON public.iuran
  FOR SELECT USING (
    store_id IN (SELECT id FROM public.stores WHERE seller_id = auth.uid())
  );

CREATE POLICY "p_iuran_admin_all" ON public.iuran
  FOR ALL USING (
    (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
  );

-- ── LANGKAH 18: Policy JADWAL_LIBUR ──────────────────────────────
CREATE POLICY "p_jadwal_seller_all" ON public.jadwal_libur
  FOR ALL USING (
    store_id IN (SELECT id FROM public.stores WHERE seller_id = auth.uid())
  );

-- ═══════════════════════════════════════════════════════════════════
--  BUAT AKUN ADMIN
--  CARA PALING AMAN & MUDAH:
--
--  1. Supabase Dashboard → Authentication → Users → [Add user]
--     Isi email & password → Create user
--
--  2. Setelah user terbuat, jalankan query ini di SQL Editor:
--     (ganti email sesuai yang Anda daftarkan)
-- ═══════════════════════════════════════════════════════════════════

-- UPDATE public.profiles
-- SET role = 'admin', full_name = 'Admin Kantin DW'
-- WHERE email = 'admin@kantindw.id';   -- ← ganti email Anda

-- ═══════════════════════════════════════════════════════════════════
--  VERIFIKASI — hasil query ini harus muncul semua tabel
-- ═══════════════════════════════════════════════════════════════════
SELECT
  table_name               AS "Tabel",
  (SELECT count(*) FROM information_schema.columns c
   WHERE c.table_schema='public' AND c.table_name=t.table_name) AS "Kolom"
FROM information_schema.tables t
WHERE table_schema = 'public'
  AND table_type   = 'BASE TABLE'
ORDER BY table_name;
