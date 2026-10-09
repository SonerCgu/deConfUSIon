# ROI plateaus, outlier screening and NIfTI volumes

Group Analysis number fields support mouse drag selection in either direction.
Double-click or **Ctrl+A** selects the complete value, including decimals and
minus signs; type a replacement and press **Enter** to apply it. Fields are
left-aligned, and preview refreshes do not rewrite unchanged axis values or
clear their selection.

In **Group Analysis → ROI settings**, **Maximum plateau** is the default. Set
**Search / interval (min)** to the search start/end (for example 15 and 25), and set
**Plateau duration (min)** to 5. Preview and Run use the same calculation:
each subject's maximum arithmetic mean over a complete frame-aligned window.
The window includes its endpoints, as in Automatic SCM; at coarse sampling,
its duration rounds up to a whole number of sample intervals when sliding.
If plateau duration equals the search width (5–6 min with a 1-min plateau, or
5–7 min with a 2-min plateau), there is exactly one candidate: all acquired
samples inside that interval. Boundaries need not coincide with frames; no
samples outside the interval are added. Selected bounds report actual sample
times, which can be slightly inside the nominal interval. Missing samples
invalidate a candidate. Ties select the earliest candidate. The result stores
the chosen bounds in `selectedPlateauWindowsMin` and the settings in
`metricSettings`. Display smoothing does not affect metrics. The menu has two
options: **Maximum plateau** and **Fixed interval mean**. Fixed interval mean
averages the entire interval and disables the plateau duration field. Robust
Peak is no longer offered in the GUI; the legacy backend remains readable.
Editing **Plateau duration** automatically selects **Maximum plateau**. This changes the per-subject
summary values in the lower plot; the measured time-course curves remain the same.

Metrics are calculated from each recording's original acquired samples, not
from the interpolated grid used to draw the group time-course plot. This keeps
the result invariant when another animal with a different TR is added, and
matches automatic SCM's maximum window mean for the same exported ROI trace,
search interval and duration. Already rebased SCM exports are not rebased again.
The reader uses the more precise seconds column of SCM TXT files. Plateau
spacing checks tolerate six-decimal timestamp rounding, without interpolating
over actual acquisition gaps or removing missing PSC samples. Rows with no
valid metric window are listed in the completion status and retained as NaN
in the results (`missingMetricSubjects`), rather than silently disappearing.

P-values use three decimal places in plot labels and `stats.pReport`.
`stats.p` retains full precision for statistics and machine-readable exports.
If rounding would place a value exactly on a significance boundary, the label
uses `<` or `>` to preserve its interpretation. The bottom plot uses one label
above the significance bracket, with pixel-based separation. Automatic axes
reserve headroom; manual limits are preserved. ANOVA/one-sample results do not
receive a misleading two-group comparison bracket.

Selecting a maximum from the measured response is exploratory and can inflate
the measured effect. Prespecify the search and duration across groups; use a
fixed plateau for a prespecified sustained-response endpoint. Input rows must
represent independent subjects for between-subject statistics.

**Add ROI / DATA** reopens the exact folder last used by that button, even
when another row is selected. A cancelled picker leaves that folder unchanged.
The subject table shows the full ROI file path. Double-click its **ROI path** cell to
open the containing folder. Selecting one row also shows its exact path below
the table; click that path or **Open ROI folder** to open the folder. Hover over the path to read it
in full when it is longer than the display area.

ROI TXT imports automatically assign **Target / PACAP → PACAP, CondA** and
**Ctrl / Control / Ringer / Vehicle → Control, CondB**. Plot labels also use
**Control**, including for legacy Vehicle labels. Saved ROI labels take
priority over the filename, followed by the nearest labeled parent folder.
Group A/B and Condition A/B names are also recognized. A parent experiment
folder such as `PACAPvsRinger` cannot override a file's explicit Ctrl label.
Conflicting or missing labels remain **Unassigned / Needs assignment**.
Use **Auto assign from ROI / file** to repair selected existing rows (or all used
rows when none are selected). This explicitly replaces their group and condition;
ordinary refreshes and list loading preserve manual assignments. Editing Group
in the table also updates the corresponding default A/B condition. Condition can
still be edited independently when the study design requires it.

Automatic SCM can export a top-N ensemble per role. Load one `mean` or
`allROIs` file per recording and role, not both: both carry the same equally
weighted mean PSC in column 3. Individual member traces and metadata are
retained in the bundle. The ROI count is not the number of animals; these
ROIs contribute to one observation. Selecting the highest responses does
not establish statistical outlier removal. Independently optimized member
plateaus can differ, so the maximum of the averaged trace can differ from
the average of those member maxima.

