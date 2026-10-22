import gzip, importlib.util, os, tempfile, unittest

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("split_holdout", os.path.join(HERE, "..", "scripts", "split_holdout.py"))
sh = importlib.util.module_from_spec(spec); spec.loader.exec_module(sh)


def iso_rows(days, per_day=3):
    out = ["Date,Open,High,Low,Close"]
    for d in days:
        for h in range(per_day):
            out.append("%s %02d:00,1,2,0.5,1.5" % (d, h))
    return out


class SplitTests(unittest.TestCase):
    def test_no_overlap_and_nothing_lost(self):
        lines = iso_rows(["2025-09-24", "2025-09-25", "2025-09-26", "2025-09-29"])
        header, pub, hold, first = sh.split_one(lines, "2025-09-26")
        self.assertEqual(pub + hold, lines[1:])
        self.assertEqual(first, "2025-09-26")
        self.assertTrue(all(sh.row_day(r) < "2025-09-26" for r in pub))
        self.assertTrue(all(sh.row_day(r) >= "2025-09-26" for r in hold))

    def test_same_cutoff_for_every_timeframe(self):
        a = sh.split_one(iso_rows(["2025-09-25", "2025-09-26"], 24), "2025-09-26")
        b = sh.split_one(iso_rows(["2025-09-25", "2025-09-26"], 96), "2025-09-26")
        self.assertEqual(a[3], b[3])

    def test_dmy_format_bank_nifty(self):
        rows = ["Instrument,Date,Time,Open,High,Low,Close"] + ["Banknifty,%02d-01-2015,9:15:00,1,2,0.5,1" % d for d in range(9, 20)]
        header, pub, hold, first = sh.split_one(rows, "2015-01-15")
        self.assertEqual(first, "2015-01-15"); self.assertEqual(len(pub), 6)

    def test_auto75_starts_on_a_day_boundary(self):
        lines = iso_rows(["2024-01-0%d" % d for d in range(1, 9)], 5)
        header, pub, hold, first = sh.split_one(lines, "auto75")
        self.assertNotEqual(sh.row_day(pub[-1]), sh.row_day(hold[0]))

    def test_unordered_or_bad_rows_are_refused(self):
        with self.assertRaises(ValueError):
            sh.split_one(iso_rows(["2025-09-27", "2025-09-26"]), "2025-09-26")
        with self.assertRaises(ValueError):
            sh.split_one(["Date,Open", "garbage,1"], "2025-09-26")

    def test_real_files_have_no_holdout_in_public_output(self):
        root = os.path.abspath(os.path.join(HERE, ".."))
        pubdir, hodir = root, os.path.join(root, "holdout")
        if not os.path.isdir(hodir):
            self.skipTest("holdout/ not generated yet")
        for f in os.listdir(hodir):
            stem = f.split(".")[0]
            inst = sh.instrument_of(stem)
            cut = sh.CUTOFFS[inst]
            p = os.path.join(pubdir, stem + ".csv.gz")
            if cut == "auto75" or not os.path.exists(p):
                continue
            days = [sh.row_day(x) for x in sh.read_lines(p)[1:]]
            self.assertLess(max(days), cut, stem)
            hdays = [sh.row_day(x) for x in sh.read_lines(os.path.join(hodir, f))[1:]]
            self.assertGreaterEqual(min(hdays), cut, stem)
        for f in os.listdir(root):
            self.assertFalse(f.endswith("-data.csv"), "plain full csv left in the site root: " + f)


if __name__ == "__main__":
    unittest.main()
