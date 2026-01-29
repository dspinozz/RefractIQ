"""Optional API key authentication middleware"""

from fastapi import Header, HTTPException, status
from typing import Optional
import os
import hmac
import hashlib


def constant_time_compare(a: Optional[str], b: Optional[str]) -> bool:
    """
    Constant-time string comparison to prevent timing attacks.
    
    Returns True if strings are equal, False otherwise.
    """
    if a is None or b is None:
        return False
    
    if len(a) != len(b):
        return False
    
    # Use hmac.compare_digest for constant-time comparison
    return hmac.compare_digest(a.encode('utf-8'), b.encode('utf-8'))


def get_api_key(x_api_key: Optional[str] = Header(None)) -> Optional[str]:
    """
    Optional API key authentication.
    
    If API_KEY_REQUIRED env var is set, requires X-API-Key header.
    Otherwise, authentication is optional (for local demo).
    
    Uses constant-time comparison to prevent timing attacks.
    """
    api_key_required = os.getenv("API_KEY_REQUIRED", "false").lower() == "true"
    expected_key = os.getenv("API_KEY")
    
    if api_key_required:
        if not expected_key:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="API key authentication required but API_KEY not configured"
            )
        
        # Use constant-time comparison to prevent timing attacks
        if not x_api_key or not constant_time_compare(x_api_key, expected_key):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid or missing API key"
            )
    
    return x_api_key
