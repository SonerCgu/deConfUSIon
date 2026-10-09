function ctx=fusiAtlasSearchContext(bundle,space,previous)
% Keep numerical labels available while viewing histology or vasculature.
if nargin<3,previous=[];end
ctx=[];meta=bundle.meta;
if meta.isColor
 file=bundle.file;
 if ~isempty(previous)&&isfield(previous,'displayProvider')&&isequal(previous.key,meta.registrationKey)&&strcmp(previous.space,space)&&strcmp(previous.provenance.file,file)&&strcmp(previous.provenance.grouping,meta.regionGrouping)
  ctx=previous;return;
 end
 [~,view]=fusiCachedAtlasUnderlayView3D(bundle.underlay,meta,space);
 labels=view.regionLabels;info=meta.regionInfo;
else
 if ~isempty(previous)&&isfield(previous,'displayProvider')&&isequal(previous.key,meta.registrationKey)&&strcmp(previous.space,space)
  ctx=previous;return;
 end
 file=fullfile(fileparts(bundle.file),'Regions_Merged.mat');
 if ~isfile(file),file=fullfile(fileparts(bundle.file),'Regions.mat');end
 if ~isempty(previous)&&isequal(previous.key,meta.registrationKey),file=previous.provenance.file;end
 if ~isfile(file),return;end
 [matched,U,regionsMeta]=fusiCachedAtlasUnderlay3D(file);
 if ~matched||~regionsMeta.isColor||~isequal(meta.registrationKey,regionsMeta.registrationKey),return;end
 desired='Parent';if ~isempty(previous)&&isequal(previous.key,meta.registrationKey),desired=previous.provenance.grouping;end
 [U,regionsMeta]=fusiAtlasRegroupUnderlay3D(U,regionsMeta,desired);
 [~,view]=fusiCachedAtlasUnderlayView3D(U,regionsMeta,space);
 labels=view.regionLabels;info=regionsMeta.regionInfo;meta=regionsMeta;
end
grouping='Detailed';if isfield(meta,'regionGrouping'),grouping=meta.regionGrouping;end
ctx=struct('labels',labels,'info',info,'key',meta.registrationKey,'space',space, ...
 'displayProvider',view.displayProvider, ...
 'provenance',struct('file',file,'transformFile',meta.transformFile, ...
 'grouping',grouping,'space',space,'arrayOrder','DV-LR-AP'));
end
