# Automatic SCM: spatial and plateau search

Close and reopen SCM after updating MATLAB files; an already-open GUI keeps its
old callbacks. Open **Automatic analysis > Find and review ROI**.

The anatomical search brush paints with left-drag and erases with right-drag.
Strokes end when the button is released or the pointer leaves the image; on
Windows the dialog also checks the held button if mouse-up happens outside
the window. During a stroke it updates only the cached mask shading, at up
to 60 redraws/second, subject to rendering speed. All stroke positions still contribute to the mask.
The preview uses the same anatomy renderer as SCM, including cached atlas
textures, colors, contrast and image placement. Anatomy is loaded once per
previewed slice, and search boundaries are rebuilt after release. The painted
search mask continues to apply to all slices.

The main SCM **ROI size [px; X x Y]** control shows its physical **X x Y**
below the slider, in micrometres. The first value is X (horizontal width,
columns); the second is Y (vertical height, rows). The scalar size applies to
both pixel counts. Width uses column spacing and height uses row spacing.
On the verified native linear 2D grid (45 um in each axis), size 5 is
225 x 225 um and size 25 is 1125 x 1125 um. On the native matrix grid (row
100 um, column 150 um), the same sizes are 750 x 500 um and 3750 x 2500 um.
After atlas alignment, the measurement uses the functional atlas grid rather
than the native spacing or the upsampled underlay texture. Unknown units show
"size unavailable" and can be confirmed in **Scale / units**. The hover/ROI
preview also reports the actual physical footprint, including edge clipping.
These are voxel-cell spans (pixel count times spacing), not centre-to-centre
distances or acoustic resolution. The existing manual centered bounds expand
even size entries to the next odd pixel count; that actual count is shown too.

Native matrix images in SCM, Video GUI and Mask Editor use the measured
in-plane sampling for their display aspect: a column pixel is 150 um wide
and a row pixel is 100 um high. MATLAB's `DataAspectRatio` is therefore
`[1 1.5 1]`, rather than `[1 100/150 1]`. This corrects display stretching;
it does not resize, interpolate or rotate the recorded data, ROI indices or
saved transforms. The native equal-spacing 2D grid remains pixel-square,
and registered atlas views keep their own atlas spacing. An explicit scripted
`probeViewAspect` override remains available; `probeViewAspect=1` shows square
pixels if a visual comparison is needed. Restart open GUIs to apply changes.

For an atlas-based search, load a saved 3D atlas underlay in SCM. The **Atlas
underlay** menu in the Underlay tab switches between **Histology**, **Vascular**,
**Regions: all**, and **Regions: merged** from the same saved registration; Video
GUI has the same menu. Switching underlays preserves the functional data and
alignment. Loaded views are cached, and changes to a saved file invalidate its
cache. Use **WARP FUNCTIONAL TO ATLAS** to move the recording to the full atlas
XY grid while keeping its acquired coronal slice count.

In Automatic analysis, choose **CPu | Caudoputamen (CPu)** from the atlas region
menu after selecting **Regions: merged**. The name list comes from the saved
integer labels, not the display colors. **Choose regions...** lets you search
abbreviations/full names and tick several regions. Each region gets its own
candidate search and Top-N ranking per role; choosing several does not combine
them into one mask with a single winner. Whole-region mode also supports several
regions. The same shared atlas labels/alignment are used for unregistered scans
when searching **All loaded scans**. Their own underlay/transform files are not
required when positioning is unchanged. The default minimum ROI coverage is
**75%**, adjustable up to 100%. A square of side N pixels must contain at least
`ceil(coverage * N^2)` pixels from the selected region. The remaining pixels may
be in neighbouring labelled brain tissue. Atlas searches ignore the uploaded
SCM display mask, so a previously masked-out part of CPu remains searchable.
This applies to named regions, whole-region mode and all labelled brain tissue.
The uploaded display mask stays unchanged. All pixels must fit the acquired
coverage, painted area, rectangle and selected side, avoid atlas-labelled ventricles,
choroid plexus and cerebral aqueduct, and have valid baseline/window samples.
Periventricular and paraventricular brain nuclei remain valid brain regions.
Slices where no candidate fits are skipped and reported; the time-window and
maximum-mean calculation are unchanged. Exports include the region ID/name,
grouping, source label file, minimum/actual coverage, ventricle exclusion and
whether the uploaded SCM mask was applied.

