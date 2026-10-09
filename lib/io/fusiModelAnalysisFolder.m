function root=fusiModelAnalysisFolder(par)
% Prefer Studio's selected analysed dataset, never its acquired input folder.
root='';
for name={'exportPath','savePath','outPath','analysedPath','analysisPath','visualizationPath'}
    if ~isfield(par,name{1})||isempty(par.(name{1})),continue;end
    candidate=char(par.(name{1}));
    if isfile(candidate),candidate=fileparts(candidate);end
    if isfolder(candidate),root=candidate;break;end
end
if isempty(root)
    for name={'loadedPath','loadedFile','sourceFile'}
        if ~isfield(par,name{1})||isempty(par.(name{1})),continue;end
        candidate=char(par.(name{1}));if isfile(candidate),candidate=fileparts(candidate);end
        if isfolder(candidate),root=candidate;break;end
    end
end
if isempty(root),root=fullfile(pwd,'AnalysedData');end
normalized=strrep(root,'\','/');
rawPattern='(^|/)(RawData|Raw_Data_fUSI)(?=/|$)';
if ~isempty(regexpi(normalized,rawPattern,'once'))
    % Match Studio's RawData -> AnalysedData mirror and per-recording folder.
    normalized=regexprep(normalized,rawPattern,'$1AnalysedData','ignorecase');
    source='';
    for name={'loadedFile','sourceFile'}
        if isfield(par,name{1}) && ~isempty(par.(name{1})),source=char(par.(name{1}));break;end
    end
    if ~isempty(source)
        [~,stem,ext]=fileparts(source);if strcmpi(ext,'.gz'),[~,stem]=fileparts(stem);end
        stem=regexprep(stem,'[^\w\-]+','_');stem=regexprep(stem,'_+','_');
        stem=regexprep(stem,'^_+|_+$','');
        [~,leaf]=fileparts(regexprep(normalized,'/+$',''));
        if ~isempty(stem)&&~strcmpi(leaf,stem),normalized=[regexprep(normalized,'/+$','') '/' stem];end
    end
end
root=strrep(normalized,'/',filesep);
% Visualization/Preprocessing/PSC are dataset children, not separate animals.
while true
    [parent,leaf]=fileparts(regexprep(root,'[\\/]+$',''));
    if ~any(strcmpi(leaf,{'Visualization','Visualisation','Preprocessing','PSC','Registration','Registration2D','Registration3D','Masks','Mask','QC'})),break;end
    root=parent;
end
end
