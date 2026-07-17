import { CDPSession, Page } from '@playwright/test';

import { NetworkProfile } from './NetworkProfiles';

/**
 * Per-resource-type transfer sizes (bytes over the wire) and request counts for
 * a single measured page load.
 */
export interface ResourceBreakdown {
  document: number;
  stylesheet: number;
  script: number;
  image: number;
  font: number;
  other: number;
}

export interface PageMeasurement {
  page: string;
  url: string;
  profile: string;
  /** Total bytes transferred over the wire (sum of encodedDataLength). */
  transferBytes: number;
  requestCount: number;
  resourceBytes: ResourceBreakdown;
  /** Time to first byte (ms), from Navigation Timing. */
  ttfbMs: number;
  /** First Contentful Paint (ms). */
  fcpMs: number;
  /** Largest Contentful Paint (ms); 0 if not observed. */
  lcpMs: number;
  /** DOMContentLoaded (ms). */
  domContentLoadedMs: number;
  /** load event end (ms). */
  loadMs: number;
}

const CDP_TYPE_TO_BUCKET: Record<string, keyof ResourceBreakdown> = {
  Document: 'document',
  Stylesheet: 'stylesheet',
  Script: 'script',
  Image: 'image',
  Font: 'font',
};

// Installed before navigation so LCP is captured with buffered entries.
const LCP_OBSERVER_SCRIPT = `
  window.__perfLcp = 0;
  try {
    new PerformanceObserver((list) => {
      const entries = list.getEntries();
      const last = entries[entries.length - 1];
      if (last) window.__perfLcp = last.renderTime || last.loadTime || last.startTime || 0;
    }).observe({ type: 'largest-contentful-paint', buffered: true });
  } catch (e) {
    // largest-contentful-paint unsupported; leave __perfLcp at 0.
  }
`;

/**
 * Measures transfer size and paint/timing metrics for individual page loads
 * under a throttled network profile, using the Chrome DevTools Protocol.
 *
 * Usage:
 *   const collector = new PerfCollector(page);
 *   await collector.start(SLOW_3G);
 *   const measurement = await collector.measure('dashboard');
 *   await collector.stop();
 *
 * `measure()` reloads the current page under throttling with cache disabled
 * (cold-cache, first-visit worst case), so drive navigation to the target page
 * *before* calling it.
 */
export class PerfCollector {
  private client?: CDPSession;
  private requestTypes = new Map<string, keyof ResourceBreakdown>();
  private resourceBytes: ResourceBreakdown = emptyBreakdown();
  private requestCount = 0;

  constructor(private readonly page: Page) {}

  async start(profile: NetworkProfile): Promise<void> {
    this.client = await this.page.context().newCDPSession(this.page);
    await this.client.send('Network.enable');

    if (profile.downloadBps < 0) {
      await this.client.send('Network.emulateNetworkConditions', {
        offline: false,
        latency: 0,
        downloadThroughput: -1,
        uploadThroughput: -1,
      });
    } else {
      await this.client.send('Network.emulateNetworkConditions', {
        offline: false,
        latency: profile.latencyMs,
        downloadThroughput: profile.downloadBps,
        uploadThroughput: profile.uploadBps,
      });
    }

    // Cold cache: the baseline should reflect a first-time visitor on a slow link.
    await this.client.send('Network.setCacheDisabled', { cacheDisabled: true });

    await this.installByteCounters(this.client);
    await this.page.addInitScript(LCP_OBSERVER_SCRIPT);
  }

  /**
   * Reload the current page under throttling and return its measurement.
   * Navigate to the target page before calling this.
   */
  async measure(pageName: string): Promise<PageMeasurement> {
    this.resetCounters();
    const url = this.page.url();

    await this.page.reload({ waitUntil: 'load' });
    // Let late resources (fonts, lazy assets, LCP candidates) settle.
    await this.page.waitForLoadState('networkidle').catch(() => undefined);

    const timing = await this.page.evaluate(() => {
      const nav = performance.getEntriesByType('navigation')[0] as
        PerformanceNavigationTiming | undefined;
      const fcp = performance
        .getEntriesByType('paint')
        .find((e) => e.name === 'first-contentful-paint');
      return {
        ttfbMs: nav ? Math.round(nav.responseStart) : 0,
        fcpMs: fcp ? Math.round(fcp.startTime) : 0,
        lcpMs: Math.round((window as unknown as { __perfLcp: number }).__perfLcp || 0),
        domContentLoadedMs: nav ? Math.round(nav.domContentLoadedEventEnd) : 0,
        loadMs: nav ? Math.round(nav.loadEventEnd) : 0,
      };
    });

    return {
      page: pageName,
      url,
      profile: '', // set by the caller (spec) which knows the active profile
      transferBytes: sumBreakdown(this.resourceBytes),
      requestCount: this.requestCount,
      resourceBytes: { ...this.resourceBytes },
      ...timing,
    };
  }

  async stop(): Promise<void> {
    await this.client?.detach().catch(() => undefined);
    this.client = undefined;
  }

  private async installByteCounters(client: CDPSession): Promise<void> {
    client.on('Network.responseReceived', (event) => {
      const bucket = CDP_TYPE_TO_BUCKET[event.type] ?? 'other';
      this.requestTypes.set(event.requestId, bucket);
    });
    client.on('Network.loadingFinished', (event) => {
      const bucket = this.requestTypes.get(event.requestId) ?? 'other';
      this.resourceBytes[bucket] += event.encodedDataLength ?? 0;
      this.requestCount += 1;
    });
  }

  private resetCounters(): void {
    this.requestTypes.clear();
    this.resourceBytes = emptyBreakdown();
    this.requestCount = 0;
  }
}

function emptyBreakdown(): ResourceBreakdown {
  return { document: 0, stylesheet: 0, script: 0, image: 0, font: 0, other: 0 };
}

function sumBreakdown(b: ResourceBreakdown): number {
  return b.document + b.stylesheet + b.script + b.image + b.font + b.other;
}
