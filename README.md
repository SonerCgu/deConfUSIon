# deConfUSIon

**A MATLAB graphical toolbox for functional ultrasound imaging analysis.**


## Manuals

| Guide | PDF | Editable Word |
|---|---|---|
| Practical user manual | [Read](docs/deConfUSIon_User_Manual.pdf) | [Download](docs/deConfUSIon_User_Manual.docx) |
| Complete user handbook | [Read](docs/deConfUSIon_User_Handbook.pdf) | [Download](docs/deConfUSIon_User_Handbook.docx) |

Start with the practical manual for installation and everyday use. The full
handbook adds mathematical explanations, detailed GUI examples, QC plots,
literature and the script/function reference.

## Installation

1. Download or clone the complete repository and keep its directory structure.
2. Open MATLAB and change the current folder to `deConfUSIon`.
3. Initialize the supported paths and launch Studio:

```matlab
deConfUSIon_setup
deConfUSIon
```

The documented reference environment is **Windows with MATLAB R2023b**.
Individual operations require their corresponding MATLAB products, including
Image Processing Toolbox for registration and Signal Processing Toolbox for
the relevant filter families. Consult the handbook and the actual
missing-function message for operation-specific requirements.

### Linux and macOS

The same source supports native MATLAB on Linux and macOS. Use R2023b or
newer for the current 3D workflows, with the MATLAB products required by each
operation. A graphical desktop and supported graphics driver are needed for
the interactive viewers. The validated reference remains Windows R2023b;
native Linux/macOS end-to-end validation is pending.

Use the actual mounted data path, such as `/Volumes/fUS/...` on macOS or
`/mnt/fUS/...` on Linux. Windows drive letters do not identify Unix mounts.
Opening a dataset remembers its project root so saved project-relative paths
can be resolved on the new mount. Native ITK-SNAP/Greedy installations are
optional for the external registration workflow; MATLAB registration remains
available with Image Processing Toolbox.

| Export | Windows | macOS | Linux |
|---|---|---|---|
| Movies and paper companions | MP4, unchanged | MP4 | Motion JPEG AVI |
| MAT, TXT, CSV, PNG | Native MATLAB | Native MATLAB | Native MATLAB |
| PPTX | Existing Report Generator / PowerPoint routes | MATLAB Report Generator | MATLAB Report Generator |
| XLSX | Existing export and optional Excel formatting | MATLAB export; no Excel COM styling | MATLAB export; no Excel COM styling |

