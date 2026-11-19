import { AbsoluteFill, useCurrentFrame, spring, interpolate, useVideoConfig } from 'remotion'
import { getCompositionStyles } from '@/lib/useStyle'

export const LaunchDay: React.FC<{ title?: string; subtitle?: string; buttonText?: string; textColor?: string; bgColor?: string; variant?: string }> = ({
  title = 'We just launched!', subtitle = 'The fastest way to ship animated videos. Built for developers.', buttonText = 'Try it free', textColor = '#171717', bgColor = '#ffffff', variant = 'default',
}) => {
  const frame = useCurrentFrame()
  const { fps } = useVideoConfig()
  const s = getCompositionStyles(variant)

  const emojiS = spring({ frame, fps, config: { stiffness: 300, damping: 10 } })
  const titleS = spring({ frame: frame - 8, fps, config: { stiffness: 180, damping: 16 } })
  const subS = spring({ frame: frame - 16, fps, config: { stiffness: 160, damping: 18 } })
  const btnS = spring({ frame: frame - 24, fps, config: { stiffness: 200, damping: 14 } })

  const isDark = bgColor === '#000000' || bgColor === '#171717' || bgColor === '#0a0a0a'
  const textBase = isDark ? '#fff' : textColor

  // Pulsing glow behind button
  const pulseScale = frame > 30 ? 1 + 0.03 * Math.sin((frame - 30) * 0.15) : 1

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: bgColor }}>
      <div style={{ textAlign: 'center', maxWidth: 700 }}>
        {/* Rocket emoji */}
        <div style={{
          fontSize: 80, marginBottom: 24,
          transform: `scale(${emojiS}) translateY(${interpolate(emojiS, [0, 1], [20, 0])}px)`,
        }}>{'\uD83D\uDE80'}</div>

        {/* Title */}
        <h1 style={{
          fontSize: 56, fontWeight: 800, color: textBase, fontFamily: s.fontFamily,
          letterSpacing: '-0.03em', lineHeight: 1.1, marginBottom: 16,
          opacity: titleS, transform: `translateY(${interpolate(titleS, [0, 1], [16, 0])}px)`,
        }}>
          {title}
        </h1>

        {/* Subtitle */}
        <p style={{
          fontSize: 22, color: isDark ? '#a3a3a3' : '#737373', fontFamily: s.fontFamily,
          lineHeight: 1.5, marginBottom: 36, maxWidth: 520, margin: '0 auto 36px',
          opacity: subS, transform: `translateY(${interpolate(subS, [0, 1], [12, 0])}px)`,
        }}>
          {subtitle}
        </p>

        {/* CTA button */}
        <div style={{
          display: 'inline-block',
          backgroundColor: textColor, color: isDark ? '#000' : '#fff',
          padding: '16px 40px', borderRadius: 999,
          fontSize: 18, fontWeight: 700, fontFamily: s.fontFamily,
          opacity: btnS, transform: `scale(${btnS * pulseScale})`,
          boxShadow: `0 4px 20px ${textColor}40`,
        }}>
          {buttonText}
        </div>
      </div>
    </AbsoluteFill>
  )
}
