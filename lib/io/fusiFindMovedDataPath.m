function path=fusiFindMovedDataPath(path)
% Resolve the same named scan after its acquisition/session folders were moved.
if ~(ischar(path)||(isstring(path)&&isscalar(path)))||isempty(path),return;end
path=char(path);if isfile(path)||isfolder(path),return;end
normalized=strrep(path,'\','/');
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
