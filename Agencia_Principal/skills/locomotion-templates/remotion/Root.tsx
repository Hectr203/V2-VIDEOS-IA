import { Composition, AbsoluteFill } from 'remotion'
import { FadeSlideUp } from '../src/templates/fade-slide-up/Composition'
import { SpringScaleIn } from '../src/templates/spring-scale-in/Composition'
import { TypewriterReveal } from '../src/templates/typewriter-reveal/Composition'
import { StaggeredWords } from '../src/templates/staggered-words/Composition'
import { ModalExplainer } from '../src/templates/modal-explainer/Composition'
import { DragDropDemo } from '../src/templates/drag-drop-demo/Composition'
import { FeatureShowcase } from '../src/templates/feature-showcase/Composition'
import { PricingComparison } from '../src/templates/pricing-comparison/Composition'
import { OnboardingFlow } from '../src/templates/onboarding-flow/Composition'
import { SaasHero } from '../src/templates/saas-hero/Composition'
import { StepExplainer } from '../src/templates/step-explainer/Composition'
import { ConceptBreakdown } from '../src/templates/concept-breakdown/Composition'
import { BarChartReveal } from '../src/templates/bar-chart-reveal/Composition'
import { StatsDashboard } from '../src/templates/stats-dashboard/Composition'
import { BoldTextPunch } from '../src/templates/bold-text-punch/Composition'
import { QuoteCard } from '../src/templates/quote-card/Composition'
import { LogoReveal } from '../src/templates/logo-reveal/Composition'
import { IntroOutro } from '../src/templates/intro-outro/Composition'
import { AppFeatureCallout } from '../src/templates/app-feature-callout/Composition'
import { UiWalkthrough } from '../src/templates/ui-walkthrough/Composition'
import { ProductReveal } from '../src/templates/product-reveal/Composition'
import { DiscountCountdown } from '../src/templates/discount-countdown/Composition'
import { CartAnimation } from '../src/templates/cart-animation/Composition'
import { LessonIntro } from '../src/templates/lesson-intro/Composition'
import { FlashcardFlip } from '../src/templates/flashcard-flip/Composition'
import { QuizResult } from '../src/templates/quiz-result/Composition'
import { StockTicker } from '../src/templates/stock-ticker/Composition'
import { PortfolioBreakdown } from '../src/templates/portfolio-breakdown/Composition'
import { PaymentFlow } from '../src/templates/payment-flow/Composition'
import { PatientJourney } from '../src/templates/patient-journey/Composition'
import { AppointmentBooking } from '../src/templates/appointment-booking/Composition'
import { WellnessStats } from '../src/templates/wellness-stats/Composition'
import { PropertyTour } from '../src/templates/property-tour/Composition'
import { ListingCard } from '../src/templates/listing-card/Composition'
import { VirtualWalkthrough } from '../src/templates/virtual-walkthrough/Composition'
import { JobPosting } from '../src/templates/job-posting/Composition'
import { TeamIntro } from '../src/templates/team-intro/Composition'
import { CultureReel } from '../src/templates/culture-reel/Composition'
import { CountdownTimer } from '../src/templates/countdown-timer/Composition'
import { AgendaReveal } from '../src/templates/agenda-reveal/Composition'
import { SpeakerCard } from '../src/templates/speaker-card/Composition'
import { AchievementUnlock } from '../src/templates/achievement-unlock/Composition'
import { Leaderboard } from '../src/templates/leaderboard/Composition'
import { LevelUp } from '../src/templates/level-up/Composition'
import { GradientText } from '../src/templates/gradient-text/Composition'
import { MetricCard } from '../src/templates/metric-card/Composition'
import { ProductHunt } from '../src/templates/product-hunt/Composition'
import { MilestoneCounter } from '../src/templates/milestone-counter/Composition'
import { ToggleSwitch } from '../src/templates/toggle-switch/Composition'
import { TestimonialCard } from '../src/templates/testimonial-card/Composition'
import { Changelog } from '../src/templates/changelog/Composition'
import { BentoGrid } from '../src/templates/bento-grid/Composition'
import { BeforeAfter } from '../src/templates/before-after/Composition'
import { SocialPost } from '../src/templates/social-post/Composition'
import { LaunchDay } from '../src/templates/launch-day/Composition'
import { ProfileCard } from '../src/templates/profile-card/Composition'
import { CollabCard } from '../src/templates/collab-card/Composition'
import { ScreenShowcase } from '../src/templates/screen-showcase/Composition'
import { DaySummary } from '../src/templates/day-summary/Composition'
import { SalesCard } from '../src/templates/sales-card/Composition'
import { MemeCard } from '../src/templates/meme-card/Composition'

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type CompDef = { id: string; component: React.FC<any>; durationInFrames: number; defaultProps?: Record<string, unknown> }

