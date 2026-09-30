import { describe, expect, it } from "vitest";
import { buildCrashlyticsBugIssue } from "./crashlyticsIssue";

const ISSUE = { id: "abc123", title: "NullPointerException", subtitle: "at MainActivity.onCreate", appVersion: "1.4.2" };

describe("buildCrashlyticsBugIssue", () => {
  it("marker enthält die Crashlytics-Issue-ID für die Dedup-Prüfung", () => {
    const result = buildCrashlyticsBugIssue("app-1", ISSUE, "fatal");
    expect(result.marker).toBe("crashlytics:abc123");
  });

  it("kennzeichnet fatale Fehler im Titel", () => {
    const result = buildCrashlyticsBugIssue("app-1", ISSUE, "fatal");
    expect(result.title).toBe("Crashlytics (Fatal): NullPointerException");
  });

  it("kennzeichnet non-fatale Fehler im Titel", () => {
    const result = buildCrashlyticsBugIssue("app-1", ISSUE, "non-fatal");
    expect(result.title).toBe("Crashlytics (Non-Fatal): NullPointerException");
  });

  it("body enthält Version, Signatur und einen Link in die Firebase-Konsole", () => {
    const result = buildCrashlyticsBugIssue("app-1", ISSUE, "fatal");
    expect(result.body).toContain("1.4.2");
    expect(result.body).toContain("at MainActivity.onCreate");
    expect(result.body).toContain("https://console.firebase.google.com/project/worktime-56c7a/crashlytics/app/app-1/issues/abc123");
  });
});
