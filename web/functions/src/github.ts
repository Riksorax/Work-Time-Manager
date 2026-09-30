import type { Octokit } from "@octokit/rest";

const REPO_OWNER = "Riksorax";
const REPO_NAME = "Work-Time-Manager";

export interface BugIssueInput {
  /** Eindeutiger Schlüssel zur Dedup-Prüfung, z. B. "crashlytics:<issueId>" oder "uptime-kuma:<monitorId>". */
  marker: string;
  title: string;
  body: string;
}

/** Versteckter HTML-Kommentar im Issue-Body, über den spätere Läufe Duplikate erkennen. */
export function markerComment(marker: string): string {
  return `<!-- auto-monitoring:${marker} -->`;
}

/**
 * Legt ein GitHub-Issue mit Label "bug" an, außer es existiert bereits eines mit demselben
 * Marker (Schutz gegen doppelte Cloud-Function-Aufrufe bei Retries/Flapping).
 */
export async function createBugIssueIfNotExists(
  octokit: Octokit,
  input: BugIssueInput,
): Promise<{ created: boolean }> {
  const comment = markerComment(input.marker);

  const existing = await octokit.rest.search.issuesAndPullRequests({
    q: `repo:${REPO_OWNER}/${REPO_NAME} is:issue in:body "${comment}"`,
  });

  if (existing.data.total_count > 0) {
    return { created: false };
  }

  await octokit.rest.issues.create({
    owner: REPO_OWNER,
    repo: REPO_NAME,
    title: input.title,
    body: `${input.body}\n\n${comment}`,
    labels: ["bug"],
  });

  return { created: true };
}
