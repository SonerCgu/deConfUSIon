function deConfUSIon()
root = fileparts(mfilename('fullpath'));
if isempty(root), root = pwd; end
addpath(root,'-begin');
atlasTools = fullfile(root,'atlas_tools');
if exist(atlasTools,'dir') == 7, addpath(atlasTools,'-begin'); end
run_deConfUSIon;
end
