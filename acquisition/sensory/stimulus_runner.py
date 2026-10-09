"""Configurable PsychoPy gratings/bar + mock whisker + software webcam.

python stimulus_runner.py --dry-run --preset combo
python stimulus_runner.py --preview --preset combo
python stimulus_runner.py --config session.json --listen
No PsychoPy, camera, serial or scanner dependency is imported in dry-run.
"""
from __future__ import annotations
import argparse
import copy
import csv
import hashlib
import json
import math
from pathlib import Path
import random
import socket
import time
import uuid

PRESETS = {
    "combo": dict(baseline_s=12, stimulus_s=12, recovery_s=0, repetitions=3, directions_deg=[0, 90, 180, 270], protocol="combo"),
    "neuron_grating": dict(baseline_s=20, stimulus_s=16, recovery_s=5, repetitions=10, directions_deg=[0], protocol="neuron_grating"),
    "retinotopy": dict(baseline_s=2.1, stimulus_s=14, recovery_s=0, repetitions=1, directions_deg=[0], protocol="retinotopy"),
    "whisker_mock": dict(baseline_s=14, stimulus_s=6, recovery_s=15, repetitions=1, directions_deg=[0], protocol="whisker_mock"),
}

def defaults():
    return json.loads(Path(__file__).with_name("defaults.json").read_text(encoding="utf-8-sig"))

def merge(base, extra):
    result = copy.deepcopy(base)
    for key, value in extra.items():
        result[key] = merge(result[key], value) if isinstance(value, dict) and isinstance(result.get(key), dict) else value
    return result

def preset(name):
    c = merge(defaults(), PRESETS[name])
    if name == "whisker_mock":
        c["whisker"]["enabled"] = True
    return c

def validate(c):
    # MATLAB jsonencode represents a one-element numeric vector as a scalar.
    if isinstance(c.get("directions_deg"), (int, float)):
        c["directions_deg"] = [c["directions_deg"]]
    for key in ("baseline_s", "stimulus_s", "recovery_s"):
        if not isinstance(c[key], (int, float)) or not math.isfinite(c[key]) or c[key] < 0:
            raise ValueError(f"{key} must be finite and nonnegative")
    if c["stimulus_s"] <= 0:
        raise ValueError("stimulus_s must be positive")
    n = c["repetitions"]
    if isinstance(n, bool) or not isinstance(n, int) or not 1 <= n <= 10000:
        raise ValueError("repetitions must be an integer from 1 to 10000")
    if not isinstance(c["directions_deg"], list) or not c["directions_deg"] or any(not isinstance(x, (int, float)) or not math.isfinite(x) for x in c["directions_deg"]):
        raise ValueError("directions_deg must contain finite angles")
    for key in ("spatial_frequency_cpd", "temporal_frequency_hz", "bar_width_deg", "bar_speed_deg_s", "checker_period_deg", "checker_reversals_hz"):
        if not math.isfinite(c[key]) or c[key] <= 0:
            raise ValueError(f"{key} must be positive")
    if not 0 <= c["contrast"] <= 1 or c["texture"] not in ("sin", "sqr"):
        raise ValueError("contrast must be 0..1 and texture sin or sqr")
    if c["protocol"] not in PRESETS:
        raise ValueError("Unknown protocol")
    m = c["monitor"]
    for key in ("width_cm", "distance_cm", "refresh_hz"):
        if not math.isfinite(m[key]) or m[key] <= 0:
            raise ValueError(f"monitor.{key} must be positive")
    if m["warp"] not in ("none", "spherical") or len(m["eyepoint"]) != 2 or any(not 0 <= x <= 1 for x in m["eyepoint"]):
        raise ValueError("Invalid warp or eyepoint")
    if len(m["size_px"]) != 2 or any(not isinstance(x, int) or x < 100 for x in m["size_px"]):
        raise ValueError("monitor.size_px must contain two integer dimensions")
    s = c["sync"]
    if s["source"] == "udp" and s["host"] != "127.0.0.1":
        raise ValueError("UDP synchronization must use localhost 127.0.0.1")
    if s["source"] not in ("udp", "serial", "keyboard") or s["marker"] not in ("mock", "serial"):
        raise ValueError("Invalid synchronization source/marker")
    if not isinstance(s["port"], int) or not 1024 <= s["port"] <= 65535 or not math.isfinite(s["wait_timeout_s"]) or s["wait_timeout_s"] <= 0 or not math.isfinite(s["run_timeout_s"]) or s["run_timeout_s"] <= 0:
        raise ValueError("Invalid UDP port or wait timeout")
    w = c["whisker"]
    if w["implementation"] != "mock":
        raise ValueError("Only mock whisker output is supported: no piezo voltage is generated")
    if not math.isfinite(w["sample_hz"]) or not (0 < w["sample_hz"] <= 10000) or not (0 < w["frequency_hz"] < w["sample_hz"] / 2) or not math.isfinite(w["amplitude_deg"]) or w["amplitude_deg"] < 0:
        raise ValueError("Invalid whisker frequency, sampling or amplitude")
    camera = c["camera"]
    if not isinstance(camera["device"], int) or camera["device"] < 0:
        raise ValueError("Camera device must be a nonnegative integer index")
    if camera["fps"] <= 0 or not math.isfinite(camera["fps"]) or camera["backend"] not in ("usb", "mock"):
        raise ValueError("Invalid software camera parameters")
    if any(not isinstance(camera[k], int) or camera[k] < 2 for k in ("width", "height")) or len(camera["codec"]) != 4:
        raise ValueError("Invalid camera size/codec")
    if sum(c[k] for k in ("baseline_s", "stimulus_s", "recovery_s")) * c["repetitions"] * len(c["directions_deg"]) > 86400:
        raise ValueError("A session must not exceed 24 hours")
    return c

