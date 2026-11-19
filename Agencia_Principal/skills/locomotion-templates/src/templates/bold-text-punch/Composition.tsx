import { AbsoluteFill, useCurrentFrame, spring, interpolate, useVideoConfig } from 'remotion'
import { getCompositionStyles } from '@/lib/useStyle'

export const BoldTextPunch: React.FC<{ text?: string; textColor?: string; bgColor?: string; variant?: string }> = ({
  text = 'Stop scrolling.',
  textColor = '#ffffff',
  bgColor = '#171717',
  variant = 'default',
}) => {
  const frame = useCurrentFrame()
  const { fps } = useVideoConfig()
  const s = getCompositionStyles(variant)
  const isMono = s.fontFamily.includes('monospace')
  const scale = spring({ frame, fps, config: { stiffness: 300, damping: 10 } })
  const opacity = interpolate(frame, [0, 8], [0, 1], { extrapolateRight: 'clamp' })
  const shake = frame > 5 && frame < 12 ? Math.sin(frame * 3) * 2 * (1 - (frame - 5) / 7) : 0

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: bgColor }}>
      <h1 style={{
        fontSize: isMono ? 68 : 80, fontWeight: 800, color: textColor, opacity,
        transform: `scale(${scale}) translateX(${shake}px)`,
        fontFamily: s.fontFamily, letterSpacing: s.letterSpacing,
        textAlign: 'center', lineHeight: 1.1, maxWidth: '80%',
        textTransform: isMono ? 'uppercase' as const : 'none' as const,
      }}>
        {text}
      </h1>
    </AbsoluteFill>
  )
}
