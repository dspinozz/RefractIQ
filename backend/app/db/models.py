"""SQLAlchemy models"""

from sqlalchemy import Column, String, Numeric, DateTime, ForeignKey, Integer
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from datetime import datetime
import uuid

from app.db.database import Base


class Device(Base):
    __tablename__ = "devices"

    device_id = Column(String(255), primary_key=True)
    name = Column(String(255))
    last_seen_at = Column(DateTime)
    # Refractometry target and alert boundaries
    target_ri = Column(Numeric(10, 4))  # Target Refractive Index value
    alert_low = Column(Numeric(10, 4))  # Lower alert boundary (warrants investigation)
    alert_high = Column(Numeric(10, 4))  # Upper alert boundary (warrants investigation)
    created_at = Column(DateTime, server_default=func.now())


class Reading(Base):
    __tablename__ = "readings"

    id = Column(Integer, primary_key=True, index=True)
    device_id = Column(String(255), ForeignKey("devices.device_id", ondelete="CASCADE"), nullable=False, index=True)
    ts = Column(DateTime, nullable=False, index=True)
    value = Column(Numeric(10, 4), nullable=False)
    unit = Column(String(50), nullable=False)
    temperature_c = Column(Numeric(5, 2))
    event_id = Column(UUID(as_uuid=True), unique=True, index=True)
    created_at = Column(DateTime, server_default=func.now())
