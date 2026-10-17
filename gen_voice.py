#!/usr/bin/env python3
"""
BFT Classroom: voices.tsv -> voice/*.mp3 using edge-tts (free, unofficial).
Usage:
  pip install edge-tts
  python gen_voice.py                          # all lines, Madhur voice
  python gen_voice.py --limit 10               # test with first 10 lines
  python gen_voice.py --voice hi-IN-SwaraNeural
Safe to re-run: existing mp3 files are skipped (resume).
"""
import argparse, asyncio, re, shutil, subprocess, sys
from pathlib import Path

try:
    import edge_tts
except ImportError:
    sys.exit("edge-tts not installed. Run:  pip install edge-tts")

PRON = {  # trading words the Hindi voice may misread; only affects speech, not file names
    r"\bSL\b": "stop loss", r"\bNFP\b": "N F P", r"\bCPI\b": "C P I", r"\bRSI\b": "R S I",
    r"\bVWAP\b": "V wap", r"\bBOS\b": "B O S", r"\bCHoCH\b": "choke", r"\bFVG\b": "F V G",
    r"\bORB\b": "O R B", r"\bFOMO\b": "fomo", r"\bCE\b": "C E", r"\bPE\b": "P E",
}

def speakable(t):
    for pat, rep in PRON.items():
        t = re.sub(pat, rep, t)
    return t.replace("&", " and ").replace(":", ",").replace("  ", " ").strip()

def load(path):
    rows = []
    for ln in Path(path).read_text(encoding="utf-8").splitlines():
        if "\t" in ln:
            name, text = ln.split("\t", 1)
            if name.endswith(".mp3") and text.strip():
                rows.append((name.strip(), text.strip()))
    return rows

async def one(sem, name, text, out, a, tries=4):
    dst = out / name
    if dst.exists() and dst.stat().st_size > 1000:
        return "skip"
    async with sem:
        for k in range(tries):
            try:
                c = edge_tts.Communicate(speakable(text), a.voice, rate=a.rate, pitch=a.pitch)
                await c.save(str(dst) + ".part")
                Path(str(dst) + ".part").replace(dst)
                return "ok"
            except Exception as e:
                await asyncio.sleep(2 * (k + 1))
        return "fail"

def normalize(files):
    ff = shutil.which("ffmpeg")
    if not ff:
        print("ffmpeg not found: skipping volume normalisation (install ffmpeg for even volume).")
        return
    for i, f in enumerate(files, 1):
        tmp = f.with_suffix(".norm.mp3")
        r = subprocess.run([ff, "-y", "-loglevel", "error", "-i", str(f), "-af",
                            "loudnorm=I=-16:TP=-1.5:LRA=11", "-ar", "44100", "-b:a", "128k", str(tmp)])
        if r.returncode == 0 and tmp.exists():
            tmp.replace(f)
        if i % 50 == 0:
            print(f"normalised {i}/{len(files)}")

async def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", default="voices.tsv")
    ap.add_argument("--out", default="voice")
    ap.add_argument("--voice", default="hi-IN-MadhurNeural")
    ap.add_argument("--rate", default="-5%", help="speed, e.g. -10%% slower")
    ap.add_argument("--pitch", default="+0Hz")
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--workers", type=int, default=3)
    ap.add_argument("--no-normalize", action="store_true")
    a = ap.parse_args()
    rows = load(a.input)
    if not rows:
        sys.exit(f"No lines found in {a.input}. In classroom.html console run downloadVoiceList()")
    if a.limit:
        rows = rows[:a.limit]
    out = Path(a.out); out.mkdir(exist_ok=True)
    sem = asyncio.Semaphore(a.workers)
    res = await asyncio.gather(*[one(sem, n, t, out, a) for n, t in rows])
    new = [out / n for (n, _), r in zip(rows, res) if r == "ok"]
    print(f"done: {res.count('ok')} new, {res.count('skip')} skipped, {res.count('fail')} failed")
    if new and not a.no_normalize:
        normalize(new)
    bad = [n for (n, _), r in zip(rows, res) if r == "fail"]
    if bad:
        print("Failed (re-run the script to retry):", *bad[:10], sep="\n  ")

asyncio.run(main())
