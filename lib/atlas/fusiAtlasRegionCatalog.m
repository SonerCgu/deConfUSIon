function [catalog,excluded]=fusiAtlasRegionCatalog(labels,info)
% Integer label IDs are authoritative; display colors never define regions.
catalog=struct('id',{},'acronym',{},'name',{},'displayName',{},'voxelCount',{});excluded=[];
if isempty(labels)||~isstruct(info)||~isfield(info,'name'),return;end
names=cellstr(string(info.name(:))); acronyms=names;
if isfield(info,'acr'),acronyms=cellstr(string(info.acr(:)));end
ids=unique(abs(double(labels(:))));ids=ids(isfinite(ids)&ids>0&ids==round(ids));
valid=abs(double(labels(:)));valid=valid(isfinite(valid)&valid>=1&valid<=numel(names)&valid==round(valid));
counts=accumarray(valid,1,[numel(names) 1]);
for id=1:numel(names)
 name=names{id};acr='';if id<=numel(acronyms),acr=acronyms{id};end
 % Do not confuse ventral brain subdivisions with ventricles.
 nonTissue=~isempty(regexpi(name,'\<ventricles?\>|\<ventricular (system|space|cavity)|cerebral aqueduct|choroid plexus','once')) || ...
     any(strcmpi(strtrim(name),{'background','outside','root','unlabeled','unlabelled'}));
 if nonTissue,excluded(end+1)=id;continue;end %#ok<AGROW>
 if ~ismember(id,ids),continue;end
 catalog(end+1)=struct('id',id,'acronym',acr,'name',name, ...
  'displayName',sprintf('%s | %s',acr,name),'voxelCount',counts(id)); %#ok<AGROW>
end
if ~isempty(catalog),[~,order]=sort(lower(string({catalog.displayName})));catalog=catalog(order);end
end
