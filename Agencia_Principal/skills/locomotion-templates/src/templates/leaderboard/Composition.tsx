import { AbsoluteFill, useCurrentFrame, spring, interpolate, useVideoConfig } from 'remotion'
import { getCompositionStyles } from '@/lib/useStyle'

export const Leaderboard: React.FC<{ variant?: string }> = ({ variant = 'default' }) => {
  const frame = useCurrentFrame()
  const { fps } = useVideoConfig()
  const s = getCompositionStyles(variant)
  const isMono = s.fontFamily.includes('monospace')
  const players = [
    { name: 'xNova', score: 12450, medal: '\uD83E\uDD47' },
    { name: 'BlazeFX', score: 11200, medal: '\uD83E\uDD48' },
    { name: 'SkyPilot', score: 9800, medal: '\uD83E\uDD49' },
    { name: 'RocketJ', score: 8650, medal: '' },
    { name: 'ZenMaster', score: 7400, medal: '' },
  ]

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: '#0a0a0a' }}>
      <div style={{ width: 360 }}>
        <h3 style={{
          fontSize: isMono ? 17 : 20, fontWeight: s.fontWeight, color: '#fff', fontFamily: s.fontFamily,
          marginBottom: 16, opacity: spring({ frame, fps, config: { stiffness: 200, damping: 20 } }),
          letterSpacing: s.letterSpacing,
          textTransform: isMono ? 'uppercase' as const : 'none' as const,
        }}>Leaderboard</h3>
        {players.map((p, i) => {
          const delay = 6 + i * 8
          const sp = spring({ frame: frame - delay, fps, config: { stiffness: 200, damping: 16 } })
          const count = Math.round(interpolate(sp, [0, 1], [0, p.score]))
          return (
            <div key={i} style={{ display: 'flex', alignItems: 'center', padding: '8px 0', borderBottom: '1px solid #1a1a1a', opacity: sp, transform: `translateX(${interpolate(sp, [0,1], [-20,0])}px)` }}>
              <span style={{ width: 24, fontSize: 13, fontWeight: 700, color: '#525252', fontFamily: s.fontFamily }}>{i + 1}</span>
              <span style={{ fontSize: 16, marginRight: 6 }}>{p.medal}</span>
              <span style={{ flex: 1, fontSize: 14, fontWeight: s.fontWeight, color: '#fff', fontFamily: s.fontFamily }}>{p.name}</span>
              <span style={{ fontSize: 14, fontWeight: 700, color: '#a3a3a3', fontFamily: s.fontFamily }}>{count.toLocaleString()}</span>
            </div>
          )
        })}
      </div>
    </AbsoluteFill>
  )
}
