import { formatUsd } from '../../shared/money.js';
import type { Segment } from '../../shared/segments.js';
import type { ExperienceFlags } from './flags.js';
import type { HomeSignals } from './signals.js';

/** Versión del contrato SDUI. La app ignora layouts de una versión mayor. */
export const SCHEMA_VERSION = 1;

export interface SduiComponent {
  /** Identificador estable: los eventos de uso (tap, dismiss) lo referencian. */
  id: string;
  type: string;
  /** Versión del componente; la app descarta las que no sabe dibujar. */
  version: number;
  props?: Record<string, unknown>;
}

interface Insight {
  priority: number;
  component: SduiComponent;
}

const CATEGORY_LABELS: Record<string, string> = {
  groceries: 'mercado',
  restaurants: 'restaurantes',
  transport: 'transporte',
  entertainment: 'entretenimiento',
  health: 'salud',
  shopping: 'compras',
  utilities: 'servicios',
};

const SUBTITLE: Record<Segment, string> = {
  saver: 'Vas por buen camino con tu meta de ahorro.',
  investor: 'Tu dinero puede trabajar más por ti.',
  entrepreneur: 'Así va tu negocio esta semana.',
};

/**
 * Motor de reglas del home: función pura de las señales del cliente y los
 * flags. Decide QUÉ componentes mostrar, con qué contenido y en qué orden.
 * Al ser pura, cada regla se prueba sin base de datos ni HTTP.
 */
export function buildHomeLayout(s: HomeSignals, flags: ExperienceFlags): SduiComponent[] {
  const visible = (c: SduiComponent | null): c is SduiComponent =>
    c !== null && !s.dismissed.has(c.id);

  const insights = flags.insights
    ? collectInsights(s)
        .filter((i) => visible(i.component))
        .sort((a, b) => b.priority - a.priority)
        .map((i) => i.component)
    : [];

  const components: (SduiComponent | null)[] = [
    greeting(s),
    insights[0] ?? null,
    { id: 'accounts', type: 'accounts_summary', version: 1 },
    quickActions(s, flags),
    insights[1] ?? null,
    flags.promotions ? promotion(s.segment) : null,
  ];
  return components.filter(visible);
}

function greeting(s: HomeSignals): SduiComponent {
  const salute =
    s.localHour < 12 ? 'Buenos días' : s.localHour < 19 ? 'Buenas tardes' : 'Buenas noches';
  return {
    id: 'greeting',
    type: 'greeting',
    version: 1,
    props: { title: `${salute}, ${s.firstName}`, subtitle: SUBTITLE[s.segment] },
  };
}

