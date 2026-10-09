# Use scan 1 as the baseline for later scans

Load the current scan (for example scan 2) and its desired raw or preprocessed
power dataset in Studio, then open Video GUI or SCM GUI. In **Overlay**, click
**Baseline source...** and select **Another scan / shared reference**.

Studio and the baseline selector share the same folder lookup. A raw file in
`RawData/<animal-session>/<scan>.mat` uses
`AnalysedData/<animal-session>/<scan>/Preprocessing`. Keep all scan result folders
for one session inside that matching animal/session folder. Existing legacy
`AnalysedData/<scan>` results are reused if the mirrored folder has no saved
datasets; an empty folder from an earlier load does not hide them. Folder lookup
does not combine results from different dates or animals.

After moving existing result folders, run `deConfUSIon` again before reloading
the raw scan and choose **Automatic output folder**. Studio updates obsolete
stored paths to the matching moved files, including the save path of a selected
preprocessing dataset, so switching scans or closing the viewer does not
recreate the old folder. A relocated scan retains each separate preprocessing
choice in the Studio dropdown.

1. Click **Select raw reference scan...** and select scan 1.
2. Choose the reference dataset from the dropdown, such as PC1 with
   imregdemons. Saved preprocessing results are discovered using the same
   names as Studio. The file picker starts in the current animal's RawData
   directory. Its corresponding AnalysedData folder is discovered automatically.
   For v7.3 MAT files, selecting a scan or switching the dropdown reads headers,
   not its entire movie. Older MAT files with a nested dataset struct may need
   a full read because that format does not support slicing the nested array.
3. Check the source scan's **Acquisition TR (s), before averaging** and enter
   its baseline start and end in seconds. TR is the time between raw frames.
   The selector defaults to **Another scan**, uses the current scan's confirmed
   acquisition TR, and falls back to **0.480 s (480 ms)** for matrix data.
   The **analysed TR** is displayed separately: averaging 25 raw
   frames at 0.480 s produces one sample every **12 s**, while 50 frames produce
   one sample every **24 s**. Saved preprocessing timing supplies the averaging
   factor; its old raw TR does not override the raw interval you enter.
   The source has its own TR and duration; the current scan's time
   axis stays unchanged. Endpoints round to the nearest acquired frame and
   are included.
4. Click **Apply baseline**. A progress window shows reference-frame reading
   and current-scan calculation. For v7.3 MAT files only the selected baseline
   frames are read, in chunks. The current scan's PSC becomes
   `100 * (current Doppler - reference mean) / reference mean`, per voxel.

For example, power 120 relative to a scan 1 baseline of 100 produces +20%,
including when the whole current scan stays at 120. SCM signal windows,
ROI curves, automatic ROI searches and exported SCM series retain that
offset. SCM disables the local baseline edit while the reference is active;
its displayed source window belongs to scan 1.

SCM prepends the reference ROI's sampled baseline time course before the current
scan's `t = 0`. It displays scan labels, a dashed boundary and a red band on the
reference baseline. **Reference trace** below the plot can show the baseline
window, the **entire reference scan**, or hide it. Both segments use the same
reference mean, per voxel. Negative plot times arrange the reference before
the current recording; they do not represent the actual gap between recordings.
Each scan retains its own sampled TR, and a break prevents drawing a continuous
line between acquisitions. Signal windows and SCM calculations remain on the
current scan. Time-course PNGs show the selected arrangement; ROI TXT exports
retain the current scan's original times and reference provenance.

References cache exact baseline-window power samples when they fit within
32 MB, so hovering normally does not reread the recording. Larger windows and
whole-scan views read only the requested ROI from the source MAT file, in bounded
chunks. Cached samples remain usable if the original source is offline. An older
mean-only reference without an available source cannot supply a time course;
select its source again instead of assuming a zero-valued reference curve.

Existing automatically selected ROIs keep their positions and signal windows
when the reference changes, and their scores are recalculated. Rerun Automatic
analysis to find new peaks under the new reference.

Use **Save reference...** in the selection dialog to save the mean map and its
source file, dataset, TR, sampled frames and requested/sample windows. In
scan 3, scan 4, or another viewer use **Load saved reference...** to reuse it.
The saved reference's original window is fixed; select the source recording
again to choose a different window. Click **Reset local baseline** beside
**Baseline source...** in either GUI to restore this scan/animal's previous
local baseline window without opening the selector.

Use scans with matching voxel spacing and orientation, acquisition gain,
intensity scaling and comparable preprocessing. Different acquired depth
ranges are placed using the scanner's recorded `origen` and `voxelSize`;
only overlapping voxels receive a baseline. Uncovered voxels remain NaN.
For example, the supplied scan 5 is `[70 64 54]` starting at 5 mm, and scan 7
is `[90 64 54]` starting at 6 mm, both with 0.1 mm row spacing. Scan 5 rows
11–70 supply the baseline for scan 7 rows 1–60; scan 7's remaining 30 rows
have no reference data. The mean map retains its original geometry when
saved, so it can also be placed back into scan 5 or used in the reverse direction.
Different spacing, fractional-voxel offsets, missing geometry on unequal
grids, or no overlap produce an actionable error before movie loading.
Recorded origins cannot detect probe movement between scans. Motion correction
inside each scan alone does not establish alignment between scans. Align the
power recordings before using a shared reference. SCM can change the baseline
or per-scan normalization after atlas alignment: it recalculates native PSC
and reapplies the saved mapping, preserving the displayed atlas and ROIs.
Video baseline changes still require native view.

