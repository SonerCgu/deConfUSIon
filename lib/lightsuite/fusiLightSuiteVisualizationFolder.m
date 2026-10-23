function folder=fusiLightSuiteVisualizationFolder(s)
% Resolve this recording's Visualization folder, including dated revisions.
candidates={};meta=struct();
if isfield(s,'inputMetadata'),meta=s.inputMetadata;end
for name={'visualizationPath','visualisationPath'}
    if isfield(meta,name{1}),candidates{end+1}=char(meta.(name{1}));end %#ok<AGROW>
end
if ~isempty(fieldnames(meta))
    root=fusiModelAnalysisFolder(meta);candidates=[candidates {fullfile(root,'Visualization'),root}];
end
root=s.opts.savepath;
for k=1:5
    candidates{end+1}=fullfile(root,'Visualization'); %#ok<AGROW>
    [parent,leaf]=fileparts(root);
    if any(strcmpi(leaf,{'Registration','Registration3D'})),candidates{end+1}=fullfile(parent,'Visualization');end %#ok<AGROW>
    if strcmp(parent,root),break;end
    root=parent;
end
folder=s.opts.savepath;
for k=1:numel(candidates),if isfolder(candidates{k}),folder=candidates{k};return;end,end
end
