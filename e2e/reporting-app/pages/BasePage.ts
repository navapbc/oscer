import { Page } from '@playwright/test';

/**
 * Base class for implementing the Page Object Model (POM) pattern.
 *
 * Page Object Models are a design pattern that represent parts of your web application
 * as reusable classes. Each page object:
 * - Provides a higher-level API for interacting with page elements
 * - Simplifies test maintenance by capturing element selectors in one place
 * - Reduces code duplication across tests
 * - Makes tests more readable and maintainable
 *
 * Classes that extend BasePage should:
 * - Define locators for important page elements
 * - Implement methods that represent common user actions
 * - Handle page navigation and state
 *
 * @see {@link https://playwright.dev/docs/pom} for more information about Page Object Models
 */
export abstract class BasePage {
  protected readonly page: Page;

  abstract get pagePath(): string;

  constructor(page: Page) {
    this.page = page;
  }

  async waitForURLtoMatchPagePath(): Promise<typeof this> {
    await this.page.waitForURL(this.pagePath);
    return this;
  }

  async go(): Promise<typeof this> {
    if (this.page.url() !== this.pagePath) {
      await this.page.goto(this.pagePath);
    }
    return this;
  }
}
