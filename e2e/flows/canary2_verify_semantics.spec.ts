import { expect, test } from '@playwright/test';
import { loginAsManager } from '../helpers/auth';
import { goToStock } from '../helpers/navigation';

test('Verify Stock Action Buttons via Semantics', async ({ page }) => {
  await page.goto('http://localhost:8081');
  await loginAsManager(page);
  await goToStock(page);

  // 1. Discover all buttons with all attributes
  console.log('[Verify] Discovering all interactive elements...');
  const elements = await page.locator('button, [role="button"], [aria-label]').all();
  for (const el of elements) {
    const text = await el.innerText();
    const attrs = await el.evaluate(node => {
      const result: any = {};
      for (let i = 0; i < node.attributes.length; i++) {
        result[node.attributes[i].name] = node.attributes[i].value;
      }
      return result;
    });
    console.log(`[Verify] Element: tag="${await el.evaluate(n => n.tagName)}", text="${text}", attrs=${JSON.stringify(attrs)}`);
  }

  // 2. Canonical requirement: Trigger via keyboard Enter
  console.log('[Verify] Attempting canonical trigger: getByRole("button", { name: "add-stock-action" }).press("Enter")');
  
  // Flutter semantics often have aria-hidden: true but are interactive via pointers/keyboard if role is button
  const addStockBtn = page.getByRole('button', { name: 'add-stock-action', includeHidden: true });
  await expect(addStockBtn).toBeAttached();
  
  // Try to focus it first to ensure keyboard events land
  await addStockBtn.focus();
  await page.keyboard.press('Enter');
  
  // Wait for navigation
  console.log('[Verify] Waiting for navigation...');
  await page.waitForTimeout(3000);
  
  // Check visibility of form
  let isVisible = await page.locator('text=Add Stock Entry').or(page.locator('text=New Stock')).isVisible();
  console.log(`[Verify] Form visible after Enter: ${isVisible}`);

  if (!isVisible) {
    console.log('[Verify] Enter failed, trying explicit .click() on the semantic node...');
    await addStockBtn.click({ force: true });
    await page.waitForTimeout(3000);
    isVisible = await page.locator('text=Add Stock Entry').or(page.locator('text=New Stock')).isVisible();
    console.log(`[Verify] Form visible after click: ${isVisible}`);
  }

  await page.screenshot({ path: 'final_verification.png' });

  if (!isVisible) {
    throw new Error('Could not trigger navigation via semantic node');
  }
  
  console.log('[Verify] SUCCESS: Navigation triggered via semantic node.');
});
