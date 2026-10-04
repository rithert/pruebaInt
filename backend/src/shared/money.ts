/** `128430` (centavos) → `$1.284,30` (es-EC, Ecuador está dolarizado). */
export function formatUsd(amountMinor: number): string {
  const negative = amountMinor < 0;
  const abs = Math.abs(amountMinor);
  const dollars = Math.trunc(abs / 100)
    .toString()
    .replace(/\B(?=(\d{3})+(?!\d))/g, '.');
  const cents = String(abs % 100).padStart(2, '0');
  return `${negative ? '-' : ''}$${dollars},${cents}`;
}
