# deConfUSIon repository review — 6 September 2026

## Scope and confidence

The folder inventory contained 261 files excluding Git internals: 164 MATLAB files (including archived and theme copies), 43 PNGs, 22 SVGs, 25 text files, one workbook, one atlas MAT file, one PDF, and miscellaneous repository files. The active root, acquisition, and atlas-tools directories contain 101 MATLAB files and approximately 99,151 lines, including comments and embedded GUI source.

This is a repository-wide architectural review with detailed inspection of selected computation, loading, workflow, and export paths. It is **not** a line-by-line audit of every historical backup or every GUI callback. The README and 19-page manual were consulted; the atlas variable inventory was checked with MATLAB. Icons and workbook contents were not visually audited. Acquisition hardware and complete interactive workflows were not exercised. The findings below were the starting point for the repair release; the implemented changes and current validation are recorded in the updated HTML manual and repository validation log.

## Repair release status

The prioritized defects in this review are implemented in the active root package. The release adds `deConfUSIon_signal.m` for interpolation, PSC/rebasing, finite-sample FC/FDR statistics, compact temporal bases, and finite means; `loadFUSIData.m` now preserves acquired frames and timestamps; NIfTI timing/geometry is explicit; invalid baselines become `NaN`; motor group exports align on physical timestamps; and the seven Standardized Analysis presets validate modality. `SCM_gui.m` uses the selected baseline for both its map and ROI trace. PCA/ICA use the compact basis and show dataset identity. Nine stateless helper files are dispatched through `deConfUSIon_utils.m`.

The MATLAB R2023b synthetic suite currently reports seven passing checks, zero parser errors, and zero failures. The supplied 2D animal 642 and 3D animal 1336 files were loaded successfully during the repair benchmark (about 11 s and 68 s respectively on the available machine); the sandboxed final validation run could not reopen the mapped `Z:` drive, so it records those two representative files as unavailable rather than treating them as failures.

## What the software does

deConfUSIon is an integrated MATLAB workbench for functional ultrasound analysis. Its central object is an active imaging dataset, normally single precision with time in the last dimension: `[Y X T]` or `[Y X Z T]`. The latter can represent step-motor slices or a matrix-probe volume; that distinction affects registration and interpretation.

The main processing route is:

1. Load MAT/NIfTI data and reconcile acquisition metadata, dimensions, timing, and output paths.
2. Inspect quality using global traces, spectra, DVARS, stability, motion proxies, and spatial metrics.
3. Optionally reconstruct motor slices, interpolate artifacts, register images, smooth/filter, remove PCA/ICA/SVD components, or model drift and nuisance signals.
4. Compute PSC and inspect time courses, SCM maps, movies, masks, and underlays.
5. Register anatomy to an atlas and extract labeled region time courses. Segmentation here is atlas-based extraction.
6. Compute subject/ROI/seed connectivity and export bundles for cohort maps and FC summaries.

The acquisition directory also integrates scanner callbacks, motor scheduling, and stimulation hardware. It deserves a separately validated hardware release boundary.

`deConfUSIon.m` launches `run_fusi_studio.m`. The launcher extracts source embedded in comments in `fusi_studio_GUI.m` and `fusi_studio_callback.m`, joins it into a temporary MATLAB runtime, and starts the GUI. Nested callbacks share Studio state. Larger independent GUIs maintain their own state and exchange MAT bundles.

Useful foundations already exist: lazy dataset discovery reads small metadata fields; preprocessing often records a parent dataset key; several algorithms use chunks and single precision; FC bundles preserve both Pearson R and Fisher Z; drift estimation exports diagnostic components; data-repair utilities default to dry runs and provide backups. Preserve these capabilities while making their contracts consistent.

## Fix first: reproduced numerical/data-handling problems

### 1. Frame rejection mixes slices and time for 4D input

**Evidence:** [interpolateRejectedVolumes.m](D:/Github/deConfUSIon/interpolateRejectedVolumes.m:20) obtains three outputs from `size(I)` and interpolates `I(z,x,:)`. For a 4D input, the final size output combines slice and time dimensions. The Studio callback passes the active input directly to it at [fusi_studio_GUI.m](D:/Github/deConfUSIon/fusi_studio_GUI.m:2286), while `frameRateQC` correctly creates one rejection flag per actual time point.

**Reproduced:** With a `[2 3 4 5]` stack whose slice/time signal is `100*z+t^2`, and five false rejection flags, the first slice changed from `[101 104 109 116 125]` to `[101 104 -1084 -2272 -3460]`. Maximum absolute error across the stack was 4776. A linear ramp initially passed, illustrating why a nonlinear, slice-distinct fixture matters.

**Improvement:** Reshape to `[spatialVoxels T]`, validate that the rejection mask has length T, replace only rejected columns, and restore the original shape. Return immediately when nothing is rejected. Make endpoint handling explicit. Add tests for independent slices, no rejections, isolated rejected frames, edge runs, and fewer than two valid frames.

