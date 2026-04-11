/**
 * Semantic Action Layer
 * 
 * Centralizes all semantic-driven interactions for Flutter Web E2E testing.
 * 
 * RULES:
 * - ALL button interactions MUST go through this module
 * - NO .click() calls - use tapSemanticAction() instead
 * - Semantic labels must match Flutter's Semantics(label: ...) values
 */

import { expect, Locator, Page } from '@playwright/test';

/**
 * Registered semantic action labels.
 * Add new labels here as they're added to Flutter widgets.
 */
export const SEMANTIC_LABELS = {
  // Stock actions
  ADD_STOCK: 'add-stock-action',
  ADD_FIRST_STOCK_ENTRY: 'add-first-stock-entry-action',
  
  // Auth actions
  LOGIN_SUBMIT: 'login-submit',
  LOGIN_EMAIL: 'login-email',
  LOGIN_PASSWORD: 'login-password',
  
  // Navigation tiles (Dashboard)
  NAV_STOCK: 'nav-stock',
  NAV_ORDERS: 'nav-orders',
  NAV_INVENTORY: 'nav-inventory',
  NAV_ITEMS: 'nav-items',
  
  // Form actions
  STOCK_SUBMIT: 'stock-submit',
  EDIT_STOCK: 'edit-stock',
  DELETE_STOCK: 'delete-stock',
  CONFIRM_DELETE: 'confirm-delete',
} as const;

export type SemanticLabel = typeof SEMANTIC_LABELS[keyof typeof SEMANTIC_LABELS];

/**
 * Get a locator for a semantic action button.
 * Uses aria-label as primary selector (Flutter Semantics maps to aria-label).
 * 
 * @param page - Playwright page
 * @param label - Semantic label (from SEMANTIC_LABELS or custom)
 * @returns Locator for the semantic element
 */
export function getSemanticLocator(page: Page, label: string): Locator {
  // Primary: aria-label (Flutter Semantics label maps here)
  // Fallback: role=button with name (for getByRole compatibility)
  return page.locator(`[aria-label="${label}"]`).or(
    page.getByRole('button', { name: label, includeHidden: true })
  );
}

/**
 * Wait for a semantic action to become available.
 * 
 * @param page - Playwright page
 * @param label - Semantic label
 * @param timeout - Maximum wait time (default: 15000ms)
 * @returns Locator once visible
 */
export async function waitForSemanticAction(
  page: Page, 
  label: string, 
  timeout: number = 15000
): Promise<Locator> {
  const locator = getSemanticLocator(page, label);
  await locator.waitFor({ state: 'attached', timeout });
  console.log(`[Semantics] Action "${label}" is available`);
  return locator;
}

/**
 * Trigger a semantic action using pointer-accurate tap.
 * This is the PRIMARY method for interacting with Flutter buttons.
 * 
 * Uses mouse events instead of .click() for Flutter gesture detector compatibility.
 * 
 * @param page - Playwright page
 * @param label - Semantic label of the action
 * @param options - Optional configuration
 */
export async function tapSemanticAction(
  page: Page, 
  label: string,
  options: { timeout?: number; waitAfter?: number } = {}
): Promise<void> {
  const { timeout = 15000, waitAfter = 100 } = options;
  
  console.log(`[Semantics] Triggering action: "${label}"`);
  
  const locator = getSemanticLocator(page, label);
  
  // Wait for element to be attached (may be aria-hidden but still interactive)
  await locator.waitFor({ state: 'attached', timeout });
  
  // Get bounding box for pointer-accurate tap
  const box = await locator.boundingBox();
  if (!box) {
    throw new Error(`[Semantics] Could not get bounding box for "${label}"`);
  }
  
  const x = box.x + box.width / 2;
  const y = box.y + box.height / 2;
  
  console.log(`[Semantics] Tapping at (${x.toFixed(1)}, ${y.toFixed(1)})`);
  
  // Pointer-accurate tap sequence (Flutter gesture detector compatible)
  await page.mouse.move(x, y);
  await page.mouse.down();
  await page.waitForTimeout(50); // Flutter gesture settle
  await page.mouse.up();
  
  // Optional wait for action to complete
  if (waitAfter > 0) {
    await page.waitForTimeout(waitAfter);
  }
  
  console.log(`[Semantics] Action "${label}" triggered successfully`);
}

/**
 * Trigger semantic action via keyboard Enter key.
 * Alternative to pointer tap for keyboard accessibility testing.
 * 
 * @param page - Playwright page
 * @param label - Semantic label
 */
export async function pressSemanticAction(
  page: Page,
  label: string,
  options: { timeout?: number } = {}
): Promise<void> {
  const { timeout = 15000 } = options;
  
  console.log(`[Semantics] Pressing Enter on: "${label}"`);
  
  const locator = getSemanticLocator(page, label);
  await locator.waitFor({ state: 'attached', timeout });
  
  await locator.focus();
  await page.keyboard.press('Enter');
  
  console.log(`[Semantics] Enter pressed on "${label}"`);
}

/**
 * Discover all semantic actions on the current page.
 * Useful for debugging and test development.
 * 
 * @param page - Playwright page
 * @returns Array of discovered aria-labels
 */
export async function discoverSemanticActions(page: Page): Promise<string[]> {
  console.log('[Semantics] Discovering available actions...');
  
  const elements = await page.locator('[aria-label], [role="button"]').all();
  const labels: string[] = [];
  
  for (const el of elements) {
    const ariaLabel = await el.getAttribute('aria-label');
    if (ariaLabel && !labels.includes(ariaLabel)) {
      labels.push(ariaLabel);
    }
  }
  
  console.log(`[Semantics] Found ${labels.length} actions:`, labels);
  return labels;
}

/**
 * Assert that a semantic action exists on the page.
 * 
 * @param page - Playwright page
 * @param label - Semantic label to verify
 */
export async function assertSemanticActionExists(
  page: Page,
  label: string
): Promise<void> {
  const locator = getSemanticLocator(page, label);
  await expect(locator).toBeAttached();
  console.log(`[Semantics] Verified action exists: "${label}"`);
}
