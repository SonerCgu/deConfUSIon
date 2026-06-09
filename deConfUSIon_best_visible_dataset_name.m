function nameOut = deConfUSIon_best_visible_dataset_name(seedName, dataStruct, matFile)
% Robust visible dataset name for Studio dropdowns.
if nargin < 1 || isempty(seedName), seedName = 'dataset'; end
if nargin < 2, dataStruct = []; end
if nargin < 3, matFile = ''; end
try, seedName = char(seedName); catch, seedName = 'dataset'; end
try, matFile = char(matFile); catch, matFile = ''; end
candidates = {};
if isstruct(dataStruct)
    flds = {'HUMOR_fullDisplayName','displayNameFull','preprocDisplayName','fullDisplayName','sourceDisplayName','sourceDatasetName'};
    for i = 1:numel(flds)
        if isfield(dataStruct,flds{i}) && ~isempty(dataStruct.(flds{i}))
            try, candidates{end+1} = char(dataStruct.(flds{i})); catch, end %#ok<AGROW>
        end
    end
end
candidates{end+1} = seedName;
if ~isempty(matFile)
    [~,stem] = fileparts(matFile);
    candidates{end+1} = stem;
end
nameOut = '';
for i = 1:numel(candidates)
    s = localClean(candidates{i});
    if ~deConfUSIon_is_bad_display_name(s)
        nameOut = s;
        break;
    end
end
if isempty(nameOut)
    if ~isempty(matFile)
        nameOut = deConfUSIon_display_from_file_context(matFile, seedName);
    else
        nameOut = localClean(seedName);
    end
end
nameOut = localClean(nameOut);
if isempty(nameOut), nameOut = 'dataset'; end
end
function s = localClean(s)
try, s = char(s); catch, s = 'dataset'; end
s = regexprep(s,'\.mat$','','ignorecase');
s = strrep(s,'...','_');
s = regexprep(s,'_+','_');
s = regexprep(s,'^_+|_+$','');
end
