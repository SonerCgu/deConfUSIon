function studio = deConfUSIon_fix_studio_dataset_names(studio)
% Fast in-memory dropdown metadata repair.
%
% Important: this function must never write to preprocessing MAT files.
% It is called whenever the dataset dropdown is refreshed.

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

    fullName = '';
    shortName = '';

    try
        if isfield(d,'HUMOR_fullDisplayName') && ~isempty(d.HUMOR_fullDisplayName)
            fullName = char(d.HUMOR_fullDisplayName);
        elseif isfield(d,'displayNameFull') && ~isempty(d.displayNameFull)
            fullName = char(d.displayNameFull);
        elseif isfield(d,'preprocDisplayName') && ~isempty(d.preprocDisplayName)
            fullName = char(d.preprocDisplayName);
        end
    catch
        fullName = '';
    end

    if isempty(fullName), fullName = key; end

    try
        if isfield(d,'displayNameShort') && ~isempty(d.displayNameShort)
            shortName = char(d.displayNameShort);
        end
    catch
        shortName = '';
    end

    if isempty(shortName)
        try
            % Empty matFile prevents any disk access during refresh.
            shortName = deConfUSIon_display_short_name(fullName,d,'');
        catch
            shortName = fullName;
        end
    end

    d.displayNameFull = fullName;
    d.preprocDisplayName = fullName;
    d.HUMOR_fullDisplayName = fullName;
    d.displayNameShort = shortName;

    if ~isfield(d,'datasetSortTime') || isempty(d.datasetSortTime)
        matFile = '';
        try
            if isfield(d,'savedFile') && ~isempty(d.savedFile)
                matFile = char(d.savedFile);
            elseif isfield(d,'lazyFile') && ~isempty(d.lazyFile)
                matFile = char(d.lazyFile);
            end
        catch
            matFile = '';
        end

        if ~isempty(matFile) && exist(matFile,'file') == 2
            try
                q = dir(matFile);
                d.datasetSortTime = q.datenum;
            catch
                d.datasetSortTime = now;
            end
        else
            d.datasetSortTime = now;
        end
    end

    studio.datasets.(key) = d;
end
end
