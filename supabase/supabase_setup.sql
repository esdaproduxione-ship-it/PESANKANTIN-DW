-- ═══════════════════════════════════════════════════════════════════
--  KANTIN DW ONLINE — Supabase Database Setup
--  Jalankan SELURUH file ini di: Supabase Dashboard → SQL Editor → Run
-- ═══════════════════════════════════════════════════════════════════

-- ── 1. HAPUS trigger lama yang menyebabkan error ─────────────────
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;

-- ── 2. BUAT tabel profiles ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.profiles (
  id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name   TEXT,
  phone       TEXT,
  email       TEXT,
  role        TEXT NOT NULL DEFAULT 'buyer'
                   CHECK (role IN ('buyer','seller','admin')),
  store_id    UUID,                      -- diisi nanti jika seller
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now()
);

-- ── 3. BUAT fungsi trigger yang aman ─────────────────────────────
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
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'phone', ''),
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'role', 'buyer')
  )
  ON CONFLICT (id) DO NOTHING;   -- aman jika dipanggil dua kali
  RETURN NEW;
END;
$$;

-- ── 4. PASANG trigger baru ────────────────────────────────────────
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ── 5. Row Level Security (RLS) ───────────────────────────────────
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Hapus policy lama jika ada
DROP POLICY IF EXISTS "profiles_select_own"  ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_own"  ON public.profiles;
DROP POLICY IF EXISTS "profiles_insert_own"  ON public.profiles;
DROP POLICY IF EXISTS "profiles_admin_all"   ON public.profiles;

-- User bisa baca profil sendiri
CREATE POLICY "profiles_select_own" ON public.profiles
  FOR SELECT USING (auth.uid() = id);

-- User bisa update profil sendiri
CREATE POLICY "profiles_update_own" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

-- Trigger (service role) bisa insert profil baru
CREATE POLICY "profiles_insert_own" ON public.profiles
  FOR INSERT WITH CHECK (auth.uid() = id OR auth.role() = 'service_role');

-- Admin bisa baca semua profil
CREATE POLICY "profiles_admin_all" ON public.profiles
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  );

-- ── 6. TABEL STORES (warung penjual) ─────────────────────────────
CREATE TABLE IF NOT EXISTS public.stores (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_id   UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  description TEXT,
  address     TEXT,
  whatsapp    TEXT,
  qris_url    TEXT,
  jam_buka    TEXT DEFAULT '07:00',
  jam_tutup   TEXT DEFAULT '15:00',
  is_open     BOOLEAN DEFAULT false,
  rating      NUMERIC(3,1) DEFAULT 0,
  total_orders INT DEFAULT 0,
  created_at  TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.stores ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "stores_public_read"   ON public.stores;
DROP POLICY IF EXISTS "stores_seller_write"  ON public.stores;
CREATE POLICY "stores_public_read"  ON public.stores FOR SELECT USING (true);
CREATE POLICY "stores_seller_write" ON public.stores FOR ALL
  USING (seller_id = auth.uid());

-- ── 7. TABEL PRODUCTS ────────────────────────────────────────────
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
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "products_public_read"  ON public.products;
DROP POLICY IF EXISTS "products_seller_write" ON public.products;
CREATE POLICY "products_public_read"  ON public.products FOR SELECT USING (true);
CREATE POLICY "products_seller_write" ON public.products FOR ALL
  USING (store_id IN (SELECT id FROM public.stores WHERE seller_id = auth.uid()));

-- ── 8. TABEL ORDERS ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.orders (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_number    TEXT UNIQUE NOT NULL,
  buyer_id        UUID REFERENCES public.profiles(id),
  store_id        UUID REFERENCES public.stores(id),
  status          TEXT DEFAULT 'pending'
                       CHECK (status IN ('pending','confirmed','processing','ready','delivering','completed','cancelled')),
  subtotal        INT NOT NULL,
  ongkir          INT DEFAULT 0,
  total           INT NOT NULL,
  payment_method  TEXT DEFAULT 'cash_pickup',
  delivery_method TEXT DEFAULT 'pickup',
  buyer_notes     TEXT,
  created_at      TIMESTAMPTZ DEFAULT now(),
  updated_at      TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "orders_buyer_own"   ON public.orders;
DROP POLICY IF EXISTS "orders_seller_own"  ON public.orders;
DROP POLICY IF EXISTS "orders_admin_all"   ON public.orders;
CREATE POLICY "orders_buyer_own"  ON public.orders FOR ALL
  USING (buyer_id = auth.uid());
CREATE POLICY "orders_seller_own" ON public.orders FOR ALL
  USING (store_id IN (SELECT id FROM public.stores WHERE seller_id = auth.uid()));
CREATE POLICY "orders_admin_all"  ON public.orders FOR ALL
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id=auth.uid() AND role='admin'));

