import type { Segment } from '../../shared/segments.js';

/** Tasa nominal anual según perfil y plazo (referencial, no es una oferta). */
export function annualRateFor(segment: Segment, termMonths: number): number {
  const base: Record<Segment, number> = { saver: 0.149, investor: 0.139, entrepreneur: 0.165 };
  return base[segment] + (termMonths > 36 ? 0.01 : 0);
}

export interface CreditQuote {
  amountMinor: number;
  termMonths: number;
  annualRate: number;
  monthlyPaymentMinor: number;
  totalPaymentMinor: number;
  totalInterestMinor: number;
}

/**
 * Cuota fija (sistema francés): `P · r / (1 − (1 + r)^−n)`, con `r` la tasa
 * mensual. Se calcula en el servidor para que la mini app no pueda alterar
 * las condiciones.
 */
export function quoteCredit(
  amountMinor: number,
  termMonths: number,
  annualRate: number,
): CreditQuote {
  const r = annualRate / 12;
  const payment = (amountMinor * r) / (1 - (1 + r) ** -termMonths);
  const monthlyPaymentMinor = Math.round(payment);
  const totalPaymentMinor = monthlyPaymentMinor * termMonths;
  return {
    amountMinor,
    termMonths,
    annualRate,
    monthlyPaymentMinor,
    totalPaymentMinor,
    totalInterestMinor: totalPaymentMinor - amountMinor,
  };
}
