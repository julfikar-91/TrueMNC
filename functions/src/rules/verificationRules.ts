// functions/src/rules/verificationRules.ts
import * as crypto from "crypto";

export type RuleResultStatus = "PASS" | "FAIL";

export interface RuleResult {
  ruleCode: string;
  result: RuleResultStatus;
  details?: string;
}

export interface RuleVerificationContext {
  source: {
    enabled: boolean;
    config?: {
      approvedAtsHost?: string;
      [key: string]: unknown;
    };
  };
  company: {
    id: string;
    domain?: string;
    website?: string;
    sourceVerified: boolean;
  };
  job: {
    id?: string;
    title: string;
    companyId?: string;
    companyName?: string;
    applyUrl: string;
    description: string;
    location?: string | null;
    city?: string | null;
    remote?: boolean | null;
    sourceJobId?: string | null;
    postedAt?: Date | null;
    firstSeenAt?: Date | null;
    deadline?: Date | null;
  };
  aiExtraction?: {
    confidence: number;
    isValidSchema: boolean;
    category?: string;
  };
  existingDedupeKeys?: Set<string>;
}

// ── Built-in Approved ATS Hosts ──────────────────────────────────────────────
export const APPROVED_ATS_HOSTS = new Set([
  "boards.greenhouse.io",
  "job-boards.greenhouse.io",
  "jobs.lever.co",
  "careers.smartrecruiters.com",
  "jobs.smartrecruiters.com",
  "myworkdayjobs.com",
  "icims.com",
]);

// ── Known URL Shortener Domains ──────────────────────────────────────────────
export const URL_SHORTENERS = new Set([
  "bit.ly",
  "tinyurl.com",
  "t.co",
  "goo.gl",
  "ow.ly",
  "is.gd",
  "buff.ly",
  "cutt.ly",
  "rebrand.ly",
  "shorturl.at",
  "snip.ly",
  "bl.ink",
]);

// ── Suspicious Safety Phrases ────────────────────────────────────────────────
export const PAYMENT_REQUEST_PHRASES = [
  "registration fee",
  "processing fee",
  "refundable deposit",
  "security deposit",
  "pay to apply",
  "application fee",
  "wire transfer",
  "training fee",
  "laptop deposit",
  "investment required",
  "pay before interview",
];

export const PERSONAL_DATA_PHRASES = [
  "send bank details",
  "bank account number",
  "credit card number",
  "debit card number",
  "passport scan",
  "aadhaar card copy",
  "social security number",
  "submit ssn",
  "net banking password",
  "otp",
];

/**
 * Normalises a domain string (strips protocol, port, paths, www).
 */
export function normaliseDomain(input: string): string {
  try {
    let clean = input.trim().toLowerCase();
    if (clean.startsWith("http://") || clean.startsWith("https://")) {
      clean = new URL(clean).hostname;
    }
    // Strip leading www.
    if (clean.startsWith("www.")) {
      clean = clean.substring(4);
    }
    // Strip trailing port if any
    clean = clean.split(":")[0];
    return clean;
  } catch {
    return input.trim().toLowerCase();
  }
}

/**
 * Extracts host from a URL string safely.
 */
export function extractHost(urlStr: string): string | null {
  try {
    const parsed = new URL(urlStr);
    return parsed.hostname.toLowerCase();
  } catch {
    return null;
  }
}

/**
 * Validates whether a target host matches an authoritative domain.
 * Strictly prevents lookalikes like evilcompany.com and company.com.evil.com!
 */
export function isAuthoritativeDomainMatch(
  targetHost: string,
  authoritativeDomain: string,
): boolean {
  const normHost = normaliseDomain(targetHost);
  const normAuth = normaliseDomain(authoritativeDomain);

  if (!normHost || !normAuth) return false;

  // Exact match
  if (normHost === normAuth) return true;

  // Genuine subdomain (must end with .domain)
  if (normHost.endsWith(`.${normAuth}`)) return true;

  return false;
}

// ── 1. RULE R1: Source Approved ──────────────────────────────────────────────
export function ruleR1SourceApproved(
  source: { enabled: boolean },
  company: { sourceVerified: boolean },
): RuleResult {
  const pass = Boolean(source.enabled && company.sourceVerified);
  return {
    ruleCode: "R1",
    result: pass ? "PASS" : "FAIL",
    details: pass
      ? "Source is enabled and company is verified."
      : "Source is not enabled or company has not been verified.",
  };
}

