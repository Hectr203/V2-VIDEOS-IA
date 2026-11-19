import { AbsoluteFill, useCurrentFrame, interpolate } from 'remotion'
import { getCompositionStyles } from '@/lib/useStyle'

export const VirtualWalkthrough: React.FC<{ variant?: string }> = ({ variant = 'default' }) => {
  const frame = useCurrentFrame()
  const s = getCompositionStyles(variant)
  const rooms = ['Living Room', 'Kitchen', 'Bedroom']
  const activeRoom = Math.min(2, Math.floor(frame / 40))
  const panX = interpolate(frame, [0, 40, 80, 120], [0, -200, -400, -400], { extrapolateRight: 'clamp' })

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: '#fafafa' }}>
      <div style={{
        width: 460, overflow: 'hidden', borderRadius: s.borderRadius,
        border: `${s.borderWidth}px solid ${s.borderColor}`, position: 'relative',
        boxShadow: s.shadow,
      }}>
        <div style={{ display: 'flex', transform: `translateX(${panX}px)`, transition: 'transform 300ms ease' }}>
          {rooms.map((_room, i) => (
            <div key={i} style={{
              width: 460, height: 240, flexShrink: 0,
              background: i === 0 ? 'linear-gradient(135deg, #f5f5f5, #e5e5e5)' : i === 1 ? 'linear-gradient(135deg, #ebebeb, #d9d9d9)' : 'linear-gradient(135deg, #e0e0e0, #d0d0d0)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}>
              <div style={{
                width: 60, height: 40, borderRadius: 8, backgroundColor: 'rgba(0,0,0,0.06)',
                border: '1px solid rgba(0,0,0,0.08)',
              }} />
            </div>
          ))}
        </div>
        <div style={{ position: 'absolute', bottom: 12, left: 12, backgroundColor: 'rgba(0,0,0,0.7)', color: '#fff', padding: '4px 12px', borderRadius: 999, fontSize: 12, fontWeight: s.fontWeight, fontFamily: s.fontFamily }}>
          {rooms[activeRoom]}
        </div>
        <div style={{ position: 'absolute', bottom: 12, right: 12, display: 'flex', gap: 4 }}>
          {rooms.map((_, i) => (
            <div key={i} style={{ width: 6, height: 6, borderRadius: 999, backgroundColor: i === activeRoom ? '#fff' : 'rgba(255,255,255,0.4)' }} />
          ))}
        </div>
      </div>
    </AbsoluteFill>
  )
}
