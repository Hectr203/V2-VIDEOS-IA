import { AbsoluteFill, useCurrentFrame, spring, interpolate, useVideoConfig } from 'remotion'
import { getCompositionStyles } from '@/lib/useStyle'

export const StatsDashboard: React.FC<{ labels?: string; values?: string; textColor?: string; variant?: string }> = ({
  labels: labelsStr = 'Users,Revenue,Growth,NPS', values: valuesStr = '12847,$84K,127%,72', textColor = '#171717', variant = 'default',
}) => {
  const frame = useCurrentFrame()
  const { fps } = useVideoConfig()
  const s = getCompositionStyles(variant)
  const isMono = s.fontFamily.includes('monospace')

  const labelList = labelsStr.split(',').map((s) => s.trim())
  const valueList = valuesStr.split(',').map((s) => s.trim())
  const stats = labelList.map((label, i) => {
    const raw = valueList[i] ?? '0'
    const prefix = raw.startsWith('$') ? '$' : ''
    const suffix = raw.endsWith('%') ? '%' : raw.endsWith('K') ? 'K' : ''
    const num = parseInt(raw.replace(/[^0-9]/g, ''), 10) || 0
    return { label, value: num, prefix, suffix }
  })

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: '#fafafa' }}>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 20, width: 620 }}>
        {stats.map((stat, i) => {
          const delay = 5 + i * 8
          const sp = spring({ frame: frame - delay, fps, config: { stiffness: 180, damping: 16 } })
          const count = Math.round(interpolate(sp, [0, 1], [0, stat.value]))

          return (
            <div key={i} style={{
              backgroundColor: '#fff', borderRadius: s.borderRadius, padding: '28px 32px',
              border: `${s.borderWidth}px solid ${s.borderColor}`, opacity: sp,
              transform: `scale(${interpolate(sp, [0, 1], [0.95, 1])})`,
              boxShadow: s.shadow,
            }}>
              <div style={{ fontSize: 14, color: '#a3a3a3', fontFamily: s.fontFamily, marginBottom: 6 }}>{stat.label}</div>
              <div style={{
                fontSize: isMono ? 36 : 44, fontWeight: 800, color: textColor, fontFamily: s.fontFamily,
                letterSpacing: s.letterSpacing,
              }}>
                {stat.prefix}{count.toLocaleString()}{stat.suffix}
              </div>
            </div>
          )
        })}
      </div>
    </AbsoluteFill>
  )
}
