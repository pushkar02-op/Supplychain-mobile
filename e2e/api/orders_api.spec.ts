import { expect, test } from '@playwright/test';

test('Backend availability - GET /v1/orders/', async ({ request }) => {
  console.log('Inside API test');
  const response = await request.get('http://127.0.0.1:8000/v1/orders/?warehouse_id=1');
  expect(response.status()).toBe(200);
});
