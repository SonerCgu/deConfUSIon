function HUMOR_write_full_display_metadata(matFile, dataStruct)
% Append full non-abbreviated display metadata into a saved MAT.

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
    end
catch
end
if isempty(nameIn)
    [~,nameIn] = fileparts(matFile);
end

displayNameFull = HUMOR_full_ordered_label_for_dataset(nameIn, dataStruct, matFile); %#ok<NASGU>
preprocDisplayName = displayNameFull; %#ok<NASGU>
datasetSortTime = now; %#ok<NASGU>

try
    save(matFile,'displayNameFull','preprocDisplayName','datasetSortTime','-append');
catch
end
end
