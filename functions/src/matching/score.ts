// functions/src/matching/score.ts
// Pure matching and scoring engine for TrueMNC.
// NO Gemini calls permitted here — deterministic scoring only.

import { SKILLS_DICTIONARY, normaliseSkill } from "./skills";

export interface CandidateSkill {
  name?: string;
  value?: string;
  canonicalId?: string;
  confirmed?: boolean;
  provenance?: "EXPLICIT" | "INFERRED" | "MISSING" | string;
}

export interface CandidateEducation {
  degree?: string;
  level?: string;
  specialization?: string;
  field?: string;
  institution?: string;
  confirmed?: boolean;
  provenance?: "EXPLICIT" | "INFERRED" | "MISSING" | string;
}

export interface CandidateExperienceItem {
  title?: string | { value?: string; provenance?: string };
  company?: string | { value?: string; provenance?: string };
  startDate?: string | Date;
  endDate?: string | Date;
  months?: number;
  confirmed?: boolean;
  provenance?: "EXPLICIT" | "INFERRED" | "MISSING" | string;
}

export interface CandidateProfile {
  id?: string;
  name?: string;
  location?: string | null;
  state?: string | null;
  skills?: CandidateSkill[] | string[] | Record<string, string[]>;
  canonicalSkills?: string[];
  education?: CandidateEducation[];
  experience?:
    | CandidateExperienceItem[]
    | {
        totalMonths?: number;
        items?: CandidateExperienceItem[];
      };
  confirmedMonths?: number | null;
  isFresher?: boolean;
  profile_confirmed?: boolean;
}

export interface CareerPreferences {
  preferredTitles?: string[];
  title?: string;
  preferredCategories?: string[];
  category?: string;
  preferredJobTypes?: ("TECHNICAL" | "NON_TECHNICAL" | string)[];
  jobType?: string;
  preferredEmploymentTypes?: string[];
  employmentType?: string;
  preferredWorkModes?: ("REMOTE" | "HYBRID" | "ONSITE" | string)[];
  workMode?: string;
  preferredCities?: string[];
  city?: string;
  openToRelocate?: boolean;
  minSalary?: number;
}

export interface JobMatchCriteria {
  id: string;
  title: string;
  category?: string | null;
  jobType?: "TECHNICAL" | "NON_TECHNICAL" | string | null;
  requiredSkills: string[];
  preferredSkills?: string[];
  minEdu?: string | null;
  expMin?: number | null;
  expMax?: number | null;
  employmentType?: string | null;
  workMode?: "REMOTE" | "HYBRID" | "ONSITE" | string | null;
  city?: string | null;
  state?: string | null;
  locations?: string[];
  status?: string;
  verification?: { state?: string };
  isVerified?: boolean;
  applyUrl?: string;
  companyEnabled?: boolean;
  hidden?: boolean;
  companyHidden?: boolean;
  contentHash?: string;
}

export interface ScoringWeights {
  skills: number;
  education: number;
  experience: number;
  location: number;
  preference: number;
}

export interface ScoringConfig {
  version?: string;
  weights?: ScoringWeights;
  skills?: number;
  education?: number;
  experience?: number;
  location?: number;
  preference?: number;
  threshold?: number;
  softCapCoverage?: number;
  softCap?: number;
  labelCutoffs?: {
    excellent: number;
    good: number;
    fair: number;
  };
  labels?: {
    excellent: number;
    good: number;
    fair: number;
  };
}

export interface MatchScoreBreakdown {
  skills: number;
  education: number;
  experience: number;
  location: number;
  preference: number;
}

export interface MatchResult {
  score: number;
  label: "Strong" | "Good" | "Possible" | "Hidden";
  breakdown: MatchScoreBreakdown;
  matchedSkills: string[];
  missingSkills: string[];
  niceToHave: string[];
  reasons: string[];
  gaps: string[];
  flags: string[];
  scoreVersion: string;
}