const compositions: CompDef[] = [
  { id: 'fade-slide-up', component: FadeSlideUp, durationInFrames: 30, defaultProps: { text: 'Hello World' } },
  { id: 'spring-scale-in', component: SpringScaleIn, durationInFrames: 30, defaultProps: { text: 'Welcome' } },
  { id: 'typewriter-reveal', component: TypewriterReveal, durationInFrames: 90, defaultProps: { text: 'Building the future.' } },
  { id: 'staggered-words', component: StaggeredWords, durationInFrames: 90, defaultProps: { text: 'Design. Build. Ship.' } },
  { id: 'modal-explainer', component: ModalExplainer, durationInFrames: 150 },
  { id: 'drag-drop-demo', component: DragDropDemo, durationInFrames: 150 },
  { id: 'feature-showcase', component: FeatureShowcase, durationInFrames: 150 },
  { id: 'pricing-comparison', component: PricingComparison, durationInFrames: 90 },
  { id: 'onboarding-flow', component: OnboardingFlow, durationInFrames: 150 },
  { id: 'saas-hero', component: SaasHero, durationInFrames: 90, defaultProps: { title: 'Ship faster with AI' } },
  { id: 'step-explainer', component: StepExplainer, durationInFrames: 90, defaultProps: { title: 'How it works' } },
  { id: 'concept-breakdown', component: ConceptBreakdown, durationInFrames: 120, defaultProps: { title: 'What is AI?' } },
  { id: 'bar-chart-reveal', component: BarChartReveal, durationInFrames: 90 },
  { id: 'stats-dashboard', component: StatsDashboard, durationInFrames: 90 },
  { id: 'bold-text-punch', component: BoldTextPunch, durationInFrames: 30, defaultProps: { text: 'Stop scrolling.' } },
  { id: 'quote-card', component: QuoteCard, durationInFrames: 90, defaultProps: { text: 'This changed everything for our team.' } },
  { id: 'logo-reveal', component: LogoReveal, durationInFrames: 60, defaultProps: { text: 'Acme' } },
  { id: 'intro-outro', component: IntroOutro, durationInFrames: 90, defaultProps: { text: 'Thanks for watching' } },
  { id: 'app-feature-callout', component: AppFeatureCallout, durationInFrames: 90, defaultProps: { text: 'Real-time collaboration' } },
  { id: 'ui-walkthrough', component: UiWalkthrough, durationInFrames: 120 },
  { id: 'product-reveal', component: ProductReveal, durationInFrames: 90, defaultProps: { text: 'New AirPods Pro' } },
  { id: 'discount-countdown', component: DiscountCountdown, durationInFrames: 90, defaultProps: { text: '50% OFF' } },
  { id: 'cart-animation', component: CartAnimation, durationInFrames: 90 },
  { id: 'lesson-intro', component: LessonIntro, durationInFrames: 90, defaultProps: { text: 'Lesson 3: Variables' } },
  { id: 'flashcard-flip', component: FlashcardFlip, durationInFrames: 90, defaultProps: { text: 'Photosynthesis' } },
  { id: 'quiz-result', component: QuizResult, durationInFrames: 90 },
  { id: 'stock-ticker', component: StockTicker, durationInFrames: 90 },
  { id: 'portfolio-breakdown', component: PortfolioBreakdown, durationInFrames: 90 },
  { id: 'payment-flow', component: PaymentFlow, durationInFrames: 90 },
  { id: 'patient-journey', component: PatientJourney, durationInFrames: 90 },
  { id: 'appointment-booking', component: AppointmentBooking, durationInFrames: 90 },
  { id: 'wellness-stats', component: WellnessStats, durationInFrames: 90 },
  { id: 'property-tour', component: PropertyTour, durationInFrames: 90, defaultProps: { text: '42 Oak Avenue' } },
  { id: 'listing-card', component: ListingCard, durationInFrames: 90 },
  { id: 'virtual-walkthrough', component: VirtualWalkthrough, durationInFrames: 120 },
  { id: 'job-posting', component: JobPosting, durationInFrames: 90, defaultProps: { text: 'Senior Engineer' } },
  { id: 'team-intro', component: TeamIntro, durationInFrames: 90 },
  { id: 'culture-reel', component: CultureReel, durationInFrames: 90, defaultProps: { text: 'Life at Acme' } },
  { id: 'countdown-timer', component: CountdownTimer, durationInFrames: 90, defaultProps: { text: 'Launching soon' } },
  { id: 'agenda-reveal', component: AgendaReveal, durationInFrames: 90, defaultProps: { text: "Today's Agenda" } },
  { id: 'speaker-card', component: SpeakerCard, durationInFrames: 90, defaultProps: { text: 'Jane Smith' } },
  { id: 'achievement-unlock', component: AchievementUnlock, durationInFrames: 90, defaultProps: { text: 'First Victory' } },
  { id: 'leaderboard', component: Leaderboard, durationInFrames: 90 },
  { id: 'level-up', component: LevelUp, durationInFrames: 90 },
  { id: 'gradient-text', component: GradientText, durationInFrames: 90, defaultProps: { text: 'Captivating' } },
  { id: 'metric-card', component: MetricCard, durationInFrames: 90 },
  { id: 'product-hunt', component: ProductHunt, durationInFrames: 90 },
  { id: 'milestone-counter', component: MilestoneCounter, durationInFrames: 90 },
  { id: 'toggle-switch', component: ToggleSwitch, durationInFrames: 90 },
  { id: 'testimonial-card', component: TestimonialCard, durationInFrames: 90 },
  { id: 'changelog', component: Changelog, durationInFrames: 90 },
  { id: 'bento-grid', component: BentoGrid, durationInFrames: 90 },
  { id: 'before-after', component: BeforeAfter, durationInFrames: 90 },
  { id: 'social-post', component: SocialPost, durationInFrames: 90 },
  { id: 'launch-day', component: LaunchDay, durationInFrames: 90 },
  { id: 'profile-card', component: ProfileCard, durationInFrames: 90 },
  { id: 'collab-card', component: CollabCard, durationInFrames: 90 },
  { id: 'screen-showcase', component: ScreenShowcase, durationInFrames: 90 },
  { id: 'day-summary', component: DaySummary, durationInFrames: 90 },
  { id: 'sales-card', component: SalesCard, durationInFrames: 90 },
  { id: 'meme-card', component: MemeCard, durationInFrames: 90, defaultProps: { topText: 'When the deploy works', bottomText: 'on the first try' } },
]

