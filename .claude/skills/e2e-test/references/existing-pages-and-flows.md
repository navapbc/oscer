# Existing Page Objects & Flows

## Overview

This catalog helps you **identify existing building blocks to reuse** before creating new page objects or flows. All page objects extend `BasePage` and use the Page Object Model (POM) pattern.

---

## Authentication & User Setup

### `SignInPage` (`pages/users/SignInPage.ts`)
**Purpose:** Member sign-in form
**Page path:** `/users/sign_in`
**Methods:**
- `fillEmail(email: string)` → fills email field
- `fillPassword(password: string)` → fills password field
- `signIn(email: string, password: string)` → fills both, submits form → `MfaPreferencePage`

### `RegistrationPage` (`pages/users/RegistrationPage.ts`)
**Purpose:** Member account registration
**Page path:** `/users/sign_up`
**Methods:**
- `fillOutRegistration(email: string, password: string)` → fills registration form → `VerifyAccountPage`

### `VerifyAccountPage` (`pages/users/VerifyAccountPage.ts`)
**Purpose:** Email verification (receives 6-digit code)
**Page path:** `/users/confirmations/new`
**Methods:**
- `submitVerificationCode(email: string, code: string)` → submits verification code → `SignInPage`

### `MfaPreferencePage` (`pages/users/mfa/MfaPreferencePage.ts`)
**Purpose:** MFA setup/preference (member can skip or enable)
**Page path:** `/users/mfa_preferences`
**Methods:**
- `skipMFA()` → skips MFA setup → `DashboardPage`

---

## Public/Pre-Auth Pages

### `CertificationRequestPage` (`pages/CertificationRequestPage.ts`)
**Purpose:** Initial certification request form (no sign-in required)
**Page path:** `/certification_request_forms/new`
**Methods:**
- `fillAndSubmit(email: string)` → submits certification request → `RegistrationPage`

---

## Member Dashboard & Navigation

### `DashboardPage` (`pages/members/DashboardPage.ts`)
**Purpose:** Member home/dashboard after sign-in
**Page path:** `/dashboard`
**Methods:**
- `clickReportActivities()` → navigates to activity report flow → `BeforeYouStartPage`

---

## Activity Report Flow

### `BeforeYouStartPage` (`pages/members/activity-reports/BeforeYouStartPage.ts`)
**Purpose:** Information/education page before starting activity report
**Page path:** `/activity_report_application_forms/*/before_you_start`
**Methods:**
- `clickStart()` → moves to month selection → `ChooseMonthsPage`

### `ChooseMonthsPage` (`pages/members/activity-reports/ChooseMonthsPage.ts`)
**Purpose:** Select reporting periods (months)
**Page path:** `/activity_report_application_forms/*/choose_months`
**Methods:**
- `selectFirstReportingPeriodAndSave()` → selects first available period, saves → `ActivityReportPage`

### `ActivityReportPage` (`pages/members/activity-reports/ActivityReportPage.ts`)
**Purpose:** Activity report list/dashboard (shows added activities)
**Page path:** `/activity_report_application_forms/*`
**Methods:**
- `clickAddActivity()` → navigates to add new activity → `ActivityTypePage`
- `clickReviewAndSubmit()` → moves to review page → `ReviewAndSubmitPage`

### `ActivityTypePage` (`pages/members/activity-reports/ActivityTypePage.ts`)
**Purpose:** Select activity type (work, hourly, income, ex parte)
**Page path:** `/activity_report_application_forms/*/activity_type`
**Methods:**
- `fillActivityType(type?: string)` → selects activity type, continues → `ActivityDetailsPage`

### `ActivityDetailsPage` (`pages/members/activity-reports/ActivityDetailsPage.ts`)
**Purpose:** Enter details for selected activity (employer, hours, income, etc.)
**Page path:** `/activity_report_application_forms/*/activity_detail`
**Methods:**
- `fillActivityDetails(employerName: string, hours: string)` → fills employer & hours, continues → `SupportingDocumentsPage`

### `SupportingDocumentsPage` (`pages/members/activity-reports/SupportingDocumentsPage.ts`)
**Purpose:** Upload/manage supporting documents (optional)
**Page path:** `/activity_report_application_forms/*/documents`
**Methods:**
- `clickContinue()` → skips document upload, returns to activity list → `ActivityReportPage`

### `ReviewAndSubmitPage` (`pages/members/activity-reports/ReviewAndSubmitPage.ts`)
**Purpose:** Final review of all activities before submission
**Page path:** `/activity_report_application_forms/*/review`
**Methods:**
- `clickSubmit()` → submits activity report → `DashboardPage`

---

## Exemption Flow

### `ExemptionScreenerPage` (`pages/members/exemptions/ExemptionScreenerPage.ts`)
**Purpose:** Entry point for exemption claims
**Page path:** `/exemption_application_forms/*/screener`

### `ExemptionScreenerQuestionPage` (`pages/members/exemptions/ExemptionScreenerQuestionPage.ts`)
**Purpose:** Answer eligibility questions dynamically
**Page path:** `/exemption_application_forms/*/question`

### `ExemptionMayQualifyPage` (`pages/members/exemptions/ExemptionMayQualifyPage.ts`)
**Purpose:** Outcome page indicating potential exemption qualification
**Page path:** `/exemption_application_forms/*/may_qualify`

### `ExemptionDocumentsPage` (`pages/members/exemptions/ExemptionDocumentsPage.ts`)
**Purpose:** Upload supporting documents for exemption claim
**Page path:** `/exemption_application_forms/*/documents`

### `ExemptionReviewPage` (`pages/members/exemptions/ExemptionReviewPage.ts`)
**Purpose:** Final review of exemption claim before submission
**Page path:** `/exemption_application_forms/*/review`

### `ExemptionSubmittedPage` (`pages/members/exemptions/ExemptionSubmittedPage.ts`)
**Purpose:** Confirmation page after successful submission
**Page path:** `/exemption_application_forms/*/submitted`

---

## Flows (Multi-Step Orchestrators)

### `AccountCreationFlow` (`flows/AccountCreationFlow.ts`)
**Purpose:** End-to-end account creation + email verification
**Constructor:** `new AccountCreationFlow(page, emailService)`
**Method:** `async run(email: string, password: string)` → returns `SignInPage`

### `ActivityReportFlow` (`flows/ActivityReportFlow.ts`)
**Purpose:** Complete activity report submission
**Constructor:** `new ActivityReportFlow(page)`
**Method:** `async run(email: string, password: string, employerName?: string, hours?: string)` → returns `DashboardPage`

### `ExemptionClaimFlow` (`flows/ExemptionClaimFlow.ts`)
**Purpose:** Complete exemption claim submission
**Constructor:** `new ExemptionClaimFlow(page)`

---

## Key Patterns

**All page methods should:**
- Return the next page type (for chaining)
- Use `.waitForURLtoMatchPagePath()` after navigation
- Handle USWDS CSS-hidden elements with `dispatchEvent('click')`

**Dynamic URLs:** Use `*` in `pagePath` for segments like `/activity_report_application_forms/*/edit`

**USWDS form controls:** Often hidden by CSS—use `dispatchEvent('click')` instead of `.click()` if it fails
