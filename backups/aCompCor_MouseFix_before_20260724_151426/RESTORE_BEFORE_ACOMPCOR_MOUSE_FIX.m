root = 'D:\Github\deConfUSIon';
bak = 'D:\Github\deConfUSIon\backups\aCompCor_MouseFix_before_20260724_151426';
copyfile(fullfile(bak,'deConfUSIon_drift_roi_picker.m'),fullfile(root,'deConfUSIon_drift_roi_picker.m'),'f');
runtimeDir = fullfile(tempdir,'deConfUSIon_fUSI_Studio_runtime');
if exist(runtimeDir,'dir')==7, try, rmdir(runtimeDir,'s'); catch, end, end
clear functions; rehash toolboxcache;
fprintf('aCompCor mouse-fix restore complete.\n');