def plan(c, refresh_hz=None):
    validate(c)
    hz = refresh_hz or c["monitor"]["refresh_hz"]
    directions = c["directions_deg"] * c["repetitions"]
    if c["randomize"]:
        random.Random(c["seed"]).shuffle(directions)
    segments, frame = [], 0
    for trial, direction in enumerate(directions, 1):
        for kind, seconds in (("baseline", c["baseline_s"]), ("stimulus", c["stimulus_s"]), ("recovery", c["recovery_s"])):
            count = int(math.floor(seconds * hz + 0.5))
            if seconds > 0 and count < 1:
                raise ValueError(f"{kind} is shorter than one display frame")
            if count:
                segments.append(dict(trial=trial, kind=kind, direction_deg=direction, start_frame=frame, frames=count, requested_s=seconds, start_s=frame / hz, duration_s=count / hz))
                frame += count
    return segments

def stimulus_parameters(c, direction, elapsed):
    # Positive phase moves the 1D carrier along its local +x axis.
    # PsychoPy orientation is clockwise; negate it for 90 = screen-up.
    return dict(ori=-direction, phase=c["temporal_frequency_hz"] * elapsed,
                bar_x=c["bar_start_deg"] + c["bar_speed_deg_s"] * elapsed,
                contrast=c["contrast"] * (-1 if int(elapsed * c["checker_reversals_hz"]) % 2 else 1))

def output_folder(c, run_id=None):
    run_id = run_id or time.strftime("%Y-%m-%d_%H-%M-%S") + "_" + uuid.uuid4().hex[:8]
    # Never let a remote ID choose a filesystem path.
    safe = "".join(x for x in run_id if x.isalnum() or x in "-_")[:100]
    if not safe:
        raise ValueError("Run ID must contain a letter or number")
    folder = Path(c["output_dir"]).resolve() / safe
    folder.mkdir(parents=True, exist_ok=False)
    return folder

