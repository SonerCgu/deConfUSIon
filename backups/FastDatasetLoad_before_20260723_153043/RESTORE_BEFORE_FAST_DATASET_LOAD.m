root = 'D:\Github\deConfUSIon';
backupDir = 'D:\Github\deConfUSIon\backups\FastDatasetLoad_before_20260723_153043';
files = {'deConfUSIon_add_preproc_lazy_datasets.m','deConfUSIon_fix_studio_dataset_names.m'};
for k = 1:numel(files)
    copyfile(fullfile(backupDir,files{k}),fullfile(root,files{k}),'f');
    fprintf('Restored: %s\n',files{k});
end
runtimeDir = fullfile(tempdir,'deConfUSIon_fUSI_Studio_runtime');
if exist(runtimeDir,'dir') == 7,try, rmdir(runtimeDir,'s'); catch, end, end
clear functions; rehash toolboxcache;
fprintf('Restore complete.\n');
