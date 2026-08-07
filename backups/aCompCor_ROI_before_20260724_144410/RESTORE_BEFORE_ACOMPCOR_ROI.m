root = 'D:\Github\deConfUSIon';
bak = 'D:\Github\deConfUSIon\backups\aCompCor_ROI_before_20260724_144410';
files = {'deConfUSIon_drift_roi_picker.m','deConfUSIon_drift_dialog.m'};
for k=1:numel(files), copyfile(fullfile(bak,files{k}),fullfile(root,files{k}),'f'); end
runtimeDir=fullfile(tempdir,'deConfUSIon_fUSI_Studio_runtime'); if exist(runtimeDir,'dir')==7, try, rmdir(runtimeDir,'s'); catch, end, end
clear functions; rehash toolboxcache; fprintf('Restore complete.
');
