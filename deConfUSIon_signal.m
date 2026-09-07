function varargout = deConfUSIon_signal(action, varargin)
% Shared, GUI-independent numerical contracts. Time is the last dimension.
switch lower(action)
    case 'interpolate', [varargout{1:nargout}] = interpolateFrames(varargin{:});
    case 'psc', [varargout{1:nargout}] = makePSC(varargin{:});
    case 'rebase', [varargout{1:nargout}] = rebasePSC(varargin{:});
    case 'fcstats', [varargout{1:nargout}] = fcStats(varargin{:});
    case 'basis', [varargout{1:nargout}] = temporalBasis(varargin{:});
    case 'mean', [varargout{1:nargout}] = finiteMean(varargin{:});
    otherwise, error('deConfUSIon:SignalAction','Unknown action: %s',action);
end
end

function O = interpolateFrames(I, rejected)
T = size(I,ndims(I));
if numel(rejected) ~= T || any(~isfinite(double(rejected(:))))
    error('deConfUSIon:RejectionLength','Rejection mask must have one finite value per time point (%d).',T);
end
bad = find(logical(rejected(:))); good = find(~logical(rejected(:)));
O = I;
if isempty(bad), return; end
if numel(good)<2
    error('deConfUSIon:TooFewFrames','Interpolation requires at least two unrejected frames.');
