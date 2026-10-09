# Reviewing a 3D matrix-probe registration

Open **Register / adjust atlas**, confirm array order and measured voxel
sampling, and select baseline Doppler or a saved anatomical brainImage.
Prefer the vascular atlas for automatic Doppler registration; use histology
and region boundaries for anatomical review. Doppler cannot create tissue
details absent from the acquisition.

Native **Column 1 side** and the acquisition-confirmation checkbox initialize
the geometry dialog's left/right reversal. Confirm that choice there. The
saved flip is applied identically to baseline anatomy and PSC in the viewer.

The moving anatomy defaults to **hot**, with 85% maximum opacity and an
intensity-dependent transparency curve. **Mask Editor standard** provides
equalized Doppler contrast; **Saved Mask Editor** preserves a loaded processed
reference. **Vessel detail**, **Linear power** and **Log Doppler** are alternatives.
Appearance controls do not change the optimizer's source anatomy or transform.
**Vessel gain** increases display contrast; **Gamma** above 1 reveals weaker
vessels. For example, try gain 2 and gamma 1.4, then adjust the window minimum
to suppress faint background. Gain has no arbitrary upper cap, but high gain
can saturate vessels and hide useful detail. These controls reuse the three
cached visible cuts, avoiding another full-volume warp. The original
anatomy, PSC and transformation matrix are unchanged by appearance edits.
Entirely negative saved log-Doppler underlays are windowed into the display
range before applying the standard contrast preset, so they remain visible.
Their stored values and the quantitative PSC are unchanged.

The top bar contains Coronal/AP, Axial/depth and Sagittal/LR slice indices.
Type a number, or scroll over either image in a pair. Left-drag the right image
to translate; right-drag to rotate. **Resize anatomy → DV / depth (Y), AP /
length (Z), LR / width (X)** resize each direction immediately on committing the
edit (Enter or leaving the field). Each direction also has **− / +** buttons,
as in the 2D editor; **Button step** selects increments of 0.01, 0.05 or 0.10.
The labels identify DV as Y, AP as Z and LR as X in the 3D model's atlas view.
1 is unchanged; 1.1 makes that direction
10% larger. Scaling occurs about the registered scan center so resizing does
not shift the anatomy away from the atlas. Invalid factors preserve the prior
transform. Both dragging and committed edits reslice only the three visible
planes, using the same affine coordinates as the full-volume reslice. Repeated
contrast changes reuse those planes. The image movers no longer redraw or
reset MATLAB interaction modes for each plane. One callback-safe redraw follows
the update of all planes. **Live 3D preview** is off by default, so a companion
model cannot interrupt repeated manual edits. Enable it to update the model
after adjustments pause for 0.75 seconds. Saving and closing publish the final
model either way. Check several slices per plane before accepting an alignment.

**SAVE TRANSFORM NOW** also creates
`Registration3D/AtlasRegistration_<date-time>/AtlasUnderlays3D/<timestamp>/Histology.mat`, `Vascular.mat`,
`Regions_All.mat`, `Regions_Merged.mat` and a region list for each version.
`Regions.mat` and `RegionList.txt` remain aliases for the grouping selected in
the registration editor. Each underlay embeds the exact saved
transform and its acquisition geometry. The main transform stays in canonical
atlas coordinates; the underlays use coronal `[DV LR AP]` array order with
atlas voxel spacing. Region labels retain their integer IDs and color table.
`Regions_All.mat` preserves every original atlas label. `Regions_Merged.mat`
combines named subdivisions, including all caudoputamen subdivisions as CPu
and cortical layers under their named parent area. Distinct nuclei remain
separate. The merged region list and `atlasSourceToRegion` record the original
label IDs contributing to each parent. Both files use exactly the same saved
affine, so choosing a different grouping does not change functional alignment.
Existing registrations can be saved again to generate both versions without
refitting their transformation.

Every explicit 3D save creates a new collision-protected, dated registration
folder containing its own `Transformation.mat` and underlay bundle. Existing
dated folders are preserved. `Registration3D/Transformation.mat` remains a
compatibility alias for the latest explicitly saved version. Saving to an
already existing filename creates another dated folder instead of overwriting
that version. 2D slice packages and motor-session indexes also get distinct
dated folders. New exports are redirected from RawData to analysed data.

Region colours follow the supplied `rgb2acr.xlsx` HEX/acronym table and the
colleague's exact-match/three-letter/two-letter prefix-mean lookup. Numeric
Excel cells are treated as HEX text, e.g. 188060 means `#188060`. Where duplicate
exact acronyms exist, the first exact row is used deterministically. Unmatched
atlas regions retain their existing colours; the reference background is black.

