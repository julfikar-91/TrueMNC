// functions/src/adapters/smartrecruiters.ts
import { JobAdapter, RawJob, SourceDoc } from "./types";
import { stripHtmlSafely } from "./greenhouse";
import { logInfo, logWarn, logError } from "../utils/logger";

const FN = "SmartRecruitersAdapter";
const DEFAULT_BASE_URL = "https://api.smartrecruiters.com/v1/companies";
const APP_USER_AGENT = "TrueCorporateJobFinder/1.0 (+https://truemnc.com/bot; bot@truemnc.com)";
const REQUEST_TIMEOUT_MS = 15000;
const MAX_RETRIES = 5;
const PAGE_SIZE = 100;
const MAX_PAGES = 50;

export interface SmartRecruitersLocation {
  city?: string;
  region?: string;
  country?: string;
  postalCode?: string;
  remote?: boolean;
}

export interface SmartRecruitersPosting {
  id: string;
  name: string;
  uuid?: string;
  refNumber?: string;
  releasedDate?: string;
  location?: SmartRecruitersLocation;
  department?: {
    id?: string;
    label?: string;
  };
  typeOfEmployment?: {
    id?: string;
    label?: string;
  };
  experienceLevel?: {
    id?: string;
    label?: string;
  };
  applyUrl?: string;
  jobAd?: {
    sections?: {
      jobDescription?: {
        text?: string;
      };
      qualifications?: {
        text?: string;
      };
      additionalInformation?: {
        text?: string;
      };
    };
  };
}

export interface SmartRecruitersPageResponse {
  totalFound?: number;
  offset?: number;
  limit?: number;
  content?: SmartRecruitersPosting[];
}

/**
 * Extracts SmartRecruiters company identifier from config or source URL.
 */
export function extractSmartRecruitersCompany(source: SourceDoc): string {
  if (source.config?.companyIdentifier && typeof source.config.companyIdentifier === "string") {
    return source.config.companyIdentifier.trim();
  }
  if (source.config?.boardToken && typeof source.config.boardToken === "string") {
    return source.config.boardToken.trim();
  }

  try {
    const url = new URL(source.url);
    const pathParts = url.pathname.split("/").filter(Boolean);
    if (pathParts.length > 0) {
      return pathParts[0];
    }
  } catch {
    // Ignore invalid URL parse
  }

  throw new Error(`Invalid SmartRecruiters source config: missing companyIdentifier/boardToken for source ${source.id}`);
}

export class SmartRecruitersAdapter implements JobAdapter {
  private readonly baseUrl: string;

  constructor(customBaseUrl?: string) {
    this.baseUrl = customBaseUrl || process.env.SMARTRECRUITERS_API_BASE_URL || DEFAULT_BASE_URL;
  }

  async fetchJobs(source: SourceDoc): Promise<RawJob[]> {
    const companyId = extractSmartRecruitersCompany(source);
    const apiBase = ((source.config?.apiBaseUrl as string) || this.baseUrl).replace(/\/$/, "");

    logInfo(FN, "Fetching jobs from SmartRecruiters Postings API", {
      sourceId: source.id,
      companyId,
      apiBase,
    });

    const allRawJobs: RawJob[] = [];
    let offset = 0;
    let pageCount = 0;

    while (pageCount < MAX_PAGES) {
      pageCount++;
      const url = `${apiBase}/${companyId}/postings?limit=${PAGE_SIZE}&offset=${offset}`;

      const response = await this.fetchWithRetry(url);
      const data = (await response.json()) as SmartRecruitersPageResponse;

      if (!data || !Array.isArray(data.content)) {
        logWarn(FN, "Unexpected SmartRecruiters response structure: expected content array", {
          sourceId: source.id,
        });
        break;
      }

      if (data.content.length === 0) {
        break;
      }

      for (const item of data.content) {
        const normalised = this.normaliseJob(item, companyId);
        if (normalised) {
          allRawJobs.push(normalised);
        } else {
          logWarn(FN, "Skipping malformed SmartRecruiters posting", { sourceId: source.id });
        }
      }

      offset += data.content.length;

      if (data.totalFound !== undefined && offset >= data.totalFound) {
        break;
      }

      if (data.content.length < PAGE_SIZE) {
        break;
      }
    }

    logInfo(FN, `Successfully fetched ${allRawJobs.length} jobs from SmartRecruiters`, {
      sourceId: source.id,
      companyId,
      pages: pageCount,
    });

    return allRawJobs;
  }

