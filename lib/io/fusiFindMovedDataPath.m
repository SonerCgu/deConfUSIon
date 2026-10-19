function path=fusiFindMovedDataPath(path,roots)
% Resolve moved sessions or Windows paths beneath explicitly opened project roots.
if ~(ischar(path)||(isstring(path)&&isscalar(path)))||isempty(path),return;end
path=char(path);if isfile(path)||isfolder(path),return;end
normalized=strrep(path,'\','/');
if ~ispc,normalized=regexprep(normalized,'/{2,}','/');end
native=strrep(normalized,'/',filesep);
if isfile(native)||isfolder(native),path=native;return;end
if nargin<2,roots=getpref('deConfUSIon','dataRoots',{});end
if ischar(roots)||isstring(roots),roots=cellstr(roots);end
% Require the project name and the complete RawData/AnalysedData suffix.
% Never search an entire share for a matching basename or choose ambiguously.
segments=strsplit(normalized,'/');
marker=find(strcmpi(segments,'RawData')|strcmpi(segments,'AnalysedData'),1);
matches={};
if ~isempty(marker)&&marker>1
    for k=1:numel(roots)
        [~,project]=fileparts(char(roots{k}));
        if ~strcmp(project,segments{marker-1}),continue;end
        candidate=fullfile(char(roots{k}),segments{marker:end});
        candidate=fusiFindMovedDataPath(candidate,{});
        if isfile(candidate)||isfolder(candidate),matches{end+1}=candidate;end %#ok<AGROW>
    end
    matches=unique(matches);
    if numel(matches)==1,path=matches{1};return;end
end
cut=regexp(normalized,'/(RawData|AnalysedData)(?=/|$)','end','once','ignorecase');
if isempty(cut),return;end
root=strrep(normalized(1:cut),'/',filesep);
parts=strsplit(regexprep(normalized(cut+1:end),'^/+',''),'/');
if endsWith(root,'RawData','IgnoreCase',true)
    [~,stem]=fileparts(parts{end});
    session=regexprep(stem,'_scan\d+(?:_.*)?$','','ignorecase');
    if strcmp(session,stem)||isempty(regexp(session,'(^|_)\d{6,8}(?=_)','once')),return;end
    candidate=fullfile(root,session,parts{end});
    if isfile(candidate),path=candidate;end
else
    scan=find(~cellfun('isempty',regexp(parts,'^.+_scan\d+(?:_.*)?$','once','ignorecase')),1);
    if isempty(scan),return;end
    session=regexprep(parts{scan},'_scan\d+(?:_.*)?$','','ignorecase');
    if isempty(regexp(session,'(^|_)\d{6,8}(?=_)','once')),return;end
    candidate=fullfile(root,session,parts{scan:end});
    oldScan=fullfile(root,parts{1:scan});newScan=fullfile(root,session,parts{scan});
    if isfile(candidate)||isfolder(candidate)||(~isfolder(oldScan)&&isfolder(newScan)),path=candidate;end
end
end
