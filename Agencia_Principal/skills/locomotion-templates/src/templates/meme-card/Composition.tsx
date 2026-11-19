import { AbsoluteFill, useCurrentFrame, spring, interpolate, useVideoConfig } from 'remotion'
import { getCompositionStyles } from '@/lib/useStyle'

export const MemeCard: React.FC<{ topText?: string; bottomText?: string; emoji?: string; bgColor?: string; variant?: string }> = ({
  topText = 'When the deploy works', bottomText = 'on the first try', emoji = '\uD83D\uDE0E', bgColor = '#171717', variant = 'default',
}) => {
  const frame = useCurrentFrame()
  const { fps } = useVideoConfig()
  const s = getCompositionStyles(variant)

  const topS = spring({ frame: frame - 3, fps, config: { stiffness: 200, damping: 14 } })
  const emojiS = spring({ frame: frame - 12, fps, config: { stiffness: 300, damping: 10 } })
  const bottomS = spring({ frame: frame - 22, fps, config: { stiffness: 180, damping: 16 } })

  // Subtle shake on the emoji
  const shake = frame > 15 && frame < 40 ? Math.sin(frame * 0.8) * 3 : 0

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: bgColor }}>
      <div style={{ textAlign: 'center', maxWidth: 700 }}>
        {/* Top text */}
        <div style={{
          fontSize: 52, fontWeight: 800, color: '#fff', fontFamily: s.fontFamily,
          letterSpacing: '-0.02em', lineHeight: 1.2, marginBottom: 32,
          opacity: topS, transform: `translateY(${interpolate(topS, [0, 1], [-16, 0])}px)`,
          textTransform: 'uppercase',
        }}>
          {topText}
        </div>

        {/* Emoji */}
        <div style={{
          fontSize: 120, marginBottom: 32,
          transform: `scale(${emojiS}) rotate(${shake}deg)`,
        }}>
          {emoji}
        </div>

        {/* Bottom text */}
        <div style={{
          fontSize: 52, fontWeight: 800, color: '#fff', fontFamily: s.fontFamily,
          letterSpacing: '-0.02em', lineHeight: 1.2,
          opacity: bottomS, transform: `translateY(${interpolate(bottomS, [0, 1], [16, 0])}px)`,
          textTransform: 'uppercase',
        }}>
          {bottomText}
        </div>
      </div>
    </AbsoluteFill>
  )
}