Select absolute, linear Doppler power data for both recordings. PSC-only
exports cannot supply the absolute baseline. Zero or nonpositive reference
voxels become NaN rather than producing infinite percentages. Saved group
bundles retain the reference provenance; raw power is required to change it.
The reference cannot correct acquisition gain changes or preprocessing that
independently rescales or zero-centres recordings.

This feature shares a baseline and can arrange reference/current curves for
display. It does not concatenate their original timestamps or fill acquisition gaps. ROI exports and saved
group bundles retain the source baseline information for later comparison.

Both GUIs' **Region list** windows now have a live search field for
abbreviations and full region names. Search is case-insensitive and supports
multiple words; **Clear** restores the complete list.

## Compare up to ten scans

In either GUI's Overlay controls, click **Scans / order...**. The current scan
and an available external reference are included. Click **Select RAW scan to
add...**, choose its saved raw or preprocessed power dataset from the dropdown,
and click **Add selected scan**. Repeat until the list contains up to ten scans
in total, then click **Use sequence**. The raw picker starts in the current
animal's RawData folder and finds the matching AnalysedData folder automatically.

The default order uses a recorded acquisition timestamp when available, with
the raw file modification time as a fallback. **Move up/down** sets a manual
order; **Sort by acquisition time** restores automatic sorting. The current
overlay scan stays selected when the list is reordered. **Overlay 1–6** in both
GUIs chooses which scan supplies the displayed signal and its baseline/signal
windows. Changing the overlay loads that scan's full movie. The default keeps
the chosen anatomy; the scan dialog also offers a new selected-scan underlay.
SCM retains saved ROIs in overlapping physical coordinates across this switch.

The scan list marks the **originally loaded** dataset: this is the raw or saved
preprocessing entry selected in Studio's **Load fUSI Data** dropdown when the
viewer opened. Switching overlays and reordering scans never changes that
identity. The original dataset stays in the list; it can be unticked.

Select a list row and tick/untick **Include selected scan in time courses**.
**Select all / Unselect all** apply to the entire list. Unticked recordings stay
available in the overlay dropdown and automatic search. Selected curves are
arranged consecutively in the chosen order. If no comparison curve is selected,
the viewer falls back to the current recording's ordinary time course.

**Overlay change: keep current anatomy and contrast** is the default in the
scan dialog. Native underlays retain their physical placement. SCM retains an
applied atlas grid, outlines, labels and ROI positions, and places the selected
scan's signal on that grid using its recorded origins. Alternatively, choose
**selected scan Mask Editor bundle**: the picker opens in that scan's analysis
folder when changing overlays. **Selected scan default Doppler underlay**
restores the previous default-underlay behavior.

SCM's **Time courses → All scans in sequence** displays the same physical ROI
in every scan, with labelled boundaries and breaks between acquisitions. Each
segment retains its own analysed TR. Plot times arrange the scans consecutively
from zero; they do not represent real acquisition gaps. Selecting an overlay
highlights its label and places the signal window within that segment. Video
offers the same scan manager and overlay selector without a time-course plot.

Only the selected overlay needs a full movie in memory. Added v7.3 datasets use
small headers, baseline mean maps and bounded ROI/slice reads. Nearby ROI
positions reuse a power cache capped at 128 MB. Individual scan curves and
stitched curves each have a separate 32 MB cache, so reordering or adding a
scan reuses curves already read. Adding or reordering scans does not recalculate
the active PSC movie when its baseline is unchanged. Unsaved current data remain
in memory; older MAT files that
do not permit partial reads require a full read. Use comparable preprocessing
for every scan. Sequence curves use the selected power datasets and baseline
means; optional viewer filters on the signal overlay are not applied to these
cross-scan comparison curves.

With **Live all scans** off (the default), hovering previews the selected scan
from memory. Clicking or **ADD ROI** displays all scans for that saved ROI.
Tick **Live all scans** to preview the full sequence when the pointer pauses.
The first full comparison requires reading the ROI from each file; the time
depends on file compression and network speed. Slice scrolling and ordinary
hover previews avoid these multi-file reads.
The active scan's power is reused from memory. Full comparisons show actual
scan-by-scan progress and a Cancel button. The progress view shows the current
ROI/scan, waiting and completed recordings, percentage and elapsed time. One
window stays open for a batch of ROI curves; cached curves are reused. Removing an ROI deletes only its
graphics, keeping every other curve intact without rereading those files.

