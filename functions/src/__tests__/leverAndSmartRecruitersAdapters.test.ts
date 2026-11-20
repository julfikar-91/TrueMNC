// functions/src/__tests__/leverAndSmartRecruitersAdapters.test.ts
import { describe, it } from "node:test";
import * as assert from "node:assert/strict";

import { LeverAdapter, extractLeverSite } from "../adapters/lever";
import {
  SmartRecruitersAdapter,
  extractSmartRecruitersCompany,
} from "../adapters/smartrecruiters";
import { SourceDoc } from "../adapters/types";

// ── RECORDED FIXTURES ────────────────────────────────────────────────────────

export const LEVER_PAGE_1_FIXTURE = [
  {
    id: "lever_job_1",
    text: "Senior Backend Engineer",
    createdAt: 1700000000000,
    description: "<p>Build high-throughput microservices using Go and PostgreSQL.</p>",
    hostedUrl: "https://jobs.lever.co/netflix/lever_job_1",
    applyUrl: "https://jobs.lever.co/netflix/lever_job_1/apply",
    workplaceType: "remote",
    categories: {
      commitment: "Full-time",
      department: "Core Engineering",
      location: "San Jose, CA",
    },
  },
  {
    id: "lever_job_malformed",
    // Missing text (title) -> must be skipped
    createdAt: 1700000000000,
  },
  {
    id: "lever_job_lookalike",
    text: "Security Analyst",
    createdAt: 1700000000000,
    description: "Lookalike scam post designed to test Rule R2 rejection.",
    // Lookalike domain must be preserved verbatim so Rule R2 rejects it downstream
    hostedUrl: "https://jobs.lever-phish.co/netflix/lever_job_lookalike",
    applyUrl: "https://jobs.lever-phish.co/netflix/lever_job_lookalike/apply",
    workplaceType: "hybrid",
    categories: {
      commitment: "Full-time",
      department: "Security",
      location: "Remote, India",
    },
  },
];

export const SMARTRECRUITERS_PAGE_1_FIXTURE = {
  totalFound: 2,
  offset: 0,
  limit: 100,
  content: [
    {
      id: "sr_job_1",
      name: "Cloud Infrastructure Architect",
      releasedDate: "2026-11-15T10:00:00.000Z",
      location: {
        city: "Bengaluru",
        region: "Karnataka",
        country: "India",
        remote: true,
      },
      department: {
        id: "dept_cloud",
        label: "Cloud Architecture",
      },
      typeOfEmployment: {
        id: "full_time",
        label: "Permanent",
      },
      applyUrl: "https://jobs.smartrecruiters.com/AcmeCorp/sr_job_1",
      jobAd: {
        sections: {
          jobDescription: {
            text: "<p>Lead Google Cloud and Kubernetes architectural migrations.</p>",
          },
        },
      },
    },
    {
      id: "sr_job_malformed",
      // Missing name (title) -> must be skipped
      releasedDate: "2026-11-15T10:00:00.000Z",
    },
    {
      id: "sr_job_lookalike",
      name: "Financial Controller",
      releasedDate: "2026-11-15T10:00:00.000Z",
      location: {
        city: "Mumbai",
        country: "India",
      },
      // Lookalike domain must be preserved verbatim for Rule R2 to reject
      applyUrl: "https://smartrecruiters-scam.com/AcmeCorp/sr_job_lookalike",
    },
  ],
};

// ── TESTS ────────────────────────────────────────────────────────────────────

