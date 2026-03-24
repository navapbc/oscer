# Flow Class Template

**Location:** `e2e/reporting-app/flows/<Name>Flow.ts`

**When to create:** Use flows only for 5+ sequential page transitions that are reused across multiple tests.

## Full flow class example

```typescript
import { Page } from '@playwright/test';
import { BeforeYouStartPage } from '../pages/members/activity-reports';
import { ChooseMonthsPage } from '../pages/members/activity-reports';
import { ActivityReportPage } from '../pages/members/activity-reports';
import { ActivityTypePage } from '../pages/members/activity-reports';
import { ActivityDetailsPage } from '../pages/members/activity-reports';
import { SupportingDocumentsPage } from '../pages/members/activity-reports';
import { ReviewAndSubmitPage } from '../pages/members/activity-reports';
import { DashboardPage } from '../pages/members';

export class ActivityReportFlow {
  page: Page;

  constructor(page: Page) {
    this.page = page;
  }

  /**
   * Runs the full activity report submission flow.
   * @param employerName - Name of the employer
   * @param hours - Hours worked
   * @returns DashboardPage after successful submission
   */
  async run(
    employerName: string = 'Acme Inc',
    hours: string = '80'
  ): Promise<DashboardPage> {
    // Step 1: Before You Start page
    const beforeYouStartPage = await new BeforeYouStartPage(this.page).waitForURLtoMatchPagePath();
    const chooseMonthsPage = await beforeYouStartPage.clickStart();

    // Step 2: Choose months
    const activityReportPage = await chooseMonthsPage.selectFirstReportingPeriodAndSave();

    // Step 3: Add activity
    const activityTypePage = await activityReportPage.clickAddActivity();

    // Step 4: Select activity type
    const activityDetailsPage = await activityTypePage.fillActivityType();

    // Step 5: Fill activity details
    const supportingDocumentsPage = await activityDetailsPage.fillActivityDetails(
      employerName,
      hours
    );

    // Step 6: Skip document upload
    const activityReportPageAfterUpload = await supportingDocumentsPage.clickContinue();

    // Step 7: Review and submit
    const reviewAndSubmitPage = await activityReportPageAfterUpload.clickReviewAndSubmit();

    // Step 8: Final submission
    return await reviewAndSubmitPage.clickSubmit();
  }
}
```

## Requirements

- **Comment each step** with a clear description
- **Return the final page type** for assertions in the test
- **Keep flows simple** — let page objects handle the complexity
- **Don't add assertions** in flows; that's the test's job
- **Match the workflow's steps** 1:1 with code

## Flow with parameters

```typescript
export class CertificationFlow {
  page: Page;

  constructor(page: Page) {
    this.page = page;
  }

  /**
   * Complete certification workflow with custom data.
   * @param certificationData - Object with member info, activities, documents
   * @returns ConfirmationPage after successful submission
   */
  async run(certificationData: {
    firstName: string;
    lastName: string;
    activities: Array<{ employer: string; hours: string }>;
    documents: string[];
  }): Promise<ConfirmationPage> {
    // Step 1: Initial info
    const infoPage = await new InformationPage(this.page).waitForURLtoMatchPagePath();
    const activitiesPage = await infoPage.fillPersonalInfo(
      certificationData.firstName,
      certificationData.lastName
    );

    // Step 2: Add all activities
    let currentPage = activitiesPage;
    for (const activity of certificationData.activities) {
      const activityForm = await currentPage.clickAddActivity();
      currentPage = await activityForm.fillActivity(activity.employer, activity.hours);
    }

    // Step 3: Upload documents
    const documentsPage = await currentPage.clickDocuments();
    for (const doc of certificationData.documents) {
      await documentsPage.uploadDocument(doc);
    }

    // Step 4: Review and submit
    const reviewPage = await documentsPage.clickReview();
    return await reviewPage.submitCertification();
  }
}
```

## Flow with conditional branches

```typescript
export class ExemptionFlow {
  page: Page;

  constructor(page: Page) {
    this.page = page;
  }

  /**
   * Exemption claim flow with conditional logic.
   */
  async run(options: {
    claimType: 'medical' | 'disability';
    uploadDocument?: boolean;
  }): Promise<SuccessPage> {
    // Step 1: Type selection
    const typePage = await new ExemptionTypePage(this.page).waitForURLtoMatchPagePath();
    const detailsPage = await typePage.selectClaimType(options.claimType);

    // Step 2: Type-specific details
    let documentsPage: DocumentsPage;
    if (options.claimType === 'medical') {
      documentsPage = await detailsPage.fillMedicalDetails('Doctor note', '2025-03-01');
    } else {
      documentsPage = await detailsPage.fillDisabilityDetails('VA rating', '50');
    }

    // Step 3: Conditional document upload
    if (options.uploadDocument) {
      await documentsPage.uploadDocument('supporting-doc.pdf');
    }

    // Step 4: Review and submit
    const reviewPage = await documentsPage.clickReview();
    return await reviewPage.submitClaim();
  }
}
```

## Flow best practices

✓ **DO:**
- Comment each step clearly
- Return final page for assertions
- Use descriptive parameter names
- Reuse existing page object methods
- Keep steps sequential and logical

✗ **DON'T:**
- Add assertions in the flow
- Create flows for simple 2-3 step workflows
- Modify page object behavior inside flow
- Mix multiple workflows in one flow
- Use magic strings—pass parameters instead

## Test usage example

```typescript
import { test } from '../../fixtures';
import { ActivityReportFlow } from '../flows';

test('member submits activity report', async ({ page }) => {
  // Initialize the flow
  const flow = new ActivityReportFlow(page);

  // Run the complete workflow
  const dashboardPage = await flow.run('My Employer', '40');

  // Assert final state
  expect(page.url()).toContain('/dashboard');
  await expect(page.locator('h1')).toContainText('Welcome');
});

test('member submits with custom data', async ({ page }) => {
  const certFlow = new CertificationFlow(page);

  const confirmation = await certFlow.run({
    firstName: 'John',
    lastName: 'Doe',
    activities: [
      { employer: 'Company A', hours: '40' },
      { employer: 'Company B', hours: '20' }
    ],
    documents: ['doc1.pdf', 'doc2.pdf']
  });

  expect(page.url()).toContain('/confirmation');
});
```
