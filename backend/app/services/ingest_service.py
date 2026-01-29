"""Reading ingestion service with idempotency"""

from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError
from typing import TYPE_CHECKING

from app.db.models import Reading, Device

if TYPE_CHECKING:
    from app.api.readings import ReadingPayload


def ingest_reading(db: Session, payload: "ReadingPayload") -> Reading:
    """
    Ingest a reading with idempotency support.
    
    - Creates/updates device record
    - Inserts reading
    - Handles duplicate event_id gracefully
    """
    # Ensure device exists
    device = db.query(Device).filter(Device.device_id == payload.device_id).first()
    if not device:
        device = Device(
            device_id=payload.device_id,
            name=f"Device {payload.device_id}",
            last_seen_at=payload.ts
        )
        db.add(device)
    else:
        # Update last_seen_at with new timestamp
        device.last_seen_at = payload.ts  # type: ignore[assignment]
    
    # Check for duplicate event_id if provided
    if payload.event_id:
        existing = db.query(Reading).filter(Reading.event_id == payload.event_id).first()
        if existing:
            # Idempotent: return existing reading
            return existing
    
    # Create new reading
    reading = Reading(
        device_id=payload.device_id,
        ts=payload.ts,
        value=payload.value,
        unit=payload.unit,
        temperature_c=payload.temperature_c,
        event_id=payload.event_id
    )
    
    try:
        db.add(reading)
        db.commit()
        db.refresh(reading)
        return reading
    except IntegrityError as e:
        db.rollback()
        # Handle race condition: event_id collision
        if payload.event_id:
            existing = db.query(Reading).filter(Reading.event_id == payload.event_id).first()
            if existing:
                return existing
        raise ValueError(f"Failed to insert reading: {str(e)}")
