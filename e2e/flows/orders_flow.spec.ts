import { expect, test } from '@playwright/test';

test('Orders screen loads', async ({ page }) => {
  await page.goto('/orders');
  await expect(page.getByText('Orders', { exact: true }).or(page.getByRole('heading', { name: /orders/i }))).toBeVisible();
  await expect(page.locator('table')).toBeVisible();
});
