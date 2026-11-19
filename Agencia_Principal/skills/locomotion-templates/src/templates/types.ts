import type { EditableProp } from '@/types/studio'

export interface TemplateMeta {
  id: string
  name: string
  description: string
  componentName: string
  duration: number // seconds
  category: string
  tags: string[]
  fps: number
  durationInFrames: number
  width: number
  height: number
  previewVideo?: string
  isFree: boolean
  source: string // raw TSX source for copy-to-clipboard
  editableProps: EditableProp[]
}
