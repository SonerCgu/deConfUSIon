# Automatic atlas registration: 2D, motor and 3D

## Single-slice and motor data

Open the **2D Coronal Atlas Registration** editor with an anatomical underlay (preferably a brain-masked Mask Editor export). Choose **Vascular** or **Histology**, select the approximate matching coronal atlas plane, and click the green **Auto: current atlas plane** button. The source slice moves; the chosen atlas plane stays fixed. **Undo auto** restores the preceding alignment. **Save Current Slice** explicitly exports the existing Reg2D transform format plus vascular, histology, regions and region TXT files.

For motor data, select each source slice with **Prev/Next** or the source slider. Every slice retains its own transform, automatic-run report and undo state. Pick that slice's matching atlas plane before fitting. **Save ALL Visited** retains its existing behavior. Automatic refinement does not infer motor spacing, assign atlas slices, or propagate one slice's transform to the others.

The 2D fit searches translation, rotation and uniform incremental scale with decreasing step sizes. It evaluates the complete original source at every candidate, avoiding an early crop into the smaller atlas field of view. It compares the current placement with foreground-center starts, then maximizes normalized mutual information using a 32 x 32 joint histogram:

`NMI(F,W) = (H(F) + H(W)) / H(F,W)`, where `H(p) = -sum(p log(p))` and `W` is the transformed source. Only the union of non-background pixels contributes. A supplied source brain mask excludes pixels outside that mask. Relative scale is bounded to 0.7–1.4, and candidates must retain sufficient foreground and atlas overlap. Incremental similarities preserve the editor's independent scale/rotation model; no shear or reflection is introduced. The saved report records the chosen source and atlas slice. This is refinement of an approximately selected anatomical plane, not automatic anatomical plane identification.

## Matrix-probe / 3D data

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

The new convention is saved as `coronal_stack_v2` in geometry metadata. Old transforms retain their legacy application path in SCM/Video; the registration dialog does not silently reuse one as a new coronal transform. Re-register and explicitly save a reviewed transform to adopt the corrected convention. Intensities used for fitting are clipped/scaled using the 1st and 99.5th nonzero percentiles and square-root compressed. This gives weaker Doppler vessels useful histogram resolution. The 3D fitter uses a separate anatomy buffer, independent of the viewer's display equalization. Acquired functional samples remain unchanged.

Rigid registration estimates `x_atlas = R*x_scan + t`, with rotation `R` and translation `t`. Affine registration estimates `x_atlas = A*x_scan + t`, additionally allowing scaling and shear. Both fit a single linear transform that remains compatible with the toolbox's `affine3d` and `Transformation.mat` pipeline. Deformable warps and ANTs are not part of this implementation.

Without a manual start, the fitter compares the image-box center and foreground-centroid positions with anterior/posterior and depth offsets. Candidate starting positions are scored by NMI and must retain foreground coverage. The search keeps confirmed spacing and orientation. A manual start bypasses this coarse search.

Greedy fits normalized cross-correlation for the vascular target and normalized mutual information for histology, at several resolutions. MATLAB uses its multimodal mutual-information optimizer with a small initial radius, a translation stage, then rigid refinement and optional affine refinement. Manual starts are prewarped before fitting an incremental transform, preserving their existing rotation and scale. Divergence is rejected. If the fine optimizer decreases NMI or loses too much coverage, the valid scored starting proposal is retained and the GUI reports that the fine fit was rejected. The report distinguishes original, initialized and final NMI, and records a rejected optimizer matrix when applicable. A retained coarse proposal still needs careful review. Fitting uses a reduced volume when the maximum image dimension exceeds 160; the resulting matrix remains in the original atlas voxel coordinates. Final functional resampling uses the full spatial grid and processes each time point with the same transform.

Greedy matrices map fixed RAS coordinates to moving RAS coordinates with column vectors. MATLAB uses a moving-to-fixed transform with row vectors, and names its image axes column/row/slice. If `H` maps MATLAB voxel coordinates to the temporary NIfTI RAS coordinates and `G` is Greedy's matrix, the MATLAB matrix is `(H^-1 * G^-1 * H)'`. The conversion includes the row/column swap and zero/one-based origins. Each Greedy result is also resliced by Greedy and MATLAB and compared in the shared interior to detect coordinate-conversion errors.

Failed or canceled runs preserve the prior alignment. Reflections, extreme scales and negligible overlap are rejected. These checks are numerical guards; visual review remains necessary for a limited field of view or a poorly matched atlas.

ITK-SNAP review files use NIfTI axes **[LR, AP, DV]**, consistently permuting the reference, anatomy and optional regions. The RAS header represents increasing AP as posterior and increasing DV as ventral. Thus the acquired coronal slice is displayed in the coronal review plane. This review-file conversion does not change the saved MATLAB matrix or the original acquisition.

## Verification

`tests/test_viewer_registration.m` exercises both viewer orientations and square-pixel rendering, repeated load cancellation including setup cancellation, actual Greedy rigid/affine execution, MATLAB fallback, landmark recovery on an asymmetric synthetic volume, coordinate conversion, proposal/undo/save behavior, static volumes with more than 16 slices, and full 4D resampling. The 4D test confirms that the same spatial transform preserves a known proportional relationship between time points. These tests do not establish registration accuracy on a particular animal.

`tests/test_atlas_2d_registration.m` checks known 2D landmark recovery, changed intensity contrast, cancellation and transform representability. `tests/test_atlas_2d_gui.m` exercises the actual editor with animal 788's saved brain image, including automatic fitting, exact undo, independent motor-slice states and all three atlas export types. It saves only to a disposable test folder.

`tests/test_atlas_real_proposals.m` is a read-only exploratory comparison using animal 788, animal 1115's PC1-removal/imregdemons-n25 motor derivative, and animal 1287's 54-slice imregdemons-n50 anatomy. The 2D atlas planes come from existing user registrations (111 for 788; 138/128/118/108 for the four motor slices). Proposals and comparison PNGs are written under `validation/atlas_real`, separately from the animal folders. These comparisons measure numerical behavior and support visual review; they are not independent anatomical ground truth.

## References

- [Greedy quick start](https://greedy.readthedocs.io/en/latest/quick_start.html)
- [Greedy command reference and transform conventions](https://greedy.readthedocs.io/en/latest/reference.html)
- [ITK-SNAP command-line tools](https://www.itksnap.org/pmwiki/pmwiki.php?n=Documentation.CommandLine)

To load the updated code, close existing deConfUSIon windows and run `run_fusi_studio` again.
