function stats = deConfUSIon_pacap_common_drift_stats(stats,I,outI,TR,opts)
% Adds common driftcompensation stats fields expected by fusi_studio_GUI.
if nargin < 5 || isempty(opts), opts = struct(); end
if nargin < 4 || isempty(TR) || ~isfinite(double(TR)), TR = 1; end
TR = double(TR);

dims = size(I);
T = dims(end);
V = prod(dims(1:end-1));
t = ((0:T-1)' * TR);
Y0 = double(reshape(single(I),[V T]));
Y1 = double(reshape(single(outI),[V T]));

if isfield(stats,'baselineSec') && ~isempty(stats.baselineSec)
    bsec = stats.baselineSec;
elseif isfield(opts,'baselineSec') && ~isempty(opts.baselineSec)
    bsec = opts.baselineSec;
else
    bsec = [0 min(60,t(end))];
end
b1 = double(bsec(1));
b2 = double(bsec(end));
bIdx = t >= b1 & t <= b2;
if nnz(bIdx) < 3, bIdx = 1:min(10,T); end

base = localMean(Y0(:,bIdx),2);
bad = ~isfinite(base) | abs(base) < eps;
base(bad) = 1;

P0 = 100 * (bsxfun(@rdivide,Y0,base) - 1);
P1 = 100 * (bsxfun(@rdivide,Y1,base) - 1);
P0(~isfinite(P0)) = NaN;
P1(~isfinite(P1)) = NaN;

mask = all(isfinite(Y0),2) & ~bad;
if isfield(opts,'brainMask') && ~isempty(opts.brainMask) && numel(opts.brainMask)==V
    mask = mask & logical(opts.brainMask(:));
end
if nnz(mask) < 10
    mask = all(isfinite(Y0),2) & ~bad;
end
if nnz(mask) < 10
    mask = true(V,1);
end

g0 = localMedian(P0(mask,:),1);
g1 = localMedian(P1(mask,:),1);
removed = g0 - g1;

stats.driftRangeBefore = localRange(g0);
stats.driftRangeAfter  = localRange(g1);
stats.driftRangeRemoved = localRange(removed);
stats.driftReductionPercent = 100 * (stats.driftRangeBefore - stats.driftRangeAfter) ./ max(stats.driftRangeBefore,eps);

stats.globalPSCBefore = g0;
stats.globalPSCAfter = g1;
stats.globalPSCRemoved = removed;

stats.baselineSec = [b1 b2];
stats.TR = TR;
stats.nFrames = T;
stats.nVoxelsUsedForStats = nnz(mask);
stats.fitIdx = (1:T)';

% Extra fields that some GUI/logging versions may ask for.
stats.driftBefore = stats.driftRangeBefore;
stats.driftAfter = stats.driftRangeAfter;
stats.driftRange = [stats.driftRangeBefore stats.driftRangeAfter];
stats.percentReduction = stats.driftReductionPercent;
stats.commonStatsAdded = true;

if ~isfield(stats,'method') || isempty(stats.method)
    stats.method = 'pacap_response';
end
end

function m = localMean(X,dim)
if nargin < 2, dim = 1; end
M = isfinite(X);
X(~M) = 0;
n = sum(M,dim);
n(n==0) = NaN;
m = sum(X,dim) ./ n;
end

function m = localMedian(X,dim)
if nargin < 2, dim = 1; end
if dim == 1
    m = zeros(1,size(X,2));
    for k = 1:size(X,2)
        a = X(:,k);
        a = a(isfinite(a));
        if isempty(a), m(k) = NaN; else, m(k) = median(a); end
    end
else
    m = zeros(size(X,1),1);
    for k = 1:size(X,1)
        a = X(k,:);
        a = a(isfinite(a));
        if isempty(a), m(k) = NaN; else, m(k) = median(a); end
    end
end
end

function r = localRange(x)
x = x(isfinite(x));
if isempty(x)
    r = NaN;
else
    r = max(x) - min(x);
end
end