## One atlas alignment across scans

In **Scans / order...**, **Share the loaded atlas alignment and regions across
all scans (same positioning)** is checked by default. Load the atlas underlay
and transform for one recording once. Every loaded scan, including scans added
after alignment, uses the same atlas grid, anatomical underlay, contrast and
region catalogue in SCM and Video. Other scans do not need their own saved
registration or underlay files. Sharing uses recorded native voxel origins to
account for different coverage. It assumes the animal/probe stayed in the same
position; it does not correct motion between recordings.
Opening Video from an aligned SCM, or SCM from Video, carries the shared atlas,
scan list, original dataset identity and available absolute power with it, so
scan and normalization controls continue to work in the child viewer.

Only the selected overlay or a scan being searched is warped. Sharing does not
preload six full warped movies, modify raw files or create new registration
files. Untick sharing to use the selected scan's separate underlay policy.

**Load new underlay** starts in the selected overlay scan's saved atlas folder.
Empty `Registration2D` folders do not hide saved bundles in `Registration` or
`Registration3D`. If that scan has no saved atlas and sharing is enabled, the
picker offers a saved atlas from another loaded scan and identifies its source
in the dialog title. If none of the loaded scans has a registration, it also
checks matching sibling scan folders of the same animal; that source scan does
not need to be added just to load its anatomy. **Load atlas folder** also accepts the dated 3D underlay
folder containing `Histology.mat`, alongside saved step-motor sessions.

## Automatic search across scans

The automatic search dialog's **Originally loaded scan** setting is the
default, independently of the active overlay. Choose a specific loaded dataset
or **All loaded scans** to compare acquisitions. Enter search times in minutes within
each acquisition, rather than positions on the stitched display axis. The same
anatomical search area is placed in physical coordinates for each recording;
an applied atlas grid and eligible tissue stay fixed. Recordings are read one
at a time, with progress and cancellation.

For example, `7 14` searches minutes 7-14 separately in scan 1, scan 2 and each
other searched recording. The range does not shift with scan order or stitched
time-course offsets. The timing header follows the selected search scope.
In an all-scan search, scans too short to cover the complete requested interval
are skipped and reported; the interval is not silently shortened. For a single
scan, choose an interval that fits within that recording.

Across multiple scans the search keeps the strongest candidate per region,
role and slice. **Choose regions...** opens a searchable tick list; selections
remain when the list is filtered. Each selected brain region is searched
separately, including in **Whole atlas region** mode. Top-N counts apply
independently to each selected region and role.
The shared-window option uses the globally strongest candidate's relative time
window across the recordings. The review table and exported search metadata
identify the source dataset for each score. ROI trace exports still describe
the currently displayed overlay recording, with selection provenance retained.

## Optional normalization and smoothing

**Normalize each scan is off by default.** The initial sequence uses the shared
baseline already selected in the viewer. If no external baseline was selected,
the current scan's baseline window supplies the common reference. This keeps
baseline offsets and sustained differences between scans visible.

To remove offsets, tick **Normalize each scan** below the SCM time-course
dropdown. In **Scans / order...**, choose its baseline start and end in seconds;
the same requested window must fit within every scan. Video exposes the same
choice in that dialog. Each scan then uses its own voxelwise mean:
`100 * (power - that scan's baseline mean) / that scan's baseline mean`.
This changes both the comparison curves and the selected scan's PSC overlay.
Unticking the option restores the previous shared reference. Normalization can
hide a real sustained change, so keep the shared-baseline view for absolute
comparisons. In SCM this option remains enabled after atlas alignment and
updates PSC using the existing transform. Absolute power is required; a
PSC-only export cannot be renormalized.

The SCM **Smooth** checkbox is also off by default. Enter a sliding window in
seconds, for example **60** or **120**, below the time-course dropdown. It applies
a centred moving mean to displayed ROI curves, independently within each scan;
it never averages across a scan boundary or missing-data break. Edge windows
shrink to available samples. The window uses each segment's analysed TR, not
the pre-averaging acquisition TR. Smoothing affects displayed curves and their
PNG export; it does not change PSC maps, automatic ROI selection or the active
scan's unsmoothed TXT export.

Atlas-aligned ROI projection and underlay rendering now reuse bounded caches.
Fast wheel input is coalesced so the last requested slice is rendered, while
the live ROI box moves immediately and its curve updates at a limited rate.
Axis scale bars reuse graphics objects and skip unchanged geometry. Adding an
ROI draws only that new ROI and reuses its current-scan trace; existing ROI
markers and curves stay in place. A busy cursor and status text appear while
stitched curves load. The progress window limits repaints to ten per second
and refreshes before network reads, reducing GUI overhead during each click.

After updating the scripts, close existing SCM/Video windows and reopen them
from Studio. Existing windows retain callbacks from the code used to create
them. The new SCM axis listeners and Close button use named callbacks. If an
older SCM window's Close button is already failing, select that SCM window and
run `delete(gcf)` in MATLAB, then reopen it.
