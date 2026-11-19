import { AbsoluteFill, useCurrentFrame, spring, interpolate, useVideoConfig } from 'remotion'
import { getCompositionStyles } from '@/lib/useStyle'

export const CollabCard: React.FC<{ leftName?: string; rightName?: string; title?: string; subtitle?: string; textColor?: string; bgColor?: string; variant?: string }> = ({
  leftName = 'Acme', rightName = 'Beacon', title = 'Better together', subtitle = 'We\'re thrilled to announce our partnership.',
  textColor = '#171717', bgColor = '#ffffff', variant = 'default',
}) => {
  const frame = useCurrentFrame()
  const { fps } = useVideoConfig()
  const s = getCompositionStyles(variant)

  const leftS = spring({ frame: frame - 3, fps, config: { stiffness: 180, damping: 14 } })
  const rightS = spring({ frame: frame - 3, fps, config: { stiffness: 180, damping: 14 } })
  const mergeS = spring({ frame: frame - 18, fps, config: { stiffness: 120, damping: 16 } })
  const textOpS = spring({ frame: frame - 30, fps, config: { stiffness: 160, damping: 18 } })
  const sparkS = spring({ frame: frame - 22, fps, config: { stiffness: 300, damping: 10 } })

  const isDark = bgColor === '#000000' || bgColor === '#171717' || bgColor === '#0a0a0a'
  const textBase = isDark ? '#fff' : textColor

  // Logos slide in from sides and meet in center
  const leftX = interpolate(mergeS, [0, 1], [-80, -50])
  const rightX = interpolate(mergeS, [0, 1], [80, 50])

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: bgColor }}>
      <div style={{ textAlign: 'center' }}>
        {/* Logo circles */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 36, position: 'relative' }}>
          {/* Left logo */}
          <div style={{
            width: 96, height: 96, borderRadius: 999,
            backgroundColor: textColor, display: 'flex',
            alignItems: 'center', justifyContent: 'center',
            fontSize: 36, fontWeight: 800, color: isDark ? '#000' : '#fff', fontFamily: s.fontFamily,
            opacity: leftS, transform: `translateX(${leftX}px) scale(${leftS})`,
            zIndex: 2,
            boxShadow: '0 4px 16px rgba(0,0,0,0.1)',
          }}>
            {leftName.charAt(0)}
          </div>

          {/* Connection spark */}
          <div style={{
            position: 'absolute', fontSize: 40,
            opacity: sparkS, transform: `scale(${sparkS})`,
            zIndex: 3,
          }}>{'\u26A1'}</div>

          {/* Right logo */}
          <div style={{
            width: 96, height: 96, borderRadius: 999,
            backgroundColor: isDark ? '#333' : '#f5f5f5',
            border: `2px solid ${isDark ? '#444' : '#e5e5e5'}`,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontSize: 36, fontWeight: 800, color: textBase, fontFamily: s.fontFamily,
            opacity: rightS, transform: `translateX(${rightX}px) scale(${rightS})`,
            zIndex: 2,
            boxShadow: '0 4px 16px rgba(0,0,0,0.1)',
          }}>
            {rightName.charAt(0)}
          </div>
        </div>

        {/* Title */}
        <h2 style={{
          fontSize: 44, fontWeight: 800, color: textBase, fontFamily: s.fontFamily,
          letterSpacing: '-0.02em', marginBottom: 12,
          opacity: textOpS, transform: `translateY(${interpolate(textOpS, [0, 1], [12, 0])}px)`,
        }}>
          {title}
        </h2>

        {/* Subtitle */}
        <p style={{
          fontSize: 20, color: isDark ? '#a3a3a3' : '#737373', fontFamily: s.fontFamily,
          opacity: textOpS, maxWidth: 480,
        }}>
          {subtitle}
        </p>

        {/* Partner names */}
        <div style={{
          marginTop: 28, fontSize: 15, fontWeight: 600, color: isDark ? '#525252' : '#a3a3a3',
          fontFamily: s.fontFamily, opacity: textOpS,
        }}>
          {leftName} {'\u00D7'} {rightName}
        </div>
      </div>
    </AbsoluteFill>
  )
}
