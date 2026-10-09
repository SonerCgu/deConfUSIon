function [labels,info,mapping]=fusiAtlasRegionGrouping(atlas,mode)
% Conservative parent-name grouping. Preserve detailed source atlas labels.
labels=atlas.Regions;info=atlas.infoRegions;
mapping=(1:numel(info.name))';if strcmp(mode,'Detailed'),return;end
names=info.name;acronyms=info.acr;parents=names;
for k=1:numel(names)
    name=char(names{k});
    if startsWith(lower(name),'caudoputamen')
        parents{k}='Caudoputamen (CPu)';
    else
        % Bundled atlas descriptions explicitly separate subdivisions/layers
        % with a comma. Merge only that named parent; do not infer unrelated
        % nuclei from their location or a short acronym prefix.
        parts=strsplit(name,',');parents{k}=strtrim(parts{1});
    end
end
[parentNames,first,mapping]=unique(parents,'stable');
lookup=zeros(numel(mapping)+1,1,'like',labels);lookup(2:end)=cast(mapping,'like',labels);
labels=reshape(lookup(double(labels(:))+1),size(labels));
info.name=parentNames;info.acr=acronyms(first);info.rgb=info.rgb(first,:);
if isfield(info,'rgb2'),info.rgb2=info.rgb2(first,:);end
for k=1:numel(parentNames)
    if strcmp(parentNames{k},'Caudoputamen (CPu)'),info.acr{k}='CPu';end
end
if isfield(info,'vol'),info.vol=accumarray(mapping(:),double(atlas.infoRegions.vol(:)))';end
info.groupingMode=mode;info.sourceToParent=mapping;
end
