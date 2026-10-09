# Saving completed analyses

Motor reconstruction, PCA/ICA and imregdemons retain their completed dataset
in Studio before writing its MAT file. A failed write therefore leaves the
result available in the dataset list and for retry, without repeating analysis.

Saves finish synchronously and verify the staged MAT before publishing the
final filename. Legacy queued results also finish with a complete write;
they no longer depend on repeated idle timer ticks to append image chunks.
Large motor files can take time to write. Wait for **Saved and verified**.
Closing or loading another animal is blocked while a write is in progress
or a result remains unsaved. Existing result files are never overwritten.

If saving failed, restore access to the output folder, then use the Studio
save-status button and **Finish / recover saves without rerunning analysis**.
For a Studio window opened before this update, run this in its MATLAB Command
Window after the current analysis finishes:

```matlab
deConfUSIon_finish_saves
```

Leave MATLAB open until recovery succeeds, then relaunch `deConfUSIon` to
load the updated Studio callbacks. Recovery uses retained in-memory results
or completed staged MAT files with recovery records. An unfinished old stage
alone is not sufficient to reconstruct missing movie samples.

QC plot/export failure is reported separately from imregdemons registration.
The completed registered data remain saveable; `imregdemons.QC.error` records
the QC failure when present. This does not change PCA, registration, timing,
slice order, or signal values.

Validation: `runtests('tests/testMotorSaving.m')` covers a 4D motor PCA and
per-slice demons save/load round trip, interrupted writes and retry, retained
Studio state, reentrant save callbacks, complete legacy-stage recovery,
partial-stage retention, and QC export failure.

## Video GUI movie geometry

**Save MP4** keeps the image coordinates, physical aspect, interpolation mode
and canvas dimensions fixed across acquired volumes. Each frame completes its
redraw before capture. The paper-ready companion crops the separate information
bar and adds acquisition time; it does not resize the image between captures.
Both movies therefore retain the same image scale. After export the selected
volume, slice and playback state are restored, and the saved-folder dialog
reports the output under the analysed-data **Videos** folder. Each export now
uses its own subfolder, for example
`Videos/20261009_103045_123_scan9_PC1_imregdemons_LPF/`. All exported slices and
their annotated/paper companions stay together there. `export_settings.json`
records the full selected dataset label, raw/preprocessed paths, baseline,
slices, TR and export settings. Repeating Save MP4 creates another folder; it
does not overwrite a previous export. Folder names follow the signal scan
even when its atlas or Mask Editor underlay came from another scan.

`tests/testVideoExportGeometry.m` decodes the actual MP4s and checks stable
landmark positions, changing signal content, grayscale/RGB single-slice data,
anisotropic multi-slice data, interpolation frame selection and restored GUI
geometry. Existing companion-movie checks remain in
`tests/testMovieCompanionsAndSliceGuide.m`.


In Video GUI's **Overlay** tab, tick **Play included scans in order**
to play the included entries from **Scans / order**. **Save MP4** opens a separate
export selector and defaults to **All included scans in their chosen order**
when several scans are included. This choice is independent of the playback
checkbox. **Selected signal overlay only** explicitly exports just one scan.
Enter individual slices such as **1 2 10**, comma-separated numbers, or an
inclusive range such as **7:9**. Only those slices are saved; each gets one
continuous annotated movie and its paper-ready companion.
Choose **Fixed underlay scan**, for example scan9, to retain its
Doppler anatomy while signals progress through scan6, scan7, scan8 and scan9.
Keep current underlay retains an already loaded Mask Editor/atlas underlay;
a loaded atlas alignment and regions stay fixed. Only the needed scan is
loaded at each boundary. The scan name and local acquisition time appear in
playback and both movie versions. The sequence folder and JSON record ordered
source datasets, scan/frame mappings, each TR, the fixed underlay and baseline
mode/window. Local acquisition time restarts for each scan; unrecorded gaps
between scans are not invented. Save MP4 restores the selected scan and volume.

For scans from the same animal, sequence movies are saved in the shared
animal's **Videos** folder, rather than one scan's folder. The dated subfolder
starts with the full scan range, for example **sequence_scan6-to-scan11**.
The JSON records the exact ordered scans and **selectedSlices**, including
noncontiguous selections. Single-scan exports retain their scan's own folder.

The 3D model's MP4 buttons use the same scan/slice selector. Selected source
slices retain their native depths: PSC and Doppler on unselected slices are
hidden, while a complete atlas reference remains available as context. A
sequence export includes every acquired frame, even when sequence playback
is unchecked. Selecting the sequence for a rotation export combines the PSC
time series with camera motion. Same-animal model sequences use the shared
animal's **3DModel** folder. The original viewer and selection are restored.
