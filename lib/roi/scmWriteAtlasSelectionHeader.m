function scmWriteAtlasSelectionHeader(fid,c,members)
if ~isfield(c,'ventriclesExcluded'),return;end
fprintf(fid,'# AtlasExcludedRegionIDs: %s\n# AtlasVentriclesExcluded: 1\n',strtrim(sprintf('%d ',c.excludedAtlasIDs)));
if isfield(c,'searchParameters')&&isfield(c.searchParameters,'uploadedMaskApplied')
 fprintf(fid,'# AtlasUploadedSCMMaskIgnored: %d\n',~c.searchParameters.uploadedMaskApplied);
end
if isfield(c,'atlasRegion')&&~isempty(c.atlasRegion)
 fprintf(fid,'# AtlasRegion: %s | %s | ID %d\n',c.atlasRegion.acronym,c.atlasRegion.name,c.atlasRegion.id);
 fprintf(fid,'# AtlasMinimumROICoverage_percent: %.12g\n',100*c.minimumAtlasCoverageFraction);
 if nargin>=3
  fractions=cellfun(@(m)m.atlasCoverageFraction,members)*100;
  fprintf(fid,'# AtlasActualROICoverage_percent_range: %.12g %.12g\n',min(fractions),max(fractions));
 else,fprintf(fid,'# AtlasActualROICoverage_percent: %.12g\n',100*c.atlasCoverageFraction);end
else,fprintf(fid,'# AtlasRegion: All labelled brain tissue\n');end
if isfield(c,'atlasProvenance')
 p=c.atlasProvenance;fprintf(fid,'# AtlasRegionFile: %s\n# AtlasGrouping: %s\n# AtlasSearchSpace: %s\n',p.file,p.grouping,p.space);
end
end
