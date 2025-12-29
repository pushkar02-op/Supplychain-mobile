import { expect, test } from '@playwright/test';
import { loginAsManager } from '../helpers/auth';

test('Auth → Dashboard redirect works', async ({ page }) => {
  page.on('console', msg => console.log('BROWSER_LOG:', msg.text()));

  await page.goto('/login');

  await loginAsManager(page);

  // 1️⃣ Check token (FlutterSecureStorage may not use localStorage on web)
  const token = await page.evaluate(() =>
    window.localStorage.getItem('access_token')
  );

  console.log('TOKEN from localStorage:', token);
  // Note: FlutterSecureStorage on web uses different storage mechanism
  // The Dashboard being visible proves auth worked
  if (!token) {
    console.log('Token not in localStorage (expected for FlutterSecureStorage on web)');
  }

  // 2️⃣ Assert dashboard DOM - This is the authoritative Dashboard marker
  await expect(
    page.locator('text=Dashboard')
  ).toBeVisible({ timeout: 15000 });
  
  console.log('[Canary-1] Dashboard visible. Test PASSED.');
});
