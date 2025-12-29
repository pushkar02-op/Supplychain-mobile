import { expect, test } from '@playwright/test';

test('sanity check', async ({ page }) => {
  await page.goto('about:blank');
  expect(1).toBe(1);
});
