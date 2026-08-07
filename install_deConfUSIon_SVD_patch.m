function install_deConfUSIon_SVD_patch(repoRoot)
% Install the SVD / Clutter Filtering patch into deConfUSIon.
%
% Example:
%   addpath('C:\Users\NAME\Downloads\deConfUSIon_SVD_patch');
%   install_deConfUSIon_SVD_patch('D:\Github\deConfUSIon');

patchRoot = fileparts(mfilename('fullpath'));
src = fullfile(patchRoot,'patched_files');

if nargin < 1 || isempty(repoRoot)
    if exist(fullfile(pwd,'fusi_studio_GUI.m'),'file') == 2
        repoRoot = pwd;
    else
        repoRoot = uigetdir(pwd,'Select the deConfUSIon repository folder');
        if isequal(repoRoot,0)
            fprintf('SVD patch cancelled.\n');
            return;
        end
    end
end
repoRoot = char(repoRoot);

requiredTarget = fullfile(repoRoot,'fusi_studio_GUI.m');
if exist(requiredTarget,'file') ~= 2
    error('Selected folder does not contain fusi_studio_GUI.m: %s',repoRoot);
end

requiredPatch = { ...
    'fusi_studio_GUI.m', ...
    'deConfUSIon_svd_clutter.m', ...
    'deConfUSIon_svd_clutter_gui.m', ...
    'svd_clutter_filter_small.m'};
for i = 1:numel(requiredPatch)
    if exist(fullfile(src,requiredPatch{i}),'file') ~= 2
        error('Patch file is missing: %s',requiredPatch{i});
    end
end

stamp = datestr(now,'yyyymmdd_HHMMSS');
backupDir = fullfile(repoRoot,'backups',['SVD_patch_before_' stamp]);
if exist(backupDir,'dir') ~= 7, mkdir(backupDir); end

filesToBackup = requiredPatch;
for i = 1:numel(filesToBackup)
    oldFile = fullfile(repoRoot,filesToBackup{i});
    if exist(oldFile,'file') == 2
        copyfile(oldFile,fullfile(backupDir,filesToBackup{i}));
    end
end

for i = 1:numel(requiredPatch)
    copyfile(fullfile(src,requiredPatch{i}),fullfile(repoRoot,requiredPatch{i}),'f');
end

clear functions;
rehash;

fprintf('\nSVD / Clutter Filtering patch installed.\n');
fprintf('Repository: %s\n',repoRoot);
fprintf('Backup:     %s\n',backupDir);
fprintf('Updated block 8: SVD / Clutter Filtering\n');
fprintf('Launch with: run_fusi_studio\n\n');
end
