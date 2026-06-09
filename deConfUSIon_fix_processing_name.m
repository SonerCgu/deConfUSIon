function nameOut = deConfUSIon_fix_processing_name(nameIn, dataStruct, matFile)
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
    if exist('deConfUSIon_is_bad_display_name','file') == 2 && deConfUSIon_is_bad_display_name(nameOut) && ~isempty(matFile)
        if exist('deConfUSIon_display_from_file_context','file') == 2
            [~,stem] = fileparts(matFile);
            nameOut = deConfUSIon_display_from_file_context(matFile, stem);
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
    if exist('deConfUSIon_compact_chain_name','file') == 2
        out = deConfUSIon_compact_chain_name(in);
        return;
    end
catch
end
out = char(in);
out = regexprep(out,'\.mat$','','ignorecase');
out = regexprep(out,'_+','_');
out = regexprep(out,'^_+|_+$','');
end


%% ------------------------------------------------------------------------
%% Integrated helper from deConfUSIon_display_from_file_context.m on 09-Jun-2026 16:52:19
%% Original file archived in backups/deConfUSIon_phase6_fast_cleanup_*/integrated_helpers
%% ------------------------------------------------------------------------

function displayName = deConfUSIon_display_from_file_context(matFile, fallbackStem)
% Build readable name for saved/lazy preprocessing files when metadata is bad.
% Preprocessing files are NEVER called raw.

if nargin < 1, matFile = ''; end
if nargin < 2, fallbackStem = ''; end
try, matFile = char(matFile); catch, matFile = ''; end
try, fallbackStem = char(fallbackStem); catch, fallbackStem = ''; end

[folder,stem] = fileparts(matFile);
if isempty(fallbackStem), fallbackStem = stem; end
combo = [fallbackStem '_' folder];
lowCombo = lower(combo);
parts = {};

an = regexp(combo,'B6J[_-](\d{3,6})','tokens','once');
if isempty(an), an = regexp(combo,'[_-](\d{3,6})[_-]Session','tokens','once'); end
if isempty(an), an = regexp(combo,'[_-](\d{3,6})[_-]scan','tokens','once'); end
if ~isempty(an), parts{end+1} = an{1}; end

sess = regexp(folder,'Session[_-]?0*([0-9]+)','tokens','once');
if ~isempty(sess), parts{end+1} = sprintf('sess%03d',str2double(sess{1})); end

sl = regexp(combo,'Slice0*([0-9]+)of0*([0-9]+)','tokens','once');
if isempty(sl), sl = regexp(combo,'sl0*([0-9]+)of0*([0-9]+)','tokens','once'); end
if ~isempty(sl), parts{end+1} = sprintf('sl%03dof%03d',str2double(sl{1}),str2double(sl{2})); end

isPreproc = deConfUSIon_is_preproc_mat_path(matFile);
ops = {};

% Important rule: processed files in SplitMotor/Preprocessing are motor-derived, not raw.
if isPreproc && (~isempty(strfind(lowCombo,'splitmotor')) || ~isempty(strfind(lowCombo,'_motor')))
    ops{end+1} = 'motor';
end

tok = regexp(fallbackStem,'imreg[^_]*_?(med|median)?_?n\d+','match','once');
if ~isempty(tok), ops{end+1} = regexprep(tok,'median','med','ignorecase'); end
tok = regexp(fallbackStem,'BPF[^_]*to[^_]*Hz_o\d+|LPF[^_]*Hz_o\d+|HPF[^_]*Hz_o\d+','match','once');
if ~isempty(tok), ops{end+1} = tok; end
tok = regexp(fallbackStem,'tsmooth_[^_]+s|temporalSmooth_[^_]+s','match','once');
if ~isempty(tok), ops{end+1} = regexprep(tok,'temporalSmooth_','tsmooth_','ignorecase'); end
tok = regexp(fallbackStem,'submean[^_]*_nsub\d+|subsample_[^_]*_nsub\d+','match','once');
if ~isempty(tok), ops{end+1} = regexprep(tok,'subsample_mean_','submean_','ignorecase'); end
tok = regexp(fallbackStem,'pca[^_]*_?dropPC[^_]*|dropPC[^_]*','match','once');
if ~isempty(tok)
    if isempty(strfind(lower(tok),'pca')), tok = ['pca_' tok]; end
    ops{end+1} = tok;
end
tok = regexp(fallbackStem,'ica[^_]*_?dropIC[^_]*|dropIC[^_]*','match','once');
if ~isempty(tok)
    if isempty(strfind(lower(tok),'ica')), tok = ['ica_' tok]; end
    ops{end+1} = tok;
end

if isempty(parts)
    base = 'dataset';
else
    base = strjoin(parts,'_');
end

if isPreproc
    if isempty(ops)
        % Still do NOT call it raw. For SplitMotor this becomes motor; otherwise processed.
        if ~isempty(strfind(lowCombo,'splitmotor'))
            ops{end+1} = 'motor';
        else
            ops{end+1} = 'processed';
        end
    end
else
    ops{end+1} = 'raw';
end

ts = regexp(fallbackStem,'\d{8}_\d{6}','match','once');
displayName = strjoin([{base} ops],'_');
if ~isempty(ts), displayName = [displayName '_' ts]; end
displayName = deConfUSIon_compact_chain_name(displayName);
end



%% ------------------------------------------------------------------------
%% Integrated helper from deConfUSIon_is_bad_display_name.m on 09-Jun-2026 16:52:19
%% Original file archived in backups/deConfUSIon_phase6_fast_cleanup_*/integrated_helpers
%% ------------------------------------------------------------------------

function tf = deConfUSIon_is_bad_display_name(s)
% True if name looks like an internal short physical filename/key.

tf = false;
if nargin < 1 || isempty(s), tf = true; return; end
try, s = char(s); catch, tf = true; return; end
low = lower(s);

patterns = {
    'preproc_preproc', ...
    '^preproc_[0-9]', ...
    '^preproc_.*_[0-9a-f]{8}$', ...
    '_[0-9a-f]{8}$', ...
    'filter_filter', ...
    'pca_pca', ...
    'ica_ica', ...
    'imreg_imreg', ...
    'motor_motor' ...
};

for i = 1:numel(patterns)
    if ~isempty(regexp(low,patterns{i},'once'))
        tf = true;
        return;
    end
end

% Generic op name without animal/session/slice context.
startsGeneric = ~isempty(regexp(low,'^(preproc|filter|pca|ica|imreg|tsmooth|subsample)_','once'));
hasContext = ~isempty(regexp(low,'\d{3,6}.*(sess|sl|slice|scan)','once'));
if startsGeneric && ~hasContext
    tf = true;
end
end



%% ------------------------------------------------------------------------
%% Integrated tiny helper from deConfUSIon_is_preproc_mat_path.m on 09-Jun-2026 16:59:36
%% ------------------------------------------------------------------------

function tf = deConfUSIon_is_preproc_mat_path(p)
% True for saved processed/lazy preprocessing MAT files.

tf = false;
if nargin < 1 || isempty(p), return; end
try, p = char(p); catch, return; end
pp = lower(strrep(p,'/','\'));

if ~isempty(strfind(pp,'\preprocessing\')) || ~isempty(strfind(pp,'\analyseddata\'))
    tf = true;
end

% Short folder P used when Windows path is too long.
if ~isempty(regexp(pp,'\\p\\[^\\]+\.mat$','once'))
    tf = true;
end
end

