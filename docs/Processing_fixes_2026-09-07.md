# Processing and registration fixes — 7 September 2026

Close the current Studio and its child windows after pending saves have finished, then run `run_fusi_studio` to rebuild the GUI callbacks. Existing windows retain their old nested functions.

## Results, responsiveness and naming

The Studio's nested logging function assigned to the shared `studio` variable. Logging a queued save could therefore replace an in-flight result with the preceding `guidata` snapshot. Logging and status rendering now use their own local state. Dropdown refresh keeps the explicitly active result and avoids scanning network preprocessing folders after every operation; discovery remains part of dataset loading.

The main action guard rejects overlapping requests, disables dataset switching while an action is running and consumes pending clicks before releasing the guard. Lazy loading reads one appropriate MAT variable instead of reading the whole acquisition and then reading it again. Selecting a dataset no longer appends naming metadata to the input file.

The cooperative save queue now prevents reentrant writes/finalization. It waits between bounded writes and pauses during a Studio action; in-memory results can be selected before their MAT file is finalized. Retry restarts at the first frame. This is a MATLAB timer queue, not a separate CPU worker. Large network writes can still take time; failed saves remain visible in Save queue.

Raw-name cleanup collapses repeated acquisition suffixes when their timestamp already appears in the session stem: `WT250408_S1_104909_FUS_104909_FUS_104909_raw` becomes `WT250408_S1_104909_raw`. Known processing tags and metadata take precedence over stale raw labels. Unknown files in a preprocessing folder are marked processed rather than raw. Repairs affect displayed metadata; existing acquisition files are not renamed.

PCA/ICA show cancellable decomposition progress. For up to 4096 time points and at least as many voxels, the exact temporal Gram matrix is accumulated in blocks and its leading eigensystem is used. Longer recordings default to a deterministic randomized SVD with 30 extra basis vectors and two stabilized subspace iterations. Seven bounded matrix passes replace the potentially hundreds of operator-SVD passes on long, noisy raw acquisitions. This applies to 2D single-slice, motor and 3D data; no prior imregdemons processing is required.

Every frame and voxel participates. For centered voxel-by-time `X`, the approximation is `X ≈ W diag(s) U'`; explained variance remains `s(k)^2 / sum(X(:).^2)`, using the exact total centered energy. The GUI identifies the fast approximation and displays `||X'W - U diag(s)||F / ||s||2`. Both component windows offer **Exact PCA/basis** to recompute. Exact mode uses a Gram matrix up to 8192 frames (512 MiB) when feasible, otherwise operator SVD. The applied result's statistics record the algorithm, approximation flag, seed, iterations and residual. Weak components may differ from exact PCA. ICA uses the same basis to whiten before symmetric FastICA. See [Halko, Martinsson and Tropp](https://arxiv.org/abs/0909.4061) for the randomized subspace method.

Filtering bounds its temporary working set by recording length, avoiding fixed blocks that become multi-gigabyte arrays on long recordings. Older repeated full stems are also collapsed: `Mouse250407_S1_Ringer_FUS_151142_Mouse250407_S1_Ringer_FUS_151142_raw` displays as `Mouse250407_S1_Ringer_FUS_151142_raw`.

## UI and drift

Section glyphs use the section accent color. Specific QC retains its colored module markers and buttons; all twelve rows fit within the panel. New log messages scroll to the latest entry, while manual scrolling remains available.

`DriftCompensation('run',...)`, numeric-first calls and `Drift('core',...)` now route PACAP aliases consistently. The PACAP estimator and common statistics remain the existing numerical implementations.

## Registration and exports

See [Automatic 3D registration](Automatic_3D_Registration.md) for the Greedy/MATLAB workflow and optional ITK-SNAP review. Native geometry conversion is shared by registration, SCM and Video before applying new 3D transforms. Legacy transforms without geometry metadata retain their direct-grid behavior.

A comparison against the repository HEAD found no removed export functions in GroupAnalysis, SCM or Video. This pass does not replace plateau or robust-peak algorithms. Export callback presence is not an end-to-end validation of every possible atlas, ROI, spreadsheet or PowerPoint export.

## Verification

`tests/test_processing_regressions.m` covers exact PCA against full SVD, cancellation, names, all 11 drift choices on 2D/3-slice/54-slice synthetic arrays, MAT round trips, two consecutive real Studio filtering runs, immediate dropdown selection, reentry rejection, geometry-aware warping and review labels/colors. `tests/test_viewer_registration.m` covers viewer geometry, repeated load cancellation, actual Greedy and MATLAB registration, proposal/undo/save and static/4D output.

Read-only validation on `Mouse250407_S1_Ringer_FUS_151142.mat` used all 156 × 256 × 6000 samples. Loading took 9.0 s; the PCA component window became interactive in 17.8 s and ICA in 13.5 s after loading. Full-recording filtering took 15.5 s. Imregdemons was checked on the first 40 frames (four median blocks), taking 2.7 s. Both GUI screenshots are in local `validation/ringer_*_window.png`. These timings describe this computer and acquisition, not a guarantee for every dataset.

`tests/test_registration_planes.m` checks unflipped coronal mapping, plane-specific drag axes, cross-plane previews, transform commit, anatomy-only opacity, and identical spatial transforms across time points. The real-data mode uses a 32-frame sampled mean from the supplied 80 × 64 × 54 scan5 acquisition at 0.10 × 0.15 × 0.15 mm. MATLAB produces a review proposal without opening ITK-SNAP. Explicit review launches one viewer, reuses it for repeated clicks, and loads vascular anatomy underneath the acquired overlay. Numerical tests and sampled anatomy do not establish anatomical accuracy; inspect this animal before saving the transform.
