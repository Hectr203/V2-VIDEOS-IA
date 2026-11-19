import { AbsoluteFill, useCurrentFrame, spring, interpolate, useVideoConfig } from 'remotion'
import { getCompositionStyles } from '@/lib/useStyle'

export const TeamIntro: React.FC<{ variant?: string }> = ({ variant = 'default' }) => {
  const frame = useCurrentFrame()
  const { fps } = useVideoConfig()
  const s = getCompositionStyles(variant)
  const isMono = s.fontFamily.includes('monospace')
  const members = [
    { name: 'Alex', role: 'CEO' },
    { name: 'Sam', role: 'CTO' },
    { name: 'Jordan', role: 'Design' },
    { name: 'Taylor', role: 'Eng' },
  ]
  const titleS = spring({ frame, fps, config: { stiffness: 200, damping: 20 } })

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: '#fff' }}>
      <h2 style={{
        fontSize: isMono ? 24 : 28, fontWeight: s.fontWeight, color: '#171717', fontFamily: s.fontFamily,
        marginBottom: 24, opacity: titleS, letterSpacing: s.letterSpacing,
        textTransform: isMono ? 'uppercase' as const : 'none' as const,
      }}>Meet the team</h2>
      <div style={{ display: 'flex', gap: 16 }}>
        {members.map((m, i) => {
          const delay = 10 + i * 8
          const sp = spring({ frame: frame - delay, fps, config: { stiffness: 200, damping: 14 } })
          return (
            <div key={i} style={{ textAlign: 'center', opacity: sp, transform: `translateY(${interpolate(sp, [0,1], [16,0])}px)` }}>
              <div style={{ width: 64, height: 64, borderRadius: 999, backgroundColor: '#f0f0f0', margin: '0 auto 8px', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 24 }}>{m.name[0]}</div>
              <div style={{ fontSize: 14, fontWeight: s.fontWeight, color: '#171717', fontFamily: s.fontFamily }}>{m.name}</div>
              <div style={{ fontSize: 11, color: '#a3a3a3', fontFamily: s.fontFamily }}>{m.role}</div>
            </div>
          )
        })}
      </div>
    </AbsoluteFill>
  )
}
