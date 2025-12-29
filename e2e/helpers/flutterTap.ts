import { expect, Locator, Page } from '@playwright/test';

/**
 * Taps a Flutter Web InkWell/GestureDetector widget using pointer-accurate mouse events.
 * This is more reliable than .click() for Flutter Web's gesture recognizers.
 * 
 * @param page - Playwright page object
 * @param locator - Locator pointing to the InkWell element
 */
export async function tapFlutterInkWell(
  page: Page,
  locator: Locator
) {
  await expect(locator).toBeVisible({ timeout: 15000 });

  const box = await locator.boundingBox();
  if (!box) {
    throw new Error('Failed to get bounding box for InkWell');
  }

  const x = box.x + box.width / 2;
  const y = box.y + box.height / 2;

  console.log(`[FlutterTap] Tapping at (${x}, ${y})`);
  
  await page.mouse.move(x, y);
  await page.mouse.down();
  await page.waitForTimeout(50); // Flutter gesture settle
  await page.mouse.up();
  
  console.log('[FlutterTap] Tap complete.');
}
