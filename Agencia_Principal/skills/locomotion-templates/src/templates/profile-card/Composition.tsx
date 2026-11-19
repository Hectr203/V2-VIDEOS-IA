import { AbsoluteFill, useCurrentFrame, spring, interpolate, useVideoConfig } from 'remotion'
import { getCompositionStyles } from '@/lib/useStyle'

export const ProfileCard: React.FC<{ name?: string; role?: string; bio?: string; stats?: string; textColor?: string; bgColor?: string; variant?: string }> = ({
  name = 'Alex Rivera', role = 'Founder & CEO', bio = 'Building the future of programmatic video. Previously at Stripe and Vercel.',
  stats = '12K followers,500+ posts,50 projects', textColor = '#171717', bgColor = '#fafafa', variant = 'default',
}) => {
  const frame = useCurrentFrame()
  const { fps } = useVideoConfig()
  const s = getCompositionStyles(variant)

  const cardS = spring({ frame: frame - 2, fps, config: { stiffness: 180, damping: 16 } })
  const avatarS = spring({ frame: frame - 6, fps, config: { stiffness: 250, damping: 12 } })
  const nameS = spring({ frame: frame - 12, fps, config: { stiffness: 180, damping: 16 } })
  const bioS = spring({ frame: frame - 20, fps, config: { stiffness: 160, damping: 18 } })

  const statsList = stats.split(',').map((st) => st.trim()).filter(Boolean)

  const isDark = bgColor === '#000000' || bgColor === '#171717' || bgColor === '#0a0a0a'
  const cardBg = isDark ? '#1a1a1a' : '#fff'
  const textBase = isDark ? '#fff' : textColor

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: bgColor }}>
      <div style={{
        width: 480, padding: 44, borderRadius: s.borderRadius + 4,
        backgroundColor: cardBg, textAlign: 'center',
        border: `${s.borderWidth}px solid ${isDark ? '#333' : s.borderColor}`,
        boxShadow: s.shadow || '0 16px 40px rgba(0,0,0,0.08)',
        opacity: cardS, transform: `scale(${interpolate(cardS, [0, 1], [0.92, 1])})`,
      }}>
        {/* Avatar */}
        <div style={{
          width: 80, height: 80, borderRadius: 999, margin: '0 auto 20px',
          backgroundColor: textColor, display: 'flex',
          alignItems: 'center', justifyContent: 'center',
          fontSize: 34, fontWeight: 800, color: cardBg, fontFamily: s.fontFamily,
          transform: `scale(${avatarS})`,
        }}>
          {name.charAt(0)}
        </div>

        {/* Name */}
        <div style={{
          fontSize: 26, fontWeight: 800, color: textBase, fontFamily: s.fontFamily,
          opacity: nameS, marginBottom: 4, letterSpacing: s.letterSpacing,
        }}>{name}</div>

        {/* Role */}
        <div style={{
          fontSize: 15, color: isDark ? '#737373' : '#a3a3a3', fontFamily: s.fontFamily,
          opacity: nameS, marginBottom: 20,
        }}>{role}</div>

        {/* Bio */}
        <p style={{
          fontSize: 16, lineHeight: 1.6, color: isDark ? '#a3a3a3' : '#737373',
          fontFamily: s.fontFamily, marginBottom: 28,
          opacity: bioS, transform: `translateY(${interpolate(bioS, [0, 1], [8, 0])}px)`,
        }}>{bio}</p>

        {/* Stats row */}
        <div style={{
          display: 'flex', justifyContent: 'center', gap: 24,
          paddingTop: 20, borderTop: `1px solid ${isDark ? '#262626' : '#f0f0f0'}`,
        }}>
          {statsList.map((stat, i) => {
            const delay = 28 + i * 6
            const statS = spring({ frame: frame - delay, fps, config: { stiffness: 200, damping: 14 } })
            const parts = stat.match(/^([\d,.KMk+]+)\s*(.*)$/)
            const num = parts?.[1] ?? stat
            const label = parts?.[2] ?? ''
            return (
              <div key={i} style={{ opacity: statS, transform: `translateY(${interpolate(statS, [0, 1], [8, 0])}px)` }}>
                <div style={{ fontSize: 20, fontWeight: 800, color: textBase, fontFamily: s.fontFamily }}>{num}</div>
                <div style={{ fontSize: 12, color: isDark ? '#525252' : '#a3a3a3', fontFamily: s.fontFamily }}>{label}</div>
              </div>
            )
          })}
        </div>
      </div>
    </AbsoluteFill>
  )
}
