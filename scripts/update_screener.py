#!/usr/bin/env python3
"""Daily updater for screener.html. Standard library only.

Downloads NSE end-of-day files, keeps ~1 year of history for the stocks in
universe.json and writes data/screener.json.

Fails safe: if NSE cannot be reached the old data stays in place, and the page
shows the "as of" date. A non-holiday download error makes the script exit 1 so
the GitHub Action turns red and GitHub emails you.
"""
import csv, io, json, os, sys, time, zipfile, urllib.request, urllib.error
from datetime import datetime, timedelta, timezone

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UNIVERSE = os.path.join(ROOT, 'universe.json')
HIST = os.path.join(ROOT, 'data', 'history.json')
OUT = os.path.join(ROOT, 'data', 'screener.json')
BASE = os.environ.get('BHAV_BASE', 'https://nsearchives.nseindia.com').rstrip('/')
KEEP_DAYS = 270          # trading days of history to keep
BACKFILL_DAYS = 400      # calendar days to fetch on the very first run
MAX_FETCH = 330          # safety cap per run
UA = {'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/124 Safari/537.36',
      'Accept': '*/*', 'Accept-Language': 'en-US,en;q=0.9'}
IST = timezone(timedelta(hours=5, minutes=30))


def get(url):
    """Return bytes, None for 404 (holiday / not published yet), raise otherwise."""
    last = None
    for i in range(3):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=40) as r:
                return r.read()
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return None
            last = e
        except Exception as e:  # timeouts, resets
            last = e
        time.sleep(1.5 * (i + 1))
    raise last


def num(x):
    try:
        return float(str(x).replace(',', '').strip())
    except Exception:
        return None


def parse(text, universe):
    """Handle both NSE layouts. Returns {symbol: [close, vol, high, low, prev]}."""
    rows = csv.reader(io.StringIO(text))
    head = [h.strip().upper() for h in next(rows)]
    ix = {h: i for i, h in enumerate(head)}

    def pick(*names):
        for n in names:
            if n.upper() in ix:
                return ix[n.upper()]
        return None
    c_sym = pick('SYMBOL', 'TckrSymb'); c_ser = pick('SERIES', 'SctySrs')
    c_cl = pick('CLOSE_PRICE', 'ClsPric'); c_pv = pick('PREV_CLOSE', 'PrvsClsPric')
    c_hi = pick('HIGH_PRICE', 'HghPric'); c_lo = pick('LOW_PRICE', 'LwPric')
    c_vo = pick('TTL_TRD_QNTY', 'TtlTradgVol')
    if None in (c_sym, c_ser, c_cl, c_pv, c_hi, c_lo, c_vo):
        raise ValueError('Unknown NSE file layout. Header: ' + ','.join(head))
    out = {}
    for r in rows:
        if len(r) <= max(c_sym, c_ser, c_cl, c_pv, c_hi, c_lo, c_vo):
            continue
        s = r[c_sym].strip()
        if s not in universe or r[c_ser].strip() != 'EQ':
            continue
        v = [num(r[c_cl]), num(r[c_vo]), num(r[c_hi]), num(r[c_lo]), num(r[c_pv])]
        if None in v or v[0] <= 0 or v[4] <= 0:
            continue
        out[s] = v
    return out


def fetch_day(d, universe):
    urls = [f'{BASE}/products/content/sec_bhavdata_full_{d:%d%m%Y}.csv',
            f'{BASE}/content/cm/BhavCopy_NSE_CM_0_0_0_{d:%Y%m%d}_F_0000.csv.zip']
    for u in urls:
        raw = get(u)
        if raw is None:
            continue
        if u.endswith('.zip'):
            z = zipfile.ZipFile(io.BytesIO(raw))
            raw = z.read(z.namelist()[0])
        return parse(raw.decode('utf-8', 'replace'), universe)
    return None


def load(path, default):
    try:
        with open(path, encoding='utf8') as f:
            return json.load(f)
    except Exception:
        return default


