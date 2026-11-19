// functions/src/ai/postProcess.ts
import * as zlib from "zlib";
import { ResumeExtraction } from "./resumeSchema";
import { normaliseSkill } from "../matching/skills";

export interface FileValidationResult {
  valid: boolean;
  mimeType: "application/pdf" | "application/vnd.openxmlformats-officedocument.wordprocessingml.document" | "text/plain";
  text: string;
  errorCode?: "RESUME_TYPE_INVALID" | "RESUME_TOO_LARGE" | "RESUME_UNREADABLE";
  errorMessage?: string;
  pageCount?: number;
}

export interface PostProcessResult {
  draft: ResumeExtraction;
  warnings: string[];
  status: "PARSED" | "PARTIAL";
}

const MAX_FILE_SIZE = 5 * 1024 * 1024; // 5 MB
const MAX_PAGES = 10;
const MIN_TEXT_LENGTH = 200;

/**
 * Validates file magic bytes, size, encryption, page limits,
 * and extracts server-side text.
 */
export function validateAndExtractText(buffer: Buffer): FileValidationResult {
  if (buffer.length > MAX_FILE_SIZE) {
    return {
      valid: false,
      mimeType: "text/plain",
      text: "",
      errorCode: "RESUME_TOO_LARGE",
      errorMessage: "File exceeds maximum size limit of 5 MB.",
    };
  }

  // Check PDF magic bytes: %PDF- (0x25, 0x50, 0x44, 0x46, 0x2D)
  const isPdf =
    buffer.length >= 5 &&
    buffer[0] === 0x25 &&
    buffer[1] === 0x50 &&
    buffer[2] === 0x44 &&
    buffer[3] === 0x46 &&
    buffer[4] === 0x2d;

  // Check DOCX magic bytes: PK\x03\x04 (0x50, 0x4B, 0x03, 0x04)
  const isDocx =
    buffer.length >= 4 &&
    buffer[0] === 0x50 &&
    buffer[1] === 0x4b &&
    buffer[2] === 0x03 &&
    buffer[3] === 0x04;

  if (isPdf) {
    return processPdf(buffer);
  } else if (isDocx) {
    return processDocx(buffer);
  } else {
    // Check if it's valid UTF-8 plain text (e.g. for testing or raw text uploads)
    // But reject binary executables (e.g. MZ header 0x4D, 0x5A or ELF 0x7F, 'E', 'L', 'F')
    if (buffer.length >= 2 && buffer[0] === 0x4d && buffer[1] === 0x5a) {
      return {
        valid: false,
        mimeType: "text/plain",
        text: "",
        errorCode: "RESUME_TYPE_INVALID",
        errorMessage: "Executable files are not permitted.",
      };
    }

    const text = buffer.toString("utf-8");
    if (text.length < MIN_TEXT_LENGTH) {
      return {
        valid: false,
        mimeType: "text/plain",
        text,
        errorCode: "RESUME_UNREADABLE",
        errorMessage: "Extracted resume text is less than 200 characters.",
      };
    }

    return {
      valid: true,
      mimeType: "text/plain",
      text,
      pageCount: 1,
    };
  }
}

