# Functional connectivity: scans, regions and display

The left column keeps **Scan, slices and hemispheres**, **Timing within each
scan**, and **Save, compare and help** visible. The coloured settings buttons
switch between Seed, Regions, Image and Data/atlas. The selected page has a
colour. The settings pages fit without scrolling; scan, hemisphere, timing and
export controls stay visible. For a repeatable scientific procedure, see
[the paper workflow](functional-connectivity-paper-workflow.md).

1. Open FC from the intended processed dataset in Load fUSI Data.
2. Click **Scans / order**, select a raw scan, then choose its saved preprocessing
   result from the dropdown. Add up to **10 scans**, tick included scans, and
   sort by acquisition time or move scans manually. Keep preprocessing comparable.
3. The originally loaded scan remains selected after accepting the list. Use
   **Selected scan** to browse another scan. The loaded anatomy and atlas are
   retained when atlas sharing is enabled; this requires unchanged positioning.
4. Choose **Left**, **Right**, **Both L/R separate**, or the other hemisphere
   modes from the always-visible **Hemisphere** selector. Signed anatomical
   labels come from the registration. A display flip does not redefine left/right.
5. Set the injection/stimulation start and end in minutes. Pre, During and Post
   use those times **within each recording**, with that recording's TR. FC never
   correlates concatenated scans. A period with fewer than three samples is rejected.
6. Use **Seed current / all** or **ROI current / all** to calculate FC. The seed
   size can be typed, selected from a preset, or changed by one pixel with +/-.
   Changing the seed clears old seed results so they cannot be mistaken for a
   calculation with the new seed.
   After calculating a seed map, clicking a new location recalculates the map.
   **Use clicked atlas region as seed** uses the selected region's mean signal;
   **Slice only** limits this seed and its map to the displayed slice. The selected
   region has a yellow outline. Bilateral merged mode combines its two sides.
7. Click **PSC baseline...** to use a defined interval from this or another scan
   for voxelwise PSC. **Reset baseline** restores the initially loaded signal and
   baseline. This changes amplitude referencing; it does not add baseline samples
   to the FC calculation or concatenate scans.
8. Click **Compare scans** or **Scan differences** and choose reference A and comparison B, e.g. scan 9
   and scan 6. When both have atlas regions, it compares region matrices;
   otherwise it compares seed maps at the current slice. Atlas rows and columns
   are aligned by signed region ID, including Left-vs-Right matrices. The third
   panel is **B minus A in Pearson r**, a descriptive difference. Save comparison
   writes its MAT data and PNG into a timestamped subfolder.

Region, pair and seed-partner selectors show full anatomical names and
hemisphere identity. The **Ruler / scale bar** controls sit beneath the seed-map
histogram: turn axes or bar on/off and enter a bar length in micrometres.
Calibrated axes show millimetres; data without known spacing retain pixel units.
Voxel spacing describes sampling rather than measured acoustic resolution.

**Regions > ROIs** distinguishes three choices: **Volume regions** pools each
anatomical region across the Calculate slices range, **Displayed slice** uses
only the current Z, and **Regions + slices** uses explicit region/slice entries.
Click **Regions / slices...**, search a region, select its hemisphere, enter
slices such as `7` or `20 21`, and add the entries. You can add CPu and sensory
cortex at slice 7, then dentate gyrus or fimbria at a later slice. Every row is
a separate trace; repeated entries for the same region on different slices
remain separate. **ROI current / all** correlates these simultaneous traces
within each scan's selected time window. Slice browsing does not change that
selection. The hemisphere menu merges homologous sides only on the same slice.
Unavailable/masked regions are reported rather than substituted from another
slice. Slice identities remain in CSV/figure labels; voxel counts and full
selection metadata are retained in the paper source MAT and group bundle.
In Group Analysis, **All slices** retains the cross-slice
matrix; choosing one slice restricts it to ROIs on that slice. Across animals,
check that selected native slices correspond to the intended anatomy; slice
numbers alone do not guarantee equivalent anatomical locations.

**Image / labels > Smooth overlay** is optional and off by default. **Sigma (px)**
sets the Gaussian standard deviation in native pixels. Smoothing acts on one
displayed correlation slice, accounts for invalid/masked neighbours, and keeps
excluded/undefined pixels transparent. It does not smooth through Z, change
ROI traces/matrices, or alter exported statistical values. The legend identifies
a smoothed display; the histogram continues to show the raw correlations.

For unmoved sequential scans, load a registration/atlas underlay once, then in
**Scans / order** enable **Share loaded atlas alignment and regions across all
scans (same positioning)**. A new registration per scan is unnecessary when
the anatomical pose and sampling geometry remain compatible. Known native
grid origins are respected when loading scans; that is not an estimate of
unrecorded physical movement. Check the boundaries against every scan's anatomy.
Movement, probe drift, or changed acquisition geometry requires correction or
an individual registration. The shared atlas does not replace within-scan
motion correction.

FC opens maximized. Timing and the settings pages have a larger separating
gap; Data/atlas buttons have more spacing. Save and both exports are green,
Close is red and Help is blue. Hemisphere selection remains visible above
all settings pages.
Compare ROI preserves physical image proportions and leaves room between the
ruler and colour scale. Its region-name overlay can be enabled in Image/labels.

**Data / atlas > Tissue mask** shows the active mask source. Automatic mode
uses finite, varying signal, without an intensity-percentile cutoff or an implicit
crop to atlas coverage. This is a validity mask, not an anatomical brain segmentation.
You can select a loaded include mask or no intensity mask. Named ventricles,
CSF and registered background exclusions remain excluded. Incompatible masks
are rejected instead of silently transposed or resized. PSC display uses the
absolute-power reference, keeping anatomy separate from the functional signal.

Full acquisition movies load only when needed. The GUI retains the selected
movie and at most one working movie, with the original dataset available for
restoring the initially selected scan. It does not allocate a concatenated
10-scan movie. File reads and FC calculations report their status.

**Export to Group** calculates missing included-region results and saves the
existing `FC_GroupBundle_*.mat` format. It preserves per-scan TR, local sample
indices, source/processed files, full region names, 3D atlas maps, calibration
and true slice-specific matrices. Unticked scans are excluded. Load the bundle
in Group Analysis's FC tab. Repeated scans from one animal remain repeated
measurements; they must not be counted as independent animals in group statistics.
The bundle includes animal and scan identifiers for that purpose.

The **Choose regions...** picker shows abbreviations, full names and voxel counts.
Search updates as you type and supports anatomical terms such as cortex. Selected
regions appear in the heatmap and in **Graph**, a signed region network whose edge
colour is r and width is |r|. The threshold is descriptive, not a significance test.
**Colour +/-r** controls the symmetric Pearson display scale. Vertical legends
put positive correlations at the top.

**Export paper figure** creates a timestamped folder with PNG, vector PDF/SVG,
matching matrix CSV, full-name region key and source-data MAT. The green CSV export
also uses the displayed region selection. **Data / atlas > Analysed TR (s)** permits
a verified timing correction per scan; it means seconds per saved volume after
averaging and clears stale FC results. Group bundles preserve timing overrides,
baseline, signal and mask provenance on import.

After updating source files, close existing FC windows and reopen FC so MATLAB
creates callbacks from the updated source. Do not edit GUI source during an
active calculation or movie export.
