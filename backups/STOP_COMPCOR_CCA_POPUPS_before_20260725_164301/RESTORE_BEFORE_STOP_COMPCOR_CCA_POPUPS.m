root = 'D:\Github\deConfUSIon';
bak = 'D:\Github\deConfUSIon\backups\STOP_COMPCOR_CCA_POPUPS_before_20260725_164301';
copyfile(fullfile(bak,'fusi_studio_GUI.m'),fullfile(root,'fusi_studio_GUI.m'),'f');
if exist(fullfile(bak,'deConfUSIon_adv_drift_opts.m'),'file')==2
    copyfile(fullfile(bak,'deConfUSIon_adv_drift_opts.m'),fullfile(root,'deConfUSIon_adv_drift_opts.m'),'f');
else
    hf = fullfile(root,'deConfUSIon_adv_drift_opts.m'); if exist(hf,'file')==2, delete(hf); end
end
runtimeDir = fullfile(tempdir,'deConfUSIon_fUSI_Studio_runtime');
if exist(runtimeDir,'dir')==7, try, rmdir(runtimeDir,'s'); catch, end, end
clear functions; rehash toolboxcache;
fprintf('Restore complete.\n');
