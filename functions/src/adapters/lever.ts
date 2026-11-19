// functions/src/adapters/lever.ts
import { JobAdapter, RawJob, SourceDoc } from "./types";

export class LeverAdapter implements JobAdapter {
  async fetchJobs(source: SourceDoc): Promise<RawJob[]> {
    throw new Error(
      `NOT_IMPLEMENTED: Lever adapter for source ${source.id} is not yet implemented.`,
    );
  }
}
