// functions/src/callables/parseSearchQuery.ts
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { z } from "zod";

import { REGION } from "../utils/config";
import { validate } from "../utils/validators";
import { parseSearchQuery } from "../ai/parseSearchQuery";
import { geminiApiKey } from "../ai/extractJob";

const ParseSearchQueryInputSchema = z.object({
  query: z.string().max(300, "Query cannot exceed 300 characters"),
});

export const parseSearchQueryCallable = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
    secrets: [geminiApiKey],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required for AI search.");
    }

    const { query } = validate(ParseSearchQueryInputSchema, request.data);
    const uid = request.auth.uid;

    return await parseSearchQuery(query, uid);
  }
);
