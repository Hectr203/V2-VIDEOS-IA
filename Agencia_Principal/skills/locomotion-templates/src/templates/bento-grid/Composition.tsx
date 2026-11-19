import { AbsoluteFill, useCurrentFrame, spring, interpolate, useVideoConfig } from 'remotion'
import { getCompositionStyles } from '@/lib/useStyle'

export const BentoGrid: React.FC<{ items?: string; textColor?: string; bgColor?: string; variant?: string }> = ({
  items = 'Analytics,Fast API,99.9% Uptime,Global CDN,Auth,Webhooks', textColor = '#171717', bgColor = '#fafafa', variant = 'default',
}) => {
  const frame = useCurrentFrame()
  const { fps } = useVideoConfig()
  const s = getCompositionStyles(variant)

  const itemList = items.split(',').map((item) => item.trim()).filter(Boolean)
  const isDark = bgColor === '#000000' || bgColor === '#171717' || bgColor === '#0a0a0a'
  const cardBg = isDark ? '#1a1a1a' : '#fff'
  const borderCol = isDark ? '#333' : s.borderColor

  // Layout: 2 columns, items in a bento pattern
  // Row 1: wide + narrow, Row 2: narrow + wide, Row 3: two equal
  const layout = [
    { col: '1 / 3', row: '1 / 2' },  // wide top
    { col: '3 / 4', row: '1 / 2' },  // narrow top-right
    { col: '1 / 2', row: '2 / 3' },  // narrow mid-left
    { col: '2 / 4', row: '2 / 3' },  // wide mid
    { col: '1 / 2', row: '3 / 4' },  // bottom-left
    { col: '2 / 4', row: '3 / 4' },  // bottom-right wide
  ]

  const emojis = ['\uD83D\uDCCA', '\u26A1', '\uD83D\uDD12', '\uD83C\uDF0D', '\uD83D\uDD11', '\uD83D\uDD17']

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: bgColor }}>
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(3, 200px)',
        gridTemplateRows: 'repeat(3, 130px)',
        gap: 14,
      }}>
        {itemList.slice(0, 6).map((item, i) => {
          const delay = 3 + i * 6
          const itemS = spring({ frame: frame - delay, fps, config: { stiffness: 200, damping: 14 } })
          const pos = layout[i] ?? { col: 'auto', row: 'auto' }

          return (
            <div key={i} style={{
              gridColumn: pos.col, gridRow: pos.row,
              backgroundColor: cardBg, borderRadius: s.borderRadius,
              border: `${s.borderWidth}px solid ${borderCol}`,
              boxShadow: s.shadow,
              padding: 24, display: 'flex', flexDirection: 'column', justifyContent: 'center',
              opacity: itemS, transform: `scale(${interpolate(itemS, [0, 1], [0.85, 1])})`,
            }}>
              <div style={{ fontSize: 32, marginBottom: 10 }}>{emojis[i] ?? '\u2728'}</div>
              <div style={{
                fontSize: 17, fontWeight: 700, color: isDark ? '#fff' : textColor,
                fontFamily: s.fontFamily, letterSpacing: s.letterSpacing,
              }}>{item}</div>
            </div>
          )
        })}
      </div>
    </AbsoluteFill>
  )
}
