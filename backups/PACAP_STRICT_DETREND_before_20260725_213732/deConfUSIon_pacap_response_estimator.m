function [outI, stats] = deConfUSIon_pacap_response_estimator(I,TR,exportPath,opts)
% Early PACAP protected / delayed drift estimator.
% Keeps early PACAP component and removes later delayed component.

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

% Recommended baseline/injection defaults
bsec = localGet(opts,'baselineSec',[0 60]);
b1 = double(bsec(1));
b2 = double(bsec(end));
bIdx = t >= b1 & t <= b2;
if nnz(bIdx) < 3
    error('PACAP_DELAYED:BadBaseline','Baseline window gives fewer than 3 frames.');
end

ti = double(localGet(opts,'injectionSec',b2));
earlySec = double(localGet(opts,'earlyResponseSec',localGet(opts,'responseSec',180)));
if ~isfinite(earlySec) || earlySec <= 0, earlySec = 180; end
earlyEndSec = double(localGet(opts,'earlyEndSec',ti + earlySec));
delayedStartSec = double(localGet(opts,'delayedStartSec',earlyEndSec));

% With baseline 0-60 and injection at 60:
% earlyEndSec defaults to 240 s and delayed drift starts at 240 s.
if ~isfinite(ti) || ti < 0 || ti >= t(end)
    error('PACAP_DELAYED:BadInjection','Injection time %.3f s is outside run.',ti);
end
if ~isfinite(delayedStartSec) || delayedStartSec <= ti
    delayedStartSec = ti + earlySec;
end
if delayedStartSec >= t(end)
    warning('PACAP_DELAYED:NoLateWindow','delayedStartSec is after run end. No delayed component will be removed.');
end

finiteMask = all(isfinite(Y),2);
baseMean = localNanMean(Y(:,bIdx),2);
bad = ~isfinite(baseMean) | abs(baseMean) < eps;
finiteMask(bad) = false;
baseMean(bad) = 1;

Ypsc = 100 * (bsxfun(@rdivide,Y,baseMean) - 1);
Ypsc(~isfinite(Ypsc)) = 0;

% Drift basis: default linear, but intercept is never subtracted.
polyOrder = round(double(localGet(opts,'polyOrder',1)));
polyOrder = max(0,min(5,polyOrder));
x = linspace(-1,1,T)';
D = ones(T,1);
for p = 1:polyOrder
    q = x.^p;
    q = q - mean(q);
    s = std(q);
    if s > 0, q = q ./ s; end
    D = [D q]; %#ok<AGROW>
end

% Early PACAP basis: only active from injection to delayedStartSec.
Rearly = localEarlyPACAPBasis(t,TR,ti,delayedStartSec);
Rearly = localResidual(Rearly,D);
Rearly = localOrtho(Rearly);

% Delayed drift basis: strictly zero before delayedStartSec, then slow.
Rdel = localDelayedBasis(t,TR,delayedStartSec,opts);
Rdel = localResidual(Rdel,[D Rearly]);
Rdel = localOrtho(Rdel);

% Optional immediate injection artifact basis. Default: transient only.
[Aart, artifactInfo] = localArtifactBasis(t,TR,ti,opts,[D Rearly Rdel]);

nD = size(D,2);
nE = size(Rearly,2);
nL = size(Rdel,2);
nA = size(Aart,2);

X = [D Rearly Rdel Aart];

stats = struct();
stats.method = 'pacap_response_early_protected_delayed_drift';
stats.baselineSec = [b1 b2];
stats.injectionSec = ti;
stats.earlyEndSec = delayedStartSec;
stats.earlyResponseSec = delayedStartSec - ti;
stats.delayedStartSec = delayedStartSec;
stats.delayedRemove = logical(localGet(opts,'delayedRemove',true));
stats.polyOrder = polyOrder;
stats.nEarlyPACAP = nE;
stats.nDelayed = nL;
stats.nArtifact = nA;
stats.designRank = rank(X);
stats.designColumns = size(X,2);
stats.designCondition = cond(X);
stats.artifactInfo = artifactInfo;

stats.maxEarlyDelayedCorrelation = localMaxCorr(Rearly,Rdel);
stats.maxEarlyArtifactCorrelation = localMaxCorr(Rearly,Aart);

