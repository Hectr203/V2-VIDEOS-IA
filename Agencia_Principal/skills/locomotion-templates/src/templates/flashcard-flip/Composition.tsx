import { AbsoluteFill, useCurrentFrame, interpolate } from 'remotion'
import { getCompositionStyles } from '@/lib/useStyle'

export const FlashcardFlip: React.FC<{ text?: string; variant?: string }> = ({ text = 'Photosynthesis', variant = 'default' }) => {
  const frame = useCurrentFrame()
  const s = getCompositionStyles(variant)
  const isMono = s.fontFamily.includes('monospace')
  const flipProgress = interpolate(frame, [20, 40], [0, 180], { extrapolateRight: 'clamp', extrapolateLeft: 'clamp' })
  const showBack = flipProgress > 90
  const scaleX = Math.abs(Math.cos((flipProgress * Math.PI) / 180))

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: '#fafafa' }}>
      <div style={{
        width: 360, height: 200, borderRadius: s.borderRadius,
        border: `${s.borderWidth}px solid ${s.borderColor}`,
        backgroundColor: showBack ? '#171717' : '#fff', display: 'flex', flexDirection: 'column',
        alignItems: 'center', justifyContent: 'center', transform: `scaleX(${scaleX})`, padding: 24,
        boxShadow: s.shadow,
      }}>
        {!showBack ? (
          <>
            <div style={{ fontSize: 12, color: '#a3a3a3', fontFamily: s.fontFamily, marginBottom: 8, textTransform: 'uppercase', letterSpacing: '0.08em' }}>Question</div>
            <div style={{
              fontSize: isMono ? 22 : 26, fontWeight: s.fontWeight, color: '#171717', fontFamily: s.fontFamily,
              textAlign: 'center', letterSpacing: s.letterSpacing,
            }}>{text}</div>
          </>
        ) : (
          <>
            <div style={{ fontSize: 12, color: '#737373', fontFamily: s.fontFamily, marginBottom: 8, textTransform: 'uppercase', letterSpacing: '0.08em' }}>Answer</div>
            <div style={{ fontSize: isMono ? 14 : 16, color: '#fff', fontFamily: s.fontFamily, textAlign: 'center', lineHeight: 1.5 }}>The process by which plants convert sunlight into energy</div>
          </>
        )}
      </div>
      <div style={{ fontSize: 11, color: '#a3a3a3', marginTop: 12, fontFamily: s.fontFamily, opacity: interpolate(frame, [0, 10], [0, 1], { extrapolateRight: 'clamp' }) }}>Tap to flip</div>
    </AbsoluteFill>
  )
}