In SCM or Video GUI, choose **LOAD NEW UNDERLAY** and select one of these MAT
files. The picker finds the newest saved 3D underlay folder for the current
recording, including existing exports in `Registration3D` beside the raw file,
and remembers the folder of an underlay you select. The file-type menu includes
MATLAB atlas files, images, NIfTI and **All files**.
Loading a saved 3D atlas underlay now aligns the functional data using that
underlay's paired saved affine and displays upright coronal atlas anatomy.
It retains every acquired slice (54 for the matrix recording), with full atlas
XY bounds and high-resolution reference textures. This replaces the previous
native-space preview, whose tilted sampling plane made the atlas look rotated
and compressed. Quantitative values are resampled geometrically; display
contrast does not change them. The original native functional array is retained
for Reset or a different transform.

The **WARP TO ATLAS: CHOOSE TRANSFORM** button opens a file picker, starting at
the exact paired transform or the last selected transform. The status line
identifies the applied transform and its version folder; the button tooltip
contains its full path. A selected transform is authoritative: an invalid or
mismatched file produces an error instead of silently applying another save.
Opening Video from SCM or SCM from Video now transfers the complete atlas
geometry, high-resolution reference provider and native-data snapshot. This
prevents a later window from treating the warped image as a new native scan or
resampling it again.
This route also detects a matching `Registration3D/Transformation.mat`; it
does not require the old 2D single-slice or Step Motor workflow.

The aligned view has one coronal atlas plane through each transformed source
slice center, retaining 54 planes rather than expanding the movie to all 264
atlas planes. Atlas XY spacing is retained; AP spacing includes the native
slice gap and the saved affine's AP scale. Reversed AP acquisition order is
recorded in the source-slice mapping. Tilted acquisitions are resliced as
coronal planes, not relabeled as if no rotation had occurred. The saved affine
and full atlas reference files remain unchanged.
Both image layers and the viewport use the full atlas XY bounds after loading,
with aspect calculated from atlas spacing. Native probe aspect preferences
do not stretch the atlas. Functional coverage is carried through the affine;
no signal is extrapolated into the reference-only tissue.
Histology and vascular display slices are sampled directly from the full
reference atlas onto a display texture of at least 512 pixels along its longer
dimension. They are not enlarged from the coarse fUSI underlay preview. The
native source arrays and slice count are retained. Existing native ROIs are
cleared when the functional grid changes. Video keeps the same display texture during playback and export;
it does not switch back to a smaller image on Play. Region textures use nearest
label sampling to preserve colors and boundaries. The display texture improves
presentation but does not change the atlas's physical voxel resolution.

Underlays from the same alignment reuse the warped functional data. Loading an
underlay from a different alignment, or explicitly selecting another transform,
starts again from the retained original native data. Repeated Warp clicks also
use those native data, so transforms are never applied twice. **RESET TO NATIVE**
restores the source array and Doppler view. PSC outside acquired coverage is missing, rather than
an invented zero response. Histology and vessels there remain atlas reference
anatomy; region labels use nearest-neighbor sampling to retain integer IDs.

Each new save keeps a consistent structure under the animal's analysed-data
registration folder:

```text
Registration3D/
  AtlasRegistration_<date_time_milliseconds>/
    Transformation.mat
    AtlasUnderlays3D/<date_time_milliseconds>/
      Transformation.mat  (exact immutable paired copy)
      Histology.mat
      Vascular.mat
      Regions_All.mat
      Regions_Merged.mat
      Regions.mat
      RegionList*.txt
      README.txt
```

The root latest-transform alias remains for compatibility. A bundle's paired
copy always stays with its anatomy; a later root alias cannot replace it.
Older bundles without a separate copy retain their embedded saved affine and
can still be loaded. No registration exports are written into raw-data folders.
Opening **3D brain / volume** from Video GUI retains the saved atlas voxel
spacing and acquisition-side choice. The viewer treats the already warped
array as the canonical coronal atlas grid, so an acquisition-side display
change affects presentation only, without another functional warp.

The basic sequence is **1. Auto: fit anatomy**, **2. Match three reference
slices**, then **3. Refine matched alignment** if desired. The three reference
slices reuse the usable range from the automatic fit (15–45 offers 15/30/45).
Their spacing-aware affine already maps the intervening and remaining scan
slices; refinement starts from that alignment, including its manual sizing.
Automatic AP scale refinement stays within 0.8–1.25 of the starting AP size,
preventing excessive shortening to match a smaller atlas subset. Manual AP
resizing and physically checked reference-slice matching remain available.

