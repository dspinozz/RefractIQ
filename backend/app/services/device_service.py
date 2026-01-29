"""Device status and management service"""

from datetime import datetime, timedelta
from typing import Optional


def get_device_status(last_seen_at: Optional[datetime]) -> str:
    """
    Determine device status based on last_seen_at.
    
    - OK: seen within last 15 minutes
    - STALE: seen within last 24 hours but > 15 minutes
    - OFFLINE: not seen in last 24 hours or never
    """
    if not last_seen_at:
        return "OFFLINE"
    
    now = datetime.utcnow()
    age = now - last_seen_at
    
    if age < timedelta(minutes=15):
        return "OK"
    elif age < timedelta(hours=24):
        return "STALE"
    else:
        return "OFFLINE"
