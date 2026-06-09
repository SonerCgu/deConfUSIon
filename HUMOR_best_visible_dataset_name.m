function name = HUMOR_best_visible_dataset_name(fallbackName, dataStruct, matFile)
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
        if exist('HUMOR_ordered_chain_label','file') == 2
            best = HUMOR_ordered_chain_label([best '_' matFile], dataStruct, matFile);
        elseif exist('HUMOR_canonical_dataset_label','file') == 2
            best = HUMOR_canonical_dataset_label([best '_' matFile], dataStruct, matFile);
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
