/**
 * Mini apps registradas en el ecosistema. Cada una declara los permisos
 * (scopes) que puede recibir: un tercero nunca obtiene más que esto.
 */
export interface MiniAppDefinition {
  id: string;
  name: string;
  scopes: readonly string[];
}

export const MINI_APPS: Record<string, MiniAppDefinition> = {
  'credit-simulator': {
    id: 'credit-simulator',
    name: 'Simulador de crédito',
    scopes: ['credit:quote'],
  },
};
