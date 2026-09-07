# GUI and numerical follow-up — 6 September 2026

This pass continues the earlier repairs in place. Pre-edit copies are in
`_backup_gui_followup_20260906_134923`. Earlier changes were retained.

## Repairs

- SCM pinned live traces now use the displayed ROI bounds when the baseline changes, including ROIs added by typed coordinates. Previously the saved trace rebased but the live trace retained its old values.
- SCM averages finite ROI voxels equally across both spatial axes. Averaging column means previously over-weighted columns containing fewer valid voxels.
- SCM and PSC Gaussian smoothing exclude invalid values from local smoothing weights and retain invalid locations as NaN. Missing baseline voxels no longer contaminate neighboring valid tissue.
- SCM series exports use the same finite signal-window mean as the preview.
- PSC interpolation and filtering choose chunk sizes from time-series length instead of fixed, large voxel counts. These bounds limit temporary buffers; they do not eliminate storage for full input and output movies.
- PCA/ICA hide unused component lines and labels, including after paging or scope changes, and use brighter axis labels.
- The ICA preview has room for its time-axis label above the selection summary. The SCM ROI annotation is above the plot, and the opacity checkbox label fits its control.
- Shared button styling gives Apply & Close the success color instead of letting the word Close override it.

## Validation

MATLAB R2023b ran `validate_gui_followup` with six passing test groups:

1. A pinned live ROI and saved ROI both change from 50% to 25% after the baseline changes to a period whose old PSC was 20%.
2. A three-valid-voxel ROI with responses 60%, 0%, and 0% returns 20%, including with asymmetric missing data.
3. Spatial smoothing retains an invalid baseline voxel and the 20% response of its valid neighbor.
4. Temporal interpolation preserves acquired samples and endpoints; chunked filtering matches an independent `filtfilt` reference.
5. PCA, ICA, and Functional Connectivity Help route to their module guidance.
6. Real PCA/ICA windows show animal and scan identity, hide unused component lines, use the correct Apply color, and leave the input unchanged on Cancel.

Synthetic SCM, PCA, and ICA window renders were inspected at 1400×900 and 1600×950 pixels. Local renders and test logs are in `validation/`.

The existing `validate_deconfusion` suite also passes seven synthetic groups and finds zero parse errors, including the assembled Studio runtime. Read-only representative loading and sampled PSC checks succeeded:

| Dataset | Loaded dimensions | Detected median TR | Load time |
| --- | --- | --- | --- |
| Animal 642, FUS 115354 | 267×256×3750 | 0.324 s | 10.7 s |
| Animal 1336, scan4 | 90×64×54×2500 | 0.399 s | 59.9 s |

Both recordings produced irregular-timestamp warnings. The 1336 spatial sample contained 608 invalid baseline voxels, retained as invalid. Source recordings were not modified.

These checks cover the repaired paths, representative loading, and selected GUI interactions. They do not certify every workflow or display size, and the representative checks are not full end-to-end analyses.

Run from the repository root in MATLAB:

```matlab
addpath(fullfile(pwd,'tests'));
validate_gui_followup;
validate_deconfusion;
```