### 2. Loading can silently shorten or pad the acquired series

**Evidence:** [loadFUSIData.m](D:/Github/deConfUSIon/loadFUSIData.m:352) derives a requested frame count from `TotalTimeSec/TR` and trims or repeats a frame when the difference is one.

**Reproduced:** A MAT file containing 10 frames, TR=1, and TotalTimeSec=9 loaded as 9 frames. Nine seconds is a valid first-to-last sample span for those ten samples.

**Improvement:** Preserve acquired frame count at import. Represent sample span `(T-1)*TR` separately from acquisition coverage `T*TR`. Report conflicting metadata; require an explicit processing operation for trimming or padding. Retain original timestamps and frame indices.

### 3. Timestamp units are guessed from magnitude

**Evidence:** [loadFUSIData.m](D:/Github/deConfUSIon/loadFUSIData.m:239) divides timestamp differences greater than 20 by 1000. A separate branch replaces explicit TR outside 0.02–20 seconds with a probe default.

**Reproduced:** Timestamps `0:30:270` loaded with TR=0.03 rather than 30. This example supplies timestamps in seconds; the loader has no unit field to disambiguate them.

**Improvement:** Use explicit units or an acquisition-format adapter. Preserve both the source value and user-confirmed interpretation. If units are unknown, report the ambiguity. Validate timestamp length, monotonicity, and regularity before treating the series as uniformly sampled.

### 4. NIfTI loading lacks a complete timing/geometry contract

**Evidence:** [loadFUSIData.m](D:/Github/deConfUSIon/loadFUSIData.m:306) reads pixels with `niftiread`, assigns `fallbackTR`, and never reads the header with `niftiinfo`. Its conversion helper squeezes and permutes dimensions without retaining an affine or axis specification.

**Reproduced:** Calling the loader on a synthetic 4D NIfTI without the optional fallback TR fails with a logical-scalar error. This test concerns the direct loader API; the GUI may supply a fallback and avoid this particular error.

**Improvement:** Read header timing units, voxel spacing, and spatial transform. Distinguish static 3D anatomy from 2D+time explicitly. Either resolve a valid TR or raise a clear missing-timing error. Test `.nii` and `.nii.gz`, singleton axes, static anatomy, and nontrivial orientation.

### 5. Invalid PSC baselines become huge finite values

**Evidence:** [computePSC.m](D:/Github/deConfUSIon/computePSC.m:67) substitutes the first 10% of the run for an invalid baseline window, then replaces zero/nonfinite baseline intensities with single-precision epsilon.

**Reproduced:** A signal with zero intensity in its baseline and intensity 1 afterward produces approximately **838,861,000% PSC**.

**Improvement:** Return a baseline-validity mask and mark unsupported PSC as invalid rather than an enormous finite response. Validate baseline duration and finite support, expose the number of affected voxels, and record the exact window actually used. Apply the same policy in SCM, segmentation, and group exports.

## Fix next: analysis and workflow consistency

### 6. Group FC p-values use a normal approximation

**Evidence:** [GroupAnalysis.m](D:/Github/deConfUSIon/GroupAnalysis.m:7871) calculates a sample t statistic but converts it to a p-value using `erfc(abs(t)/sqrt(2))`. Both single-group FC calculation paths call this helper. The reviewed path exports p-values without a multiple-comparison adjustment. Fisher-Z averaging is already present and should remain.

**Improvement:** Use a finite-sample test with the appropriate degrees of freedom, define behavior for degenerate variance, export valid subject counts per edge, and offer a declared multiple-testing family over unique off-diagonal edges. Make animal/session identity explicit and validate duplicate/repeated scans before treating observations as independent. These are source findings; the full group GUI has not been exercised.

### 7. Motor group export combines frame indices instead of physical times

**Evidence:** [GroupAnalysis.m](D:/Github/deConfUSIon/GroupAnalysis.m:6538) loads each subject's TR, truncates to the shortest frame count, averages corresponding frame indices, and then assigns the median TR to the combined series. Different TRs therefore align different physical times. The export setup also forces baseline `[20 40]` seconds at line 6514. Its PSC normalization helper replaces nonfinite data with zero before later contribution counting.

**Improvement:** Validate common anatomical coordinates and baseline conventions, align each subject to a documented physical/event-relative time grid, and preserve missing data until contribution counts are computed. Share computation between preview and export so exports inherit the chosen baseline. Reject incompatible bundles with an actionable message. This finding is specific to the motor group bundle/export path, not a claim about every GroupAnalysis workflow.

### 8. Option A has changed substantially without matching documentation

**Evidence:** [standardizedAnalysis.m](D:/Github/deConfUSIon/standardizedAnalysis.m:953) now enables PCA/ICA, Imregdemons, and SCM. It sets automatic PC1 removal, nsub=50, baseline 30–60 seconds, and signal window 120–180 seconds. The README and June manual describe Motor, Imregdemons, Video, Time-Course Viewer, and SCM instead. The implementation's PCA auto-apply setting is passed through the Studio callback.

