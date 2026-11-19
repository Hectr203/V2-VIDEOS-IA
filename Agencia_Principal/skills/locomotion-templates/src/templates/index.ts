import type { TemplateMeta } from './types'

// Template source code strings — self-contained, copy-paste ready
const fadeSlideUpSource = `import { AbsoluteFill, useCurrentFrame, interpolate } from 'remotion';

export const FadeSlideUp: React.FC<{ text?: string }> = ({ text = 'Hello World' }) => {
  const frame = useCurrentFrame();
  const opacity = interpolate(frame, [0, 20], [0, 1], { extrapolateRight: 'clamp' });
  const translateY = interpolate(frame, [0, 20], [24, 0], { extrapolateRight: 'clamp' });

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: '#fff' }}>
      <h1 style={{
        fontSize: 64,
        fontWeight: 600,
        color: '#171717',
        opacity,
        transform: \`translateY(\${translateY}px)\`,
        fontFamily: 'system-ui, sans-serif',
      }}>
        {text}
      </h1>
    </AbsoluteFill>
  );
};`

const springScaleInSource = `import { AbsoluteFill, useCurrentFrame, spring, useVideoConfig } from 'remotion';

export const SpringScaleIn: React.FC<{ text?: string }> = ({ text = 'Welcome' }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const scale = spring({ frame, fps, config: { stiffness: 200, damping: 12 } });
  const opacity = spring({ frame, fps, config: { stiffness: 300, damping: 20 } });

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: '#fff' }}>
      <h1 style={{
        fontSize: 72,
        fontWeight: 800,
        color: '#000',
        transform: \`scale(\${scale})\`,
        opacity,
        fontFamily: 'system-ui, sans-serif',
      }}>
        {text}
      </h1>
    </AbsoluteFill>
  );
};`

const typewriterSource = `import { AbsoluteFill, useCurrentFrame, interpolate } from 'remotion';

export const TypewriterReveal: React.FC<{ text?: string }> = ({ text = 'Building the future.' }) => {
  const frame = useCurrentFrame();
  const chars = Math.floor(interpolate(frame, [0, 70], [0, text.length], { extrapolateRight: 'clamp' }));
  const cursorOpacity = Math.round(frame / 8) % 2 === 0 ? 1 : 0;

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: '#fafafa' }}>
      <div style={{ fontFamily: 'ui-monospace, monospace', fontSize: 42, color: '#171717' }}>
        {text.slice(0, chars)}
        <span style={{ opacity: cursorOpacity, color: '#a3a3a3' }}>|</span>
      </div>
    </AbsoluteFill>
  );
};`

const staggeredWordsSource = `import { AbsoluteFill, useCurrentFrame, spring, useVideoConfig } from 'remotion';

export const StaggeredWords: React.FC<{ text?: string }> = ({ text = 'Design. Build. Ship.' }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const words = text.split(' ');

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: '#fff', gap: 12 }}>
      <div style={{ display: 'flex', gap: 16, flexWrap: 'wrap', justifyContent: 'center' }}>
        {words.map((word, i) => {
          const delay = i * 6;
          const opacity = spring({ frame: frame - delay, fps, config: { stiffness: 200, damping: 15 } });
          const y = interpolate(opacity, [0, 1], [16, 0]);
          return (
            <span key={i} style={{
              fontSize: 56, fontWeight: 600, color: '#171717',
              opacity, transform: \`translateY(\${y}px)\`,
              fontFamily: 'system-ui, sans-serif',
            }}>
              {word}
            </span>
          );
        })}
      </div>
    </AbsoluteFill>
  );
};

import { interpolate } from 'remotion';`

const modalExplainerSource = `import { AbsoluteFill, useCurrentFrame, spring, interpolate, useVideoConfig } from 'remotion';

export const ModalExplainer: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const backdropOpacity = interpolate(frame, [0, 15], [0, 0.5], { extrapolateRight: 'clamp' });
  const modalScale = spring({ frame: frame - 5, fps, config: { stiffness: 200, damping: 18 } });
  const modalOpacity = interpolate(frame, [5, 20], [0, 1], { extrapolateRight: 'clamp' });

  const steps = ['Connect your account', 'Choose a template', 'Customize & export'];
  const stepStyles = steps.map((_, i) => {
    const delay = 30 + i * 15;
    const progress = spring({ frame: frame - delay, fps, config: { stiffness: 180, damping: 14 } });
    return { opacity: progress, y: interpolate(progress, [0, 1], [12, 0]) };
  });

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: '#f5f5f5' }}>
      <div style={{ position: 'absolute', inset: 0, backgroundColor: \`rgba(0,0,0,\${backdropOpacity})\` }} />
      <div style={{
        width: 420, backgroundColor: '#fff', borderRadius: 16, padding: 32,
        transform: \`scale(\${modalScale})\`, opacity: modalOpacity,
        boxShadow: '0 24px 48px rgba(0,0,0,0.12)',
      }}>
        <h2 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8, color: '#171717', fontFamily: 'system-ui' }}>How it works</h2>
        <p style={{ fontSize: 14, color: '#737373', marginBottom: 24, fontFamily: 'system-ui' }}>Get started in three simple steps</p>
        {steps.map((step, i) => (
          <div key={i} style={{
            display: 'flex', alignItems: 'center', gap: 12, padding: '12px 0',
            borderTop: i > 0 ? '1px solid #f5f5f5' : 'none',
            opacity: stepStyles[i].opacity,
            transform: \`translateY(\${stepStyles[i].y}px)\`,
          }}>
            <div style={{
              width: 28, height: 28, borderRadius: 8, backgroundColor: '#f5f5f5',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              fontSize: 13, fontWeight: 600, color: '#525252', fontFamily: 'system-ui',
            }}>{i + 1}</div>
            <span style={{ fontSize: 15, color: '#262626', fontFamily: 'system-ui' }}>{step}</span>
          </div>
        ))}
      </div>
    </AbsoluteFill>
  );
};`

const dragDropSource = `import { AbsoluteFill, useCurrentFrame, spring, interpolate, useVideoConfig } from 'remotion';

export const DragDropDemo: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const items = ['Design', 'Develop', 'Deploy'];
  const targetX = 280;
  const startX = 40;

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: '#fff' }}>
      {/* Source area */}
      <div style={{ position: 'absolute', left: 40, top: '50%', transform: 'translateY(-50%)' }}>
        {items.map((item, i) => {
          const moveStart = 20 + i * 30;
          const progress = spring({ frame: frame - moveStart, fps, config: { stiffness: 120, damping: 14 } });
          const x = interpolate(progress, [0, 1], [0, targetX - startX + 20]);
          const opacity = frame < moveStart ? 1 : interpolate(progress, [0, 0.5, 1], [1, 0.6, 1]);

          return (
            <div key={i} style={{
              padding: '10px 20px', marginBottom: 8, borderRadius: 10,
              border: '1px solid #e5e5e5', backgroundColor: '#fafafa',
              fontSize: 15, fontWeight: 500, color: '#262626',
              transform: \`translateX(\${x}px)\`, opacity,
              fontFamily: 'system-ui',
            }}>
              {item}
            </div>
          );
        })}
      </div>

      {/* Target area */}
      <div style={{
        position: 'absolute', right: 80, top: '50%', transform: 'translateY(-50%)',
        width: 180, minHeight: 160, border: '2px dashed #d4d4d4', borderRadius: 12,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        fontSize: 13, color: '#a3a3a3', fontFamily: 'system-ui',
      }}>
        Drop here
      </div>

      {/* Animated cursor */}
      {frame > 15 && (
        <div style={{
          position: 'absolute',
          left: interpolate(frame, [15, 40, 50, 80, 90, 120], [80, 340, 80, 340, 80, 340], { extrapolateRight: 'clamp' }),
          top: interpolate(frame, [15, 40, 50, 80, 90, 120], [200, 200, 230, 230, 260, 260], { extrapolateRight: 'clamp' }),
          width: 16, height: 16, borderRadius: 999,
          backgroundColor: '#000', opacity: 0.6,
        }} />
      )}
    </AbsoluteFill>
  );
};`

