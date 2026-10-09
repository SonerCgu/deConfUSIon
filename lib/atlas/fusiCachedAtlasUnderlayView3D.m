function [V,viewMeta,Tgrid,info]=fusiCachedAtlasUnderlayView3D(U,meta,space)
persistent entries clock implementation
% Cached nested display callbacks carry their creating workspace. Rebuild
% them after display-code updates instead of calling a newer nested function
% with an older workspace (which may not contain its new sliceCache).
currentImplementation=displayImplementation();
if isempty(entries)||~isequal(implementation,currentImplementation)
 entries={};clock=0;implementation=currentImplementation;
end
clock=clock+1;
if ~isfield(meta,'fileRevision'),[V,viewMeta,Tgrid,info]=fusiAtlasUnderlayView3D(U,meta,space);return;end
grouping='';if isfield(meta,'regionGrouping'),grouping=meta.regionGrouping;end
key=struct('revision',meta.fileRevision,'space',space,'geometry',meta.registrationKey,'grouping',grouping);
for k=1:numel(entries)
 if isequal(entries{k}.key,key)
  entry=entries{k};entries{k}.used=clock;
  V=entry.V;viewMeta=entry.viewMeta;Tgrid=entry.Tgrid;info=entry.info;return;
 end
end
[V,viewMeta,Tgrid,info]=fusiAtlasUnderlayView3D(U,meta,space);
entry=struct('key',key,'V',V,'viewMeta',viewMeta,'Tgrid',Tgrid,'info',info,'used',clock);
if numel(entries)<8,entries{end+1}=entry;
else,[~,k]=min(cellfun(@(e)e.used,entries));entries{k}=entry;end
end

function revision=displayImplementation()
names={'fusiAtlasUnderlayView3D','fusiAtlasUnderlayDisplay3D','fusiRegionColorLUT','deConfUSIon_apply_rgb2acr'};
revision=cell(size(names));
for k=1:numel(names)
 file=which(names{k});details=dir(file);
 if isempty(details),revision{k}=struct('file',file,'bytes',0,'datenum',0);
 else,revision{k}=struct('file',file,'bytes',details(1).bytes,'datenum',details(1).datenum);end
end
end
