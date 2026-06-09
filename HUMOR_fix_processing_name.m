function nameOut = HUMOR_fix_processing_name(nameIn, dataStruct, matFile)
% Ensure user-facing dataset names preserve applied processing steps.
% Especially fixes: motor -> PCA -> imregdemons where PCA was missing after reload.

if nargin < 1 || isempty(nameIn), nameIn = 'dataset'; end
if nargin < 2, dataStruct = []; end
if nargin < 3, matFile = ''; end

try, nameOut = char(nameIn); catch, nameOut = 'dataset'; end
try, matFile = char(matFile); catch, matFile = ''; end

nameOut = local_compact(nameOut);

% If the visible name is only an internal short save name, use folder context first.
try
    if exist('HUMOR_is_bad_display_name','file') == 2 && HUMOR_is_bad_display_name(nameOut) && ~isempty(matFile)
        if exist('HUMOR_display_from_file_context','file') == 2
            [~,stem] = fileparts(matFile);
            nameOut = HUMOR_display_from_file_context(matFile, stem);
        end
    end
catch
end

nameOut = local_compact(nameOut);

% Append PCA/ICA tags when metadata proves they were applied but name lacks them.
if isstruct(dataStruct)
    if isfield(dataStruct,'pcaStats') && isempty(regexpi(nameOut,'(^|_)pca(_|$)'))
        tag = local_pca_tag(dataStruct.pcaStats);
        nameOut = local_insert_before_late_ops(nameOut, tag);
    end
    if isfield(dataStruct,'icaStats') && isempty(regexpi(nameOut,'(^|_)ica(_|$)'))
        tag = local_ica_tag(dataStruct.icaStats);
        nameOut = local_insert_before_late_ops(nameOut, tag);
    end
end

nameOut = local_compact(nameOut);
end

function tag = local_pca_tag(stats)
tag = 'pca';
try
    if isfield(stats,'selectedComponents') && ~isempty(stats.selectedComponents)
        sel = unique(stats.selectedComponents(:)');
        tag = ['pca_dropPC' local_range_tag(sel)];
    else
        tag = 'pca_done';
    end
    if isfield(stats,'sliceScope') && isstruct(stats.sliceScope) && isfield(stats.sliceScope,'sliceSpecific') && stats.sliceScope.sliceSpecific
        sl = sprintf('sl%03dof%03d', round(stats.sliceScope.zIndex), round(stats.sliceScope.nSlices));
        tag = [sl '_' tag];
    end
catch
    tag = 'pca_done';
end
end

function tag = local_ica_tag(stats)
tag = 'ica';
try
    if isfield(stats,'selectedComponents') && ~isempty(stats.selectedComponents)
        sel = unique(stats.selectedComponents(:)');
        tag = ['ica_dropIC' local_range_tag(sel)];
    else
        tag = 'ica_done';
    end
    if isfield(stats,'sliceScope') && isstruct(stats.sliceScope) && isfield(stats.sliceScope,'sliceSpecific') && stats.sliceScope.sliceSpecific
        sl = sprintf('sl%03dof%03d', round(stats.sliceScope.zIndex), round(stats.sliceScope.nSlices));
        tag = [sl '_' tag];
    end
catch
    tag = 'ica_done';
end
end

function s = local_range_tag(v)
v = sort(unique(v(:)'));
if isempty(v), s = 'unknown'; return; end
ranges = {};
i = 1;
while i <= numel(v)
    j = i;
    while j < numel(v) && v(j+1) == v(j)+1
        j = j + 1;
    end
    if i == j
        ranges{end+1} = sprintf('%d',v(i)); %#ok<AGROW>
    else
        ranges{end+1} = sprintf('%d-%d',v(i),v(j)); %#ok<AGROW>
    end
    i = j + 1;
end
s = strjoin(ranges,'-');
end

function out = local_insert_before_late_ops(nameIn, tag)
% If imreg/filter/etc happened after PCA/ICA but PCA was missing, insert before later ops.
out = nameIn;
if isempty(tag), return; end

% Preserve trailing timestamp.
ts = regexp(out,'\d{8}_\d{6}$','match','once');
if ~isempty(ts)
    out = regexprep(out,'_\d{8}_\d{6}$','');
end

% Avoid duplicate tag.
if ~isempty(strfind(lower(out), lower(tag)))
    if ~isempty(ts), out = [out '_' ts]; end
    return;
end

% Insert before first later operation if present.
latePats = {'_imregdemons','_imreg','_BPF','_LPF','_HPF','_filter','_tsmooth','_submean','_submed','_subsample'};
idx = [];
low = lower(out);
for k = 1:numel(latePats)
    p = strfind(low, lower(latePats{k}));
    if ~isempty(p)
        idx(end+1) = p(1); %#ok<AGROW>
    end
end

if isempty(idx)
    out = [out '_' tag];
else
    p = min(idx);
    out = [out(1:p-1) '_' tag out(p:end)];
end

if ~isempty(ts), out = [out '_' ts]; end
end

function out = local_compact(in)
try
    if exist('HUMOR_compact_chain_name','file') == 2
        out = HUMOR_compact_chain_name(in);
        return;
    end
catch
end
out = char(in);
out = regexprep(out,'\.mat$','','ignorecase');
out = regexprep(out,'_+','_');
out = regexprep(out,'^_+|_+$','');
end
