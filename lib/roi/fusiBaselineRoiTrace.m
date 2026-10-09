function series=fusiBaselineRoiTrace(r,c,wholeScan,progress)
% Read only this ROI from reference power; retain the reference's sampled TR.
if nargin<3,wholeScan=false;end
if nargin<4,progress=@(~,~)[];end
progress(0,'Preparing ROI samples...');
shape=r.spatialSize;B=r.mean;
if isfield(r,'nativeMean'),shape=r.nativeSpatialSize;B=r.nativeMean;end
sourceShape=[shape ones(1,3-numel(shape))];B=reshape(B,sourceShape);
offset=zeros(1,3);if isfield(r,'alignment'),q=r.alignment.offsetVoxels;offset(1:numel(q))=q;end
if isfield(c,'roiMaskVolumeIndices')
    [y,x,z]=ind2sub(c.roiMaskSizeYXZ,c.roiMaskVolumeIndices);
else
    b=c.boundsXY;[y,x]=ndgrid(b(3):b(4),b(1):b(2));z=repmat(c.slice,size(y));
    if isfield(c,'roiMaskIndices')
        m=false(c.roiMaskSizeYX);m(c.roiMaskIndices)=true;
        keep=m(sub2ind(c.roiMaskSizeYX,y,x));y=y(keep);x=x(keep);z=z(keep);
    end
end
voxels=[y(:) x(:) z(:)]-offset;
valid=all(voxels>=1&voxels<=sourceShape,2);voxels=voxels(valid,:);
assert(~isempty(voxels),'deConfUSIon:ReferenceTraceROI','This ROI has no overlapping reference voxels.');
indices=sub2ind(sourceShape,voxels(:,1),voxels(:,2),voxels(:,3));base=double(B(indices));
valid=isfinite(base)&base>0;voxels=voxels(valid,:);base=base(valid);
assert(~isempty(base),'deConfUSIon:ReferenceTraceROI','This ROI has no valid reference baseline.');
lo=min(voxels,[],1);hi=max(voxels,[],1);extent=hi-lo+1;local=voxels-lo+1;
take=sub2ind(extent,local(:,1),local(:,2),local(:,3));
frames=r.frames(1):r.frames(2);if wholeScan,frames=1:r.nFrames;end
cached=isfield(r,'tracePower')&&isfield(r,'traceFrames')&&all(ismember(frames,r.traceFrames));
if ~cached
    assert(isfield(r,'sourceFile')&&~isempty(r.sourceFile),'deConfUSIon:ReferenceTraceFile', ...
        'The reference mean has no time series. Select its source scan again to show its curve.');
    file=fusiFindMovedDataPath(r.sourceFile);
    if isfield(r,'fileInfo')&&isstruct(r.fileInfo)&&r.fileInfo.partialReadable
        assert(isfile(file),'deConfUSIon:ReferenceTraceFile','The scan time-series file is unavailable.');
        info=r.fileInfo;info.file=file;
    else,info=referenceInfo(file);end
    assert(isequal(info.spatialSize,shape),'deConfUSIon:ReferenceTraceGrid','The reference source grid changed; select the source scan again.');
    signature=[];if isfield(info,'fileBytes'),signature=[info.fileBytes info.fileDatenum];end
    key=struct('file',info.file,'path',info.path,'signature',signature,'voxels',voxels, ...
        'baseline',base,'frames',frames,'TR',r.TR,'window',r.windowSec);
    series=fusiRoiCurveCache('get',key);if ~isempty(series),progress(1,'Using cached curve');return;end
end
psc=nan(1,numel(frames));chunk=max(1,floor(16*1024^2/(16*prod(extent))));
slab=[];
if ~cached&&info.partialReadable
    progress(.05,'Reading native slice from disk / network...');slab=fusiPowerSlabCache(info,lo,hi,frames);
    progress(.65,'Native slice ready; computing the ROI curve...');
end
for first=1:chunk:numel(frames)
    last=min(numel(frames),first+chunk-1);chosen=frames(first:last);
    spatial={lo(1):hi(1),lo(2):hi(2)};if numel(shape)==3,spatial{3}=lo(3):hi(3);end
    if cached
        [~,q]=ismember(chosen,r.traceFrames);A=r.tracePower(spatial{:},q);
    elseif ~isempty(slab)
        sub=cell(1,numel(shape)+1);
        for axis=1:numel(shape),sub{axis}=lo(axis)-slab.start(axis)+1:hi(axis)-slab.start(axis)+1;end
        sub{end}=first:last;A=slab.power(sub{:});
    elseif info.partialReadable
        start=[lo(1:numel(shape)) chosen(1)];count=[extent(1:numel(shape)) numel(chosen)];
        A=h5read(info.file,info.path,start,count);
    else
        A=info.data(spatial{:},chosen);
    end
    A=reshape(double(A),prod(extent),numel(chosen));A=100*(A(take,:)./base-1);
    psc(first:last)=mean(A,1,'omitnan');
    progress(.65+.35*last/numel(frames),sprintf('ROI samples %d / %d',last,numel(frames)));
end
series=struct('PSC',psc,'timeSec',(frames-1)*r.TR,'frames',frames,'TR',r.TR, ...
    'baselineWindowSec',r.windowSec,'voxelCount',numel(base));
if ~cached,fusiRoiCurveCache('put',key,series);end
end
function info=referenceInfo(file)
persistent previous
assert(isfile(file),'deConfUSIon:ReferenceTraceFile', ...
    'Reference time-series file is unavailable. Cached baseline samples can still be shown; the whole scan requires its original file.');
if isempty(previous)||~strcmpi(previous.file,file)
    previous=fusiBaselineFileInfo(file);
    if ~previous.partialReadable&&isempty(previous.data)
        key=previous.path(2:end);s=load(file,key);previous.data=s.(key);
    end
end
info=previous;
end
