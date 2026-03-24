# Existing Page Objects and Flows

Always check this list before creating new classes. Reuse or extend where possible.

## Page Objects

### Top-level (`e2e/reporting-app/pages/`)

| Class | File | `pagePath` |
|-------|------|-----------|
| `CertificationRequestPage` | `pages/CertificationRequestPage.ts` | `/demo/certifications/new` |
| `BasePage` | `pages/BasePage.ts` | abstract base |

### Members (`e2e/reporting-app/pages/members/`)

| Class | File | `pagePath` |
|-------|------|-----------|
| `DashboardPage` | `pages/members/DashboardPage.ts` | `/dashboard` |
| `StaffDashboardPage` | `pages/members/StaffDashboardPage.ts` | `/staff/dashboard` (or similar) |

### Auth / Users (`e2e/reporting-app/pages/users/`)

| Class | File | `pagePath` |
|-------|------|-----------|
| `RegistrationPage` | `pages/users/RegistrationPage.ts` | `/users/registrations` |
| `SignInPage` | `pages/users/SignInPage.ts` | `/users/sign_in` |
| `VerifyAccountPage` | `pages/users/VerifyAccountPage.ts` | (email verification) |
| `MfaPreferencePage` | `pages/users/MfaPreferencePage.ts` | (MFA skip/setup) |

### Activity Reports (`e2e/reporting-app/pages/members/activity-reports/`)

| Class | File | `pagePath` |
|-------|------|-----------|
| `BeforeYouStartPage` | `activity-reports/BeforeYouStartPage.ts` | `/activity_report_application_forms/new?*` |
| `ChooseMonthsPage` | `activity-reports/ChooseMonthsPage.ts` | `/activity_report_application_forms/*/edit` |
| `ActivityReportPage` | `activity-reports/ActivityReportPage.ts` | `/activity_report_application_forms/*` |
| `ActivityTypePage` | `activity-reports/ActivityTypePage.ts` | `/activity_report_application_forms/*/activities/new` |
| `ActivityDetailsPage` | `activity-reports/ActivityDetailsPage.ts` | (activity edit page) |
| `SupportingDocumentsPage` | `activity-reports/SupportingDocumentsPage.ts` | (document upload) |
| `ReviewAndSubmitPage` | `activity-reports/ReviewAndSubmitPage.ts` | (review before submit) |
| `DocAiUploadPage` | `activity-reports/DocAiUploadPage.ts` | `activity_report_application_forms/*/doc_ai_upload` |
| `DocAiUploadStatusPage` | `activity-reports/DocAiUploadStatusPage.ts` | `*document_staging/doc_ai_upload_status*` |
| `DocAiActivityReviewPage` | `activity-reports/DocAiActivityReviewPage.ts` | `activity_report_application_forms/*/activities/*/edit*` |

## Flows (`e2e/reporting-app/flows/`)

| Class | File | What it does |
|-------|------|-------------|
| `AccountCreationFlow` | `flows/AccountCreationFlow.ts` | Registers user, verifies email, returns `SignInPage` |
| `ActivityReportFlow` | `flows/ActivityReportFlow.ts` | Full manual activity report — dashboard → submit. Args: `email, password, employerName, hours` |
| `DocAiUploadFlow` | `flows/DocAiUploadFlow.ts` | Full DocAI flow — dashboard → upload paystubs → review AI activities → submit. Args: `pdfPath, jpegPath` |

## Key method signatures

### `CertificationRequestPage`
```typescript
fillAndSubmit(email: string, options?: { certificationDate?: string }): Promise<void>
// certificationDate format: 'M/D/YYYY' (e.g. '2/15/2026')
```

### `BeforeYouStartPage`
```typescript
clickStart(skipAi?: boolean): Promise<ChooseMonthsPage>
// skipAi defaults to true (manual flow); pass false for DocAI flow
```

### `ChooseMonthsPage`
```typescript
selectFirstReportingPeriodAndSave(): Promise<ActivityReportPage>        // manual flow
selectFirstReportingPeriodAndSaveForDocAi(): Promise<DocAiUploadPage>   // DocAI flow
```

### `ActivityReportFlow`
```typescript
run(email: string, password: string, employerName?: string, hours?: string): Promise<DashboardPage>
// Defaults: employerName='Acme Inc', hours='80'
```

### `DocAiUploadFlow`
```typescript
run(pdfPath: string, jpegPath: string): Promise<ReviewAndSubmitPage>
// Fixture files live in: e2e/reporting-app/fixtures/
```

### `AccountCreationFlow`
```typescript
run(emailAddress: EmailAddress, password: string): Promise<SignInPage>
```

## Fixture files

| File | Path | Used for |
|------|------|---------|
| `paystub_test_feb_2026_paydate.pdf` | `e2e/reporting-app/fixtures/` | DocAI PDF upload |
| `paystub_feb2026.jpg` | `e2e/reporting-app/fixtures/` | DocAI JPEG upload |

## Barrel exports to update

When adding new classes, export them from:
- `e2e/reporting-app/pages/members/activity-reports/index.ts`
- `e2e/reporting-app/pages/members/index.ts`
- `e2e/reporting-app/pages/index.ts`
- `e2e/reporting-app/flows/index.ts`
