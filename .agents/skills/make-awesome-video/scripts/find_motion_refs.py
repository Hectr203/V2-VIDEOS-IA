#!/usr/bin/env python3
"""Search the prompt-motion.com gallery (Claude-made motion videos + the prompts behind them).

Each entry pairs a rendered video with the exact prompt (or skill) that produced it, so it is
both a visual reference (mp4 for analyze_ref.sh) and a prompt reference (how the brief was written).
Content belongs to the creators linked on each entry: use it as reference, never copy it into
deliverables or redistribute the prompts.

Examples:
  find_motion_refs.py kinetic type --limit 8
  find_motion_refs.py launch --structured --details          # long, spec-style prompts only
  find_motion_refs.py --aspect square --stack playwright
  find_motion_refs.py --show twoclipping-6dd14e               # print one full prompt to read
  find_motion_refs.py --stats
"""
import argparse
import concurrent.futures as cf
import html
import json
import os
import re
import sys
import time
import urllib.request
from collections import Counter

BASE = "https://prompt-motion.com"
CACHE_DIR = os.path.join(
    os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")),
    "make-awesome-video",
)
CACHE = os.path.join(CACHE_DIR, "prompt-motion-index.json")
CACHE_TTL = 12 * 3600
UA = "make-awesome-video-skill/1.0 (+reference research)"
# the copy-paste "showreel" prompt that dozens of entries share; useful as a baseline, noisy in results
SHOWREEL = re.compile(r"shows? (?:off )?what an incredible motion designer you are", re.I)


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "text/html"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read().decode("utf-8")


def parse_home(page):
    raw = page.replace('\\"', '"')
    items = {}
    for m in re.finditer(r'\{"slug":"([^"]+)".*?"promptShared":(?:true|false)[^}]*\}', raw):
        blob = m.group(0)
        row = {}
        for k in ("slug", "title", "tags", "handle", "date", "video", "poster", "width", "height"):
            mm = re.search(r'"%s":("(?:[^"\\]|\\.)*"|\[[^\]]*\]|[0-9]+)' % k, blob)
            row[k] = json.loads(mm.group(1)) if mm else None
        items.setdefault(row["slug"], row)
    return list(items.values())


def parse_detail(page):
    body = re.sub(r"<script.*?</script>", "", page, flags=re.S)
    out = {}
    m = re.search(r'id="entry-prompt"[^>]*>(.*?)</div>', body, re.S)
    if m:
        out["prompt"] = html.unescape(re.sub(r"<[^>]+>", "", m.group(1))).strip()
    for dt, dd in re.findall(r"<dt[^>]*>([^<]+)</dt><dd[^>]*>(.*?)</dd>", body, re.S):
        val = html.unescape(re.sub(r"<[^>]+>", "", dd)).strip()
        if dt in ("Model", "Stack", "Iterations") and val:
            out[dt.lower()] = val
    if "prompt" not in out:  # skill entries: description + install command
        text = [l.strip() for l in html.unescape(re.sub(r"<[^>]+>", "\n", body)).split("\n") if l.strip()]
        if "Skill" in text:
            i = text.index("Skill")
            end = text.index("Copied") if "Copied" in text[i:] else i + 2
            out["skill"] = " | ".join(text[i + 1 : end])
    m = re.search(r'href="(https://(?:x|twitter)\.com/[^"]+/status/[^"]+)"', body)
    if m:
        out["post"] = m.group(1)
    return out


def load_index(refresh=False):
    if not refresh and os.path.exists(CACHE) and time.time() - os.path.getmtime(CACHE) < CACHE_TTL:
        with open(CACHE, encoding="utf-8") as f:
            return json.load(f)
    old = {}
    if os.path.exists(CACHE):
        with open(CACHE, encoding="utf-8") as f:
            old = {r["slug"]: r for r in json.load(f)}
    items = parse_home(fetch(BASE + "/"))
    if not items:
        raise RuntimeError("홈 페이지에서 항목을 찾지 못함 (사이트 구조 변경 가능)")
    todo = [r for r in items if not (old.get(r["slug"], {}).get("prompt") or old.get(r["slug"], {}).get("skill"))]
    if todo:
        print(f"상세 {len(todo)}개 수집 중 (최초 1회, 이후 캐시)...", file=sys.stderr)

    def one(r):
        try:
            return r["slug"], parse_detail(fetch(f"{BASE}/{r['slug']}"))
        except Exception as e:
            return r["slug"], {"error": str(e)}

    got = {}
    with cf.ThreadPoolExecutor(6) as ex:
        for slug, d in ex.map(one, todo):
            got[slug] = d
    for r in items:
        prev = old.get(r["slug"], {})
        r.update({k: prev[k] for k in ("prompt", "skill", "model", "stack", "iterations", "post") if k in prev})
        r.update(got.get(r["slug"], {}))
    os.makedirs(CACHE_DIR, exist_ok=True)
    with open(CACHE, "w", encoding="utf-8") as f:
        json.dump(items, f, ensure_ascii=False)
    return items


def aspect(r):
    w, h = r.get("width") or 0, r.get("height") or 0
    if not w or not h:
        return "?"
    q = w / h
    return "square" if 0.9 <= q <= 1.1 else "landscape" if q > 1.1 else "portrait"


