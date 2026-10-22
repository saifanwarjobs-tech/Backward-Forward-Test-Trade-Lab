// Razorpay webhook: verifies signature AND amount, records the payment (with product + plan) and grants access.
// Partner programme: a valid note `ref` creates a pending commission row (see schema_referral.sql). Refund events void it.
// Deploy: supabase functions deploy razorpay-webhook --no-verify-jwt   Secret: RAZORPAY_WEBHOOK_SECRET
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
const hex = (b: ArrayBuffer) => [...new Uint8Array(b)].map((x) => x.toString(16).padStart(2, "0")).join("");
async function sign(body: string, secret: string) {
  const k = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return hex(await crypto.subtle.sign("HMAC", k, new TextEncoder().encode(body)));
}
function same(a: string, b: string) { if (a.length !== b.length) return false; let d = 0; for (let i = 0; i < a.length; i++) d |= a.charCodeAt(i) ^ b.charCodeAt(i); return d === 0; }
async function expected(sb: any, pid: string, plan: string): Promise<number | null> {
  if (pid.startsWith("item:")) { const { data } = await sb.from("items").select("price").eq("id", pid.slice(5)).maybeSingle(); return data?.price ?? null; }
  const { data } = await sb.from("products").select("price_once,price_month").eq("id", pid).maybeSingle();
  return data ? (plan === "month" ? data.price_month : data.price_once) ?? null : null;
}
const HOLD_DAYS = 10; // commission becomes payable after this many days (refund window is 7 days)
function normEmail(e: string) {
  let [l, d] = String(e || "").trim().toLowerCase().split("@"); if (!d) return String(e || "").trim().toLowerCase();
  l = l.split("+")[0]; if (d === "gmail.com" || d === "googlemail.com") { l = l.replace(/\./g, ""); d = "gmail.com"; }
  return l + "@" + d;
}
async function recordReferral(sb: any, p: any, email: string, pid: string, rupees: number) {
  const code = String(p.notes?.ref || "").toUpperCase();
  if (!/^[A-Z0-9]{4,12}$/.test(code)) return;
  const { data: r } = await sb.from("referrers").select("email,rate,active").eq("code", code).maybeSingle();
  if (!r || !r.active || normEmail(r.email) === normEmail(email)) return;   // unknown / paused partner or self-referral
  const commission = Math.floor((rupees * r.rate) / 100);
  if (commission <= 0) return;
  const { error } = await sb.from("referrals").insert({ payment_id: p.id, code, referrer_email: r.email, buyer_email: email, product_id: pid,
    amount: rupees, rate: r.rate, commission, status: "pending", approve_after: new Date(Date.now() + HOLD_DAYS * 864e5).toISOString() });
  if (error && error.code !== "23505") console.error("referral insert failed", p.id, error);   // never block access because of a referral problem
}
Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("POST only", { status: 405 });
  const body = await req.text();
  const secret = Deno.env.get("RAZORPAY_WEBHOOK_SECRET") || "";
  if (!secret || !same(await sign(body, secret), req.headers.get("x-razorpay-signature") || "")) return new Response("bad signature", { status: 401 });
  const ev = JSON.parse(body);
  if (ev.event === "refund.processed") {      // add "refund.processed" to the webhook events in Razorpay
    const rid = ev.payload?.refund?.entity?.payment_id || ev.payload?.payment?.entity?.id;
    if (rid) {
      const sb0 = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
      await sb0.from("referrals").update({ refunded: true, status: "void" }).eq("payment_id", rid).in("status", ["pending", "approved"]);
      await sb0.from("referrals").update({ refunded: true }).eq("payment_id", rid).eq("status", "paid");   // already paid out: clawback on next payout
    }
    return new Response("ok", { status: 200 });
  }
  if (ev.event !== "payment.captured" && ev.event !== "order.paid") return new Response("ignored", { status: 200 });
  const p = ev.payload?.payment?.entity;
  if (!p || p.status !== "captured") return new Response("not captured", { status: 200 });
  const email = String(p.notes?.email || p.email || "").trim().toLowerCase();
  if (!/^\S+@\S+\.\S+$/.test(email)) { console.error("no email on payment", p.id); return new Response("no email", { status: 200 }); }
  const phone = String(p.notes?.phone || p.contact || "").replace(/\D/g, "").slice(-12) || null;
  const rupees = Math.round((p.amount || 0) / 100);
  const pid = String(p.notes?.product_id || "academy"); const plan = p.notes?.plan === "month" ? "month" : "once";
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const need = await expected(sb, pid, plan);
  const ok = need != null && rupees >= need;               // never grant on an underpaid / unknown product
  const ins = await sb.from("payments").insert({ payment_id: p.id, order_id: p.order_id, email, phone, amount: rupees,
    status: ok ? "captured" : "CHECK_MANUALLY", product_id: pid, plan, source: "razorpay" });
  if (ins.error && ins.error.code !== "23505") { console.error(ins.error); return new Response("db error", { status: 500 }); }
  if (ins.error) return new Response("duplicate", { status: 200 });
  if (!ok) { console.error("amount/product mismatch", p.id, pid, rupees, need); return new Response("mismatch", { status: 200 }); }

  let expires: string | null = null;
  if (plan === "month") {
    const { data: cur } = await sb.from("entitlements").select("expires_at").eq("email", email).eq("product_id", pid).maybeSingle();
    if (cur && cur.expires_at === null) expires = null;     // already lifetime, keep it
    else { const base = Math.max(Date.now(), cur?.expires_at ? Date.parse(cur.expires_at) : 0); expires = new Date(base + 30 * 864e5).toISOString(); }
  }
  const up = await sb.from("entitlements").upsert({ email, product_id: pid, plan, expires_at: expires, amount: rupees, phone }, { onConflict: "email,product_id" });
  if (up.error) { console.error(up.error); return new Response("db error", { status: 500 }); }
  await recordReferral(sb, p, email, pid, rupees);
  if (pid === "academy") await sb.from("students").upsert({ email, phone, amount: rupees, expires_at: null, note: `Razorpay ${p.id}` }, { onConflict: "email" });
  return new Response("ok", { status: 200 });
});
