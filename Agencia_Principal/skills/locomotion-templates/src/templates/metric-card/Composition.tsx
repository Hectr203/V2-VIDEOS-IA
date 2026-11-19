import { AbsoluteFill, useCurrentFrame, spring, interpolate, useVideoConfig } from 'remotion'
import { getCompositionStyles } from '@/lib/useStyle'

export const MetricCard: React.FC<{ label?: string; value?: string; change?: string; date?: string; textColor?: string; bgColor?: string; variant?: string }> = ({
  label = 'MRR', value = '$12,450', change = '+37.18%', date = 'March 2026', textColor = '#10B981', bgColor = '#000000', variant = 'default',
}) => {
  const frame = useCurrentFrame()
  const { fps } = useVideoConfig()
  const s = getCompositionStyles(variant)

  const cardS = spring({ frame: frame - 3, fps, config: { stiffness: 180, damping: 16 } })
  const numberS = spring({ frame: frame - 12, fps, config: { stiffness: 120, damping: 18 } })
  const badgeS = spring({ frame: frame - 30, fps, config: { stiffness: 200, damping: 12 } })

  // Parse numeric value for counter animation
  const numericStr = value.replace(/[^0-9.]/g, '')
  const numericVal = parseFloat(numericStr) || 0
  const prefix = value.match(/^[^0-9]*/)?.[0] ?? ''
  const suffix = value.match(/[^0-9]*$/)?.[0] ?? ''
  const animatedNum = Math.round(interpolate(numberS, [0, 1], [0, numericVal]))
  const formattedNum = animatedNum.toLocaleString()

  // Sparkline points
  const sparkPoints = [20, 35, 28, 45, 40, 55, 50, 68, 60, 75, 72, 85]
  const sparklineProgress = interpolate(frame, [15, 50], [0, 1], { extrapolateRight: 'clamp', extrapolateLeft: 'clamp' })

  // Bar chart
  const barHeights = [40, 55, 35, 65, 50, 75, 60, 85]

  // Confetti particles
  const showConfetti = frame > 40
  const confettiColors = ['#10B981', '#3B82F6', '#F59E0B', '#EC4899', '#8B5CF6']

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: bgColor }}>
      <div style={{
        width: 520, backgroundColor: '#111', borderRadius: s.borderRadius + 8,
        padding: 40, opacity: cardS, transform: `scale(${interpolate(cardS, [0, 1], [0.9, 1])})`,
        border: `${s.borderWidth}px solid #222`,
        position: 'relative', overflow: 'hidden',
      }}>
        {/* Label */}
        <div style={{ fontSize: 16, color: '#737373', fontFamily: s.fontFamily, marginBottom: 4, letterSpacing: s.letterSpacing }}>
          {label}
        </div>

        {/* Big number */}
        <div style={{ fontSize: 56, fontWeight: 800, color: '#fff', fontFamily: s.fontFamily, letterSpacing: '-0.02em', marginBottom: 4 }}>
          {prefix}{formattedNum}{suffix}
        </div>

        {/* Date + change badge */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 24 }}>
          <span style={{ fontSize: 13, color: '#525252', fontFamily: s.fontFamily }}>{date}</span>
          <div style={{
            fontSize: 12, fontWeight: 600, color: textColor,
            backgroundColor: `${textColor}18`, padding: '3px 10px', borderRadius: 999,
            opacity: badgeS, transform: `scale(${badgeS})`,
            fontFamily: s.fontFamily,
          }}>
            {change}
          </div>
        </div>

        {/* Sparkline */}
        <svg width="100%" height="40" viewBox="0 0 440 40" style={{ marginBottom: 16 }}>
          <polyline
            fill="none"
            stroke={textColor}
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
            points={sparkPoints.slice(0, Math.ceil(sparkPoints.length * sparklineProgress)).map((y, i) =>
              `${(i / (sparkPoints.length - 1)) * 440},${40 - (y / 100) * 40}`
            ).join(' ')}
          />
        </svg>

        {/* Bar chart */}
        <div style={{ display: 'flex', alignItems: 'flex-end', gap: 6, height: 60 }}>
          {barHeights.map((h, i) => {
            const barDelay = 20 + i * 3
            const barS = spring({ frame: frame - barDelay, fps, config: { stiffness: 200, damping: 14 } })
            return (
              <div key={i} style={{
                flex: 1, height: `${h * barS}%`,
                backgroundColor: i === barHeights.length - 1 ? textColor : '#262626',
                borderRadius: 3,
              }} />
            )
          })}
        </div>

        {/* Confetti */}
        {showConfetti && Array.from({ length: 20 }).map((_, i) => {
          const confettiFrame = frame - 40
          const angle = (i / 20) * Math.PI * 2
          const speed = 2 + (i % 5) * 0.8
          const x = Math.cos(angle) * speed * confettiFrame
          const y = Math.sin(angle) * speed * confettiFrame - confettiFrame * 0.5
          const opacity = interpolate(confettiFrame, [0, 30], [1, 0], { extrapolateRight: 'clamp' })
          return (
            <div key={i} style={{
              position: 'absolute', left: '50%', top: '40%',
              width: 6, height: 6, borderRadius: i % 2 === 0 ? 999 : 1,
              backgroundColor: confettiColors[i % confettiColors.length],
              transform: `translate(${x}px, ${y}px) rotate(${confettiFrame * (5 + i)}deg)`,
              opacity,
            }} />
          )
        })}
      </div>
    </AbsoluteFill>
  )
}
