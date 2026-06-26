// generate-icons.js
// Buat ikon PWA tanpa install dependency apapun
// Jalankan: node generate-icons.js
// Butuh: Node.js 18+ (sudah gratis & terinstall di semua OS)

const fs   = require("fs");
const path = require("path");
const http  = require("http");
const https = require("https");

const SIZES     = [72, 96, 128, 144, 152, 192, 384, 512];
const OUT_DIR   = path.join(__dirname, "icons");

if (!fs.existsSync(OUT_DIR)) fs.mkdirSync(OUT_DIR, { recursive: true });

// ── Buat ikon SVG pure text, lalu simpan sebagai SVG ──────
// (SVG bisa langsung dipakai sebagai ikon — tidak butuh library)
function generateSVG(size) {
  const fontSize = Math.floor(size * 0.52);
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">
  <circle cx="${size/2}" cy="${size/2}" r="${size/2}" fill="#16a34a"/>
  <circle cx="${size/2}" cy="${size/2}" r="${size/2 - size*0.08}" fill="#15803d"/>
  <text x="${size/2}" y="${size/2 + fontSize*0.18}" font-size="${fontSize}" text-anchor="middle" dominant-baseline="central" font-family="serif">🍽️</text>
</svg>`;
  fs.writeFileSync(path.join(OUT_DIR, `icon-${size}.svg`), svg);
  console.log(`✅ icon-${size}.svg`);
}

// ── Buat favicon.ico sederhana (16x16 ICO header) ─────────
function generateFaviconTip() {
  console.log("\n💡 Untuk favicon.ico dan PNG:");
  console.log("   Buka https://favicon.io/favicon-generator/");
  console.log("   Teks: DW | BG: #16a34a | Font: Any");
  console.log("   Download → extract ke folder /icons/\n");
}

// ── Buat placeholder PNG 1x1 (agar manifest tidak error) ──
// Format PNG minimal: header + IHDR + IDAT + IEND
function generateMinimalPNG(size, filePath) {
  // Warna hijau #16a34a dalam RGB
  const r = 0x16, g = 0xa3, b = 0x4a;

  function crc32(buf) {
    let crc = 0xffffffff;
    const table = [];
    for (let n = 0; n < 256; n++) {
      let c = n;
      for (let k = 0; k < 8; k++) c = (c & 1) ? (0xedb88320 ^ (c >>> 1)) : (c >>> 1);
      table[n] = c;
    }
    for (let i = 0; i < buf.length; i++) crc = table[(crc ^ buf[i]) & 0xff] ^ (crc >>> 8);
    return (crc ^ 0xffffffff) >>> 0;
  }

  function u32(n) {
    const b = Buffer.alloc(4);
    b.writeUInt32BE(n, 0);
    return b;
  }

  function chunk(type, data) {
    const t = Buffer.from(type, "ascii");
    const d = Buffer.isBuffer(data) ? data : Buffer.from(data);
    const c = crc32(Buffer.concat([t, d]));
    return Buffer.concat([u32(d.length), t, d, u32(c)]);
  }

  // Buat gambar 1x1 pixel warna solid (lebih kecil, cukup untuk placeholder)
  // Untuk produksi, gunakan favicon.io atau realfavicongenerator.net
  const PNG_SIGNATURE = Buffer.from([137,80,78,71,13,10,26,10]);

  const IHDR_data = Buffer.concat([
    u32(1), u32(1),  // 1×1 px (placeholder)
    Buffer.from([8, 2, 0, 0, 0])  // bit depth 8, color type RGB
  ]);

  // IDAT: filter byte 0x00 + RGB
  const raw      = Buffer.from([0x00, r, g, b]);
  const deflated = Buffer.from([0x78, 0x9c, 0x62, 0x60, 0x60, 0x60, 0x00, 0x00, 0x00, 0x04, 0x00, 0x01]);

  const png = Buffer.concat([
    PNG_SIGNATURE,
    chunk("IHDR", IHDR_data),
    chunk("IDAT", deflated),
    chunk("IEND", Buffer.alloc(0)),
  ]);

  fs.writeFileSync(filePath, png);
}

// ── Jalankan ───────────────────────────────────────────────
console.log("🎨 Membuat ikon PWA (tanpa dependency)...\n");

SIZES.forEach(size => {
  generateSVG(size);
  // Buat placeholder PNG agar manifest.json tidak error saat test
  const pngPath = path.join(OUT_DIR, `icon-${size}.png`);
  if (!fs.existsSync(pngPath)) {
    generateMinimalPNG(size, pngPath);
    console.log(`   ↳ placeholder PNG icon-${size}.png (ganti dengan PNG asli)`);
  }
});

generateFaviconTip();

console.log("🎉 Selesai! File ada di folder /icons/");
console.log("📌 PENTING: Ganti file PNG placeholder dengan ikon asli dari favicon.io");
