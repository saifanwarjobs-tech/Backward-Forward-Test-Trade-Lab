#!/usr/bin/env python3
"""
BFT Classroom: voices.tsv -> voice/*.mp3 using edge-tts (free, unofficial).
Usage:
  pip install edge-tts
  python gen_voice.py --sample                 # make samples/ in several Indian voices, pick by ear
  python gen_voice.py --voice en-IN-NeerjaNeural --preset teacher
  python gen_voice.py                          # all lines, Swara (female) voice
  python gen_voice.py --fix                    # clean hiss on existing files
  python gen_voice.py --limit 10               # test with first 10 lines
  python gen_voice.py --voice hi-IN-MadhurNeural   # male
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

SAMPLES = ["Breakout. Bullish setup.",
           "Dhyan se dekho. Price baar baar ek hi level se wapas aa raha hai. Wahi level aaj ki kahani hai.",
           "Entry: candle level ke Above close kare, tab Buy.",
           "Pehle liquidity pehchano. Phir sweep ka intezaar karo. Phir structure break aur order block par entry. Jaldi nahi, sabr se."]
PRESETS = {"teacher": dict(rate="+4%", pitch="+2Hz"), "calm": dict(rate="-5%", pitch="+0Hz")}

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

async def pick_voices():
    vs = await edge_tts.list_voices()
    ok = [v for v in vs if v["Locale"].endswith("-IN") or "Multilingual" in v["ShortName"]]
    ok.sort(key=lambda v: (v["Gender"] != "Female", v["Locale"] != "hi-IN", v["ShortName"]))
    return [(v["ShortName"], v["Gender"]) for v in ok]

async def make(text, voice, dst, rate, pitch, volume):
    kw = dict(rate=rate, pitch=pitch)
    if volume:
        kw["volume"] = volume
    await edge_tts.Communicate(speakable(text), voice, **kw).save(str(dst))

async def one(sem, name, text, out, a, tries=4):
    dst = out / name
    if dst.exists() and dst.stat().st_size > 1000:
        return "skip"
    async with sem:
        for k in range(tries):
            try:
                await make(text, a.voice, str(dst) + ".part", a.rate, a.pitch, a.volume)
                Path(str(dst) + ".part").replace(dst)
                return "ok"
            except Exception as e:
                await asyncio.sleep(2 * (k + 1))
        return "fail"

CHAIN = "highpass=f=70,lowpass=f=10500,afftdn=nr=8:nf=-45,loudnorm=I=-16:TP=-1.5:LRA=11"

def normalize(files, out):
    """Clean hiss + even out volume + re-encode at better quality. Each file is processed only once."""
    ff = shutil.which("ffmpeg")
    if not ff:
        print("ffmpeg NOT found: hiss cleanup skipped. Install it:  winget install Gyan.FFmpeg  (then reopen terminal and run: python gen_voice.py --fix)")
        return
    mark = out / ".processed.txt"
    done = set(mark.read_text().split()) if mark.exists() else set()
    todo = [f for f in files if f.name not in done]
    for i, f in enumerate(todo, 1):
        tmp = f.with_suffix(".tmp.mp3")
        r = subprocess.run([ff, "-y", "-loglevel", "error", "-i", str(f), "-af", CHAIN,
                            "-ar", "44100", "-ac", "1", "-b:a", "160k", str(tmp)])
        if r.returncode == 0 and tmp.exists():
            tmp.replace(f)
            done.add(f.name)
        if i % 50 == 0:
            print(f"cleaned {i}/{len(todo)}")
    mark.write_text("\n".join(sorted(done)))
    ok = len([f for f in todo if f.name in done])
    print(f"cleaned {ok}/{len(todo)} files" + ("" if ok == len(todo) else "  (some failed: check ffmpeg)"))

async def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", default="voices.tsv")
    ap.add_argument("--out", default="voice")
    ap.add_argument("--voice", default="hi-IN-SwaraNeural")
    ap.add_argument("--rate", default=None, help="speed, e.g. -10%% slower")
    ap.add_argument("--pitch", default=None)
    ap.add_argument("--volume", default=None)
    ap.add_argument("--preset", choices=list(PRESETS), default=None)
    ap.add_argument("--list", action="store_true", help="list Indian/multilingual voices")
    ap.add_argument("--sample", action="store_true", help="make samples/ with every candidate voice")
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--workers", type=int, default=3)
    ap.add_argument("--no-normalize", action="store_true")
    ap.add_argument("--fix", action="store_true", help="only clean existing mp3 files (no new generation)")
    a = ap.parse_args()
    pr = PRESETS.get(a.preset, {})
    a.rate = a.rate or pr.get("rate", "-5%")
    a.pitch = a.pitch or pr.get("pitch", "+0Hz")
    if a.list or a.sample:
        vs = await pick_voices()
        if a.list:
            [print(n, g) for n, g in vs]; return
        sd = Path("samples"); sd.mkdir(exist_ok=True)
        files = []
        for name, g in vs[:10]:
            for i, t in enumerate(SAMPLES, 1):
                f = sd / f"{name}_{i}.mp3"
                try:
                    await make(t, name, f, a.rate, a.pitch, a.volume); files.append(f)
                except Exception as e:
                    print("skip", name, e); break
            print("sample done:", name, g)
        normalize(files, sd)
        print("Listen to the files in the samples folder, then run: python gen_voice.py --voice <name> --preset teacher")
        return
    if a.fix:
        o = Path(a.out); normalize(sorted(o.glob("*.mp3")), o); return
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
        normalize(new, out)
    bad = [n for (n, _), r in zip(rows, res) if r == "fail"]
    if bad:
        print("Failed (re-run the script to retry):", *bad[:10], sep="\n  ")

asyncio.run(main())
