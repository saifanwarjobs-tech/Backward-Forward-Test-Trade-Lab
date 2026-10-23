import importlib.util, json, os, unittest
from datetime import date, datetime, timedelta, timezone

HERE = os.path.dirname(os.path.abspath(__file__))


def load(name):
    spec = importlib.util.spec_from_file_location(name, os.path.join(HERE, '..', 'scripts', name + '.py'))
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
    return m


al, seed, imp = load('event_alerts'), load('seed_events'), load('build_impact')
IST = timezone(timedelta(hours=5, minutes=30))


def at(s):
    return datetime.fromisoformat(s)


def ev(i, start, impact='high', **kw):
    d = {'id': i, 'title': 'T ' + i, 'start': start, 'impact': impact, 'region': 'IN', 'type': 'x', 'note': ''}
    d.update(kw)
    return d


class AlertTests(unittest.TestCase):
    def test_heads_up_only_inside_window_and_once(self):
        e = [ev('a', '2026-10-28T23:30+05:30')]
        self.assertEqual(al.select_alerts(e, {}, at('2026-10-28T22:00+05:30')), [])          # 90 min away
        out = al.select_alerts(e, {}, at('2026-10-28T22:40+05:30'))                           # 50 min away
        self.assertEqual([k for k, _ in out], ['pre:a'])
        self.assertEqual(al.select_alerts(e, {'sent': {'pre:a': 'x'}}, at('2026-10-28T22:50+05:30')), [])
        self.assertEqual(al.select_alerts(e, {}, at('2026-10-28T23:31+05:30')), [])          # already started

    def test_low_impact_and_all_day_never_get_heads_up(self):
        e = [ev('w', '2026-11-03T15:30+05:30', 'low'), ev('h', '2026-11-08T00:00+05:30', 'low', all_day=True, time_tba=True)]
        self.assertEqual(al.select_alerts(e, {}, at('2026-11-03T14:50+05:30')), [])

    def test_morning_note_once_in_the_morning(self):
        e = [ev('r', '2026-12-04T10:00+05:30'), ev('n', '2026-12-04T19:00+05:30'), ev('w', '2026-12-04T15:30+05:30', 'low')]
        self.assertEqual(al.select_alerts(e, {}, at('2026-12-04T07:45+05:30')), [])
        out = al.select_alerts(e, {}, at('2026-12-04T08:20+05:30'))
        self.assertEqual(len(out), 1)
        self.assertIn('10:00 AM IST', out[0][1]); self.assertIn('7:00 PM IST', out[0][1])
        self.assertNotIn('T w', out[0][1])                                                    # low impact left out
        self.assertEqual(al.select_alerts(e, {'sent': {'digest:2026-12-04': 'x'}}, at('2026-12-04T08:35+05:30')), [])

    def test_holiday_is_in_the_morning_note(self):
        e = [ev('h', '2026-11-10T00:00+05:30', 'low', type='holiday', all_day=True)]
        self.assertEqual(len(al.select_alerts(e, {}, at('2026-11-10T08:30+05:30'))), 1)

    def test_prune_keeps_exactly_seven_days(self):
        now = at('2026-10-23T12:00+05:30')
        e = [ev('old', '2026-10-15T15:30+05:30'), ev('edge', '2026-10-16T15:30+05:30'), ev('fut', '2026-12-04T10:00+05:30'),
             ev('hol_old', '2026-10-15T00:00+05:30', all_day=True), ev('hol_ok', '2026-10-16T00:00+05:30', all_day=True)]
        self.assertEqual([x['id'] for x in al.prune(e, now)], ['edge', 'fut', 'hol_ok'])


class SeedTests(unittest.TestCase):
    def test_fed_time_follows_us_daylight_saving(self):
        ev = {e['id']: e for e in seed.build()}
        self.assertTrue(ev['fomc-2026-10-28']['start'].startswith('2026-10-28T23:30'))      # US summer time
        self.assertTrue(ev['fomc-2026-12-09']['start'].startswith('2026-12-10T00:30'))      # US winter time
        self.assertTrue(ev['nfp-2026-11-06']['start'].startswith('2026-11-06T19:00'))

    def test_expiry_moves_back_for_holidays_and_monthly_is_last_tuesday(self):
        ev = {e['id']: e for e in seed.build()}
        self.assertEqual(ev['exp-2026-11-23']['type'], 'expiry_monthly')                    # 24 Nov is a holiday
        self.assertNotIn('exp-2026-11-24', ev); self.assertNotIn('exp-2026-11-10', ev)
        self.assertIn('exp-2026-11-09', ev)
        self.assertEqual(ev['exp-2026-10-27']['type'], 'expiry_monthly')
        self.assertEqual(ev['exp-2026-12-29']['type'], 'expiry_monthly')
        self.assertEqual(ev['exp-2026-12-01']['type'], 'expiry_weekly')

    def test_last_tuesday(self):
        self.assertEqual(seed.last_tuesday(2026, 12), date(2026, 12, 29))
        self.assertEqual(seed.last_tuesday(2026, 11), date(2026, 11, 24))

    def test_committed_events_file_is_valid(self):
        doc = json.load(open(os.path.join(HERE, '..', 'data', 'events.json')))
        ids = [e['id'] for e in doc['events']]
        self.assertEqual(len(ids), len(set(ids)))
        for e in doc['events']:
            self.assertIn(e['impact'], ('high', 'med', 'low')); at(e['start'])


class ImpactTests(unittest.TestCase):
    def test_event_day_is_compared_with_normal_days(self):
        def day(rng):
            return [(555 + 5 * i, 100, 100 + rng / 2, 100 - rng / 2, 100) for i in range(75)]
        days = {'2026-01-0%d' % i: day(1) for i in range(1, 6)}
        days['2026-01-09'] = day(4)
        out = imp.build(days, {'big': {'label': 'Big', 'dates': ['2026-01-09', '2026-02-01']}})
        t = out['types']['big']
        self.assertEqual(t['n'], 1); self.assertEqual(t['missing'], ['2026-02-01'])
        self.assertAlmostEqual(t['x_normal'], 4.0, places=1)


if __name__ == '__main__':
    unittest.main()
