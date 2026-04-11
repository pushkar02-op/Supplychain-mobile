import { expect, test } from '@playwright/test';

test('Inventory screen loads', async ({ page }) => {
  await page.goto('/inventory');
  await expect(page.getByText('Inventory', { exact: true }).or(page.getByRole('heading', { name: /inventory/i }))).toBeVisible();
  const table = page.locator('table');
  await expect(table).toBeVisible();
  await expect(table.locator('tbody tr').first()).toBeVisible({ timeout: 15000 });
});
