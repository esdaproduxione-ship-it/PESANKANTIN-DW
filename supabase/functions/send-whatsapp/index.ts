// supabase/functions/send-whatsapp/index.ts
// ============================================================
// GRATIS 100% — Menggunakan CallMeBot (WhatsApp gratis)
// Daftar di: https://www.callmebot.com/blog/free-api-whatsapp-messages/
//
// ALTERNATIF GRATIS LAINNYA:
// 1. CallMeBot      → https://callmebot.com     (gratis, personal)
// 2. WA-Automate   → self-hosted, open source
// 3. Baileys        → self-hosted Node.js, open source
// 4. Email fallback → Supabase SMTP (gratis 3 email/hari)
// ============================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL          = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// CallMeBot — GRATIS, tidak perlu registrasi bisnis
// Cara setup: kirim "I allow callmebot to send me messages" ke +34 644 59 73 48
// lalu simpan API key yang diberikan di sini
const CALLMEBOT_APIKEY = Deno.env.get("CALLMEBOT_APIKEY") ?? "";

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

// ── Template Pesan ─────────────────────────────────────────
const TEMPLATES: Record<string, (o: OrderData) => string> = {
  order_received: (o) => [
    "🛍️ *PESANAN BARU MASUK!*",
    "━━━━━━━━━━━━━━━",
    `📋 No: *${o.order_number}*`,
    `👤 Pembeli: ${o.buyer_name}`,
    `📱 HP: ${o.buyer_phone}`,
    "",
    "🍽️ *Detail:*",
    ...o.items.map(i => `• ${i.name} ×${i.qty} = Rp ${fmtRp(i.price * i.qty)}`),
    "",
    `💰 Total: *Rp ${fmtRp(o.total)}*`,
    `💳 Bayar: ${o.payment_label}`,
    `🚀 Ambil: ${o.delivery_label}`,
    o.notes ? `📝 Catatan: ${o.notes}` : "",
    "",
    "Segera konfirmasi pesanan! 🙏",
  ].filter(Boolean).join("\n"),

  order_confirmed: (o) => [
    "✅ *PESANAN DIKONFIRMASI*",
    "━━━━━━━━━━━━━━━",
    `📋 No: *${o.order_number}*`,
    `🏪 Dari: ${o.store_name}`,
    "",
    "Pesanan Anda sedang *diproses*.",
    "Kami akan memberi tahu saat siap. 🍽️",
  ].join("\n"),

  order_ready: (o) => [
    "🎉 *PESANAN SIAP DIAMBIL!*",
    "━━━━━━━━━━━━━━━",
    `📋 No: *${o.order_number}*`,
    `🏪 ${o.store_name}`,
    "",
    "Pesanan Anda sudah *siap*!",
    "Silakan diambil di warung. 🏃",
  ].join("\n"),

  order_delivering: (o) => [
    "🛵 *PESANAN SEDANG DIANTAR*",
    "━━━━━━━━━━━━━━━",
    `📋 No: *${o.order_number}*`,
    "",
    "Harap siap menerima pesanan. 🏠",
  ].join("\n"),

  order_completed: (o) => [
    "🌟 *PESANAN SELESAI*",
    "━━━━━━━━━━━━━━━",
    `📋 No: *${o.order_number}*`,
    `🏪 ${o.store_name}`,
    "",
    "Terima kasih sudah memesan! 😊",
    "Beri bintang 5 ya! ⭐⭐⭐⭐⭐",
  ].join("\n"),
};

interface OrderItem  { name: string; qty: number; price: number; }
interface OrderData  {
  order_number: string; buyer_name: string; buyer_phone: string;
  store_name: string; store_wa: string; items: OrderItem[];
  total: number; payment_label: string; delivery_label: string; notes: string;
}

function fmtRp(n: number) {
  return n.toLocaleString("id-ID");
}

// ── Kirim via CallMeBot (GRATIS) ───────────────────────────
async function sendViaCallmebot(phone: string, message: string) {
  // Normalisasi nomor: 08xxx → 628xxx
  const normalized = phone.replace(/^0/, "62").replace(/\D/g, "");
  const encoded    = encodeURIComponent(message);
  const url = `https://api.callmebot.com/whatsapp.php?phone=${normalized}&text=${encoded}&apikey=${CALLMEBOT_APIKEY}`;

  const res  = await fetch(url);
  const text = await res.text();
  return { ok: res.ok, status: res.status, body: text };
}

// ── Fallback: kirim via email (Supabase SMTP — GRATIS) ─────
async function sendViaEmail(to: string, subject: string, body: string) {
  // Gunakan Supabase Auth email atau SMTP gratis (Resend free tier: 3000/bulan)
  // Ini hanya fallback jika WhatsApp gagal
  const res = await fetch(`${SUPABASE_URL}/functions/v1/send-email`, {
    method: "POST",
    headers: { "Content-Type": "application/json", "Authorization": `Bearer ${SUPABASE_SERVICE_KEY}` },
    body: JSON.stringify({ to, subject, body }),
  });
  return res.ok;
}

// ── Main Handler ───────────────────────────────────────────
serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, content-type" },
    });
  }

  try {
    const { type, order_id } = await req.json();

    const { data: order, error } = await supabase
      .from("orders")
      .select(`*, profiles!buyer_id(full_name, phone), stores(name, whatsapp), order_items(product_name, quantity, product_price)`)
      .eq("id", order_id)
      .single();

    if (error || !order) throw new Error("Order tidak ditemukan");

    const PAY: Record<string, string> = { qris: "QRIS", cod: "COD", cash_pickup: "Tunai saat ambil" };
    const DEL: Record<string, string> = { pickup: "Ambil sendiri", delivery: "Diantar" };

    const orderData: OrderData = {
      order_number:   order.order_number,
      buyer_name:     order.profiles.full_name,
      buyer_phone:    order.profiles.phone ?? "",
      store_name:     order.stores.name,
      store_wa:       order.stores.whatsapp ?? "",
      items:          order.order_items.map((i: any) => ({ name: i.product_name, qty: i.quantity, price: i.product_price })),
      total:          order.total,
      payment_label:  PAY[order.payment_method]  ?? order.payment_method,
      delivery_label: DEL[order.delivery_method] ?? order.delivery_method,
      notes:          order.buyer_notes ?? "",
    };

    const template = TEMPLATES[type];
    if (!template) throw new Error(`Template tidak ditemukan: ${type}`);
    const message = template(orderData);

    const results: unknown[] = [];

    // Kirim ke penjual saat pesanan masuk
    if (type === "order_received" && orderData.store_wa) {
      const r = await sendViaCallmebot(orderData.store_wa, message);
      results.push({ to: "seller", ...r });
    }

    // Kirim ke pembeli saat status berubah
    if (["order_confirmed","order_ready","order_delivering","order_completed"].includes(type) && orderData.buyer_phone) {
      const r = await sendViaCallmebot(orderData.buyer_phone, message);
      results.push({ to: "buyer", ...r });
    }

    // Simpan notifikasi ke DB (selalu, tanpa tergantung WA berhasil)
    await supabase.from("notifications").insert({
      user_id: order.buyer_id,
      title:   `Update Pesanan ${order.order_number}`,
      body:    message.split("\n")[0].replace(/\*/g, ""),
      type:    type,
      data:    { order_id, order_number: order.order_number },
    });

    return new Response(JSON.stringify({ success: true, results }), {
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
    });

  } catch (err: any) {
    return new Response(JSON.stringify({ success: false, error: err.message }), {
      status: 500,
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
    });
  }
});
