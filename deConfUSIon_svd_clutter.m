function [Iout, stats, model] = deConfUSIon_svd_clutter(I, TR, opts)
% deConfUSIon_svd_clutter  Spatiotemporal SVD clutter filtering.
%
%   [Iout,stats,model] = deConfUSIon_svd_clutter(I,TR,opts)
%
% I must be [Y X T] or [Y X Z T], with time last. The exact Demene et al.
% clutter filter is intended for beamformed complex IQ cine data before
% Power-Doppler integration. Applying SVD to real Power-Doppler/fUSI time
% series is experimental and can remove genuine global haemodynamic signal.
%
% Important opts fields:
%   cutoffPercent : first percentage of temporal singular vectors removed
%   nReject       : exact number removed (overrides cutoffPercent)
%   scope         : 'joint' or 'per-slice'
%   centerMode    : 'none' (paper/IQ) or 'voxelmean' (subtract and restore)
%   mask          : optional 2-D/3-D logical estimation mask
%   chunkVoxels   : processing chunk size (default 20000)
%   computeOnly   : compute decomposition without reconstructing output
%   model         : reuse a previously computed compatible model
%
% The decomposition is estimated from S'*S, avoiding a full spatial U matrix.

if nargin < 2 || isempty(TR), TR = 1; end
if nargin < 3 || isempty(opts), opts = struct(); end

validateattributes(I, {'numeric','logical'}, {'nonempty'}, mfilename, 'I');
if ndims(I) < 3 || ndims(I) > 4
    error('deConfUSIon:SVD:Dimensions', ...
        'I must be [Y X T] or [Y X Z T], with time in the last dimension.');
end

TR = double(TR(1));
if ~isfinite(TR) || TR <= 0, TR = 1; end

opts = localDefaults(opts, I);
sz = size(I);
T = sz(end);
if T < 4
    error('deConfUSIon:SVD:TooShort','At least 4 temporal frames are required.');
end

if isfield(opts,'model') && isstruct(opts.model) && ~isempty(opts.model)
    model = opts.model;
    localCheckModel(model, sz, opts);
else
    model = localBuildModel(I, TR, opts);
end

stats = localStatsFromModel(model, opts);

if opts.computeOnly
    Iout = [];
    return;
end

startT = tic;
Iout = localApplyModel(I, model, opts);
stats.processingTime = toc(startT);
stats.outputClass = class(Iout);
stats.wasComplex = ~isreal(I);
end

% -------------------------------------------------------------------------
function opts = localDefaults(opts, I)
if ~isfield(opts,'cutoffPercent') || isempty(opts.cutoffPercent), opts.cutoffPercent = 20; end
if ~isfield(opts,'nReject'), opts.nReject = []; end
if ~isfield(opts,'scope') || isempty(opts.scope)
    if ndims(I) == 4 && size(I,3) > 1, opts.scope = 'per-slice'; else, opts.scope = 'joint'; end
end
if ~isfield(opts,'centerMode') || isempty(opts.centerMode)
    if isreal(I), opts.centerMode = 'voxelmean'; else, opts.centerMode = 'none'; end
end
if ~isfield(opts,'mask'), opts.mask = []; end
if ~isfield(opts,'chunkVoxels') || isempty(opts.chunkVoxels), opts.chunkVoxels = 20000; end
if ~isfield(opts,'computeOnly') || isempty(opts.computeOnly), opts.computeOnly = false; end
if ~isfield(opts,'verbose') || isempty(opts.verbose), opts.verbose = false; end

opts.cutoffPercent = max(0,min(95,double(opts.cutoffPercent(1))));
opts.chunkVoxels = max(1000,round(double(opts.chunkVoxels(1))));
opts.scope = lower(strtrim(char(opts.scope)));
opts.centerMode = lower(strtrim(char(opts.centerMode)));
if ~ismember(opts.scope,{'joint','per-slice'})
    error('deConfUSIon:SVD:Scope','scope must be ''joint'' or ''per-slice''.');
end
if ~ismember(opts.centerMode,{'none','voxelmean'})
    error('deConfUSIon:SVD:Center','centerMode must be ''none'' or ''voxelmean''.');
end
end

% -------------------------------------------------------------------------
function model = localBuildModel(I, TR, opts)
sz = size(I);
T = sz(end);
model = struct();
model.version = 'deConfUSIon_SVD_v1';
model.inputSize = sz;
model.TR = TR;
model.scope = opts.scope;
model.centerMode = opts.centerMode;
model.created = datestr(now,30);
model.isComplex = ~isreal(I);
model.blocks = {};

if strcmp(opts.scope,'joint') || ndims(I) == 3
    X = reshape(I,[],T);
    maskVec = localMaskForJoint(opts.mask, sz);
    model.blocks{1} = localComputeBlock(X, maskVec, TR, opts);
    model.blockLabels = {'all'};
