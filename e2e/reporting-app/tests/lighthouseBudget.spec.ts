import fs from 'fs';
import path from 'path';

import type { Config } from 'lighthouse';
import { playAudit } from 'playwright-lighthouse';

import { test } from '../../fixtures';
import { AccountCreationFlow } from '../flows';
import { CertificationRequestPage } from '../pages';
import { DashboardPage } from '../pages/members/DashboardPage';

/**
 * Runs Lighthouse against the authenticated member pages and enforces a
 * performance budget (e2e/reporting-app/lighthouse/budget.json). Supports the
 * "frontier / limited connectivity" work (issue #747): AC "meet a defined
 * performance budget".
 *
 * Lighthouse attaches to the Playwright-controlled Chromium over CDP, so
 * Playwright owns authentication (one login path) and Lighthouse reuses the
 * session cookies. The browser must expose a remote debugging port — set below.
 *
 * NOTE: run this file on its own (workers=1) so the fixed CDP port does not
 * clash with parallel workers:
 *   make e2e-test-native APP_NAME=reporting-app \
 *     E2E_ARGS=reporting-app/tests/lighthouseBudget.spec.ts
 */

const LH_PORT = 9222;

test.use({ launchOptions: { args: [`--remote-debugging-port=${LH_PORT}`] } });

const budgets = JSON.parse(
  fs.readFileSync(path.resolve(__dirname, '../lighthouse/budget.json'), 'utf-8')
);

// Simulated Slow-3G-ish mobile throttling (matches the Track A "Slow 3G" intent).
const THROTTLING = {
  rttMs: 400,
  throughputKbps: 400,
  requestLatencyMs: 400 * 3.75,
  downloadThroughputKbps: 400 * 0.9,
  uploadThroughputKbps: 400 * 0.9,
  cpuSlowdownMultiplier: 4,
};

test('member pages meet the performance budget under 3G', async ({ page, emailService }) => {
  test.setTimeout(10 * 60 * 1000);

  const email = emailService.generateEmailAddress(emailService.generateUsername());
  const password = 'testPassword';

  // Authenticate (same path as the other member specs).
  const certPage = await new CertificationRequestPage(page).go();
  await certPage.fillAndSubmit(email);
  const signInPage = await new AccountCreationFlow(page, emailService).run(email, password);
  const mfaPreferencePage = await signInPage.signIn(email, password);
  await mfaPreferencePage.skipMFA();

  // Reach the pages to audit and capture their URLs (capture before navigating on).
  const dashboard = await new DashboardPage(page).go();
  const dashboardUrl = page.url();
  await dashboard.clickGetStarted();
  const screenerUrl = page.url();

  const targets = [
    { name: 'dashboard', url: dashboardUrl },
    { name: 'exemption-screener-index', url: screenerUrl },
  ];

  // `budgets` is a valid runtime lighthouse setting (settings.budgets) but is
  // absent from lighthouse's exported Config types, so cast the settings object.
  const lighthouseConfig: Config = {
    extends: 'lighthouse:default',
    settings: {
      formFactor: 'mobile',
      onlyCategories: ['performance', 'accessibility'],
      throttlingMethod: 'simulate',
      throttling: THROTTLING,
      budgets,
    } as Config['settings'],
  };

  for (const target of targets) {
    await page.goto(target.url);
    await playAudit({
      page,
      port: LH_PORT,
      // Category-score floors; budget.json enforces size/timing budgets.
      thresholds: { performance: 50, accessibility: 90 },
      config: lighthouseConfig,
      reports: {
        formats: { html: true, json: true },
        name: `lighthouse-${target.name}`,
        directory: path.resolve(__dirname, '../../perf-results/lighthouse'),
      },
    });
  }
});
