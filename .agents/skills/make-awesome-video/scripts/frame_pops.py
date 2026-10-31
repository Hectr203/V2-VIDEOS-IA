#!/usr/bin/env python3
"""Find single-frame pops in a render: frame-to-frame differences that spike far above their neighbours.

A pop is one frame where half the screen changes at once (a flood that didn't overscale, a 0.05s fade,
a zoom that snapped back to 1.0 at a handoff, an element that appears without an entrance). Intended
hard cuts also spike; list them with --allow so only the unexpected ones are reported.

Usage: frame_pops.py <video.mp4> [--ratio 3] [--floor 4] [--window 4] [--allow 2.47,3.37] [--allow-range 13.5-14.9]
  --ratio   spike must be this many times the median of its neighbours (default 3)
  --floor   ignore differences below this mean-abs luma (0-255), i.e. tiny motion (default 4)
  --window  neighbours on each side used for the median (default 4)
  --allow   comma-separated times (s) of intended hard cuts to skip (±--tol, default 0.05s)
  --allow-range  comma-separated a-b spans where rapid change is intended (16th-note image runs, rewind montage)
Exit 1 when an unexpected pop is found.
"""
import argparse
import subprocess
import sys
from statistics import median


def diffs(path):
    out = subprocess.run(
        ["ffmpeg", "-hide_banner", "-i", path, "-vf",
         "scale=320:-2,format=gray,tblend=all_mode=difference,signalstats,metadata=print:key=lavfi.signalstats.YAVG",
         "-an", "-f", "null", "-"],
        capture_output=True, text=True).stderr
    t, rows = None, []
    for line in out.splitlines():
        if "pts_time:" in line:
            t = float(line.split("pts_time:")[1].split()[0])
        elif "YAVG=" in line and t is not None:
            rows.append((t, float(line.split("YAVG=")[1])))
    return rows


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("video")
    ap.add_argument("--ratio", type=float, default=3.0)
    ap.add_argument("--floor", type=float, default=4.0)
    ap.add_argument("--window", type=int, default=4)
    ap.add_argument("--allow", default="")
    ap.add_argument("--allow-range", default="")
    ap.add_argument("--tol", type=float, default=0.05)
    a = ap.parse_args()

    rows = diffs(a.video)
    if not rows:
        sys.exit("프레임 차분을 읽지 못함 (ffmpeg 출력 확인)")
    allow = [float(x) for x in a.allow.split(",") if x.strip()]
    spans = [tuple(map(float, x.split("-"))) for x in a.allow_range.split(",") if x.strip()]
    pops, allowed = [], 0
    for i, (t, d) in enumerate(rows):
        if d < a.floor:
            continue
        nb = [v for _, v in rows[max(0, i - a.window):i] + rows[i + 1:i + 1 + a.window]]
        if not nb:
            continue
        base = max(median(nb), 0.5)
        if d >= a.ratio * base:
            if any(abs(t - x) <= a.tol for x in allow) or any(lo <= t <= hi for lo, hi in spans):
                allowed += 1
            else:
                pops.append((t, d, base))

    print(f"{len(rows)} frames · ratio ≥ {a.ratio}× · floor {a.floor} · spikes skipped as intended {allowed}")
    if not pops:
        print("unexpected pops: none")
        return
    print(f"unexpected pops: {len(pops)}  (hard cut이면 --allow에 추가, 아니면 전환을 고친다)")
    for t, d, base in pops:
        print(f"  {t:7.3f}s  diff {d:6.1f}  neighbours {base:5.1f}  ({d / base:4.1f}×)")
    sys.exit(1)


if __name__ == "__main__":
    main()
