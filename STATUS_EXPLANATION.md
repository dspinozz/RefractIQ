# Device Status Explanation

## Status Types

### OK (Green)
- **Meaning**: Device is actively reporting
- **Criteria**: Last reading received within the last **15 minutes**
- **Action**: No action needed - device is functioning normally

### STALE (Orange/Yellow)
- **Meaning**: Device is reporting but with delays
- **Criteria**: Last reading received within the last **24 hours** but more than **15 minutes** ago
- **Possible causes**:
  - Network connectivity issues
  - Device in low-power mode
  - Scheduled reporting interval (e.g., 15-minute intervals)
- **Action**: Monitor - device may be functioning but delayed

### OFFLINE (Red)
- **Meaning**: Device has not reported recently
- **Criteria**: No reading received in the last **24 hours** or device never reported
- **Possible causes**:
  - Device powered off
  - Network connection lost
  - Device malfunction
  - Device not yet commissioned
- **Action**: Investigate device connectivity and power status

## Are These Separate Devices?

Yes! Each device has a unique `device_id`:
- **DEV001**: Separate refractometry device
- **DEV002**: Separate refractometry device  
- **DEV003**: Separate refractometry device
- **TEST001**: Test device (from earlier testing)

Each device can have different:
- Refractometry values (RI or Brix)
- Last seen timestamps
- Status (OK/STALE/OFFLINE)
- Reading history

## Integration with Mock IoT Device Simulator

The simulator (`device/simulator/device_sim.py`) is correctly integrated:

1. **Sends readings** to `/api/v1/readings` endpoint
2. **Creates devices** automatically when first reading is sent
3. **Updates last_seen_at** timestamp on each reading
4. **Supports queueing** when backend is unavailable
5. **Generates realistic values**:
   - 70% RI readings (1.3300-1.3400 range)
   - 30% Brix readings (10.0-15.0 range)
   - Temperature values (20-30°C)

### To Test with Simulator:

```bash
cd device/simulator
python device_sim.py --device-id DEMO-001 --interval-seconds 2
```

This will:
- Create device DEMO-001 (if it doesn't exist)
- Send readings every 2 seconds
- Update device status to "OK" (within 15 minutes)
- Appear in the dashboard automatically
