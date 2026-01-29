# IoT Device Simulator

Server-side simulator that emulates an IoT device sending refractometry readings on a schedule. This complements the C reference client and enables end-to-end testing without hardware.

## Purpose

- **Demo end-to-end functionality** without physical devices
- **Test ingest/idempotency/queueing** behaviors
- **Enable quick evaluation** by reviewers
- **Simulate production cadence** (15-minute intervals) or fast demo cadence (2-second intervals)

## Installation

```bash
pip install -r requirements.txt
```

Or use system Python 3.9+ with requests installed.

## Usage

### Basic Usage

```bash
python device_sim.py --device-id demo-001
```

Sends readings every 15 seconds to `http://localhost:9000`.

### Demo Mode (Fast Interval)

```bash
python device_sim.py --device-id demo-001 --interval-seconds 2
```

Useful for quick demonstrations where you want to see readings appear rapidly.

### Production-Like (15-Minute Cadence)

```bash
python device_sim.py --device-id prod-001 --interval-seconds 900
```

Simulates the intended production cadence of 15-minute intervals.

### With Jitter and Failure Simulation

```bash
python device_sim.py \
  --device-id test-001 \
  --interval-seconds 5 \
  --jitter 0.1 \
  --failure-rate 0.05
```

- `--jitter 0.1`: Adds ±10% random variation to intervals
- `--failure-rate 0.05`: Simulates 5% device failures (skipped readings)

## CLI Options

| Option | Description | Default |
|--------|------------|---------|
| `--device-id` | Device identifier (required) | - |
| `--server-url` | Backend API URL | `http://localhost:9000` |
| `--interval-seconds` | Seconds between readings | `15` |
| `--jitter` | Interval jitter (0.0-1.0) | `0.0` |
| `--failure-rate` | Simulated failure rate (0.0-1.0) | `0.0` |
| `--api-key` | API key for authentication | None |
| `--queue-file` | Queue file path | `queue.jsonl` |

## Queueing Behavior

The simulator implements the same queueing semantics as the C client:

1. **On startup**: Flushes any existing queued readings
2. **On send failure**: Appends reading to `queue.jsonl` (JSONL format)
3. **On next success**: Attempts to flush queued readings before sending current reading

### Queue File Format

Each line is a JSON object:
```json
{"device_id":"demo-001","ts":"2024-01-28T15:40:00Z","value":1.3330,"unit":"RI","temperature_c":25.0,"event_id":"..."}
```

## Example: Demonstrating Queue Behavior

```bash
# Terminal 1: Start backend
docker compose up -d postgres backend

# Terminal 2: Start simulator
python device_sim.py --device-id demo-001 --interval-seconds 2

# Terminal 3: Stop backend (simulator will queue readings)
docker compose stop backend

# Wait a few seconds, then restart backend
docker compose start backend

# Simulator will automatically flush queued readings on next send
```

## Generated Readings

The simulator generates realistic readings:
- **70% RI (Refractive Index)**: Values in range 1.3300-1.3400
- **30% Brix**: Values in range 10.0-15.0
- **Temperature**: Random between 20.0-30.0°C
- **Event ID**: UUID for idempotency

## Integration with C Client

Both the simulator and C client use the same:
- API endpoint: `POST /api/v1/readings`
- Queue file format: JSONL
- Flush behavior: Attempt flush before sending current reading

This allows testing both paths with the same backend.

## Troubleshooting

**Simulator cannot connect:**
- Verify backend is running: `curl http://localhost:9000/health`
- Check `--server-url` matches backend port
- Check firewall/network settings

**Readings not appearing:**
- Check backend logs: `docker compose logs backend`
- Verify device appears in device list: `curl http://localhost:9000/api/v1/devices`
- Check for validation errors in backend logs

**Queue not flushing:**
- Verify backend is accessible
- Check queue file exists: `cat queue.jsonl`
- Manually test API: `curl -X POST http://localhost:9000/api/v1/readings ...`

## See Also

- [C Client README](../c-client/README.md) - Reference connectivity client
- [Backend README](../../backend/README.md) - API documentation
- [Demo Script](../../docs/demo_script.md) - End-to-end demo instructions
