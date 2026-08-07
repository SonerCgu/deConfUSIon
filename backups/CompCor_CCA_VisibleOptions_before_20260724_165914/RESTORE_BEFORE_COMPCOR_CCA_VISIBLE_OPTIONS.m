root = 'D:\Github\deConfUSIon';
bak = 'D:\Github\deConfUSIon\backups\CompCor_CCA_VisibleOptions_before_20260724_165914';
copyfile(fullfile(bak,'deConfUSIon_drift_dialog.m'),fullfile(root,'deConfUSIon_drift_dialog.m'),'f');
hf = fullfile(root,'deConfUSIon_adv_drift_opts.m');
if exist(hf,'file')==2, delete(hf); end
runtimeDir = fullfile(tempdir,'deConfUSIon_fUSI_Studio_runtime');
if exist(runtimeDir,'dir')==7, try, rmdir(runtimeDir,'s'); catch, end, end
clear functions; rehash toolboxcache;
fprintf('Restore complete.\n');