  private async fetchWithRetry(url: string, retryCount = 0): Promise<Response> {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);

    try {
      const response = await fetch(url, {
        headers: {
          "User-Agent": APP_USER_AGENT,
          Accept: "application/json",
        },
        signal: controller.signal,
      });

      clearTimeout(timeout);

      // Handle Rate Limiting (429) & Server Errors (5xx) with Exponential Backoff
      if (
        (response.status === 429 || response.status >= 500) &&
        retryCount < MAX_RETRIES
      ) {
        const delay = Math.pow(2, retryCount) * 1000 + Math.random() * 500;
        logWarn(FN, `Request failed with status ${response.status}. Retrying in ${delay}ms...`, {
          url,
          retryCount,
        });
        await new Promise((resolve) => setTimeout(resolve, delay));
        return this.fetchWithRetry(url, retryCount + 1);
      }

      if (!response.ok) {
        throw new Error(
          `SmartRecruiters API responded with HTTP status ${response.status} ${response.statusText}`,
        );
      }

      return response;
    } catch (err: unknown) {
      clearTimeout(timeout);

      if (retryCount < MAX_RETRIES) {
        const delay = Math.pow(2, retryCount) * 1000 + Math.random() * 500;
        logWarn(FN, `Network error fetching SmartRecruiters API. Retrying in ${delay}ms...`, {
          error: (err as Error).message,
          retryCount,
        });
        await new Promise((resolve) => setTimeout(resolve, delay));
        return this.fetchWithRetry(url, retryCount + 1);
      }

      logError(FN, err, { url, retriesExhausted: true });
      throw err;
    }
  }

  private normaliseJob(data: unknown, companyId: string): RawJob | null {
    if (!data || typeof data !== "object") return null;
    const item = data as SmartRecruitersPosting;

    // Must have id and name (title)
    if (!item.id || typeof item.id !== "string" || !item.name || typeof item.name !== "string") {
      return null;
    }

    const title = item.name.trim();
    if (!title) return null;

    // Combine job description sections if present
    const sections = item.jobAd?.sections;
    const rawContent = [
      sections?.jobDescription?.text,
      sections?.qualifications?.text,
      sections?.additionalInformation?.text,
    ]
      .filter(Boolean)
      .join("\n\n");

    const cleanDescription = stripHtmlSafely(rawContent || title);

    // Apply URL: preserve lookalike host verbatim so rule R2 can reject lookalikes
    const applyUrl =
      item.applyUrl || `https://jobs.smartrecruiters.com/${companyId}/${item.id}`;

    // Format location string
    const locParts = [
      item.location?.city,
      item.location?.region,
      item.location?.country,
    ].filter(Boolean);
    const location = locParts.length > 0 ? locParts.join(", ") : null;

    // Remote detection
    const isExplicitRemote = item.location?.remote === true;
    const titleOrLoc = `${title} ${location ?? ""}`.toLowerCase();
    const isRemote =
      isExplicitRemote ||
      titleOrLoc.includes("remote") ||
      titleOrLoc.includes("work from home") ||
      titleOrLoc.includes("wfh") ||
      titleOrLoc.includes("anywhere");

    // Department & Employment Type
    const department = item.department?.label || item.department?.id || null;
    const employmentType =
      item.typeOfEmployment?.label || item.typeOfEmployment?.id || null;

    // Released / posted date
    let postedAt: Date | null = null;
    if (item.releasedDate) {
      const parsed = new Date(item.releasedDate);
      if (!isNaN(parsed.getTime())) {
        postedAt = parsed;
      }
    }

    return {
      sourceJobId: item.id,
      title,
      description: cleanDescription,
      applyUrl,
      location,
      remote: isRemote,
      postedAt,
      deadline: null,
      department,
      employmentType,
      raw: item,
    };
  }
}
