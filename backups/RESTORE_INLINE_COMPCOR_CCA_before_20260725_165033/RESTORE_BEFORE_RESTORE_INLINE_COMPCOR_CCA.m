root = 'D:\Github\deConfUSIon';
bak = 'D:\Github\deConfUSIon\backups\RESTORE_INLINE_COMPCOR_CCA_before_20260725_165033';
copyfile(fullfile(bak,'deConfUSIon_drift_dialog.m'),fullfile(root,'deConfUSIon_drift_dialog.m'),'f');
runtimeDir = fullfile(tempdir,'deConfUSIon_fUSI_Studio_runtime');
if exist(runtimeDir,'dir')==7, try, rmdir(runtimeDir,'s'); catch, end, end
clear functions; rehash toolboxcache;
fprintf('Restore complete.\n');