Outlier screening uses the current metrics within each **Group × Condition**,
with a minimum of four finite, distinct subject rows. Repeated subject IDs,
missing Animal IDs, insufficient samples, and zero MAD/IQR/SD are reported rather than silently
producing flags. MAD uses `0.6745 * (x - median) / MAD` (default threshold 3.5);
IQR uses the quartile fences (default multiplier 1.5). The optional **SD z-score
(exploratory)** uses `(x - mean)/sampleSD` (default absolute threshold 3).
These are exploratory
flags, not calibrated hypothesis tests or an instruction to discard data.
**None** is the default: all eligible animals are retained. Detection does not
exclude rows. **Exclude flagged** recalculates the flags, requires an exclusion
reason, and retains the original cohort, values, method, threshold, fences,
flags and available pre-exclusion statistics. Failed detection cannot apply
stale flags. Results MAT exports retain these snapshots; Excel exports include
`Exclusion_History`, separately from the current cohort's `Outlier_Audit`.
Revert restores inclusion, but the history remains an account of past actions.

Extreme values inflate the mean and SD, which can hide the very observation
being screened. For a sample of size `n`, the largest possible sample z-score
is `(n−1)/sqrt(n)`. At `n=6`, this is approximately `2.04`; a 3-SD rule cannot
flag anything. The GUI reports this limit. MAD and IQR reduce this masking,
but neither guarantees that an unusual biological response is erroneous.
Four is only a software minimum for screening, not an assurance that a small
cohort supports reliable outlier inference. Do not switch rules/thresholds or
repeatedly remove animals to obtain significance.

