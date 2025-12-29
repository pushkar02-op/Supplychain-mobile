import { Page } from '@playwright/test';
import { tapFlutterInkWell } from './flutterTap';

/**
 * Navigate to Stock module from Dashboard using InkWell tap
 */
export async function goToStock(page: Page) {
  console.log('[Nav] Navigating to Stock...');
  const stockTile = page.locator('[role="button"]:has-text("Stock")').first();
  await tapFlutterInkWell(page, stockTile);
  
  // Wait for navigation to complete
  await page.waitForTimeout(1000);
  console.log('[Nav] Stock navigation complete.');
}

/**
 * Navigate to Orders module from Dashboard
 */
export async function goToOrders(page: Page) {
  console.log('[Nav] Navigating to Orders...');
  const ordersTile = page.locator('[role="button"]:has-text("Orders")').first();
  await tapFlutterInkWell(page, ordersTile);
  await page.waitForTimeout(1000);
  console.log('[Nav] Orders navigation complete.');
}

/**
 * Navigate to Inventory module from Dashboard  
 */
export async function goToInventory(page: Page) {
  console.log('[Nav] Navigating to Inventory...');
  const invTile = page.locator('[role="button"]:has-text("Inventory")').first();
  await tapFlutterInkWell(page, invTile);
  await page.waitForTimeout(1000);
  console.log('[Nav] Inventory navigation complete.');
}

/**
 * Navigate to Items module from Dashboard
 */
export async function goToItems(page: Page) {
  console.log('[Nav] Navigating to Items...');
  const itemsTile = page.locator('[role="button"]:has-text("Items")').first();
  await tapFlutterInkWell(page, itemsTile);
  await page.waitForTimeout(1000);
  console.log('[Nav] Items navigation complete.');
}

/**
 * CENTRALIZED: Click Stock action button on StockListScreen
 * 
 * DOM-driven discovery with priority order:
 * 1. "Add your first stock entry" (empty state TextButton)
 * 2. "Add Stock" (FAB)
 * 
 * Uses ONLY InkWell pointer tap - NO .click()
 */
export async function clickStockAction(page: Page) {
  console.log('[StockAction] Discovering available Stock action buttons...');
  
  // Priority 1: Empty state TextButton
  const emptyStateBtn = page.locator('button:has-text("Add your first stock entry")');
  // Priority 2: FAB
  const fabBtn = page.locator('button:has-text("Add Stock")');
  
  // Check which button is visible and use priority order
  const emptyStateVisible = await emptyStateBtn.isVisible().catch(() => false);
  const fabVisible = await fabBtn.isVisible().catch(() => false);
  
  console.log(`[StockAction] Button visibility - EmptyState: ${emptyStateVisible}, FAB: ${fabVisible}`);
  
  let targetBtn;
  let targetLabel;
  
  if (emptyStateVisible) {
    targetBtn = emptyStateBtn;
    targetLabel = 'Add your first stock entry';
  } else if (fabVisible) {
    targetBtn = fabBtn;
    targetLabel = 'Add Stock';
  } else {
    throw new Error('[StockAction] No Stock action button found in DOM');
  }
  
  console.log(`[StockAction] Selected target: "${targetLabel}"`);
  
  // Use ONLY InkWell pointer tap - NO .click()
  await tapFlutterInkWell(page, targetBtn);
  
  // Wait for navigation
  await page.waitForTimeout(1500);
  console.log('[StockAction] Tap complete. Verifying navigation...');
}

// Keep legacy alias for backward compatibility
export const clickAddStock = clickStockAction;
