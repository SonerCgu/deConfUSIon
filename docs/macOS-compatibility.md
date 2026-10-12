# macOS setup and verification

Use MATLAB **R2023b or newer** for the current 3D model and atlas workflows,
with Image Processing Toolbox. Apple Silicon users should use native MATLAB;
MathWorks requires a compatible Java runtime for that installation. Follow
[MathWorks' Apple Silicon instructions](https://www.mathworks.com/support/requirements/apple-silicon.html).
Install the additional toolboxes required by the processing modules you use.

Open the repository folder in MATLAB, then run:

```matlab
deConfUSIon_setup
deConfUSIon
```

Use the actual mounted share, e.g. `/Volumes/fUS/Project_MMP9/RawData/...`.
Windows drive letters are not macOS mount points. Once a file under a project's
RawData or AnalysedData folder is opened, the loader remembers that project
root. Saved Windows paths can then be resolved against the same project on the
new mount. The resolver requires the complete project-relative suffix and
refuses ambiguous matches. For a project that has not yet been opened:

```matlab
setpref('deConfUSIon','dataRoots',{'/Volumes/fUS/Project_MMP9'})
```

**Registration:** install native ITK-SNAP and Greedy. Discovery recognises
ITK-SNAP `.app` bundles, `/opt/homebrew/bin`, `/usr/local/bin`, PATH and saved
preferences. Explicit paths can be set with:

```matlab
setpref('deConfUSIon','itksnapExecutable','/Applications/ITK-SNAP.app')
setpref('deConfUSIon','greedyExecutable','/opt/homebrew/bin/greedy')
```

The viewer launch removes MATLAB's conflicting Qt environment and writes a
log beside the workspace. Use binaries built for your Mac's architecture.
Executable registration tools must have permission to run; permissions and
macOS security prompts are controlled by the operating system.

**Exports:** Open saved folder uses Finder on macOS. MATLAB supports MPEG-4
VideoWriter on Windows and macOS; the regression suite encodes and decodes a
small movie. [VideoWriter documentation](https://www.mathworks.com/help/matlab/ref/videowriter.html).
PPTX export uses MATLAB Report Generator. Windows can additionally use the
PowerPoint COM fallback; macOS retains the exported PNG when Report Generator
is unavailable. Correlation calculations, MAT bundles and CSV export do not
require PowerPoint.

Acquisition scripts with Verasonics hardware, Windows vendor libraries or COM
port names require their supported acquisition host. These analysis fixes do
not port vendor hardware drivers to macOS. Serial device names on macOS differ
from Windows COM names.

Run the regression suite from the repository root:

```matlab
run_deConfUSIon_tests
```

The suite covers portable argument handling, moved paths, macOS app discovery,
calibration, MPEG-4 encoding, signed FC comparison, independent per-scan timing,
lazy 3D loading and export/reload through Group Analysis. The GitHub workflow
also runs these tests on Windows and macOS after it is pushed. It is a smoke
test, not exhaustive validation of each processing module or external program.
This change was tested locally on Windows R2023b; a native macOS run has not
yet been performed. Representative 3D datasets and external registration tools
still need validation on the target Mac.
