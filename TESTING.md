# Testing Guide

## Quick Start

### 1. Start Services

```bash
docker compose up -d postgres backend
```

Wait ~10 seconds for services to initialize, then verify:

```bash
curl http://localhost:9000/health
```

Should return: `{"status":"healthy"}`

### 2. Run Automated Tests

```bash
./test_api.sh
```

This runs comprehensive API tests covering:
- Health checks
- Reading creation (RI and Brix units)
- Idempotency (event_id)
- Validation errors
- Device listing
- Reading history queries
- Time series data

## Manual Testing Commands

### Health Check

```bash
curl http://localhost:9000/health
```

### Create a Reading (RI unit)

```bash
curl -X POST http://localhost:9000/api/v1/readings \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "DEV001",
    "ts": "2024-01-28T15:40:00Z",
    "value": 1.3330,
    "unit": "RI",
    "temperature_c": 25.0
  }' | python3 -m json.tool
```

### Create a Reading (Brix unit)

```bash
curl -X POST http://localhost:9000/api/v1/readings \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "DEV002",
    "ts": "2024-01-28T15:40:00Z",
    "value": 12.5,
    "unit": "Brix",
    "temperature_c": 20.0
  }' | python3 -m json.tool
```

### Test Idempotency (event_id)

```bash
# First request
curl -X POST http://localhost:9000/api/v1/readings \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "DEV003",
    "ts": "2024-01-28T15:40:00Z",
    "value": 1.3340,
    "unit": "RI",
    "event_id": "550e8400-e29b-41d4-a716-446655440000"
  }' | python3 -m json.tool

# Duplicate request (same event_id) - should return same reading
curl -X POST http://localhost:9000/api/v1/readings \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "DEV003",
    "ts": "2024-01-28T15:41:00Z",
    "value": 1.3350,
    "unit": "RI",
    "event_id": "550e8400-e29b-41d4-a716-446655440000"
  }' | python3 -m json.tool
```

### List All Devices

```bash
curl http://localhost:9000/api/v1/devices | python3 -m json.tool
```

### Get Device Readings

```bash
curl "http://localhost:9000/api/v1/devices/DEV001/readings?limit=10" | python3 -m json.tool
```

### Test Validation Errors

**Invalid unit:**
```bash
curl -X POST http://localhost:9000/api/v1/readings \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "DEV004",
    "ts": "2024-01-28T15:40:00Z",
    "value": 1.33,
    "unit": "INVALID"
  }'
```

**Value out of range (RI):**
```bash
curl -X POST http://localhost:9000/api/v1/readings \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "DEV005",
    "ts": "2024-01-28T15:40:00Z",
    "value": 3.0,
    "unit": "RI"
  }'
```

**Value out of range (Brix):**
```bash
curl -X POST http://localhost:9000/api/v1/readings \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "DEV006",
    "ts": "2024-01-28T15:40:00Z",
    "value": 150.0,
    "unit": "Brix"
  }'
```

### Test Non-existent Device

```bash
curl http://localhost:9000/api/v1/devices/NONEXISTENT/readings
```

Should return: `{"detail":"Device not found"}` with HTTP 404

## Test C Device Client

### Build the client

```bash
cd device/c-client
make
```

### Send a reading

```bash
./refract_client -d TEST001 -v 1.3330 -u RI -t 25.0 -s http://localhost:9000
```

### Test offline queue

```bash
# Stop backend
docker compose stop backend

# Send reading (will queue)
./refract_client -d TEST002 -v 1.3340 -u RI -t 26.0 -s http://localhost:9000

# Check queue file
cat queue.log

# Start backend
docker compose start backend

# Flush queue
./refract_client -f -s http://localhost:9000
```

## API Documentation

Interactive API documentation available at:
- **Swagger UI**: http://localhost:9000/docs
- **ReDoc**: http://localhost:9000/redoc

## Schema Validation

### Database Schema Alignment

✅ **Verified**: Database models match SQL schema:
- `devices` table: `device_id` (PK), `name`, `last_seen_at`, `created_at`
- `readings` table: `id` (PK), `device_id` (FK), `ts`, `value`, `unit`, `temperature_c`, `event_id`, `created_at`
- Indexes: `(device_id, ts DESC)`, `event_id` (unique, partial)

### API Contract Alignment

✅ **Verified**: API implementation matches contract:
- `POST /api/v1/readings` - Accepts all required fields, validates, enforces idempotency
- `GET /api/v1/devices` - Returns devices with status and latest reading
- `GET /api/v1/devices/{id}/readings` - Returns time-series data with limit parameter
- `GET /health` - Returns health status

### Parameter Matching

✅ **Verified**: Backend ↔ Database parameter alignment:
- `device_id`: String(255) in both API and DB
- `ts`: DateTime in API, TIMESTAMP in DB
- `value`: float in API, NUMERIC(10,4) in DB
- `unit`: str in API, VARCHAR(50) in DB
- `temperature_c`: Optional[float] in API, NUMERIC(5,2) nullable in DB
- `event_id`: Optional[UUID] in API, UUID nullable unique in DB

## Type Safety

✅ **Verified**: Type checking passes:
- Pydantic models validate input types
- SQLAlchemy models match database types
- Response serialization handles nullable fields correctly
- Numeric types properly converted (Numeric → float)

## Test Results Summary

| Test | Status | Notes |
|------|--------|-------|
| Health Check | ✅ PASS | Returns `{"status":"healthy"}` |
| POST Reading (RI) | ✅ PASS | Creates reading, returns 201 |
| POST Reading (Brix) | ✅ PASS | Creates reading, returns 201 |
| Idempotency | ✅ PASS | Same event_id returns existing reading |
| Validation (invalid unit) | ✅ PASS | Returns 400 with error message |
| Validation (out of range) | ✅ PASS | Returns 400 with error message |
| GET Devices | ✅ PASS | Returns device list with status |
| GET Device Readings | ✅ PASS | Returns time-series data |
| 404 Handling | ✅ PASS | Returns 404 for non-existent device |
| Time Series | ✅ PASS | Multiple readings ordered by timestamp |

## Troubleshooting

### Backend not starting
```bash
docker compose logs backend
```

### Database connection issues
```bash
docker compose logs postgres
```

### Port conflicts
Edit `docker-compose.yml` to change port mapping:
```yaml
ports:
  - "9000:8000"  # Change 9000 to available port
```

### Clear database and restart
```bash
docker compose down -v
docker compose up -d postgres backend
```
