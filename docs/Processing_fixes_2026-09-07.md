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

The SCM/Video setup defaults are now 20–40 s for detected motor data, 30–60 s for matrix-probe volumes, and 30–240 s for other single-slice data. Baseline entry fields use 18-point Arial; the other parameter entries use 14-point Arial. Explicit standardized workflow baselines still take precedence.

Imregdemons, filtering, frame QC/interpolation, scrubbing and despiking show compact dark progress windows with a percentage, elapsed time, approximate remaining time and Cancel. Imregdemons updates after each registered frame/volume (or motor slice/frame), so cancellation waits for the current registration call to finish. QC image export and filesystem work can make the estimate less accurate near completion. Scrubbing metrics now accumulate in bounded voxel blocks rather than making full-size double movie/difference copies. Single-slice scrubbing and despiking outputs retain their original `[Y X T]` layout.

## Consistent acquisition timing

The supplied `RGRO_13082026_MM_B6J_1024_1287_PACAPvscsf01nM_4_FUS_104646` acquisition has 2000 frames. Its existing imregdemons branches used 0.448 s per raw frame (896 s total), while two older PCA branches used 0.320 s (640 s total). This is inconsistent timing metadata, not temporal shortening caused by PCA.

On selection, Studio reconciles legacy derivative timing with the currently confirmed raw-acquisition TR. The 40-frame PCA+imregdemons result therefore changes from TR 16 s to 22.4 s when raw TR is 0.448 s. Acquired samples and existing MAT files are not rewritten. Corrected timing is retained in memory and inherited by newly saved derived outputs. Corrections are logged and carry provenance. Explicit chopping/trimming remains shorter; ambiguous legacy cuts are not inferred from a duration ratio.

SCM's automatic x-axis limit and **X all** use the common acquisition duration, while plotted samples retain their proper temporal spacing. This avoids changing the displayed extent merely because block averaging has an earlier last sample. Explicit manual x limits remain available. PSC caches now require matching dataset identity, baseline, frame count and TR in both SCM and Video, preventing a processed child from reusing its parent's cached PSC.

`tests/test_timing_progress.m` validates timing fields read from all four reported derivative MAT files, unchanged signal samples, idempotent correction, legitimate cuts, identical SCM x-axis extents for 40/80-frame representations, all six SCM/Video probe-default dialogs, font sizes, progress cleanup/cancellation, and the 2D/motor/3D processing paths.

Section glyphs use the section accent color. Specific QC retains its colored module markers and buttons; all twelve rows fit within the panel. New log messages scroll to the latest entry, while manual scrolling remains available.

`DriftCompensation('run',...)`, numeric-first calls and `Drift('core',...)` now route PACAP aliases consistently. The PACAP estimator and common statistics remain the existing numerical implementations.

## Registration and exports

### Split-motor timing and SCM/Video launch follow-up

SCM hover follow-up: mouse movement now queues only the latest ROI for a 25 Hz timer, with the final position rendered even after the mouse stops. The timer stops when idle and is deleted with the SCM window. Rectangle and trace update together; unchanged axes/window graphics are skipped, and pinned time-course limits are cached rather than repeatedly concatenating all saved traces during hover. Existing hover sampling and full-resolution pinned/export calculations are unchanged. `tests/test_scm_hover.m` exercises burst coalescing, final position, 1/4/54-slice data, numerical trace agreement, baseline/slice changes, freezing, automatic limits and timer cleanup through an instrumented temporary copy of the real GUI.

The September 7 timing reconciliation incorrectly compared a reconstructed motor recording with one 44-frame raw dwell. For the reported animal 1115 this compressed 2,244 frames at 0.385 s (or 89 median-block frames at 9.625 s) into approximately 17 seconds. PCA did not delete frames. Reconciliation now uses `motorInfo.reconstructedFramesPerSlice` and its acquisition TR, and repairs derivatives carrying the erroneous dwell-based `acquisitionTiming` in memory when selected. Source MAT files are not rewritten. Legitimate block averaging retains its sampling interval and partial-block coverage.

SCM/Video setup uses the repaired TR, checks baseline limits before accepting settings, and offers an available window for genuinely short recordings. PSC rejects invalid windows before temporal interpolation. Removed the redundant double-precision retry on every PSC error; Video now also populates the bounded PSC cache. Uncaught graphical-button callback errors display a purple `!!! ACTION CRASHED !!!` status, retain the error report, and release the action guard so the user can retry. A terminated MATLAB process cannot update its own GUI.

`test_timing_progress('motor')` covers both reconstruction sizes, repeated timing reconciliation, valid PSC, and removing multiple PCA components without changing time. The `launch` case exercises Studio SCM/Video callbacks and graphical-button error cleanup.

See [Automatic 3D registration](Automatic_3D_Registration.md) for the Greedy/MATLAB workflow and optional ITK-SNAP review. Native geometry conversion is shared by registration, SCM and Video before applying new 3D transforms. Legacy transforms without geometry metadata retain their direct-grid behavior.

A comparison against the repository HEAD found no removed export functions in GroupAnalysis, SCM or Video. This pass does not replace plateau or robust-peak algorithms. Export callback presence is not an end-to-end validation of every possible atlas, ROI, spreadsheet or PowerPoint export.

## Verification

`tests/test_processing_regressions.m` covers exact PCA against full SVD, cancellation, names, all 11 drift choices on 2D/3-slice/54-slice synthetic arrays, MAT round trips, two consecutive real Studio filtering runs, immediate dropdown selection, reentry rejection, geometry-aware warping and review labels/colors. `tests/test_viewer_registration.m` covers viewer geometry, repeated load cancellation, actual Greedy and MATLAB registration, proposal/undo/save and static/4D output.

Read-only validation on `Mouse250407_S1_Ringer_FUS_151142.mat` used all 156 × 256 × 6000 samples. Loading took 9.0 s; the PCA component window became interactive in 17.8 s and ICA in 13.5 s after loading. Full-recording filtering took 15.5 s. Imregdemons was checked on the first 40 frames (four median blocks), taking 2.7 s. Both GUI screenshots are in local `validation/ringer_*_window.png`. These timings describe this computer and acquisition, not a guarantee for every dataset.

`tests/test_registration_planes.m` checks unflipped coronal mapping, plane-specific drag axes, cross-plane previews, transform commit, anatomy-only opacity, and identical spatial transforms across time points. The real-data mode uses a 32-frame sampled mean from the supplied 80 × 64 × 54 scan5 acquisition at 0.10 × 0.15 × 0.15 mm. MATLAB produces a review proposal without opening ITK-SNAP. Explicit review launches one viewer, reuses it for repeated clicks, and loads vascular anatomy underneath the acquired overlay. Numerical tests and sampled anatomy do not establish anatomical accuracy; inspect this animal before saving the transform.
