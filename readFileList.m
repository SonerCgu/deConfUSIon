function D = readFileList(listFile, infoRegions)
% readFileList  Parse JM selected-region list and map acronyms to atlas indices.
% Usage:
%   D = readFileList('list_selected_regions.txt', atlas.infoRegions);
%
% Output D is a struct array with fields:
%   group   - group/microregion acronym from the first token on each data line
%   parts   - atlas.infoRegions indices for the matched acronym(s)
%   line    - original cleaned list line
%   comment - trailing // comment, if present
%
% Lines beginning with // are section headers and are skipped.
% Lines beginning with % define grouped acronyms, e.g.:
%   %LS LSv LSc LSr
% The group field becomes LS and parts contains the listed component indices.

if nargin < 1 || isempty(listFile)
    error('readFileList:MissingFile','Missing list file.');
end
if nargin < 2 || isempty(infoRegions)
    error('readFileList:MissingInfoRegions','Missing atlas.infoRegions.');
end
if exist(listFile,'file') ~= 2
    error('readFileList:FileNotFound','List file not found: %s', listFile);
end

acr = localGetField(infoRegions, {'acr','acronym','acronyms'});
if isempty(acr)
    error('readFileList:NoAcr','atlas.infoRegions must contain an acr/acronym field.');
end
acr = localToCellstr(acr);
acrClean = cell(size(acr));
for i = 1:numel(acr)
    acrClean{i} = localCleanToken(acr{i});
end

fid = fopen(listFile,'r');
if fid < 0
    error('readFileList:OpenFailed','Could not open %s', listFile);
end
closer = onCleanup(@() fclose(fid)); %#ok<NASGU>

D = struct('group',{{}},'parts',{{}},'line',{{}},'comment',{{}});
while true
    ln = fgetl(fid);
    if ~ischar(ln), break; end
    raw = strtrim(ln);
    if isempty(raw), continue; end
    if numel(raw) >= 2 && strcmp(raw(1:2),'//')
        continue;
    end

    comment = '';
    cpos = strfind(raw,'//');
    if ~isempty(cpos)
        comment = strtrim(raw(cpos(1)+2:end));
        raw = strtrim(raw(1:cpos(1)-1));
    end
    if isempty(raw), continue; end

    rawNoPct = raw;
    if rawNoPct(1) == '%'
        rawNoPct = strtrim(rawNoPct(2:end));
    end
    toks = regexp(rawNoPct,'\s+','split');
    toks = toks(~cellfun('isempty',toks));
    if isempty(toks), continue; end

    group = toks{1};
    partsTokens = toks;
    if numel(toks) > 1
        partsTokens = toks(2:end);
    end

    idx = [];
    for t = 1:numel(partsTokens)
        tok = localCleanToken(partsTokens{t});
        hit = find(strcmpi(acrClean,tok));
        if isempty(hit)
            hit = find(strcmpi(acr,tok));
        end
        if isempty(hit)
            % Some tokens include display hints such as VISp(pl). Try the prefix.
            tok2 = regexprep(tok,'\(.*\)$','');
            if ~strcmp(tok2,tok)
                hit = find(strcmpi(acrClean,tok2));
            end
        end
        if ~isempty(hit)
            idx = [idx hit(:)']; %#ok<AGROW>
        end
    end
    idx = unique(idx,'stable');

    D.group{end+1} = group; %#ok<AGROW>
    D.parts{end+1} = idx; %#ok<AGROW>
    D.line{end+1} = raw; %#ok<AGROW>
    D.comment{end+1} = comment; %#ok<AGROW>
end
end

function v = localGetField(s, names)
v = [];
for i = 1:numel(names)
    if isstruct(s) && isfield(s,names{i})
        v = s.(names{i});
        return;
    end
end
end

function c = localToCellstr(x)
if iscell(x)
    c = x(:);
elseif ischar(x)
    c = cellstr(x);
elseif isstring(x)
    c = cellstr(x(:));
else
    c = cell(numel(x),1);
    for i = 1:numel(x)
        c{i} = char(x(i));
    end
end
for i = 1:numel(c)
    if isempty(c{i}), c{i} = ''; else, c{i} = char(c{i}); end
end
end

function s = localCleanToken(s)
s = char(strtrim(s));
s = regexprep(s,'\s+','');
end
