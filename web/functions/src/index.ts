import { Octokit } from "@octokit/rest";
import { defineSecret } from "firebase-functions/params";
import {
  onNewFatalIssuePublished,
  onNewNonfatalIssuePublished,
} from "firebase-functions/v2/alerts/crashlytics";
import { onRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";

import { buildCrashlyticsBugIssue } from "./crashlyticsIssue";
import { createBugIssueIfNotExists } from "./github";
import { evaluateUptimeKumaWebhook, type UptimeKumaWebhookBody } from "./uptimeKumaWebhook";

// Fein granuliertes GitHub-PAT mit nur issues:write auf dieses Repo, siehe #322.
const githubToken = defineSecret("GITHUB_TOKEN");
// Muss demselben Wert entsprechen, den Uptime Kuma als Query-Parameter "?secret=" mitschickt
// (Webhook-Benachrichtigung → URL: .../uptimeKumaWebhook?secret=<UPTIME_KUMA_SECRET>).
const uptimeKumaSecret = defineSecret("UPTIME_KUMA_SECRET");

export const onCrashlyticsFatal = onNewFatalIssuePublished(
  { secrets: [githubToken] },
  async (event) => {
    const { issue } = event.data.payload;
    const bugIssue = buildCrashlyticsBugIssue(event.appId, issue, "fatal");
    const octokit = new Octokit({ auth: githubToken.value() });
    const result = await createBugIssueIfNotExists(octokit, bugIssue);
    logger.info("Crashlytics fatal alert verarbeitet", { issueId: issue.id, ...result });
  },
);

export const onCrashlyticsNonFatal = onNewNonfatalIssuePublished(
  { secrets: [githubToken] },
  async (event) => {
    const { issue } = event.data.payload;
    const bugIssue = buildCrashlyticsBugIssue(event.appId, issue, "non-fatal");
    const octokit = new Octokit({ auth: githubToken.value() });
    const result = await createBugIssueIfNotExists(octokit, bugIssue);
    logger.info("Crashlytics non-fatal alert verarbeitet", { issueId: issue.id, ...result });
  },
);

export const uptimeKumaWebhook = onRequest(
  { secrets: [githubToken, uptimeKumaSecret] },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    const result = evaluateUptimeKumaWebhook(
      req.body as UptimeKumaWebhookBody,
      typeof req.query.secret === "string" ? req.query.secret : undefined,
      uptimeKumaSecret.value(),
    );

    if (result.action === "unauthorized") {
      res.status(401).send("Unauthorized");
      return;
    }

    if (result.action === "ignored") {
      logger.debug("Uptime-Kuma-Webhook ignoriert", { reason: result.reason });
      res.status(200).send("ignored");
      return;
    }

    const octokit = new Octokit({ auth: githubToken.value() });
    const created = await createBugIssueIfNotExists(octokit, result.issue);
    logger.info("Uptime-Kuma-Down-Alarm verarbeitet", { marker: result.issue.marker, ...created });
    res.status(200).send("ok");
  },
);
