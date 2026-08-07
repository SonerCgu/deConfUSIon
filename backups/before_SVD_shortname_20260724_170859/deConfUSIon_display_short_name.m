function label = deConfUSIon_display_short_name(nameIn, dataStruct, matFile)
% Central user-facing name used by Studio dropdowns.
% Short means cleaned/canonical; the chain is not hard-truncated.
if nargin < 1 || isempty(nameIn), nameIn = 'dataset'; end
if nargin < 2, dataStruct = []; end
if nargin < 3, matFile = ''; end
try
    label = deConfUSIon_display_name_from_sources(nameIn,dataStruct,matFile);
catch
    try, label = char(nameIn); catch, label = 'dataset'; end
end
label = strrep(label,'...','_');
label = regexprep(label,'\.mat$','','ignorecase');
label = regexprep(label,'_+','_');
label = regexprep(label,'^_+|_+$','');
if isempty(label), label = 'dataset'; end
end