describe("Lever Adapter & Normalisation", () => {
  it("1. Site Extraction: extracts from config or URL", () => {
    const fromConfig: SourceDoc = {
      id: "src_lever_1",
      companyId: "comp_1",
      type: "LEVER",
      url: "https://jobs.lever.co/netflix",
      enabled: true,
      config: { site: "netflix_careers" },
    };
    assert.strictEqual(extractLeverSite(fromConfig), "netflix_careers");

    const fromUrl: SourceDoc = {
      id: "src_lever_2",
      companyId: "comp_1",
      type: "LEVER",
      url: "https://jobs.lever.co/spotify/jobs",
      enabled: true,
    };
    assert.strictEqual(extractLeverSite(fromUrl), "spotify");
  });

  it("2. Empty Board: returns empty array cleanly", async () => {
    const adapter = new LeverAdapter();
    const originalFetch = globalThis.fetch;
    globalThis.fetch = async () =>
      new Response(JSON.stringify([]), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });

    try {
      const source: SourceDoc = {
        id: "src_empty",
        companyId: "comp_1",
        type: "LEVER",
        url: "https://jobs.lever.co/emptyboard",
        enabled: true,
      };
      const jobs = await adapter.fetchJobs(source);
      assert.strictEqual(jobs.length, 0);
    } finally {
      globalThis.fetch = originalFetch;
    }
  });

  it("3. Malformed Items Skipped & Lookalike Apply URL Preserved for R2", async () => {
    const adapter = new LeverAdapter();
    const originalFetch = globalThis.fetch;
    globalThis.fetch = async () =>
      new Response(JSON.stringify(LEVER_PAGE_1_FIXTURE), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });

    try {
      const source: SourceDoc = {
        id: "src_lever",
        companyId: "comp_netflix",
        type: "LEVER",
        url: "https://jobs.lever.co/netflix",
        enabled: true,
      };
      const jobs = await adapter.fetchJobs(source);

      // Malformed item skipped: only 2 valid jobs out of 3 fixture items
      assert.strictEqual(jobs.length, 2);

      // Job 1 verified
      const job1 = jobs[0];
      assert.strictEqual(job1.sourceJobId, "lever_job_1");
      assert.strictEqual(job1.title, "Senior Backend Engineer");
      assert.strictEqual(job1.remote, true);
      assert.strictEqual(job1.location, "San Jose, CA");
      assert.strictEqual(job1.employmentType, "Full-time");
      assert.ok(job1.description.includes("Build high-throughput microservices"));

      // Job 2 (lookalike) preserved verbatim so downstream Rule R2 rejects it
      const lookalike = jobs[1];
      assert.strictEqual(lookalike.sourceJobId, "lever_job_lookalike");
      assert.strictEqual(
        lookalike.applyUrl,
        "https://jobs.lever-phish.co/netflix/lever_job_lookalike",
        "Lookalike host must be preserved for Rule R2 to catch",
      );
    } finally {
      globalThis.fetch = originalFetch;
    }
  });

  it("4. Pagination: fetches consecutive pages using cursor skip", async () => {
    const adapter = new LeverAdapter();
    const originalFetch = globalThis.fetch;
    let callCount = 0;

    globalThis.fetch = async (input: any) => {
      callCount++;
      const urlStr = input.toString();

      // Page 1 returns 100 items (simulated)
      if (!urlStr.includes("skip=")) {
        const page1 = Array.from({ length: 100 }, (_, i) => ({
          id: `job_p1_${i}`,
          text: `Engineer ${i}`,
          hostedUrl: `https://jobs.lever.co/test/job_p1_${i}`,
        }));
        return new Response(JSON.stringify(page1), { status: 200 });
      }

      // Page 2 returns 5 items
      const page2 = Array.from({ length: 5 }, (_, i) => ({
        id: `job_p2_${i}`,
        text: `Designer ${i}`,
        hostedUrl: `https://jobs.lever.co/test/job_p2_${i}`,
      }));
      return new Response(JSON.stringify(page2), { status: 200 });
    };

    try {
      const source: SourceDoc = {
        id: "src_paged",
        companyId: "comp_1",
        type: "LEVER",
        url: "https://jobs.lever.co/test",
        enabled: true,
      };
      const jobs = await adapter.fetchJobs(source);
      assert.strictEqual(callCount, 2);
      assert.strictEqual(jobs.length, 105);
    } finally {
      globalThis.fetch = originalFetch;
    }
  });
});

