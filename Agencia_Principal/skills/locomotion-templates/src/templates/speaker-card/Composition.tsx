import { AbsoluteFill, useCurrentFrame, spring, interpolate, useVideoConfig } from 'remotion'
import { getCompositionStyles } from '@/lib/useStyle'

export const SpeakerCard: React.FC<{ text?: string; variant?: string }> = ({ text = 'Jane Smith', variant = 'default' }) => {
  const frame = useCurrentFrame()
  const { fps } = useVideoConfig()
  const s = getCompositionStyles(variant)
  const isMono = s.fontFamily.includes('monospace')
  const avatarS = spring({ frame, fps, config: { stiffness: 200, damping: 14 } })
  const nameS = spring({ frame: frame - 10, fps, config: { stiffness: 200, damping: 18 } })
  const detailS = spring({ frame: frame - 18, fps, config: { stiffness: 200, damping: 20 } })

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: '#fafafa' }}>
      <div style={{ textAlign: 'center' }}>
        <div style={{ width: 90, height: 90, borderRadius: 999, backgroundColor: '#e5e5e5', margin: '0 auto 16px', display: 'flex', alignItems: 'center', justifyContent: 'center', transform: `scale(${avatarS})`, fontSize: 36 }}>
          {text[0]}
        </div>
        <h2 style={{
          fontSize: isMono ? 26 : 30, fontWeight: s.fontWeight, color: '#171717', fontFamily: s.fontFamily,
          opacity: nameS, transform: `translateY(${interpolate(nameS, [0,1], [8,0])}px)`,
          letterSpacing: s.letterSpacing,
          textTransform: isMono ? 'uppercase' as const : 'none' as const,
        }}>{text}</h2>
        <p style={{ fontSize: 14, color: '#737373', fontFamily: s.fontFamily, marginTop: 4, opacity: detailS }}>VP Engineering, Acme Inc.</p>
        <div style={{ fontSize: 12, color: '#a3a3a3', fontFamily: s.fontFamily, marginTop: 8, opacity: detailS }}>
          "Building the future of developer tools"
        </div>
      </div>
    </AbsoluteFill>
  )
}
