# Automatic SCM analysis: ROI search and fixed protocols

SCM has an **Automatic analysis** button beside Compute SCM, with two modes: **Find and review ROI**, and **Load fixed protocol**. Both operate on numerical PSC, independently of display colors and alpha. Neither is a trained deep-learning classifier.

## Find and review ROI

1. Select the slice, baseline and brain mask in SCM, then click **Automatic analysis → Find and review ROI**.
2. Enter a square side length: 4, 8, 15, 25, 50 or any positive integer that fits. A size of 8 means exactly **8 × 8 pixels (64 pixels)**. This is not a physical area in mm².
3. Enter signal start/end in **minutes**, separated by a space. The complete interval must fit in the acquisition. The baseline remains the current SCM baseline.
   Search uses the same nearest-frame, inclusive endpoint conversion as SCM. For example, 14–15 minutes with TR=33.5 s selects sample times 837.5, 871 and 904.5 s, rather than rejecting the window because only 871 s is strictly inside it. The result records the actual frame IDs/timestamps and displays baseline/signal frame counts. A one-frame signal interval is a valid snapshot mean, but is not a sustained-response estimate. No samples are fabricated or interpolated by the search.
4. For motor/matrix stacks, **Search all slices** is enabled by default; uncheck it to search only the current slice. Click **Find and mark ROI**. The search evaluates every full square within each slice's mask and selects one highest signed mean PSC per eligible slice. Each included voxel must have finite data throughout both intervals. Slices with no complete valid ROI are listed as skipped. Ties resolve deterministically in MATLAB column order. A maximum is not a significance test; even a noise-only slice can produce a candidate.
5. **Positive display** is enabled by default: range **0–30%**, alpha modulation **5–10%**, positive values only, global opacity 100%. Uncheck it to retain your display settings. This is a fixed visual preset, not a data-dependent optimization or statistical threshold. Negative/weak responses may be hidden visually but remain in ROI traces and numerical scores.
6. Review the yellow numbered rectangles and traces. For multiple slices, a ranked candidate table shows slice, ROI ID, mean PSC and coordinates. Selecting a row jumps to that slice; the strongest candidate is initially displayed. Existing ROIs are retained. The new marks are ordinary SCM ROIs that can be removed with existing controls. Nothing is exported automatically. Use **EXPORT ROIs (TXT)** after review and choose the target/control label as usual. The TXT header records slice, automatic selection settings, display-preset choice and original search score. Multiple slices from one animal are not independent animals.

For each voxel, the search computes `M(v)=100*(mean_signal(P(v))-mean_baseline(P(v)))/(100+mean_baseline(P(v)))`. For each complete square it computes the equal-weight spatial mean of M and chooses the maximum. Summed-area tables make this linear in image size instead of scanning every pixel of every candidate. No display smoothing, threshold, color clipping or alpha modulation changes the score. Multi-slice processing reads one slice/window in bounded chunks; cancellation leaves existing marks and display intact because candidates are published only after the search completes.

This is **exploratory, response-selected analysis**. Using the same data to select the maximum ROI and to test its response creates selection bias. Use an independent localizer/held-out acquisition or the fixed-protocol mode for confirmatory comparisons. Pixel sizes must be interpreted with probe spacing when comparing acquisitions.

## Real-data validation (2026-09-09)

All source files were read only; results and screenshots are in the repository's `validation` directory. These checks verify calculation, display independence and slice navigation, not biological specificity.

- **Animal 788, single slice:** saved `imreg_imreg_med_n100_20260810_144000_00003713.mat` (GLM drift compensation). Size 15, baseline 30–240 s, signal 14–15 min. The positive-display preset retains the same ROI at x=97–111, y=100–114 and mean 25.7004% PSC.
- **Animal 1115, Session_012_SplitMotor:** opened the first raw split file and tested `pca_sl001of004_dropPC1_20260907_163206_00002d02.mat`, whose saved name records motor → PC1 removal → imregdemons n=25. The existing acquisition-timing repair changes legacy TR 0.18872549 to 9.625 s without changing samples. Size 15, baseline 20–40 s, signal 6–9 min. All four slices produced candidates; every table row and trace was checked.
- **Animal 1287, matrix probe:** tested the original `RGRO_13082026_MM_B6J_1024_1287_PACAPvscsf01nM_4_FUS_104646.mat`, size `[70 64 54 2000]`, TR 0.448 s. Size 15, baseline 30–60 s, signal 6–9 min. All 54 slices were searched; 52 had complete valid ROIs and slices 53–54 were correctly skipped. Every candidate's trace and slice-navigation result was checked. Search plus dialog/marking took about 4.4 s in this test, excluding acquisition loading/PSC preparation.

Some motor maxima lie near image edges. The raw matrix recording has large spikes and edge maxima; these must not be interpreted as PACAP responses simply because they rank highest. Use a reviewed brain mask and appropriate preprocessing, then inspect the full traces. The 6–9 min test interval was used to exercise functionality, not established as this experiment's optimal response window.

