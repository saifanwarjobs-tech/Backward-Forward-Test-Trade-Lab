#!/usr/bin/env python3
"""Builds data/impact.json for events.html from bank-nifty-5m-data.csv. Standard library only.

Two things are computed:
  1. "tod": how much BankNifty moves in each 15-minute slot of the day (average range, % of price).
  2. "types": for every event type listed in data/event-history.json, how the index behaved on those
     past days compared with a normal day (day range, first-30-minute range, direction).

Add past dates to data/event-history.json (see its "_help" key) and run:  python3 scripts/build_impact.py
Dates the CSV does not contain (holiday, after April 2024) are listed under "missing", never guessed.
This is history, not a forecast. The page says so.
"""
import csv, json, os, statistics, sys
from collections import defaultdict
from datetime import datetime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CSV = os.path.join(ROOT, 'bank-nifty-5m-data.csv')
HIST = os.path.join(ROOT, 'data', 'event-history.json')
OUT = os.path.join(ROOT, 'data', 'impact.json')


def load_days(path):
    """-> {iso_date: [(minute_of_day, o, h, l, c), ...]} sorted by time."""
    days = defaultdict(list)
    with open(path, newline='') as f:
        for r in csv.DictReader(f):
            try:
                d = datetime.strptime(r['Date'], '%d-%m-%Y').strftime('%Y-%m-%d')
                hh, mm = r['Time'].split(':')[:2]
                m = int(hh) * 60 + int(mm)
                days[d].append((m, float(r['Open']), float(r['High']), float(r['Low']), float(r['Close'])))
            except (ValueError, KeyError):
                continue
    for d in days:
        days[d].sort()
    return days


def day_stats(bars):
    o, c = bars[0][1], bars[-1][4]
    hi, lo = max(b[2] for b in bars), min(b[3] for b in bars)
    first = [b for b in bars if b[0] < 9 * 60 + 15 + 30]
    f_rng = (max(b[2] for b in first) - min(b[3] for b in first)) / o * 100 if first else None
    return {'range': (hi - lo) / o * 100, 'first30': f_rng, 'move': (c - o) / o * 100}


def tod_table(days):
    acc = defaultdict(list)
    for bars in days.values():
        slots = defaultdict(list)
        for b in bars:
            slots[(b[0] // 15) * 15].append(b)
        for s, bs in slots.items():
            o = bs[0][1]
            acc[s].append((max(x[2] for x in bs) - min(x[3] for x in bs)) / o * 100)
    out = []
    for s in sorted(acc):
        if 9 * 60 + 15 <= s < 15 * 60 + 30:
            out.append({'t': '%02d:%02d' % divmod(s, 60), 'avg_range_pct': round(statistics.mean(acc[s]), 3)})
    return out


def mean(xs):
    xs = [x for x in xs if x is not None]
    return statistics.mean(xs) if xs else None


def build(days, hist):
    st = {d: day_stats(b) for d, b in days.items() if len(b) >= 40}  # skip half days / bad days
    ev_dates = {d for t in hist.values() if isinstance(t, dict) for d in t.get('dates', [])}
    normal = [v for d, v in st.items() if d not in ev_dates]
    base_rng = statistics.median(v['range'] for v in normal)
    base_f30 = statistics.median(v['first30'] for v in normal if v['first30'] is not None)
    out = {
        'source': 'bank-nifty-5m-data.csv',
        'from': min(st), 'to': max(st), 'days': len(st),
        'baseline': {'day_range_pct': round(base_rng, 3), 'first30_range_pct': round(base_f30, 3)},
        'tod': tod_table({d: days[d] for d in st}),
        'types': {},
    }
    for key, t in hist.items():
        if key.startswith('_') or not isinstance(t, dict):
            continue
        got = [(d, st[d]) for d in t.get('dates', []) if d in st]
        missing = [d for d in t.get('dates', []) if d not in st]
        if not got:
            out['types'][key] = {'label': t.get('label', key), 'n': 0, 'missing': missing}
            continue
        rng = mean(v['range'] for _, v in got)
        out['types'][key] = {
            'label': t.get('label', key), 'n': len(got),
            'avg_day_range_pct': round(rng, 3),
            'x_normal': round(rng / base_rng, 2),
            'avg_first30_pct': round(mean(v['first30'] for _, v in got), 3),
            'avg_abs_move_pct': round(mean(abs(v['move']) for _, v in got), 3),
            'up_days': sum(1 for _, v in got if v['move'] > 0),
            'dates': [d for d, _ in got], 'missing': missing,
        }
    return out


def main():
    days = load_days(CSV)
    hist = json.load(open(HIST)) if os.path.exists(HIST) else {}
    out = build(days, hist)
    with open(OUT, 'w') as f:
        json.dump(out, f, separators=(',', ':'))
    print('wrote %s: %d days, %d event types' % (OUT, out['days'], len(out['types'])))
    for k, v in out['types'].items():
        print(' ', k, 'n=%d' % v['n'], 'x_normal=%s' % v.get('x_normal'), 'missing=%s' % v['missing'])


if __name__ == '__main__':
    sys.exit(main())
