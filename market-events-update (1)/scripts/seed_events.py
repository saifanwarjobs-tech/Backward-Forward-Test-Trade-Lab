#!/usr/bin/env python3
"""Generates the events in data/events.json. Standard library only.

Everything here comes from official calendars (checked Oct 2026):
  RBI MPC FY27      rbi.org.in press release 62422 (decision on the last day of each meeting)
  US Fed (FOMC)     federalreserve.gov / chicagofed.org calendar
  US CPI and jobs   bls.gov/schedule/2026
  NSE expiry        Nifty weekly = Tuesday, Nifty / Bank Nifty / Fin Nifty monthly = last Tuesday,
                    a holiday moves the expiry to the previous trading day
  NSE holidays      NSE holiday list 2026

You can also edit data/events.json by hand. Events you add by hand (no "src":"seed") are kept when this
script is run again. To add next year's events, add the dates below and run:  python3 scripts/seed_events.py
"""
import json, os
from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'data', 'events.json')
IST, NY = ZoneInfo('Asia/Kolkata'), ZoneInfo('America/New_York')

HOLIDAYS = {  # NSE trading holidays on weekdays, Oct to Dec 2026
    date(2026, 10, 20): 'Dussehra',
    date(2026, 11, 10): 'Diwali (Balipratipada)',
    date(2026, 11, 24): 'Prakash Gurpurb (Guru Nanak Jayanti)',
    date(2026, 12, 25): 'Christmas',
}
EXPIRY_UNTIL = date(2026, 12, 31)  # holiday list for 2027 is not out yet
EXPIRY_FROM = date(2026, 10, 16)
RBI_DECISIONS = [date(2026, 12, 4), date(2027, 2, 5)]  # 10:00 IST announcement is the usual time, confirm on rbi.org.in
FOMC_STATEMENTS = [date(2026, 10, 28), date(2026, 12, 9)]  # 2:00 pm New York
US_NFP = [date(2026, 11, 6), date(2026, 12, 4)]            # 8:30 am New York
US_CPI = [date(2026, 11, 10), date(2026, 12, 10)]          # 8:30 am New York


def ist(y, m, d, hh, mm):
    return datetime(y, m, d, hh, mm, tzinfo=IST)


def from_ny(day, hh, mm):
    return datetime(day.year, day.month, day.day, hh, mm, tzinfo=NY).astimezone(IST)


def iso(dt):
    return dt.isoformat(timespec='minutes')


def prev_trading_day(d):
    while d.weekday() >= 5 or d in HOLIDAYS:
        d -= timedelta(days=1)
    return d


def last_tuesday(y, m):
    d = date(y + (m == 12), m % 12 + 1, 1) - timedelta(days=1)
    while d.weekday() != 1:
        d -= timedelta(days=1)
    return d


def expiries():
    monthly = {last_tuesday(y, m) for y in (2026,) for m in range(1, 13)}
    out, d = [], EXPIRY_FROM
    while d <= EXPIRY_UNTIL:
        if d.weekday() == 1:
            real = prev_trading_day(d)
            is_month = d in monthly
            out.append({
                'id': 'exp-%s' % real.isoformat(),
                'title': 'Monthly expiry: Bank Nifty, Nifty, Fin Nifty' if is_month else 'Nifty weekly expiry',
                'start': iso(ist(real.year, real.month, real.day, 15, 30)),
                'impact': 'med' if is_month else 'low', 'region': 'IN',
                'type': 'expiry_monthly' if is_month else 'expiry_weekly',
                'note': ('Moved from %s because of a holiday. ' % d.strftime('%a %d %b') if real != d else '') +
                        'Contracts settle at 3:30 pm.'})
        d += timedelta(days=1)
    return out


def build():
    ev = []
    for d in RBI_DECISIONS:
        ev.append({'id': 'rbi-%s' % d, 'title': 'RBI monetary policy decision', 'start': iso(ist(d.year, d.month, d.day, 10, 0)),
                   'impact': 'high', 'region': 'IN', 'type': 'rbi',
                   'note': 'Repo rate decision, usually announced at 10:00 am. Banks and Bank Nifty react most.'})
    for d in FOMC_STATEMENTS:
        t = from_ny(d, 14, 0)
        ev.append({'id': 'fomc-%s' % d, 'title': 'US Fed rate decision (FOMC)', 'start': iso(t), 'impact': 'high', 'region': 'US', 'type': 'fomc',
                   'note': 'Comes after the Indian market closes. The reaction shows up in the next India session.'})
    for d in US_NFP:
        ev.append({'id': 'nfp-%s' % d, 'title': 'US jobs report (NFP)', 'start': iso(from_ny(d, 8, 30)), 'impact': 'high', 'region': 'US', 'type': 'us_nfp',
                   'note': 'Released after India closes. Moves global markets and gold, India reacts next day.'})
    for d in US_CPI:
        ev.append({'id': 'cpi-%s' % d, 'title': 'US inflation (CPI)', 'start': iso(from_ny(d, 8, 30)), 'impact': 'high', 'region': 'US', 'type': 'us_cpi',
                   'note': 'Released after India closes. Changes Fed rate hopes, so it moves global markets.'})
    for d, name in HOLIDAYS.items():
        ev.append({'id': 'hol-%s' % d, 'title': 'Market closed: ' + name, 'start': iso(ist(d.year, d.month, d.day, 0, 0)), 'all_day': True,
                   'impact': 'low', 'region': 'IN', 'type': 'holiday', 'note': 'NSE and BSE equity and F&O are closed.'})
    ev.append({'id': 'muhurat-2026', 'title': 'Diwali Muhurat trading (special session)', 'start': iso(ist(2026, 11, 8, 0, 0)), 'all_day': True, 'time_tba': True,
               'impact': 'low', 'region': 'IN', 'type': 'muhurat', 'note': 'Sunday. NSE announces the exact timing closer to the date.'})
    ev += expiries()
    for e in ev:
        e['src'] = 'seed'
    return ev


def main():
    old = json.load(open(OUT)) if os.path.exists(OUT) else {}
    keep = [e for e in old.get('events', []) if e.get('src') != 'seed']
    meta = old.get('meta', {})
    meta.setdefault('telegram', '')
    meta['sources'] = 'RBI, US Federal Reserve, US BLS, NSE'
    events = sorted(keep + build(), key=lambda e: e['start'])
    with open(OUT, 'w') as f:
        json.dump({'meta': meta, 'events': events}, f, indent=1, ensure_ascii=False)
    print('wrote %s with %d events (%d added by hand kept)' % (OUT, len(events), len(keep)))


if __name__ == '__main__':
    main()
