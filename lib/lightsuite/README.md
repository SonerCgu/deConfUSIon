# Optional LightSuite registration

Open **Registration to Atlas → LightSuite (beta)** or run:

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

An existing animal can be registered again with **Open existing project →
Re-register (new version)**. The new run is saved inside the selected project as
`Registration_yyyyMMdd_HHmmss_SSS`. **Edit copied landmarks** retains editable
copies of the pairs; **Recheck orientation** starts at orientation confirmation
without carrying pairs into a changed coordinate system. The anatomy and verified
spacing are reused, and the previous fit and outputs are preserved. Fit, review
and save the new version, then load that exact timestamped subfolder in SCM.
If both affine and nonlinear views have the same tilt, inspect orientation and
the affine alignment first. Correct uncertain pairs and distribute reliable
vessel correspondences across all three dimensions; review unused anatomy too.

**Continue automatically between steps** is enabled by default. Click
**1 Prepare + start**, confirm orientation, then mark paired landmarks in the
editor that opens. **Save pairs (S)** saves while you continue editing;
the green **Save + continue to fit** saves, closes the editor, fits, and opens
registration review. After inspecting the fit, **Accept + save all outputs**
closes review and saves mapped anatomy, native regions, available atlas
backgrounds and masks. Closing or rejecting review does not export. Disable
automatic continuation to run the numbered steps individually.

Numbered coloured buttons perform the workflow; blue **Help** buttons provide
instructions. The active step is emphasized. Animal and scan appear in window
titles and headers; activity indicators distinguish **BUSY** from **READY**.
Important Command Window messages include a bold stage label, time, identity
and output path. The final **SAVED** state identifies the project folder.

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
   inferred from numerical magnitude. **1 Prepare + start** has a cancellable
   progress window for sampling, median calculation, atlas loading and saving.
3. Confirm orientation using the atlas / sample preview. The signed permutation
   maps native dimensions onto **AP × DV × ML**. Closing this dialog cancels;
   it does not silently accept the default permutation. Probe-coordinate origin
   is preserved as provenance and is not interpreted as a CCF origin.
4. Use **3 Edit landmarks** to open the dark paired-point workspace.
   Both images show full slices. Choose coronal/AP, horizontal/DV or
   sagittal/ML views; each image has its own slider, previous/next buttons and
   editable slice number. The mouse wheel changes the image under the cursor.
   Left/right arrows change the sample; up/down arrows change the atlas.
   Click a recognizable vessel bifurcation in the **left sample** first, then
   navigate and click the **same feature in the right atlas**. A yellow pending
   point becomes a numbered pair only after both clicks. Esc cancels the
   pending point. Right-click an image in marking mode to undo the last click:
   undoing an atlas point keeps its sample pending for correction; another
   right-click cancels that sample. **Delete selected pair** removes both
   points in the selected row. Zoom/pan are explicit inspection modes; return to **Mark
   matching points** before annotating. **Mask Editor standard** is the default
   contrast, using the toolbox's existing equalized Doppler display function.
   Scrolling over either image panel (including its margins) changes only
   that panel. Contrast changes only the display.
   **Load edited underlay...** opens this recording's **Visualization** folder.
   Select a saved Mask Editor MAT bundle to use its edited anatomical pixels
   for landmark placement. The image must match the native recording grid;
   saved display flips are not reapplied, and the overlay/signal mask is not
   used to hide vessels. The selection is remembered in `landmark_underlay.mat`
   and carried into new registration versions. Fitting still uses the original
   anatomical template; landmark coordinates and physical spacing stay native.
   Marker edits reuse the displayed planes; changing one slice recomputes only
   that panel. **UNSAVED CHANGES**, **PENDING POINT** and timestamped **SAVED**
   badges distinguish editing state. Complete or cancel pending pairs before
   saving. **Save pairs** or `S` writes the upstream-compatible landmark file. An
   existing landmark file is backed up before its first replacement. A fitted
   project opens read-only so its landmarks cannot silently invalidate a fit.

Registration review offers **Original anatomy / Edited underlay**, independent
**Sample contrast / Atlas contrast**, a true **Atlas opacity** blend, and presets
to emphasize either image or show boundaries on anatomy. The mapped-anatomy
review also has separate atlas/anatomy contrast controls. These controls affect
the display only. Both registered atlas stages are sampled directly from the
full reference, so nonlinear displacement cannot expose blank strips from an
intermediate affine crop.

In SCM, the LightSuite background selector also includes **Recorded anatomy**
when the exported native mask bundle contains the original anatomical template.
The dashed box marks the acquired field; reference tissue outside it has no
measured functional signal. Changing the atlas display cannot recover data
outside acquisition coverage. Atlas abbreviations such as `PAL-unassigned` are
displayed as `PAL`; the full name (`Pallidum, unassigned`) and label ID remain
available in the region list, without merging these voxels into named nuclei.

SCM starts with **Show atlas outside acquired field** unchecked. This keeps
the atlas and measured PSC on the same visible acquisition extent without
stretching the registration. Check it to inspect the full atlas reference;
the dashed box then separates measured voxels from reference-only tissue.
Slice browsing, affine/B-spline switching and ROI values use the original
native coordinates in both views.

