function install_deConfUSIon_modern_theme(toolboxRoot)
% INSTALL_DECONFUSION_MODERN_THEME
% Visual-only theme installer for deConfUSIon.
% It backs up and replaces ONLY:
%   fusi_studio_GUI.m
%   fusi_studio_callback.m
%   studio_load_options_dark_dialog.m
% and installs the theme_icons folder used by the GUI.
%
% No analysis functions or callback mappings are changed.

if nargin < 1 || isempty(toolboxRoot)
    w = which('deConfUSIon');
    if ~isempty(w)
        toolboxRoot = fileparts(w);
    else
        toolboxRoot = uigetdir(pwd,'Select the deConfUSIon toolbox folder');
        if isequal(toolboxRoot,0), return; end
    end
end

packRoot = fileparts(mfilename('fullpath'));
files = {'fusi_studio_GUI.m','fusi_studio_callback.m','studio_load_options_dark_dialog.m'};
iconFolderName = 'theme_icons';

for k = 1:numel(files)
    if exist(fullfile(packRoot,files{k}),'file') ~= 2
        error('Theme pack is incomplete: missing %s',files{k});
    end
    if exist(fullfile(toolboxRoot,files{k}),'file') ~= 2
        error('Target does not look like the deConfUSIon root. Missing %s',files{k});
    end
end

if exist(fullfile(packRoot,iconFolderName),'dir') ~= 7
    error('Theme pack is incomplete: missing %s folder',iconFolderName);
end

stamp = datestr(now,'yyyymmdd_HHMMSS');
backupDir = fullfile(toolboxRoot,['_backup_modern_theme_' stamp]);
mkdir(backupDir);

fprintf('\nInstalling deConfUSIon modern theme v6\n');
fprintf('Toolbox: %s\n',toolboxRoot);
fprintf('Backup : %s\n\n',backupDir);

for k = 1:numel(files)
    src = fullfile(packRoot,files{k});
    dst = fullfile(toolboxRoot,files{k});
    copyfile(dst,fullfile(backupDir,files{k}));
    copyfile(src,dst,'f');
    fprintf('  updated %s\n',files{k});
end

try
    copyfile(fullfile(packRoot,iconFolderName), fullfile(toolboxRoot,iconFolderName), 'f');
    fprintf('  installed %s/\n',iconFolderName);
catch ME
    warning('Could not copy theme icon folder: %s', ME.message);
end

% Force the split runtime to be rebuilt on next launch.
try
    runtimeFile = fullfile(tempdir,'deConfUSIon_fUSI_Studio_runtime','fusi_studio_runtime.m');
    if exist(runtimeFile,'file') == 2, delete(runtimeFile); end
catch
end

try, clear('fusi_studio_runtime'); catch, end
rehash;

fprintf('\nDone. Your previous files are in:\n%s\n',backupDir);
fprintf('Launch normally with: deConfUSIon\n\n');
end
