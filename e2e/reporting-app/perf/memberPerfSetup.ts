import { Page } from '@playwright/test';

import { EmailService } from '../../lib/services/email/EmailService';
import { AccountCreationFlow } from '../flows';
import { CertificationRequestPage } from '../pages';
import { DashboardPage } from '../pages/members/DashboardPage';

export type BaselineTarget = {
  name: string;
  url: string;
};

const DEFAULT_PASSWORD = 'testPassword';

/**
 * Creates a new member account and signs in (skips MFA), matching the path used
 * by other member e2e specs. Shared by Track A (baseline) and Track B (Lighthouse).
 */
export async function signInAsNewMember(page: Page, emailService: EmailService): Promise<void> {
  const email = emailService.generateEmailAddress(emailService.generateUsername());

  const certPage = await new CertificationRequestPage(page).go();
  await certPage.fillAndSubmit(email);

  const signInPage = await new AccountCreationFlow(page, emailService).run(email, DEFAULT_PASSWORD);
  const mfaPreferencePage = await signInPage.signIn(email, DEFAULT_PASSWORD);
  await mfaPreferencePage.skipMFA();
}

/**
 * Walks dashboard → exemption screener once and returns stable GET-restorable URLs.
 * Multi-step form pages are intentionally omitted (direct URL navigation can redirect).
 */
export async function captureDashboardAndScreenerTargets(page: Page): Promise<{
  dashboard: BaselineTarget;
  screener: BaselineTarget;
}> {
  const dashboardPage = await new DashboardPage(page).go();
  const dashboard = { name: 'Dashboard', url: page.url() };

  await dashboardPage.clickGetStarted();
  const screener = { name: 'Exemption screener (index)', url: page.url() };

  return { dashboard, screener };
}

/** Targets used by the Track A baseline harness (sign-in + authenticated pages). */
export async function collectBaselineTargets(page: Page): Promise<BaselineTarget[]> {
  const { dashboard, screener } = await captureDashboardAndScreenerTargets(page);
  const signIn: BaselineTarget = {
    name: 'Sign in',
    url: new URL('/users/sign_in', page.url()).toString(),
  };
  return [signIn, dashboard, screener];
}
