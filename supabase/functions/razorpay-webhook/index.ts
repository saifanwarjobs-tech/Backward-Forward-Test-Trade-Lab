// Razorpay webhook: verifies the signature, then unlocks the student (lifetime) and records the payment.
// Deploy:  supabase functions deploy razorpay-webhook --no-verify-jwt
// Secrets: RAZORPAY_WEBHOOK_SECRET (the one you type in Razorpay > Webhooks). SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided automatically.
// In Razorpay Dashboard > Webhooks: URL = https://<project>.supabase.co/functions/v1/razorpay-webhook, events = payment.captured, order.paid
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const hex = (b: ArrayBuffer) => [...new Uint8Array(b)].map((x) => x.toString(16).padStart(2, "0")).join("");
async function sign(body: string, secret: string) {
  const k = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return hex(await crypto.subtle.sign("HMAC", k, new TextEncoder().encode(body)));
}
function same(a: string, b: string) { // constant-time compare
  if (a.length !== b.length) return false;
  let d = 0; for (let i = 0; i < a.length; i++) d |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return d === 0;
}
Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("POST only", { status: 405 });
  const body = await req.text();
  const sig = req.headers.get("x-razorpay-signature") || "";
  const secret = Deno.env.get("RAZORPAY_WEBHOOK_SECRET") || "";
  if (!secret || !same(await sign(body, secret), sig)) return new Response("bad signature", { status: 401 });

  const ev = JSON.parse(body);
  if (ev.event !== "payment.captured" && ev.event !== "order.paid") return new Response("ignored", { status: 200 });
  const p = ev.payload?.payment?.entity;
  if (!p || p.status !== "captured") return new Response("not captured", { status: 200 });

  const email = String(p.notes?.email || p.email || "").trim().toLowerCase();
  if (!/^\S+@\S+\.\S+$/.test(email)) { console.error("no email on payment", p.id); return new Response("no email", { status: 200 }); }
  const phone = String(p.notes?.phone || p.contact || "").replace(/\D/g, "").slice(-12) || null;
  const rupees = Math.round((p.amount || 0) / 100);

  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  // Idempotent: a retried webhook for the same payment changes nothing.
  const ins = await sb.from("payments").insert({ payment_id: p.id, order_id: p.order_id, email, phone, amount: rupees, status: "captured" });
  if (ins.error && ins.error.code !== "23505") { console.error(ins.error); return new Response("db error", { status: 500 }); } // 500 => Razorpay retries
  if (ins.error) return new Response("duplicate", { status: 200 });

  const up = await sb.from("students").upsert({ email, phone, amount: rupees, expires_at: null, note: `Razorpay ${p.id}` }, { onConflict: "email" });
  if (up.error) { console.error(up.error); return new Response("db error", { status: 500 }); }
  return new Response("ok", { status: 200 });
});
