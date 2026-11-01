import React from 'react';
import { joint, wave, ease, clamp, Point } from '../../../shared-art/math/motion';

export type ChavoPose = 'seated_car' | 'standing' | 'eso_eso' | 'pipipipi' | 'barrel_peek';
export type ChavoMood = 'neutral' | 'talk' | 'smile' | 'crying' | 'scared' | 'determined';

export interface ChavoRigProps {
  x?: number;
  y?: number;
  scale?: number;
  f: number;
  pose?: ChavoPose;
  mood?: ChavoMood;
  showToyCar?: boolean;
  showBarrel?: boolean;
  showBackground?: boolean;
  lookX?: number; // -1 (izq) a 1 (der)
  lookY?: number; // -1 (arriba) a 1 (abajo)
}

export const CHAVO_COLORS = {
  skin: '#fad7bd',
  skinShadow: '#dba785',
  hair: '#241a18',

  // Gorro con cuadros estilo ushanka
  hatBase: '#697268',
  hatCharcoal: '#383d37',
  hatSage: '#9da79c',
  hatDarkLine: '#20241f',
  hatVisorUnderside: '#474c46',

  // Camiseta a rayas horizontales
  shirtBrown: '#5a3d24',
  shirtDark: '#201e20',
  shirtCream: '#eae5dc',

  // Tirante rojo anaranjado
  suspender: '#e84534',
  suspenderShadow: '#b82f1f',

  // Pantalón / bermudas con parche
  pants: '#d1cbc2',
  pantsShadow: '#b5afa5',
  patch: '#847e75',
  patchStitch: '#1b1a19',

  // Carrito de juguete
  carRed: '#f0433a',
  carWindow: '#8ed5fa',
  carBlack: '#1e2126',

  // Barril de madera
  barrelWoodDark: '#4a2f18',
  barrelWoodMed: '#6c4727',
  barrelWoodLight: '#8a5e35',
  barrelHoop: '#1a1816',

  // Fondo de vecindad
  wallOrange: '#f29f2e',
  floorBrown: '#ba792f',
  lineDark: '#161514'
};

export const ChavoDefs: React.FC = () => {
  return (
    <defs>
      {/* Patrón de cuadros con bloques grandes calibrado al dibujo */}
      <pattern id="chavo-hat-plaid" width="60" height="60" patternUnits="userSpaceOnUse" patternTransform="rotate(-4)">
        <rect width="60" height="60" fill={CHAVO_COLORS.hatBase} />
        <rect x="0" y="0" width="30" height="30" fill={CHAVO_COLORS.hatCharcoal} />
        <rect x="30" y="30" width="30" height="30" fill={CHAVO_COLORS.hatCharcoal} />
        <rect x="30" y="0" width="30" height="30" fill={CHAVO_COLORS.hatSage} opacity="0.9" />
        <rect x="0" y="30" width="30" height="30" fill={CHAVO_COLORS.hatSage} opacity="0.9" />
        <line x1="0" y1="30" x2="60" y2="30" stroke={CHAVO_COLORS.hatDarkLine} strokeWidth="1.8" />
        <line x1="30" y1="0" x2="30" y2="60" stroke={CHAVO_COLORS.hatDarkLine} strokeWidth="1.8" />
      </pattern>

      {/* Patrón para orejeras */}
      <pattern id="chavo-hat-flap-l" width="50" height="50" patternUnits="userSpaceOnUse" patternTransform="rotate(3)">
        <rect width="50" height="50" fill={CHAVO_COLORS.hatBase} />
        <rect x="0" y="0" width="25" height="25" fill={CHAVO_COLORS.hatCharcoal} />
        <rect x="25" y="25" width="25" height="25" fill={CHAVO_COLORS.hatCharcoal} />
        <rect x="25" y="0" width="25" height="25" fill={CHAVO_COLORS.hatSage} opacity="0.85" />
        <rect x="0" y="25" width="25" height="25" fill={CHAVO_COLORS.hatSage} opacity="0.85" />
        <line x1="0" y1="25" x2="50" y2="25" stroke={CHAVO_COLORS.hatDarkLine} strokeWidth="1.8" />
        <line x1="25" y1="0" x2="25" y2="50" stroke={CHAVO_COLORS.hatDarkLine} strokeWidth="1.8" />
      </pattern>

      <pattern id="chavo-hat-flap-r" width="50" height="50" patternUnits="userSpaceOnUse" patternTransform="rotate(-6)">
        <rect width="50" height="50" fill={CHAVO_COLORS.hatBase} />
        <rect x="0" y="0" width="25" height="25" fill={CHAVO_COLORS.hatCharcoal} />
        <rect x="25" y="25" width="25" height="25" fill={CHAVO_COLORS.hatCharcoal} />
        <rect x="25" y="0" width="25" height="25" fill={CHAVO_COLORS.hatSage} opacity="0.85" />
        <rect x="0" y="25" width="25" height="25" fill={CHAVO_COLORS.hatSage} opacity="0.85" />
        <line x1="0" y1="25" x2="50" y2="25" stroke={CHAVO_COLORS.hatDarkLine} strokeWidth="1.8" />
        <line x1="25" y1="0" x2="25" y2="50" stroke={CHAVO_COLORS.hatDarkLine} strokeWidth="1.8" />
      </pattern>

      {/* Gradiente para duelas del barril */}
      <linearGradient id="chavo-barrel-wood" x1="0" y1="0" x2="1" y2="0">
        <stop offset="0%" stopColor={CHAVO_COLORS.barrelWoodDark} />
        <stop offset="35%" stopColor={CHAVO_COLORS.barrelWoodLight} />
        <stop offset="70%" stopColor={CHAVO_COLORS.barrelWoodMed} />
        <stop offset="100%" stopColor={CHAVO_COLORS.barrelWoodDark} />
      </linearGradient>
    </defs>
  );
};

