import { AbsoluteFill, useCurrentFrame, spring, interpolate, useVideoConfig } from 'remotion'
import { getCompositionStyles } from '@/lib/useStyle'

export const FeatureShowcase: React.FC<{ title?: string; features?: string; descriptions?: string; textColor?: string; variant?: string }> = ({
  title = 'Everything you need', features: featuresStr = 'Fast,Secure,Ship it', descriptions: descStr = 'Built for speed,Enterprise ready,Idea to prod', textColor = '#171717', variant = 'default',
}) => {
  const frame = useCurrentFrame()
  const { fps } = useVideoConfig()
  const s = getCompositionStyles(variant)
  const isMono = s.fontFamily.includes('monospace')

  const featureNames = featuresStr.split(',').map((s) => s.trim())
  const featureDescs = descStr.split(',').map((s) => s.trim())
  const featureList = featureNames.map((name, i) => ({ title: name, desc: featureDescs[i] ?? '' }))

  const titleProgress = spring({ frame, fps, config: { stiffness: 200, damping: 20 } })
  const titleY = interpolate(titleProgress, [0, 1], [16, 0])

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: '#fff', flexDirection: 'column', gap: 36 }}>
      <h2 style={{
        fontSize: isMono ? 38 : 46,
        fontWeight: s.fontWeight, color: textColor,
        opacity: titleProgress, transform: `translateY(${titleY}px)`,
        fontFamily: s.fontFamily, letterSpacing: s.letterSpacing,
        textTransform: isMono ? 'uppercase' as const : 'none' as const,
      }}>{title}</h2>
      <div style={{ display: 'flex', gap: s.borderRadius > 12 ? 20 : 12 }}>
        {featureList.map((f, i) => {
          const delay = 15 + i * 10
          const sp = spring({ frame: frame - delay, fps, config: { stiffness: 180, damping: 15 } })
          const y = interpolate(sp, [0, 1], [16, 0])
          return (
            <div key={i} style={{
              width: 260, padding: s.borderRadius > 16 ? 28 : 24,
              borderRadius: s.borderRadius,
              border: `${s.borderWidth}px solid ${s.borderColor}`,
              boxShadow: s.shadow,
              opacity: sp, transform: `translateY(${y}px)`, backgroundColor: '#fff',
            }}>
              <div style={{
                width: 44, height: 44, borderRadius: s.borderRadius > 12 ? s.borderRadius / 2 : s.borderRadius / 3,
                backgroundColor: '#f5f5f5', marginBottom: 14,
                border: s.borderWidth > 1 ? `${s.borderWidth}px solid ${s.borderColor}` : 'none',
              }} />
              <h3 style={{
                fontSize: isMono ? 18 : 22, fontWeight: s.fontWeight, color: textColor,
                marginBottom: 6, fontFamily: s.fontFamily, letterSpacing: s.letterSpacing,
                textTransform: isMono ? 'uppercase' as const : 'none' as const,
              }}>{f.title}</h3>
              <p style={{
                fontSize: 15, color: '#737373', fontFamily: s.fontFamily,
                letterSpacing: s.letterSpacing,
              }}>{f.desc}</p>
            </div>
          )
        })}
      </div>
    </AbsoluteFill>
  )
}
