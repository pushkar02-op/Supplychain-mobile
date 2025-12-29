import { expect, test } from '@playwright/test';
import { expectSuccess } from '../helpers/assertions';
import { loginAsManager } from '../helpers/auth';
import { typeFlutterInput } from '../helpers/flutterInput';
import { clickAddStock, goToStock } from '../helpers/navigation';
import { seedRequirements } from '../helpers/seed';

test.describe('Stock Entry — Full Lifecycle', () => {

  test('Create → Edit → Delete stock entry', async ({ page, request }) => {
    // --- Seed Data ---
    let itemId: string;
    try {
        console.log('[Spec] Seeding requirements...');
        itemId = (await seedRequirements(request)).toString();
        console.log(`[Spec] Seed complete. Item ID: ${itemId}`);
    } catch(e: any) {
        console.error(`Seed Failed: ${e}\n${e.stack}`);
        throw e;
    }
    
    // --- Login ---
    await loginAsManager(page);

    // --- Navigate to Stock ---
    await goToStock(page);
    
    // Wait for Stock list screen to load
    await expect(page.locator('text=Stock')).toBeVisible({ timeout: 10000 });
    console.log('[Spec] Stock page loaded.');
    
    // Click Add Stock button using InkWell tap helper
    await clickAddStock(page);
    
    // Assert Stock Entry form appears
    await expect(
      page.locator('text=Add Stock Entry').or(page.locator('text=New Stock'))
    ).toBeVisible({ timeout: 15000 });
    console.log('[Spec] Stock Entry form opened.');
    
    // Select item - try dropdown or autocomplete pattern
    const itemDropdown = page.locator('select').or(
      page.locator('[role="combobox"]').or(
        page.locator('[aria-label="item-name"]')
      )
    ).first();
    
    if (await itemDropdown.count() > 0) {
      try {
        await itemDropdown.selectOption(itemId);
      } catch {
        // May be a different widget - try click + type
        await itemDropdown.click();
        await page.keyboard.type('E2E Rice', { delay: 50 });
        await page.keyboard.press('Enter');
      }
    }
    console.log('[Spec] Item selected.');

    // Enter quantity using Flutter input helper
    await typeFlutterInput(page, 'Quantity', '10.5');

    // Submit form
    const submitBtn = page.locator('button:has-text("Save")').or(
      page.locator('button:has-text("Submit")').or(
        page.locator('button:has-text("Create")').or(
          page.locator('[aria-label="stock-submit"]')
        )
      )
    ).first();
    await submitBtn.click();
    console.log('[Spec] Stock entry submitted.');
    
    await expectSuccess(page);
    console.log('[Spec] Stock entry created successfully.');

    // --- Edit Stock Entry ---
    await page.waitForTimeout(1500); // Wait for list refresh
    
    // Find the row with our item
    const row = page.locator('text=E2E Rice').first();
    await row.waitFor({ state: 'visible', timeout: 10000 });
    
    // Click edit button in that row - try icon or text
    const editBtn = row.locator('xpath=./ancestor::*[contains(@class,"row") or self::tr]//button').filter({ hasText: /edit/i }).or(
      row.locator('..').locator('button:has-text("Edit")').or(
        row.locator('..').locator('[aria-label="edit-stock"]')
      )
    ).first();
    
    await editBtn.click();
    console.log('[Spec] Edit button clicked.');
    
    await page.waitForTimeout(1000);
    await typeFlutterInput(page, 'Quantity', '12.0');
    await submitBtn.click();
    await expectSuccess(page);
    console.log('[Spec] Stock entry edited successfully.');

    // --- Delete Stock Entry ---
    await page.waitForTimeout(1500);
    
    const rowDelete = page.locator('text=E2E Rice').first();
    const deleteBtn = rowDelete.locator('xpath=./ancestor::*[contains(@class,"row") or self::tr]//button').filter({ hasText: /delete/i }).or(
      rowDelete.locator('..').locator('button:has-text("Delete")').or(
        rowDelete.locator('..').locator('[aria-label="delete-stock"]')
      )
    ).first();
    
    await deleteBtn.click();
    console.log('[Spec] Delete button clicked.');
    
    // Confirm deletion
    const confirmBtn = page.locator('button:has-text("Confirm")').or(
      page.locator('button:has-text("Yes")').or(
        page.locator('button:has-text("Delete")').last().or(
          page.locator('[aria-label="confirm-delete"]')
        )
      )
    ).first();
    await confirmBtn.click();
    
    await expectSuccess(page);
    console.log('[Spec] Stock entry deleted successfully.');

    // --- Stability Checks ---
    await expect(page.locator('text=Something went wrong')).toHaveCount(0);
    await expect(page.locator('text=Unauthorized')).toHaveCount(0);
    console.log('[Spec] Stability checks passed.');
  });
});
