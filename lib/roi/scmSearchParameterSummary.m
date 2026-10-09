function textOut=scmSearchParameterSummary(candidates,skipped,source)
% Readable audit of the actual search, shared by review and TXT exports.
if nargin<2,skipped={};end
if nargin<3,source='';end
lines={['Recording: ' char(source)]};
if isempty(candidates),textOut=strjoin(lines,newline);return;end
c=candidates{1};xy=[diff(c.boundsXY(1:2))+1 diff(c.boundsXY(3:4))+1];
if isfield(c,'searchScanLabel')
 lines{end+1}=sprintf('ROI search source: %s | source TR %.9g s',c.searchScanLabel,c.searchTR);
 lines{end+1}=['Searched scans: ' strjoin(c.searchParameters.searchedScanLabels,'; ')];
 lines{end+1}='Time windows: minutes within each individual scan, starting at zero; stitched plot offsets are not used.';
 lines{end+1}='Scores describe the search source; exported ROI traces describe the displayed overlay recording.';
end
shape=sprintf('%d x %d pixels (X x Y)',xy);
if isfield(c,'roiMode')&&strcmp(c.roiMode,'region'),shape=sprintf('Whole selected region per slice (%d voxels in this candidate)',c.pixelCount);end
lines{end+1}=sprintf('ROI: %s',shape);
if isfield(c,'sizeXYUm')&&all(isfinite(c.sizeXYUm))
 physical=sprintf('Physical bounding size (X x Y): %.6g x %.6g um',c.sizeXYUm);
 if isfield(c,'requestedSizeUm')&&all(isfinite(c.requestedSizeUm)),physical=sprintf('%s | requested %.6g x %.6g um',physical,c.requestedSizeUm);end
 lines{end+1}=physical;
end
lines{end+1}=sprintf('Search: %.6g-%.6g min | Plateau: %.6g min | Window mode: %s',c.searchIntervalSec/60,c.plateauSec/60,c.windowMode);
if isfield(c,'baselineMode')&&strcmp(c.baselineMode,'external')
 lines{end+1}=['Baseline: ' fusiBaselineReference('label',struct('reference',c.baselineReference))];
 lines{end+1}=sprintf('Baseline source file: %s | TR: %.9g s | Source frames: %s | Searched slices: %s', ...
     c.baselineReference.sourceFile,c.baselineReference.TR,mat2str(c.baselineReference.frames),mat2str(c.searchedSlices));
elseif isfield(c,'searchParameters')&&isfield(c.searchParameters,'configuredBaselineRange')&&isfield(c.searchParameters,'configuredBaselineUnits')
 lines{end+1}=sprintf('Baseline: configured %.6g-%.6g %s; sampled %.6g-%.6g s | Searched slices: %s',c.searchParameters.configuredBaselineRange,c.searchParameters.configuredBaselineUnits,c.baselineSampleSec([1 end]),mat2str(c.searchedSlices));
else
 lines{end+1}=sprintf('Baseline used: %.6g-%.6g s; sampled %.6g-%.6g s | Searched slices: %s',c.baselineSec,c.baselineSampleSec([1 end]),mat2str(c.searchedSlices));
end
region='All eligible tissue';if isfield(c,'atlasRegion')&&~isempty(c.atlasRegion),region=sprintf('%s | %s',c.atlasRegion.acronym,c.atlasRegion.name);end
lines{end+1}=['Region: ' region];
if isfield(c,'searchParameters')&&isfield(c.searchParameters,'selectedAtlasRegions')&&~isempty(c.searchParameters.selectedAtlasRegions)
 chosen=c.searchParameters.selectedAtlasRegions;
 lines{end+1}=['Selected regions (searched and ranked separately): ' strjoin({chosen.displayName},'; ')];
end
if isfield(c,'minimumAtlasCoverageFraction')&&isfinite(c.minimumAtlasCoverageFraction)
 lines{end}=sprintf('%s | Minimum region coverage: %.6g%%',lines{end},100*c.minimumAtlasCoverageFraction);
end
if isfield(c,'ventriclesExcluded'),lines{end+1}='Atlas ventricles and background excluded from every ROI pixel.';end
if isfield(c,'searchParameters')&&isfield(c.searchParameters,'uploadedMaskApplied')
 lines{end+1}=['Uploaded SCM mask: ' choose(c.searchParameters.uploadedMaskApplied, ...
  'applied to native search','ignored for atlas region search (paint, bounds, sides and acquired sample validity still apply).')];
end
if isfield(c,'searchParameters')&&isfield(c.searchParameters,'bilateral')&&~c.searchParameters.bilateral
 lines{end+1}=sprintf('Sides searched together | Search bounds [x1 x2 y1 y2]: %s',mat2str(c.searchBoundsXY));
else
 lines{end+1}=sprintf('Target side: %s | Left/right split X: %.6g | Search bounds [x1 x2 y1 y2]: %s',choose(c.leftIsTarget,'image-left','image-right'),c.splitX,mat2str(c.searchBoundsXY));
end
if isfield(c,'searchParameters')
 p=c.searchParameters;lines{end+1}=sprintf('Requested roles: %s | Top ROIs [Target Control]: %s | TR: %.9g s',p.roiSelection,mat2str(p.topCount),p.TR);
 lines{end+1}=sprintf('Painted search area: %s | Display mode: %s',choose(p.hasPaintMask,'yes','no'),p.displayMode);
end
if isfield(c,'atlasProvenance')
 p=c.atlasProvenance;lines{end+1}=sprintf('Atlas grouping: %s | Space: %s | Region file: %s',p.grouping,p.space,p.file);
end
lines{end+1}=sprintf('Candidates: %d | Skipped slice/role searches: %d',numel(candidates),numel(skipped));
if ~isempty(skipped),lines{end+1}=['Skipped: ' strjoin(skipped,', ')];end
lines{end+1}='Selection: exploratory maximum of the ROI voxel mean, using exact percent rebasing per voxel. Selection is not outlier removal.';
textOut=strjoin(lines,newline);
end
function v=choose(condition,a,b)
if condition,v=a;else,v=b;end
end
