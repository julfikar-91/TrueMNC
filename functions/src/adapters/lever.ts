// functions/src/adapters/lever.ts
import { JobAdapter, RawJob, SourceDoc } from "./types";
import { stripHtmlSafely } from "./greenhouse";
import { logInfo, logWarn, logError } from "../utils/logger";

const FN = "LeverAdapter";
const DEFAULT_BASE_URL = "https://api.lever.co/v0/postings";
const APP_USER_AGENT = "TrueCorporateJobFinder/1.0 (+https://truemnc.com/bot; bot@truemnc.com)";
const REQUEST_TIMEOUT_MS = 15000;
const MAX_RETRIES = 5;
const PAGE_SIZE = 100;
const MAX_PAGES = 50;

export interface LeverCategories {
  commitment?: string;
  department?: string;
  team?: string;
  location?: string;
  allLocations?: string[];
}

export interface LeverPosting {
  id: string;
  text: string;
  createdAt?: number;
  description?: string;
  descriptionPlain?: string;
  hostedUrl?: string;
  applyUrl?: string;
  workplaceType?: string;
  categories?: LeverCategories;
  additional?: string;
  additionalPlain?: string;
}

/**
 * Extracts Lever site identifier from config or source URL.
 */
export function extractLeverSite(source: SourceDoc): string {
  if (source.config?.site && typeof source.config.site === "string") {
    return source.config.site.trim();
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

  throw new Error(`Invalid Lever source config: missing site/boardToken for source ${source.id}`);
}

export class LeverAdapter implements JobAdapter {
  private readonly baseUrl: string;

  constructor(customBaseUrl?: string) {
    this.baseUrl = customBaseUrl || process.env.LEVER_API_BASE_URL || DEFAULT_BASE_URL;
  }

  async fetchJobs(source: SourceDoc): Promise<RawJob[]> {
    const site = extractLeverSite(source);
    const apiBase = ((source.config?.apiBaseUrl as string) || this.baseUrl).replace(/\/$/, "");

    logInfo(FN, "Fetching jobs from Lever Postings API", {
      sourceId: source.id,
      site,
      apiBase,
    });

    const allRawJobs: RawJob[] = [];
    let skip: string | undefined;
    let pageCount = 0;

    while (pageCount < MAX_PAGES) {
      pageCount++;
      let url = `${apiBase}/${site}?mode=json&limit=${PAGE_SIZE}`;
      if (skip) {
        url += `&skip=${encodeURIComponent(skip)}`;
      }

      const response = await this.fetchWithRetry(url);
      const data = (await response.json()) as unknown;

      if (!Array.isArray(data)) {
        logWarn(FN, "Unexpected Lever response format: expected array", { sourceId: source.id });
        break;
      }

      if (data.length === 0) {
        break;
      }

      for (const item of data) {
        const normalised = this.normaliseJob(item, site);
        if (normalised) {
          allRawJobs.push(normalised);
        } else {
          logWarn(FN, "Skipping malformed Lever posting", { sourceId: source.id });
        }
      }

      if (data.length < PAGE_SIZE) {
        // Last page reached
        break;
      }

      // Next cursor is the ID of the last item in the page
      const lastItem = data[data.length - 1] as LeverPosting;
      if (lastItem?.id && lastItem.id !== skip) {
        skip = lastItem.id;
      } else {
        break;
      }
    }

    logInfo(FN, `Successfully fetched ${allRawJobs.length} jobs from Lever`, {
      sourceId: source.id,
      site,
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
        throw new Error(`Lever API responded with HTTP status ${response.status} ${response.statusText}`);
      }

      return response;
    } catch (err: unknown) {
      clearTimeout(timeout);

      if (retryCount < MAX_RETRIES) {
        const delay = Math.pow(2, retryCount) * 1000 + Math.random() * 500;
        logWarn(FN, `Network error fetching Lever API. Retrying in ${delay}ms...`, {
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

  private normaliseJob(data: unknown, site: string): RawJob | null {
    if (!data || typeof data !== "object") return null;
    const item = data as LeverPosting;

    // Must have id and text (title)
    if (!item.id || typeof item.id !== "string" || !item.text || typeof item.text !== "string") {
      return null;
    }

    const title = item.text.trim();
    if (!title) return null;

    // Clean HTML description safely
    const rawContent = item.description || item.descriptionPlain || "";
    const cleanDescription = stripHtmlSafely(rawContent);

    // Apply URL: preserve lookalike or custom URLs verbatim so rule R2 can validate host
    const applyUrl = item.hostedUrl || item.applyUrl || `https://jobs.lever.co/${site}/${item.id}`;

    // Location & Remote status
    const location = item.categories?.location?.trim() || null;
    const workplace = item.workplaceType?.toLowerCase() || "";
    const titleOrLoc = `${title} ${location ?? ""} ${workplace}`.toLowerCase();

    const isRemote =
      workplace === "remote" ||
      titleOrLoc.includes("remote") ||
      titleOrLoc.includes("work from home") ||
      titleOrLoc.includes("wfh") ||
      titleOrLoc.includes("anywhere");

    // Department & Employment Type
    const department = item.categories?.department?.trim() || item.categories?.team?.trim() || null;
    const employmentType = item.categories?.commitment?.trim() || null;

    // Posted at date
    let postedAt: Date | null = null;
    if (item.createdAt && typeof item.createdAt === "number") {
      postedAt = new Date(item.createdAt);
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
