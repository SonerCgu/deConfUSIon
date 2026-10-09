function display=fusiAtlasUnderlayDisplay3D(U,meta,space)
% Sample the full reference atlas for display, independently of PSC sampling.
T=meta.transform;g=T.scanGeometry;[~,info]=fusiAtlasRecordingGrid3D(T);
if strcmp(space,'native')
 shape=double(g.originalSize);spacing=g.originalSpacingUm;
 % The reference continues beyond the acquired field of view. Project the
 % atlas box into native coordinates, without extending the measured PSC.
 sz=double(T.size);[ap,dv,lr]=ndgrid([1 sz(1)],[1 sz(2)],[1 sz(3)]);
 p=[dv(:) ap(:) lr(:) ones(8,1)]/double(T.M);
 prepared={p(:,2),p(:,1),p(:,3)};native=cell(1,3);
 dims=g.originalSize(g.permutation);
 for axis=1:3
  values=1+(prepared{axis}-1)*g.atlasVoxelSizeUm(axis)/g.originalSpacingUm(g.permutation(axis));
  if isfield(g,'flipAxes') && ismember(axis,g.flipAxes),values=dims(axis)+1-values;end
  native{g.permutation(axis)}=values;
 end
 yData=[floor(min([1;native{1}])) ceil(max([shape(1);native{1}]))];
 xData=[floor(min([1;native{2}])) ceil(max([shape(2);native{2}]))];
elseif strcmp(space,'atlas')
 shape=info.outputSizeYXZ;spacing=info.voxelSizeYXZUm;xData=[1 shape(2)];yData=[1 shape(1)];
else,error('deConfUSIon:AtlasUnderlaySpace','Unknown 3D underlay display space.');end
canvas=[diff(yData) diff(xData)]+1;
factor=max(1,ceil(512/max(canvas)));
textureSize=max(2,round(canvas*min(factor,1536/max(canvas))));
if meta.isColor
 sample=griddedInterpolant(single(meta.regionLabels),'nearest','none');
 lut=255*fusiRegionColorLUT(meta.regionInfo,numel(meta.regionInfo.name));
 lut=uint8(max(0,min(255,round(lut))));
else,sample=griddedInterpolant(single(U),'linear','none');end
[y,x]=ndgrid(linspace(yData(1),yData(2),textureSize(1)),linspace(xData(1),xData(2),textureSize(2)));
sliceCache={};
display=struct('getSlice',@getSlice,'getLabels',@getLabels,'gridSizeYXZ',shape,'textureSizeYX',textureSize, ...
 'xData',xData,'yData',yData,'spacingUm',spacing, ...
 'space',space,'atlasMode',meta.atlasMode,'source','Full-resolution atlas; display sampling only');
 function texture=getSlice(slice)
  slice=max(1,min(shape(3),round(slice)));
  for k=1:numel(sliceCache),if sliceCache{k}.slice==slice,texture=sliceCache{k}.texture;return;end;end
  if strcmp(space,'native')
   raw={y,x,slice*ones(size(y))};prepared=cell(1,3);dims=g.originalSize(g.permutation);
   for axis=1:3
    values=raw{g.permutation(axis)};
    if isfield(g,'flipAxes') && ismember(axis,g.flipAxes),values=dims(axis)+1-values;end
    prepared{axis}=1+(values-1)*g.originalSpacingUm(g.permutation(axis))/g.atlasVoxelSizeUm(axis);
   end
   p=[prepared{2}(:) prepared{1}(:) prepared{3}(:) ones(numel(y),1)]*double(T.M);
   values=sample(p(:,1),p(:,3),p(:,2));
  else,values=sample(y,x,info.atlasAPIndices(slice)*ones(size(y)));end
  values=reshape(values,textureSize);values(~isfinite(values))=0;
  if meta.isColor
   index=double(values);valid=index>=1 & index<=size(lut,1);index(~valid)=1;
   texture=zeros([textureSize 3],'uint8');
   for channel=1:3,plane=reshape(lut(index(:),channel),textureSize);plane(~valid)=0;texture(:,:,channel)=plane;end
  else,texture=values;end
  if numel(sliceCache)>=8,sliceCache(1)=[];end
  sliceCache{end+1}=struct('slice',slice,'texture',texture,'labels',[]);
  if meta.isColor,sliceCache{end}.labels=uint16(values);end
 end
 function labels=getLabels(slice)
  labels=[];if ~meta.isColor,return;end
  getSlice(slice);
  for k=1:numel(sliceCache),if sliceCache{k}.slice==slice,labels=sliceCache{k}.labels;return;end;end
 end
end
