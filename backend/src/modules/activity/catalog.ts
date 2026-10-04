import { between, type Random } from '../../shared/random.js';
import type { Segment } from '../../shared/segments.js';

/** Ecuador está dolarizado: todas las cuentas operan en USD. */
export const CURRENCY = 'USD';

/** Monto aleatorio en centavos entre `min` y `max` dólares (con centavos). */
export const usd = (random: Random, min: number, max: number) =>
  between(random, Math.round(min * 100), Math.round(max * 100));

export interface SpendingCategory {
  merchants: readonly string[];
  /** Rango del cargo en dólares. */
  min: number;
  max: number;
}

export const SPENDING: Record<string, SpendingCategory> = {
  groceries: {
    merchants: ['Supermercado La Canasta', 'Mercado Fresco', 'Tienda Don Pepe'],
    min: 4,
    max: 95,
  },
  restaurants: {
    merchants: ['Restaurante El Fogón', 'Café Central', 'Pizzería Napoli'],
    min: 3.5,
    max: 38,
  },
  transport: {
    merchants: ['Transporte urbano', 'App de movilidad', 'Gasolinera Ruta 7'],
    min: 0.45,
    max: 18,
  },
  entertainment: {
    merchants: ['Streaming Plus', 'Cine Estrella', 'Música Ilimitada'],
    min: 4.99,
    max: 14.99,
  },
  health: { merchants: ['Farmacia Salud', 'Laboratorio Vida'], min: 2.5, max: 45 },
  shopping: {
    merchants: ['Tienda de ropa Moda Viva', 'Librería Páginas', 'Electro Hogar'],
    min: 12,
    max: 160,
  },
  utilities: {
    merchants: ['Empresa eléctrica', 'Agua potable municipal', 'Internet Hogar'],
    min: 18,
    max: 75,
  },
};

export type SpendingCategoryName = keyof typeof SPENDING;

/** Peso relativo de cada categoría de gasto por segmento. */
export const SPENDING_WEIGHTS: Record<Segment, Record<string, number>> = {
  saver: {
    groceries: 5,
    transport: 4,
    utilities: 1,
    health: 1,
    restaurants: 1,
    entertainment: 1,
    shopping: 1,
  },
  investor: {
    restaurants: 4,
    entertainment: 3,
    shopping: 3,
    transport: 3,
    groceries: 3,
    utilities: 1,
    health: 1,
  },
  entrepreneur: {
    transport: 4,
    groceries: 3,
    restaurants: 3,
    utilities: 2,
    shopping: 2,
    health: 1,
    entertainment: 1,
  },
};

export const PEOPLE = [
  'Laura Méndez',
  'Carlos Rojas',
  'Ana Gómez',
  'Julián Torres',
  'Sofía Herrera',
];
export const CLIENTS = [
  'Distribuidora Andina',
  'Comercial El Puente',
  'Hotel Las Palmas',
  'Cliente mostrador',
];
export const SUPPLIERS = ['Proveedor Insumos SAS', 'Empaques del Norte', 'Logística Express'];