if isfinite(stats.maxEarlyDelayedCorrelation) && stats.maxEarlyDelayedCorrelation > 0.6
    warning('PACAP_DELAYED:Collinear', ...
        'Early and delayed components are %.0f%% correlated. Interpret separation cautiously.', ...
        100*stats.maxEarlyDelayedCorrelation);
end

if stats.designRank < stats.designColumns
    warning('PACAP_DELAYED:RankDeficient','Model is rank deficient. Results are least-squares but should be inspected carefully.');
end

chunk = round(double(localGet(opts,'chunkVoxels',5000)));
chunk = max(500,min(50000,chunk));

Ycorr = zeros(V,T,'single');
Yremoved = zeros(V,T,'single');
Yearly = zeros(V,T,'single');
Ydelayed = zeros(V,T,'single');
betaEarly = zeros(V,max(1,nE),'single');
betaDelayed = zeros(V,max(1,nL),'single');
ampEarly = zeros(V,1,'single');
ampDelayed = zeros(V,1,'single');
ratioEarlyDelayed = zeros(V,1,'single');

eWin = t >= ti & t <= delayedStartSec;
dWin = t >= delayedStartSec;
if nnz(eWin) < 2, eWin = t >= ti; end
if nnz(dWin) < 2, dWin = false(size(t)); end

