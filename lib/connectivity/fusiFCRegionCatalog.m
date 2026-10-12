function catalog=fusiFCRegionCatalog(names,T,labels,atlas)
% Keep selector indices separate from signed anatomical IDs.
if nargin<3,labels=[];end;if nargin<4,atlas=[];end
names=cellstr(string(names));full=fusiFCFullRegionNames(names,T);
catalog=struct('id',{},'acronym',{},'name',{},'displayName',{},'voxelCount',{});
for k=1:numel(names)
 acronym=regexprep(strtrim(names{k}),'\s*\[[^\]]*\]\s*$','');
 if contains(acronym,'|'),acronym=strtrim(extractBefore(acronym,'|'));end
 count=0;if k<=numel(labels)&&~isempty(atlas)
  id=labels(k);if startsWith(names{k},'L_')||startsWith(names{k},'R_')||any(labels<0),count=nnz(atlas==id);else,count=nnz(abs(atlas)==abs(id));end
 end
 catalog(k)=struct('id',k,'acronym',acronym,'name',full{k}, ...
  'displayName',[acronym ' | ' full{k}],'voxelCount',count);
end
end
