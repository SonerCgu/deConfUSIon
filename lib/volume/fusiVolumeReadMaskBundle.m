function next=fusiVolumeReadMaskBundle(data,file,mode)
% Import saved appearance and independent brain/PSC masks on the model grid.
if nargin<3,mode='both';end
S=load(file);B=scmReadMaskEditorBundle(S);
if isempty(B)
    R=S;if isfield(S,'maskBundle'),R=S.maskBundle;end
    B=struct('image',[],'isProcessed',false,'brainMask',[],'overlayMask',[],'includeMask',[]);
    B.image=pick(R,{'sliceUnderlayProcessed','anatomical_reference','brainImage','sliceUnderlayRaw','anatomical_reference_raw'});
    B.isProcessed=~isempty(pick(R,{'sliceUnderlayProcessed','anatomical_reference'}));
    B.brainMask=pick(R,{'brainMask','underlayMask'});B.overlayMask=pick(R,{'overlayMask','signalMask'});
    if isempty(B.overlayMask)
        B.overlayMask=pick(R,{'mask','loadedMask','activeMask'});
        if ~isempty(B.overlayMask)&&isfield(R,'maskIsInclude')&&~R.maskIsInclude,B.overlayMask=~B.overlayMask;end
    elseif isfield(R,'overlayMaskIsInclude')&&~R.overlayMaskIsInclude,B.overlayMask=~B.overlayMask;end
    if ~isempty(B.brainMask)&&isfield(R,'brainMaskIsInclude')&&~R.brainMaskIsInclude,B.brainMask=~B.brainMask;end
    if isempty(B.overlayMask)&&strcmp(mode,'overlay')
        names=fieldnames(R);
        for k=1:numel(names)
            if ismember(names{k},{'brainMask','underlayMask','brainImage','sliceUnderlayProcessed','sliceUnderlayRaw','anatomical_reference','anatomical_reference_raw'}),continue;end
            value=R.(names{k});
            if (isnumeric(value)||islogical(value))&&ndims(value)==3&&all(ismember(value(:),[0 1]))
                B.overlayMask=value;break;
            end
        end
    end
end
for name={'brainMask','overlayMask'}
    if ~isempty(B.(name{1})),B.(name{1})=isfinite(B.(name{1}))&B.(name{1})~=0;end
end
assert(any(strcmp(mode,{'both','overlay'})),'Unknown 3D mask import mode.');
if strcmp(mode,'overlay')
    assert(~isempty(B.overlayMask),'deConfUSIon:VolumeMaskBundle','This file contains no saved overlay mask.');
    if isempty(B.image),B.image=zeros(size(B.overlayMask),'single');end
else
    assert(~isempty(B.image),'deConfUSIon:VolumeMaskBundle','Select a saved Mask Editor underlay + masks bundle.');
end
shape=size(data.PSC,[1 2 3]);source=size(B.image,[1 2 3]);
mapping=[];if isfield(data,'scanMapping'),mapping=data.scanMapping;end
native=source;
if isfield(data,'nativePower'),native=size(data.nativePower,[1 2 3]);
elseif ~isempty(mapping)&&isfield(mapping,'transform')&&isfield(mapping.transform,'scanGeometry'),native=mapping.transform.scanGeometry.originalSize;end
context=struct('sizeYXZ',shape,'nativeSizeYXZ',native,'mapping',mapping, ...
    'isAtlasWarped',isfield(data,'transformed')&&data.transformed);
[B,alignment]=scmReadMaskEditorBundle('align',B,context);
next=data;
if strcmp(mode,'both')
    next.underlay=single(B.image);next.underlayProcessed=B.isProcessed;next.underlayLabel=char(file);
    next.brainMask=B.brainMask;next.overlayMask=B.overlayMask;
    next.maskUnderlayFile=char(file);next.maskOverlayFile=char(file);
else
    next.overlayMask=B.overlayMask;next.maskOverlayFile=char(file);
end
next.maskImportAlignment=alignment;
end
function value=pick(S,names)
value=[];
for k=1:numel(names),if isfield(S,names{k})&&~isempty(S.(names{k})),value=S.(names{k});return;end,end
end
