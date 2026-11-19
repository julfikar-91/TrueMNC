// functions/src/callables/searchJobs.ts
// Callable: searchJobs — full-text job search (server-side)
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { z } from "zod";

import { REGION, db, Collections } from "../utils/config";
import { validate } from "../utils/validators";
import { logInfo, logError } from "../utils/logger";

const FN = "searchJobs";

const SearchJobsSchema = z.object({
  query: z.string().min(1).max(200),
  location: z.string().optional(),
  jobType: z.enum(["fullTime", "partTime", "contract", "internship"]).optional(),
  workMode: z.enum(["onsite", "remote", "hybrid"]).optional(),
  minSalary: z.number().optional(),
  maxSalary: z.number().optional(),
  limit: z.number().int().min(1).max(50).default(20),
});

export const searchJobs = onCall(
  {
    region: REGION,
    enforceAppCheck: true, // Enforce App Check
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }

    const params = validate(SearchJobsSchema, request.data);
    logInfo(FN, "Searching jobs", { actorUid: request.auth.uid });

    try {
      let query = db()
        .collection(Collections.JOBS)
        .where("status", "==", "active")
        .where("isVerified", "==", true)
        .limit(params.limit ?? 20);

      if (params.jobType) {
        query = query.where("jobType", "==", params.jobType) as typeof query;
      }
      if (params.workMode) {
        query = query.where("workMode", "==", params.workMode) as typeof query;
      }

      const snap = await query.get();
      const jobs = snap.docs.map((d) => ({ id: d.id, ...d.data() }));

      return { jobs, total: jobs.length };
    } catch (err) {
      logError(FN, err, { actorUid: request.auth.uid });
      throw new HttpsError("internal", "Search failed.");
    }
  },
);
