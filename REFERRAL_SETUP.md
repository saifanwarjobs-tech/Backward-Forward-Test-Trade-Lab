# Partner (referral) programme: setup

## Go live (4 steps, ~10 minutes)
1. **Supabase SQL Editor**: run `schema_referral.sql` (after schema.sql and schema_pricing.sql). Safe to re-run.
2. **Redeploy the two functions** (they now understand partner codes and refunds):
   ```
   supabase functions deploy razorpay-order --no-verify-jwt
   supabase functions deploy razorpay-webhook --no-verify-jwt
   ```
3. **Razorpay Dashboard > Webhooks**: edit your webhook and also tick the event **`refund.processed`** (keep `payment.captured` and `order.paid`). Without it, refunds will not cancel commission automatically.
4. **Upload the site files** to GitHub Pages as usual (new: `referral.html`, `ref.js`; changed: all pages load `ref.js`, `academy.html`, `access.js`, `admin.html`, `sw.js`, `sitemap.xml`).

## How it works
- Partner joins at `referral.html` (email login, name, UPI) and gets a code such as `SAIF3F9A`.
- Link: `https://your-site/index.html?ref=SAIF3F9A` (partner can choose Home / Academy / Pricing / Testing Lab / Journal).
- `ref.js` stores the code for 30 days (last click wins) and counts one visitor per day per device.
- Checkout sends the code to `razorpay-order`, which ignores it if invalid, paused, or the buyer is the partner (same gmail ignoring dots and +tags).
- `razorpay-webhook` records the commission after the payment is verified: pending, then approved after 10 days (refund window is 7), then paid by you.
- Refund before payout: commission is cancelled. Refund after payout: deducted from that partner's next payout.

## Your monthly routine (admin.html > Partners)
1. Open Partners, press **Pay ₹X** on a partner: it opens your UPI app with the amount filled.
2. Send the money, paste the UTR, press **Mark as paid**. The partner sees it in their Payouts list.
3. Use **Cancel** on a sale if you find fraud or self-referral. **Edit** changes one partner's rate or pauses them.

## Settings
- Rate: default 30, per partner in Admin > Partners > Edit.
- Hold days: `HOLD_DAYS` in `razorpay-webhook/index.ts` and `hold_days` text in `partner_dashboard()` (SQL) and the rules text in `referral.html`.
- Minimum payout: Rs 500 (`min_payout` in `partner_dashboard()`, `PT_MIN` in admin.html, rules text).

## Please check before you promote it
- Ask your CA about TDS and tax on commission payouts to partners (and whether you need PAN from them).
- Keep partner-facing wording to "education only". The rules on `referral.html` already forbid profit or signal claims; you remain responsible for enforcing them.
- Test once: make a partner, open the link in a private window, buy a cheap item with a different email, check Admin > Partners shows a pending sale, refund it in Razorpay and watch it turn Cancelled.
