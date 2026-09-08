# SCM, Video and cooperative saving

The save queue is implemented with a MATLAB timer, so its file writes run on the same thread as GUI callbacks. It is not a separate background worker. Queue polling now yields while SCM hover or Video rendering has occurred within the last 0.75 seconds, as well as during an active Studio action. Saving resumes automatically when interaction stops. An explicit `DataIO('wait')` still finishes all saves. Marked, reproducible PSC viewer caches are excluded from saved dataset metadata; the image series, acquisition timing and processing metadata are retained. This avoids an unchunked second movie save during metadata creation.

SCM retains its existing preview time samples and full-resolution pinned/export traces. Large moving ROIs now maintain double-precision sums and valid-voxel counts, updating only the non-overlapping entering/leaving strips. Large jumps, baseline/slice changes, changed time grids and periodic refreshes recompute the complete ROI. Blocks are memory-bounded. Small ROIs use the existing direct calculation. Automatic plot limits and baseline semantics are unchanged.

Video caches the unchanged underlay during playback; manual display changes rebuild it. Playback uses native image RGB frames rather than enlarging and sharpening every multi-slice frame on the CPU. The paused display retains the previous enlargement/sharpening, and export code is unchanged. Image coordinates and aspect ratio remain the same. The fixed-rate playback timer drops overdue callbacks rather than accumulating work, and avoids resetting image axes every frame.

## Measurements and checks

Controlled MATLAB R2023b measurements on this computer (NVIDIA RTX A4000, synthetic data):

| Path | Previous median | Updated median |
| --- | ---: | ---: |
| Video, 80 × 64 pixels, 4 or 54 slices | approximately 58 ms/frame | approximately 3–4 ms/frame |
| Moving SCM ROI, 101 × 101 pixels, 1,500 samples | approximately 58 ms/update | approximately 5–15 ms/update |

These are callback measurements, not guaranteed end-to-end frame rates for a network-loaded live acquisition. Network and memory contention can still affect performance.

`tests/test_scm_hover.m` checks 1/4/54-slice arrays, final pointer position, pinned full-resolution traces, automatic plot limits, timer cleanup and large incremental ROIs with NaNs, diagonal motion, jumps, size changes and clipped edges. `tests/profile_scm_hover.m` compares optimized ROI traces with direct computation. `tests/profile_video_playback.m` checks playback timers, underlay cache equivalence/invalidation, queue deferral while playing, saved image equality and cleanup. `tests/test_save_queue_interaction.m` checks automatic deferral/resumption, atomic publication, metadata and image preservation, and that unmarked scientific PSC fields are retained.

Pause playback and allow pending saves to finish before restarting MATLAB. Reopen Studio and its viewers to replace callbacks from an older session. No existing acquisition or processed MAT files were rewritten by these changes.
