import { AbsoluteFill, useCurrentFrame, spring, interpolate, useVideoConfig } from 'remotion'
import { getCompositionStyles } from '@/lib/useStyle'

export const PricingComparison: React.FC<{ planNames?: string; planPrices?: string; planFeatures?: string; buttonText?: string; textColor?: string; variant?: string }> = ({
  planNames = 'Starter,Pro,Team', planPrices = '$9,$29,$99', planFeatures = '5 projects|Basic,Unlimited|Analytics,Everything|Support', buttonText = 'Get started', textColor = '#171717', variant = 'default',
}) => {
  const frame = useCurrentFrame()
  const { fps } = useVideoConfig()
  const s = getCompositionStyles(variant)

  const names = planNames.split(',').map((s) => s.trim())
  const prices = planPrices.split(',').map((s) => s.trim())
  const features = planFeatures.split(',').map((g) => g.split('|').map((s) => s.trim()))
  const plans = names.map((name, i) => ({ name, price: prices[i] ?? '', features: features[i] ?? [], popular: i === 1 }))

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: '#fafafa' }}>
      <div style={{ display: 'flex', gap: s.borderRadius > 12 ? 18 : 10, alignItems: 'stretch' }}>
        {plans.map((plan, i) => {
          const delay = 5 + i * 8
          const sp = spring({ frame: frame - delay, fps, config: { stiffness: 200, damping: 16 } })
          const y = interpolate(sp, [0, 1], [20, 0])
          const pulseScale = plan.popular ? 1 + 0.015 * Math.sin((frame - 40) * 0.1) * (frame > 40 ? 1 : 0) : 1

          return (
            <div key={i} style={{
              width: 240, padding: s.borderRadius > 16 ? 30 : 26,
              borderRadius: s.borderRadius,
              backgroundColor: '#fff',
              border: plan.popular
                ? `${s.borderWidth + 1}px solid ${textColor}`
                : `${s.borderWidth}px solid ${s.borderColor}`,
              boxShadow: plan.popular ? (s.shadow || '0 4px 12px rgba(0,0,0,0.08)') : s.card.boxShadow,
              opacity: sp,
              transform: `translateY(${y}px) scale(${pulseScale})`,
            }}>
              {plan.popular && (
                <div style={{
                  fontSize: 11,
                  fontWeight: s.fontWeight,
                  color: '#fff',
                  backgroundColor: textColor,
                  borderRadius: s.borderRadius > 12 ? 999 : s.borderRadius / 3,
                  padding: s.borderRadius === 0 ? '4px 10px' : '4px 12px',
                  marginBottom: 12,
                  display: 'inline-block',
                  fontFamily: s.fontFamily,
                  letterSpacing: s.letterSpacing,
                  textTransform: s.fontFamily.includes('monospace') ? 'uppercase' as const : 'none' as const,
                }}>Popular</div>
              )}
              <h3 style={{
                fontSize: 20, fontWeight: s.fontWeight, color: textColor,
                fontFamily: s.fontFamily, letterSpacing: s.letterSpacing,
                textTransform: s.fontFamily.includes('monospace') ? 'uppercase' as const : 'none' as const,
              }}>{plan.name}</h3>
              <div style={{
                fontSize: 46, fontWeight: Math.min(900, s.fontWeight + 200), color: '#000',
                margin: '8px 0', fontFamily: s.fontFamily,
                letterSpacing: s.letterSpacing,
              }}>
                {plan.price}
                <span style={{ fontSize: 15, color: '#737373', fontWeight: 400, fontFamily: s.fontFamily }}>/mo</span>
              </div>
              {plan.features.map((f, j) => (
                <div key={j} style={{
                  fontSize: 15, color: '#525252', padding: '4px 0',
                  fontFamily: s.fontFamily, letterSpacing: s.letterSpacing,
                }}>{f}</div>
              ))}
              <div style={{
                marginTop: 16, padding: '10px 0', textAlign: 'center',
                backgroundColor: plan.popular ? textColor : 'transparent',
                color: plan.popular ? '#fff' : textColor,
                border: plan.popular ? 'none' : `${s.borderWidth}px solid ${s.borderColor}`,
                borderRadius: s.borderRadius > 12 ? 999 : s.borderRadius / 2,
                fontSize: 13, fontWeight: s.fontWeight,
                fontFamily: s.fontFamily, letterSpacing: s.letterSpacing,
                boxShadow: plan.popular ? s.shadow : undefined,
              }}>
                {buttonText}
              </div>
            </div>
          )
        })}
      </div>
    </AbsoluteFill>
  )
}
