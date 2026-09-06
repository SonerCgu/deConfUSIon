function restore_deConfUSIon_pre_theme(toolboxRoot)
% RESTORE_DECONFUSION_PRE_THEME
% Restore the three GUI files from a _backup_modern_theme_* folder.

if nargin < 1 || isempty(toolboxRoot)
    w = which('deConfUSIon');
    if ~isempty(w)
        toolboxRoot = fileparts(w);
    else
        toolboxRoot = uigetdir(pwd,'Select the deConfUSIon toolbox folder');
        if isequal(toolboxRoot,0), return; end
    end
end

D = dir(fullfile(toolboxRoot,'_backup_modern_theme_*'));
D = D([D.isdir]);
if isempty(D)
    error('No _backup_modern_theme_* folder found in %s',toolboxRoot);
end
[~,idx] = max([D.datenum]);
backupDir = fullfile(toolboxRoot,D(idx).name);
files = {'fusi_studio_GUI.m','fusi_studio_callback.m','studio_load_options_dark_dialog.m'};

for k = 1:numel(files)
    src = fullfile(backupDir,files{k});
    dst = fullfile(toolboxRoot,files{k});
    if exist(src,'file') ~= 2
        error('Backup is incomplete: %s is missing.',src);
    end
    copyfile(src,dst,'f');
    fprintf('restored %s\n',files{k});
end

try
    runtimeFile = fullfile(tempdir,'deConfUSIon_fUSI_Studio_runtime','fusi_studio_runtime.m');
    if exist(runtimeFile,'file') == 2, delete(runtimeFile); end
catch
end
try, clear('fusi_studio_runtime'); catch, end
rehash;
fprintf('\nRestored from: %s\n',backupDir);
fprintf('Launch normally with: deConfUSIon\n');
end
