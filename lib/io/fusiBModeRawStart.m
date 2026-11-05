function folder=fusiBModeRawStart(par,fallback)
% Resolve this recording's raw folder without a remembered cross-animal path.
if nargin<2||~isfolder(fallback),fallback=pwd;end
paths={};
for field={'rawFile','loadedFile','sourceFile','rawPath','loadedPath','sourcePath'}
    if isfield(par,field{1}) && (ischar(par.(field{1}))||isstring(par.(field{1})))
        p=fusiFindMovedDataPath(char(par.(field{1})));
        if isfile(p),p=fileparts(p);end
        if isfolder(p),paths{end+1}=p;end %#ok<AGROW>
    end
end
folder=resolveRawFolder(paths);
if isempty(folder),folder=resolveRawFolder({fallback});end
if isempty(folder),folder=fallback;end
end

function folder=resolveRawFolder(paths)
folder='';
for k=1:numel(paths)
    if ~isempty(regexpi(strrep(paths{k},'\','/'),'(^|/)RawData(/|$)','once'))
        folder=paths{k};return;
    end
end
for k=1:numel(paths)
    p=strrep(paths{k},'\','/');
    cut=regexpi(p,'(^|/)AnalysedData(?=/|$)','end','once');
    if isempty(cut),continue;end
    rawRoot=strrep(regexprep(p(1:cut),'AnalysedData$','RawData','ignorecase'),'/',filesep);
    candidate=fullfile(rawRoot,strrep(regexprep(p(cut+1:end),'^/+',''),'/',filesep));
    while numel(candidate)>=numel(rawRoot)
        if isfolder(candidate),folder=candidate;return;end
        parent=fileparts(candidate);if strcmp(parent,candidate),break;end
        candidate=parent;
    end
end
% Acquisitions outside a RawData/AnalysedData project still use their own folder.
for k=1:numel(paths)
    if isempty(regexpi(strrep(paths{k},'\','/'),'(^|/)AnalysedData(/|$)','once'))
        folder=paths{k};return;
    end
end
end
