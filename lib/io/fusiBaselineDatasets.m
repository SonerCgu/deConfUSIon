function [entries,analysisFolder]=fusiBaselineDatasets(rawFile,analysisFolder)
% Reuse Studio's dataset names/scanner without changing the active dataset.
if nargin<2||isempty(analysisFolder)
    paths=fusiResolveAnalysisFolder(rawFile);analysisFolder=paths.datasetFolder;
end
entries=struct('label','Raw scan','file',rawFile);
studio=struct('exportPath',analysisFolder,'datasets',struct());
studio=deConfUSIon_add_preproc_lazy_datasets(studio);
names=fieldnames(studio.datasets);
for k=1:numel(names)
    d=studio.datasets.(names{k});
    % An independently normalised PSC recording cannot supply absolute power.
    if contains(strrep(d.lazyFile,'\','/'),'/PSC/','IgnoreCase',true),continue;end
    entries(end+1)=struct('label',d.displayNameFull,'file',d.lazyFile); %#ok<AGROW>
end
end
