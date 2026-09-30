import type { BugIssueInput } from "./github";

// Status-Codes aus Uptime Kuma: 0 = DOWN, 1 = UP, 2 = PENDING, 3 = MAINTENANCE.
const STATUS_DOWN = 0;

export interface UptimeKumaWebhookBody {
  heartbeat?: { status?: number; msg?: string };
  monitor?: { id?: number; name?: string };
  msg?: string;
}

export type UptimeKumaWebhookResult =
  | { action: "unauthorized" }
  | { action: "ignored"; reason: string }
  | { action: "create"; issue: BugIssueInput };

/**
 * Reine Funktion: entscheidet anhand des Uptime-Kuma-Webhook-Bodys, ob ein Issue entstehen soll.
 * Kein Firebase-/Netzwerk-Zugriff — das Secret wird als Parameter übergeben, nicht selbst gelesen.
 */
export function evaluateUptimeKumaWebhook(
  body: UptimeKumaWebhookBody,
  providedSecret: string | undefined,
  expectedSecret: string,
): UptimeKumaWebhookResult {
  if (providedSecret !== expectedSecret) {
    return { action: "unauthorized" };
  }

  if (!body.monitor?.id || !body.monitor?.name) {
    return { action: "ignored", reason: "monitor fehlt im Payload" };
  }

  if (body.heartbeat?.status !== STATUS_DOWN) {
    return { action: "ignored", reason: "kein Down-Status" };
  }

  return {
    action: "create",
    issue: {
      marker: `uptime-kuma:${body.monitor.id}`,
      title: `Uptime-Kuma: ${body.monitor.name} ist down`,
      body: [
        "Automatisch von Uptime-Kuma erstellt.",
        "",
        `**Monitor:** ${body.monitor.name}`,
        `**Meldung:** ${body.heartbeat?.msg ?? body.msg ?? "unbekannt"}`,
        "",
        "[Status-Seite](https://status.work-time-manager.app)",
      ].join("\n"),
    },
  };
}
