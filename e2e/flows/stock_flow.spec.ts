import { expect, test } from '@playwright/test';

test('Stock entries screen loads', async ({ page }) => {
  await page.goto('/stock');
  await expect(page.locator('table')).toBeVisible();
});
