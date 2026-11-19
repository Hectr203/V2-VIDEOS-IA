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
  bg: '#050816',
  card: 'rgba(15, 23, 42, 0.84)',
  cyan: '#38BDF8',
  violet: '#A855F7',
  gold: '#FBBF24',
  emerald: '#34D399',
  danger: '#FB7185',
  white: '#F8FAFC',
  muted: '#94A3B8',
};

const FONT = "'Inter', 'Segoe UI', system-ui, -apple-system, sans-serif";

/* Escenario 3D con plano de suelo en perspectiva */
const PerspectiveStageBg: React.FC = () => {
  const frame = useCurrentFrame();
  const gridShift = (frame * 3) % 90;

  return (
    <AbsoluteFill
      style={{
        backgroundColor: PALETTE.bg,
        perspective: 1100,
        overflow: 'hidden',
      }}
    >
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background:
            'radial-gradient(circle at 50% 28%, rgba(56,189,248,0.22) 0%, rgba(168,85,247,0.12) 45%, transparent 75%)',
        }}
      />
      <div
        style={{
          position: 'absolute',
          left: -400,
          right: -400,
          bottom: -260,
          height: 1100,
          transform: `rotateX(68deg) translateY(${gridShift}px)`,
          transformOrigin: 'center bottom',
          backgroundImage: `linear-gradient(to right, rgba(56,189,248,0.22) 2px, transparent 2px),
                            linear-gradient(to bottom, rgba(168,85,247,0.22) 2px, transparent 2px)`,
          backgroundSize: '90px 90px',
          maskImage: 'linear-gradient(to top, rgba(0,0,0,0.95) 20%, transparent 95%)',
          WebkitMaskImage: 'linear-gradient(to top, rgba(0,0,0,0.95) 20%, transparent 95%)',
        }}
      />
    </AbsoluteFill>
  );
};

