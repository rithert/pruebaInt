/**
 * Feature flags de la experiencia, modificables en caliente desde
 * /admin/flags. Funcionan como *kill switches*: apagar promociones o una
 * mini app no requiere publicar una nueva versión de la app.
 */
export interface ExperienceFlags {
  insights: boolean;
  promotions: boolean;
  miniApps: boolean;
}

export const DEFAULT_FLAGS: ExperienceFlags = {
  insights: true,
  promotions: true,
  miniApps: true,
};

export class FlagStore {
  private flags: ExperienceFlags = { ...DEFAULT_FLAGS };

  current(): ExperienceFlags {
    return { ...this.flags };
  }

  update(patch: Partial<ExperienceFlags>): ExperienceFlags {
    this.flags = { ...this.flags, ...patch };
    return this.current();
  }
}
