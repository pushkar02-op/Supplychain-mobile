import { expect, test } from '@playwright/test';

test('Dispatch screen loads', async ({ page }) => {
  await page.goto('/dispatch');
  await expect(page.getByText('Dispatch', { exact: true }).or(page.getByRole('heading', { name: /dispatch/i }))).toBeVisible();
  await expect(page.locator('table')).toBeVisible();
});
