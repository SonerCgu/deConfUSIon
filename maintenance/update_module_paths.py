"""One-time, idempotent migration of module paths; no numerical code changes."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENTRIES = '''deConfUSIon run_fusi_studio fUSI_Live_Studio SCM_gui SCM_static_gui
play_fusi_video_final mask Segmentation FunctionalConnectivity GroupAnalysis
GroupAnalysis_Common GroupAnalysis_FC GroupAnalysis_Map AutomaticSCM AtlasRegistration
DataIO coreg coreg_3d coreg_coronal_2d fusiVolumeGUI fusiAtlasVolumeGUI openNiftiSCM
viewFMRINifti loadFUSIData deConfUSIon_ui'''.split()
ENTRIES += '''ClutterFilter computePSC deConfUSIon_signal deConfUSIon_utils despike
Drift DriftCompensation filtering frameRateQC ica_denoise imregdemons_preprocess
interpolate3D interpolateRejectedVolumes mapscan Motion motor pca_denoise qc_fusi
scrubbing standardizedAnalysis temporalsmoothing showScmVideoSetupDialog
studio_load_options_dark_dialog studio_resolve_paths tryReadSCMroiExportTxt'''.split()

def write(path, text):
    with path.open('w', encoding='utf-8', newline='') as stream:
        stream.write(text)

for name in ENTRIES:
    path = ROOT / (name + '.m')
    text = path.read_text(encoding='utf-8-sig')
    if 'deConfUSIon_setup();' in text:
        continue
    lines = text.splitlines(keepends=True)
    index = next(i for i, line in enumerate(lines) if line.lstrip().startswith('function '))
    while lines[index].rstrip().endswith('...'):
        index += 1
    index += 1
    while index < len(lines) and (not lines[index].strip() or lines[index].lstrip().startswith('%')):
        index += 1
    lines.insert(index, 'deConfUSIon_setup();\n')
    write(path, ''.join(lines))

for path in (ROOT / 'lib').rglob('*.m'):
    text = path.read_text(encoding='utf-8-sig')
    changed = text.replace("fileparts(mfilename('fullpath'))", 'deConfUSIon_root()')
    if changed != text:
        write(path, changed)

for path in (ROOT / 'tests').glob('test*.m'):
    text = path.read_text(encoding='utf-8-sig')
    # Existing test fixtures install the toolbox root before this call.
    target = "t.applyFixture(matlab.unittest.fixtures.PathFixture(fileparts(fileparts(mfilename('fullpath')))));"
    if target in text and 'deConfUSIon_setup();' not in text:
        write(path, text.replace(target, target + '\ndeConfUSIon_setup();', 1))
print('Module paths installed in entry points, resource lookups and test fixtures.')