/* Moneda 3D volumétrica construida con capas en el eje Z */
const Coin3D: React.FC<{ size?: number }> = ({ size = 240 }) => {
  const frame = useCurrentFrame();
  const rotY = frame * 3.2;
  const rotX = Math.sin(frame * 0.06) * 14;
  const floatY = Math.sin(frame * 0.08) * 18;
  const slices = [-12, -9, -6, -3, 0, 3, 6, 9, 12];

  return (
    <div style={{ perspective: 1200, width: size, height: size }}>
      <div
        style={{
          width: '100%',
          height: '100%',
          position: 'relative',
          transformStyle: 'preserve-3d',
          transform: `translateY(${floatY}px) rotateX(${rotX}deg) rotateY(${rotY}deg)`,
        }}
      >
        {slices.map((z) => {
          const isFront = z === 12;
          const isBack = z === -12;
          return (
            <div
              key={z}
              style={{
                position: 'absolute',
                inset: 0,
                borderRadius: '50%',
                transform: `translateZ(${z}px)`,
                background:
                  isFront || isBack
                    ? 'radial-gradient(circle at 35% 30%, #FEF08A 0%, #F59E0B 55%, #B45309 100%)'
                    : '#B45309',
                border: isFront || isBack ? '8px solid #E2E8F0' : '2px solid #78350F',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                boxShadow: isFront ? '0 0 50px rgba(251,191,36,0.45)' : undefined,
              }}
            >
              {(isFront || isBack) && (
                <span
                  style={{
                    fontFamily: FONT,
                    fontSize: size * 0.45,
                    fontWeight: 900,
                    color: '#78350F',
                    transform: isBack ? 'rotateY(180deg)' : undefined,
                  }}
                >
                  $
                </span>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
};

/* Pilar 3D extruido para gráficas espaciales */
const Pillar3D: React.FC<{
  width: number;
  height: number;
  depth: number;
  frontColor: string;
  sideColor: string;
  topColor: string;
}> = ({ width, height, depth, frontColor, sideColor, topColor }) => {
  return (
    <div
      style={{
        width,
        height,
        position: 'relative',
        transformStyle: 'preserve-3d',
      }}
    >
      {/* Cara frontal */}
      <div
        style={{
          position: 'absolute',
          inset: 0,
          backgroundColor: frontColor,
          transform: `translateZ(${depth / 2}px)`,
          borderRadius: '10px 10px 0 0',
        }}
      />
      {/* Cara derecha */}
      <div
        style={{
          position: 'absolute',
          top: 0,
          right: 0,
          width: depth,
          height,
          backgroundColor: sideColor,
          transformOrigin: 'right center',
          transform: `translateZ(${depth / 2}px) rotateY(90deg)`,
        }}
      />
      {/* Tapa superior */}
      <div
        style={{
          position: 'absolute',
          top: 0,
          left: 0,
          width,
          height: depth,
          backgroundColor: topColor,
          transformOrigin: 'top center',
          transform: `translateZ(${depth / 2}px) rotateX(90deg)`,
        }}
      />
    </div>
  );
};

const ProgressBar3D: React.FC = () => {
  const frame = useCurrentFrame();
  const { durationInFrames } = useVideoConfig();
  const pct = interpolate(frame, [0, durationInFrames], [0, 100], { extrapolateRight: 'clamp' });
  return (
    <div
      style={{
        position: 'absolute',
        top: 44,
        left: 60,
        right: 60,
        height: 8,
        borderRadius: 999,
        backgroundColor: 'rgba(248,250,252,0.12)',
        overflow: 'hidden',
      }}
    >
      <div
        style={{
          width: `${pct}%`,
          height: '100%',
          background: `linear-gradient(90deg, ${PALETTE.cyan}, ${PALETTE.violet})`,
        }}
      />
    </div>
  );
};

const Caption3D: React.FC<{ text: string; highlight: string }> = ({ text, highlight }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const sp = spring({ frame, fps, config: { damping: 14, stiffness: 180 } });
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
        transform: `translateY(${interpolate(sp, [0, 1], [32, 0])}px)`,
      }}
    >
      <div
        style={{
          backgroundColor: 'rgba(5, 8, 22, 0.88)',
          border: `2px solid ${PALETTE.cyan}`,
          borderRadius: 24,
          padding: '22px 34px',
          textAlign: 'center',
          boxShadow: '0 20px 50px rgba(56,189,248,0.22)',
        }}
      >
        <span style={{ fontFamily: FONT, fontSize: 38, fontWeight: 800, color: PALETTE.white }}>
          {text}{' '}
        </span>
        <span style={{ fontFamily: FONT, fontSize: 38, fontWeight: 900, color: PALETTE.cyan }}>
          {highlight}
        </span>
      </div>
    </div>
  );
};

/* ESCENA 1: Moneda 3D + Tarjeta Glassmórfica con inclinación 3D */
const Scene1Hook3D: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const cardSp = spring({ frame: frame - 6, fps, config: { damping: 14, stiffness: 140 } });
  const tiltY = Math.sin(frame * 0.05) * 10;
  const tiltX = Math.cos(frame * 0.04) * 6;

  return (
    <AbsoluteFill
      style={{
        justifyContent: 'center',
        alignItems: 'center',
        padding: '0 68px',
        perspective: 1400,
      }}
    >
      <Coin3D size={230} />

      <div
        style={{
          marginTop: 56,
          backgroundColor: PALETTE.card,
          border: `2px solid ${PALETTE.cyan}`,
          borderRadius: 36,
          padding: '48px 44px',
          textAlign: 'center',
          transformStyle: 'preserve-3d',
          transform: `scale(${cardSp}) rotateY(${tiltY}deg) rotateX(${tiltX}deg)`,
          boxShadow: '0 32px 80px rgba(56,189,248,0.25)',
        }}
      >
        <div
          style={{
            fontFamily: FONT,
            fontSize: 26,
            fontWeight: 800,
            color: PALETTE.violet,
            letterSpacing: 2,
            transform: 'translateZ(30px)',
          }}
        >
          FINANZAS EN MÉXICO · 3D
        </div>
        <h1
          style={{
            fontFamily: FONT,
            fontSize: 72,
            fontWeight: 900,
            color: PALETTE.white,
            lineHeight: 1.1,
            margin: '18px 0 0',
            transform: 'translateZ(50px)',
          }}
        >
          Domina tu ahorro con <span style={{ color: PALETTE.gold }}>inteligencia</span>
        </h1>
      </div>

      <Caption3D text="4 claves para hacer crecer" highlight="tu dinero en México" />
    </AbsoluteFill>
  );
};

/* ESCENA 2: Tarjetas 3D apiladas en profundidad Z (50 / 30 / 20) */
const Scene2Bloques3D: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const camY = interpolate(frame, [0, 150], [-10, 8], { extrapolateRight: 'clamp' });

  const layers = [
    { pct: '50%', title: 'Necesidades', color: PALETTE.cyan, z: 0 },
    { pct: '30%', title: 'Gustos', color: PALETTE.violet, z: 40 },
    { pct: '20%', title: 'Ahorro e Inversión', color: PALETTE.emerald, z: 80 },
  ];

  return (
    <AbsoluteFill style={{ justifyContent: 'center', padding: '0 72px', perspective: 1400 }}>
      <div style={{ fontFamily: FONT, fontSize: 28, fontWeight: 800, color: PALETTE.cyan }}>
        TIP 01 · ARQUITECTURA 50/30/20
      </div>
      <h2 style={{ fontFamily: FONT, fontSize: 66, fontWeight: 900, color: PALETTE.white, margin: '10px 0 46px' }}>
        Capas de tu quincena
      </h2>

      <div
        style={{
          display: 'flex',
          flexDirection: 'column',
          gap: 30,
          transformStyle: 'preserve-3d',
          transform: `rotateY(${camY}deg) rotateX(6deg)`,
        }}
      >
        {layers.map((layer, idx) => {
          const sp = spring({ frame: frame - idx * 14, fps, config: { damping: 13, stiffness: 150 } });
          return (
            <div
              key={layer.pct}
              style={{
                backgroundColor: PALETTE.card,
                border: `2px solid ${layer.color}`,
                borderRadius: 28,
                padding: '34px 40px',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                transform: `translateZ(${interpolate(sp, [0, 1], [-180, layer.z])}px)`,
                opacity: sp,
                boxShadow: `0 22px 50px ${layer.color}33`,
              }}
            >
              <div style={{ fontFamily: FONT, fontSize: 42, fontWeight: 900, color: PALETTE.white }}>
                {layer.title}
              </div>
              <div style={{ fontFamily: FONT, fontSize: 64, fontWeight: 900, color: layer.color }}>
                {layer.pct}
              </div>
            </div>
          );
        })}
      </div>

      <Caption3D text="Separa primero el" highlight="20% de tu ingreso" />
    </AbsoluteFill>
  );
};

/* ESCENA 3: Pilares 3D Extruidos (Inflación vs CETES) */
const Scene3Pilares3D: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const rotY = interpolate(frame, [0, 150], [-28, -14], { extrapolateRight: 'clamp' });

  const h1 = Math.round(interpolate(spring({ frame: frame - 10, fps, config: { damping: 14 } }), [0, 1], [20, 160]));
  const h2 = Math.round(interpolate(spring({ frame: frame - 22, fps, config: { damping: 14 } }), [0, 1], [20, 240]));
  const h3 = Math.round(interpolate(spring({ frame: frame - 34, fps, config: { damping: 14 } }), [0, 1], [20, 520]));

  return (
    <AbsoluteFill style={{ justifyContent: 'center', padding: '0 72px', perspective: 1300 }}>
      <div style={{ fontFamily: FONT, fontSize: 28, fontWeight: 800, color: PALETTE.gold }}>
        TIP 02 · RENDIMIENTO REAL
      </div>
      <h2 style={{ fontFamily: FONT, fontSize: 66, fontWeight: 900, color: PALETTE.white, margin: '10px 0 40px' }}>
        Colchón vs CETES Directo
      </h2>

      <div
        style={{
          height: 680,
          display: 'flex',
          alignItems: 'flex-end',
          justifyContent: 'space-around',
          transformStyle: 'preserve-3d',
          transform: `rotateX(-12deg) rotateY(${rotY}deg)`,
          paddingBottom: 40,
        }}
      >
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 18 }}>
          <span style={{ fontFamily: FONT, fontSize: 36, fontWeight: 900, color: PALETTE.danger }}>-4.5%</span>
          <Pillar3D
            width={140}
            height={h1}
            depth={80}
            frontColor="#FB7185"
            sideColor="#BE123C"
            topColor="#FDA4AF"
          />
          <span style={{ fontFamily: FONT, fontSize: 26, fontWeight: 800, color: PALETTE.white }}>Colchón</span>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 18 }}>
          <span style={{ fontFamily: FONT, fontSize: 36, fontWeight: 900, color: PALETTE.muted }}>+1.5%</span>
          <Pillar3D
            width={140}
            height={h2}
            depth={80}
            frontColor="#64748B"
            sideColor="#334155"
            topColor="#94A3B8"
          />
          <span style={{ fontFamily: FONT, fontSize: 26, fontWeight: 800, color: PALETTE.white }}>Banco</span>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 18 }}>
          <span style={{ fontFamily: FONT, fontSize: 40, fontWeight: 900, color: PALETTE.emerald }}>+10.0%</span>
          <Pillar3D
            width={140}
            height={h3}
            depth={80}
            frontColor="#34D399"
            sideColor="#047857"
            topColor="#6EE7B7"
          />
          <span style={{ fontFamily: FONT, fontSize: 26, fontWeight: 800, color: PALETTE.white }}>CETES</span>
        </div>
      </div>

      <Caption3D text="Tu dinero protegido contra" highlight="la inflación" />
    </AbsoluteFill>
  );
};

