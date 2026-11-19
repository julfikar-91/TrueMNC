// functions/src/adapters/greenhouse.ts
import { JobAdapter, RawJob, SourceDoc } from "./types";
import { logInfo, logWarn, logError } from "../utils/logger";

const FN = "GreenhouseAdapter";
const DEFAULT_BASE_URL = "https://boards-api.greenhouse.io/v1/boards";
const APP_USER_AGENT = "TrueCorporateJobFinder/1.0 (+https://truemnc.com/bot; bot@truemnc.com)";
const REQUEST_TIMEOUT_MS = 15000;
const MAX_RETRIES = 5;

interface GreenhouseJobLocation {
  name?: string;
}

interface GreenhouseDepartment {
  id?: number;
  name?: string;
}

interface GreenhouseJobResponse {
  id: number;
  title: string;
  updated_at?: string;
  absolute_url: string;
  location?: GreenhouseJobLocation;
  departments?: GreenhouseDepartment[];
  content?: string;
  metadata?: Array<{
    name?: string;
    value?: unknown;
  }>;
}

interface GreenhouseJobsResponse {
  jobs: GreenhouseJobResponse[];
}

/**
 * Safely strips HTML tags while preserving line breaks and decoding common entities.
 */
export function stripHtmlSafely(html: string): string {
  if (!html) return "";

  // 1. Decode entities first in case HTML tags themselves were escaped (standard in Greenhouse content)
  let text = html
    .replace(/&lt;/gi, "<")
    .replace(/&gt;/gi, ">")
    .replace(/&quot;/gi, '"')
    .replace(/&#39;/gi, "'")
    .replace(/&nbsp;/gi, " ")
    .replace(/&amp;/gi, "&")
    .replace(/&amp;/gi, "&");

  // 2. Replace structural tags with line breaks and bullets
  text = text
    .replace(/<br\s*\/?>/gi, "\n")
    .replace(/<\/p>/gi, "\n\n")
    .replace(/<\/div>/gi, "\n")
    .replace(/<\/li>/gi, "\n")
    .replace(/<li>/gi, "• ");

  // 3. Remove all remaining HTML tags
  text = text.replace(/<[^>]*>/g, "");

  // 4. Normalize newlines and whitespace
  return text
    .replace(/\r\n/g, "\n")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

/**
 * Extracts Greenhouse board token from config or URL.
 */
export function extractBoardToken(source: SourceDoc): string {
  if (source.config?.boardToken && typeof source.config.boardToken === "string") {
    return source.config.boardToken.trim();
  }

  // Parse token from URL (e.g. https://boards.greenhouse.io/airbnb/ or https://job-boards.greenhouse.io/airbnb)
  try {
    const url = new URL(source.url);
    const pathParts = url.pathname.split("/").filter(Boolean);
    if (pathParts.length > 0) {
      return pathParts[0];
    }
  } catch {
    // Ignore invalid URL parse
  }

  throw new Error(`Invalid Greenhouse source config: missing boardToken for source ${source.id}`);
}

export class GreenhouseAdapter implements JobAdapter {
  private readonly baseUrl: string;

  constructor(customBaseUrl?: string) {
    this.baseUrl =
      customBaseUrl || process.env.GREENHOUSE_API_BASE_URL || DEFAULT_BASE_URL;
  }

  async fetchJobs(source: SourceDoc): Promise<RawJob[]> {
    const boardToken = extractBoardToken(source);
    const apiBase = (source.config?.apiBaseUrl as string) || this.baseUrl;
    const endpoint = `${apiBase.replace(/\/$/, "")}/${boardToken}/jobs?content=true`;

    logInfo(FN, "Fetching jobs from Greenhouse board API", {
      sourceId: source.id,
      boardToken,
      endpoint,
    });

    const response = await this.fetchWithRetry(endpoint);
    const data = (await response.json()) as GreenhouseJobsResponse;

    if (!data || !Array.isArray(data.jobs)) {
      logWarn(FN, "Unexpected Greenhouse response structure", {
        sourceId: source.id,
      });
      return [];
    }

    logInfo(FN, `Successfully fetched ${data.jobs.length} jobs from Greenhouse`, {
      sourceId: source.id,
      boardToken,
    });

    return data.jobs.map((job) => this.normaliseJob(job));
  }

  private async fetchWithRetry(
    url: string,
    retryCount = 0,
  ): Promise<Response> {
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

      // Handle Rate Limiting (HTTP 429) and Server Errors (5xx)
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
        throw new Error(`Greenhouse API responded with HTTP status ${response.status} ${response.statusText}`);
      }

      return response;
    } catch (err: unknown) {
      clearTimeout(timeout);

      if (retryCount < MAX_RETRIES) {
        const delay = Math.pow(2, retryCount) * 1000 + Math.random() * 500;
        logWarn(FN, `Network error fetching Greenhouse API. Retrying in ${delay}ms...`, {
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

  private normaliseJob(job: GreenhouseJobResponse): RawJob {
    const rawContent = job.content ?? "";
    const cleanDescription = stripHtmlSafely(rawContent);

    const locationName = job.location?.name ?? null;
    const title = job.title.trim();
    const titleOrLoc = `${title} ${locationName ?? ""}`.toLowerCase();
    const isRemote =
      titleOrLoc.includes("remote") ||
      titleOrLoc.includes("work from home") ||
      titleOrLoc.includes("wfh") ||
      titleOrLoc.includes("anywhere");

    const department =
      job.departments && job.departments.length > 0
        ? job.departments[0].name ?? null
        : null;

    let postedAt: Date | null = null;
    if (job.updated_at) {
      const parsed = new Date(job.updated_at);
      if (!isNaN(parsed.getTime())) {
        postedAt = parsed;
      }
    }

    return {
      sourceJobId: job.id.toString(),
      title,
      description: cleanDescription,
      applyUrl: job.absolute_url,
      location: locationName,
      remote: isRemote,
      postedAt,
      deadline: null, // Greenhouse board API does not provide explicit expiration dates
      department,
      employmentType: null,
      raw: job,
    };
  }
}
