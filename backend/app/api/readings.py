"""Reading ingestion endpoints"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional
from uuid import UUID

from app.db.database import get_db
from app.db.models import Reading, Device
from app.services.ingest_service import ingest_reading
from app.utils.validate import validate_reading_payload
from app.middleware.auth import get_api_key
from typing import Optional

router = APIRouter()


class ReadingPayload(BaseModel):
    device_id: str = Field(..., description="Device identifier")
    ts: datetime = Field(..., description="Reading timestamp (ISO8601)")
    value: float = Field(..., description="Refractive index or Brix value")
    unit: str = Field(..., description="Unit: 'RI' or 'Brix'")
    temperature_c: Optional[float] = Field(None, description="Temperature in Celsius")
    event_id: Optional[UUID] = Field(None, description="Unique event ID for idempotency")


@router.post("/readings", status_code=status.HTTP_201_CREATED)
async def create_reading(
    payload: ReadingPayload,
    db: Session = Depends(get_db),
    api_key: Optional[str] = Depends(get_api_key)
):
    """
    Ingest a device reading.
    
    - Validates payload
    - Enforces idempotency if event_id provided
    - Updates device last_seen_at
    - Returns created reading
    """
    # Validate payload
    validation_error = validate_reading_payload(payload.unit, payload.value, payload.temperature_c)
    if validation_error:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=validation_error
        )
    
    try:
        reading = ingest_reading(db, payload)
        return {
            "id": reading.id,
            "device_id": reading.device_id,
            "ts": reading.ts.isoformat(),
            "value": float(reading.value),
            "unit": reading.unit,
            "temperature_c": float(reading.temperature_c) if reading.temperature_c else None,
            "event_id": str(reading.event_id) if reading.event_id else None
        }
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
