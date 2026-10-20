// Creates a Razorpay order. The price comes from the DATABASE (products / items), never from the browser.
// Body: { email, phone, product_id, plan }  plan = 'once' | 'month'. product_id may be 'item:<uuid>'. Default: academy.
// Secrets: RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET, ALLOWED_ORIGIN. SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are automatic.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
const cors = (o: string) => ({ "Access-Control-Allow-Origin": o, "Access-Control-Allow-Headers": "content-type, authorization, apikey",
  "Access-Control-Allow-Methods": "POST, OPTIONS", "Vary": "Origin" });
export async function priceOf(sb: any, pid: string, plan: string) {
  if (pid.startsWith("item:")) {
    const { data } = await sb.from("items").select("price,published").eq("id", pid.slice(5)).maybeSingle();
    return data && data.published && data.price > 0 ? { rupees: data.price as number, plan: "once" } : null;
  }
  const { data } = await sb.from("products").select("price_once,price_month,active").eq("id", pid).maybeSingle();
  if (!data || !data.active) return null;
  const p = plan === "month" ? data.price_month : data.price_once;
  return p > 0 ? { rupees: p as number, plan: plan === "month" ? "month" : "once" } : null;
}
Deno.serve(async (req) => {
  const origin = Deno.env.get("ALLOWED_ORIGIN");
  const h = { ...cors(origin || "*"), "Content-Type": "application/json" };
  if (req.method === "OPTIONS") return new Response("ok", { headers: h });
  if (req.method !== "POST") return new Response(JSON.stringify({ error: "POST only" }), { status: 405, headers: h });
  if (origin && req.headers.get("origin") !== origin) return new Response(JSON.stringify({ error: "Not allowed" }), { status: 403, headers: h });
  try {
    const b = await req.json();
    const em = String(b.email || "").trim().toLowerCase();
    if (!/^\S+@\S+\.\S+$/.test(em) || em.length > 120) return new Response(JSON.stringify({ error: "Enter a valid email" }), { status: 400, headers: h });
    const ph = String(b.phone || "").replace(/\D/g, "").slice(-12);
    const pid = String(b.product_id || "academy").slice(0, 80);
    const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const pr = await priceOf(sb, pid, String(b.plan || "once"));
    if (!pr) return new Response(JSON.stringify({ error: "This option is not on sale" }), { status: 400, headers: h });
    const auth = "Basic " + btoa(`${Deno.env.get("RAZORPAY_KEY_ID")}:${Deno.env.get("RAZORPAY_KEY_SECRET")}`);
    const r = await fetch("https://api.razorpay.com/v1/orders", { method: "POST", headers: { Authorization: auth, "Content-Type": "application/json" },
      body: JSON.stringify({ amount: pr.rupees * 100, currency: "INR", receipt: "bft_" + Date.now(),
        notes: { email: em, phone: ph, product_id: pid, plan: pr.plan } }) });
    const o = await r.json();
    if (!r.ok) { console.error("razorpay order error", JSON.stringify(o)); return new Response(JSON.stringify({ error: "Could not start payment. Try again." }), { status: 502, headers: h }); }
    return new Response(JSON.stringify({ order_id: o.id, amount: o.amount }), { headers: h });
  } catch (e) { console.error(e); return new Response(JSON.stringify({ error: "Something went wrong" }), { status: 500, headers: h }); }
});
