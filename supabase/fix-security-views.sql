-- ============================================================
-- FIX: Security Definer View
-- Jalankan di SQL Editor Supabase
-- ============================================================
-- Masalah: view implisit menggunakan SECURITY DEFINER,
-- sehingga RLS user diabaikan dan query berjalan dengan hak
-- akses pemilik view (superuser/postgres).
-- Solusi: tambahkan security_invoker = true agar view
-- menghormati RLS dan permission user yang sedang login.
-- ============================================================

-- ── 1. admin_dashboard_stats ──────────────────────────────
-- View ini hanya boleh diakses oleh admin.
-- Dengan security_invoker, RLS pada tabel orders dan profiles
-- tetap berlaku saat view di-query.

DROP VIEW IF EXISTS public.admin_dashboard_stats;

CREATE VIEW public.admin_dashboard_stats
WITH (security_invoker = true)
AS
SELECT
  (SELECT COUNT(*) FROM profiles WHERE role = 'seller')                AS total_sellers,
  (SELECT COUNT(*) FROM profiles WHERE role = 'buyer')                 AS total_buyers,
  (SELECT COUNT(*) FROM orders  WHERE status = 'completed')            AS total_orders,
  (SELECT COALESCE(SUM(total), 0) FROM orders WHERE status = 'completed') AS total_revenue,
  (SELECT COUNT(*) FROM orders
     WHERE status = 'completed'
       AND DATE(created_at) = CURRENT_DATE)                            AS today_orders,
  (SELECT COALESCE(SUM(total), 0) FROM orders
     WHERE status = 'completed'
       AND DATE(created_at) = CURRENT_DATE)                            AS today_revenue;

-- Hanya admin yang boleh SELECT view ini
REVOKE ALL ON public.admin_dashboard_stats FROM anon, authenticated;
GRANT SELECT ON public.admin_dashboard_stats TO authenticated;

COMMENT ON VIEW public.admin_dashboard_stats IS
  'Statistik ringkasan untuk dashboard admin. Hanya bisa diakses user dengan role admin (dikontrol RLS di tabel sumber).';


-- ── 2. seller_dashboard_stats ─────────────────────────────
-- View ini di-query per penjual. Dengan security_invoker,
-- RLS pada tabel stores dan orders tetap aktif,
-- sehingga penjual hanya bisa lihat data warungnya sendiri.

DROP VIEW IF EXISTS public.seller_dashboard_stats;

CREATE VIEW public.seller_dashboard_stats
WITH (security_invoker = true)
AS
SELECT
  s.id                                                                  AS store_id,
  s.name                                                                AS store_name,
  s.owner_id,
  COUNT(CASE WHEN o.status = 'pending'                    THEN 1 END)  AS pending_orders,
  COUNT(CASE WHEN o.status IN ('confirmed','processing')  THEN 1 END)  AS processing_orders,
  COUNT(CASE WHEN o.status = 'ready'                      THEN 1 END)  AS ready_orders,
  COUNT(CASE WHEN o.status = 'completed'                  THEN 1 END)  AS completed_orders,
  COALESCE(SUM(
    CASE WHEN o.status = 'completed'
          AND DATE(o.created_at) = CURRENT_DATE
    THEN o.total END
  ), 0)                                                                 AS today_revenue,
  COALESCE(SUM(
    CASE WHEN o.status = 'completed'
          AND DATE_TRUNC('month', o.created_at) = DATE_TRUNC('month', NOW())
    THEN o.total END
  ), 0)                                                                 AS month_revenue
FROM stores s
LEFT JOIN orders o ON o.store_id = s.id
GROUP BY s.id, s.name, s.owner_id;

-- Hanya authenticated user yang bisa akses
-- (RLS pada tabel stores membatasi penjual ke warungnya sendiri)
REVOKE ALL ON public.seller_dashboard_stats FROM anon, authenticated;
GRANT SELECT ON public.seller_dashboard_stats TO authenticated;

COMMENT ON VIEW public.seller_dashboard_stats IS
  'Statistik per warung untuk dashboard penjual. RLS pada tabel stores memastikan penjual hanya melihat warungnya sendiri.';


-- ── 3. popular_products ───────────────────────────────────
-- View publik — siapa pun (termasuk pengunjung belum login)
-- boleh melihat produk populer. security_invoker tetap
-- diperlukan agar konsisten dan RLS tabel sumber dihormati.

DROP VIEW IF EXISTS public.popular_products;

CREATE VIEW public.popular_products
WITH (security_invoker = true)
AS
SELECT
  p.id,
  p.store_id,
  p.category_id,
  p.name,
  p.description,
  p.price,
  p.image_url,
  p.stock,
  p.status,
  p.is_featured,
  p.total_sold,
  p.rating,
  p.created_at,
  p.updated_at,
  s.name   AS store_name,
  s.slug   AS store_slug,
  s.is_open AS store_is_open,
  c.name   AS category_name,
  c.icon   AS category_icon
FROM products p
JOIN stores     s ON s.id = p.store_id
LEFT JOIN categories c ON c.id = p.category_id
WHERE p.status    = 'active'
  AND s.is_active = TRUE
ORDER BY p.total_sold DESC;

-- Bisa diakses siapa pun (produk publik)
REVOKE ALL ON public.popular_products FROM anon, authenticated;
GRANT SELECT ON public.popular_products TO anon, authenticated;

COMMENT ON VIEW public.popular_products IS
  'Daftar produk aktif diurutkan berdasarkan total terjual. Dapat diakses publik.';


-- ── Verifikasi ────────────────────────────────────────────
-- Jalankan query ini untuk memastikan security_invoker = true
SELECT
  viewname,
  definition
FROM pg_views
WHERE schemaname = 'public'
  AND viewname IN (
    'admin_dashboard_stats',
    'seller_dashboard_stats',
    'popular_products'
  );

-- Cek security_invoker via pg_class (harus reloptions berisi 'security_invoker=true')
SELECT
  relname                            AS view_name,
  reloptions                         AS options
FROM pg_class
WHERE relname IN (
    'admin_dashboard_stats',
    'seller_dashboard_stats',
    'popular_products'
  )
  AND relkind = 'v';