The numerical search labels remain available when the display is switched to
histology or vascular anatomy. Atlas context beyond the recorded field of view
does not create measured functional signal.

**Segmentation:** choose saved `Regions_Merged.mat` as the label source and
“Regions as saved / detailed” as the resolution. Alternatively, choose
`Regions_All.mat` and “Merged parent regions (e.g. CPu)”. This conservative
parent grouping differs from the much broader “Coarse anatomical families”.
The saved transform samples labels on the matching native or atlas recording
grid, using nearest-neighbour interpolation. Hemisphere extraction uses the
saved 3D geometry, never the anterior-to-posterior slice index.

**Functional Connectivity:** use **ROI labels** to select `Regions_Merged.mat`
or `Regions_All.mat`. The corresponding names load with the integer labels;
ventricle/background labels are excluded. This also works at the startup label
prompt and with the segmentation result. The optional script argument
`opts.atlasRegionFile` loads the same bundle for scripted FC setup.

Saved region bundles contain `atlasInfoRegions` and a selectable region catalog,
and accompany `RegionList_All.txt` and `RegionList_Merged.txt`. Existing bundles
with integer labels and names already work; no new registration is required.
For older 3D bundles containing only `Regions.mat`, the underlay selector
offers detailed and merged views in memory. It preserves the original files
and transform; a newly saved registration exports both versions explicitly.

1. Set the baseline in SCM. In the black search dialog, enter **Search start/end**
   in minutes, for example `5 15`.
2. Set **Plateau duration** to `2` to search all consecutive two-minute windows
   between minutes 5 and 15. Set `0` to average the entire selected interval.
   The search jointly selects the square ROI and time window with the highest
   mean rebased PSC. Choose **Different best window per ROI / slice** or
   **Same best window across all slices**. Different windows are the default. Shared mode finds the globally
   strongest eligible candidate window, then re-searches Target and Control on
   every requested slice using that exact common window.
   A plateau equal to the search width is valid: `5 6` with duration `1`, or
   `5 7` with duration `2`, uses all acquired samples inside that single
   interval. Start/end need not align with frames. The requested duration is
   preserved in metadata; actual sample bounds may lie slightly inside it.
   The final acquisition bin is allowed, but missing tails, missing values,
   and intervals containing fewer than two samples are not silently filled.
3. Choose square ROI side length in pixels. Enter **X start/end, Y start/end**,
   or click **Draw rectangle**, press and drag on the image, then release.
   A live outline follows the pointer. Escape cancels drawing; Reset restores
   the whole image. This rectangle applies to every searched slice.
   The brush is enabled immediately: **left-drag adds** to a painted search mask
   and **right-drag erases** it. Change **Radius (pixels)** to adjust brush size.
   The first left stroke starts with an empty mask; the first right stroke starts
   with the full area. **Clear painted area** and **Fill painted area** also apply
   to all slices. Painting restricts the search inside the rectangle and selected
   side; native searches also use the uploaded image mask, while atlas searches
   use labelled brain tissue instead. It does not alter the fUSI display/data masks. A candidate
   square must fit entirely inside the painted area, including any erased holes.
   The same painted mask applies to **every slice**. Switching the brush off
   stops painting but keeps its restriction. Reset clears the rectangle and paint
   restrictions. Painted mask indices and image dimensions are saved in each
   automatic ROI's export metadata. Display settings are kept unchanged by default.
4. Enable **Separate left/right target and control** and choose **LEFT = Target**
   or **RIGHT = Target**. The opposite side automatically becomes Control.
   Choose **Mark Target and Control**, **Mark Target only**, or **Mark Control only**
   above the anatomy preview. Only selected roles are searched, marked and listed
   for export. Shared-window selection also uses only those roles.
   The preview labels the selected regions. Move the numeric X boundary if required.
   With left/right separation off, a single selected role searches the entire
   chosen rectangle and retains that Target or Control label.
   Left/right refer to the displayed image, not inferred anatomical orientation.

