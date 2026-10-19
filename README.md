# BFT Trade Lab

Static site (plain HTML/JS, no build step). Open `index.html` or serve the folder with any static host.

| Page | What it is |
|---|---|
| `index.html` | Home: Premium Journal, Academy, Pro Lab, Classroom |
| `journal.html` | Premium Journal (localStorage; CSV import/export) |
| `academy.html` | Academy (courses, PDFs, indicators). Content comes from the database; manage it in `admin.html` |
| `admin.html` | Admin 2.0: dashboard, course/module/lesson builder, video/PDF/cover upload, indicators, students (expiry, amount, WhatsApp) |
| `trade-lab-pro.html` | Pro replay lab, backtest + locked forward test |
| `classroom.html` | Teaching board |
| `screener.html` | Market Movers: end-of-day top gainers/losers, 52-week highs/lows, volume spikes (data in `data/screener.json`) |
| `tools.html` | Trading tools (calculators, checklists) |
| `legal.html` | Terms, privacy and refund policy |

Data (pick in the Pro Lab header dropdown):
- `bank-nifty-5m-data.csv` (Jan 2015 to Apr 2024)
- `xauusd-m15-data.csv` (Jul 2022 to Oct 2026), `xauusd-m30-data.csv` (May 2018 to Oct 2026), `xauusd-h1-data.csv` (Jan 2010 to Oct 2026): Gold XAUUSD, broker server time, Sunday bars merged into Monday. Gold profile: 1 lot = 10 oz, $10,000 demo, 1:100 margin, 0.40 spread.
- Added Oct 2026 (stored as `.csv.gz`, loaded in the browser): Bitcoin BTCUSD M1/M5/M15/M30/H1/H4/D1 (2017 to Oct 2026, shorter ranges on the small timeframes) and Gold XAUUSD M1/M5/H4/D1. MT5 broker export (1 lot = 0.01 BTC for Bitcoin).

Academy setup (once):
1. Supabase > SQL Editor: run `schema.sql` (safe to re-run; migrates v1 data). First time also: `insert into admins values ('you@email.com');`
2. Supabase > Authentication > Providers > Email: turn ON "Confirm email" (the admin dashboard warns if it is off).
3. Open `admin.html`, sign in, add content. Students: add their email after payment.

Before charging: confirm the data licence for the CSV files, set up custom SMTP in Supabase (the default sender is heavily rate-limited), and add a support email in `legal.html` (`B.email`).

Payment is still manual UPI + WhatsApp (temporary). See DECISIONS.md.

## Market Movers (screener) setup
Data is end-of-day (not live) and refreshes itself every weekday evening. You never upload anything.
1. GitHub repo > Settings > Actions > General > Workflow permissions: choose **Read and write permissions**.
2. Actions tab > **Update screener data** > Run workflow (once). The first run downloads about a year of history and takes a few minutes. After that it runs by itself at 19:00 and 21:00 IST on weekdays.
3. Add or remove stocks in `universe.json` (exact NSE symbols). Symbols NSE does not return are listed in `data/screener.json` under `meta.missing`.
4. If NSE blocks or changes the file, the run turns red (GitHub emails you) and the page keeps showing the last data with its "As of" date.
5. Check NSE's terms for using their end-of-day files in a paid product before charging for this.

## Journal extras
- Import trades: accepts your own CSV (one row per completed trade) or a broker tradebook CSV (symbol, buy/sell, quantity, price, time). Fills are merged by order and paired first-in-first-out into completed trades. Charges are not in a tradebook, so they import as 0.
- Report (Menu > Report): weekly / monthly summary, print or save as PDF, copy for WhatsApp.
- Cloud backup (Menu > Cloud backup): optional. Run the latest `schema.sql` once in Supabase (it adds the `journal_cloud` table with row-level security). Sync merges trades across devices; it never deletes.
