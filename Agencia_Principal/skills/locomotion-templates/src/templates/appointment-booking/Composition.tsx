import { AbsoluteFill, useCurrentFrame, spring, interpolate, useVideoConfig } from 'remotion'
import { getCompositionStyles } from '@/lib/useStyle'

export const AppointmentBooking: React.FC<{ variant?: string }> = ({ variant = 'default' }) => {
  const frame = useCurrentFrame()
  const { fps } = useVideoConfig()
  const s = getCompositionStyles(variant)
  const cardS = spring({ frame, fps, config: { stiffness: 180, damping: 18 } })
  const slots = ['9:00 AM', '10:30 AM', '2:00 PM']
  const selectedSlot = 1
  const confirmS = spring({ frame: frame - 50, fps, config: { stiffness: 200, damping: 14 } })

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: '#fafafa' }}>
      <div style={{
        width: 320, backgroundColor: '#fff', borderRadius: s.borderRadius,
        border: `${s.borderWidth}px solid ${s.borderColor}`, padding: 24,
        opacity: cardS, transform: `translateY(${interpolate(cardS, [0,1], [12,0])}px)`,
        boxShadow: s.shadow,
      }}>
        <h3 style={{ fontSize: 18, fontWeight: s.fontWeight, color: '#171717', fontFamily: s.fontFamily, marginBottom: 4 }}>Book appointment</h3>
        <div style={{ fontSize: 12, color: '#a3a3a3', fontFamily: s.fontFamily, marginBottom: 16 }}>Dr. Smith · March 28</div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
          {slots.map((slot, i) => {
            const delay = 15 + i * 8
            const sp = spring({ frame: frame - delay, fps, config: { stiffness: 200, damping: 16 } })
            const selected = i === selectedSlot && frame > 35
            return (
              <div key={i} style={{
                padding: '10px 14px', borderRadius: s.borderRadius > 16 ? 8 : s.borderRadius,
                border: selected ? '2px solid #171717' : `${s.borderWidth}px solid ${s.borderColor}`,
                backgroundColor: selected ? '#f5f5f5' : '#fff', fontSize: 14,
                fontWeight: selected ? s.fontWeight : 400, color: '#171717', fontFamily: s.fontFamily,
                opacity: sp, transform: `scale(${selected ? 1.02 : 1})`, transition: 'all 150ms',
              }}>{slot}</div>
            )
          })}
        </div>
        <div style={{ marginTop: 14, backgroundColor: '#171717', color: '#fff', padding: '10px 0', borderRadius: 999, textAlign: 'center', fontSize: 13, fontWeight: s.fontWeight, fontFamily: s.fontFamily, opacity: confirmS, transform: `scale(${confirmS})` }}>Confirm booking</div>
      </div>
    </AbsoluteFill>
  )
}
