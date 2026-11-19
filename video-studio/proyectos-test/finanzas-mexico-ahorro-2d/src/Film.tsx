import React from 'react';
import {
  AbsoluteFill,
  Sequence,
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';

const PALETTE = {
  bg: '#06281E',
  bgCard: '#0B3B2D',
  bgCardAlt: '#0F4C3A',
  emerald: '#10B981',
  lime: '#A3E635',
  gold: '#F59E0B',
  cream: '#ECFDF5',
  muted: '#94A3B8',
  danger: '#EF4444',
};

const FONT = "'Inter', 'Segoe UI', system-ui, -apple-system, sans-serif";

const EditorialGridBg: React.FC = () => {
  const frame = useCurrentFrame();
  const driftX = (frame * 0.4) % 80;
  const driftY = (frame * 0.25) % 80;

  return (
    <AbsoluteFill style={{ backgroundColor: PALETTE.bg, overflow: 'hidden' }}>
      <div
        style={{
          position: 'absolute',
          inset: -80,
          backgroundImage: `linear-gradient(to right, rgba(16,185,129,0.08) 1px, transparent 1px),
                            linear-gradient(to bottom, rgba(16,185,129,0.08) 1px, transparent 1px)`,
          backgroundSize: '80px 80px',
          translate: `${driftX}px ${driftY}px`,
        }}
      />
      <div
        style={{
          position: 'absolute',
          width: 900,
          height: 900,
          borderRadius: '50%',
          background: 'radial-gradient(circle, rgba(16,185,129,0.22) 0%, transparent 70%)',
          top: -220,
          right: -220,
        }}
      />
      <div
        style={{
          position: 'absolute',
          width: 780,
          height: 780,
          borderRadius: '50%',
          background: 'radial-gradient(circle, rgba(245,158,11,0.14) 0%, transparent 70%)',
          bottom: -180,
          left: -180,
        }}
      />
    </AbsoluteFill>
  );
};

const PesoCoinSVG: React.FC<{ size?: number; bounceFrame?: number }> = ({
  size = 180,
  bounceFrame = 0,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const f = Math.max(0, frame - bounceFrame);
  const pop = spring({ frame: f, fps, config: { damping: 10, stiffness: 180 } });
  const floatY = Math.sin(frame * 0.1) * 10;
  const squashX = 1 + Math.sin(frame * 0.1) * 0.03;
  const squashY = 1 - Math.sin(frame * 0.1) * 0.03;

  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 200 200"
      style={{
        scale: `${pop * squashX} ${pop * squashY}`,
        translate: `0px ${floatY}px`,
        filter: 'drop-shadow(0 18px 28px rgba(0,0,0,0.45))',
      }}
    >
      <defs>
        <radialGradient id="coinGold" cx="35%" cy="30%" r="70%">
          <stop offset="0%" stopColor="#FDE68A" />
          <stop offset="55%" stopColor="#F59E0B" />
          <stop offset="100%" stopColor="#B45309" />
        </radialGradient>
        <linearGradient id="coinRing" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stopColor="#E2E8F0" />
          <stop offset="100%" stopColor="#64748B" />
        </linearGradient>
      </defs>
      <circle cx="100" cy="100" r="92" fill="url(#coinRing)" />
      <circle cx="100" cy="100" r="74" fill="url(#coinGold)" stroke="#FEF3C7" strokeWidth="3" />
      <text
        x="100"
        y="124"
        textAnchor="middle"
        fontFamily={FONT}
        fontWeight="900"
        fontSize="84"
        fill="#78350F"
      >
        $
      </text>
    </svg>
  );
};

const SceneProgressBar: React.FC = () => {
  const frame = useCurrentFrame();
  const { durationInFrames } = useVideoConfig();
  const pct = interpolate(frame, [0, durationInFrames], [0, 100], {
    extrapolateRight: 'clamp',
  });
  return (
    <div
      style={{
        position: 'absolute',
        top: 44,
        left: 60,
        right: 60,
        height: 8,
        borderRadius: 999,
        backgroundColor: 'rgba(236,253,245,0.14)',
        overflow: 'hidden',
      }}
    >
      <div
        style={{
          width: `${pct}%`,
          height: '100%',
          borderRadius: 999,
          background: `linear-gradient(90deg, ${PALETTE.emerald}, ${PALETTE.lime})`,
        }}
      />
    </div>
  );
};

const KineticCaption: React.FC<{ text: string; highlight?: string }> = ({ text, highlight }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const sp = spring({ frame, fps, config: { damping: 14, stiffness: 200 } });

  return (
    <div
      style={{
        position: 'absolute',
        bottom: 130,
        left: 64,
        right: 64,
        display: 'flex',
        justifyContent: 'center',
        opacity: sp,
        translate: `0px ${interpolate(sp, [0, 1], [28, 0])}px`,
      }}
    >
      <div
        style={{
          backgroundColor: 'rgba(6, 40, 30, 0.92)',
          border: `2px solid ${PALETTE.emerald}`,
          borderRadius: 24,
          padding: '22px 34px',
          textAlign: 'center',
          boxShadow: '0 20px 45px rgba(0,0,0,0.45)',
        }}
      >
        <span style={{ fontFamily: FONT, fontSize: 38, fontWeight: 800, color: PALETTE.cream }}>
          {text}{' '}
        </span>
        {highlight && (
          <span style={{ fontFamily: FONT, fontSize: 38, fontWeight: 900, color: PALETTE.lime }}>
            {highlight}
          </span>
        )}
      </div>
    </div>
  );
};

/* ESCENA 1: Hook - Por qué tu quincena desaparece */
const Scene1Hook: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const titleSp = spring({ frame, fps, config: { damping: 14, stiffness: 150 } });
  const badgeSp = spring({ frame: frame - 12, fps, config: { damping: 12, stiffness: 180 } });
  const counterVal = Math.round(
    interpolate(frame, [15, 75], [10000, 0], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' })
  );

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', padding: '0 70px' }}>
      <div
        style={{
          padding: '12px 28px',
          borderRadius: 999,
          backgroundColor: 'rgba(245,158,11,0.18)',
          border: `2px solid ${PALETTE.gold}`,
          color: PALETTE.gold,
          fontFamily: FONT,
          fontSize: 28,
          fontWeight: 800,
          letterSpacing: 1.5,
          marginBottom: 42,
          scale: `${badgeSp}`,
        }}
      >
        FINANZAS EN MÉXICO · 2D
      </div>

      <h1
        style={{
          fontFamily: FONT,
          fontSize: 82,
          fontWeight: 900,
          color: PALETTE.cream,
          textAlign: 'center',
          lineHeight: 1.08,
          margin: 0,
          opacity: titleSp,
          translate: `0px ${interpolate(titleSp, [0, 1], [40, 0])}px`,
        }}
      >
        ¿Tu quincena <span style={{ color: PALETTE.gold }}>desaparece</span> antes del día 15?
      </h1>

      <div
        style={{
          marginTop: 54,
          backgroundColor: PALETTE.bgCard,
          border: `2px solid ${PALETTE.emerald}`,
          borderRadius: 32,
          padding: '38px 56px',
          display: 'flex',
          alignItems: 'center',
          gap: 36,
          boxShadow: '0 24px 60px rgba(0,0,0,0.4)',
        }}
      >
        <PesoCoinSVG size={140} />
        <div>
          <div style={{ fontFamily: FONT, fontSize: 24, color: PALETTE.muted, fontWeight: 700 }}>
            SALDO SIN PLAN
          </div>
          <div
            style={{
              fontFamily: FONT,
              fontSize: 72,
              fontWeight: 900,
              color: counterVal < 2000 ? PALETTE.danger : PALETTE.lime,
            }}
          >
            ${counterVal.toLocaleString('es-MX')}
          </div>
        </div>
      </div>

      <KineticCaption text="4 tips prácticos para" highlight="ahorrar en México" />
    </AbsoluteFill>
  );
};

