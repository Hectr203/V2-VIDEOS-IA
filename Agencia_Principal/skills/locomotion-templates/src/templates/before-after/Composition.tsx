import { AbsoluteFill, useCurrentFrame, spring, interpolate, useVideoConfig } from 'remotion'
import { getCompositionStyles } from '@/lib/useStyle'

export const BeforeAfter: React.FC<{ beforeTitle?: string; afterTitle?: string; beforeItems?: string; afterItems?: string; textColor?: string; bgColor?: string; variant?: string }> = ({
  beforeTitle = 'Before', afterTitle = 'After',
  beforeItems = 'Manual deploys,No monitoring,Slow feedback', afterItems = 'Auto CI/CD,Real-time alerts,Ship in minutes',
  textColor = '#171717', bgColor = '#ffffff', variant = 'default',
}) => {
  const frame = useCurrentFrame()
  const { fps } = useVideoConfig()
  const s = getCompositionStyles(variant)

  const isDark = bgColor === '#000000' || bgColor === '#171717' || bgColor === '#0a0a0a'
  const textBase = isDark ? '#fff' : textColor

  const beforeList = beforeItems.split(',').map((i) => i.trim()).filter(Boolean)
  const afterList = afterItems.split(',').map((i) => i.trim()).filter(Boolean)

  // Before card enters first
  const beforeS = spring({ frame: frame - 3, fps, config: { stiffness: 180, damping: 16 } })
  // After card enters with delay
  const afterS = spring({ frame: frame - 20, fps, config: { stiffness: 180, damping: 16 } })
  // Arrow between them
  const arrowS = spring({ frame: frame - 15, fps, config: { stiffness: 200, damping: 14 } })

  const cardStyle = (bg: string, border: string): React.CSSProperties => ({
    width: 300, padding: 32, borderRadius: s.borderRadius,
    backgroundColor: bg,
    border: `${s.borderWidth}px solid ${border}`,
    boxShadow: s.shadow,
  })

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: bgColor }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 24 }}>
        {/* Before */}
        <div style={{
          ...cardStyle(isDark ? '#1a1a1a' : '#fff', isDark ? '#333' : '#e5e5e5'),
          opacity: beforeS, transform: `translateX(${interpolate(beforeS, [0, 1], [-20, 0])}px)`,
        }}>
          <div style={{
            fontSize: 12, fontWeight: 600, color: '#EF4444',
            textTransform: 'uppercase', letterSpacing: '0.08em', marginBottom: 16,
            fontFamily: s.fontFamily,
          }}>{beforeTitle}</div>
          {beforeList.map((item, i) => {
            const delay = 8 + i * 6
            const itemS = spring({ frame: frame - delay, fps, config: { stiffness: 180, damping: 16 } })
            return (
              <div key={i} style={{
                display: 'flex', alignItems: 'center', gap: 10, padding: '10px 0',
                opacity: itemS, transform: `translateX(${interpolate(itemS, [0, 1], [-10, 0])}px)`,
              }}>
                <span style={{ color: '#EF4444', fontSize: 16 }}>{'\u2717'}</span>
                <span style={{ fontSize: 16, color: isDark ? '#a3a3a3' : '#737373', fontFamily: s.fontFamily }}>{item}</span>
              </div>
            )
          })}
        </div>

        {/* Arrow */}
        <div style={{
          fontSize: 32, color: textBase, opacity: arrowS,
          transform: `scale(${arrowS})`,
        }}>{'\u2192'}</div>

        {/* After */}
        <div style={{
          ...cardStyle(isDark ? '#1a1a1a' : '#fff', isDark ? '#333' : s.borderColor),
          opacity: afterS, transform: `translateX(${interpolate(afterS, [0, 1], [20, 0])}px)`,
          border: `${s.borderWidth + 1}px solid ${textColor}`,
        }}>
          <div style={{
            fontSize: 12, fontWeight: 600, color: textColor,
            textTransform: 'uppercase', letterSpacing: '0.08em', marginBottom: 16,
            fontFamily: s.fontFamily,
          }}>{afterTitle}</div>
          {afterList.map((item, i) => {
            const delay = 24 + i * 6
            const itemS = spring({ frame: frame - delay, fps, config: { stiffness: 180, damping: 16 } })
            return (
              <div key={i} style={{
                display: 'flex', alignItems: 'center', gap: 10, padding: '10px 0',
                opacity: itemS, transform: `translateX(${interpolate(itemS, [0, 1], [10, 0])}px)`,
              }}>
                <span style={{ color: textColor, fontSize: 16 }}>{'\u2713'}</span>
                <span style={{ fontSize: 16, color: textBase, fontWeight: 500, fontFamily: s.fontFamily }}>{item}</span>
              </div>
            )
          })}
        </div>
      </div>
    </AbsoluteFill>
  )
}
