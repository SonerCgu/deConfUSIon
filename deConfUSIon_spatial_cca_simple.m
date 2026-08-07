function [A,info] = deConfUSIon_spatial_cca_simple(Y, spatialSize, finiteMask, opts, R)
% Paper-style fUS spatial CCA: functional area vs noise area.
% Uses separate SVD whitening and returns common temporal modes as nuisance regressors.
if nargin < 5 || isempty(R), R = zeros(size(Y,2),0); end
T = size(Y,2); V = size(Y,1);
finiteMask = logical(finiteMask(:));
if ~isfield(opts,'ccaNoiseMask') || isempty(opts.ccaNoiseMask)
    error('deConfUSIon:NeedCCANoiseMask','Spatial CCA requires a painted noise/non-functional ROI.');
end
noise = localMask(opts.ccaNoiseMask,spatialSize,V) & finiteMask;
if isfield(opts,'brainMask') && ~isempty(opts.brainMask)
    func = localMask(opts.brainMask,spatialSize,V) & finiteMask & ~noise;
else
    func = finiteMask & ~noise;
end
fi = find(func); ni = find(noise);
if numel(fi)<20 || numel(ni)<20
    error('deConfUSIon:CCAMaskSmall','Need >=20 functional and >=20 noise voxels for CCA.');
end
maxV = max(100,round(double(localGet(opts,'ccaMaxVoxels',2500))));
fi = localSubsample(fi,maxV); ni = localSubsample(ni,maxV);
P = localOrtho([ones(T,1),double(R)]);
Xf = localResidual(double(Y(fi,:))',P);
Xn = localResidual(double(Y(ni,:))',P);
Xf = localZvox(Xf); Xn = localZvox(Xn);
[Uf,~,~] = svd(Xf,'econ');
[Un,~,~] = svd(Xn,'econ');
rankW = max(2,round(double(localGet(opts,'ccaWhitenRank',50))));
Uf = Uf(:,1:min(rankW,size(Uf,2)));
Un = Un(:,1:min(rankW,size(Un,2)));
G = Uf*Uf' + Un*Un'; G = (G+G')/2;
[U,S] = eig(G); [ev,ord] = sort(real(diag(S)),'descend'); U = real(U(:,ord));
th = max(1,round(double(localGet(opts,'ccaThreshold',10))));
nPos = sum(ev > max(eps,max(ev)*1e-12));
th = min([th,nPos,size(U,2)]);
if th < 1, error('deConfUSIon:CCANoModes','No CCA modes found.'); end
A = U(:,1:th);
A = localResidual(A,P); A = localOrtho(A);
info = struct('nCCA',size(A,2),'nFunctional',numel(fi),'nNoise',numel(ni),'threshold',th);
end

function X = localZvox(X)
X = bsxfun(@minus,X,mean(X,1));
s = std(X,0,1); X = X(:,s>sqrt(eps)); s = s(s>sqrt(eps));
X = bsxfun(@rdivide,X,s);
end

function idx = localSubsample(idx,n)
if numel(idx)>n, idx = idx(unique(round(linspace(1,numel(idx),n)))); end
end

function m = localMask(M,spatialSize,V)
if numel(M) ~= V && ~isequal(size(M),spatialSize), error('deConfUSIon:MaskMismatch','Mask size mismatch.'); end
m = logical(M(:));
end

function X = localResidual(X,P)
if ~isempty(P), X = X - P*(P\X); end
end

function Q = localOrtho(X)
if isempty(X), Q = zeros(size(X,1),0); return; end
X = double(X); X(:,~all(isfinite(X),1))=[]; X(:,std(X,0,1)<sqrt(eps))=[];
if isempty(X), Q = zeros(size(X,1),0); return; end
[Q,R] = qr(X,0); keep = abs(diag(R)) > max(size(X))*eps(max(1,norm(R,'fro'))); Q = Q(:,keep);
end

function v = localGet(s,n,d)
if isfield(s,n) && ~isempty(s.(n)), v = s.(n); else, v = d; end
end
