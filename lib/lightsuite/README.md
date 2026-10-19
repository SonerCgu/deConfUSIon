# Optional LightSuite registration

Open **Registration to atlas → LightSuite (experimental)** or run:

```matlab
deConfUSIon_LightSuite
```

The independent workspace provides a resumable alternative to the established
deConfUSIon registration. The default route is unchanged. This integration uses
the actual LightSuite functions and published vascular reference, not an
approximation of the paper's algorithm.

## Installation

In **Dependencies**, choose **Install / complete setup**. Windows open-source
dependencies are downloaded outside the toolbox to its sibling folder
`deConfUSIon_ExternalTools`. Code revisions and Elastix 5.1.0 are pinned; a
different pre-existing revision is preserved and reported. No global MATLAB
path, `startup.m`, or system PATH is edited. Only named source modules are added
for each operation. Upstream licenses are retained.

MATLAB R2022b or newer, Computer Vision, Image Processing, Optimization, Parallel
Computing, and Statistics and Machine Learning Toolboxes are required by
LightSuite. The checker reports missing products; licensed MathWorks products
cannot be supplied by this open-source installer. CZI additionally needs
BioformatsImage and OME Bio-Formats. TIFF sections do not require Bio-Formats.
Cortical flatmaps are not enabled by this adapter; those require additional
Python / Allen streamline resources and independent validation.

## 3D fUSI workflow

1. The recording loaded in Studio is selected automatically, including its
   current in-memory processing result. Browse or edit **Recording** to choose
   a different file. Choose a **new dedicated output folder**. For ordinary MAT
   files containing a 4-D `I`, preparation samples at most 101 frames through
   `matfile`. It does not load or copy an entire multi-gigabyte movie.
2. Spacing is read automatically when the workspace opens or a recording is
   selected. Explicit physical units and the native AUTC beamformer geometry
   profiles already verified by deConfUSIon are supported, including headers
   nested in saved `newData`, `data`, `par` and `meta` structures. For older
   processed files that retained only a unitless `voxelSize`, a saved link to
   the original recording can recover its header when spatial dimensions and
   retained spacing agree. v7.3 header inspection never loads the movie. The status line
   names the metadata source. Unsupported headers still need measured spacing
   in **millimetres along each original array dimension**; units are never
   inferred from numerical magnitude. **Prepare anatomy** has a cancellable
   progress window for sampling, median calculation, atlas loading and saving.
3. Confirm orientation using the atlas / sample preview. The signed permutation
   maps native dimensions onto **AP × DV × ML**. Closing this dialog cancels;
   it does not silently accept the default permutation. Probe-coordinate origin
   is preserved as provenance and is not interpreted as a CCF origin.
4. Use **Place / edit landmarks** to open the dark paired-point workspace.
   Both images show full slices. Choose coronal/AP, horizontal/DV or
   sagittal/ML views; each image has its own slider, previous/next buttons and
   editable slice number. The mouse wheel changes the image under the cursor.
   Left/right arrows change the sample; up/down arrows change the atlas.
   Click a recognizable vessel bifurcation in the **left sample** first, then
   navigate and click the **same feature in the right atlas**. A yellow pending
   point becomes a numbered pair only after both clicks. Esc cancels the
   pending point. The pair table jumps to existing points; delete removes the
   selected pair. Zoom/pan are explicit inspection modes; return to **Mark
   matching points** before annotating. **Mask Editor standard** is the default
   contrast, using the toolbox's existing equalized Doppler display function.
   Scrolling over either image panel (including its margins) changes only
   that panel. Contrast changes only the display.
   **Save pairs** or `S` writes the upstream-compatible landmark file. An
   existing landmark file is backed up before its first replacement. A fitted
   project opens read-only so its landmarks cannot silently invalidate a fit.
   At least five noncoplanar pairs are required, spread over all three spatial
   directions. This is a minimum for fitting, not an accuracy guarantee. The
   paper used many more landmarks. Unequal sample / atlas sets are rejected.
5. Fit the affine and B-spline chain. The default final B-spline spacing is
   **1.6 mm** and landmark weight **0.1**, following the fUS workflow.
   A cancellable progress window and Command Window percentages report the
   current optimization stage, resolution and configured iteration budget.
   This percentage is not a prediction of total remaining time. Native
   initialization and postprocessing have an indeterminate progress display.
   The Windows adapter writes MHD/RAW images directly to the output directory,
   avoiding wildcard moves from MATLAB's current folder and stale-file clashes.
   Patched compatibility copies are generated under the external tools folder;
   downloaded upstream sources and their licenses are preserved unchanged.
