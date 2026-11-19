import { AbsoluteFill, useCurrentFrame, spring, interpolate, useVideoConfig } from 'remotion'
import { getCompositionStyles } from '@/lib/useStyle'

export const ProductHunt: React.FC<{ rank?: string; upvotes?: string; thankYouText?: string; textColor?: string; bgColor?: string; variant?: string }> = ({
  rank = '#1', upvotes = '1,500', thankYouText = 'Thank you for support', textColor = '#FF6154', bgColor = '#ffffff', variant = 'default',
}) => {
  const frame = useCurrentFrame()
  const { fps } = useVideoConfig()
  const s = getCompositionStyles(variant)

  const cardS = spring({ frame, fps, config: { stiffness: 180, damping: 16 } })
  const laurelS = spring({ frame: frame - 10, fps, config: { stiffness: 200, damping: 14 } })
  const rankS = spring({ frame: frame - 18, fps, config: { stiffness: 250, damping: 12 } })
  const upvoteS = spring({ frame: frame - 8, fps, config: { stiffness: 200, damping: 15 } })
  const textS = spring({ frame: frame - 35, fps, config: { stiffness: 180, damping: 18 } })

  // Rolling upvote count
  const upvoteNum = parseInt(upvotes.replace(/,/g, ''), 10) || 0
  const animatedUpvotes = Math.round(interpolate(upvoteS, [0, 1], [0, upvoteNum]))

  const isDark = bgColor === '#000000' || bgColor === '#171717' || bgColor === '#0a0a0a'
  const textBase = isDark ? '#fff' : '#171717'
  const textMuted = isDark ? '#a3a3a3' : '#737373'

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: bgColor }}>
      <div style={{
        textAlign: 'center', opacity: cardS,
        transform: `scale(${interpolate(cardS, [0, 1], [0.9, 1])})`,
      }}>
        {/* Upvote button */}
        <div style={{
          display: 'inline-flex', alignItems: 'center', gap: 10,
          backgroundColor: textColor, color: '#fff',
          padding: '12px 28px', borderRadius: 10, fontSize: 18, fontWeight: 700,
          fontFamily: s.fontFamily, marginBottom: 36,
          transform: `scale(${upvoteS})`,
        }}>
          <span style={{ fontSize: 16 }}>{'\u25B2'}</span>
          UPVOTE {animatedUpvotes.toLocaleString()}
        </div>

        {/* Product of the day title */}
        <div style={{ position: 'relative', marginBottom: 20 }}>
          {/* Laurel wreath left */}
          <span style={{
            position: 'absolute', left: -60, top: '50%', fontSize: 64,
            transform: `translateY(-50%) scale(${laurelS})`, opacity: laurelS,
          }}>{'\uD83C\uDF3F'}</span>

          <div>
            <div style={{
              fontSize: 36, fontWeight: 700, color: textBase, fontFamily: s.fontFamily,
              letterSpacing: s.letterSpacing, lineHeight: 1.2,
            }}>
              Product of the day
            </div>
            <div style={{
              fontSize: 72, fontWeight: 800, color: textBase, fontFamily: s.fontFamily,
              opacity: rankS, transform: `scale(${rankS})`,
            }}>
              {rank}
            </div>
          </div>

          {/* Laurel wreath right */}
          <span style={{
            position: 'absolute', right: -60, top: '50%', fontSize: 64,
            transform: `translateY(-50%) scaleX(-1) scale(${laurelS})`, opacity: laurelS,
          }}>{'\uD83C\uDF3F'}</span>
        </div>

        {/* Celebration emoji */}
        <div style={{
          fontSize: 64, marginBottom: 16,
          opacity: rankS, transform: `scale(${interpolate(rankS, [0, 1], [0.5, 1])})`,
        }}>{'\uD83C\uDF89'}</div>

        {/* Thank you text */}
        <div style={{
          fontSize: 28, fontWeight: 700, color: textBase, fontFamily: s.fontFamily,
          opacity: textS, transform: `translateY(${interpolate(textS, [0, 1], [12, 0])}px)`,
        }}>
          {thankYouText} {'\uD83D\uDE4F'}
        </div>
      </div>
    </AbsoluteFill>
  )
}