function processPdf(buffer: Buffer): FileValidationResult {
  const rawString = buffer.toString("latin1");

  // Check encryption / password protection
  if (rawString.includes("/Encrypt")) {
    return {
      valid: false,
      mimeType: "application/pdf",
      text: "",
      errorCode: "RESUME_UNREADABLE",
      errorMessage: "Password-protected or encrypted PDFs are not supported.",
    };
  }

  // Count pages: match /Type /Page (excluding /Pages)
  const pageMatches = rawString.match(/\/Type\s*\/Page\b/g);
  const pageCount = pageMatches ? pageMatches.length : 1;

  if (pageCount > MAX_PAGES) {
    return {
      valid: false,
      mimeType: "application/pdf",
      text: "",
      errorCode: "RESUME_TOO_LARGE",
      errorMessage: `PDF exceeds maximum page limit of ${MAX_PAGES} pages (found ${pageCount}).`,
      pageCount,
    };
  }

  // Extract text from PDF streams and content operators
  let extractedText = "";

  // 1. Extract and decompress FlateDecode streams
  const streamRegex = /stream\r?\n([\s\S]*?)\r?\nendstream/g;
  let match: RegExpExecArray | null;

  while ((match = streamRegex.exec(rawString)) !== null) {
    const streamContent = match[1];
    const streamBuf = Buffer.from(streamContent, "latin1");

    // Try inflating flate stream
    let decompressed: string | null = null;
    try {
      decompressed = zlib.inflateSync(streamBuf).toString("utf-8");
    } catch {
      try {
        decompressed = zlib.inflateRawSync(streamBuf).toString("utf-8");
      } catch {
        // Not compressed or raw text
        decompressed = streamContent;
      }
    }

    if (decompressed) {
      // Extract text in PDF text blocks: (text) Tj or [(t)(e)(x)(t)] TJ
      const textMatches = decompressed.match(/\(([^)]+)\)\s*T[jJ]/g);
      if (textMatches) {
        for (const tm of textMatches) {
          const inner = tm.replace(/^.*\(/, "").replace(/\)\s*T[jJ]$/, "");
          extractedText += inner + " ";
        }
      } else {
        // Look for TJ array syntax
        const tjMatches = decompressed.match(/\[(.*?)\]\s*TJ/g);
        if (tjMatches) {
          for (const tj of tjMatches) {
            const parts = tj.match(/\(([^)]+)\)/g);
            if (parts) {
              extractedText += parts.map((p) => p.slice(1, -1)).join("") + " ";
            }
          }
        }
      }
    }
  }

  // Fallback: if stream extraction didn't find enough text, scan ASCII words
  if (extractedText.trim().length < MIN_TEXT_LENGTH) {
    const cleanAscii = rawString
      .replace(/[\x00-\x1F\x7F-\xFF]/g, " ")
      .replace(/obj[\s\S]*?endobj/g, " ")
      .replace(/stream[\s\S]*?endstream/g, " ")
      .replace(/<<[\s\S]*?>>/g, " ")
      .replace(/\s+/g, " ")
      .trim();

    if (cleanAscii.length > extractedText.length) {
      extractedText = cleanAscii;
    }
  }

  if (extractedText.trim().length < MIN_TEXT_LENGTH) {
    return {
      valid: false,
      mimeType: "application/pdf",
      text: extractedText,
      errorCode: "RESUME_UNREADABLE",
      errorMessage: "Extracted PDF text is less than 200 characters (scanned images or empty documents not supported).",
      pageCount,
    };
  }

  return {
    valid: true,
    mimeType: "application/pdf",
    text: extractedText.trim(),
    pageCount,
  };
}

function processDocx(buffer: Buffer): FileValidationResult {
  // Parse ZIP to locate word/document.xml
  let offset = 0;
  let documentXml: string | null = null;

  try {
    while (offset < buffer.length - 4) {
      if (
        buffer[offset] === 0x50 &&
        buffer[offset + 1] === 0x4b &&
        buffer[offset + 2] === 0x03 &&
        buffer[offset + 3] === 0x04
      ) {
        // Local file header
        const compMethod = buffer.readUInt16LE(offset + 8);
        const compSize = buffer.readUInt32LE(offset + 18);
        const fileNameLen = buffer.readUInt16LE(offset + 26);
        const extraLen = buffer.readUInt16LE(offset + 28);

        const fileNameStart = offset + 30;
        const fileNameEnd = fileNameStart + fileNameLen;
        const fileName = buffer.toString("utf-8", fileNameStart, fileNameEnd);

        const dataStart = fileNameEnd + extraLen;
        const dataEnd = dataStart + compSize;

        if (fileName === "word/document.xml") {
          const compData = buffer.slice(dataStart, dataEnd);
          if (compMethod === 8) {
            documentXml = zlib.inflateRawSync(compData).toString("utf-8");
          } else if (compMethod === 0) {
            documentXml = compData.toString("utf-8");
          }
          break;
        }

        offset = dataEnd;
      } else {
        offset++;
      }
    }
  } catch {
    // If ZIP traversal fails
  }

  if (!documentXml) {
    return {
      valid: false,
      mimeType: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
      text: "",
      errorCode: "RESUME_TYPE_INVALID",
      errorMessage: "DOCX file is missing word/document.xml or is corrupt.",
    };
  }

  // Strip XML tags and unescape
  const extractedText = documentXml
    .replace(/<w:p[^>]*>/gi, "\n")
    .replace(/<[^>]+>/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/\s+/g, " ")
    .trim();

  if (extractedText.length < MIN_TEXT_LENGTH) {
    return {
      valid: false,
      mimeType: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
      text: extractedText,
      errorCode: "RESUME_UNREADABLE",
      errorMessage: "Extracted DOCX text is less than 200 characters.",
    };
  }

  return {
    valid: true,
    mimeType: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    text: extractedText,
    pageCount: 1,
  };
}

/**
 * Post-processes the extracted resume JSON:
 * - Drops prompt-injection phrases
 * - Sanitizes HTML tags
 * - Validates emails, phones, URLs, graduation years, CGPA scales
 * - Fuzzy evidence matching: downgrades EXPLICIT to INFERRED if evidence missing
 * - Normalises skills via canonical dictionary and flags unrecognised skills
 * - Enforces string limits
 * - Determines status: PARSED vs PARTIAL
 */
