root = 'D:\Github\deConfUSIon';
bak = 'D:\Github\deConfUSIon\backups\PACAP_STRICT_DETREND_before_20260725_213732';
copyfile(fullfile(bak,'deConfUSIon_pacap_response_estimator.m'),fullfile(root,'deConfUSIon_pacap_response_estimator.m'),'f');
if exist(fullfile(bak,'deConfUSIon_drift_dialog.m'),'file')==2
    copyfile(fullfile(bak,'deConfUSIon_drift_dialog.m'),fullfile(root,'deConfUSIon_drift_dialog.m'),'f');
end
runtimeDir = fullfile(tempdir,'deConfUSIon_fUSI_Studio_runtime');
if exist(runtimeDir,'dir')==7, try, rmdir(runtimeDir,'s'); catch, end, end
clear functions; rehash toolboxcache;
fprintf('Restore complete.\n');
