# Demo Script

**Goal**: Demonstrate end-to-end functionality in <5 minutes.

## Prerequisites

- Docker and Docker Compose installed
- Python 3.9+ (for simulator)
- Terminal/command line access

## Step-by-Step Demo

### 1. Start Backend Services

```bash
cd refract-iot-mvp
docker compose up -d postgres backend
```

Wait ~10 seconds for services to initialize.

**Verify**:
```bash
curl http://localhost:9000/health
```

Should return: `{"status":"healthy"}`

### 2. Open Web Dashboard

Open browser to: **http://localhost:9000/docs**

This shows the interactive API documentation. You can also access:
- **Swagger UI**: http://localhost:9000/docs
- **ReDoc**: http://localhost:9000/redoc

*(Note: Flutter web dashboard can be run separately with `cd web && flutter run -d chrome`)*

### 3. Start Device Simulator

In a new terminal:

```bash
cd refract-iot-mvp/device/simulator
python3 device_sim.py --device-id demo-001 --interval-seconds 2
```

You should see:
```
🚀 Device Simulator Starting
   Device ID: demo-001
   Server: http://localhost:9000
   Interval: 2s
   ...
  [SENT] 1.3330 RI @ 2024-01-28T...
```

### 4. Verify Readings in API

In another terminal:

```bash
# List devices
curl http://localhost:9000/api/v1/devices | python3 -m json.tool

# Get readings for demo-001
curl "http://localhost:9000/api/v1/devices/demo-001/readings?limit=5" | python3 -m json.tool
```

You should see:
- Device `demo-001` with status "OK"
- Multiple readings with timestamps
- Values in RI or Brix units

### 5. Demonstrate Queue Behavior

**Stop the backend** (simulator will queue readings):

```bash
docker compose stop backend
```

Wait 5-10 seconds. The simulator will show:
```
  [ERROR] Connection failed: ...
  [QUEUED] Reading queued to queue.jsonl
```

**Check the queue**:
```bash
cat device/simulator/queue.jsonl
```

You should see JSON lines with queued readings.

**Restart backend**:
```bash
docker compose start backend
```

**Watch simulator** - it will automatically flush queued readings:
```
  [FLUSH] Attempting to flush 3 queued reading(s)...
  [SENT] 1.3330 RI @ ...
  [FLUSH] All 3 queued readings sent successfully
```

### 6. (Optional) Test C Client

In another terminal:

```bash
cd refract-iot-mvp/device/c-client
make
./refract_client -d demo-002 -v 1.3340 -u RI -t 25.0 -s http://localhost:9000
```

Verify it appears:
```bash
curl http://localhost:9000/api/v1/devices | python3 -m json.tool
```

### 7. Demonstrate Idempotency

Send a reading with an `event_id`:

```bash
curl -X POST http://localhost:9000/api/v1/readings \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "demo-003",
    "ts": "2024-01-28T15:40:00Z",
    "value": 1.3350,
    "unit": "RI",
    "event_id": "550e8400-e29b-41d4-a716-446655440000"
  }' | python3 -m json.tool
```

Note the returned `id`. Send the **same request again** (same `event_id`):

```bash
curl -X POST http://localhost:9000/api/v1/readings \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "demo-003",
    "ts": "2024-01-28T15:41:00Z",
    "value": 1.3360,
    "unit": "RI",
    "event_id": "550e8400-e29b-41d4-a716-446655440000"
  }' | python3 -m json.tool
```

The `id` should be **the same** - demonstrating idempotency.

### 8. Show Validation

Test invalid input:

```bash
curl -X POST http://localhost:9000/api/v1/readings \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "demo-004",
    "ts": "2024-01-28T15:40:00Z",
    "value": 3.0,
    "unit": "RI"
  }'
```

Should return HTTP 400 with error: `"Refractive index value 3.0 out of range [1.0, 2.0]"`

## Demo Summary

✅ **What was demonstrated**:
1. Backend API running and healthy
2. Device simulator sending readings on schedule
3. Queue behavior when backend is unavailable
4. Automatic queue flush on reconnect
5. Idempotency via `event_id`
6. Input validation
7. C client integration (optional)

**Total time**: ~5 minutes

## Next Steps for Reviewer

- Explore API docs: http://localhost:9000/docs
- Review architecture: [docs/architecture.md](./architecture.md)
- Check API contract: [docs/api_contract.md](./api_contract.md)
- Run full test suite: `./test_api.sh`
