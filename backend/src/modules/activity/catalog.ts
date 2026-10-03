import type { Segment } from '../../shared/segments.js';

export const CURRENCY = 'COP';

/** Convierte pesos a unidades menores (centavos). */
export const cop = (pesos: number) => pesos * 100;

export interface SpendingCategory {
  merchants: readonly string[];
  /** Rango del cargo en pesos. */
  min: number;
  max: number;
}

export const SPENDING: Record<string, SpendingCategory> = {
  groceries: { merchants: ['Supermercado La Canasta', 'Mercado Fresco', 'Tienda Don Pepe'], min: 15_000, max: 220_000 },
  restaurants: { merchants: ['Restaurante El Fogón', 'Café Central', 'Pizzería Napoli'], min: 12_000, max: 120_000 },
  transport: { merchants: ['Transporte urbano', 'App de movilidad', 'Gasolinera Ruta 7'], min: 3_000, max: 90_000 },
  entertainment: { merchants: ['Streaming Plus', 'Cine Estrella', 'Música Ilimitada'], min: 15_000, max: 60_000 },
  health: { merchants: ['Farmacia Salud', 'Laboratorio Vida'], min: 10_000, max: 150_000 },
  shopping: { merchants: ['Tienda de ropa Moda Viva', 'Librería Páginas', 'Electro Hogar'], min: 30_000, max: 450_000 },
  utilities: { merchants: ['Empresa de energía', 'Acueducto municipal', 'Internet Hogar'], min: 60_000, max: 250_000 },
};

export type SpendingCategoryName = keyof typeof SPENDING;

/** Peso relativo de cada categoría de gasto por segmento. */
export const SPENDING_WEIGHTS: Record<Segment, Record<string, number>> = {
  saver: { groceries: 5, transport: 4, utilities: 1, health: 1, restaurants: 1, entertainment: 1, shopping: 1 },
  investor: { restaurants: 4, entertainment: 3, shopping: 3, transport: 3, groceries: 3, utilities: 1, health: 1 },
  entrepreneur: { transport: 4, groceries: 3, restaurants: 3, utilities: 2, shopping: 2, health: 1, entertainment: 1 },
};

export const PEOPLE = ['Laura Méndez', 'Carlos Rojas', 'Ana Gómez', 'Julián Torres', 'Sofía Herrera'];
export const CLIENTS = ['Distribuidora Andina', 'Comercial El Puente', 'Hotel Las Palmas', 'Cliente mostrador'];
export const SUPPLIERS = ['Proveedor Insumos SAS', 'Empaques del Norte', 'Logística Express'];
