import { AbsoluteFill } from 'remotion'

// Wraps any composition with inverted colors for dark mode rendering
export const DarkWrapper: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  return (
    <AbsoluteFill style={{ filter: 'invert(1) hue-rotate(180deg)' }}>
      {children}
    </AbsoluteFill>
  )
}
