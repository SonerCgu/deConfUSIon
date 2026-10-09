function bundle=fusiSaveAtlasUnderlays3D(atlas,Transf,transformFile)
% Fixed atlas anatomy and labels paired with one explicitly saved affine.
transformFile=fusiAnalysisOutputPath(transformFile);
atlas=deConfUSIon_apply_rgb2acr(atlas);
sz=[size(atlas.Histology,1) size(atlas.Histology,2) size(atlas.Histology,3)];
assert(isequal(double(Transf.size),double(sz)),'deConfUSIon:AtlasUnderlayGrid','Transform and fixed atlas grids differ.');
mode='Detailed';if isfield(Transf,'regionGrouping'),mode=Transf.regionGrouping;end
folder=fileparts(transformFile);if isempty(folder),folder=pwd;transformFile=fullfile(folder,transformFile);end
stamp=char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
folder=fusiUniqueOutputFolder(fullfile(folder,'AtlasUnderlays3D'),stamp);
bundle=struct('folder',folder,'histology',fullfile(folder,'Histology.mat'), ...
 'vascular',fullfile(folder,'Vascular.mat'),'regions',fullfile(folder,'Regions.mat'), ...
 'regionsAll',fullfile(folder,'Regions_All.mat'),'regionsMerged',fullfile(folder,'Regions_Merged.mat'), ...
 'regionList',fullfile(folder,'RegionList.txt'),'regionListAll',fullfile(folder,'RegionList_All.txt'), ...
 'regionListMerged',fullfile(folder,'RegionList_Merged.txt'),'transformFile',transformFile, ...
 'pairedTransformFile',fullfile(folder,'Transformation.mat'), ...
 'readme',fullfile(folder,'README.txt'), ...
 'arrayOrder','DV-LR-AP','voxelSizeUm',double(atlas.VoxelSize([2 3 1])));
% The affine remains in the canonical atlas coordinate system. Only the
% final displayed array is permuted to coronal [row column slice].
Transf.displayPermutation=[2 3 1];Transf.atlasCanonicalSize=sz;
Transf.outputSize=sz(Transf.displayPermutation);
Transf.underlayArrayOrder=bundle.arrayOrder;
Transf.atlasUnderlays=bundle;
atlasUnderlayMeta=struct('kind','deConfUSIon_3D_registration_underlay','version',1, ...
 'arrayOrder',bundle.arrayOrder,'voxelSizeUm',bundle.voxelSizeUm, ...
 'transformFile',bundle.pairedTransformFile,'registrationFile',transformFile, ...
 'regionGrouping',mode,'createdAt',stamp);
for item={'histology','vascular'}
 atlasMode=item{1};
  field=[upper(atlasMode(1)) atlasMode(2:end)];atlasUnderlay=permute(atlas.(field),[2 3 1]);brainImage=atlasUnderlay; %#ok<NASGU>
  save(bundle.(atlasMode),'atlasUnderlay','brainImage','atlasMode','atlasUnderlayMeta','Transf','-v7.3');
end
writeRegions('Detailed',bundle.regionsAll,bundle.regionListAll);
writeRegions('Parent',bundle.regionsMerged,bundle.regionListMerged);
% Preserve the old filename as an alias for the GUI's selected grouping.
if strcmpi(mode,'Detailed'),selected=bundle.regionsAll;list=bundle.regionListAll;
else,selected=bundle.regionsMerged;list=bundle.regionListMerged;end
copyfile(selected,bundle.regions);copyfile(list,bundle.regionList);
% This immutable copy travels with the underlays. It is never a mutable
% latest-transform alias from another save or a different animal.
save(bundle.pairedTransformFile,'Transf');
fid=fopen(bundle.readme,'w');assert(fid>=0,'Could not create atlas bundle guide.');
guideGuard=onCleanup(@()fclose(fid)); %#ok<NASGU>
nativeSize='not recorded (legacy transform)';
if isfield(Transf,'scanGeometry') && isstruct(Transf.scanGeometry) && isfield(Transf.scanGeometry,'originalSize')
 nativeSize=mat2str(Transf.scanGeometry.originalSize);
end
fprintf(fid,['Saved atlas registration bundle: %s\n' ...
 'Transformation.mat is the exact transform paired with these underlays.\n' ...
 'Load Histology.mat, Vascular.mat, Regions_All.mat or Regions_Merged.mat\n' ...
 'with LOAD NEW UNDERLAY in SCM or Video. The paired 3D alignment is applied\n' ...
 'from the original native functional data; reference anatomy is upright.\n' ...
 'WARP FUNCTIONAL TO ATLAS opens a transform picker for an explicit choice.\n' ...
 'Array order: DV-LR-AP. Native recording size: %s.\n' ...
 'The viewers retain one coronal atlas plane per acquired source slice.\n' ...
 'Full atlas reference volumes are saved here to retain high-resolution anatomy.\n' ...
 'Original registration file: %s\n'],stamp,nativeSize,transformFile);

 function writeRegions(groupMode,file,listFile)
  [labels,info,mapping]=fusiAtlasRegionGrouping(atlas,groupMode);
  corrected=deConfUSIon_apply_rgb2acr(struct('infoRegions',info));info=corrected.infoRegions;
  labelVolume=permute(labels,[2 3 1]);lut=255*fusiRegionColorLUT(info,numel(info.name));
  lut=uint8(max(0,min(255,round(lut))));
  ix=double(labelVolume);valid=ix>=1 & ix<=size(lut,1);ix(~valid)=1;
  rgb=zeros([size(labelVolume,1) size(labelVolume,2) 3 size(labelVolume,3)],'uint8');
  for channel=1:3
   values=reshape(lut(ix(:),channel),size(labelVolume));values(~valid)=0;
   rgb(:,:,channel,:)=reshape(values,size(labelVolume,1),size(labelVolume,2),1,[]);
  end
  regionTransform=Transf;regionTransform.regionGrouping=groupMode;
  regionMeta=atlasUnderlayMeta;regionMeta.regionGrouping=groupMode;
  [atlasRegionCatalog,atlasExcludedRegionIDs]=fusiAtlasRegionCatalog(labelVolume,info);
  payload=struct('atlasUnderlay',labelVolume,'atlasRegionLabels3D',labelVolume, ...
   'atlasUnderlayRGB',rgb,'brainImage',rgb,'atlasInfoRegions',info,'atlasMode','regions', ...
   'atlasUnderlayMeta',regionMeta,'Transf',regionTransform,'atlasSourceToRegion',mapping, ...
   'atlasRegionCatalog',atlasRegionCatalog,'atlasExcludedRegionIDs',atlasExcludedRegionIDs, ...
   'regionListFile',listFile);
  save(file,'-struct','payload','-v7.3');
  fid=fopen(listFile,'w');assert(fid>=0,'Could not create region list.');guard=onCleanup(@()fclose(fid)); %#ok<NASGU>
  fprintf(fid,'3D atlas regions; %s grouping; array order DV-LR-AP\nID\tAcronym\tName\tAtlas voxel count\tSource label IDs\n',groupMode);
  counts=accumarray(double(labels(:))+1,1,[numel(info.name)+1 1]);
  for k=1:numel(info.name)
   source=strtrim(sprintf('%d ',find(mapping==k)));
   fprintf(fid,'%d\t%s\t%s\t%d\t%s\n',k,info.acr{k},info.name{k},counts(k+1),source);
  end
 end
end
