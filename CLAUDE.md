# CLAUDE.md — True Corporate Job Finder (TrueMNC)

## Stack & Forbidden Tech
- **Stack**: Flutter + Dart (Material 3), Riverpod, GoRouter, Firebase Auth, Cloud Firestore, Firebase Storage, Cloud Functions Gen 2 (TypeScript in `/functions`, `asia-south1`), FCM, App Check, Gemini API (server-side only).
- **Forbidden**: React, Next.js, Python backend, PostgreSQL, MongoDB, Redis, Supabase, third-party backend, separate web admin.

## 8 Non-Negotiable Principles
1. **Official sources only**: Ingest only official careers pages / verified ATS APIs.
2. **AI never sets verification**: Only deterministic rules R1–R8 and admins set `VERIFIED`/`ACTIVE`.
3. **Server-side trust**: Client never sets roles, verification, scoring, or admin actions.
4. **Honest UI states**: Every screen handles loading, empty, and error states via `AsyncValue`.
5. **Never invent data**: Missing fields stay `null`; provenance tracked.
6. **User confirms AI output**: AI extractions/resumes require human review before saving.
7. **Privacy & zero PII**: No secrets in Flutter; zero PII in AI logs; IP addresses hashed.
8. **Cheap before smart**: Deterministic validation, content hashing, and caching before LLM calls.

## Roles & Security
- **Roles**: `USER`, `ADMIN`, `SUPER_ADMIN` managed strictly via Firebase Auth Custom Claims. Client never writes roles.
- **Admin Callables**: Protected by App Check, `requireRole()`, and immutable audit logging.

## Folder Structure
- `lib/`: `main.dart`, `app.dart`, `core/{theme,router,errors,utils,widgets}`, `data/{models,repositories,services}`, `features/{auth,onboarding,resume,profile,home,search,jobs,companies,recommendations,saved,notifications,settings,reports,admin}`.
- `functions/src/`: `adapters`, `ai`, `callables`, `matching`, `rules`, `tasks`, `triggers`, `utils`.

## Coding Conventions
- **Flutter**: Riverpod for state, GoRouter for navigation & guards, 48dp touch targets, AA contrast, light + dark mode.
- **Data flow**: UI never touches Firestore directly; access exclusively through repository providers.
- **Functions**: TypeScript only, strict schema validation using `zod`, idempotent task handlers.

## Project Status
- **Current**: Day 1 (Auth, Models, Rules), Day 2 (Admin Console, Seed, SuperAdmin), Day 3 (Job Collection Engine, Greenhouse Adapter, Rules R1–R8, Admin Source/Job/Review Screens) completed and tested.