// ── 2. RULE R2: Domain ───────────────────────────────────────────────────────
export function ruleR2Domain(
  applyUrl: string,
  companyDomain?: string,
  customApprovedAtsHost?: string,
): RuleResult {
  const host = extractHost(applyUrl);
  if (!host) {
    return {
      ruleCode: "R2",
      result: "FAIL",
      details: "Invalid or unparseable applyUrl.",
    };
  }

  // 1. Check against company domain
  if (companyDomain && isAuthoritativeDomainMatch(host, companyDomain)) {
    return {
      ruleCode: "R2",
      result: "PASS",
      details: `Apply host "${host}" matches company domain "${companyDomain}".`,
    };
  }

  // 2. Check against custom approved ATS host on source
  if (
    customApprovedAtsHost &&
    isAuthoritativeDomainMatch(host, customApprovedAtsHost)
  ) {
    return {
      ruleCode: "R2",
      result: "PASS",
      details: `Apply host "${host}" matches source-approved ATS host "${customApprovedAtsHost}".`,
    };
  }

  // 3. Check against built-in approved ATS hosts
  for (const approvedAts of APPROVED_ATS_HOSTS) {
    if (isAuthoritativeDomainMatch(host, approvedAts)) {
      return {
        ruleCode: "R2",
        result: "PASS",
        details: `Apply host "${host}" matches standard verified ATS host "${approvedAts}".`,
      };
    }
  }

  return {
    ruleCode: "R2",
    result: "FAIL",
    details: `Apply host "${host}" does not match company domain "${companyDomain ?? "N/A"}" or any approved ATS host.`,
  };
}

// ── 3. RULE R3: URL Live ─────────────────────────────────────────────────────
export async function ruleR3UrlLive(
  applyUrl: string,
  companyDomain?: string,
  customApprovedAtsHost?: string,
  fetchFn: typeof fetch = fetch,
): Promise<RuleResult> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 10000);

  try {
    let currentUrl = applyUrl;
    let redirectCount = 0;
    const maxRedirects = 3;

    // Follow redirects manually up to 3 times to inspect final destination host
    while (redirectCount <= maxRedirects) {
      // Try HEAD first; fallback to GET if method not allowed
      let resp = await fetchFn(currentUrl, {
        method: "HEAD",
        redirect: "manual",
        signal: controller.signal,
        headers: {
          "User-Agent": "TrueCorporateJobFinder/1.0 (+https://truemnc.com/bot)",
        },
      });

      if (resp.status === 405) {
        resp = await fetchFn(currentUrl, {
          method: "GET",
          redirect: "manual",
          signal: controller.signal,
          headers: {
            "User-Agent": "TrueCorporateJobFinder/1.0 (+https://truemnc.com/bot)",
          },
        });
      }

      // Check if redirect
      if ([301, 302, 303, 307, 308].includes(resp.status)) {
        redirectCount++;
        if (redirectCount > maxRedirects) {
          clearTimeout(timeout);
          return {
            ruleCode: "R3",
            result: "FAIL",
            details: `Exceeded maximum redirect chain of ${maxRedirects} redirects.`,
          };
        }

        const location = resp.headers.get("location");
        if (!location) {
          clearTimeout(timeout);
          return {
            ruleCode: "R3",
            result: "FAIL",
            details: `Redirect ${resp.status} with missing Location header.`,
          };
        }

        currentUrl = new URL(location, currentUrl).toString();
        continue;
      }

      clearTimeout(timeout);

      // Check status code (200-399)
      if (resp.status >= 200 && resp.status <= 399) {
        // Re-check final destination host against R2 domain rule
        const r2Check = ruleR2Domain(currentUrl, companyDomain, customApprovedAtsHost);
        if (r2Check.result !== "PASS") {
          return {
            ruleCode: "R3",
            result: "FAIL",
            details: `URL redirects to unverified destination: ${r2Check.details}`,
          };
        }

        return {
          ruleCode: "R3",
          result: "PASS",
          details: `URL is live (status ${resp.status}) at ${currentUrl}.`,
        };
      }

      return {
        ruleCode: "R3",
        result: "FAIL",
        details: `URL returned non-success HTTP status ${resp.status}.`,
      };
    }

    clearTimeout(timeout);
    return {
      ruleCode: "R3",
      result: "FAIL",
      details: "Redirect chain loop detected.",
    };
  } catch (err: unknown) {
    clearTimeout(timeout);
    return {
      ruleCode: "R3",
      result: "FAIL",
      details: `URL probe error: ${(err as Error).message}`,
    };
  }
}

