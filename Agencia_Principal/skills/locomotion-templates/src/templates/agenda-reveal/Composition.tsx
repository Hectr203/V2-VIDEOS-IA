import { AbsoluteFill, useCurrentFrame, spring, interpolate, useVideoConfig } from 'remotion'
import { getCompositionStyles } from '@/lib/useStyle'

export const AgendaReveal: React.FC<{ text?: string; variant?: string }> = ({ text = 'Today\'s Agenda', variant = 'default' }) => {
  const frame = useCurrentFrame()
  const { fps } = useVideoConfig()
  const s = getCompositionStyles(variant)
  const isMono = s.fontFamily.includes('monospace')
  const titleS = spring({ frame, fps, config: { stiffness: 200, damping: 20 } })
  const items = [
    { time: '10:00', topic: 'Opening keynote' },
    { time: '11:30', topic: 'Panel discussion' },
    { time: '14:00', topic: 'Workshops' },
    { time: '16:00', topic: 'Networking' },
  ]

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: '#fff' }}>
      <div style={{ width: 400 }}>
        <h2 style={{
          fontSize: isMono ? 24 : 28, fontWeight: s.fontWeight, color: '#171717', fontFamily: s.fontFamily,
          marginBottom: 20, opacity: titleS, letterSpacing: s.letterSpacing,
          textTransform: isMono ? 'uppercase' as const : 'none' as const,
        }}>{text}</h2>
        {items.map((item, i) => {
          const delay = 10 + i * 10
          const sp = spring({ frame: frame - delay, fps, config: { stiffness: 200, damping: 16 } })
          return (
            <div key={i} style={{ display: 'flex', gap: 14, padding: '10px 0', borderBottom: '1px solid #f0f0f0', opacity: sp, transform: `translateX(${interpolate(sp, [0,1], [-16,0])}px)` }}>
              <span style={{ fontSize: 13, fontWeight: 600, color: '#a3a3a3', fontFamily: s.fontFamily, width: 50, flexShrink: 0 }}>{item.time}</span>
              <span style={{ fontSize: 15, fontWeight: 500, color: '#171717', fontFamily: s.fontFamily }}>{item.topic}</span>
            </div>
          )
        })}
      </div>
    </AbsoluteFill>
  )
}