The display menu offers **Keep current**, **Shared limits across animals**, and
**Automatic per animal (99th percentile)**. No automatic contrast rule can be
optimal for every recording and also guarantee identical numerical limits.
For direct comparisons use Shared limits: its initial profile is 0–30% color,
5–10% alpha modulation, and 100% opacity. Adjust the main SCM controls and click
**Remember current SCM limits for all animals** to replace that shared profile.
The saved numerical limits, opacity and polarity are reused across animals.

Automatic per-animal mode uses the 99th percentile of the absolute, unsmoothed,
rebased SCM values across the selected search areas, slices and candidate windows
(minimum upper limit 1%). The alpha ramp runs from one-sixth to one-third of
that upper limit. The same profile is applied to every selected slice/ROI for
that animal; signed display uses symmetric color limits. This is a reproducible
contrast heuristic, not a significance threshold. Different animals can receive
different limits, so their colors are not directly comparable. Profile values,
rule and scope are saved in each automatic ROI's metadata. Neither mode changes
the selected ROI, maximum plateau calculation, or exported trace values.
5. Scroll the mouse wheel or use the slider to preview other slices. Enable
   **Slice range: from / to** and enter inclusive start/end slice numbers,
   for example `4` and `50`. The default is the complete stack (`1` to the
   last slice). Equal bounds search one slice. Uncheck it to search only the
   previewed slice. Bounds must be whole numbers within the loaded stack.
   The range restricts candidate selection, shared-window selection and
   automatic contrast. Browsing outside it does not change the chosen range;
   the preview identifies those slices as outside the search. Each automatic
   ROI's exported metadata records the searched slice numbers.
   For 3D data, **Top ROIs per role** retains the requested number separately
   for Target and Control (for example `3` and `6`). `0` keeps all candidates.
   Ranking uses selected-window mean PSC, with one best square per role per
   searched slice; equal scores use ascending slice number. The requested
   number must be available: an insufficient set is reported rather than
   silently reduced. Only the selected ROIs are marked and used for automatic
   display scaling. Their Export checkboxes are initially selected.
6. Click **GO / Start analysis**. Invalid settings are explained directly above
   the button. A progress window appears during analysis, including single-slice
   searches. Cancel preserves existing marks. A successful rerun replaces unsaved
   automatic candidates instead of accumulating them; numbering restarts at 1
   when no other marks remain. Manual and already-exported marks are retained.
7. The highest-response slice opens automatically. Filter the review table by
   Target/Control and slice range (or one slice); sort by maximum/minimum PSC or
   ascending/descending slice. **Show maximum** opens the strongest filtered result.
   Selecting a row switches SCM to its slice and window. In shared mode this
   interval remains identical across slices. Table rows and marks turn red for
   any slice with a candidate window-mean PSC >200%. This flags it for review,
   without excluding it. Otherwise orange identifies Target, blue identifies
   Control. Regions without a fully valid ROI/window are reported explicitly.
8. Tick the **Export** column and use **Export SELECTED ROIs (TXT)** for checked candidates.
   Ticking or unticking preserves the table's current scroll position and row
   selection; green row shading updates immediately without rebuilding it.
   **Export checked ROIs: per-role bundle + averaged TXT** writes two files
   per selected role in a dated subfolder of the ROI export directory, for
   example `ROI_Bundle_2026-10-01_20-37-12_Target3_Control4`. A repeated export
   in the same second gets a numeric suffix and retains earlier files. The
   `allROIs` file contains time, ensemble PSC, and each member's PSC column;
   the `mean` file contains time and the same ensemble PSC only. Each is
   compatible with Group Analysis, which reads ensemble PSC as one observation.
   Load **either** file per role and recording, never both. Members are equally
   weighted on the original time grid; a missing member value makes that time
   point missing, so the contributing set does not silently change. Per-member
   slice, bounds, rank, search range and selected window are recorded in headers.
   Group Analysis's maximum plateau of this mean trace is not necessarily the
   mean of the members' individual maxima when they use different windows.
   Selecting top responses is exploratory and does not constitute statistical
   outlier removal, including on the Control side.
   The main SCM **EXPORT ROIs (TXT)** button exports all marks, including manual marks.
   **Choose Target + Control to export** asks for exactly one marked ROI per role
   and writes only those two traces, labeled Target and Ctrl, to the normal ROI
   folder. Table filters do not restrict the all-marks export.
   **Clear ALL marked ROIs** removes marks across every slice and closes the
   summary and resets marker numbering to 1; exported files remain. This button
   is also in the main SCM panel. Marker IDs are separate from export-set numbers.