// ── Stage 1 Hard Eligibility ──────────────────────────────────────────────────
export function checkStage1Eligibility(
  job: Partial<JobMatchCriteria>,
  company?: { enabled?: boolean; hidden?: boolean; status?: string } | null,
): { eligible: boolean; reason?: string } {
  if (job.status !== "ACTIVE") {
    return { eligible: false, reason: `Job status is ${job.status}, expected ACTIVE` };
  }

  const isVerified =
    job.verification?.state === "VERIFIED" || job.isVerified === true;
  if (!isVerified) {
    return { eligible: false, reason: "Job verification state is not VERIFIED" };
  }

  if (!job.applyUrl || !/^https?:\/\//i.test(job.applyUrl.trim())) {
    return { eligible: false, reason: "Job applyUrl is missing or invalid" };
  }

  if (job.hidden === true) {
    return { eligible: false, reason: "Job is hidden" };
  }

  if (company) {
    if (company.enabled === false || (company.status && company.status !== "ACTIVE")) {
      return { eligible: false, reason: "Company is disabled" };
    }
    if (company.hidden === true) {
      return { eligible: false, reason: "Company is hidden" };
    }
  } else {
    if (job.companyEnabled === false) {
      return { eligible: false, reason: "Company is disabled" };
    }
    if (job.companyHidden === true) {
      return { eligible: false, reason: "Company is hidden" };
    }
  }

  return { eligible: true };
}

// ── Banker's Rounding (Round half to even) ───────────────────────────────────
export function roundScore(val: number): number {
  const clamped = Math.max(0, Math.min(100, val));
  const floor = Math.floor(clamped);
  const diff = clamped - floor;
  if (Math.abs(diff - 0.5) < 1e-9) {
    return floor % 2 === 0 ? floor : floor + 1;
  }
  return Math.round(clamped);
}

// ── Helper: Map skill to canonical and relatedGroupId ─────────────────────────
const SKILL_MAP = new Map<string, { canonicalId: string; relatedGroupId: string }>();
for (const entry of SKILLS_DICTIONARY) {
  SKILL_MAP.set(entry.canonicalId, {
    canonicalId: entry.canonicalId,
    relatedGroupId: entry.relatedGroupId,
  });
}

function resolveSkillInfo(raw: string): { canonicalId: string; relatedGroupId?: string } {
  const norm = normaliseSkill(raw);
  const canonicalId = norm.canonicalId ?? raw.toLowerCase().trim();
  const entry = SKILL_MAP.get(canonicalId);
  return {
    canonicalId,
    relatedGroupId: entry?.relatedGroupId,
  };
}

