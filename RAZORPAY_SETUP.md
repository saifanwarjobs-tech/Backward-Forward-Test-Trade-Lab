# Razorpay setup (BFT Academy)

## A. Before you apply (so activation is not rejected)
1. Put the site on **your own domain** (e.g. bft-tradelab.in) and use an email on it (support@...). Razorpay is stricter with github.io / netlify.app links.
2. In `scripts/build_pages.py` set `address` (full postal address), `owner` (your legal/proprietor name), `email`, then run `python3 scripts/build_pages.py`. Commit the regenerated pages.
3. Add real content in Academy (at least one course with a few lessons, and one PDF) via admin.html. Mark a few lessons FREE.
4. In the Razorpay form, describe the business as **"Online education: price-action trading course, journal and practice software. No tips, no signals, no advisory."** Give these URLs: home, /academy.html, /pricing.html, /terms.html, /refund.html, /privacy.html, /contact.html.
5. Do not put "indicators", "signals", "calls" or profit claims in the headline. Do not show your personal UPI/QR on the live site once Razorpay is on (the UPI box disappears automatically when `razorpayKey` + `orderUrl` are set).
6. Keep ready: PAN (business or personal), bank account in the same name, address proof, GST/Udyam if you have one.

## B. After activation (test mode first)
1. Supabase SQL Editor: run the latest `schema.sql` (adds the `payments` table).
2. Install the Supabase CLI, then in this folder:
   ```
   supabase login
   supabase link --project-ref ytdipdzzwuzdnzrabpwx
   supabase secrets set RAZORPAY_KEY_ID=rzp_test_xxx RAZORPAY_KEY_SECRET=xxx PRICE_RUPEES=4999 ALLOWED_ORIGIN=https://your-domain RAZORPAY_WEBHOOK_SECRET=choose-a-long-random-string
   supabase functions deploy razorpay-order --no-verify-jwt
   supabase functions deploy razorpay-webhook --no-verify-jwt
   ```
3. Razorpay Dashboard > Settings > Webhooks > Add: URL `https://ytdipdzzwuzdnzrabpwx.supabase.co/functions/v1/razorpay-webhook`, secret = the same `RAZORPAY_WEBHOOK_SECRET`, events `payment.captured` and `order.paid`.
4. In `academy.html` CFG set `razorpayKey:'rzp_test_xxx'` (Key ID only, never the secret) and `orderUrl:'https://ytdipdzzwuzdnzrabpwx.supabase.co/functions/v1/razorpay-order'`.
5. Test with Razorpay test UPI/cards. After payment, the email should appear in admin.html > Students and in the `payments` table.
6. Go live: swap to the `rzp_live_` key and secret (`supabase secrets set ...`), update `razorpayKey`, test once with a small real payment and refund it.

## Notes
- Price is fixed in the order function (`PRICE_RUPEES`), not in the browser. If you change the price, change it in the secret **and** in academy.html `CFG.price` and pricing.html.
- Webhooks are verified by signature and are safe to retry (duplicate payment ids are ignored).
- "Confirm email" must stay ON in Supabase Auth, otherwise someone could sign up with a paid student's email.
- Refunds are done from the Razorpay dashboard; then set that student's expiry to today in admin.html.
