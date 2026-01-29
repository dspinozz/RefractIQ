"""Device management endpoints"""

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import desc
from typing import List, Optional
from datetime import datetime, timedelta

from app.db.database import get_db
from app.db.models import Device, Reading
from app.services.device_service import get_device_status

router = APIRouter()


@router.get("/devices")
async def list_devices(
    db: Session = Depends(get_db)
):
    """
    List all devices with status and latest reading.
    
    Returns devices with:
    - Device ID and name
    - Last seen timestamp
    - Latest reading value
    - Status: OK / STALE / OFFLINE
    """
    devices = db.query(Device).all()
    
    result = []
    for device in devices:
        # Get latest reading
        latest_reading = db.query(Reading).filter(
            Reading.device_id == device.device_id
        ).order_by(desc(Reading.ts)).first()
        
        # Determine status
        # Extract datetime value from SQLAlchemy instance
        # At runtime, device.last_seen_at is already Optional[datetime]
        last_seen: Optional[datetime] = device.last_seen_at  # type: ignore[assignment]
        status = get_device_status(last_seen)
        
        device_data = {
            "device_id": device.device_id,
            "name": device.name,
            "last_seen_at": device.last_seen_at.isoformat() if device.last_seen_at else None,
            "status": status,
            "target_ri": float(device.target_ri) if device.target_ri else None,
            "alert_low": float(device.alert_low) if device.alert_low else None,
            "alert_high": float(device.alert_high) if device.alert_high else None,
        }
        
        if latest_reading:
            device_data["latest_reading"] = {
                "value": float(latest_reading.value),
                "unit": latest_reading.unit,
                "ts": latest_reading.ts.isoformat()
            }
        else:
            device_data["latest_reading"] = None
        
        result.append(device_data)
    
    return {"devices": result}


@router.get("/devices/{device_id}/readings")
async def get_device_readings(
    device_id: str,
    limit: int = Query(100, ge=1, le=1000),
    db: Session = Depends(get_db)
):
    """
    Get reading history for a device.
    
    Returns time-series data for charts/tables.
    """
    # Verify device exists
    device = db.query(Device).filter(Device.device_id == device_id).first()
    if not device:
        raise HTTPException(status_code=404, detail="Device not found")
    
    readings = db.query(Reading).filter(
        Reading.device_id == device_id
    ).order_by(desc(Reading.ts)).limit(limit).all()
    
    return {
        "device_id": device_id,
        "readings": [
            {
                "id": r.id,
                "ts": r.ts.isoformat(),
                "value": float(r.value),
                "unit": r.unit,
                "temperature_c": float(r.temperature_c) if r.temperature_c else None
            }
            for r in readings
        ]
    }
