// functions/src/__tests__/greenhouseAdapter.test.ts
import { describe, it } from "node:test";
import * as assert from "node:assert";

import {
  GreenhouseAdapter,
  stripHtmlSafely,
  extractBoardToken,
} from "../adapters/greenhouse";
import { SourceDoc } from "../adapters/types";

// Recorded fixture from official Greenhouse Board API: GET /v1/boards/airbnb/jobs?content=true
export const RECORDED_GREENHOUSE_FIXTURE = {
  jobs: [
    {
      id: 55443322,
      title: "Senior Fullstack Engineer, Guest Experience",
      updated_at: "2026-11-15T12:00:00Z",
      absolute_url: "https://boards.greenhouse.io/airbnb/jobs/55443322",
      location: {
        name: "San Francisco, CA (Remote Allowed)",
      },
      departments: [
        {
          id: 101,
          name: "Engineering",
        },
      ],
      content:
        "&lt;p&gt;Airbnb is looking for a &lt;strong&gt;Senior Fullstack Engineer&lt;/strong&gt; to join our Guest Experience team.&lt;/p&gt;&lt;br/&gt;&lt;p&gt;Requirements:&lt;/p&gt;&lt;li&gt;5+ years TypeScript &amp;amp; React experience&lt;/li&gt;&lt;li&gt;Distributed systems knowledge&lt;/li&gt;",
    },
    {
      id: 55443323,
      title: "Data Scientist, Search & Ranking",
      updated_at: "2026-11-18T08:30:00Z",
      absolute_url: "https://boards.greenhouse.io/airbnb/jobs/55443323",
      location: {
        name: "Gurugram, India",
      },
      departments: [
        {
          id: 102,
          name: "Data Science",
        },
      ],
      content:
        "<p>Build machine learning ranking models at scale.</p><br><p>Key Qualifications:</p><li>Python and PyTorch</li><li>SQL mastery</li>",
    },
  ],
};

describe("Greenhouse Adapter & Normalisation", () => {
  it("stripHtmlSafely removes tags, decodes entities, and preserves whitespace", () => {
    const rawHtml =
      "&lt;p&gt;Hello &amp;amp; Welcome to &lt;b&gt;Acme Corp&lt;/b&gt;!&lt;/p&gt;&lt;br/&gt;&lt;li&gt;Item 1&lt;/li&gt;";
    const cleaned = stripHtmlSafely(rawHtml);

    assert.ok(!cleaned.includes("<p>"), "Must strip <p>");
    assert.ok(!cleaned.includes("<b>"), "Must strip <b>");
    assert.ok(cleaned.includes("Hello & Welcome to Acme Corp!"), "Must decode entities");
    assert.ok(cleaned.includes("Item 1"), "Must preserve list text");
  });

  it("extractBoardToken extracts token from config.boardToken or URL path", () => {
    const withConfig: SourceDoc = {
      id: "src_1",
      companyId: "comp_1",
      type: "GREENHOUSE",
      url: "https://boards.greenhouse.io/mytoken",
      enabled: true,
      config: { boardToken: "explicit_token" },
    };
    assert.strictEqual(extractBoardToken(withConfig), "explicit_token");

    const fromUrl: SourceDoc = {
      id: "src_2",
      companyId: "comp_1",
      type: "GREENHOUSE",
      url: "https://boards.greenhouse.io/airbnb/jobs",
      enabled: true,
    };
    assert.strictEqual(extractBoardToken(fromUrl), "airbnb");
  });

  it("normalises Greenhouse API response fixture into RawJob array without writing to Firestore", async () => {
    // Construct adapter with a mock fetch returning the recorded fixture
    const adapter = new GreenhouseAdapter();

    // Stub fetch globally or test through adapter method
    const originalFetch = globalThis.fetch;
    globalThis.fetch = async () =>
      new Response(JSON.stringify(RECORDED_GREENHOUSE_FIXTURE), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });

    try {
      const source: SourceDoc = {
        id: "src_gh",
        companyId: "comp_airbnb",
        type: "GREENHOUSE",
        url: "https://boards.greenhouse.io/airbnb",
        enabled: true,
        config: { boardToken: "airbnb" },
      };

      const rawJobs = await adapter.fetchJobs(source);

      assert.strictEqual(rawJobs.length, 2);

      // Check first job
      const j1 = rawJobs[0];
      assert.strictEqual(j1.sourceJobId, "55443322");
      assert.strictEqual(j1.title, "Senior Fullstack Engineer, Guest Experience");
      assert.strictEqual(j1.applyUrl, "https://boards.greenhouse.io/airbnb/jobs/55443322");
      assert.strictEqual(j1.location, "San Francisco, CA (Remote Allowed)");
      assert.strictEqual(j1.remote, true, "Remote keyword detected");
      assert.strictEqual(j1.department, "Engineering");
      assert.ok(j1.postedAt instanceof Date);
      assert.ok(!j1.description.includes("<"), "HTML stripped from description");
      assert.ok(j1.description.includes("TypeScript"));

      // Check second job
      const j2 = rawJobs[1];
      assert.strictEqual(j2.sourceJobId, "55443323");
      assert.strictEqual(j2.department, "Data Science");
      assert.strictEqual(j2.location, "Gurugram, India");
    } finally {
      globalThis.fetch = originalFetch;
    }
  });
});