for c0 = 1:chunk:V
    c1 = min(V,c0+chunk-1);
    blk = double(Ypsc(c0:c1,:))';
    beta = X \ blk;

    earlyPred = Rearly * beta(nD+1:nD+nE,:);

    delayedPred = zeros(T,size(blk,2));
    if nL > 0
        delayedPred = Rdel * beta(nD+nE+1:nD+nE+nL,:);
    end

    artPred = zeros(T,size(blk,2));
    if nA > 0
        artPred = Aart * beta(nD+nE+nL+1:nD+nE+nL+nA,:);
    end

    driftPred = zeros(T,size(blk,2));
    if nD > 1
        driftPred = D(:,2:end) * beta(2:nD,:);
    end

    nuisance = driftPred + artPred;
    if stats.delayedRemove
        nuisance = nuisance + delayedPred;
    end

    corrBlk = blk - nuisance;

    Ycorr(c0:c1,:) = single(corrBlk');
    Yremoved(c0:c1,:) = single(nuisance');
    Yearly(c0:c1,:) = single(earlyPred');
    Ydelayed(c0:c1,:) = single(delayedPred');

    if nE > 0
        betaEarly(c0:c1,1:nE) = single(beta(nD+1:nD+nE,:)');
        ampEarly(c0:c1) = single(max(earlyPred(eWin,:),[],1) - localNanMedian(earlyPred(bIdx,:),1));
    end
    if nL > 0 && any(dWin)
        betaDelayed(c0:c1,1:nL) = single(beta(nD+nE+1:nD+nE+nL,:)');
        ampDelayed(c0:c1) = single(max(delayedPred(dWin,:),[],1) - localNanMedian(delayedPred(bIdx,:),1));
    end

    ae = double(ampEarly(c0:c1));
    ad = abs(double(ampDelayed(c0:c1)));
    ratioEarlyDelayed(c0:c1) = single(ae ./ max(ad,eps));
end

outY = bsxfun(@times,1 + double(Ycorr)/100,baseMean);
outY(~isfinite(outY)) = double(Yraw(~isfinite(outY)));
outY(~finiteMask,:) = double(Yraw(~finiteMask,:));
outI = reshape(single(outY),dims);

stats.correctedPSC = reshape(Ycorr,dims);
stats.removedNuisancePSC = reshape(Yremoved,dims);
stats.earlyPACAPPredictionPSC = reshape(Yearly,dims);
stats.delayedComponentPSC = reshape(Ydelayed,dims);
stats.earlyPACAPBetaMapsPSC = reshape(betaEarly,[spatialSize size(betaEarly,2)]);
stats.delayedBetaMapsPSC = reshape(betaDelayed,[spatialSize size(betaDelayed,2)]);
stats.earlyPACAPAmplitudeMapPSC = reshape(ampEarly,spatialSize);
stats.delayedAmplitudeMapPSC = reshape(ampDelayed,spatialSize);
stats.earlyDelayedRatioMap = reshape(ratioEarlyDelayed,spatialSize);
stats.recommendation = 'Use earlyPACAPAmplitudeMapPSC as protected PACAP estimate; inspect delayedAmplitudeMapPSC before calling it artifact.';

try
    if ~isempty(exportPath) && exist(exportPath,'dir')==7
        saveFile = fullfile(exportPath,['PACAP_EarlyProtected_DelayedDrift_' datestr(now,'yyyymmdd_HHMMSS') '.mat']);
        save(saveFile,'stats','-v7.3');
        stats.savedFile = saveFile;
    end
catch ME
    stats.saveWarning = ME.message;
end
end

function R = localEarlyPACAPBasis(t,TR,ti,earlyEnd)
T = numel(t);
dt = max(0,t-ti);
L = max(TR,earlyEnd-ti);
win = double(t>=ti & t<=earlyEnd);
w = max(1,round(15/TR));
if w > 1, win = movmean(win,w,'Endpoints','shrink'); end

tau = max(TR,L/4);
r1 = (dt./tau).^2 .* exp(-dt./tau);
r1(t<ti)=0;
r1 = r1 .* win;
if max(abs(r1))>0, r1=r1./max(abs(r1)); end

r2 = win;
if max(abs(r2))>0, r2=r2./max(abs(r2)); end

r3 = min(1,dt./max(TR,L/2));
r3(t<ti)=0;
r3 = r3 .* win;
if max(abs(r3))>0, r3=r3./max(abs(r3)); end

R = [r1 r2 r3];
R = R(:,std(R,0,1)>sqrt(eps));
end

function R = localDelayedBasis(t,TR,delayStart,opts)
dt = max(0,t-delayStart);
post = double(t>=delayStart);
taus = double(localGet(opts,'delayedTauSec',[90 180 360]));
R = zeros(numel(t),0);
for k=1:numel(taus)
    if isfinite(taus(k)) && taus(k)>0
        r = 1 - exp(-dt./taus(k));
        r(t<delayStart)=0;
        if max(abs(r))>0, r=r./max(abs(r)); end
        R = [R r(:)]; %#ok<AGROW>
    end
end
if logical(localGet(opts,'delayedRamp',true))
    r = dt ./ max(TR,max(dt));
    r(t<delayStart)=0;
    R = [R r(:)];
end
if logical(localGet(opts,'delayedStep',false))
    R = [R post(:)];
end
R = R(:,std(R,0,1)>sqrt(eps));
end

function [A,info] = localArtifactBasis(t,TR,ti,opts,P)
% Recommended default: only short injection artefact, not persistent/plateau.
T = numel(t);
mode = lower(char(localGet(opts,'artifactMode','auto')));
A = zeros(T,0);
labels = {};
if any(strcmp(mode,{'auto','auto_roi','auto_custom','auto_spatial_cca'}))
    pulseSec = double(localGet(opts,'artifactPulseSec',5));
    taus = double(localGet(opts,'artifactExpTauSec',[5 20]));
    dt = max(0,t-ti);
    pulse = double(t>=ti & t<ti+pulseSec);
    A = [A pulse(:)]; labels{end+1} = 'inj_pulse';
    for k=1:numel(taus)
        if isfinite(taus(k)) && taus(k)>0
            e = exp(-dt./taus(k)); e(t<ti)=0;
            A = [A e(:)]; labels{end+1}=sprintf('inj_exp_%g',taus(k)); %#ok<AGROW>
        end
    end
    if logical(localGet(opts,'artifactPersistent',false))
        s = double(t>=ti); A=[A s(:)]; labels{end+1}='artifact_step';
    end
    if logical(localGet(opts,'artifactPlateau',false))
        r = min(1,dt./max(TR,60)); r(t<ti)=0;
        A=[A r(:)]; labels{end+1}='artifact_plateau';
    end
end
A = localResidual(A,P);
A = localOrtho(A);
info = struct();
info.mode = mode;
info.labels = labels;
info.nRegressors = size(A,2);
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
        for k=1:size(X,2)
            a=X(:,k); a=a(isfinite(a));
            if isempty(a), m(k)=NaN; else, m(k)=median(a); end
        end
    else
        m=zeros(size(X,1),1);
        for k=1:size(X,1)
            a=X(k,:); a=a(isfinite(a));
            if isempty(a), m(k)=NaN; else, m(k)=median(a); end
        end
    end
end
end

function v = localGet(s,n,d)
v = d;
try
    if isfield(s,n) && ~isempty(s.(n)), v = s.(n); end
catch
end
end
