# Functional Connectivity: 3D slice range and layout

Functional Connectivity opens maximized. Data/atlas loading, the period and
its timing settings, and export remain visible on the left. Large coloured
buttons switch Seed settings, Region settings and Image/labels settings.
Calculations use green, atlas controls violet, export amber, image controls cyan
and Close red. View buttons have distinct colours and retain text labels.
The former white native control tabs have been removed. Mean/median reference
volumes are calculated once; slice scrolling refreshes only the visible view.
Physical rulers and scale bars use verified voxel units or the loaded
registration geometry. Unknown units stay in pixels.

Enter `5 50` in **Calculate slices** to include slices 5 through 50. Slice
indices are inclusive integers on the current functional grid. For an atlas
warped recording, these are its retained acquired coronal planes, not all 264
reference-atlas planes. A single 2D slice uses `1 1`.

Both seed correlation and region-mean extraction use only the selected slices.
Changing the range clears previous seed/region results; compute again to update
the result. Seed placement must lie inside the calculation range. Excluded
planes in a saved seed map are NaN rather than invented zero correlations.
Region result bundles record `analysisSliceRange`; per-slice result generation
omits excluded planes. The original functional array is retained unchanged.
Constant or incomplete ROI traces have undefined Pearson correlations (NaN),
including their diagonal entries. Constant or incomplete voxels in seed maps
are also NaN. They are not reported as zero connectivity or perfect self-FC.
Complete nonconstant traces retain the ordinary Pearson calculation.

**Display slice** changes the viewed plane. **Slice only** restricts seed
calculation to its current plane. **Slice ROIs** filters a region display to
regions present in the current plane. These settings have different purposes
from the inclusive calculation range.

The range reduces calculation work and temporary epoch arrays. It does not
avoid loading the original recording into MATLAB initially. Very large movies
still need a later lazy/chunked file reader to reduce initial memory use.

Load `Regions_All.mat` or `Regions_Merged.mat` as **ROI labels** after atlas
registration. Histology and vascular files are display underlays; they are not
integer region definitions. Merged regions retain their colour/name tables.
Review the registration and hemisphere convention before interpreting FC.

Matrix labels default to **Auto**, which samples labels in large heatmaps.
Choose All when a dense label set is needed, or use the region key and CSV for
complete names. Label settings now belong to the current figure, so another
open FC window cannot silently change its matrix label density.

Output roots are redirected to analysed-data locations if the supplied save
path belongs to RawData. Source arrays and raw recording files are not edited.

## Regions, hemispheres and time periods

Load `Regions_All.mat` for detailed regions or `Regions_Merged.mat` for named
parent subdivisions. The atlas-granularity dropdown switches these independently
of the hemisphere dropdown (Left / Right / Both separate / Bilateral merged).
Registered native labels use the saved transform to identify **anatomical**
left/right. Image-left can be anatomical-right. Ventricles, aqueduct, choroid
plexus, background and root labels are excluded; paraventricular brain nuclei
are retained. Verify the anatomical registration rather than assigning sides
from AP slice number. Histology is sampled through the same transform.

Region names opens a searchable key before calculations. Search accepts cortical
synonyms (motor cortex finds the Allen "Primary motor area") and updates while
typing. Region settings offers a selected seed versus chosen regions or the
strongest N partners, and a filtered full matrix. These are display selections;
the full signed matrix is retained in the export. Rankings are exploratory.

Set injection/stimulation Start and End in minutes, then choose Whole, Pre,
During or Post. Window limits how much of the selected period is used; without
it, the full corresponding period is used. Intervals are half-open: Pre excludes
the first stimulation sample; Post starts at the end boundary. A period with
fewer than three acquired samples fails explicitly instead of falling back to
the whole recording. For a scan ending with stimulation, there is no separate
post-stimulation period to calculate.

**ROI all periods** calculates available Whole/Pre/During/Post results with a
cancellable progress view. They occupy independent result slots. Changing time
boundaries or atlas labels clears stale results. **Export to Group** saves the
selected period plus calculated other periods, their actual time indices,
signed region IDs, counts, slice-numbered matrices/maps, geometry and atlas
provenance in `GroupAnalysis/FunctionalConnectivity/FC_GroupBundle_*.mat`.
Metadata-only region exports are rejected.

In Group Analysis's FC tab, load/scan the exported bundles, select the saved
period with the new period selector and select All slices or an anatomical
slice number. All slices uses whole-volume region timecourse FC (it does not
average independent slice correlations). Per-slice matrices are aligned by
signed IDs; absent regions stay NaN and missing slices never substitute another
plane. Animals are the independent observations; slice/voxel counts do not
increase group sample size. Group statistics remain in Fisher-z space.
