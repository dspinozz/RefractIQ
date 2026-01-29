-- Refractometry IoT Database Schema

CREATE TABLE IF NOT EXISTS devices (
    device_id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255),
    last_seen_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS readings (
    id SERIAL PRIMARY KEY,
    device_id VARCHAR(255) NOT NULL REFERENCES devices(device_id) ON DELETE CASCADE,
    ts TIMESTAMP NOT NULL,
    value NUMERIC(10, 4) NOT NULL,
    unit VARCHAR(50) NOT NULL,
    temperature_c NUMERIC(5, 2),
    event_id UUID UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Index for efficient time-series queries
CREATE INDEX IF NOT EXISTS idx_readings_device_ts ON readings(device_id, ts DESC);

-- Index for idempotency checks
CREATE INDEX IF NOT EXISTS idx_readings_event_id ON readings(event_id) WHERE event_id IS NOT NULL;
