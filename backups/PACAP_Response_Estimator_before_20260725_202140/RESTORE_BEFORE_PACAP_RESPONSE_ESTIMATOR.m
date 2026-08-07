root = 'D:\Github\deConfUSIon';
bak = 'D:\Github\deConfUSIon\backups\PACAP_Response_Estimator_before_20260725_202140';
files = {'driftcompensation.m','deConfUSIon_driftcompensation_core.m','deConfUSIon_pacap_response_estimator.m','deConfUSIon_drift_dialog.m'};
existed = [1 0 0 1 ];
for k=1:numel(files)
    src=fullfile(bak,files{k}); dst=fullfile(root,files{k});
    if existed(k) && exist(src,'file')==2
        copyfile(src,dst,'f');
    elseif ~existed(k) && exist(dst,'file')==2
        delete(dst);
    end
end
runtimeDir = fullfile(tempdir,'deConfUSIon_fUSI_Studio_runtime');
if exist(runtimeDir,'dir')==7, try, rmdir(runtimeDir,'s'); catch, end, end
clear functions; rehash toolboxcache;
fprintf('Restore complete.\n');
