function label = HUMOR_ordered_chain_label(nameIn, dataStruct, matFile)
% Compatibility wrapper for the Studio display-name builder.
if nargin < 1 || isempty(nameIn), nameIn = 'dataset'; end
if nargin < 2, dataStruct = []; end
if nargin < 3, matFile = ''; end
try
    label = HUMOR_display_name_from_sources(nameIn, dataStruct, matFile);
catch
    try, label = char(nameIn); catch, label = 'dataset'; end
    label = strrep(label,'...','_');
    label = regexprep(label,'\.mat$','','ignorecase');
    label = regexprep(label,'_+','_');
    label = regexprep(label,'^_+|_+$','');
    if isempty(label), label = 'dataset'; end
end
end
