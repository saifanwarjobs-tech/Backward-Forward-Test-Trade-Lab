#!/usr/bin/env python3
"""Builds the static policy pages (terms, privacy, refund, contact, pricing, about, legal).
Edit the values in B below, then run:  python3 scripts/build_pages.py
Pages are plain HTML (no JavaScript needed to read them), so payment-gateway reviewers and crawlers can see the text."""
import html, pathlib
B = dict(
    name="BFT Trade Lab", updated="19 October 2026", city="Jaipur", state="Rajasthan",
    address="58A, Udyog Nagar, Jhotwara, Jaipur 302012, Rajasthan, India",   # full postal address (Razorpay asks for it)
    owner="Saif Anwar",                    # legal / proprietor name, shown on Contact page
    days=7, pct=20, price="4,999",
    email="saif.anwar.jobs@gmail.com",     # <-- better: support@your-own-domain
    phone="+91 63505 66010", wa="https://wa.me/916350566010",
)
ROOT = pathlib.Path(__file__).resolve().parent.parent
E = lambda s: html.escape(str(s))

CSS = """:root{--bg:#070b14;--pn:#0f1626;--tx:#e8eefb;--mu:#8e9bb8;--ln:rgba(255,255,255,.1);--ac:#6aa5ff}
@media(prefers-color-scheme:light){:root{--bg:#f5f7fc;--pn:#fff;--tx:#0f172a;--mu:#55617a;--ln:rgba(15,23,42,.12);--ac:#2f6fe4}}
*{box-sizing:border-box;margin:0}
body{background:var(--bg);color:var(--tx);font:16px/1.7 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;padding:env(safe-area-inset-top,0) 0 40px}
.w{max-width:720px;margin:0 auto;padding:0 18px}
header{display:flex;justify-content:space-between;padding:16px 0;font-size:14px}header a{color:var(--mu);text-decoration:none}
h1{font-size:28px;letter-spacing:-.02em;margin:10px 0 4px}h2{font-size:21px;margin:0 0 10px}h3{font-size:16px;margin:18px 0 4px}
p,li{color:var(--mu);margin-bottom:10px}li{margin-left:20px}p b,li b,td b{color:var(--tx)}
article{background:var(--pn);border:1px solid var(--ln);border-radius:16px;padding:22px 20px;margin:18px 0}
.lead{margin:0 0 6px}table{width:100%;border-collapse:collapse}td{padding:10px 0;border-bottom:1px solid var(--ln);color:var(--mu);vertical-align:top}td:first-child{width:34%;color:var(--tx);font-weight:600}
.big{font-size:40px;font-weight:800;color:var(--tx);letter-spacing:-.02em}
.btn{display:inline-flex;align-items:center;min-height:48px;padding:0 22px;border-radius:12px;background:var(--ac);color:#fff;font-weight:700;text-decoration:none;margin-top:8px}
nav.f{display:flex;flex-wrap:wrap;gap:6px 16px;margin-top:26px;font-size:14px}nav.f a{color:var(--mu)}
:focus-visible{outline:2px solid var(--ac);outline-offset:2px}a{color:var(--ac)}"""

NAV = [("Terms","terms.html"),("Privacy","privacy.html"),("Refund","refund.html"),("Pricing","pricing.html"),("Contact","contact.html"),("About","about.html")]

def page(fn, title, desc, body):
    nav = "".join(f'<a href="{u}">{t}</a>' for t, u in NAV)
    out = f"""<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<title>{E(title)} – {E(B['name'])}</title><meta name="description" content="{E(desc)}">
<meta name="theme-color" content="#070b14"><link rel="icon" href="icon.svg">
<style>{CSS}</style></head><body><div class="w">
<header><b>{E(B['name'])}</b><a href="index.html">Back to home</a></header>
{body}
<nav class="f" aria-label="Policies">{nav}</nav>
<p style="font-size:13px;margin-top:14px">© {E(B['name'])}. Education and practice platform. No tips, signals or investment advice.</p>
</div></body></html>"""
    (ROOT / fn).write_text(out, encoding="utf-8")

N, C = E(B["name"]), E(B["email"])
contact_line = f'<a href="mailto:{C}">{C}</a> or WhatsApp <a href="{E(B["wa"])}">{E(B["phone"])}</a>'

