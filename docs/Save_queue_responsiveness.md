# Analysis saves and recovery

Studio preprocessing finishes saving before reporting success. PCA/ICA,
imregdemons, drift compensation, filtering, motor reconstruction and the other
preprocessing callbacks use `DataIO('save', ...)`. The older `enqueue` entry
point now obeys the same synchronous contract, including calls from an older
assembled Studio GUI. The completed MAT file is
available immediately after an analysis finishes, including after restarting
Studio. Saving a large acquisition to a network drive may take time; this is
part of completing the analysis.

DataIO writes an uncompressed v7.3 MAT file beside its destination with a
`.saving` suffix, verifies the expected variables and image dimensions, then
renames it to the final name without overwriting an existing file. Only the
final MAT is listed as saved. A small completion record is published after
the entire stage has been written and checked. If final publication is
interrupted, this record allows the next session to recover that complete
stage. Image class, samples and processing history are preserved. A failed
write raises an error and retains the result for retry, including when the
destination directory cannot be created. Filename resolution no longer writes
directories before DataIO has retained the computed result.

Explicit PSC analysis files also use verified saving and shorter physical
filenames. They retain the source signal in `newData.I`, the computed PSC in
`newData.PSC`, and the baseline/filter settings in `newData.pscParameters`.
Loading them does not replace the source signal with PSC or normalize it twice.
Transient SCM/video PSC caches are still omitted from preprocessing saves.
Standardized Analysis checks save completion before reporting a step as
finished, including when a GUI callback catches and displays a write error.

Physical filenames identify the latest operation. The dataset label and
embedded metadata retain the processing history, including PCA and any actual
drift correction. The saved-file picker reads only small provenance fields
and refreshes old naming caches. Legacy GLM results previously mislabeled as
imreg-only now show their actual correction.

## Existing pending results

Relaunching `run_fusi_studio`, loading another animal, and closing Studio first
finish pending writes and save any result still in Studio memory whose
destination is missing. If this fails, the current session is kept open.
Leave that session open until this completes. Save queue / Retry failed saves
remains available for older queued jobs and failures.

New calls to the legacy `DataIO('enqueue', ...)` API now finish saving before
returning. Older `.deconf.pending` files in the
temporary directory are not necessarily complete. A neighboring JSON manifest
identifies a finalized legacy stage. Studio automatically checks those records
on launch and `.saving.json` records in the selected animal's output folders
on load. Recovery refuses to overwrite a destination and retains conflicting
or invalid stages for inspection/retry. `DataIO('recover',folder)` can also
check a specific result folder.

An incomplete stage without a manifest must not be renamed to a completed MAT
file. After loss of the in-memory result, an incomplete stage may require
rerunning the analysis. This cannot protect against forcibly terminating
MATLAB or losing power while the movie is still being written; keep Studio
open when a save fails, restore the destination, and use Retry failed saves.

## Verification

`tests/test_durable_analysis_save.m` verifies immediate publication even while
Studio/viewer busy flags are set, exact single/double/integer samples including
NaN/Inf, metadata on reload, refusal to overwrite, recovery after write failure,
legacy label correction, saving retained in-memory results, and explicit PSC
data/parameter round trips without double normalization.
`tests/test_motor_pca_imreg_save.m` exercises the actual PCA then imregdemons
GUI callbacks on synthetic motor data.
`tests/test_save_queue_transfer.m` verifies the legacy enqueue API's durable
return, large 3D movies, and result retention/retry after directory failure.
`tests/test_save_recovery.m` verifies restart recovery, legacy stages,
incomplete-stage exclusion, conflict protection, changed-stage rejection and
safe repeat recovery after publication finished but record cleanup did not.
`tests/test_standardized_save_failure.m` checks that a caught GUI save error
is reported as a failed workflow step instead of a successful one.