Define exclusions before data inspection where possible, document technical/QC
failures independently of treatment responses, and report exact animal counts
and the analysis including all animals as a sensitivity check. An exclusion
reason entered in the GUI is documentation, not proof that exclusion is justified.
Reference: [NIST outlier guidance](https://itl.nist.gov/div898/handbook/eda/section3/eda35h.htm).
Reporting: [ARRIVE inclusion/exclusion criteria](https://arriveguidelines.org/arrive-guidelines/inclusion-and-exclusion-criteria/3a/explanation).

Use Studio's **Load** button to load the original **4D functional recording**
into the normal **Raw** dataset slot, followed by the usual processing and SCM
buttons. In the supplied analysis folder, `mc_func.nii.gz` is a motion-corrected
4D intensity series with 2,400 frames and a 1-second TR. The cleaned mean and
signal-change maps are 3D summaries, not recordings. Selecting one with Load
now asks for the 4D file in the same directory; it never opens a viewer instead.

Optional static viewing remains available with `viewFMRINifti(path)` or
`openNiftiSCM(path)`. In **SCM static-map mode**, choose **Signal change (%)** only for a map already
containing percent change; choose **Image intensity** for a mean fMRI image.
Then select which native voxel axis to scroll through. For the two supplied
files, **voxel axis 2** shows the broad in-plane brain view. This only permutes
axes; exported metadata records the permutation and original affine.
This mode calls `SCM_gui` with explicit static-volume metadata and preserves
voxel values, without inventing frames, a TR, or a baseline. It provides slice
navigation, range/threshold/opacity and colormap controls, square ROIs with
finite-voxel statistics, CSV measurements, PNG images and a static MAT bundle.
ROI measurements always use original values, independent of display controls.
The static bundle is a spatial result, not a time-course/group-analysis bundle.

An optional NIfTI underlay must have the same dimensions, spatial units and
affine transform. The supplied structural-space map and shrunk mean image
have different grids; register/resample the underlay into the map's grid before
combining them. No automatic resize or registration is performed.

The **Open three-plane viewer** button opens the separate volume viewer;
its **Open in SCM** button returns to the static SCM import. It provides slice
sliders, voxel spacing, and an editable intensity range. Signed
volumes initially use a symmetric blue–white–red range based on the 98th
percentile of nonzero absolute values (display clipping only); other volumes use
grayscale. Axes describe native voxel dimensions, not assumed anatomical
directions. Header transforms remain in the viewer metadata; data are not
resampled. The current fUSI dataset, masks and display settings are preserved.

Four-dimensional NIfTI time series still use the normal pipeline and SCM GUI,
including baseline/PSC calculation, temporal processing and ROI time courses.
Those operations are unavailable from a static image. NIfTI slope
and intercept are applied, and temporal units determine TR (unknown units
require confirmation). Static maps are never interpreted as time series.

Run regression checks with `runtests('tests/testGroupROIAndNifti.m')`.
Static SCM checks: `runtests('tests/testStaticSCM.m')`. Reopen Studio after code
updates to replace its assembled Load callback; no MATLAB restart is needed.

SCM ROI TXT filenames include timing provenance. For example,
`ROI1_Target_search15to20min_over3minplateau_selected16to19min_d1.txt`
records the original search, requested plateau duration and selected interval.
Decimal minutes use `p` (for example `0p5`). Manual ROIs use `fixed15to20min`
instead of claiming an automatic search. Full-interval automatic searches use
`wholeSearchMean`. Exact seconds and automatic-search metadata are retained in
the TXT header, and existing ROI labels and time-course columns are preserved.

## Upper time-course display and statistical checks

The **ROI Preview** tab now has an **SEM / SD / None** selector and **Group mean / Group mean + animals / Animals only** views. **Choose animals…** selects animal IDs; the same animal's target/control traces are shown together. These choices change the upper plot and its PNG exports only. They never change group membership, lower-plot metrics, exclusions or p-values. Native per-recording traces and their acquisition time axes are retained in the analysis result. Display smoothing does not change the plateau or t-test calculations.

For individual animal curves, select **Both conditions / Condition A only / Condition B only** next to the view selector. This combines with the animal selection and is retained in PNG exports. It uses each row's Condition (`CondA`, `Condition A`, or `A`, and corresponding B labels); only blank conditions fall back to the row's Group assignment. Explicit conditions take precedence. Group-average curves and the lower statistical comparison remain unchanged.

Mixing exported PSC and raw-intensity recordings requires **Compute PSC** with a valid baseline for the raw recordings. Otherwise the analysis reports incompatible units rather than comparing intensities with percentages. Already exported PSC traces are not normalized a second time.

SD uses the sample denominator `n−1`; `SEM=SD/sqrt(n)` uses the finite contributing recordings at each time point. Neither band is drawn where fewer than two observations are available. SEM expresses precision of the group mean, not the range of individual responses. For example, constant animal responses `[0,10,20]%` have mean `10%`, SD `10%` and SEM `5.77%`: the SEM band does not include the animal at zero. The bottom dot is each recording's maximum complete plateau-window mean on its native grid. Different animals may select different windows, so a mean of individual maxima need not equal a maximum of the group-average trace.

Student's two-sample test uses pooled sample variance and `df=n1+n2−2`. Welch's test uses `sqrt(s1²/n1+s2²/n2)` and Welch–Satterthwaite degrees of freedom. Both p-values are two-sided, `2*P(T_df <= −abs(t))`, computed without rounding or artificially flooring the standard error. Display formatting alone rounds p-values to three decimal places (for example `0.036`); tiny p-values use the existing threshold notation.

**Student's two-sample t-test (equal variance)** is the default. Welch remains
available for independent groups without the equal-variance assumption. The
software does not select between them by a preliminary variance/normality test.
See [GraphPad's guidance on test selection](https://www.graphpad.com/guides/prism/latest/statistics/stat_choosing_a_t_test.htm).
Both require independent animal endpoints; Welch relaxes equal variance, not
independence or the distribution assumptions. The results record finite/missing
row counts, the mean difference in original signal units, its confidence interval
(95% at alpha 0.05), test statistic, degrees of freedom and full-precision p-value.
Excel includes these in `ROI_Statistics`.

For target/control measurements from the **same animals**, select **Paired t-test (matched PairID / animal)**. Matching uses explicit PairID, falling back to Animal ID only when PairID is empty. It tests within-pair differences with `df=numberOfCompletePairs−1`. Duplicate rows within a pair/group are rejected rather than silently averaged; unmatched or nonfinite pairs are excluded and listed in result metadata. Independent two-sample tests require exactly two groups; use ANOVA for more groups. Repeated ROIs/sessions must be aggregated to an independent animal-level endpoint, or analysed with a suitable repeated-measures model.

The selected test runs without inferring the study design from Animal ID labels.
Repeated or blank labels do not suppress an independent-test p-value. Paired
tests use explicit PairIDs, falling back to Animal IDs, and retain their checks
for ambiguous or missing pairs. Select the test according to the experimental
design; repeated ROIs are not independent animal replicates. One-sample testing
requires a single group and cannot silently pool different treatments. For paired
tests, examine within-pair differences; for independent tests, examine each group.

The maximum-window endpoint remains exploratory because its window is selected from the response data. Correct test formulas do not establish normality, independence, or remove selection bias. For confirmatory reporting, prespecify the metric/window and statistical design. Numerical tests compare Student, Welch and paired results against MATLAB `ttest2`/`ttest`, including very small and large scales, missing observations and invalid group/pair configurations. See [NIST's t-test definitions](https://www.itl.nist.gov/div898/handbook/eda/section3/eda353.htm).

ROI statistical p-values are **unadjusted for multiple analyses**. Several brain
regions, windows or endpoints form a family of hypotheses that needs a planned
correction (for example Holm or BH FDR, chosen for the study's aims); the GUI does
not infer that family from separate runs. Reporting only the most favourable
window/ROI/test or excluding a low responder after inspecting the p-value
invalidates a confirmatory interpretation. ROI selection using the same response
data is also exploratory unless selection is independent or accounted for in the
analysis. Report effect estimates and uncertainty alongside p-values, following
the [ASA statement](https://www.amstat.org/docs/default-source/amstat-documents/p-valuestatement.pdf).
