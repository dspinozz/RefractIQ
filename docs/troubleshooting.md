# Troubleshooting Guide

Common issues and solutions for the Refractometry IoT MVP.

## No Devices Show Up

### Symptoms
- `GET /api/v1/devices` returns empty array
- Dashboard shows no devices

### Checklist

1. **Verify backend is running**:
   ```bash
   curl http://localhost:9000/health
   ```
   Should return `{"status":"healthy"}`

2. **Check if readings were sent**:
   ```bash
   curl http://localhost:9000/api/v1/devices | python3 -m json.tool
   ```

3. **Check backend logs**:
   ```bash
   docker compose logs backend | tail -50
   ```
   Look for errors or validation failures

4. **Verify simulator/client is running**:
   - Check simulator terminal for `[SENT]` messages
   - Check C client output for success messages

5. **Test manual POST**:
   ```bash
   curl -X POST http://localhost:9000/api/v1/readings \
     -H "Content-Type: application/json" \
     -d '{
       "device_id": "test-001",
       "ts": "2024-01-28T15:40:00Z",
       "value": 1.3330,
       "unit": "RI"
     }'
   ```

6. **Check database directly**:
   ```bash
   docker compose exec postgres psql -U refract -d refract_iot -c "SELECT * FROM devices;"
   ```

## Database Connection Errors

### Symptoms
- Backend logs show: `could not connect to server`
- Health check fails
- 500 errors on API calls

### Solutions

1. **Check PostgreSQL is running**:
   ```bash
   docker compose ps postgres
   ```
   Should show "Up" and "healthy"

2. **Check database URL**:
   ```bash
   docker compose exec backend env | grep DATABASE
   ```
   Should be: `postgresql://refract:refract_dev@postgres:5432/refract_iot`

3. **Check PostgreSQL logs**:
   ```bash
   docker compose logs postgres | tail -50
   ```

4. **Restart PostgreSQL**:
   ```bash
   docker compose restart postgres
   ```

5. **Verify network connectivity**:
   ```bash
   docker compose exec backend ping -c 2 postgres
   ```

6. **Reset database** (last resort):
   ```bash
   docker compose down -v
   docker compose up -d postgres backend
   ```

## C Client Build Errors

### Symptoms
- `make` fails
- Missing libcurl errors
- Compilation errors

### Solutions

**Linux (Debian/Ubuntu)**:
```bash
sudo apt-get update
sudo apt-get install build-essential libcurl4-openssl-dev
cd device/c-client
make clean
make
```

**macOS**:
```bash
brew install curl
cd device/c-client
make clean
make
```

**Check libcurl installation**:
```bash
pkg-config --libs libcurl
# Should output: -lcurl
```

**Manual compilation**:
```bash
gcc -Wall -std=c11 -O2 \
  device/c-client/src/main.c \
  device/c-client/src/http_client.c \
  device/c-client/src/queue.c \
  -o refract_client \
  -lcurl
```

## Simulator Cannot Connect

### Symptoms
- Simulator shows `[ERROR] Connection failed`
- Readings not appearing in API

### Solutions

1. **Verify backend URL**:
   ```bash
   curl http://localhost:9000/health
   ```
   If using different port, update `--server-url`

2. **Check backend is accessible**:
   ```bash
   python3 -c "import requests; print(requests.get('http://localhost:9000/health').json())"
   ```

3. **Check firewall/network**:
   - Ensure port 9000 is not blocked
   - Check if backend is bound to `0.0.0.0` (not `127.0.0.1`)

4. **Verify API endpoint**:
   ```bash
   curl -X POST http://localhost:9000/api/v1/readings \
     -H "Content-Type: application/json" \
     -d '{"device_id":"test","ts":"2024-01-28T15:40:00Z","value":1.33,"unit":"RI"}'
   ```

5. **Check for API key requirement**:
   - If `API_KEY_REQUIRED=true`, add `--api-key` to simulator
   - Or disable auth for local demo: `API_KEY_REQUIRED=false`

## Flutter Web Cannot Reach API

### Symptoms
- Dashboard shows "Error loading devices"
- CORS errors in browser console
- Network errors

### Solutions

1. **Check CORS configuration**:
   - Backend should allow `http://localhost:8080` and `http://localhost:3000`
   - Check `backend/app/main.py` CORS settings

2. **Verify API base URL**:
   - Check `web/lib/api/client.dart`:
     ```dart
     ApiClient({this.baseUrl = 'http://localhost:9000'});
     ```
   - Update if backend is on different port

