function studio = deConfUSIon_fix_studio_dataset_names(studio)
% Repair Studio dataset display metadata and preserve new preprocessing outputs in dropdown.
if nargin < 1 || ~isstruct(studio), return; end
if ~isfield(studio,'datasets') || isempty(studio.datasets), return; end
keys = fieldnames(studio.datasets);
for i = 1:numel(keys)
    key = keys{i};
    try
        d = studio.datasets.(key);
    catch
        continue;
    end
    if ~isstruct(d), continue; end
    matFile = '';
    if isfield(d,'savedFile') && ~isempty(d.savedFile)
        try, matFile = char(d.savedFile); catch, end
    end
    if isempty(matFile) && isfield(d,'lazyFile') && ~isempty(d.lazyFile)
        try, matFile = char(d.lazyFile); catch, end
    end
    seed = key;
    flds = {'HUMOR_fullDisplayName','displayNameFull','preprocDisplayName','fullDisplayName','sourceDisplayName'};
    for f = 1:numel(flds)
        if isfield(d,flds{f}) && ~isempty(d.(flds{f}))
            try, seed = char(d.(flds{f})); break; catch, end
        end
    end
    fullName = deConfUSIon_best_visible_dataset_name(seed,d,matFile);
    d.HUMOR_fullDisplayName = fullName;
    d.displayNameFull = fullName;
    d.preprocDisplayName = fullName;
    if ~isfield(d,'datasetSortTime') || isempty(d.datasetSortTime)
        if ~isempty(matFile) && exist(matFile,'file') == 2
            q = dir(matFile);
            d.datasetSortTime = q.datenum;
        else
            d.datasetSortTime = now;
        end
    end
    studio.datasets.(key) = d;
    try, deConfUSIon_commit_full_display_name(matFile,d,fullName); catch, end
end
end
