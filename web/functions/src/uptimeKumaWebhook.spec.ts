import { describe, expect, it } from "vitest";
import { evaluateUptimeKumaWebhook, type UptimeKumaWebhookBody } from "./uptimeKumaWebhook";

const SECRET = "test-secret";
const MONITOR = { id: 42, name: "API" };

function body(overrides: Partial<UptimeKumaWebhookBody> = {}): UptimeKumaWebhookBody {
  return { heartbeat: { status: 0, msg: "connection refused" }, monitor: MONITOR, ...overrides };
}

describe("evaluateUptimeKumaWebhook", () => {
  it("weist ein falsches Secret zurück, ohne den Body zu prüfen", () => {
    const result = evaluateUptimeKumaWebhook(body(), "falsch", SECRET);
    expect(result.action).toBe("unauthorized");
  });

  it("weist ein fehlendes Secret zurück", () => {
    const result = evaluateUptimeKumaWebhook(body(), undefined, SECRET);
    expect(result.action).toBe("unauthorized");
  });

  it("ignoriert Heartbeats ohne Down-Status (z. B. UP, PENDING, MAINTENANCE)", () => {
    const result = evaluateUptimeKumaWebhook(body({ heartbeat: { status: 1, msg: "ok" } }), SECRET, SECRET);
    expect(result).toEqual({ action: "ignored", reason: "kein Down-Status" });
  });

  it("ignoriert Payloads ohne Monitor-Informationen", () => {
    const result = evaluateUptimeKumaWebhook(body({ monitor: undefined }), SECRET, SECRET);
    expect(result.action).toBe("ignored");
  });

  it("erstellt bei Down-Status ein Issue mit Monitor-ID als Marker", () => {
    const result = evaluateUptimeKumaWebhook(body(), SECRET, SECRET);
    expect(result).toEqual({
      action: "create",
      issue: {
        marker: "uptime-kuma:42",
        title: "Uptime-Kuma: API ist down",
        body: [
          "Automatisch von Uptime-Kuma erstellt.",
          "",
          "**Monitor:** API",
          "**Meldung:** connection refused",
          "",
          "[Status-Seite](https://status.work-time-manager.app)",
        ].join("\n"),
      },
    });
  });

  it("fällt auf das Top-Level-msg zurück, wenn heartbeat.msg fehlt", () => {
    const result = evaluateUptimeKumaWebhook(
      body({ heartbeat: { status: 0 }, msg: "Fallback-Meldung" }),
      SECRET,
      SECRET,
    );
    expect(result.action).toBe("create");
    if (result.action === "create") {
      expect(result.issue.body).toContain("Fallback-Meldung");
    }
  });
});
