/**
 * Ledger Assertion Layer
 * 
 * Business-logic verification via backend API.
 * Uses ledger endpoints to verify inventory deltas, idempotency, and quantity correctness.
 * 
 * RULES:
 * - All assertions are READ-ONLY against backend
 * - Never bypass API for direct DB access
 * - Snapshots must be taken BEFORE and AFTER actions
 */

import { APIRequestContext, expect } from '@playwright/test';

const BACKEND_URL = 'http://localhost:8000';

/**
 * Ledger health snapshot for before/after comparisons.
 */
export interface LedgerSnapshot {
  status: 'healthy' | 'warning';
  totalBatches: number;
  driftedBatches: number;
  negativeBatches: number;
  unhealthyRecords: number;
  timestamp: number;
}

/**
 * Expected delta for ledger comparison.
 */
export interface LedgerDelta {
  /** Expected change in total batches (positive = new batches) */
  batchesDelta?: number;
  /** If true, assert no new drift occurred */
  noNewDrift?: boolean;
  /** If true, assert no new negative stock */
  noNewNegative?: boolean;
}

/**
 * Capture current ledger state via backend API.
 * 
 * @param request - Playwright API request context
 * @returns Current ledger snapshot
 */
export async function takeLedgerSnapshot(
  request: APIRequestContext
): Promise<LedgerSnapshot> {
  console.log('[Ledger] Taking snapshot...');
  
  const response = await request.get(`${BACKEND_URL}/admin/ledger/health`);
  
  if (!response.ok()) {
    const text = await response.text();
    throw new Error(`[Ledger] Failed to get health: ${response.status()} - ${text}`);
  }
  
  const data = await response.json();
  
  const snapshot: LedgerSnapshot = {
    status: data.status,
    totalBatches: data.total_batches,
    driftedBatches: data.drifted_batches,
    negativeBatches: data.negative_stock_batches,
    unhealthyRecords: data.unhealthy_records,
    timestamp: Date.now(),
  };
  
  console.log(`[Ledger] Snapshot: ${snapshot.totalBatches} batches, ${snapshot.driftedBatches} drifted, ${snapshot.negativeBatches} negative`);
  
  return snapshot;
}

/**
 * Assert ledger delta between two snapshots.
 * 
 * @param before - Snapshot taken before action
 * @param after - Snapshot taken after action
 * @param expected - Expected delta values
 */
export async function assertLedgerDelta(
  before: LedgerSnapshot,
  after: LedgerSnapshot,
  expected: LedgerDelta
): Promise<void> {
  console.log('[Ledger] Asserting delta...');
  
  // Assert batch count delta
  if (expected.batchesDelta !== undefined) {
    const actualDelta = after.totalBatches - before.totalBatches;
    console.log(`[Ledger] Batches delta: expected ${expected.batchesDelta}, actual ${actualDelta}`);
    expect(actualDelta).toBe(expected.batchesDelta);
  }
  
  // Assert no new drift
  if (expected.noNewDrift) {
    const driftDelta = after.driftedBatches - before.driftedBatches;
    console.log(`[Ledger] Drift delta: ${driftDelta}`);
    expect(driftDelta).toBeLessThanOrEqual(0);
  }
  
  // Assert no new negative
  if (expected.noNewNegative) {
    const negativeDelta = after.negativeBatches - before.negativeBatches;
    console.log(`[Ledger] Negative delta: ${negativeDelta}`);
    expect(negativeDelta).toBeLessThanOrEqual(0);
  }
  
  console.log('[Ledger] Delta assertion passed');
}

/**
 * Verify idempotency: execute action twice and assert no ledger change on second run.
 * 
 * @param action - Async function to execute (will be called twice)
 * @param request - Playwright API request context
 * @returns Result from first action execution
 */
export async function assertIdempotency<T>(
  action: () => Promise<T>,
  request: APIRequestContext
): Promise<T> {
  console.log('[Ledger] Testing idempotency...');
  
  // First execution
  const snapshotBefore1 = await takeLedgerSnapshot(request);
  const result = await action();
  const snapshotAfter1 = await takeLedgerSnapshot(request);
  
  console.log(`[Ledger] First run: ${snapshotAfter1.totalBatches - snapshotBefore1.totalBatches} batch delta`);
  
  // Second execution
  const snapshotBefore2 = await takeLedgerSnapshot(request);
  await action();
  const snapshotAfter2 = await takeLedgerSnapshot(request);
  
  // Second execution should have zero delta
  const deltaOnSecond = snapshotAfter2.totalBatches - snapshotBefore2.totalBatches;
  console.log(`[Ledger] Second run delta: ${deltaOnSecond} (should be 0 for idempotent operations)`);
  
  expect(deltaOnSecond).toBe(0);
  console.log('[Ledger] Idempotency verified');
  
  return result;
}

/**
 * Assert a specific batch has expected quantity via API.
 * 
 * @param request - Playwright API request context
 * @param batchId - ID of the batch to check
 * @param expectedQuantity - Expected quantity value
 */
export async function assertBatchQuantity(
  request: APIRequestContext,
  batchId: number,
  expectedQuantity: number
): Promise<void> {
  console.log(`[Ledger] Checking batch ${batchId} quantity...`);
  
  const response = await request.get(`${BACKEND_URL}/v1/batch/${batchId}`);
  
  if (!response.ok()) {
    const text = await response.text();
    throw new Error(`[Ledger] Failed to get batch ${batchId}: ${response.status()} - ${text}`);
  }
  
  const batch = await response.json();
  const actualQuantity = parseFloat(batch.quantity);
  
  console.log(`[Ledger] Batch ${batchId}: expected ${expectedQuantity}, actual ${actualQuantity}`);
  expect(actualQuantity).toBeCloseTo(expectedQuantity, 4);
  
  console.log('[Ledger] Quantity assertion passed');
}

/**
 * Assert ledger is in healthy state (no drift, no negative).
 * 
 * @param request - Playwright API request context
 */
export async function assertLedgerHealthy(
  request: APIRequestContext
): Promise<void> {
  console.log('[Ledger] Checking health...');
  
  const snapshot = await takeLedgerSnapshot(request);
  
  expect(snapshot.status).toBe('healthy');
  expect(snapshot.driftedBatches).toBe(0);
  expect(snapshot.negativeBatches).toBe(0);
  
  console.log('[Ledger] Ledger is healthy');
}

/**
 * Get detailed reconciliation report for debugging.
 * 
 * @param request - Playwright API request context
 * @returns Array of drift records
 */
export async function getLedgerReconcileReport(
  request: APIRequestContext
): Promise<any[]> {
  console.log('[Ledger] Fetching reconcile report...');
  
  const response = await request.get(`${BACKEND_URL}/admin/ledger/reconcile`);
  
  if (!response.ok()) {
    const text = await response.text();
    throw new Error(`[Ledger] Failed to get reconcile report: ${response.status()} - ${text}`);
  }
  
  const report = await response.json();
  console.log(`[Ledger] Reconcile report: ${report.length} records`);
  
  return report;
}