/* ESCENA 2: Regla 50 / 30 / 20 (Adaptada de StepExplainer) */
const Scene2Regla503020: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const headerSp = spring({ frame, fps, config: { damping: 14, stiffness: 170 } });

  const steps = [
    { pct: '50%', label: 'Necesidades básicas', sub: 'Renta, despensa, transporte', color: PALETTE.emerald },
    { pct: '30%', label: 'Estilo de vida', sub: 'Salidas, streaming, gustos', color: PALETTE.gold },
    { pct: '20%', label: 'Ahorro e inversión', sub: 'Págate primero al cobrar', color: PALETTE.lime },
  ];

  return (
    <AbsoluteFill style={{ justifyContent: 'center', padding: '0 72px' }}>
      <div style={{ opacity: headerSp, translate: `0px ${interpolate(headerSp, [0, 1], [30, 0])}px` }}>
        <div style={{ fontFamily: FONT, fontSize: 28, fontWeight: 800, color: PALETTE.lime }}>
          TIP 01 · PRESUPUESTO
        </div>
        <h2 style={{ fontFamily: FONT, fontSize: 70, fontWeight: 900, color: PALETTE.cream, margin: '12px 0 48px' }}>
          La Regla 50 / 30 / 20
        </h2>
      </div>

      <div style={{ display: 'flex', flexDirection: 'column', gap: 28 }}>
        {steps.map((st, idx) => {
          const sp = spring({ frame: frame - (14 + idx * 16), fps, config: { damping: 14, stiffness: 160 } });
          const barW = interpolate(sp, [0, 1], [0, 100]);
          return (
            <div
              key={st.pct}
              style={{
                backgroundColor: PALETTE.bgCard,
                borderRadius: 28,
                padding: '32px 36px',
                border: `2px solid ${st.color}`,
                opacity: sp,
                translate: `${interpolate(sp, [0, 1], [-60, 0])}px 0px`,
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                <div>
                  <div style={{ fontFamily: FONT, fontSize: 40, fontWeight: 900, color: PALETTE.cream }}>
                    {st.label}
                  </div>
                  <div style={{ fontFamily: FONT, fontSize: 26, color: PALETTE.muted, marginTop: 6 }}>
                    {st.sub}
                  </div>
                </div>
                <div style={{ fontFamily: FONT, fontSize: 64, fontWeight: 900, color: st.color }}>
                  {st.pct}
                </div>
              </div>
              <div
                style={{
                  marginTop: 18,
                  height: 8,
                  backgroundColor: 'rgba(255,255,255,0.08)',
                  borderRadius: 99,
                  overflow: 'hidden',
                }}
              >
                <div style={{ width: `${barW}%`, height: '100%', backgroundColor: st.color }} />
              </div>
            </div>
          );
        })}
      </div>

      <KineticCaption text="Divide tu ingreso apenas" highlight="caiga la quincena" />
    </AbsoluteFill>
  );
};

/* ESCENA 3: CETES vs Debajo del colchón (Adaptada de BarChartReveal) */
const Scene3CetesVsInflacion: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const headerSp = spring({ frame, fps, config: { damping: 14, stiffness: 170 } });

  const bars = [
    { label: 'Colchón', pctText: '-4.5%', heightPx: 190, color: PALETTE.danger, note: 'Pierde valor' },
    { label: 'Banco Trad.', pctText: '+1.5%', heightPx: 260, color: PALETTE.muted, note: 'Casi cero' },
    { label: 'CETES / SOFIPO', pctText: '+10.0%', heightPx: 540, color: PALETTE.lime, note: 'Crece seguro' },
  ];

  return (
    <AbsoluteFill style={{ justifyContent: 'center', padding: '0 72px' }}>
      <div style={{ opacity: headerSp, translate: `0px ${interpolate(headerSp, [0, 1], [30, 0])}px` }}>
        <div style={{ fontFamily: FONT, fontSize: 28, fontWeight: 800, color: PALETTE.gold }}>
          TIP 02 · INFLACIÓN VS RENDIMIENTO
        </div>
        <h2 style={{ fontFamily: FONT, fontSize: 68, fontWeight: 900, color: PALETTE.cream, margin: '12px 0 42px' }}>
          No guardes efectivo, ponlo a rendir
        </h2>
      </div>

      <div
        style={{
          backgroundColor: PALETTE.bgCard,
          borderRadius: 34,
          padding: '48px 40px',
          border: `2px solid rgba(16,185,129,0.4)`,
          display: 'flex',
          alignItems: 'flex-end',
          justifyContent: 'space-around',
          height: 760,
        }}
      >
        {bars.map((b, i) => {
          const sp = spring({ frame: frame - (16 + i * 14), fps, config: { damping: 13, stiffness: 140 } });
          const h = interpolate(sp, [0, 1], [0, b.heightPx]);
          return (
            <div key={b.label} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', width: 220 }}>
              <div style={{ fontFamily: FONT, fontSize: 42, fontWeight: 900, color: b.color, opacity: sp }}>
                {b.pctText}
              </div>
              <div style={{ fontFamily: FONT, fontSize: 22, color: PALETTE.muted, marginBottom: 14, opacity: sp }}>
                {b.note}
              </div>
              <div
                style={{
                  width: 150,
                  height: h,
                  backgroundColor: b.color,
                  borderRadius: '22px 22px 6px 6px',
                  boxShadow: `0 10px 30px ${b.color}44`,
                }}
              />
              <div
                style={{
                  fontFamily: FONT,
                  fontSize: 28,
                  fontWeight: 800,
                  color: PALETTE.cream,
                  marginTop: 20,
                  textAlign: 'center',
                }}
              >
                {b.label}
              </div>
            </div>
          );
        })}
      </div>

      <KineticCaption text="CETES Directo desde" highlight="$100 MXN" />
    </AbsoluteFill>
  );
};