# ---------- Terms ----------
page("terms.html", "Terms of Use", f"Terms of use for {B['name']}.", f"""
<h1>Terms of use</h1><p class="lead">Last updated {B['updated']}.</p>
<article>
<h3>What this site is</h3><p>{N} is an <b>education and practice platform</b>. It offers courses, a trading journal, a replay lab with demo money, and calculators. It does not give tips, signals, recommendations or personal investment advice, and it does not manage anyone’s money. We are not a SEBI-registered investment adviser or research analyst.</p>
<h3>Data sources</h3><p>Historical price data in the Lab (BANKNIFTY, Gold/XAUUSD) and end-of-day data in Market Movers come from third-party sources and are provided for <b>education and practice only</b>. They may contain gaps or errors and are not live. Names such as NSE, NIFTY and BANKNIFTY belong to their owners; we are not affiliated with or endorsed by them. You may not copy, scrape or resell data from this site. If you are a data owner and want something removed, contact us and we will act promptly.</p>
<h3>No promise of profit</h3><p>Trading in shares, futures, options, gold and other markets carries a high risk of loss. Backtests and demo results use historical data and simplified costs. They are not a prediction of future results. You alone are responsible for your trading decisions.</p>
<h3>Your account and access</h3><p>Paid content is for the person who bought it. Do not share your login, videos, PDFs or indicator code. “Lifetime access” means access for as long as the Academy is offered. We may suspend access if an account is shared, content is copied or resold, or the service is misused. No refund is due in that case.</p>
<h3>Payments</h3><p>Payments are in Indian rupees (INR) and are processed by our payment partner Razorpay (UPI, cards, net banking, wallets). We do not see or store your card or bank details. Access is switched on after the payment is confirmed. See the <a href="refund.html">Refund policy</a>.</p>
<h3>Our content</h3><p>Lessons, videos, PDFs, indicators, designs and software belong to {N}. You get a personal, non-transferable licence to use them for your own learning. You may not copy, record, resell or publish them.</p>
<h3>Liability</h3><p>The service is provided as it is. To the extent the law allows, {N} is not liable for any trading loss, lost profit or indirect loss arising from your use of the site. Our total liability for any claim is limited to the amount you paid us in the last 12 months.</p>
<h3>Changes and law</h3><p>We may update these terms and will change the date at the top. These terms are governed by the laws of India. Courts at {E(B['city'])} have jurisdiction, subject to any rights you have under consumer law.</p>
<h3>Contact</h3><p>{contact_line}</p>
</article>""")

# ---------- Refund ----------
page("refund.html", "Refund, Cancellation and Delivery Policy", f"Refund, cancellation and delivery policy of {B['name']}.", f"""
<h1>Refund, cancellation and delivery</h1><p class="lead">Last updated {B['updated']}.</p>
<article>
<h3>What you are buying</h3><p>A digital product: online access to the Academy (courses, PDF notes, indicators). Nothing is shipped. Prices are in INR.</p>
<h3>Delivery</h3><p>Access starts after your payment is confirmed, usually within a few minutes (automatically) and in any case within 24 hours. Sign in with the same email you used at checkout. If you did not get access, contact us and we will fix it.</p>
<h3>{B['days']}-day refund</h3><p>If the Academy is not right for you, ask for a refund within <b>{B['days']} days</b> of your payment date, as long as you have completed <b>less than {B['pct']}%</b> of the lessons. This stops full courses being finished and then refunded.</p>
<h3>How to ask</h3><p>Message us at {contact_line} from the contact details you used to buy, with your registered email. Tell us briefly why; it helps us improve.</p>
<h3>When you get the money</h3><p>Approved refunds go back to the original payment method within <b>7 working days</b>. Your bank may take extra time to show it.</p>
<h3>Cancellation</h3><p>There is no subscription or auto-renewal. You pay once, so there is nothing to cancel later.</p>
<h3>Double payment or failed access</h3><p>If you were charged twice, or paid but did not get access, contact us at any time. We will fix it or refund the extra amount.</p>
<h3>Not refundable</h3><p>Accounts that were shared or misused, and requests made after the refund window.</p>
</article>""")

# ---------- Privacy ----------
page("privacy.html", "Privacy Policy", f"Privacy policy of {B['name']}.", f"""
<h1>Privacy policy</h1><p class="lead">Last updated {B['updated']}.</p>
<article>
<h3>What we collect</h3><p>Journal, Lab and Tools data (trades, notes, settings, checklists) stays on <b>your own device</b> in your browser storage by default, and we do not receive it. If you clear browser data it is gone, so use Export. If you choose Cloud backup in the Journal, your trades are copied to our database (Supabase) and linked to your account. You can delete the cloud copy at any time from the same screen.</p>
<p>Academy account data: your email, your phone number if you share it for payment or support, your plan, amount paid, payment reference and expiry date. Messages you send us on WhatsApp or email.</p>
<h3>Why we use it</h3><p>To give you access to paid content, confirm payments, answer support questions and send service messages. We do not sell your personal data.</p>
<h3>Who helps us run the site</h3><p>Your Academy login and course data are stored with our database provider (Supabase). Payments are handled by Razorpay; we do not see or store your card or bank details. Some scripts load from public content networks. If we add analytics or advertising tools later, we will update this page.</p>
<h3>How long we keep it</h3><p>Academy records are kept while your account is active and for the period needed for accounts, tax and dispute records. You can ask us to delete your account data sooner, except where we must keep a record by law.</p>
<h3>Your choices</h3><p>You can ask to see, correct or delete the personal data we hold about you, and withdraw consent to messages at any time. Contact: {contact_line}</p>
<h3>Age</h3><p>This site is for people aged 18 and over.</p>
</article>""")

