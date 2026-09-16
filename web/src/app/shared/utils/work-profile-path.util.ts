import { DEFAULT_WORK_PROFILE_ID } from '../models';

/**
 * Firestore-Pfad für profil-gebundene Daten (siehe #138/#239/#244). `null`/
 * `undefined`/`'default'` verweist auf den bestehenden, nicht migrierten
 * Pfad `users/{uid}/{collection}`; jedes andere Profil liegt unter
 * `users/{uid}/profiles/{profileId}/{collection}` — identisch zu Flutter
 * (`FirestoreDataSourceImpl._profileScopedDoc`) und Backend (`ProfileScope`).
 */
export function profileScopedPath(
  uid: string,
  collection: string,
  profileId: string | null | undefined,
): string {
  if (!profileId || profileId === DEFAULT_WORK_PROFILE_ID) {
    return `users/${uid}/${collection}`;
  }
  return `users/${uid}/profiles/${profileId}/${collection}`;
}
