# Flutter Web Dashboard

Flutter web application providing a real-time monitoring dashboard for refractometry IoT devices. Displays device status, reading history, and time-series visualization.

## Overview

The web dashboard is a **Flutter web application** that connects to the FastAPI backend to:
- Display all registered devices with real-time status
- Show device details and reading history
- Visualize time-series data with charts
- Auto-refresh device status every 30 seconds

## Architecture

### Technology Stack

- **Flutter Web**: Cross-platform web framework
- **Material Design 3**: Modern UI components
- **HTTP Package**: REST API client
- **Intl Package**: Date/time formatting

### Project Structure

```
web/
├── lib/
│   ├── main.dart              # App entry point
│   ├── api/
│   │   └── client.dart        # API client (REST calls)
│   ├── pages/
│   │   ├── index.dart         # Device list page
│   │   └── devices/
│   │       └── detail.dart    # Device detail page
│   └── components/
│       ├── device_table.dart  # Device list table
│       ├── status_badge.dart   # Status indicator badge
│       └── reading_chart.dart # Time-series chart
├── pubspec.yaml               # Dependencies
└── README.md                  # This file
```

## Prerequisites

- **Flutter SDK** (3.0.0 or later)
- **Chrome** or **Edge** browser (for development)
- **Backend API** running (see [Backend README](../backend/README.md))

### Install Flutter

**macOS**:
```bash
brew install flutter
```

**Linux**:
```bash
# Download from https://flutter.dev/docs/get-started/install/linux
# Or use snap:
sudo snap install flutter --classic
```

**Verify installation**:
```bash
flutter doctor
```

## Installation

### 1. Install Dependencies

```bash
cd web
flutter pub get
```

### 2. Configure API Endpoint

Create `.env` file (or use default):
```bash
cp .env.example .env
```

Edit `.env`:
```
API_BASE_URL=http://localhost:9000
```

**Note**: The default API client uses `http://localhost:8000`. To change:
- Edit `lib/api/client.dart` and update the `baseUrl` parameter
- Or pass custom URL: `ApiClient(baseUrl: 'http://localhost:9000')`

## Development

### Run Development Server

```bash
flutter run -d chrome
```

This will:
1. Build the web app
2. Launch Chrome
3. Open the dashboard at `http://localhost:8080` (or similar)

### Hot Reload

Flutter supports hot reload during development:
- Press `r` in terminal to hot reload
- Press `R` to hot restart
- Press `q` to quit

### Build for Production

```bash
flutter build web
```

Output is in `build/web/` directory. Deploy to any static web server.

### Serve Production Build Locally

```bash
# Using Python
cd build/web
python3 -m http.server 8080

# Using Node.js
npx serve build/web
```

## Features

### Device List Page

- **Device Table**: Shows all devices with:
  - Device ID
  - Name (if set)
  - Status (OK/STALE/OFFLINE)
  - Latest reading value and unit
  - Last seen timestamp
- **Auto-refresh**: Updates every 30 seconds
- **Click to view details**: Navigate to device detail page

### Device Detail Page

- **Device Information**: Device ID, name, status
- **Reading History**: Table of recent readings
- **Time-Series Chart**: Visualizes reading trends over time
- **Refresh Button**: Manual refresh of readings

### Status Indicators

- **OK** (Green): Device seen within last 15 minutes
- **STALE** (Yellow): Device seen within last 24 hours but > 15 minutes ago
- **OFFLINE** (Red): Device not seen in last 24 hours or never

## API Integration

### Endpoints Used

1. **GET /api/v1/devices**
   - Fetches all devices with latest reading
   - Used by device list page

2. **GET /api/v1/devices/{device_id}/readings**
   - Fetches reading history for a device
   - Used by device detail page
   - Supports `?limit=100` query parameter

3. **POST /api/v1/readings** (optional)
   - Can be used for manual reading submission
   - Not currently used in UI

### API Client

The `ApiClient` class in `lib/api/client.dart` handles:
- HTTP GET/POST requests
- JSON serialization/deserialization
- Error handling

