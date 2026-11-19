import { AbsoluteFill, useCurrentFrame, spring, interpolate, useVideoConfig } from 'remotion'
import { getCompositionStyles } from '@/lib/useStyle'

export const SalesCard: React.FC<{ productName?: string; revenue?: string; unitsSold?: string; price?: string; textColor?: string; bgColor?: string; variant?: string }> = ({
  productName = 'Pro Templates', revenue = '$4,280', unitsSold = '142', price = '$29', textColor = '#10B981', bgColor = '#000000', variant = 'default',
}) => {
  const frame = useCurrentFrame()
  const { fps } = useVideoConfig()
  const s = getCompositionStyles(variant)

  const cardS = spring({ frame: frame - 2, fps, config: { stiffness: 180, damping: 16 } })
  const revenueS = spring({ frame: frame - 10, fps, config: { stiffness: 120, damping: 18 } })
  const statsS = spring({ frame: frame - 25, fps, config: { stiffness: 180, damping: 16 } })

  const revNum = parseInt(revenue.replace(/[^0-9]/g, ''), 10) || 0
  const unitsNum = parseInt(unitsSold.replace(/[^0-9]/g, ''), 10) || 0
  const animatedRev = Math.round(interpolate(revenueS, [0, 1], [0, revNum]))
  const animatedUnits = Math.round(interpolate(statsS, [0, 1], [0, unitsNum]))

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: bgColor }}>
      <div style={{
        width: 520, padding: 44, borderRadius: s.borderRadius + 8,
        backgroundColor: '#111', border: `${s.borderWidth}px solid #222`,
        boxShadow: '0 24px 48px rgba(0,0,0,0.3)',
        opacity: cardS, transform: `scale(${interpolate(cardS, [0, 1], [0.9, 1])})`,
      }}>
        {/* Product name + badge */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 8 }}>
          <div style={{ fontSize: 15, color: '#737373', fontFamily: s.fontFamily }}>{productName}</div>
          <div style={{
            fontSize: 11, fontWeight: 600, color: textColor,
            backgroundColor: `${textColor}18`, padding: '3px 10px', borderRadius: 999,
          }}>LIVE</div>
        </div>

        {/* Big revenue number */}
        <div style={{
          fontSize: 56, fontWeight: 800, color: '#fff', fontFamily: s.fontFamily,
          letterSpacing: '-0.02em', marginBottom: 4,
        }}>
          ${animatedRev.toLocaleString()}
        </div>
        <div style={{ fontSize: 14, color: '#525252', fontFamily: s.fontFamily, marginBottom: 28 }}>
          Total revenue
        </div>

        {/* Stats row */}
        <div style={{
          display: 'flex', gap: 0, borderTop: '1px solid #222', paddingTop: 24,
          opacity: statsS,
        }}>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 28, fontWeight: 800, color: '#fff', fontFamily: s.fontFamily }}>{animatedUnits}</div>
            <div style={{ fontSize: 13, color: '#525252', fontFamily: s.fontFamily }}>Units sold</div>
          </div>
          <div style={{ width: 1, backgroundColor: '#222' }} />
          <div style={{ flex: 1, paddingLeft: 24 }}>
            <div style={{ fontSize: 28, fontWeight: 800, color: '#fff', fontFamily: s.fontFamily }}>{price}</div>
            <div style={{ fontSize: 13, color: '#525252', fontFamily: s.fontFamily }}>Price each</div>
          </div>
          <div style={{ width: 1, backgroundColor: '#222' }} />
          <div style={{ flex: 1, paddingLeft: 24 }}>
            <div style={{ fontSize: 28, fontWeight: 800, color: textColor, fontFamily: s.fontFamily }}>
              {'\u2191'} {Math.round(revNum / (unitsNum || 1) * 0.4)}%
            </div>
            <div style={{ fontSize: 13, color: '#525252', fontFamily: s.fontFamily }}>Growth</div>
          </div>
        </div>
      </div>
    </AbsoluteFill>
  )
}
