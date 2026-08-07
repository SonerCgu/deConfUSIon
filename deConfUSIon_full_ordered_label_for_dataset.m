function label = deConfUSIon_full_ordered_label_for_dataset(nameIn, dataStruct, matFile)
% Return a stable ordered processing-chain label without truncation.
if nargin < 1 || isempty(nameIn), nameIn = 'dataset'; end
if nargin < 2, dataStruct = []; end
if nargin < 3, matFile = ''; end
try
    label = deConfUSIon_display_name_from_sources(nameIn,dataStruct,matFile);
catch
    try, label = char(nameIn); catch, label = 'dataset'; end
    label = regexprep(label,'\.mat$','','ignorecase');
    label = strrep(label,'...','_');
    label = regexprep(label,'_+','_');
    label = regexprep(label,'^_+|_+$','');
end
if isempty(label), label = 'dataset'; end
end
