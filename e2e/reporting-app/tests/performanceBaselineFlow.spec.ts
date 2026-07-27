import { expect } from '@playwright/test';

import { test } from '../../fixtures';
import {
  PerfCollector,
  PerfReporter,
  runAllNoScreenerActivitiesFlow,
  runMedicalExemptionYesFlow,
  selectedProfiles,
  signInAsNewMember,
} from '../perf';

/**
 * Multi-step flow performance baselines under throttled networks (OSCER-747).
 *
 * ⚠️  LONG-RUNNING — NOT FOR CI / DEFAULT `make e2e-test`
 * ---------------------------------------------------------------------------
 * These tests walk full member flows under Slow/Fast 3G and Unthrottled.
 * Expect **tens of minutes to ~1+ hour** for all profiles (90m timeout).
 * Prefer `PERF_PROFILES="Slow 3G"` (or a single profile) for a shorter run.
 *
 * They are **excluded from the default Playwright suite and CI** unless you
 * explicitly set `PERF=1`. Do not enable PERF in GitHub Actions e2e workflows.
 *
 * Two flows (separate tests; fresh member + all selected profiles each).
 * Make runs with `--workers=1`; each profile clears cookies before signup.
 * 1. Match manual walk: No through screener → 2 hours activities + docs →
 *    1 income + doc → submit (classic upload, not DocAI).
 * 2. Medical exemption Yes + regular document upload → submit.
 *
 * Run locally only:
 *   make e2e-perf-baseline-flow APP_NAME=reporting-app
 *   PERF_PROFILES="Slow 3G" make e2e-perf-baseline-flow APP_NAME=reporting-app
 *
 * Writes e2e/perf-results/perf-baseline-flow-*.json/.md
 */

const FLOW_TIMEOUT_MS = 90 * 60 * 1000;

test.describe('performance baseline flows', () => {
  test.beforeEach(({}, testInfo) => {
    test.skip(
      testInfo.project.name !== 'chromium',
      'Perf flow baselines run on the chromium project only (set PERF=1).'
    );
  });

  test('all-No screener + hours/income activities with supporting docs', async ({
    page,
    emailService,
  }) => {
    test.setTimeout(FLOW_TIMEOUT_MS);

    const profiles = selectedProfiles();
    const reporter = new PerfReporter();

    for (const profile of profiles) {
      await signInAsNewMember(page, emailService);
      const collector = new PerfCollector(page);
      await collector.start(profile);
      const steps = await runAllNoScreenerActivitiesFlow(page, collector, profile);
      for (const step of steps) {
        reporter.add(step);
      }
      await collector.stop();
    }

    expect(reporter.size).toBeGreaterThan(0);
    const dir = reporter.flush('perf-baseline-flow-activities');
    // eslint-disable-next-line no-console
    console.log(`\nFlow baseline (activities) written to ${dir}\n`);
  });

  test('medical exemption Yes + regular document upload', async ({ page, emailService }) => {
    test.setTimeout(FLOW_TIMEOUT_MS);

    const profiles = selectedProfiles();
    const reporter = new PerfReporter();

    for (const profile of profiles) {
      await signInAsNewMember(page, emailService);
      const collector = new PerfCollector(page);
      await collector.start(profile);
      const steps = await runMedicalExemptionYesFlow(page, collector, profile);
      for (const step of steps) {
        reporter.add(step);
      }
      await collector.stop();
    }

    expect(reporter.size).toBeGreaterThan(0);
    const dir = reporter.flush('perf-baseline-flow-exemption');
    // eslint-disable-next-line no-console
    console.log(`\nFlow baseline (exemption) written to ${dir}\n`);
  });
});
