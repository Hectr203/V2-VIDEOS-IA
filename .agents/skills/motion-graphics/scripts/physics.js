/* ════════════════════════════════════════════════════════════════════════
   PHYSICS — projectile, bounce, topple, departure
   Inline alongside the timeline engine. Every function returns an array of
   sampled points; feed them to tl() with ease:'linear' and the sampling
   carries the curve.

   Why sample instead of ease: an easing curve is a shape, not a simulation.
   `ease-out` decelerates and a fall accelerates, so no curve gets a drop
   right. Sampling at a fixed dt does, and it costs ~120 keyframes a second.
   ════════════════════════════════════════════════════════════════════════ */

const PHYS = (() => {

  /* ── PROJECTILE WITH BOUNCE AND TOPPLE — FOR BOXES ────────────────────
     This models a RECTANGLE: contact on a corner, and a topple that ends with a
     face lying flat. Do not use it for a round object. A disc has a constant
     contact height and does not topple — it rolls — and running it through here
     produces something that rises and falls with every rotation. Use `roll()`
     below for anything circular.

     box  : { w, h }              the object, in canvas px
     from : { cx, cy, vx, vy, spin }   centre, velocity px/s, spin rad/s
     floor: y of the surface the object lands on
     opt  : { g, rest, dt, stop }

     `stop` is the vertical speed below which bouncing ends and the object
     starts settling. It is the knob that decides "bounces twice" versus
     "bounces five times", so it is a directorial control, not an
     implementation detail. Default 90 px/s; raise it for fewer bounces.

     Returns { pts, tLand, tEnd, last }. Each point carries cx, cy (centre),
     rot (degrees), and k — a 0…1 "intensity" you can map to a motion trail.

     Two things this gets right that hand-rolled versions usually do not:

     1. Contact uses the real height of a rotated box, a·|sinθ| + b·|cosθ|,
        so a corner touches first instead of an axis-aligned edge.

     2. A box has FOUR stable resting orientations, not one. Modelling only
        "upright" leaves anything that tips past its balance point rocking
        forever, because there is no rest state to catch it. For a box taller
        than it is wide, lying down is the lower-energy state — so a tumbling
        object will usually end up fallen. That is correct, and worth saying
        out loud to whoever expected it to land neatly upright. The honest
        lever on the outcome is the throw, not the landing. */
  function drop(from, floor, box, opt = {}){
    const dt   = opt.dt   ?? 1/240;
    const g    = opt.g    ?? 4400;
    const rest = opt.rest ?? .46;
    const stop = opt.stop ?? 90;      // fewer bounces: raise this
    const a = box.w / 2, b = box.h / 2;
    const I = (4/3) * (a*a + b*b);                  // rectangle about its corner
    const H = th => Math.abs(a*Math.sin(th)) + Math.abs(b*Math.cos(th));

    /* The contact corner, straight from the signs of sine and cosine. This
       description stays continuous through the tipping point — the same corner
       stays down while the object crosses from one face's basin to the next —
       and only changes at multiples of 90°, when a face slaps flat and the
       pivot genuinely moves. Describing it with 90° "frames" that swap the
       half-extents instead makes the centre jump the width of the box. */
    const corner = (th, dir) => ({
      u: a * (Math.sign(Math.sin(th)) || dir),
      v: b * (Math.sign(Math.cos(th)) || 1),
      side: Math.sign(Math.sin(th)) || dir
    });

    let { cx, cy, vx, vy } = from;
    let th = 0, om = from.spin ?? 0;
    let t = 0, phase = 1, armed = false, tLand = null, piv = 0, side = 1, n = 0;
    const pts = [];
    const put = k => pts.push({ t: t, cx, cy, rot: th * 180 / Math.PI, k });
    put(0);

    while (t < (opt.limit ?? 3.2) && n++ < 1600){
      t += dt;
      if (phase === 1){
        vy += g*dt;  cy += vy*dt;  cx += vx*dt;  th += om*dt;
        const ground = floor - H(th);
        if (cy < ground - 1) armed = true;
        if (armed && cy >= ground && vy > 0){
          cy = ground;
          if (tLand === null) tLand = t;
          vy = -vy*rest;  vx *= .70;  om *= .45;
          if (Math.abs(vy) < stop){                  // done bouncing, settle
            phase = 2;  vy = 0;  vx = 0;
            const q = corner(th, Math.sign(om) || 1);
            side = q.side;
            piv  = cx + (q.u*Math.cos(th) - q.v*Math.sin(th));
          }
        }
      } else {
        /* Pendulum about the contact corner. Gravity's torque is proportional
           to that corner's horizontal lever arm and vanishes exactly at the
           tipping point. The centre DROPS as it flattens (a corner rest is
           higher than a face rest) and SHIFTS sideways following the pivot —
           those two are what make it read as real. A pure rotation reads as a
           tween however well eased. */
        const q = corner(th, side);
        side = q.side;
        om += -(g/I) * (q.u*Math.cos(th) - q.v*Math.sin(th)) * dt;
        om *= (1 - 1.6*dt);                          // contact friction

        let next = th + om*dt;
        const flat = Math.round(th / (Math.PI/2)) * (Math.PI/2);
        if ((th - flat) * (next - flat) < 0){        // a face slapped down
          next = flat;
          om = -om * .26;
          if (Math.abs(om) < 1.0) om = 0;
        }
        th = next;

        const r = corner(th, side);
        cx = piv - (r.u*Math.cos(th) - r.v*Math.sin(th));
        cy = floor - (r.u*Math.sin(th) + r.v*Math.cos(th));
        if (om === 0 && Math.abs(th - Math.round(th/(Math.PI/2))*(Math.PI/2)) < .004){
          th = Math.round(th/(Math.PI/2))*(Math.PI/2);
          cy = floor - H(th);
          put(0); break;
        }
      }
      put(0);
    }
    const last = pts[pts.length - 1];
    return { pts, tLand: tLand ?? 0, tEnd: last.t, last };
  }

  /* ── ROLLING DISC ─────────────────────────────────────────────────────
     For anything round. The contact height is the radius no matter the angle,
     so there is no topple: it bounces, then rolls, then friction stops it.
     Spin couples to the surface at each impact — that tangential impulse is
     what makes a coin look like a coin instead of a bouncing ball with a
     texture painted on. */
  function roll(from, floor, r, opt = {}){
    const dt   = opt.dt   ?? 1/240;
    const g    = opt.g    ?? 4400;
    const rest = opt.rest ?? .46;
    const stop = opt.stop ?? 90;
    const mu   = opt.friction ?? .35;     // rolling friction
    let { cx, cy, vx, vy } = from;
    let th = 0, om = from.spin ?? 0;
    let t = 0, tLand = null, rolling = false, n = 0;
    const pts = [];
    const put = () => pts.push({ t, cx, cy, rot: th * 180 / Math.PI, k: 0 });
    put();
    while (t < (opt.limit ?? 4) && n++ < 1600){
      t += dt;
      if (!rolling){
        vy += g*dt;  cy += vy*dt;  cx += vx*dt;  th += om*dt;
        if (cy >= floor - r && vy > 0){
          cy = floor - r;
          if (tLand === null) tLand = t;
          vy = -vy*rest;
          // the impact couples spin to the surface
          const slip = vx - om*r;
          const j = slip * .45;
          vx -= j;  om += j / r;
          if (Math.abs(vy) < stop){ vy = 0; rolling = true; }
        }
      } else {
        cy = floor - r;
        const slip = vx - om*r;
        vx -= Math.sign(slip) * Math.min(Math.abs(slip), mu*g*dt) * .5;
        om  = vx / r;                      // rolling without slipping
        vx -= Math.sign(vx) * mu*g*dt*.25; // rolling resistance
        if (Math.abs(vx) < 4){ vx = 0; om = 0; put(); break; }
        cx += vx*dt;  th += om*dt;
      }
      put();
    }
    return { pts, tLand: tLand ?? 0, tEnd: pts[pts.length-1].t, last: pts[pts.length-1] };
  }

  /* ── DEPARTURE ────────────────────────────────────────────────────────
     Something pulling away starts slow and builds: x = ½at². `ease-out` does
     the exact opposite and `ease-in` only approximates it.

     Two beats sell it beyond the maths — a weight-transfer squat before
     anything moves, and a couple of rocking oscillations that go nowhere
     before it grips.

     `dir` is not free. If the object came to rest in some orientation it now
     has a facing, and leaving the other way reads as reversing. Everything
     mirrors off this one value, including the trail, which always sits behind
     the motion. */
  function departure(from, box, opt = {}){
    const dt   = opt.dt   ?? 1/240;
    const A    = opt.a    ?? 2600;
    const VMAX = opt.vmax ?? 1900;
    const dir  = opt.dir  ?? -1;
    const W    = opt.canvasWidth ?? 1080;
    const rot0 = from.rot, y = from.cy;
    const pts  = [];
    const put = (t, cx, rot, k) => pts.push({ t, cx, cy: y, rot, k });

    put(0,    from.cx,            rot0,           0);
    put(.20,  from.cx - dir*13,   rot0 - dir*4,   0);   // squat, weight back
    put(.27,  from.cx + dir*6,    rot0 + dir*2.6, 0);   // spins, no grip
    put(.33,  from.cx - dir*12,   rot0 - dir*2.2, 0);
    put(.38,  from.cx + dir*6,    rot0 + dir*1.4, 0);
    put(.43,  from.cx + dir*10,   rot0,           0);   // grips

    let x = from.cx + dir*10, v = 0, t = 0, n = 0;
    const out = () => dir < 0 ? x > -box.w : x < W + box.w;
    while (out() && n++ < 1200){
      t += dt;
      v = Math.min(VMAX, v + A*dt);
      x += dir * v * dt;
      put(.43 + t, x, rot0 + dir*2.2*(v/VMAX), v/VMAX);
    }
    return { pts, tGo: .43, tEnd: pts[pts.length-1].t, dir };
  }

  /* Shift a point list onto the absolute timeline. */
  const at = (t0, pts) => pts.map(p => ({ ...p, t: t0 + p.t }));

  /* Points → keyframes. `extra(p)` can add per-point properties such as a
     motion trail scaled by p.k. */
  function keyframes(pts, box, extra){
    return pts.map(p => ({
      t: p.t,
      transform: `translate(${(p.cx - box.w/2).toFixed(2)}px, ${(p.cy - box.h/2).toFixed(2)}px) `
               + `rotate(${p.rot.toFixed(2)}deg)`,
      ease: 'linear',
      ...(extra ? extra(p) : {})
    }));
  }

  return { drop, roll, departure, at, keyframes };
})();
