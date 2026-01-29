# Setup Guide

Simple, step-by-step setup instructions for the Refractometry IoT MVP.

## Prerequisites

- **Docker and Docker Compose** (required for PostgreSQL database and backend API)
- **Flutter SDK** (for web development)
- **Python 3.9+** (for device simulator)
- **GCC and libcurl** (optional, for C device client)

## Quick Start

### 1. Start Backend Services (PostgreSQL + FastAPI)

```bash
docker compose up -d
```

This starts:
- **PostgreSQL database** (port 5432, internal Docker network)
- **FastAPI backend API** (port 8000)

Wait a few seconds for services to initialize, then verify:

```bash
curl http://localhost:8000/health
```

Should return: `{"status":"healthy"}`

### 2. Start Device Simulator (Recommended)

The Python simulator is the easiest way to generate test data:

```bash
cd device/simulator
pip install -r requirements.txt
python device_sim.py --device-id demo-001
```

The simulator will:
- Send readings every 15 seconds
- Create device `demo-001` automatically
- Continue running until stopped (Ctrl+C)

For faster demo mode (2-second intervals):
```bash
python device_sim.py --device-id demo-001 --interval-seconds 2
```

See [Device Simulator README](./device/simulator/README.md) for full options.

### 3. Run Flutter Web Dashboard

```bash
cd web
flutter pub get
flutter run -d chrome
```

The dashboard will open in Chrome at `http://localhost:8080` (or similar).

### 4. Verify End-to-End

**Check the dashboard:**
- Open `http://localhost:8080` in your browser
- You should see device `demo-001` with status "OK"
- Click on the device to see readings and time-series chart
- Readings update every 15 seconds

### Alternative: Test with C Device Client

Instead of the simulator, you can use the C reference client:

```bash
cd device/c-client
make
./refract_client -d TEST001 -v 1.3330 -u RI -t 25.0
```

## Verification

Run the verification script:

```bash
./verify_setup.sh
```

## Troubleshooting

### Backend not starting
- Check Docker is running: `docker ps`
- Check logs: `docker compose logs backend`
- Verify port 8000 is not in use

### Flutter web not building
- Ensure Flutter SDK is installed: `flutter doctor`
- Try: `flutter clean && flutter pub get`

### C client not compiling
- Install libcurl: `sudo apt-get install libcurl4-openssl-dev` (Linux) or `brew install curl` (macOS)
- Check GCC is installed: `gcc --version`

## Next Steps

- See [README.md](./README.md) for architecture overview
- See [docs/architecture.md](./docs/architecture.md) for detailed design
- See [docs/api_contract.md](./docs/api_contract.md) for API documentation