end
sz = size(I); V = reshape(I,[],T); O = V;
% Endpoint gaps use the nearest observed frame, never unbounded extrapolation.
tq = min(max(bad,good(1)),good(end));
chunk = max(1,floor(32*1024^2/(8*T)));
for a=1:chunk:size(V,1)
    b=min(size(V,1),a+chunk-1);
    O(a:b,bad) = cast(interp1(good,double(V(a:b,good))',tq,'linear')','like',I);
end
O=reshape(O,sz);
end

function [P,B,valid] = makePSC(I,idx)
T=size(I,ndims(I));
idx=validateFrames(idx,T);
subs=repmat({':'},1,ndims(I)); subs{end}=idx;
B=finiteMean(I(subs{:}),ndims(I));
valid=isfinite(B) & B>0;
den=B; den(~valid)=NaN;
P=single(100*bsxfun(@rdivide,bsxfun(@minus,single(I),B),den));
end

function [P,B] = rebasePSC(P,idx)
% Exact percent change relative to a new baseline, from existing PSC.
% 100*(P-B)/(100+B); works without retaining another raw movie.
T=size(P,ndims(P)); idx=validateFrames(idx,T);
subs=repmat({':'},1,ndims(P)); subs{end}=idx;
B=finiteMean(P(subs{:}),ndims(P));
den=100+B; den(~isfinite(den) | den<=sqrt(eps('single')))=NaN;
P=100*bsxfun(@rdivide,bsxfun(@minus,P,B),den);
end

function idx=validateFrames(idx,T)
idx=double(idx(:)');
if isempty(idx) || any(~isfinite(idx) | idx<1 | idx>T | idx~=round(idx))
    error('deConfUSIon:BaselineFrames','Baseline frames must be valid indices within the acquisition.');
end
end

function M=finiteMean(X,dim)
if nargin<2, dim=1; end
ok=isfinite(X); X(~ok)=0; count=sum(ok,dim);
M=sum(X,dim)./max(1,count); M(count==0)=NaN;
end

function [P,N,Q] = fcStats(X)
% Two-sided one-sample Student t on independent subject Fisher Z values.
nr=size(X,1); nc=size(X,2); P=nan(nr,nc); N=zeros(nr,nc);
for r=1:nr
    for c=1:nc
        v=double(reshape(X(r,c,:),[],1)); v=v(isfinite(v)); n=numel(v); N(r,c)=n;
        if n<2 || r==c, continue; end
        sd=std(v); if sd<=sqrt(eps), continue; end
        t=mean(v)/(sd/sqrt(n)); df=n-1;
        P(r,c)=betainc(df/(df+t*t),df/2,0.5);
    end
end
Q=nan(size(P));
eligible=find(triu(true(nr,nc),1) & isfinite(P));
if isempty(eligible), return; end
[p,order]=sort(P(eligible)); m=numel(p); q=min(1,p(:).*m./(1:m)');
for k=m-1:-1:1, q(k)=min(q(k),q(k+1)); end
Q(eligible(order))=q;
for k=1:numel(eligible), [r,c]=ind2sub(size(P),eligible(k)); if c<=nr && r<=nc, Q(c,r)=Q(r,c); end, end
end

function [U,s,W,energy,info] = temporalBasis(X,K,options)
% Exact components for short recordings; bounded-pass randomized SVD for
% long recordings in auto mode. options.method='exact' requests exact PCA.
if nargin<3, options=struct(); end
progress=[];
if isfield(options,'showProgress') && options.showProgress
    progress=waitbar(0,'Preparing PCA / ICA components...', 'Name','Decomposition progress', ...
        'CreateCancelBtn',@(h,~)setappdata(ancestor(h,'figure'),'CancelDecomposition',true));
    set(progress,'CloseRequestFcn',@(h,~)setappdata(h,'CancelDecomposition',true));
    deConfUSIon_ui('style',progress);
end
cleanup=onCleanup(@()closeDecompositionProgress(progress)); %#ok<NASGU>
lastProgress=tic;
[V,T]=size(X); K=min([round(K),V,T-1]);
method='auto'; if isfield(options,'method'), method=lower(options.method); end
if ~ismember(method,{'auto','fast','exact'}), error('deConfUSIon:BasisMethod','Unknown decomposition method: %s',method); end
fast=(strcmp(method,'fast') || strcmp(method,'auto') && T>4096) && min(V,T)>K+30;
multiplicationPass=0;
info=struct('algorithm','exact','approximate',false,'powerIterations',0,'seed',0,'relativeResidual',NaN);
if K<1, error('deConfUSIon:ShortSeries','At least two time points and one voxel are required.'); end
chunk=max(1,floor(32*1024^2/(8*T)));
energy=0;
useGram=~fast && T<=8192 && V>=T;
if useGram, G=zeros(T); end
for a=1:chunk:V
    b=min(V,a+chunk-1); Z=double(X(a:b,:));
    if any(~isfinite(Z(:))), error('deConfUSIon:NonfiniteDecomposition','PCA/ICA requires finite data; inspect QC and invalid voxels first.'); end
    energy=energy+sum(Z(:).^2);
    if useGram, G=G+Z'*Z; end
    tick(.7*b/V,'Computing temporal covariance / data energy...');
end
clear Z;
if energy<=eps, error('deConfUSIon:ConstantSeries','No temporal variation is available for decomposition.'); end
if fast
    % Deterministic randomized range finder, stabilized subspace iteration
    % (Halko et al.). All frames/voxels participate; no temporal subsampling.
    info.algorithm='randomized SVD'; info.approximate=true; info.powerIterations=2;
    L=min([K+30,V,T]); random=RandStream('mt19937ar','Seed',0);
    B=randn(random,V,L); Q=multiply(B,'notransp'); [Q,~]=qr(Q,0);
    for iteration=1:2
        B=multiply(Q,'transp'); [B,~]=qr(B,0);
        Q=multiply(B,'notransp'); [Q,~]=qr(Q,0);
    end
    B=multiply(Q,'transp'); [W,S,rotation]=svd(B,'econ');
    U=Q*rotation(:,1:K); W=W(:,1:K); s=diag(S); s=s(1:K);
    residual=multiply(W,'notransp')-bsxfun(@times,U,s');
    info.relativeResidual=norm(residual,'fro')/max(eps,norm(s));
elseif useGram
    tick(.72,'Solving leading components...');
    G=(G+G')/2;
    if T<=256 || K>=T-1
        [U,D]=eig(G,'vector'); [D,ord]=sort(real(D),'descend'); U=U(:,ord(1:K)); D=D(1:K);
    else
        [U,D,flag]=eigs(G,K,'largestreal',struct('tol',1e-8,'maxit',500,'issym',true));
        if flag~=0, error('deConfUSIon:SVDConvergence','Temporal covariance decomposition did not converge.'); end
        D=diag(D);
    end
    clear G;
    [D,ord]=sort(real(D),'descend'); U=U(:,ord);
    keep=D>max(V,T)*eps(max(D)); D=D(keep); U=U(:,keep);
    s=sqrt(max(0,D)); W=zeros(V,numel(s));
    for a=1:chunk:V
        b=min(V,a+chunk-1); W(a:b,:)=bsxfun(@rdivide,double(X(a:b,:))*U,s');
        tick(.8+.19*b/V,'Computing spatial component weights...');
    end
elseif min(V,T)<=K+1 && double(V)*T<=2e6
    [U,S,W]=svd(double(X'),'econ'); U=U(:,1:K); W=W(:,1:K); s=diag(S); s=s(1:K);
else
    settings=struct('tol',1e-6,'maxit',500);
    [U,S,W,flag]=svds(@multiply,[T V],K,'largest',settings);
    if flag~=0, error('deConfUSIon:SVDConvergence','Decomposition did not converge. Reduce component count or select a slice.'); end
    s=diag(S);
end
[s,ord]=sort(s,'descend'); U=U(:,ord); W=W(:,ord);
keep=s>max(V,T)*eps(max(s)); U=U(:,keep); W=W(:,keep); s=s(keep);
    function Y=multiply(A,mode)
        multiplicationPass=multiplicationPass+1;
        if fast
            fraction=.70+.29*min(1,multiplicationPass/7);
            message=sprintf('Fast PCA / ICA: matrix pass %d of 7...',multiplicationPass);
        else
            fraction=.75; message=sprintf('Exact decomposition: matrix pass %d...',multiplicationPass);
        end
        tick(fraction,message);
        if strcmp(mode,'notransp')
            Y=zeros(T,size(A,2));
            for q=1:chunk:V, e=min(V,q+chunk-1); Y=Y+double(X(q:e,:))'*A(q:e,:); tick(fraction,message); end
        else
            Y=zeros(V,size(A,2));
            for q=1:chunk:V, e=min(V,q+chunk-1); Y(q:e,:)=double(X(q:e,:))*A; tick(fraction,message); end
        end
    end
    function tick(fraction,message)
        if toc(lastProgress)>.15
            if ~isempty(progress) && isgraphics(progress), waitbar(fraction,progress,message); end
            drawnow;
            lastProgress=tic;
        end
        cancelled=isfield(options,'cancelFcn') && options.cancelFcn();
        if ~isempty(progress), cancelled=cancelled || ~isgraphics(progress) || isequal(getappdata(progress,'CancelDecomposition'),true); end
        if cancelled, error('deConfUSIon:DecompositionCancelled','Decomposition cancelled; the input dataset is unchanged.'); end
    end
end

function closeDecompositionProgress(h)
if ~isempty(h) && isgraphics(h), delete(h); end
end
