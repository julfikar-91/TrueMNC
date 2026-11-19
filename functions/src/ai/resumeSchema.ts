// functions/src/ai/resumeSchema.ts
import { z } from "zod";
import { Provenance, ProvenanceEnum } from "../utils/types";

/**
 * Universal wrapper for every single extracted resume field.
 * Tracks value, extraction provenance, textual evidence, and confidence score.
 */
export const createFieldSchema = <T extends z.ZodTypeAny>(valueSchema: T) =>
  z.object({
    value: valueSchema.nullable(),
    provenance: ProvenanceEnum,
    evidence: z.string().nullable().optional().default(null),
    confidence: z.number().min(0).max(1).default(1.0),
  });

export const StringFieldSchema = createFieldSchema(z.string());
export const NumberFieldSchema = createFieldSchema(z.number());
export const BooleanFieldSchema = createFieldSchema(z.boolean());

export type Field<T> = {
  value: T | null;
  provenance: Provenance;
  evidence: string | null;
  confidence: number;
};

// ── 1. Personal Section ──────────────────────────────────────────────────────
export const PersonalSectionSchema = z.object({
  name: StringFieldSchema,
  email: StringFieldSchema,
  phone: StringFieldSchema,
  location: StringFieldSchema,
  linkedin: StringFieldSchema,
  github: StringFieldSchema,
  portfolio: StringFieldSchema,
});

// ── 2. Education Section ────────────────────────────────────────────────────
export const EducationLevelEnum = z.enum([
  "HIGH_SCHOOL",
  "BACHELORS",
  "MASTERS",
  "DOCTORATE",
  "DIPLOMA",
  "OTHER",
]);

export const EducationItemSchema = z.object({
  degree: StringFieldSchema,
  specialization: StringFieldSchema,
  institution: StringFieldSchema,
  graduationYear: createFieldSchema(z.union([z.number(), z.string()])),
  gradValue: createFieldSchema(z.union([z.number(), z.string()])),
  gradScale: createFieldSchema(z.union([z.number(), z.string()])),
  level: createFieldSchema(EducationLevelEnum),
});

export type EducationItem = z.infer<typeof EducationItemSchema>;

// ── 3. Skills Section ───────────────────────────────────────────────────────
export const SkillsSectionSchema = z.object({
  languages: z.array(StringFieldSchema).default([]),
  frameworks: z.array(StringFieldSchema).default([]),
  libraries: z.array(StringFieldSchema).default([]),
  databases: z.array(StringFieldSchema).default([]),
  cloud: z.array(StringFieldSchema).default([]),
  tools: z.array(StringFieldSchema).default([]),
  technicalCerts: z.array(StringFieldSchema).default([]),
  soft: z.array(StringFieldSchema).default([]),
});

// ── 4. Experience Section ───────────────────────────────────────────────────
export const ExperienceItemSchema = z.object({
  company: StringFieldSchema,
  title: StringFieldSchema,
  location: StringFieldSchema,
  startDate: StringFieldSchema,
  endDate: StringFieldSchema,
  isCurrent: BooleanFieldSchema,
  description: StringFieldSchema,
  highlights: z.array(StringFieldSchema).default([]),
});

export type ExperienceItem = z.infer<typeof ExperienceItemSchema>;

export const ExperienceSectionSchema = z.object({
  totalExperienceStated: createFieldSchema(z.union([z.number(), z.string()])),
  items: z.array(ExperienceItemSchema).default([]),
});

// ── 5. Projects Section ─────────────────────────────────────────────────────
export const ProjectItemSchema = z.object({
  title: StringFieldSchema,
  description: StringFieldSchema,
  role: StringFieldSchema,
  tools: z.array(StringFieldSchema).default([]),
  url: StringFieldSchema,
  highlights: z.array(StringFieldSchema).default([]),
});

export type ProjectItem = z.infer<typeof ProjectItemSchema>;

// ── 6. Certifications Section ───────────────────────────────────────────────
export const CertificationItemSchema = z.object({
  name: StringFieldSchema,
  issuer: StringFieldSchema,
  issueDate: StringFieldSchema,
  expiryDate: StringFieldSchema,
  url: StringFieldSchema,
  credentialId: StringFieldSchema,
});

export type CertificationItem = z.infer<typeof CertificationItemSchema>;

// ── 7. Achievements Section ─────────────────────────────────────────────────
export const AchievementItemSchema = z.object({
  title: StringFieldSchema,
  description: StringFieldSchema,
  date: StringFieldSchema,
});

export type AchievementItem = z.infer<typeof AchievementItemSchema>;

// ── 8. Languages Section ────────────────────────────────────────────────────
export const LanguageItemSchema = z.object({
  language: StringFieldSchema,
  proficiency: StringFieldSchema,
});

export type LanguageItem = z.infer<typeof LanguageItemSchema>;

// ── Full Resume Extraction Schema ───────────────────────────────────────────
export const ResumeExtractionSchema = z.object({
  personal: PersonalSectionSchema,
  education: z.array(EducationItemSchema).default([]),
  skills: SkillsSectionSchema,
  experience: ExperienceSectionSchema,
  projects: z.array(ProjectItemSchema).default([]),
  certifications: z.array(CertificationItemSchema).default([]),
  achievements: z.array(AchievementItemSchema).default([]),
  languages: z.array(LanguageItemSchema).default([]),
  summary: StringFieldSchema,
});

export type ResumeExtraction = z.infer<typeof ResumeExtractionSchema>;
