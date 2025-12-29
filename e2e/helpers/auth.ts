import { Page, expect } from '@playwright/test';
import { typeFlutterInput } from './flutterInput';

export async function loginAsManager(page: Page) {
  const loginUrl = '/login';
  
  console.log(`[E2E] Navigating to ${loginUrl}...`);
  await page.goto(loginUrl, { waitUntil: 'load' });
  console.log('[E2E] Navigation complete.');

  // Use Flutter input helper for reliable text entry
  await typeFlutterInput(page, 'Email', 'manager@test.com');
  
  // Wait for input stability before switching fields
  await page.waitForTimeout(500);
  
  await typeFlutterInput(page, 'Password', 'password');

  console.log('[E2E] Submitting form...');
  // Use the outer semantics button which triggers Flutter's onPressed
  const loginButton = page.locator('[aria-label="login-submit"]');
  await loginButton.waitFor({ state: 'visible' });
  await loginButton.click();
  console.log('[E2E] Login button clicked.');

  // Start waiting for the login response
  const loginResponsePromise = page.waitForResponse(response => 
    response.url().includes('/auth/token') || response.url().includes('/login')
  ).catch(() => null);

  // Allow time for API call and token storage
  await page.waitForTimeout(2000);

  // Try to capture login response
  try {
    const response = await loginResponsePromise;
    if (response) {
      console.log(`[E2E] LOGIN_RESPONSE Status: ${response.status()}`);
    }
  } catch (e) {
    console.log('[E2E] Login response already processed');
  }

  // Check Token (FlutterSecureStorage may not use localStorage)
  try {
    const keys = await page.evaluate(() => Object.keys(window.localStorage));
    console.log(`[E2E] localStorage keys: ${JSON.stringify(keys)}`);
    
    const token = await page.evaluate(() => 
      window.localStorage.getItem('access_token') || window.localStorage.getItem('token')
    );
    if (token) {
      console.log(`[E2E] ACCESS_TOKEN Found: ${token.substring(0, 15)}...`);
    } else {
      console.log('[E2E] ACCESS_TOKEN NOT found in localStorage (expected for FlutterSecureStorage)');
    }
  } catch (e) {
    console.error(`[E2E] Failed to inspect localStorage: ${e}`);
  }

  console.log(`[E2E] CURRENT_URL: ${page.url()}`);

  console.log('[E2E] Verifying Dashboard DOM...');
  // Use Dashboard heading text as authoritative marker
  try {
    const dashboardMarker = page.locator('text=Dashboard');
    await expect(dashboardMarker).toBeVisible({ timeout: 15000 });
    console.log('[E2E] Dashboard text is VISIBLE. Login Succeeded.');
  } catch (e) {
    console.error('[E2E] Dashboard NOT visible.', e);
    if (page.url().includes('login')) {
      console.log('[E2E] Still on Login Page.');
    }
    throw e;
  }
}