function collectInsights(s: HomeSignals): Insight[] {
  const insights: Insight[] = [];
  const accountRoute = s.mainAccountId ? `/accounts/${s.mainAccountId}` : undefined;

  if (s.mainBalanceMinor < 50_00) {
    insights.push({
      priority: 100,
      component: insight('insight.low_balance', 'warning', {
        title: 'Tu saldo está bajo',
        body: `Te quedan ${formatUsd(s.mainBalanceMinor)} en tu cuenta de ahorros.`,
        action: accountRoute ? { label: 'Ver movimientos', route: accountRoute } : undefined,
      }),
    });
  }

  // La categoría con mayor aumento relevante frente a los 30 días anteriores.
  const increases = Object.entries(s.spendCurrent)
    .map(([category, current]) => {
      const previous = s.spendPrevious[category] ?? 0;
      return { category, current, delta: current - previous, previous };
    })
    .filter((x) => x.previous > 0 && x.delta >= 20_00 && x.delta / x.previous >= 0.2)
    .sort((a, b) => b.delta - a.delta);
  const top = increases[0];
  if (top && CATEGORY_LABELS[top.category]) {
    const pct = Math.round((top.delta / top.previous) * 100);
    insights.push({
      priority: 80,
      component: insight(`insight.spending_up.${top.category}`, 'info', {
        title: `Gastaste ${pct}% más en ${CATEGORY_LABELS[top.category]}`,
        body: `${formatUsd(top.current)} en los últimos 30 días (${formatUsd(top.delta)} más que el mes anterior).`,
        action: accountRoute ? { label: 'Revisar gastos', route: accountRoute } : undefined,
      }),
    });
  }

  if (s.segment === 'entrepreneur' && s.salesPrev7dMinor > 0) {
    const pct = Math.round(((s.salesLast7dMinor - s.salesPrev7dMinor) / s.salesPrev7dMinor) * 100);
    insights.push({
      priority: 70,
      component: insight('insight.sales_trend', pct >= 0 ? 'success' : 'info', {
        title: `Tus ventas ${pct >= 0 ? 'subieron' : 'bajaron'} ${Math.abs(pct)}% esta semana`,
        body: `Recibiste ${formatUsd(s.salesLast7dMinor)} en ventas en los últimos 7 días.`,
      }),
    });
  } else if (s.incomeLast7dMinor > 0) {
    const suggestion = Math.round(s.incomeLast7dMinor * 0.1);
    insights.push({
      priority: 60,
      component: insight('insight.income_received', 'success', {
        title: `Recibiste ${formatUsd(s.incomeLast7dMinor)} esta semana`,
        body:
          s.segment === 'saver'
            ? `¿Separas ${formatUsd(suggestion)} (10%) para tu bolsillo de metas?`
            : `Invertir ${formatUsd(suggestion)} (10%) puede darte rendimientos cada mes.`,
        action: {
          label: s.segment === 'saver' ? 'Ahorrar ahora' : 'Mover a inversión',
          route: '/transfer',
        },
      }),
    });
  }

  if (s.segment === 'saver' && s.goalBalanceMinor !== null && s.goalBalanceMinor > 0) {
    insights.push({
      priority: 40,
      component: insight('insight.goal_progress', 'success', {
        title: `Llevas ${formatUsd(s.goalBalanceMinor)} en tu bolsillo de metas`,
        body: 'Cada aporte semanal te acerca a tu objetivo.',
      }),
    });
  }

  return insights;
}

function insight(
  id: string,
  tone: 'info' | 'success' | 'warning',
  props: { title: string; body: string; action?: { label: string; route: string } | undefined },
): SduiComponent {
  return { id, type: 'insight', version: 1, props: { tone, dismissible: true, ...props } };
}

/** Acciones rápidas ordenadas por uso real: lo que más toca el cliente, primero. */
function quickActions(s: HomeSignals, flags: ExperienceFlags): SduiComponent {
  const actions = [
    { id: 'transfer', label: 'Transferir', icon: 'transfer', route: '/transfer' },
    s.mainAccountId && {
      id: 'movements',
      label: 'Movimientos',
      icon: 'receipt',
      route: `/accounts/${s.mainAccountId}`,
    },
    flags.miniApps && {
      id: 'credit_simulator',
      label: 'Simular crédito',
      icon: 'calculator',
      route: '/mini-apps/credit-simulator',
    },
    { id: 'support', label: 'Ayuda', icon: 'support', route: '/diagnostics' },
  ]
    .filter((a): a is Exclude<typeof a, false | null | '' | undefined> => Boolean(a))
    .map((action, index) => ({ action, index, taps: s.taps[`quick_actions.${action.id}`] ?? 0 }))
    .sort((a, b) => b.taps - a.taps || a.index - b.index)
    .map((x) => x.action);

  return { id: 'quick_actions', type: 'quick_actions', version: 1, props: { actions } };
}

const PROMOTIONS: Record<Segment, { title: string; body: string; cta: string; route: string }> = {
  saver: {
    title: 'Ahorro programado',
    body: 'Separa automáticamente una parte de cada ingreso para tu meta.',
    cta: 'Configurar',
    route: '/transfer',
  },
  investor: {
    title: 'Simula tu crédito o inversión',
    body: 'Calcula cuotas y rendimientos antes de decidir.',
    cta: 'Simular',
    route: '/mini-apps/credit-simulator',
  },
  entrepreneur: {
    title: 'Crédito para tu negocio',
    body: 'Simula un crédito productivo según tus ventas.',
    cta: 'Simular',
    route: '/mini-apps/credit-simulator',
  },
};

function promotion(segment: Segment): SduiComponent {
  const promo = PROMOTIONS[segment];
  return {
    id: `promo.${segment}`,
    type: 'promo_banner',
    version: 1,
    props: { ...promo, dismissible: true },
  };
}
