/** Objetivo financiero que el cliente declara en el onboarding. */
export const GOALS = ['save', 'invest', 'grow_business'] as const;
export type Goal = (typeof GOALS)[number];

/**
 * Segmento que alimenta la personalización. Se inicializa desde el objetivo
 * declarado y luego el backend lo ajusta según el comportamiento (F5).
 */
export const SEGMENTS = ['saver', 'investor', 'entrepreneur'] as const;
export type Segment = (typeof SEGMENTS)[number];

const SEGMENT_BY_GOAL: Record<Goal, Segment> = {
  save: 'saver',
  invest: 'investor',
  grow_business: 'entrepreneur',
};

export function initialSegmentFor(goal: Goal): Segment {
  return SEGMENT_BY_GOAL[goal];
}
