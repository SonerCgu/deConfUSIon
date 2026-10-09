function [V,viewMeta,Tgrid,info]=fusiAtlasUnderlayView3D(U,meta,space)
% Preview anatomy in native coordinates; warp view keeps acquired slice count.
T=meta.transform;g=T.scanGeometry;[Tgrid,info]=fusiAtlasRecordingGrid3D(T);
viewMeta=meta;
if strcmp(space,'native')
 sz=double(g.originalSize);[y,x,z]=ndgrid(1:sz(1),1:sz(2),1:sz(3));raw={y,x,z};
 prepared=cell(1,3);dims=sz(g.permutation);
 for axis=1:3
  values=raw{g.permutation(axis)};
  if isfield(g,'flipAxes') && ismember(axis,g.flipAxes),values=dims(axis)+1-values;end
  prepared{axis}=1+(values-1)*g.originalSpacingUm(g.permutation(axis))/g.atlasVoxelSizeUm(axis);
 end
 points=[prepared{2}(:) prepared{1}(:) prepared{3}(:) ones(numel(y),1)]*double(T.M);
 q={reshape(points(:,1),sz),reshape(points(:,3),sz),reshape(points(:,2),sz)};
 viewMeta.voxelSizeUm=g.originalSpacingUm;
elseif strcmp(space,'atlas')
 [y,x,z]=ndgrid(1:size(U,1),1:size(U,2),info.atlasAPIndices);q={y,x,z};
 viewMeta.voxelSizeUm=info.voxelSizeYXZUm;
else,error('deConfUSIon:AtlasUnderlaySpace','Unknown 3D underlay space.');end
if meta.isColor
 labels=cast(interpn(single(meta.regionLabels),q{:},'nearest',0),'like',meta.regionLabels);
 viewMeta.regionLabels=labels;lut=255*fusiRegionColorLUT(meta.regionInfo,numel(meta.regionInfo.name));
 lut=uint8(max(0,min(255,round(lut))));ix=double(labels);valid=ix>=1 & ix<=size(lut,1);ix(~valid)=1;
 V=zeros([size(labels,1) size(labels,2) 3 size(labels,3)],'uint8');
 for channel=1:3
  values=reshape(lut(ix(:),channel),size(labels));values(~valid)=0;
  V(:,:,channel,:)=reshape(values,size(labels,1),size(labels,2),1,[]);
 end
else,V=interpn(single(U),q{:},'linear',0);end
viewMeta.displayProvider=fusiAtlasUnderlayDisplay3D(U,meta,space);
end
