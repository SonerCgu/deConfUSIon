function studio = deConfUSIon_add_preproc_lazy_datasets(studio)
% Fast scanner for saved preprocessing and explicit PSC analysis datasets.
%
% Performance rules:
%   - never load newData during Studio startup
%   - never write into preprocessing MAT files while refreshing dropdowns
%   - read only small naming/provenance fields (including legacy newData)
%   - cache metadata by filename, byte size and modification time

if nargin < 1 || ~isstruct(studio), return; end
if ~isfield(studio,'datasets') || isempty(studio.datasets)
    studio.datasets = struct();
end

folders = {};
try
    if isfield(studio,'exportPath') && ~isempty(studio.exportPath)
        folders{end+1} = fullfile(studio.exportPath,'Preprocessing'); %#ok<AGROW>
        folders{end+1} = fullfile(studio.exportPath,'P'); %#ok<AGROW>
        folders{end+1} = fullfile(studio.exportPath,'PSC'); %#ok<AGROW>
        folders{end+1} = fullfile(studio.exportPath,'PSC','P'); %#ok<AGROW>
    end
catch
end

folders = local_unique_folders(folders);
registered = local_registered_paths(studio);

for ff = 1:numel(folders)
    folder = folders{ff};
    if exist(folder,'dir') ~= 7, continue; end

    files = dir(fullfile(folder,'*.mat'));
    if isempty(files), continue; end

    cacheFile = fullfile(folder,'.deconfusion_name_index.cache');
    cache = struct('name',{},'bytes',{},'datenum',{}, ...
        'displayNameFull',{},'displayNameShort',{},'sortTime',{});

    if exist(cacheFile,'file') == 2
        try
            C = load(cacheFile,'-mat'); % Older indexes have no cacheVersion.
            if isfield(C,'cache') && isstruct(C.cache) && isfield(C,'cacheVersion') && C.cacheVersion==2
                cache = C.cache;
            end
        catch
            cache = struct('name',{},'bytes',{},'datenum',{}, ...
                'displayNameFull',{},'displayNameShort',{},'sortTime',{});
        end
    end

    cacheDirty = false;

    for kk = 1:numel(files)
        matFile = fullfile(files(kk).folder,files(kk).name);

        if local_is_registered(registered,matFile)
            continue;
        end

        [~,stem] = fileparts(files(kk).name);
        displayNameFull = stem;
        displayNameShort = stem;
        sortTime = files(kk).datenum;

        cacheHit = 0;
        for cc = 1:numel(cache)
            sameName = strcmpi(cache(cc).name,files(kk).name);
            sameBytes = isequal(double(cache(cc).bytes),double(files(kk).bytes));
            sameTime = abs(double(cache(cc).datenum)-double(files(kk).datenum)) < 1e-10;
            if sameName && sameBytes && sameTime
                cacheHit = cc;
                break;
            end
        end

        if cacheHit > 0
            try, displayNameFull = cache(cacheHit).displayNameFull; catch, end
            try, displayNameShort = cache(cacheHit).displayNameShort; catch, end
            try, sortTime = cache(cacheHit).sortTime; catch, end
        else
            % Read only tiny top-level metadata variables.
            % Never read newData here.
            oldWarning = warning('off','all');
            try
                S = load(matFile, ...
                    'HUMOR_fullDisplayName', ...
                    'displayNameFull', ...
                    'displayNameShort', ...
                    'preprocDisplayName', ...
                    'datasetSortTime');
            catch
                S = struct();
            end
            warning(oldWarning);

            try
                if isfield(S,'HUMOR_fullDisplayName') && ~isempty(S.HUMOR_fullDisplayName)
                    displayNameFull = char(S.HUMOR_fullDisplayName);
                elseif isfield(S,'displayNameFull') && ~isempty(S.displayNameFull)
                    displayNameFull = char(S.displayNameFull);
                elseif isfield(S,'preprocDisplayName') && ~isempty(S.preprocDisplayName)
                    displayNameFull = char(S.preprocDisplayName);
                end
            catch
                displayNameFull = stem;
            end

            try
                % Reconcile legacy picker labels with the actual saved result.
                % An old GLM file must not masquerade as an imreg-only result.
                provenance=deConfUSIon_read_processing_metadata(matFile);
                if isfield(provenance,'displayNameFull') && ~isempty(provenance.displayNameFull)
                    displayNameFull=char(provenance.displayNameFull);
                end
                displayNameShort=deConfUSIon_display_short_name(displayNameFull,provenance,matFile);
                displayNameFull=displayNameShort;
            catch
                displayNameShort = displayNameFull;
            end

            try
                if isfield(S,'datasetSortTime') && ...
                        ~isempty(S.datasetSortTime) && ...
                        isnumeric(S.datasetSortTime)
                    sortTime = double(S.datasetSortTime(1));
                end
            catch
            end

            % Remove stale cache records for the same filename.
            keep = true(1,numel(cache));
            for cc = 1:numel(cache)
                if strcmpi(cache(cc).name,files(kk).name)
                    keep(cc) = false;
                end
            end
            cache = cache(keep);

            entry = struct();
            entry.name = files(kk).name;
            entry.bytes = double(files(kk).bytes);
            entry.datenum = double(files(kk).datenum);
            entry.displayNameFull = displayNameFull;
            entry.displayNameShort = displayNameShort;
            entry.sortTime = sortTime;
            cache(end+1) = entry; %#ok<AGROW>
            cacheDirty = true;
        end

        if isempty(displayNameFull), displayNameFull = stem; end
        if isempty(displayNameShort), displayNameShort = displayNameFull; end

        key = local_key(displayNameFull,studio.datasets);

        studio.datasets.(key) = struct( ...
            'lazyFile',matFile, ...
            'isLazy',true, ...
            'displayNameFull',displayNameFull, ...
            'displayNameShort',displayNameShort, ...
            'preprocDisplayName',displayNameFull, ...
            'datasetSortTime',sortTime);

        registered{end+1} = matFile; %#ok<AGROW>
    end

    if cacheDirty
        try
            cacheVersion=2; %#ok<NASGU>
            save(cacheFile,'cache','cacheVersion','-mat');
        catch
            % Cache failure must never prevent loading the dataset.
        end
    end
