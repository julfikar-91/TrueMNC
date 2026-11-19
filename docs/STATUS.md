# True Corporate Job Finder — Project Status

## Done (Days 1–4 Complete)
- **Day 1**: Core architecture, Freezed models, Firebase Auth, claims, security rules.
- **Day 2**: Admin console (A02-A05), SuperAdmin management (A15-A17), audit logs, seed scripts.
- **Day 3**: Collection pipeline (`asia-south1`), Greenhouse adapter, rules R1–R8, Gemini extraction, 13 admin callables, admin screens A06–A10, S22.
- **Day 4 Backend**: Resume pipeline in `/functions`:
  - `resumeSchema.ts`: Zod schema tracking value, provenance (`EXPLICIT`/`INFERRED`/`MISSING`), evidence, confidence.
  - `extractResume.ts`: Gemini parser reading model from `config/app`, 60s timeout, prompt-injection defense, 1 repair attempt, telemetry in `aiLogs` (zero PII).
  - `postProcess.ts`: Magic bytes (PDF/DOCX), <5MB, <=10 pages, encrypted check, format validators, evidence fuzzy matching, `normaliseSkill()`, status `PARSED`/`PARTIAL`.
  - Callables: `parseResume` (7 progress stages, 3/day rate limit), `confirmProfile` (subcollections with `confirmed: true`, 100 pt completion formula, `matchKeys`), `deleteResume`.
  - Unit tests: 17/17 tests passing (`npm run test:resume`).
- **Day 4 Frontend**: Candidate resume & profile screens:
  - `ResumeRepository`: Resumable upload, zero download URL exposed, doc watchers, callables.
  - S08 Onboarding (`/resume-onboarding`): Headline, upload resume, manual profile stub, skip, privacy note.
  - S09 Upload (`/resume-upload`): File picker (<5MB, PDF/DOCX), progress bar, error handling.
  - S10 Processing (`/resume-processing`): 7 stages driven strictly by server `resumes/{id}.progress`.
  - S11 Preview (`/profile-preview`): Provenance badges, inferred checkmarks, fresher choice (never auto-marked).
  - Router: Table-driven redirect rows 4–7 wired, 125/125 Flutter tests passing.

## Stubbed
- **Adapters**: `lever.ts`, `smartrecruiters.ts`, `careersPage.ts` (JSON-LD + robots.txt).
- **Matching Pipeline**: Initial matching trigger enqueued after profile confirmation (Day 5).

## Known Issues
- Sandbox file path locks on Windows during test execution (run unsandboxed).

## Next Step (Day 5)
- Candidate job discovery, search, match scoring calculation, and job detail views.
