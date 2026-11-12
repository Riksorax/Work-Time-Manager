/**
 * Findet Firestore-Daten von Konten, deren Auth-User nicht mehr existiert (#511).
 *
 * Bis 1.8.0 blieb `users/{uid}` nach einer Konto-Löschung liegen. `onUserDeleted` räumt nur
 * künftige Löschungen ab; die Altlasten findet diese Funktion.
 */

/** Höchstzahl an Kennungen je `getUsers`-Aufruf (Grenze der Admin-API). */
export const AUTH_LOOKUP_BATCH_SIZE = 100;

export interface UserDocumentLister {
  /** IDs aller Dokumente unter `users`, auch solcher, die nur noch Unter-Collections haben. */
  listUserIds(): Promise<string[]>;
}

export interface AuthLookup {
  /** Liefert die UIDs aus `uids`, zu denen ein Auth-User existiert. */
  existingUids(uids: string[]): Promise<string[]>;
}

export interface OrphanReport {
  /** Anzahl der Dokumente unter `users`. */
  total: number;
  /** UIDs ohne Auth-User, sortiert. */
  orphaned: string[];
}

export async function findOrphanedUsers(
  lister: UserDocumentLister,
  auth: AuthLookup,
): Promise<OrphanReport> {
  const ids = await lister.listUserIds();
  const existing = new Set<string>();
  for (let i = 0; i < ids.length; i += AUTH_LOOKUP_BATCH_SIZE) {
    const batch = ids.slice(i, i + AUTH_LOOKUP_BATCH_SIZE);
    for (const uid of await auth.existingUids(batch)) {
      existing.add(uid);
    }
  }
  return {
    total: ids.length,
    orphaned: ids.filter((id) => !existing.has(id)).sort(),
  };
}

/**
 * Schutz vor falschem Projekt oder falschen Zugangsdaten: Hat kein einziges Dokument einen
 * Auth-User, stimmt mit hoher Wahrscheinlichkeit die Auth-Abfrage nicht, und es darf nichts
 * gelöscht werden.
 */
export function looksLikeWrongProject(report: OrphanReport): boolean {
  return report.total > 0 && report.orphaned.length === report.total;
}