def adjusted(series):
    """Back-adjust closes/highs/lows for splits and bonus issues.
    series = [(date, close, vol, high, low, prev), ...] oldest first."""
    n = len(series)
    mult = 1.0
    adj = [None] * n
    for i in range(n - 1, -1, -1):
        d, c, v, h, l, p = series[i]
        adj[i] = (c * mult, v, h * mult, l * mult)
        if i > 0:
            prev_close = series[i - 1][1]
            f = p / prev_close if prev_close else 1.0
            if abs(f - 1) > 0.015:   # NSE's prev close differs from yesterday's close: corporate action
                mult *= f
    return adj


def build(hist, universe, missing):
    dates = sorted(hist)
    rows = []
    for sym, tags in universe.items():
        s = [(d,) + tuple(hist[d][sym]) for d in dates if sym in hist[d]]
        if not s or s[-1][0] != dates[-1]:
            continue
        a = adjusted(s)
        closes = [x[0] for x in a]
        c = closes[-1]
        p = s[-1][5]

        def ch(n):
            return round((c / closes[-1 - n] - 1) * 100, 2) if len(closes) > n else None
        win = a[-252:]
        h52 = max(x[2] for x in win); l52 = min(x[3] for x in win)
        prior = [x[1] for x in a[-21:-1] if x[1]]
        vx = round(a[-1][1] / (sum(prior) / len(prior)), 2) if len(prior) >= 5 and a[-1][1] else None
        rows.append({'s': sym, 'c': round(c, 2), 'ch': round((s[-1][1] / p - 1) * 100, 2),
                     'w': ch(5), 'm': ch(21), 'q': ch(63),
                     'h52': round(h52, 2), 'l52': round(l52, 2),
                     'fh': round((c / h52 - 1) * 100, 2), 'fl': round((c / l52 - 1) * 100, 2),
                     'v': int(a[-1][1]), 'vx': vx, 't': tags,
                     'sp': [round(x[0], 2) for x in a[-30:]]})
    return rows


def main():
    universe = (load(UNIVERSE, {}) or {}).get('symbols') or {}
    if not universe:
        print('universe.json is empty or unreadable'); return 1
    hist = load(HIST, {})
    today = datetime.now(IST).date()
    start = (datetime.strptime(max(hist), '%Y-%m-%d').date() + timedelta(days=1)) if hist \
        else today - timedelta(days=BACKFILL_DAYS)
    d, fetched, errors, tries = start, 0, [], 0
    while d <= today and tries < MAX_FETCH:
        if d.weekday() < 5:
            tries += 1
            try:
                day = fetch_day(d, universe)
                if day:
                    hist[d.isoformat()] = day; fetched += 1
                    print('ok  ', d, len(day), 'symbols')
                else:
                    print('skip', d, '(holiday or not published yet)')
            except Exception as e:
                errors.append(f'{d}: {e}'); print('ERR ', d, e)
            time.sleep(0.4)
        d += timedelta(days=1)
    if not hist:
        print('No data at all. Nothing written.'); return 1
    for k in sorted(hist)[:-KEEP_DAYS]:
        del hist[k]
    os.makedirs(os.path.dirname(HIST), exist_ok=True)
    with open(HIST, 'w', encoding='utf8') as f:
        json.dump(hist, f, separators=(',', ':'), sort_keys=True)
    last = max(hist)
    missing = sorted(s for s in universe if s not in hist[last])
    rows = build(hist, universe, missing)
    meta = {'asof': last, 'updated': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
            'count': len(rows), 'days': len(hist), 'missing': missing,
            'source': 'NSE end-of-day files', 'errors': errors[:3]}
    with open(OUT, 'w', encoding='utf8') as f:
        json.dump({'meta': meta, 'rows': rows}, f, separators=(',', ':'))
    print(f'wrote {len(rows)} rows, as of {last}, new days {fetched}, errors {len(errors)}')
    return 1 if errors else 0


if __name__ == '__main__':
    sys.exit(main())
