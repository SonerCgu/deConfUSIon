function file=scmExportSearchParameters(folder,candidates,source,skipped,name)
if nargin<4,skipped={};end
if nargin<5,name='Analysis_Parameters.txt';end
file=fullfile(folder,name);fid=fopen(file,'w','n','UTF-8');
assert(fid>=0,'deConfUSIon:ROIParameters','Could not write search parameters: %s',file);
guard=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'Automatic SCM ROI analysis\nExported: %s\n\n%s\n',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')),scmSearchParameterSummary(candidates,skipped,source));
fprintf(fid,'\nExported ROI members (slice, role, bounds, selected window, coverage):\n');
for k=1:numel(candidates)
 c=candidates{k};fprintf(fid,'%d. Slice %d | %s | %s | %.9g-%.9g min | mean PSC %.9g%%',k,c.slice,c.role,mat2str(c.boundsXY),c.signalSampleSec([1 end])/60,c.meanPSC);
 if isfield(c,'pixelCount'),fprintf(fid,' | %d voxels',c.pixelCount);end
 if isfield(c,'sizeXYUm')&&all(isfinite(c.sizeXYUm)),fprintf(fid,' | bounds X/Y %.9g x %.9g um',c.sizeXYUm);end
 if isfield(c,'selectedRegionIncludedFraction'),fprintf(fid,' | selected region included %.6g%%',100*c.selectedRegionIncludedFraction);end
 if isfield(c,'atlasCoverageFraction')&&isfinite(c.atlasCoverageFraction),fprintf(fid,' | region coverage %.6g%%',100*c.atlasCoverageFraction);end
 fprintf(fid,'\n');
end
end
