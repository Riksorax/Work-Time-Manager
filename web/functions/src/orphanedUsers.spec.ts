import { describe, expect, it, vi } from "vitest";
import { AUTH_LOOKUP_BATCH_SIZE, findOrphanedUsers, looksLikeWrongProject } from "./orphanedUsers";

function setup(ids: string[], existing: string[]) {
  const existingUids = vi.fn(async (uids: string[]) => uids.filter((uid) => existing.includes(uid)));
  return { lister: { listUserIds: async () => ids }, auth: { existingUids }, existingUids };
}

describe("findOrphanedUsers", () => {
  it("meldet nur UIDs ohne Auth-User, sortiert", async () => {
    const { lister, auth } = setup(["c", "a", "b"], ["a"]);
    expect(await findOrphanedUsers(lister, auth)).toEqual({ total: 3, orphaned: ["b", "c"] });
  });

  it("meldet nichts, wenn alle einen Auth-User haben", async () => {
    const { lister, auth } = setup(["a", "b"], ["a", "b"]);
    expect(await findOrphanedUsers(lister, auth)).toEqual({ total: 2, orphaned: [] });
  });

  it("fragt Auth in Blöcken der erlaubten Größe ab", async () => {
    const ids = Array.from({ length: AUTH_LOOKUP_BATCH_SIZE * 2 + 1 }, (_, i) => `u${i}`);
    const { lister, auth, existingUids } = setup(ids, ids.slice(1));
    const report = await findOrphanedUsers(lister, auth);
    expect(existingUids.mock.calls.map(([batch]) => batch.length)).toEqual([
      AUTH_LOOKUP_BATCH_SIZE,
      AUTH_LOOKUP_BATCH_SIZE,
      1,
    ]);
    expect(report.orphaned).toEqual(["u0"]);
  });

  it("reicht Fehler der Auth-Abfrage weiter, statt alle als verwaist zu melden", async () => {
    const { lister } = setup(["a"], []);
    const auth = { existingUids: vi.fn().mockRejectedValue(new Error("permission")) };
    await expect(findOrphanedUsers(lister, auth)).rejects.toThrow("permission");
  });
});

describe("looksLikeWrongProject", () => {
  it("schlägt an, wenn kein Dokument einen Auth-User hat", () => {
    expect(looksLikeWrongProject({ total: 2, orphaned: ["a", "b"] })).toBe(true);
  });

  it("schlägt nicht an bei gemischtem Ergebnis oder leerer Collection", () => {
    expect(looksLikeWrongProject({ total: 2, orphaned: ["a"] })).toBe(false);
    expect(looksLikeWrongProject({ total: 0, orphaned: [] })).toBe(false);
  });
});
