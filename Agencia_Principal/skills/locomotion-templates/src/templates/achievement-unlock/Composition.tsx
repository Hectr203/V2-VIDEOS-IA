import { AbsoluteFill, useCurrentFrame, spring, interpolate, useVideoConfig } from 'remotion'
import { getCompositionStyles } from '@/lib/useStyle'

export const AchievementUnlock: React.FC<{ text?: string; subtitle?: string; reward?: string; variant?: string }> = ({
  text = 'First Victory', subtitle = 'Achievement Unlocked', reward = '+500 XP', variant = 'default',
}) => {
  const frame = useCurrentFrame()
  const { fps } = useVideoConfig()
  const s = getCompositionStyles(variant)
  const isMono = s.fontFamily.includes('monospace')
  const bannerS = spring({ frame: frame - 5, fps, config: { stiffness: 250, damping: 12 } })
  const iconS = spring({ frame, fps, config: { stiffness: 300, damping: 10 } })
  const shineAngle = interpolate(frame, [0, 60], [-45, 90], { extrapolateRight: 'clamp' })

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: '#171717' }}>
      <div style={{ textAlign: 'center' }}>
        <div style={{ fontSize: 72, transform: `scale(${iconS})`, marginBottom: 16, filter: `hue-rotate(${shineAngle}deg)` }}>{'\uD83C\uDFC6'}</div>
        <div style={{ fontSize: 14, color: '#737373', fontFamily: s.fontFamily, textTransform: 'uppercase', letterSpacing: '0.12em', marginBottom: 8, opacity: bannerS }}>{subtitle}</div>
        <h2 style={{
          fontSize: isMono ? 34 : 40, fontWeight: 800, color: '#fff', fontFamily: s.fontFamily,
          opacity: bannerS, transform: `translateY(${interpolate(bannerS, [0,1], [12,0])}px)`,
          letterSpacing: s.letterSpacing,
          textTransform: isMono ? 'uppercase' as const : 'none' as const,
        }}>{text}</h2>
        <div style={{ width: 260, height: 5, backgroundColor: '#262626', borderRadius: 3, margin: '18px auto 0', overflow: 'hidden' }}>
          <div style={{ height: '100%', width: `${interpolate(frame, [15, 50], [0, 100], { extrapolateRight: 'clamp', extrapolateLeft: 'clamp' })}%`, backgroundColor: '#fbbf24', borderRadius: 3 }} />
        </div>
        <div style={{ fontSize: 14, color: '#525252', fontFamily: s.fontFamily, marginTop: 8, opacity: spring({ frame: frame - 25, fps, config: { stiffness: 200, damping: 20 } }) }}>{reward}</div>
      </div>
    </AbsoluteFill>
  )
}