The ordinary Studio registration launcher uses this same editor. Saved Mask
Editor files with both raw and processed anatomy use the raw reference for
fitting and the processed underlay for viewing. The active processed recording
uses its mean Doppler anatomy, with scanner geometry read from its source
header when available. This avoids fitting a display gamma or equalization
operation as if it were acquired intensity.

## Automatic initialization and refinement

Greedy calculates image registration; ITK-SNAP is the interactive image
viewer. The toolbox can run Greedy, MATLAB, or compare their proposals.
An improved fitting score is not anatomical validation.

- Leave **Refine current manual alignment** off to search starting positions.
- Select it after bringing the scan close manually, after a plausible existing
  transform, or after accepting the three-anchor initialization.
- **Rigid** preserves shape. **Rigid then bounded scale** adds independent
  depth/AP/LR scale refinement with no automatic shear. Both engines use the
  same bounded refinement and intensity/local-contrast/interior-gradient
  scoring rule. A joint depth/width scale search precedes fine increments;
  acquired edges and missing atlas coverage are excluded from the interior
  score. A bright lower acquisition boundary is not treated as the ventral
  boundary of a complete brain. Size increments follow the mapped scan center.
- **Usable source slices** uses original acquisition indices, e.g. `10 50`.
  Selected AP support is masked without cropping or shifting the source origin.
  Automatic empty-end trimming removes only empty/very-low-energy outer planes;
  exclude nonempty but poor-quality slices manually.
- Optional **Matching atlas AP slices** identifies the atlas positions of the
  first/last selected source slices. These anatomically identified endpoints
  initialize AP scale and position. They must respect the confirmed AP direction.
- Verify internal vessels, boundaries and ventricles where visible. Internal
  contrast contributes to fitting, but the algorithm does not claim to detect
  an absent or indistinct ventricle from Doppler alone.
- Check all planes before **SAVE TRANSFORM NOW**. Use **Undo auto** to reject a
  proposal. Saving updates the companion volume through its saved transform.

At 150 µm source and 50 µm atlas spacing, each source interval spans three atlas
sampling intervals: source slices 10–50 span 120 atlas intervals. Spacing alone
does not determine absolute AP location, acoustic resolution or slice thickness.

## Semi-automatic first / middle / last anchors

**Semi-auto: first / middle / last slice** reuses the familiar 2D coronal editor:

An **anchor** is a manually matched reference slice: one acquired scan slice
paired with its corresponding atlas AP plane, including its accepted in-plane
position, rotation and size. The three pairs guide a single transform for the
complete recording. They are not ROIs or independently warped slice outputs.

1. Choose three usable original source slices, e.g. `10 30 50`.
2. For each anchor, select the matching atlas AP slice, then move, rotate and
   scale the high-contrast source overlay. Use vessels, boundaries and ventricles
   where visible. **Use this slice alignment** advances to the next reference slice.
   The spacing panel shows expected relative atlas gaps before acceptance.
   With 150 µm acquisition and 50 µm atlas sampling, scan 15/30/45 matched first
   at atlas 100 nominally predicts 100/145/190. Later planes start at this
   separation; **Use spacing estimate** changes only the atlas plane, retaining
   your in-plane transform. This is a sampling estimate, not an anatomical
   bregma assignment or proof that an individual brain has unit scale.
   A span outside the permitted AP size range stays open with its measured
   scan/atlas spans and factor. The third plane also checks the complete affine
   before closing. Cancellation retains accepted pairs for reopening Semi-auto.
3. The three accepted planes fit ONE shared 3D affine in measured atlas-grid
   coordinates. All intervening slices, orthogonal views and PSC use that matrix;
   there are no independent per-slice warps.
4. Inspect the three RMS anchor errors in mm. Inconsistent rotations or AP
   placements cannot all be matched by one affine. Revisit anchors if errors are
   appreciable relative to your sampling.
5. Review all three planes. Optionally run automatic registration with
   **Refine current manual alignment**, then review again and **SAVE TRANSFORM NOW**.

If a warning reports 4.50 mm acquired span mapped to 1.85 mm atlas span, the
chosen atlas endpoints imply AP scaling 1.85 / 4.50 = 0.411. This would compress
the scan to 41% of its measured length, outside the permitted size range. At
50 µm atlas sampling, 4.50 mm corresponds to 90 atlas slice intervals, whereas
1.85 mm corresponds to 37. Recheck the matching first/last atlas planes,
acquired spacing and in-plane sizes. The warning preserves your accepted
reference slices for reopening Semi-auto and leaves the previous transform
in place; it does not silently force an anatomically implausible fit.

