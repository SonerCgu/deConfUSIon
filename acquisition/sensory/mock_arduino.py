"""In-memory Arduino marker/whisker model. Never opens a COM port."""
import json
import math
import time

class MockArduino:
    def __init__(self):
        self.reset(time.perf_counter())

    def reset(self, origin):
        self.origin = origin
        self.active = False
        self.events = []

    def receive(self, command, now=None):
        now = time.perf_counter() if now is None else now
        if command not in ("S", "H", "L", "X"):
            raise ValueError("Commands: S start, H active, L inactive, X stop")
        if command == "H": self.active = True
        elif command in ("L", "X"): self.active = False
        self.events.append(dict(command=command, elapsed_s=now-self.origin,
                                marker_high=self.active, physical_output="NONE"))

    def angle(self, elapsed_s, frequency_hz=5, amplitude_deg=20):
        return amplitude_deg * math.sin(2 * math.pi * frequency_hz * elapsed_s) if self.active else 0.0

    def save(self, path):
        path.write_text(json.dumps(dict(implementation="MOCK", events=self.events,
                                       physical_output="NONE"), indent=2), encoding="utf-8")