def dry_run(c, folder):
    segments = plan(c)
    (folder / "config.json").write_text(json.dumps(c, indent=2), encoding="utf-8")
    (folder / "schedule.json").write_text(json.dumps(segments, indent=2), encoding="utf-8")
    with (folder / "events.csv").open("w", newline="", encoding="utf-8") as file:
        writer = csv.writer(file); writer.writerow(["planned_s", "event", "trial", "direction_deg", "timing_source"])
        for s in segments:
            writer.writerow([s["start_s"], s["kind"] + "_on", s["trial"], s["direction_deg"], "SIMULATED"])
    duration = sum(s["duration_s"] for s in segments)
    from mock_arduino import MockArduino
    arduino = MockArduino(); arduino.reset(0); arduino.receive("S", now=0)
    for segment in segments:
        arduino.receive("H" if segment["kind"] == "stimulus" else "L", now=segment["start_s"])
    arduino.receive("X", now=duration); arduino.save(folder / "arduino_mock.json")
    if c["whisker"]["enabled"]:
        w = c["whisker"]
        with (folder / "whisker_mock.csv").open("w", newline="") as file:
            writer = csv.writer(file); writer.writerow(["planned_s", "requested_angle_deg", "physical_output"])
            for s in segments:
                for i in range(round(s["duration_s"] * w["sample_hz"])):
                    local = i / w["sample_hz"]
                    angle = w["amplitude_deg"] * math.sin(2 * math.pi * w["frequency_hz"] * local) if s["kind"] == "stimulus" else 0
                    writer.writerow([s["start_s"] + local, angle, "NONE_MOCK_ONLY"])
    if c["camera"]["enabled"]:
        with (folder / "camera_mock.csv").open("w", newline="") as file:
            writer = csv.writer(file); writer.writerow(["frame", "planned_s", "exposure_timing"])
            for i in range(math.ceil(duration * c["camera"]["fps"])):
                writer.writerow([i, i / c["camera"]["fps"], "SIMULATED_NOT_EXPOSURE"])
    return segments

class Sync:
    def __init__(self, c):
        self.c, self.sock, self.serial, self.peer, self.run_id = c, None, None, None, None
        self.start_perf = None
        from mock_arduino import MockArduino
        self.arduino = MockArduino()
        s = c["sync"]
        if s["source"] == "udp":
            self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            self.sock.bind((s["host"], s["port"])); self.sock.setblocking(False)
        if s["source"] == "serial" or s["marker"] == "serial":
            import serial
            self.serial = serial.Serial(s["serial_port"], s["baud"], timeout=0, write_timeout=0.1)
            time.sleep(2); self.serial.reset_input_buffer()
    def poll(self, running=False):
        if self.sock:
            while True:
                try: payload, peer = self.sock.recvfrom(8192)
                except BlockingIOError: break
                except ConnectionResetError: continue  # Windows UDP peer closed
                try: message = json.loads(payload)
                except (ValueError, UnicodeDecodeError): continue
                kind = message.get("event")
                if kind == "PING":
                    reply = {"event": "BUSY" if running else "READY", "nonce": message.get("nonce")}
                    if "_protocol_sha256" in self.c: reply["protocol_sha256"] = self.c["_protocol_sha256"]
                    self.sock.sendto(json.dumps(reply).encode(), peer)
                elif kind == "SHUTDOWN" and not running:
                    return "QUIT"
                elif kind == "START" and not running:
                    if self.c["sync"]["marker"] == "serial":
                        self.serial.write(b"L\n")
                    self.peer, self.run_id = peer, str(message.get("run_id", uuid.uuid4().hex))
                    self.start_perf = time.perf_counter()
                    self.sock.sendto(json.dumps({"event": "STARTED", "run_id": self.run_id}).encode(), peer)
                    return "START"
                elif kind == "STOP" and running and peer == self.peer and message.get("run_id") == self.run_id:
                    return "STOP"
        if self.serial and self.c["sync"]["source"] == "serial":
            while self.serial.in_waiting:
                if self.serial.read(1) == b"S" and not running:
                    self.start_perf = time.perf_counter()
                    return "START"
        return None
    def marker(self, active):
        self.arduino.receive("H" if active else "L")
        if self.serial and self.c["sync"]["marker"] == "serial":
            self.serial.write(b"H\n" if active else b"L\n")
    def close(self):
        if self.serial:
            try: self.serial.write(b"L\nX\n")
            finally: self.serial.close()
        if self.sock: self.sock.close()

