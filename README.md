# 🍽️ Kantin DW Online

**Aplikasi pemesanan makanan online untuk Kantin Dharma Wanita**

Menghubungkan penjual kantin dengan pembeli dari lingkungan perkantoran, sekolah, rumah sakit, dan kampus.

[![Deploy with Vercel](https://vercel.com/button)](https://vercel.com/new/clone?repository-url=https://github.com/USERNAME/kantin-dw-online)

---

## ✨ Fitur Utama

| Fitur | Pembeli | Penjual | Admin |
|-------|---------|---------|-------|
| Dashboard | ✅ | ✅ | ✅ |
| Kelola produk | ❌ | ✅ | ✅ |
| Pesan makanan | ✅ | ❌ | ❌ |
| Notifikasi WA | ✅ | ✅ | ❌ |
| Laporan | ❌ | ✅ | ✅ |
| Manajemen user | ❌ | ❌ | ✅ |

## 📱 Platform yang Didukung

- ✅ Android (Browser + PWA + APK)
- ✅ iPhone (Browser + PWA)
- ✅ PC/Laptop (Browser)
- ✅ Offline mode (via Service Worker)

## 🛠️ Tech Stack

- **Frontend**: HTML5, Tailwind CSS, Vanilla JavaScript
- **Backend**: Supabase (PostgreSQL + Auth + Storage + Edge Functions)
- **Hosting**: Vercel + GitHub
- **Notifikasi**: WhatsApp (Fonnte) + Web Push Notification
- **PWA**: Service Worker + Web App Manifest

## 🚀 Deploy Cepat

Lihat [PANDUAN-DEPLOY.md](./PANDUAN-DEPLOY.md) untuk panduan lengkap.

**Ringkasan:**
1. Buat project di [supabase.com](https://supabase.com)
2. Jalankan `supabase/schema.sql`
3. Fork/clone repo ini ke GitHub
4. Import ke [vercel.com](https://vercel.com)
5. Set environment variables
6. Deploy! ✅

## 📁 Struktur Project

```
kantin-dw-online/
├── index.html              # Aplikasi utama (semua halaman)
├── manifest.json           # PWA manifest
├── sw.js                   # Service Worker
├── vercel.json             # Konfigurasi Vercel
├── .env.example            # Template environment variables
├── icons/                  # Ikon PWA semua ukuran
├── supabase/
│   ├── schema.sql          # SQL schema lengkap
│   └── functions/
│       └── send-whatsapp/  # Edge function notifikasi WA
└── PANDUAN-DEPLOY.md       # Panduan deploy lengkap
```

## 💰 Biaya

**Sepenuhnya GRATIS** untuk skala kecil-menengah:
- Supabase Free: 500MB database, 1GB storage
- Vercel Free: 100GB bandwidth/bulan
- GitHub Free: repo publik unlimited

## 📄 Lisensi

MIT License - bebas digunakan dan dimodifikasi

---

Dibuat dengan ❤️ untuk Kantin Dharma Wanita
