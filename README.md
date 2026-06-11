# deConfUSIon

**deConfUSIon** is a MATLAB-based graphical toolbox for functional ultrasound imaging (fUSI) analysis. It supports data loading, quality control, preprocessing, percentage signal change (PSC) computation, signal-change-map (SCM) visualization, masking, atlas registration, segmentation, group analysis, and functional connectivity.

This repository was previously named **HUMoR / HUMOR-Analysis-Tool**. The toolbox has now been renamed to **deConfUSIon**. Some internal metadata fields may still retain legacy names such as `HUMOR_fullDisplayName` for backward compatibility with old `.mat` files and saved preprocessing outputs. Do not remove those compatibility fields from saved datasets.

> **Important:** This is research software. All outputs must be manually reviewed before interpretation, presentation, or publication. Raw movies, QC plots, preprocessing choices, baseline windows, masks, ROI traces, atlas registrations, group labels, and functional connectivity outputs should always be checked carefully.

---

## Quick Start

Open MATLAB, navigate to the repository folder, and run:

```matlab
cd('D:\Github\deConfUSIon')
deConfUSIon
```

`deConfUSIon.m` is the recommended user-facing launcher.

Internally, `deConfUSIon.m` calls `run_fusi_studio.m`. Keep `run_fusi_studio.m` in the repository because it assembles and starts the split GUI/runtime safely.

---

## Current Status

The toolbox is currently most complete for:

- **2D probe / single-slice fUSI workflows**
- **2D step-motor / multi-slice workflows**
- **QC and preprocessing**
- **SCM visualization**
- **Mask editing**
- **Atlas registration**
- **Functional connectivity**
- **Group analysis**

The code has recently been cleaned and renamed from HUMoR/HUMOR to deConfUSIon. The active root folder now mainly contains runtime files, shared GUI helpers, atlas helpers, FC/step-motor helpers, and compatibility helpers needed for dropdown naming and saved preprocessing metadata.

---

## Platform and MATLAB Compatibility

Developed and tested mainly on:

- Windows
- MATLAB 2017b
- MATLAB 2023b

The code is written to remain compatible with older MATLAB syntax where possible. Some acquisition-related scripts use Windows-style serial ports such as `COM9`, `COM8`, or `COM14`; these must be adapted for other systems.

Some export functions may depend on Windows-specific features, Microsoft PowerPoint, or ActiveX.

---

## Recommended Workflow

1. Start the toolbox with:

   ```matlab
   deConfUSIon
   ```

2. Load fUSI data using **Load fUSI Data**.

3. Confirm probe type and TR.

4. Run **Full QC** before preprocessing.

5. Review QC outputs.

6. Apply preprocessing only when scientifically justified:
   - frame rejection / interpolation
   - scrubbing
   - imregdemons correction
   - step-motor reconstruction
   - temporal smoothing
   - filtering
   - PCA / ICA denoising
   - despiking

7. Inspect the active dataset in the dropdown after every preprocessing step.

8. Use the Time-Course Viewer and SCM GUI to inspect dynamics and PSC maps.

9. Use masks and atlas registration only after checking raw and preprocessed data quality.

10. Run Functional Connectivity and Group Analysis only after individual datasets pass QC.

11. Export logs and outputs for reproducibility.

---

## Main Features

- Load `.mat`, `.nii`, and `.nii.gz` fUSI datasets.
- Support `[Y X T]` 2D probe data.
- Support `[Y X Z T]` step-motor / multi-slice / 3D-like data.
- Probe-type and TR confirmation during loading.
- Full QC diagnostics.
- Frame rejection and interpolation.
- Scrubbing and outlier handling.
- Imregdemons-based spatial correction.
- Step-motor reconstruction.
- Temporal smoothing and subsampling.
- Butterworth low-pass, high-pass, and band-pass filtering.
- PCA and ICA component inspection/removal.
- Despiking.
- PSC computation.
- SCM visualization.
- Dynamic video inspection.
- Mask editing.
- 2D and 3D atlas registration workflows.
- JM atlas color/order support through `atlas_tools`.
- Segmentation workflow.
- ROI/seed/pair/graph functional connectivity.
- Group-level ROI/map/FC workflows.
- Export of figures, logs, bundles, and analysis outputs.

