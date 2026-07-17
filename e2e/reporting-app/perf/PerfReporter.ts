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

  private outDir(): string {
    return process.env.PERF_OUT_DIR ?? path.resolve(__dirname, '../../perf-results');
  }

  /** Write both perf-baseline.json and perf-baseline.md. Returns the directory. */
  flush(): string {
    const dir = this.outDir();
    fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(
      path.join(dir, 'perf-baseline.json'),
      JSON.stringify(this.measurements, null, 2)
    );
    fs.writeFileSync(path.join(dir, 'perf-baseline.md'), this.toMarkdown());
    return dir;
  }

  private toMarkdown(): string {
    const header = [
      '# Client-facing performance baseline',
      '',
      'Transfer sizes are bytes over the wire (cold cache). Timings in milliseconds.',
      '',
      '| Page | Profile | Transfer (KB) | Requests | JS (KB) | CSS (KB) | Img (KB) | TTFB | FCP | LCP | Load |',
      '| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |',
    ];
    const rows = this.measurements.map((m) => {
      const kb = (n: number) => (n / KB).toFixed(1);
      return `| ${m.page} | ${m.profile} | ${kb(m.transferBytes)} | ${m.requestCount} | ${kb(m.resourceBytes.script)} | ${kb(m.resourceBytes.stylesheet)} | ${kb(m.resourceBytes.image)} | ${m.ttfbMs} | ${m.fcpMs} | ${m.lcpMs} | ${m.loadMs} |`;
    });
    return [...header, ...rows, ''].join('\n');
  }
}
