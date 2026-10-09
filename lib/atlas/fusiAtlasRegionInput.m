function [matched,labels,meta]=fusiAtlasRegionInput(S,targetSize,space)
% Sample a saved 3D region bundle on its actual recording grid, never stretch
% the complete atlas through the acquired AP range by resizing its indices.
if nargin<3,space='auto';end
[matched,U,meta]=fusiReadAtlasUnderlay3D(S);labels=[];if ~matched,return;end
assert(meta.isColor&&strcmpi(meta.atlasMode,'regions'),'deConfUSIon:AtlasRegionInput', ...
 'Select Regions_All.mat or Regions_Merged.mat for integer ROI labels.');
targetSize=double(targetSize(:)');targetSize(end+1:3)=1;
native=double(meta.transform.scanGeometry.originalSize);fixed=double(meta.transform.outputSize);
recording=[fixed(1:2) native(3)];
if strcmp(space,'auto')
 if isequal(targetSize,native),space='native';
 elseif isequal(targetSize,fixed),space='full';
 elseif isequal(targetSize,recording),space='atlas';
 else,error('deConfUSIon:AtlasRegionGrid','Region bundle belongs to native %s or aligned %s, but functional data is %s. Use the matching recording/registration.',mat2str(native),mat2str(recording),mat2str(targetSize));end
end
if strcmp(space,'full'),labels=meta.regionLabels;
else,[~,view]=fusiAtlasUnderlayView3D(U,meta,space);labels=view.regionLabels;end
assert(isequal(size(labels,[1 2 3]),targetSize),'deConfUSIon:AtlasRegionGrid','Region labels and functional data must share the same physical grid.');
meta.space=space;meta.atlasInfoRegions=meta.regionInfo;meta.field='atlasRegionLabels3D';
[catalog,excluded]=fusiAtlasRegionCatalog(labels,meta.regionInfo);
meta.excludedRegionIDs=excluded;meta.catalog=catalog;
meta.nameTable=struct('labels',(1:numel(meta.regionInfo.name))', ...
 'names',{cellstr(string(meta.regionInfo.acr(:)))},'fullNames',{cellstr(string(meta.regionInfo.name(:)))});
% Signed hemisphere labels on the native grid follow the saved geometry.
% In atlas display order, LR is column (not AP slice number).
if strcmp(space,'native')
 sz=size(labels,[1 2 3]);[y,x,z]=ndgrid(1:sz(1),1:sz(2),1:sz(3));raw={y,x,z};g=meta.transform.scanGeometry;
 prep=cell(1,3);dims=sz(g.permutation);
 for k=1:3
  v=raw{g.permutation(k)};if isfield(g,'flipAxes')&&ismember(k,g.flipAxes),v=dims(k)+1-v;end
  prep{k}=1+(v-1)*g.originalSpacingUm(g.permutation(k))/g.atlasVoxelSizeUm(k);
 end
 p=[prep{2}(:) prep{1}(:) prep{3}(:) ones(numel(labels),1)]*double(meta.transform.M);
 atlasColumn=reshape(p(:,3),sz);
else,atlasColumn=repmat(reshape(1:size(labels,2),1,[],1),size(labels,1),1,size(labels,3));end
% Allen atlas convention matches AtlasRegistration's Atlas R / Atlas L.
meta.leftHemisphereMask=atlasColumn>(fixed(2)+1)/2;
meta.rightHemisphereMask=~meta.leftHemisphereMask;
end
