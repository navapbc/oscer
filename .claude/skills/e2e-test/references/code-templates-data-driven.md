# Data-Driven & Parameterized Tests

**For testing multiple similar scenarios with different data:**

## Simple parameterized test

```typescript
const testCases = [
  { email: 'member1@example.com', expectedDashboard: 'Dashboard for Member 1' },
  { email: 'member2@example.com', expectedDashboard: 'Dashboard for Member 2' },
];

for (const { email, expectedDashboard } of testCases) {
  test(`member ${email} can sign in`, async ({ page, emailService }) => {
    // ... sign-in flow ...
    await expect(page.locator('h1')).toContainText(expectedDashboard);
  });
}
```

## Test with multiple parameters

```typescript
const scenarios = [
  {
    name: 'valid email',
    input: 'test@example.com',
    shouldSucceed: true
  },
  {
    name: 'invalid email format',
    input: 'not-an-email',
    shouldSucceed: false
  },
  {
    name: 'empty email',
    input: '',
    shouldSucceed: false
  }
];

for (const scenario of scenarios) {
  test(`form validation: ${scenario.name}`, async ({ page }) => {
    const form = await new FormPage(page).waitForURLtoMatchPagePath();

    await form.emailField.fill(scenario.input);
    await form.submitButton.click();

    if (scenario.shouldSucceed) {
      expect(page.url()).toContain('/success');
    } else {
      await expect(page.locator('[role="alert"]')).toBeVisible();
      expect(page.url()).toContain('/form');
    }
  });
}
```

## Activity report scenarios

```typescript
const activityScenarios = [
  {
    description: 'single activity, 40 hours',
    activities: [
      { employer: 'Company A', hours: '40' }
    ],
    expectedTotal: '40 hours'
  },
  {
    description: 'multiple activities, different hours',
    activities: [
      { employer: 'Company A', hours: '30' },
      { employer: 'Company B', hours: '20' },
      { employer: 'Company C', hours: '10' }
    ],
    expectedTotal: '60 hours'
  },
  {
    description: 'part-time activities',
    activities: [
      { employer: 'Company A', hours: '20' },
      { employer: 'Company B', hours: '15' }
    ],
    expectedTotal: '35 hours'
  }
];

for (const scenario of activityScenarios) {
  test(`member can submit activities: ${scenario.description}`, async ({ page }) => {
    const flow = new ActivityReportFlow(page);

    // Submit first activity
    let currentPage = await flow.startActivityReport();

    // Add all activities in scenario
    for (const activity of scenario.activities) {
      currentPage = await currentPage.addActivity(
        activity.employer,
        activity.hours
      );
    }

    // Review and submit
    const confirmationPage = await currentPage.submitReport();

    // Verify total hours
    await expect(page.locator('[data-testid="total-hours"]')).toContainText(
      scenario.expectedTotal
    );
  });
}
```

## Error scenario testing

```typescript
const errorScenarios = [
  {
    field: 'email',
    value: 'invalid',
    expectedError: 'Enter a valid email address'
  },
  {
    field: 'firstName',
    value: '',
    expectedError: 'First name is required'
  },
  {
    field: 'phone',
    value: '123',
    expectedError: 'Phone number must be valid'
  }
];

for (const scenario of errorScenarios) {
  test(`form shows error for invalid ${scenario.field}`, async ({ page }) => {
    const form = await new FormPage(page).waitForURLtoMatchPagePath();

    // Fill the specific field with invalid data
    const field = form[`${scenario.field}Field`];
    await field.fill(scenario.value);

    // Try to submit
    await form.submitButton.click();

    // Expect error message
    await expect(page.locator('[role="alert"]')).toContainText(
      scenario.expectedError
    );
  });
}
```

## Exemption claim types

```typescript
const exemptionTypes = [
  {
    type: 'medical',
    description: 'Doctor states disability',
    document: 'doctor-note.pdf'
  },
  {
    type: 'disability',
    description: 'VA rated disability',
    document: 'va-rating.pdf'
  },
  {
    type: 'hardship',
    description: 'Financial hardship',
    document: 'hardship-letter.pdf'
  }
];

for (const exemption of exemptionTypes) {
  test(`member files ${exemption.type} exemption claim: ${exemption.description}`, async ({
    page,
    emailService
  }) => {
    const email = emailService.generateEmailAddress(emailService.generateUsername());

    // Start exemption flow
    const typePage = await new ExemptionTypePage(page).go();
    const detailsPage = await typePage.selectExemptionType(exemption.type);

    // Fill type-specific details
    let documentsPage;
    switch (exemption.type) {
      case 'medical':
        documentsPage = await detailsPage.fillMedicalDetails('Doctor name', '2025-01-01');
        break;
      case 'disability':
        documentsPage = await detailsPage.fillDisabilityDetails('VA rating', '50%');
        break;
      case 'hardship':
        documentsPage = await detailsPage.fillHardshipDetails('Income loss');
        break;
    }

    // Upload document
    const reviewPage = await documentsPage.uploadDocument(
      path.join(__dirname, '../../fixtures', exemption.document)
    );

    // Submit and verify
    const confirmation = await reviewPage.submit();
    expect(page.url()).toContain('/confirmation');
  });
}
```

## Best practices for data-driven tests

✓ **DO:**
- Use descriptive names in scenario objects
- Keep scenario data separate from test logic
- Vary meaningful data (not just different emails)
- Test edge cases (empty, invalid, boundary values)
- Group related scenarios together

✗ **DON'T:**
- Duplicate entire test code for each scenario
- Use vague parameter names like `a`, `b`, `data1`
- Test unrelated scenarios in one loop
- Leave scenarios hardcoded—use arrays/objects
- Mix test logic with scenario definitions

## Template for complex scenarios

```typescript
interface TestScenario {
  name: string;
  description: string;
  inputs: Record<string, string>;
  expected: {
    success: boolean;
    message?: string;
    url?: string;
  };
}

const scenarios: TestScenario[] = [
  {
    name: 'valid_submission',
    description: 'Member with all required fields',
    inputs: {
      firstName: 'John',
      lastName: 'Doe',
      email: 'john@example.com'
    },
    expected: {
      success: true,
      url: '/confirmation'
    }
  },
  {
    name: 'missing_email',
    description: 'Submission without email',
    inputs: {
      firstName: 'Jane',
      lastName: 'Doe',
      email: ''
    },
    expected: {
      success: false,
      message: 'Email is required'
    }
  }
];

for (const scenario of scenarios) {
  test(`${scenario.name}: ${scenario.description}`, async ({ page }) => {
    const form = new FormPage(page);

    // Fill all inputs from scenario
    for (const [field, value] of Object.entries(scenario.inputs)) {
      const locator = form[`${field}Field`];
      await locator.fill(value);
    }

    await form.submitButton.click();

    // Verify expected outcome
    if (scenario.expected.success) {
      expect(page.url()).toContain(scenario.expected.url);
    } else {
      await expect(page.locator('[role="alert"]')).toContainText(
        scenario.expected.message
      );
    }
  });
}
```
