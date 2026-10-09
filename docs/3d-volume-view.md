# 3D volume and coronal slice stack

Open a native multi-slice recording in Studio, open **Video GUI**, and click
**3D brain / volume**. Reopen the GUI after updating MATLAB code: an existing
window retains old callbacks. Processing does not need to be repeated.

The black window groups controls into **Scans / Time / PSC / Doppler** on the left
and **Atlas / View / Stack / Grid** on the right. Playback and amber export
buttons remain visible. The quantitative color legend is vertical beside the
scene. Edits apply immediately when committed.

## PSC and baseline

**Follow Video GUI PSC settings** initially inherits the exact LUT, numerical
color range, positive/negative mode, opacity, alpha modulation and ramp limits,
threshold, and overlay smoothing. PSC initially inherits the Video baseline normalization. Explicit baseline or
scan changes recompute PSC from absolute power; an existing PSC series is never
normalized a second time. RGB renderer limits are fixed at 0–1 and
specular highlights are disabled, avoiding per-frame recoloring and white
highlights that could be mistaken for large responses.

**3D opacity gain** starts at 5 and is adjustable to 20. **Strong PSC opacity**
also lifts the visible alpha ramp. Both change opacity only, never numerical
PSC or LUT colors. Turn Strong PSC off and choose gain 1 to match Video's alpha
transfer. A response below the ramp start has zero opacity; lower that start
or disable alpha modulation to display it. Local PSC edits disable following;
select Follow again to adopt Video's latest settings.

Frame and interval controls use acquired samples, excluding inserted temporal
interpolation frames. Interval means require full finite support at each voxel.
The current Video ROI mask restricts PSC; the mask checkbox also restricts
grayscale anatomy. An empty mask imposes no restriction. Source arrays and the
2D display are unchanged. Reopen after changing the recording or source mask.

**PSC only / verify functional colors** hides Doppler and atlas tissue without
changing PSC. Bright grayscale tissue does not represent a 50% response. The
caption reports the numerical PSC range, and values beyond the selected range
clip to the LUT endpoint exactly as in Video.

## Doppler and atlas visibility

Manual vessel presets are **gamma 1, contrast gain 2, voxel opacity 4%, faint
cutoff 6%**. Gamma/gain affect grayscale Doppler only. Set both to 1 for the
saved underlay's original brightness. A loaded processed Mask Editor reference
is retained; otherwise the Mask Editor standard contrast preset uses baseline
power for a consistent anatomical display. Baseline Doppler uses the same
baseline frames as Video. Video underlay selects its static reference instead.

**Auto vessel opacity and faint cutoff** is optional. It chooses a baseline-only
profile from normalized linear power and path attenuation, fixed over movie
frames. Editing opacity/cutoff returns to manual mode. Faint background hiding
does not erase valid PSC merely because Doppler power is weak. With PSC-only
input, a complete 3D Doppler underlay is required; a single plane is replaced
by mean raw Doppler only when raw intensity is available.

Loading a saved transform shows the **whole atlas**, retains the chosen camera view,
uses **80% overall atlas context opacity**, and hides acquired Doppler. Restore
that layer with **Doppler → Show grayscale Doppler vessels**. Reference opacity
is converted into per-voxel attenuation across the tissue volume: it is not
80% at every voxel, which would create an opaque layer hiding deep PSC.
Reference brightness is lifted separately so its outline remains readable
without increasing attenuation of the functional overlay.
Atlas tissue outside acquisition coverage remains reference anatomy. PSC is
only mapped from finite acquired support, using the saved native-to-atlas matrix.

**Source slices** selects the inclusive original scan range. **Exclude slices**
accepts space-separated original slice numbers. Both restrict acquired PSC
and Doppler before mapping without cutting away the whole reference atlas.
Load transform starts in that animal's previously saved registration folder.
Register / adjust atlas reopens the common registration editor; saving refreshes
the companion viewer. Automatic proposals are labeled as requiring review.

## Coronal slice stack

Choose **Rendering → Coronal slice stack**. In the right **Stack** tab choose
tile count, slices per strip, **Combine by**, and optional first/last
slab-center indices. Opening the Stack tab or editing these controls activates
the renderer. Blank centers fit acquired atlas coverage, or the whole grid for
a standalone atlas/native recording. Tiles
are staggered and tilted like a paper slice figure, with R → L arrows, physical rulers,
and their contributing slice ranges. Drag to rotate; Reset view restores the
paper layout.

