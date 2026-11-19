import { AbsoluteFill, useCurrentFrame, spring, interpolate, useVideoConfig } from 'remotion'
import { getCompositionStyles } from '@/lib/useStyle'

export const BarChartReveal: React.FC<{ variant?: string }> = ({ variant = 'default' }) => {
  const frame = useCurrentFrame()
  const { fps } = useVideoConfig()
  const s = getCompositionStyles(variant)
  const isMono = s.fontFamily.includes('monospace')

  const titleS = spring({ frame, fps, config: { stiffness: 200, damping: 20 } })
  const bars = [
    { label: 'Q1', value: 65, color: '#d4d4d4' },
    { label: 'Q2', value: 78, color: '#a3a3a3' },
    { label: 'Q3', value: 92, color: '#525252' },
    { label: 'Q4', value: 100, color: '#171717' },
  ]

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: '#fff' }}>
      <div style={{ width: 480 }}>
        <h2 style={{
          fontSize: isMono ? 24 : 28, fontWeight: s.fontWeight, color: '#171717', marginBottom: 32,
          opacity: titleS, fontFamily: s.fontFamily, letterSpacing: s.letterSpacing,
          textTransform: isMono ? 'uppercase' as const : 'none' as const,
        }}>Revenue Growth</h2>

        <div style={{ display: 'flex', alignItems: 'flex-end', gap: 20, height: 200 }}>
          {bars.map((bar, i) => {
            const delay = 10 + i * 8
            const sp = spring({ frame: frame - delay, fps, config: { stiffness: 150, damping: 14 } })
            const height = interpolate(sp, [0, 1], [0, bar.value * 1.8])

            return (
              <div key={i} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8 }}>
                <div style={{
                  fontSize: 14, fontWeight: s.fontWeight, color: '#171717', fontFamily: s.fontFamily,
                  opacity: sp,
                }}>{bar.value}%</div>
                <div style={{
                  width: '100%', height, backgroundColor: bar.color, borderRadius: '6px 6px 0 0',
                }} />
                <div style={{
                  fontSize: 13, color: '#a3a3a3', fontFamily: s.fontFamily,
                  opacity: sp,
                }}>{bar.label}</div>
              </div>
            )
          })}
        </div>
      </div>
    </AbsoluteFill>
  )
}
