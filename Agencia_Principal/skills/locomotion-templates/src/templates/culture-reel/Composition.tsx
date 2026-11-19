import { AbsoluteFill, useCurrentFrame, spring, interpolate, useVideoConfig } from 'remotion'
import { getCompositionStyles } from '@/lib/useStyle'

export const CultureReel: React.FC<{ text?: string; variant?: string }> = ({ text = 'Life at Acme', variant = 'default' }) => {
  const frame = useCurrentFrame()
  const { fps } = useVideoConfig()
  const s = getCompositionStyles(variant)
  const isMono = s.fontFamily.includes('monospace')
  const titleS = spring({ frame, fps, config: { stiffness: 180, damping: 18 } })
  const values = ['\uD83C\uDF1F Innovation', '\uD83E\uDD1D Collaboration', '\uD83C\uDF31 Growth']

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: '#171717' }}>
      <div style={{ textAlign: 'center' }}>
        <h1 style={{
          fontSize: isMono ? 32 : 38, fontWeight: 800, color: '#fff', fontFamily: s.fontFamily,
          opacity: titleS, transform: `translateY(${interpolate(titleS, [0,1], [16,0])}px)`,
          letterSpacing: s.letterSpacing,
          textTransform: isMono ? 'uppercase' as const : 'none' as const,
        }}>{text}</h1>
        <div style={{ display: 'flex', gap: 20, marginTop: 24, justifyContent: 'center' }}>
          {values.map((v, i) => {
            const delay = 15 + i * 10
            const sp = spring({ frame: frame - delay, fps, config: { stiffness: 200, damping: 16 } })
            return (
              <div key={i} style={{
                padding: '10px 18px', borderRadius: 999,
                border: `${s.borderWidth}px solid #404040`,
                fontSize: 14, color: '#fff', fontFamily: s.fontFamily, opacity: sp, transform: `scale(${sp})`,
              }}>{v}</div>
            )
          })}
        </div>
      </div>
    </AbsoluteFill>
  )
}
