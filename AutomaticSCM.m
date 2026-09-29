function result = AutomaticSCM(PSC,TR,protocol,outDir,fileLabel)
if ischar(PSC) && strcmp(PSC,'search')
    result=searchROI(TR,protocol,outDir,fileLabel); return;
end
% Fixed-protocol export, or an explicit exploratory peak search via 'search'.
% Coordinates refer to the exact current SCM array, before display rendering.
if ischar(protocol) || isstring(protocol), protocol=jsondecode(fileread(protocol)); end
required={'name','referenceSizeYXZ','roiSizeYX','targetXYZ','controlXYZ','baselineSec','signalSec'};
for k=1:numel(required)
    assert(isfield(protocol,required{k}),'deConfUSIon:Protocol','Missing protocol field: %s',required{k});
end

assert(isscalar(TR)&&isfinite(TR)&&TR>0,'deConfUSIon:Protocol','Invalid TR.');
sz=size(PSC); if ndims(PSC)==3, sz=[sz(1:2) 1 sz(3)]; end
assert(numel(sz)==4 && isequal(double(protocol.referenceSizeYXZ(:)'),double(sz(1:3))), ...
    'deConfUSIon:ProtocolGeometry','Protocol dimensions do not match the current SCM coordinate grid.');
roiSize=double(protocol.roiSizeYX(:)');
assert(numel(roiSize)==2 && all(isfinite(roiSize)&roiSize>=1&roiSize==round(roiSize)), ...
    'deConfUSIon:Protocol','ROI size must contain two positive integer pixel counts [Y X].');
t=(0:sz(4)-1)*TR;
b=window(protocol.baselineSec,t); signal=window(protocol.signalSec,t);
assert(protocol.baselineSec(2)<protocol.signalSec(1),'deConfUSIon:Protocol', ...
    'Baseline must precede the signal interval. Use the same prespecified intervals across animals.');
labels={'Target','Control'}; centers={protocol.targetXYZ,protocol.controlXYZ};
result=struct('version',1,'protocol',protocol,'source',fileLabel,'TR',TR,'timeSec',t);
result.created=datestr(now,30); result.rois=struct([]);
for k=1:2
    c=double(centers{k}(:)');
    assert(numel(c)==3 && all(isfinite(c)&c==round(c)),'deConfUSIon:Protocol','ROI coordinates must be integer [X Y Z].');
    x=c(1)-floor((roiSize(2)-1)/2)+(0:roiSize(2)-1);
    y=c(2)-floor((roiSize(1)-1)/2)+(0:roiSize(1)-1); z=c(3);
    assert(min(x)>=1&&max(x)<=sz(2)&&min(y)>=1&&max(y)<=sz(1)&&z>=1&&z<=sz(3), ...
        'deConfUSIon:ProtocolBounds','The complete fixed-size ROI must fit within the data; no clipping is allowed.');
    if ndims(PSC)==3, V=double(reshape(PSC(y,x,:),[],sz(4)));
    else, V=double(reshape(PSC(y,x,z,:),[],sz(4))); end
    % Exact change of baseline for input already represented as percent signal.
    B=deConfUSIon_signal('mean',V(:,b),2); denom=100+B;
    good=sum(isfinite(V(:,b)),2)>=ceil(.8*numel(b)) & isfinite(denom) & denom>sqrt(eps('single'));
    assert(all(good),'deConfUSIon:ProtocolCoverage','A fixed ROI contains invalid baseline voxels. Review data quality; the ROI will not be silently shrunk.');
    V=100*bsxfun(@rdivide,bsxfun(@minus,V,B),denom);
    % Require all ROI voxels at each frame to keep the spatial support fixed.
    tc=mean(V,1); tc(any(~isfinite(V),1))=NaN;
    assert(sum(isfinite(tc(signal)))>=ceil(.8*numel(signal)), ...
        'deConfUSIon:ProtocolCoverage','Less than 80%% signal-window coverage.');
    result.rois(k).label=labels{k}; result.rois(k).centerXYZ=c;
    result.rois(k).boundsXY=[min(x) max(x) min(y) max(y)];
    result.rois(k).pixelCount=prod(roiSize); result.rois(k).psc=tc;
    result.rois(k).signalMean=deConfUSIon_signal('mean',tc(signal),2);
end
a=result.rois(1); c=result.rois(2);
assert(a.centerXYZ(3)~=c.centerXYZ(3) || a.boundsXY(2)<c.boundsXY(1) || c.boundsXY(2)<a.boundsXY(1) || ...
    a.boundsXY(4)<c.boundsXY(3) || c.boundsXY(4)<a.boundsXY(3), ...
    'deConfUSIon:ProtocolOverlap','Target and control ROIs must not overlap.');
if nargin<4 || isempty(outDir), return; end
% Validate both ROIs before writing anything. A unique run folder avoids overwrite.
if ~exist(outDir,'dir'), mkdir(outDir); end
runDir=tempname(outDir); mkdir(runDir); result.outputFolder=runDir;
save(fullfile(runDir,'AutomaticSCM_result.mat'),'result');
fid=fopen(fullfile(runDir,'protocol.json'),'w'); assert(fid>=0,'Could not save protocol.');
guard=onCleanup(@()fclose(fid)); fprintf(fid,'%s',jsonencode(protocol)); clear guard;
for k=1:2
    r=result.rois(k); fid=fopen(fullfile(runDir,sprintf('ROI1_%s_d1.txt',r.label)),'w');
    assert(fid>=0,'Could not save ROI.'); guard=onCleanup(@()fclose(fid));
    fprintf(fid,'# ROI export from SCM_gui: AutomaticSCM fixed protocol\n# FileLabel: %s\n',fileLabel);
    fprintf(fid,'# ROI_LABEL: %s\n# SLICE: %d\n# TR_sec: %.9g\n',r.label,r.centerXYZ(3),TR);
    fprintf(fid,'# PSC_REBASED: 1\n# BaselineWindow: %.9g %.9g sec\n',protocol.baselineSec);
    fprintf(fid,'# SignalWindow: %.9g %.9g sec\n',protocol.signalSec);
    fprintf(fid,'# x1 x2 y1 y2\n%d %d %d %d\n',r.boundsXY);
    fprintf(fid,'# columns: time_sec\ttime_min\tPSC\n');
    fprintf(fid,'%.9g\t%.9g\t%.9g\n',[t;t/60;r.psc]); clear guard;
end
end

function idx=window(w,t)
w=double(w(:)');
tol=max(1e-9,16*eps(max(1,max(abs(t)))));
assert(numel(w)==2 && all(isfinite(w)) && w(1)>=t(1)-tol && w(2)<=t(end)+tol && w(2)>w(1), ...
    'deConfUSIon:ProtocolWindow','The complete protocol window must fall within the acquisition, in seconds.');
idx=find(t>=w(1)-tol&t<=w(2)+tol);
assert(numel(idx)>=2,'deConfUSIon:ProtocolWindow','Each interval needs at least two acquired samples.');
end

function R=searchROI(A,TR,cfg,mask)
% Search raw, exactly rebased PSC; display alpha/smoothing never participates.
assert(isscalar(TR)&&isfinite(TR)&&TR>0,'deConfUSIon:Protocol','Invalid TR.');
n=double(cfg.size); z=double(cfg.slice); T=size(A,ndims(A)); t=(0:T-1)*TR;
assert(isscalar(n)&&isfinite(n)&&n>=1&&n==round(n),'deConfUSIon:SearchSize','ROI size is an integer side length in pixels.');
sz=size(A); nz=1; if ndims(A)==4, nz=sz(3); end
assert(isscalar(z)&&z>=1&&z<=nz&&z==round(z),'deConfUSIon:SearchSlice','Invalid slice.');
assert(n<=min(sz(1:2)),'deConfUSIon:SearchSize','ROI is larger than the image.');
assert(isequal(size(mask),sz(1:2)),'deConfUSIon:SearchMask','Mask dimensions do not match the selected slice.');
% SCM rounds endpoints to the nearest acquired frame (inclusive). Strict
% timestamp containment can select only one frame in a 60 s window at
% TR=33.5 s even though the displayed SCM averages three frames.
b=scmWindow(cfg.baselineSec,TR,T);
duration=0; if isfield(cfg,'plateauSec'), duration=cfg.plateauSec; end
[starts,width]=scmSearchWindows(cfg.signalSec,duration,TR,T);
[B,nb]=average(b);
baseValid=logical(mask)&isfinite(B)&(100+B)>sqrt(eps('single'))&nb==numel(b);
value=-Inf; index=1; bestStart=starts(1);
[S,ns,total]=average(starts(1)+(0:width-1));
for wi=1:numel(starts)
    first=starts(wi);
    if wi>1
        [old,oldGood]=frame(first-1); [new,newGood]=frame(first+width-1);
        total=total-old+new; ns=ns-double(oldGood)+double(newGood); S=total./ns;
    end
    valid=baseValid&isfinite(S)&ns==width;
    M=100*(S-B)./(100+B); M(~valid)=0;
    score=boxSum(M,n)/(n*n); count=boxSum(double(valid),n);
    score(count~=n*n)=-Inf;
    [v,ii]=max(score(:));
    if v>value, value=v; index=ii; bestStart=first; end
    if isfield(cfg,'progress'), cfg.progress(wi/numel(starts)); end
end
assert(isfinite(value),'deConfUSIon:SearchCoverage','No complete ROI fits inside the mask with finite data throughout baseline and an eligible signal window.');
[y,x]=ind2sub(size(score),index); s=bestStart+(0:width-1);
selectedSec=cfg.signalSec; if duration>0, selectedSec=t(s([1 end])); end
R=struct('boundsXY',[x x+n-1 y y+n-1],'slice',z,'size',n,'meanPSC',value, ...
    'baselineSec',cfg.baselineSec,'signalSec',selectedSec,'method','maximum mean rebased PSC; full square support', ...
    'selection','exploratory: ROI and optional plateau selected on the measured response');
R.searchIntervalSec=cfg.signalSec; R.plateauSec=duration; R.windowsTested=numel(starts);
R.baselineFrames=b; R.signalFrames=s;
R.baselineSampleSec=t(b); R.signalSampleSec=t(s);
R.actualWindowSpanSec=t(s(end))-t(s(1));
R.windowRule='SCM nearest-frame endpoints, inclusive; no interpolated samples';
if duration>0
    R.windowRule='Frame-aligned sliding windows entirely within search range; span rounded up to at least requested duration; endpoints inclusive';
end
    function [v,good]=frame(ii)
        if ndims(A)==3, v=double(A(:,:,ii)); else, v=double(A(:,:,z,ii)); end
        good=isfinite(v); v(~good)=0;
    end
    function [mu,count,total]=average(idx)
        total=zeros(sz(1:2)); count=total;
        chunk=max(1,floor(16*1024^2/(8*prod(sz(1:2)))));
        for start=1:chunk:numel(idx)
            ii=idx(start:min(end,start+chunk-1));
            if ndims(A)==3, V=double(A(:,:,ii)); else, V=double(A(:,:,z,ii)); end
            V=reshape(V,sz(1),sz(2),[]); good=isfinite(V); V(~good)=0;
            total=total+sum(V,3); count=count+sum(good,3);
        end
        mu=total./count;
    end
end

function idx=scmWindow(w,TR,T)
w=double(w(:)');
assert(numel(w)==2&&all(isfinite(w))&&w(1)>=0&&w(2)>=w(1)&&w(1)<T*TR&&w(2)<=T*TR, ...
    'deConfUSIon:ProtocolWindow','Enter start/end within the acquisition. The search dialog uses minutes; SCM controls use seconds.');
ends=max(1,min(T,round(w/TR)+1)); idx=ends(1):ends(2);
end

function S=boxSum(A,n)
C=zeros(size(A)+1); C(2:end,2:end)=cumsum(cumsum(A,1),2);
S=C(n+1:end,n+1:end)-C(1:end-n,n+1:end)-C(n+1:end,1:end-n)+C(1:end-n,1:end-n);
end
