import { AbsoluteFill, useCurrentFrame, interpolate } from 'remotion'
import { getCompositionStyles } from '@/lib/useStyle'

export const FadeSlideUp: React.FC<{ text?: string; textColor?: string; bgColor?: string; variant?: string }> = ({
  text = 'Hello World', textColor = '#171717', bgColor = '#ffffff', variant = 'default',
}) => {
  const frame = useCurrentFrame()
  const s = getCompositionStyles(variant)
  const opacity = interpolate(frame, [0, 20], [0, 1], { extrapolateRight: 'clamp' })
  const translateY = interpolate(frame, [0, 20], [20, 0], { extrapolateRight: 'clamp' })

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: bgColor }}>
      <h1 style={{
        fontSize: 72, fontWeight: s.fontWeight, color: textColor, opacity,
        transform: `translateY(${translateY}px)`, fontFamily: s.fontFamily,
        letterSpacing: s.letterSpacing,
      }}>{text}</h1>
    </AbsoluteFill>
  )
}