end
end

function folders = local_unique_folders(folders)
out = {};
for i = 1:numel(folders)
    f = folders{i};
    if isempty(f), continue; end
    found = false;
    for j = 1:numel(out)
        if strcmpi(out{j},f), found = true; break; end
    end
    if ~found, out{end+1} = f; end %#ok<AGROW>
end
folders = out;
end

function registered = local_registered_paths(studio)
registered = {};
try
    keys = fieldnames(studio.datasets);
    for i = 1:numel(keys)
        d = studio.datasets.(keys{i});
        if ~isstruct(d), continue; end
        if isfield(d,'lazyFile') && ~isempty(d.lazyFile)
            registered{end+1} = char(d.lazyFile); %#ok<AGROW>
        end
        if isfield(d,'savedFile') && ~isempty(d.savedFile)
            registered{end+1} = char(d.savedFile); %#ok<AGROW>
        end
    end
catch
end
end

function tf = local_is_registered(registered,matFile)
tf = false;
for i = 1:numel(registered)
    if strcmpi(registered{i},matFile)
        tf = true;
        return;
    end
end
end

function key = local_key(name,datasets)
try, name = char(name); catch, name = 'dataset'; end
key = regexprep(name,'[^A-Za-z0-9_]','_');
key = regexprep(key,'_+','_');
key = regexprep(key,'^_+|_+$','');
if isempty(key), key = 'dataset'; end
if ~isletter(key(1)), key = ['d_' key]; end
if numel(key) > namelengthmax, key = key(1:namelengthmax); end
base = key;
n = 1;
while isfield(datasets,key)
    suffix = sprintf('_v%d',n);
    maxBase = max(1,namelengthmax-numel(suffix));
    key = [base(1:min(numel(base),maxBase)) suffix];
    n = n + 1;
end
end
