# deConfUSIon

**deConfUSIon** is a MATLAB-based graphical toolbox for functional ultrasound imaging (fUSI) analysis. It supports data loading, quality control, preprocessing, percentage signal change (PSC) computation, signal-change-map (SCM) visualization, masking, atlas registration, segmentation, functional connectivity, and group analysis - 11th of June 2026.

This repository was previously developed as **HUMoR / HUMOR-Analysis-Tool**. The active launcher and current repository name are now **deConfUSIon**.

> **Research-use warning:** deConfUSIon is research software, not medical software. Always manually review raw movies, QC plots, preprocessing choices, baseline windows, masks, atlas registrations, ROI traces, FC outputs, group labels, and exported figures before interpreting or publishing results.

---

## User Manual

Open the current full updated user manual:

- [Open the current deConfUSIon fUSI Studio User Manual PDF](docs/deConfUSIon_fUSI_Studio_Full_Updated_User_Manual_2026-06-24.pdf)
- [Open on GitHub](https://github.com/SonerCgu/deConfUSIon/blob/main/docs/deConfUSIon_fUSI_Studio_Full_Updated_User_Manual_2026-06-24.pdf)
- [Direct PDF download / browser open](https://github.com/SonerCgu/deConfUSIon/raw/main/docs/deConfUSIon_fUSI_Studio_Full_Updated_User_Manual_2026-06-24.pdf)

This manual covers installation/startup, expected folder structure, Standardized Analysis workflows A and B, QC, preprocessing, frame rejection, scrubbing, despiking, SCM and Video GUI, mask editing, atlas registration, segmentation, functional connectivity, group analysis, exports, abbreviations, mathematical calculations, and troubleshooting.

In MATLAB you can also open the same manual directly with:

```matlab
web(fullfile(pwd,'docs','deConfUSIon_fUSI_Studio_Full_Updated_User_Manual_2026-06-24.pdf'),'-browser')
```

---

## Quick Start

In MATLAB:

```matlab
cd('D:\Github\deConfUSIon')
deConfUSIon
```

`deConfUSIon.m` is the recommended user-facing launcher.

`run_fusi_studio.m` must stay in the repository. It is the internal runtime launcher used by `deConfUSIon.m` to assemble and start the split GUI from `fusi_studio_GUI.m` and `fusi_studio_callback.m`.

---

## Current Code Status

The current source package contains approximately:

- 80 root MATLAB runtime/helper files
- 2 MATLAB utilities inside `atlas_tools`
- 1 current full updated PDF user manual inside `docs`
- atlas support files including `allen_brain_atlas.mat`, `rgb2acr.xlsx`, and `list_selected_regions.txt`

The current code is best suited for:

- 2D probe / single-slice fUSI workflows
- 2D step-motor / multi-slice workflows
- QC and preprocessing
- PSC and SCM visualization
- mask editing
- atlas registration
- segmentation
- functional connectivity
- group analysis

Step-motor and group-level FC workflows should still be validated carefully with representative datasets before publication.

---

## Platform and MATLAB Compatibility

Developed and tested mainly on:

- Windows
- MATLAB 2017b
- MATLAB 2023b

The code is written to remain compatible with older MATLAB syntax where possible. Some acquisition-related files use Windows serial-port names such as `COM8`, `COM9`, or `COM14`; these must be adapted for other computers.

Some export workflows may depend on Windows-specific features, Microsoft PowerPoint, or ActiveX.

---

## Recommended Analysis Workflow

1. Start the toolbox:

   ```matlab
   deConfUSIon
   ```

2. Load fUSI data with **Load fUSI Data**.

3. Confirm probe type, dimensions, TR, and total duration.

4. Run **Full QC** before preprocessing.

5. Review QC outputs and raw movie behavior.

6. Apply preprocessing only when justified:
   - frame rejection / interpolation
   - scrubbing
   - imregdemons correction
   - step-motor reconstruction
   - temporal smoothing
   - filtering
   - PCA / ICA denoising
   - despiking

7. After each preprocessing step, check the active dataset dropdown.

8. For a guided workflow, use **Standardized Analysis**:
   - **Option A Fast** ticks only Motor, Imregdemons, Video GUI, Time-Course Viewer, and SCM GUI.
   - **Option B Detailed** restores the longer current workflow with mask, atlas registration, segmentation, and Functional Connectivity.

9. Use the Time-Course Viewer, Video GUI, and SCM GUI to inspect PSC maps and signal dynamics.

10. Use masks, segmentation, and atlas registration only after the dataset passes QC.

11. Run Functional Connectivity and Group Analysis only after individual datasets are validated.

12. Export logs, figures, and analysis outputs for reproducibility.

---

## Main Features

- Load `.mat`, `.nii`, and `.nii.gz` fUSI datasets.
- Support `[Y X T]` 2D single-slice data.
- Support `[Y X Z T]` step-motor / multi-slice / 3D-like data.
- Confirm probe type and TR during loading.
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
- JM atlas color/order support.
- Segmentation workflow.
- ROI, seed, pair, and graph functional connectivity.
- Group-level ROI, map, and FC workflows.
- Export of figures, logs, bundles, and reports.

---

## Core Runtime Files

| File / folder | Purpose | Keep? |
|---|---|---|
| `deConfUSIon.m` | Main user-facing launcher | Yes |
| `run_fusi_studio.m` | Internal runtime launcher and GUI assembly | Yes |
| `fusi_studio_GUI.m` | Main Studio GUI layout | Yes |
| `fusi_studio_callback.m` | Main Studio callbacks | Yes |
| `loadFUSIData.m` | Loads `.mat`, `.nii`, and `.nii.gz` data | Yes |
| `qc_fusi.m` | Quality control | Yes |
| `filtering.m` | Temporal filtering | Yes |
| `motor.m` | Step-motor reconstruction | Yes |
| `pca_denoise.m` | PCA denoising | Yes |
| `ica_denoise.m` | ICA denoising | Yes |
| `scrubbing.m` | Scrubbing / outlier correction | Yes |
| `imregdemons_preprocess.m` | Imregdemons preprocessing | Yes |
| `fUSI_Live_Studio.m` | Time-course and movie viewer | Yes |
| `SCM_gui.m` | Signal-change-map GUI | Yes |
| `play_fusi_video_final.m` | Dynamic overlay/video GUI | Yes |
| `mask.m` | Mask editor | Yes |
| `coreg.m` | Atlas registration launcher | Yes |
| `coreg_3d.m` | 3D atlas registration entry | Yes |
| `coreg_coronal_2d.m` | 2D coronal atlas registration entry | Yes |
| `registration_ccf.m` | Manual 3D atlas registration GUI | Yes |
| `registration_coronal_2d.m` | Manual 2D atlas registration GUI | Yes |
| `Segmentation.m` | Segmentation workflow | Yes |
| `FunctionalConnectivity.m` | Functional connectivity workflow | Yes |
| `GroupAnalysis*.m` | Group analysis modules | Yes |
| `atlas_tools/` | JM atlas color/order files and manual utilities | Yes |
| `docs/` | User manual PDF | Yes |

---

## Files That Should Stay External

Some helper files are intentionally small and should not be merged into large GUI files, because MATLAB callbacks, timers, lazy-loading logic, or multiple modules may call them by name.

### GUI / timer / popup helpers

Keep these external:

```text
deConfUSIon_popup_autofit_apply.m
deConfUSIon_popup_autofit_timer.m
deConfUSIon_popup_polish_now.m
deConfUSIon_force_fullscreen_fig.m
```

### Functional connectivity / step-motor shared helpers

Keep these external:

```text
deConfUSIon_FC_find_stepmotor_txt_names.m
deConfUSIon_FC_read_region_names_file.m
deConfUSIon_FC_stepmotor_read_folder.m
deConfUSIon_find_stepmotor_seg_fc_files.m
deConfUSIon_FC_force_layout.m
deConfUSIon_FC_remember_layout.m
deConfUSIon_FC_make_slice_roi_result.m
```

### Dropdown / metadata compatibility helpers

Keep these external. They make saved preprocessing outputs appear correctly in the dataset dropdown:

```text
deConfUSIon_fix_studio_dataset_names.m
deConfUSIon_write_full_display_metadata.m
deConfUSIon_commit_full_display_name.m
deConfUSIon_best_visible_dataset_name.m
deConfUSIon_display_from_file_context.m
deConfUSIon_display_name_from_sources.m
deConfUSIon_is_bad_display_name.m
```

Some metadata fields still contain legacy names such as `HUMOR_fullDisplayName`. Keep these compatibility fields so older `.mat` outputs continue to load.

---

## Atlas Tools and JM Color/Order Support

Do **not** delete `atlas_tools`.

Expected contents include:

```text
atlas_tools/
  rgb2acr.xlsx
  list_selected_regions.txt
  save_correct_colors.m
  deConfUSIon_reorder_FC_by_list.m
```

Automatic atlas preparation uses:

```text
deConfUSIon_prepare_atlas.m
deConfUSIon_apply_rgb2acr.m
readFileList.m
deConfUSIon_fc_jm_order.m
```

JM atlas preparation changes atlas color/order metadata. It does not change registration geometry. Always visually inspect registration overlays before trusting atlas labels.

---

## Expected Data Formats

### MATLAB `.mat`

Preferred image variable:

```matlab
I
```

Typical dimensions:

```matlab
I = [Y X T]       % 2D single-slice data
I = [Y X Z T]     % step-motor / multi-slice / 3D-style data
```

Optional metadata may include TR, sampling rate, time vector, probe type, baseline windows, masks, stimulation/injection timing, and acquisition parameters.

### NIfTI

`.nii` and `.nii.gz` files are supported. Always check orientation, dimensions, TR, and total duration after loading.

### Step-Motor / Split Data

Use consistent naming for split step-motor files, for example:

```text
slice1_t001.mat
slice2_t001.mat
slice3_t001.mat
```

Always verify number of slices, frames per slice, trimming, baseline frames, reconstructed dimensions, and active dataset selection after reconstruction.

---

## Output and Repository Hygiene

Keep raw data separate from generated outputs. Do not overwrite raw data.

Recommended analysis-output structure:

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

Do not commit animal data, generated analysis outputs, or temporary backup folders to GitHub.

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
*.asv
*.tmp
.DS_Store
Thumbs.db
```

Large atlas resources such as `allen_brain_atlas.mat` may be better handled through Git LFS, release assets, or institutional storage if the repository becomes large.

---

## Backup Folder Policy

During development and cleanup, the repository may contain a `backups/` folder. Keep it until full testing passes with:

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

After testing, zip or move `backups/` outside the repository before committing.

---

## Troubleshooting

### A preprocessing output is saved but not visible in the dropdown

Check:

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
which deConfUSIon_fc_jm_order
```

Also verify:

```text
atlas_tools/rgb2acr.xlsx
atlas_tools/list_selected_regions.txt
```

### Direct `FunctionalConnectivity` call asks for data

Functional Connectivity usually receives data from deConfUSIon Studio. If called directly, select a valid `.mat` dataset when prompted.

---

## Development Notes

Before adding new modules:

1. Keep runtime files in root unless there is a strong reason to move them.
2. Keep shared GUI/helper functions external if they are called by callbacks or multiple modules.
3. Avoid deleting small helper files only because they are small.
4. Add generated outputs to `.gitignore`.
5. Test with both normal 2D and 2D step-motor data.

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
