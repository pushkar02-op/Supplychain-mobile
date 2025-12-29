import { Page, expect } from '@playwright/test';

export async function expectSuccess(page: Page) {
  await expect(
    page.locator('[data-testid="success-toast"]')
  ).toBeVisible();
}
