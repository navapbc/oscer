import { test } from '../../fixtures';
import { AccountCreationFlow } from '../flows';
import { CertificationRequestPage } from '../pages';
import { DashboardPage } from '../pages/members/DashboardPage';
import { PerfCollector, PerfReporter, selectedProfiles } from '../perf';

/**
 * Captures client-facing performance baselines (transfer size, request count,
 * paint/timing metrics) for the member-facing critical path under throttled
 * network profiles. Supports the "frontier / limited connectivity" work
 * (github.com/navapbc/oscer/issues/747): establishes the numbers a performance
 * budget is set against.
 *
 * Run a subset of profiles with PERF_PROFILES (e.g. PERF_PROFILES="Slow 3G").
 * Results are written to e2e/perf-results/ (perf-baseline.json + .md).
 */
test('capture client-facing performance baselines under throttled networks', async ({
  page,
  emailService,
}) => {
  // Slow 3G adds ~2s latency per request; the full sweep needs a long budget.
  test.setTimeout(10 * 60 * 1000);

  const email = emailService.generateEmailAddress(emailService.generateUsername());
  const password = 'testPassword';

  // --- Reach an authenticated session (mirrors the exemption spec) ---
  const certPage = await new CertificationRequestPage(page).go();
  await certPage.fillAndSubmit(email);

  const signInPage = await new AccountCreationFlow(page, emailService).run(email, password);
  const mfaPreferencePage = await signInPage.signIn(email, password);
  await mfaPreferencePage.skipMFA();

  // --- Walk the flow once to capture stable URLs of the pages we baseline ---
  // Only pages that are reliably restorable by a plain GET are re-measured in
  // the profile loop below (each iteration re-navigates by URL). Multi-step
  // form pages (screener questions, activity-report steps) are NOT included:
  // navigating straight to their URL can redirect and silently mis-measure.
  // To baseline those, extend the walk to re-drive the flow per profile.
  const targets: { name: string; url: string }[] = [];

  const dashboard = await new DashboardPage(page).go();
  targets.push({ name: 'Dashboard', url: page.url() });

  await dashboard.clickGetStarted();
  targets.push({ name: 'Exemption screener (index)', url: page.url() });

  // The sign-in page is public but part of the member entry path — baseline it too.
  targets.unshift({ name: 'Sign in', url: new URL('/users/sign_in', page.url()).toString() });

  // --- Measure every target under every selected network profile ---
  const reporter = new PerfReporter();
  for (const profile of selectedProfiles()) {
    const collector = new PerfCollector(page);
    await collector.start(profile);
    for (const target of targets) {
      await page.goto(target.url);
      const measurement = await collector.measure(target.name);
      measurement.profile = profile.name;
      reporter.add(measurement);
    }
    await collector.stop();
  }

  const dir = reporter.flush();
  // eslint-disable-next-line no-console
  console.log(`\nPerformance baseline written to ${dir}\n`);
});