const featureShowcaseSource = `import { AbsoluteFill, useCurrentFrame, spring, interpolate, useVideoConfig } from 'remotion';

export const FeatureShowcase: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const features = [
    { icon: '\\u26A1', title: 'Lightning Fast', desc: 'Built for performance' },
    { icon: '\\uD83D\\uDD12', title: 'Secure by Default', desc: 'Enterprise-grade security' },
    { icon: '\\uD83D\\uDE80', title: 'Ship Faster', desc: 'From idea to production' },
  ];

  const titleProgress = spring({ frame, fps, config: { stiffness: 200, damping: 20 } });
  const titleY = interpolate(titleProgress, [0, 1], [20, 0]);

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: '#fff', padding: 60 }}>
      <h2 style={{
        fontSize: 36, fontWeight: 700, color: '#171717', marginBottom: 40,
        opacity: titleProgress, transform: \`translateY(\${titleY}px)\`,
        fontFamily: 'system-ui',
      }}>
        Everything you need
      </h2>
      <div style={{ display: 'flex', gap: 20 }}>
        {features.map((f, i) => {
          const delay = 15 + i * 10;
          const s = spring({ frame: frame - delay, fps, config: { stiffness: 180, damping: 15 } });
          return (
            <div key={i} style={{
              width: 200, padding: 24, borderRadius: 16, border: '1px solid #e5e5e5',
              opacity: s, transform: \`translateY(\${interpolate(s, [0, 1], [20, 0])}px)\`,
            }}>
              <div style={{ fontSize: 28, marginBottom: 12 }}>{f.icon}</div>
              <h3 style={{ fontSize: 16, fontWeight: 600, color: '#171717', marginBottom: 4, fontFamily: 'system-ui' }}>{f.title}</h3>
              <p style={{ fontSize: 13, color: '#737373', fontFamily: 'system-ui' }}>{f.desc}</p>
            </div>
          );
        })}
      </div>
    </AbsoluteFill>
  );
};`

const pricingComparisonSource = `import { AbsoluteFill, useCurrentFrame, spring, interpolate, useVideoConfig } from 'remotion';

export const PricingComparison: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const plans = [
    { name: 'Starter', price: '$9', features: ['5 projects', 'Basic analytics'] },
    { name: 'Pro', price: '$29', features: ['Unlimited projects', 'Advanced analytics'], popular: true },
    { name: 'Enterprise', price: '$99', features: ['Everything in Pro', 'Priority support'] },
  ];

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: '#fafafa', gap: 16 }}>
      <div style={{ display: 'flex', gap: 16, alignItems: 'stretch' }}>
        {plans.map((plan, i) => {
          const delay = 5 + i * 8;
          const s = spring({ frame: frame - delay, fps, config: { stiffness: 200, damping: 16 } });
          const highlight = plan.popular && frame > 40;
          const pulseScale = plan.popular
            ? 1 + 0.02 * Math.sin((frame - 40) * 0.1) * (frame > 40 ? 1 : 0)
            : 1;

          return (
            <div key={i} style={{
              width: 190, padding: 24, borderRadius: 16,
              backgroundColor: '#fff',
              border: plan.popular ? '2px solid #171717' : '1px solid #e5e5e5',
              opacity: s, transform: \`translateY(\${interpolate(s, [0,1], [24,0])}px) scale(\${pulseScale})\`,
            }}>
              {plan.popular && (
                <div style={{ fontSize: 11, fontWeight: 600, color: '#fff', backgroundColor: '#171717', borderRadius: 999, padding: '3px 10px', marginBottom: 12, display: 'inline-block', fontFamily: 'system-ui' }}>
                  Popular
                </div>
              )}
              <h3 style={{ fontSize: 18, fontWeight: 600, color: '#171717', fontFamily: 'system-ui' }}>{plan.name}</h3>
              <div style={{ fontSize: 36, fontWeight: 800, color: '#000', margin: '8px 0', fontFamily: 'system-ui' }}>{plan.price}<span style={{ fontSize: 14, color: '#737373', fontWeight: 400 }}>/mo</span></div>
              {plan.features.map((f, j) => (
                <div key={j} style={{ fontSize: 13, color: '#525252', padding: '4px 0', fontFamily: 'system-ui' }}>{f}</div>
              ))}
            </div>
          );
        })}
      </div>
    </AbsoluteFill>
  );
};`

const onboardingFlowSource = `import { AbsoluteFill, useCurrentFrame, spring, interpolate, useVideoConfig } from 'remotion';

export const OnboardingFlow: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const steps = ['Create account', 'Set up workspace', 'Invite your team', 'Start building'];

  const progressWidth = interpolate(frame, [0, 120], [0, 100], { extrapolateRight: 'clamp' });

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: '#fff', padding: 60 }}>
      <div style={{ width: 400 }}>
        <h2 style={{ fontSize: 28, fontWeight: 700, color: '#171717', marginBottom: 24, fontFamily: 'system-ui' }}>Get started</h2>

        {/* Progress bar */}
        <div style={{ height: 3, backgroundColor: '#f5f5f5', borderRadius: 2, marginBottom: 32, overflow: 'hidden' }}>
          <div style={{ height: '100%', width: \`\${progressWidth}%\`, backgroundColor: '#171717', borderRadius: 2 }} />
        </div>

        {steps.map((step, i) => {
          const checkFrame = 10 + i * 25;
          const checked = frame > checkFrame;
          const checkScale = spring({ frame: frame - checkFrame, fps, config: { stiffness: 300, damping: 20 } });

          return (
            <div key={i} style={{
              display: 'flex', alignItems: 'center', gap: 12, padding: '14px 0',
              borderBottom: '1px solid #f5f5f5',
            }}>
              <div style={{
                width: 22, height: 22, borderRadius: 6,
                border: checked ? 'none' : '1.5px solid #d4d4d4',
                backgroundColor: checked ? '#171717' : 'transparent',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                transform: \`scale(\${checked ? checkScale : 1})\`,
              }}>
                {checked && <span style={{ color: '#fff', fontSize: 12 }}>\\u2713</span>}
              </div>
              <span style={{
                fontSize: 15, color: checked ? '#171717' : '#a3a3a3', fontWeight: checked ? 500 : 400,
                textDecoration: checked && frame > checkFrame + 10 ? 'line-through' : 'none',
                fontFamily: 'system-ui',
              }}>
                {step}
              </span>
            </div>
          );
        })}
      </div>
    </AbsoluteFill>
  );
};`

