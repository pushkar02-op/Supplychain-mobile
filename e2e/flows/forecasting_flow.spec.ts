import { expect, test } from '@playwright/test';

test('Forecast dashboard loads', async ({ page }) => {
  await page.goto('/forecasting');
  await expect(page.getByText('Forecast', { exact: false }).or(page.getByRole('heading', { name: /forecast/i }))).toBeVisible();
});
