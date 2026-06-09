function studio = HUMOR_add_preproc_lazy_datasets(studio)
% Scanner for saved Preprocessing/P MATs. Repairs abbreviated names.

if nargin < 1 || ~isstruct(studio), return; end
if ~isfield(studio,'datasets') || isempty(studio.datasets), studio.datasets = struct(); end

folders = {};
try
    if isfield(studio,'exportPath') && ~isempty(studio.exportPath)
        folders{end+1} = fullfile(studio.exportPath,'Preprocessing');
        folders{end+1} = fullfile(studio.exportPath,'P');
    end
catch
end

allFiles = [];
for f = 1:numel(folders)
    try
        if exist(folders{f},'dir') == 7
            d = dir(fullfile(folders{f},'*.mat'));
            allFiles = [allFiles; d]; %#ok<AGROW>
        end
    catch
    end
end
if isempty(allFiles), return; end
[~,ord] = sort([allFiles.datenum],'ascend');
allFiles = allFiles(ord);

for kk = 1:numel(allFiles)
    matFile = fullfile(allFiles(kk).folder, allFiles(kk).name);
    if local_registered(studio, matFile), continue; end

    [~,stem] = fileparts(allFiles(kk).name);
    displayName = stem;
    sortTime = allFiles(kk).datenum;

    try
        info = whos('-file', matFile);
    catch
        % Corrupt/partial MAT: skip silently.
        continue;
    end
    names = {info.name};

    try
        vars = {};
        if ismember('HUMOR_fullDisplayName',names), vars{end+1} = 'HUMOR_fullDisplayName'; end %#ok<AGROW>
        if ismember('displayNameFull',names), vars{end+1} = 'displayNameFull'; end %#ok<AGROW>
        if ismember('preprocDisplayName',names), vars{end+1} = 'preprocDisplayName'; end %#ok<AGROW>
        if ismember('datasetSortTime',names), vars{end+1} = 'datasetSortTime'; end %#ok<AGROW>
        if ~isempty(vars)
            S = load(matFile, vars{:});
            if isfield(S,'HUMOR_fullDisplayName') && ~isempty(S.HUMOR_fullDisplayName)
                displayName = char(S.HUMOR_fullDisplayName);
            elseif isfield(S,'displayNameFull') && ~isempty(S.displayNameFull)
                displayName = char(S.displayNameFull);
            elseif isfield(S,'preprocDisplayName') && ~isempty(S.preprocDisplayName)
                displayName = char(S.preprocDisplayName);
            end
            if isfield(S,'datasetSortTime') && ~isempty(S.datasetSortTime)
                sortTime = S.datasetSortTime;
            end
        end
    catch
    end

    displayName = HUMOR_best_visible_dataset_name(displayName, [], matFile);

    if local_needs_newdata(displayName) && ismember('newData',names)
        try
            S2 = load(matFile,'newData');
            if isfield(S2,'newData') && isstruct(S2.newData)
                displayName = HUMOR_best_visible_dataset_name(displayName, S2.newData, matFile);
                try, HUMOR_commit_full_display_name(matFile, S2.newData, displayName); catch, end
            end
        catch
        end
    end

    key = local_key(displayName, studio.datasets);
    studio.datasets.(key) = struct('lazyFile',matFile,'isLazy',true,'displayNameFull',displayName,'preprocDisplayName',displayName,'datasetSortTime',sortTime);
end
end

function tf = local_needs_newdata(s)
low = lower(s);
tf = false;
if isempty(s), tf = true; return; end
if ~isempty(strfind(s,'...')), tf = true; return; end
if ~isempty(strfind(low,'preproc_preproc')), tf = true; return; end
if ~isempty(regexp(low,'(^|_)preproc_[0-9]','once')), tf = true; return; end
if ~isempty(regexp(low,'_[0-9a-f]{8}($|_)','once')), tf = true; return; end
% Names without timestamp are probably incomplete.
if isempty(regexp(low,'(?:19|20)\d{6}_\d{6}','once')), tf = true; return; end
end

function tf = local_registered(studio, matFile)
tf = false;
try
    keys = fieldnames(studio.datasets);
    for i = 1:numel(keys)
        d = studio.datasets.(keys{i});
        if isstruct(d)
            if isfield(d,'lazyFile') && strcmpi(char(d.lazyFile),char(matFile)), tf = true; return; end
            if isfield(d,'savedFile') && strcmpi(char(d.savedFile),char(matFile)), tf = true; return; end
        end
    end
catch
end
end

function key = local_key(name, datasets)
key = regexprep(char(name),'[^A-Za-z0-9_]','_');
key = regexprep(key,'_+','_');
key = regexprep(key,'^_+|_+$','');
if isempty(key), key = 'dataset'; end
if ~isletter(key(1)), key = ['d_' key]; end
if numel(key) > 75, key = key(1:75); end
base = key; n = 1;
while isfield(datasets,key)
    key = sprintf('%s_v%d',base,n);
    if numel(key) > 83, key = [base(1:75) sprintf('_v%d',n)]; end
    n = n + 1;
end
end