**Improvement:** Name and version presets by their actual purpose. Show the ordered operations and parameter changes before execution, including automatic component removal and temporal reduction. Keep an inspection preset available. Generate the preset documentation from the same definitions used by the GUI. Validate modality and timing windows against the current dataset.

## Structural improvements with the highest payoff

### One dataset and provenance schema

Introduce a versioned contract containing dataset ID, parent ID, source path/fingerprint, explicit axes, modality, physical coordinates, time vector and units, acquisition events, mask meaning, and processing history. Each history entry should include parameters, actual applied settings, warnings, software revision, and success/partial/cancelled status. Keep legacy display fields readable through adapters.

Display names should be generated from metadata, not serve as metadata. The existing naming/repair helpers demonstrate how costly it is to infer processing chains from filenames and multiple competing fields.

### Computation callable independently of the GUI

Extract one module at a time into functions accepting data and settings and returning results/status. Start with the reproduced loader/interpolation/PSC problems, then group FC and export. Keep the existing GUI as the front end.

`GroupAnalysis.m` has 11,652 lines, `FunctionalConnectivity.m` 10,452, and the two Studio chunks total 13,284. Embedded source assembly and source-text action dispatch complicate debugging and automated checking. An explicit dispatch table and independently parsed modules would make behavior easier to trace. If the temporary assembly remains, isolate its directory by checkout/revision to avoid collisions between running copies.

### A small scientific regression suite

Add synthetic fixtures for known PSC, independent slice/time signals, known correlations, invalid data, timing units, singletons, unequal scan lengths, and atlas-label preservation. Add save/reload round trips across SCM → FC → GroupAnalysis, including reordered ROIs and different hemispheres. Test that cancel/failure cannot be reported as a successful new dataset. No active test directory or CI configuration was found in this inventory.

The next level is a small, approved representative dataset set covering 2D, motor, and matrix-probe workflows. Compare numerical outputs and exported bundles after every release; screenshots alone cannot verify correctness.

### Visible partial failures and reproducible output

Several operations catch errors and continue: filtering can fall back from zero-phase to single-pass filtering, demons can retain the uncorrected block, and display metadata append can fail silently. Filtering already counts fallback chunks; propagate such diagnostics into the Studio dataset status and exports. Cosmetic failures can stay lightweight, while numerical and save failures need structured reporting.

Use one atomic save service: write a temporary result, verify required metadata/dimensions, then publish the final filename. Preserve the current short-filename and lazy-metadata benefits.

### Memory budgets and cancellation

The code already uses useful chunking, but `frameRateQC` converts the complete input to double, the loader loads the full MAT file before selecting an image variable, and the PACAP estimator keeps multiple complete voxel-by-time arrays. Spatial CCA explicitly builds a T×T matrix. These paths can dominate memory on long 4D acquisitions.

Inspect MAT variable metadata before loading candidates; use partial access where the file format permits. Choose chunk sizes from a memory budget, avoid allocating optional diagnostic volumes until requested, and provide progress/cancellation between chunks. Benchmark peak memory as well as elapsed time on real data before choosing optimizations.

### Validate response protection using recovery experiments

The PACAP estimator explicitly preserves an early modeled component and removes a delayed component; stricter settings increase removal scaling. Treat this as a model assumption with saved diagnostics. Validate with synthetic known responses plus nuisance signals, including real responses outside the protected time window. Compare recovered amplitude, timing, residuals, and downstream FC rather than relying only on smoother traces or improved appearance.

### Release and UI maintenance

- Track `atlas_tools/rgb2acr.xlsx` explicitly: it exists locally, but `git ls-files atlas_tools` does not include it and the broad `*.xlsx` ignore rule excludes it. Atlas preparation can skip color correction when it is absent.
- Maintain one theme implementation. The three source files shipped in the theme pack currently match the root, but the installer replaces complete GUI/callback files and can overwrite later application changes. Prefer reusable styling functions and assets.
- Replace global figure-name-based popup polling with layout applied to owned figures on creation/resize where practical.
- Add a dependency/startup diagnostic and a clean release manifest. Document supported MATLAB versions based on actual regression runs, and choose an explicit license and citation metadata with the author.
- Show active dataset lineage, dimensions, TR, baseline, mask, and registration status together. Provide linked before/after views with shared scaling so preprocessing can be assessed consistently.

## Suggested order of work

1. Repair and regression-test 4D interpolation, import timing/frame preservation, NIfTI, and invalid PSC baselines.
2. Correct FC inference and motor group export timing/baseline/missing-data handling; synchronize Option A documentation.
3. Introduce the dataset/result contracts, shared save service, and headless processing entry points incrementally.
4. Add representative end-to-end validation, memory benchmarks, clean packaging, and UI consolidation.

The main opportunity is to make the existing breadth dependable and reproducible. A large GUI rewrite or additional denoising methods should follow that foundation.
