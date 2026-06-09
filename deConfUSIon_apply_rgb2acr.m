function atlas = deConfUSIon_apply_rgb2acr(atlas, rgbFile)
% deConfUSIon_apply_rgb2acr  Apply RGB colors from JM rgb2acr.xlsx to atlas.infoRegions.

if nargin < 2 || isempty(rgbFile) || exist(rgbFile,'file') ~= 2
    return;
end
if ~isstruct(atlas) || ~isfield(atlas,'infoRegions')
    return;
end
info = atlas.infoRegions;
acr = localGetField(info, {'acr','acronym','acronyms'});
if isempty(acr), return; end
acr = localToCellstr(acr);

try
    [~,~,raw] = xlsread(rgbFile);
catch
    try
        raw = readcell(rgbFile);
    catch
        warning('deConfUSIon:RGB','Could not read rgb2acr file: %s', rgbFile);
        return;
    end
end
if isempty(raw), return; end

header = raw(1,:);
keys = cell(size(header));
for i = 1:numel(header)
    keys{i} = lower(regexprep(char(localCellValue(header{i})),'[^a-z0-9]',''));
end
acrCol = localFindCol(keys, {'acr','acronym','acronyms'});
rCol = localFindCol(keys, {'r','red'});
gCol = localFindCol(keys, {'g','green'});
bCol = localFindCol(keys, {'b','blue'});
rgbCol = localFindCol(keys, {'rgb'});
if isempty(acrCol)
    acrCol = 1;
end

mapAcr = {};
mapRgb = [];
for r = 2:size(raw,1)
    a = strtrim(char(localCellValue(raw{r,acrCol})));
    if isempty(a), continue; end
    rgb = [];
    if ~isempty(rCol) && ~isempty(gCol) && ~isempty(bCol)
        rgb = [localNum(raw{r,rCol}) localNum(raw{r,gCol}) localNum(raw{r,bCol})];
    elseif ~isempty(rgbCol)
        rgb = localParseRgb(raw{r,rgbCol});
    end
    if numel(rgb) == 3 && all(isfinite(rgb))
        if max(rgb) > 1, rgb = rgb ./ 255; end
        rgb = max(0,min(1,rgb));
        mapAcr{end+1,1} = a; %#ok<AGROW>
        mapRgb(end+1,:) = rgb; %#ok<AGROW>
    end
end
if isempty(mapAcr), return; end

rgbOut = nan(numel(acr),3);
for i = 1:numel(acr)
    hit = find(strcmpi(mapAcr, strtrim(acr{i})), 1, 'first');
    if ~isempty(hit)
        rgbOut(i,:) = mapRgb(hit,:);
    end
end

% Preserve existing colors where JM table has no match.
if isfield(info,'rgb')
    old = info.rgb;
    if isnumeric(old) && size(old,2) == 3
        n = min(size(old,1),size(rgbOut,1));
        miss = any(~isfinite(rgbOut(1:n,:)),2);
        rgbOut(1:n,:) = localFillRows(rgbOut(1:n,:), old(1:n,:), miss);
    end
end
rgbOut(~isfinite(rgbOut)) = 0.5;

atlas.infoRegions.rgb = rgbOut;
try, atlas.deConfUSIon.rgb2acr_file = rgbFile; catch, end
try, atlas.deConfUSIon.rgb2acr_applied_on = datestr(now); catch, end
end

function out = localFillRows(out, old, miss)
for i = 1:numel(miss)
    if miss(i), out(i,:) = old(i,:); end
end
end

function col = localFindCol(keys, names)
col = [];
for n = 1:numel(names)
    hit = find(strcmp(keys,names{n}),1,'first');
    if ~isempty(hit), col = hit; return; end
end
end

function v = localCellValue(x)
if isempty(x), v = ''; return; end
if isnumeric(x), v = x; return; end
if ischar(x), v = x; return; end
try, v = char(x); catch, v = ''; end
end

function x = localNum(v)
if isnumeric(v), x = double(v); return; end
x = str2double(char(localCellValue(v)));
end

function rgb = localParseRgb(v)
s = char(localCellValue(v));
nums = regexp(s,'[-+]?\d*\.?\d+','match');
rgb = nan(1,3);
if numel(nums) >= 3
    rgb = [str2double(nums{1}) str2double(nums{2}) str2double(nums{3})];
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
    for i = 1:numel(x), c{i} = char(x(i)); end
end
for i = 1:numel(c)
    if isempty(c{i}), c{i} = ''; else, c{i} = char(c{i}); end
end
end
