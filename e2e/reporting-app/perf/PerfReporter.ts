import fs from 'fs';
import path from 'path';

import { PageMeasurement } from './PerfCollector';

const KB = 1024;

/**
 * Accumulates page measurements across profiles and writes a machine-readable
 * JSON file plus a human-readable markdown table (paste-ready for the ticket).
 *
 * Output goes to e2e/perf-results/ by default; override with PERF_OUT_DIR.
 */
export class PerfReporter {
  private readonly measurements: PageMeasurement[] = [];

  add(measurement: PageMeasurement): void {
    this.measurements.push(measurement);
  }

  get size(): number {
    return this.measurements.length;
  }

  private outDir(): string {
    // Make often exports PERF_OUT_DIR="" when unset; treat blank like missing.
    const fromEnv = process.env.PERF_OUT_DIR?.trim();
    return fromEnv || path.resolve(__dirname, '../../perf-results');
  }

  /**
   * Write JSON + markdown. `basename` defaults to `perf-baseline`
   * (e.g. pass `perf-baseline-flow` for multi-step flow runs).
   */
  flush(basename = 'perf-baseline'): string {
    const dir = this.outDir();
    fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(
      path.join(dir, `${basename}.json`),
      JSON.stringify(this.measurements, null, 2)
    );
    fs.writeFileSync(path.join(dir, `${basename}.md`), this.toMarkdown(basename));
    return dir;
  }

  private toMarkdown(basename: string): string {
    const hasStep = this.measurements.some((m) => m.stepDurationMs != null);
    const header = [
      `# Client-facing performance baseline (${basename})`,
      '',
      'Transfer sizes are bytes over the wire (cold cache). Timings in milliseconds.',
      hasStep ? 'Step (ms) is wall-clock for measured actions (navigations / uploads).' : '',
      '',
      hasStep
        ? '| Page | Profile | Transfer (KB) | Requests | JS (KB) | CSS (KB) | Img (KB) | TTFB | FCP | LCP | Load | Step |'
        : '| Page | Profile | Transfer (KB) | Requests | JS (KB) | CSS (KB) | Img (KB) | TTFB | FCP | LCP | Load |',
      hasStep
        ? '| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |'
        : '| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |',
    ].filter((line) => line !== undefined);

    const rows = this.measurements.map((m) => {
      const kb = (n: number) => (n / KB).toFixed(1);
      const base = `| ${m.page} | ${m.profile} | ${kb(m.transferBytes)} | ${m.requestCount} | ${kb(m.resourceBytes.script)} | ${kb(m.resourceBytes.stylesheet)} | ${kb(m.resourceBytes.image)} | ${m.ttfbMs} | ${m.fcpMs} | ${m.lcpMs} | ${m.loadMs}`;
      return hasStep ? `${base} | ${m.stepDurationMs ?? ''} |` : `${base} |`;
    });
    return [...header, ...rows, ''].join('\n');
  }
}
