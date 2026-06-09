function studio = deConfUSIon_add_preproc_lazy_datasets(studio)
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

    displayName = deConfUSIon_best_visible_dataset_name(displayName, [], matFile);

    if local_needs_newdata(displayName) && ismember('newData',names)
        try
            S2 = load(matFile,'newData');
            if isfield(S2,'newData') && isstruct(S2.newData)
                displayName = deConfUSIon_best_visible_dataset_name(displayName, S2.newData, matFile);
                try, deConfUSIon_commit_full_display_name(matFile, S2.newData, displayName); catch, end
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


%% ------------------------------------------------------------------------
%% Integrated helper from deConfUSIon_commit_full_display_name.m on 09-Jun-2026 16:52:19
%% Original file archived in backups/deConfUSIon_phase6_fast_cleanup_*/integrated_helpers
%% ------------------------------------------------------------------------

function fullName = deConfUSIon_commit_full_display_name(matFile, dataStruct, fallbackName)
% Append exact full display name into top-level MAT metadata.

if nargin < 1, matFile = ''; end
if nargin < 2, dataStruct = []; end
if nargin < 3 || isempty(fallbackName), fallbackName = 'dataset'; end
try, matFile = char(matFile); catch, matFile = ''; end

fullName = deConfUSIon_best_visible_dataset_name(fallbackName, dataStruct, matFile);

if ~isempty(matFile) && exist(matFile,'file') == 2
    try
        HUMOR_fullDisplayName = fullName; %#ok<NASGU>
        displayNameFull = fullName; %#ok<NASGU>
        preprocDisplayName = fullName; %#ok<NASGU>
        datasetSortTime = now; %#ok<NASGU>
        save(matFile,'HUMOR_fullDisplayName','displayNameFull','preprocDisplayName','datasetSortTime','-append');
    catch
    end
end
end



%% ------------------------------------------------------------------------
%% Integrated tiny helper from deConfUSIon_best_visible_dataset_name.m on 09-Jun-2026 16:59:35
%% ------------------------------------------------------------------------

function name = deConfUSIon_best_visible_dataset_name(fallbackName, dataStruct, matFile)
% Prefer exact full name saved inside dataset struct. Never abbreviate.

if nargin < 1 || isempty(fallbackName), fallbackName = 'dataset'; end
if nargin < 2, dataStruct = []; end
if nargin < 3, matFile = ''; end

try, fallbackName = char(fallbackName); catch, fallbackName = 'dataset'; end
try, matFile = char(matFile); catch, matFile = ''; end

cands = {};

% Highest priority: exact fields inside loaded dataset struct.
try
    if isstruct(dataStruct)
        exactFields = {'HUMOR_fullDisplayName','displayNameFull','preprocDisplayName','fullDisplayName','sourceDisplayName'};
        for i = 1:numel(exactFields)
            f = exactFields{i};
            if isfield(dataStruct,f) && ~isempty(dataStruct.(f))
                try, cands{end+1} = char(dataStruct.(f)); catch, end %#ok<AGROW>
            end
        end
    end
catch
end

% Lower priority: top-level/fallback string.
cands{end+1} = fallbackName;

best = '';
bestScore = -Inf;
for i = 1:numel(cands)
    s = local_clean_exact(cands{i});
    if isempty(s), continue; end
    score = local_score(s);
    if score > bestScore
        best = s;
        bestScore = score;
    end
end

% If best is still an internal/short name, reconstruct from helper.
if local_is_bad(best)
    try
        if exist('deConfUSIon_ordered_chain_label','file') == 2
            best = deConfUSIon_ordered_chain_label([best '_' matFile], dataStruct, matFile);
        elseif exist('deConfUSIon_ordered_chain_label','file') == 2
            best = deConfUSIon_ordered_chain_label([best '_' matFile], dataStruct, matFile);
        end
    catch
    end
end

name = local_clean_exact(best);
if isempty(name), name = 'dataset'; end
end

function tf = local_is_bad(s)
try, s = char(s); catch, tf = true; return; end
low = lower(s);
tf = false;
if isempty(s), tf = true; return; end
if ~isempty(strfind(s,'...')), tf = true; return; end
if ~isempty(strfind(low,'preproc_preproc')), tf = true; return; end
if ~isempty(regexp(low,'(^|_)preproc_[0-9]','once')), tf = true; return; end
if ~isempty(regexp(low,'_[0-9a-f]{8}($|_)','once')), tf = true; return; end
end

function score = local_score(s)
low = lower(s);
score = numel(s) * 0.05;
if isempty(strfind(s,'...')), score = score + 200; else, score = score - 1000; end
if ~isempty(regexp(low,'(?:^|_)\d{3,6}(?:_|$)','once')), score = score + 30; end
if ~isempty(regexp(low,'sess\d+','once')), score = score + 30; end
if ~isempty(regexp(low,'(?:19|20)\d{6}_\d{6}','once')), score = score + 50; end
if ~isempty(strfind(low,'motor')), score = score + 25; end
if ~isempty(strfind(low,'pca')), score = score + 50; end
if ~isempty(strfind(low,'ica')), score = score + 50; end
if ~isempty(strfind(low,'imreg')), score = score + 45; end
if ~isempty(strfind(low,'bpf')) || ~isempty(strfind(low,'lpf')) || ~isempty(strfind(low,'hpf')), score = score + 30; end
if ~isempty(strfind(low,'preproc_preproc')), score = score - 800; end
if ~isempty(regexp(low,'_[0-9a-f]{8}($|_)','once')), score = score - 400; end
end

function out = local_clean_exact(in)
try, out = char(in); catch, out = ''; end
out = strrep(out,'...','_');
out = regexprep(out,'\.nii\.gz$','','ignorecase');
out = regexprep(out,'\.nii$','','ignorecase');
out = regexprep(out,'\.mat$','','ignorecase');
out = regexprep(out,'^preproc_preproc_','','ignorecase');
out = regexprep(out,'^preproc_','','ignorecase');
out = regexprep(out,'_0000[0-9a-fA-F]{4,}','');
out = regexprep(out,'_[0-9a-fA-F]{8}(?=_|$)','');
out = regexprep(out,'_+','_');
out = regexprep(out,'^_+|_+$','');
end



%% ------------------------------------------------------------------------
%% Integrated tiny helper from deConfUSIon_ordered_chain_label.m on 09-Jun-2026 16:59:37
%% ------------------------------------------------------------------------

function label = deConfUSIon_ordered_chain_label(nameIn, dataStruct, matFile)
% Compatibility wrapper for the Studio display-name builder.
if nargin < 1 || isempty(nameIn), nameIn = 'dataset'; end
if nargin < 2, dataStruct = []; end
if nargin < 3, matFile = ''; end
try
    label = deConfUSIon_display_name_from_sources(nameIn, dataStruct, matFile);
catch
    try, label = char(nameIn); catch, label = 'dataset'; end
    label = strrep(label,'...','_');
    label = regexprep(label,'\.mat$','','ignorecase');
    label = regexprep(label,'_+','_');
    label = regexprep(label,'^_+|_+$','');
    if isempty(label), label = 'dataset'; end
end
end

