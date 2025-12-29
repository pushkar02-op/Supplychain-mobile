import { APIRequestContext } from '@playwright/test';

// ... (keep old functions if needed, but we will focus on seedRequirements)

export async function seedRequirements(request: APIRequestContext) {
  // Use provided request context (test fixture)
  
  // 1. Seed User
  const username = 'manager@test.com';
  console.log(`[SEED] Seeding user ${username}...`);
  // Note: request fixture is already bound to baseURL if configured? 
  // If not, we use full URL or ensure baseURL in config. Config has 8080.
  // Wait, config baseURL is 8080 (Flutter Web). Backend is 8000.
  // So we MUST use full URL.
  const backendUrl = 'http://localhost:8000';

  const userRes = await request.post(`${backendUrl}/register`, {
    data: { username, password: 'password', full_name: 'Manager User' }
  });
  
  if (!userRes.ok()) {
    const text = await userRes.text();
    if (!text.includes('already exists') && userRes.status() !== 400) {
       console.error(`[SEED] User seed failed: ${text}`);
       throw new Error(`User seed failed: ${text}`);
    }
    console.log(`[SEED] User ${username} already exists (likely).`);
  } else {
    console.log(`[SEED] User ${username} registered successfully.`);
  }

  // 2. Seed Item
  console.log('[SEED] Seeding item...');
  const itemRes = await request.post(`${backendUrl}/v1/item`, {
    data: { name: 'E2E Rice', uom: 'kg' }
  });

  if (!itemRes.ok()) {
    const text = await itemRes.text();
    if (itemRes.status() === 400 || text.includes('already exists')) {
        console.log('[SEED] Item already exists. Searching...');
        
        // Loop to find item (Pagination workaround)
        let skip = 0;
        const limit = 100;
        let foundId = null;
        
        for (let i = 0; i < 20; i++) { // Check up to 2000 items
            const listRes = await request.get(`${backendUrl}/v1/item/?skip=${skip}&limit=${limit}`);
            if (!listRes.ok()) throw new Error(`Recovery failed: List GET status ${listRes.status()} - ${await listRes.text()}`);
            
            const items = await listRes.json();
            if (items.length === 0) break;
            
            const found = items.find((i: any) => i.name === 'E2E Rice');
            if (found) {
                foundId = found.id;
                break;
            }
            skip += limit;
        }

        if (foundId) {
            console.log(`[SEED] Found existing item ID: ${foundId}`);
            return foundId;
        }
        throw new Error(`Recovery failed: Item 'E2E Rice' not found after scanning ${skip} items.`);
    }
    throw new Error(`Item Seed failed: ${text}`);
  }

  const id = (await itemRes.json()).id;
  console.log('[SEED] Seeding complete.');
  return id;
}
