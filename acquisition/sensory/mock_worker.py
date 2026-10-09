"""Test-only UDP Arduino/display emulator. Never imports PsychoPy or hardware.
Used by MATLAB tests to verify the actual Java UDP bridge.
"""
import argparse
import json
import hashlib
from pathlib import Path
import time
from stimulus_runner import defaults, Sync

if __name__ == "__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port",type=int,required=True)
    parser.add_argument("--output",type=Path,required=True)
    parser.add_argument("--config",type=Path,required=True)
    args=parser.parse_args(); c=defaults(); c["sync"]["port"] = args.port
    c["_protocol_sha256"] = hashlib.sha256(args.config.read_bytes()).hexdigest()
    sync=Sync(c); running=False
    try:
        with args.output.open("w",encoding="utf-8") as file:
            print("READY",flush=True)
            while True:
                command=sync.poll(running)
                if command == "QUIT": break
                if command:
                    file.write(json.dumps(dict(event=command,run_id=sync.run_id))+"\n");file.flush()
                if command == "START": running=True
                elif command == "STOP": running=False
                time.sleep(.001)
    finally: sync.close()