def is_structured(r):
    p = r.get("prompt") or ""
    return len(p) >= 700 or bool(re.search(r"<(direction|structure|build)>", p))


def score(r, terms):
    if not terms:
        return 1
    title = (r.get("title") or "").lower()
    text = " ".join(str(r.get(k) or "") for k in ("prompt", "skill", "stack", "handle")).lower()
    if not all(t in title or t in text for t in terms):
        return 0
    return sum(3 * (t in title) + (t in text) for t in terms)


def excerpt(p, n=220):
    p = re.sub(r"\s+", " ", p or "").strip()
    return p if len(p) <= n else p[:n].rsplit(" ", 1)[0] + " …"


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("query", nargs="*", help="keywords matched in title + prompt (all must match)")
    ap.add_argument("--stack", help="substring of the stated stack, e.g. remotion, hyperframes, three, playwright")
    ap.add_argument("--aspect", choices=["landscape", "portrait", "square"])
    ap.add_argument("--structured", action="store_true", help="only long spec-style prompts (direction/structure/build)")
    ap.add_argument("--include-showreel", action="store_true", help="keep the shared copy-paste showreel prompt entries in keyword-less listings")
    ap.add_argument("--limit", type=int, default=10)
    ap.add_argument("--details", action="store_true", help="print a prompt excerpt per result")
    ap.add_argument("--show", metavar="SLUG", help="print one entry's full prompt (for reading, not copying)")
    ap.add_argument("--stats", action="store_true", help="catalog summary: stacks, aspects, prompt lengths")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--refresh", action="store_true", help="ignore the 12h cache")
    a = ap.parse_args()

    try:
        rows = load_index(a.refresh)
    except Exception as e:
        sys.exit(f"prompt-motion 카탈로그를 가져오지 못함: {e}\n브라우저로 {BASE} 를 직접 보거나 사용자에게 참조 링크를 요청하세요.")

    if a.show:
        r = next((x for x in rows if x["slug"] == a.show), None)
        if not r:
            sys.exit(f"slug 없음: {a.show}")
        print(f"{r['title']} — @{r.get('handle')} · {r.get('width')}x{r.get('height')} · {r.get('stack') or '-'} · {r.get('iterations') or '-'}")
        print(f"page:  {BASE}/{r['slug']}\nvideo: {r.get('video')}\npost:  {r.get('post') or '-'}\n")
        print(r.get("prompt") or r.get("skill") or "(프롬프트 없음)")
        print("\n※ 크리에이터 소유. 기법을 참고만 하고 문장을 결과물·스킬 문서에 옮기지 않는다.")
        return

    if a.stats:
        print(f"{len(rows)}개 항목")
        print("비율:", dict(Counter(aspect(r) for r in rows)))
        print("스택:", Counter((r.get("stack") or "-") for r in rows).most_common(12))
        print("반복:", dict(Counter((r.get("iterations") or "-") for r in rows)))
        print("공유 showreel 프롬프트:", sum(bool(SHOWREEL.search(r.get("prompt") or "")) for r in rows))
        print("구조화 프롬프트(--structured):", sum(is_structured(r) for r in rows))
        return

    terms = [t.lower() for q in a.query for t in q.split()]
    res = []
    for r in rows:
        if a.stack and a.stack.lower() not in (r.get("stack") or "").lower():
            continue
        if a.aspect and aspect(r) != a.aspect:
            continue
        if a.structured and not is_structured(r):
            continue
        p = r.get("prompt") or ""
        if not a.include_showreel and SHOWREEL.search(p) and len(p) < 260 and not terms:
            continue
        s = score(r, terms)
        if s:
            res.append((s + (2 if is_structured(r) else 0), r))
    res.sort(key=lambda x: -x[0])
    res = [r for _, r in res[: a.limit]]

    if a.json:
        out = [{k: r.get(k) for k in ("slug", "title", "handle", "date", "width", "height", "stack",
                                       "iterations", "video", "poster", "post")} | {"page": f"{BASE}/{r['slug']}",
               "aspect": aspect(r), "structured": is_structured(r), "prompt_chars": len(r.get("prompt") or "")}
               for r in res]
        print(json.dumps(out, ensure_ascii=False, indent=2))
        return
    if not res:
        print("결과 없음. 키워드를 줄이거나 필터를 빼고 다시 검색하세요.")
        return
    print(f"{len(res)}개 (갤러리 {len(rows)}개 중)\n")
    for i, r in enumerate(res, 1):
        tag = " · 구조화" if is_structured(r) else ""
        print(f"{i}. {r['title']}  [{r['slug']}]")
        print(f"   @{r.get('handle')} · {r.get('width')}x{r.get('height')} ({aspect(r)}) · {r.get('stack') or '-'}"
              f" · {r.get('iterations') or '-'} · {r.get('date')} · 프롬프트 {len(r.get('prompt') or '')}자{tag}")
        print(f"   page:  {BASE}/{r['slug']}")
        print(f"   video: {r.get('video')}")
        if a.details:
            print(f"   prompt: {excerpt(r.get('prompt') or r.get('skill'))}")
        print()


if __name__ == "__main__":
    main()
