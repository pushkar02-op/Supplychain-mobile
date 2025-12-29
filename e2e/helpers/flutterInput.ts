import { Page, expect } from '@playwright/test';

/**
 * Types into a Flutter Web text input by targeting the real input element.
 * 
 * @param page - Playwright page object
 * @param visibleLabel - The visible label text (e.g., "Email", "Password", "Quantity")
 * @param value - The value to type
 */
export async function typeFlutterInput(
  page: Page,
  visibleLabel: string,
  value: string
) {
  const input = page.locator(`input[aria-label="${visibleLabel}"]`);

  await input.waitFor({ state: 'visible', timeout: 15000 });
  await input.click();

  // Flutter needs focus settle
  await page.waitForTimeout(200);

  await page.keyboard.type(value, { delay: 50 });

  // Visual + DOM assertion
  await expect(input).toHaveValue(value);
  
  console.log(`[FlutterInput] Typed "${value}" into "${visibleLabel}"`);
}

/**
 * Clicks a Flutter Web button by its visible text.
 * 
 * @param page - Playwright page object
 * @param visibleText - The visible button text
 */
export async function clickFlutterButton(
  page: Page,
  visibleText: string
) {
  const button = page.locator(`button:has-text("${visibleText}")`).first();
  
  await button.waitFor({ state: 'visible', timeout: 15000 });
  await button.click();
  
  console.log(`[FlutterButton] Clicked "${visibleText}"`);
}
