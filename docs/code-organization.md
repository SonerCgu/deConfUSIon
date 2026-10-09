# Source organization and recovery

156 implementation helpers were moved from the root into nine `lib` modules.
Their function names and public calling signatures are preserved. No analysis
data or atlas assets were moved. The root retains 68 executable MATLAB source
files plus `Contents.m`, including the public GUIs and processing entry points.

| Folder | Responsibility |
|---|---|
| Root | Supported launchers, GUIs, processing APIs and shared numerical contracts |
| `lib/atlas` | Registration, transform geometry, reference underlays and region metadata |
| `lib/volume` | Volume/stack rendering, cameras, playback and export |
| `lib/roi` | SCM automatic search, masks, candidate selection and ROI exports |
| `lib/connectivity` | FC layout, region names, motor/slice results and ordering |
| `lib/group` | Group ROI summaries, condition assignment and plateau calculations |
| `lib/display` | Image contrast, region colours, labels, rulers and GUI support |
| `lib/io` | Analysis output paths, collision protection and saving |
| `lib/preprocessing` | Drift, SVD and artifact-regressor support |
| `lib/metadata` | Processing names, modality and provenance helpers |
| `atlas_tools` | Atlas assets and external table readers |
| `acquisition` | Scan/stimulation configuration and sensory experiment tools |
| `tests` | MATLAB regression tests |
| `docs` | User guides and generated source/dependency inventory |
| `maintenance` | Inventory generation and reversible organization tools |
| `validation` | Local validation outputs; excluded from Git |

MATLAB makes local functions in an umbrella file private to that file. Combining
all helpers would break existing callers or require a new dispatch interface.
Modules and `Contents.m` indexes group the code for review while retaining the
existing APIs. Large GUI files still need a later separation of calculation,
state and layout; this reorganization does not pretend to perform that rewrite.

## Startup

Close and reopen toolbox windows after updating the source. Already open MATLAB
figures keep their old callback workspaces.

```matlab
cd('D:/Github/deConfUSIon')
deConfUSIon_setup
deConfUSIon
```

Public analysis entry points initialize the module paths automatically. When
calling a `lib` helper directly in a fresh MATLAB session, run `deConfUSIon_setup`
first. Do not use `addpath(genpath(pwd))`: it can activate old backup functions.
Setup removes known backup and validation paths under this checkout.

The split Studio source files remain at the root. Their nested callbacks must
be assembled into one temporary runtime function by `run_fusi_studio`; this is
why those two files have not been merged into unrelated helpers.

## Source map

[Code map](code_map.md) links each active MATLAB source file to its statically
detected callers and dependencies. [Inventory](code_inventory.csv) includes
line counts and SHA256 hashes; [dependency edges](code_dependencies.csv) are
suitable for filtering in Excel. Dynamic calls and external executables need
additional review; a static reference is not proof of execution.

Regenerate after source changes:

```powershell
python maintenance/build_code_map.py
```

## Backup and reversing the organization

Before moving files, all root MATLAB sources and tests were copied to
`_backup_code_organization_20261004_232839_843`. Each moved file was SHA256-checked
immediately after its move. `maintenance/script_moves.csv` records the mapping
and the original hashes. Backups are excluded from Git and the active MATLAB path.

Close toolbox windows, then run from the repository in PowerShell:

```powershell
./maintenance/restore_script_organization.ps1
```

The default moves current helper implementations back to their original root
names, retaining subsequent functional fixes. It first preserves the current
modules in another `_backup_before_restore_<timestamp>` folder.

To restore the exact root/test snapshot as well, use `-Snapshot`. That also
reverts fixes made after the snapshot; the newer versions remain in the recovery
backup. Do not run either restore during a MATLAB export or calculation.

```powershell
./maintenance/restore_script_organization.ps1 -Snapshot
```

## Tests

```matlab
run_deConfUSIon_tests('tests/testFunctionalConnectivitySliceRange.m')
run_deConfUSIon_tests('tests/testAtlasPaletteSavesAndContrast.m')
```

`run_deConfUSIon_tests` initializes the module paths and treats failed or
incomplete selected tests as a failure. Some full-suite GUI tests involve modal
windows and some acquisition tests use mocks; passing them is not evidence of
hardware validation or an anatomically correct registration for every animal.
