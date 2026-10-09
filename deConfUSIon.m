function deConfUSIon()
% deConfUSIon - main launcher for deConfUSIon / fUSI Studio.
% This directly calls run_fusi_studio because the split GUI runtime still
% depends on fusi_studio_GUI.m + fusi_studio_callback.m assembly.

deConfUSIon_setup();
root = fileparts(mfilename('fullpath'));
if isempty(root), root = pwd; end
addpath(root,'-begin');

atlasTools = fullfile(root,'atlas_tools');
if exist(atlasTools,'dir') == 7
    addpath(atlasTools,'-begin');
end

acqDir = fullfile(root,'acquisition');
if exist(acqDir,'dir') == 7
    addpath(acqDir,'-begin');
end

run_fusi_studio;
end
