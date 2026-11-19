// functions/src/adapters/registry.ts
import { JobAdapter } from "./types";
import { GreenhouseAdapter } from "./greenhouse";
import { LeverAdapter } from "./lever";
import { SmartRecruitersAdapter } from "./smartrecruiters";
import { CareersPageAdapter } from "./careersPage";

const adapters = new Map<string, JobAdapter>();

export function registerAdapter(type: string, adapter: JobAdapter): void {
  adapters.set(type.toUpperCase(), adapter);
}

export function getAdapter(type: string): JobAdapter {
  const normalised = type.toUpperCase();
  const adapter = adapters.get(normalised);
  if (!adapter) {
    throw new Error(`Unsupported or unrecognised job adapter type: "${type}"`);
  }
  return adapter;
}

// Initialise default adapters
registerAdapter("GREENHOUSE", new GreenhouseAdapter());
registerAdapter("LEVER", new LeverAdapter());
registerAdapter("SMARTRECRUITERS", new SmartRecruitersAdapter());
registerAdapter("CAREERS_PAGE", new CareersPageAdapter());
registerAdapter("OFFICIAL_FEED", new CareersPageAdapter());
