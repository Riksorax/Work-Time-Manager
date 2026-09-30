import type { BugIssueInput } from "./github";

export interface CrashlyticsIssue {
  id: string;
  title: string;
  subtitle: string;
  appVersion: string;
}

const FIREBASE_PROJECT_ID = "worktime-56c7a";

/** Reine Funktion: baut aus einem Crashlytics-Alert die GitHub-Issue-Eingabe. Kein Firebase-/Netzwerk-Zugriff. */
export function buildCrashlyticsBugIssue(
  appId: string,
  issue: CrashlyticsIssue,
  kind: "fatal" | "non-fatal",
): BugIssueInput {
  const kindLabel = kind === "fatal" ? "Fatal" : "Non-Fatal";
  const crashlyticsUrl =
    `https://console.firebase.google.com/project/${FIREBASE_PROJECT_ID}` +
    `/crashlytics/app/${appId}/issues/${issue.id}`;

  return {
    marker: `crashlytics:${issue.id}`,
    title: `Crashlytics (${kindLabel}): ${issue.title}`,
    body: [
      `Automatisch von Crashlytics erstellt (${kindLabel}).`,
      "",
      `**Version:** ${issue.appVersion}`,
      `**Signatur:** ${issue.subtitle}`,
      "",
      `[In Crashlytics öffnen](${crashlyticsUrl})`,
    ].join("\n"),
  };
}
