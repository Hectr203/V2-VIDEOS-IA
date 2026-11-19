import { AbsoluteFill, useCurrentFrame, spring, interpolate, useVideoConfig } from 'remotion'
import { getCompositionStyles } from '@/lib/useStyle'

export const ModalExplainer: React.FC<{ title?: string; subtitle?: string; steps?: string; stepDescriptions?: string; textColor?: string; variant?: string }> = ({
  title = 'How it works', subtitle = 'Get started in three simple steps', steps: stepsStr = 'Connect,Choose,Launch', stepDescriptions: descStr = 'Link your account in one click,Pick a template that fits,Go live in minutes', textColor = '#171717', variant = 'default',
}) => {
  const frame = useCurrentFrame()
  const { fps } = useVideoConfig()
  const s = getCompositionStyles(variant)
  const isMono = s.fontFamily.includes('monospace')

  const backdropOpacity = interpolate(frame, [0, 15], [0, 0.4], { extrapolateRight: 'clamp' })
  const modalScale = spring({ frame: frame - 5, fps, config: { stiffness: 200, damping: 18 } })
  const modalOpacity = interpolate(frame, [5, 20], [0, 1], { extrapolateRight: 'clamp' })

  const stepNames = stepsStr.split(',').map((s) => s.trim())
  const stepDescs = descStr.split(',').map((s) => s.trim())
  const steps = stepNames.map((name, i) => ({ title: name, desc: stepDescs[i] ?? '' }))

  const activeStep = Math.min(2, Math.floor(Math.max(0, frame - 30) / 35))
  const stepProgress = interpolate(frame, [30, 135], [0, 100], { extrapolateRight: 'clamp', extrapolateLeft: 'clamp' })

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: '#f5f5f5' }}>
      <div style={{ position: 'absolute', inset: 0, backgroundColor: `rgba(0,0,0,${backdropOpacity})` }} />
      <div style={{
        width: 600, backgroundColor: '#fff',
        borderRadius: s.borderRadius + 4,
        overflow: 'hidden',
        transform: `scale(${modalScale})`, opacity: modalOpacity,
        boxShadow: s.shadow || '0 24px 48px rgba(0,0,0,0.12)',
        zIndex: 1,
        border: `${s.borderWidth}px solid ${s.borderColor}`,
      }}>
        {/* Header */}
        <div style={{ padding: '28px 32px 0' }}>
          <h2 style={{
            fontSize: isMono ? 22 : 26,
            fontWeight: s.fontWeight, color: textColor,
            fontFamily: s.fontFamily, marginBottom: 4,
            letterSpacing: s.letterSpacing,
            textTransform: isMono ? 'uppercase' as const : 'none' as const,
          }}>{title}</h2>
          <p style={{
            fontSize: 14, color: '#a3a3a3', fontFamily: s.fontFamily,
            letterSpacing: s.letterSpacing,
          }}>{subtitle}</p>
        </div>

        {/* Steps */}
        <div style={{ padding: '24px 32px', height: 140 }}>
          {steps.map((step, i) => {
            const isActive = i === activeStep
            const stepDelay = 30 + i * 35
            const enterS = spring({ frame: frame - stepDelay, fps, config: { stiffness: 200, damping: 16 } })
            if (frame < stepDelay) return null
            return (
              <div key={i} style={{
                position: 'absolute',
                opacity: isActive ? enterS : interpolate(frame - stepDelay - 30, [0, 5], [1, 0], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' }),
                transform: `translateY(${isActive ? interpolate(enterS, [0, 1], [16, 0]) : 0}px)`,
              }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
                  <div style={{
                    width: 44, height: 44,
                    borderRadius: s.borderRadius > 16 ? 14 : s.borderRadius / 3,
                    backgroundColor: isActive ? textColor : '#f5f5f5',
                    border: isActive ? 'none' : `${s.borderWidth}px solid ${s.borderColor}`,
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    fontSize: 18, fontWeight: s.fontWeight,
                    color: isActive ? '#fff' : '#a3a3a3',
                    fontFamily: s.fontFamily, flexShrink: 0,
                  }}>{i + 1}</div>
                  <div>
                    <div style={{
                      fontSize: isMono ? 16 : 20,
                      fontWeight: s.fontWeight, color: textColor,
                      fontFamily: s.fontFamily, letterSpacing: s.letterSpacing,
                      textTransform: isMono ? 'uppercase' as const : 'none' as const,
                    }}>{step.title}</div>
                    <div style={{
                      fontSize: 14, color: '#737373',
                      fontFamily: s.fontFamily, marginTop: 2,
                      letterSpacing: s.letterSpacing,
                    }}>{step.desc}</div>
                  </div>
                </div>
                {/* Progress bars per step */}
                <div style={{ marginTop: 16, marginLeft: 58, display: 'flex', gap: 6 }}>
                  {[0, 1, 2].map((j) => {
                    const blockDelay = stepDelay + 8 + j * 4
                    const blockS = spring({ frame: frame - blockDelay, fps, config: { stiffness: 180, damping: 14 } })
                    return (
                      <div key={j} style={{
                        height: 6, flex: 1,
                        borderRadius: s.borderRadius > 12 ? 3 : 0,
                        backgroundColor: '#f0f0f0', overflow: 'hidden',
                      }}>
                        <div style={{
                          height: '100%',
                          borderRadius: s.borderRadius > 12 ? 3 : 0,
                          backgroundColor: textColor, width: `${blockS * 100}%`,
                        }} />
                      </div>
                    )
                  })}
                </div>
              </div>
            )
          })}
        </div>

        {/* Dots */}
        <div style={{ padding: '0 32px 8px', display: 'flex', gap: 8 }}>
          {steps.map((_, i) => (
            <div key={i} style={{
              width: 6, height: 6,
              borderRadius: s.borderRadius > 4 ? 999 : 1,
              backgroundColor: i === activeStep ? textColor : '#e5e5e5',
            }} />
          ))}
        </div>

        {/* Bottom progress */}
        <div style={{ height: 4, backgroundColor: '#f5f5f5' }}>
          <div style={{
            height: '100%', backgroundColor: textColor,
            borderRadius: s.borderRadius > 4 ? '0 2px 2px 0' : 0,
            width: `${stepProgress}%`,
          }} />
        </div>
      </div>
    </AbsoluteFill>
  )
}