# ---------- Contact ----------
owner_row = f"<tr><td>Operated by</td><td>{E(B['owner'])}</td></tr>" if B["owner"] else ""
page("contact.html", "Contact Us", f"Contact details of {B['name']}.", f"""
<h1>Contact us</h1><p class="lead">Questions, payment help or refund requests. We reply within 1 working day.</p>
<article><table>
<tr><td>Business</td><td>{N}</td></tr>{owner_row}
<tr><td>Email</td><td><a href="mailto:{C}">{C}</a></td></tr>
<tr><td>Phone / WhatsApp</td><td><a href="tel:{E(B['phone'].replace(' ',''))}">{E(B['phone'])}</a> · <a href="{E(B['wa'])}">WhatsApp</a></td></tr>
<tr><td>Address</td><td>{E(B['address'])}</td></tr>
<tr><td>Support hours</td><td>Monday to Saturday, 10:00 to 19:00 IST</td></tr>
</table></article>""")

# ---------- Pricing ----------
page("pricing.html", "Pricing", f"{B['name']} Academy pricing: one payment of Rs {B['price']}, lifetime access.", f"""
<h1>Pricing</h1><p class="lead">One simple plan. No subscription, no auto-renewal.</p>
<article>
<h2>BFT Academy – lifetime access</h2>
<p class="big">₹{B['price']}</p><p>One-time payment in INR · digital access · inclusive of applicable taxes</p>
<ul><li>All price-action courses and lessons, including those added later</li><li>PDF notes</li><li>TradingView indicators for study and practice (education only, not signals)</li><li>Practice on the Testing Lab with demo money</li></ul>
<p>Pay securely with UPI, cards, net banking or wallets through Razorpay. Access is activated after payment confirmation. See the <a href="refund.html">refund policy</a> ({B['days']}-day refund).</p>
<a class="btn" href="academy.html#pricing">Go to the Academy</a>
<h3>Free</h3><p>The Journal, Testing Lab, Classroom board, Tools, Market Movers and Reality Check are free. Some Academy lessons are free to preview.</p>
</article>
<p style="font-size:13px"><b>Education only.</b> No tips, signals or investment advice. Trading involves risk of loss. We do not promise profit.</p>""")

# ---------- About ----------
page("about.html", "About", f"About {B['name']}.", f"""
<h1>About {N}</h1>
<article>
<p>{N} is an independent trading <b>education and practice</b> platform based in {E(B['city'])}, {E(B['state'])}. It helps traders learn price action, practise on real historical market data with demo money, test an idea on unseen data, and keep a journal to find the habits that cost money.</p>
<h3>What we do not do</h3><ul><li>We do not give buy or sell tips, signals or calls.</li><li>We do not manage money or take deposits for trading.</li><li>We do not promise profits. Trading carries a high risk of loss.</li></ul>
<h3>What we offer</h3><ul><li><a href="journal.html">Journal</a>: log trades, see your leaks, weekly reports.</li><li><a href="trade-lab-pro.html">Testing Lab</a>: replay history, backtest and forward-test with demo money.</li><li><a href="classroom.html">Classroom</a> and <a href="tools.html">Tools</a>: teach and calculate.</li><li><a href="academy.html">Academy</a>: structured courses, notes and indicators (paid).</li></ul>
<h3>Get in touch</h3><p>{contact_line}. See <a href="contact.html">Contact</a>.</p>
</article>""")

# ---------- legal.html (kept so old links work) ----------
page("legal.html", "Terms, Refund and Privacy", "Policies of BFT Trade Lab.", f"""
<h1>Policies</h1><article><ul>
<li><a href="terms.html">Terms of use</a></li><li><a href="refund.html">Refund, cancellation and delivery</a></li><li><a href="privacy.html">Privacy policy</a></li><li><a href="pricing.html">Pricing</a></li><li><a href="contact.html">Contact</a></li><li><a href="about.html">About</a></li></ul></article>""")
print("built", ", ".join(f for _, f in NAV) + ", legal.html")
