# 🚀 Panduan Deploy Kantin DW Online
## Setup Lengkap: Supabase → GitHub → Vercel → PWA

---

## FASE 1: SETUP SUPABASE (Backend & Database)

### Langkah 1.1 — Buat Project Supabase

1. Buka **https://supabase.com** → klik **Start your project**
2. Login dengan GitHub atau email
3. Klik **New Project**
4. Isi:
   - **Organization**: pilih atau buat baru
   - **Name**: `kantin-dw-online`
   - **Database Password**: buat password kuat (simpan!)
   - **Region**: `Southeast Asia (Singapore)` ← pilih ini agar cepat
5. Klik **Create new project** → tunggu ~2 menit

### Langkah 1.2 — Jalankan SQL Schema

1. Di dashboard Supabase, klik **SQL Editor** (ikon database di kiri)
2. Klik **New query**
3. Buka file `supabase/schema.sql` dari project ini
4. Copy **seluruh isi** file tersebut
5. Paste ke SQL Editor Supabase
6. Klik tombol **Run** (atau tekan Ctrl+Enter)
7. Tunggu hingga muncul ✅ "Success"

> ⚠️ Jika ada error, jalankan bagian per bagian mulai dari CREATE EXTENSION

### Langkah 1.3 — Ambil API Keys

1. Di Supabase, klik **Settings** (ikon gear) → **API**
2. Salin nilai berikut:
   - **Project URL** → ini adalah `SUPABASE_URL`
   - **anon / public key** → ini adalah `SUPABASE_ANON_KEY`
   - **service_role key** → ini adalah `SUPABASE_SERVICE_ROLE_KEY` (RAHASIA!)

### Langkah 1.4 — Setup Authentication

1. Klik **Authentication** → **Providers**
2. **Email** sudah aktif otomatis ✅
3. Untuk **Google Login**:
   - Toggle Google → Enable
   - Buka https://console.cloud.google.com
   - Buat project baru → OAuth 2.0 Client ID
   - **Authorized redirect URI**: `https://YOUR_PROJECT.supabase.co/auth/v1/callback`
   - Salin **Client ID** dan **Client Secret** ke Supabase

### Langkah 1.5 — Buat Storage Buckets

1. Klik **Storage** di menu kiri
2. Klik **New bucket** dan buat 5 bucket berikut:

| Nama Bucket | Public | Keterangan |
|-------------|--------|------------|
| `avatars`   | ✅ Ya  | Foto profil user |
| `products`  | ✅ Ya  | Foto produk |
| `stores`    | ✅ Ya  | Logo & banner warung |
| `banners`   | ✅ Ya  | Banner promo aplikasi |
| `qris`      | ✅ Ya  | QR Code pembayaran |

3. Untuk setiap bucket, klik **Policies** → tambah policy:
   - **SELECT**: `true` (siapa pun bisa melihat)
   - **INSERT/UPDATE/DELETE**: `auth.uid() IS NOT NULL` (hanya yang login)

### Langkah 1.6 — Setup Edge Functions (WhatsApp)

```bash
# Install Supabase CLI
npm install -g supabase

# Login ke Supabase
supabase login

# Link ke project Anda
supabase link --project-ref YOUR_PROJECT_ID

# Deploy fungsi WhatsApp
supabase functions deploy send-whatsapp

# Set environment variable untuk fungsi
supabase secrets set CALLMEBOT_APIKEY=your_api_key_here
```

**Cara setup CallMeBot (100% GRATIS, tanpa kartu kredit):**
1. Simpan nomor ini di kontak HP: **+34 644 59 73 48**
2. Kirim pesan WhatsApp: `I allow callmebot to send me messages`
3. Tunggu balasan berisi **API Key** Anda (langsung otomatis)
4. Simpan API Key tersebut sebagai `CALLMEBOT_APIKEY` di Vercel

> ✅ Gratis tanpa batas untuk penggunaan personal/kantin kecil

---

## FASE 2: DEPLOY KE GITHUB + VERCEL

### Langkah 2.1 — Persiapan File

Sebelum deploy, update file `index.html`:

