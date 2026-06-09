function out = deConfUSIon_make_loaded_display_name(datasetName, sourcePath, sourceFile)
% Visible RAW label for Studio dropdown.
% Preferred: animal_scanX_raw, e.g. 1005_scan3_raw.

if nargin < 1 || isempty(datasetName), datasetName = 'dataset'; end
if nargin < 2, sourcePath = ''; end
if nargin < 3, sourceFile = ''; end

try, datasetName = char(datasetName); catch, datasetName = 'dataset'; end
try, sourcePath  = char(sourcePath);  catch, sourcePath = ''; end
try, sourceFile  = char(sourceFile);  catch, sourceFile = ''; end

combo = [datasetName '_' sourceFile '_' sourcePath];

try
    out = deConfUSIon_display_name_from_sources(combo, [], '');
catch
    out = 'dataset_raw';
end

out = regexprep(out,'_(?:19|20)\d{6}_\d{6}$','');
out = regexprep(out,'_+','_');
out = regexprep(out,'^_+|_+$','');
if isempty(out), out = 'dataset_raw'; end
end
