import { AbsoluteFill, useCurrentFrame, spring, interpolate, useVideoConfig } from 'remotion'
import { getCompositionStyles } from '@/lib/useStyle'

export const PaymentFlow: React.FC<{ variant?: string }> = ({ variant = 'default' }) => {
  const frame = useCurrentFrame()
  const { fps } = useVideoConfig()
  const s = getCompositionStyles(variant)
  const steps = [
    { label: 'Enter card', num: '1' },
    { label: 'Verify', num: '2' },
    { label: 'Complete', num: '3' },
  ]

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: '#fafafa' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
        {steps.map((step, i) => {
          const delay = 10 + i * 20
          const sp = spring({ frame: frame - delay, fps, config: { stiffness: 200, damping: 16 } })
          const active = frame > delay + 10
          return (
            <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
              <div style={{
                width: 120, padding: '16px 16px', borderRadius: s.borderRadius,
                backgroundColor: '#fff', border: active ? '2px solid #171717' : `${s.borderWidth}px solid ${s.borderColor}`,
                opacity: sp, transform: `scale(${interpolate(sp, [0,1], [0.9,1])})`,
                textAlign: 'center', boxShadow: s.shadow,
              }}>
                <div style={{
                  width: 28, height: 28, borderRadius: 999,
                  backgroundColor: active ? '#171717' : '#f5f5f5',
                  color: active ? '#fff' : '#a3a3a3',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  fontSize: 13, fontWeight: s.fontWeight, fontFamily: s.fontFamily,
                  margin: '0 auto 8px',
                }}>{step.num}</div>
                <div style={{ fontSize: 12, fontWeight: s.fontWeight, color: '#171717', fontFamily: s.fontFamily }}>{step.label}</div>
              </div>
              {i < steps.length - 1 && (
                <div style={{ width: 24, height: 2, backgroundColor: frame > delay + 15 ? '#171717' : '#e5e5e5', borderRadius: 1 }} />
              )}
            </div>
          )
        })}
      </div>
    </AbsoluteFill>
  )
}
