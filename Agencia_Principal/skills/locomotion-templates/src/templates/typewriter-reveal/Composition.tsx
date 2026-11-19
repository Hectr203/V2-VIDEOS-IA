import { AbsoluteFill, useCurrentFrame, interpolate } from 'remotion'
import { getCompositionStyles } from '@/lib/useStyle'

export const TypewriterReveal: React.FC<{ text?: string; variant?: string }> = ({
  text = 'Building the future.',
  variant = 'default',
}) => {
  const frame = useCurrentFrame()
  const s = getCompositionStyles(variant)
  const isMono = s.fontFamily.includes('monospace')
  const chars = Math.floor(
    interpolate(frame, [0, 70], [0, text.length], { extrapolateRight: 'clamp' })
  )
  const cursorOpacity = Math.round(frame / 8) % 2 === 0 ? 1 : 0

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: '#fafafa' }}>
      <div style={{
        fontFamily: s.fontFamily, fontSize: isMono ? 40 : 46, color: '#171717',
        fontWeight: s.fontWeight, letterSpacing: s.letterSpacing,
        textTransform: isMono ? 'uppercase' as const : 'none' as const,
      }}>
        {text.slice(0, chars)}
        <span style={{ opacity: cursorOpacity, color: '#a3a3a3' }}>|</span>
      </div>
    </AbsoluteFill>
  )
}
