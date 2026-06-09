function fullName = HUMOR_commit_full_display_name(matFile, dataStruct, fallbackName)
% Append exact full display name into top-level MAT metadata.

if nargin < 1, matFile = ''; end
if nargin < 2, dataStruct = []; end
if nargin < 3 || isempty(fallbackName), fallbackName = 'dataset'; end
try, matFile = char(matFile); catch, matFile = ''; end

fullName = HUMOR_best_visible_dataset_name(fallbackName, dataStruct, matFile);

if ~isempty(matFile) && exist(matFile,'file') == 2
    try
        HUMOR_fullDisplayName = fullName; %#ok<NASGU>
        displayNameFull = fullName; %#ok<NASGU>
        preprocDisplayName = fullName; %#ok<NASGU>
        datasetSortTime = now; %#ok<NASGU>
        save(matFile,'HUMOR_fullDisplayName','displayNameFull','preprocDisplayName','datasetSortTime','-append');
    catch
    end
end
end
