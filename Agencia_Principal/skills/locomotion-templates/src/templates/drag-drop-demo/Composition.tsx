import { AbsoluteFill, useCurrentFrame, spring, interpolate, useVideoConfig } from 'remotion'
import { getCompositionStyles } from '@/lib/useStyle'

export const DragDropDemo: React.FC<{ variant?: string }> = ({ variant = 'default' }) => {
  const frame = useCurrentFrame()
  const { fps } = useVideoConfig()
  const s = getCompositionStyles(variant)
  const isMono = s.fontFamily.includes('monospace')

  const items = [
    { label: 'Header', color: '#171717' },
    { label: 'Features', color: '#525252' },
    { label: 'Pricing', color: '#737373' },
  ]

  // Title fade in
  const titleOpacity = interpolate(frame, [0, 15], [0, 1], { extrapolateRight: 'clamp' })

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: '#fff' }}>
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 24 }}>
        <h2 style={{
          fontSize: isMono ? 24 : 28, fontWeight: s.fontWeight, color: '#171717', fontFamily: s.fontFamily,
          opacity: titleOpacity, letterSpacing: s.letterSpacing,
          textTransform: isMono ? 'uppercase' as const : 'none' as const,
        }}>
          Build your page
        </h2>

        {/* Layout preview - items stack into a page mockup */}
        <div style={{
          width: 380, backgroundColor: '#fafafa', borderRadius: s.borderRadius,
          border: `${s.borderWidth}px solid ${s.borderColor}`, overflow: 'hidden',
          boxShadow: s.shadow,
        }}>
          {items.map((item, i) => {
            const delay = 15 + i * 20
            const progress = spring({ frame: frame - delay, fps, config: { stiffness: 150, damping: 16 } })
            const slideX = interpolate(progress, [0, 1], [-400, 0])
            const opacity = interpolate(progress, [0, 0.3, 1], [0, 1, 1])

            // After landing, show a subtle settle
            const settleScale = spring({
              frame: frame - delay - 5,
              fps,
              config: { stiffness: 300, damping: 12 },
            })
            const scale = progress > 0.9 ? settleScale * 0.02 + 0.98 : 1

            return (
              <div key={i} style={{
                padding: '18px 20px',
                borderBottom: i < items.length - 1 ? `${s.borderWidth}px solid ${s.borderColor}` : 'none',
                transform: `translateX(${slideX}px) scale(${scale})`,
                opacity,
                display: 'flex',
                alignItems: 'center',
                gap: 12,
              }}>
                {/* Drag handle */}
                <div style={{
                  display: 'flex', flexDirection: 'column', gap: 2, opacity: 0.3,
                }}>
                  <div style={{ width: 12, height: 2, backgroundColor: '#171717', borderRadius: 1 }} />
                  <div style={{ width: 12, height: 2, backgroundColor: '#171717', borderRadius: 1 }} />
                  <div style={{ width: 12, height: 2, backgroundColor: '#171717', borderRadius: 1 }} />
                </div>

                {/* Block preview */}
                <div style={{
                  flex: 1, height: 36, borderRadius: 6,
                  backgroundColor: item.color, opacity: 0.1,
                }} />

                <span style={{
                  fontSize: 14, fontWeight: 500, color: item.color,
                  fontFamily: s.fontFamily,
                }}>
                  {item.label}
                </span>
              </div>
            )
          })}
        </div>

        {/* Success checkmark after all items land */}
        {(() => {
          const checkDelay = 80
          const checkProgress = spring({
            frame: frame - checkDelay,
            fps,
            config: { stiffness: 200, damping: 14 },
          })
          return (
            <div style={{
              display: 'flex', alignItems: 'center', gap: 8,
              opacity: checkProgress,
              transform: `scale(${checkProgress})`,
            }}>
              <div style={{
                width: 28, height: 28, borderRadius: 999, backgroundColor: '#171717',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
              }}>
                <span style={{ color: '#fff', fontSize: 14 }}>{'\u2713'}</span>
              </div>
              <span style={{ fontSize: 15, fontWeight: 500, color: '#171717', fontFamily: s.fontFamily }}>
                Page ready
              </span>
            </div>
          )
        })()}
      </div>
    </AbsoluteFill>
  )
}
