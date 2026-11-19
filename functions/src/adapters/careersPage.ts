// functions/src/adapters/careersPage.ts
import { JobAdapter, RawJob, SourceDoc } from "./types";

/**
 * Interface definition for Schema.org JobPosting JSON-LD.
 * Designed for future implementation.
 */
export interface JsonLdJobPosting {
  "@context"?: string;
  "@type": "JobPosting";
  title: string;
  description: string;
  datePosted?: string;
  validThrough?: string;
  employmentType?: string;
  hiringOrganization?: {
    name?: string;
    sameAs?: string;
  };
  jobLocation?: {
    address?: {
      addressLocality?: string;
      addressRegion?: string;
      addressCountry?: string;
    };
  };
  baseSalary?: unknown;
}

/**
 * Careers page scraper adapter designed to:
 * 1. Respect site robots.txt guidelines prior to crawl.
 * 2. Prioritise schema.org/JobPosting JSON-LD embedded microdata.
 * 3. Fallback to structured semantic HTML parsing.
 */
export class CareersPageAdapter implements JobAdapter {
  async fetchJobs(source: SourceDoc): Promise<RawJob[]> {
    // Stub only for today
    throw new Error(
      `NOT_IMPLEMENTED: CareersPageAdapter for ${source.url} is planned for subsequent release. ` +
      `Design prefers Schema.org JobPosting JSON-LD and respects robots.txt.`,
    );
  }
}
