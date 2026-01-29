#!/usr/bin/env python3
"""
IoT Device Simulator for Refractometry Telemetry

Emulates a device sending readings on a schedule.
Supports queueing when backend is unavailable.
"""

import argparse
import json
import random
import requests
import time
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional
import uuid


class DeviceSimulator:
    def __init__(
        self,
        device_id: str,
        server_url: str,
        interval_seconds: int = 15,  # Default: 15 seconds (production cadence)
        jitter: float = 0.0,
        failure_rate: float = 0.0,
        api_key: Optional[str] = None,
        queue_file: str = "queue.jsonl"
    ):
        self.device_id = device_id
        self.server_url = server_url.rstrip('/')
        self.interval_seconds = interval_seconds
        self.jitter = jitter
        self.failure_rate = failure_rate
        self.api_key = api_key
        self.queue_file = Path(queue_file)
        self.session = requests.Session()
        
        if api_key:
            self.session.headers.update({"X-API-Key": api_key})
        
        self.session.headers.update({"Content-Type": "application/json"})
    
    def generate_reading(self) -> dict:
        """Generate a realistic refractometry reading."""
        # Refractometers measure Refractive Index (RI) as the primary unit
        # RI is a dimensionless number typically in the range 1.3300-1.3400 for liquids
        # Brix is a derived/converted value, not a direct measurement
        value = round(random.uniform(1.3300, 1.3400), 4)
        unit = "RI"
        
        temperature = round(random.uniform(20.0, 30.0), 1)
        event_id = str(uuid.uuid4())
        
        return {
            "device_id": self.device_id,
            "ts": datetime.now(timezone.utc).isoformat(),
            "value": value,
            "unit": unit,
            "temperature_c": temperature,
            "event_id": event_id
        }
    
    def queue_reading(self, reading: dict) -> None:
        """Append reading to queue file."""
        with open(self.queue_file, 'a') as f:
            f.write(json.dumps(reading) + '\n')
        print(f"  [QUEUED] Reading queued to {self.queue_file}")
    
    def flush_queue(self) -> int:
        """Flush queued readings to server."""
        if not self.queue_file.exists():
            return 0
        
        flushed = 0
        failed = []
        
        with open(self.queue_file, 'r') as f:
            lines = f.readlines()
        
        if not lines:
            return 0
        
        print(f"  [FLUSH] Attempting to flush {len(lines)} queued reading(s)...")
        
        for line in lines:
            reading = json.loads(line.strip())
            if self._send_reading(reading, queue_on_failure=False):
                flushed += 1
            else:
                failed.append(line)
        
        # Rewrite queue with failed readings
        if failed:
            with open(self.queue_file, 'w') as f:
                f.writelines(failed)
            print(f"  [FLUSH] {flushed} sent, {len(failed)} remain in queue")
        else:
            self.queue_file.unlink()
            print(f"  [FLUSH] All {flushed} queued readings sent successfully")
        
        return flushed
    
    def _send_reading(self, reading: dict, queue_on_failure: bool = True) -> bool:
        """Send a single reading to the server."""
        try:
            url = f"{self.server_url}/api/v1/readings"
            response = self.session.post(url, json=reading, timeout=5)
            
            if response.status_code == 201:
                print(f"  [SENT] {reading['value']} {reading['unit']} @ {reading['ts']}")
                return True
            else:
                print(f"  [ERROR] HTTP {response.status_code}: {response.text}")
                if queue_on_failure:
                    self.queue_reading(reading)
                return False
        
        except requests.exceptions.RequestException as e:
            print(f"  [ERROR] Connection failed: {e}")
            if queue_on_failure:
                self.queue_reading(reading)
            return False
    
    def run(self):
        """Main simulation loop."""
        print(f"🚀 Device Simulator Starting")
        print(f"   Device ID: {self.device_id}")
        print(f"   Server: {self.server_url}")
        print(f"   Interval: {self.interval_seconds}s")
        print(f"   Jitter: ±{self.jitter * 100:.0f}%")
        print(f"   Failure Rate: {self.failure_rate * 100:.1f}%")
        print()
        
        # Flush any existing queue on startup
        if self.queue_file.exists():
            self.flush_queue()
            print()
        
        iteration = 0
        try:
            while True:
                iteration += 1
                
                # Apply failure rate
                if random.random() < self.failure_rate:
                    print(f"[{iteration}] Simulating device failure (skipping this reading)")
                    time.sleep(self.interval_seconds)
                    continue
                
                # Generate and send reading
                reading = self.generate_reading()
                self._send_reading(reading)
                
                # Calculate next interval with jitter
                jitter_amount = random.uniform(-self.jitter, self.jitter)
                next_interval = max(1, int(self.interval_seconds * (1 + jitter_amount)))
                
                # Wait for next reading
                time.sleep(next_interval)
        
        except KeyboardInterrupt:
            print()
            print("🛑 Simulator stopped by user")
            if self.queue_file.exists():
                queue_size = len(self.queue_file.read_text().strip().split('\n'))
                if queue_size > 0:
                    print(f"   {queue_size} reading(s) remain in queue: {self.queue_file}")


def main():
    parser = argparse.ArgumentParser(
        description="IoT Device Simulator for Refractometry Telemetry",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Basic usage (15 second interval)
  python device_sim.py --device-id demo-001

  # Demo mode (2 second interval for fast demo)
  python device_sim.py --device-id demo-001 --interval-seconds 2

  # Production-like (15 minute interval)
  python device_sim.py --device-id prod-001 --interval-seconds 900

  # With jitter and failure simulation
  python device_sim.py --device-id test-001 --interval-seconds 5 --jitter 0.1 --failure-rate 0.05
        """
    )
    
    parser.add_argument(
        "--device-id",
        required=True,
        help="Device identifier"
    )
    
    parser.add_argument(
        "--server-url",
        default="http://localhost:9000",
        help="Backend API URL (default: http://localhost:9000)"
    )
    
    parser.add_argument(
        "--interval-seconds",
        type=int,
        default=15,
        help="Interval between readings in seconds (default: 15, use 900 for 15-minute production cadence)"
    )
    
    parser.add_argument(
        "--jitter",
        type=float,
        default=0.0,
        help="Jitter as fraction of interval (e.g., 0.1 = ±10%%, default: 0.0)"
    )
    
    parser.add_argument(
        "--failure-rate",
        type=float,
        default=0.0,
        help="Simulated failure rate (0.0-1.0, default: 0.0)"
    )
    
    parser.add_argument(
        "--api-key",
        help="API key for authentication (optional)"
    )
    
    parser.add_argument(
        "--queue-file",
        default="queue.jsonl",
        help="Queue file path (default: queue.jsonl)"
    )
    
    args = parser.parse_args()
    
    simulator = DeviceSimulator(
        device_id=args.device_id,
        server_url=args.server_url,
        interval_seconds=args.interval_seconds,
        jitter=args.jitter,
        failure_rate=args.failure_rate,
        api_key=args.api_key,
        queue_file=args.queue_file
    )
    
    simulator.run()


if __name__ == "__main__":
    main()
