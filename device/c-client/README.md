# C Reference Connectivity Client

Minimal C client demonstrating IoT device connectivity patterns: HTTP POST, offline queueing, and store-and-forward behavior.

**Positioning**: This is a **reference connectivity client** / **connectivity harness**, not full firmware. It demonstrates the connectivity contract and offline handling patterns that would be integrated into device firmware.

## Build Instructions

### Prerequisites

**Linux (Debian/Ubuntu)**:
```bash
sudo apt-get update
sudo apt-get install build-essential libcurl4-openssl-dev
```

**macOS**:
```bash
brew install curl
```

**Verify libcurl**:
```bash
pkg-config --libs libcurl
# Should output: -lcurl
```

### Build

```bash
make
```

This creates the `refract_client` executable.

### Clean

```bash
make clean
```

Removes build artifacts and queue file.

## Run Instructions

### Configuration

Configuration via command-line arguments or environment variables:

**Command-line** (recommended):
```bash
./refract_client -d DEV001 -v 1.3330 -u RI -t 25.0 -s http://localhost:9000
```

**Environment variables** (set before running):
```bash
export SERVER_URL=http://localhost:9000
export DEVICE_ID=DEV001
export API_KEY=your-key-here  # Optional
./refract_client -v 1.3330 -u RI -t 25.0
```

### Options

| Option | Description | Required |
|--------|-------------|-----------|
| `-d, --device-id` | Device identifier | Yes |
| `-v, --value` | Reading value | Yes |
| `-u, --unit` | Unit: "RI" or "Brix" | Yes |
| `-t, --temp` | Temperature in Celsius | No (default: 25.0) |
| `-s, --server` | Server URL | No (default: http://localhost:8000) |
| `-f, --flush` | Flush queued readings only | No |
| `-h, --help` | Show help | No |

### Example Usage

**Send a reading**:
```bash
./refract_client -d DEV001 -v 1.3330 -u RI -t 25.0 -s http://localhost:9000
```

**Send Brix reading**:
```bash
./refract_client -d DEV002 -v 12.5 -u Brix -t 20.0
```

**Flush queue only**:
```bash
./refract_client -f -s http://localhost:9000
```

## Queueing Behavior

### Queue File

Queued readings are stored in `queue.log` (JSONL format) when the backend is unavailable.

**Location**: Same directory as executable (or current working directory)

**Format**: One JSON object per line:
```json
{"device_id":"DEV001","ts":"2024-01-28T15:40:00Z","value":1.3330,"unit":"RI","temperature_c":25.0}
```

### Flush Behavior

1. **On startup**: Client attempts to flush any existing queued readings
2. **On send failure**: Reading is appended to `queue.log`
3. **On next success**: Queued readings are flushed before sending current reading

### Example: Demonstrating Queue Behavior

```bash
# Terminal 1: Start backend
docker compose up -d postgres backend

# Terminal 2: Send reading (succeeds)
./refract_client -d TEST001 -v 1.3330 -u RI -t 25.0 -s http://localhost:9000
# Output: Successfully sent reading

# Terminal 1: Stop backend
docker compose stop backend

# Terminal 2: Send reading (queues)
./refract_client -d TEST001 -v 1.3340 -u RI -t 26.0 -s http://localhost:9000
# Output: Failed to send reading, queuing for later

# Check queue
cat queue.log
# Shows: {"device_id":"TEST001",...}

# Terminal 1: Start backend
docker compose start backend

# Terminal 2: Send reading (flushes queue first)
./refract_client -d TEST001 -v 1.3350 -u RI -t 27.0 -s http://localhost:9000
# Output:
#   Flushing queued readings...
#   Sending queued reading: {...}
#   Successfully sent queued reading
#   Flushed 1 queued reading(s)
#   Sending reading: {...}
#   Successfully sent reading
```

### Partial Flush Failures

If some queued readings fail to send during flush:
- Successfully sent readings are removed from queue
- Failed readings remain in queue for next attempt
- Current reading is still sent if flush completes

## Integration Example

In real device firmware, this client would be called periodically:

```c
// Pseudocode for device firmware integration
while (1) {
    double reading = read_sensor();        // Read from hardware
    double temp = read_temperature();      // Read temperature sensor
    
    // Call connectivity client
    char cmd[512];
    snprintf(cmd, sizeof(cmd), 
        "./refract_client -d %s -v %.4f -u RI -t %.1f -s %s",
        device_id, reading, temp, server_url);
    system(cmd);
    
    sleep(900);  // 15 minutes
}
```

## Production Considerations

### TLS/HTTPS

Current implementation uses HTTP. For production:

1. Enable TLS in `http_client.c`:
   ```c
   curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 1L);
   curl_easy_setopt(curl, CURLOPT_SSL_VERIFYHOST, 2L);
   curl_easy_setopt(curl, CURLOPT_CAINFO, "/path/to/ca-bundle.crt");
   ```

2. Use HTTPS URL:
   ```bash
   ./refract_client -s https://api.example.com ...
   ```

### Queue Persistence

Current implementation uses a simple file. For production:
- Consider SQLite for more robust storage
- Add queue size limits and rotation
- Implement queue compression for long offline periods

### Retry Logic

Current implementation:
- Flushes queue on every send attempt
- No exponential backoff
- No max retry limits

For production, add:
- Exponential backoff between retries
- Max retry count per reading
- Dead letter queue for permanently failed readings

### Event IDs

Current implementation does not generate `event_id` for idempotency. To add:

1. Link against UUID library (e.g., `libuuid`)
2. Generate UUID before sending
3. Include in JSON payload

Example:
```c
#include <uuid/uuid.h>
uuid_t uuid;
uuid_generate(uuid);
char uuid_str[37];
uuid_unparse(uuid, uuid_str);
// Include in JSON: "event_id": uuid_str
```

## Troubleshooting

**Build errors**:
- Verify libcurl is installed: `pkg-config --libs libcurl`
- Check GCC version: `gcc --version`
- See [troubleshooting.md](../../docs/troubleshooting.md)

**Connection errors**:
- Verify backend is running: `curl http://localhost:9000/health`
- Check server URL matches backend port
- Check network/firewall settings

**Queue not flushing**:
- Verify backend is accessible
- Check queue file exists: `cat queue.log`
- Manually test API: `curl -X POST http://localhost:9000/api/v1/readings ...`

## See Also

- [Simulator README](../simulator/README.md) - Python device simulator
- [Backend README](../../backend/README.md) - API documentation
- [Demo Script](../../docs/demo_script.md) - End-to-end demo
