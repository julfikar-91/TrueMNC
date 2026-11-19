// functions/src/adapters/types.ts

export interface RawJob {
  sourceJobId: string;
  title: string;
  description: string;
  applyUrl: string;
  location?: string | null;
  remote?: boolean | null;
  postedAt?: Date | null;
  deadline?: Date | null;
  department?: string | null;
  employmentType?: string | null;
  raw?: unknown;
}

export interface SourceDoc {
  id: string;
  companyId: string;
  type: string; // 'GREENHOUSE' | 'LEVER' | 'SMARTRECRUITERS' | 'OFFICIAL_FEED' | 'CAREERS_PAGE'
  url: string;
  enabled: boolean;
  config?: {
    boardToken?: string;
    approvedAtsHost?: string;
    apiBaseUrl?: string;
    [key: string]: unknown;
  };
  secretRef?: string | null;
  intervalMin?: number;
  nextRun?: any;
  lastRun?: any;
  consecutiveFailures?: number;
  needsAttention?: boolean;
}

export interface JobAdapter {
  fetchJobs(source: SourceDoc): Promise<RawJob[]>;
}
