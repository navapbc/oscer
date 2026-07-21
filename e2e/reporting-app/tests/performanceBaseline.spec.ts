import { expect } from '@playwright/test';

import { test } from '../../fixtures';
import {
  PerfCollector,
  PerfReporter,
  collectBaselineTargets,
  selectedProfiles,
  signInAsNewMember,
} from '../perf';

/**
 * Captures client-facing performance baselines (transfer size, request count,
 * paint/timing metrics) for the member-facing critical path under throttled
 * network profiles. Supports the "frontier / limited connectivity" work
 * (github.com/navapbc/oscer/issues/747): establishes the numbers a performance
 * budget is set against.
 *
 * Opt-in only — excluded from the default e2e suite unless PERF=1:
 *   make e2e-perf-baseline APP_NAME=reporting-app
 *   # or: PERF=1 make e2e-test-native APP_NAME=reporting-app \
 *   #      E2E_ARGS=reporting-app/tests/performanceBaseline.spec.ts
 *
 * Run a subset of profiles with PERF_PROFILES (e.g. PERF_PROFILES="Slow 3G").
 * Results are written to e2e/perf-results/ (perf-baseline.json + .md).
 */
test('capture client-facing performance baselines under throttled networks', async ({
  page,
  emailService,
}, testInfo) => {
  test.skip(
    testInfo.project.name !== 'chromium',
    'Perf baselines run on the chromium project only (set PERF=1).'
  );

  // Slow 3G adds ~2s latency per request; the full sweep needs a long budget.
  test.setTimeout(10 * 60 * 1000);

  await signInAsNewMember(page, emailService);

  // Only pages that are reliably restorable by a plain GET are re-measured in
  // the profile loop below. Multi-step form pages are NOT included.
  const targets = await collectBaselineTargets(page);
  const profiles = selectedProfiles();
  const expectedCount = profiles.length * targets.length;

  const reporter = new PerfReporter();
  for (const profile of profiles) {
    const collector = new PerfCollector(page);
    await collector.start(profile);
    for (const target of targets) {
      reporter.add(await collector.measure(target.name, profile, target.url));
    }
    await collector.stop();
  }

  expect(
    reporter.size,
    `expected ${expectedCount} measurements (${profiles.length} profiles × ${targets.length} pages)`
  ).toBe(expectedCount);

  const dir = reporter.flush();
  // eslint-disable-next-line no-console
  console.log(`\nPerformance baseline written to ${dir}\n`);
});
