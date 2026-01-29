#!/bin/bash
# Manual API Testing Script for Refractometry IoT MVP
# Backend should be running on http://localhost:9000

set -e

API_BASE="http://localhost:9000"
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🧪 Testing Refractometry IoT API"
echo "API Base URL: $API_BASE"
echo ""

# Test 1: Health Check
echo -e "${YELLOW}Test 1: Health Check${NC}"
response=$(curl -s "$API_BASE/health")
echo "Response: $response"
if [[ "$response" == *"healthy"* ]]; then
    echo -e "${GREEN}✓ Health check passed${NC}"
else
    echo -e "${RED}✗ Health check failed${NC}"
    exit 1
fi
echo ""

# Test 2: Root endpoint
echo -e "${YELLOW}Test 2: Root Endpoint${NC}"
curl -s "$API_BASE/" | python3 -m json.tool
echo ""

# Test 3: Post a reading (RI unit)
echo -e "${YELLOW}Test 3: POST Reading (RI unit)${NC}"
reading1=$(curl -s -X POST "$API_BASE/api/v1/readings" \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "DEV001",
    "ts": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",
    "value": 1.3330,
    "unit": "RI",
    "temperature_c": 25.0
  }')
echo "$reading1" | python3 -m json.tool
if echo "$reading1" | grep -q "device_id"; then
    echo -e "${GREEN}✓ Reading created successfully${NC}"
else
    echo -e "${RED}✗ Failed to create reading${NC}"
fi
echo ""

# Test 4: Post a reading (Brix unit)
echo -e "${YELLOW}Test 4: POST Reading (Brix unit)${NC}"
reading2=$(curl -s -X POST "$API_BASE/api/v1/readings" \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "DEV002",
    "ts": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",
    "value": 12.5,
    "unit": "Brix",
    "temperature_c": 20.0
  }')
echo "$reading2" | python3 -m json.tool
echo ""

# Test 5: Post with event_id (idempotency test)
echo -e "${YELLOW}Test 5: POST Reading with event_id (Idempotency)${NC}"
event_id="550e8400-e29b-41d4-a716-446655440000"
reading3=$(curl -s -X POST "$API_BASE/api/v1/readings" \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "DEV003",
    "ts": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",
    "value": 1.3340,
    "unit": "RI",
    "event_id": "'$event_id'"
  }')
first_id=$(echo "$reading3" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")
echo "First POST - Reading ID: $first_id"

# Post same event_id again (should return existing)
reading3_dup=$(curl -s -X POST "$API_BASE/api/v1/readings" \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "DEV003",
    "ts": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",
    "value": 1.3350,
    "unit": "RI",
    "event_id": "'$event_id'"
  }')
dup_id=$(echo "$reading3_dup" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")
echo "Duplicate POST - Reading ID: $dup_id"

if [ "$first_id" == "$dup_id" ]; then
    echo -e "${GREEN}✓ Idempotency working (same ID returned)${NC}"
else
    echo -e "${RED}✗ Idempotency failed${NC}"
fi
echo ""

# Test 6: Validation error (invalid unit)
echo -e "${YELLOW}Test 6: Validation Error (Invalid Unit)${NC}"
error_response=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "$API_BASE/api/v1/readings" \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "DEV004",
    "ts": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",
    "value": 1.33,
    "unit": "INVALID"
  }')
http_code=$(echo "$error_response" | grep "HTTP_CODE" | cut -d: -f2)
body=$(echo "$error_response" | grep -v "HTTP_CODE")
echo "HTTP Code: $http_code"
if [ -n "$body" ] && echo "$body" | python3 -m json.tool >/dev/null 2>&1; then
    echo "Response:" 
    echo "$body" | python3 -m json.tool
else
    echo "Response: $body"
fi
if [ "$http_code" == "400" ]; then
    echo -e "${GREEN}✓ Validation error handled correctly${NC}"
else
    echo -e "${RED}✗ Expected 400, got $http_code${NC}"
fi
echo ""

# Test 7: Validation error (value out of range)
echo -e "${YELLOW}Test 7: Validation Error (Value Out of Range)${NC}"
error_response2=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "$API_BASE/api/v1/readings" \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "DEV005",
    "ts": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",
    "value": 3.0,
    "unit": "RI"
  }')
http_code2=$(echo "$error_response2" | grep "HTTP_CODE" | cut -d: -f2)
if [ "$http_code2" == "400" ]; then
    echo -e "${GREEN}✓ Range validation working${NC}"
else
    echo -e "${RED}✗ Range validation failed${NC}"
fi
echo ""

# Test 8: Get all devices
echo -e "${YELLOW}Test 8: GET All Devices${NC}"
devices=$(curl -s "$API_BASE/api/v1/devices")
echo "$devices" | python3 -m json.tool
device_count=$(echo "$devices" | python3 -c "import sys, json; print(len(json.load(sys.stdin)['devices']))")
echo -e "${GREEN}✓ Found $device_count device(s)${NC}"
echo ""

# Test 9: Get device readings
echo -e "${YELLOW}Test 9: GET Device Readings${NC}"
readings=$(curl -s "$API_BASE/api/v1/devices/DEV001/readings?limit=10")
echo "$readings" | python3 -m json.tool
reading_count=$(echo "$readings" | python3 -c "import sys, json; print(len(json.load(sys.stdin)['readings']))")
echo -e "${GREEN}✓ Found $reading_count reading(s) for DEV001${NC}"
echo ""

# Test 10: Get non-existent device
echo -e "${YELLOW}Test 10: GET Non-existent Device${NC}"
not_found=$(curl -s -w "\nHTTP_CODE:%{http_code}" "$API_BASE/api/v1/devices/NONEXISTENT/readings")
http_code3=$(echo "$not_found" | grep "HTTP_CODE" | cut -d: -f2)
if [ "$http_code3" == "404" ]; then
    echo -e "${GREEN}✓ 404 error handled correctly${NC}"
else
    echo -e "${RED}✗ Expected 404, got $http_code3${NC}"
fi
echo ""

# Test 11: Multiple readings for time series
echo -e "${YELLOW}Test 11: Create Multiple Readings for Time Series${NC}"
for i in {1..5}; do
    curl -s -X POST "$API_BASE/api/v1/readings" \
      -H "Content-Type: application/json" \
      -d "{
        \"device_id\": \"DEV001\",
        \"ts\": \"$(date -u -v-${i}M +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d "${i} minutes ago" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")\",
        \"value\": $((13330 + i * 10))e-4,
        \"unit\": \"RI\",
        \"temperature_c\": $((25 + i))
      }" > /dev/null
done
echo -e "${GREEN}✓ Created 5 additional readings${NC}"
echo ""

# Test 12: Verify time series
echo -e "${YELLOW}Test 12: Verify Time Series Data${NC}"
time_series=$(curl -s "$API_BASE/api/v1/devices/DEV001/readings?limit=10")
series_count=$(echo "$time_series" | python3 -c "import sys, json; print(len(json.load(sys.stdin)['readings']))")
echo "Readings in time series: $series_count"
if [ "$series_count" -ge 5 ]; then
    echo -e "${GREEN}✓ Time series data available${NC}"
else
    echo -e "${RED}✗ Expected at least 5 readings${NC}"
fi
echo ""

echo -e "${GREEN}✅ All API tests completed!${NC}"
echo ""
echo "API Documentation: http://localhost:9000/docs"
echo "ReDoc: http://localhost:9000/redoc"
