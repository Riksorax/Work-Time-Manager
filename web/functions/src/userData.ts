/**
 * Löscht alle Firestore-Daten eines Nutzers (#511).
 *
 * Die Clients können das nicht selbst: Nach dem Löschen des Auth-Users ist niemand mehr
 * angemeldet, die Security Rules lehnen jeden Zugriff ab. Deshalb räumt der Server ab,
 * ausgelöst durch das Löschen des Auth-Users (`onUserDeleted` in `index.ts`).
 */

/** Der Teil von Firestore, den das Löschen braucht (in Tests ein Fake). */
export interface UserDataStore<Ref = unknown> {
  doc(path: string): Ref;
  /** Löscht das Dokument samt aller Unter-Collections, auch wenn das Dokument selbst nicht existiert. */
  recursiveDelete(ref: Ref): Promise<void>;
}

/** Firebase-UIDs sind 1 bis 128 Zeichen lang; ein `/` würde den Pfad verlassen. */
export function isValidUid(uid: unknown): uid is string {
  return typeof uid === "string" && uid.length > 0 && uid.length <= 128 && !uid.includes("/");
}

/**
 * Entfernt `users/{uid}` rekursiv: Arbeitseinträge, Gleitzeit, Einstellungen, Wochen-Reflexionen
 * und zusätzliche Arbeitszeit-Profile samt deren Unter-Collections. Idempotent.
 */
export async function deleteUserData<Ref>(store: UserDataStore<Ref>, uid: string): Promise<void> {
  if (!isValidUid(uid)) {
    throw new Error("Ungültige UID, es wird nichts gelöscht");
  }
  await store.recursiveDelete(store.doc(`users/${uid}`));
}
