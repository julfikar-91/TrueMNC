// functions/src/utils/types.ts
// Shared data contracts and Zod schemas mirroring Flutter Dart models.
// Always keeps TypeScript and Flutter sides in sync.

import { z } from "zod";

// ── 1. Enums ─────────────────────────────────────────────────────────────────

export const ProvenanceEnum = z.enum(["EXPLICIT", "INFERRED", "MISSING"]);
export type Provenance = z.infer<typeof ProvenanceEnum>;

export const JobStatusEnum = z.enum([
  "DRAFT_RAW",
  "PENDING_REVIEW",
  "ACTIVE",
  "CLOSING_SOON",
  "EXPIRED",
  "CLOSED",
  "REJECTED",
  "DUPLICATE",
]);
export type JobStatus = z.infer<typeof JobStatusEnum>;

export const JobTypeEnum = z.enum([
  "FULL_TIME",
  "PART_TIME",
  "CONTRACT",
  "INTERNSHIP",
  "OTHER",
]);
export type JobType = z.infer<typeof JobTypeEnum>;

export const WorkModeEnum = z.enum(["ONSITE", "REMOTE", "HYBRID"]);
export type WorkMode = z.infer<typeof WorkModeEnum>;

export const EmploymentTypeEnum = z.enum([
  "PERMANENT",
  "TEMPORARY",
  "CONTRACTOR",
  "INTERN",
]);
export type EmploymentType = z.infer<typeof EmploymentTypeEnum>;

export const ExperienceLevelEnum = z.enum([
  "ENTRY_LEVEL",
  "MID_LEVEL",
  "SENIOR",
  "LEAD",
  "EXECUTIVE",
]);
export type ExperienceLevel = z.infer<typeof ExperienceLevelEnum>;

export const VerificationStateEnum = z.enum([
  "UNVERIFIED",
  "PENDING",
  "VERIFIED",
  "REJECTED",
]);
export type VerificationState = z.infer<typeof VerificationStateEnum>;

export const SourceTypeEnum = z.enum([
  "GREENHOUSE",
  "LEVER",
  "SMARTRECRUITERS",
  "OFFICIAL_FEED",
  "CAREERS_PAGE",
]);
export type SourceType = z.infer<typeof SourceTypeEnum>;

export const ResumeParseStatusEnum = z.enum([
  "NOT_STARTED",
  "IN_PROGRESS",
  "PARSED",
  "FAILED",
]);
export type ResumeParseStatus = z.infer<typeof ResumeParseStatusEnum>;

export const UserRoleEnum = z.enum(["USER", "ADMIN", "SUPER_ADMIN"]);
export type UserRole = z.infer<typeof UserRoleEnum>;

// Helper for date/timestamp serialization: accepts string (ISO), Date, number, or Firestore Timestamp object
const TimestampOrDateSchema = z.union([
  z.string(),
  z.date(),
  z.number(),
  z.object({
    _seconds: z.number(),
    _nanoseconds: z.number(),
  }),
  z.object({
    seconds: z.number(),
    nanoseconds: z.number(),
  }),
  z.any(),
]);

// ── 2. FieldValue wrapper { value, provenance, evidence, confidence } ───────

export const FieldValueWrapperSchema = <T extends z.ZodTypeAny>(valueSchema: T) =>
  z.object({
    value: valueSchema.nullable(),
    provenance: ProvenanceEnum.default("MISSING"),
    evidence: z.string().nullable().optional(),
    confidence: z.number().min(0).max(1).nullable().optional(),
  });

export interface FieldValueWrapper<T> {
  value: T | null;
  provenance: Provenance;
  evidence?: string | null;
  confidence?: number | null;
}

// ── 3. Profile & Career Sub-models ──────────────────────────────────────────

export const EducationSchema = z.object({
  id: z.string().optional(),
  institution: z.string().nullable().optional(),
  degree: z.string().nullable().optional(),
  fieldOfStudy: z.string().nullable().optional(),
  startDate: TimestampOrDateSchema.nullable().optional(),
  endDate: TimestampOrDateSchema.nullable().optional(),
  current: z.boolean().nullable().optional(),
  grade: z.string().nullable().optional(),
  provenance: ProvenanceEnum.default("EXPLICIT"),
});
export type Education = z.infer<typeof EducationSchema>;