// ── Pure Function: scoreForUser ──────────────────────────────────────────────
export function scoreForUser(
  profile: CandidateProfile | null | undefined,
  prefs: CareerPreferences | null | undefined,
  job: JobMatchCriteria,
  config?: ScoringConfig | null,
): MatchResult {
  // Extract and normalize config values
  const weights: ScoringWeights = {
    skills: config?.weights?.skills ?? config?.skills ?? 40,
    education: config?.weights?.education ?? config?.education ?? 15,
    experience: config?.weights?.experience ?? config?.experience ?? 15,
    location: config?.weights?.location ?? config?.location ?? 10,
    preference: config?.weights?.preference ?? config?.preference ?? 20,
  };

  const softCap = config?.softCap ?? 74;
  const softCapCoverage = config?.softCapCoverage ?? 0.5;
  const scoreVersion = config?.version ?? "v1";

  const cutoffs = {
    excellent: config?.labelCutoffs?.excellent ?? config?.labels?.excellent ?? 80,
    good: config?.labelCutoffs?.good ?? config?.labels?.good ?? 65,
    fair: config?.labelCutoffs?.fair ?? config?.labels?.fair ?? 55,
  };

  const reasons: string[] = [];
  const gaps: string[] = [];
  const flags: string[] = [];
  const matchedSkills: string[] = [];
  const missingSkills: string[] = [];
  const niceToHave: string[] = [];

  const breakdown: MatchScoreBreakdown = {
    skills: 0,
    education: 0,
    experience: 0,
    location: 0,
    preference: 0,
  };

  const activeDimensions: Record<keyof MatchScoreBreakdown, boolean> = {
    skills: false,
    education: false,
    experience: false,
    location: false,
    preference: false,
  };

  // ── 1. Skills Scoring (Weight 40) ─────────────────────────────────────────
  // Use ONLY confirmed data; INFERRED values are ignored.
  const userConfirmedCanonicals = new Set<string>();
  const userRelatedGroups = new Map<string, string>(); // relatedGroupId -> canonicalId

  if (profile) {
    const rawSkillsList: string[] = [];

    if (Array.isArray(profile.skills)) {
      for (const item of profile.skills) {
        if (typeof item === "string") {
          rawSkillsList.push(item);
        } else if (item && typeof item === "object") {
          // Check provenance and confirmation
          if (item.provenance === "INFERRED" || item.confirmed === false) {
            continue; // IGNORE INFERRED OR UNCONFIRMED
          }
          const val = item.value || item.canonicalId || item.name;
          if (val) rawSkillsList.push(val);
        }
      }
    } else if (profile.skills && typeof profile.skills === "object") {
      // Category map
      for (const catList of Object.values(profile.skills)) {
        if (Array.isArray(catList)) {
          for (const s of catList) {
            if (typeof s === "string") rawSkillsList.push(s);
          }
        }
      }
    }

    if (Array.isArray(profile.canonicalSkills)) {
      for (const cs of profile.canonicalSkills) {
        if (typeof cs === "string") rawSkillsList.push(cs);
      }
    }

    for (const raw of rawSkillsList) {
      const info = resolveSkillInfo(raw);
      userConfirmedCanonicals.add(info.canonicalId);
      if (info.relatedGroupId) {
        userRelatedGroups.set(info.relatedGroupId, info.canonicalId);
      }
    }
  }

  const reqSkills = job.requiredSkills || [];
  const prefSkills = job.preferredSkills || [];
  let totalSkillsWeight = 0;
  let matchedSkillsWeight = 0;
  let totalRequiredWeight = 0;
  let matchedRequiredWeight = 0;

  for (const req of reqSkills) {
    const info = resolveSkillInfo(req);
    totalSkillsWeight += 1.0;
    totalRequiredWeight += 1.0;

    if (userConfirmedCanonicals.has(info.canonicalId)) {
      matchedSkillsWeight += 1.0;
      matchedRequiredWeight += 1.0;
      matchedSkills.push(req);
    } else if (info.relatedGroupId && userRelatedGroups.has(info.relatedGroupId)) {
      matchedSkillsWeight += 0.5;
      matchedRequiredWeight += 0.5;
      matchedSkills.push(req);
      reasons.push(`Related skill match for ${req} (via ${userRelatedGroups.get(info.relatedGroupId)})`);
    } else {
      missingSkills.push(req);
      gaps.push(`Missing required skill: ${req}`);
    }
  }

  for (const pref of prefSkills) {
    const info = resolveSkillInfo(pref);
    totalSkillsWeight += 0.5;

    if (userConfirmedCanonicals.has(info.canonicalId)) {
      matchedSkillsWeight += 0.5;
      matchedSkills.push(pref);
      niceToHave.push(pref);
    } else if (info.relatedGroupId && userRelatedGroups.has(info.relatedGroupId)) {
      matchedSkillsWeight += 0.25;
      matchedSkills.push(pref);
      niceToHave.push(pref);
    }
    // Missing optional skill NEVER rejects and is NOT added to missingSkills or gaps
  }

  if (totalSkillsWeight > 0) {
    breakdown.skills = Math.round((matchedSkillsWeight / totalSkillsWeight) * 100);
    activeDimensions.skills = true;
    if (matchedSkills.length > 0) {
      reasons.push(`Matched skills: ${matchedSkills.slice(0, 4).join(", ")}`);
    }
  }

  const requiredSkillCoverage =
    totalRequiredWeight > 0 ? matchedRequiredWeight / totalRequiredWeight : 1.0;

  // ── 2. Education Scoring (Weight 15) ───────────────────────────────────────
  // Level rank: Diploma 1, Bachelor 2, Master 3, PhD 4
  const rankMap: Record<string, number> = {
    diploma: 1,
    polytechnic: 1,
    bachelor: 2,
    "b.tech": 2,
    btech: 2,
    "b.e": 2,
    be: 2,
    bsc: 2,
    "b.sc": 2,
    bca: 2,
    bba: 2,
    ba: 2,
    bcom: 2,
    "b.com": 2,
    undergraduate: 2,
    master: 3,
    "m.tech": 3,
    mtech: 3,
    "m.e": 3,
    me: 3,
    msc: 3,
    "m.sc": 3,
    mca: 3,
    mba: 3,
    ma: 3,
    mcom: 3,
    "m.com": 3,
    postgraduate: 3,
    phd: 4,
    doctorate: 4,
  };

  function parseEducationLevel(str?: string | null): number {
    if (!str) return 0;
    const lower = str.toLowerCase();
    for (const [key, rank] of Object.entries(rankMap)) {
      if (lower.includes(key)) return rank;
    }
    return 2; // Default to Bachelor if degree present but rank unknown
  }

  const confirmedEduItems = (profile?.education || []).filter(
    (e) => e.confirmed !== false && e.provenance !== "INFERRED",
  );

  const jobMinEduRaw = (job.minEdu || "").toLowerCase().trim();
  const isAnyGraduate =
    !jobMinEduRaw ||
    jobMinEduRaw.includes("any graduate") ||
    jobMinEduRaw === "any" ||
    jobMinEduRaw === "graduate";

  if (confirmedEduItems.length > 0 || isAnyGraduate) {
    activeDimensions.education = true;

    if (isAnyGraduate) {
      breakdown.education = 100;
      reasons.push("Education requirement met (Any Graduate)");
    } else {
      let userMaxRank = 0;
      let userBestEdu: CandidateEducation | null = null;
      for (const edu of confirmedEduItems) {
        const r = parseEducationLevel(edu.level || edu.degree);
        if (r >= userMaxRank) {
          userMaxRank = r;
          userBestEdu = edu;
        }
      }

      const jobReqRank = parseEducationLevel(jobMinEduRaw);

      // Check field relevance
      const userField = (
        (userBestEdu?.specialization || "") +
        " " +
        (userBestEdu?.degree || "") +
        " " +
        (userBestEdu?.field || "")
      ).toLowerCase();

      const isCsOrIt =
        userField.includes("cse") ||
        userField.includes("computer") ||
        userField.includes("software") ||
        userField.includes("it") ||
        userField.includes("technology") ||
        userField.includes("information");

      const isRelatedStem =
        isCsOrIt ||
        userField.includes("ece") ||
        userField.includes("electronics") ||
        userField.includes("electrical") ||
        userField.includes("engineering") ||
        userField.includes("math") ||
        userField.includes("data") ||
        userField.includes("physics") ||
        userField.includes("statistics") ||
        userField.includes("science");

      if (userMaxRank >= jobReqRank) {
        if (isCsOrIt || !jobMinEduRaw.includes("computer")) {
          breakdown.education = 100;
          reasons.push("Education meets level and field requirement");
        } else if (isRelatedStem) {
          breakdown.education = 75;
          reasons.push("Education meets degree level in a related field");
        } else {
          breakdown.education = 70;
        }
      } else if (userMaxRank === jobReqRank - 1) {
        breakdown.education = 40;
        gaps.push("Education is one level below required qualification");
      } else {
        breakdown.education = 20;
        gaps.push("Education is below required qualification");
      }
    }
  }

  // ── 3. Experience Scoring (Weight 15) ──────────────────────────────────────
  // Confirmed months only; in range 100; below min -25 per missing year (floor 20);
  // above max -15 per extra year (floor 40); unknown = 50 and flag "Add experience for better accuracy".
  // NEVER assume fresher.
  let confirmedExperienceMonths: number | null = null;

  if (profile?.confirmedMonths !== undefined && profile.confirmedMonths !== null) {
    confirmedExperienceMonths = profile.confirmedMonths;
  } else if (profile?.isFresher === true) {
    confirmedExperienceMonths = 0;
  } else {
    // Look for confirmed experience items
    let expItems: CandidateExperienceItem[] = [];
    if (Array.isArray(profile?.experience)) {
      expItems = profile.experience;
    } else if (profile?.experience && typeof profile.experience === "object") {
      expItems = profile.experience.items || [];
    }

    const validExp = expItems.filter((e) => {
      const prov =
        typeof e.title === "object" ? e.title?.provenance : e.provenance;
      return e.confirmed !== false && prov !== "INFERRED";
    });

    if (validExp.length > 0) {
      let sumMonths = 0;
      for (const item of validExp) {
        sumMonths += item.months || 12; // default 12 months if duration not explicit
      }
      confirmedExperienceMonths = sumMonths;
    }
  }

  // Active if job specifies experience criteria or baseline experience is evaluated
  activeDimensions.experience = true;

  if (confirmedExperienceMonths === null) {
    breakdown.experience = 50;
    flags.push("Add experience for better accuracy");
  } else {
    const userYears = confirmedExperienceMonths / 12;
    const minExp = job.expMin ?? 0;
    const maxExp = job.expMax ?? null;

    if (userYears >= minExp && (maxExp === null || userYears <= maxExp)) {
      breakdown.experience = 100;
      reasons.push(`Experience (${userYears.toFixed(1)} yrs) meets job requirements`);
    } else if (userYears < minExp) {
      const missingYears = minExp - userYears;
      breakdown.experience = Math.max(20, Math.round(100 - missingYears * 25));
      gaps.push(`Experience is ${missingYears.toFixed(1)} yr(s) below required minimum`);
    } else if (maxExp !== null && userYears > maxExp) {
      const extraYears = userYears - maxExp;
      breakdown.experience = Math.max(40, Math.round(100 - extraYears * 15));
      flags.push(`Experience exceeds target maximum by ${extraYears.toFixed(1)} yr(s)`);
    }
  }

  // ── 4. Location Scoring (Weight 10) ────────────────────────────────────────
  // preferred city or remote-and-accepted 100; same state 70; open to relocate 60; else 20.
  const userCity = (profile?.location || "").toLowerCase().trim();
  const userState = (profile?.state || "").toLowerCase().trim();
  const preferredCities = (prefs?.preferredCities || [])
    .map((c) => c.toLowerCase().trim())
    .concat(prefs?.city ? [prefs.city.toLowerCase().trim()] : []);

  const jobCity = (job.city || "").toLowerCase().trim();
  const jobState = (job.state || "").toLowerCase().trim();
  const jobLocations = (job.locations || []).map((l) => l.toLowerCase().trim());

  const isRemoteJob =
    job.workMode === "REMOTE" ||
    jobCity === "remote" ||
    jobLocations.includes("remote");

  const preferredModes = (prefs?.preferredWorkModes || [])
    .map((m) => m.toUpperCase())
    .concat(prefs?.workMode ? [prefs.workMode.toUpperCase()] : []);

  const acceptsRemote =
    preferredModes.length === 0 ||
    preferredModes.includes("REMOTE") ||
    preferredModes.includes("HYBRID");

  const openToRelocate = prefs?.openToRelocate === true;

  if (userCity || preferredCities.length > 0 || isRemoteJob || openToRelocate) {
    activeDimensions.location = true;

    if (isRemoteJob && acceptsRemote) {
      breakdown.location = 100;
      reasons.push("Remote job matches your work mode preferences");
    } else if (
      (jobCity && userCity && jobCity === userCity) ||
      (jobCity && preferredCities.includes(jobCity)) ||
      (jobLocations.length > 0 && userCity && jobLocations.includes(userCity))
    ) {
      breakdown.location = 100;
      reasons.push(`Job located in preferred city (${job.city || userCity})`);
    } else if (jobState && userState && jobState === userState) {
      breakdown.location = 70;
      reasons.push(`Job located in the same state (${job.state})`);
    } else if (openToRelocate) {
      breakdown.location = 60;
      reasons.push("Willing to relocate matches job location");
    } else {
      breakdown.location = 20;
      gaps.push(`Job location (${job.city || "Other"}) is outside preferred cities`);
    }
  }

  // ── 5. Preference Scoring (Weight 20) ──────────────────────────────────────
  // Average of title overlap, category, jobType, employmentType, workMode
  // (match 100, partial 50, none 0); preferences missing => dimension excluded.
  const hasPreferences =
    Boolean(prefs) &&
    Object.values(prefs || {}).some(
      (v) => v !== undefined && v !== null && (Array.isArray(v) ? v.length > 0 : true),
    );

  if (hasPreferences) {
    activeDimensions.preference = true;

    // 1. Title overlap
    let titleScore = 0;
    const prefTitles = (prefs?.preferredTitles || [])
      .concat(prefs?.title ? [prefs.title] : [])
      .map((t) => t.toLowerCase().trim());

    if (prefTitles.length === 0) {
      titleScore = 100;
    } else {
      const jobTitleTokens = job.title
        .toLowerCase()
        .replace(/[^a-z0-9\s]/g, " ")
        .split(/\s+/)
        .filter((w) => w.length >= 2);

      let matchedTokens = 0;
      for (const pt of prefTitles) {
        const ptTokens = pt
          .replace(/[^a-z0-9\s]/g, " ")
          .split(/\s+/)
          .filter((w) => w.length >= 2);

        const overlap = ptTokens.filter((t) => jobTitleTokens.includes(t));
        if (overlap.length === ptTokens.length && ptTokens.length > 0) {
          titleScore = 100;
          break;
        } else if (overlap.length > 0) {
          matchedTokens = Math.max(matchedTokens, overlap.length);
        }
      }
      if (titleScore === 0) {
        titleScore = matchedTokens > 0 ? 50 : 0;
      }
    }

    // 2. Category
    let categoryScore = 0;
    const prefCats = (prefs?.preferredCategories || [])
      .concat(prefs?.category ? [prefs.category] : [])
      .map((c) => c.toLowerCase().trim());

    if (prefCats.length === 0) {
      categoryScore = 100;
    } else {
      const jobCat = (job.category || "").toLowerCase().trim();
      if (prefCats.includes(jobCat)) {
        categoryScore = 100;
      } else if (
        prefCats.some((c) => c.includes("software") || c.includes("data") || c.includes("cloud")) &&
        (jobCat.includes("software") || jobCat.includes("data") || jobCat.includes("cloud"))
      ) {
        categoryScore = 50;
      } else {
        categoryScore = 0;
      }
    }

    // 3. Job Type
    let jobTypeScore = 0;
    const prefJobTypes = (prefs?.preferredJobTypes || [])
      .concat(prefs?.jobType ? [prefs.jobType] : [])
      .map((jt) => jt.toUpperCase().trim());

    if (prefJobTypes.length === 0 || !job.jobType) {
      jobTypeScore = 100;
    } else if (prefJobTypes.includes(job.jobType.toUpperCase())) {
      jobTypeScore = 100;
    } else {
      jobTypeScore = 0;
    }

    // 4. Employment Type
    let empScore = 0;
    const prefEmpTypes = (prefs?.preferredEmploymentTypes || [])
      .concat(prefs?.employmentType ? [prefs.employmentType] : [])
      .map((e) => e.toUpperCase().trim());

    if (prefEmpTypes.length === 0 || !job.employmentType) {
      empScore = 100;
    } else if (prefEmpTypes.includes(job.employmentType.toUpperCase())) {
      empScore = 100;
    } else {
      empScore = 50;
    }

    // 5. Work Mode
    let modeScore = 0;
    if (preferredModes.length === 0 || !job.workMode) {
      modeScore = 100;
    } else if (preferredModes.includes(job.workMode.toUpperCase())) {
      modeScore = 100;
    } else if (
      (job.workMode.toUpperCase() === "HYBRID" && preferredModes.includes("ONSITE")) ||
      (job.workMode.toUpperCase() === "ONSITE" && preferredModes.includes("HYBRID"))
    ) {
      modeScore = 50;
    } else {
      modeScore = 0;
    }

    breakdown.preference = Math.round(
      (titleScore + categoryScore + jobTypeScore + empScore + modeScore) / 5,
    );
    if (breakdown.preference >= 80) {
      reasons.push("Role and career preferences strongly align");
    }
  }

  // ── Renormalisation Over Active Dimensions ──────────────────────────────────
  let activeWeightTotal = 0;
  let weightedScoreTotal = 0;

  const dims: Array<keyof MatchScoreBreakdown> = [
    "skills",
    "education",
    "experience",
    "location",
    "preference",
  ];

  for (const d of dims) {
    if (activeDimensions[d]) {
      const w = weights[d];
      activeWeightTotal += w;
      weightedScoreTotal += breakdown[d] * w;
    }
  }

  let rawScore = activeWeightTotal > 0 ? weightedScoreTotal / activeWeightTotal : 0;

  // Soft cap if required skills coverage < 0.5
  if (requiredSkillCoverage < softCapCoverage) {
    rawScore = Math.min(rawScore, softCap);
    flags.push("Soft cap applied: Required skills coverage below 50%");
  }

  const finalScore = roundScore(rawScore);

  let label: MatchResult["label"];
  if (finalScore >= cutoffs.excellent) {
    label = "Strong";
  } else if (finalScore >= cutoffs.good) {
    label = "Good";
  } else if (finalScore >= cutoffs.fair) {
    label = "Possible";
  } else {
    label = "Hidden";
  }

  return {
    score: finalScore,
    label,
    breakdown,
    matchedSkills,
    missingSkills,
    niceToHave,
    reasons,
    gaps,
    flags,
    scoreVersion,
  };
}
