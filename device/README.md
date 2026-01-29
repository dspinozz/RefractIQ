# Device Component

The device component provides two complementary implementations for IoT device connectivity to the Refractometry IoT MVP backend:

1. **C Reference Client** (`c-client/`) - Minimal C client demonstrating connectivity patterns for embedded device firmware
2. **Python Device Simulator** (`simulator/`) - Server-side simulator for testing and demos without hardware

Both implementations share the same connectivity contract, queueing semantics, and API integration patterns.

## Overview

### Purpose

The device component demonstrates how IoT devices connect to the backend API to:
- Send refractometry readings (RI or Brix values)
- Handle offline scenarios with store-and-forward queueing
- Support idempotent requests via event IDs
- Integrate with the FastAPI backend service

### Architecture

```
Device Component
├── c-client/          # C reference implementation
│   ├── src/          # Source files (main.c, http_client.c, queue.c)
│   ├── Makefile      # Build configuration
│   └── README.md     # C client documentation
└── simulator/        # Python simulator
    ├── device_sim.py # Simulator script
    └── README.md     # Simulator documentation
```

## Components

### 1. C Reference Client

**Location**: `c-client/`

**Purpose**: Reference implementation for embedded device firmware integration.

**Use Cases**:
- **Firmware integration** - Copy connectivity patterns into device firmware
- **Reference implementation** - Understand the connectivity contract
- **Hardware testing** - Test with actual embedded devices
- **Production deployment** - Minimal C client for resource-constrained devices

**Key Features**:
- HTTP POST to backend API
- Offline queue management (JSONL file-based)
- Store-and-forward behavior
- Command-line interface for testing
- Minimal dependencies (libcurl only)

**See**: [C Client README](./c-client/README.md) for build instructions, usage, and integration examples.

### 2. Python Device Simulator

**Location**: `simulator/`

**Purpose**: Server-side simulator for testing and demonstrations.

**Use Cases**:
- **End-to-end testing** - Test backend without physical devices
- **Demos and presentations** - Quick setup for reviewers
- **Development workflow** - Rapid iteration without hardware
- **Load testing** - Simulate multiple devices
- **Queue behavior testing** - Test offline/online scenarios

**Key Features**:
- Configurable intervals (demo: 2s, production: 15min)
- Realistic reading generation (RI/Brix values)
- Queueing behavior matching C client
- Failure simulation (jitter, failure rate)
- Multiple device support

**See**: [Simulator README](./simulator/README.md) for installation, usage, and configuration.

## When to Use Each

### Use C Client When:
- ✅ Integrating with actual device hardware
- ✅ Building production firmware
- ✅ Testing on embedded platforms
- ✅ Need minimal resource footprint
- ✅ Working with C/C++ codebase

### Use Simulator When:
- ✅ Testing backend functionality
- ✅ Demonstrating system to stakeholders
- ✅ Rapid development iteration
- ✅ Testing without hardware access
- ✅ Simulating multiple devices
- ✅ Testing queue/offline behavior

## Shared Behavior

Both implementations follow the same connectivity contract:

### API Endpoint
```
POST /api/v1/readings
```

### Request Format
```json
{
  "device_id": "DEV001",
  "ts": "2024-01-28T15:40:00Z",
  "value": 1.3330,
  "unit": "RI",
  "temperature_c": 25.0,
  "event_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

### Queueing Semantics

Both implementations use the same queueing behavior:

1. **On startup**: Attempt to flush any existing queued readings
2. **On send failure**: Append reading to queue file (JSONL format)
3. **On next success**: Flush queued readings before sending current reading

**Queue File Format** (JSONL):
```json
{"device_id":"DEV001","ts":"2024-01-28T15:40:00Z","value":1.3330,"unit":"RI","temperature_c":25.0,"event_id":"..."}
{"device_id":"DEV001","ts":"2024-01-28T15:41:00Z","value":1.3340,"unit":"RI","temperature_c":26.0,"event_id":"..."}
```

### Idempotency

Both support idempotent requests via `event_id`:
- First request with `event_id`: Creates new reading
- Duplicate request with same `event_id`: Returns existing reading (no duplicate)

## Integration Examples

### Example 1: Testing with Simulator

```bash
# Terminal 1: Start backend
cd ../backend
docker compose up -d postgres backend

# Terminal 2: Run simulator
cd device/simulator
python device_sim.py --device-id test-001 --interval-seconds 2