Cari baris ini (sekitar baris 600):
```javascript
const SUPABASE_URL = window.ENV?.SUPABASE_URL || 'https://YOUR_PROJECT.supabase.co';
const SUPABASE_ANON_KEY = window.ENV?.SUPABASE_ANON_KEY || 'YOUR_ANON_KEY';
```

Ganti dengan URL dan key Supabase Anda yang asli.

### Langkah 2.2 — Upload ke GitHub

**Cara 1: Via GitHub.com (Mudah, tanpa install apapun)**

1. Buka https://github.com → Login
2. Klik tombol **+** → **New repository**
3. Isi:
   - **Repository name**: `kantin-dw-online`
   - **Description**: Aplikasi Kantin Dharma Wanita Online
   - **Visibility**: Public
   - ❌ Jangan centang "Initialize with README"
4. Klik **Create repository**
5. Di halaman repo kosong, klik **uploading an existing file**
6. **Drag & drop** semua file project (kecuali `.env`):
   - `index.html`
   - `manifest.json`
   - `sw.js`
   - `README.md`
   - Folder `supabase/`
7. Tulis commit message: `feat: initial commit Kantin DW Online`
8. Klik **Commit changes**

**Cara 2: Via Terminal (Lebih cepat)**

```bash
# Masuk ke folder project
cd kantin-dw

# Inisialisasi Git
git init
git add .
git commit -m "feat: initial commit Kantin DW Online"

# Hubungkan ke GitHub (ganti USERNAME)
git remote add origin https://github.com/USERNAME/kantin-dw-online.git
git branch -M main
git push -u origin main
```

### Langkah 2.3 — Deploy ke Vercel

1. Buka https://vercel.com → **Sign Up with GitHub**
2. Klik **New Project**
3. Cari dan pilih repo `kantin-dw-online` → klik **Import**
4. Konfigurasi:
   - **Framework Preset**: `Other` (bukan Next.js, dll)
   - **Root Directory**: `./`
   - **Build Command**: kosongkan
   - **Output Directory**: kosongkan
5. Buka **Environment Variables** dan tambahkan:

| Key | Value |
|-----|-------|
| `SUPABASE_URL` | `https://xxxxx.supabase.co` |
| `SUPABASE_ANON_KEY` | `eyJhbG...` |

6. Klik **Deploy** → tunggu ~1 menit
7. ✅ Aplikasi live di: `https://kantin-dw-online.vercel.app`

### Langkah 2.4 — Custom Domain (Opsional)

1. Di Vercel → **Settings** → **Domains**
2. Tambah domain: `kantindw.id` (jika sudah punya)
3. Update DNS sesuai instruksi Vercel
4. Aktifkan SSL otomatis ✅

---

## FASE 3: KONVERSI KE PWA

File `manifest.json` dan `sw.js` sudah tersedia di project.

### Langkah 3.1 — Generate Ikon PWA

**Cara mudah (online):**
1. Buka https://realfavicongenerator.net
2. Upload logo/gambar warung (minimal 512×512 px)
3. Download ZIP → extract → simpan di folder `/icons/`

**Atau buat manual menggunakan Canva:**
1. Buka Canva.com → buat desain 512×512 px
2. Tambahkan logo "DW" dengan background hijau
3. Download PNG → resize ke semua ukuran yang dibutuhkan

### Langkah 3.2 — Tambahkan ke index.html

Pastikan di dalam `<head>` di `index.html` sudah ada:

```html
<link rel="manifest" href="/manifest.json" />
<meta name="theme-color" content="#16a34a" />
<link rel="apple-touch-icon" href="/icons/icon-192.png" />
<meta name="apple-mobile-web-app-capable" content="yes" />
<meta name="apple-mobile-web-app-status-bar-style" content="default" />
<meta name="apple-mobile-web-app-title" content="Kantin DW" />
```

Dan pastikan service worker didaftarkan (di akhir body):

```html
<script>
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/sw.js')
      .then(reg => console.log('SW registered:', reg.scope))
      .catch(err => console.log('SW failed:', err));
  });
}
</script>
```

### Langkah 3.3 — Test & Install PWA

**Di Android (Chrome):**
1. Buka URL aplikasi di Chrome
2. Tunggu beberapa detik → muncul banner "Tambahkan ke layar utama"
3. Ketuk banner → **Tambahkan**
4. Ikon muncul di homescreen ✅

