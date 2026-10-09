function varargout=scmROI(action,varargin)
% ROI sizing and fixed-support trace/export contract. X = columns, Y = rows.
switch action
 case 'size',varargout{1}=resolveSize(varargin{:});
 case 'trace',varargout{1}=trace(varargin{:});
 case 'writeSize',writeSize(varargin{:});
 case 'map',varargout{1}=mapDefinitions(varargin{:});
 case 'mask',varargout{1}=sliceMask(varargin{:});
 case 'nativeMatrix',varargout{1}=directNativeMatrix(varargin{:});
 otherwise,error('deConfUSIon:ROIAction','Unknown ROI action: %s',action);
end
end
function s=resolveSize(cfg,spacing)
if nargin<2,spacing=[NaN NaN NaN];end
known=numel(spacing)>=2&&all(isfinite(spacing(1:2))&spacing(1:2)>0);
mode='pixels';if isfield(cfg,'sizeMode'),mode=char(cfg.sizeMode);end
requested=[NaN NaN];
if strcmp(mode,'um')
 assert(known,'deConfUSIon:ROICalibration','Physical ROI sizes require verified row/column spacing. Use Scale / units.');
 requested=double(cfg.sizeUm(:)');
 assert(numel(requested)==2&&all(isfinite(requested)&requested>0),'deConfUSIon:SearchSize','Enter positive ROI width X and height Y in micrometres.');
 pixels=max(1,round(requested./spacing([2 1])));
else
 assert(strcmp(mode,'pixels'),'deConfUSIon:SearchSize','ROI size mode must be pixels or um.');
 if isfield(cfg,'sizeXY'),pixels=double(cfg.sizeXY(:)');else,pixels=double(cfg.size(:)');end
 if isscalar(pixels),pixels=[pixels pixels];end
 assert(numel(pixels)==2&&all(isfinite(pixels)&pixels>=1&pixels==round(pixels)), ...
  'deConfUSIon:SearchSize','ROI pixel counts must be positive integers [X Y].');
end
actual=[NaN NaN];if known,actual=pixels.*spacing([2 1]);end
s=struct('sizeMode',mode,'sizeXY',pixels,'requestedSizeUm',requested,'sizeXYUm',actual, ...
 'spacingUm',spacing,'calibrated',known,'roundingRule','Nearest whole native pixels; minimum one per axis. X columns, Y rows.');
end
function tc=trace(A,c)
T=size(A,ndims(A));b=c.boundsXY;
if isfield(c,'roiMaskVolumeIndices')
 shape=[size(A,1) size(A,2) 1];if ndims(A)==4,shape(3)=size(A,3);end
 assert(isequal(double(c.roiMaskSizeYXZ),double(shape)),'deConfUSIon:ROIMask','ROI volume mask does not match the functional grid.');
 V=reshape(A,[],T);V=double(V(c.roiMaskVolumeIndices,:));
elseif ndims(A)==3,V=A(b(3):b(4),b(1):b(2),:);
else,V=A(b(3):b(4),b(1):b(2),c.slice,:);end
V=double(reshape(V,[],T));
if isfield(c,'roiMaskIndices')&&~isempty(c.roiMaskIndices)
 shape=c.roiMaskSizeYX;assert(isequal(shape,size(A,[1 2])),'deConfUSIon:ROIMask','ROI mask does not match the functional grid.');
 mask=false(shape);mask(c.roiMaskIndices)=true;mask=mask(b(3):b(4),b(1):b(2));V=V(mask(:),:);
end
assert(~isempty(V),'deConfUSIon:ROIMask','ROI contains no voxels.');
if isfield(c,'baselineMode')&&strcmp(c.baselineMode,'external'),B=zeros(size(V,1),1);
else,B=mean(V(:,c.baselineFrames),2);end
if isfield(c,'coordinateProjection')&&any(~isfinite(B)|100+B<=sqrt(eps('single'))),tc=nan(1,T);return;end
assert(all(isfinite(B)&100+B>sqrt(eps('single'))),'deConfUSIon:ROIBundle','Invalid baseline in ROI.');
V=100*bsxfun(@rdivide,bsxfun(@minus,V,B),100+B);tc=mean(V,1);
end
function writeSize(fid,c)
mode='rectangle';if isfield(c,'roiMode'),mode=c.roiMode;end
if isfield(c,'roiMaskVolumeIndices'),mode='transformed volume mask';end
b=c.boundsXY;xy=[b(2)-b(1)+1 b(4)-b(3)+1];
fprintf(fid,'# ROI_SHAPE: %s\n# ROI_BOUNDING_SIZE_XY_px: %d %d\n',mode,xy);
if isfield(c,'pixelCount'),fprintf(fid,'# ROI_VOXEL_COUNT: %d\n',c.pixelCount);else,fprintf(fid,'# ROI_VOXEL_COUNT: %d\n',prod(xy));end
if isfield(c,'requestedSizeUm')&&all(isfinite(c.requestedSizeUm)),fprintf(fid,'# ROI_REQUESTED_SIZE_XY_um: %.12g %.12g\n',c.requestedSizeUm);end
if isfield(c,'sizeXYUm')&&all(isfinite(c.sizeXYUm)),fprintf(fid,'# ROI_BOUNDING_SIZE_XY_um: %.12g %.12g\n',c.sizeXYUm);end
if isfield(c,'roiMaskIndices')
 fprintf(fid,'# ROI_MASK_SIZE_YX: %d %d\n# ROI_MASK_INDICES: %s\n',c.roiMaskSizeYX,strtrim(sprintf('%d ',c.roiMaskIndices)));
 fprintf(fid,'# ROI_MASK_CONVENTION: MATLAB 1-based column-major indices on full functional slice; bounds are only the bounding box.\n');
end
if isfield(c,'roiMaskVolumeIndices')
 fprintf(fid,'# ROI_MASK_SIZE_YXZ: %d %d %d\n# ROI_VOLUME_MASK_INDICES: %s\n',c.roiMaskSizeYXZ,strtrim(sprintf('%d ',c.roiMaskVolumeIndices)));
 fprintf(fid,'# ROI_MASK_CONVENTION: MATLAB 1-based column-major indices on the full functional volume; trace uses all these voxels as one ROI.\n');
end
if isfield(c,'coordinateProjection'),fprintf(fid,'# ROI_COORDINATE_PROJECTION: %s\n',c.coordinateProjection);end
end
function m=sliceMask(c,z,shape)
m=false(shape(1:2));
if isfield(c,'roiMaskVolumeIndices')
 [y,x,zz]=ind2sub(c.roiMaskSizeYXZ,c.roiMaskVolumeIndices);q=zz==z;m(sub2ind(shape(1:2),y(q),x(q)))=true;
elseif isfield(c,'roiMaskIndices'),m(c.roiMaskIndices)=true;
else,b=c.boundsXY;m(b(3):b(4),b(1):b(2))=true;end
end
function mapped=mapDefinitions(definitions,sourceShape,targetShape,mapping,toNative,spacing)
% Pull discrete ROI membership through the same transform used by PSC.
% A tilted coronal ROI can occupy multiple acquired planes. It remains one
% ROI, with a volume mask and one voxel-weighted trace across those planes.
mapped=definitions;if isempty(definitions),return;end
assert(~isempty(mapping),'deConfUSIon:ROICoordinates','No applied transform is available to preserve ROI coordinates.');
persistent pullCache
if isempty(pullCache),pullCache={};end
key={sourceShape,targetShape,toNative,mapGeometryKey(mapping)};pull=[];
for ci=1:numel(pullCache),if isequal(pullCache{ci}.key,key),pull=pullCache{ci}.pull;break;end,end
if isempty(pull)
[y,x,z]=ndgrid(1:targetShape(1),1:targetShape(2),1:targetShape(3));
if strcmp(mapping.kind,'3D')
 T=mapping.transform;g=T.scanGeometry;
 if toNative
  raw={y,x,z};p=cell(1,3);dims=g.originalSize(g.permutation);
  for axis=1:3
   v=raw{g.permutation(axis)};if isfield(g,'flipAxes')&&ismember(axis,g.flipAxes),v=dims(axis)+1-v;end
   p{axis}=1+(v-1)*g.originalSpacingUm(g.permutation(axis))/g.atlasVoxelSizeUm(axis);
  end
  q=[p{2}(:) p{1}(:) p{3}(:) ones(numel(y),1)]*double(T.M);source=[q(:,1) q(:,3) q(:,2)];
 else
  q=[y(:) z(:) x(:) ones(numel(y),1)]/double(T.M);p={q(:,2),q(:,1),q(:,3)};raw=cell(1,3);dims=g.originalSize(g.permutation);
  for axis=1:3
   v=1+(p{axis}-1)*g.atlasVoxelSizeUm(axis)/g.originalSpacingUm(g.permutation(axis));
   if isfield(g,'flipAxes')&&ismember(axis,g.flipAxes),v=dims(axis)+1-v;end
   raw{g.permutation(axis)}=v;
  end
  source=[raw{1} raw{2} raw{3}];
 end
elseif strcmp(mapping.kind,'3DDirect')
 T=mapping.transform;M=directNativeMatrix(T);order=1:3;
 if isfield(T,'displayPermutation'),order=T.displayPermutation;end
 if ~toNative
  canonical=zeros(numel(y),3);canonical(:,order)=[y(:) x(:) z(:)];
  q=[canonical(:,[2 1 3]) ones(numel(y),1)]/M;source=q(:,[2 1 3]);
 else
  q=[x(:) y(:) z(:) ones(numel(y),1)]*M;canonical=q(:,[2 1 3]);source=canonical(:,order);
 end
elseif strcmp(mapping.kind,'2D')
 source=nan(numel(y),3);
 for plane=1:numel(mapping.sourceSlices)
  nativeSlice=mapping.sourceSlices(plane);A=mapping.matrices{plane};transpose=mapping.transpose(plane);
  if toNative
   take=z(:)==nativeSlice;xx=x(take);yy=y(take);if transpose,tmp=xx;xx=yy;yy=tmp;end
   q=[xx yy ones(nnz(take),1)]*A;source(take,:)=[q(:,2) q(:,1) repmat(plane,nnz(take),1)];
  else
   take=z(:)==plane;q=[x(take) y(take) ones(nnz(take),1)]/A;
   xx=q(:,1);yy=q(:,2);if transpose,tmp=xx;xx=yy;yy=tmp;end
   source(take,:)=[yy xx repmat(nativeSlice,nnz(take),1)];
  end
 end
else,error('deConfUSIon:ROICoordinates','Unsupported ROI transform.');end
source=round(source);valid=all(isfinite(source),2)&all(source>=1 & source<=sourceShape,2);
pull=zeros(numel(y),1);pull(valid)=sub2ind(sourceShape,source(valid,1),source(valid,2),source(valid,3));
pull=uint32(pull);
if numel(pull)*4<=32*1024^2
 while ~isempty(pullCache)&&(numel(pullCache)>=4||sum(cellfun(@(e)numel(e.pull)*4,pullCache))+numel(pull)*4>32*1024^2),pullCache(1)=[];end
 pullCache{end+1}=struct('key',{key},'pull',pull);
end
end
for k=1:numel(definitions)
 c=definitions{k};
 if isfield(c,'roiMaskVolumeIndices'),input=c.roiMaskVolumeIndices;
 elseif isfield(c,'roiMaskIndices'),input=c.roiMaskIndices+(c.slice-1)*prod(sourceShape(1:2));
 else
  b=c.boundsXY;[yy,xx]=ndgrid(b(3):b(4),b(1):b(2));
  input=sub2ind(sourceShape,yy(:),xx(:),repmat(c.slice,numel(yy),1));
 end
 indices=find(ismember(pull,uint32(input)));
 if isfield(c,'roiMaskIndices'),c=rmfield(c,{'roiMaskIndices','roiMaskSizeYX'});end
 c.roiMaskVolumeIndices=indices(:)';c.roiMaskSizeYXZ=targetShape;c.pixelCount=numel(indices);
 c.coordinateProjection='Nearest-neighbour mask through the applied functional transform; all mapped voxels form one ROI.';
 c.coordinateSpace='atlas';if toNative,c.coordinateSpace='native';end
 if ~isempty(indices)
  [yy,xx,zz]=ind2sub(targetShape,indices);c.slice=min(zz);c.activeSlices=unique(zz(:)');
  c.boundsXY=[min(xx) max(xx) min(yy) max(yy)];c.sizeXY=[max(xx)-min(xx)+1 max(yy)-min(yy)+1];
  c.sizeXYUm=c.sizeXY.*spacing([2 1]);
 else,c.activeSlices=[];end
 mapped{k}=c;
end
end

function key=mapGeometryKey(mapping)
key=struct('kind',mapping.kind);
if isfield(mapping,'transform')
 T=mapping.transform;key.transform=struct();
 for name={'M','warpA','scanGeometry','displayPermutation'}
  if isfield(T,name{1}),key.transform.(name{1})=T.(name{1});end
 end
else
 for name={'sourceSlices','matrices','transpose'}
  if isfield(mapping,name{1}),key.(name{1})=mapping.(name{1});end
 end
end
end

function M=directNativeMatrix(T)
% Compose legacy orientation/resampling with its saved intrinsic affine.
% Evaluate a basis so row-vector MATLAB XYZ conventions stay explicit.
if isfield(T,'warpA'),M=double(T.warpA);else,M=double(T.M);end
if ~isfield(T,'scanGeometry')||isempty(T.scanGeometry),return;end
g=T.scanGeometry;points=[0 0 0;eye(3)];raw=points(:,[2 1 3]);p=raw(:,g.permutation);
sv=double(g.originalSpacingUm(g.permutation));av=double(g.atlasVoxelSizeUm);dims=double(g.originalSize(g.permutation));
if isfield(g,'convention')&&strcmp(g.convention,'coronal_stack_v2')
 if isfield(g,'flipAxes'),for axis=g.flipAxes,p(:,axis)=dims(axis)+1-p(:,axis);end,end
 p=1+(p-1).*sv./av;
else
 p=1+(p-1).*sv./av;n=round((dims-1).*sv./av)+1;
 p(:,2)=n(2)+1-p(:,2);p(:,3)=n(3)+1-p(:,3);p=p(:,[3 1 2]);
end
q=p(:,[2 1 3]);preparation=eye(4);preparation(1:3,1:3)=q(2:4,:)-q(1,:);preparation(4,1:3)=q(1,:);
M=preparation*M;
end
