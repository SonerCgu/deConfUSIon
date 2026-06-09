function out = shortenMiddle(in, maxLen)
% shortenMiddle
% Safely shorten long labels/paths by preserving beginning and end.
% Needed by SCM / Video setup dialogs and dropdown labels.

if nargin < 1 || isempty(in)
    out = '';
    return;
end

if nargin < 2 || isempty(maxLen)
    maxLen = 120;
end

try
    if isstring(in)
        in = char(in);
    elseif isnumeric(in)
        in = num2str(in);
    elseif ~ischar(in)
        in = char(string(in));
    end
catch
    try
        in = char(in);
    catch
        in = '';
    end
end

maxLen = round(double(maxLen));
if ~isfinite(maxLen) || maxLen < 10
    maxLen = 10;
end

if numel(in) <= maxLen
    out = in;
    return;
end

ellipsisTxt = '...';
keep = maxLen - numel(ellipsisTxt);
frontN = ceil(keep * 0.60);
backN  = floor(keep * 0.40);

frontN = max(1, frontN);
backN  = max(1, backN);

if frontN + backN + numel(ellipsisTxt) > maxLen
    backN = max(1, maxLen - frontN - numel(ellipsisTxt));
end

out = [in(1:frontN) ellipsisTxt in(end-backN+1:end)];
end
