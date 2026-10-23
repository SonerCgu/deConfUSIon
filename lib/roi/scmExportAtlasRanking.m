function paths=scmExportAtlasRanking(reports,skipped,folder)
% CSV tables/curves plus a MAT audit with fixed regional voxel membership.
assert(~isempty(reports),'deConfUSIon:AtlasRankingExport','No rankings to export.');
if ~isfolder(folder),mkdir(folder);end
paths={};
for k=1:numel(reports)
    r=reports{k};stem=sprintf('Scan_%02d_AtlasRanking',k);
    if isfield(r,'sourceScanIndex'),stem=sprintf('Scan_%02d_AtlasRanking',r.sourceScanIndex);end
    if isfield(r,'role'),stem=[stem '_' r.role];end
    tab=r.table;
    if isfield(r,'role'),tab.SearchRole=repmat({r.role},height(tab),1);tab.ImageSide=repmat({r.imageSide},height(tab),1);end
    if isfield(r,'sourceScanLabel'),tab.SourceScan=repmat({r.sourceScanLabel},height(tab),1);end
    file=fullfile(folder,[stem '.csv']);writetable(tab,file);paths{end+1}=file; %#ok<AGROW>
    curveTable=array2table([r.timeSec(:) r.traces'],'VariableNames', ...
        [{'Time_sec'} arrayfun(@(id)sprintf('AtlasID_%d_PSC_pct',id),r.table.AtlasID','UniformOutput',false)]);
    file=fullfile(folder,[stem '_Curves.csv']);writetable(curveTable,file);paths{end+1}=file; %#ok<AGROW>
    writetable(r.omitted,fullfile(folder,[stem '_Omitted.csv']));
end
audit=fullfile(folder,'AtlasRanking.mat');save(audit,'reports','skipped','-v7.3');paths{end+1}=audit;
file=fullfile(folder,'ReadMe.txt');fid=fopen(file,'w');assert(fid>=0,'Cannot write ranking notes.');
cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n\n',reports{1}.method);
fprintf(fid,['ChangePSC_pct is the signed ranking metric (mean or peak). Peak is computed from the regional mean curve, never individual voxels.\n' ...
    'For decreases the most negative response ranks first; absolute change ranks by magnitude and retains its sign.\n' ...
    'Each scan is ranked separately. Time starts at zero in that scan.\n' ...
    'AtlasRanking.mat stores exact settings, source/atlas provenance, omitted regions, curves, and fixed MATLAB 1-based voxel indices on shapeYXZ.\n\n']);
for k=1:numel(reports)
    r=reports{k};fprintf(fid,'Scan %d: %s / %s; signal %.9g-%.9g min; slices %d-%d; baseline mode %s.\n', ...
        k,r.settings.metric,r.settings.direction,r.settings.signalSec/60,r.settings.sliceRange,r.settings.baselineMode);
end
for k=1:numel(skipped),fprintf(fid,'Skipped: %s\n',skipped{k});end
end