Automatic selection metadata records the search interval, requested plateau
duration, selected frames, actual time span, spatial constraints and roles.
Independent mode can select different intervals for each side. Shared mode uses
one interval chosen from the data; an independently prespecified interval is
still preferable for confirmatory target/control comparisons.

“Plateau” means the highest **window-averaged positive PSC**, not a flatness test
or the largest absolute change. A sufficiently large short spike can still
influence the average. In a negative-only region the least negative candidate
wins. Spatial and temporal maximization remain exploratory and upward-biased;
use independent/held-out data or **Load fixed protocol** for confirmatory analysis.

Plateau windows use acquired frames entirely within the search interval. Their
sample-to-sample duration rounds UP to the next multiple of TR, includes both
endpoints and is at least the requested duration. For example, 60 seconds at
TR = 33.5 seconds uses three samples spanning 67 seconds. With duration 0,
SCM's original nearest-frame, inclusive-endpoint averaging is retained.

For native searches, the uploaded inclusion mask, rectangle and side mask are
intersected. Atlas searches use labelled brain tissue instead of the uploaded
inclusion mask; any deliberately painted search area still applies. A complete
square ROI must fit in that intersection and have finite data throughout baseline
and the selected window. Display smoothing/alpha/thresholds do not affect scores.
The same workflow operates on the current 2D, motor-acquired 2D or 3D SCM array.
Source data are not modified. Dialog settings start fresh for each search.

Run the synthetic tests from MATLAB:

```matlab
results = runtests('tests/testAutomaticSCM.m');
assert(all([results.Passed]));
```

### Selecting exports and controlling hover

In the candidate table, tick **Export** for each desired ROI, then use
**Export SELECTED ROIs (TXT)**. Green highlighting identifies selected rows;
red text still flags slices exceeding 200%. Selections survive sorting and
filtering, including currently hidden rows, and the status shows their count.
Only checked ROIs are written, with each candidate's Target/Control label and
signal window. The main SCM **EXPORT ROIs (TXT)** button retains its all-marks
export behavior; the explicit Target + Control pair picker is also available.

**HOVER ACTIVE** (green) enables the moving preview. Click to switch to
**HOVER INACTIVE** (red); pending previews are cancelled and moving the mouse
or changing slices cannot re-enable it. Click again to reactivate. Selecting
an automatic candidate or placing a fixed ROI also switches hover to inactive.


## Review settings and registered 2D data

The normal Find and review ROI dialog opens with a 6 x 6 pixel ROI,
7-14 minute search interval and 3-minute maximum plateau. The plateau remains
editable, including 5 minutes. Requested intervals are validated against the
actual acquisition; a short recording is not silently changed to another protocol.

The candidate table shows the recording, ROI side length, search interval,
plateau duration and mode, configured and actual sampled baseline, searched slices, selected
region, coverage limit, roles and image-side split. Bundle exports also save
**Analysis_Parameters.txt** beside the ROI traces. Individual automatic ROI exports
save **Analysis_Parameters_ROIsetN.txt** in the ROI folder. These files include
region provenance, grouping, acquisition TR, requested top-N counts and each
exported member's chosen window, bounds and measured region coverage.

For a single 2D coronal registration or a motor stack registered with per-source
Registration2D files, warping the functional recording loads a four-choice atlas
underlay menu and its region name table. Each motor plane uses its own saved atlas
slice; missing region planes remain unavailable for search. The same 75% minimum
region coverage and strict ventricle/background exclusion apply in 2D and 3D.
Older coronal exports read the region table from their matching
AtlasUnderlay_regions_sliceNNN.mat companion files; new Reg2D files also embed it.

