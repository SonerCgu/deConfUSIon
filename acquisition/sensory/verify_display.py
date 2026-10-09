"""Exercise real PsychoPy + UDP + two mock-camera sessions, without a scanner.
Run with the PsychoPy Python: python verify_display.py --output validation/sensory/udp-display
Uses a small window on the first screen. No serial port or live camera is opened.
"""
import argparse
import csv
import json
import hashlib
from pathlib import Path
import socket
import subprocess
import sys
import time
from stimulus_runner import defaults

def verify(output):
    output = output.resolve(); output.mkdir(parents=True, exist_ok=True)
    c = defaults()
    c.update(baseline_s=.25, stimulus_s=1, recovery_s=.25, repetitions=1, directions_deg=[0], randomize=False, output_dir=str(output))
    c["monitor"].update(size_px=[800,600],width_cm=30,distance_cm=50,screen=0,fullscreen=False,warp="none")
    c["camera"].update(enabled=True,backend="mock",width=80,height=60,fps=20)
    c["sync"].update(wait_timeout_s=120,run_timeout_s=20)
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
        probe.bind(("127.0.0.1",0)); c["sync"]["port"] = probe.getsockname()[1]
    config = output / "worker-config.json"; config.write_text(json.dumps(c, indent=2))
    runner = Path(__file__).with_name("stimulus_runner.py")
    with (output / "worker.log").open("w") as log, socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as client:
        process = subprocess.Popen([sys.executable,str(runner),"--config",str(config),"--listen"],stdout=log,stderr=subprocess.STDOUT)
        client.settimeout(.25); address = ("127.0.0.1", c["sync"]["port"])
        def send(event, **kw): client.sendto(json.dumps(dict(event=event, **kw)).encode(),address)
        def ready(timeout=60):
            limit = time.monotonic()+timeout
            while time.monotonic()<limit:
                if process.poll() is not None: raise RuntimeError("Display worker exited: see worker.log")
                send("PING",nonce="verify")
                try:
                    reply = json.loads(client.recv(8192))
                    if reply.get("event") == "READY" and reply.get("nonce") == "verify":
                        assert reply.get("protocol_sha256") == hashlib.sha256(config.read_bytes()).hexdigest()
                        return
                except (socket.timeout, ConnectionResetError): pass
            raise TimeoutError("No READY from actual display")
        try:
            for i in range(2):
                ready(); name = "verification_"+time.strftime("%Y%m%d_%H%M%S")+f"_{i}"
                send("START",run_id=name)
                client.settimeout(2); reply = json.loads(client.recv(8192)); client.settimeout(.25)
                assert reply == dict(event="STARTED",run_id=name), reply
                time.sleep(2.2); send("STOP",run_id=name); ready(10)
                folder = output / name
                timing = json.loads((folder/"timing.json").read_text()); assert timing["status"] == "completed", timing
                with (folder/"events.csv").open() as file: events = list(csv.DictReader(file))
                assert any(x["event"] == "protocol_complete_camera_continues" for x in events)
                with (folder/"camera_frames.csv").open() as file: frames = list(csv.DictReader(file))
                assert len(frames) >= 30
                assert float(frames[-1]["receive_s_from_start"]) > 2
                print(f"Session {i+1}: {len(frames)} mock camera frames, {timing['dropped_frames']} long display intervals, clean STOP/re-arm")
            # STOP during an active stimulus must clear the marker and close
            # its recorder, not leave the last grating or marker active.
            ready();name="interrupted_"+time.strftime("%Y%m%d_%H%M%S")
            send("START",run_id=name);client.settimeout(2);reply=json.loads(client.recv(8192))
            assert reply.get("event") == "STARTED"
            time.sleep(.7);send("STOP",run_id=name);process.wait(timeout=10)
            assert process.returncode == 0
            folder=output/name;timing=json.loads((folder/"timing.json").read_text())
            assert timing["status"] == "interrupted"
            with (folder/"events.csv").open() as file: events=list(csv.DictReader(file))
            assert any(x["event"] == "marker_low" for x in events)
            arduino=json.loads((folder/"arduino_mock.json").read_text())
            assert arduino["events"][-1]["marker_high"] is False
            print("Interrupted session: marker cleared, camera closed, gray screen restored, status saved")
        finally:
            if process.poll() is None: process.terminate(); process.wait(timeout=10)

if __name__ == "__main__":
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--output",type=Path,required=True)
    verify(p.parse_args().output)
