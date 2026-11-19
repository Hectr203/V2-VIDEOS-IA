import { AbsoluteFill, useCurrentFrame, spring, interpolate, useVideoConfig } from 'remotion'
import { getCompositionStyles } from '@/lib/useStyle'

export const OnboardingFlow: React.FC<{ title?: string; steps?: string; textColor?: string; variant?: string }> = ({
  title = 'Get started', steps: stepsStr = 'Create account,Set up workspace,Invite team,Start building', textColor = '#171717', variant = 'default',
}) => {
  const frame = useCurrentFrame()
  const { fps } = useVideoConfig()
  const s = getCompositionStyles(variant)
  const isMono = s.fontFamily.includes('monospace')

  const stepsList = stepsStr.split(',').map((s) => s.trim()).filter(Boolean)
  const progressWidth = interpolate(frame, [0, 120], [0, 100], { extrapolateRight: 'clamp' })

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: '#fff' }}>
      <div style={{ width: 560 }}>
        <h2 style={{
          fontSize: isMono ? 32 : 38, fontWeight: s.fontWeight, color: textColor, marginBottom: 24,
          fontFamily: s.fontFamily, letterSpacing: s.letterSpacing,
          textTransform: isMono ? 'uppercase' as const : 'none' as const,
        }}>
          {title}
        </h2>
        <div style={{ height: 4, backgroundColor: '#f5f5f5', borderRadius: 2, marginBottom: 28, overflow: 'hidden' }}>
          <div style={{ height: '100%', width: `${progressWidth}%`, backgroundColor: textColor, borderRadius: 2 }} />
        </div>
        {stepsList.map((step, i) => {
          const checkFrame = 10 + i * 25
          const checked = frame > checkFrame
          const checkScale = spring({ frame: frame - checkFrame, fps, config: { stiffness: 300, damping: 20 } })
          return (
            <div key={i} style={{
              display: 'flex', alignItems: 'center', gap: 12, padding: '12px 0',
              borderBottom: '1px solid #f5f5f5',
            }}>
              <div style={{
                width: 28, height: 28, borderRadius: 8,
                border: checked ? 'none' : '1.5px solid #d4d4d4',
                backgroundColor: checked ? textColor : 'transparent',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                transform: `scale(${checked ? checkScale : 1})`, flexShrink: 0,
              }}>
                {checked && <span style={{ color: '#fff', fontSize: 13 }}>{'\u2713'}</span>}
              </div>
              <span style={{
                fontSize: 19, color: checked ? textColor : '#a3a3a3', fontWeight: checked ? 500 : 400,
                textDecoration: checked && frame > checkFrame + 10 ? 'line-through' : 'none',
                fontFamily: s.fontFamily,
              }}>{step}</span>
            </div>
          )
        })}
      </div>
    </AbsoluteFill>
  )
}
