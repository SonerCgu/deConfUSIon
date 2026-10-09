# MatlabMace pipeline review — October 5, 2026

Reviewed `D:/Github/MatlabMace`: 18 MATLAB files in `codes`, nine example scripts,
and the GUIDE figure. This checkout has no README, license file, sample MAT
recordings, atlas MAT file or `dataSamples` folder. The code headers credit the
Urban/Mace laboratories and date the pipeline to September 2020.

All source files were inspected. Numerical and failure cases below were reproduced
in an isolated MATLAB R2023b process using synthetic data. Files in MatlabMace
and raw recording folders were not modified. This is a code review, not a
validation of registration accuracy or experimental results from the authors.

The pipeline has a useful small structure: intensity QC/replacement, repeat
aggregation, stimulus correlation/GLM, affine atlas resampling, regional
extraction and across-session statistics. I would retain these separate stages
and improve their numerical contracts before using it for new datasets.

## Confirmed issues to address first

### 1. Degrees of freedom are wrong in both group-statistics functions

- `codes/map_statistics.m:23` uses `tcdf(t,NumberSessions)`.
- `codes/segmentation_statistics.m:42` uses `tcdf(t,nrep)`.

For an ordinary one-sample t-test of **n independent complete observations**,
the degrees of freedom are **n−1**. Both functions calculate the ordinary
one-sample t statistic but use a different null distribution. This changes
reported significance. [MATLAB one-sample t-test documentation](https://www.mathworks.com/help/stats/ttest.html).

For four values `[1 2 3 4]`, the code gives `t = 3.872983346` and
`p = 0.008973957`. MATLAB's right-tailed one-sample test gives
`p = 0.015233146` with 3 degrees of freedom; a two-sided test gives
`p = 0.030466292`. The regional implementation's degree-of-freedom mismatch was
also reproduced independently.

Use a validated t-test with an explicit tail and dimension. A right-tailed test
is appropriate only for a prespecified increase hypothesis; decreases need the
corresponding left tail or a two-sided test. Return the actual valid n, confidence
interval and effect size. Repeated sessions from one animal must not be treated
as independent animals without an appropriate repeated-measures model. These
functions do not contain that model.

### 2. The averaging example writes a sum

`examples/example02_filter_average.m:16` accumulates accepted scans, then line 21
saves that accumulation as `sessionAverage`, without dividing by the number
accepted. If all scans are rejected, it still saves the last loaded scan's
metadata with zero data. Absolute Doppler values therefore depend on the number
of accepted runs. Some later scale-invariant normalizations can cancel a common
factor; that does not make the saved array an average.

Track accepted scan IDs, check dimensions/spacing/timing, divide by accepted n,
and fail explicitly when n is zero. Require aligned stimulus schedules before
averaging runs. Retain individual runs for animal-level statistics.

### 3. Segmentation has background and hemisphere hazards

At `codes/segmentation_ccf.m:69`, a zero background label enters the `else` branch
and attempts `PR(0)`, which raises an indexing error. An atlas whose background
uses label 1 may avoid this crash but then includes that background label as a
region unless explicitly excluded. A synthetic atlas containing zero reproduced
the failure.

Lines 28–31 say negative labels represent the left hemisphere. Lines 70–74 send
negative labels to `Right`, contradicting that convention. Without the supplied
atlas/acquisition metadata I cannot establish the true anatomical hemisphere,
but the internal inconsistency is definite. Do not fix this by blindly swapping
outputs: verify a known asymmetric landmark and persist the orientation.

The projector sums voxel signals without dividing by their valid counts.
This is consistent with the file's opening description but contradicts its
later “average” comment. A four-voxel region with normalized signals
`[0.5 1 1.5]` returns `[2 4 6]`. If the intended measurement is a regional mean,
track coverage/counts and divide. Label absent/invalid regions as NaN instead of
zero. Grouped regional sums can otherwise be affected by region size and
partial acquisition coverage.

### 4. Timing and baseline are tied to the example acquisition

`codes/segmentation_statistics.m:23` constructs exactly 70 time samples. Calling
it with 50 samples fails with incompatible array dimensions, as reproduced.
`map_correlation.m:24`, `segmentation_statistics.m:25`, and the GLM example
hard-code an HRF repeat time of **0.1 seconds**. This is correct only if it matches
the actual sampling interval used by those traces. Stimulus bounds are sample
indices, not seconds. `select_brain_regions.m:44` uses the first 30 samples as
baseline without checking length, timing or zero variance.

Pass a common timestamps/TR contract, build the stimulus on that time grid,
set baseline in seconds, and validate duration and usable samples. For a motor
scan, preserve per-plane acquisition timing rather than assume simultaneous
sampling of every plane. Separate whole-recording mean normalization from
baseline PSC and baseline z-score; report which quantity is being saved.

### 5. Grouped-region lists can crash

`codes/readFileList.m:74` reads `numberInAtlas` before assigning it when the first
entry begins with a custom `%Group` name. `%Group CP CTX` reproduces an
“unrecognized function or variable numberInAtlas” error. Later group names can
inherit an unrelated preceding region's name.

Initialize group names explicitly; resolve actual member IDs after parsing.
Open read-only lists with `r`, check `fopen`, and close handles on failure.
Validate empty files, unknown acronyms and repeated/overlapping members.

### 6. QC replacement needs edge-case handling

`image_rejection.m:31` requires at least two accepted samples for its default
linear interpolation. One accepted sample raises an interpolation error.
Unconditional extrapolation at the first/last frames or across long rejected
periods can also manufacture unsupported signals.

`data_stability.m:20` squeezes a single-plane trace into a column; its per-plane
loop then normalizes only the first element and returns a time-by-1 rejection
mask instead of 1-by-time. The shape error was reproduced. A flat trace or an
empty lower half of the distribution can leave its scale estimate undefined.

Preserve dimensions with explicit reshaping. Define a policy for no/one valid
frame, maximum interpolation gap and edge censoring; save the rejection mask
and interpolation provenance. Mean intensity alone can flag a genuine global
response and can miss motion that preserves mean intensity. Add independent
motion/frame-difference measures and review QC relative to stimulation.

## Registration and implementation recommendations

- **Record geometry and orientation explicitly.** `interpolate3D.m:32` flips two
  axes and permutes them; `register_data` then warps with the affine matrix.
  This may be correct for the original scanner/atlas convention. It cannot be
  assumed correct for a matrix probe or NIfTI acquisition with a different
  affine. Save native/output spacing, units, axis convention, physical origins,
  transform direction, acquired coverage and a hemisphere check.
- **Resample quantitative data once.** Current registration first creates a
  dense interpolated volume and then calls `imwarp`. Compose physical geometry
  with the affine into one resampling where practical. Use nearest-neighbour
  interpolation for integer region labels and an explicit quantitative
  interpolation policy for Doppler/PSC. Keep display enhancement separate.
- **Keep registration versions and output locations.**
  `registration_ccf.m:304` saves `Transformation.mat` in the current working
  folder and replaces its previous contents. The examples and region-list
  writer also save to the working directory. Introduce an explicit analysed
  output root and dated versions; never rely on the raw-data working directory.
- **Apply pending manual movement before saving.** The save callback writes
  `R.TF`; drag operations live in `r1/r2/r3.T0` until Apply recomposes them.
  Save should apply/validate those edits or clearly block a stale save. This
  follows from the callback flow; it was not interactively reproduced.
- **Make previews cheap.** The legacy registration GUI resamples the full volume
  on Apply/scale changes and deletes/recreates all contour lines on each slice
  refresh. Cache reference slices and reusable graphics, preview only needed
  planes, and perform full resampling for an accepted result. Replace unchecked
  `evalin`/`str2num` display input with validated choices and numeric parsing.
- **Avoid MATLAB name collisions.** `registration_ccf`, `interpolate3D`,
  `moveimage`, `mapscan` and other names overlap deConfUSIon. Keep a separate
  MATLAB path/session for this review copy, or convert reusable APIs to a
  `+mace` package before integrating them. Path order and already-loaded classes
  can silently choose the other implementation.
- **Vectorize bounded blocks.** Correlation, GLM and segmentation currently use
  voxel/frame loops. Compute valid, masked blocks, reuse the GLM design
  decomposition, and use indexed regional reductions with counts. Do not change
  statistical conventions just to make the calculation faster.

## Scientific additions before publication use

1. Keep individual animals/runs, motion estimates, rejected/interpolated frames,
   stimulus timestamps and atlas-review records in every result bundle.
2. For GLM inference, examine residual temporal autocorrelation, include
   justified nuisance/drift regressors, and use an appropriate covariance model.
   `glmfit(...,'normal')` currently has no explicit temporal-whitening step.
3. Correct the intended family of voxel/region comparisons. The examples display
   uncorrected p thresholds and smooth a binary significant map. That is a
   visualization choice, not a validated cluster-inference procedure.
4. Retain unsmoothed quantitative correlation maps. `map_correlation` applies a
   custom spatial median replacement internally; expose it as an optional,
   documented step with its footprint in physical units.
5. Add input contracts, tested failure cases, a minimal reference recording,
   documented dependencies, a reproducible runner and an attribution/license
   audit. Confirm institutional and original-author rights before redistribution.

I would borrow the clear stage-by-stage organization from this pipeline, but
would **not replace the newer deConfUSIon atlas/FC implementations with these
legacy files**. Geometry, timing, hemisphere identity and statistical fixes
need explicit compatibility tests first.

## Evidence

- Review fixture: `validation/review_matlab_mace_oct05.m` in deConfUSIon.
- MATLAB results: `validation/matlab_mace_review_oct05.log`.
- Source hashes: `validation/matlab_mace_source_hashes_before.json`; checked
  again after the review to establish that the supplied pipeline was unchanged.
- Source review covers all supplied scripts; no end-to-end animal run was
  possible from this checkout alone because its referenced datasets are absent.
