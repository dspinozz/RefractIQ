"""
Refractometry IoT Backend API
FastAPI service for device telemetry ingestion and querying
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from app.api import readings, devices
from app.db.database import engine, Base


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: create tables
    Base.metadata.create_all(bind=engine)
    yield
    # Shutdown: cleanup if needed
    pass


app = FastAPI(
    title="RefractIQ API",
    description="IoT telemetry platform for refractometry instrumentation - Real-time monitoring, alerting, and data visualization",
    version="1.0.0",
    lifespan=lifespan
)

# CORS middleware for web frontend
# Restrict to specific origins and methods for security
# Origins can be configured via CORS_ORIGINS environment variable (comma-separated)
# Default includes common localhost ports for development
import os

cors_origins_env = os.getenv("CORS_ORIGINS", "")
if cors_origins_env:
    # Parse comma-separated origins from environment
    cors_origins = [origin.strip() for origin in cors_origins_env.split(",") if origin.strip()]
else:
    # Default development origins
    cors_origins = [
        "http://localhost:8080",
        "http://localhost:3000",
        "http://localhost:8081",
        "http://localhost:8888",
        "http://localhost:5001",
        "http://localhost:9090",
    ]

app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST"],  # Only allow necessary methods
    allow_headers=["Content-Type", "X-API-Key"],  # Only allow necessary headers
)

# Include routers
app.include_router(readings.router, prefix="/api/v1", tags=["readings"])
app.include_router(devices.router, prefix="/api/v1", tags=["devices"])


@app.get("/health")
async def health():
    """Health check endpoint for load balancers"""
    return {"status": "healthy"}


@app.get("/")
async def root():
    return {
        "service": "RefractIQ API",
        "version": "1.0.0",
        "docs": "/docs"
    }