-- ── 9. TABEL ORDER ITEMS ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.order_items (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id      UUID REFERENCES public.orders(id) ON DELETE CASCADE,
  product_id    UUID REFERENCES public.products(id),
  product_name  TEXT NOT NULL,
  product_price INT NOT NULL,
  quantity      INT NOT NULL DEFAULT 1
);
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "order_items_via_order" ON public.order_items FOR ALL
  USING (order_id IN (
    SELECT id FROM public.orders
    WHERE buyer_id = auth.uid()
       OR store_id IN (SELECT id FROM public.stores WHERE seller_id = auth.uid())
  ));

-- ── 10. TABEL ULASAN ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.ulasan (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id    UUID REFERENCES public.orders(id),
  buyer_id    UUID REFERENCES public.profiles(id),
  store_id    UUID REFERENCES public.stores(id),
  produk      INT CHECK (produk BETWEEN 1 AND 5),
  penjual     INT CHECK (penjual BETWEEN 1 AND 5),
  kirim       INT CHECK (kirim BETWEEN 1 AND 5),
  layanan     INT CHECK (layanan BETWEEN 1 AND 5),
  thumb       JSONB,
  komentar    TEXT,
  created_at  TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.ulasan ENABLE ROW LEVEL SECURITY;
CREATE POLICY "ulasan_public_read"   ON public.ulasan FOR SELECT USING (true);
CREATE POLICY "ulasan_buyer_insert"  ON public.ulasan FOR INSERT
  WITH CHECK (buyer_id = auth.uid());

-- ── 11. TABEL IURAN ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.iuran (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id    UUID REFERENCES public.stores(id),
  jenis       TEXT CHECK (jenis IN ('sewa','komisi')),
  periode     TEXT,            -- format YYYY-MM
  jumlah      INT NOT NULL,
  status      TEXT DEFAULT 'belum' CHECK (status IN ('belum','lunas')),
  bayar_at    DATE,
  created_at  TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.iuran ENABLE ROW LEVEL SECURITY;
CREATE POLICY "iuran_seller_read" ON public.iuran FOR SELECT
  USING (store_id IN (SELECT id FROM public.stores WHERE seller_id = auth.uid()));
CREATE POLICY "iuran_admin_all"   ON public.iuran FOR ALL
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id=auth.uid() AND role='admin'));

-- ── 12. BUAT AKUN ADMIN (jalankan SEKALI saja) ───────────────────
-- Ganti email & password sesuai kebutuhan Anda
-- CATATAN: Cara ini lebih aman dari dashboard karena melewati trigger dengan benar

INSERT INTO auth.users (
  id,
  instance_id,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at,
  role,
  aud
)
SELECT
  gen_random_uuid(),
  '00000000-0000-0000-0000-000000000000',
  'admin@kantindw.id',           -- ← GANTI email admin
  crypt('AdminKantin2025!', gen_salt('bf')),  -- ← GANTI password admin
  now(),
  '{"provider":"email","providers":["email"]}',
  '{"full_name":"Admin Kantin DW","role":"admin"}',
  now(),
  now(),
  'authenticated',
  'authenticated'
WHERE NOT EXISTS (
  SELECT 1 FROM auth.users WHERE email = 'admin@kantindw.id'
);

-- ── 13. VERIFIKASI ────────────────────────────────────────────────
SELECT 'profiles table'  AS tabel, count(*) AS jumlah FROM public.profiles
UNION ALL
SELECT 'stores',   count(*) FROM public.stores
UNION ALL
SELECT 'products', count(*) FROM public.products
UNION ALL
SELECT 'orders',   count(*) FROM public.orders
UNION ALL
SELECT 'ulasan',   count(*) FROM public.ulasan
UNION ALL
SELECT 'iuran',    count(*) FROM public.iuran;

-- ════════════════════════════════════════════════════════════════════
--  SELESAI — Jika ada error "permission denied for table users"
--  pada baris INSERT auth.users, gunakan cara alternatif:
--  Supabase Dashboard → Authentication → Users → Add user
--  lalu UPDATE profiles SET role='admin' WHERE email='admin@kantindw.id';
-- ════════════════════════════════════════════════════════════════════
