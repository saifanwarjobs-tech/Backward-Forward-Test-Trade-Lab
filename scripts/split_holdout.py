#!/usr/bin/env python3
"""Split every price file into a PUBLIC part and a HOLDOUT part.

  public  -> <stem>.csv.gz in the site root  (served to everyone, used for Backtest)
  holdout -> holdout/<stem>.csv.gz           (upload to the PRIVATE Supabase bucket
                                              'holdout'; released only after a user
                                              has locked their rules on the server)

One cutoff date per instrument, shared by every timeframe of that instrument.
That matters: if M15 were public up to 2025 while H1 hid 2022-2026, anyone could
read the "reserved" H1 period from the M15 file. Same date for all = no leak.

Usage (from the project root):
    python3 scripts/split_holdout.py            # uses _private-full-data/ as the source
    python3 scripts/split_holdout.py --check    # only verify, write nothing

To roll the holdout forward later (old holdout becomes public backtest data,
new data becomes the holdout), put the new full files in _private-full-data/,
change the date in CUTOFFS, run again, re-upload holdout/ to Supabase.
Standard library only.
"""
import argparse, glob, gzip, io, os, re, sys

# One cutoff per instrument prefix (file name starts with it). Format YYYY-MM-DD,
# choose a day the market is open. 'auto75' = first day on or after 75% of the rows.
CUTOFFS = {
    "bank-nifty": "auto75",     # single file, Jan 2015 - Apr 2024
    "xauusd": "2025-09-26",     # Gold: about 13 months held out
    "btcusd": "2026-02-02",     # Bitcoin: about 8.5 months held out
}
MIN_PUBLIC_ROWS = 500           # the Lab refuses to load fewer; such files become forward-only

ISO = re.compile(r"^(\d{4})-(\d{2})-(\d{2})")
DMY = re.compile(r"^(\d{2})-(\d{2})-(\d{4})$")


def row_day(line):
    """YYYY-MM-DD of a data row, or None if the line is not a data row."""
    for f in line.split(",")[:3]:
        f = f.strip().strip('"')
        m = ISO.match(f)
        if m:
            return "%s-%s-%s" % m.groups()
        m = DMY.match(f)
        if m:
            d, mo, y = m.groups()
            return "%s-%s-%s" % (y, mo, d)
    return None


def read_lines(path):
    op = gzip.open if path.endswith(".gz") else open
    with op(path, "rt", encoding="utf-8") as fh:
        return [x for x in fh.read().splitlines() if x.strip()]


def write_gz(path, lines):
    raw = ("\n".join(lines) + "\n").encode("utf-8")
    with open(path, "wb") as out:
        with gzip.GzipFile(filename="", mode="wb", fileobj=out, compresslevel=9, mtime=0) as gz:
            gz.write(raw)


def instrument_of(stem):
    for p in CUTOFFS:
        if stem.startswith(p):
            return p
    return None


def split_one(lines, cutoff):
    header = lines[0]
    rows = lines[1:]
    days = [row_day(r) for r in rows]
    if any(d is None for d in days):
        bad = next(i for i, d in enumerate(days) if d is None)
        raise ValueError("row %d has no readable date: %r" % (bad + 2, rows[bad][:60]))
    if days != sorted(days):
        raise ValueError("rows are not in date order")
    if cutoff == "auto75":
        target = int(len(rows) * 0.75)
        cut = next((i for i in range(target, len(rows)) if i == 0 or days[i] != days[i - 1]), len(rows))
    else:
        cut = next((i for i, d in enumerate(days) if d >= cutoff), len(rows))
    return header, rows[:cut], rows[cut:], days[cut] if cut < len(rows) else None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default="_private-full-data")
    ap.add_argument("--public", default=".")
    ap.add_argument("--holdout", default="holdout")
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()

    files = {}
    for f in sorted(glob.glob(os.path.join(a.src, "*-data.csv*"))):
        stem = os.path.basename(f).split(".")[0]
        if stem not in files or f.endswith(".gz"):   # prefer the .gz, the Lab loads that first
            files[stem] = f
    if not files:
        sys.exit("No *-data.csv[.gz] files in %s" % a.src)

    if not a.check:
        os.makedirs(a.holdout, exist_ok=True)
    forward_only = []
    print("%-22s %9s %9s  %-10s  %s" % ("file", "public", "holdout", "cutoff", "public range"))
    for stem, f in sorted(files.items()):
        inst = instrument_of(stem)
        if inst is None:
            print("%-22s skipped (no cutoff configured for this instrument)" % stem)
            continue
        lines = read_lines(f)
        header, pub, hold, first_hold = split_one(lines, CUTOFFS[inst])
        rng = "%s .. %s" % (row_day(pub[0]), row_day(pub[-1])) if pub else "none"
        print("%-22s %9d %9d  %-10s  %s" % (stem, len(pub), len(hold), first_hold or "-", rng))
        if len(pub) < MIN_PUBLIC_ROWS:
            forward_only.append(stem)
        if a.check:
            continue
        # public: keep the plain .csv out of the site, only the truncated .gz is served
        if len(pub) >= MIN_PUBLIC_ROWS:
            write_gz(os.path.join(a.public, stem + ".csv.gz"), [header] + pub)
        else:
            p = os.path.join(a.public, stem + ".csv.gz")
            if os.path.exists(p):
                os.remove(p)
        plain = os.path.join(a.public, stem + ".csv")
        if os.path.exists(plain):
            os.remove(plain)
        if hold:
            write_gz(os.path.join(a.holdout, stem + ".csv.gz"), [header] + hold)
    if forward_only:
        print("\nForward-only (no public part, removed from the dropdown): " + ", ".join(forward_only))
    print("\nDone." if not a.check else "\nCheck only, nothing written.")


if __name__ == "__main__":
    main()
