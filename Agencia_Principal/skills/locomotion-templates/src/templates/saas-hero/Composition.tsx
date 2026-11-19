import { AbsoluteFill, useCurrentFrame, spring, interpolate, useVideoConfig } from 'remotion'
import { getCompositionStyles } from '@/lib/useStyle'

export const SaasHero: React.FC<{ title?: string; textColor?: string; bgColor?: string; variant?: string }> = ({
  title = 'Ship faster with AI', textColor = '#000000', bgColor = '#ffffff', variant = 'default',
}) => {
  const frame = useCurrentFrame()
  const { fps } = useVideoConfig()
  const s = getCompositionStyles(variant)
  const isMono = s.fontFamily.includes('monospace')

  const titleScale = spring({ frame, fps, config: { stiffness: 160, damping: 18 } })
  const titleY = interpolate(titleScale, [0, 1], [20, 0])
  const subtitleProgress = spring({ frame: frame - 10, fps, config: { stiffness: 200, damping: 20 } })
  const subtitleY = interpolate(subtitleProgress, [0, 1], [10, 0])
  const buttonProgress = spring({ frame: frame - 25, fps, config: { stiffness: 200, damping: 16 } })

  const stats = [
    { value: '10K+', label: 'Users', num: 10000 },
    { value: '99.9%', label: 'Uptime', num: 0 },
    { value: '< 50ms', label: 'Latency', num: 0 },
  ]

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: bgColor, flexDirection: 'column' }}>
      <h1 style={{
        fontSize: isMono ? 44 : 56,
        fontWeight: s.fontWeight, color: textColor, textAlign: 'center',
        opacity: titleScale, transform: `translateY(${titleY}px)`,
        fontFamily: s.fontFamily, letterSpacing: s.letterSpacing,
        textTransform: isMono ? 'uppercase' as const : 'none' as const,
      }}>{title}</h1>
      <p style={{
        fontSize: isMono ? 14 : 18, color: '#737373', marginTop: 8, textAlign: 'center',
        opacity: subtitleProgress, transform: `translateY(${subtitleY}px)`,
        fontFamily: s.fontFamily, letterSpacing: s.letterSpacing,
      }}>The platform teams love to build on</p>
      <div style={{ display: 'flex', gap: 40, marginTop: 24 }}>
        {stats.map((stat, i) => {
          const delay = 15 + i * 6
          const sp = spring({ frame: frame - delay, fps, config: { stiffness: 180, damping: 15 } })
          const displayValue = stat.num > 0 ? Math.round(interpolate(sp, [0, 1], [0, stat.num])).toLocaleString() + '+' : stat.value
          return (
            <div key={i} style={{ textAlign: 'center', opacity: sp }}>
              <div style={{
                fontSize: 30, fontWeight: s.fontWeight, color: textColor,
                fontFamily: s.fontFamily, letterSpacing: s.letterSpacing,
              }}>{displayValue}</div>
              <div style={{
                fontSize: 12, color: '#a3a3a3', fontFamily: s.fontFamily,
                letterSpacing: s.letterSpacing,
                textTransform: isMono ? 'uppercase' as const : 'none' as const,
              }}>{stat.label}</div>
            </div>
          )
        })}
      </div>
      <div style={{
        marginTop: 24, padding: isMono ? '12px 28px' : '12px 28px',
        backgroundColor: textColor, color: bgColor,
        borderRadius: s.borderRadius > 16 ? 999 : s.borderRadius / 2,
        fontSize: 15, fontWeight: s.fontWeight,
        opacity: buttonProgress, transform: `scale(${buttonProgress})`,
        fontFamily: s.fontFamily, letterSpacing: s.letterSpacing,
        boxShadow: s.shadow,
        textTransform: isMono ? 'uppercase' as const : 'none' as const,
      }}>Get started free {'\u2192'}</div>
    </AbsoluteFill>
  )
}