def run_display(c, listen=False, preview=False, smoke_test=False):
    from psychopy import visual, event, monitors
    from camera_recorder import WebcamRecorder
    m = c["monitor"]
    monitor = monitors.Monitor(m["name"], width=m["width_cm"], distance=m["distance_cm"])
    monitor.setSizePix(m["size_px"])
    win = None; sync = None; recorder = None
    try:
        win = visual.Window(size=(800, 600) if preview else m["size_px"], screen=0 if preview else m["screen"], fullscr=False if preview else m["fullscreen"], monitor=monitor, units="deg", color=0, useFBO=True, waitBlanking=True)
        if m["warp"] == "spherical" and not preview:
            from psychopy.visual.windowwarp import Warper
            warper = Warper(win, warp="spherical", warpGridsize=300, eyepoint=m["eyepoint"])
        hz = win.getActualFrameRate(nIdentical=20, nMaxFrames=120, nWarmUpFrames=20)
        if not hz:
            raise RuntimeError("Could not measure stable display refresh. Check monitor/GPU before recording.")
        if c["temporal_frequency_hz"] >= hz / 2 or c["checker_reversals_hz"] >= hz:
            raise ValueError("Requested temporal frequency/reversal rate exceeds display sampling")
        schedule = plan(c, hz)
        grating = visual.GratingStim(win, tex=c["texture"], sf=c["spatial_frequency_cpd"], size=400, contrast=c["contrast"], autoLog=False)
        bar = visual.GratingStim(win, tex="sqrXsqr", sf=1 / c["checker_period_deg"], size=(c["bar_width_deg"], 200), autoLog=False)
        patch = visual.Rect(win, width=.10, height=.12, units="norm", pos=(.90, -.88), fillColor=-1, lineColor=None, autoLog=False)
        instructions = visual.TextStim(win, text="Armed: waiting for scan start\nSpace: manual start | Escape: stop", units="norm", height=.04, autoLog=False)
        sync = Sync(c)
        while True:
            recorder = WebcamRecorder(c["camera"], None, 0) if c["camera"]["enabled"] else None
            if recorder: recorder.prepare()
            waiting = time.monotonic(); event.clearEvents()
            while True:
                keys = event.getKeys()
                if recorder: recorder.check()
                if "escape" in keys: return
                command = sync.poll()
                if command == "QUIT": return
                if command == "START": break
                if smoke_test or (c["sync"]["source"] == "keyboard" and "space" in keys):
                    sync.start_perf = time.perf_counter(); break
                if time.monotonic() - waiting > c["sync"]["wait_timeout_s"]: raise TimeoutError("No scan start received")
                if preview or c["sync"]["source"] == "keyboard": instructions.draw()
                patch.draw(); win.flip()
            folder = output_folder(c, sync.run_id)
            session = merge(c, {"measured_refresh_hz": hz, "preview_only": preview})
            (folder / "config.json").write_text(json.dumps(session, indent=2), encoding="utf-8")
            (folder / "schedule.json").write_text(json.dumps(schedule, indent=2), encoding="utf-8")
            origin = sync.start_perf; status = "completed"; cleanup_error = None
            sync.arduino.reset(origin)
            if recorder: recorder.folder = folder; recorder.origin = origin
            win.recordFrameIntervals = False; win.frameIntervals = []
            with (folder / "events.csv").open("w", newline="", encoding="utf-8") as file:
                writer = csv.writer(file); writer.writerow(["actual_s", "event", "trial", "direction_deg", "source"])
                def marker(active, segment):
                    sync.marker(active)
                    writer.writerow([time.perf_counter()-origin, "marker_high" if active else "marker_low", segment["trial"], segment["direction_deg"], "screen_flip_callback_USB_marker_not_TTL_measurement"])
                    file.flush()
                def boundary(segment):
                    writer.writerow([time.perf_counter()-origin, segment["kind"]+"_on", segment["trial"], segment["direction_deg"], "screen_flip_callback"])
                previous_active = False
                try:
                    if recorder: recorder.start()
                    win.recordFrameIntervals = True
                    for segment in schedule:
                        active = segment["kind"] == "stimulus"
                        for frame in range(segment["frames"]):
                            if "escape" in event.getKeys() or sync.poll(running=True) == "STOP":
                                status = "interrupted"; raise InterruptedError("Stop requested")
                            parameters = stimulus_parameters(c, segment["direction_deg"], frame / hz)
                            if active and c["protocol"] != "whisker_mock":
                                if c["protocol"] == "retinotopy":
                                    bar.pos = (parameters["bar_x"], 0); bar.contrast = parameters["contrast"]; bar.draw()
                                else:
                                    grating.ori = parameters["ori"]; grating.phase = parameters["phase"]; grating.draw()
                            patch.fillColor = 1 if active else -1; patch.draw()
                            if frame == 0 and active != previous_active:
                                win.callOnFlip(marker, active, segment)
                            if frame == 0: win.callOnFlip(boundary, segment)
                            win.flip(); previous_active = active
                            if smoke_test and active and frame == segment["frames"] // 2:
                                win.getMovieFrame(buffer="front"); win.saveMovieFrames(str(folder / "preview.png"))
                            if recorder: recorder.check()
                    if previous_active:
                        patch.fillColor = -1; patch.draw(); win.callOnFlip(marker, False, schedule[-1]); win.flip()
                        previous_active = False
                    if recorder and listen and c["sync"]["source"] == "udp" and c["camera"]["record_until_scan_stop"]:
                        win.recordFrameIntervals = False
                        writer.writerow([time.perf_counter()-origin, "protocol_complete_camera_continues", 0, 0, "software"]); file.flush()
                        while sync.poll(running=True) != "STOP":
                            if "escape" in event.getKeys():
                                status = "interrupted"; break
                            if time.perf_counter()-origin > c["sync"]["run_timeout_s"]:
                                raise TimeoutError("No scanner STOP received before run_timeout_s")
                            recorder.check(); patch.fillColor = -1; patch.draw(); win.flip()
                except InterruptedError:
                    pass
                except BaseException:
                    status = "error"; raise
                finally:
                    win.recordFrameIntervals = False
                    patch.fillColor = -1; patch.draw()
                    if previous_active: win.callOnFlip(marker, False, segment)
                    win.flip()
                    sync.marker(False)
                    if recorder:
                        try: recorder.stop()
                        except Exception as error: cleanup_error = error; status = "error"
                        recorder = None
                    writer.writerow([time.perf_counter()-origin, status, 0, 0, "software"]); file.flush()
                    timing = {"status": status, "elapsed_s": time.perf_counter()-origin, "start_receive_perf_counter_s": origin, "refresh_hz": float(hz), "dropped_frames": int(sum(x > 1.5 / hz for x in win.frameIntervals[1:])), "intervals_s": [float(x) for x in win.frameIntervals[1:]], "whisker_output": "MOCK_ONLY", "cleanup_error": str(cleanup_error) if cleanup_error else None}
                    (folder / "timing.json").write_text(json.dumps(timing, indent=2), encoding="utf-8")
                    sync.arduino.save(folder / "arduino_mock.json")
                    if c["whisker"]["enabled"]:
                        mock_plan = folder / "mock_plan"
                        mock_plan.mkdir()
                        dry_run(c, mock_plan)
                if cleanup_error: raise cleanup_error
            print(f"{status}: {folder}", flush=True)
            sync.run_id = None
            if not listen or status != "completed": return
    finally:
        if recorder: recorder.stop()
        if sync: sync.close()
        if win: win.close()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path)
    parser.add_argument("--preset", choices=PRESETS)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--validate-only", action="store_true", help="Validate configuration without any display, camera or serial access")
    parser.add_argument("--preview", action="store_true")
    parser.add_argument("--listen", action="store_true")
    parser.add_argument("--smoke-test", action="store_true", help="Short automatic preview; mock markers, no camera/hardware")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    c = preset(args.preset) if args.preset else defaults()
    if args.config:
        c = merge(c, json.loads(args.config.read_text(encoding="utf-8-sig")))
        c["_protocol_sha256"] = hashlib.sha256(args.config.read_bytes()).hexdigest()
    if args.output: c["output_dir"] = str(args.output)
    if args.smoke_test: args.preview = True
    if args.preview:
        c = merge(c, {"baseline_s": 1, "stimulus_s": 2, "recovery_s": 1, "repetitions": 1, "randomize": False, "camera": {"enabled": False}, "sync": {"source": "keyboard", "marker": "mock"}})
    if args.smoke_test:
        c = merge(c, {"baseline_s": .25, "stimulus_s": 1, "recovery_s": .25, "directions_deg": [0]})
    validate(c)
    if args.validate_only:
        schedule = plan(c)
        print(f"VALID: {len(schedule)} segments, {sum(s['duration_s'] for s in schedule):g} seconds")
        return
    if args.dry_run:
        folder = output_folder(c); schedule = dry_run(c, folder)
        print(f"DRY RUN: {len(schedule)} segments, {sum(s['duration_s'] for s in schedule):g} seconds. {folder}")
    else: run_display(c, args.listen, args.preview, args.smoke_test)

if __name__ == "__main__":
    main()