/* ESCENA 4: Tarjeta Flip 3D (Gastos Hormiga -> Ahorro Anual) */
const Scene4Flip3D: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const flipProgress = spring({ frame: frame - 42, fps, config: { damping: 14, stiffness: 120 } });
  const rotY = interpolate(flipProgress, [0, 1], [0, 180]);

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', padding: '0 72px', perspective: 1400 }}>
      <div style={{ fontFamily: FONT, fontSize: 28, fontWeight: 800, color: PALETTE.violet, marginBottom: 12 }}>
        TIP 03 · EFECTO COMPUESTO
      </div>
      <h2 style={{ fontFamily: FONT, fontSize: 64, fontWeight: 900, color: PALETTE.white, textAlign: 'center', margin: '0 0 48px' }}>
        Elimina fugas diarias
      </h2>

      <div
        style={{
          width: 860,
          height: 460,
          position: 'relative',
          transformStyle: 'preserve-3d',
          transform: `rotateY(${rotY}deg)`,
        }}
      >
        {/* Frente: Gasto hormiga */}
        <div
          style={{
            position: 'absolute',
            inset: 0,
            backfaceVisibility: 'hidden',
            WebkitBackfaceVisibility: 'hidden',
            backgroundColor: 'rgba(251, 113, 133, 0.16)',
            border: `3px solid ${PALETTE.danger}`,
            borderRadius: 36,
            display: 'flex',
            flexDirection: 'column',
            justifyContent: 'center',
            alignItems: 'center',
            padding: 44,
          }}
        >
          <div style={{ fontFamily: FONT, fontSize: 30, fontWeight: 800, color: PALETTE.danger }}>
            GASTO HORMIGA DIARIO
          </div>
          <div style={{ fontFamily: FONT, fontSize: 96, fontWeight: 900, color: PALETTE.white, marginTop: 14 }}>
            -$60 / día
          </div>
        </div>

        {/* Reverso: Ahorro anual */}
        <div
          style={{
            position: 'absolute',
            inset: 0,
            backfaceVisibility: 'hidden',
            WebkitBackfaceVisibility: 'hidden',
            transform: 'rotateY(180deg)',
            backgroundColor: 'rgba(52, 211, 153, 0.16)',
            border: `3px solid ${PALETTE.emerald}`,
            borderRadius: 36,
            display: 'flex',
            flexDirection: 'column',
            justifyContent: 'center',
            alignItems: 'center',
            padding: 44,
            boxShadow: '0 30px 70px rgba(52,211,153,0.28)',
          }}
        >
          <div style={{ fontFamily: FONT, fontSize: 30, fontWeight: 800, color: PALETTE.emerald }}>
            FONDO DE EMERGENCIA ANUAL
          </div>
          <div style={{ fontFamily: FONT, fontSize: 96, fontWeight: 900, color: PALETTE.emerald, marginTop: 14 }}>
            +$21,600
          </div>
        </div>
      </div>

      <Caption3D text="Pequeños cambios crean" highlight="grandes reservas" />
    </AbsoluteFill>
  );
};

