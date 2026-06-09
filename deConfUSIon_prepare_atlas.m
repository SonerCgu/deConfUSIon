function atlas = deConfUSIon_prepare_atlas(atlas, atlasPath)
% deConfUSIon_prepare_atlas  Automatic JM atlas color/order preparation.
% This does not change atlas geometry. It adds corrected rgb fields and stores
% selected/reordered region indices in atlas.deConfUSIon.

if nargin < 2, atlasPath = ''; end
try
    here = fileparts(mfilename('fullpath'));
    if isempty(here), here = pwd; end

    [listFile, rgbFile] = localFindJmAtlasFiles(here);

    if exist(rgbFile,'file') == 2
        atlas = deConfUSIon_apply_rgb2acr(atlas, rgbFile);
    end

    if isstruct(atlas) && isfield(atlas,'infoRegions') && exist(listFile,'file') == 2
        D = readFileList(listFile, atlas.infoRegions);
        selected_regions = [];
        try
            selected_regions = cat(2,D.parts{:});
        catch
            selected_regions = [];
        end
        selected_regions = unique(selected_regions,'stable');
        atlas.deConfUSIon.selected_regions = selected_regions;
        atlas.deConfUSIon.selected_region_list_file = listFile;
        atlas.deConfUSIon.rgb2acr_file = rgbFile;
        atlas.deConfUSIon.selected_region_groups = D;
        if isfield(atlas.infoRegions,'acr')
            try, atlas.deConfUSIon.acr_reordered = atlas.infoRegions.acr(selected_regions); catch, end
        end
        if ~isempty(atlasPath)
            try, atlas.deConfUSIon.source_atlas_path = atlasPath; catch, end
        end
    end
catch ME
    warning('deConfUSIon:PrepareAtlas','JM atlas preparation skipped: %s', ME.message);
end
end

function [listFile, rgbFile] = localFindJmAtlasFiles(here)
% Prefer root if present, otherwise atlas_tools.
listFile = fullfile(here,'list_selected_regions.txt');
rgbFile  = fullfile(here,'rgb2acr.xlsx');

atlasDir = fullfile(here,'atlas_tools');
if exist(listFile,'file') ~= 2
    cand = fullfile(atlasDir,'list_selected_regions.txt');
    if exist(cand,'file') == 2, listFile = cand; end
end
if exist(rgbFile,'file') ~= 2
    cand = fullfile(atlasDir,'rgb2acr.xlsx');
    if exist(cand,'file') == 2, rgbFile = cand; end
end
end