export const SkillItemSchema = z.object({
  name: z.string(),
  level: z.string().nullable().optional(),
  yearsOfExperience: z.number().nullable().optional(),
  provenance: ProvenanceEnum.default("EXPLICIT"),
});
export type SkillItem = z.infer<typeof SkillItemSchema>;

export const ExperienceSchema = z.object({
  id: z.string().optional(),
  company: z.string(),
  title: z.string(),
  location: z.string().nullable().optional(),
  startDate: TimestampOrDateSchema.nullable().optional(),
  endDate: TimestampOrDateSchema.nullable().optional(),
  current: z.boolean().nullable().optional(),
  description: z.string().nullable().optional(),
  highlights: z.array(z.string()).default([]),
  provenance: ProvenanceEnum.default("EXPLICIT"),
});
export type Experience = z.infer<typeof ExperienceSchema>;

export const ProjectSchema = z.object({
  id: z.string().optional(),
  title: z.string(),
  description: z.string().nullable().optional(),
  url: z.string().nullable().optional(),
  skills: z.array(z.string()).default([]),
  startDate: TimestampOrDateSchema.nullable().optional(),
  endDate: TimestampOrDateSchema.nullable().optional(),
  provenance: ProvenanceEnum.default("EXPLICIT"),
});
export type Project = z.infer<typeof ProjectSchema>;

export const CertificationSchema = z.object({
  id: z.string().optional(),
  name: z.string(),
  issuer: z.string().nullable().optional(),
  issueDate: TimestampOrDateSchema.nullable().optional(),
  expiryDate: TimestampOrDateSchema.nullable().optional(),
  credentialId: z.string().nullable().optional(),
  credentialUrl: z.string().nullable().optional(),
  provenance: ProvenanceEnum.default("EXPLICIT"),
});
export type Certification = z.infer<typeof CertificationSchema>;

export const CareerPreferencesSchema = z.object({
  desiredTitles: z.array(z.string()).default([]),
  preferredLocations: z.array(z.string()).default([]),
  preferredWorkModes: z.array(WorkModeEnum).default([]),
  preferredJobTypes: z.array(JobTypeEnum).default([]),
  preferredEmploymentTypes: z.array(EmploymentTypeEnum).default([]),
  minExpectedSalary: z.number().nullable().optional(),
  currency: z.string().default("INR"),
  noticePeriodDays: z.number().nullable().optional(),
  provenance: ProvenanceEnum.default("EXPLICIT"),
});
export type CareerPreferences = z.infer<typeof CareerPreferencesSchema>;

// ── 4. AppUser ───────────────────────────────────────────────────────────────

export const NotificationPreferencesSchema = z.object({
  jobAlerts: z.boolean().default(true),
  applicationUpdates: z.boolean().default(true),
  marketing: z.boolean().default(false),
});
export type NotificationPreferences = z.infer<typeof NotificationPreferencesSchema>;

export const AppUserSchema = z.object({
  id: z.string().optional(),
  uid: z.string().optional(),
  name: z.string().nullable().optional(),
  email: z.string().nullable().optional(),
  photoUrl: z.string().nullable().optional(),
  role: UserRoleEnum.default("USER"),
  onboardingDone: z.boolean().default(false),
  resumeParseStatus: ResumeParseStatusEnum.default("NOT_STARTED"),
  profileGeneratedAt: TimestampOrDateSchema.nullable().optional(),
  profileConfirmed: z.boolean().default(false),
  profileCompletion: z.number().min(0).max(100).default(0),
  notifPrefs: NotificationPreferencesSchema.default({
    jobAlerts: true,
    applicationUpdates: true,
    marketing: false,
  }),
  createdAt: TimestampOrDateSchema.nullable().optional(),
  // Server-side only fields (never writable by client):
  matchKeys: z.array(z.string()).optional(),
  fcm_tokens: z.array(z.string()).optional(),
});
export type AppUser = z.infer<typeof AppUserSchema>;

// ── 5. Recommendation ────────────────────────────────────────────────────────

export const ScoreBreakdownSchema = z.object({
  skills: z.number().default(0),
  education: z.number().default(0),
  experience: z.number().default(0),
  location: z.number().default(0),
  preference: z.number().default(0),
});
export type ScoreBreakdown = z.infer<typeof ScoreBreakdownSchema>;

