import { expect, test as setup } from '@playwright/test';
import * as fs from 'fs';
import * as path from 'path';

const authFile = 'user.json';

setup('authenticate', async ({ page }) => {
  console.log('Current working directory:', process.cwd());
  const testFile = path.join(process.cwd(), 'write_test.txt');
  fs.writeFileSync(testFile, 'Disk write test');
  console.log('Manual disk write test completed:', testFile);
  page.on('console', msg => console.log('BROWSER LOG:', msg.text()));
  
  console.log('Navigating to login page...');
  await page.goto('http://127.0.0.1:8080/?enable_semantics=true');
  
  // Wait for the app to load
  console.log('Waiting for Email field...');
  const emailField = page.locator('input[aria-label="Email"]');
  await expect(emailField).toBeVisible({ timeout: 60_000 });
  
  console.log('Filling Email...');
  await emailField.click();
  await page.keyboard.press('Control+A');
  await page.keyboard.press('Backspace');
  await page.keyboard.type('admin@example.com', { delay: 100 }); 

  console.log('Filling Password...');
  const passwordField = page.locator('input[aria-label="Password"]');
  await passwordField.click();
  await page.keyboard.press('Control+A');
  await page.keyboard.press('Backspace');
  await page.keyboard.type('admin', { delay: 100 }); 
  
  await page.screenshot({ path: 'd:/Projects/SupplyChain- mobile/e2e/credentials_filled.png' });
  console.log('Credentials filled, screenshot saved.');

  console.log('Pressing Login button (at coordinates 500, 663)...');
  await page.mouse.click(500, 663);

  // Wait until the Overview screen appears
  console.log('Waiting for URL redirect to #/main...');
  try {
    await page.waitForURL('**/main', { timeout: 30_000 });
    console.log('Login successful, URL matches #/main.');
    
    // Additional wait for the UI to be interactive
    await page.waitForTimeout(3000);
    
    // Verify one element just to be sure we are logged in
    const activityText = page.getByText('Today\'s Activity').or(page.getByText('Overview'));
    await expect(activityText.first()).toBeVisible({ timeout: 10_000 });
    
    await page.context().storageState({ path: authFile });
    console.log('Storage state saved successfully to:', authFile);
  } catch (error) {
    console.log('Login failed or timed out. Current URL:', page.url());
    await page.screenshot({ path: 'd:/Projects/SupplyChain- mobile/e2e/login_failure_final.png' });
    throw error;
  }
});