const styleVariants = ['brutalist', 'rounded', 'minimal', 'glass', 'neo']

export const Root: React.FC = () => {
  return (
    <>
      {/* Default light versions */}
      {compositions.map(({ id, component: C, durationInFrames, defaultProps }) => (
        <Composition key={id} id={id} component={C} durationInFrames={durationInFrames} fps={30} width={960} height={540} defaultProps={defaultProps} />
      ))}

      {/* Dark versions (CSS invert) */}
      {compositions.map(({ id, component: C, durationInFrames, defaultProps }) => (
        <Composition
          key={`dark-${id}`}
          id={`dark-${id}`}
          component={({ ...props }) => (
            <AbsoluteFill style={{ filter: 'invert(1) hue-rotate(180deg)' }}><C {...props} /></AbsoluteFill>
          )}
          durationInFrames={durationInFrames} fps={30} width={960} height={540} defaultProps={defaultProps}
        />
      ))}

      {/* Style variants — pass variant prop directly to composition */}
      {styleVariants.map((variant) =>
        compositions.map(({ id, component: C, durationInFrames, defaultProps }) => (
          <Composition
            key={`${variant}-${id}`}
            id={`${variant}-${id}`}
            component={C}
            durationInFrames={durationInFrames} fps={30} width={960} height={540}
            defaultProps={{ ...defaultProps, variant }}
          />
        ))
      )}
    </>
  )
}
