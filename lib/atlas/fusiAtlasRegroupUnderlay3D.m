function [U,meta]=fusiAtlasRegroupUnderlay3D(U,meta,grouping)
% Offer both label granularities for legacy Regions.mat bundles in memory.
persistent entries
if isempty(entries),entries={};end
if isempty(grouping)||~meta.isColor,return;end
current='Detailed';if isfield(meta,'regionGrouping'),current=meta.regionGrouping;end
if strcmpi(current,grouping),return;end
key=[];
if isfield(meta,'fileRevision')
 key=struct('revision',meta.fileRevision,'geometry',meta.registrationKey,'grouping',grouping);
 for k=1:numel(entries)
  if isequal(entries{k}.key,key),U=entries{k}.U;meta=entries{k}.meta;return;end
 end
end
if strcmpi(current,'Detailed')&&strcmpi(grouping,'Parent')
 atlas=struct('Regions',meta.regionLabels,'infoRegions',meta.regionInfo);
else
 source=fullfile(deConfUSIon_root(),'allen_brain_atlas.mat');
 if isfield(meta.transform,'atlasSource')&&isfile(meta.transform.atlasSource),source=meta.transform.atlasSource;end
 S=load(source);if isfield(S,'atlas'),atlas=S.atlas;else,atlas=S;end
 assert(isequal(size(atlas.Regions,[1 2 3]),double(meta.transform.atlasCanonicalSize)), ...
  'deConfUSIon:AtlasRegionGrid','Detailed atlas reference must match the saved registration.');
 atlas.Regions=permute(atlas.Regions,[2 3 1]);
end
[labels,info]=fusiAtlasRegionGrouping(atlas,grouping);
meta.regionLabels=labels;meta.regionInfo=info;meta.regionGrouping=grouping;
meta.transform.regionGrouping=grouping;
lut=255*fusiRegionColorLUT(info,numel(info.name));lut=uint8(max(0,min(255,round(lut))));
ix=double(labels);valid=ix>=1&ix<=size(lut,1);ix(~valid)=1;
U=zeros([size(labels,1) size(labels,2) 3 size(labels,3)],'uint8');
for channel=1:3
 values=reshape(lut(ix(:),channel),size(labels));values(~valid)=0;
 U(:,:,channel,:)=reshape(values,size(labels,1),size(labels,2),1,[]);
end
if ~isempty(key)
 if numel(entries)>=4,entries(1)=[];end
 entries{end+1}=struct('key',key,'U',U,'meta',meta);
end
end
