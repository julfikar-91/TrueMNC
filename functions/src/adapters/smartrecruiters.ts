// functions/src/adapters/smartrecruiters.ts
import { JobAdapter, RawJob, SourceDoc } from "./types";

export class SmartRecruitersAdapter implements JobAdapter {
  async fetchJobs(source: SourceDoc): Promise<RawJob[]> {
    throw new Error(
      `NOT_IMPLEMENTED: SmartRecruiters adapter for source ${source.id} is not yet implemented.`,
    );
  }
}