// ── 4. RULE R4: Required Fields ──────────────────────────────────────────────
export function ruleR4RequiredFields(job: {
  title?: string | null;
  companyName?: string | null;
  companyId?: string | null;
  location?: string | null;
  remote?: boolean | null;
  description?: string | null;
}): RuleResult {
  const missing: string[] = [];

  if (!job.title || job.title.trim().length === 0) {
    missing.push("title");
  }
  if (
    (!job.companyName || job.companyName.trim().length === 0) &&
    (!job.companyId || job.companyId.trim().length === 0)
  ) {
    missing.push("company");
  }
  const hasLocation = Boolean(job.location && job.location.trim().length > 0);
  const isRemote = job.remote === true;
  if (!hasLocation && !isRemote) {
    missing.push("location or remote flag");
  }
  if (!job.description || job.description.trim().length < 80) {
    missing.push("description (must be >= 80 characters)");
  }

  if (missing.length > 0) {
    return {
      ruleCode: "R4",
      result: "FAIL",
      details: `Missing mandatory job fields: ${missing.join(", ")}.`,
    };
  }

  return {
    ruleCode: "R4",
    result: "PASS",
    details: "All required fields present and valid.",
  };
}

// ── 5. RULE R5: Freshness ────────────────────────────────────────────────────
export function ruleR5Freshness(job: {
  postedAt?: Date | null;
  firstSeenAt?: Date | null;
  deadline?: Date | null;
}): RuleResult {
  if (!job.postedAt && !job.firstSeenAt) {
    return {
      ruleCode: "R5",
      result: "FAIL",
      details: "Neither postedAt nor firstSeenAt timestamp is present.",
    };
  }

  if (job.deadline) {
    const now = Date.now();
    if (job.deadline.getTime() < now) {
      return {
        ruleCode: "R5",
        result: "FAIL",
        details: `Application deadline expired on ${job.deadline.toISOString()}.`,
      };
    }
  }

  return {
    ruleCode: "R5",
    result: "PASS",
    details: "Job is fresh and deadline has not passed.",
  };
}

// ── 6. RULE R6: Duplicate ────────────────────────────────────────────────────
export function computeDedupeKey(params: {
  companyId: string;
  title: string;
  city?: string | null;
  sourceJobId?: string | null;
  applyUrl?: string | null;
}): string {
  const normTitle = params.title
    .toLowerCase()
    .replace(/[^a-z0-9]/g, "")
    .trim();
  const normCity = (params.city ?? "").toLowerCase().trim();

  let pathOrId = params.sourceJobId?.trim() ?? "";
  if (!pathOrId && params.applyUrl) {
    try {
      pathOrId = new URL(params.applyUrl).pathname;
    } catch {
      pathOrId = params.applyUrl;
    }
  }

  const raw = `${params.companyId}_${normTitle}_${normCity}_${pathOrId}`;
  return crypto.createHash("sha256").update(raw).digest("hex");
}

export function ruleR6Duplicate(
  dedupeKey: string,
  existingKeys?: Set<string>,
): RuleResult {
  if (existingKeys && existingKeys.has(dedupeKey)) {
    return {
      ruleCode: "R6",
      result: "FAIL",
      details: `Job matches an existing active job (duplicate hash ${dedupeKey.substring(0, 12)}).`,
    };
  }

  return {
    ruleCode: "R6",
    result: "PASS",
    details: "No duplicate detected.",
  };
}

// ── 7. RULE R7: AI Confidence ────────────────────────────────────────────────
export function ruleR7AiConfidence(aiExtraction?: {
  confidence: number;
  isValidSchema: boolean;
}): RuleResult {
  if (!aiExtraction) {
    return {
      ruleCode: "R7",
      result: "FAIL",
      details: "AI extraction payload missing.",
    };
  }

  if (!aiExtraction.isValidSchema) {
    return {
      ruleCode: "R7",
      result: "FAIL",
      details: "AI extraction schema validation failed.",
    };
  }

  if (aiExtraction.confidence < 0.7) {
    return {
      ruleCode: "R7",
      result: "FAIL",
      details: `AI extraction confidence ${aiExtraction.confidence.toFixed(2)} is below minimum threshold of 0.70.`,
    };
  }

  return {
    ruleCode: "R7",
    result: "PASS",
    details: `AI extraction confidence ${aiExtraction.confidence.toFixed(2)} passes threshold.`,
  };
}