Underlay > **Region abbreviations** shows names on the current Regions plane
(default off). **Region list** opens an ID / abbreviation / full-name table.
Atlas background and unlabelled pixels are black. Display changes and labels do
not change PSC or numerical region masks.

Underlay > **Region colors** selects Atlas, Distinct, Pastel or Grayscale.
**Atlas region boundaries** switches white boundaries on or off, including
while viewing histology or vascular anatomy. Abbreviation positions and boundary
graphics are reused between slices and frames. Opening the region list cannot
overwrite the Video GUI status handle.

Registration, atlas-underlay, ROI and movie outputs use analysed-data destinations.
Legacy RawData / Raw_Data_fUSI registration files remain readable; subsequent
saves are redirected to AnalysedData. Loading an underlay only reads its files.

Prepared atlas textures and contrast-adjusted anatomy are held in bounded caches.
They are reused between PSC frames and repeated slice visits, and invalidated
when the underlay or contrast settings change. Manual 3D registration also reuses
its anatomy interpolator while sampling only the three visible review planes;
full functional warping remains an explicit action.

## Physical ROI sizes and whole-region searches

The ROI-size selector in SCM offers the existing pixel size or **µm; X × Y**.
In micrometre mode enter the horizontal width X and vertical height Y separately.
The footprint uses the nearest whole native pixel count on each axis. The label
shows the actual dimensions and pixel counts; its tooltip retains the requested
size. For the matrix probe's 150 µm columns and 100 µm rows, 1000 × 1000 µm
becomes 7 × 10 pixels, or 1050 × 1000 µm. A 900 × 900 µm footprint is exact.
This also works for calibrated 2D recordings. Unknown calibration requires
**Scale / units** before micrometre mode can be used. Existing pixel-mode ROI
behavior is retained.

Automatic analysis has **square pixels**, **X/Y micrometres**, and **whole atlas
region** modes. Choose CPu or another named region from a registered Regions
underlay. Whole-region mode averages its actual outline separately on each
selected slice and target/control side, then searches the selected plateau
interval. It defaults to the strongest one slice per role; increase the top-N
counts to retain more slices. This is a per-slice regional mean, not the mean of
the entire 3D region. The painted area, selected search bounds and available
acquired coverage still apply; the uploaded SCM mask is ignored. Atlas background and ventricles
are excluded. Missing or invalid voxels cannot silently change the spatial
weights between candidate windows or trace samples.

Plots and TXT exports use the exact regional mask, including irregular borders
and holes. The bounding rectangle is not the averaging mask. Exports record
requested/actual physical sizes, voxel count and, for whole regions, the exact
mask indices. The per-role mean remains one observation for Group Analysis.

SCM and Video **Underlay → Physical X/Y scale** switches between physical
aspect and the previous square-pixel appearance. **Sharp pixels** uses nearest
display interpolation; turn it off for a smoother appearance. Neither option
changes image samples, PSC, masks, ROI coordinates, physical measurements or
atlas transforms.

SCM **Underlay → Show µm ruler** immediately shows or hides the scale bar and
its micrometre label, including on registered atlas underlays. The toggle keeps
the last chosen length; **Overlay → Scale / units → Ruler settings** changes
that length. Rulers require verified spacing for the current functional grid.

**Reset to Native** retains marked ROIs and their IDs. ROIs are mapped through
the applied functional transform using nearest-neighbour mask membership.
An oblique atlas ROI can span several acquired slices; it remains one ROI,
one voxel-weighted time course and one TXT observation. Native traces are
recomputed from native PSC on that mapped support. Returning to the same
atlas grid restores the original ROI definitions instead of repeatedly
resampling them. ROIs outside acquired coverage remain retained for return
to atlas, without inventing native voxels.

Loading Histology first from a registered 2D slice also populates the
Histology / Vascular / Regions menus and region search immediately. Loading
a second underlay is unnecessary.

The automatic candidate review's Close button uses MATLAB's native
`delete(gcbf)` callback. After updating toolbox files, reopen existing SCM
windows to replace callbacks created by an older version; the processed
recording does not need to be recomputed.
