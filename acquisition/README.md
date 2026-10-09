# Visual stimulation, mock whisker stimulation and USB face recording

The existing acquisition controller now has a **VISUAL / WHISKER / CAMERA** button. It opens a companion panel with Protocol, Mock whisker, Visual display, USB camera, Connection and Advanced JSON tabs. The new acquisition feature defaults to **disabled**. Existing scan modes and accessory schedules keep their existing paths when it is disabled.

The companion panel was tested with MATLAB R2023b and PsychoPy 2026.2.4 on Windows. Its modern UI requires MATLAB with `uifigure`/`uigridlayout`; it does not change the vendor scanner API or replace its launcher.

## Start here

Launch your acquisition controller through the usual OpenfUS/company launcher. With the acquisition folder on the MATLAB path, the entry script is:

```matlab
vfUSI_StimBox_TTL_EACH_FRAME_OR_TRIGGER_ACCESSORIES_PARAMETERS
```

1. Open **VISUAL / WHISKER / CAMERA**. Choose a protocol and edit durations, repetitions, directions, contrast and frequency.
2. Set the measured display width, eye distance, resolution and screen index. `0` means the first screen; `1` means the second. The shipped 59.8 cm width and 18 cm distance are editable examples, not calibration of your monitor.
3. In Connection, select the PsychoPy Python executable. The installed Windows standalone location is detected automatically when present. Choose an output folder.
4. **SAVE SETTINGS** validates and writes a timestamped JSON snapshot. **TEST MOCK** writes planned event/whisker/camera traces and simulated Arduino messages without accessing hardware. **SCREEN PREVIEW** shows shortened stimuli on the first display in a small window; Space starts, Escape stops. Preview disables serial markers and camera recording.
5. For a real visual session, enable USB face recording if wanted, then click **ARM PsychoPy worker**. This opens and settles the camera before waiting for acquisition. The panel verifies a READY reply before reporting that the worker is armed.
6. In the acquisition controller, choose **Functional fUSI** and disable Motor. Choose enough scan frames for the entire protocol, then START. STOP or scan completion sends the worker its matching session stop. Escape in the stimulus window also stops it.

The companion can be opened alone with `vfusiSensoryGUI` for preparation and testing. To apply settings to an acquisition, open it from that controller's button. Reloading Defaults resets sensory mode to disabled.

When Connection mode is **mock**, an actual scan receives only software event logging; it does not open a stimulus window or move whiskers. Use TEST MOCK to generate the angle waveform. When mode is **psychopy**, ARM the worker first. The `whisker_mock` preset displays gray plus its marker patch, logs mock whisker events and can record the USB camera; it still never drives a piezo. Sensory sessions currently support Functional/Doppler with Motor disabled; existing motor/anatomy modes can still be used with sensory disabled.

## Presets and their provenance

| Internal name | Stimulus | Baseline / stimulus / recovery | Repetitions |
|---|---|---|---|
| `combo` | Full-field drifting square-wave gratings; four cardinal directions | 12 / 12 / 0 s | Three per direction, 288 s total |
| `neuron_grating` | Single-direction drifting grating | 20 / 16 / 5 s | Ten by default, editable |
| `retinotopy` | Moving vertical checkerboard bar | 2.1 / 14 / 0 s | One by default, editable |
| `whisker_mock` | Requested sinusoidal whisker angle, **no physical output** | 14 / 6 / 15 s | One by default, editable |

