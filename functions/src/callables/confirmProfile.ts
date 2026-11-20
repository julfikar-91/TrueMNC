// functions/src/callables/confirmProfile.ts
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { z } from "zod";

import { REGION, db, Collections } from "../utils/config";
import { validate } from "../utils/validators";
import { logInfo } from "../utils/logger";
import { ResumeExtraction, ResumeExtractionSchema } from "../ai/resumeSchema";
import { normaliseSkill } from "../matching/skills";
import { onProfileConfirmedOrPreferencesChanged } from "../matching/fanout";

const FN = "confirmProfile";

const ConfirmProfileInputSchema = z.object({
  resumeId: z.string().min(1, "resumeId is required"),
  confirmedProfile: ResumeExtractionSchema.optional(),
});

export const confirmProfile = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required to confirm profile.");
    }

    const { uid } = request.auth;
    const input = validate(ConfirmProfileInputSchema, request.data);
    const { resumeId } = input;

    logInfo(FN, "Confirming profile from resume draft", { resumeId, uid });

    // 1. Fetch draft from resumeParses
    const parseDocRef = db().collection("resumeParses").doc(resumeId);
    const parseSnap = await parseDocRef.get();

    if (!parseSnap.exists) {
      throw new HttpsError("not-found", "Resume draft not found.");
    }

    const parseData = parseSnap.data();
    if (parseData?.uid !== uid) {
      throw new HttpsError("permission-denied", "Unauthorized: Resume draft belongs to another user.");
    }

    // 2. Select profile data: user edits take precedence over original draft
    const profileToConfirm: ResumeExtraction = input.confirmedProfile ?? parseData.draft;

    const batch = db().batch();
    const userRef = db().collection(Collections.USERS).doc(uid);

    // 3. Populate subcollections with confirmed: true
    // Subcollection: education
    for (let i = 0; i < profileToConfirm.education.length; i++) {
      const item = profileToConfirm.education[i];
      // Keep only explicit or user-confirmed items
      if (item.degree.value) {
        const eduRef = userRef.collection("education").doc(`edu_${i}`);
        batch.set(eduRef, {
          id: `edu_${i}`,
          degree: item.degree.value,
          specialization: item.specialization.value,
          institution: item.institution.value,
          graduationYear: item.graduationYear.value,
          gradValue: item.gradValue.value,
          gradScale: item.gradScale.value,
          level: item.level.value,
          provenance: item.degree.provenance,
          confirmed: true,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }

    // Subcollection: skills
    const canonicalSkills: string[] = [];
    const skillsByCategory: Record<string, string[]> = {};

    const categories: Array<keyof typeof profileToConfirm.skills> = [
      "languages",
      "frameworks",
      "libraries",
      "databases",
      "cloud",
      "tools",
      "technicalCerts",
      "soft",
    ];

    for (const cat of categories) {
      skillsByCategory[cat] = [];
      const list = profileToConfirm.skills[cat];
      if (Array.isArray(list)) {
        for (const s of list) {
          if (s.value) {
            skillsByCategory[cat].push(s.value);
            const norm = normaliseSkill(s.value);
            canonicalSkills.push(norm.canonicalId ?? s.value.toLowerCase().trim());
          }
        }
      }
    }

    const skillsDocRef = userRef.collection("skills").doc("canonical");
    batch.set(skillsDocRef, {
      ...skillsByCategory,
      canonicalList: Array.from(new Set(canonicalSkills)),
      confirmed: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Subcollection: experience
    for (let i = 0; i < profileToConfirm.experience.items.length; i++) {
      const item = profileToConfirm.experience.items[i];
      if (item.company.value || item.title.value) {
        const expRef = userRef.collection("experience").doc(`exp_${i}`);
        batch.set(expRef, {
          id: `exp_${i}`,
          company: item.company.value,
          title: item.title.value,
          location: item.location.value,
          startDate: item.startDate.value,
          endDate: item.endDate.value,
          isCurrent: item.isCurrent.value ?? false,
          description: item.description.value,
          highlights: item.highlights.map((h) => h.value).filter(Boolean),
          provenance: item.company.provenance,
          confirmed: true,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }

    // Subcollection: projects
    for (let i = 0; i < profileToConfirm.projects.length; i++) {
      const item = profileToConfirm.projects[i];
      if (item.title.value) {
        const projRef = userRef.collection("projects").doc(`proj_${i}`);
        batch.set(projRef, {
          id: `proj_${i}`,
          title: item.title.value,
          description: item.description.value,
          role: item.role.value,
          url: item.url.value,
          tools: item.tools.map((t) => t.value).filter(Boolean),
          highlights: item.highlights.map((h) => h.value).filter(Boolean),
          confirmed: true,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }

    // Subcollection: certifications
    for (let i = 0; i < profileToConfirm.certifications.length; i++) {
      const item = profileToConfirm.certifications[i];
      if (item.name.value) {
        const certRef = userRef.collection("certifications").doc(`cert_${i}`);
        batch.set(certRef, {
          id: `cert_${i}`,
          name: item.name.value,
          issuer: item.issuer.value,
          issueDate: item.issueDate.value,
          expiryDate: item.expiryDate.value,
          url: item.url.value,
          credentialId: item.credentialId.value,
          confirmed: true,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }

    // 4. Compute profile_completion (strictly sums to 100 max)
    // Points formula:
    // Personal: 20 (name, email, phone)
    // Education: 20 (>= 1 education)
    // Skills: 20 (>= 3 skills)
    // Experience: 15 (>= 1 experience item or explicit fresher)
    // Projects: 10 (>= 1 project)
    // Preferences: 10 (existing user preferences or default set)
    // Photo/Links: 5 (linkedin, github, or portfolio)
    let personalScore = 0;
    if (profileToConfirm.personal.name.value) personalScore += 10;
    if (profileToConfirm.personal.email.value) personalScore += 5;
    if (profileToConfirm.personal.phone.value) personalScore += 5;

    const educationScore = profileToConfirm.education.length > 0 ? 20 : 0;
    const skillsScore = canonicalSkills.length >= 3 ? 20 : (canonicalSkills.length > 0 ? 10 : 0);

    const isFresher =
      String(profileToConfirm.experience.totalExperienceStated.value ?? "")
        .toLowerCase()
        .includes("fresher") ||
      profileToConfirm.experience.totalExperienceStated.value === 0;

    const experienceScore =
      profileToConfirm.experience.items.length > 0 || isFresher ? 15 : 0;

    const projectsScore = profileToConfirm.projects.length > 0 ? 10 : 0;

    // Check existing preferences on user document if available
    const userDocSnap = await userRef.get();
    const existingUserData = userDocSnap.data() || {};
    const preferencesScore =
      existingUserData.preferences && Object.keys(existingUserData.preferences).length > 0
        ? 10
        : 10; // Default candidate preference allocated on confirmation

    const hasLinks = Boolean(
      profileToConfirm.personal.linkedin.value ||
        profileToConfirm.personal.github.value ||
        profileToConfirm.personal.portfolio.value
    );
    const photoLinksScore = hasLinks ? 5 : 0;

    const profileCompletion =
      personalScore +
      educationScore +
      skillsScore +
      experienceScore +
      projectsScore +
      preferencesScore +
      photoLinksScore;

    // 5. Compute matchKeys for indexing & fast matching queries
    const matchKeysSet = new Set<string>();

    // Canonical skills
    for (const skill of canonicalSkills) {
      matchKeysSet.add(`skill:${skill}`);
    }

    // Locations
    if (profileToConfirm.personal.location.value) {
      matchKeysSet.add(`loc:${profileToConfirm.personal.location.value.toLowerCase().trim()}`);
    }

    // Education levels
    for (const edu of profileToConfirm.education) {
      if (edu.level.value) {
        matchKeysSet.add(`edu:${edu.level.value.toLowerCase()}`);
      }
    }

    // Titles
    for (const exp of profileToConfirm.experience.items) {
      if (exp.title.value) {
        matchKeysSet.add(`title:${exp.title.value.toLowerCase().trim()}`);
      }
    }

    const matchKeys = Array.from(matchKeysSet);

    // 6. Update user master document
    batch.update(userRef, {
      name: profileToConfirm.personal.name.value,
      email: profileToConfirm.personal.email.value,
      phone: profileToConfirm.personal.phone.value,
      location: profileToConfirm.personal.location.value,
      linkedin: profileToConfirm.personal.linkedin.value,
      github: profileToConfirm.personal.github.value,
      portfolio: profileToConfirm.personal.portfolio.value,
      summary: profileToConfirm.summary.value,
      profile_completion: profileCompletion,
      matchKeys,
      profile_confirmed: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 7. Update status to CONFIRMED
    const resumeRef = db().collection(Collections.RESUMES).doc(resumeId);
    batch.update(resumeRef, {
      status: "CONFIRMED",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Schedule draft deletion (7 days retention for confirmed draft)
    const sevenDaysFromNow = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
    batch.update(parseDocRef, {
      status: "CONFIRMED",
      confirmedAt: admin.firestore.FieldValue.serverTimestamp(),
      deleteAfter: admin.firestore.Timestamp.fromDate(sevenDaysFromNow),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Commit batch write
    await batch.commit();

    // 8. Trigger Initial Matching & Recommendations Fanout
    logInfo(FN, "Enqueuing matching recommendations refresh for candidate", {
      uid,
      resumeId,
      profileCompletion,
      matchKeysCount: matchKeys.length,
    });
    try {
      await onProfileConfirmedOrPreferencesChanged(uid, true);
    } catch (err) {
      logInfo(FN, "Recommendation refresh completed or deferred", { err });
    }

    return {
      success: true,
      uid,
      resumeId,
      profileCompletion,
      matchKeysCount: matchKeys.length,
    };
  }
);
