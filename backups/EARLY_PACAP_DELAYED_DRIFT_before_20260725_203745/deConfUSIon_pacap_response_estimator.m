function [outI, stats] = deConfUSIon_pacap_response_estimator(I,TR,exportPath,opts)
% PACAP response estimator for fUSI/deConfUSIon.
% Estimates PACAP-specific response while modelling drift and nuisance separately.

if nargin < 4 || isempty(opts), opts = struct(); end
if nargin < 3, exportPath = ''; end
if nargin < 2 || isempty(TR) || ~isfinite(double(TR)), TR = 1; end
TR = double(TR);

dims = size(I);
T = dims(end);
V = prod(dims(1:end-1));
spatialSize = dims(1:end-1);
t = ((0:T-1)' * TR);
Yraw = reshape(single(I),[V T]);
Y = double(Yraw);

bsec = localGet(opts,'baselineSec',[0 min(60,t(end))]);
b1 = double(bsec(1)); b2 = double(bsec(end));
bIdx = t >= b1 & t <= b2;
if nnz(bIdx) < 3
    error('PACAP:BadBaseline','Baseline window gives fewer than 3 frames.');
end

finiteMask = all(isfinite(Y),2);
baseMean = localNanMean(Y(:,bIdx),2);
bad = ~isfinite(baseMean) | abs(baseMean) < eps;
finiteMask(bad) = false;
baseMean(bad) = 1;

Ypsc = 100 * (bsxfun(@rdivide,Y,baseMean) - 1);
Ypsc(~isfinite(Ypsc)) = 0;

ti = double(localGet(opts,'injectionSec',b2));
respSec = double(localGet(opts,'responseSec',min(180,max(TR,t(end)-ti))));
if ~isfinite(ti) || ti < 0 || ti >= t(end)
    error('PACAP:BadInjection','Injection time %.3f s is outside run.',ti);
end
if ~isfinite(respSec) || respSec <= 0, respSec = min(180,max(TR,t(end)-ti)); end

polyOrder = round(double(localGet(opts,'polyOrder',1)));
polyOrder = max(0,min(5,polyOrder));
x = linspace(-1,1,T)';
D = ones(T,1);
for p = 1:polyOrder
    q = x.^p;
    q = q - mean(q);
    s = std(q); if s > 0, q = q ./ s; end
    D = [D q]; %#ok<AGROW>
end

R = localPACAPBasis(t,TR,ti,respSec);
R = localZ(R);
nD = size(D,2);
nR = size(R,2);

[A, artifactInfo] = localArtifactRegressors(Ypsc,spatialSize,finiteMask,t,TR,opts,R,D);
nA = size(A,2);

X = [D R A];
stats = struct();
stats.method = 'pacap_response';
stats.baselineSec = [b1 b2];
stats.injectionSec = ti;
stats.responseSec = respSec;
stats.polyOrder = polyOrder;
stats.nDrift = nD;
stats.nResponse = nR;
stats.nArtifact = nA;
stats.designLabels = [{'intercept'}, localDriftLabels(polyOrder), localRespLabels(nR), artifactInfo.labels];
stats.designRank = rank(X);
stats.designColumns = size(X,2);
stats.designCondition = cond(X);
stats.artifactInfo = artifactInfo;

if stats.designRank < stats.designColumns
    warning('PACAP:RankDeficient','PACAP model is rank deficient. Results are least-squares but interpret cautiously.');
end

Xz = localZ(X(:,2:end));
if nA > 0
    rCols = nD:(nD+nR-1);
    aCols = (nD+nR):(nD+nR+nA-1);
    C = abs(Xz(:,aCols)' * Xz(:,rCols)) / max(1,T-1);
    stats.maxArtifactResponseCorrelation = max(C(:));
else
    stats.maxArtifactResponseCorrelation = NaN;
end

if isfinite(stats.maxArtifactResponseCorrelation) && stats.maxArtifactResponseCorrelation > 0.8
    warning('PACAP:ArtifactResponseCollinear', ...
        'Artifact and PACAP response model are %.0f%% correlated. Use vehicle/control or exclude scan.', ...
        100*stats.maxArtifactResponseCorrelation);
end

chunk = round(double(localGet(opts,'chunkVoxels',5000)));
chunk = max(500,min(50000,chunk));
Ycorr = zeros(V,T,'single');
Yremoved = zeros(V,T,'single');
betaMaps = zeros(V,nR,'single');
ampMap = zeros(V,1,'single');
aucMap = zeros(V,1,'single');
rWin = t >= ti & t <= min(t(end),ti+respSec);
if nnz(rWin) < 2, rWin = t >= ti; end

for c0 = 1:chunk:V
    c1 = min(V,c0+chunk-1);
    blk = double(Ypsc(c0:c1,:))';
    beta = X \ blk;

    nuisance = zeros(T,size(blk,2));
    if nD > 1
        nuisance = nuisance + D(:,2:end) * beta(2:nD,:);
    end
    if nA > 0
        nuisance = nuisance + A * beta(nD+nR+1:nD+nR+nA,:);
    end

    respPred = R * beta(nD+1:nD+nR,:);
    Ycorr(c0:c1,:) = single((blk - nuisance)');
    Yremoved(c0:c1,:) = single(nuisance');
    betaMaps(c0:c1,:) = single(beta(nD+1:nD+nR,:)');
    ampMap(c0:c1) = single(max(respPred(rWin,:),[],1) - localNanMedian(respPred(bIdx,:),1));
    aucMap(c0:c1) = single(trapz(t(rWin),respPred(rWin,:),1));
end

outY = bsxfun(@times,1 + double(Ycorr)/100,baseMean);
outY(~isfinite(outY)) = double(Yraw(~isfinite(outY)));
outY(~finiteMask,:) = double(Yraw(~finiteMask,:));
outI = reshape(single(outY),dims);

stats.pacapBetaMapsPSC = reshape(betaMaps,[spatialSize nR]);
stats.pacapAmplitudeMapPSC = reshape(ampMap,spatialSize);
stats.pacapAUCMapPSCsec = reshape(aucMap,spatialSize);
stats.removedNuisancePSC = reshape(Yremoved,dims);
stats.correctedPSC = reshape(Ycorr,dims);
stats.note = 'Use pacapAmplitudeMapPSC / pacapBetaMapsPSC as primary PACAP estimate; corrected movie is secondary QC.';

try
    if ~isempty(exportPath) && exist(exportPath,'dir')==7
        saveFile = fullfile(exportPath,['PACAP_Response_Estimator_' datestr(now,'yyyymmdd_HHMMSS') '.mat']);
        save(saveFile,'stats','-v7.3');
        stats.savedFile = saveFile;
    end
catch ME
    stats.saveWarning = ME.message;
end
end

function R = localPACAPBasis(t,TR,ti,L)
dt = max(0,t-ti);
tau = max(TR,L/4);
r1 = (dt./tau).^2 .* exp(-dt./tau);
r1(t<ti) = 0;
if max(r1)>0, r1 = r1 ./ max(r1); end
r2 = double(t>=ti & t<=ti+L);
w = max(1,round((L/8)/TR));
if w > 1, r2 = movmean(r2,w,'Endpoints','shrink'); end
if max(r2)>0, r2 = r2 ./ max(r2); end
r3 = 1-exp(-dt./max(TR,L/3));
r3(t<ti) = 0;
if max(r3)>0, r3 = r3 ./ max(r3); end
R = [r1 r2 r3];
R = R(:,std(R,0,1)>sqrt(eps));
end

function [A,info] = localArtifactRegressors(Ypsc,spatialSize,finiteMask,t,TR,opts,R,D)
T = numel(t); V = size(Ypsc,1);
mode = lower(char(localGet(opts,'artifactMode','auto')));
A = zeros(T,0); labels = {};
P = localOrtho([D R]);
ti = double(localGet(opts,'injectionSec',t(round(numel(t)/4))));

autoModes = {'auto','auto_roi','auto_custom','auto_spatial_cca'};
roiModes = {'roi','auto_roi'};
customModes = {'custom','auto_custom'};
ccaModes = {'spatial_cca','auto_spatial_cca'};
vehModes = {'vehicle','auto_vehicle'};

if any(strcmp(mode,autoModes))
    pulseSec = double(localGet(opts,'artifactPulseSec',5));
    taus = double(localGet(opts,'artifactExpTauSec',[5 20 60]));
    dt = max(0,t-ti);
    pulse = double(t>=ti & t<ti+pulseSec);
    A = [A pulse(:)]; labels{end+1} = 'inj_pulse';
    for k = 1:numel(taus)
        if isfinite(taus(k)) && taus(k)>0
            e = exp(-dt./taus(k)); e(t<ti)=0;
            A = [A e(:)]; labels{end+1}=sprintf('inj_exp_%g',taus(k)); %#ok<AGROW>
        end
    end
    if logical(localGet(opts,'artifactPersistent',false))
        s = double(t>=ti); A=[A s(:)]; labels{end+1}='persistent_step';
    end
    if logical(localGet(opts,'artifactPlateau',true))
        ramp = min(1,dt./max(TR,double(localGet(opts,'responseSec',180))/3));
        ramp(t<ti)=0; A=[A ramp(:)]; labels{end+1}='slow_plateau';
    end
end

if any(strcmp(mode,roiModes))
    if ~isfield(opts,'artifactMask') || isempty(opts.artifactMask)
        error('PACAP:NeedArtifactROI','Artifact ROI mode requires opts.artifactMask.');
    end
    idx = localMaskIdx(opts.artifactMask,spatialSize,V,finiteMask);
    K = max(1,round(double(localGet(opts,'artifactNPC',3))));
    Q = localPCs(double(Ypsc(idx,:))',P,K);
    A = [A Q];
    for k=1:size(Q,2), labels{end+1}=sprintf('artifactROI_PC%d',k); end %#ok<AGROW>
end

if any(strcmp(mode,customModes))
    if ~isfield(opts,'customArtifactFile') || isempty(opts.customArtifactFile)
        error('PACAP:NeedCustom','Custom artifact mode requires opts.customArtifactFile.');
    end
    C = localReadCustom(opts.customArtifactFile,T);
    A = [A C];
    for k=1:size(C,2), labels{end+1}=sprintf('custom_%d',k); end %#ok<AGROW>
end

if any(strcmp(mode,ccaModes))
    if ~isfield(opts,'ccaNoiseMask') || isempty(opts.ccaNoiseMask)
        error('PACAP:NeedCCANoise','Spatial CCA mode requires opts.ccaNoiseMask.');
    end
    K = max(1,round(double(localGet(opts,'ccaThreshold',3))));
    Q = localCCA(Ypsc,spatialSize,finiteMask,opts.ccaNoiseMask,P,K);
    A = [A Q];
    for k=1:size(Q,2), labels{end+1}=sprintf('CCA_noise_%d',k); end %#ok<AGROW>
end

if any(strcmp(mode,vehModes)) || isfield(opts,'vehicleI') || isfield(opts,'vehicleFile')
    VI = [];
    if isfield(opts,'vehicleI') && ~isempty(opts.vehicleI), VI = opts.vehicleI; end
    if isempty(VI) && isfield(opts,'vehicleFile') && ~isempty(opts.vehicleFile) && exist(opts.vehicleFile,'file')==2
        VI = localLoadImage(opts.vehicleFile);
    end
    if ~isempty(VI)
        Q = localVehicleRegressors(VI,spatialSize,T,TR,opts,P);
        A = [A Q];
        for k=1:size(Q,2), labels{end+1}=sprintf('vehicle_%d',k); end %#ok<AGROW>
    end
end

A = localResidual(A,P);
A = localOrtho(A);
info = struct();
info.mode = mode;
info.labels = labels;
info.nRegressors = size(A,2);
info.maxResponseCorrelation = localMaxCorr(A,R);
end

function Q = localCCA(Ypsc,spatialSize,finiteMask,noiseMask,P,K)
V = size(Ypsc,1);
noiseIdx = localMaskIdx(noiseMask,spatialSize,V,finiteMask);
funcIdx = find(finiteMask);
funcIdx = setdiff(funcIdx,noiseIdx);
if numel(noiseIdx)<20 || numel(funcIdx)<20, error('PACAP:CCAMaskSmall','CCA needs >=20 noise and functional voxels.'); end
maxV = 2500;
noiseIdx = localSub(noiseIdx,maxV);
funcIdx = localSub(funcIdx,maxV);
Xf = localZ(localResidual(double(Ypsc(funcIdx,:))',P));
Xn = localZ(localResidual(double(Ypsc(noiseIdx,:))',P));
[Uf,~,~] = svd(Xf,'econ');
[Un,~,~] = svd(Xn,'econ');
r = min([50 size(Uf,2) size(Un,2)]);
G = Uf(:,1:r)*Uf(:,1:r)' + Un(:,1:r)*Un(:,1:r)';
G = (G+G')/2;
[U,S] = eig(G);
[~,ord] = sort(real(diag(S)),'descend');
U = real(U(:,ord));
Q = U(:,1:min(K,size(U,2)));
Q = localResidual(Q,P); Q = localOrtho(Q);
end

function Q = localVehicleRegressors(VI,spatialSize,T,TR,opts,P)
dv = size(VI); Tv = dv(end); Vv = prod(dv(1:end-1));
if ~isequal(dv(1:end-1),spatialSize)
    error('PACAP:VehicleSize','Vehicle scan spatial grid does not match target scan.');
end
Yv = double(reshape(single(VI),[Vv Tv]));
tv = ((0:Tv-1)'*TR);
t = ((0:T-1)'*TR);
bsec = localGet(opts,'baselineSec',[0 min(60,t(end))]);
bv = tv>=bsec(1) & tv<=bsec(end);
if nnz(bv)<3, bv = true(size(tv)); end
bm = localNanMean(Yv(:,bv),2);
bad = ~isfinite(bm) | abs(bm)<eps; bm(bad)=1;
Yvp = 100*(bsxfun(@rdivide,Yv,bm)-1);
Yvp(~isfinite(Yvp))=0;
q = localNanMean(Yvp,1)';
if Tv ~= T, q = interp1(tv,q,t,'linear','extrap'); end
Q = localResidual(q,P);
Q = localOrtho(Q);
end

function X = localReadCustom(fn,T)
[~,~,ext] = fileparts(fn); ext = lower(ext);
if strcmp(ext,'.mat')
    S = load(fn); names = fieldnames(S); X = [];
    for k=1:numel(names)
        a = S.(names{k});
        if isnumeric(a) && ismatrix(a), X = double(a); break; end
    end
    if isempty(X), error('PACAP:BadCustomMAT','No numeric matrix in MAT file.'); end
else
    try, X = readmatrix(fn);
    catch, try, X = csvread(fn); catch, X = dlmread(fn); end, end
end
X = double(X);
if size(X,1)~=T && size(X,2)==T, X=X'; end
if size(X,1)~=T, error('PACAP:CustomLength','Custom regressors have %d rows, expected %d.',size(X,1),T); end
X(:,~all(isfinite(X),1))=[];
end

function I = localLoadImage(fn)
S = load(fn); I = [];
if isfield(S,'newData') && isstruct(S.newData) && isfield(S.newData,'I'), I = S.newData.I; return; end
if isfield(S,'data') && isstruct(S.data) && isfield(S.data,'I'), I = S.data.I; return; end
if isfield(S,'I'), I = S.I; return; end
if isfield(S,'outI'), I = S.outI; return; end
names = fieldnames(S);
for k=1:numel(names)
    a=S.(names{k});
    if isnumeric(a) && ndims(a)>=3, I=a; return; end
end
error('PACAP:VehicleLoad','Could not find image data in %s',fn);
end

function idx = localMaskIdx(M,spatialSize,V,finiteMask)
if numel(M)~=V && ~isequal(size(M),spatialSize)
    error('PACAP:MaskMismatch','Mask size does not match image spatial grid.');
end
idx = find(logical(M(:)) & finiteMask(:));
if numel(idx)<5, error('PACAP:MaskSmall','Mask contains too few valid voxels.'); end
end

function Q = localPCs(X,P,K)
X = localResidual(X,P);
X = localZ(X);
if size(X,2)<2, Q=zeros(size(X,1),0); return; end
[U,~,~] = svd(X,'econ');
Q = U(:,1:min(K,size(U,2)));
Q = localResidual(Q,P);
Q = localOrtho(Q);
end

function idx = localSub(idx,n)
idx = idx(:);
if numel(idx)>n
    ii = unique(round(linspace(1,numel(idx),n)));
    idx = idx(ii);
end
end

function X = localResidual(X,P)
if isempty(X), return; end
if ~isempty(P), X = X - P*(P\X); end
end

function Q = localOrtho(X)
if isempty(X), Q=zeros(size(X,1),0); return; end
X = double(X);
X(:,~all(isfinite(X),1))=[];
X(:,std(X,0,1)<sqrt(eps))=[];
if isempty(X), Q=zeros(size(X,1),0); return; end
[Q,R] = qr(X,0);
keep = abs(diag(R)) > max(size(X))*eps(max(1,norm(R,'fro')));
Q = Q(:,keep);
end

function Z = localZ(X)
if isempty(X), Z=X; return; end
X = double(X);
X = bsxfun(@minus,X,localNanMean(X,1));
s = sqrt(localNanMean(X.^2,1));
s(~isfinite(s) | s==0)=1;
Z = bsxfun(@rdivide,X,s);
Z(~isfinite(Z))=0;
end

function c = localMaxCorr(A,B)
if isempty(A) || isempty(B), c=NaN; return; end
A=localZ(A); B=localZ(B);
C=abs(A'*B)/max(1,size(A,1)-1);
c=max(C(:));
end

function m = localNanMean(X,dim)
if nargin<2, dim=1; end
M = isfinite(X);
X(~M)=0;
n = sum(M,dim);
n(n==0)=NaN;
m = sum(X,dim)./n;
end

function m = localNanMedian(X,dim)
if nargin<2, dim=1; end
try
    m = nanmedian(X,dim);
catch
    if dim==1
        m=zeros(1,size(X,2));
        for k=1:size(X,2), a=X(:,k); a=a(isfinite(a)); if isempty(a), m(k)=NaN; else, m(k)=median(a); end, end
    else
        m=zeros(size(X,1),1);
        for k=1:size(X,1), a=X(k,:); a=a(isfinite(a)); if isempty(a), m(k)=NaN; else, m(k)=median(a); end, end
    end
end
end

function C = localDriftLabels(p)
C = {};
for k=1:p, C{end+1}=sprintf('drift_poly_%d',k); end
end

function C = localRespLabels(n)
C = {};
base = {'PACAP_gamma','PACAP_sustained','PACAP_slow'};
for k=1:n
    if k<=numel(base), C{end+1}=base{k}; else, C{end+1}=sprintf('PACAP_%d',k); end
end
end

function v = localGet(s,n,d)
v = d;
try
    if isfield(s,n) && ~isempty(s.(n)), v = s.(n); end
catch
end
end
