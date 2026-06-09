function label = HUMOR_full_ordered_label_for_dataset(nameIn, dataStruct, matFile)
% Robust full ordered visible dataset label.
% Uses nameIn + dataStruct metadata + matFile path to avoid abbreviated reopened names.

if nargin < 1 || isempty(nameIn), nameIn = 'dataset'; end
if nargin < 2, dataStruct = []; end
if nargin < 3, matFile = ''; end

try, base = char(nameIn); catch, base = 'dataset'; end
try, matFile = char(matFile); catch, matFile = ''; end

% Collect all available name hints.
allName = base;
try
    if isstruct(dataStruct)
        fields = {'displayNameFull','preprocDisplayName','sourceDatasetKey','preprocessing','savedFile','lazyFile'};
        for i = 1:numel(fields)
            f = fields{i};
            if isfield(dataStruct,f) && ~isempty(dataStruct.(f))
                try
                    allName = [allName '_' char(dataStruct.(f))]; %#ok<AGROW>
                catch
                end
            end
        end
    end
catch
end

% If the visible name contains ellipsis, it is not trustworthy by itself.
allName = strrep(allName,'...','_');

try
    if exist('HUMOR_ordered_chain_label','file') == 2
        label = HUMOR_ordered_chain_label(allName, dataStruct, matFile);
    elseif exist('HUMOR_canonical_dataset_label','file') == 2
        label = HUMOR_canonical_dataset_label(allName, dataStruct, matFile);
    else
        label = local_basic_clean(allName);
    end
catch
    label = local_basic_clean(allName);
end

% Final cleanup only, never shorten.
label = regexprep(label,'\.\.\.','_');
label = regexprep(label,'_+','_');
label = regexprep(label,'^_+|_+$','');
if isempty(label), label = 'dataset'; end
end

function out = local_basic_clean(in)
out = char(in);
out = regexprep(out,'\.mat$','','ignorecase');
out = regexprep(out,'^preproc_preproc_','','ignorecase');
out = regexprep(out,'^preproc_','','ignorecase');
out = regexprep(out,'_0000[0-9a-fA-F]{4,}','');
out = regexprep(out,'_[0-9a-fA-F]{8}(?=_|$)','');
out = regexprep(out,'_+','_');
out = regexprep(out,'^_+|_+$','');
end
