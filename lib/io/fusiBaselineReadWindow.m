function r=fusiBaselineReadWindow(info,TR,window,provenance,progress)
% Read only baseline frames from v7.3 files, in bounded chunks.
if nargin<5,progress=@(~,~)[];end
T=info.nFrames;window=double(window(:).');
assert(numel(window)==2&&all(isfinite(window))&&window(1)>=0&&window(2)>window(1)&&window(2)<=(T-1)*TR, ...
    'deConfUSIon:BaselineWindow','Baseline must lie inside the selected reference dataset (0-%.6g s).',(T-1)*TR);
frames=round(window/TR)+1;shape=info.spatialSize;
total=zeros(shape,'double');count=zeros(shape,'double');
chunk=max(1,floor(32*1024^2/(12*prod(shape))));N=diff(frames)+1;
preview=[];if N*prod(shape)*4<=32*1024^2,preview=nan([shape N],'single');end
if ~info.partialReadable&&isempty(info.data)
    progress(0,'Loading classic MAT file (partial reads require v7.3)...');
    key=info.path(2:end);s=load(info.file,key);info.data=s.(key);
end
for first=frames(1):chunk:frames(2)
    last=min(frames(2),first+chunk-1);n=last-first+1;
    progress((first-frames(1))/N,sprintf('Reading baseline frames %d-%d of %d',first,last,T));
    if info.partialReadable
        start=ones(size(info.size));start(end)=first;block=info.size;block(end)=n;
        A=h5read(info.file,info.path,start,block);
    else
        q=repmat({':'},1,numel(info.size));q{end}=first:last;A=info.data(q{:});
    end
    A=reshape(single(A),[shape n]);
    if ~isempty(preview),q=repmat({':'},1,numel(info.size));q{end}=first-frames(1)+1:last-frames(1)+1;preview(q{:})=A;end
    good=isfinite(A);A(~good)=0;
    total=total+sum(double(A),numel(info.size));count=count+sum(good,numel(info.size));
end
B=single(total./count);B(count==0|B<=0)=NaN;
assert(any(isfinite(B(:))),'deConfUSIon:BaselinePower','No positive, finite power in the selected baseline.');
r=struct('kind','FUSI_SHARED_BASELINE','version',2,'mean',B,'TR',TR, ...
    'requestedWindowSec',window,'windowSec',(frames-1)*TR,'frames',frames, ...
    'nFrames',T,'spatialSize',shape,'created',datestr(now,30), ...
    'sourceFile',info.file,'rawFile','','datasetLabel','Reference scan');
for f=fieldnames(provenance)',r.(f{1})=provenance.(f{1});end
if ~isempty(preview),r.tracePower=preview;r.traceFrames=frames(1):frames(2);end
progress(1,'Reference mean ready');
end
