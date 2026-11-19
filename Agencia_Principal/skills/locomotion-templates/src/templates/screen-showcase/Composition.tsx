import { AbsoluteFill, useCurrentFrame, spring, interpolate, useVideoConfig } from 'remotion'
import { getCompositionStyles } from '@/lib/useStyle'

export const ScreenShowcase: React.FC<{ title?: string; features?: string; textColor?: string; bgColor?: string; variant?: string }> = ({
  title = 'Dashboard', features = 'Real-time analytics,Team collaboration,Custom reports', textColor = '#171717', bgColor = '#fafafa', variant = 'default',
}) => {
  const frame = useCurrentFrame()
  const { fps } = useVideoConfig()
  const s = getCompositionStyles(variant)

  const browserS = spring({ frame: frame - 2, fps, config: { stiffness: 160, damping: 16 } })
  const featureList = features.split(',').map((f) => f.trim()).filter(Boolean)

  const isDark = bgColor === '#000000' || bgColor === '#171717' || bgColor === '#0a0a0a'
  const chromeBg = isDark ? '#1a1a1a' : '#fff'
  const uiBg = isDark ? '#111' : '#f5f5f5'

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: bgColor }}>
      <div style={{ display: 'flex', gap: 32, alignItems: 'center' }}>
        {/* Browser mockup */}
        <div style={{
          width: 480, borderRadius: s.borderRadius + 4, overflow: 'hidden',
          border: `${s.borderWidth}px solid ${isDark ? '#333' : s.borderColor}`,
          boxShadow: s.shadow || '0 16px 40px rgba(0,0,0,0.1)',
          opacity: browserS, transform: `translateX(${interpolate(browserS, [0, 1], [-20, 0])}px)`,
        }}>
          {/* Chrome bar */}
          <div style={{
            height: 36, backgroundColor: isDark ? '#222' : '#f5f5f5',
            display: 'flex', alignItems: 'center', padding: '0 14px', gap: 7,
            borderBottom: `1px solid ${isDark ? '#333' : '#e5e5e5'}`,
          }}>
            <div style={{ width: 10, height: 10, borderRadius: 999, backgroundColor: '#EF4444' }} />
            <div style={{ width: 10, height: 10, borderRadius: 999, backgroundColor: '#F59E0B' }} />
            <div style={{ width: 10, height: 10, borderRadius: 999, backgroundColor: '#10B981' }} />
            <div style={{
              marginLeft: 16, flex: 1, height: 20, borderRadius: 4,
              backgroundColor: isDark ? '#333' : '#e5e5e5', maxWidth: 200,
            }} />
          </div>

          {/* App UI */}
          <div style={{ backgroundColor: chromeBg, padding: 24, minHeight: 260 }}>
            {/* Nav placeholder */}
            <div style={{ display: 'flex', gap: 8, marginBottom: 20 }}>
              {[80, 60, 70].map((w, i) => (
                <div key={i} style={{ width: w, height: 8, borderRadius: 4, backgroundColor: uiBg }} />
              ))}
            </div>
            {/* Title */}
            <div style={{ fontSize: 20, fontWeight: 700, color: isDark ? '#fff' : textColor, fontFamily: s.fontFamily, marginBottom: 16 }}>{title}</div>
            {/* Fake cards grid */}
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
              {[0, 1, 2, 3].map((i) => {
                const delay = 15 + i * 6
                const cS = spring({ frame: frame - delay, fps, config: { stiffness: 180, damping: 14 } })
                return (
                  <div key={i} style={{
                    height: 60, borderRadius: s.borderRadius / 2,
                    backgroundColor: uiBg, opacity: cS,
                    border: `1px solid ${isDark ? '#262626' : '#e5e5e5'}`,
                  }} />
                )
              })}
            </div>
          </div>
        </div>

        {/* Feature callouts */}
        <div style={{ maxWidth: 260 }}>
          {featureList.map((feature, i) => {
            const delay = 20 + i * 10
            const fS = spring({ frame: frame - delay, fps, config: { stiffness: 180, damping: 16 } })
            return (
              <div key={i} style={{
                display: 'flex', alignItems: 'center', gap: 12, marginBottom: 20,
                opacity: fS, transform: `translateX(${interpolate(fS, [0, 1], [16, 0])}px)`,
              }}>
                <div style={{
                  width: 32, height: 32, borderRadius: 999, backgroundColor: `${textColor}14`,
                  display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
                  fontSize: 14, color: textColor, fontWeight: 700,
                }}>{i + 1}</div>
                <span style={{
                  fontSize: 16, fontWeight: 600, color: isDark ? '#fff' : textColor, fontFamily: s.fontFamily,
                }}>{feature}</span>
              </div>
            )
          })}
        </div>
      </div>
    </AbsoluteFill>
  )
}
