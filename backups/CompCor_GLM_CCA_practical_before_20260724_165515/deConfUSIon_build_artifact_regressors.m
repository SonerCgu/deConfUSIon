function [A,info] = deConfUSIon_build_artifact_regressors(Y, spatialSize, finiteMask, t, opts, R)
% Build injection/bubble artifact regressors and optional spatial CCA regressors.
if nargin < 6 || isempty(R), R = zeros(size(Y,2),0); end
T = size(Y,2); V = size(Y,1);
finiteMask = logical(finiteMask(:));
mode = lower(localGet(opts,'artifactMode','none'));
ti = double(localGet(opts,'injectionSec',t(round(numel(t)/4))));
pulseSec = double(localGet(opts,'artifactPulseSec',5));
taus = double(localGet(opts,'artifactExpTauSec',[5 20 60]));
npc = max(1,round(double(localGet(opts,'artifactNPC',3))));
A = zeros(T,0); labels = {}; applyMask = [];
P = localOrtho([ones(T,1),double(R)]);

if any(strcmp(mode,{'auto','auto_roi','auto_custom','auto_spatial_cca'}))
    dt = max(0,double(t(:))-ti);
    pulse = double(double(t(:))>=ti & double(t(:))<ti+pulseSec);
    A = [A,pulse(:)]; labels{end+1} = 'pulse';
    for k=1:numel(taus)
        if isfinite(taus(k)) && taus(k)>0
            e = exp(-dt/taus(k)); e(double(t(:))<ti)=0;
            A = [A,e(:)]; labels{end+1} = sprintf('exp%g',taus(k)); %#ok<AGROW>
        end
    end
    if logical(localGet(opts,'artifactPersistent',false))
        s = double(double(t(:))>=ti); A=[A,s(:)]; labels{end+1}='step';
    end
    if logical(localGet(opts,'artifactPlateau',true))
        ramp = min(1,dt/max(1,double(localGet(opts,'responseSec',180))/3));
        ramp(double(t(:))<ti)=0; A=[A,ramp(:)]; labels{end+1}='plateau';
    end
end

if any(strcmp(mode,{'roi','auto_roi'}))
    if ~isfield(opts,'artifactMask') || isempty(opts.artifactMask)
        error('deConfUSIon:NeedArtifactROI','Artifact ROI mode requires opts.artifactMask.');
    end
    idx = find(localMask(opts.artifactMask,spatialSize,V) & finiteMask);
    if numel(idx) < 20, error('deConfUSIon:ArtifactROISmall','Artifact ROI has only %d voxels.',numel(idx)); end
    Q = localPCs(double(Y(idx,:))',P,npc);
    A = [A,Q];
    for k=1:size(Q,2), labels{end+1}=sprintf('artifactROI_PC%d',k); end %#ok<AGROW>
end

if any(strcmp(mode,{'custom','auto_custom'}))
    if ~isfield(opts,'customArtifactFile') || isempty(opts.customArtifactFile)
        error('deConfUSIon:NeedCustomArtifact','Custom artifact mode requires a customArtifactFile.');
    end
    C = localLoadCustom(opts.customArtifactFile,T);
    A = [A,C];
    for k=1:size(C,2), labels{end+1}=sprintf('custom%d',k); end %#ok<AGROW>
end

if any(strcmp(mode,{'spatial_cca','auto_spatial_cca'}))
    [C,ccaInfo] = deConfUSIon_spatial_cca_simple(Y,spatialSize,finiteMask,opts,R);
    A = [A,C];
    for k=1:size(C,2), labels{end+1}=sprintf('CCA%d',k); end %#ok<AGROW>
else
    ccaInfo = struct();
end

A = localResidual(A,P);
A = localOrtho(A);
info = struct('mode',mode,'labels',{labels},'nRegressors',size(A,2), ...
    'maxResponseCorrelation',localMaxCorr(A,R),'applyMask',applyMask,'ccaInfo',ccaInfo);
end

function C = localLoadCustom(fn,T)
[~,~,ext] = fileparts(fn); ext = lower(ext);
if strcmp(ext,'.mat')
    S = load(fn); names = fieldnames(S); C = [];
    for i=1:numel(names)
        x = S.(names{i});
        if isnumeric(x) && ismatrix(x), C = x; break; end
    end
    if isempty(C), error('deConfUSIon:BadCustomMAT','No numeric matrix found in MAT file.'); end
else
    C = readmatrix(fn);
end
C = double(C);
if size(C,1) ~= T && size(C,2) == T, C = C'; end
if size(C,1) ~= T
    error('deConfUSIon:CustomLength','Custom regressors have %d rows, expected %d.',size(C,1),T);
end
C(:,~all(isfinite(C),1)) = [];
end

function Q = localPCs(X,P,K)
X = localResidual(X,P);
X = bsxfun(@minus,X,mean(X,1));
s = std(X,0,1); X = X(:,s>sqrt(eps)); s=s(s>sqrt(eps));
X = bsxfun(@rdivide,X,s);
[U,~,~] = svd(X,'econ');
Q = U(:,1:min(K,size(U,2)));
Q = localResidual(Q,P); Q = localOrtho(Q);
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

function c = localMaxCorr(A,B)
if isempty(A) || isempty(B), c = NaN; return; end
A = localZ(A); B = localZ(B); C = abs(A'*B)/max(1,size(A,1)-1); c = max(C(:));
end

function Z = localZ(X)
X = double(X); X = bsxfun(@minus,X,mean(X,1)); s = std(X,0,1); s(s==0)=1; Z = bsxfun(@rdivide,X,s);
end

function v = localGet(s,n,d)
if isfield(s,n) && ~isempty(s.(n)), v = s.(n); else, v = d; end
end