The COMBO timing, 20-degree grating period, 10 degrees/s speed and cardinal-direction counts were verified in the [PLOS Biology methods](https://journals.plos.org/plosbiology/article?id=10.1371/journal.pbio.3002664). A period of 20 degrees means spatial frequency `1/20 = 0.05 cycles/degree`; temporal frequency is `10 × 0.05 = 0.5 cycles/s`.

The other presets follow the table in your local **Mouse_Stimulation_and_Face_Recording_Setup_Guide.pdf**, pages 2 and 6–8. The requested [Brunner et al. Neuron paper](https://doi.org/10.1016/j.neuron.2020.09.020) could be identified, but its publisher full text was inaccessible in this session. These presets are consequently labelled as guide-derived, not independently verified reproductions of its methods. Ten repeats for the trial grating are an editable guide example.

The guide uses both “6 Hz reversal” and “reverse every 1/12 s.” Those are different conventions. Here `checker_reversals_hz = 6` explicitly means **six contrast sign changes per second**, i.e. three complete black–white–black cycles/s. Set it to `12` for six complete cycles/s. `checker_period_deg = 25` is one full spatial checkerboard cycle, matching the guide's `sf=1/25` code. Set the period explicitly if your intended checker size differs.

Whisker amplitude means **peak angle**, not peak-to-peak: 20 degrees produces a requested ±20 degree waveform. The guide uses amplitude terminology inconsistently; no angle-to-voltage or injection-related inference is made here. The mock is not a calibrated piezo driver.

## Configuring PsychoPy

All parameters live in `sensory/defaults.json`; the GUI writes session copies instead of overwriting it. Use Advanced JSON → Import to edit less common parameters, then SAVE SETTINGS. Important fields include:

- `protocol`, `baseline_s`, `stimulus_s`, `recovery_s`, `repetitions`, `directions_deg`, `randomize`, `seed`.
- `spatial_frequency_cpd`, `temporal_frequency_hz`, `contrast`, `texture` (`sin` or `sqr`). Speed in degrees/s equals temporal frequency divided by spatial frequency.
- `bar_width_deg`, `bar_speed_deg_s`, `bar_start_deg`, `checker_period_deg`, `checker_reversals_hz`. The default retinotopy bar moves from −28 to +28 degrees in 14 s; adjust its path for your visual field.
- `monitor.name`, width, distance, pixels, screen, fullscreen, `warp` (`none` or `spherical`), `eyepoint` (fraction of screen width/height, origin at bottom left).
- `camera.enabled`, `device`, requested `fps`, width, height, `backend` (`usb` or `mock`), four-character codec (`MJPG` default), `record_until_scan_stop`.
- `whisker.enabled`, frequency, peak angular amplitude and sample rate. `implementation` must be `mock`.

Directions are **screen motion directions**: 0 right, 90 up, 180 left, 270 down. PsychoPy's clockwise orientation is converted accordingly. Which direction is nasal-to-temporal depends on your monitor/eye placement and must be set from the actual rig.

Create/calibrate the selected monitor profile in PsychoPy Monitor Center, including luminance/gamma. Loading a profile does not measure your monitor or guarantee that digital mid-gray equals half the emitted luminance. The worker uses the profile and the explicit geometry overrides. Spherical projection uses PsychoPy's [Warper](https://psychopy.org/api/visual/windowwarp.html); preview leaves it off. Confirm the photodiode patch's physical location after warping.

The worker measures a stable refresh rate before arming, rounds segment durations to whole display frames, and records requested versus frame-quantized durations. Stimuli advance by display frames; dropped frames can stretch their duration. Review actual boundaries and `timing.json` instead of assuming perfect nominal timing. Screen markers are queued with PsychoPy's flip callback; a USB serial write is not a measurement of the physical TTL edge or photon onset. [PsychoPy timing documentation](https://psychopy.org/coder/codeStimuli.html)

## Software synchronization and webcam recording

The optional scanner callback sends one localhost UDP START at its first acquired-frame callback. It preserves the RF argument and original scanner frame indices. It does not wait for acknowledgements or screen refresh during acquisition; the START acknowledgement is checked after the scan. A missing acknowledgement is logged as a synchronization error and does not prevent saving the scanner data. READY must match both a fresh nonce and the saved protocol's SHA-256 hash, preventing a stale worker with different settings from being used.

The start event may occur **after** the first acquisition frame has completed. It is not the scanner's physical start TTL. The scan's JSONL log stores elapsed and wall-clock times; the display/camera logs share the worker's monotonic start-receive clock. Match them by `run_id`, and treat UDP latency and camera buffering as unmeasured offsets. This is software synchronization, not guaranteed exposure synchronization.

USB webcam frames are written to `face.avi` with `camera_frames.csv` timestamps taken immediately after each camera read. They are **host receive times**, not exposure times. The webcam may ignore requested FPS/resolution; actual saved image size follows the returned frame. AVI playback is at the requested constant FPS; use the CSV to align the actual received frames. Camera disconnect/write/start errors are reported, and timing logs are retained.

By default an enabled camera continues recording the gray-screen tail until scanner STOP when using the listening acquisition worker. Uncheck **Record until scanner STOP** to end it with the stimulus protocol. A standalone keyboard run ends with its protocol. `sync.run_timeout_s` limits waiting for scanner STOP (24 hours by default). If you need TTL/exposure alignment later, use a camera/DAQ with a measured exposure signal; the software webcam path does not pretend to provide that signal.

Serial markers are optional and default to mock. A compatible Arduino accepts `H`/`L` for marker high/low and `X` for stop; it can emit `S` for a hardware-started standalone serial session. The serial COM port must differ from enabled StimBox/PulsePal ports. No Arduino firmware is flashed, and no real whisker actuation is implemented. `mock_arduino.py` simulates these messages in memory and records requested states only.

## Output and timing

Each scan has a unique timestamp + UUID. Its acquisition MAT metadata contains `sensory.run_id`, log folder, an immutable protocol snapshot and whether the worker START was acknowledged. The same ID names its PsychoPy/camera folder in the selected output root.

| Output | Meaning |
|---|---|
| `scan_<run_id>/protocol.json` | Snapshot used for that scan |
| `scan_<run_id>/scan_events.jsonl` | ARMED, START, original scanner callback FRAME indices, acknowledgement/error, STOP |
| `<run_id>/config.json`, `schedule.json` | Actual configuration and frame-quantized schedule |
| `<run_id>/events.csv` | Actual flip-callback stimulus/baseline/recovery boundaries, marker requests, completion/stop status |
| `<run_id>/timing.json` | Measured refresh, actual elapsed time, long-frame count/intervals, error status |
| `<run_id>/face.avi`, `camera_frames.csv`, `camera_info.json` | Optional webcam video and software timing information |
| `arduino_mock.json` | Simulated commands; physical output is NONE |
| `whisker_mock.csv`, `camera_mock.csv` | Planned dry-run samples, clearly labelled simulated |

The scan validator requires enough duration after the first callback: `(n_frames − 1) × nblocksImage × tr_unit_s ≥ protocol duration`. This is a nominal preflight check; actual scan and display timing remain logged. For example a 288 s COMBO run at nominal TR 0.32 s needs at least 901 frames. Leave additional recovery/timing margin as appropriate for your protocol.

## Tests you can run

From the repository folder in PowerShell, use the Python bundled with your PsychoPy installation:

```powershell
$stimPython = "$env:LOCALAPPDATA\Programs\PsychoPy\python.exe"
& $stimPython acquisition/sensory/stimulus_runner.py --dry-run --preset whisker_mock
& $stimPython acquisition/sensory/stimulus_runner.py --preview --preset combo
& $stimPython acquisition/sensory/stimulus_runner.py --preview --preset retinotopy
& $stimPython acquisition/sensory/stimulus_runner.py --smoke-test
& $stimPython -m unittest discover -s acquisition/sensory -p test_sensory.py -v
& $stimPython acquisition/sensory/verify_display.py --output validation/sensory/udp-display
```

The last command opens a real small PsychoPy window, tests two complete UDP-triggered sessions with a **mock** webcam, then a stop during stimulation. It checks video/timestamps, re-arm, cleared markers and saved cancellation status, and closes its own worker. It does not call the scanner, open a real camera or access a COM port. `--smoke-test` automatically starts a short hardware-free preview and saves a screenshot; taking that screenshot intentionally interferes with timing, so it is not a timing benchmark.

For standalone hardware sessions:

```powershell
& $stimPython acquisition/sensory/stimulus_runner.py --config "D:\path\Protocol_session.json" --listen
```

Use the GUI's ARM button for controller integration; it handles READY verification and applying the matching settings. A manually launched worker must use the same port/config as the controller.

To test your actual USB camera without a scanner, make a copy of a saved JSON, set `sync.source` to `keyboard` and `sync.marker` to `mock`, enable `camera` with `backend: "usb"`, and set a short protocol on screen 0 with fullscreen false. Run the worker with `--config` and **without** `--preview`/`--listen`. Space starts, Escape stops; it saves an AVI and timestamps. Preview deliberately disables camera recording, so that test must use the copied keyboard configuration.

MATLAB regression tests use an injected mock scanner/file service and an in-memory UDP worker; no vendor scan or accessory hardware is started:

```matlab
addpath('acquisition');
results = runtests('tests/testSensoryAcquisition.m');
assertSuccess(results);
```

Actual scanner, serial-marker electrical timing and your particular USB webcam have not been bench-tested by these software checks. Verification artifacts for this session are in `validation/sensory`.