6. Open **Interactive fit review**. This reconstructs the actual affine and
   nonlinear atlas volumes on the prepared recording grid; it is not a PNG
   contact sheet. Select coronal, horizontal/axial or sagittal views, or all
   three. Scroll over an image, drag the slice slider or enter a slice number;
   both stages show the same slice. Gray is acquired anatomy, cyan is the
   registered vascular atlas. Solid region outlines have selectable color and
   thickness and can be hidden. Compare overlay, checkerboard, sample-only and
   atlas-only views; adjust contrast/opacity or zoom with the toolbar.
   Inspect several slices in **all three planes**, including acquired coverage
   boundaries, left/right anatomy and local distortion. A sagittal view can
   reveal AP/DV misalignment that is harder to judge in other planes.
   A numerical check runs before acceptance. If it fails, **Accept** is disabled
   and **Rebuild inverse + recheck** builds a separate candidate without changing
   landmarks or the forward fit. A candidate replaces the old inverse only if
   it passes the unchanged numerical limits, with the old inverse backed up.
   If rebuilding fails, revise geometry/landmarks in a new project and refit.
   Closing review retains the current decision; acceptance remains explicit.
   The original PNG diagnostics remain available as static records.
7. Map anatomy or a native-grid measurement. Regional timecourses are the
   default for movies; full atlas movies can consume enormous memory. Missing
   acquired coverage remains missing. Do not interpret a smooth overlay as
   evidence that a registration is anatomically correct.

This method is **landmark-guided registration with automatic optimization**,
not a completely unattended atlas fit. Registration and activation statistics
are separate; a good image alignment does not validate a biological effect.

### Script API

```matlab
cfg = struct('outputFolder', 'D:\analysis\recording_lightsuite', ...
             'voxelSizeMm', [.10 .15 .15], ... % example only: confirm yours
             'permutation', [3 1 2], ...      % example only: verify anatomy
             'orientationConfirmed', false);
s = deConfUSIon_LightSuite('preparefile', recordingFile, cfg);
% Open the workspace, resume the folder, confirm geometry and annotate.
deConfUSIon_LightSuite('gui', [], struct(), struct('sourceFile', recordingFile));

% After manual geometry confirmation, saved landmarks, fit and QC acceptance:
r = deConfUSIon_LightSuite('apply', s.opts.savepath, nativeMap, true);
% nativeMap must use the EXACT prepared native grid.
% For a movie, keep the third argument false to return regional timecourses.
```

`prepare` also accepts an already loaded canonical `data.I` and `meta`. The
adapter stores `deconfusion_lightsuite_session.mat`, `regopts.mat`, physical
geometry, sampled frame indices and method provenance in the output folder.
It keeps nonlinear LightSuite transforms separate from deConfUSIon's affine
`Transformation.mat` files. Do not rename one into the other.

Two upstream portability / measurement issues are handled here: machine-specific
`loadAtlasInfo` / path settings are bypassed using explicit installed resources;
regional volumes are recomputed from the actual **50 µm** atlas spacing instead
of the upstream hard-coded 10 µm factor. Reported region volumes are total atlas
anatomical volumes, not measured valid voxel coverage.