## Load fixed protocol details

This mode loads JSON, applies the same fixed rectangular target/control ROIs and baseline/signal intervals, and exports two TXT traces, the protocol, and a MAT audit record into a unique folder under `ROI/Automatic` in the current SCM export location. The following sections describe this mode.

## 1. Define the protocol before examining the response

Choose target/control locations from anatomy, a reviewed atlas alignment, or an independent localizer. The coordinates must refer to the **current SCM data array**, not the screen pixels. A dimensions check cannot establish anatomical correspondence: native coordinates cannot be reused across differently positioned animals without registration. Do not choose the ROI on the same response map that will be tested; this creates selection bias ([Kriegeskorte et al., 2009](https://www.nature.com/articles/nn.2303)).

Create a JSON file like this, replacing **all example values** with the study protocol:

```json
{
  "name": "Example only - replace for your experiment",
  "referenceSizeYXZ": [267, 256, 4],
  "roiSizeYX": [9, 9],
  "targetXYZ": [80, 100, 1],
  "controlXYZ": [180, 100, 1],
  "baselineSec": [20, 40],
  "signalSec": [360, 540]
}
```

Coordinates are one-based integers. ROI size is in pixels, not mm². Reuse it only on the same physical sampling grid; an identical pixel count on probes with different spacing does not have an identical physical area. The window endpoints are in seconds. Both windows must fit entirely in the recording. The baseline must precede the signal window and should precede administration according to the experiment protocol. No automatic "best" baseline is inferred from the observed response.

## 2. Calculation and quality checks

For input PSC `P(v,t)`, let `B(v)` be its baseline-window mean. The exact rebase is

`Q(v,t) = 100 [P(v,t) - B(v)] / [100 + B(v)]`.

Each trace is the equal-weight mean over the same fixed voxel set at every frame. Each voxel needs at least 80% finite baseline samples and a positive denominator; invalid ROIs are rejected rather than shrunk. A frame with a missing ROI voxel is marked NaN. At least 80% of the signal interval must have valid trace samples. Target and control cannot overlap or be clipped at image edges. The exported signal summary is the mean trace within the declared signal interval.

Display alpha, spatial display smoothing and color limits do not influence exported measurements. This first implementation does not choose PCA components, optimize contrast, place ROIs by response maxima, or change the current viewer's manual ROIs/windows. It analyzes the dataset currently supplied to SCM: use a fixed preprocessing protocol upstream and retain its provenance. It exports traces, not significance claims or a learned PACAP diagnosis.

## 3. Registration and mask automation

The existing atlas tool supports MATLAB and ITK-SNAP/Greedy rigid/affine proposals with manual review; see [Automatic 3D registration](Automatic_3D_Registration.md). These are numerical registration algorithms, not deep learning. A learned registration model would require representative paired scans, consistent orientation/spacing, anatomical landmarks and validation on held-out animals. Deformable registration would also require applying and exporting nonlinear transforms consistently throughout SCM, Video and ROI export.

Mask learning requires manually reviewed underlay/overlay masks. Start with anatomy-based proposals and manual correction, collect these masks, and evaluate boundary error and excluded vessels on animals excluded from training. Selecting masks to make a functional response look cleaner can bias measurement. No new trained registration or segmentation model is included in this change.

## 4. Motor timing correction

New motor reconstructions now discard the single input dwell's inherited timing/PSC cache and initialize timing from the reconstructed frame count and sample TR. Files concatenate numerically by T index within each slice. Duplicate IDs, different T IDs between slices, or unequal block lengths now stop with an explanation instead of silently truncating or shifting data. The time axis represents concatenated acquired samples; it does not reconstruct wall-clock gaps while the probe visits other slices.

Previously saved datasets remain unchanged on disk. For a dataset saved after an incorrect timing repair, reconstruct again from the original split folder; do not infer a new TR from a stretched plot. Actual file verification is still required for the reported animal.

## 5. Group ROI metrics

The display defaults to 0–20 minutes; peak and plateau windows default to 6–9 minutes, with a one-minute robust-peak window. These are editable starting values, not validated biological response timing.

Plateau is the arithmetic mean in the fixed interval; it does not demonstrate that a response is flat. Robust peak is the maximum trimmed mean over full-duration moving windows within the search interval. Ten percent total trimming removes five percent from each tail, rounded down to whole samples. Both require at least 80% sample coverage and two finite samples. Searching for a maximum still has upward selection bias, even after trimming; use the same prespecified search interval for all groups.

At each time point, `SEM(t) = s(t) / sqrt(n(t))`, using available subjects and sample standard deviation. It is undefined for fewer than two subjects. The shade now draws finite adjacent intervals independently, so missing samples do not break the entire unsmoothed band. Display smoothing preserves missing intervals and does not change exported metrics. Repeated acquisitions from one animal must not be treated as independent animals.