**Accept anchor** or the anchor window's X accepts the current plane and
advances. **Cancel anchors** discards the fit and preserves the previous transform. Accepting an anchor
does not export intermediate slice packages or accept the final volume.
The proposal report retains anchors, corresponding points and residuals.
Three coronal anchors constrain an initialization; tilt, partial coverage and
unclear landmarks still require orthogonal review.

If the AP order is reversed in all three accepted anchors, the editor offers
**Reverse source AP**. Confirm this only when the acquisition direction is
opposite to the current geometry. It reverses the prepared AP grid and records
the same reversal in the native-to-atlas geometry; it does not change L/R.
Mixed AP order, duplicate matching atlas planes, or stretches outside 0.5–2
remain errors. The message reports the relevant AP positions and/or stretches.
Accepted anchors are retained after a failed fit: reopen **Semi-auto** with
the same source slices to correct their placements without starting over.

## Saving the animal transform

The green **SAVE TRANSFORM NOW** button saves immediately to the animal's
current registration folder, using `AtlasTransform_yyyy-MM-dd_HH-mm-ss-SSS.mat`.
It refreshes the companion 3D viewer and remembers the animal's folder. Right-click
the button for optional **Save as...**. **Save current transform** also
uses timestamped quick saving. A canonical `Transformation.mat` copy is retained
for existing Studio/coregistration readers.

Automatic, three-anchor and imported SNAP alignments update an **unsaved**
companion 3D preview. They do not save transform files or overwrite a saved
transform. Closing the 3D registration editor preserves its current preview
in the companion, but only an explicit Save retains it on disk. After a previous
fit or loaded transform, automatic settings default to refining the current
alignment; uncheck that option to restart the starting-position search.
A numerical registration score does not establish anatomical correctness.

Optional AP coordinates can seed first/middle/last anchors. Enter first/last
AP in mm relative to bregma, positive anterior and negative posterior, and the
atlas AP index corresponding to bregma. The bundled atlas has no bregma metadata;
its origin cannot be inferred reliably from voxel spacing alone.
The editable initial index is `bregmaIndex - APmm * 1000 / APspacingUm`; the
middle anchor's AP coordinate is interpolated by its source position. Coordinates
are starting estimates: visually adjust each anchor and review all three planes.

## ITK-SNAP review and manual adjustments

The automatic-registration dialog separates **Registration target** from the
**SNAP underlay** choice beside Open ITK-SNAP review: Same as registration
target, Histology, or Vascular. You can fit the vascular reference and inspect
the result on histology, or vice versa. The main registration editor also has
a **SNAP: Vascular / SNAP: Histology** selector beside Semi-auto. Change it
before clicking ITK-SNAP review; a changed reference creates a new review
workspace on the same atlas grid without changing the transform. Imported
manual adjustments still compose against that review's original matrix.

1. Click **ITK-SNAP review** after applying a proposal. The AutoReview folder
   contains the fixed atlas, anatomy already resliced by the current transform,
   optional region labels, ReviewSession.json metadata, and an `atlas_anatomy_overlay.itksnap` workspace.
   The workspace opens anatomy as a hot transparent overlay on the fixed atlas,
   independently of previously selected tile-layout preferences.
   If separate image tiles appear, right-click aligned_anatomy and choose
   **Display as Overlay**.
   The Windows launcher removes inherited MATLAB Qt plugin paths and verifies
   that SNAP created a window. A launch failure is reported rather than claiming
   success. The automatic settings checkbox also permits SNAP review after a
   MATLAB fit; image registration is still performed by the chosen engine.
2. Browse several coronal, axial and sagittal slices inside acquired coverage.
   Reference tissue outside that coverage is atlas context.
3. The SNAP anatomy overlay starts at 95% opacity with a window spanning the
   5th–98.5th percentiles of positive acquired intensities, gamma 0.65, and a
   steep hot-color/alpha ramp. Weak background stays transparent; vessels
   become bright red/yellow sooner. These are workspace display settings:
   review NIfTI values, registration input and transforms stay unchanged.
   Select the anatomy layer to adjust its contrast window if needed.
   **Alt-I** replaces this preset with SNAP's auto-contrast; **Q/E** adjusts opacity;
   **W** hides/reveals overlays. Alternate visibility to inspect displaced edges.
