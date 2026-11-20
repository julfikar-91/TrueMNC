# CLAUDE.md — True Corporate Job Finder (TrueMNC)

## WORK MODE
WORK MODE: Do only the task in the current prompt. Never explore or re-read the whole project.
Never run the full test suite or full analyze unless the prompt says so. Read ONLY files listed in the
prompt's READ list plus /docs/MAP.md. If something else is needed, grep for the exact symbol first.
Do not refactor, re-print, or review code outside the task. Final answer max 8 lines.

## Stack & Forbidden Tech
- **Stack**: Flutter + Dart (M3), Riverpod, GoRouter, Firebase Auth, Firestore, Cloud Functions Gen 2 (TypeScript, asia-south1), Cloud Tasks, FCM, App Check, Gemini API (server only).
- **Forbidden**: React, Next.js, Python backend, PostgreSQL, MongoDB, Redis, Supabase, separate web admin.

## 8 Non-Negotiable Principles
1. **Official sources only**: Ingest only official careers pages / verified ATS APIs.
2. **AI never sets verification**: Only deterministic rules R1-R8 and admins set VERIFIED/ACTIVE.
3. **Server-side trust**: Client never sets roles, verification, scoring, or admin actions.
4. **Honest UI states**: Every screen handles loading, empty, and error states via AsyncValue.
5. **Never invent data**: Missing fields stay null; provenance tracked.
6. **User confirms AI output**: AI extractions/resumes require human review before saving.
7. **Privacy & zero PII**: No secrets in Flutter; zero PII in AI logs; IP addresses hashed.
8. **Cheap before smart**: Deterministic validation, content hashing, and caching before LLM calls.

## Roles & Security
- **Roles**: USER, ADMIN, SUPER_ADMIN managed strictly via Firebase Auth Custom Claims. Client never writes roles.
- **Admin Callables**: Protected by App Check, requireRole(), and immutable audit logging.

## Folder Structure & Conventions
- `lib/`: `core/{theme,router,errors,utils,widgets}`, `data/{models,repositories,services}`, `features/`.
- `functions/src/`: `adapters`, `ai`, `callables`, `matching`, `notifications`, `rules`, `tasks`, `triggers`, `utils`.
- **Conventions**: Repositories only (UI never calls Firestore directly), Riverpod for state, GoRouter for navigation & guards, Zod for functions validation.
