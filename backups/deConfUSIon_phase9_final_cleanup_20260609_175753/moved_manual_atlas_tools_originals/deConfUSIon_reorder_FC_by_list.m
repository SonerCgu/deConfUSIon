function [FC_reordered, selected_regions, acr_reordered, D] = deConfUSIon_reorder_FC_by_list(FC, atlas, listFile)
% deConfUSIon_reorder_FC_by_list  JM example wrapper for FC matrices.

if nargin < 3 || isempty(listFile)
    here = fileparts(mfilename('fullpath'));
    listFile = fullfile(here,'list_selected_regions.txt');
end
D = readFileList(listFile, atlas.infoRegions);
selected_regions = [];
try
    selected_regions = cat(2,D.parts{:});
catch
    selected_regions = [];
end
selected_regions = unique(selected_regions,'stable');
selected_regions = selected_regions(selected_regions >= 1 & selected_regions <= size(FC,1) & selected_regions <= size(FC,2));
FC_reordered = FC(selected_regions, selected_regions);
acr_reordered = {};
try, acr_reordered = atlas.infoRegions.acr(selected_regions); catch, end
end
