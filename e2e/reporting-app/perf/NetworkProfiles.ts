/**
 * Network throttling profiles for performance baselining.
 *
 * Values mirror the Chrome DevTools "Slow 3G" / "Fast 3G" presets exactly
 * (see Chromium `NetworkManager` throttling constants), so numbers collected
 * via CDP (Track A) match what a developer sees via DevTools → Network →
 * throttling, which is the manual workflow referenced in the ticket.
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

export const ALL_PROFILES: readonly NetworkProfile[] = [SLOW_3G, FAST_3G, UNTHROTTLED];

/**
 * Lighthouse `settings.throttling` approximating Slow 3G bandwidth/latency for
 * `throttlingMethod: 'simulate'`.
 *
 * Lighthouse simulation is **not** the same as CDP `Network.emulateNetworkConditions`
 * (Track A). Timings are not 1:1 comparable across tracks; use Track A for
 * DevTools-parity baselines and Track B for Lighthouse scores/budgets.
 */
export function lighthouseSlow3gSimulatedThrottling() {
  const downloadThroughputKbps = (SLOW_3G.downloadBps * 8) / 1000;
  const uploadThroughputKbps = (SLOW_3G.uploadBps * 8) / 1000;
  return {
    rttMs: SLOW_3G.latencyMs,
    throughputKbps: downloadThroughputKbps,
    // Lighthouse simulate applies an extra latency multiplier on requests.
    requestLatencyMs: SLOW_3G.latencyMs * 3.75,
    downloadThroughputKbps: downloadThroughputKbps * 0.9,
    uploadThroughputKbps: uploadThroughputKbps * 0.9,
    cpuSlowdownMultiplier: 4,
  };
}

/**
 * Profiles measured by the baseline spec. Override via the PERF_PROFILES env
 * var (comma-separated names) to run a subset, e.g. PERF_PROFILES="Slow 3G".
 *
 * Throws if PERF_PROFILES is set but empty after parsing, or if any name is unknown.
 */
export function selectedProfiles(): NetworkProfile[] {
  const raw = process.env.PERF_PROFILES;
  if (raw === undefined || raw.trim() === '') {
    return [...ALL_PROFILES];
  }

  const requested = raw
    .split(',')
    .map((s) => s.trim().toLowerCase())
    .filter((s) => s.length > 0);

  if (requested.length === 0) {
    throw new Error(
      'PERF_PROFILES is set but empty after parsing. Unset it to use all profiles, or pass names like "Slow 3G,Fast 3G".'
    );
  }

  const unknown = requested.filter(
    (name) => !ALL_PROFILES.some((p) => p.name.toLowerCase() === name)
  );
  if (unknown.length > 0) {
    const valid = ALL_PROFILES.map((p) => p.name).join(', ');
    throw new Error(`Unknown PERF_PROFILES value(s): ${unknown.join(', ')}. Valid: ${valid}`);
  }

  return ALL_PROFILES.filter((p) => requested.includes(p.name.toLowerCase()));
}
