function fullName = deConfUSIon_commit_full_display_name(matFile, dataStruct, fallbackName)
% Append stable full and dropdown metadata after the MAT file exists.
if nargin < 1, matFile = ''; end
if nargin < 2, dataStruct = []; end
if nargin < 3 || isempty(fallbackName), fallbackName = 'dataset'; end
try, matFile = char(matFile); catch, matFile = ''; end
try
    fullName = deConfUSIon_best_visible_dataset_name(fallbackName,dataStruct,matFile);
catch
    try, fullName = char(fallbackName); catch, fullName = 'dataset'; end
end
if ~isempty(matFile) && exist(matFile,'file') == 2
    try
        HUMOR_fullDisplayName = fullName; %#ok<NASGU>
        displayNameFull = fullName; %#ok<NASGU>
        preprocDisplayName = fullName; %#ok<NASGU>
        displayNameShort = deConfUSIon_display_short_name(fullName,dataStruct,matFile); %#ok<NASGU>
        datasetSortTime = now; %#ok<NASGU>
        save(matFile,'HUMOR_fullDisplayName','displayNameFull', ...
            'displayNameShort','preprocDisplayName', ...
            'datasetSortTime','-append');
    catch
    end
end
end
