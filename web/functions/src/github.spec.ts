import { describe, expect, it, vi } from "vitest";
import type { Octokit } from "@octokit/rest";
import { createBugIssueIfNotExists, markerComment } from "./github";

function fakeOctokit(totalCount: number) {
  const search = vi.fn().mockResolvedValue({ data: { total_count: totalCount } });
  const create = vi.fn().mockResolvedValue({ data: {} });
  const octokit = {
    rest: {
      search: { issuesAndPullRequests: search },
      issues: { create },
    },
  } as unknown as Octokit;
  return { octokit, search, create };
}

describe("createBugIssueIfNotExists", () => {
  it("legt kein Issue an, wenn eines mit demselben Marker bereits existiert", async () => {
    const { octokit, create } = fakeOctokit(1);
    const result = await createBugIssueIfNotExists(octokit, {
      marker: "crashlytics:abc",
      title: "Titel",
      body: "Body",
    });
    expect(result).toEqual({ created: false });
    expect(create).not.toHaveBeenCalled();
  });

  it("legt ein Issue mit Label bug und dem Marker-Kommentar im Body an, wenn keins existiert", async () => {
    const { octokit, create } = fakeOctokit(0);
    const result = await createBugIssueIfNotExists(octokit, {
      marker: "crashlytics:abc",
      title: "Titel",
      body: "Body",
    });
    expect(result).toEqual({ created: true });
    expect(create).toHaveBeenCalledWith(
      expect.objectContaining({
        owner: "Riksorax",
        repo: "Work-Time-Manager",
        title: "Titel",
        labels: ["bug"],
        body: `Body\n\n${markerComment("crashlytics:abc")}`,
      }),
    );
  });

  it("sucht nach dem versteckten Marker-Kommentar, nicht nach dem sichtbaren Titel", async () => {
    const { octokit, search } = fakeOctokit(0);
    await createBugIssueIfNotExists(octokit, { marker: "uptime-kuma:42", title: "x", body: "y" });
    expect(search).toHaveBeenCalledWith(
      expect.objectContaining({
        q: expect.stringContaining(markerComment("uptime-kuma:42")),
      }),
    );
  });
});
