/**
 * Network throttling profiles for performance baselining.
 *
 * Values mirror the Chrome DevTools "Slow 3G" / "Fast 3G" presets exactly
 * (see Chromium `NetworkManager` throttling constants), so numbers collected
 * here match what a developer sees via DevTools → Network → throttling, which
 * is the manual workflow referenced in the ticket.
 *
 * Throughput is expressed in bytes/second (CDP `Network.emulateNetworkConditions`
 * expects bytes/s); latency is round-trip time in milliseconds.
 */
export interface NetworkProfile {
  readonly name: string;
  /** Round-trip latency in milliseconds. */
  readonly latencyMs: number;
  /** Download throughput in bytes/second (-1 = unthrottled). */
  readonly downloadBps: number;
  /** Upload throughput in bytes/second (-1 = unthrottled). */
  readonly uploadBps: number;
}

// Chrome DevTools "Slow 3G": 500 kbit/s * 0.8, RTT 400ms * 5.
export const SLOW_3G: NetworkProfile = {
  name: 'Slow 3G',
  latencyMs: 400 * 5,
  downloadBps: ((500 * 1000) / 8) * 0.8,
  uploadBps: ((500 * 1000) / 8) * 0.8,
};

// Chrome DevTools "Fast 3G": 1.6 Mbit/s down * 0.9 / 750 kbit/s up * 0.9, RTT 150ms * 3.75.
export const FAST_3G: NetworkProfile = {
  name: 'Fast 3G',
  latencyMs: 150 * 3.75,
  downloadBps: ((1.6 * 1000 * 1000) / 8) * 0.9,
  uploadBps: ((750 * 1000) / 8) * 0.9,
};

// Control run with no throttling, for comparison against the 3G numbers.
export const UNTHROTTLED: NetworkProfile = {
  name: 'Unthrottled',
  latencyMs: 0,
  downloadBps: -1,
  uploadBps: -1,
};

/**
 * Profiles measured by the baseline spec. Override via the PERF_PROFILES env
 * var (comma-separated names) to run a subset, e.g. PERF_PROFILES="Slow 3G".
 */
export function selectedProfiles(): NetworkProfile[] {
  const all = [SLOW_3G, FAST_3G, UNTHROTTLED];
  const requested = process.env.PERF_PROFILES?.split(',').map((s) => s.trim().toLowerCase());
  if (!requested || requested.length === 0) {
    return all;
  }
  return all.filter((p) => requested.includes(p.name.toLowerCase()));
}