4. For manual realignment, choose **Tools → Registration → Manual** and select
   **aligned_anatomy** as the moving layer. Keep the atlas main image fixed.
   Enable **Interactive Tool**: drag away from the wheel to translate, or turn
   the wheel to rotate. Inspect coronal, axial and sagittal views. Rotation,
   translation and scaling fields are also available in that panel.
5. Use the registration panel's **Save Transform**. Save ITK affine **text**
   (`.tfm`/`.txt`) or Convert3D **4×4 RAS text matrix**. Do not save a segmentation,
   a resliced image, a workspace or binary MATLAB/ITK transform instead.
6. Return to MATLAB and click **Import SNAP edit**. Choose that saved transform.
   The toolbox converts physical coordinates and composes the adjustment once
   with the original native-to-atlas proposal. Native Doppler and PSC use the
   same resulting matrix; it does not repeatedly warp an already warped movie.
7. Review all planes in MATLAB, then **SAVE TRANSFORM NOW**.
   **Undo auto** rejects the imported adjustment. If you changed the MATLAB
   alignment since opening SNAP, import is refused; open a fresh review.

Import supports the one affine for the supplied already-aligned review layer.
It does not import a nonlinear displacement, changed image header or a transform
for a different main/moving image pair. You can also perform all manual edits
directly in the MATLAB editor, without importing anything.

Review NIfTI files use directional LR/AP/DV headers. Probe handedness still
needs acquisition landmarks. Region background is zero in review NIfTIs, even
though the bundled MATLAB atlas uses table index 1 for background.

## Parent regions

**Atlas display → Parent regions** merges explicit parent names in the bundled
descriptions: Caudoputamen subdivisions become **CPu**, and comma-separated
layers/subdivisions share their named parent. Unrelated nuclei remain separate;
this conservative grouping is not a replacement ontology.

Parent boundaries, region display, ITK-SNAP review labels and registered atlas
label exports use this mapping. The original detailed atlas file is unchanged.
Export metadata records the grouping and source-to-parent map.

## Popup timer error

The reported STRING error came from styling a multiline character matrix as a
single row. Labels are normalized for matching without changing their content;
one popup cannot abort styling of others. This callback does not calculate or
save analysis data. It does not by itself indicate a corrupted recording.

Replace an already-running old timer with
`deConfUSIon_popup_autofit_timer('start')`. Reopen old Video/SCM/registration
windows to install new callbacks; PCA and motion correction need not be repeated.

Sources: [Greedy documentation](https://greedy.readthedocs.io/en/latest/),
[ITK-SNAP command-line tools](https://www.itksnap.org/pmwiki/pmwiki.php?n=Documentation.CommandLine),
[ITK-SNAP shortcuts](https://itksnap.org/pmwiki/pmwiki.php?n=Documentation.KeyboardShortcuts).
Transform conventions are verified against the official
[ITK-SNAP registration implementation](https://github.com/pyushkevich/itksnap/blob/master/GUI/Model/RegistrationModel.cxx)
and [affine serialization](https://github.com/pyushkevich/itksnap/blob/master/Common/AffineTransformHelper.cxx).

**Atlas display → Atlas underlay** toggles the atlas anatomy beneath the
moving overlay in all three review planes. Switch it off to inspect the
acquired vessels alone against black with the same gain, gamma, window and
opacity settings. The atlas boundaries in those moving-image panels are also
hidden while the underlay is off; the fixed reference panels stay visible.
Switch it on again to compare alignment. This display control leaves the
registration matrix, source data, saved underlays and automatic fitting
unchanged, and reuses the cached review planes.

## Step-motor underlay bundle

In 2D coronal registration, **Save ALL Visited** creates one new dated
`StepMotor_Reg2D_Session_*` folder in the analysed recording's Registration2D
directory. Its per-source transform folders and `StepMotor_Reg2D_Session.mat`
stay together, with an `AtlasUnderlays` subfolder containing **Histology.mat**,
**Vascular.mat**, **Regions_All.mat**, **Regions_Merged.mat** and region lists.
Only explicitly visited/saved source planes are included; each full atlas plane
keeps its saved source-slice and atlas-slice mapping. It does not stretch or
interpolate the AP gaps between motor positions.

In SCM's **Underlay** tab, choose **LOAD ATLAS FOLDER** and select that session
folder or its `AtlasUnderlays` subfolder. Alternatively, **LOAD NEW UNDERLAY**
can open its session MAT or any of the combined underlay MAT files. SCM applies
the paired per-slice transforms from native functional data and loads all four
underlay choices together. Switch them in **Atlas underlay** without loading
the files or warping the functional data again. A source-slice count mismatch
is rejected. The complete session can be copied because its transform paths
are also recorded relative to the session directory.
