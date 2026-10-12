# Functional connectivity: repeatable workflow for a paper

This procedure uses the FC GUI's actual calculations and exports. It separates
stimulation-response amplitudes from correlations between time courses. A clear
PSC response in SCM is useful evidence of activation, but does not guarantee an
FC effect. Awake-mouse fUS can measure activation and region correlations; these
are distinct outcomes ([Ferrier et al., 2020](https://pubmed.ncbi.nlm.nih.gov/32541017/)).

## 1. Choose and verify the input

For the example animal, load this raw scan in **Load fUSI Data**, then select the
saved **pca_dropPC1 + imreg_median_n25** entry in its processed-data dropdown:

`Z:/fUS/Project_MMP9/RawData/RGRO_261007_1024_MM_B6J_1362/RGRO_261007_1024_MM_B6J_1362_scan7_ES.mat`

The verified processed file is:

`Z:/fUS/Project_MMP9/AnalysedData/RGRO_261007_1024_MM_B6J_1362/RGRO_261007_1024_MM_B6J_1362_scan7_ES/Preprocessing/imreg_imreg_median_n25_20261007_133149_67f012fa.mat`

Its saved display name confirms PC1 removal before this imreg result. Use the
same preprocessing decisions for subsequent animals; record the saved filename
and processing history. Inspect motion, registration, abrupt intensity changes
and missing frames before FC. Do not select a pipeline because its network looks
more convincing. Compare a version retaining PC1 as a sensitivity analysis:
removing a shared component can change correlations, including their signs.

Do **not** use this animal's `filter_LPF0p001Hz_o4_...` entry to measure the
40-second-on/20-second-off responses or their correlations. The cycle frequency
is 1/60 = 0.0167 Hz, above that 0.001 Hz low-pass cutoff. Such filtering leaves
mostly much slower changes. Choose a frequency band for the scientific question
and the verified sampling rate, rather than smoothing until an effect appears.

### Resolve timing before using the example in a paper

**Data / atlas > Analysed TR (s)** means seconds between the saved functional
volumes, after averaging. It is not necessarily the raw acquisition TR.

| Recording | Saved volumes | Stored raw interval | Averaging factor | Stored analysed TR |
|---|---:|---:|---:|---:|
| Scan 6 | 100 | 0.399 s | 25 | 9.975 s |
| Scan 7 ES | 145 | 0.409 s | 25 | 10.225 s |

These stored intervals disagree with the reported 0.480 s acquisition interval.
Check acquisition timestamps/trigger logs and how temporal averaging was
performed. If the verified interval is 0.480 s and each output volume combines
25 consecutive input volumes, the analysed TR is **12 s**. Correct the selected
scan's field and repeat the calculation. Do not enter 0.480 into an n25 dataset.
Changes invalidate that scan's FC results and are recorded in exports. This
example retains the stored timing pending that verification.
Correct every included scan separately. If using an external PSC reference,
also confirm its acquisition interval in the baseline selector and rebuild the
reference window; changing the target scan's TR does not change an already
calculated external baseline mean.

The number of independent acquired samples is not increased by display
interpolation or smoothing. At 10.225 s, a three-minute baseline has only about
18 samples. A longer suitable resting recording is preferable for stable
resting-state estimates; do not present that short baseline as a precise network
estimate simply because the GUI can calculate it.

## 2. Load anatomy, regions and a justified tissue mask

Open **Functional Connectivity**. In **Data / atlas**:

1. Click **Histology / image** and select `Histology.mat` from the reviewed 3D
   registration folder for this scan. The picker starts in the analysed
   registration tree. Vascular underlays are also supported.
2. Click **Region labels** and select `Regions_Merged.mat` from that same
   registration. Its embedded metadata supplies full names. Use `Regions_All.mat`
   when detailed subdivisions are the intended analysis.
3. Inspect several slices, including 7/8, with atlas boundaries temporarily on.
   Boundaries, cortex, ventricles and hemisphere identity must agree with anatomy.
   **Hide outlines / mask** removes drawn outlines without changing membership.
4. For seed-to-voxel maps, load a reviewed include mask from Mask Editor when
   needed. An automatic valid-signal mask is not a complete anatomical brain
   segmentation: background can contain varying noise. Mask Editor brain and
   signal masks intersect, respect include/exclude flags, and use the saved grid.
   Loading that bundle as an underlay also imports its drawn masks. No arbitrary
   resizing/transposition of a mismatched mask is performed.

Registered background/root and labelled ventricles/CSF exclusions remain excluded.
Check the registration and mask yourself: an unlabelled or misregistered
ventricle cannot be reliably identified from an acronym list alone. Region FC
uses only labelled, included voxels with usable signal.

**Anatomy > Merge anatomical subdivisions** and **Hemisphere > Merge left +
right** are different choices. The first uses parent regions such as CPu instead
of CPaa/CPamm subdivisions. The second combines homologous left/right traces
using voxel-count weights. For lateralized effects, start with **Both L/R
separate**. Signed registration labels define anatomical left/right; screen
right is not automatically anatomical right.

## 3. Add scans and choose the PSC reference

Click **Scans / order**. Add up to ten raw scans, select a comparable saved
processing entry for each, tick the recordings to include, and sort by
acquisition time or move them manually. The originally loaded scan remains the
initial selection. Shared atlas/underlay mapping is appropriate only when
positioning and geometry stayed unchanged; otherwise register each scan first.

For the requested amplitude reference, click **PSC baseline...**, choose scan 6's
matching n25 processing entry, and select **0–180 seconds**, if that interval is
confirmed suitable. **Reset baseline** restores the initially loaded signal and
baseline. Alternatively use each scan's own defined baseline; use one consistent
policy across animals and record it.

The baseline sets `PSC = 100 × (power − baseline mean) / baseline mean` per voxel.
It is not maximum normalization and does not append baseline samples to the FC
calculation. Pearson correlation of an individual voxel pair is unchanged by a
constant positive rescaling/offset. However, voxelwise PSC scaling changes the
relative weights in a region mean, so ROI FC can depend on the baseline policy.
The GUI computes each recording separately; scan ordering does not concatenate
movies for FC.

## 4. Set the stimulation windows and calculate region FC

Your protocol is **25 minutes total**: 0–3 min baseline, then 22 one-minute cycles
from 3–25 min. Each cycle has 40 s stimulation and 20 s off, giving 14 min 40 s
active stimulation. There is no separate post-stimulation recording in this
25-minute schedule. Use actual trigger times if acquisition and stimulation did
not start together.

In **Time window in each scan**, enter **Start = 3**, **End = 25**:

| Period | With “Use win” off | Interpretation |
|---|---|---|
| Pre | 0–3 min | Short pre-stimulation recording |
| During | 3–25 min, clipped to available samples | Entire stimulation block sequence, including off intervals |
| Post | 25 min to recording end | Unavailable if the recording stops at 25 min |

**During does not automatically select only the 40-second on periods.** The
20-second gaps are also not independent resting-state recordings: responses
may persist into them. Choose **Use win = 3 min** for matched-duration Pre
versus early-During exploratory comparisons. For an independently recorded
resting scan versus a task scan, also match usable durations and preprocessing.
Every time window is local to each recording, not the accumulated scan sequence.

In **Regions**, click **ROI current**, or **ROI all periods** to calculate
available Whole/Pre/During/Post results for included scans. Missing/too-short
periods are skipped rather than replaced by the whole recording. Set **Regions
> ROIs** to **Volume regions** for volume means, and use **Calculate slices**
consistently across animals. **Displayed slice** uses just the current Z.
**Regions + slices > Regions / slices...** explicitly compares, for example,
CPu and sensory cortex on Z7 with dentate gyrus/fimbria on later slices. Each
region/slice entry contributes a separate trace over the same scan-local time
samples. Entries and hemisphere identity are retained in figures and group
exports. In Group Analysis, use **All slices** for this cross-slice matrix.
Check anatomical equivalence of the chosen slices across animals; native Z
indices alone do not ensure matching anatomy. A missing ROI is an error, not
a substitute ROI from another slice.

**Image / labels > Smooth overlay**, off by default, optionally smooths the
displayed signed-r slice using a masked in-plane Gaussian kernel. **Sigma (px)**
is the standard deviation in native pixels. It keeps excluded/undefined pixels
transparent and does not modify ROI traces, matrices, raw seed maps or statistics.
Report it as a visualization setting, separate from analytical preprocessing.
The histogram still describes raw seed correlations.

Click **Choose regions...**. Search by abbreviation, full name, or terms such as
`motor cortex`, `caudoputamen`, `dentate gyrus`. Tick the hypothesis-defined
regions and press **Use regions**. The selection controls Heatmap, Graph and scan
comparisons. Use anatomically defined regions before looking for the strongest
connections; selecting a peak SCM voxel and testing the same recording would
make the result exploratory.

The demonstration selects MOp, MOs, CPu and DGv on both sides: eight ROIs present
in this registration. DGv is a dentate-gyrus subdivision, not all hippocampus.
CA1/CA3 were not available for this selected-region example. Do not invent a
whole-hippocampus result where atlas coverage is missing.

## 5. Review and export the figure and group inputs

1. **ROI Heatmap** shows the selected region correlations. **Colour +/-r = 1**
   makes scales directly comparable across animals. A smaller limit changes
   colour saturation only. Keep the same range across compared panels.
2. **Graph** shows a signed region network: edge colour is r and width is |r|.
   **Min |r|** is a display threshold, not a significance cutoff. Prespecify a
   threshold, e.g. 0.2, and retain the full unthresholded matrix in exports.
3. **Scan differences** selects A and B and displays A, B and **B − A**. IDs
   align the same regions despite ordering differences. Set the intended local
   period first. This difference is descriptive, not a test of significance.
4. **Export paper figure** writes a timestamped folder under `Connectivity/fc_QC`
   containing a 300-dpi PNG, vector PDF/SVG, matrix CSV, full-name region key and
   MAT with the matrix, source region traces, labels, timing, baseline, mask and
   source files. **Export CSV** also follows the displayed selection.
5. **Export to Group** writes `FC_GroupBundle_*.mat`, including available periods,
   full names, 3D maps, slice results, per-scan sample indices and Fisher-z values.
   In **Group Analysis > FC**, click **Load FC Bundles** and choose those files.

Repeat the same choices for each animal. For group inference, use one appropriate
recording per animal per condition, or an explicitly paired/repeated-measures
analysis. The bundle preserves animal IDs but loading several scans does not
automatically make them independent animals or establish a paired statistical
model. Verify the group design and period selection before interpreting p-values;
use per-animal Fisher-z matrices and a justified multiple-comparison procedure.

## What the present example supports

The current toolbox computes ordinary correlations after the chosen upstream
preprocessing. It does **not** automatically regress the event-averaged
stimulation response, physiological nuisance or movement from the ROI traces.
Shared stimulus timing can increase correlation even without a change in neural
interaction. For a task-state connectivity claim beyond coactivation, fit and
validate a suitable flexible stimulus-response model, then evaluate residual
time courses with the same registration, timing and QC. The exported ROI traces
support that subsequent analysis. This rationale comes from fMRI methodological
work and is relevant to interpreting these haemodynamic data, rather than being
a validated fUS model for this animal ([Cole et al., 2019](https://www.colelab.org/pubs/ColeEtAl2019NeuroImage.pdf)).

For now, describe the exported example as **region time-course correlations
during the stimulation sequence in one animal**. Use SCM/task-response analysis
for activation amplitude, add control/resting recordings and independent animals,
and test the prespecified group effect before claiming altered connectivity.

A useful final paper figure can combine a reviewed seed map, selected-region
heatmap/network, and a per-animal paired condition comparison. Its caption should
state preprocessing, TR, usable samples, windows, mask, atlas grouping, hemisphere
mode, animals and statistical model. Strong colour or a visible network alone
is not evidence of significance.
