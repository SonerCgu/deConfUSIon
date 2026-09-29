# Awake 3D workflow and physical scale

Select **E | 3D awake** in Standardized Analysis. The checked steps run in this order:

1. PCA: remove PC1 automatically, with the existing all-slices PCA implementation.
2. Imregdemons: median blocks of 50 frames, true volumetric registration.
3. Mask Editor: save the mask and close the editor before continuing.
4. Time-Course Viewer: review the trace and close the viewer.
5. SCM GUI: positive-only 0–30%, blackbody, alpha modulation 5–10%, spatial sigma 0.
   Search all slices automatically with 5 × 5 pixel ROIs and a 3-minute plateau
   within minutes 4–16. The end is capped at the last acquired sample. A scan
   without a complete plateau after minute 4 is skipped with a status message.

The default baseline is 30–60 seconds and is editable in the workflow.
Automatic search uses the inclusion mask and a middle split, with displayed
left = Target and right = Control. It uses one shared best window across slices.
Review these assignments and the mask; use Automatic analysis to change them.
No ROI files are exported automatically. Select candidates for export in the review.

## Sampling and smoothing

Imregdemons n=50 is temporal block aggregation, not a spatial sigma. Its output
TR is 50 × input TR; incomplete final blocks are dropped by the existing code.
Registration uses displacement-field regularization (regSmooth=1.3) and spatial
interpolation; turning SCM smoothing off does not undo those operations.

Standalone SCM also opens with the display defaults above. Sigma 0 means no
additional spatial Gaussian smoothing of the SCM map. If enabled, sigma 1 means
one pixel standard deviation along both in-plane axes; Gaussian FWHM is about
2.355 pixels. There is no across-slice Gaussian smoothing in SCM. For 100 µm
pixels, sigma 1 corresponds to sigma 100 µm and FWHM about 235 µm. Anisotropic
pixel spacing gives different physical widths along the two axes. The sigma
field and Scale / units tooltips report those widths for the current setting.
ROI searches and exported traces use the unsmoothed data, not the displayed map.

## Physical ruler

Use **Scale / units → Ruler settings** for Off, 100 µm or 500 µm tick intervals.
Horizontal and vertical rulers use the current row/column spacing. This measures
physical distances on the image; it does not automatically segment brain width.

Spacing is read from explicit voxelSizeUm metadata or voxelSize with declared
spatial units, including NIfTI SpaceUnits. Native scanner headers nested in metadata are also recognized when voxelSize and
imageSize match the grids verified from the supplied matrix/linear sequences.
The current image dimensions must match; cropped/resampled grids are not assigned
these native dimensions automatically. Raw unit magnitudes alone are never used.
When units or transformed-axis correspondence are unavailable, choose
**Calibrate spacing** and enter current row, column and slice spacings in µm.
Unknown slice spacing may remain NaN. Calibration is local to the open GUI.
Native-space rulers are suppressed after atlas warping, and opening a different
SCM bundle clears calibration to avoid silently applying the previous scale.

Voxel spacing is sampling pitch, not measured acoustic resolution. Resolution
requires acquisition/beamforming information and preferably a measured point-
spread function; it cannot be determined from array dimensions alone.

Validation: tests/testAwakeSCMPreset.m and tests/testAutomaticSCM.m.

## Verified sequence grids (29 September 2026)

- paramMatrix15M_1024_V1.m: bf.dz=0.1 mm, bf.dx=bf.dy=0.15 mm:
  [row/depth, column/lateral, slice/elevational] = [100,150,150] µm.
- paramLinear15M_128_D.m: probe.dx=0.09 mm, bf.dx=bf.dz=probe.dx/2:
  [row/depth, column/lateral] = [45,45] µm. Motor-step spacing is not in this file.

The saved header of RGRO_260831_1024_MM_B6J_1336_scan3.mat was inspected without
loading its image array: voxelSize=[0.1,0.15,0.15], imageSize=[90,64,54]. Its native
spacing now resolves automatically to [100,150,150] µm. Use Scale / units → Probe
presets if the saved header is absent but the matching native sequence is known.
These profiles reflect the supplied files, not every acquisition using that probe.

A 5×5-pixel ROI spans 500×750 µm on this matrix grid, or 225×225 µm on the linear
grid. Sigma 1 corresponds to 100×150 µm (matrix in-plane), or 45×45 µm (linear);
Gaussian FWHM is approximately 235×353 µm or 106×106 µm respectively. These are
smoothing widths, not experimentally measured spatial resolution.

The candidate review has a Time: minutes / Time: seconds selector. It converts
Start/End columns without changing the selected frames, ROI IDs, export selection,
or TXT time columns (which already include both seconds and minutes).
