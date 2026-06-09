function [ord, ok, score] = deConfUSIon_fc_jm_order(labels, names, listFile)
% deConfUSIon_fc_jm_order  Reorder FC ROI names according to JM list.
% The function returns ord into the input arrays. Unmatched regions are kept
% after matched regions in their original order.

if nargin < 3 || isempty(listFile)
    here = fileparts(mfilename('fullpath'));
    listFile = localFindJmListFile(here);
end
labels = labels(:);
if nargin < 2 || isempty(names)
    names = cell(numel(labels),1);
    for i = 1:numel(labels), names{i} = sprintf('ROI_%g',labels(i)); end
end
names = cellstr(names(:));
ord = (1:numel(names))';
ok = false;
score = 0;
if exist(listFile,'file') ~= 2 || isempty(names)
    return;
end

jm = localReadJmTokens(listFile);
if isempty(jm), return; end
rank = inf(numel(names),1);
for i = 1:numel(names)
    nm = lower(localCleanName(names{i}));
    best = inf;
    for j = 1:numel(jm)
        tok = lower(localCleanName(jm{j}));
        if isempty(tok), continue; end
        if strcmp(nm,tok) || ~isempty(strfind(nm,tok)) || ~isempty(strfind(tok,nm))
            best = j;
            break;
        end
    end
    rank(i) = best;
end
matched = isfinite(rank);
score = sum(matched);
if any(matched)
    [~,ix] = sortrows([rank(:) (1:numel(rank))']);
    ord = ix(:);
    ok = true;
end
end

function listFile = localFindJmListFile(here)
listFile = fullfile(here,'list_selected_regions.txt');
if exist(listFile,'file') ~= 2
    cand = fullfile(here,'atlas_tools','list_selected_regions.txt');
    if exist(cand,'file') == 2, listFile = cand; end
end
end

function tokens = localReadJmTokens(listFile)
tokens = {};
fid = fopen(listFile,'r');
if fid < 0, return; end
closer = onCleanup(@() fclose(fid)); %#ok<NASGU>
while true
    ln = fgetl(fid);
    if ~ischar(ln), break; end
    raw = strtrim(ln);
    if isempty(raw), continue; end
    if numel(raw) >= 2 && strcmp(raw(1:2),'//'), continue; end
    cpos = strfind(raw,'//');
    if ~isempty(cpos), raw = strtrim(raw(1:cpos(1)-1)); end
    if isempty(raw), continue; end
    if raw(1) == '%', raw = strtrim(raw(2:end)); end
    toks = regexp(raw,'\s+','split');
    toks = toks(~cellfun('isempty',toks));
    if isempty(toks), continue; end
    tokens{end+1,1} = toks{1}; %#ok<AGROW>
end
end

function s = localCleanName(s)
s = char(s);
s = regexprep(s,'^[LR][\-_\s]+','');
s = regexprep(s,'\s*\([LR]\)\s*$','');
s = regexprep(s,'left|right','');
s = regexprep(s,'[^A-Za-z0-9]+','');
end