export const RecommendationSchema = z.object({
  id: z.string().optional(),
  jobId: z.string().optional(),
  userId: z.string().optional(),
  score: z.number().min(0).max(100),
  breakdown: ScoreBreakdownSchema,
  matchedSkills: z.array(z.string()).default([]),
  missingSkills: z.array(z.string()).default([]),
  reasons: z.array(z.string()).default([]),
  scoreVersion: z.string().default("v1"),
  isNew: z.boolean().default(true),
  computedAt: TimestampOrDateSchema.nullable().optional(),
});
export type Recommendation = z.infer<typeof RecommendationSchema>;

// ── 6. Job ───────────────────────────────────────────────────────────────────

export const JobSalarySchema = z.object({
  min: z.number().nullable().optional(),
  max: z.number().nullable().optional(),
  currency: z.string().default("INR"),
});
export type JobSalary = z.infer<typeof JobSalarySchema>;

export const JobVerificationSchema = z.object({
  state: VerificationStateEnum.default("UNVERIFIED"),
  checkedAt: TimestampOrDateSchema.nullable().optional(),
  rules: z.array(z.string()).default([]),
});
export type JobVerification = z.infer<typeof JobVerificationSchema>;

export const JobSchema = z.object({
  id: z.string().optional(),
  companyId: z.string(),
  companyName: z.string(),
  sourceUrl: z.string().nullable().optional(),
  applyUrl: z.string(),
  title: z.string(),
  description: z.string(),
  aiSummary: z.string().nullable().optional(),
  jobType: JobTypeEnum.default("FULL_TIME"),
  category: z.string().nullable().optional(),
  requiredSkills: z.array(z.string()).default([]),
  preferredSkills: z.array(z.string()).default([]),
  minEdu: z.string().nullable().optional(),
  expMin: z.number().nullable().optional(),
  expMax: z.number().nullable().optional(),
  expLevel: ExperienceLevelEnum.default("MID_LEVEL"),
  employmentType: EmploymentTypeEnum.default("PERMANENT"),
  workMode: WorkModeEnum.default("ONSITE"),
  locations: z.array(z.string()).default([]),
  city: z.string().nullable().optional(),
  state: z.string().nullable().optional(),
  country: z.string().nullable().optional(),
  salary: JobSalarySchema.nullable().optional(),
  deadline: TimestampOrDateSchema.nullable().optional(),
  postedAt: TimestampOrDateSchema.nullable().optional(),
  status: JobStatusEnum.default("DRAFT_RAW"),
  verification: JobVerificationSchema.default({
    state: "UNVERIFIED",
    rules: [],
  }),
  reportCount: z.number().default(0),
  lastSeenAt: TimestampOrDateSchema.nullable().optional(),
});
export type Job = z.infer<typeof JobSchema>;

// ── 7. Source & Company ──────────────────────────────────────────────────────

export const SourceSchema = z.object({
  id: z.string().optional(),
  companyId: z.string().optional(),
  type: SourceTypeEnum.default("CAREERS_PAGE"),
  url: z.string().url(),
  isActive: z.boolean().default(true),
  lastSyncAt: TimestampOrDateSchema.nullable().optional(),
  createdAt: TimestampOrDateSchema.nullable().optional(),
});
export type Source = z.infer<typeof SourceSchema>;

export const CompanySchema = z.object({
  id: z.string().optional(),
  name: z.string(),
  slug: z.string().nullable().optional(),
  website: z.string().nullable().optional(),
  careersUrl: z.string().nullable().optional(),
  logoUrl: z.string().nullable().optional(),
  description: z.string().nullable().optional(),
  industry: z.string().nullable().optional(),
  headquarters: z.string().nullable().optional(),
  isVerified: z.boolean().default(false),
  sources: z.array(SourceSchema).default([]),
  createdAt: TimestampOrDateSchema.nullable().optional(),
  updatedAt: TimestampOrDateSchema.nullable().optional(),
});
export type Company = z.infer<typeof CompanySchema>;

// ── 8. CollectionRun ─────────────────────────────────────────────────────────

