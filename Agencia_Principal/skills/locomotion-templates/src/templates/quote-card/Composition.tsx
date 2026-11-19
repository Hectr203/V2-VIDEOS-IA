import { AbsoluteFill, useCurrentFrame, spring, interpolate, useVideoConfig } from 'remotion'
import { getCompositionStyles } from '@/lib/useStyle'

export const QuoteCard: React.FC<{ text?: string; variant?: string }> = ({
  text = 'This changed everything for our team.', variant = 'default',
}) => {
  const frame = useCurrentFrame()
  const { fps } = useVideoConfig()
  const s = getCompositionStyles(variant)
  const isMono = s.fontFamily.includes('monospace')

  const cardS = spring({ frame, fps, config: { stiffness: 180, damping: 18 } })
  const quoteS = spring({ frame: frame - 10, fps, config: { stiffness: 200, damping: 20 } })
  const authorS = spring({ frame: frame - 25, fps, config: { stiffness: 200, damping: 20 } })

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: '#fafafa' }}>
      <div style={{
        width: 480, backgroundColor: '#fff', padding: 36,
        borderRadius: s.borderRadius,
        border: `${s.borderWidth}px solid ${s.borderColor}`,
        boxShadow: s.shadow,
        opacity: cardS,
        transform: `translateY(${interpolate(cardS, [0, 1], [16, 0])}px)`,
      }}>
        <div style={{
          fontSize: 48, color: isMono ? '#171717' : '#e5e5e5',
          fontFamily: isMono ? s.fontFamily : 'Georgia, serif',
          lineHeight: 0.5, marginBottom: 16,
          fontWeight: s.fontWeight,
        }}>"</div>
        <p style={{
          fontSize: isMono ? 18 : 22,
          fontWeight: s.fontWeight, color: '#171717', lineHeight: 1.5,
          fontFamily: s.fontFamily, opacity: quoteS,
          transform: `translateY(${interpolate(quoteS, [0, 1], [8, 0])}px)`,
          letterSpacing: s.letterSpacing,
        }}>{text}</p>
        <div style={{
          marginTop: 20, display: 'flex', alignItems: 'center', gap: 10, opacity: authorS,
        }}>
          <div style={{
            width: 32, height: 32,
            borderRadius: s.borderRadius > 16 ? 999 : s.borderRadius / 3,
            backgroundColor: '#e5e5e5',
            border: s.borderWidth > 1 ? `${s.borderWidth}px solid ${s.borderColor}` : 'none',
          }} />
          <div>
            <div style={{
              fontSize: 13, fontWeight: s.fontWeight, color: '#171717',
              fontFamily: s.fontFamily, letterSpacing: s.letterSpacing,
              textTransform: isMono ? 'uppercase' as const : 'none' as const,
            }}>Sarah Chen</div>
            <div style={{
              fontSize: 11, color: '#a3a3a3', fontFamily: s.fontFamily,
              letterSpacing: s.letterSpacing,
            }}>CEO, Acme Inc.</div>
          </div>
        </div>
      </div>
    </AbsoluteFill>
  )
}
