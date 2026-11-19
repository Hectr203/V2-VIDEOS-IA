import { bundle } from '@remotion/bundler'
import { renderMedia, selectComposition } from '@remotion/renderer'
import path from 'path'
import { fileURLToPath } from 'url'
import fs from 'fs'

const __dirname = path.dirname(fileURLToPath(import.meta.url))

const templateIds = [
  'fade-slide-up', 'spring-scale-in', 'typewriter-reveal', 'staggered-words',
  'modal-explainer', 'drag-drop-demo', 'feature-showcase', 'pricing-comparison',
  'onboarding-flow', 'saas-hero', 'step-explainer', 'concept-breakdown',
  'bar-chart-reveal', 'stats-dashboard', 'bold-text-punch', 'quote-card',
  'logo-reveal', 'intro-outro', 'app-feature-callout', 'ui-walkthrough',
  'product-reveal', 'discount-countdown', 'cart-animation', 'lesson-intro',
  'flashcard-flip', 'quiz-result', 'stock-ticker', 'portfolio-breakdown',
  'payment-flow', 'patient-journey', 'appointment-booking', 'wellness-stats',
  'property-tour', 'listing-card', 'virtual-walkthrough', 'job-posting',
  'team-intro', 'culture-reel', 'countdown-timer', 'agenda-reveal',
  'speaker-card', 'achievement-unlock', 'leaderboard', 'level-up',
  'gradient-text', 'metric-card', 'product-hunt', 'milestone-counter', 'toggle-switch',
  'testimonial-card', 'changelog', 'bento-grid', 'before-after', 'social-post',
  'launch-day', 'profile-card', 'collab-card', 'screen-showcase', 'day-summary',
  'sales-card', 'meme-card',
]

const styleVariants = ['brutalist', 'rounded', 'minimal', 'glass', 'neo']

async function main() {
  const outDir = path.resolve(__dirname, '../public/videos')
  if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true })

  // Check for --styles-only flag to skip default+dark renders
  const stylesOnly = process.argv.includes('--styles-only')
  const darkOnly = process.argv.includes('--dark-only')
  const specificStyle = process.argv.find(a => styleVariants.includes(a))

  console.log('Bundling Remotion project...')
  const bundleLocation = await bundle({
    entryPoint: path.resolve(__dirname, './index.ts'),
    webpackOverride: (config) => ({
      ...config,
      resolve: {
        ...config.resolve,
        alias: {
          ...config.resolve?.alias,
          '@': path.resolve(__dirname, '../src'),
        },
      },
    }),
  })
  console.log('Bundle complete.')

  async function render(compositionId, outputPath) {
    if (fs.existsSync(outputPath) && process.argv.includes('--skip-existing')) {
      console.log(`  -> skipped (exists) ${outputPath}`)
      return
    }
    console.log(`Rendering ${compositionId}...`)
    try {
      const composition = await selectComposition({ serveUrl: bundleLocation, id: compositionId })
      await renderMedia({ composition, serveUrl: bundleLocation, codec: 'h264', outputLocation: outputPath })
      console.log(`  -> ${outputPath}`)
    } catch (e) {
      console.log(`  -> FAILED: ${e.message}`)
    }
  }

  // Default light versions
  if (!stylesOnly && !darkOnly) {
    for (const id of templateIds) {
      await render(id, path.join(outDir, `${id}.mp4`))
    }
  }

  // Dark versions
  if (!stylesOnly) {
    for (const id of templateIds) {
      await render(`dark-${id}`, path.join(outDir, `${id}-dark.mp4`))
    }
  }

  // Style variants
  const stylesToRender = specificStyle ? [specificStyle] : styleVariants
  for (const variant of stylesToRender) {
    console.log(`\n--- Rendering ${variant} style ---`)
    for (const id of templateIds) {
      await render(`${variant}-${id}`, path.join(outDir, `${id}-${variant}.mp4`))
    }
  }

  console.log('\nAll renders complete!')
}

main().catch((err) => { console.error(err); process.exit(1) })
