import fs from 'fs';
import path from 'path';

import type { Config } from 'lighthouse';
import { playAudit } from 'playwright-lighthouse';

import { test } from '../../fixtures';
import {
  captureDashboardAndScreenerTargets,
  lighthouseSlow3gSimulatedThrottling,
  signInAsNewMember,
} from '../perf';

/**
 * Runs Lighthouse against authenticated member pages. Supports the
 * "frontier / limited connectivity" work (issue #747).
 *
 * Opt-in only — excluded from the default e2e suite unless PERF=1:
 *   make e2e-perf-lighthouse APP_NAME=reporting-app
 *
 * By default this is **capture-first**: HTML/JSON reports are written under
 * e2e/perf-results/lighthouse/ without failing on placeholder budgets or
 * category-score floors. Set PERF_ENFORCE_BUDGET=1 to enforce budget.json and
 * score thresholds after baselines are calibrated.
 *
 * Lighthouse attaches to Playwright Chromium over CDP (fixed port below).
 * Run with workers=1 / a single project so the port does not clash.
 */

const LH_PORT = 9222;

test.use({ launchOptions: { args: [`--remote-debugging-port=${LH_PORT}`] } });

const budgets = JSON.parse(
  fs.readFileSync(path.resolve(__dirname, '../lighthouse/budget.json'), 'utf-8')
);

const enforceBudget = process.env.PERF_ENFORCE_BUDGET === '1';

test('member pages meet the performance budget under 3G', async ({
  page,
  emailService,
}, testInfo) => {
  test.skip(
    testInfo.project.name !== 'chromium',
    'Lighthouse requires a single Chromium CDP port; skip other projects.'
  );

  test.setTimeout(10 * 60 * 1000);

  await signInAsNewMember(page, emailService);

  const { dashboard, screener } = await captureDashboardAndScreenerTargets(page);
  const targets = [
    { name: 'dashboard', url: dashboard.url },
    { name: 'exemption-screener-index', url: screener.url },
  ];

  // `budgets` is a valid runtime lighthouse setting (settings.budgets) but is
  // absent from lighthouse's exported Config types, so cast the settings object.
  // Track B uses Lighthouse *simulate* throttling derived from Slow 3G constants;
  // it is not identical to CDP Network.emulateNetworkConditions (Track A).
  const lighthouseConfig: Config = {
    extends: 'lighthouse:default',
    settings: {
      formFactor: 'mobile',
      onlyCategories: ['performance', 'accessibility'],
      throttlingMethod: 'simulate',
      throttling: lighthouseSlow3gSimulatedThrottling(),
      ...(enforceBudget ? { budgets } : {}),
    } as Config['settings'],
  };

  for (const target of targets) {
    await page.goto(target.url);
    await playAudit({
      page,
      port: LH_PORT,
      // Soft floors unless PERF_ENFORCE_BUDGET=1 (capture-first workflow).
      thresholds: enforceBudget
        ? { performance: 50, accessibility: 90 }
        : { performance: 0, accessibility: 0 },
      config: lighthouseConfig,
      reports: {
        formats: { html: true, json: true },
        name: `lighthouse-${target.name}`,
        directory: path.resolve(__dirname, '../../perf-results/lighthouse'),
      },
    });
  }
});
