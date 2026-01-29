#!/bin/bash
# Simple verification script for Refractometry IoT MVP
# Checks that all essential files and dependencies are present

set -e

echo "🔍 Verifying project setup..."

# Check Python backend
echo "✓ Checking Python backend..."
if [ ! -f "backend/requirements.txt" ]; then
    echo "✗ Missing backend/requirements.txt"
    exit 1
fi

if [ ! -f "backend/src/main.py" ]; then
    echo "✗ Missing backend/src/main.py"
    exit 1
fi

# Check Flutter web
echo "✓ Checking Flutter web..."
if [ ! -f "web/pubspec.yaml" ]; then
    echo "✗ Missing web/pubspec.yaml"
    exit 1
fi

if [ ! -f "web/lib/main.dart" ]; then
    echo "✗ Missing web/lib/main.dart"
    exit 1
fi

# Check C device client
echo "✓ Checking C device client..."
if [ ! -f "device/c-client/Makefile" ]; then
    echo "✗ Missing device/c-client/Makefile"
    exit 1
fi

if [ ! -f "device/c-client/src/main.c" ]; then
    echo "✗ Missing device/c-client/src/main.c"
    exit 1
fi

# Check Docker setup
echo "✓ Checking Docker setup..."
if [ ! -f "docker-compose.yml" ]; then
    echo "✗ Missing docker-compose.yml"
    exit 1
fi

# Check documentation
echo "✓ Checking documentation..."
if [ ! -f "README.md" ]; then
    echo "✗ Missing README.md"
    exit 1
fi

if [ ! -f "docs/architecture.md" ]; then
    echo "✗ Missing docs/architecture.md"
    exit 1
fi

echo ""
echo "✅ All essential files present!"
echo ""
echo "Next steps:"
echo "  1. Start services: docker compose up -d"
echo "  2. Build C client: cd device/c-client && make"
echo "  3. Run Flutter web: cd web && flutter pub get && flutter run -d chrome"