/* ESCENA 4: Gastos Hormiga vs Fondo de Emergencia (Adaptada de BeforeAfter) */
const Scene4GastosHormiga: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const headerSp = spring({ frame, fps, config: { damping: 14, stiffness: 170 } });
  const leftSp = spring({ frame: frame - 12, fps, config: { damping: 13, stiffness: 150 } });
  const rightSp = spring({ frame: frame - 26, fps, config: { damping: 13, stiffness: 150 } });
  const saved = Math.round(
    interpolate(frame, [30, 100], [0, 21600], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' })
  );

  return (
    <AbsoluteFill style={{ justifyContent: 'center', padding: '0 72px' }}>
      <div style={{ opacity: headerSp }}>
        <div style={{ fontFamily: FONT, fontSize: 28, fontWeight: 800, color: PALETTE.emerald }}>
          TIP 03 · FUGAS SILENCIOSAS
        </div>
        <h2 style={{ fontFamily: FONT, fontSize: 66, fontWeight: 900, color: PALETTE.cream, margin: '12px 0 44px' }}>
          Caza tus gastos hormiga
        </h2>
      </div>

      <div style={{ display: 'flex', flexDirection: 'column', gap: 32 }}>
        <div
          style={{
            backgroundColor: 'rgba(239, 68, 68, 0.14)',
            border: `2px solid ${PALETTE.danger}`,
            borderRadius: 28,
            padding: '36px 40px',
            opacity: leftSp,
            scale: `${interpolate(leftSp, [0, 1], [0.9, 1])}`,
          }}
        >
          <div style={{ fontFamily: FONT, fontSize: 26, fontWeight: 800, color: PALETTE.danger }}>
            ANTES · $60 MXN DIARIOS SIN NOTARLO
          </div>
          <div style={{ fontFamily: FONT, fontSize: 44, fontWeight: 900, color: PALETTE.cream, marginTop: 10 }}>
            Café + snacks + suscripciones = -$1,800/mes
          </div>
        </div>

        <div
          style={{
            backgroundColor: 'rgba(163, 230, 53, 0.14)',
            border: `2px solid ${PALETTE.lime}`,
            borderRadius: 28,
            padding: '40px',
            opacity: rightSp,
            scale: `${interpolate(rightSp, [0, 1], [0.9, 1])}`,
          }}
        >
          <div style={{ fontFamily: FONT, fontSize: 26, fontWeight: 800, color: PALETTE.lime }}>
            DESPUÉS · FONDO DE EMERGENCIA EN 1 AÑO
          </div>
          <div style={{ fontFamily: FONT, fontSize: 84, fontWeight: 900, color: PALETTE.lime, marginTop: 10 }}>
            +${saved.toLocaleString('es-MX')} MXN
          </div>
        </div>
      </div>

      <KineticCaption text="Tu meta: 3 a 6 meses de" highlight="fondo de emergencia" />
    </AbsoluteFill>
  );
};