**Example usage**:
```dart
final api = ApiClient(baseUrl: 'http://localhost:9000');
final devices = await api.getDevices();
final readings = await api.getDeviceReadings('DEV001', limit: 50);
```

## Configuration

### Environment Variables

Create `.env` file:
```
API_BASE_URL=http://localhost:9000
```

**Note**: Currently, the API client uses hardcoded default. To use `.env`:
1. Add `flutter_dotenv` package to `pubspec.yaml`
2. Load `.env` in `main.dart`
3. Pass to `ApiClient`

### API Base URL

Default: `http://localhost:8000`

To change:
- Edit `lib/api/client.dart`: `ApiClient({this.baseUrl = 'http://localhost:9000'})`
- Or pass when instantiating: `ApiClient(baseUrl: 'http://your-api:9000')`

## Testing

### Run Tests

```bash
flutter test
```

### Manual Testing

1. **Start backend**:
   ```bash
   docker compose up -d postgres backend
   ```

2. **Send test readings** (using simulator or C client):
   ```bash
   cd ../device/simulator
   python device_sim.py --device-id test-001 --interval-seconds 2
   ```

3. **Open dashboard**:
   ```bash
   flutter run -d chrome
   ```

4. **Verify**:
   - Device list shows `test-001` with status "OK"
   - Click device to see reading history
   - Chart displays time-series data

## Troubleshooting

### Dashboard shows "Failed to load devices"

**Check backend is running**:
```bash
curl http://localhost:9000/health
```

**Check API URL**: Verify `ApiClient` baseUrl matches backend port (default: 8000, but backend runs on 9000).

**Check CORS**: If backend is on different origin, ensure CORS is enabled in FastAPI:
```python
from fastapi.middleware.cors import CORSMiddleware
app.add_middleware(CORSMiddleware, allow_origins=["*"])
```

### Chart not displaying

- Verify device has readings: `curl http://localhost:9000/api/v1/devices/test-001/readings`
- Check browser console for errors
- Ensure `reading_chart.dart` component is properly imported

### Build errors

**Flutter version**:
```bash
flutter --version  # Should be >= 3.0.0
```

**Clean and rebuild**:
```bash
flutter clean
flutter pub get
flutter build web
```

### Hot reload not working

- Ensure you're in development mode: `flutter run -d chrome` (not `flutter build web`)
- Check terminal for hot reload prompt
- Try hot restart: Press `R` in terminal

## Deployment

### Static Web Hosting

The Flutter web build is a static site. Deploy to:
- **Netlify**: Drag and drop `build/web/` folder
- **Vercel**: `vercel build/web`
- **GitHub Pages**: Copy `build/web/` to `gh-pages` branch
- **AWS S3**: Upload `build/web/` to S3 bucket with static hosting
- **Nginx**: Serve `build/web/` directory

### Environment Configuration

For production, configure API URL:
1. Build with custom API URL:
   ```dart
   // In main.dart or config file
   final apiUrl = const String.fromEnvironment('API_URL', 
       defaultValue: 'https://api.example.com');
   final api = ApiClient(baseUrl: apiUrl);
   ```

2. Build with flag:
   ```bash
   flutter build web --dart-define=API_URL=https://api.example.com
   ```

### Docker Deployment

Example Dockerfile:
```dockerfile
FROM nginx:alpine
COPY build/web /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

Build and run:
```bash
docker build -t refract-web .
docker run -p 8080:80 refract-web
```

## Future Enhancements

- **Real-time updates**: WebSocket support for live reading updates
- **Authentication**: User login and API key management
- **Filters**: Filter devices by status, date range
- **Export**: Export readings to CSV/JSON
- **Alerts**: Visual alerts for offline/stale devices
- **Multi-device view**: Compare readings across devices
- **Dark mode**: Theme toggle

## See Also

- [Backend README](../backend/README.md) - API documentation
- [C Client README](../device/c-client/README.md) - Device client
- [Simulator README](../device/simulator/README.md) - Device simulator
- [Architecture Docs](../docs/architecture.md) - System design
- [Demo Script](../docs/demo_script.md) - End-to-end demo
