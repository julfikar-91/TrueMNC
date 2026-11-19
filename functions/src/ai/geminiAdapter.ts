// functions/src/ai/geminiAdapter.ts
// Server-side only Gemini API integration.
// NEVER called from Flutter client — always via Cloud Function.
import { GEMINI_MODEL } from "../utils/config";
import { logInfo, logError } from "../utils/logger";

const FN = "geminiAdapter";

export interface GeminiScoreResult {
  score: number;         // 0.0 – 1.0
  reasoning: string;
  keyMatches: string[];
  gaps: string[];
}

/**
 * Score a resume against a job description using Gemini.
 * Returns a normalised match score and reasoning.
 * AI score is advisory only — it NEVER sets verification status.
 */
export async function geminiScoreMatch(
  resumeText: string,
  jobDescription: string,
): Promise<GeminiScoreResult> {
  logInfo(FN, "Calling Gemini for match scoring", { model: GEMINI_MODEL });

  // TODO: Implement using @google/generative-ai SDK
  // const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY!);
  // const model = genAI.getGenerativeModel({ model: GEMINI_MODEL });
  // const prompt = buildScoringPrompt(resumeText, jobDescription);
  // const result = await model.generateContent(prompt);
  // return parseGeminiResponse(result.response.text());

  // Placeholder until SDK is wired:
  logError(FN, "Gemini adapter not yet implemented — returning placeholder.");
  return {
    score: 0,
    reasoning: "Not implemented",
    keyMatches: [],
    gaps: [],
  };
}
