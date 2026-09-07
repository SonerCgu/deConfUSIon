function deConfUSIon_write_full_display_metadata(matFile, dataStruct)
% Append stable display metadata after a preprocessing MAT is saved.
if nargin < 1 || isempty(matFile), return; end
if nargin < 2, dataStruct = []; end
try, matFile = char(matFile); catch, return; end
if exist(matFile,'file') ~= 2, return; end
nameIn = '';
try
    if isstruct(dataStruct) && isfield(dataStruct,'displayNameFull') && ~isempty(dataStruct.displayNameFull)
        nameIn = dataStruct.displayNameFull;
    elseif isstruct(dataStruct) && isfield(dataStruct,'preprocDisplayName') && ~isempty(dataStruct.preprocDisplayName)
        nameIn = dataStruct.preprocDisplayName;
    elseif isstruct(dataStruct) && isfield(dataStruct,'HUMOR_fullDisplayName') && ~isempty(dataStruct.HUMOR_fullDisplayName)
        nameIn = dataStruct.HUMOR_fullDisplayName;
    end
catch
end
if isempty(nameIn), [~,nameIn] = fileparts(matFile); end
try
    displayNameFull = deConfUSIon_best_visible_dataset_name(nameIn,dataStruct,matFile); %#ok<NASGU>
catch
    displayNameFull = nameIn; %#ok<NASGU>
end
preprocDisplayName = displayNameFull; %#ok<NASGU>
HUMOR_fullDisplayName = displayNameFull; %#ok<NASGU>
displayNameShort = deConfUSIon_display_short_name(displayNameFull,dataStruct,matFile); %#ok<NASGU>
datasetSortTime = now; %#ok<NASGU>
try
    save(matFile,'displayNameFull','displayNameShort', ...
        'preprocDisplayName','HUMOR_fullDisplayName', ...
        'datasetSortTime','-append');
catch ME
    warning('deConfUSIon:MetadataSave','Could not append dataset metadata to %s: %s',matFile,ME.message);
end
end