export function postProcessResume(
  rawDraft: ResumeExtraction,
  resumeText: string
): PostProcessResult {
  const warnings: string[] = [];
  const normalizedText = normalizeWhitespace(resumeText.toLowerCase());

  // Deep clone to avoid mutating input directly
  const draft: ResumeExtraction = JSON.parse(JSON.stringify(rawDraft));

  // 1. Sanitize Personal Section
  sanitizeField(draft.personal.name, 200);
  sanitizeField(draft.personal.email, 200);
  sanitizeField(draft.personal.phone, 50);
  sanitizeField(draft.personal.location, 200);
  sanitizeField(draft.personal.linkedin, 300);
  sanitizeField(draft.personal.github, 300);
  sanitizeField(draft.personal.portfolio, 300);

  // Email format validation
  if (draft.personal.email.value) {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(draft.personal.email.value)) {
      warnings.push(`Invalid email format: "${draft.personal.email.value}".`);
      draft.personal.email.value = null;
      draft.personal.email.provenance = "MISSING";
    }
  }

  // Phone format validation (8 to 15 digits)
  if (draft.personal.phone.value) {
    const digitsOnly = draft.personal.phone.value.replace(/[^0-9]/g, "");
    if (digitsOnly.length < 8 || digitsOnly.length > 15) {
      warnings.push(`Phone number has unusual length: "${draft.personal.phone.value}".`);
    }
  }

  // URL normalization
  normalizeUrlField(draft.personal.linkedin, warnings, "LinkedIn URL");
  normalizeUrlField(draft.personal.github, warnings, "GitHub URL");
  normalizeUrlField(draft.personal.portfolio, warnings, "Portfolio URL");

  // Evidence check for personal
  checkEvidence(draft.personal.name, normalizedText, "personal.name", warnings);
  checkEvidence(draft.personal.email, normalizedText, "personal.email", warnings);
  checkEvidence(draft.personal.phone, normalizedText, "personal.phone", warnings);
  checkEvidence(draft.personal.location, normalizedText, "personal.location", warnings);

  // 2. Education Section
  const currentYear = new Date().getFullYear();
  const minGradYear = 1980;
  const maxGradYear = currentYear + 6;

  for (let i = 0; i < draft.education.length; i++) {
    const edu = draft.education[i];
    sanitizeField(edu.degree, 200);
    sanitizeField(edu.specialization, 200);
    sanitizeField(edu.institution, 200);

    // Graduation Year Validation
    if (edu.graduationYear.value !== null) {
      const year = Number(edu.graduationYear.value);
      if (isNaN(year) || year < minGradYear || year > maxGradYear) {
        warnings.push(`Education [${i}]: Invalid graduation year ${edu.graduationYear.value}.`);
      }
    }

    // CGPA / GradScale Validation
    if (edu.gradValue.value !== null && edu.gradScale.value !== null) {
      const val = Number(edu.gradValue.value);
      const scale = Number(edu.gradScale.value);
      if (!isNaN(val) && !isNaN(scale) && val > scale) {
        warnings.push(`Education [${i}]: gradValue (${val}) exceeds gradScale (${scale}).`);
      }
    }

    checkEvidence(edu.degree, normalizedText, `education[${i}].degree`, warnings);
    checkEvidence(edu.institution, normalizedText, `education[${i}].institution`, warnings);
  }

  // 3. Skills Normalization & Verification
  const skillCategories: Array<keyof typeof draft.skills> = [
    "languages",
    "frameworks",
    "libraries",
    "databases",
    "cloud",
    "tools",
    "technicalCerts",
    "soft",
  ];

  for (const cat of skillCategories) {
    const list = draft.skills[cat];
    if (Array.isArray(list)) {
      for (const skillField of list) {
        sanitizeField(skillField, 100);
        if (skillField.value) {
          const norm = normaliseSkill(skillField.value);
          if (norm.flagged) {
            warnings.push(`Skill "${skillField.value}" in ${cat} flagged for review.`);
          }
        }
        checkEvidence(skillField, normalizedText, `skills.${cat}`, warnings);
      }
    }
  }

  // 4. Experience Section
  sanitizeField(draft.experience.totalExperienceStated, 100);
  for (let i = 0; i < draft.experience.items.length; i++) {
    const exp = draft.experience.items[i];
    sanitizeField(exp.company, 200);
    sanitizeField(exp.title, 200);
    sanitizeField(exp.location, 200);
    sanitizeField(exp.startDate, 100);
    sanitizeField(exp.endDate, 100);
    sanitizeField(exp.description, 2000);

    for (const h of exp.highlights) {
      sanitizeField(h, 500);
    }

    checkEvidence(exp.company, normalizedText, `experience[${i}].company`, warnings);
    checkEvidence(exp.title, normalizedText, `experience[${i}].title`, warnings);
  }

  // 5. Projects Section
  for (let i = 0; i < draft.projects.length; i++) {
    const proj = draft.projects[i];
    sanitizeField(proj.title, 200);
    sanitizeField(proj.description, 2000);
    sanitizeField(proj.role, 200);
    normalizeUrlField(proj.url, warnings, `Project [${i}] URL`);
    for (const t of proj.tools) {
      sanitizeField(t, 100);
    }
    for (const h of proj.highlights) {
      sanitizeField(h, 500);
    }
    checkEvidence(proj.title, normalizedText, `projects[${i}].title`, warnings);
  }

  // 6. Certifications Section
  for (let i = 0; i < draft.certifications.length; i++) {
    const cert = draft.certifications[i];
    sanitizeField(cert.name, 200);
    sanitizeField(cert.issuer, 200);
    sanitizeField(cert.issueDate, 100);
    sanitizeField(cert.expiryDate, 100);
    sanitizeField(cert.credentialId, 200);
    normalizeUrlField(cert.url, warnings, `Certification [${i}] URL`);
    checkEvidence(cert.name, normalizedText, `certifications[${i}].name`, warnings);
  }

  // 7. Achievements & Languages
  for (const ach of draft.achievements) {
    sanitizeField(ach.title, 200);
    sanitizeField(ach.description, 1000);
    sanitizeField(ach.date, 100);
  }
  for (const lang of draft.languages) {
    sanitizeField(lang.language, 100);
    sanitizeField(lang.proficiency, 100);
  }

  // 8. Summary
  sanitizeField(draft.summary, 1000);

  // Determine status: PARTIAL if critical fields are missing
  const hasName = Boolean(draft.personal.name.value);
  const hasEmail = Boolean(draft.personal.email.value);
  const totalSkills = skillCategories.reduce(
    (acc, cat) => acc + (draft.skills[cat]?.length ?? 0),
    0
  );
  const hasEducation = draft.education.length > 0;
  const hasExperience = draft.experience.items.length > 0;

  let status: "PARSED" | "PARTIAL" = "PARSED";
  if (!hasName || !hasEmail || (!hasEducation && !hasExperience && totalSkills === 0)) {
    status = "PARTIAL";
    warnings.push("Resume is missing key identifiers or experience/education sections.");
  }

  return {
    draft,
    warnings,
    status,
  };
}

