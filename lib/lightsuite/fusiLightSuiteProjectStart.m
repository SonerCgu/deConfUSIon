function folder=fusiLightSuiteProjectStart(sourceFile,outputFolder,meta)
% Stay with this recording/animal; never use another animal's recent project.
if nargin<3||isempty(meta),meta=struct();end
roots={};
if ~isempty(sourceFile)&&isfolder(fileparts(char(sourceFile)))
    par=meta;par.loadedFile=char(sourceFile);par.loadedPath=fileparts(char(sourceFile));
    roots={fusiModelAnalysisFolder(par),par.loadedPath};
elseif ~isempty(fieldnames(meta))
    roots={fusiModelAnalysisFolder(meta)};
end
roots=unique(roots,'stable');
for index=1:numel(roots)
    root=roots{index};
    candidates={fullfile(root,'Registration','LightSuite'),fullfile(root,'Registration3D','LightSuite'), ...
        fullfile(root,'Visualization','Registration','LightSuite'), ...
        fullfile(root,'Visualization','Registration3D','LightSuite'),fullfile(root,'LightSuite')};
    [~,leaf]=fileparts(root);if strcmpi(leaf,'LightSuite'),candidates=[{root} candidates];end
    for k=1:numel(candidates)
        if isfolder(candidates{k}),folder=candidates{k};return;end
    end
end
for index=1:numel(roots)
    if isfolder(roots{index}),folder=roots{index};return;end
end
folder=pwd;
if ~isempty(outputFolder)&&isfolder(outputFolder),folder=char(outputFolder);end
end
