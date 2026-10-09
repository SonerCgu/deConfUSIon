function [entries,names,ctx]=fusiAtlasUnderlayLibrary2D(files,targetSize)
% Read each registered motor plane independently; never stretch AP labels.
if ischar(files)||isstring(files),files=cellstr(files);end
entries={};names={};ctx=[];targetSize=double(targetSize);targetSize(end+1:3)=1;
if numel(files)~=targetSize(3),return;end
modes={'histology','vascular','regions'};volumes=cell(1,3);info=struct();
spacing=[NaN NaN NaN];
recordedSpacing=nan(numel(files),2);hasSpacingMetadata=false;
for k=1:numel(files)
 if ~isfile(files{k}),return;end
 S=load(files{k});R=S;if isfield(S,'Reg2D'),R=S.Reg2D;end
 if ~isfield(R,'type')||~strcmpi(R.type,'simple_coronal_2d'),return;end
 if isfield(R,'atlasVoxelSizeYXZUm')
  hasSpacingMetadata=true;
  v=double(R.atlasVoxelSizeYXZUm(:)');
  if numel(v)>=2 && all(isfinite(v(1:2)) & v(1:2)>0)
   recordedSpacing(k,:)=v(1:2);
  end
 end
 for m=1:3
  field=[modes{m} 'Image'];plane=[];
  if isfield(R,field),plane=R.(field);elseif isfield(S,field),plane=S.(field);end
  external=fullfile(fileparts(files{k}),sprintf('AtlasUnderlay_%s_slice%03d.mat',modes{m},R.atlasSliceIndex));
  E=struct();if isfile(external),E=load(external);end
  if isempty(plane)&&isfield(E,'atlasUnderlay'),plane=E.atlasUnderlay;end
  if m==3
   if isfield(E,'atlasRegionLabels2D'),plane=E.atlasRegionLabels2D;end
   candidateInfo=struct();
   if isfield(E,'atlasInfoRegions'),candidateInfo=E.atlasInfoRegions;
   elseif isfield(R,'atlasInfoRegions'),candidateInfo=R.atlasInfoRegions;
   elseif isfield(S,'atlasInfoRegions'),candidateInfo=S.atlasInfoRegions;end
   if isfield(candidateInfo,'name')
    if isfield(info,'name'),assert(isequal(info.name,candidateInfo.name),'deConfUSIon:AtlasRegionNames','Motor slices use different region label tables.');end
    info=candidateInfo;
   end
  end
  if isempty(plane),continue;end
  assert(ismatrix(plane)&&isequal(size(plane),targetSize(1:2)), ...
   'deConfUSIon:AtlasRegionGrid','Registered atlas plane does not match the functional output grid.');
  if isempty(volumes{m}),volumes{m}=zeros(targetSize,'like',plane);end
  volumes{m}(:,:,k)=plane;
 end
end
if all(isfinite(recordedSpacing(:))) && all(all(recordedSpacing==recordedSpacing(1,:)))
 spacing(1:2)=recordedSpacing(1,:);
elseif ~hasSpacingMetadata,spacing=legacyReferenceSpacing(targetSize(1:2));end
if ~isempty(volumes{3})&&~isfield(info,'name')
 % Older coronal registration exports used this bundled atlas, but omitted
 % the table from their transform. Matching slice underlay files take priority.
 source=fullfile(deConfUSIon_root(),'allen_brain_atlas.mat');
 if isfile(source),A=load(source);if isfield(A,'atlas'),A=A.atlas;end;info=A.infoRegions;end
end
labels=volumes{3};
for m=1:2
 if isempty(volumes{m}),continue;end
 meta=struct('isColor',false,'regionLabels',[],'regionInfo',struct(),'atlasMode',modes{m},'voxelSizeUm',spacing);
 entries{end+1}=struct('data',volumes{m},'meta',meta,'grouping','Detailed'); %#ok<AGROW>
 names{end+1}=[upper(modes{m}(1)) modes{m}(2:end)]; %#ok<AGROW>
end
if isempty(labels)||~isfield(info,'name'),return;end
for grouping={'Detailed','Parent'}
 [L,I]=fusiAtlasRegionGrouping(struct('Regions',uint16(abs(labels)),'infoRegions',info),grouping{1});
 meta=struct('isColor',true,'regionLabels',L,'regionInfo',I,'atlasMode','regions','voxelSizeUm',spacing);
 entries{end+1}=struct('data',L,'meta',meta,'grouping',grouping{1}); %#ok<AGROW>
 if strcmp(grouping{1},'Detailed'),names{end+1}='Regions: all';else,names{end+1}='Regions: merged';end %#ok<AGROW>
end
ctx=struct('labels',entries{end}.meta.regionLabels,'info',entries{end}.meta.regionInfo, ...
 'provenance',struct('file',strjoin(files,'; '),'transformFile',strjoin(files,'; '), ...
 'grouping','Parent','space','atlas','arrayOrder','row-column-source slice'));
end

function spacing=legacyReferenceSpacing(shape)
% Old Reg2D files use this toolbox's fixed coronal atlas grid. Verify the
% full reference dimensions before recovering its calibration, once per file.
persistent signature planeSize voxel
spacing=[NaN NaN NaN];source=fullfile(deConfUSIon_root(),'allen_brain_atlas.mat');
if ~isfile(source),return;end
d=dir(source);key={source,d.bytes,d.datenum};
if ~isequal(key,signature)
 signature=key;planeSize=[];voxel=[];
 A=load(source,'atlas');
 if isfield(A,'atlas') && all(isfield(A.atlas,{'Histology','VoxelSize'}))
  planeSize=size(A.atlas.Histology,[2 3]);voxel=double(A.atlas.VoxelSize([2 3]));
 end
end
if isequal(double(shape),double(planeSize)) && numel(voxel)==2 && all(isfinite(voxel) & voxel>0)
 spacing(1:2)=voxel;
end
end
