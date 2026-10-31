"""
Generate archival-style objects on a pure-white background via OpenAI images,
ready for halftone_objects.py to cut out and dot-ify.

Usage:
    export OPENAI_API_KEY=sk-...
    python gen_archival_objects.py                 # uses the default JOBS below
    python gen_archival_objects.py --out ./gen     # choose output dir

The white background is load-bearing: halftone_objects.py thresholds on it to
build the cutout mask. Generate several per need — expect ~1 in 4 to read as an
abstract blob; cast the survivors.
"""
import argparse, base64, json, os, sys, urllib.request, urllib.error, pathlib

KEY = os.environ.get("OPENAI_API_KEY")
if not KEY:
    sys.exit("Set OPENAI_API_KEY in your environment first.")

# The prompt tail that makes an image cut out cleanly. Edit the subject list
# (JOBS) for your own objects; keep the STYLE tail.
STYLE = ("single object, photographed straight-on side view, "
         "high-contrast black and white archival photograph look, strong shadows, "
         "isolated on a pure white background, no text, no watermark, fills most of frame")

JOBS = [
    ("typewriter",      f"a vintage manual typewriter, {STYLE}"),
    ("filing-cabinet",  f"a tall metal filing cabinet with drawers slightly open, {STYLE}"),
    ("paper-stack",     f"a tall messy stack of documents on a desk tray, {STYLE}"),
    ("rotary-phone",    f"a rotary desk telephone, {STYLE}"),
]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="gen", help="output directory (default: ./gen)")
    args = ap.parse_args()
    out = pathlib.Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    for name, prompt in JOBS:
        body = json.dumps({
            "model": "gpt-image-1",
            "prompt": prompt,
            "size": "1024x1024",
            "quality": "medium",
            "n": 1,
        }).encode()
        req = urllib.request.Request(
            "https://api.openai.com/v1/images/generations",
            data=body,
            headers={"Authorization": f"Bearer {KEY}", "Content-Type": "application/json"},
        )
        try:
            resp = json.load(urllib.request.urlopen(req, timeout=300))
            p = out / f"{name}.png"
            p.write_bytes(base64.b64decode(resp["data"][0]["b64_json"]))
            print("generated", p)
        except urllib.error.HTTPError as e:
            print("FAIL", name, e.code, e.read().decode()[:300])
    print("done")


if __name__ == "__main__":
    main()