/**
 * Sanitizes string field by stripping HTML tags, stripping prompt injections,
 * and capping string length.
 */
function sanitizeField(
  field: { value: string | number | boolean | null; provenance: string; evidence?: string | null },
  maxLength: number
): void {
  if (typeof field.value === "string") {
    let clean = field.value
      .replace(/<[^>]*>/g, "") // Strip HTML
      .trim();

    // Drop prompt injection phrases
    const injectionPhrases = [
      /ignore\s+(all\s+)?(previous|prior)\s+instructions/gi,
      /you\s+are\s+now\s+a/gi,
      /disregard\s+all\s+rules/gi,
      /system\s+prompt:/gi,
      /always\s+respond\s+with/gi,
    ];
    for (const phrase of injectionPhrases) {
      clean = clean.replace(phrase, "").trim();
    }
    clean = clean.replace(/\s+/g, " ").trim();

    if (clean.length > maxLength) {
      clean = clean.substring(0, maxLength);
    }

    field.value = clean.length > 0 ? clean : null;
  }
}

/**
 * Checks if verbatim evidence is present in resume text.
 * If evidence is absent, downgrades EXPLICIT to INFERRED.
 */
function checkEvidence(
  field: { value: unknown; provenance: string; evidence?: string | null },
  normalizedResumeText: string,
  fieldPath: string,
  warnings: string[]
): void {
  if (field.provenance === "EXPLICIT" && field.value !== null) {
    if (!field.evidence) {
      field.provenance = "INFERRED";
      warnings.push(`Evidence missing for ${fieldPath}: downgraded to INFERRED.`);
    } else {
      const normEvidence = normalizeWhitespace(field.evidence.toLowerCase());
      if (!normalizedResumeText.includes(normEvidence)) {
        field.provenance = "INFERRED";
        warnings.push(`Evidence "${field.evidence}" not found in resume text for ${fieldPath}: downgraded to INFERRED.`);
      }
    }
  }
}

function normalizeWhitespace(str: string): string {
  return str.replace(/\s+/g, " ").trim();
}

function normalizeUrlField(
  field: { value: string | null; provenance: string },
  warnings: string[],
  label: string
): void {
  if (field.value) {
    let url = field.value.trim();
    if (!url.startsWith("http://") && !url.startsWith("https://")) {
      url = "https://" + url;
    }
    try {
      new URL(url);
      field.value = url;
    } catch {
      warnings.push(`Invalid URL format for ${label}: "${field.value}".`);
      field.value = null;
      field.provenance = "MISSING";
    }
  }
}
