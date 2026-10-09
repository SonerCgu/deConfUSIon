"""USB webcam AVI with per-received-frame timestamps; no TTL claims."""
from __future__ import annotations
import csv
import json
from pathlib import Path
import threading
import time

class WebcamRecorder:
    def __init__(self, config, folder, origin):
        self.config, self.folder, self.origin = config, folder, origin
        self.cap = self.writer = self.thread = None
        self.timestamp_file = self.csv_writer = None
        self.recording = threading.Event()
        self.stop_event = threading.Event(); self.error = None; self.frames = 0
    def prepare(self):
        import cv2
        self.cv = cv2
        if self.config["backend"] == "mock": return
        # Open/settle BEFORE the scan start so startup cannot delay baseline.
        self.cap = cv2.VideoCapture(self.config["device"])
        if not self.cap.isOpened():
            self.cap.release(); self.cap = None
            raise RuntimeError("USB camera could not open. Select the correct device or disable recording.")
        self.cap.set(cv2.CAP_PROP_FRAME_WIDTH, self.config["width"])
        self.cap.set(cv2.CAP_PROP_FRAME_HEIGHT, self.config["height"])
        self.cap.set(cv2.CAP_PROP_FPS, self.config["fps"])
        ok, frame = self.cap.read()
        if not ok: self.cap.release(); self.cap = None; raise RuntimeError("USB camera returned no image")
        self.shape = frame.shape[:2]
        # Keep draining the driver while armed, rather than accumulating stale
        # frames in its queue until the scan START arrives.
        self.thread = threading.Thread(target=self._record, name="WebcamRecorder", daemon=True)
        self.thread.start()
    def start(self):
        if not hasattr(self, "cv"): self.prepare()
        if self.cap is None and self.config["backend"] != "mock": self.prepare()
        if self.config["backend"] == "mock": self.shape = (self.config["height"], self.config["width"])
        h, w = self.shape
        self.writer = self.cv.VideoWriter(str(Path(self.folder) / "face.avi"), self.cv.VideoWriter_fourcc(*self.config["codec"]), self.config["fps"], (w, h))
        if not self.writer.isOpened(): self.stop(); raise RuntimeError("Camera video codec could not open")
        self.timestamp_file = (Path(self.folder) / "camera_frames.csv").open("w", newline="", encoding="utf-8")
        self.csv_writer = csv.writer(self.timestamp_file)
        self.csv_writer.writerow(["frame", "receive_s_from_start", "receive_perf_counter_s", "exposure_time_known"])
        self.recording.set()
        if self.config["backend"] == "mock":
            self.thread = threading.Thread(target=self._record, name="WebcamRecorder", daemon=True); self.thread.start()
    def _record(self):
        import numpy as np
        period = 1 / self.config["fps"]; next_frame = time.perf_counter()
        try:
            while not self.stop_event.is_set():
                if self.config["backend"] == "mock":
                    if self.stop_event.wait(max(0, next_frame-time.perf_counter())): break
                    frame = np.full((*self.shape, 3), self.frames % 256, dtype=np.uint8); next_frame += period
                else:
                    ok, frame = self.cap.read()
                    if not ok: raise RuntimeError("USB camera disconnected or failed to return a frame")
                now = time.perf_counter()
                if self.stop_event.is_set(): break
                if not self.recording.is_set(): continue
                if frame.shape[:2] != self.shape:
                    raise RuntimeError("Camera frame size changed during recording")
                self.writer.write(frame)
                self.csv_writer.writerow([self.frames, now-self.origin, now, False]); self.timestamp_file.flush(); self.frames += 1
        except BaseException as error: self.error = error
    def check(self):
        if self.error: raise RuntimeError(f"Camera recording failed: {self.error}") from self.error
    def stop(self):
        self.stop_event.set()
        if self.thread:
            self.thread.join(timeout=3)
            if self.thread.is_alive():
                # Never release a writer while its thread may still write.
                raise RuntimeError("USB camera driver blocked. Recording thread did not stop; restart the stimulus worker.")
        if self.writer: self.writer.release(); self.writer = None
        if self.timestamp_file: self.timestamp_file.close(); self.timestamp_file = None
        if self.cap: self.cap.release(); self.cap = None
        if self.folder:
            (Path(self.folder) / "camera_info.json").write_text(json.dumps({"frames_written": self.frames, "requested_fps": self.config["fps"], "backend": self.config["backend"], "timestamp_role": "Host receive time; not camera exposure time", "AVI_playback": "Constant requested FPS. Use camera_frames.csv for actual time alignment."}, indent=2), encoding="utf-8")
        self.check()