export const CollectionRunSchema = z.object({
  id: z.string().optional(),
  sourceId: z.string().nullable().optional(),
  companyId: z.string().nullable().optional(),
  status: z.string().default("RUNNING"),
  jobsFound: z.number().default(0),
  jobsCreated: z.number().default(0),
  jobsUpdated: z.number().default(0),
  errors: z.array(z.string()).default([]),
  startedAt: TimestampOrDateSchema.nullable().optional(),
  completedAt: TimestampOrDateSchema.nullable().optional(),
});
export type CollectionRun = z.infer<typeof CollectionRunSchema>;

// ── 9. ReportItem ────────────────────────────────────────────────────────────

export const ReportItemSchema = z.object({
  id: z.string().optional(),
  jobId: z.string(),
  userId: z.string(),
  reason: z.string(),
  details: z.string().nullable().optional(),
  status: z.enum(["PENDING", "INVESTIGATING", "RESOLVED", "DISMISSED"]).default("PENDING"),
  createdAt: TimestampOrDateSchema.nullable().optional(),
  reviewedAt: TimestampOrDateSchema.nullable().optional(),
  reviewedBy: z.string().nullable().optional(),
});
export type ReportItem = z.infer<typeof ReportItemSchema>;

// ── 10. AppNotification ──────────────────────────────────────────────────────

export const AppNotificationSchema = z.object({
  id: z.string().optional(),
  userId: z.string(),
  title: z.string(),
  body: z.string(),
  type: z.string().default("JOB_MATCH"),
  data: z.record(z.any()).nullable().optional(),
  isRead: z.boolean().default(false),
  createdAt: TimestampOrDateSchema.nullable().optional(),
});
export type AppNotification = z.infer<typeof AppNotificationSchema>;

// ── 11. AuditLog ─────────────────────────────────────────────────────────────

export const AuditLogSchema = z.object({
  id: z.string().optional(),
  action: z.string(),
  performedBy: z.string(),
  targetType: z.string(),
  targetId: z.string(),
  details: z.record(z.any()).nullable().optional(),
  ipAddress: z.string().nullable().optional(),
  userAgent: z.string().nullable().optional(),
  timestamp: TimestampOrDateSchema.nullable().optional(),
});
export type AuditLog = z.infer<typeof AuditLogSchema>;

// ── 12. ScoringConfig & AppConfig ───────────────────────────────────────────

export const ScoringConfigSchema = z
  .object({
    skills: z.number().default(40),
    education: z.number().default(15),
    experience: z.number().default(15),
    location: z.number().default(10),
    preference: z.number().default(20),
    threshold: z.number().default(55),
    softCap: z.number().default(74),
    labels: z
      .object({
        excellent: z.number().default(80),
        good: z.number().default(65),
        fair: z.number().default(55),
      })
      .default({
        excellent: 80,
        good: 65,
        fair: 55,
      }),
  })
  .refine(
    (cfg) =>
      cfg.skills + cfg.education + cfg.experience + cfg.location + cfg.preference === 100,
    {
      message: "ScoringConfig weights must total exactly 100 (skills + education + experience + location + preference = 100)",
    },
  );
export type ScoringConfig = z.infer<typeof ScoringConfigSchema>;

export const DEFAULT_SCORING_CONFIG: ScoringConfig = {
  skills: 40,
  education: 15,
  experience: 15,
  location: 10,
  preference: 20,
  threshold: 55,
  softCap: 74,
  labels: {
    excellent: 80,
    good: 65,
    fair: 55,
  },
};

export const AppConfigSchema = z.object({
  id: z.string().optional(),
  scoring: ScoringConfigSchema.default(DEFAULT_SCORING_CONFIG),
  minSupportedVersion: z.string().default("1.0.0"),
  maintenanceMode: z.boolean().default(false),
  termsUrl: z.string().nullable().optional(),
  privacyUrl: z.string().nullable().optional(),
});
export type AppConfig = z.infer<typeof AppConfigSchema>;

// ── 13. Category ─────────────────────────────────────────────────────────────

export const CategorySchema = z.object({
  id: z.string().optional(),
  name: z.string(),
  type: z.string().nullable().optional(),
  aliases: z.array(z.string()).default([]),
  keywords: z.array(z.string()).default([]),
  order: z.number().default(0),
  active: z.boolean().default(true),
  activeCount: z.number().default(0),
});
export type Category = z.infer<typeof CategorySchema>;