const saasHeroSource = `import { AbsoluteFill, useCurrentFrame, spring, interpolate, useVideoConfig } from 'remotion';

export const SaasHero: React.FC<{ title?: string }> = ({ title = 'Ship faster with AI' }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const titleScale = spring({ frame, fps, config: { stiffness: 160, damping: 18 } });
  const titleY = interpolate(titleScale, [0, 1], [30, 0]);

  const subtitleProgress = spring({ frame: frame - 10, fps, config: { stiffness: 200, damping: 20 } });
  const subtitleY = interpolate(subtitleProgress, [0, 1], [16, 0]);

  const stats = [
    { value: '10K+', label: 'Users' },
    { value: '99.9%', label: 'Uptime' },
    { value: '< 50ms', label: 'Latency' },
  ];

  const buttonProgress = spring({ frame: frame - 25, fps, config: { stiffness: 200, damping: 16 } });

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', backgroundColor: '#fff', padding: 40 }}>
      <h1 style={{
        fontSize: 52, fontWeight: 800, color: '#000', textAlign: 'center',
        opacity: titleScale, transform: \`translateY(\${titleY}px)\`,
        fontFamily: 'system-ui', letterSpacing: '-0.02em',
      }}>{title}</h1>
      <p style={{
        fontSize: 18, color: '#737373', marginTop: 12, textAlign: 'center',
        opacity: subtitleProgress, transform: \`translateY(\${subtitleY}px)\`,
        fontFamily: 'system-ui',
      }}>The platform teams love to build on</p>

      <div style={{ display: 'flex', gap: 40, marginTop: 32 }}>
        {stats.map((stat, i) => {
          const delay = 15 + i * 6;
          const s = spring({ frame: frame - delay, fps, config: { stiffness: 180, damping: 15 } });
          const count = stat.value.includes('+')
            ? Math.round(interpolate(s, [0, 1], [0, parseInt(stat.value)])).toLocaleString() + '+'
            : stat.value;
          return (
            <div key={i} style={{ textAlign: 'center', opacity: s }}>
              <div style={{ fontSize: 28, fontWeight: 700, color: '#171717', fontFamily: 'system-ui' }}>{count}</div>
              <div style={{ fontSize: 13, color: '#a3a3a3', fontFamily: 'system-ui' }}>{stat.label}</div>
            </div>
          );
        })}
      </div>

      <div style={{
        marginTop: 32, padding: '12px 28px', backgroundColor: '#000', color: '#fff',
        borderRadius: 999, fontSize: 15, fontWeight: 600,
        opacity: buttonProgress, transform: \`scale(\${buttonProgress})\`,
        fontFamily: 'system-ui',
      }}>
        Get started free \\u2192
      </div>
    </AbsoluteFill>
  );
};`

