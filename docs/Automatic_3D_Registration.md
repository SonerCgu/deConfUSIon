# Automatic 3D atlas registration

Open **Registration to Atlas**, choose **3D atlas: AUTOMATIC registration**, and select **ACTIVE 3D DATASET: mean anatomy** for a loaded matrix-probe time series. The active option computes a mean over time without rereading the acquisition file. A saved 3D anatomy can also be selected. The 3D review window always has a green **Automatic 3D registration** button.

1. Confirm the array order and all three voxel spacings in **3D scan geometry**. Spacings are entered in micrometres, independently for each array dimension. For example, 0.1 mm is 100 um. A 54-slice volume is spatial data, not 54 time points. The acquisition orientation must already be known; automatic registration cannot establish probe left/right handedness.
2. Select **ITK-SNAP / Greedy** or **MATLAB**. Greedy is detected in PATH or an installed Windows ITK-SNAP `bin` directory. This installation has ITK-SNAP 4.2. A custom executable can be specified using `setpref('deConfUSIon','greedyExecutable',fullpath)`.
3. Select the vascular atlas for Doppler anatomy, or the histology atlas for multimodal alignment. Begin with **Rigid**. **Rigid then affine** also fits scale and shear. With partial brain coverage, first align the anatomy manually and select **Refine the current manual alignment**.
4. Run registration. Greedy runs as a separate process using local temporary NIfTI volumes; its Cancel button remains responsive. MATLAB optimization runs in process and checks cancellation between stages.
5. **MATLAB registration stays in MATLAB.** The optional automatic ITK-SNAP launch is available only for Greedy. **ITK-SNAP review** exports the current alignment on demand and opens one viewer; repeated clicks reuse a running viewer for the same transform and reference. Vascular or histology is the fixed main image, with the acquired anatomy as the only overlay. Region labels/colors are exported for optional loading but start hidden. Each review creates an `AutoReview` folder with NIfTI images, atlas colors, original label-ID mapping and `ReviewProposal.mat`. In ITK-SNAP, Q/E changes overlay opacity and W toggles the overlay. ITK-SNAP label edits do not automatically change MATLAB's transform.
6. The large top view is coronal; the smaller axial and sagittal views are sanity checks. Scroll through slices and adjust **Anatomy opacity**, which leaves the fixed atlas fully opaque. Drag the anatomy to translate (left button) or rotate (right button). The other planes preview that movement; releasing the mouse commits the same 3D transform. Inspect the brain boundary, ventricles and vessels. Numerical similarity alone does not establish anatomical correctness. **Undo auto** restores the preceding alignment.
7. Choose **Save reviewed** to write `Transformation.mat` into the current dataset's Registration folder. Automatic alignment itself does not save or replace this file. Saved metadata contains the confirmed scan geometry, engine, transform type, optimization matrix, similarity summaries and reviewed matrix. SCM and Video apply this geometry conversion before the affine matrix, using the same resampling routine as 3D registration.

## Calculation and coordinate conventions

The bundled atlas is stored as **[AP, DV, LR]**. A native coronal acquisition is **[DV, LR, AP]**, so the new coronal geometry uses `permute(native,[3 1 2])`, then resamples each axis by its confirmed spacing. It preserves the acquired coronal image without a hidden mirror or transpose. Reverse AP slice order explicitly in Scan geometry if acquisition ran posterior to anterior. Spacing alone cannot establish probe left/right handedness. A separate legacy option retains the original paper convention for files acquired in that layout.

The new convention is saved as `coronal_stack_v2` in geometry metadata. Old transforms retain their legacy application path in SCM/Video; the registration dialog does not silently reuse one as a new coronal transform. Re-register and explicitly save a reviewed transform to adopt the corrected convention. Intensities used for fitting are robustly scaled using the 1st and 99.5th percentiles; acquired functional samples remain unchanged.

Rigid registration estimates `x_atlas = R*x_scan + t`, with rotation `R` and translation `t`. Affine registration estimates `x_atlas = A*x_scan + t`, additionally allowing scaling and shear. Both fit a single linear transform that remains compatible with the toolbox's `affine3d` and `Transformation.mat` pipeline. Deformable warps and ANTs are not part of this implementation.

Greedy fits normalized cross-correlation for the vascular target and normalized mutual information for histology, at several resolutions. MATLAB uses its multimodal mutual-information optimizer with a small initial radius, a translation stage, then rigid refinement and optional affine refinement. Manual starts are prewarped before fitting an incremental transform, preserving their existing rotation and scale. Divergence is rejected, and coverage checks reject proposals that move excessive anatomy outside the atlas. Fitting uses a reduced volume when the maximum image dimension exceeds 160; the resulting matrix remains in the original atlas voxel coordinates. Final functional resampling uses the full spatial grid and processes each time point with the same transform.

Greedy matrices map fixed RAS coordinates to moving RAS coordinates with column vectors. MATLAB uses a moving-to-fixed transform with row vectors, and names its image axes column/row/slice. If `H` maps MATLAB voxel coordinates to the temporary NIfTI RAS coordinates and `G` is Greedy's matrix, the MATLAB matrix is `(H^-1 * G^-1 * H)'`. The conversion includes the row/column swap and zero/one-based origins. Each Greedy result is also resliced by Greedy and MATLAB and compared in the shared interior to detect coordinate-conversion errors.

Failed or canceled proposals preserve the prior alignment. Reflections, extreme scales, negligible overlap, or a substantial decrease in similarity are rejected. These checks are numerical guards; visual review remains necessary for a limited field of view or a poorly matched atlas.

ITK-SNAP review files use NIfTI axes **[LR, AP, DV]**, consistently permuting the reference, anatomy and optional regions. The RAS header represents increasing AP as posterior and increasing DV as ventral. Thus the acquired coronal slice is displayed in the coronal review plane. This review-file conversion does not change the saved MATLAB matrix or the original acquisition.

## Verification

`tests/test_viewer_registration.m` exercises both viewer orientations and square-pixel rendering, repeated load cancellation including setup cancellation, actual Greedy rigid/affine execution, MATLAB fallback, landmark recovery on an asymmetric synthetic volume, coordinate conversion, proposal/undo/save behavior, static volumes with more than 16 slices, and full 4D resampling. The 4D test confirms that the same spatial transform preserves a known proportional relationship between time points. These tests do not establish registration accuracy on a particular animal.

## References

- [Greedy quick start](https://greedy.readthedocs.io/en/latest/quick_start.html)
- [Greedy command reference and transform conventions](https://greedy.readthedocs.io/en/latest/reference.html)
- [ITK-SNAP command-line tools](https://www.itksnap.org/pmwiki/pmwiki.php?n=Documentation.CommandLine)

To load the updated code, close existing deConfUSIon windows and run `run_fusi_studio` again.
