"""Hardware-free regression tests; camera encoding test needs OpenCV/numpy."""
import csv
import json
from pathlib import Path
import socket
import tempfile
import time
import unittest
from unittest.mock import patch
from stimulus_runner import defaults, preset, plan, validate, dry_run, output_folder, stimulus_parameters, Sync
from mock_arduino import MockArduino
from camera_recorder import WebcamRecorder

class SensoryTests(unittest.TestCase):
    def test_combo_schedule_and_speed(self):
        c = preset("combo"); s = plan(c, 60)
        self.assertEqual(len(s), 24)
        self.assertEqual(sum(x["duration_s"] for x in s), 288)
        angles = [x["direction_deg"] for x in s if x["kind"] == "stimulus"]
        self.assertEqual(sorted(angles), [0]*3 + [90]*3 + [180]*3 + [270]*3)
        self.assertEqual(c["temporal_frequency_hz"]/c["spatial_frequency_cpd"], 10)
        self.assertEqual(s, plan(c, 60))

    def test_scalar_matlab_direction(self):
        c = preset("neuron_grating"); c["directions_deg"] = 0
        self.assertEqual(len(plan(c)), 30)
        self.assertEqual(sum(x["duration_s"] for x in plan(c)), 410)

    def test_bar_units_and_reversal(self):
        c = preset("retinotopy")
        self.assertEqual(stimulus_parameters(c, 0, 14)["bar_x"], 28)
        self.assertEqual(stimulus_parameters(c, 0, 1/6)["contrast"], -1)
        self.assertEqual(stimulus_parameters(c, 0, 2/6)["contrast"], 1)

    def test_invalid_protocols(self):
        for key, value in (("baseline_s", -1), ("stimulus_s", 0), ("repetitions", 1.1), ("directions_deg", []), ("contrast", 2)):
            c = defaults(); c[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError): validate(c)
        c = defaults(); c["whisker"]["implementation"] = "real"
        with self.assertRaises(ValueError): validate(c)
        c = defaults(); c["sync"]["host"] = "0.0.0.0"
        with self.assertRaises(ValueError): validate(c)

    def test_frame_quantization(self):
        c = defaults(); c.update(baseline_s=.023, stimulus_s=.101, recovery_s=0, repetitions=1, directions_deg=[0])
        s = plan(c, 60)
        self.assertEqual([x["frames"] for x in s], [1,6])
        c["stimulus_s"] = .001
        with self.assertRaises(ValueError): plan(c, 60)

    def test_dry_whisker_and_camera(self):
        with tempfile.TemporaryDirectory() as d:
            c = preset("whisker_mock"); c.update(output_dir=d, baseline_s=.1, stimulus_s=.2, recovery_s=.1)
            c["camera"]["enabled"] = True
            folder = output_folder(c); dry_run(c, folder)
            with (folder / "whisker_mock.csv").open() as file: rows = list(csv.DictReader(file))
            self.assertEqual(len(rows), 400)
            self.assertEqual(float(rows[150]["requested_angle_deg"]), 20)
            self.assertTrue(all(float(x["requested_angle_deg"]) == 0 for x in rows[:100]+rows[300:]))
            self.assertEqual(rows[150]["physical_output"], "NONE_MOCK_ONLY")
            self.assertTrue((folder / "camera_mock.csv").exists())

    def test_output_path_and_overwrite(self):
        with tempfile.TemporaryDirectory() as d:
            c = defaults(); c["output_dir"] = d
            f = output_folder(c, "../experiment")
            self.assertEqual(f.parent, Path(d))
            with self.assertRaises(FileExistsError): output_folder(c, "../experiment")
            with self.assertRaises(ValueError): output_folder(c, "../")

    def test_arduino_stop(self):
        a = MockArduino(); a.receive("H")
        self.assertAlmostEqual(a.angle(.05), 20)
        a.receive("X"); self.assertFalse(a.active); self.assertEqual(a.angle(.05), 0)
        with self.assertRaises(ValueError): a.receive("UNKNOWN")

    def test_udp_handshake_and_session_stop(self):
        c = defaults()
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
            probe.bind(("127.0.0.1",0)); c["sync"]["port"] = probe.getsockname()[1]
        sync = Sync(c)
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as client:
                client.settimeout(1); peer = ("127.0.0.1", c["sync"]["port"])
                def send(event, **kw):
                    client.sendto(json.dumps(dict(event=event, **kw)).encode(), peer)
                send("PING", nonce="123"); sync.poll()
                self.assertEqual(json.loads(client.recv(1000)),dict(event="READY",nonce="123"))
                send("START", run_id="animal1"); self.assertEqual(sync.poll(), "START")
                self.assertEqual(json.loads(client.recv(1000))["event"], "STARTED")
                self.assertIsNotNone(sync.start_perf)
                send("STOP", run_id="other"); self.assertIsNone(sync.poll(True))
                send("PING", nonce="busy"); sync.poll(True)
                self.assertEqual(json.loads(client.recv(1000))["event"], "BUSY")
                send("STOP", run_id="animal1"); self.assertEqual(sync.poll(True), "STOP")
        finally: sync.close()

    def test_mock_camera_writes_playable_movie_and_timestamps(self):
        import cv2
        with tempfile.TemporaryDirectory() as d:
            c = defaults()["camera"]; c.update(backend="mock",width=64,height=48,fps=20)
            recorder = WebcamRecorder(c, Path(d), time.perf_counter())
            recorder.start(); time.sleep(.27); recorder.stop()
            with (Path(d)/"camera_frames.csv").open() as file: rows = list(csv.DictReader(file))
            self.assertGreaterEqual(len(rows), 4)
            times = [float(x["receive_s_from_start"]) for x in rows]
            self.assertEqual(times, sorted(times))
            self.assertTrue(all(x["exposure_time_known"] == "False" for x in rows))
            cap = cv2.VideoCapture(str(Path(d)/"face.avi"))
            try:
                self.assertTrue(cap.isOpened()); ok, frame = cap.read()
                self.assertTrue(ok); self.assertEqual(frame.shape[:2], (48,64))
                self.assertEqual(int(cap.get(cv2.CAP_PROP_FRAME_COUNT)), len(rows))
            finally: cap.release()

    def test_usb_reader_drains_while_armed_and_closes_on_disconnect(self):
        import numpy as np
        class Camera:
            calls = 0
            released = False
            fail = False
            def isOpened(self): return True
            def set(self, *args): pass
            def read(self):
                time.sleep(.01); self.calls += 1
                return (False, None) if self.fail else (True, np.zeros((48,64,3), dtype=np.uint8))
            def release(self): self.released = True
        with tempfile.TemporaryDirectory() as d:
            camera = Camera(); c=defaults()["camera"]; c.update(backend="usb",width=64,height=48)
            with patch("cv2.VideoCapture", return_value=camera):
                r=WebcamRecorder(c, Path(d), time.perf_counter()); r.prepare(); time.sleep(.05)
                self.assertGreater(camera.calls, 3); self.assertEqual(r.frames,0)
                self.assertFalse((Path(d)/"camera_frames.csv").exists())
                r.origin=time.perf_counter();r.start();time.sleep(.05);camera.fail=True;time.sleep(.05)
                with self.assertRaisesRegex(RuntimeError,"disconnected"): r.stop()
                self.assertTrue(camera.released)
                with (Path(d)/"camera_frames.csv").open() as file: rows=list(csv.DictReader(file))
                self.assertGreater(len(rows),0)
                self.assertTrue(all(float(x["receive_s_from_start"])>=0 for x in rows))

if __name__ == "__main__": unittest.main()