Linux movie export uses MATLAB's native AVI writer because the MPEG-4 writer
is supported on Windows and macOS. Frame selection, timing and analysis
values are preserved. See the [MathWorks VideoWriter reference](https://www.mathworks.com/help/matlab/ref/videowriter.html).
Live acquisition still depends on the operating systems supported by the
scanner and vendor hardware drivers.

Avoid `addpath(genpath(...))` and keep backup checkouts off the active MATLAB
path. Use `which deConfUSIon -all` to inspect competing versions. After updating
files, reopen affected GUIs so their callbacks use the new source.

## What must stay together

| Location | Purpose |
|---|---|
| Root MATLAB scripts | Public launchers, Studio assembly and main GUIs |
| `lib/` | Essential runtime helpers for loading, processing, displays, regions and exports |
| `atlas_tools/` and `allen_brain_atlas.mat` | Atlas resources and registration support |
| `acquisition/` | Supported acquisition and stimulation tools |
| `theme_icons/` and `Icon.png` | GUI icons and branding |
| `docs/` | The two current guides, each as PDF and Word |

`lib` is required. Keep `fusi_studio_GUI.m` and `fusi_studio_callback.m` with
`run_fusi_studio.m` at the repository root. `Contents.m` files are MATLAB help
indexes and can remain with their modules.

## First analysis

### Brain-wide atlas region ranking in SCM

In the enlarged black **SCM GUI > Automatic analysis** window, choose
**Atlas: rank whole regions across slices** in the ROI-mode dropdown. Select
the signal interval, slice range and number of top regions for Target and
Control (0 = all). No ROI size is needed. Use the shared image-left/right
boundary and Target-side selector to assign sides; turning off separate sides
combines them. **Draw midline** lets you drag a straight or slanted dividing
line on the anatomy; it extends across every searched slice. **Remove / combine
sides** removes it and combines the sides. These are explicitly displayed image sides, not inferred
anatomical laterality. Registered integer atlas labels define each region;
each result averages all usable voxels across the chosen slices within its
assigned side. LightSuite and standard registered Regions atlases are supported,
including while a histology or vascular underlay is displayed.

Rank by mean PSC over the interval, or the peak of each regional mean curve,
and choose increases, decreases or absolute change. The table includes the
abbreviation, full region name, signed percentage change, ranking, voxel
counts, slice span and usable coverage. Results use the normal Target/Control
candidate table: click a row to update SCM's slice, signal window, atlas-shaped
ROI outline and trace. All **Mark / export** checkboxes start empty, with no
automatic candidate outlines. With **Pair same region on opposite side**
enabled, clicking a Target previews its matching opposite-side Control and
their time courses / percentages without ticking either box. Pairing uses the
same atlas ID, source scan, signal/baseline windows and slice range; a stronger
unrelated Control is never substituted. Matching Controls are kept even when
they rank below the Control top-N cutoff. Missing coverage is reported instead.

Tick a Target to retain it and its matching Control for averaging and export;
unticking it releases the automatic Control unless that Control was selected
independently. You can uncheck a Control explicitly or disable pairing. Dashed
outlines identify temporary previews; solid outlines identify checked regions.
Edit a row's Role dropdown to reassign Target/Control, **Clear selection** to
unmark the results, or **Edit midline...** to reopen the editor with the same
analysis settings. Changing a midline reruns the analysis and starts unchecked.
The ROI remains one fixed volume across all its slices. Square and per-slice
ROI searches remain available in the same window, alongside Load fixed protocol.
Attached scans can be ranked separately with scan-relative times; short scans
are skipped without shortening the requested interval.

Coverage refers to labelled voxels in the selected **acquired** slices, not
the complete reference atlas. Voxels need a valid baseline and finite samples
throughout the signal interval; their membership stays fixed for the curve.
The default minimum coverage is 75%, adjustable in the dialog. Local PSC is
rebased exactly per voxel; an external baseline retains its existing reference.
Display masks, smoothing and color limits do not affect the measurements.
ROI-size, brush and search-rectangle restrictions are disabled for volume ranking.
These rankings are exploratory, not tests of statistical significance.
**Export tables + curves** saves CSV tables/curves and a MAT audit containing
settings, atlas/source provenance, omitted regions and fixed voxel indices.
The normal checked-ROI TXT and bundle exports also support ranked regions and
retain edited roles; ranked table exports record assigned roles separately
from the original image-side assignment and identify rows marked for export.

### Optional LightSuite atlas registration

Choose **Registration to Atlas → LightSuite (beta)** in Studio, or run
`deConfUSIon_LightSuite` for its independent workspace. This experimental
alternative provides landmark-guided affine and B-spline registration against
the published vascular atlas, serial histology workflows, and launchers for
annotated fiber/probe tracks in compatible registered whole-brain histology.

Use the workspace's **Dependencies** tab for the scoped dependency check and
Windows installer. External source, Elastix 5.1.0 and atlas resources are kept
outside this repository in `deConfUSIon_ExternalTools`; licensed MATLAB
products must be installed separately. Confirm physical geometry, landmarks
and diagnostic overlays before interpreting results. The supplied fUSI
recording can check anatomy preparation; it cannot validate expression or an
implant trajectory without suitable histology.

The guided workflow advances from preparation to orientation, landmark editing,
fit and review. **Save + continue to fit** closes the finished editor, and
**Accept + save all outputs** exports the native atlas package. Window headers
identify the animal and scan; the editor supports right-click undo and visible
busy/saved states.

We acknowledge Karamanlis and colleagues for LightSuite. Please cite their
[bioRxiv preprint, *LightSuite: scalable atlas registration and cell detection
across the central nervous system* (2026)](https://doi.org/10.64898/2026.10.13.757638)
alongside deConfUSIon when using this integration.

See the [LightSuite integration guide](lib/lightsuite/README.md) for setup,
coordinate conventions, limitations, attribution and the script API, and the
[original LightSuite workflow](https://lightsuite.readthedocs.io/en/latest/usage_fusi/).

### Recommended sequence

1. **Load fUSI Data** and verify dimensions, timing, physical spacing and output path.
2. Inspect the original movie in Time-Course Viewer and run **Full QC**.
3. Compare one justified processing change at a time with the original recording.
4. Confirm baseline and signal windows, then review SCM or Video.
5. Inspect masks and atlas alignment before interpreting anatomical ROIs.
6. Review ROI traces before exporting, and keep notes/audit files and baseline sidecars together.
7. Use appropriate independent animal identities and statistical designs for FC/groups.
8. Repeat a reviewed protocol with **Standardized Analysis**.

The final array dimension is time: a 2D movie is `[Y X T]`, while a reconstructed
motor stack or volumetric movie is `[Y X Z T]`. Sequential motor planes are not
automatically simultaneous. Recheck analyzed TR after temporal reduction.

### Mask shapes and smoothing for 3D probe data

In **Mask Editor**, choose **Auto: Rectangular (3D probe)** and **AUTO MASK**.
The preview proposes one rectangle across the stack, retaining weaker signal
inside its straight edges. Drag the blue edges/corners or edit the bounds,
adjust the inset, and scroll through slices before applying to the stack or
the current slice. **Auto: Ellipse (rounded)** provides an oval overlay;
**Anatomical (intensity)** follows the Doppler envelope. Rectangle and ellipse
can also be switched in the preview. Choices are remembered independently for
underlay and overlay. Overlays default to **Follow slice size**: each slice gets
its own fitted rectangle or ellipse, so smaller/larger slices shrink/expand.
Resize the current preview to adjust the other slices proportionally. Turn
this option off to reuse one fixed box; underlay masks default to that fixed
geometry. **Smooth: All slices** smooths each plane of the active
mask independently; choose **Current slice** to limit the operation.
Empty Doppler slices remain empty; an existing brain mask also restricts the
overlay, including during smoothing. **Apply mask** updates the editor, and the usual
**SAVE UNDERLAY / OVERLAY / BOTH** buttons save the result.

### Connecting repeated animals in Group Analysis

In the ROI preview, enable **Connect same animal** for the maximum signal
change plot. The connection controls offer **Line color** (including a custom
picker), **Width (pt)** and **Opacity**, all carried through to PNG exports.
The table **Animal ID**
is authoritative, including manual corrections. Source-label differences are
reported without blocking the corrected animal. For automatic identification,
ROI source headers, recording names and the nearest animal folder are checked.
Files copied into a shared ROI folder keep their source animal identity.
Generic ROI folder names never identify an animal. Repeated animals connect
within the same scan, session and acquisition date, supporting both `scan18`
and `FUS_104646` names. Truly ambiguous duplicates within one recording,
missing identities and unmatched recordings are reported in the status line.
Connecting lines change the display; select the appropriate statistical test
separately. Automatic PairIDs follow manual Animal ID corrections, including
historical source IDs in older saved lists; custom pair labels are retained.
Paired tests still require one observation per pair in each group.
All test directions use the unrounded p-value for the same star thresholds:
`***` for p ≤ 0.001, `**` for p ≤ 0.01, and `*` for p ≤ 0.05.
P-value labels show extra digits near these thresholds: a value of 0.0013
is shown as `p = 0.0013` with `**`, rather than rounded to `p = 0.001`.

## Interpretation and reporting

deConfUSIon is research software. Review raw movies, QC decisions, component
removal, filters, baselines, anatomical support and statistics against the
original acquisition and event log. A maximum chosen from response data is an
exploratory result. Several ROIs from one animal are not independent animals.
The example masks and time windows in the manuals illustrate operation.

For a reproducible issue, record the source path, dimensions, TR, active
toolbox version, exact action and complete MATLAB error. Use the
[GitHub issue tracker](https://github.com/SonerCgu/deConfUSIon/issues).

Developer tests, maintenance tools, historical reports and temporary build
artifacts are maintained separately from this runtime distribution.

Developed by **Soner Caner Cagun**, MPI for Biological Cybernetics.

### Awake fast injections preset

In **Standardized Analysis**, select **H | Awake fast injections**: Frame
Rejection (3 sigma, interpolate on the original time grid), automatic PC1
removal with voxel means restored, then Imregdemons using median blocks of 50.
SCM opens positive only at 0–50%, alpha modulation 5–10%, baseline 30–60 s and
signal 700–900 s. These settings remain editable. Block averaging multiplies
TR by 50; a timing check runs before processing. Frame QC files are saved
without opening preview windows. Computational and registration time depends
on recording dimensions and storage speed.

### Low-pass, frame rejection and Imregdemons preset

In **Standardized Analysis**, select **I | Low-pass / Reject / Imreg50**:
low-pass filtering at **0.01 Hz** (Butterworth, order 2, zero phase, baseline
mean preserved), then **Frame Rejection** (3 sigma, interpolate on the original
time grid), then **Imregdemons** using median blocks of **50 frames** with
automatic 2D, step-motor or 3D registration selection. Only these three steps
are checked. Settings remain editable, and the setup window closes when the
workflow finishes. Input timing is checked before processing; Imregdemons
multiplies TR by 50.

### Frame rejection, PCs 1-5, Imregdemons and SCM preset

Select **J | Reject / PC1-5 / Imreg50 / SCM** in **Standardized Analysis**:
Frame Rejection at 3 sigma with interpolation on the original time grid,
automatic removal of **PCA components 1-5** across all slices with voxel means
restored, **Imregdemons** using median blocks of **50 frames**, then **SCM GUI**.
SCM starts with baseline 30-60 s and signal 7-14 min, positive display 0-50%
and alpha modulation 5-10%. All settings remain editable. The PCA component
field accepts a range such as `1:5` or a list such as `1 2 3 4 5`.
