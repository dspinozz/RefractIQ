"""Payload validation utilities"""

from typing import Optional


def validate_reading_payload(unit: str, value: float, temperature_c: Optional[float] = None) -> Optional[str]:
    """
    Validate reading payload values.
    
    Args:
        unit: Unit string ("RI" or "Brix")
        value: Reading value
        temperature_c: Optional temperature in Celsius
    
    Returns error message if invalid, None if valid.
    """
    # Validate unit
    if unit not in ["RI", "Brix"]:
        return f"Invalid unit: {unit}. Must be 'RI' or 'Brix'"
    
    # Validate value ranges
    if unit == "RI":
        if not (1.0 <= value <= 2.0):
            return f"Refractive index value {value} out of range [1.0, 2.0]"
    elif unit == "Brix":
        if not (0.0 <= value <= 100.0):
            return f"Brix value {value} out of range [0.0, 100.0]"
    
    # Validate temperature if provided
    if temperature_c is not None:
        if not (-50.0 <= temperature_c <= 150.0):
            return f"Temperature {temperature_c}°C out of range [-50, 150]"
    
    return None
