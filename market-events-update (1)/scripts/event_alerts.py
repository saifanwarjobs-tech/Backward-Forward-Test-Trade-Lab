#!/usr/bin/env python3
"""Sends Telegram reminders for data/events.json and deletes events older than 7 days. Standard library only.

Runs every 15 minutes from GitHub Actions (.github/workflows/event-alerts.yml).
  * Morning note (about 8:30 am IST): today's events, once per day.
  * Heads-up: 60 minutes before every high or medium impact event that has a clock time.
  * Clean-up: events that ended more than 7 days ago are removed (like Forex Factory's one-week view).
Nothing is sent twice: what was sent is remembered in data/alerts-state.json.

Secrets (GitHub repo > Settings > Secrets and variables > Actions):
  TELEGRAM_BOT_TOKEN   from @BotFather
  TELEGRAM_CHAT_ID     your channel, e.g. @bft_market_events  (the bot must be an admin of the channel)
Without them the script only prints what it would send (dry run).

Test by hand:  python3 scripts/event_alerts.py --dry-run --now 2026-10-28T22:40+05:30
Messages are reminders only. They never say buy or sell.
"""
import argparse, html, json, os, sys, urllib.parse, urllib.request
from datetime import datetime, timedelta, timezone

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EVENTS = os.path.join(ROOT, 'data', 'events.json')
STATE = os.path.join(ROOT, 'data', 'alerts-state.json')
IST = timezone(timedelta(hours=5, minutes=30))
KEEP_DAYS = 7
PRE_MINUTES = 60
DIGEST_HOUR = 8            # morning note goes out at the first run after 08:00 IST (and before noon)
TAIL = '\nEducation only. Not a trade signal.'
ICON = {'high': '🔴', 'med': '🟠', 'low': '⚪'}


def parse(s):
    return datetime.fromisoformat(s)


def end_of(e):
    s = parse(e['start'])
    return s.replace(hour=23, minute=59) if e.get('all_day') else s


def has_clock(e):
    return not e.get('all_day') and not e.get('time_tba')


def fmt_time(e):
    s = parse(e['start']).astimezone(IST)
    if e.get('all_day'):
        return 'All day' + (' (time to be announced)' if e.get('time_tba') else '')
    return s.strftime('%I:%M %p').lstrip('0') + ' IST'


def prune(events, now):
    cut = now - timedelta(days=KEEP_DAYS)
    return [e for e in events if end_of(e) >= cut]


def select_alerts(events, state, now):
    """Pure function. Returns [(key, text)] that should be sent now and are not in state['sent']."""
    sent, out = state.get('sent', {}), []
    today = now.astimezone(IST).date()
    # morning note
    key = 'digest:%s' % today.isoformat()
    if key not in sent and DIGEST_HOUR <= now.astimezone(IST).hour < 12:
        todays = sorted((e for e in events if parse(e['start']).astimezone(IST).date() == today), key=lambda e: e['start'])
        todays = [e for e in todays if e['impact'] != 'low' or e.get('type') in ('holiday', 'muhurat')]
        if todays:
            lines = ['<b>Today (%s)</b>' % today.strftime('%a %d %b')]
            for e in todays:
                lines.append('%s %s  %s' % (ICON[e['impact']], fmt_time(e), html.escape(e['title'])))
            out.append((key, '\n'.join(lines) + TAIL))
    # heads-up
    for e in events:
        if e['impact'] == 'low' or not has_clock(e):
            continue
        k = 'pre:%s' % e['id']
        mins = (parse(e['start']) - now).total_seconds() / 60
        if k not in sent and 0 < mins <= PRE_MINUTES:
            body = '%s <b>%s</b> in about %d min (%s)' % (ICON[e['impact']], html.escape(e['title']), round(mins), fmt_time(e))
            if e.get('note'):
                body += '\n' + html.escape(e['note'])
            out.append((k, body + TAIL))
    return out


def send(token, chat, text):
    data = urllib.parse.urlencode({'chat_id': chat, 'text': text, 'parse_mode': 'HTML', 'disable_web_page_preview': 'true'}).encode()
    req = urllib.request.Request('https://api.telegram.org/bot%s/sendMessage' % token, data=data)
    with urllib.request.urlopen(req, timeout=20) as r:
        return json.load(r).get('ok') is True


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('--now', help='pretend it is this time, e.g. 2026-10-28T22:40+05:30')
    a = ap.parse_args()
    now = parse(a.now) if a.now else datetime.now(timezone.utc)
    if now.tzinfo is None:
        now = now.replace(tzinfo=IST)

    doc = json.load(open(EVENTS))
    n0 = len(doc['events'])
    doc['events'] = prune(doc['events'], now)
    state = json.load(open(STATE)) if os.path.exists(STATE) else {}
    state.setdefault('sent', {})

    token, chat = os.environ.get('TELEGRAM_BOT_TOKEN'), os.environ.get('TELEGRAM_CHAT_ID')
    dry = a.dry_run or not (token and chat)
    failed = False
    for key, text in select_alerts(doc['events'], state, now):
        if dry:
            print('[dry run] would send (%s):\n%s\n' % (key, text))
            continue
        try:
            if send(token, chat, text):
                state['sent'][key] = now.isoformat(timespec='minutes')
                print('sent', key)
            else:
                failed = True
        except Exception as ex:  # network or Telegram error: try again on the next run
            print('send failed for', key, ex, file=sys.stderr)
            failed = True

    keep_ids = {e['id'] for e in doc['events']}
    state['sent'] = {k: v for k, v in state['sent'].items()
                     if k.startswith('digest:') and k[7:] >= (now - timedelta(days=KEEP_DAYS)).date().isoformat()
                     or k.startswith('pre:') and k[4:] in keep_ids}
    if not a.dry_run:
        if len(doc['events']) != n0:
            with open(EVENTS, 'w') as f:
                json.dump(doc, f, indent=1, ensure_ascii=False)
            print('removed %d old events' % (n0 - len(doc['events'])))
        with open(STATE, 'w') as f:
            json.dump(state, f, indent=1, sort_keys=True)
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
