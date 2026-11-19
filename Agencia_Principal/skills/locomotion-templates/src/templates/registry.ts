import type React from 'react'
import { FadeSlideUp } from './fade-slide-up/Composition'
import { SpringScaleIn } from './spring-scale-in/Composition'
import { TypewriterReveal } from './typewriter-reveal/Composition'
import { StaggeredWords } from './staggered-words/Composition'
import { ModalExplainer } from './modal-explainer/Composition'
import { DragDropDemo } from './drag-drop-demo/Composition'
import { FeatureShowcase } from './feature-showcase/Composition'
import { PricingComparison } from './pricing-comparison/Composition'
import { OnboardingFlow } from './onboarding-flow/Composition'
import { SaasHero } from './saas-hero/Composition'
import { StepExplainer } from './step-explainer/Composition'
import { ConceptBreakdown } from './concept-breakdown/Composition'
import { BarChartReveal } from './bar-chart-reveal/Composition'
import { StatsDashboard } from './stats-dashboard/Composition'
import { BoldTextPunch } from './bold-text-punch/Composition'
import { QuoteCard } from './quote-card/Composition'
import { LogoReveal } from './logo-reveal/Composition'
import { IntroOutro } from './intro-outro/Composition'
import { AppFeatureCallout } from './app-feature-callout/Composition'
import { UiWalkthrough } from './ui-walkthrough/Composition'
import { ProductReveal } from './product-reveal/Composition'
import { DiscountCountdown } from './discount-countdown/Composition'
import { CartAnimation } from './cart-animation/Composition'
import { LessonIntro } from './lesson-intro/Composition'
import { FlashcardFlip } from './flashcard-flip/Composition'
import { QuizResult } from './quiz-result/Composition'
import { StockTicker } from './stock-ticker/Composition'
import { PortfolioBreakdown } from './portfolio-breakdown/Composition'
import { PaymentFlow } from './payment-flow/Composition'
import { PatientJourney } from './patient-journey/Composition'
import { AppointmentBooking } from './appointment-booking/Composition'
import { WellnessStats } from './wellness-stats/Composition'
import { PropertyTour } from './property-tour/Composition'
import { ListingCard } from './listing-card/Composition'
import { VirtualWalkthrough } from './virtual-walkthrough/Composition'
import { JobPosting } from './job-posting/Composition'
import { TeamIntro } from './team-intro/Composition'
import { CultureReel } from './culture-reel/Composition'
import { CountdownTimer } from './countdown-timer/Composition'
import { AgendaReveal } from './agenda-reveal/Composition'
import { SpeakerCard } from './speaker-card/Composition'
import { AchievementUnlock } from './achievement-unlock/Composition'
import { Leaderboard } from './leaderboard/Composition'
import { LevelUp } from './level-up/Composition'
import { GradientText } from './gradient-text/Composition'
import { MetricCard } from './metric-card/Composition'
import { ProductHunt } from './product-hunt/Composition'
import { MilestoneCounter } from './milestone-counter/Composition'
import { ToggleSwitch } from './toggle-switch/Composition'
import { TestimonialCard } from './testimonial-card/Composition'
import { Changelog } from './changelog/Composition'
import { BentoGrid } from './bento-grid/Composition'
import { BeforeAfter } from './before-after/Composition'
import { SocialPost } from './social-post/Composition'
import { LaunchDay } from './launch-day/Composition'
import { ProfileCard } from './profile-card/Composition'
import { CollabCard } from './collab-card/Composition'
import { ScreenShowcase } from './screen-showcase/Composition'
import { DaySummary } from './day-summary/Composition'
import { SalesCard } from './sales-card/Composition'
import { MemeCard } from './meme-card/Composition'

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export const templateComponents: Record<string, React.FC<any>> = {
  'fade-slide-up': FadeSlideUp,
  'spring-scale-in': SpringScaleIn,
  'typewriter-reveal': TypewriterReveal,
  'staggered-words': StaggeredWords,
  'modal-explainer': ModalExplainer,
  'drag-drop-demo': DragDropDemo,
  'feature-showcase': FeatureShowcase,
  'pricing-comparison': PricingComparison,
  'onboarding-flow': OnboardingFlow,
  'saas-hero': SaasHero,
  'step-explainer': StepExplainer,
  'concept-breakdown': ConceptBreakdown,
  'bar-chart-reveal': BarChartReveal,
  'stats-dashboard': StatsDashboard,
  'bold-text-punch': BoldTextPunch,
  'quote-card': QuoteCard,
  'logo-reveal': LogoReveal,
  'intro-outro': IntroOutro,
  'app-feature-callout': AppFeatureCallout,
  'ui-walkthrough': UiWalkthrough,
  'product-reveal': ProductReveal,
  'discount-countdown': DiscountCountdown,
  'cart-animation': CartAnimation,
  'lesson-intro': LessonIntro,
  'flashcard-flip': FlashcardFlip,
  'quiz-result': QuizResult,
  'stock-ticker': StockTicker,
  'portfolio-breakdown': PortfolioBreakdown,
  'payment-flow': PaymentFlow,
  'patient-journey': PatientJourney,
  'appointment-booking': AppointmentBooking,
  'wellness-stats': WellnessStats,
  'property-tour': PropertyTour,
  'listing-card': ListingCard,
  'virtual-walkthrough': VirtualWalkthrough,
  'job-posting': JobPosting,
  'team-intro': TeamIntro,
  'culture-reel': CultureReel,
  'countdown-timer': CountdownTimer,
  'agenda-reveal': AgendaReveal,
  'speaker-card': SpeakerCard,
  'achievement-unlock': AchievementUnlock,
  'leaderboard': Leaderboard,
  'level-up': LevelUp,
  'gradient-text': GradientText,
  'metric-card': MetricCard,
  'product-hunt': ProductHunt,
  'milestone-counter': MilestoneCounter,
  'toggle-switch': ToggleSwitch,
  'testimonial-card': TestimonialCard,
  'changelog': Changelog,
  'bento-grid': BentoGrid,
  'before-after': BeforeAfter,
  'social-post': SocialPost,
  'launch-day': LaunchDay,
  'profile-card': ProfileCard,
  'collab-card': CollabCard,
  'screen-showcase': ScreenShowcase,
  'day-summary': DaySummary,
  'sales-card': SalesCard,
  'meme-card': MemeCard,
}
