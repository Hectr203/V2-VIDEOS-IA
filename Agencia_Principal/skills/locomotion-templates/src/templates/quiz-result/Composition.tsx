import { AbsoluteFill, useCurrentFrame, spring, interpolate, useVideoConfig } from 'remotion'
import { getCompositionStyles } from '@/lib/useStyle'

export const QuizResult: React.FC<{ variant?: string }> = ({ variant = 'default' }) => {
  const frame = useCurrentFrame()
  const { fps } = useVideoConfig()
  const s = getCompositionStyles(variant)
  const isMono = s.fontFamily.includes('monospace')
  const score = 85
  const circleS = spring({ frame, fps, config: { stiffness: 100, damping: 16 } })
  const scoreCount = Math.round(interpolate(circleS, [0, 1], [0, score]))
  const circumference = 2 * Math.PI * 60
  const strokeDashoffset = circumference * (1 - circleS * (score / 100))

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: '#fff' }}>
      <div style={{ textAlign: 'center' }}>
        <svg width={150} height={150} style={{ transform: 'rotate(-90deg)' }}>
          <circle cx={75} cy={75} r={60} fill="none" stroke="#f0f0f0" strokeWidth={8} />
          <circle cx={75} cy={75} r={60} fill="none" stroke="#171717" strokeWidth={8} strokeLinecap="round" strokeDasharray={circumference} strokeDashoffset={strokeDashoffset} />
        </svg>
        <div style={{ marginTop: -100, fontSize: isMono ? 30 : 36, fontWeight: 800, color: '#171717', fontFamily: s.fontFamily }}>{scoreCount}%</div>
        <div style={{ fontSize: 13, color: '#a3a3a3', fontFamily: s.fontFamily, marginTop: 55 }}>Quiz Score</div>
        <div style={{
          fontSize: isMono ? 17 : 20, fontWeight: s.fontWeight, color: '#171717', fontFamily: s.fontFamily,
          marginTop: 8, opacity: spring({ frame: frame - 20, fps, config: { stiffness: 200, damping: 18 } }),
          textTransform: isMono ? 'uppercase' as const : 'none' as const,
        }}>Great job!</div>
      </div>
    </AbsoluteFill>
  )
}