When the chosen LightSuite parent folder contains exported registration
revisions, SCM asks which version to load and shows each fit's timestamp and
landmark count. Selecting a revision folder or its region MAT file directly
loads that exact version. An incomplete revision is not offered as an atlas.
Registration review now reports saved landmark residuals and the AP/DV/ML
span of the marked points alongside the inverse-consistency check. A small
round-trip error alone does not establish anatomical accuracy; inspect large
pair residuals and slices beyond the marked planes before accepting a fit.

   At least five noncoplanar pairs are required, spread over all three spatial
   directions. This is a minimum for fitting, not an accuracy guarantee. The
   paper reports a median of **219 landmarks per mouse**, not a required
   threshold. Add confident pairs in rounds, distributed across the acquired
   volume, and check unused anatomy after fitting. Neither point count nor a
   low landmark residual establishes anatomical accuracy. Unequal sample /
   atlas sets are rejected.
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

### 3D Model and movies

In the **3D Model GUI → Atlas → Load atlas transform**, choose a LightSuite
folder, or select its `transform_params.mat`. Select the complete project
containing the session and saved forward/inverse B-spline files. No fitting is
performed. The model uses the published LightSuite reference and offers
**Affine + B-spline / Affine only**. Functional frames remain limited to acquired
coverage; camera-rotation and PSC time-series exports use the same mapping.

The selected project/stage is remembered in the scan's
`Registration/3DModel_Atlas.json`. Where the recording folder explicitly identifies
its parent animal, `3DModel_LightSuiteAtlas.json` shares the choice with sibling
scans of that animal. Opening the 3D Model starts with the supplied recording
and does not search for or load a LightSuite project. Use **Load atlas transform**
when you want to reuse a saved fit; grid and physical spacing are checked before
applying it. **Native view** clears
the choice for that scan. Exported movie/PNG settings include the project path,
registration stage, saved-fit signature and acquisition coverage.

**Register / adjust atlas → LightSuite** opens the LightSuite workspace. Existing
projects can be resumed there, including timestamped revisions. Saving the
outputs updates the originating 3D model automatically; other scans can load
that same saved folder instead of repeating landmark placement and fitting.

The 3D Model **Masks** tab can load a saved Mask Editor underlay and both masks,
or replace only the PSC overlay mask. The brain mask and overlay mask have
independent switches. Saved processed underlays retain their edited contrast
and native slice orientation; the import checks the recording grid. The picker
starts in the current recording's Visualization folder when available.

Atlas source selection and loading use small modeless popups. Loading closes
the temporary progress window and returns the existing model to the foreground.

PNG and MP4 exports use the original **1080-pixel longest-edge** default.
**View → Movie resolution** also offers 720, 1920 and the display size. Large
exports render at the requested raster size even on smaller monitors; only
the progress preview is reduced to fit the screen. Exports reuse the current
display grid, transfer settings and camera; no additional atlas loading or
high-detail remapping runs when export starts. Both the live preview and saved
files retain the black scene background, including off-screen HD captures.
Slice stacks already sample the full atlas slabs. MP4 encoding remains at
maximum quality. This improves export detail without increasing the acquired
ultrasound resolution or changing the PSC baseline. Settings JSON records the
actual raster dimensions and atlas sampling used for the export.

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

After accepting a fit, **SAVE / EXPORT BOTH ATLAS STAGES + MASKS** saves
`LightSuite_Native_Regions.mat` (Affine + B-spline) and
`LightSuite_Affine_Native_Regions.mat` (Affine only). Each has matching
`_Native_Backgrounds.mat` and `_Native_Mask.mat` companions. Load either
region file as an atlas in SCM, Video or functional
connectivity on the **same native recording grid**. IDs are dense structure
labels with a matching saved name table. Hemisphere maps are warped through the
same affine and B-spline chain. Cropped, resampled or atlas-space recordings
must not use this native bundle. It is not an affine `Transformation.mat`.

The same export saves `LightSuite_Native_Backgrounds.mat` beside the region
bundle. SCM and Video offer **Vascular**, **Histology** and **Regions** in the
background selector. Continuous backgrounds use linear interpolation through
the accepted affine and B-spline chain, followed by the original native axis
order; choosing a background does not resample the functional recording.
Region names and hemisphere masks remain available in all three modes.
SCM's **Registration stage** selector switches the backgrounds, labels,
boundaries and hemisphere lookup together. **EXPORT ATLAS** copies both
stages and their companions into a new portable folder.
Continuous atlas backgrounds retain available reference detail in a separate
display texture, with linear display sampling and a stable intensity window
across slices. Functional values and region IDs stay on their original grid.
The full reference canvas extends beyond the recording rectangle, so tilted
or shifted registrations do not crop the atlas at the acquisition edges.
SCM preserves the native scan orientation by default. Optional **Upright atlas
view** rotates the atlas, signal and ROI graphics together, using the saved
affine orientation. This changes viewing only; ROI coordinates and measurements
remain native. Regions and continuous backgrounds use the same expanded
reference coordinates. Image and series exports retain the viewing choice.
Histology uses the Allen CCF2020 average template (install dependencies with
`-IncludeHistology` if it is missing). Its 10 µm array is block-averaged to the
50 µm atlas grid using bounded memory before transformation.

In **LOAD ATLAS**, choose **LightSuite folder** to open a LightSuite project
directly, or **Normal folder** for the standard registration outputs.
**Single file** remains available for individual saved underlays. The
LightSuite folder picker starts at the last loaded project or this recording's
`Registration/LightSuite` folder when available.

Opening an older project in SCM or Video generates missing stages and
backgrounds once from its accepted saved registration, without refitting.
Keep the region and background files together when moving exported underlays.
If only the old region file is available, open the complete LightSuite project
and export again; backgrounds cannot be recovered from label IDs alone.
In the LightSuite workspace, **Open existing project** starts in the selected
animal/recording's LightSuite folder when present, otherwise its analysis
folder.

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
