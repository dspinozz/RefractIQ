# RefractIQ

**RefractIQ** is an IoT telemetry platform for refractometry instrumentation. Real-time monitoring, alerting, and visualization for refractive index measurements with Wi-Fi connectivity, store-and-forward reliability, and web dashboard.

## Architecture Overview

This system demonstrates a production-ready IoT telemetry architecture:

- **Wi-Fi + HTTPS**: Chosen for reliability and unattended operation at periodic cadence (e.g., 15-minute intervals)
- **Store-and-forward**: Device queues readings when offline, flushes on reconnect
- **Server as source of truth**: Centralized ingest, validation, and idempotency
- **Web dashboard**: Real-time device status and time-series visualization

### Design Decisions

**Wi-Fi over BLE**: BLE is excellent for commissioning and local service workflows, but Wi-Fi/cloud is better for unattended periodic telemetry and fleet reliability. BLE can be fragile in production due to phone range limitations, OS background restrictions, permissions, and OEM quirks.

**Mobile Component**: Flutter/Dart web for presentation. Native bridges for Android and iOS are documented for future native app development.

**Device Layer**: Minimal C client demonstrating connectivity contract and offline handling. Positioned as "reference client / connectivity harness" rather than full firmware.

## Project Structure

```
refract-iot-mvp/
├── backend/          # FastAPI HTTP service + Postgres
├── web/              # Flutter web dashboard
├── device/           # C client
└── docs/             # Architecture and API documentation
```

## Quick Start

### Prerequisites

- **Docker and Docker Compose** (required for PostgreSQL database and backend API)
- **Flutter SDK** (for web development)
- **Python 3.9+** (for backend API server and device simulator)
- **GCC and libcurl** (optional, for C device client)

### Local Development

1. **Start backend services (PostgreSQL + FastAPI)**:
   ```bash
   docker compose up -d
   ```
   
   This starts:
   - PostgreSQL database (port 5432, internal)
   - FastAPI backend API (port 8000)

2. **Start device simulator** (recommended for testing):
   ```bash
   cd device/simulator
   pip install -r requirements.txt
   python device_sim.py --device-id demo-001
   ```
   
   The simulator sends readings every 15 seconds. See [Device Simulator README](./device/simulator/README.md) for options.

3. **Run Flutter web app**:
   ```bash
   cd web
   flutter pub get
   flutter run -d chrome
   ```

4. **Access dashboard**: http://localhost:8080

   You should see device `demo-001` with status "OK" and recent readings.

### Alternative: Test with C Device Client

Instead of the simulator, you can use the C reference client:

```bash
cd device/c-client
make
./refract_client -d TEST001 -v 1.3330 -u RI -t 25.0
```

## Components

### Backend (`/backend`)

FastAPI service with Postgres database:
- `POST /api/v1/readings` - Ingest device readings
- `GET /api/v1/devices` - List devices with status
- `GET /api/v1/devices/{id}/readings` - Reading history
- `GET /health` - Health check

### Web Dashboard (`/web`)

Flutter web application:
- Device list with status badges
- Device detail pages with time-series charts
- Real-time reading updates

### Device Components (`/device`)

**Python Simulator** (`/device/simulator`):
- Server-side simulator for testing without hardware
- Generates realistic refractometry readings
- Configurable intervals (2 seconds for demos, 15 minutes for production-like)
- See [Simulator README](./device/simulator/README.md)

**C Reference Client** (`/device/c-client`):
- Minimal C client demonstrating connectivity contract
- HTTPS POST to ingest endpoint
- Offline queue management
- Store-and-forward behavior
- Reference implementation for IoT device firmware

## Documentation

- [Architecture](./docs/architecture.md) - System design and component interactions
- [API Contract](./docs/api_contract.md) - Backend API specification

## Future Enhancements

- Native mobile apps (Android/iOS) with Flutter native bridges
- BLE commissioning workflow
- TLS/SSL for production device communication
- Cloud deployment (ECS Fargate + RDS + ALB)
- Device firmware OTA updates

## License

MIT
