# Honest Forward Test: setup

The forward test used to be a browser-only lock on data that every visitor could download. Now:

- The **rules are locked on the server** (Supabase), with the server's clock. They cannot be edited or deleted, and each new lock is a numbered attempt.
- The **reserved (holdout) candles are not in the public files any more.** They sit in a private Supabase bucket and are released only to a signed-in user who has locked rules for that dataset, and who owns the Lab (or the dataset is on the free list).
- One cutoff date per instrument for every timeframe, so a finer timeframe can't leak the reserved period.

What this proves: "these rules existed, with this timestamp, before the reserved data was opened, on attempt N."
What it does not prove: that the trades followed the rules. Trading in the Lab is manual, and trade history stays in the browser.

## Go live (about 20 minutes)

1. **Supabase > SQL Editor:** run `schema_forward.sql` (after `schema.sql` and `schema_pricing.sql`; safe to re-run). It creates `fw_locks`, `fw_free`, the `fw_lock()` function, and the private `holdout` bucket with its access rule.
2. **Supabase > Storage > holdout > Upload:** upload every file from the `holdout/` folder (zip delivered separately). Keep the file names exactly (`xauusd-h1-data.csv.gz`, ...). Never make this bucket public.
3. **Site files:** upload to GitHub Pages
   - changed: `trade-lab-pro.html`, `access.js`, `sw.js`
   - replaced: every `*-data.csv.gz` (now truncated to the public part)
   - **delete** from the repo: `xauusd-h1-data.csv`, `xauusd-m15-data.csv`, `xauusd-m30-data.csv`, `bank-nifty-5m-data.csv` (the plain files are the full data), and `xauusd-m1-data.csv.gz`, `btcusd-m1-data.csv.gz` (see "Forward-only" below).
   - new (optional, for your own use): `scripts/split_holdout.py`, `tests/test_split_holdout.py`, this file.
4. **Git history:** the old full files are still in your repo's earlier commits and anyone can open them. To close that, either start a fresh repo with only the new files, or purge history (`git filter-repo --path-glob '*-data.csv*' --invert-paths`, then re-add the truncated files and force-push). Copies people already downloaded cannot be recalled; the honesty guarantee applies to the data from your next holdout onward (see "Rolling the holdout").
5. **Test it once** (private window): open the Lab > Forward Test. You should see the chart end at the cutoff date, stepping blocked. Write rules, press Lock, sign in (free), then the reserved period appears and "attempt 1" shows. Reload: it comes back from the server. Check `fw_locks` in Supabase Table Editor: your row is there.

## Settings

- **Cutoff dates:** `CUTOFFS` at the top of `scripts/split_holdout.py` (Gold 2025-09-26, Bitcoin 2026-02-02, Bank Nifty = last 25%).
- **Free forward-test datasets:** table `fw_free` (Table Editor). It ships with `xauusd-d1-data` so a free account can try one real forward test before paying. Everything else needs `lab` or `all_tools` (checked on the server, not in the browser). Add or remove rows any time.
- **Rate limit:** 30 locks per user per day (`fw_lock()` in `schema_forward.sql`).

## Rolling the holdout (monthly or quarterly)

Put the new full price files in a private folder named `_private-full-data/`, move the dates in `CUTOFFS` later, run `python3 scripts/split_holdout.py`, replace the public `*.csv.gz` files on the site and re-upload `holdout/` to the bucket. The previously reserved months become public backtest data and fresh months become the new reserved period. Tell users the old attempts ran on the previous period.

## Forward-only datasets (removed from the dropdown)

Gold M1 (starts Jul 2026) and Bitcoin M1 (starts Aug 2026) begin after the cutoff, so they have no public part and cannot be backtested. They are held back entirely. After a roll or two they will have enough public history and can be added back to `INSL` in `trade-lab-pro.html`.

## Not covered here

- **Data licence.** This protects the reserved data from casual viewing. It does not make the price files licensed for resale. Settle the source terms in writing (or use a broker-supplied feed) before charging.
- Users can still upload their own CSV; those runs keep the old browser-only lock and are not server-verified.
- Trades are not audited on the server (a later step: log each trade with a server timestamp).
