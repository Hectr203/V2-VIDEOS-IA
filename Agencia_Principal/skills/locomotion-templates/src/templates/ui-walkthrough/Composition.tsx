import { AbsoluteFill, useCurrentFrame, spring, interpolate, useVideoConfig } from 'remotion'
import { getCompositionStyles } from '@/lib/useStyle'

export const UiWalkthrough: React.FC<{ variant?: string }> = ({ variant = 'default' }) => {
  const frame = useCurrentFrame()
  const { fps } = useVideoConfig()
  const s = getCompositionStyles(variant)

  const steps = [
    { label: 'Click "New Project"', x: 120, y: 100 },
    { label: 'Enter details', x: 300, y: 200 },
    { label: 'Hit "Create"', x: 420, y: 340 },
  ]

  const screenS = spring({ frame, fps, config: { stiffness: 200, damping: 20 } })

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: '#fff' }}>
      {/* App mockup */}
      <div style={{
        width: 560, height: 340, backgroundColor: '#fafafa', borderRadius: s.borderRadius,
        border: `${s.borderWidth}px solid ${s.borderColor}`, position: 'relative', overflow: 'hidden',
        opacity: screenS, boxShadow: s.shadow,
      }}>
        {/* Sidebar */}
        <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: 100, backgroundColor: '#f0f0f0', borderRight: `${s.borderWidth}px solid ${s.borderColor}` }}>
          {[0, 1, 2, 3].map((i) => (
            <div key={i} style={{ height: 8, width: 60, backgroundColor: '#d4d4d4', borderRadius: 4, margin: '12px auto 0' }} />
          ))}
        </div>

        {/* Main area */}
        <div style={{ marginLeft: 100, padding: 20 }}>
          <div style={{ height: 10, width: 120, backgroundColor: '#e5e5e5', borderRadius: 4, marginBottom: 16 }} />
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
            {[0, 1, 2, 3].map((i) => (
              <div key={i} style={{ height: 60, backgroundColor: '#f0f0f0', borderRadius: 8 }} />
            ))}
          </div>
          {/* Create button */}
          <div style={{
            marginTop: 16, width: 80, height: 28, backgroundColor: '#171717', borderRadius: 6,
          }} />
        </div>

        {/* Animated cursor + tooltips */}
        {steps.map((step, i) => {
          const delay = 15 + i * 30
          const show = frame >= delay
          const cursorS = spring({ frame: frame - delay, fps, config: { stiffness: 200, damping: 16 } })
          const tipS = spring({ frame: frame - delay - 5, fps, config: { stiffness: 200, damping: 18 } })

          if (!show) return null

          return (
            <div key={i}>
              {/* Cursor dot */}
              <div style={{
                position: 'absolute', left: step.x, top: step.y,
                width: 16, height: 16, borderRadius: 999,
                backgroundColor: '#171717', opacity: cursorS * 0.6,
                transform: `scale(${cursorS})`,
                boxShadow: '0 2px 8px rgba(0,0,0,0.2)',
              }} />

              {/* Tooltip */}
              <div style={{
                position: 'absolute', left: step.x + 20, top: step.y - 12,
                backgroundColor: '#171717', color: '#fff',
                padding: '4px 10px', borderRadius: 6,
                fontSize: 11, fontWeight: 500, fontFamily: s.fontFamily,
                whiteSpace: 'nowrap',
                opacity: tipS, transform: `translateY(${interpolate(tipS, [0, 1], [4, 0])}px)`,
              }}>
                {step.label}
              </div>
            </div>
          )
        })}
      </div>
    </AbsoluteFill>
  )
}
