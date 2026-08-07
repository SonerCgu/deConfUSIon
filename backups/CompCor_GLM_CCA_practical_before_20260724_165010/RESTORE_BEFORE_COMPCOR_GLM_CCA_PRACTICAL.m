root = 'D:\Github\deConfUSIon';
bak = 'D:\Github\deConfUSIon\backups\CompCor_GLM_CCA_practical_before_20260724_165010';
files = {'driftcompensation.m','fusi_studio_GUI.m','deConfUSIon_adv_drift_opts.m','deConfUSIon_build_compcor_regressors.m','deConfUSIon_build_artifact_regressors.m','deConfUSIon_spatial_cca_simple.m'};
existed = [1 1 0 0 0 0 ];
for k=1:numel(files)
    src=fullfile(bak,files{k}); dst=fullfile(root,files{k});
    if existed(k) && exist(src,'file')==2
        copyfile(src,dst,'f');
    elseif ~existed(k) && exist(dst,'file')==2
        delete(dst);
    end
end
runtimeDir=fullfile(tempdir,'deConfUSIon_fUSI_Studio_runtime');
if exist(runtimeDir,'dir')==7, try, rmdir(runtimeDir,'s'); catch, end, end
clear functions; rehash toolboxcache;
fprintf('Restore complete.\n');
