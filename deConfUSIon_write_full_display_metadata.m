function deConfUSIon_write_full_display_metadata(matFile, dataStruct)
% Append full display metadata into a saved MAT file.
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
if isempty(nameIn)
    [~,nameIn] = fileparts(matFile);
end
displayNameFull = deConfUSIon_best_visible_dataset_name(nameIn, dataStruct, matFile); %#ok<NASGU>
preprocDisplayName = displayNameFull; %#ok<NASGU>
HUMOR_fullDisplayName = displayNameFull; %#ok<NASGU>
datasetSortTime = now; %#ok<NASGU>
try
    save(matFile,'displayNameFull','preprocDisplayName','HUMOR_fullDisplayName','datasetSortTime','-append');
catch
end
end
