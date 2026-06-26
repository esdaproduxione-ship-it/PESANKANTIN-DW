-- ============================================================
-- KANTIN DW ONLINE - Complete Supabase Schema
-- ============================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ============================================================
-- ENUMS
-- ============================================================

CREATE TYPE user_role AS ENUM ('admin', 'seller', 'buyer');
CREATE TYPE order_status AS ENUM (
  'pending', 'confirmed', 'processing', 'ready', 'delivering', 'completed', 'cancelled'
);
CREATE TYPE payment_method AS ENUM ('qris', 'cod', 'cash_pickup');
CREATE TYPE delivery_method AS ENUM ('pickup', 'delivery');
CREATE TYPE payment_status AS ENUM ('pending', 'paid', 'failed', 'refunded');
CREATE TYPE product_status AS ENUM ('active', 'inactive', 'out_of_stock');
CREATE TYPE promo_type AS ENUM ('discount_percent', 'discount_fixed', 'bundle', 'flash_sale');

-- ============================================================
-- PROFILES (extends Supabase Auth users)
-- ============================================================

CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  phone TEXT UNIQUE,
  avatar_url TEXT,
  role user_role NOT NULL DEFAULT 'buyer',
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_profiles_role ON profiles(role);
CREATE INDEX idx_profiles_phone ON profiles(phone);

-- ============================================================
-- STORES (Warung)
-- ============================================================