/* ESCENA 5: Bóveda 3D Orbital + Automatización */
const Scene5Cierre3D: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const pop = spring({ frame, fps, config: { damping: 13, stiffness: 140 } });
  const ringRot = frame * 1.4;

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', padding: '0 72px', perspective: 1300 }}>
      <div style={{ position: 'relative', width: 320, height: 320, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <div
          style={{
            position: 'absolute',
            inset: 0,
            borderRadius: '50%',
            border: `4px dashed ${PALETTE.cyan}`,
            transform: `rotateX(65deg) rotateZ(${ringRot}deg)`,
          }}
        />
        <Coin3D size={200} />
      </div>

      <div
        style={{
          marginTop: 46,
          backgroundColor: PALETTE.card,
          border: `3px solid ${PALETTE.violet}`,
          borderRadius: 36,
          padding: '44px 42px',
          textAlign: 'center',
          transform: `scale(${pop}) rotateX(6deg)`,
          boxShadow: '0 30px 70px rgba(168,85,247,0.32)',
        }}
      >
        <div style={{ fontFamily: FONT, fontSize: 28, fontWeight: 800, color: PALETTE.cyan }}>
          TIP 04 · DOMICILIACIÓN AUTOMÁTICA
        </div>
        <h2 style={{ fontFamily: FONT, fontSize: 62, fontWeight: 900, color: PALETTE.white, margin: '16px 0' }}>
          Programa tu ahorro cada quincena
        </h2>
        <p style={{ fontFamily: FONT, fontSize: 30, color: PALETTE.muted, margin: 0 }}>
          Educación financiera constante = libertad real.
        </p>
      </div>

      <Caption3D text="Experimento 3D · Remotion" highlight="Perspectiva Espacial" />
    </AbsoluteFill>
  );
};

export const FinanzasMexico3D: React.FC = () => {
  return (
    <AbsoluteFill>
      <PerspectiveStageBg />
      <Sequence from={0} durationInFrames={120}>
        <Scene1Hook3D />
      </Sequence>
      <Sequence from={120} durationInFrames={150}>
        <Scene2Bloques3D />
      </Sequence>
      <Sequence from={270} durationInFrames={150}>
        <Scene3Pilares3D />
      </Sequence>
      <Sequence from={420} durationInFrames={150}>
        <Scene4Flip3D />
      </Sequence>
      <Sequence from={570} durationInFrames={180}>
        <Scene5Cierre3D />
      </Sequence>
      <ProgressBar3D />
    </AbsoluteFill>
  );
};
