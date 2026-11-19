import { AbsoluteFill, useCurrentFrame, spring, interpolate, useVideoConfig, Img } from 'remotion'
import { getCompositionStyles } from '@/lib/useStyle'

export const LogoReveal: React.FC<{ text?: string; logoUrl?: string; variant?: string }> = ({
  text = 'Acme',
  logoUrl,
  variant = 'default',
}) => {
  const frame = useCurrentFrame()
  const { fps } = useVideoConfig()
  const s = getCompositionStyles(variant)
  const isMono = s.fontFamily.includes('monospace')

  const ringScale = spring({ frame, fps, config: { stiffness: 120, damping: 14 } })
  const logoScale = spring({ frame: frame - 8, fps, config: { stiffness: 200, damping: 16 } })
  const textOpacity = spring({ frame: frame - 18, fps, config: { stiffness: 200, damping: 20 } })
  const ringOpacity = interpolate(frame, [20, 30], [0.15, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  })

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: '#fff' }}>
      {/* Expanding ring */}
      <div
        style={{
          position: 'absolute',
          width: 200,
          height: 200,
          borderRadius: 999,
          border: '3px solid #171717',
          transform: `scale(${ringScale * 1.8})`,
          opacity: ringOpacity,
        }}
      />

      {/* Logo */}
      <div
        style={{
          width: 72,
          height: 72,
          borderRadius: s.borderRadius,
          backgroundColor: logoUrl ? 'transparent' : '#171717',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          transform: `scale(${logoScale})`,
          marginBottom: 12,
          overflow: 'hidden',
        }}
      >
        {logoUrl ? (
          <Img
            src={logoUrl}
            style={{ width: 64, height: 64, objectFit: 'contain' }}
          />
        ) : (
          <span style={{ color: '#fff', fontSize: 28, fontWeight: 800, fontFamily: s.fontFamily }}>
            {text.charAt(0)}
          </span>
        )}
      </div>

      {/* Brand name */}
      <div
        style={{
          fontSize: isMono ? 30 : 36,
          fontWeight: s.fontWeight,
          color: '#171717',
          fontFamily: s.fontFamily,
          opacity: textOpacity,
          transform: `translateY(${interpolate(textOpacity, [0, 1], [8, 0])}px)`,
          letterSpacing: s.letterSpacing,
          textTransform: isMono ? 'uppercase' as const : 'none' as const,
        }}
      >
        {text}
      </div>
    </AbsoluteFill>
  )
}
