function [matched,U,meta]=fusiCachedAtlasUnderlay3D(file)
% Bounded shared cache; invalidate if the saved file changes on disk.
persistent entries clock
if isempty(entries),entries={};clock=0;end
clock=clock+1;matched=false;U=[];meta=struct();details=dir(file);if isempty(details),return;end
revision=struct('file',char(file),'bytes',details(1).bytes,'datenum',details(1).datenum);
for k=1:numel(entries)
 if isequal(entries{k}.revision,revision)
  entries{k}.used=clock;matched=true;U=entries{k}.U;meta=entries{k}.meta;return;
 end
end
if ~endsWith(lower(file),'.mat'),return;end
variables=whos('-file',file);if ~any(strcmp({variables.name},'atlasUnderlayMeta')),return;end
header=load(file,'atlasUnderlayMeta');
if ~isfield(header.atlasUnderlayMeta,'kind')||~strcmp(header.atlasUnderlayMeta.kind,'deConfUSIon_3D_registration_underlay'),return;end
S=load(file);[matched,U,meta]=fusiReadAtlasUnderlay3D(S);if ~matched,return;end
meta.fileRevision=revision;
entry=struct('revision',revision,'U',U,'meta',meta,'used',clock);
if numel(entries)<4,entries{end+1}=entry;
else,[~,k]=min(cellfun(@(e)e.used,entries));entries{k}=entry;end
end
