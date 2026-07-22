import baseConfig from '../playwright.config';
import { deepMerge } from '../lib/util';
import { defineConfig } from '@playwright/test';

/**
 * Perf / Lighthouse harnesses are **opt-in** via PERF=1 and are ignored otherwise
 * (`performanceBaseline`, `performanceBaselineFlow`, `lighthouseBudget`).
 * Default `make e2e-test` / CI must NOT set PERF=1 — flow baselines are very slow.
 * See docs/e2e/e2e-checks.md ("Performance baselines").
 */
const perfOptIn = process.env.PERF === '1';

export default defineConfig(
  deepMerge(baseConfig, {
    use: {
      baseURL: baseConfig.use.baseURL || 'http://localhost:3000',
    },
    testIgnore: perfOptIn
      ? []
      : [
          '**/performanceBaseline.spec.ts',
          '**/performanceBaselineFlow.spec.ts',
          '**/lighthouseBudget.spec.ts',
        ],
  })
);