export const ChavoRig: React.FC<ChavoRigProps> = ({
  x = 0,
  y = 0,
  scale = 1,
  f,
  pose = 'seated_car',
  mood = 'neutral',
  showToyCar = true,
  showBarrel = true,
  showBackground = false,
  lookX = 0,
  lookY = 0,
}) => {
  // Dinámicas biológicas y sutiles
  const breathe = wave(f, 0.05, 3.0);
  const headBob = wave(f, 0.05, 1.5, 0.4);
  const hatFlapSway = wave(f, 0.06, 1.8);
  const carVibe = pose === 'seated_car' ? wave(f, 0.1, 0.8) : 0;

  // Parpadeo cómico (ojos se aplanan verticalmente)
  const blinkCycle = f % 115;
  const isBlinking = blinkCycle > 110;
  const blinkScale = isBlinking ? 0.05 : 1;

  // Expresiones
  const isCrying = mood === 'crying' || pose === 'pipipipi';
  const cryTremble = isCrying ? wave(f, 0.45, 2.5) : 0;
  const tearDropY = isCrying ? (f * 4) % 60 : 0;
  const mouthOpen = mood === 'talk' ? Math.abs(wave(f, 0.35, 6)) : 0;

  return (
    <g transform={`translate(${x} ${y}) scale(${scale})`}>
      <ChavoDefs />

      {/* ---------------------------------------------------- */}
      {/* EL BARRIL DEL CHAVO                                  */}
      {/* ---------------------------------------------------- */}
      {showBarrel && (
        <g id="el-barril" transform="translate(-200, -120)">
          {/* Sombra en el suelo */}
          <ellipse cx="0" cy="380" rx="115" ry="26" fill="#000000" opacity="0.35" />

          {/* Cuerpo curvado del barril */}
          <path
            d="M -85,-240 Q -125,50 -90,370 L 90,370 Q 125,50 85,-240 Z"
            fill="url(#chavo-barrel-wood)"
            stroke={CHAVO_COLORS.lineDark}
            strokeWidth="6"
            strokeLinejoin="round"
          />

          {/* Duelas / Tablas verticales de madera */}
          <path d="M -50,-240 Q -78,50 -55,370" stroke="#351f0f" strokeWidth="3.5" fill="none" opacity="0.65" />
          <path d="M -18,-240 Q -26,50 -18,370" stroke="#351f0f" strokeWidth="3.5" fill="none" opacity="0.65" />
          <path d="M 18,-240 Q 26,50 18,370" stroke="#351f0f" strokeWidth="3.5" fill="none" opacity="0.65" />
          <path d="M 50,-240 Q 78,50 55,370" stroke="#351f0f" strokeWidth="3.5" fill="none" opacity="0.65" />

          {/* Flejes metálicos negros */}
          <path d="M -88,-180 Q 0,-158 88,-180" stroke={CHAVO_COLORS.barrelHoop} strokeWidth="22" fill="none" strokeLinecap="round" />
          <path d="M -106,-40 Q 0,-12 106,-40" stroke={CHAVO_COLORS.barrelHoop} strokeWidth="24" fill="none" strokeLinecap="round" />
          <path d="M -107,145 Q 0,175 107,145" stroke={CHAVO_COLORS.barrelHoop} strokeWidth="24" fill="none" strokeLinecap="round" />
          <path d="M -92,305 Q 0,330 92,305" stroke={CHAVO_COLORS.barrelHoop} strokeWidth="24" fill="none" strokeLinecap="round" />

          {/* Remaches de metal */}
          <circle cx="-60" cy="-170" r="3.5" fill="#666" />
          <circle cx="60" cy="-170" r="3.5" fill="#666" />
          <circle cx="-78" cy="-28" r="4" fill="#666" />
          <circle cx="78" cy="-28" r="4" fill="#666" />
          <circle cx="-78" cy="160" r="4" fill="#666" />
          <circle cx="78" cy="160" r="4" fill="#666" />

          {/* Boca superior del barril */}
          <ellipse cx="0" cy="-240" rx="85" ry="20" fill="#361f10" stroke={CHAVO_COLORS.lineDark} strokeWidth="6" />
          <ellipse cx="0" cy="-240" rx="74" ry="14" fill="#180e07" />
        </g>
      )}

      {/* ---------------------------------------------------- */}
      {/* CUERPO DEL PERSONAJE                                 */}
      {/* ---------------------------------------------------- */}
      <g id="chavo-body-rig" transform={`translate(0, ${breathe})`}>

        {/* PIERNAS Y PANTALÓN (POSE SENTADO EXACTA A LA REFERENCIA) */}
        {pose === 'seated_car' ? (
          <g id="legs-seated">
            {/* Pierna derecha extendida en ángulo hacia la esquina inferior derecha */}
            <g id="leg-right-extended">
              <path
                d="M 50,160 L 140,210 Q 200,240 240,265 L 195,320 Q 140,285 55,225 Z"
                fill={CHAVO_COLORS.skin}
                stroke={CHAVO_COLORS.lineDark}
                strokeWidth="5.5"
                strokeLinejoin="round"
                strokeLinecap="round"
              />
              {/* Pliegue anatómico de la rodilla derecha */}
              <path d="M 125,200 Q 148,225 136,250" stroke={CHAVO_COLORS.lineDark} strokeWidth="4.5" fill="none" strokeLinecap="round" />
            </g>

            {/* Pierna izquierda doblada en el suelo */}
            <path
              d="M -75,145 Q -95,190 -50,215 Q -25,215 -35,175 Z"
              fill={CHAVO_COLORS.skin}
              stroke={CHAVO_COLORS.lineDark}
              strokeWidth="5.5"
              strokeLinejoin="round"
            />

            {/* BERMUDAS / PANTALÓN GRIS CLARO DEL CHAVO */}
            <g id="shorts-seated">
              {/* Silueta de los shorts con pernera ancha derecha */}
              <path
                d="M -90,115 L 45,125 L 90,180 L 15,230 L -45,210 L -80,210 Z"
                fill={CHAVO_COLORS.pants}
                stroke={CHAVO_COLORS.lineDark}
                strokeWidth="5.5"
                strokeLinejoin="round"
              />
              {/* Pliegue de entrepierna */}
              <line x1="15" y1="230" x2="-8" y2="175" stroke={CHAVO_COLORS.lineDark} strokeWidth="5" strokeLinecap="round" />

              {/* PARCHE RECTANGULAR GRIS OSCURO CON PESPUNTES NEGROS */}
              <g id="chavo-patch" transform="translate(-52, 165) rotate(-5)">
                <polygon
                  points="0,0 36,3 32,22 -3,19"
                  fill={CHAVO_COLORS.patch}
                  stroke={CHAVO_COLORS.lineDark}
                  strokeWidth="3.5"
                />
                {/* Costuras pespunteadas en los cuatro costados */}
                <line x1="-1" y1="-2" x2="37" y2="1" stroke={CHAVO_COLORS.patchStitch} strokeWidth="3.5" strokeDasharray="5,4" />
                <line x1="37" y1="1" x2="33" y2="24" stroke={CHAVO_COLORS.patchStitch} strokeWidth="3.5" strokeDasharray="5,4" />
                <line x1="33" y1="24" x2="-4" y2="21" stroke={CHAVO_COLORS.patchStitch} strokeWidth="3.5" strokeDasharray="5,4" />
                <line x1="-4" y1="21" x2="-1" y2="-2" stroke={CHAVO_COLORS.patchStitch} strokeWidth="3.5" strokeDasharray="5,4" />
              </g>
            </g>
          </g>
        ) : (
          <g id="legs-standing">
            <rect x="-55" y="150" width="38" height="90" rx="10" fill={CHAVO_COLORS.pants} stroke={CHAVO_COLORS.lineDark} strokeWidth="5" />
            <rect x="-50" y="235" width="28" height="80" rx="8" fill={CHAVO_COLORS.skin} stroke={CHAVO_COLORS.lineDark} strokeWidth="5" />
            <ellipse cx="-36" cy="320" rx="20" ry="10" fill="#2d221c" stroke={CHAVO_COLORS.lineDark} strokeWidth="4" />

            <rect x="15" y="150" width="40" height="90" rx="10" fill={CHAVO_COLORS.pants} stroke={CHAVO_COLORS.lineDark} strokeWidth="5" />
            <rect x="21" y="235" width="28" height="80" rx="8" fill={CHAVO_COLORS.skin} stroke={CHAVO_COLORS.lineDark} strokeWidth="5" />
            <ellipse cx="35" cy="320" rx="20" ry="10" fill="#2d221c" stroke={CHAVO_COLORS.lineDark} strokeWidth="4" />

            <g transform="translate(20, 180)">
              <polygon points="0,0 28,2 25,18 -3,16" fill={CHAVO_COLORS.patch} stroke={CHAVO_COLORS.lineDark} strokeWidth="2.5" />
              <line x1="-1" y1="-2" x2="29" y2="0" stroke={CHAVO_COLORS.patchStitch} strokeWidth="2.5" strokeDasharray="4,3" />
            </g>
          </g>
        )}

        {/* ---------------------------------------------------- */}
        {/* TORSO Y CAMISETA A RAYAS HORIZONTALES               */}
        {/* ---------------------------------------------------- */}
        <g id="torso">
          <clipPath id="chavo-torso-clip">
            <path d="M -90,-25 L 60,-20 L 50,135 L -80,130 Z" />
          </clipPath>

          <g clipPath="url(#chavo-torso-clip)">
            {/* Franja 1 superior: Marrón cálido */}
            <rect x="-100" y="-35" width="190" height="42" fill={CHAVO_COLORS.shirtBrown} />
            {/* Franja 2: Carbón oscuro */}
            <rect x="-100" y="7" width="190" height="38" fill={CHAVO_COLORS.shirtDark} />
            {/* Franja 3: Blanco crema */}
            <rect x="-100" y="45" width="190" height="40" fill={CHAVO_COLORS.shirtCream} />
            {/* Franja 4: Marrón cálido */}
            <rect x="-100" y="85" width="190" height="36" fill={CHAVO_COLORS.shirtBrown} />
            {/* Franja 5: Blanco crema */}
            <rect x="-100" y="121" width="190" height="40" fill={CHAVO_COLORS.shirtCream} />
          </g>

          {/* Contorno exterior del torso */}
          <path
            d="M -90,-25 L 60,-20 L 50,135 L -80,130 Z"
            fill="none"
            stroke={CHAVO_COLORS.lineDark}
            strokeWidth="5.5"
            strokeLinejoin="round"
          />

          {/* Cuello redondo de la camiseta */}
          <path
            d="M -45,-30 Q -10,-15 18,-25"
            stroke={CHAVO_COLORS.lineDark}
            strokeWidth="5.5"
            fill="none"
            strokeLinecap="round"
          />

          {/* MANGA IZQUIERDA (SUELTA CON FRANJA) */}
          <g id="sleeve-left">
            <path
              d="M -75,-20 L -135,20 L -105,65 L -68,25 Z"
              fill={CHAVO_COLORS.shirtCream}
              stroke={CHAVO_COLORS.lineDark}
              strokeWidth="5.5"
              strokeLinejoin="round"
            />
            {/* Franja marrón en la manga */}
            <path
              d="M -75,-20 L -115,7 L -95,40 L -68,25 Z"
              fill={CHAVO_COLORS.shirtBrown}
              stroke={CHAVO_COLORS.lineDark}
              strokeWidth="4"
            />
            {/* Franja oscura */}
            <path
              d="M -115,7 L -128,14 L -102,52 L -95,40 Z"
              fill={CHAVO_COLORS.shirtDark}
            />
            <path
              d="M -75,-20 L -135,20 L -105,65 L -68,25 Z"
              fill="none"
              stroke={CHAVO_COLORS.lineDark}
              strokeWidth="5.5"
            />
          </g>

          {/* MANGA DERECHA */}
          <g id="sleeve-right">
            <path
              d="M 42,-18 L 78,18 L 52,60 L 25,38 Z"
              fill={CHAVO_COLORS.shirtCream}
              stroke={CHAVO_COLORS.lineDark}
              strokeWidth="5.5"
              strokeLinejoin="round"
            />
            <path
              d="M 42,-18 L 65,4 L 45,44 L 25,38 Z"
              fill={CHAVO_COLORS.shirtBrown}
              stroke={CHAVO_COLORS.lineDark}
              strokeWidth="3.5"
            />
            {/* Franja oscura */}
            <path
              d="M 65,4 L 74,14 L 50,56 L 45,44 Z"
              fill={CHAVO_COLORS.shirtDark}
            />
            <path
              d="M 42,-18 L 78,18 L 52,60 L 25,38 Z"
              fill="none"
              stroke={CHAVO_COLORS.lineDark}
              strokeWidth="5.5"
            />
          </g>

          {/* -------------------------------------------------- */}
          {/* EL TIRANTE ROJO ANARANJADO (DOBLE TIRA DE LA FOTO) */}
          {/* -------------------------------------------------- */}
          <g id="el-tirante">
            {/* Sombra proyectada */}
            <path d="M 8,-26 L -38,140 L -18,142 L 28,-24 Z" fill="#000000" opacity="0.16" />

            {/* Tira principal izquierda */}
            <path
              d="M 6,-28 L -42,138 L -26,140 L 22,-26 Z"
              fill={CHAVO_COLORS.suspender}
              stroke={CHAVO_COLORS.lineDark}
              strokeWidth="5"
              strokeLinejoin="round"
            />

            {/* Segunda tira / rama del tirante que se abre hacia la derecha */}
            <path
              d="M 16,-26 L -10,130 L 0,130 L 26,-26 Z"
              fill={CHAVO_COLORS.suspender}
              stroke={CHAVO_COLORS.lineDark}
              strokeWidth="4.5"
              strokeLinejoin="round"
            />
          </g>
        </g>

        {/* ---------------------------------------------------- */}
        {/* BRAZOS, MANO Y CARRITO DE JUGUETE                   */}
        {/* ---------------------------------------------------- */}
        {pose === 'seated_car' ? (
          <g id="arms-seated">
            {/* Brazo izquierdo que apoya en el costado/regazo */}
            <path
              d="M -115,45 Q -90,110 -15,115 Q -45,150 -95,140 Q -135,105 -130,50 Z"
              fill={CHAVO_COLORS.skin}
              stroke={CHAVO_COLORS.lineDark}
              strokeWidth="5.5"
              strokeLinejoin="round"
              strokeLinecap="round"
            />

            {/* Brazo derecho que desciende y sujeta el carrito rojo */}
            <g id="arm-right-holding-car" transform={`translate(0, ${carVibe})`}>
              {/* Antebrazo y mano */}
              <path
                d="M 45,45 Q 70,110 35,145 L 20,145 Q -20,135 -25,110 Q 5,100 20,55 Z"
                fill={CHAVO_COLORS.skin}
                stroke={CHAVO_COLORS.lineDark}
                strokeWidth="5.5"
                strokeLinejoin="round"
              />
              {/* Dedos envolviendo la parte superior del carrito */}
              <path
                d="M -18,118 Q -2,138 18,134 Q 24,121 8,108"
                fill={CHAVO_COLORS.skin}
                stroke={CHAVO_COLORS.lineDark}
                strokeWidth="4.5"
                strokeLinecap="round"
              />
            </g>

            {/* CARRITO DE JUGUETE ROJO (Fiel a la foto) */}
            {showToyCar && (
              <g id="toy-car" transform={`translate(-18, 132) rotate(-4) translate(0, ${carVibe})`}>
                {/* Ruedas negras debajo */}
                <ellipse cx="-10" cy="30" rx="9" ry="9" fill={CHAVO_COLORS.carBlack} stroke={CHAVO_COLORS.lineDark} strokeWidth="3.5" />
                <ellipse cx="65" cy="30" rx="9" ry="9" fill={CHAVO_COLORS.carBlack} stroke={CHAVO_COLORS.lineDark} strokeWidth="3.5" />

                {/* Chasis rojo de madera */}
                <path
                  d="M -28,12 L 85,20 L 80,35 L -26,32 Z"
                  fill={CHAVO_COLORS.carRed}
                  stroke={CHAVO_COLORS.lineDark}
                  strokeWidth="5"
                  strokeLinejoin="round"
                />

                {/* Cabina / Parabrisas celeste */}
                <polygon
                  points="22,14 45,-6 62,-6 56,16"
                  fill={CHAVO_COLORS.carWindow}
                  stroke={CHAVO_COLORS.lineDark}
                  strokeWidth="4"
                  strokeLinejoin="round"
                />

                {/* Techo y brillo superior */}
                <path
                  d="M -24,12 Q 10,-1 75,11 L 72,17 L -26,15 Z"
                  fill="#ff5952"
                  stroke={CHAVO_COLORS.lineDark}
                  strokeWidth="3.5"
                />
              </g>
            )}
          </g>
        ) : pose === 'eso_eso' ? (
          <g id="arms-eso-eso">
            <path d="M -80,10 Q -110,60 -75,90" stroke={CHAVO_COLORS.skin} strokeWidth="22" strokeLinecap="round" fill="none" />
            <path d="M -80,10 Q -110,60 -75,90" stroke={CHAVO_COLORS.lineDark} strokeWidth="27" strokeLinecap="round" fill="none" style={{zIndex: -1}} />

            <g transform={`rotate(${wave(f, 0.4, 12)}, 50, 20)`}>
              <path d="M 50,20 Q 95,15 130,-5" stroke={CHAVO_COLORS.skin} strokeWidth="20" strokeLinecap="round" fill="none" />
              <line x1="130" y1="-5" x2="165" y2="-15" stroke={CHAVO_COLORS.skin} strokeWidth="12" strokeLinecap="round" />
              <line x1="130" y1="-5" x2="165" y2="-15" stroke={CHAVO_COLORS.lineDark} strokeWidth="17" strokeLinecap="round" style={{zIndex: -1}} />
              <circle cx="128" cy="-3" r="14" fill={CHAVO_COLORS.skin} stroke={CHAVO_COLORS.lineDark} strokeWidth="4" />
            </g>
          </g>
        ) : pose === 'pipipipi' ? (
          <g id="arms-pipipipi">
            <g transform={`translate(${cryTremble}, ${headBob})`}>
              <circle cx="-25" cy="-70" r="16" fill={CHAVO_COLORS.skin} stroke={CHAVO_COLORS.lineDark} strokeWidth="4.5" />
              <circle cx="25" cy="-70" r="16" fill={CHAVO_COLORS.skin} stroke={CHAVO_COLORS.lineDark} strokeWidth="4.5" />
            </g>
          </g>
        ) : (
          <g id="arms-standing">
            <path d="M -75,15 Q -100,75 -75,120" stroke={CHAVO_COLORS.skin} strokeWidth="20" strokeLinecap="round" fill="none" />
            <circle cx="-75" cy="120" r="12" fill={CHAVO_COLORS.skin} stroke={CHAVO_COLORS.lineDark} strokeWidth="4" />
            <path d="M 65,15 Q 90,75 65,120" stroke={CHAVO_COLORS.skin} strokeWidth="20" strokeLinecap="round" fill="none" />
            <circle cx="65" cy="120" r="12" fill={CHAVO_COLORS.skin} stroke={CHAVO_COLORS.lineDark} strokeWidth="4" />
          </g>
        )}

        {/* ---------------------------------------------------- */}
        {/* CABEZA, ROSTRO Y GORRO ICÓNICO DE CUADROS            */}
        {/* ---------------------------------------------------- */}
        <g id="head-group" transform={`translate(0, ${headBob})`}>

          {/* Cuello */}
          <path
            d="M -22,-35 L -22,-5 L 18,-5 L 18,-35 Z"
            fill={CHAVO_COLORS.skin}
            stroke={CHAVO_COLORS.lineDark}
            strokeWidth="5.5"
          />

          {/* OREJERA IZQUIERDA DEL GORRO */}
          <g id="hat-flap-left" transform={`rotate(${hatFlapSway}, -70, -70)`}>
            <path
              d="M -75,-100 Q -110,-35 -105,25 Q -85,75 -55,55 Q -38,20 -50,-40 Z"
              fill="url(#chavo-hat-flap-l)"
              stroke={CHAVO_COLORS.lineDark}
              strokeWidth="5.5"
              strokeLinejoin="round"
            />
          </g>

          {/* CABEZA / ROSTRO BASE (ANCHO Y REDONDEADO) */}
          <g id="face-base">
            <path
              d="M -72,-105 C -75,-50 -72,0 -52,18 C -32,35 25,35 45,18 C 65,0 68,-50 65,-105 Z"
              fill={CHAVO_COLORS.skin}
              stroke={CHAVO_COLORS.lineDark}
              strokeWidth="5.5"
              strokeLinejoin="round"
            />
          </g>

          {/* OREJERA DERECHA DEL GORRO */}
          <g id="hat-flap-right" transform={`rotate(${-hatFlapSway}, 55, -70)`}>
            <path
              d="M 50,-85 Q 58,-35 66,15 Q 72,65 52,70 Q 38,40 38,-20 Z"
              fill="url(#chavo-hat-flap-r)"
              stroke={CHAVO_COLORS.lineDark}
              strokeWidth="5.5"
              strokeLinejoin="round"
            />
          </g>

          {/* CORONA PRINCIPAL DEL GORRO DE CUADROS */}
          <g id="hat-crown">
            <path
              d="M -85,-100 C -90,-200 -40,-235 0,-235 C 40,-235 80,-200 75,-100 Z"
              fill="url(#chavo-hat-plaid)"
              stroke={CHAVO_COLORS.lineDark}
              strokeWidth="6"
              strokeLinejoin="round"
            />
            {/* Costuras curvas dividiendo los gajos */}
            <path d="M 0,-235 Q -6,-165 -10,-105" stroke={CHAVO_COLORS.hatDarkLine} strokeWidth="3" fill="none" opacity="0.75" />
            <path d="M 0,-235 Q -48,-165 -52,-115" stroke={CHAVO_COLORS.hatDarkLine} strokeWidth="3" fill="none" opacity="0.75" />
            <path d="M 0,-235 Q 42,-165 48,-115" stroke={CHAVO_COLORS.hatDarkLine} strokeWidth="3" fill="none" opacity="0.75" />
          </g>

          {/* VISERA FRONTAL DEL GORRO (UBICADA LIMPIAMENTE ARRIBA DE LOS OJOS) */}
          <g id="hat-visor">
            {/* Sombra proyectada en la frente */}
            <path
              d="M -60,-95 Q 0,-78 62,-95 Q 10,-70 -50,-85 Z"
              fill={CHAVO_COLORS.skinShadow}
              opacity="0.65"
            />

            {/* Visera acolchada que asoma al frente */}
            <path
              d="M -68,-108 Q -10,-90 68,-108 Q 80,-72 68,-65 Q 0,-72 -60,-75 Q -72,-88 -68,-108 Z"
              fill="url(#chavo-hat-plaid)"
              stroke={CHAVO_COLORS.lineDark}
              strokeWidth="5.5"
              strokeLinejoin="round"
            />

            {/* Pliegue inferior de la visera */}
            <path
              d="M -62,-75 Q 0,-72 68,-65"
              stroke={CHAVO_COLORS.lineDark}
              strokeWidth="4"
              fill="none"
              strokeLinecap="round"
            />
          </g>

          {/* -------------------------------------------------- */}
          {/* OJOS GRANDES HORIZONTALES CON MIRADA INEXPRESIVA   */}
          {/* -------------------------------------------------- */}
          <g id="chavo-eyes" transform={`translate(0, -36) scale(1, ${blinkScale})`}>

            {/* OJO IZQUIERDO */}
            <g id="eye-left" transform="translate(-25, 0)">
              {/* Esclerótica blanca */}
              <ellipse
                cx="0"
                cy="0"
                rx="27"
                ry="16"
                fill="#ffffff"
                stroke={CHAVO_COLORS.lineDark}
                strokeWidth="5.5"
              />
              {/* Pupila gigante negra horizontal */}
              <ellipse
                cx={lookX * 3.5}
                cy={lookY * 2.5}
                rx="21"
                ry="14.5"
                fill="#121214"
              />
            </g>

            {/* OJO DERECHO */}
            <g id="eye-right" transform="translate(30, 0)">
              {/* Esclerótica blanca */}
              <ellipse
                cx="0"
                cy="0"
                rx="27"
                ry="16"
                fill="#ffffff"
                stroke={CHAVO_COLORS.lineDark}
                strokeWidth="5.5"
              />
              {/* Pupila gigante negra */}
              <ellipse
                cx={lookX * 3.5}
                cy={lookY * 2.5}
                rx="21"
                ry="14.5"
                fill="#121214"
              />
            </g>
          </g>

          {/* LAGRIMAS SI ESTA LLORANDO */}
          {isCrying && (
            <g id="crying-tears">
              <ellipse cx="-25" cy={-16 + tearDropY} rx="4" ry="8" fill="#60a5fa" opacity="0.85" />
              <ellipse cx="30" cy={-16 + tearDropY} rx="4" ry="8" fill="#60a5fa" opacity="0.85" />
            </g>
          )}

          {/* BOCA / EXPRESIÓN FACIAL */}
          <g id="chavo-mouth" transform="translate(2, -2)">
            {mood === 'neutral' ? (
              /* Línea horizontal plana inexpresiva (Idéntica a la referencia) */
              <line
                x1="-14"
                y1="0"
                x2="10"
                y2="0"
                stroke={CHAVO_COLORS.lineDark}
                strokeWidth="5.5"
                strokeLinecap="round"
              />
            ) : mood === 'smile' ? (
              <path
                d="M -16,-3 Q 0,16 16,-3 Z"
                fill="#ffffff"
                stroke={CHAVO_COLORS.lineDark}
                strokeWidth="4.5"
                strokeLinejoin="round"
              />
            ) : mood === 'talk' ? (
              <ellipse
                cx="0"
                cy="2"
                rx="10"
                ry={3 + mouthOpen}
                fill="#54171f"
                stroke={CHAVO_COLORS.lineDark}
                strokeWidth="4.5"
              />
            ) : mood === 'crying' ? (
              <path
                d={`M -14,6 Q 0,-4 14,6 Q ${cryTremble},16 -14,6 Z`}
                fill="#54171f"
                stroke={CHAVO_COLORS.lineDark}
                strokeWidth="4.5"
              />
            ) : (
              <line x1="-12" y1="0" x2="8" y2="0" stroke={CHAVO_COLORS.lineDark} strokeWidth="5.5" strokeLinecap="round" />
            )}
          </g>

        </g>
      </g>
    </g>
  );
};
