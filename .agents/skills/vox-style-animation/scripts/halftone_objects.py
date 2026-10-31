"""
Halftone-cutout bake for white-background objects (from gen_archival_objects.py):
white-bg threshold -> alpha mask -> per-cell luminance ink dots -> trimmed PNG.

Usage:
    pip install pillow
    python halftone_objects.py                          # ./gen -> ./photos
    python halftone_objects.py --in gen --out photos    # choose dirs
    python halftone_objects.py --names typewriter phone  # bake a subset

Output PNGs are named obj_<name>_ink.png with a transparent background — drop
them straight into a composition's assets/photos/. No runtime filters, ever:
everything is pre-baked so renders stay deterministic.
"""
import argparse, pathlib
from PIL import Image, ImageDraw, ImageFilter

INK = (22, 21, 19)   # ink black — matches --ink in brand-tokens.css
SIZE = 760           # output px (longest side, before trim)
SS = 2               # supersample factor
CELL = 12            # halftone cell size in supersampled px


def bake(name, gen_dir, out_dir):
    im = Image.open(gen_dir / f"{name}.png").convert("RGB")
    g = im.convert("L")
    # alpha mask: background is near-white; object pixels are darker
    mask = g.point(lambda v: 0 if v > 238 else 255)
    # clean edges: blur then re-threshold to drop tiny speckle
    mask = mask.filter(ImageFilter.GaussianBlur(2)).point(lambda v: 255 if v > 128 else 0)

    big = SIZE * SS
    g2 = g.resize((big, big), Image.LANCZOS)
    m2 = mask.resize((big, big), Image.LANCZOS)
    # stretch contrast so dot sizes use the full luminance range
    lo, hi = g2.getextrema()
    if hi > lo:
        g2 = g2.point(lambda v: max(0, min(255, int((v - lo) * 255 / (hi - lo)))))

    canvas = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(canvas)
    gp, mp = g2.load(), m2.load()
    rmax = CELL * 0.62
    for cy in range(0, big, CELL):
        for cx in range(0, big, CELL):
            tot = n = mtot = 0
            for y in range(cy, min(cy + CELL, big), 3):
                for x in range(cx, min(cx + CELL, big), 3):
                    tot += gp[x, y]; mtot += mp[x, y]; n += 1
            if n == 0 or mtot / n < 128:   # cell mostly background -> skip
                continue
            lum = tot / n
            r = rmax * (1 - lum / 255) ** 0.75   # darker cell -> bigger dot
            if r < 0.8:
                continue
            c = (cx + CELL / 2, cy + CELL / 2)
            d.ellipse([c[0] - r, c[1] - r, c[0] + r, c[1] + r], fill=INK + (255,))

    small = canvas.resize((SIZE, SIZE), Image.LANCZOS)
    bbox = small.getbbox()
    if bbox:
        small = small.crop(bbox)
    out = out_dir / f"obj_{name}_ink.png"
    small.save(out)
    print("baked", out, small.size)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--in", dest="gen", default="gen", help="input dir of white-bg PNGs")
    ap.add_argument("--out", default="photos", help="output dir for baked cutouts")
    ap.add_argument("--names", nargs="*", help="subset of base names to bake (default: all PNGs in --in)")
    args = ap.parse_args()

    gen_dir = pathlib.Path(args.gen)
    out_dir = pathlib.Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    names = args.names or [p.stem for p in sorted(gen_dir.glob("*.png"))]
    for n in names:
        bake(n, gen_dir, out_dir)
    print("done")


if __name__ == "__main__":
    main()
