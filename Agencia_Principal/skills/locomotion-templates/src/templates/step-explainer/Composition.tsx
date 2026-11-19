import { AbsoluteFill, useCurrentFrame, spring, interpolate, useVideoConfig } from 'remotion'
import { getCompositionStyles } from '@/lib/useStyle'

export const StepExplainer: React.FC<{ title?: string; variant?: string }> = ({ title = 'How it works', variant = 'default' }) => {
  const frame = useCurrentFrame()
  const { fps } = useVideoConfig()
  const s = getCompositionStyles(variant)
  const isMono = s.fontFamily.includes('monospace')

  const titleProgress = spring({ frame, fps, config: { stiffness: 200, damping: 20 } })
  const steps = [
    { num: '01', text: 'Sign up for free' },
    { num: '02', text: 'Connect your tools' },
    { num: '03', text: 'Launch in minutes' },
  ]

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: '#fff' }}>
      <div style={{ width: 500 }}>
        <h2 style={{
          fontSize: isMono ? 36 : 42, fontWeight: s.fontWeight, color: '#171717', marginBottom: 32,
          opacity: titleProgress, transform: `translateY(${interpolate(titleProgress, [0, 1], [16, 0])}px)`,
          fontFamily: s.fontFamily, letterSpacing: s.letterSpacing,
          textTransform: isMono ? 'uppercase' as const : 'none' as const,
        }}>{title}</h2>

        {steps.map((step, i) => {
          const delay = 12 + i * 14
          const sp = spring({ frame: frame - delay, fps, config: { stiffness: 180, damping: 16 } })
          const lineWidth = interpolate(sp, [0, 1], [0, 100])

          return (
            <div key={i} style={{ display: 'flex', gap: 16, marginBottom: 20, opacity: sp, transform: `translateX(${interpolate(sp, [0, 1], [-20, 0])}px)` }}>
              <div style={{
                fontSize: 13, fontWeight: 700, color: '#a3a3a3', fontFamily: s.fontFamily,
                width: 30, flexShrink: 0, paddingTop: 2,
              }}>{step.num}</div>
              <div>
                <div style={{ fontSize: isMono ? 16 : 20, fontWeight: s.fontWeight, color: '#171717', fontFamily: s.fontFamily, letterSpacing: s.letterSpacing }}>{step.text}</div>
                <div style={{ height: 2, backgroundColor: '#171717', width: `${lineWidth}%`, marginTop: 6, borderRadius: 1 }} />
              </div>
            </div>
          )
        })}
      </div>
    </AbsoluteFill>
  )
}
