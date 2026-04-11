# E2E Testing Rules

This document defines the mandatory patterns for Flutter Web E2E testing in this codebase.

---

## Why Semantics Are Required

Flutter Web renders to a canvas, not a traditional DOM. This creates unique challenges:

1. **No stable DOM structure** - Widget rebuilds change the DOM unpredictably
2. **Gesture detection differs** - Flutter's gesture recognizers need pointer events, not `.click()`
3. **Accessibility layer is stable** - Flutter's `Semantics` widget creates stable, labeled accessibility nodes

**Bottom line**: Semantic labels are the ONLY reliable selectors for Flutter Web.

---

## Forbidden Patterns ❌

### 1. `.click()` calls
```typescript
// ❌ NEVER DO THIS
await page.locator('button').click();
await button.click();
```

**Why**: Flutter gesture detectors may not respond to synthetic click events.  
**Instead**: Use `tapSemanticAction()` or `tapFlutterInkWell()`.

### 2. Raw CSS selectors
```typescript
// ❌ NEVER DO THIS
await page.locator('.my-class').fill('text');
await page.locator('div > span').click();
```

**Why**: DOM structure changes with Flutter rebuilds.  
**Instead**: Use semantic locators: `[aria-label="..."]` or `getByRole()`.

### 3. Index-based selectors
```typescript
// ❌ NEVER DO THIS
await page.locator('button').nth(2).click();
await page.locator('input').first().fill('text');
```

**Why**: Order is not guaranteed after rebuilds.  
**Instead**: Use explicit semantic labels.

### 4. URL-based assertions
```typescript
// ❌ AVOID THIS
expect(page.url()).toContain('/stock');
await page.waitForURL('**/dashboard');
```

**Why**: Deep linking behavior varies; URL may not reflect actual screen.  
**Instead**: Use screen marker text: `expectScreen(page, 'Dashboard')`.

### 5. Hardcoded timeouts for assertions
```typescript
// ❌ AVOID THIS
await page.waitForTimeout(5000);
expect(await element.isVisible()).toBe(true);
```

**Why**: Flaky, doesn't wait for actual state.  
**Instead**: Use Playwright's built-in waiting: `await expect(element).toBeVisible()`.

---

## Required Patterns ✅

### 1. Semantic actions (buttons)
```typescript
import { tapSemanticAction, SEMANTIC_LABELS } from '../helpers/semantics';

// ✅ CORRECT
await tapSemanticAction(page, SEMANTIC_LABELS.ADD_STOCK);

// Or with custom label
await tapSemanticAction(page, 'my-custom-action');
```

### 2. Screen verification
```typescript
import { expectScreen, SCREEN_MARKERS } from '../helpers/assertions';

// ✅ CORRECT
await expectScreen(page, SCREEN_MARKERS.DASHBOARD);
await expectScreen(page, 'Add Stock Entry');
```

### 3. Navigation
```typescript
import { navigateTo } from '../helpers/navigation';

// ✅ CORRECT
await navigateTo(page, 'stock');
await navigateTo(page, 'orders');
```

### 4. Text input (Flutter-aware)
```typescript
import { typeFlutterInput } from '../helpers/flutterInput';

// ✅ CORRECT - targets input[aria-label="..."]
await typeFlutterInput(page, 'Quantity', '10.5');
```

### 5. Ledger assertions
```typescript
import { takeLedgerSnapshot, assertLedgerDelta } from '../helpers/ledger';

// ✅ CORRECT
const before = await takeLedgerSnapshot(request);
// ... perform action ...
const after = await takeLedgerSnapshot(request);
await assertLedgerDelta(before, after, { batchesDelta: 1 });
```

---

## How to Add New Screen Tests

### Step 1: Add semantic labels in Flutter

In your Flutter widget:
```dart
Semantics(
  label: 'my-action-button', // stable, test-facing label
  button: true,
  onTap: () => _handleAction(),
  child: ElevatedButton(
    onPressed: () => _handleAction(),
    child: Text('Do Action'),
  ),
)
```

### Step 2: Register the label

In `e2e/helpers/semantics.ts`:
```typescript
export const SEMANTIC_LABELS = {
  // ... existing labels ...
  MY_ACTION: 'my-action-button',
} as const;
```

### Step 3: Use in tests

```typescript
import { tapSemanticAction, SEMANTIC_LABELS } from '../helpers/semantics';

test('My feature test', async ({ page }) => {
  await tapSemanticAction(page, SEMANTIC_LABELS.MY_ACTION);
});
```

### Step 4: Add screen marker (if new screen)

In `e2e/helpers/assertions.ts`:
```typescript
export const SCREEN_MARKERS = {
  // ... existing markers ...
  MY_SCREEN: 'My Screen Title',
} as const;
```

---

## Available Helpers Reference

| Helper | File | Purpose |
|--------|------|---------|
| `tapSemanticAction` | semantics.ts | Trigger button via semantic label |
| `waitForSemanticAction` | semantics.ts | Wait for action to be available |
| `discoverSemanticActions` | semantics.ts | Debug: list all actions on page |
| `navigateTo` | navigation.ts | Navigate to app destination |
| `waitForScreen` | navigation.ts | Wait for screen to load |
| `typeFlutterInput` | flutterInput.ts | Type into Flutter text field |
| `tapFlutterInkWell` | flutterTap.ts | Low-level InkWell tap (fallback) |
| `expectScreen` | assertions.ts | Assert screen by marker |
| `expectSuccessSemantic` | assertions.ts | Assert success state |
| `expectNoError` | assertions.ts | Assert no errors present |
| `takeLedgerSnapshot` | ledger.ts | Capture ledger state |
| `assertLedgerDelta` | ledger.ts | Assert ledger changes |
| `assertIdempotency` | ledger.ts | Verify action is idempotent |
| `loginAsManager` | auth.ts | Login with test credentials |
| `seedRequirements` | seed.ts | Seed test data via API |

---

## Test File Template

```typescript
import { expect, test } from '@playwright/test';
import { loginAsManager } from '../helpers/auth';
import { navigateTo } from '../helpers/navigation';
import { tapSemanticAction, SEMANTIC_LABELS } from '../helpers/semantics';
import { expectScreen, expectNoError, SCREEN_MARKERS } from '../helpers/assertions';
import { takeLedgerSnapshot, assertLedgerDelta } from '../helpers/ledger';

test.describe('Feature Name', () => {
  test('scenario description', async ({ page, request }) => {
    // 1. Login
    await loginAsManager(page);
    
    // 2. Navigate
    await navigateTo(page, 'stock');
    
    // 3. Take snapshot (before)
    const before = await takeLedgerSnapshot(request);
    
    // 4. Perform action
    await tapSemanticAction(page, SEMANTIC_LABELS.ADD_STOCK);
    
    // 5. Verify screen
    await expectScreen(page, SCREEN_MARKERS.STOCK_FORM);
    
    // 6. Verify ledger (after)
    const after = await takeLedgerSnapshot(request);
    await assertLedgerDelta(before, after, { batchesDelta: 1 });
    
    // 7. Stability check
    await expectNoError(page);
  });
});
```