export const templates: TemplateMeta[] = [
  {
    id: 'fade-slide-up',
    name: 'Fade Slide Up',
    componentName: 'FadeSlideUp',
    description: 'Classic fade-in with upward slide. The essential text entrance animation.',
    duration: 1,
    category: 'Text',
    tags: ['fade', 'slide', 'entrance', 'text'],
    fps: 30,
    durationInFrames: 30,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/fade-slide-up.mp4',
    source: fadeSlideUpSource,
    editableProps: [
      { key: 'text', type: 'string', label: 'Text', defaultValue: 'Hello World', placeholder: 'Enter display text' },
    ],
  },
  {
    id: 'spring-scale-in',
    name: 'Spring Scale In',
    componentName: 'SpringScaleIn',
    description: 'Bouncy spring scale entrance for headlines and hero text.',
    duration: 1,
    category: 'Text',
    tags: ['spring', 'scale', 'bounce', 'headline'],
    fps: 30,
    durationInFrames: 30,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/spring-scale-in.mp4',
    source: springScaleInSource,
    editableProps: [
      { key: 'text', type: 'string', label: 'Text', defaultValue: 'Welcome', placeholder: 'Enter headline text' },
    ],
  },
  {
    id: 'typewriter-reveal',
    name: 'Typewriter Reveal',
    componentName: 'TypewriterReveal',
    description: 'Character-by-character typewriter effect with blinking cursor.',
    duration: 3,
    category: 'Text',
    tags: ['typewriter', 'text', 'reveal', 'cursor'],
    fps: 30,
    durationInFrames: 90,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/typewriter-reveal.mp4',
    source: typewriterSource,
    editableProps: [
      { key: 'text', type: 'string', label: 'Text', defaultValue: 'Building the future.', placeholder: 'Enter typewriter text' },
    ],
  },
  {
    id: 'staggered-words',
    name: 'Staggered Words',
    componentName: 'StaggeredWords',
    description: 'Words fade in one by one with spring physics for natural rhythm.',
    duration: 3,
    category: 'Text',
    tags: ['stagger', 'words', 'spring', 'sequence'],
    fps: 30,
    durationInFrames: 90,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/staggered-words.mp4',
    source: staggeredWordsSource,
    editableProps: [
      { key: 'text', type: 'string', label: 'Text', defaultValue: 'Design. Build. Ship.', placeholder: 'Enter words (space separated)' },
    ],
  },
  {
    id: 'modal-explainer',
    name: 'Modal Explainer',
    componentName: 'ModalExplainer',
    description: '"How it Works" modal with backdrop, spring entrance, and stepped content reveal.',
    duration: 5,
    category: 'SaaS',
    tags: ['modal', 'explainer', 'steps', 'how-it-works'],
    fps: 30,
    durationInFrames: 150,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/modal-explainer.mp4',
    source: modalExplainerSource,
    editableProps: [
      { key: 'title', type: 'string' as const, label: 'Title', defaultValue: 'How it works' },
      { key: 'subtitle', type: 'string' as const, label: 'Subtitle', defaultValue: 'Get started in three simple steps' },
      { key: 'steps', type: 'string' as const, label: 'Step names (comma-separated)', defaultValue: 'Connect,Choose,Launch' },
      { key: 'stepDescriptions', type: 'string' as const, label: 'Step descriptions (comma-separated)', defaultValue: 'Link your account in one click,Pick a template that fits,Go live in minutes' },
    ],
  },
  {
    id: 'drag-drop-demo',
    name: 'Drag & Drop Demo',
    componentName: 'DragDropDemo',
    description: 'Page builder blocks slide into place with spring landing and success checkmark.',
    duration: 5,
    category: 'SaaS',
    tags: ['drag', 'drop', 'builder', 'interaction'],
    fps: 30,
    durationInFrames: 150,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/drag-drop-demo.mp4',
    source: dragDropSource,
    editableProps: [],
  },
  {
    id: 'feature-showcase',
    name: 'Feature Showcase',
    componentName: 'FeatureShowcase',
    description: 'Three feature cards fly in with staggered spring animation and icons.',
    duration: 5,
    category: 'SaaS',
    tags: ['features', 'cards', 'showcase', 'stagger'],
    fps: 30,
    durationInFrames: 150,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/feature-showcase.mp4',
    source: featureShowcaseSource,
    editableProps: [
      { key: 'title', type: 'string' as const, label: 'Title', defaultValue: 'Everything you need' },
      { key: 'features', type: 'string' as const, label: 'Feature names (comma-separated)', defaultValue: 'Fast,Secure,Ship it' },
      { key: 'descriptions', type: 'string' as const, label: 'Descriptions (comma-separated)', defaultValue: 'Built for speed,Enterprise ready,Idea to prod' },
    ],
  },
  {
    id: 'pricing-comparison',
    name: 'Pricing Comparison',
    componentName: 'PricingComparison',
    description: 'Animated pricing table with highlighted popular plan and subtle pulse.',
    duration: 3,
    category: 'SaaS',
    tags: ['pricing', 'table', 'comparison', 'plans'],
    fps: 30,
    durationInFrames: 90,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/pricing-comparison.mp4',
    source: pricingComparisonSource,
    editableProps: [
      { key: 'planNames', type: 'string' as const, label: 'Plan names', defaultValue: 'Starter,Pro,Team' },
      { key: 'planPrices', type: 'string' as const, label: 'Plan prices', defaultValue: '$9,$29,$99' },
      { key: 'planFeatures', type: 'string' as const, label: 'Features (pipe-separated per plan)', defaultValue: '5 projects|Basic,Unlimited|Analytics,Everything|Support' },
      { key: 'buttonText', type: 'string' as const, label: 'Button text', defaultValue: 'Get started' },
    ],
  },
  {
    id: 'onboarding-flow',
    name: 'Onboarding Flow',
    componentName: 'OnboardingFlow',
    description: 'Step-by-step checklist with progress bar and spring checkmarks.',
    duration: 5,
    category: 'SaaS',
    tags: ['onboarding', 'checklist', 'progress', 'steps'],
    fps: 30,
    durationInFrames: 150,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/onboarding-flow.mp4',
    source: onboardingFlowSource,
    editableProps: [
      { key: 'title', type: 'string' as const, label: 'Title', defaultValue: 'Get started' },
      { key: 'steps', type: 'string' as const, label: 'Steps (comma-separated)', defaultValue: 'Create account,Set up workspace,Invite team,Start building' },
    ],
  },
  {
    id: 'saas-hero',
    name: 'SaaS Hero',
    componentName: 'SaasHero',
    description: 'Hero section with animated stats counter, headline spring-in, and CTA button.',
    duration: 3,
    category: 'SaaS',
    tags: ['hero', 'stats', 'counter', 'cta'],
    fps: 30,
    durationInFrames: 90,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/saas-hero.mp4',
    source: saasHeroSource,
    editableProps: [
      { key: 'title', type: 'string', label: 'Title', defaultValue: 'Ship faster with AI', placeholder: 'Enter hero title' },
    ],
  },
  // --- Explainer ---
  {
    id: 'step-explainer',
    name: 'Step Explainer',
    componentName: 'StepExplainer',
    description: 'Numbered steps with animated underlines. Perfect for "How it works" sections.',
    duration: 3,
    category: 'Explainer',
    tags: ['steps', 'how-it-works', 'numbered', 'process'],
    fps: 30,
    durationInFrames: 90,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/step-explainer.mp4',
    source: '// Step Explainer template — see Composition.tsx',
    editableProps: [
      { key: 'title', type: 'string', label: 'Title', defaultValue: 'How it works', placeholder: 'Enter section title' },
    ],
  },
  {
    id: 'concept-breakdown',
    name: 'Concept Breakdown',
    componentName: 'ConceptBreakdown',
    description: '"What is X?" explainer with bullet points that fade in sequentially.',
    duration: 4,
    category: 'Explainer',
    tags: ['concept', 'definition', 'bullets', 'educational'],
    fps: 30,
    durationInFrames: 120,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/concept-breakdown.mp4',
    source: '// Concept Breakdown template — see Composition.tsx',
    editableProps: [
      { key: 'title', type: 'string', label: 'Title', defaultValue: 'What is AI?', placeholder: 'What is...?' },
    ],
  },
  // --- Data ---
  {
    id: 'bar-chart-reveal',
    name: 'Bar Chart Reveal',
    componentName: 'BarChartReveal',
    description: 'Animated bar chart with spring-loaded bars rising from zero.',
    duration: 3,
    category: 'Data',
    tags: ['chart', 'bar', 'data', 'revenue', 'growth'],
    fps: 30,
    durationInFrames: 90,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/bar-chart-reveal.mp4',
    source: '// Bar Chart Reveal template — see Composition.tsx',
    editableProps: [],
  },
  {
    id: 'stats-dashboard',
    name: 'Stats Dashboard',
    componentName: 'StatsDashboard',
    description: 'Four-card metrics grid with animated counters. Users, revenue, growth, NPS.',
    duration: 3,
    category: 'Data',
    tags: ['stats', 'dashboard', 'metrics', 'kpi', 'counter'],
    fps: 30,
    durationInFrames: 90,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/stats-dashboard.mp4',
    source: '// Stats Dashboard template — see Composition.tsx',
    editableProps: [
      { key: 'labels', type: 'string' as const, label: 'Metric labels (comma-separated)', defaultValue: 'Users,Revenue,Growth,NPS' },
      { key: 'values', type: 'string' as const, label: 'Values (e.g. 12847,$84K,127%,72)', defaultValue: '12847,$84K,127%,72' },
    ],
  },
  // --- Social ---
  {
    id: 'bold-text-punch',
    name: 'Bold Text Punch',
    componentName: 'BoldTextPunch',
    description: 'Impact text on dark background with scale-in and shake. Made for social clips.',
    duration: 1,
    category: 'Social',
    tags: ['bold', 'impact', 'social', 'short', 'dark'],
    fps: 30,
    durationInFrames: 30,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/bold-text-punch.mp4',
    source: '// Bold Text Punch template — see Composition.tsx',
    editableProps: [
      { key: 'text', type: 'string', label: 'Text', defaultValue: 'Stop scrolling.', placeholder: 'Enter impact text' },
    ],
  },
  {
    id: 'quote-card',
    name: 'Quote Card',
    componentName: 'QuoteCard',
    description: 'Testimonial quote card with author avatar. Great for social proof clips.',
    duration: 3,
    category: 'Social',
    tags: ['quote', 'testimonial', 'social-proof', 'card'],
    fps: 30,
    durationInFrames: 90,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/quote-card.mp4',
    source: '// Quote Card template — see Composition.tsx',
    editableProps: [
      { key: 'text', type: 'string', label: 'Quote', defaultValue: 'This changed everything for our team.', placeholder: 'Enter testimonial' },
    ],
  },
  // --- Branding ---
  {
    id: 'logo-reveal',
    name: 'Logo Reveal',
    componentName: 'LogoReveal',
    description: 'Logo mark scales in with expanding ring, then company name fades up.',
    duration: 2,
    category: 'Branding',
    tags: ['logo', 'reveal', 'brand', 'intro'],
    fps: 30,
    durationInFrames: 60,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/logo-reveal.mp4',
    source: '// Logo Reveal template — see Composition.tsx',
    editableProps: [
      { key: 'text', type: 'string', label: 'Brand Name', defaultValue: 'Acme', placeholder: 'Your brand name' },
    ],
  },
  {
    id: 'intro-outro',
    name: 'Intro / Outro',
    componentName: 'IntroOutro',
    description: 'Cinematic dark card with decorative lines. Works as video intro or outro.',
    duration: 3,
    category: 'Branding',
    tags: ['intro', 'outro', 'end-screen', 'cinematic'],
    fps: 30,
    durationInFrames: 90,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/intro-outro.mp4',
    source: '// Intro Outro template — see Composition.tsx',
    editableProps: [
      { key: 'text', type: 'string', label: 'Text', defaultValue: 'Thanks for watching', placeholder: 'Closing message' },
    ],
  },
  // --- Product ---
  {
    id: 'app-feature-callout',
    name: 'App Feature Callout',
    componentName: 'AppFeatureCallout',
    description: 'App mockup with highlighted feature area and floating callout badge.',
    duration: 3,
    category: 'Product',
    tags: ['app', 'feature', 'callout', 'ui', 'mockup'],
    fps: 30,
    durationInFrames: 90,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/app-feature-callout.mp4',
    source: '// App Feature Callout template — see Composition.tsx',
    editableProps: [
      { key: 'text', type: 'string', label: 'Feature', defaultValue: 'Real-time collaboration', placeholder: 'Feature name' },
    ],
  },
  {
    id: 'ui-walkthrough',
    name: 'UI Walkthrough',
    componentName: 'UiWalkthrough',
    description: 'Animated cursor walks through 3 steps on an app mockup with tooltips.',
    duration: 4,
    category: 'Product',
    tags: ['walkthrough', 'tutorial', 'cursor', 'ui', 'demo'],
    fps: 30,
    durationInFrames: 120,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/ui-walkthrough.mp4',
    source: '// UI Walkthrough template — see Composition.tsx',
    editableProps: [],
  },
  // --- E-commerce ---
  {
    id: 'product-reveal',
    name: 'Product Reveal',
    componentName: 'ProductReveal',
    description: 'Cinematic product unveil with smooth zoom and text overlay for launches.',
    duration: 3,
    category: 'E-commerce',
    tags: ['product', 'reveal', 'launch', 'e-commerce'],
    fps: 30,
    durationInFrames: 90,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/product-reveal.mp4',
    source: '// ProductReveal template — see Composition.tsx',
    editableProps: [
      { key: 'text', type: 'string', label: 'Product Name', defaultValue: 'New AirPods Pro', placeholder: 'Enter product name' },
    ],
  },
  {
    id: 'discount-countdown',
    name: 'Discount Countdown',
    componentName: 'DiscountCountdown',
    description: 'Urgency-driven discount banner with animated countdown and bold offer text.',
    duration: 3,
    category: 'E-commerce',
    tags: ['discount', 'countdown', 'sale', 'urgency'],
    fps: 30,
    durationInFrames: 90,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/discount-countdown.mp4',
    source: '// DiscountCountdown template — see Composition.tsx',
    editableProps: [
      { key: 'text', type: 'string', label: 'Offer Text', defaultValue: '50% OFF', placeholder: 'Enter discount text' },
    ],
  },
  {
    id: 'cart-animation',
    name: 'Cart Animation',
    componentName: 'CartAnimation',
    description: 'Add-to-cart interaction with item flying into basket and count badge updating.',
    duration: 3,
    category: 'E-commerce',
    tags: ['cart', 'shopping', 'add-to-cart', 'interaction'],
    fps: 30,
    durationInFrames: 90,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/cart-animation.mp4',
    source: '// CartAnimation template — see Composition.tsx',
    editableProps: [
      { key: 'title', type: 'string' as const, label: 'Title', defaultValue: 'Your Cart' },
      { key: 'items', type: 'string' as const, label: 'Items (comma-separated)', defaultValue: 'Sneakers,T-Shirt,Cap' },
      { key: 'buttonText', type: 'string' as const, label: 'Button Text', defaultValue: 'Checkout' },
    ],
  },
  // --- Education ---
  {
    id: 'lesson-intro',
    name: 'Lesson Intro',
    componentName: 'LessonIntro',
    description: 'Animated lesson title card with chapter number and subject line.',
    duration: 3,
    category: 'Education',
    tags: ['lesson', 'intro', 'course', 'education'],
    fps: 30,
    durationInFrames: 90,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/lesson-intro.mp4',
    source: '// LessonIntro template — see Composition.tsx',
    editableProps: [
      { key: 'text', type: 'string', label: 'Lesson Title', defaultValue: 'Lesson 3: Variables', placeholder: 'Enter lesson title' },
    ],
  },
  {
    id: 'flashcard-flip',
    name: 'Flashcard Flip',
    componentName: 'FlashcardFlip',
    description: '3D card flip revealing answer on the back. Great for study content.',
    duration: 3,
    category: 'Education',
    tags: ['flashcard', 'flip', 'study', 'quiz'],
    fps: 30,
    durationInFrames: 90,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/flashcard-flip.mp4',
    source: '// FlashcardFlip template — see Composition.tsx',
    editableProps: [
      { key: 'text', type: 'string', label: 'Term', defaultValue: 'Photosynthesis', placeholder: 'Enter flashcard term' },
    ],
  },
  {
    id: 'quiz-result',
    name: 'Quiz Result',
    componentName: 'QuizResult',
    description: 'Animated score reveal with progress ring and pass/fail feedback.',
    duration: 3,
    category: 'Education',
    tags: ['quiz', 'result', 'score', 'assessment'],
    fps: 30,
    durationInFrames: 90,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/quiz-result.mp4',
    source: '// QuizResult template — see Composition.tsx',
    editableProps: [],
  },
  // --- Finance ---
  {
    id: 'stock-ticker',
    name: 'Stock Ticker',
    componentName: 'StockTicker',
    description: 'Scrolling stock ticker with price changes and directional arrows.',
    duration: 3,
    category: 'Finance',
    tags: ['stock', 'ticker', 'market', 'trading'],
    fps: 30,
    durationInFrames: 90,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/stock-ticker.mp4',
    source: '// StockTicker template — see Composition.tsx',
    editableProps: [],
  },
  {
    id: 'portfolio-breakdown',
    name: 'Portfolio Breakdown',
    componentName: 'PortfolioBreakdown',
    description: 'Animated donut chart breaking down portfolio allocation by asset class.',
    duration: 3,
    category: 'Finance',
    tags: ['portfolio', 'allocation', 'chart', 'investment'],
    fps: 30,
    durationInFrames: 90,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/portfolio-breakdown.mp4',
    source: '// PortfolioBreakdown template — see Composition.tsx',
    editableProps: [],
  },
  {
    id: 'payment-flow',
    name: 'Payment Flow',
    componentName: 'PaymentFlow',
    description: 'Step-by-step payment process animation from checkout to confirmation.',
    duration: 3,
    category: 'Finance',
    tags: ['payment', 'checkout', 'transaction', 'flow'],
    fps: 30,
    durationInFrames: 90,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/payment-flow.mp4',
    source: '// PaymentFlow template — see Composition.tsx',
    editableProps: [],
  },
  // --- Healthcare ---
  {
    id: 'patient-journey',
    name: 'Patient Journey',
    componentName: 'PatientJourney',
    description: 'Timeline animation showing the patient care journey from intake to follow-up.',
    duration: 3,
    category: 'Healthcare',
    tags: ['patient', 'journey', 'timeline', 'healthcare'],
    fps: 30,
    durationInFrames: 90,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/patient-journey.mp4',
    source: '// PatientJourney template — see Composition.tsx',
    editableProps: [],
  },
  {
    id: 'appointment-booking',
    name: 'Appointment Booking',
    componentName: 'AppointmentBooking',
    description: 'Calendar interaction showing date selection and booking confirmation.',
    duration: 3,
    category: 'Healthcare',
    tags: ['appointment', 'booking', 'calendar', 'scheduling'],
    fps: 30,
    durationInFrames: 90,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/appointment-booking.mp4',
    source: '// AppointmentBooking template — see Composition.tsx',
    editableProps: [],
  },
  {
    id: 'wellness-stats',
    name: 'Wellness Stats',
    componentName: 'WellnessStats',
    description: 'Health metrics dashboard with animated heart rate, steps, and sleep data.',
    duration: 3,
    category: 'Healthcare',
    tags: ['wellness', 'health', 'stats', 'metrics'],
    fps: 30,
    durationInFrames: 90,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/wellness-stats.mp4',
    source: '// WellnessStats template — see Composition.tsx',
    editableProps: [],
  },
  // --- Real Estate ---
  {
    id: 'property-tour',
    name: 'Property Tour',
    componentName: 'PropertyTour',
    description: 'Animated property card with address reveal and key details sliding in.',
    duration: 3,
    category: 'Real Estate',
    tags: ['property', 'tour', 'real-estate', 'listing'],
    fps: 30,
    durationInFrames: 90,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/property-tour.mp4',
    source: '// PropertyTour template — see Composition.tsx',
    editableProps: [
      { key: 'text', type: 'string', label: 'Address', defaultValue: '42 Oak Avenue', placeholder: 'Enter property address' },
    ],
  },
  {
    id: 'listing-card',
    name: 'Listing Card',
    componentName: 'ListingCard',
    description: 'Real estate listing card with price, beds/baths, and photo placeholder.',
    duration: 3,
    category: 'Real Estate',
    tags: ['listing', 'card', 'property', 'price'],
    fps: 30,
    durationInFrames: 90,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/listing-card.mp4',
    source: '// ListingCard template — see Composition.tsx',
    editableProps: [],
  },
  {
    id: 'virtual-walkthrough',
    name: 'Virtual Walkthrough',
    componentName: 'VirtualWalkthrough',
    description: 'Simulated room-to-room walkthrough with smooth pan and fade transitions.',
    duration: 4,
    category: 'Real Estate',
    tags: ['walkthrough', 'virtual', 'tour', '3d'],
    fps: 30,
    durationInFrames: 120,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/virtual-walkthrough.mp4',
    source: '// VirtualWalkthrough template — see Composition.tsx',
    editableProps: [],
  },
  // --- Recruitment ---
  {
    id: 'job-posting',
    name: 'Job Posting',
    componentName: 'JobPosting',
    description: 'Animated job listing with role title, company badge, and key requirements.',
    duration: 3,
    category: 'Recruitment',
    tags: ['job', 'posting', 'hiring', 'recruitment'],
    fps: 30,
    durationInFrames: 90,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/job-posting.mp4',
    source: '// JobPosting template — see Composition.tsx',
    editableProps: [
      { key: 'text', type: 'string', label: 'Job Title', defaultValue: 'Senior Engineer', placeholder: 'Enter job title' },
    ],
  },
  {
    id: 'team-intro',
    name: 'Team Intro',
    componentName: 'TeamIntro',
    description: 'Team member cards appearing with staggered spring animation and roles.',
    duration: 3,
    category: 'Recruitment',
    tags: ['team', 'intro', 'people', 'company'],
    fps: 30,
    durationInFrames: 90,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/team-intro.mp4',
    source: '// TeamIntro template — see Composition.tsx',
    editableProps: [],
  },
  {
    id: 'culture-reel',
    name: 'Culture Reel',
    componentName: 'CultureReel',
    description: 'Company culture showcase with tagline, value badges, and photo grid.',
    duration: 3,
    category: 'Recruitment',
    tags: ['culture', 'values', 'company', 'employer-brand'],
    fps: 30,
    durationInFrames: 90,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/culture-reel.mp4',
    source: '// CultureReel template — see Composition.tsx',
    editableProps: [
      { key: 'text', type: 'string', label: 'Tagline', defaultValue: 'Life at Acme', placeholder: 'Enter company tagline' },
    ],
  },
  // --- Events ---
  {
    id: 'countdown-timer',
    name: 'Countdown Timer',
    componentName: 'CountdownTimer',
    description: 'Event countdown with ticking digits and launch message.',
    duration: 3,
    category: 'Events',
    tags: ['countdown', 'timer', 'launch', 'event'],
    fps: 30,
    durationInFrames: 90,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/countdown-timer.mp4',
    source: '// CountdownTimer template — see Composition.tsx',
    editableProps: [
      { key: 'text', type: 'string', label: 'Message', defaultValue: 'Launching soon', placeholder: 'Enter countdown message' },
    ],
  },
  {
    id: 'agenda-reveal',
    name: 'Agenda Reveal',
    componentName: 'AgendaReveal',
    description: 'Agenda items appear one by one with time slots and session titles.',
    duration: 3,
    category: 'Events',
    tags: ['agenda', 'schedule', 'conference', 'event'],
    fps: 30,
    durationInFrames: 90,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/agenda-reveal.mp4',
    source: '// AgendaReveal template — see Composition.tsx',
    editableProps: [
      { key: 'text', type: 'string', label: 'Title', defaultValue: "Today's Agenda", placeholder: 'Enter agenda title' },
    ],
  },
  {
    id: 'speaker-card',
    name: 'Speaker Card',
    componentName: 'SpeakerCard',
    description: 'Speaker introduction card with name, title, and avatar placeholder.',
    duration: 3,
    category: 'Events',
    tags: ['speaker', 'card', 'conference', 'introduction'],
    fps: 30,
    durationInFrames: 90,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/speaker-card.mp4',
    source: '// SpeakerCard template — see Composition.tsx',
    editableProps: [
      { key: 'text', type: 'string', label: 'Speaker Name', defaultValue: 'Jane Smith', placeholder: 'Enter speaker name' },
    ],
  },
  // --- Gaming ---
  {
    id: 'achievement-unlock',
    name: 'Achievement Unlock',
    componentName: 'AchievementUnlock',
    description: 'Trophy pop-in with achievement title and glow effect for unlocked milestones.',
    duration: 3,
    category: 'Gaming',
    tags: ['achievement', 'unlock', 'trophy', 'gaming'],
    fps: 30,
    durationInFrames: 90,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/achievement-unlock.mp4',
    source: '// AchievementUnlock template — see Composition.tsx',
    editableProps: [
      { key: 'text', type: 'string' as const, label: 'Title', defaultValue: 'First Victory' },
      { key: 'subtitle', type: 'string' as const, label: 'Subtitle', defaultValue: 'Achievement Unlocked' },
      { key: 'reward', type: 'string' as const, label: 'Reward', defaultValue: '+500 XP' },
    ],
  },
  {
    id: 'leaderboard',
    name: 'Leaderboard',
    componentName: 'Leaderboard',
    description: 'Animated leaderboard with ranked player rows sliding in from the side.',
    duration: 3,
    category: 'Gaming',
    tags: ['leaderboard', 'ranking', 'scores', 'competition'],
    fps: 30,
    durationInFrames: 90,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/leaderboard.mp4',
    source: '// Leaderboard template — see Composition.tsx',
    editableProps: [],
  },
  {
    id: 'level-up',
    name: 'Level Up',
    componentName: 'LevelUp',
    description: 'Level-up celebration with number increment, particle burst, and glow ring.',
    duration: 3,
    category: 'Gaming',
    tags: ['level-up', 'celebration', 'progress', 'gaming'],
    fps: 30,
    durationInFrames: 90,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/level-up.mp4',
    source: '// LevelUp template — see Composition.tsx',
    editableProps: [],
  },
  {
    id: 'gradient-text',
    name: 'Gradient Text',
    componentName: 'GradientText',
    description: 'Large text with animated purple-to-gold gradient color sweep on dark or light background.',
    duration: 3,
    category: 'Text',
    tags: ['gradient', 'text', 'color-sweep', 'hero', 'announcement'],
    fps: 30,
    durationInFrames: 90,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/gradient-text.mp4',
    source: '// GradientText template — see Composition.tsx',
    editableProps: [
      { key: 'text', type: 'string' as const, label: 'Text', defaultValue: 'Captivating' },
      { key: 'bgColor', type: 'string' as const, label: 'Background', defaultValue: '#000000' },
    ],
  },
  {
    id: 'metric-card',
    name: 'Metric Card',
    componentName: 'MetricCard',
    description: 'Single stat card with rolling number counter, sparkline, bar chart, percentage badge, and confetti burst.',
    duration: 3,
    category: 'Data',
    tags: ['metric', 'counter', 'stats', 'mrr', 'revenue', 'sparkline', 'confetti'],
    fps: 30,
    durationInFrames: 90,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/metric-card.mp4',
    source: '// MetricCard template — see Composition.tsx',
    editableProps: [
      { key: 'label', type: 'string' as const, label: 'Metric label', defaultValue: 'MRR' },
      { key: 'value', type: 'string' as const, label: 'Value', defaultValue: '$12,450' },
      { key: 'change', type: 'string' as const, label: 'Change badge', defaultValue: '+37.18%' },
      { key: 'date', type: 'string' as const, label: 'Date', defaultValue: 'March 2026' },
      { key: 'bgColor', type: 'string' as const, label: 'Background', defaultValue: '#000000' },
    ],
  },
  {
    id: 'product-hunt',
    name: 'Product Hunt',
    componentName: 'ProductHunt',
    description: 'Product Hunt celebration with animated laurel wreath, rolling upvote counter, rank badge, and thank-you message.',
    duration: 3,
    category: 'Social',
    tags: ['product-hunt', 'launch', 'celebration', 'upvotes', 'social-proof'],
    fps: 30,
    durationInFrames: 90,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/product-hunt.mp4',
    source: '// ProductHunt template — see Composition.tsx',
    editableProps: [
      { key: 'rank', type: 'string' as const, label: 'Rank', defaultValue: '#1' },
      { key: 'upvotes', type: 'string' as const, label: 'Upvote count', defaultValue: '1,500' },
      { key: 'thankYouText', type: 'string' as const, label: 'Thank you text', defaultValue: 'Thank you for support' },
      { key: 'bgColor', type: 'string' as const, label: 'Background', defaultValue: '#ffffff' },
    ],
  },
  {
    id: 'milestone-counter',
    name: 'Milestone Counter',
    componentName: 'MilestoneCounter',
    description: 'Big rolling number counter with emoji icon on vibrant gradient background. Great for follower milestones and growth celebrations.',
    duration: 3,
    category: 'Social',
    tags: ['milestone', 'counter', 'followers', 'growth', 'celebration', 'emoji'],
    fps: 30,
    durationInFrames: 90,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/milestone-counter.mp4',
    source: '// MilestoneCounter template — see Composition.tsx',
    editableProps: [
      { key: 'label', type: 'string' as const, label: 'Label', defaultValue: 'Followers' },
      { key: 'value', type: 'string' as const, label: 'Value', defaultValue: '+1,300' },
      { key: 'emoji', type: 'string' as const, label: 'Emoji', defaultValue: '\uD83D\uDD25' },
      { key: 'bgColor', type: 'string' as const, label: 'Background', defaultValue: '#EC4899' },
    ],
  },
  {
    id: 'toggle-switch',
    name: 'Toggle Switch',
    componentName: 'ToggleSwitch',
    description: 'Oversized pill-shaped toggle that animates on with spring physics on a colorful gradient background.',
    duration: 3,
    category: 'Branding',
    tags: ['toggle', 'switch', 'ui', 'motion-graphic', 'interaction'],
    fps: 30,
    durationInFrames: 90,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/toggle-switch.mp4',
    source: '// ToggleSwitch template — see Composition.tsx',
    editableProps: [
      { key: 'text', type: 'string' as const, label: 'Label', defaultValue: 'Video' },
      { key: 'bgColor', type: 'string' as const, label: 'Background', defaultValue: '#9333EA' },
    ],
  },
  {
    id: 'testimonial-card',
    name: 'Testimonial Card',
    componentName: 'TestimonialCard',
    description: 'Customer testimonial with glassmorphic card, quote text, avatar, name, and role.',
    duration: 3,
    category: 'Social',
    tags: ['testimonial', 'review', 'quote', 'social-proof', 'customer'],
    fps: 30,
    durationInFrames: 90,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/testimonial-card.mp4',
    source: '// TestimonialCard template — see Composition.tsx',
    editableProps: [
      { key: 'quote', type: 'string' as const, label: 'Quote', defaultValue: 'This product completely changed how we work. The team shipped 3x faster in the first month.' },
      { key: 'name', type: 'string' as const, label: 'Name', defaultValue: 'Sarah Chen' },
      { key: 'role', type: 'string' as const, label: 'Role', defaultValue: 'CTO at Acme' },
      { key: 'bgColor', type: 'string' as const, label: 'Background', defaultValue: '#fafafa' },
    ],
  },
  {
    id: 'changelog',
    name: 'Changelog',
    componentName: 'Changelog',
    description: 'Version release changelog with version badge and animated feature list with check icons.',
    duration: 3,
    category: 'SaaS',
    tags: ['changelog', 'release', 'version', 'features', 'update'],
    fps: 30,
    durationInFrames: 90,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/changelog.mp4',
    source: '// Changelog template — see Composition.tsx',
    editableProps: [
      { key: 'version', type: 'string' as const, label: 'Version', defaultValue: 'v2.4.0' },
      { key: 'title', type: 'string' as const, label: 'Title', defaultValue: "What's new" },
      { key: 'features', type: 'string' as const, label: 'Features (comma-separated)', defaultValue: 'AI chat assistant,Drag-and-drop timeline,6 style variants,Code export' },
      { key: 'bgColor', type: 'string' as const, label: 'Background', defaultValue: '#ffffff' },
    ],
  },
  {
    id: 'bento-grid',
    name: 'Bento Grid',
    componentName: 'BentoGrid',
    description: 'Modern bento-box grid layout with items staggering in. Great for feature overviews.',
    duration: 3,
    category: 'Branding',
    tags: ['bento', 'grid', 'features', 'layout', 'overview'],
    fps: 30,
    durationInFrames: 90,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/bento-grid.mp4',
    source: '// BentoGrid template — see Composition.tsx',
    editableProps: [
      { key: 'items', type: 'string' as const, label: 'Items (comma-separated, max 6)', defaultValue: 'Analytics,Fast API,99.9% Uptime,Global CDN,Auth,Webhooks' },
      { key: 'bgColor', type: 'string' as const, label: 'Background', defaultValue: '#fafafa' },
    ],
  },
  {
    id: 'before-after',
    name: 'Before & After',
    componentName: 'BeforeAfter',
    description: 'Side-by-side comparison cards showing before and after states with transition animation.',
    duration: 3,
    category: 'Explainer',
    tags: ['before-after', 'comparison', 'transformation', 'contrast'],
    fps: 30,
    durationInFrames: 90,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/before-after.mp4',
    source: '// BeforeAfter template — see Composition.tsx',
    editableProps: [
      { key: 'beforeTitle', type: 'string' as const, label: 'Before label', defaultValue: 'Before' },
      { key: 'afterTitle', type: 'string' as const, label: 'After label', defaultValue: 'After' },
      { key: 'beforeItems', type: 'string' as const, label: 'Before items (comma-separated)', defaultValue: 'Manual deploys,No monitoring,Slow feedback' },
      { key: 'afterItems', type: 'string' as const, label: 'After items (comma-separated)', defaultValue: 'Auto CI/CD,Real-time alerts,Ship in minutes' },
      { key: 'bgColor', type: 'string' as const, label: 'Background', defaultValue: '#ffffff' },
    ],
  },
  {
    id: 'social-post',
    name: 'Social Post',
    componentName: 'SocialPost',
    description: 'Animated social media post card with avatar, text, rolling like count, retweets, and views.',
    duration: 3,
    category: 'Social',
    tags: ['social', 'post', 'twitter', 'x', 'announcement', 'likes'],
    fps: 30,
    durationInFrames: 90,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/social-post.mp4',
    source: '// SocialPost template — see Composition.tsx',
    editableProps: [
      { key: 'name', type: 'string' as const, label: 'Display name', defaultValue: 'Acme' },
      { key: 'handle', type: 'string' as const, label: 'Handle', defaultValue: '@acmehq' },
      { key: 'text', type: 'string' as const, label: 'Post text', defaultValue: 'We just launched! After 6 months of building, our product is live. Check it out and let us know what you think.' },
      { key: 'likes', type: 'string' as const, label: 'Like count', defaultValue: '2,847' },
      { key: 'bgColor', type: 'string' as const, label: 'Background', defaultValue: '#f5f5f5' },
    ],
  },
  {
    id: 'launch-day',
    name: 'Launch Day',
    componentName: 'LaunchDay',
    description: 'Product launch announcement with rocket emoji, headline, subtitle, and pulsing CTA button.',
    duration: 3,
    category: 'Branding',
    tags: ['launch', 'announcement', 'product', 'cta', 'hero'],
    fps: 30,
    durationInFrames: 90,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/launch-day.mp4',
    source: '// LaunchDay template — see Composition.tsx',
    editableProps: [
      { key: 'title', type: 'string' as const, label: 'Title', defaultValue: 'We just launched!' },
      { key: 'subtitle', type: 'string' as const, label: 'Subtitle', defaultValue: 'The fastest way to ship animated videos. Built for developers.' },
      { key: 'buttonText', type: 'string' as const, label: 'Button text', defaultValue: 'Try it free' },
      { key: 'bgColor', type: 'string' as const, label: 'Background', defaultValue: '#ffffff' },
    ],
  },
  {
    id: 'profile-card',
    name: 'Profile Card',
    componentName: 'ProfileCard',
    description: 'Professional profile introduction with avatar, name, role, bio, and animated stat counters.',
    duration: 3,
    category: 'Social',
    tags: ['profile', 'bio', 'introduction', 'personal', 'social'],
    fps: 30,
    durationInFrames: 90,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/profile-card.mp4',
    source: '// ProfileCard template — see Composition.tsx',
    editableProps: [
      { key: 'name', type: 'string' as const, label: 'Name', defaultValue: 'Alex Rivera' },
      { key: 'role', type: 'string' as const, label: 'Role', defaultValue: 'Founder & CEO' },
      { key: 'bio', type: 'string' as const, label: 'Bio', defaultValue: 'Building the future of programmatic video. Previously at Stripe and Vercel.' },
      { key: 'stats', type: 'string' as const, label: 'Stats (comma-separated)', defaultValue: '12K followers,500+ posts,50 projects' },
      { key: 'bgColor', type: 'string' as const, label: 'Background', defaultValue: '#fafafa' },
    ],
  },
  {
    id: 'collab-card',
    name: 'Collaboration',
    componentName: 'CollabCard',
    description: 'Partnership announcement with two logos sliding together, spark effect, and announcement text.',
    duration: 3,
    category: 'Branding',
    tags: ['collaboration', 'partnership', 'announcement', 'logos', 'together'],
    fps: 30,
    durationInFrames: 90,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/collab-card.mp4',
    source: '// CollabCard template — see Composition.tsx',
    editableProps: [
      { key: 'leftName', type: 'string' as const, label: 'Left brand', defaultValue: 'Acme' },
      { key: 'rightName', type: 'string' as const, label: 'Right brand', defaultValue: 'Beacon' },
      { key: 'title', type: 'string' as const, label: 'Title', defaultValue: 'Better together' },
      { key: 'subtitle', type: 'string' as const, label: 'Subtitle', defaultValue: "We're thrilled to announce our partnership." },
      { key: 'bgColor', type: 'string' as const, label: 'Background', defaultValue: '#ffffff' },
    ],
  },
  {
    id: 'screen-showcase',
    name: 'Screen Showcase',
    componentName: 'ScreenShowcase',
    description: 'App screenshot in browser chrome mockup with animated feature callouts on the side.',
    duration: 3,
    category: 'Product',
    tags: ['screen', 'screenshot', 'mockup', 'browser', 'app', 'demo'],
    fps: 30,
    durationInFrames: 90,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/screen-showcase.mp4',
    source: '// ScreenShowcase template — see Composition.tsx',
    editableProps: [
      { key: 'title', type: 'string' as const, label: 'App title', defaultValue: 'Dashboard' },
      { key: 'features', type: 'string' as const, label: 'Features (comma-separated)', defaultValue: 'Real-time analytics,Team collaboration,Custom reports' },
      { key: 'bgColor', type: 'string' as const, label: 'Background', defaultValue: '#fafafa' },
    ],
  },
  {
    id: 'day-summary',
    name: 'Day Summary',
    componentName: 'DaySummary',
    description: 'Daily productivity summary with task checklist, animated checkmarks, and metric counter.',
    duration: 3,
    category: 'Data',
    tags: ['productivity', 'daily', 'tasks', 'checklist', 'summary'],
    fps: 30,
    durationInFrames: 90,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/day-summary.mp4',
    source: '// DaySummary template — see Composition.tsx',
    editableProps: [
      { key: 'title', type: 'string' as const, label: 'Title', defaultValue: 'Productive day' },
      { key: 'tasks', type: 'string' as const, label: 'Tasks (comma-separated)', defaultValue: 'Shipped v2.4,Fixed 12 bugs,Reviewed 5 PRs,Wrote docs' },
      { key: 'metric', type: 'string' as const, label: 'Metric label', defaultValue: 'Tasks completed' },
      { key: 'metricValue', type: 'string' as const, label: 'Metric value', defaultValue: '23' },
      { key: 'bgColor', type: 'string' as const, label: 'Background', defaultValue: '#ffffff' },
    ],
  },
  {
    id: 'sales-card',
    name: 'Sales Card',
    componentName: 'SalesCard',
    description: 'Digital product sales dashboard with rolling revenue counter, units sold, price, and growth percentage.',
    duration: 3,
    category: 'E-commerce',
    tags: ['sales', 'revenue', 'product', 'lemon-squeezy', 'gumroad', 'earnings'],
    fps: 30,
    durationInFrames: 90,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/sales-card.mp4',
    source: '// SalesCard template — see Composition.tsx',
    editableProps: [
      { key: 'productName', type: 'string' as const, label: 'Product name', defaultValue: 'Pro Templates' },
      { key: 'revenue', type: 'string' as const, label: 'Revenue', defaultValue: '$4,280' },
      { key: 'unitsSold', type: 'string' as const, label: 'Units sold', defaultValue: '142' },
      { key: 'price', type: 'string' as const, label: 'Price each', defaultValue: '$29' },
      { key: 'bgColor', type: 'string' as const, label: 'Background', defaultValue: '#000000' },
    ],
  },
  {
    id: 'meme-card',
    name: 'Meme Card',
    componentName: 'MemeCard',
    description: 'Meme-style text animation with top text, emoji, and bottom text on dark background with shake effect.',
    duration: 3,
    category: 'Social',
    tags: ['meme', 'funny', 'viral', 'emoji', 'social'],
    fps: 30,
    durationInFrames: 90,
    width: 1920,
    height: 1080,
    isFree: true,
    previewVideo: '/videos/meme-card.mp4',
    source: '// MemeCard template — see Composition.tsx',
    editableProps: [
      { key: 'topText', type: 'string' as const, label: 'Top text', defaultValue: 'When the deploy works' },
      { key: 'bottomText', type: 'string' as const, label: 'Bottom text', defaultValue: 'on the first try' },
      { key: 'emoji', type: 'string' as const, label: 'Emoji', defaultValue: '\uD83D\uDE0E' },
      { key: 'bgColor', type: 'string' as const, label: 'Background', defaultValue: '#171717' },
    ],
  },
]

export function getTemplate(id: string): TemplateMeta | undefined {
  return templates.find((t) => t.id === id)
}

export function getCategories(): string[] {
  return [...new Set(templates.map((t) => t.category))]
}

export function filterTemplates(
  duration: number | null,
  category: string | null,
): TemplateMeta[] {
  return templates.filter((t) => {
    if (duration && t.duration !== duration) return false
    if (category && t.category !== category) return false
    return true
  })
}