/* ESCENA 5: Automatiza tu ahorro y Cierre */
const Scene5Cierre: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const cardSp = spring({ frame, fps, config: { damping: 12, stiffness: 140 } });

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', padding: '0 72px' }}>
      <PesoCoinSVG size={210} bounceFrame={4} />

      <div
        style={{
          marginTop: 48,
          backgroundColor: PALETTE.bgCardAlt,
          border: `3px solid ${PALETTE.lime}`,
          borderRadius: 36,
          padding: '48px 46px',
          textAlign: 'center',
          scale: `${cardSp}`,
          boxShadow: '0 30px 70px rgba(0,0,0,0.5)',
        }}
      >
        <div style={{ fontFamily: FONT, fontSize: 28, fontWeight: 800, color: PALETTE.gold }}>
          TIP 04 · HÁBITO AUTOMÁTICO
        </div>
        <h2 style={{ fontFamily: FONT, fontSize: 64, fontWeight: 900, color: PALETTE.cream, margin: '18px 0' }}>
          Automatiza tu ahorro el día de pago
        </h2>
        <p style={{ fontFamily: FONT, fontSize: 32, color: PALETTE.cream, opacity: 0.9, margin: 0 }}>
          Si esperas a fin de mes para ahorrar, nunca sobra.
        </p>
      </div>

      <KineticCaption text="Experimento 2D · Educación" highlight="Financiera MX" />
    </AbsoluteFill>
  );
};

export const FinanzasMexico2D: React.FC = () => {
  return (
    <AbsoluteFill>
      <EditorialGridBg />
      <Sequence from={0} durationInFrames={120}>
        <Scene1Hook />
      </Sequence>
      <Sequence from={120} durationInFrames={150}>
        <Scene2Regla503020 />
      </Sequence>
      <Sequence from={270} durationInFrames={150}>
        <Scene3CetesVsInflacion />
      </Sequence>
      <Sequence from={420} durationInFrames={150}>
        <Scene4GastosHormiga />
      </Sequence>
      <Sequence from={570} durationInFrames={180}>
        <Scene5Cierre />
      </Sequence>
      <SceneProgressBar />
    </AbsoluteFill>
  );
};