---

## Core Runtime Files

| File / Folder | Purpose | Keep? |
|---|---|---|
| `deConfUSIon.m` | Main user-facing launcher | Yes |
| `run_fusi_studio.m` | Internal runtime launcher and GUI assembly | Yes |
| `fusi_studio_GUI.m` | Main Studio GUI layout | Yes |
| `fusi_studio_callback.m` | Main Studio callbacks | Yes |
| `loadFUSIData.m` | Data loading | Yes |
| `qc_fusi.m` | Quality control | Yes |
| `filtering.m` | Temporal filtering | Yes |
| `motor.m` | Step-motor reconstruction | Yes |
| `pca_denoise.m` | PCA denoising | Yes |
| `ica_denoise.m` | ICA denoising | Yes |
| `scrubbing.m` | Motion/global-signal scrubbing | Yes |
| `imregdemons_preprocess.m` | Imregdemons preprocessing | Yes |
| `fUSI_Live_Studio.m` | Time-course/movie viewer | Yes |
| `SCM_gui.m` | SCM visualization | Yes |
| `play_fusi_video_final.m` | Video/SCM visualization | Yes |
| `mask.m` | Mask editor | Yes |
| `coreg.m` | Atlas registration launcher | Yes |
| `coreg_3d.m` | 3D atlas registration entry | Yes |
| `coreg_coronal_2d.m` | 2D coronal registration entry | Yes |
| `registration_ccf.m` | Manual atlas registration GUI | Yes |
| `registration_coronal_2d.m` | 2D registration GUI | Yes |
| `Segmentation.m` | Segmentation workflow | Yes |
| `FunctionalConnectivity.m` | Functional connectivity GUI/workflow | Yes |
| `GroupAnalysis*.m` | Group analysis modules | Yes |
| `atlas_tools/` | JM atlas color/order files and manual utilities | Yes |

---

## Files That Should Stay External

Some files are intentionally small and should **not** be integrated into large scripts.

### GUI / timer / popup helpers

Keep these external because MATLAB GUI callbacks/timers may call them by name:

```text
deConfUSIon_popup_autofit_apply.m
deConfUSIon_popup_autofit_timer.m
deConfUSIon_popup_polish_now.m
deConfUSIon_force_fullscreen_fig.m
```

### Functional connectivity / step-motor shared helpers

Keep these external because they are shared across FC, Studio, segmentation, and step-motor workflows:

```text
deConfUSIon_FC_find_stepmotor_txt_names.m
deConfUSIon_FC_read_region_names_file.m
deConfUSIon_FC_stepmotor_read_folder.m
deConfUSIon_find_stepmotor_seg_fc_files.m
deConfUSIon_FC_force_layout.m
deConfUSIon_FC_remember_layout.m
```

### Dropdown / metadata compatibility helpers

Keep these external because they are used by loading, saving, lazy preprocessing, and dataset dropdown refresh:

```text
deConfUSIon_fix_studio_dataset_names.m
deConfUSIon_write_full_display_metadata.m
deConfUSIon_commit_full_display_name.m
deConfUSIon_best_visible_dataset_name.m
deConfUSIon_display_from_file_context.m
deConfUSIon_is_bad_display_name.m
```

---

## Atlas Tools and JM Color/Order Support

Do **not** delete `atlas_tools`.

It should contain files such as:

```text
atlas_tools/
  rgb2acr.xlsx
  list_selected_regions.txt
  save_correct_colors.m
  deConfUSIon_reorder_FC_by_list.m
```

The files `rgb2acr.xlsx` and `list_selected_regions.txt` are needed for JM atlas color/order support.

Automatic atlas preparation uses:

```text
deConfUSIon_prepare_atlas.m
deConfUSIon_apply_rgb2acr.m
readFileList.m
deConfUSIon_fc_jm_order.m
```

`save_correct_colors.m` is a manual utility and can stay inside `atlas_tools`.

JM atlas preparation changes atlas color/order metadata. It does **not** change registration geometry. Always visually inspect registration overlays before trusting atlas labels.

---

## Expected Data Formats

### MATLAB `.mat`

Preferred variable:

```matlab
I
```

Typical dimensions:

```matlab
I = [Y X T]       % 2D single-slice data
I = [Y X Z T]     % step-motor / multi-slice / 3D-style data
```