**Time rows (min)** optionally repeats the same sections at up to eight
recording times, for example `0 2 5 10`. Each row uses the nearest acquired
frame and labels its actual time. All rows share the same PSC range and LUT;
there is no temporal average or interpolation between these rows. Leave it
blank for the current frame/interval and progressing movie playback. Fixed
time rows export as PNG or camera rotation; clear the field for a PSC movie.
Slab data are cached while adjusting display contrast.

This layout follows the repeated, oblique coronal strips in
[SORDINO Figure 6c](https://www.nature.com/articles/s41593-026-02424-8#Fig6),
whose rows show maps at five peri-event times. The paper does not specify
combining five or ten adjacent slices for that figure. The selectable slab
means here are a separate deConfUSIon display option, recorded in export JSON.

**Slice count** combines exactly the requested number of samples (default 5).
Choose 10 to make one displayed slab from ten consecutive slices. Native slabs
use acquired slice sampling; atlas/registered slabs use the full-resolution
atlas grid. With 150 µm acquired sampling, five samples make a 750 µm slab;
with the 50 µm atlas, five make 250 µm and ten make 500 µm. **Physical width**
instead converts the entered width to the nearest integer sample count.
Default centers keep slabs inside the grid. Manually selected edge centers
can have fewer contributing samples; captions and JSON record the actual width.

Each tile is now a solid slab with textured front/back faces and tissue-shaped
side walls, including holes in the tissue mask. Its physical depth follows the
actual combined sample count instead of remaining a zero-depth plane.
**Depth display gain** defaults to **3** to make thin slabs legible in the
oblique view. Choose **1** for physical proportions; this control never changes
PSC means, sample counts or the in-plane ruler. Export JSON records both
`actualThicknessUm` and `renderedThicknessUm`, plus `depthDisplayGain`.

PSC is averaged numerically across finite samples **before** applying the
Video LUT. Missing/excluded samples are omitted, never replaced by zero PSC.
Anatomy uses arithmetic slab means. Atlas histology retains grayscale contrast
independently of Doppler gain. These exposed slab faces show internal responses
without a foreground atlas volume obscuring them.

Registered data and standalone atlas stacks use the original atlas sampling,
independent of the coarser volume preview. **250 µm = five samples on the
bundled 50 µm AP atlas grid**. On native 150 µm AP sampling the same request
rounds to two samples (300 µm); slabs at the grid edges can contain fewer
samples. Actual sample counts and widths are displayed and exported. Atlas
resampling does not improve the probe's measured acoustic resolution.

Stack center indices refer to atlas AP slices after registration and original
native slices in native mode. Tile count does not change acquired coverage.
Play time series and time-series MP4 work in stack mode, using cached mapping
queries and reference anatomy between frames.

## Interaction, orientation and calibration

Volume rendering uses viewer3d/volshow with explicit RGB and alpha (R2023b).
Surface rendering defaults to **Unsmoothed voxel PSC surface**: exposed voxel
faces carry their own PSC color/alpha, with no Gaussian smoothing, mesh
interpolation, reduction or specular lighting. Turning it off uses threshold
contours. Static anatomical meshes are bounded to 25,000 faces and cached.
Neither surface alternative exposes every interior response; use the slice stack.

Left-drag rotates surfaces and textured slabs; scrolling zooms in/out. Volume
mode uses native viewer interactions. View presets align the camera to Coronal,
Dorsal, Sagittal or Oblique; they do not perform registration. Native mode
starts Coronal with L/R confirmation selected as requested. A saved acquisition
side overrides the default Left for column 1. This preference is not independent
anatomical verification. Unchecking confirmation changes labels to L?/R?.
Atlas hemisphere markers identify atlas sides and follow the camera. Dorsal
view puts posterior up and anterior down. View → Show spatial axes (mm) toggles
physical ticks beside volume/surface views; axes pointing into the camera are
omitted in volume mode to avoid overlapping depth labels.

The ruler defaults to **500 µm**, with editable lengths from 50 µm to 5 mm and
a µm/mm unit selector. Unit changes preserve physical length. **Ruler position**
chooses Image bottom right (default), Below image, or View bottom right. It
follows camera zoom; unknown voxel units disable it.
The stack has one ruler beside the last section of the first strip and an
R → L arrow beside its first section; all sections
share physical scaling. Slice-range labels are optional to keep large layouts
readable; export JSON always records their contributing indices and widths.
Grid and Spacing / help report the physical calibration source. Native scanner
spacing must not be reused silently for an already transformed output grid.

Animal 1287's raw matrix scan has a **70 × 64 × 54** grid and **0.10 × 0.15 ×
0.15 mm** row/column/slice sampling, giving voxel-cell coverage **7.0 × 9.6 ×
8.1 mm**. The matching reference sequence `paramMatrix15M_1024_V1.m` specifies
12.5 MHz and 1500 m/s: wavelength 120 µm (100 µm at nominal 15 MHz). Frequency
is not saved in that raw scan, so these are reference-sequence values. The
sequence is read as text, never executed. Sampling and wavelength are not a
measured point-spread function or acoustic resolution.

In SCM GUI, Scale / units → Ruler settings toggles the same physical lengths.
Smoothing labels report row/column sigma in µm and FWHM = 2.35482 × sigma;
no slice smoothing is applied. Native 100/150 µm sampling and sigma 1 pixel
mean 100/150 µm sigma and 235/353 µm FWHM. Native rulers are not silently reused
after atlas warping without an output-grid calibration.

## Atlas-only view and export

Allen brain atlas opens the complete bundled histology or vascular reference
without an animal or transform. It supports volume, surface and slice-stack
rendering, rotation, three-plane review, PNG and rotation MP4. Functional
playback is disabled and metadata clearly identifies static reference anatomy.
The brain mask excludes the atlas region named background.

PNG captures the scene, legend and acquisition caption. One MP4 button uses
the selected movie type: **Camera rotation** turns the selected static volume,
**PSC time series** plays the acquired frames, and **PSC time series + rotation**
does both simultaneously using the selected motion in the View controls. Exports automatically create
`<animal folder>/3DModel/yyyy-MM-dd_HH-mm-ss-SSS/` with readable filenames.
Studio's `exportPath` (the analysed dataset) is preferred over `loadedPath`
(the acquired input). If only a RawData recording is known, its corresponding
AnalysedData folder and recording basename are used. Visualization and other
analysis-stage folders resolve to their parent dataset. If there are no source
paths, exports use `pwd/AnalysedData`. Export failure never falls back to RawData.
Time-series playback/export uses acquired frames
within the selected start/end interval at the chosen FPS, fixed reference
anatomy and camera. Live playback follows a wall clock: if rendering cannot
keep up, it advances to the appropriate acquired frame, whose true timestamp
is shown. This display-only skipping does not affect exports: movies include
every selected acquired frame. Pause retains the current frame; changing FPS
while playing changes speed immediately without restarting the movie or camera.
Rendering uses a timer that leaves an event-loop gap after each frame, so
native volume uploads cannot fill the callback queue. Existing volume mouse
interactions stay installed across frames; Pause can run between updates.
No extra acquired frames are invented. Data/display edits pause playback and closing removes
the timer. JSON companions record baseline, original frames/times, geometry,
masks, calibration, display transfer, camera, and slab averaging/actual widths.

Surface/slab movies use a native graphics canvas copying the actual displayed
geometry, textures, alpha and camera, avoiding full web-app capture. Volume
movies use a synchronous OpenGL voxel-plane compositor with the displayed
full-resolution RGB/alpha volume, physical transform and camera. This avoids
capturing an asynchronous viewer3d canvas before its new frame is ready; it
does not open a blank extra viewer window. Voxel-plane compositing may differ
slightly from viewer3d ray casting at oblique angles; the renderer is recorded
in JSON. PSC values, LUT, alpha settings and selected frames are unchanged.
**View → Movie resolution** selects Fast (720 px,
default), HD (1080 px), or Display size; only the output image size changes.
PNG retains the original scene capture. No acquired movie frames are skipped; JSON
records capture fallbacks, export duration and movie frame/time provenance.
Progress reports frames completed and estimated time remaining. Completion
shows **Export saved** with the movie/image and settings paths and an
**Open saved folder** button; the same paths
are printed in the MATLAB command window and retained in `FUSIVolumeLastExport`.

Top-right **Time** shows the acquired timestamp in minutes and seconds during
playback and export (or both endpoints for an interval mean). Atlas-only views
have no recording time. Left-drag rotates native and aligned volumes, surfaces
and stacks; scrolling zooms. Volumes use the canvas's native interactions;
surfaces/stacks use figure callbacks. Loading an atlas transform rebuilds the
canvas and installs its native handlers again.
Camera events from a replaced canvas are ignored, preventing an old native
camera or zoom from moving the newly loaded atlas out of view.
Subsequent transform loads and registration previews on the same atlas grid
update the mapped data in the existing canvas, keeping rotation, zoom and
display controls. The first atlas load fits the complete reference brain.
The native camera-moved event is persisted explicitly, so a mouse-selected
angle and zoom are retained when stepping frames and starting an export, even
on MATLAB releases where the web canvas leaves public camera properties stale.

Every 3D MP4 also writes `<same name>_paper_ready.mp4` beside the annotated
movie. It contains only the brain/slabs and acquisition time at the top right:
no color legend, caption, hemisphere labels, spatial axes, slice labels or ruler.
It uses exactly the same acquired frame sequence, FPS and camera motion.
Atlas-only movies have no acquired timestamp. The normal Video GUI's Save MP4
also writes this companion for each exported slice, at the selected playback
FPS. Both exports use the analysed dataset folder.

**Stack → Camera preset** offers Paper oblique, Shallow oblique and Face-on.
Turn, Tilt and Roll provide continuous angle adjustment. **Diagonal rise (%)**
controls the stagger between slices; zero makes a straight strip. **Tile gap
(%)** controls separation and **Depth display gain** exaggerates slab thickness
without changing spatial means. Changing slab width or gap preserves the
current camera. Tile-count changes fit the layout while retaining rotation
and relative zoom; this automatic fitting can be disabled. View → Oblique applies Paper oblique to a
stack. These are display conventions inspired by the supplied figure, not an
assertion that its authors used the same slab-averaging method.
Paper oblique uses a gentler tilt and roll so coronal structures remain visible.
Choosing a preset fits the visible slice tissue, rather than the empty corners
of a rectangular volume bounding box. Choosing a preset deliberately changes
the angle and fits it; ordinary data edits preserve the current angle.

Paper oblique starts with six near-face-on sections, turn/tilt/roll
−6°/8°/0° and a 20% diagonal rise. Larger selections arrange in compact rows
by default, rather than extending a steep diagonal that makes every tile tiny.
Editing **Slices per strip** selects a manual layout. **Fit when tile count
changes** retains rotation and relative zoom while fitting the new layout;
disable it to retain the exact camera position. Slab-width edits keep the camera.
**Fit stack to image** refits the current layout without resetting rotation.

**View → Display convention** defaults to **As acquired**. Native column-one
side is retained when loading a transform; a saved geometry supplies it when
there is no explicit acquisition-side choice. The atlas has canonical LR
columns, so its displayed anatomy and PSC are presented in the chosen acquired
convention together. Display-column reversal does not alter native PSC, slab
means, exclusions or the saved affine. The previous forced radiological stack
mirror is removed. Export metadata records the presentation convention.

L/R labels follow the displayed anatomy through rotation. Choose **L/R marker →
Custom position**, then use **Marker X/Y (%)** or click inside a surface/stack
image. **Hidden** removes the labels. The automatic stack marker appears once
below the first section, rather than repeating on each strip.

MP4 encoding uses a short local staging path (by default
`.deconfusion-cache/MovieExports` beside the toolbox), then copies completed
movies to the analysed dataset's dated `3DModel` folder. This avoids Windows
encoder path limits and per-frame writes over the network. Export names leave
room for the paper-ready suffix; the completion dialog reports final paths.
The scratch folder can be set with the `deConfUSIon` `movieScratchFolder`
preference. Failed final transfers report where the encoded files were retained.
Surface/slab movie capture reuses unchanged geometry and refreshes textures;
changed meshes are cloned safely. Atlas preview updates reuse the loaded
reference atlas and sampling grid, rather than rereading them at every edit.

Movies now default to **View → Movie resolution → HD (1080 px)**, with
**Full HD (1920 px)**, 720-pixel and display-size alternatives. MPEG-4 encoding
uses quality 100. Volume exports feed the synchronous compositor with the exact
RGB and alpha arrays produced by the current GUI settings; they avoid a second
upload of every frame to the web viewer. Surface and slab exports retain their
displayed geometry and textures. The OpenGL volume compositor is a different
renderer from viewer3d's ray caster, so small view-dependent compositing
differences can remain; it does not rescale PSC or its color range.

For **PSC time series + rotation**, camera steps run at least 24 times per
second even when the requested acquired-frame rate is lower. Each acquired PSC
volume is held for exactly its GUI frame duration while the camera moves.
Recording timestamps identify the held acquired sample. No temporal PSC
interpolation is introduced; movie metadata records both acquisition and
encoding FPS and the complete encoded sample mapping. Fixed-camera PSC movies
retain the selected GUI FPS.

Volume movie camera steps are applied directly to the synchronous export
renderer. The live web viewer keeps its camera during encoding, avoiding a
web-canvas camera upload for every encoded step. Rulers and hemisphere labels
follow the export camera; the original live frame and camera are restored
after export or cancellation.

Automatic L/R markers follow visible anatomy instead of padded atlas bounds.
They stay at the viewport edge when zoomed in, remain separate in a sagittal
view, and update at every exported camera step. **Coronal** is a useful start
for an orbit around the brain's dorsal/ventral axis; **Dorsal** shows an
overview from above, and **Oblique** exposes depth. Selecting these camera
presets changes only the view. **L/R marker → Custom position** remains
available. Paper-ready companions intentionally contain only the brain and
acquisition time, so their L/R markers remain absent by design.

## Multiple scans, baselines and presentation motion

Open **Scans** in the 3D viewer. **Scans / order (up to 10)** uses the same
raw-scan picker, preprocessing dropdown, include checkboxes, acquisition-time
sorting and manual ordering as SCM/Video. The selected signal scan can be
changed without replacing retained anatomy. **Baseline source / window**
selects another scan as a shared reference or edits the local seconds;
**Reset local baseline** restores the local window. These edits belong to the
3D window, independently of its parent Video window.

**Use each scan own baseline** is optional and starts off. It computes
`100 * (voxel power - that scan's baseline mean) / that baseline mean`. The
defined baseline seconds are applied independently to every scan. It does
not divide by a peak or maximum. Uncheck it to return to the shared baseline;
shared references preserve sustained baseline differences between scans.

Tick **Play included scans in order** to preview all acquired frames
from the included scans in their selected order. MP4 export opens its own
selector, which defaults to all included scans even when playback is unticked.
Choose **Selected signal overlay only** to export one scan instead. Enter
individual source slices such as **1 2 10** or a range such as **7:9**. Their
original depths are retained; unselected PSC/Doppler planes are hidden and
the complete atlas remains available as context. In sequence playback mode the single-scan
Start/End fields are disabled. Movies load one scan as it is needed, rather
than concatenating up to ten full 4D arrays in memory. Disk reads at scan
boundaries can pause live playback; export includes every selected acquired
frame. JSON records the scan IDs, local frames and times, each processed TR,
normalization window and continuous presentation timeline. Acquisition gaps
are not inferred. Different compatible native grids are placed on the retained
display grid; uncovered voxels stay missing. The atlas context remains fixed.

Under **Atlas / view → View**, choose Dorsal/Sagittal/Coronal oblique for a
slightly angled static view. Movie motion offers gentle yaw, gentle tilt,
an oblique orbit, an orbit around the current view, or a fixed camera.
Speed is in degrees per presentation second and is independent of PSC playback
FPS. Swing/tilt amplitude limits gentle motion; rotation length controls a
static camera movie. An orbit turns by speed × duration (30 deg/s for 12 seconds
makes a full turn). **PSC time series + rotation** previews and exports the
selected motion while retaining the acquired PSC samples. For presentations,
try Dorsal oblique or Sagittal oblique with Gentle yaw, 10–20 degrees amplitude
and 3–10 degrees/second; adjust after reviewing the acquired coverage.

3D exports also use a timestamped **3DModel** subfolder labelled with the
selected signal scan and preprocessing. Same-animal sequence movies use the
shared animal folder and a label such as **sequence_scan6-to-scan11**.
Their identity records included scans in the chosen order. The JSON settings beside the
movie retain full source names when a long Windows path requires shorter
folder labels. **Load atlas transform** opens the active scan's analysed
Registration/Registration3D folder and finds its dated registration runs;
a retained transform from another scan does not override a saved transform
for the currently selected scan.


Combined PSC/rotation playback moves the camera continuously between acquired
frames. PSC remains unchanged until its next acquired sample; no temporal
interpolation is introduced. MP4 export opens a native **Live preview** of the
actual movie model, with frame progress, estimated remaining time and **Cancel
export**. Its controls are outside the captured scene. The native onscreen
capture avoids the hidden-figure printing path when the canvas fits the screen;
HD/Full HD output dimensions and all acquired samples are retained. **Fast
(720 px)** reduces image rendering/encoding work for a quick review. Export
restores the selected scan/frame and camera, including after cancellation.