describe("SmartRecruiters Adapter & Normalisation", () => {
  it("1. Company Extraction: extracts from config or URL", () => {
    const fromConfig: SourceDoc = {
      id: "src_sr_1",
      companyId: "comp_1",
      type: "SMARTRECRUITERS",
      url: "https://jobs.smartrecruiters.com/Acme",
      enabled: true,
      config: { companyIdentifier: "AcmeCorpGlobal" },
    };
    assert.strictEqual(extractSmartRecruitersCompany(fromConfig), "AcmeCorpGlobal");

    const fromUrl: SourceDoc = {
      id: "src_sr_2",
      companyId: "comp_1",
      type: "SMARTRECRUITERS",
      url: "https://careers.smartrecruiters.com/Stripe/jobs",
      enabled: true,
    };
    assert.strictEqual(extractSmartRecruitersCompany(fromUrl), "Stripe");
  });

  it("2. Empty Board: returns empty array cleanly", async () => {
    const adapter = new SmartRecruitersAdapter();
    const originalFetch = globalThis.fetch;
    globalThis.fetch = async () =>
      new Response(JSON.stringify({ totalFound: 0, content: [] }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });

    try {
      const source: SourceDoc = {
        id: "src_empty_sr",
        companyId: "comp_1",
        type: "SMARTRECRUITERS",
        url: "https://jobs.smartrecruiters.com/empty",
        enabled: true,
      };
      const jobs = await adapter.fetchJobs(source);
      assert.strictEqual(jobs.length, 0);
    } finally {
      globalThis.fetch = originalFetch;
    }
  });

  it("3. Malformed Items Skipped & Lookalike Apply URL Preserved for R2", async () => {
    const adapter = new SmartRecruitersAdapter();
    const originalFetch = globalThis.fetch;
    globalThis.fetch = async () =>
      new Response(JSON.stringify(SMARTRECRUITERS_PAGE_1_FIXTURE), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });

    try {
      const source: SourceDoc = {
        id: "src_sr",
        companyId: "comp_acme",
        type: "SMARTRECRUITERS",
        url: "https://jobs.smartrecruiters.com/AcmeCorp",
        enabled: true,
      };
      const jobs = await adapter.fetchJobs(source);

      // Malformed item skipped: only 2 valid jobs out of 3 fixture items
      assert.strictEqual(jobs.length, 2);

      // Job 1 verified
      const job1 = jobs[0];
      assert.strictEqual(job1.sourceJobId, "sr_job_1");
      assert.strictEqual(job1.title, "Cloud Infrastructure Architect");
      assert.strictEqual(job1.remote, true);
      assert.strictEqual(job1.location, "Bengaluru, Karnataka, India");
      assert.strictEqual(job1.employmentType, "Permanent");
      assert.ok(job1.description.includes("Lead Google Cloud and Kubernetes"));

      // Job 2 (lookalike) preserved verbatim so downstream Rule R2 rejects it
      const lookalike = jobs[1];
      assert.strictEqual(lookalike.sourceJobId, "sr_job_lookalike");
      assert.strictEqual(
        lookalike.applyUrl,
        "https://smartrecruiters-scam.com/AcmeCorp/sr_job_lookalike",
        "Lookalike host must be preserved for Rule R2 to catch",
      );
    } finally {
      globalThis.fetch = originalFetch;
    }
  });

  it("4. Pagination: fetches consecutive pages using offset and limit", async () => {
    const adapter = new SmartRecruitersAdapter();
    const originalFetch = globalThis.fetch;
    let callCount = 0;

    globalThis.fetch = async (input: any) => {
      callCount++;
      const urlStr = input.toString();

      if (urlStr.includes("offset=0")) {
        const page1 = Array.from({ length: 100 }, (_, i) => ({
          id: `sr_p1_${i}`,
          name: `Developer ${i}`,
        }));
        return new Response(
          JSON.stringify({ totalFound: 102, limit: 100, offset: 0, content: page1 }),
          { status: 200 },
        );
      }

      // Page 2 at offset=100
      const page2 = Array.from({ length: 2 }, (_, i) => ({
        id: `sr_p2_${i}`,
        name: `Tester ${i}`,
      }));
      return new Response(
        JSON.stringify({ totalFound: 102, limit: 100, offset: 100, content: page2 }),
        { status: 200 },
      );
    };

    try {
      const source: SourceDoc = {
        id: "src_paged_sr",
        companyId: "comp_1",
        type: "SMARTRECRUITERS",
        url: "https://jobs.smartrecruiters.com/test",
        enabled: true,
      };
      const jobs = await adapter.fetchJobs(source);
      assert.strictEqual(callCount, 2);
      assert.strictEqual(jobs.length, 102);
    } finally {
      globalThis.fetch = originalFetch;
    }
  });
});
