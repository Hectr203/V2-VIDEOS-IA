/* ════════════════════════════════════════════════════════════════════════
   TIMELINE ENGINE — deterministic motion graphics
   Inline this into the HTML file. A single self-contained document is the
   deliverable; the exporter only needs window.__seek and window.__duration.

   Everything is a paused Web Animations object with its absolute start time
   baked in as `delay`, so positioning the whole piece at any instant is just
   currentTime = t on every animation. That is what makes frame-exact export
   possible, and it is also what lets you interrogate any moment with
   getBoundingClientRect() while writing verification scripts.
   ════════════════════════════════════════════════════════════════════════ */

const MG = (() => {

  const A = [];            // every animation in the piece
  let loopId = null;       // preview loop, cancelled on the first external seek

  /* Build one animation from keyframes given in ABSOLUTE seconds.
     Steps look like: { t, ease, ...cssProperties }
     A step may omit a property — it then interpolates straight across that
     step, which is sometimes exactly what you want (see references/engine.md
     on porting CSS keyframes faithfully). */
  function tl(el, steps){
    const t0 = steps[0].t, t1 = steps[steps.length - 1].t;
    const dur = Math.max(1, (t1 - t0) * 1000);
    const kf = steps.map(s => {
      const o = { offset: (s.t - t0) * 1000 / dur };
      for (const k in s) if (k !== 't' && k !== 'ease') o[k] = s[k];
      if (s.ease) o.easing = s.ease;
      return o;
    });
    const a = el.animate(kf, { delay: t0 * 1000, duration: dur, fill: 'both', easing: 'linear' });
    a.pause();
    A.push(a);
    return a;
  }

  /* seek() PAUSES before setting the time and kills the preview loop.
     Without the pause the animations keep running: you set currentTime, they
     advance a few milliseconds, and the screenshot lands late. That corrupts
     every frame of an export, not just the preview. */
  function seek(s){
    if (loopId){ clearInterval(loopId); loopId = null; }
    A.forEach(a => { a.pause(); a.currentTime = s * 1000; });
  }
  function play(){ A.forEach(a => { a.currentTime = 0; a.play(); }); }
  function loop(duration){
    play();
    loopId = setInterval(play, (duration + 1.2) * 1000);
  }

  /* ── A TRACK: one element, many chained moves ─────────────────────────
     For something that travels through the whole piece (a highlight bar, a
     camera, a mascot) you want to describe moves in sequence rather than
     compute absolute keyframe times by hand. Track() keeps the running state
     and clamps every push to be monotonic, so scheduling a move slightly too
     early degrades into "immediately after" instead of throwing
     `Offsets must be monotonically non-decreasing`. */
  function Track(initial){
    let cur = { ...initial };
    let last = 0;
    const K = [];
    const push = (t, patch, ease) => {
      t = Math.max(t, last); last = t;
      cur = { ...cur, ...patch };
      K.push({ t, ...cur, ease });
      return t;
    };
    return {
      get state(){ return { ...cur }; },
      get t(){ return last; },
      push,
      hold: t => push(t, {}, undefined),
      /* Emit the collected states as a single animation. `render` turns a
         state object into CSS properties. One animation, because several
         animations on the same element would fight over transform. */
      commit(el, render){ return tl(el, K.map(k => ({ t: k.t, ease: k.ease, ...render(k) }))); }
    };
  }

  /* ── DIRECTIONAL SMEAR ────────────────────────────────────────────────
     filter:blur() is isotropic and wrong for linear motion. Offset copies give
     a directional smear, and shadow lists interpolate between keyframes so it
     animates for free.

       trail(120, k)                          smear left, dark, for text
       trail(120, k, {dx:0, dy:1})            smear downward
       trail(120, k, {colour:'255,255,255'})  on a dark background
       trail(120, k, {box:true})              box-shadow, for non-text elements

     The colour is a parameter and not a constant for a reason: hardcoded black
     is invisible on a dark background, and the smear silently disappears.

     A costlier but better alternative exists — render several subframes per
     output frame and average them in ffmpeg (`tmix`). That gives true motion
     blur in every direction at once, at the price of N× the capture time.
     Worth it for a hero piece, overkill for a social clip. */
  const SMEAR = [[.05,.30],[.11,.22],[.18,.15],[.27,.09],[.38,.045]];
  function trail(sizePx, k, opt = {}){
    const dx = opt.dx ?? -1, dy = opt.dy ?? 0;
    const c  = opt.colour ?? '0,0,0';
    return SMEAR.map(([d, a]) =>
      `${(dx*d*sizePx*k).toFixed(2)}px ${(dy*d*sizePx*k).toFixed(2)}px 0 rgba(${c},${(a*k).toFixed(3)})`
    ).join(', ');
  }

  /* ── TYPOGRAPHIC METRICS ──────────────────────────────────────────────
     Where the baseline and the cap height actually sit inside a line box.
     Needed for optical centering and for placing rules against text. */
  const mctx = document.createElement('canvas').getContext('2d');
  function lineMetrics(el){
    const cs = getComputedStyle(el);
    const fs = parseFloat(cs.fontSize);
    const lh = parseFloat(cs.lineHeight) || fs;
    mctx.font = `${cs.fontWeight} ${fs}px ${cs.fontFamily}`;
    const m = mctx.measureText('H');
    return {
      fontSize: fs,
      baseline: (lh - (m.fontBoundingBoxAscent + m.fontBoundingBoxDescent)) / 2 + m.fontBoundingBoxAscent,
      cap: m.actualBoundingBoxAscent
    };
  }

  /* Layout-space rect: undoes the preview scale on the stage so measurements
     are in canvas coordinates regardless of window size. */
  function box(el, stage){
    const f = parseFloat(getComputedStyle(stage).getPropertyValue('--fit')) || 1;
    const s = stage.getBoundingClientRect(), r = el.getBoundingClientRect();
    return { x: (r.left - s.left) / f, y: (r.top - s.top) / f, w: r.width / f, h: r.height / f };
  }

  /* ── OPTICAL CENTERING ────────────────────────────────────────────────
     Centering the layout box leaves text sitting low, because the box carries
     ascender and descender space nobody sees. Centre the INK instead: cap top
     of the first line to baseline of the last.

     `extras` are other marks that belong to the composition (a rule under the
     last line, for instance) given as [{ y, h }] in canvas coordinates. Include
     a mark only where it is a fixed part of the lockup — a highlight that moves
     from line to line should not drag the framing around with it. */
  function opticalCenter(inner, stage, centerY, extras = []){
    const lines = [...inner.querySelectorAll('[data-line]')];
    if (!lines.length) return 0;
    const first = box(lines[0], stage), last = box(lines[lines.length - 1], stage);
    const mf = lineMetrics(lines[0]), ml = lineMetrics(lines[lines.length - 1]);
    let top = first.y + mf.baseline - mf.cap;
    let bot = last.y + ml.baseline;
    extras.forEach(e => { bot = Math.max(bot, e.y + e.h); top = Math.min(top, e.y); });
    const d = Math.round(centerY - (top + bot) / 2);
    inner.style.transform = `translateY(${d}px)`;
    return d;
  }

  /* ── CAMERA ───────────────────────────────────────────────────────────
     A slow continuous push so no scene is ever perfectly still. It settles
     over `settle` seconds and then keeps drifting until the scene leaves —
     that sustained crawl is what stops a held frame reading as stuck.

     Put it on the full-canvas scene element, not on the text block: the scene's
     centre is the canvas centre, so any other full-canvas layer (an overlay
     holding a travelling accent, say) can reuse the identical transform and
     stay locked to the type.

     `dy` is the optical-centering offset of that scene's content. Scaling about
     the canvas centre when the content sits dy away displaces it by (1-s)·dy;
     the translateY term cancels exactly that, so the push happens about the
     content's own centre without moving the transform origin. */
  function cameraKeyframes(t0, t1, { dx = 1.6, from = 1.03, to = 1.007, settle = 1.5, dy = 0 } = {}){
    const ty = s => ((1 - s) * dy).toFixed(3);
    const k = [
      { t: t0,          transform: `translate(${dx.toFixed(2)}px, ${ty(from)}px) scale(${from})`, ease: EASE.brake },
      { t: t0 + settle, transform: 'translate(0px, 0px) scale(1)', ease: 'linear' }
    ];
    if (t1 > t0 + settle + .3) k.push({ t: t1, transform: `translate(0px, ${ty(to)}px) scale(${to})` });
    return k;
  }

  /* ── SEEDED RANDOMNESS ────────────────────────────────────────────────
     Any variation must be reproducible: with Math.random() the preview and the
     export are different films, and so is every re-render. */
  function rng(seed){
    let s = ((seed * 9301) % 233280 + 233280) % 233280;
    return () => (s = (s * 9301 + 49297) % 233280) / 233280;
  }

  const EASE = {
    brake:  'cubic-bezier(.12,.85,.25,1)',   // arrivals: fast in, settles
    launch: 'cubic-bezier(.55,0,.9,.35)',    // departures: accelerates away
    settle: 'cubic-bezier(.16,1,.3,1)',      // smooth in and out
    breath: 'cubic-bezier(.45,0,.55,1)'      // continuous: no stop-start
  };

  /* ── MOTION LANGUAGES ─────────────────────────────────────────────────
     A piece should pick ONE way things arrive and leave, and hold to it. Which
     one is a tone decision, not a technical one — see references/craft.md for
     the table of what each one says.

     These return keyframe STEPS, not animations, so an entrance and an exit
     concatenate into a single list. That matters: two animations with
     fill:'both' on the same element fight and the later one wins from t=0.

       tl(el, [...ENTER.pop(0, {size}), ...EXIT.drift(3.0, {size})])

     `size` is the element's font-size or width in px — everything scales off
     it so the same language reads the same at any scale. */
  const ID = 'translate(0px, 0px) scale(1)';

  const ENTER = {
    // urgency, sport, news. Arrives fast with a directional smear and brakes.
    speed(t0, o = {}){
      const d = o.dur ?? .78, s = o.size ?? 100, dx = (o.dx ?? -1.45) * s;
      const sm = k => trail(s, k, o);
      return [
        { t:t0,        opacity:0, transform:`translate(${dx}px, 0px) scale(1)`, textShadow:sm(1),  ease:EASE.brake },
        { t:t0+d*.28,  opacity:1,                                              textShadow:sm(.6), ease:EASE.brake },
        { t:t0+d*.68,  opacity:1, transform:`translate(${(-dx*.04).toFixed(1)}px, 0px) scale(1)`, textShadow:sm(0), ease:EASE.brake },
        { t:t0+d,      opacity:1, transform:ID,                                textShadow:sm(0),  ease:'linear' }
      ];
    },
    // playful, product, toy. Grows from nothing and overshoots.
    pop(t0, o = {}){
      const d = o.dur ?? .52;
      return [
        { t:t0,       opacity:0, transform:'translate(0px, 0px) scale(.4)',  ease:EASE.brake },
        { t:t0+d*.55, opacity:1, transform:'translate(0px, 0px) scale(1.08)', ease:EASE.brake },
        { t:t0+d*.8,  opacity:1, transform:'translate(0px, 0px) scale(.98)',  ease:EASE.brake },
        { t:t0+d,     opacity:1, transform:ID,                                ease:'linear' }
      ];
    },
    // editorial, architectural. A hard edge uncovers it in place; nothing moves.
    wipe(t0, o = {}){
      const d = o.dur ?? .62, from = o.from ?? 'left';
      const hide = { left:'inset(-30% 100% -30% -5%)', right:'inset(-30% -5% -30% 100%)',
                     up:'inset(100% -5% -30% -5%)',    down:'inset(-30% -5% 100% -5%)' }[from];
      return [
        { t:t0,   opacity:1, transform:ID, clipPath:hide,                      ease:EASE.settle },
        { t:t0+d, opacity:1, transform:ID, clipPath:'inset(-30% -5% -30% -5%)', ease:'linear' }
      ];
    },
    // premium, calm, luxury. Barely moves; the fade does the work.
    drift(t0, o = {}){
      const d = o.dur ?? 1.1, s = o.size ?? 100, dy = (o.dy ?? .06) * s;
      return [
        { t:t0,   opacity:0, transform:`translate(0px, ${dy.toFixed(1)}px) scale(1.02)`, ease:EASE.breath },
        { t:t0+d, opacity:1, transform:ID,                                               ease:'linear' }
      ];
    },
    // cinematic titles. Rises out of its own baseline; needs overflow:hidden on a wrapper.
    rise(t0, o = {}){
      const d = o.dur ?? .8, s = o.size ?? 100;
      return [
        { t:t0,       opacity:1, transform:`translate(0px, ${(s*1.05).toFixed(1)}px) scale(1)`, ease:EASE.settle },
        { t:t0+d,     opacity:1, transform:ID,                                                  ease:'linear' }
      ];
    },
    // photographic, dreamy. Comes into focus.
    focus(t0, o = {}){
      const d = o.dur ?? .9, s = o.size ?? 100;
      return [
        { t:t0,   opacity:0, transform:'translate(0px, 0px) scale(1.04)', filter:`blur(${(s*.12).toFixed(1)}px)`, ease:EASE.settle },
        { t:t0+d, opacity:1, transform:ID,                                filter:'blur(0px)',                     ease:'linear' }
      ];
    }
  };

  const EXIT = {
    speed(t0, o = {}){
      const d = o.dur ?? .5, s = o.size ?? 100, k = o.k ?? 1, dx = (o.dx ?? 1.45) * s * k;
      const sm = v => trail(s, v, o);
      return [
        { t:t0,       opacity:1, transform:ID,                                     textShadow:sm(0),  ease:EASE.launch },
        { t:t0+d*.45, opacity:1, transform:`translate(${(dx*.34).toFixed(1)}px, 0px) scale(1)`, textShadow:sm(.7), ease:EASE.launch },
        { t:t0+d,     opacity:0, transform:`translate(${(dx*1.8).toFixed(1)}px, 0px) scale(1)`, textShadow:sm(1) }
      ];
    },
    pop(t0, o = {}){
      const d = o.dur ?? .34;
      return [
        { t:t0,       opacity:1, transform:ID,                                ease:EASE.launch },
        { t:t0+d*.3,  opacity:1, transform:'translate(0px, 0px) scale(1.06)',  ease:EASE.launch },
        { t:t0+d,     opacity:0, transform:'translate(0px, 0px) scale(.5)' }
      ];
    },
    wipe(t0, o = {}){
      const d = o.dur ?? .5, to = o.to ?? 'right';
      const gone = { left:'inset(-30% 100% -30% -5%)', right:'inset(-30% -5% -30% 100%)',
                     up:'inset(100% -5% -30% -5%)',    down:'inset(-30% -5% 100% -5%)' }[to];
      return [
        { t:t0,   opacity:1, transform:ID, clipPath:'inset(-30% -5% -30% -5%)', ease:EASE.settle },
        { t:t0+d, opacity:1, transform:ID, clipPath:gone }
      ];
    },
    drift(t0, o = {}){
      const d = o.dur ?? .8, s = o.size ?? 100, dy = (o.dy ?? -.05) * s;
      return [
        { t:t0,   opacity:1, transform:ID,                                                ease:EASE.breath },
        { t:t0+d, opacity:0, transform:`translate(0px, ${dy.toFixed(1)}px) scale(1.015)` }
      ];
    },
    focus(t0, o = {}){
      const d = o.dur ?? .7, s = o.size ?? 100;
      return [
        { t:t0,   opacity:1, transform:ID,                                filter:'blur(0px)',                     ease:EASE.settle },
        { t:t0+d, opacity:0, transform:'translate(0px, 0px) scale(1.03)', filter:`blur(${(s*.09).toFixed(1)}px)` }
      ];
    },
    // keeps going up and out of the same mask it came from
    rise(t0, o = {}){
      const d = o.dur ?? .6, s = o.size ?? 100;
      return [
        { t:t0,   opacity:1, transform:ID,                                                     ease:EASE.launch },
        { t:t0+d, opacity:1, transform:`translate(0px, ${(-s*1.05).toFixed(1)}px) scale(1)` }
      ];
    }
  };

  return { A, tl, seek, play, loop, Track, trail, ENTER, EXIT, lineMetrics, box,
           opticalCenter, cameraKeyframes, rng, EASE };
})();