Optional metadata can include TR, sampling rate, probe type, baseline windows, masks, stimulation/injection timing, and acquisition parameters.

### NIfTI

`.nii` and `.nii.gz` are supported, but orientation, TR, dimensions, and total duration must be checked after loading.

### Step-Motor / Split Data

Use consistent naming for split step-motor files, for example:

```text
slice1_t001.mat
slice2_t001.mat
slice3_t001.mat
```

Always verify:

- number of slices
- frames per slice
- trimming
- baseline frames
- reconstructed dimensions
- active dataset after reconstruction

---

## Recommended Output Structure

Keep raw data separate from generated outputs.

```text
RawData/
  project/
    animal/
      session/
        scan.mat

AnalysedData/
  project/
    animal/
      session/
        scan/
          QC/
          Preprocessing/
          PSC/
          Visualization/
          Masks/
          Registration/
          Registration2D/
          FunctionalConnectivity/
          GroupAnalysis/
          Reports/
```

Do not overwrite raw data. Each preprocessing step should create a new dataset version.

---

## Repository Hygiene

Do **not** commit generated analysis outputs, temporary backups, or animal/session data.

Recommended `.gitignore` entries:

```gitignore
backups/
cleanup_reports/
bakcups/
**/QC/
**/Preprocessing/
**/PSC/
**/Visualization/
**/Masks/
**/Registration/
**/Registration2D/
**/FunctionalConnectivity/
**/GroupAnalysis/
**/Reports/
*.nii
*.nii.gz
*.mat
*.mp4
*.avi
*.pptx
```

Large atlas resources such as `allen_brain_atlas.mat` should ideally be stored through Git LFS, release assets, institutional storage, or separate download instructions.

---

## Backup Folder Policy

During cleanup, the toolbox may contain a `backups/` folder. Keep it until full testing passes with:

- normal 2D data
- 2D step-motor data
- QC
- imregdemons
- filtering
- PCA / ICA
- segmentation
- atlas registration
- functional connectivity
- group analysis

After testing, move or zip `backups/` outside the repository before committing.

---

## Troubleshooting

### A preprocessing output is saved but not visible in the dropdown

Check that these files are present:

```matlab
which deConfUSIon_fix_studio_dataset_names
which deConfUSIon_write_full_display_metadata
which deConfUSIon_commit_full_display_name
which deConfUSIon_best_visible_dataset_name
```

Then restart the GUI and reload the dataset folder.

### Step-motor FC cannot find region TXT names

Check:

```matlab
which deConfUSIon_FC_find_stepmotor_txt_names
which deConfUSIon_FC_read_region_names_file
```

These helpers must remain external.

### Atlas colors/order do not appear correct

Check:

```matlab
which deConfUSIon_prepare_atlas
which deConfUSIon_apply_rgb2acr
which readFileList
```

Also verify that:

```text
atlas_tools/rgb2acr.xlsx
atlas_tools/list_selected_regions.txt
```

exist.

### Direct `FunctionalConnectivity` call asks for data

The FC GUI usually receives data from deConfUSIon Studio. If called directly, it may ask you to select a `.mat` file.

---

## Development Notes

The toolbox was originally developed as HUMoR / HUMOR-Analysis-Tool and was later renamed to deConfUSIon. Some compatibility logic remains so old datasets and metadata still load correctly.

Before adding new modules:

1. Keep runtime files in root unless there is a strong reason to move them.
2. Keep shared GUI/helper functions external if they are used by callbacks.
3. Avoid deleting small helper files solely because they are small.
4. Add new generated outputs to `.gitignore`.
5. Test with normal 2D and 2D step-motor data.

---

## Citation / Acknowledgment

This toolbox is under active development. If you use or adapt it, please cite or acknowledge the author/developer and repository as appropriate. A formal citation can be added once the toolbox or associated manuscript is published.

---

## Author

**Soner Caner Cagun**  
Max Planck Institute for Biological Cybernetics  
Molecular Signaling Lab  
Tuebingen, Germany

---

## Disclaimer

deConfUSIon is provided for research and development purposes. It is not medical software. Results should be validated independently and interpreted in the context of experimental design, acquisition quality, preprocessing choices, registration quality, and biological question.
