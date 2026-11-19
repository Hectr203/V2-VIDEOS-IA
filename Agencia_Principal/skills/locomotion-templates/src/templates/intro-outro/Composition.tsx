import { AbsoluteFill, useCurrentFrame, spring, interpolate, useVideoConfig } from 'remotion'
import { getCompositionStyles } from '@/lib/useStyle'

export const IntroOutro: React.FC<{ text?: string; variant?: string }> = ({ text = 'Thanks for watching', variant = 'default' }) => {
  const frame = useCurrentFrame()
  const { fps } = useVideoConfig()
  const s = getCompositionStyles(variant)
  const isMono = s.fontFamily.includes('monospace')
  const totalFrames = 90

  // Line draws in
  const lineWidth = interpolate(frame, [0, 20], [0, 200], { extrapolateRight: 'clamp' })
  const textS = spring({ frame: frame - 8, fps, config: { stiffness: 180, damping: 18 } })
  const subtitleS = spring({ frame: frame - 18, fps, config: { stiffness: 200, damping: 20 } })

  // Fade out at end
  const fadeOut = interpolate(frame, [totalFrames - 15, totalFrames], [1, 0], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' })

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: '#171717', opacity: fadeOut }}>
      <div style={{ textAlign: 'center' }}>
        {/* Decorative line */}
        <div style={{
          width: lineWidth, height: 2, backgroundColor: '#525252',
          margin: '0 auto 20px', borderRadius: 1,
        }} />

        <h1 style={{
          fontSize: isMono ? 34 : 40, fontWeight: s.fontWeight, color: '#fff', fontFamily: s.fontFamily,
          opacity: textS, transform: `translateY(${interpolate(textS, [0, 1], [12, 0])}px)`,
          letterSpacing: s.letterSpacing,
          textTransform: isMono ? 'uppercase' as const : 'none' as const,
        }}>{text}</h1>

        <p style={{
          fontSize: 16, color: '#737373', marginTop: 8, fontFamily: s.fontFamily,
          opacity: subtitleS,
        }}>Subscribe for more</p>

        {/* Bottom line */}
        <div style={{
          width: interpolate(frame, [15, 30], [0, 120], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' }),
          height: 2, backgroundColor: '#525252',
          margin: '20px auto 0', borderRadius: 1,
        }} />
      </div>
    </AbsoluteFill>
  )
}
