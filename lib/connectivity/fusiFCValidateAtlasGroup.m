function fusiFCValidateAtlasGroup(subjects)
% Parent IDs and detailed IDs are different label spaces, even when numeric
% IDs happen to coincide. Never combine them in a group matrix.
modes={};
for k=1:numel(subjects)
 if isfield(subjects(k),'atlasRegionInfo')&&isstruct(subjects(k).atlasRegionInfo)&& ...
   isfield(subjects(k).atlasRegionInfo,'grouping')&&~isempty(subjects(k).atlasRegionInfo.grouping)
  mode=lower(subjects(k).atlasRegionInfo.grouping);if strcmp(mode,'merged'),mode='parent';end
  modes{end+1}=mode; %#ok<AGROW>
 end
end
assert(numel(unique(modes))<=1,'deConfUSIon:FCAtlasGroupingMismatch', ...
 'Group FC cannot combine detailed and merged atlas IDs. Use the same atlas granularity in every export.');
end
