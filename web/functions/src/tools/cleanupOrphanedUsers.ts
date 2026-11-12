/**
 * Einmaliges Aufräumen: Firestore-Daten bereits gelöschter Konten entfernen (#511).
 *
 *   npm run build
 *   GOOGLE_APPLICATION_CREDENTIALS=<service-account.json> GOOGLE_CLOUD_PROJECT=worktime-56c7a \
 *     node lib/tools/cleanupOrphanedUsers.js            # nur auflisten (Standard)
 *   ... node lib/tools/cleanupOrphanedUsers.js --delete  # wirklich löschen
 *
 * Ohne `--delete` wird nichts verändert. Ablauf und Voraussetzungen: `CONTRIBUTING.md`,
 * „Konto-Löschung“.
 */
import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";

import { findOrphanedUsers, looksLikeWrongProject } from "../orphanedUsers";
import { deleteUserData } from "../userData";

async function main(): Promise<void> {
  const doDelete = process.argv.includes("--delete");
  const force = process.argv.includes("--force");

  initializeApp();
  const db = getFirestore();
  const auth = getAuth();

  const report = await findOrphanedUsers(
    {
      listUserIds: async () => (await db.collection("users").listDocuments()).map((ref) => ref.id),
    },
    {
      existingUids: async (uids) =>
        (await auth.getUsers(uids.map((uid) => ({ uid })))).users.map((user) => user.uid),
    },
  );

  console.log(`Dokumente unter users: ${report.total}`);
  console.log(`Davon ohne Auth-User:  ${report.orphaned.length}`);
  for (const uid of report.orphaned) {
    console.log(`  ${uid}`);
  }

  if (!doDelete) {
    console.log("Probelauf: nichts gelöscht. Zum Löschen mit --delete aufrufen.");
    return;
  }
  if (report.orphaned.length === 0) {
    return;
  }
  if (looksLikeWrongProject(report) && !force) {
    throw new Error(
      "Kein einziges Dokument hat einen Auth-User. Das deutet auf ein falsches Projekt oder " +
        "falsche Zugangsdaten hin. Nichts gelöscht (bewusst übergehen: --force).",
    );
  }

  let deleted = 0;
  for (const uid of report.orphaned) {
    await deleteUserData({ doc: (path) => db.doc(path), recursiveDelete: (ref) => db.recursiveDelete(ref) }, uid);
    deleted += 1;
    console.log(`gelöscht: ${uid}`);
  }
  console.log(`Fertig: ${deleted} von ${report.orphaned.length} gelöscht.`);
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