3. **Test API directly**:
   ```bash
   curl http://localhost:9000/api/v1/devices
   ```

4. **Check browser console**:
   - Open DevTools (F12)
   - Look for CORS or network errors
   - Check Network tab for failed requests

5. **Run Flutter with correct base URL**:
   ```bash
   cd web
   flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:9000
   ```

6. **Verify backend CORS headers**:
   ```bash
   curl -v http://localhost:9000/api/v1/devices 2>&1 | grep -i "access-control"
   ```

## Queue Not Flushing

### Symptoms
- Readings queued but not sent
- Queue file grows
- No flush messages

### Solutions

1. **Verify backend is accessible**:
   ```bash
   curl http://localhost:9000/health
   ```

2. **Check queue file**:
   ```bash
   cat device/simulator/queue.jsonl
   # or
   cat device/c-client/queue.log
   ```

3. **Manually test API**:
   ```bash
   # Take first line from queue
   head -1 device/simulator/queue.jsonl | \
     curl -X POST http://localhost:9000/api/v1/readings \
       -H "Content-Type: application/json" \
       -d @-
   ```

4. **Force flush**:
   - **Simulator**: Restart (will flush on startup)
   - **C client**: Run `./refract_client -f -s http://localhost:9000`

5. **Check for validation errors**:
   - Queue may contain invalid readings
   - Check backend logs for validation errors

## Port Already in Use

### Symptoms
- `docker compose up` fails with "port already allocated"
- Cannot bind to port 9000

### Solutions

1. **Find process using port**:
   ```bash
   lsof -i :9000
   # or
   netstat -an | grep 9000
   ```

2. **Kill process** (if safe):
   ```bash
   kill -9 $(lsof -ti :9000)
   ```

3. **Change port in docker-compose.yml**:
   ```yaml
   ports:
     - "9001:8000"  # Change 9001 to available port
   ```

4. **Update API URLs**:
   - Simulator: `--server-url http://localhost:9001`
   - C client: `-s http://localhost:9001`
   - Flutter: Update `baseUrl` in `client.dart`

## Validation Errors

### Symptoms
- POST returns 400 Bad Request
- Error message about invalid unit/value

### Solutions

1. **Check unit value**:
   - Must be exactly `"RI"` or `"Brix"` (case-sensitive)

2. **Check value ranges**:
   - RI: 1.0 to 2.0
   - Brix: 0.0 to 100.0

3. **Check temperature** (if provided):
   - Range: -50.0 to 150.0°C

4. **Check timestamp format**:
   - Must be ISO8601: `2024-01-28T15:40:00Z`

5. **Example valid payload**:
   ```json
   {
     "device_id": "test-001",
     "ts": "2024-01-28T15:40:00Z",
     "value": 1.3330,
     "unit": "RI",
     "temperature_c": 25.0
   }
   ```

## Performance Issues

### Symptoms
- Slow API responses
- High database load
- Container resource exhaustion

### Solutions

1. **Check container resources**:
   ```bash
   docker stats
   ```

2. **Check database indexes**:
   ```bash
   docker compose exec postgres psql -U refract -d refract_iot -c "
   SELECT indexname, indexdef 
   FROM pg_indexes 
   WHERE tablename IN ('devices', 'readings');
   "
   ```

3. **Analyze slow queries**:
   ```bash
   docker compose exec postgres psql -U refract -d refract_iot -c "
   EXPLAIN ANALYZE SELECT * FROM readings 
   WHERE device_id = 'demo-001' 
   ORDER BY ts DESC 
   LIMIT 100;
   "
   ```

4. **Check reading count**:
   ```bash
   docker compose exec postgres psql -U refract -d refract_iot -c "
   SELECT COUNT(*) FROM readings;
   "
   ```
   Consider archiving old readings if count is very high

5. **Restart services**:
   ```bash
   docker compose restart
   ```

## Getting Help

If issues persist:

1. **Collect logs**:
   ```bash
   docker compose logs > logs.txt
   ```

2. **Check system resources**:
   ```bash
   docker system df
   docker stats --no-stream
   ```

3. **Verify environment**:
   ```bash
   docker --version
   docker compose version
   python3 --version
   ```

4. **Review documentation**:
   - [README.md](../README.md)
   - [architecture.md](./architecture.md)
   - [api_contract.md](./api_contract.md)