else
    Z = sz(3);
    model.blocks = cell(1,Z);
    model.blockLabels = cell(1,Z);
    for z = 1:Z
        X = reshape(I(:,:,z,:),[],T);
        maskVec = localMaskForSlice(opts.mask, sz, z);
        model.blocks{z} = localComputeBlock(X, maskVec, TR, opts);
        model.blockLabels{z} = sprintf('slice_%02d',z);
        if opts.verbose
            fprintf('[SVD] computed slice %d/%d\n',z,Z);
        end
    end
end
end

% -------------------------------------------------------------------------
function B = localComputeBlock(X, maskVec, TR, opts)
[nV,T] = size(X);
if isempty(maskVec), maskVec = true(nV,1); else, maskVec = logical(maskVec(:)); end
if numel(maskVec) ~= nV
    error('deConfUSIon:SVD:MaskSize','Estimation mask does not match the spatial dimensions.');
end
rows = find(maskVec);
if isempty(rows), rows = (1:nV)'; end

C = zeros(T,T,'double');
nUsed = 0;
for a = 1:opts.chunkVoxels:numel(rows)
    rr = rows(a:min(numel(rows),a+opts.chunkVoxels-1));
    Xi = double(X(rr,:));
    Xi = localFillNonfinite(Xi);
    keep = sum(abs(Xi).^2,2) > eps;
    Xi = Xi(keep,:);
    if isempty(Xi), continue; end
    if strcmp(opts.centerMode,'voxelmean')
        Xi = Xi - mean(Xi,2);
    end
    C = C + Xi' * Xi;
    nUsed = nUsed + size(Xi,1);
end

if nUsed < 1 || ~any(abs(C(:)) > 0)
    error('deConfUSIon:SVD:Empty','No non-zero finite voxels were available for SVD estimation.');