# Terminal 3: Check dashboard
cd ../web
flutter run -d chrome
```

### Example 2: Testing with C Client

```bash
# Terminal 1: Start backend
cd ../backend
docker compose up -d postgres backend

# Terminal 2: Build and run C client
cd device/c-client
make
./refract_client -d test-002 -v 1.3330 -u RI -t 25.0 -s http://localhost:9000

# Terminal 3: Check dashboard
cd ../web
flutter run -d chrome
```

### Example 3: Testing Queue Behavior

```bash
# Terminal 1: Start backend
cd ../backend
docker compose up -d postgres backend

# Terminal 2: Send reading (succeeds)
cd device/c-client
./refract_client -d test-003 -v 1.3330 -u RI -t 25.0

# Terminal 1: Stop backend
docker compose stop backend

# Terminal 2: Send reading (queues)
./refract_client -d test-003 -v 1.3340 -u RI -t 26.0
# Output: Failed to send reading, queuing for later

# Check queue
cat queue.log
# Shows: {"device_id":"test-003",...}

# Terminal 1: Start backend
docker compose start backend

# Terminal 2: Send reading (flushes queue)
./refract_client -d test-003 -v 1.3350 -u RI -t 27.0
# Output:
#   Flushing queued readings...
#   Successfully sent queued reading
#   Flushed 1 queued reading(s)
#   Successfully sent reading
```

## Development Workflow

### Recommended Workflow

1. **Start with Simulator**: Use simulator for rapid backend development and testing
   ```bash
   cd device/simulator
   python device_sim.py --device-id dev-001 --interval-seconds 2
   ```

2. **Test with C Client**: Once backend is stable, test with C client for hardware integration
   ```bash
   cd device/c-client
   make
   ./refract_client -d dev-001 -v 1.3330 -u RI -t 25.0
   ```

3. **Verify in Dashboard**: Check both implementations appear correctly in web dashboard
   ```bash
   cd ../web
   flutter run -d chrome
   ```

### Testing Queue Behavior

Both implementations can be used to test queue behavior:

```bash
# Start backend
docker compose up -d postgres backend

# Send reading (succeeds)
./refract_client -d test -v 1.3330 -u RI

# Stop backend
docker compose stop backend

# Send reading (queues)
./refract_client -d test -v 1.3340 -u RI

# Restart backend
docker compose start backend

# Send reading (flushes queue)
./refract_client -d test -v 1.3350 -u RI
```

## Production Considerations

### C Client for Production

For production deployment with the C client:

1. **Enable TLS/HTTPS**: Modify `http_client.c` to use HTTPS
2. **Add Event IDs**: Generate UUIDs for idempotency (link against `libuuid`)
3. **Queue Persistence**: Consider SQLite for more robust storage
4. **Retry Logic**: Add exponential backoff and max retry limits
5. **Queue Limits**: Implement queue size limits and rotation

See [C Client README](./c-client/README.md) for detailed production considerations.

### Simulator for Production

The simulator is **not intended for production use**. It's designed for:
- Development and testing
- Demos and presentations
- Backend validation

For production, use the C client or integrate connectivity patterns into device firmware.

## Troubleshooting

### Common Issues

**C Client build errors**:
- Verify libcurl is installed: `pkg-config --libs libcurl`
- Check GCC version: `gcc --version`
- See [C Client README](./c-client/README.md) troubleshooting section

**Simulator connection errors**:
- Verify backend is running: `curl http://localhost:9000/health`
- Check `--server-url` matches backend port
- Check firewall/network settings

**Queue not flushing**:
- Verify backend is accessible
- Check queue file exists: `cat queue.log` (C client) or `cat queue.jsonl` (simulator)
- Manually test API: `curl -X POST http://localhost:9000/api/v1/readings ...`

**Readings not appearing**:
- Check backend logs: `docker compose logs backend`
- Verify device appears: `curl http://localhost:9000/api/v1/devices`
- Check for validation errors in backend logs

## See Also

- [C Client README](./c-client/README.md) - C reference client documentation
- [Simulator README](./simulator/README.md) - Python simulator documentation
- [Backend README](../backend/README.md) - API documentation
- [Web Dashboard README](../web/README.md) - Dashboard documentation
- [Architecture Docs](../docs/architecture.md) - System design
- [Demo Script](../docs/demo_script.md) - End-to-end demo instructions