Forward and inverse deformation fields must be finite and within a conservative
physical bound before acceptance or mapping. Their bidirectional round-trip
error is tested in physical millimetres on an interior grid and saved sample
landmarks: the maximum must be at most two atlas voxels and the 95th percentile
at most one atlas voxel. If the pinned upstream inverse optimizer diverges or
underconverges, fitting tries a deterministic grid-sampled L-BFGS inverse using
the [elastix displacement-magnitude penalty](https://elastix.dev/doxygen/classelastix_1_1DisplacementMagnitudePenalty.html).
The previous tiny fixed-gain retry could underconverge for larger displacements.
Existing projects can use **Rebuild inverse + recheck** or
`deConfUSIon_LightSuite('repairinverse', projectFolder)` without refitting their
forward registration. A candidate that fails validation is retained for
diagnosis and never replaces the saved inverse. These numerical checks are
separate from anatomical accuracy; neither a passed check nor an attractive
overlay establishes accurate anatomical registration.

After accepting a fit, **Export native region labels** saves
`LightSuite_Native_Regions.mat`. Load it as an atlas in SCM, Video or functional
connectivity on the **same native recording grid**. IDs are dense structure
labels with a matching saved name table. Hemisphere maps are warped through the
same affine and B-spline chain. Cropped, resampled or atlas-space recordings
must not use this native bundle. It is not an affine `Transformation.mat`.

## Serial histology and expression measurements

The **Histology sections** tab accepts serial TIFF or CZI sections. One TIFF
file represents one section; multipage TIFF pages represent channels. Supply
real channel names, isotropic pixel size, section spacing, registration channel
and approximate atlas AP range. The adapter copies inputs into the analysis
folder so ordering / flips / crop decisions do not alter the raw images.

Proceed through preparation → ordering / crop review → initial alignment →
cutting angle → paired landmarks → section refinement → registered volume →
regional intensities. Cell detection is a separate explicit step. Inspect
detection overlays and tune cell diameter / thresholds for your
images. Fluorescence intensity and detected-cell counts measure different
quantities; neither is automatically an unbiased measure of expression.

The current adapter enforces the upstream point-mapping convention of **1.25 µm
processing, 20 µm registration, 10 µm Allen atlas**, because other processing
resolutions would be mis-scaled by the upstream slice point mapper. It does not
pretend those options are freely interchangeable. An independent single slice
does not establish a unique 3-D position; use the existing 2-D registration and
manually identified atlas plane or a properly spaced serial stack.

Mapping detected serial-section cells to atlas coordinates is currently disabled
because that upstream point-coordinate chain needs independent validation. This
does not block image registration or regional fluorescence intensities. Intensity
exports correct the pinned upstream left/right column labels to match the
official CCF2020 PIR convention; MAT outputs record hemisphere order explicitly.

## Fibers / probes

The **Fiber / probe trajectories** tab opens LightSuite's real optical fiber /
GRIN or linear-probe annotation interfaces for an **already registered
whole-brain histology project**. It requires the nested `regopts.opts` schema,
whole-brain transform chain and a 20 µm registration TIFF. Incompatible fUSI and
serial-section project schemas are rejected before the GUI starts. Register
your histology with the upstream whole-brain workflow first.

Click visible track / damage points across several sections, specify the real
fiber diameter and channel, save, fit and inspect. fUSI cannot infer an invisible
implant trajectory or expression. No implant image was supplied for validation;
this launcher is experimental and requires validation on your actual histology.

Implant points use a scoped adapter that evaluates the original forward
image-pull transform in **Transformix point mode**. Physical millimetres are
converted back to MATLAB 1-based registration coordinates before the saved
inverse affine. This avoids the pinned upstream point mapper's coordinate
offset and missing volume-size argument for flipped probe displays. Category
figures use MATLAB's categorical palette through a small compatibility helper;
colors do not determine atlas IDs. Native fUSI region exports use the official
CCF2020 convention: ML runs anatomically from left to right. These adapters
remain separate from the downloaded source.

## References and notices

- Karamanlis et al. (2026), *LightSuite: scalable atlas registration and cell
  detection across the central nervous system*, bioRxiv,
  DOI [10.64898/2026.10.13.757638](https://doi.org/10.64898/2026.10.13.757638).
- LightSuite code: <https://github.com/dimokaramanlis/LightSuite>, pinned commit
  `2cf948caaa96f1acac6e02917717499b2ba174ce`, **GPL-3.0**. It is downloaded
  separately; its full license stays in the external checkout. This adapter
  does not copy or relicense the upstream implementation.
- Published vascular atlas / example resources:
  <https://doi.org/10.5281/zenodo.21338217>, **CC BY 4.0**; retain attribution.
- Allen CCF2020 reference and parcellation resources:
  <https://alleninstitute.github.io/abc_atlas_access/descriptions/Allen-CCF-2020.html>.
- Allen coordinate convention, **PIR** (posterior, inferior, right; ML runs
  from anatomical left to right): <https://brain-map.org/support/documentation>.
- Elastix 5.1.0: <https://github.com/SuperElastix/elastix/releases/tag/5.1.0>.
  Retain its Apache license / NOTICE and cite Elastix when used.
- Installation and workflows: <https://lightsuite.readthedocs.io/en/latest/>.

Outputs are exploratory until geometry, registration and downstream scientific
measurements have been checked on independent landmarks / held-out data.
