import { AbsoluteFill, useCurrentFrame, spring, interpolate, useVideoConfig } from 'remotion'
import { getCompositionStyles } from '@/lib/useStyle'

export const ConceptBreakdown: React.FC<{ title?: string; variant?: string }> = ({ title = 'What is AI?', variant = 'default' }) => {
  const frame = useCurrentFrame()
  const { fps } = useVideoConfig()
  const s = getCompositionStyles(variant)
  const isMono = s.fontFamily.includes('monospace')

  const titleS = spring({ frame, fps, config: { stiffness: 160, damping: 18 } })
  const bulletDelay = [20, 35, 50]
  const bullets = ['Machines that learn from data', 'Automates complex decisions', 'Powers modern applications']

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: '#fafafa' }}>
      <div style={{ width: 520 }}>
        <div style={{
          fontSize: 14, fontWeight: s.fontWeight, color: '#a3a3a3', textTransform: 'uppercase',
          letterSpacing: '0.08em', marginBottom: 8, opacity: titleS, fontFamily: s.fontFamily,
        }}>Explained</div>
        <h1 style={{
          fontSize: isMono ? 40 : 48, fontWeight: 800, color: '#171717', marginBottom: 28,
          opacity: titleS, transform: `translateY(${interpolate(titleS, [0, 1], [12, 0])}px)`,
          fontFamily: s.fontFamily, letterSpacing: s.letterSpacing,
          textTransform: isMono ? 'uppercase' as const : 'none' as const,
        }}>{title}</h1>

        {bullets.map((b, i) => {
          const sp = spring({ frame: frame - bulletDelay[i], fps, config: { stiffness: 200, damping: 16 } })
          return (
            <div key={i} style={{
              display: 'flex', alignItems: 'center', gap: 12, padding: '10px 0',
              opacity: sp, transform: `translateY(${interpolate(sp, [0, 1], [8, 0])}px)`,
            }}>
              <div style={{
                width: 8, height: 8, borderRadius: 999, backgroundColor: '#171717', flexShrink: 0,
              }} />
              <span style={{ fontSize: isMono ? 15 : 18, color: '#525252', fontFamily: s.fontFamily, letterSpacing: s.letterSpacing }}>{b}</span>
            </div>
          )
        })}
      </div>
    </AbsoluteFill>
  )
}
