import baseConfig from '../playwright.config';
import { deepMerge } from '../lib/util';
import { defineConfig } from '@playwright/test';

/**
 * Perf / Lighthouse harnesses (performanceBaseline, lighthouseBudget) are
 * opt-in via PERF=1 so they do not run in the default CI e2e suite.
 * See docs/e2e/e2e-checks.md ("Performance baselines").
 */
const perfOptIn = process.env.PERF === '1';

export default defineConfig(
  deepMerge(baseConfig, {
    use: {
      baseURL: baseConfig.use.baseURL || 'http://localhost:3000',
    },
    testIgnore: perfOptIn ? [] : ['**/performanceBaseline.spec.ts', '**/lighthouseBudget.spec.ts'],
  })
);