end
C = (C + C')/2;
[V,D] = eig(C,'vector');
d = real(D(:));
[d,ord] = sort(d,'descend');
d(d < 0 & d > -max(eps,max(abs(d)))*1e-10) = 0;
d = max(d,0);
V = V(:,ord);
lambda = sqrt(d);

% Normalize phase/sign to make component plots stable.
for k = 1:size(V,2)
    [~,im] = max(abs(V(:,k)));
    if abs(V(im,k)) > 0
        if isreal(V)
            if V(im,k) < 0, V(:,k) = -V(:,k); end
        else
            V(:,k) = V(:,k) .* exp(-1i*angle(V(im,k)));
        end
    end
end

freq = localFrequencyMetrics(V,TR);
elbowK = localElbow(lambda);

B = struct();
B.V = V;
B.singularValues = lambda;
B.energy = d;
B.energyFraction = d ./ max(eps,sum(d));
B.cumulativeEnergy = cumsum(B.energyFraction);
B.frequency = freq;
B.elbowK = elbowK;
B.elbowPercent = 100*elbowK/T;
B.nTime = T;
B.nVoxelsUsed = nUsed;
B.maskFraction = nUsed/max(1,nV);
end

% -------------------------------------------------------------------------
function Iout = localApplyModel(I, model, opts)
sz = size(I);
T = sz(end);
Iout = zeros(sz,'like',I);

if strcmp(model.scope,'joint') || ndims(I) == 3
    X = reshape(I,[],T);
    Y = localApplyBlock(X, model.blocks{1}, opts);
    Iout = reshape(localCastLike(Y,I),sz);
else
    Z = sz(3);
    for z = 1:Z
        X = reshape(I(:,:,z,:),[],T);
        Y = localApplyBlock(X, model.blocks{z}, opts);
        Iout(:,:,z,:) = reshape(localCastLike(Y,I),sz(1),sz(2),1,T);
    end
end
end

% -------------------------------------------------------------------------
function Y = localApplyBlock(X, B, opts)
[nV,T] = size(X);
k = localRejectCount(T,opts);
Vrej = B.V(:,1:k);
Y = zeros(nV,T,'like',X);
if ~isreal(X), Y = complex(Y); end

for a = 1:opts.chunkVoxels:nV
    rr = a:min(nV,a+opts.chunkVoxels-1);
    Xi = double(X(rr,:));
    Xi = localFillNonfinite(Xi);
    if strcmp(opts.centerMode,'voxelmean')
        mu = mean(Xi,2);
        Xc = Xi - mu;
        if k > 0, Xc = Xc - (Xc*Vrej)*Vrej'; end
        Yi = Xc + mu;
    else
        Yi = Xi;
        if k > 0, Yi = Yi - (Yi*Vrej)*Vrej'; end
    end
    Y(rr,:) = Yi;
end
end

% -------------------------------------------------------------------------
function k = localRejectCount(T,opts)
if isfield(opts,'nReject') && ~isempty(opts.nReject) && isfinite(double(opts.nReject(1)))
    k = round(double(opts.nReject(1)));
else
    k = round(T*double(opts.cutoffPercent)/100);
end
k = max(0,min(T-1,k));
end

% -------------------------------------------------------------------------
function stats = localStatsFromModel(model, opts)
T = model.inputSize(end);
k = localRejectCount(T,opts);
stats = struct();
stats.method = 'spatiotemporal SVD clutter filtering';
stats.scope = model.scope;
stats.centerMode = model.centerMode;
stats.TR = model.TR;
stats.nFrames = T;
stats.nRejected = k;
stats.cutoffPercent = 100*k/T;
stats.paperReferencePercent = 20;
stats.paperReferenceNote = ['Demene et al. Fig. 5 removed 49 of 250 components (~19.6%) ' ...
    'for one rat IQ cine; this is a starting point, not a universal threshold.'];
stats.isComplexInput = model.isComplex;
stats.experimentalOnPowerDoppler = ~model.isComplex;
stats.processingTime = NaN;

if numel(model.blocks) == 1
    B = model.blocks{1};
    stats.singularValues = B.singularValues;
    stats.energyFraction = B.energyFraction;
    stats.cumulativeEnergy = B.cumulativeEnergy;
    stats.centralFrequencyHz = B.frequency.centralHz;
    stats.centralFrequencyFractionNyquist = B.frequency.centralFractionNyquist;
    stats.peakFrequencyHz = B.frequency.peakHz;
    stats.lowFrequencyFraction = B.frequency.lowFraction;
    stats.elbowK = B.elbowK;
    stats.elbowPercent = B.elbowPercent;
else
    Z = numel(model.blocks);
    stats.singularValues = cell(1,Z);
    stats.centralFrequencyHz = cell(1,Z);
    stats.elbowK = zeros(1,Z);
    stats.elbowPercent = zeros(1,Z);
    for z = 1:Z
        B = model.blocks{z};
        stats.singularValues{z} = B.singularValues;
        stats.centralFrequencyHz{z} = B.frequency.centralHz;
        stats.elbowK(z) = B.elbowK;
        stats.elbowPercent(z) = B.elbowPercent;
    end
end
end

% -------------------------------------------------------------------------
function F = localFrequencyMetrics(V,TR)
T = size(V,1);
fs = 1/TR;
f = ((0:T-1) - floor(T/2))*(fs/T);
P = abs(fftshift(fft(V,[],1),1)).^2;
den = sum(P,1) + eps;
central = sum(abs(f(:)).*P,1)./den;
[~,ip] = max(P,[],1);
peak = abs(f(ip));
nyq = fs/2;
lowCut = 0.05*nyq;
low = sum(P(abs(f)<=lowCut,:),1)./den;
centralFrac = central/max(eps,nyq);
F = struct('centralHz',central(:)', ...
           'centralFractionNyquist',centralFrac(:)', ...
           'peakHz',peak(:)', ...
           'lowFraction',low(:)', ...
           'nyquistHz',nyq);
end

% -------------------------------------------------------------------------
function k = localElbow(lambda)
T = numel(lambda);
N = min(T,max(8,round(0.40*T)));
y = 20*log10(lambda(1:N)/max(eps,lambda(1)) + eps);
x = (1:N)';
p1 = [x(1) y(1)]; p2 = [x(end) y(end)];
v = p2-p1;
if norm(v) < eps, k = max(1,round(0.1*T)); return; end
d = abs(v(1)*(p1(2)-y) - (p1(1)-x)*v(2))/norm(v);
[~,k] = max(d);
k = max(1,min(T-1,k));
end

% -------------------------------------------------------------------------
function X = localFillNonfinite(X)
bad = ~isfinite(X);
if ~any(bad(:)), return; end
X(bad) = 0;
end

% -------------------------------------------------------------------------
function maskVec = localMaskForJoint(M, sz)
maskVec = [];
if isempty(M), return; end
M = logical(squeeze(M));
if ndims(M) == 2 && numel(sz) == 3 && isequal(size(M),sz(1:2))
    maskVec = M(:);
elseif ndims(M) == 2 && numel(sz) == 4 && isequal(size(M),sz(1:2))
    maskVec = repmat(M,[1 1 sz(3)]); maskVec = maskVec(:);
elseif ndims(M) == 3 && numel(sz) == 4 && isequal(size(M),sz(1:3))
    maskVec = M(:);
end
end

% -------------------------------------------------------------------------
function maskVec = localMaskForSlice(M, sz, z)
maskVec = [];
if isempty(M), return; end
M = logical(squeeze(M));
if ndims(M) == 2 && isequal(size(M),sz(1:2))
    maskVec = M(:);
elseif ndims(M) == 3 && isequal(size(M),sz(1:3))
    maskVec = M(:,:,z); maskVec = maskVec(:);
end
end

% -------------------------------------------------------------------------
function localCheckModel(model, sz, opts)
if ~isfield(model,'inputSize') || ~isequal(double(model.inputSize),double(sz))
    error('deConfUSIon:SVD:ModelSize','Cached SVD model does not match the current input size.');
end
if ~strcmpi(model.scope,opts.scope) || ~strcmpi(model.centerMode,opts.centerMode)
    error('deConfUSIon:SVD:ModelOptions','Cached SVD model scope/centering does not match current options.');
end
end

% -------------------------------------------------------------------------
function Y = localCastLike(X, ref)
if isa(ref,'single'), Y = single(X);
elseif isa(ref,'double'), Y = double(X);
else, Y = cast(X,class(ref));
end
end