**Di iPhone (Safari):**
1. Buka URL di Safari
2. Ketuk ikon **Share** (kotak dengan panah ke atas)
3. Scroll ke bawah → **"Tambahkan ke Layar Utama"**
4. Ketuk **Tambahkan**
5. Ikon muncul di homescreen ✅

**Di PC/Laptop (Chrome):**
1. Buka URL di Chrome
2. Di address bar, klik ikon install (komputer + +)
3. Klik **Install**
4. Aplikasi buka seperti software desktop ✅

---

## FASE 4: KONVERSI KE APK ANDROID

### Metode: PWABuilder.com (Gratis, Mudah)

1. Buka https://www.pwabuilder.com
2. Masukkan URL aplikasi Vercel Anda
3. Klik **Start** → tunggu analisis selesai
4. Klik **Package for Stores** → pilih **Android**
5. Pilih **Android (APK)** → Download
6. File `.apk` siap diinstal di Android!

### Alternatif: Bubblewrap (Google Official)

```bash
# Install Node.js dan Bubblewrap
npm install -g @bubblewrap/cli

# Init project Android
bubblewrap init --manifest https://kantin-dw.vercel.app/manifest.json

# Build APK
bubblewrap build

# File APK ada di ./app/build/outputs/apk/
```

---

## CHECKLIST FINAL SEBELUM LAUNCH 🚀

### ✅ Supabase
- [ ] Project dibuat di region Singapore
- [ ] SQL Schema berhasil dijalankan (semua tabel ada)
- [ ] Auth Email aktif
- [ ] Auth Google aktif (opsional)
- [ ] 5 Storage bucket dibuat dan public
- [ ] Edge Function WhatsApp di-deploy
- [ ] Secret CALLMEBOT_APIKEY sudah diset (ambil dari CallMeBot gratis)

### ✅ GitHub
- [ ] Repository dibuat (public)
- [ ] Semua file di-upload
- [ ] File `.env` TIDAK ikut di-commit

### ✅ Vercel
- [ ] Project berhasil di-deploy
- [ ] Environment variables SUPABASE sudah diset
- [ ] URL live bisa diakses dari HP
- [ ] HTTPS aktif (otomatis di Vercel)

### ✅ PWA
- [ ] manifest.json bisa diakses di /manifest.json
- [ ] Service Worker terdaftar (cek DevTools → Application)
- [ ] Ikon semua ukuran tersedia
- [ ] Bisa diinstall di Android
- [ ] Bisa diinstall di iPhone

### ✅ Fungsionalitas
- [ ] Registrasi akun berfungsi
- [ ] Login email + Google berfungsi
- [ ] Upload foto produk berfungsi
- [ ] Checkout dan buat pesanan berfungsi
- [ ] Notifikasi WhatsApp terkirim ke penjual
- [ ] Penjual bisa update status pesanan
- [ ] Pembeli dapat notifikasi status

---

## BIAYA OPERASIONAL

| Layanan | Paket | Biaya |
|---------|-------|-------|
| Supabase | Free (500MB DB, 1GB Storage, 50k Auth users) | **GRATIS** |
| Vercel | Free (100GB bandwidth, unlimited deploy) | **GRATIS** |
| GitHub | Free (repo publik unlimited) | **GRATIS** |
| CallMeBot | Free (notifikasi WA tanpa batas) | **GRATIS** |
| Web Push API | Free (built-in browser) | **GRATIS** |
| PWABuilder APK | Free (Microsoft) | **GRATIS** |
| Domain .id | Opsional — bisa pakai subdomain Vercel | **GRATIS** |

**Total: 100% GRATIS** — tidak ada biaya tersembunyi

---

## DUKUNGAN & MASALAH UMUM

### Error: "Invalid API Key"
→ Periksa kembali `SUPABASE_ANON_KEY` di Vercel Environment Variables

### WhatsApp tidak terkirim
→ Pastikan CALLMEBOT_APIKEY benar. Kirim ulang aktivasi ke +34 644 59 73 48

### PWA tidak bisa diinstall
→ Pastikan HTTPS aktif dan `manifest.json` dapat diakses

### Database error saat checkout
→ Periksa RLS Policy di Supabase → Table Editor → Policies
