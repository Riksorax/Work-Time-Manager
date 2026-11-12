import { describe, expect, it, vi } from "vitest";
import { deleteUserData, isValidUid } from "./userData";

function fakeStore() {
  const recursiveDelete = vi.fn().mockResolvedValue(undefined);
  return { store: { doc: (path: string) => ({ path }), recursiveDelete }, recursiveDelete };
}

describe("deleteUserData", () => {
  it("löscht users/{uid} rekursiv", async () => {
    const { store, recursiveDelete } = fakeStore();
    await deleteUserData(store, "abc123");
    expect(recursiveDelete).toHaveBeenCalledTimes(1);
    expect(recursiveDelete).toHaveBeenCalledWith({ path: "users/abc123" });
  });

  it.each(["", "a/b", "../users", "x".repeat(129)])("löscht nichts bei ungültiger UID %j", async (uid) => {
    const { store, recursiveDelete } = fakeStore();
    await expect(deleteUserData(store, uid)).rejects.toThrow("Ungültige UID");
    expect(recursiveDelete).not.toHaveBeenCalled();
  });

  it("reicht Fehler weiter, damit der Trigger wiederholt wird", async () => {
    const { store, recursiveDelete } = fakeStore();
    recursiveDelete.mockRejectedValue(new Error("unavailable"));
    await expect(deleteUserData(store, "abc123")).rejects.toThrow("unavailable");
  });
});

describe("isValidUid", () => {
  it("akzeptiert eine übliche Firebase-UID", () => {
    expect(isValidUid("Xk3f9aQ2ZbN7pLm0RtYu4WvE1cD2")).toBe(true);
  });

  it.each([undefined, null, 42, {}])("lehnt %j ab", (value) => {
    expect(isValidUid(value)).toBe(false);
  });
});