CREATE TABLE stores (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  owner_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  description TEXT,
  logo_url TEXT,
  banner_url TEXT,
  whatsapp TEXT,
  address TEXT,
  qris_image_url TEXT,
  is_open BOOLEAN DEFAULT FALSE,
  is_active BOOLEAN DEFAULT TRUE,
  rating NUMERIC(3,2) DEFAULT 0,
  total_orders INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_stores_owner ON stores(owner_id);
CREATE INDEX idx_stores_slug ON stores(slug);
CREATE INDEX idx_stores_active ON stores(is_active, is_open);

-- Store operating hours
CREATE TABLE store_hours (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  day_of_week INTEGER NOT NULL CHECK (day_of_week BETWEEN 0 AND 6), -- 0=Sunday
  open_time TIME,
  close_time TIME,
  is_closed BOOLEAN DEFAULT FALSE,
  UNIQUE(store_id, day_of_week)
);

-- ============================================================
-- CATEGORIES
-- ============================================================

CREATE TABLE categories (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL UNIQUE,
  icon TEXT,
  sort_order INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO categories (name, icon, sort_order) VALUES
  ('Makanan Berat', '🍚', 1),
  ('Mie & Bakso', '🍜', 2),
  ('Gorengan & Snack', '🍟', 3),
  ('Minuman', '🥤', 4),
  ('Kue & Dessert', '🍰', 5),
  ('Nasi Box', '📦', 6),
  ('Sarapan', '🍳', 7),
  ('Lainnya', '🍽️', 8);

-- ============================================================
-- PRODUCTS
-- ============================================================

CREATE TABLE products (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  description TEXT,
  price NUMERIC(12,2) NOT NULL CHECK (price >= 0),
  image_url TEXT,
  stock INTEGER DEFAULT -1, -- -1 = unlimited
  status product_status DEFAULT 'active',
  is_featured BOOLEAN DEFAULT FALSE,
  total_sold INTEGER DEFAULT 0,
  rating NUMERIC(3,2) DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_products_store ON products(store_id);
CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_products_status ON products(status);
CREATE INDEX idx_products_name_trgm ON products USING gin(name gin_trgm_ops);

-- ============================================================
-- PROMOS
-- ============================================================

CREATE TABLE promos (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  store_id UUID REFERENCES stores(id) ON DELETE CASCADE, -- NULL = global promo
  code TEXT UNIQUE,
  name TEXT NOT NULL,
  type promo_type NOT NULL,
  value NUMERIC(12,2) NOT NULL,
  min_order NUMERIC(12,2) DEFAULT 0,
  max_discount NUMERIC(12,2),
  start_date TIMESTAMPTZ,
  end_date TIMESTAMPTZ,
  usage_limit INTEGER,
  used_count INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_promos_store ON promos(store_id);
CREATE INDEX idx_promos_code ON promos(code);

-- ============================================================
-- BANNERS
-- ============================================================

CREATE TABLE banners (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT,
  image_url TEXT NOT NULL,
  link TEXT,
  sort_order INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- ORDERS
-- ============================================================

CREATE TABLE orders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_number TEXT UNIQUE NOT NULL,
  buyer_id UUID NOT NULL REFERENCES profiles(id),
  store_id UUID NOT NULL REFERENCES stores(id),
  status order_status DEFAULT 'pending',
  subtotal NUMERIC(12,2) NOT NULL,
  discount NUMERIC(12,2) DEFAULT 0,
  delivery_fee NUMERIC(12,2) DEFAULT 0,
  total NUMERIC(12,2) NOT NULL,
  payment_method payment_method NOT NULL,
  payment_status payment_status DEFAULT 'pending',
  delivery_method delivery_method NOT NULL,
  delivery_address TEXT,
  buyer_notes TEXT,
  seller_notes TEXT,
  promo_id UUID REFERENCES promos(id),
  cancelled_reason TEXT,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_orders_buyer ON orders(buyer_id);
CREATE INDEX idx_orders_store ON orders(store_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_number ON orders(order_number);
CREATE INDEX idx_orders_created ON orders(created_at DESC);

-- ============================================================
-- ORDER ITEMS
-- ============================================================

CREATE TABLE order_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  product_id UUID REFERENCES products(id) ON DELETE SET NULL,
  product_name TEXT NOT NULL,
  product_price NUMERIC(12,2) NOT NULL,
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  subtotal NUMERIC(12,2) NOT NULL,
  notes TEXT
);

CREATE INDEX idx_order_items_order ON order_items(order_id);

-- ============================================================
-- ORDER STATUS HISTORY
-- ============================================================

CREATE TABLE order_status_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  status order_status NOT NULL,
  notes TEXT,
  changed_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_order_history_order ON order_status_history(order_id);

-- ============================================================
-- REVIEWS
-- ============================================================

CREATE TABLE reviews (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID UNIQUE NOT NULL REFERENCES orders(id),
  buyer_id UUID NOT NULL REFERENCES profiles(id),
  store_id UUID NOT NULL REFERENCES stores(id),
  product_id UUID REFERENCES products(id),
  rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_reviews_store ON reviews(store_id);
CREATE INDEX idx_reviews_product ON reviews(product_id);

-- ============================================================
-- FAVORITES
-- ============================================================

CREATE TABLE favorites (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  buyer_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(buyer_id, product_id)
);

-- ============================================================
-- NOTIFICATIONS
-- ============================================================

CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  type TEXT,
  data JSONB,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_notifications_user ON notifications(user_id, is_read);

-- ============================================================
-- AUDIT LOG
-- ============================================================

CREATE TABLE audit_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES profiles(id),
  action TEXT NOT NULL,
  table_name TEXT,
  record_id TEXT,
  old_data JSONB,
  new_data JSONB,
  ip_address INET,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_created ON audit_logs(created_at DESC);

-- ============================================================
-- VIEWS
-- ============================================================

-- Dashboard stats view for admin
CREATE OR REPLACE VIEW admin_dashboard_stats AS
SELECT
  (SELECT COUNT(*) FROM profiles WHERE role = 'seller') AS total_sellers,
  (SELECT COUNT(*) FROM profiles WHERE role = 'buyer') AS total_buyers,
  (SELECT COUNT(*) FROM orders WHERE status = 'completed') AS total_orders,
  (SELECT COALESCE(SUM(total), 0) FROM orders WHERE status = 'completed') AS total_revenue,
  (SELECT COUNT(*) FROM orders WHERE status = 'completed' AND DATE(created_at) = CURRENT_DATE) AS today_orders,
  (SELECT COALESCE(SUM(total), 0) FROM orders WHERE status = 'completed' AND DATE(created_at) = CURRENT_DATE) AS today_revenue;

-- Seller dashboard stats view
CREATE OR REPLACE VIEW seller_dashboard_stats AS
SELECT
  s.id AS store_id,
  s.name AS store_name,
  COUNT(CASE WHEN o.status = 'pending' THEN 1 END) AS pending_orders,
  COUNT(CASE WHEN o.status IN ('confirmed','processing') THEN 1 END) AS processing_orders,
  COUNT(CASE WHEN o.status = 'completed' THEN 1 END) AS completed_orders,
  COALESCE(SUM(CASE WHEN o.status = 'completed' AND DATE(o.created_at) = CURRENT_DATE THEN o.total END), 0) AS today_revenue,
  COALESCE(SUM(CASE WHEN o.status = 'completed' AND DATE_TRUNC('month', o.created_at) = DATE_TRUNC('month', NOW()) THEN o.total END), 0) AS month_revenue
FROM stores s
LEFT JOIN orders o ON o.store_id = s.id
GROUP BY s.id, s.name;

-- Popular products view
CREATE OR REPLACE VIEW popular_products AS
SELECT
  p.*,
  s.name AS store_name,
  c.name AS category_name
FROM products p
JOIN stores s ON s.id = p.store_id
LEFT JOIN categories c ON c.id = p.category_id
WHERE p.status = 'active' AND s.is_active = TRUE
ORDER BY p.total_sold DESC;

-- ============================================================
-- FUNCTIONS
-- ============================================================

-- Auto-generate order number
CREATE OR REPLACE FUNCTION generate_order_number()
RETURNS TEXT AS $$
DECLARE
  v_date TEXT;
  v_seq INTEGER;
  v_number TEXT;
BEGIN
  v_date := TO_CHAR(NOW(), 'YYYYMMDD');
  SELECT COUNT(*) + 1 INTO v_seq
  FROM orders
  WHERE DATE(created_at) = CURRENT_DATE;
  v_number := 'ORD-' || v_date || '-' || LPAD(v_seq::TEXT, 4, '0');
  RETURN v_number;
END;
$$ LANGUAGE plpgsql;

-- Update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Update product total_sold and rating after order completion
CREATE OR REPLACE FUNCTION update_product_stats()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
    UPDATE products p
    SET total_sold = total_sold + oi.quantity
    FROM order_items oi
    WHERE oi.order_id = NEW.id AND oi.product_id = p.id;
    
    UPDATE stores
    SET total_orders = total_orders + 1
    WHERE id = NEW.store_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Update store and product rating after review
CREATE OR REPLACE FUNCTION update_ratings()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE stores
  SET rating = (
    SELECT ROUND(AVG(rating)::NUMERIC, 2)
    FROM reviews WHERE store_id = NEW.store_id
  )
  WHERE id = NEW.store_id;

  IF NEW.product_id IS NOT NULL THEN
    UPDATE products
    SET rating = (
      SELECT ROUND(AVG(rating)::NUMERIC, 2)
      FROM reviews WHERE product_id = NEW.product_id
    )
    WHERE id = NEW.product_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create profile on user signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, full_name, phone, avatar_url, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'Pengguna Baru'),
    NEW.phone,
    NEW.raw_user_meta_data->>'avatar_url',
    COALESCE((NEW.raw_user_meta_data->>'role')::user_role, 'buyer')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- TRIGGERS
-- ============================================================

CREATE TRIGGER trg_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_stores_updated_at
  BEFORE UPDATE ON stores
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_products_updated_at
  BEFORE UPDATE ON products
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_orders_updated_at
  BEFORE UPDATE ON orders
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_order_status_stats
  AFTER UPDATE ON orders
  FOR EACH ROW EXECUTE FUNCTION update_product_stats();

CREATE TRIGGER trg_review_ratings
  AFTER INSERT ON reviews
  FOR EACH ROW EXECUTE FUNCTION update_ratings();

CREATE TRIGGER trg_new_user_profile
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE stores ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- PROFILES policies
CREATE POLICY "Public profiles visible to all" ON profiles FOR SELECT USING (TRUE);
CREATE POLICY "Users update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Admin full access profiles" ON profiles FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

-- STORES policies
CREATE POLICY "Stores visible to all" ON stores FOR SELECT USING (TRUE);
CREATE POLICY "Seller manages own store" ON stores FOR ALL USING (owner_id = auth.uid());
CREATE POLICY "Admin full access stores" ON stores FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

-- PRODUCTS policies
CREATE POLICY "Products visible to all" ON products FOR SELECT USING (TRUE);
CREATE POLICY "Seller manages own products" ON products FOR ALL USING (
  store_id IN (SELECT id FROM stores WHERE owner_id = auth.uid())
);
CREATE POLICY "Admin full access products" ON products FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

-- ORDERS policies
CREATE POLICY "Buyer sees own orders" ON orders FOR SELECT USING (buyer_id = auth.uid());
CREATE POLICY "Seller sees store orders" ON orders FOR SELECT USING (
  store_id IN (SELECT id FROM stores WHERE owner_id = auth.uid())
);
CREATE POLICY "Buyer creates order" ON orders FOR INSERT WITH CHECK (buyer_id = auth.uid());
CREATE POLICY "Seller updates order status" ON orders FOR UPDATE USING (
  store_id IN (SELECT id FROM stores WHERE owner_id = auth.uid())
);
CREATE POLICY "Admin full access orders" ON orders FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

-- ORDER ITEMS policies
CREATE POLICY "Order items visible to order parties" ON order_items FOR SELECT USING (
  order_id IN (
    SELECT id FROM orders WHERE buyer_id = auth.uid()
    UNION
    SELECT o.id FROM orders o JOIN stores s ON s.id = o.store_id WHERE s.owner_id = auth.uid()
  )
);
CREATE POLICY "Buyer creates order items" ON order_items FOR INSERT WITH CHECK (
  order_id IN (SELECT id FROM orders WHERE buyer_id = auth.uid())
);

-- REVIEWS policies
CREATE POLICY "Reviews visible to all" ON reviews FOR SELECT USING (TRUE);
CREATE POLICY "Buyer creates own review" ON reviews FOR INSERT WITH CHECK (buyer_id = auth.uid());

-- FAVORITES policies
CREATE POLICY "Buyer manages own favorites" ON favorites FOR ALL USING (buyer_id = auth.uid());

-- NOTIFICATIONS policies
CREATE POLICY "User sees own notifications" ON notifications FOR ALL USING (user_id = auth.uid());

-- ============================================================
-- STORAGE BUCKETS (run via Supabase Dashboard or API)
-- ============================================================
-- INSERT INTO storage.buckets (id, name, public) VALUES ('avatars', 'avatars', true);
-- INSERT INTO storage.buckets (id, name, public) VALUES ('products', 'products', true);
-- INSERT INTO storage.buckets (id, name, public) VALUES ('stores', 'stores', true);
-- INSERT INTO storage.buckets (id, name, public) VALUES ('banners', 'banners', true);
-- INSERT INTO storage.buckets (id, name, public) VALUES ('qris', 'qris', true);
