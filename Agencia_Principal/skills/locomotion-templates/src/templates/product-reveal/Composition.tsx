import { AbsoluteFill, useCurrentFrame, spring, interpolate, useVideoConfig } from 'remotion'
import { getCompositionStyles } from '@/lib/useStyle'

export const ProductReveal: React.FC<{ text?: string; variant?: string }> = ({ text = 'New AirPods Pro', variant = 'default' }) => {
  const frame = useCurrentFrame()
  const { fps } = useVideoConfig()
  const s = getCompositionStyles(variant)
  const isMono = s.fontFamily.includes('monospace')
  const boxS = spring({ frame, fps, config: { stiffness: 140, damping: 16 } })
  const labelS = spring({ frame: frame - 15, fps, config: { stiffness: 200, damping: 18 } })
  const priceS = spring({ frame: frame - 25, fps, config: { stiffness: 200, damping: 16 } })

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: '#fafafa' }}>
      <div style={{
        width: 300, height: 200, backgroundColor: '#fff', borderRadius: s.borderRadius,
        border: `${s.borderWidth}px solid ${s.borderColor}`, display: 'flex', alignItems: 'center',
        justifyContent: 'center', transform: `scale(${boxS})`, opacity: boxS,
        boxShadow: s.shadow,
      }}>
        <div style={{ width: 80, height: 80, borderRadius: s.borderRadius, backgroundColor: '#f0f0f0' }} />
      </div>
      <h2 style={{
        fontSize: isMono ? 24 : 28, fontWeight: s.fontWeight, color: '#171717', marginTop: 20,
        opacity: labelS, transform: `translateY(${interpolate(labelS, [0,1], [10,0])}px)`,
        fontFamily: s.fontFamily, letterSpacing: s.letterSpacing,
        textTransform: isMono ? 'uppercase' as const : 'none' as const,
      }}>{text}</h2>
      <div style={{ display: 'flex', gap: 12, marginTop: 10, opacity: priceS }}>
        <span style={{ fontSize: 22, fontWeight: 800, color: '#171717', fontFamily: s.fontFamily }}>$249</span>
        <span style={{ fontSize: 14, color: '#a3a3a3', fontFamily: s.fontFamily, alignSelf: 'center', textDecoration: 'line-through' }}>$299</span>
      </div>
    </AbsoluteFill>
  )
}
