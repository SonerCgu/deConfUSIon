function [Q,info] = deConfUSIon_build_compcor_regressors(Y, spatialSize, finiteMask, baseMean, t, bIdx, opts, R)
% Build Global / tCompCor / aCompCor / Random / Low-variance CompCor regressors.
if nargin < 8 || isempty(R), R = zeros(size(Y,2),0); end
T = size(Y,2); V = size(Y,1);
finiteMask = logical(finiteMask(:));
mode = lower(localGet(opts,'compcorMode','tcompcor'));
K = max(1,round(double(localGet(opts,'nComp',5))));
frac = double(localGet(opts,'compcorFrac',0.05));
if frac > 1, frac = frac/100; end
frac = max(0.001,min(0.95,frac));
protect = logical(localGet(opts,'protectResponse',true));
respCorrThr = double(localGet(opts,'responseExcludeCorr',0.20));
brainMask = finiteMask;
if isfield(opts,'brainMask') && ~isempty(opts.brainMask)
    brainMask = localMask(opts.brainMask,spatialSize,V) & finiteMask;
end
cand = find(brainMask);
if numel(cand) < 20, cand = find(finiteMask); end
if numel(cand) < 20, error('deConfUSIon:CompCorNoVoxels','Too few finite voxels for CompCor.'); end

info = struct('mode',mode,'source','','nVoxels',0,'nComponents',0, ...
    'variancePercent',NaN,'excludedResponseVoxels',0,'maxResponseCorrelation',NaN);

if strcmp(mode,'global') || strcmp(mode,'gsr')
    q = mean(double(Y(cand,:)),1)';
    q = localResidual(q,localProtect(t,R,protect));
    Q = localZ(q);
    info.mode = 'global'; info.source = 'brain global signal';
    info.nVoxels = numel(cand); info.nComponents = 1;
    info.maxResponseCorrelation = localMaxCorr(Q,R);
    return;
end

refIdx = [];
if isfield(opts,'refMask') && ~isempty(opts.refMask)
    refIdx = find(localMask(opts.refMask,spatialSize,V) & finiteMask);
end

switch mode
    case {'acompcor','a_compcor','anatomical'}
        if isempty(refIdx)
            error('deConfUSIon:aCompCorNeedsMask', ...
                'aCompCor needs a manually selected non-responsive/WM-CSF-like ROI. Use tCompCor or Low-variance for automatic mode.');
        end
        noiseIdx = refIdx;
        info.source = 'manual anatomical / non-responsive ROI';

    case {'tcompcor','t_compcor','highvar'}
        sd = localVoxelStd(Y,cand,localProtect(t,R,protect));
        n = max(20,round(frac*numel(cand)));
        [~,ord] = sort(sd,'descend');
        noiseIdx = cand(ord(1:min(n,numel(ord))));
        info.source = sprintf('highest temporal SD %.2g%% voxels',100*frac);

    case {'lowvar','lowvariance','low_variance'}
        sd = localVoxelStd(Y,cand,localProtect(t,R,protect));
        n = max(20,round(frac*numel(cand)));
        [~,ord] = sort(sd,'ascend');
        noiseIdx = cand(ord(1:min(n,numel(ord))));
        info.source = sprintf('lowest temporal SD %.2g%% voxels',100*frac);

    case {'random','randomcompcor'}
        n = max(20,round(frac*numel(cand)));
        if ~isempty(refIdx), n = numel(refIdx); end
        savedRng=rng; rngCleanup=onCleanup(@()rng(savedRng)); %#ok<NASGU>
        rng(round(double(localGet(opts,'randomSeed',1))));
        ord = randperm(numel(cand),min(n,numel(cand)));
        noiseIdx = cand(ord);
        info.source = sprintf('random size-matched mask, n=%d',numel(noiseIdx));

    otherwise
        error('deConfUSIon:BadCompCorMode','Unknown CompCor mode: %s',mode);
end

if protect && ~isempty(R) && ~isempty(noiseIdx)
    Yn0 = double(Y(noiseIdx,:))';
    Yn0 = localResidual(Yn0,localProtect(t,zeros(T,0),true));
    c = localMaxCorrPerVoxel(Yn0,R);
    bad = c > respCorrThr;
    info.excludedResponseVoxels = sum(bad);
    noiseIdx(bad) = [];
end

if numel(noiseIdx) < 20
    error('deConfUSIon:NoiseRegionTooSmall','Noise region has only %d voxels after response protection.',numel(noiseIdx));
end

Yn = double(Y(noiseIdx,:))';
Yn = localResidual(Yn,localProtect(t,R,protect));
Yn = bsxfun(@minus,Yn,mean(Yn,1));
sd = std(Yn,0,1); keep = sd > sqrt(eps);
Yn = Yn(:,keep); sd = sd(keep);
Yn = bsxfun(@rdivide,Yn,sd);
if size(Yn,2) < 2, error('deConfUSIon:CompCorDegenerate','Too few variable noise voxels.'); end
[U,S,~] = svd(Yn,'econ');
ev = diag(S).^2;
K = min(K,size(U,2));
Q = U(:,1:K);
Q = localResidual(Q,localProtect(t,R,protect));
Q = localOrtho(Q);
if isempty(Q), error('deConfUSIon:CompCorEmpty','CompCor regressors were removed by response protection.'); end
info.nVoxels = numel(noiseIdx);
info.nComponents = size(Q,2);
if sum(ev)>0, info.variancePercent = 100*sum(ev(1:K))/sum(ev); end
info.maxResponseCorrelation = localMaxCorr(Q,R);
end

function P = localProtect(t,R,protect)
if protect, P = localOrtho([ones(numel(t),1),double(R)]); else, P = localOrtho(ones(numel(t),1)); end
end

function m = localMask(M,spatialSize,V)
if numel(M) ~= V && ~isequal(size(M),spatialSize), error('deConfUSIon:MaskMismatch','Mask size mismatch.'); end
m = logical(M(:));
end

function sd = localVoxelStd(Y,idx,P)
X = double(Y(idx,:))';
X = localResidual(X,P);
sd = std(X,0,1);
end

function X = localResidual(X,P)
if ~isempty(P), X = X - P*(P\X); end
end

function Q = localOrtho(X)
if isempty(X), Q = zeros(size(X,1),0); return; end
X = double(X); X(:,~all(isfinite(X),1)) = [];
X(:,std(X,0,1)<sqrt(eps)) = [];
if isempty(X), Q = zeros(size(X,1),0); return; end
[Q,R] = qr(X,0);
keep = abs(diag(R)) > max(size(X))*eps(max(1,norm(R,'fro')));
Q = Q(:,keep);
end

function Z = localZ(X)
X = double(X);
X = bsxfun(@minus,X,mean(X,1));
s = std(X,0,1); s(s==0)=1;
Z = bsxfun(@rdivide,X,s);
end

function c = localMaxCorr(A,B)
if isempty(A) || isempty(B), c = NaN; return; end
A = localZ(A); B = localZ(B);
C = abs(A'*B)/max(1,size(A,1)-1);
c = max(C(:));
end

function c = localMaxCorrPerVoxel(A,R)
if isempty(R), c = zeros(1,size(A,2)); return; end
A = localZ(A); R = localZ(R);
C = abs(A'*R)/max(1,size(A,1)-1);
c = max(C,[],2)';
end

function v = localGet(s,n,d)
if isfield(s,n) && ~isempty(s.(n)), v = s.(n); else, v = d; end
end
