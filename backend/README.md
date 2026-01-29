# Backend API

FastAPI service for refractometry telemetry ingestion and device management.

## Data Model

### Tables

**devices**
- `device_id` (VARCHAR(255), PK): Device identifier
- `name` (VARCHAR(255)): Human-readable name
- `last_seen_at` (TIMESTAMP): Last reading timestamp
- `created_at` (TIMESTAMP): Record creation time

**readings**
- `id` (SERIAL, PK): Auto-increment primary key
- `device_id` (VARCHAR(255), FK): References devices.device_id
- `ts` (TIMESTAMP): Reading timestamp
- `value` (NUMERIC(10,4)): Reading value (4 decimal places)
- `unit` (VARCHAR(50)): "RI" or "Brix"
- `temperature_c` (NUMERIC(5,2)): Temperature in Celsius (nullable)
- `event_id` (UUID): Unique event ID for idempotency (nullable, unique)
- `created_at` (TIMESTAMP): Record creation time

### Migrations

Database schema is auto-created on startup via SQLAlchemy. For manual migrations:

```bash
# Apply schema manually
docker compose exec postgres psql -U refract -d refract_iot -f /app/app/db/schema.sql
```

Or use Alembic (future):
```bash
alembic upgrade head
```

## Endpoints

### POST /api/v1/readings

Ingest a device reading.

**Example**:
```bash
curl -X POST http://localhost:9000/api/v1/readings \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "DEV001",
    "ts": "2024-01-28T15:40:00Z",
    "value": 1.3330,
    "unit": "RI",
    "temperature_c": 25.0,
    "event_id": "550e8400-e29b-41d4-a716-446655440000"
  }'
```

**Response** (201 Created):
```json
{
  "id": 123,
  "device_id": "DEV001",
  "ts": "2024-01-28T15:40:00Z",
  "value": 1.3330,
  "unit": "RI",
  "temperature_c": 25.0,
  "event_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

### GET /api/v1/devices

List all devices with status and latest reading.

**Example**:
```bash
curl http://localhost:9000/api/v1/devices
```

**Response** (200 OK):
```json
{
  "devices": [
    {
      "device_id": "DEV001",
      "name": "Device DEV001",
      "last_seen_at": "2024-01-28T15:40:00Z",
      "status": "OK",
      "latest_reading": {
        "value": 1.3330,
        "unit": "RI",
        "ts": "2024-01-28T15:40:00Z"
      }
    }
  ]
}
```

### GET /api/v1/devices/{device_id}/readings

Get reading history for a device.

**Example**:
```bash
curl "http://localhost:9000/api/v1/devices/DEV001/readings?limit=100"
```

**Response** (200 OK):
```json
{
  "device_id": "DEV001",
  "readings": [
    {
      "id": 123,
      "ts": "2024-01-28T15:40:00Z",
      "value": 1.3330,
      "unit": "RI",
      "temperature_c": 25.0
    }
  ]
}
```

### GET /health

Health check endpoint.

**Example**:
```bash
curl http://localhost:9000/health
```

**Response** (200 OK):
```json
{"status": "healthy"}
```

## Authentication

### API Key (Optional)

For local demo, authentication is **disabled by default**. To enable:

1. Set environment variables:
   ```bash
   export API_KEY=your-secret-key
   export API_KEY_REQUIRED=true
   ```

2. Or in `.env`:
   ```
   API_KEY=your-secret-key
   API_KEY_REQUIRED=true
   ```

3. Include header in requests:
   ```bash
   curl -X POST http://localhost:9000/api/v1/readings \
     -H "X-API-Key: your-secret-key" \
     -H "Content-Type: application/json" \
     -d '{...}'
   ```

**For local demo**: Leave `API_KEY_REQUIRED=false` (default) to skip authentication.

## Idempotency

The API supports idempotent requests via `event_id`:

1. **First request** with a given `event_id`: Creates new reading, returns 201
2. **Subsequent requests** with same `event_id`: Returns existing reading (same `id`), no duplicate

**Recommendation**: Always include `event_id` (UUID) in device readings to enable safe retries.

**Example**:
```bash
# First request
curl -X POST http://localhost:9000/api/v1/readings \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "DEV001",
    "ts": "2024-01-28T15:40:00Z",
    "value": 1.3330,
    "unit": "RI",
    "event_id": "550e8400-e29b-41d4-a716-446655440000"
  }'
# Returns: {"id": 123, ...}

# Duplicate request (same event_id)
curl -X POST http://localhost:9000/api/v1/readings \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "DEV001",
    "ts": "2024-01-28T15:41:00Z",
    "value": 1.3340,
    "unit": "RI",
    "event_id": "550e8400-e29b-41d4-a716-446655440000"
  }'
# Returns: {"id": 123, ...} (same ID, original reading)
```

## Status Logic

Device status is calculated based on `last_seen_at`:

- **OK**: Seen within last 15 minutes
- **STALE**: Seen within last 24 hours but > 15 minutes ago
- **OFFLINE**: Not seen in last 24 hours or never

Implemented in `app/services/device_service.py`:
```python
def get_device_status(last_seen_at: Optional[datetime]) -> str:
    if not last_seen_at:
        return "OFFLINE"
    
    age = datetime.utcnow() - last_seen_at
    
    if age < timedelta(minutes=15):
        return "OK"
    elif age < timedelta(hours=24):
        return "STALE"
    else:
        return "OFFLINE"
```

## Observability

### Structured Logging

Logs are output in JSON format (when configured):

```json
{
  "timestamp": "2024-01-28T15:40:00Z",
  "level": "INFO",
  "message": "Reading ingested",
  "device_id": "DEV001",
  "reading_id": 123
}
```

### Request ID Correlation

Request IDs can be added via middleware (future enhancement). Currently, use `event_id` for correlation.

### Log Levels

- **INFO**: Normal operations (reading ingestion, device queries)
- **WARNING**: Validation errors, retries
- **ERROR**: Database errors, connection failures

## OpenAPI Specification

Interactive API documentation:

- **Swagger UI**: http://localhost:9000/docs
- **ReDoc**: http://localhost:9000/redoc
- **OpenAPI JSON**: http://localhost:9000/openapi.json

The OpenAPI spec is auto-generated from FastAPI route definitions and Pydantic models.

## Development

### Local Development

```bash
# Install dependencies
pip install -r requirements.txt

# Set environment
export DATABASE_URL=postgresql://refract:refract_dev@localhost:5432/refract_iot

# Run with hot reload
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### Docker Development

```bash
docker compose up -d postgres backend
docker compose logs -f backend
```

### Testing

```bash
# Run test suite
cd ..
./test_api.sh

# Manual testing
curl http://localhost:9000/health
curl http://localhost:9000/api/v1/devices
```

## See Also

- [API Contract](../docs/api_contract.md) - Complete API specification
- [Architecture](../docs/architecture.md) - System design
- [Demo Script](../docs/demo_script.md) - End-to-end demo
