function atlas = save_correct_colors(atlasFile, rgbFile, outFile)
% save_correct_colors  Add/fix atlas.infoRegions.rgb from JM rgb2acr.xlsx.
%
% Usage:
%   atlas = save_correct_colors('allen_brain_atlas.mat','rgb2acr.xlsx');
%   atlas = save_correct_colors(atlasStruct,'rgb2acr.xlsx','atlas_rgb_fixed.mat');

if nargin < 2 || isempty(rgbFile)
    error('save_correct_colors:MissingRgb','Missing rgb2acr.xlsx file.');
end
if nargin < 3
    outFile = '';
end

if ischar(atlasFile) || isstring(atlasFile)
    atlasPath = char(atlasFile);
    S = load(atlasPath);
    if ~isfield(S,'atlas')
        error('save_correct_colors:NoAtlas','MAT file does not contain variable atlas: %s', atlasPath);
    end
    atlas = S.atlas;
    if isempty(outFile)
        [p,n,e] = fileparts(atlasPath);
        outFile = fullfile(p,[n '_rgb_fixed' e]);
    end
else
    atlas = atlasFile;
end

atlas = deConfUSIon_apply_rgb2acr(atlas, rgbFile);

if ~isempty(outFile)
    save(outFile,'atlas','-v7.3');
    fprintf('Saved corrected atlas: %s\n', outFile);
end
end
