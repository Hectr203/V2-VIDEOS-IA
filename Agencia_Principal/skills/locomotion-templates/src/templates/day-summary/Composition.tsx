import { AbsoluteFill, useCurrentFrame, spring, interpolate, useVideoConfig } from 'remotion'
import { getCompositionStyles } from '@/lib/useStyle'

export const DaySummary: React.FC<{ title?: string; tasks?: string; metric?: string; metricValue?: string; textColor?: string; bgColor?: string; variant?: string }> = ({
  title = 'Productive day', tasks = 'Shipped v2.4,Fixed 12 bugs,Reviewed 5 PRs,Wrote docs', metric = 'Tasks completed', metricValue = '23', textColor = '#171717', bgColor = '#ffffff', variant = 'default',
}) => {
  const frame = useCurrentFrame()
  const { fps } = useVideoConfig()
  const s = getCompositionStyles(variant)

  const headerS = spring({ frame, fps, config: { stiffness: 180, damping: 18 } })
  const taskList = tasks.split(',').map((t) => t.trim()).filter(Boolean)

  const isDark = bgColor === '#000000' || bgColor === '#171717' || bgColor === '#0a0a0a'
  const cardBg = isDark ? '#1a1a1a' : '#fff'
  const textBase = isDark ? '#fff' : textColor
  const lineBg = isDark ? '#262626' : '#f0f0f0'

  const metricNum = parseInt(metricValue, 10) || 0
  const metricAnimS = spring({ frame: frame - 10, fps, config: { stiffness: 120, damping: 18 } })
  const animatedMetric = Math.round(interpolate(metricAnimS, [0, 1], [0, metricNum]))

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: bgColor }}>
      <div style={{
        width: 520, padding: 40, borderRadius: s.borderRadius + 4,
        backgroundColor: cardBg,
        border: `${s.borderWidth}px solid ${isDark ? '#222' : s.borderColor}`,
        boxShadow: s.shadow || '0 16px 40px rgba(0,0,0,0.08)',
        opacity: headerS, transform: `scale(${interpolate(headerS, [0, 1], [0.94, 1])})`,
      }}>
        {/* Header with emoji */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 8 }}>
          <span style={{ fontSize: 32 }}>{'\u2728'}</span>
          <h2 style={{ fontSize: 28, fontWeight: 800, color: textBase, fontFamily: s.fontFamily }}>{title}</h2>
        </div>

        {/* Metric */}
        <div style={{
          backgroundColor: isDark ? '#111' : '#f5f5f5', borderRadius: s.borderRadius,
          padding: '16px 20px', marginBottom: 24, marginTop: 16,
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        }}>
          <span style={{ fontSize: 14, color: isDark ? '#737373' : '#a3a3a3', fontFamily: s.fontFamily }}>{metric}</span>
          <span style={{ fontSize: 32, fontWeight: 800, color: textColor, fontFamily: s.fontFamily }}>{animatedMetric}</span>
        </div>

        {/* Task list */}
        {taskList.map((task, i) => {
          const delay = 18 + i * 7
          const taskS = spring({ frame: frame - delay, fps, config: { stiffness: 200, damping: 14 } })
          const checked = frame > delay + 10
          const checkS = spring({ frame: frame - delay - 10, fps, config: { stiffness: 300, damping: 16 } })
          return (
            <div key={i}>
              <div style={{
                display: 'flex', alignItems: 'center', gap: 12, padding: '12px 0',
                opacity: taskS, transform: `translateX(${interpolate(taskS, [0, 1], [-12, 0])}px)`,
              }}>
                <div style={{
                  width: 24, height: 24, borderRadius: 6,
                  backgroundColor: checked ? textColor : 'transparent',
                  border: checked ? 'none' : `1.5px solid ${isDark ? '#444' : '#d4d4d4'}`,
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  transform: `scale(${checked ? checkS : 1})`, flexShrink: 0,
                }}>
                  {checked && <span style={{ color: '#fff', fontSize: 12 }}>{'\u2713'}</span>}
                </div>
                <span style={{
                  fontSize: 16, color: textBase, fontFamily: s.fontFamily,
                  textDecoration: checked && frame > delay + 18 ? 'line-through' : 'none',
                  opacity: checked && frame > delay + 18 ? 0.5 : 1,
                }}>{task}</span>
              </div>
              {i < taskList.length - 1 && <div style={{ height: 1, backgroundColor: lineBg, marginLeft: 36 }} />}
            </div>
          )
        })}
      </div>
    </AbsoluteFill>
  )
}
