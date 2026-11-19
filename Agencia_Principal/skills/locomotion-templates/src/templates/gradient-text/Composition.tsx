import { AbsoluteFill, useCurrentFrame, interpolate, useVideoConfig } from 'remotion'
import { getCompositionStyles } from '@/lib/useStyle'

export const GradientText: React.FC<{ text?: string; bgColor?: string; variant?: string }> = ({
  text = 'Captivating', bgColor = '#000000', variant = 'default',
}) => {
  const frame = useCurrentFrame()
  const { fps } = useVideoConfig()
  const s = getCompositionStyles(variant)

  // Text scales in from 0.85 to 1
  const scaleProgress = interpolate(frame, [0, 20], [0.85, 1], { extrapolateRight: 'clamp' })
  const opacityProgress = interpolate(frame, [0, 15], [0, 1], { extrapolateRight: 'clamp' })

  // Gradient sweep moves from left to right across the text
  const gradientPos = interpolate(frame, [5, fps * 2], [-100, 200], { extrapolateRight: 'clamp' })

  // Determine if bg is dark to pick fallback text color
  const isDark = bgColor === '#000000' || bgColor === '#171717' || bgColor === '#0a0a0a' ||
    (bgColor.startsWith('#') && parseInt(bgColor.slice(1, 3), 16) < 80)

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: bgColor }}>
      <div style={{
        fontSize: 120,
        fontWeight: 800,
        fontFamily: s.fontFamily,
        letterSpacing: '-0.04em',
        opacity: opacityProgress,
        transform: `scale(${scaleProgress})`,
        background: `linear-gradient(90deg, #9333EA ${gradientPos - 60}%, #EC4899 ${gradientPos - 20}%, #F59E0B ${gradientPos + 20}%, ${isDark ? '#fff' : '#171717'} ${gradientPos + 60}%)`,
        WebkitBackgroundClip: 'text',
        WebkitTextFillColor: 'transparent',
        backgroundClip: 'text',
        lineHeight: 1.1,
        textAlign: 'center',
        maxWidth: '80%',
      }}>
        {text}
      </div>
    </AbsoluteFill>
  )
}
