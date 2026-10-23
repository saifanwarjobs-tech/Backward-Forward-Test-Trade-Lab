# Market Events + Telegram alerts (free)

`events.html` shows the events that move the Indian market, in IST: last 7 days + upcoming, a countdown to the next high-impact event, and BankNifty history (time-of-day and event days).

## What is where
| File | Job |
|---|---|
| `data/events.json` | The events the page shows. Edit by hand or regenerate with `scripts/seed_events.py` |
| `scripts/seed_events.py` | Official dates (RBI, Fed, US CPI/jobs, NSE expiry and holidays) -> events.json. Hand-added events are kept |
| `data/event-history.json` | Past dates per event type, used for "on past Budget days BankNifty moved 3x" |
| `scripts/build_impact.py` | Reads `bank-nifty-5m-data.csv` and writes `data/impact.json` |
| `scripts/event_alerts.py` | Telegram reminders + deletes events older than 7 days |
| `.github/workflows/event-alerts.yml` | Runs the alert script every 15 minutes |

## One-time Telegram setup (5 minutes)
1. Telegram > search **@BotFather** > `/newbot` > copy the bot token.
2. Create a **public channel** (e.g. `BFT Market Events`) with a username like `bft_market_events`.
3. Channel > Administrators > add your bot as admin (allow "Post messages").
4. GitHub repo > Settings > Secrets and variables > Actions > New secret:
   - `TELEGRAM_BOT_TOKEN` = the token
   - `TELEGRAM_CHAT_ID` = `@bft_market_events` (your channel username)
5. In `data/events.json`, set `"telegram": "https://t.me/bft_market_events"` under `meta`. The "Join on Telegram" button then appears on the page.
6. Actions tab > **Event alerts** > Run workflow. Without the two secrets it only prints what it would send.

Alerts: one morning note (about 8:30 am IST, today's events) and a heads-up 60 minutes before every high or medium impact event with a clock time. Nothing is sent twice. Messages are reminders and never say buy or sell (SEBI).
Settings (top of `scripts/event_alerts.py`): `PRE_MINUTES`, `DIGEST_HOUR`, `KEEP_DAYS`.

## Keeping it fresh
- Add dates for the next months to `scripts/seed_events.py` (RBI, Fed, BLS and NSE holiday lists are published for the whole year) and run `python3 scripts/seed_events.py`, then commit.
- Fill `data/event-history.json` with past RBI / Fed / CPI / NFP dates from the official sites, then run `python3 scripts/build_impact.py` and commit. The page shows the history line only for types with 3 or more past days. Do not guess dates.
- Add a one-off event (bank results, a special session) by adding an object to `events.json`: `id`, `title`, `start` (ISO with +05:30), `impact` (high / med / low), `region` (IN / US), `type`, `note`.

## Limits and notes
- No live "actual vs forecast" numbers yet. That needs a licensed economic-calendar API (for when you have paying customers). Do not scrape Forex Factory: their terms forbid it.
- GitHub can start a scheduled run a few minutes late, so the "60 minutes before" message can arrive a little off.
- Actions are free on a public repo. On a private repo, 96 runs a day will use up the free minutes.
- Issuers can change dates. The page tells people to confirm on the official site.
- Tests: `python3 -m unittest discover tests`
