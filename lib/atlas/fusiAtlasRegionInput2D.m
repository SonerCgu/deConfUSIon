function [matched,labels,meta]=fusiAtlasRegionInput2D(S,targetSize,space)
% Keep coronal labels on their saved grid, or map back with the saved A.
% Never resize an atlas plane to the native functional recording.
if nargin<3,space='auto';end
matched=false;labels=[];meta=struct();R=struct();info=[];L=[];grouping='Detailed';
if isfield(S,'Seg')&&isstruct(S.Seg)
 Q=S.Seg;
 if ~isfield(Q,'labelMap')||~isfield(Q,'labelInfo')|| ...
   ~isfield(Q.labelInfo,'atlasInfoRegions')|| ...
   (isfield(Q,'settings')&&isfield(Q.settings,'regionResolution')&&strcmpi(Q.settings.regionResolution,'coarse')),return;end
 L=Q.labelMap;info=Q.labelInfo.atlasInfoRegions;
 if isfield(Q.labelInfo,'regionGrouping'),grouping=Q.labelInfo.regionGrouping;end
 % A one-plane step-motor segmentation saves its labels on the atlas grid.
 % Retain the original transform when FC is opened on the native movie.
 if isfield(Q.labelInfo,'type')&&strcmp(Q.labelInfo.type,'step_reg2d')&& ...
   isfield(Q.labelInfo,'files')&&numel(Q.labelInfo.files)==1&&isfile(Q.labelInfo.files{1})
  original=load(Q.labelInfo.files{1},'Reg2D');
  if isfield(original,'Reg2D'),R=original.Reg2D;end
 end
elseif isfield(S,'Reg2D')&&isstruct(S.Reg2D)&& ...
  isfield(S.Reg2D,'type')&&strcmpi(S.Reg2D.type,'simple_coronal_2d')
 R=S.Reg2D;
 if isfield(S,'atlasMode')&&~strcmpi(S.atlasMode,'regions'),return;end
 if isfield(S,'atlasInfoRegions'),info=S.atlasInfoRegions;
 elseif isfield(R,'atlasInfoRegions'),info=R.atlasInfoRegions;end
 for field={'atlasRegionLabelsLR2D','atlasRegionLabels2D','atlasRegionLabels'}
  if isfield(S,field{1})&&~isempty(S.(field{1})),L=S.(field{1});break;end
 end
 if isempty(L)&&isfield(R,'regionsImage'),L=R.regionsImage;end
 if isfield(R,'regionGrouping'),grouping=R.regionGrouping;end
elseif isfield(S,'stepMotorUnderlayMeta')&&isstruct(S.stepMotorUnderlayMeta)&& ...
  isfield(S.stepMotorUnderlayMeta,'kind')&&strcmp(S.stepMotorUnderlayMeta.kind,'deConfUSIon_step_motor_registration_underlay')&& ...
  isfield(S,'atlasRegionLabels')&&isfield(S,'atlasInfoRegions')
 L=S.atlasRegionLabels;info=S.atlasInfoRegions;grouping=S.stepMotorUnderlayMeta.grouping;
else,return;end
if isempty(L)||~ismatrix(L)||~isstruct(info)||~isfield(info,'name')||isempty(info.name),return;end
matched=true;targetSize=double(targetSize(:)');targetSize(end+1:3)=1;
assert(targetSize(3)==1,'deConfUSIon:AtlasRegionGrid','A single coronal registration cannot label multiple acquired slices.');
L=double(L);L(~isfinite(L))=0;L=round(L);fixed=size(L,[1 2]);
assert(all(abs(L(:))<=numel(info.name)),'deConfUSIon:AtlasRegionNames','Coronal region IDs do not match their saved name table.');
if ~isfield(info,'acr'),info.acr=info.name;end
if ~isfield(info,'rgb'),info.rgb=zeros(numel(info.name),3);end
if isfield(info,'groupingMode'),grouping=info.groupingMode;end
if strcmpi(grouping,'Merged'),grouping='Parent';end
if ~any(L(:)<0),L(:,1:round(fixed(2)/2))=-abs(L(:,1:round(fixed(2)/2)));end
native=fixed;hasTransform=all(isfield(R,{'A','sourceSize','outputSize'}));
if hasTransform,native=double(R.sourceSize(1:2));end
if strcmpi(space,'auto')
 % Equal native/output dimensions are ambiguous; select the saved atlas grid.
 if isequal(targetSize(1:2),fixed),space='atlas';
 elseif hasTransform&&isequal(targetSize(1:2),native),space='native';
 else,error('deConfUSIon:AtlasRegionGrid','Coronal labels belong to native %s or registered %s, not %s. Select the matching data and registration.',mat2str(native),mat2str(fixed),mat2str(targetSize(1:2)));end
end
if strcmpi(space,'native')&&hasTransform
 L=imwarp(L,invert(affine2d(double(R.A))),'nearest','OutputView',imref2d(native),'FillValues',0);
else
 assert(isequal(size(L,[1 2]),targetSize(1:2)),'deConfUSIon:AtlasRegionGrid','Coronal labels and functional data must share the saved grid.');
end
assert(isequal(size(L,[1 2 3]),targetSize),'deConfUSIon:AtlasRegionGrid','Coronal labels and functional data grids differ.');
spacing=[NaN NaN NaN];sourceSpacing=spacing;
if isfield(R,'atlasVoxelSizeYXZUm'),v=double(R.atlasVoxelSizeYXZUm(:)');spacing(1:min(3,numel(v)))=v(1:min(3,numel(v)));end
if isfield(R,'sourceVoxelSizeUm'),v=double(R.sourceVoxelSizeUm(:)');sourceSpacing(1:min(3,numel(v)))=v(1:min(3,numel(v)));end
labels=abs(L);[catalog,excluded]=fusiAtlasRegionCatalog(labels,info);
meta=struct('kind','deConfUSIon_2D_region_input','isColor',true,'atlasMode','regions', ...
 'space',space,'regionGrouping',grouping,'regionInfo',info,'atlasInfoRegions',info, ...
 'regionLabels',labels,'voxelSizeUm',spacing,'field','atlasRegionLabels2D', ...
 'transformFile','','excludedRegionIDs',excluded,'catalog',catalog, ...
 'leftHemisphereMask',L<0,'rightHemisphereMask',L>0);
meta.transform=R;meta.transform.scanGeometry=struct('originalSpacingUm',sourceSpacing,'originalSize',[native 1]);
meta.nameTable=struct('labels',(1:numel(info.name))', ...
 'names',{cellstr(string(info.acr(:)))},'fullNames',{cellstr(string(info.name(:)))});
end
