# BFT Trade Lab

Static site (plain HTML/JS, no build step). Open `index.html` or serve the folder with any static host.

| Page | What it is |
|---|---|
| `index.html` | Home: Premium Journal, Academy, Pro Lab, Classroom |
| `journal.html` | Premium Journal (localStorage; CSV import/export) |
| `academy.html` | Academy. Edit `CFG`, `COURSES`, `BOOKS` at the top of its script |
| `trade-lab-pro.html` | Pro replay lab, backtest + locked forward test |
| `classroom.html` | Teaching board |
| `backtest.html` | Classic lab (Supabase login/sync) |

Data (pick in the Pro Lab header dropdown):
- `bank-nifty-5m-data.csv` (Jan 2015 to Apr 2024)
- `xauusd-m15-data.csv` (Jul 2022 to Oct 2026), `xauusd-m30-data.csv` (May 2018 to Oct 2026), `xauusd-h1-data.csv` (Jan 2010 to Oct 2026): Gold XAUUSD, broker server time, Sunday bars merged into Monday. Gold profile: 1 lot = 10 oz, $10,000 demo, 1:100 margin, 0.40 spread.

Not production-ready yet: Academy paywall is client-side only, video/book links are empty, payment link and contact number are placeholders. See DECISIONS.md.
