# Runbook

Operational procedures for the Refractometry IoT MVP.

## Start Services

```bash
docker compose up -d postgres backend
```

Wait ~10 seconds, then verify:
```bash
curl http://localhost:9000/health
```

## Stop Services

```bash
docker compose stop
```

Or to stop and remove containers:
```bash
docker compose down
```

## View Logs

**Backend logs**:
```bash
docker compose logs -f backend
```

**PostgreSQL logs**:
```bash
docker compose logs -f postgres
```

**All services**:
```bash
docker compose logs -f
```

## Reset Database

**WARNING**: This deletes all data.

```bash
# Stop services
docker compose down

# Remove volume (deletes all data)
docker volume rm refract-iot-mvp_postgres_data

# Restart
docker compose up -d postgres backend
```

## Seed Test Device

Create a device with initial readings:

```bash
# Create device with reading
curl -X POST http://localhost:9000/api/v1/readings \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "seed-001",
    "ts": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",
    "value": 1.3330,
    "unit": "RI",
    "temperature_c": 25.0
  }'

# Create multiple readings for time series
for i in {1..10}; do
  curl -X POST http://localhost:9000/api/v1/readings \
    -H "Content-Type: application/json" \
    -d "{
      \"device_id\": \"seed-001\",
      \"ts\": \"$(date -u -v-${i}M +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d "${i} minutes ago" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")\",
      \"value\": $((13330 + i * 10))e-4,
      \"unit\": \"RI\",
      \"temperature_c\": $((25 + i))
    }" > /dev/null
done

echo "Created 10 readings for seed-001"
```

## Verify System Health

**Health check**:
```bash
curl http://localhost:9000/health
```

**List devices**:
```bash
curl http://localhost:9000/api/v1/devices | python3 -m json.tool
```

**Database connection** (from host):
```bash
docker compose exec postgres psql -U refract -d refract_iot -c "SELECT COUNT(*) FROM devices;"
```

**Backend API docs**:
- http://localhost:9000/docs
- http://localhost:9000/redoc

## Common Operations

### Check Queue Status

**Simulator queue**:
```bash
wc -l device/simulator/queue.jsonl
cat device/simulator/queue.jsonl | tail -5
```

**C client queue**:
```bash
wc -l device/c-client/queue.log
cat device/c-client/queue.log | tail -5
```

### Force Queue Flush

**Simulator** (restart with existing queue):
```bash
cd device/simulator
python3 device_sim.py --device-id demo-001 --interval-seconds 900
# Will flush on startup
```

**C client**:
```bash
cd device/c-client
./refract_client -f -s http://localhost:9000
```

### Monitor Reading Ingestion

**Watch device list**:
```bash
watch -n 2 'curl -s http://localhost:9000/api/v1/devices | python3 -m json.tool'
```

**Watch backend logs**:
```bash
docker compose logs -f backend | grep -E "POST|reading|device"
```

### Check Database Size

```bash
docker compose exec postgres psql -U refract -d refract_iot -c "
SELECT 
  pg_size_pretty(pg_database_size('refract_iot')) as db_size,
  (SELECT COUNT(*) FROM devices) as device_count,
  (SELECT COUNT(*) FROM readings) as reading_count;
"
```

## Backup and Restore

### Backup Database

```bash
docker compose exec postgres pg_dump -U refract refract_iot > backup_$(date +%Y%m%d_%H%M%S).sql
```

### Restore Database

```bash
# Stop services
docker compose stop postgres

# Remove volume
docker volume rm refract-iot-mvp_postgres_data

# Restart
docker compose up -d postgres

# Wait for startup, then restore
docker compose exec -T postgres psql -U refract -d refract_iot < backup_YYYYMMDD_HHMMSS.sql
```

## Performance Monitoring

### Check Container Resources

```bash
docker stats refract-iot-mvp-backend-1 refract-iot-mvp-postgres-1
```

### Check API Response Times

```bash
time curl -s http://localhost:9000/health
time curl -s http://localhost:9000/api/v1/devices
```

### Database Query Performance

```bash
docker compose exec postgres psql -U refract -d refract_iot -c "
EXPLAIN ANALYZE SELECT * FROM readings 
WHERE device_id = 'demo-001' 
ORDER BY ts DESC 
LIMIT 100;
"
```

## Troubleshooting

See [troubleshooting.md](./troubleshooting.md) for detailed troubleshooting procedures.

## Production Considerations

**Current setup is for development**. For production:

1. **TLS/HTTPS**: Add reverse proxy (Caddy, nginx, ALB)
2. **API Authentication**: Set `API_KEY_REQUIRED=true` and configure `API_KEY`
3. **Database**: Use managed PostgreSQL (RDS, Cloud SQL)
4. **Monitoring**: Add structured logging, metrics, alerts
5. **Backup**: Automated daily backups
6. **Scaling**: Horizontal scaling for API, read replicas for DB

See [architecture.md](./architecture.md) for production deployment architecture.
