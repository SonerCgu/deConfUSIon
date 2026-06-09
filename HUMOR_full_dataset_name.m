function name = HUMOR_full_dataset_name(studio, key)
% Return full visible dataset name without shortening.
name = key;
try
    if nargin < 2 || isempty(key)
        key = studio.activeDataset;
    end
    d = studio.datasets.(key);
    if isstruct(d) && isfield(d,'displayNameFull') && ~isempty(d.displayNameFull)
        name = d.displayNameFull;
    elseif isstruct(d) && isfield(d,'preprocDisplayName') && ~isempty(d.preprocDisplayName)
        name = d.preprocDisplayName;
    else
        name = key;
    end
    if exist('HUMOR_fix_processing_name','file') == 2
        name = HUMOR_fix_processing_name(name, d, '');
    elseif exist('HUMOR_compact_chain_name','file') == 2
        name = HUMOR_compact_chain_name(name);
    end
catch
end
end
