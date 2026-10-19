# deConfUSIon

**A MATLAB graphical toolbox for functional ultrasound imaging analysis.**

Load reconstructed Doppler movies, inspect quality, apply justified processing,
review atlas alignment and extract regional time courses, functional
connectivity and group summaries. Supported workflows include single 2D
planes, sequential 2D probe recordings with a step motor and volumetric 3D
probe data.

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