// ── 8. RULE R8: Safety ───────────────────────────────────────────────────────
export function ruleR8Safety(job: {
  applyUrl: string;
  description: string;
}): RuleResult {
  const text = `${job.applyUrl} ${job.description}`.toLowerCase();

  // 1. Check payment wording
  for (const phrase of PAYMENT_REQUEST_PHRASES) {
    if (text.includes(phrase)) {
      return {
        ruleCode: "R8",
        result: "FAIL",
        details: `Prohibited payment request detected: "${phrase}".`,
      };
    }
  }

  // 2. Check personal-data collection wording
  for (const phrase of PERSONAL_DATA_PHRASES) {
    if (text.includes(phrase)) {
      return {
        ruleCode: "R8",
        result: "FAIL",
        details: `Prohibited personal data solicitation detected: "${phrase}".`,
      };
    }
  }

  // 3. Check for URL shorteners in applyUrl or description
  const host = extractHost(job.applyUrl);
  if (host && URL_SHORTENERS.has(host)) {
    return {
      ruleCode: "R8",
      result: "FAIL",
      details: `Prohibited URL shortener detected: "${host}".`,
    };
  }
  for (const shortener of URL_SHORTENERS) {
    if (text.includes(`://${shortener}/`) || text.includes(`www.${shortener}/`)) {
      return {
        ruleCode: "R8",
        result: "FAIL",
        details: `Prohibited URL shortener found in text: "${shortener}".`,
      };
    }
  }

  // 4. Check for IP-address URLs (IPv4)
  const ipv4Regex = /(?:https?:\/\/)?(?:\d{1,3}\.){3}\d{1,3}(?::\d+)?(?:\/|$)/;
  if (ipv4Regex.test(job.applyUrl) || ipv4Regex.test(job.description)) {
    return {
      ruleCode: "R8",
      result: "FAIL",
      details: "Prohibited raw IP-address URL detected.",
    };
  }

  return {
    ruleCode: "R8",
    result: "PASS",
    details: "Job description and URL pass all safety scans.",
  };
}

// ── Orchestrator: runRules ───────────────────────────────────────────────────
export interface RulesEvaluationResult {
  allPass: boolean;
  results: RuleResult[];
  reasonCodes: string[];
}

export async function runRules(
  ctx: RuleVerificationContext,
  options?: { skipLiveProbe?: boolean },
): Promise<RulesEvaluationResult> {
  const results: RuleResult[] = [];

  // R1
  results.push(ruleR1SourceApproved(ctx.source, ctx.company));

  // R2
  results.push(
    ruleR2Domain(
      ctx.job.applyUrl,
      ctx.company.domain,
      ctx.source.config?.approvedAtsHost,
    ),
  );

  // R3 (probe unless skipped in fast/mock mode)
  if (options?.skipLiveProbe) {
    results.push({
      ruleCode: "R3",
      result: "PASS",
      details: "Live URL probe skipped by option.",
    });
  } else {
    results.push(
      await ruleR3UrlLive(
        ctx.job.applyUrl,
        ctx.company.domain,
        ctx.source.config?.approvedAtsHost,
      ),
    );
  }

  // R4
  results.push(
    ruleR4RequiredFields({
      title: ctx.job.title,
      companyId: ctx.job.companyId ?? ctx.company.id,
      companyName: ctx.job.companyName,
      location: ctx.job.location,
      remote: ctx.job.remote,
      description: ctx.job.description,
    }),
  );

  // R5
  results.push(
    ruleR5Freshness({
      postedAt: ctx.job.postedAt,
      firstSeenAt: ctx.job.firstSeenAt,
      deadline: ctx.job.deadline,
    }),
  );

  // R6
  const dedupeKey = computeDedupeKey({
    companyId: ctx.company.id,
    title: ctx.job.title,
    city: ctx.job.city,
    sourceJobId: ctx.job.sourceJobId,
    applyUrl: ctx.job.applyUrl,
  });
  results.push(ruleR6Duplicate(dedupeKey, ctx.existingDedupeKeys));

  // R7
  results.push(ruleR7AiConfidence(ctx.aiExtraction));

  // R8
  results.push(
    ruleR8Safety({
      applyUrl: ctx.job.applyUrl,
      description: ctx.job.description,
    }),
  );

  const failedResults = results.filter((r) => r.result === "FAIL");
  const allPass = failedResults.length === 0;
  const reasonCodes = failedResults.map((r) => `${r.ruleCode}_FAIL`);

  return {
    allPass,
    results,
    reasonCodes,
  };
}
