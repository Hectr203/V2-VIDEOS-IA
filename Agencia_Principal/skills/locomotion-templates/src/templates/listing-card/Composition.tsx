import { AbsoluteFill, useCurrentFrame, spring, interpolate, useVideoConfig } from 'remotion'
import { getCompositionStyles } from '@/lib/useStyle'

export const ListingCard: React.FC<{ variant?: string }> = ({ variant = 'default' }) => {
  const frame = useCurrentFrame()
  const { fps } = useVideoConfig()
  const s = getCompositionStyles(variant)
  const isMono = s.fontFamily.includes('monospace')
  const listings = [
    { addr: '12 Maple St', price: '$320K', beds: 2 },
    { addr: '88 Pine Rd', price: '$475K', beds: 3 },
    { addr: '5 River Dr', price: '$650K', beds: 4 },
  ]

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: '#fafafa' }}>
      <div style={{ display: 'flex', gap: 14 }}>
        {listings.map((l, i) => {
          const delay = 5 + i * 10
          const sp = spring({ frame: frame - delay, fps, config: { stiffness: 180, damping: 15 } })
          return (
            <div key={i} style={{
              width: 160, borderRadius: s.borderRadius,
              border: `${s.borderWidth}px solid ${s.borderColor}`,
              backgroundColor: '#fff', overflow: 'hidden', opacity: sp,
              transform: `translateY(${interpolate(sp, [0,1], [16,0])}px)`,
              boxShadow: s.shadow,
            }}>
              <div style={{ height: 80, background: 'linear-gradient(135deg, #f0f0f0, #e5e5e5)' }} />
              <div style={{ padding: 10 }}>
                <div style={{ fontSize: 12, fontWeight: s.fontWeight, color: '#171717', fontFamily: s.fontFamily }}>{l.addr}</div>
                <div style={{ fontSize: isMono ? 14 : 16, fontWeight: 800, color: '#171717', fontFamily: s.fontFamily, marginTop: 2 }}>{l.price}</div>
                <div style={{ fontSize: 10, color: '#a3a3a3', fontFamily: s.fontFamily }}>{l.beds} beds</div>
              </div>
            </div>
          )
        })}
      </div>
    </AbsoluteFill>
  )
}
