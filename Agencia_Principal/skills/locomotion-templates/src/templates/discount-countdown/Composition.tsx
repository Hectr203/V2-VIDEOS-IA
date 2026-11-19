import { AbsoluteFill, useCurrentFrame, spring, interpolate, useVideoConfig } from 'remotion'
import { getCompositionStyles } from '@/lib/useStyle'

export const DiscountCountdown: React.FC<{ text?: string; variant?: string }> = ({ text = '50% OFF', variant = 'default' }) => {
  const frame = useCurrentFrame()
  const { fps } = useVideoConfig()
  const s = getCompositionStyles(variant)
  const isMono = s.fontFamily.includes('monospace')
  const badgeS = spring({ frame, fps, config: { stiffness: 250, damping: 12 } })
  const timerS = spring({ frame: frame - 12, fps, config: { stiffness: 200, damping: 18 } })
  const hours = Math.max(0, Math.floor(interpolate(frame, [20, 80], [23, 0], { extrapolateRight: 'clamp', extrapolateLeft: 'clamp' })))
  const mins = Math.max(0, Math.floor(interpolate(frame, [20, 80], [59, 0], { extrapolateRight: 'clamp', extrapolateLeft: 'clamp' })))

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: '#fff' }}>
      <div style={{
        backgroundColor: '#171717', color: '#fff', padding: '8px 20px', borderRadius: 999,
        fontSize: isMono ? 15 : 18, fontWeight: 800, fontFamily: s.fontFamily,
        opacity: badgeS, transform: `scale(${badgeS})`, marginBottom: 16,
      }}>{text}</div>
      <div style={{ fontSize: 14, color: '#a3a3a3', fontFamily: s.fontFamily, opacity: timerS, marginBottom: 8 }}>Ends in</div>
      <div style={{ display: 'flex', gap: 8, opacity: timerS }}>
        {[{ v: hours, l: 'HRS' }, { v: mins, l: 'MIN' }, { v: 59, l: 'SEC' }].map((t, i) => (
          <div key={i} style={{
            backgroundColor: '#f5f5f5', borderRadius: s.borderRadius, padding: '10px 14px', textAlign: 'center',
            border: `${s.borderWidth}px solid ${s.borderColor}`, boxShadow: s.shadow,
          }}>
            <div style={{ fontSize: isMono ? 24 : 28, fontWeight: 800, color: '#171717', fontFamily: s.fontFamily }}>{String(t.v).padStart(2, '0')}</div>
            <div style={{ fontSize: 9, color: '#a3a3a3', fontFamily: s.fontFamily, letterSpacing: '0.1em' }}>{t.l}</div>
          </div>
        ))}
      </div>
    </AbsoluteFill>
  )
}
