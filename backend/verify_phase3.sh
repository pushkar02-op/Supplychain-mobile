#!/bin/bash
set -e

BASE_URL="http://localhost:8000/v1"
echo "=== Phase 3 Idempotency Verification Script ==="
echo "Date: $(date)"
echo ""

# Step 0: Register and Login
echo "--- SETUP: Register & Login ---"
curl -s -X POST "$BASE_URL/register" \
  -H "Content-Type: application/json" \
  -d '{"username":"idem_tester","email":"idem@test.com","password":"Password123!","full_name":"Idem Tester","role":"admin"}' || true

TOKEN=$(curl -s -X POST "$BASE_URL/login" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=idem_tester&password=Password123!" | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
  echo "FATAL: Failed to get token"
  exit 1
fi
echo "Token acquired successfully."

# Step 1: Create test item
echo ""
echo "--- SETUP: Create Test Item ---"
ITEM_RESPONSE=$(curl -s -X POST "$BASE_URL/item/" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"name":"VerifyItem_'$(date +%s)'"}')
ITEM_ID=$(echo $ITEM_RESPONSE | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
echo "Created Item ID: $ITEM_ID"

if [ -z "$ITEM_ID" ]; then
  echo "FATAL: Failed to create item. Response: $ITEM_RESPONSE"
  exit 1
fi

# Payload for stock entry
PAYLOAD='{"item_id":'$ITEM_ID',"quantity":100,"unit":"kg","received_date":"2025-12-24","price_per_unit":10.0,"total_cost":1000.0}'
echo "Payload: $PAYLOAD"

echo ""
echo "========================================"
echo "SCENARIO 1: Missing Idempotency Key"
echo "========================================"
echo "Calling POST /stock-entry/ WITHOUT Idempotency-Key header"
RESP1=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/stock-entry/" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "$PAYLOAD")
HTTP_CODE1=$(echo "$RESP1" | tail -n1)
BODY1=$(echo "$RESP1" | sed '$d')
echo "HTTP Code: $HTTP_CODE1"
echo "Response: $BODY1"
if [ "$HTTP_CODE1" == "400" ]; then
  echo "SCENARIO 1: PASS (400 returned as expected)"
else
  echo "SCENARIO 1: FAIL (Expected 400, got $HTTP_CODE1)"
fi

echo ""
echo "========================================"
echo "SCENARIO 2: Happy Path (New Key K1)"
echo "========================================"
KEY1="idem-key-$(date +%s)-1"
echo "Using Idempotency-Key: $KEY1"
RESP2=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/stock-entry/" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Idempotency-Key: $KEY1" \
  -d "$PAYLOAD")
HTTP_CODE2=$(echo "$RESP2" | tail -n1)
BODY2=$(echo "$RESP2" | sed '$d')
echo "HTTP Code: $HTTP_CODE2"
echo "Response: $BODY2"
ENTRY_ID=$(echo $BODY2 | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
echo "Created StockEntry ID: $ENTRY_ID"
if [ "$HTTP_CODE2" == "201" ] || [ "$HTTP_CODE2" == "200" ]; then
  echo "SCENARIO 2: PASS (Success)"
else
  echo "SCENARIO 2: FAIL (Expected 201/200, got $HTTP_CODE2)"
fi

echo ""
echo "========================================"
echo "SCENARIO 3: Replay (Same Key K1, Same Payload)"
echo "========================================"
echo "Replaying with Idempotency-Key: $KEY1"
RESP3=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/stock-entry/" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Idempotency-Key: $KEY1" \
  -d "$PAYLOAD")
HTTP_CODE3=$(echo "$RESP3" | tail -n1)
BODY3=$(echo "$RESP3" | sed '$d')
echo "HTTP Code: $HTTP_CODE3"
echo "Response: $BODY3"
REPLAY_ID=$(echo $BODY3 | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
echo "Returned StockEntry ID: $REPLAY_ID"
if [ "$HTTP_CODE3" == "201" ] || [ "$HTTP_CODE3" == "200" ]; then
  if [ "$ENTRY_ID" == "$REPLAY_ID" ]; then
    echo "SCENARIO 3: PASS (Same entity returned)"
  else
    echo "SCENARIO 3: FAIL (IDs differ: $ENTRY_ID vs $REPLAY_ID)"
  fi
else
  echo "SCENARIO 3: FAIL (Expected 201/200, got $HTTP_CODE3)"
fi

echo ""
echo "========================================"
echo "SCENARIO 4: Conflict (Same Key K1, Different Payload)"
echo "========================================"
PAYLOAD_DIFF='{"item_id":'$ITEM_ID',"quantity":999,"unit":"kg","received_date":"2025-12-24","price_per_unit":10.0,"total_cost":9990.0}'
echo "Using modified payload with quantity=999"
RESP4=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/stock-entry/" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Idempotency-Key: $KEY1" \
  -d "$PAYLOAD_DIFF")
HTTP_CODE4=$(echo "$RESP4" | tail -n1)
BODY4=$(echo "$RESP4" | sed '$d')
echo "HTTP Code: $HTTP_CODE4"
echo "Response: $BODY4"
if [ "$HTTP_CODE4" == "409" ]; then
  echo "SCENARIO 4: PASS (409 Conflict returned)"
else
  echo "SCENARIO 4: FAIL (Expected 409, got $HTTP_CODE4)"
fi

echo ""
echo "========================================"
echo "SCENARIO 5: Legitimate Repeat (New Key K2, Same Payload)"
echo "========================================"
KEY2="idem-key-$(date +%s)-2"
echo "Using new Idempotency-Key: $KEY2"
RESP5=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/stock-entry/" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Idempotency-Key: $KEY2" \
  -d "$PAYLOAD")
HTTP_CODE5=$(echo "$RESP5" | tail -n1)
BODY5=$(echo "$RESP5" | sed '$d')
echo "HTTP Code: $HTTP_CODE5"
echo "Response: $BODY5"
NEW_ENTRY_ID=$(echo $BODY5 | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
echo "Created NEW StockEntry ID: $NEW_ENTRY_ID"
if [ "$HTTP_CODE5" == "201" ] || [ "$HTTP_CODE5" == "200" ]; then
  if [ "$ENTRY_ID" != "$NEW_ENTRY_ID" ]; then
    echo "SCENARIO 5: PASS (New entity created)"
  else
    echo "SCENARIO 5: FAIL (Same ID returned - should be new)"
  fi
else
  echo "SCENARIO 5: FAIL (Expected 201/200, got $HTTP_CODE5)"
fi

echo ""
echo "=== Verification Script Complete ==="
