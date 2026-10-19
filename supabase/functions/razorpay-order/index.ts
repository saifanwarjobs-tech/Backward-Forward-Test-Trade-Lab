// Creates a Razorpay order for the Academy. The price is fixed HERE (server side), never taken from the browser.
// Deploy:  supabase functions deploy razorpay-order --no-verify-jwt
// Secrets: RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET, PRICE_RUPEES (default 4999), ALLOWED_ORIGIN (your site, e.g. https://bft-tradelab.in)
const cors = (o: string) => ({
  "Access-Control-Allow-Origin": o, "Access-Control-Allow-Headers": "content-type, authorization, apikey",
  "Access-Control-Allow-Methods": "POST, OPTIONS", "Vary": "Origin",
});
Deno.serve(async (req) => {
  const origin = Deno.env.get("ALLOWED_ORIGIN") || "*";
  const h = { ...cors(origin), "Content-Type": "application/json" };
  if (req.method === "OPTIONS") return new Response("ok", { headers: h });
  if (req.method !== "POST") return new Response(JSON.stringify({ error: "POST only" }), { status: 405, headers: h });
  try {
    const { email, phone } = await req.json();
    const em = String(email || "").trim().toLowerCase();
    if (!/^\S+@\S+\.\S+$/.test(em) || em.length > 120) return new Response(JSON.stringify({ error: "Enter a valid email" }), { status: 400, headers: h });
    const ph = String(phone || "").replace(/\D/g, "").slice(0, 15);
    const amount = Math.round(Number(Deno.env.get("PRICE_RUPEES") || "4999") * 100);
    const auth = "Basic " + btoa(`${Deno.env.get("RAZORPAY_KEY_ID")}:${Deno.env.get("RAZORPAY_KEY_SECRET")}`);
    const r = await fetch("https://api.razorpay.com/v1/orders", {
      method: "POST", headers: { Authorization: auth, "Content-Type": "application/json" },
      body: JSON.stringify({ amount, currency: "INR", receipt: "acad_" + Date.now(), notes: { email: em, phone: ph, product: "academy_lifetime" } }),
    });
    const o = await r.json();
    if (!r.ok) { console.error("razorpay order error", JSON.stringify(o)); return new Response(JSON.stringify({ error: "Could not start payment. Try again." }), { status: 502, headers: h }); }
    return new Response(JSON.stringify({ order_id: o.id, amount: o.amount }), { headers: h });
  } catch (e) {
    console.error(e);
    return new Response(JSON.stringify({ error: "Something went wrong" }), { status: 500, headers: h });
  }
});
