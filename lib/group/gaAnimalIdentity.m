function [id,info]=gaAnimalIdentity(rowOrFile)
% Resolve an animal from a table row or file, without using an ROI bundle's
% generic folder name as an animal. Source headers outrank copied filenames;
% filenames outrank enclosing folders. A table Animal ID is an explicit
% correction; retain source disagreements as notes instead of rejecting it.
id='';info=struct('key','','source','','conflict',false,'reason','', ...
    'explicitID','','sourceID','','folderID','','sourceMismatch',false,'recording',struct());
if iscell(rowOrFile)
    row=rowOrFile;explicit='';if numel(row)>=2,explicit=explicitID(row{2});end
    files={};for k=[7 8 6],if numel(row)>=k,files{end+1}=asText(row{k});end,end %#ok<AGROW>
else
    explicit='';files={asText(rowOrFile)};
end
info.explicitID=explicit;ids={};sources={};labels={};
for k=1:numel(files)
    file=files{k};if isempty(file),continue;end
    parts=regexp(file,'[\\/]','split');parts=parts(~cellfun(@isempty,parts));
    if isempty(parts),continue;end
    [candidate,conflict,recordingLabel]=headerID(file);
    labels{end+1}=recordingLabel; %#ok<AGROW>
    if conflict,info.conflict=true;info.reason='Conflicting animal IDs in ROI source metadata.';end
    source='ROI source header';
    if isempty(candidate),candidate=parseLabel(parts{end},false);source='Recording filename';end
    folder='';
    for p=numel(parts)-1:-1:1
        folder=parseLabel(parts{p},true);if ~isempty(folder),break;end
    end
    if isempty(info.folderID),info.folderID=folder;end
    if isempty(candidate),candidate=folder;source='Nearest animal folder';end
    if ~isempty(candidate),ids{end+1}=candidate;sources{end+1}=source;end %#ok<AGROW>
end
if ~isempty(ids)
    keys=cellfun(@canonical,ids,'UniformOutput',false);
    if numel(unique(keys))>1
        info.conflict=true;info.reason='The row files identify different animals.';
    end
    info.sourceID=ids{1};
end
if ~isempty(explicit)
    id=explicit;info.source='Animal ID';
    mismatch=info.conflict || any(~strcmp(canonical(explicit),cellfun(@canonical,ids,'UniformOutput',false)));
    info.sourceMismatch=mismatch;info.conflict=false;
    if mismatch
        info.reason=sprintf('Using table Animal ID %s over historical source labels.',explicit);
    end
elseif ~isempty(ids)
    id=ids{1};info.source=sources{1};
else
    info.reason='No animal ID in the row, recording metadata, filename or animal folders.';
end
info.key=canonical(id);
info.recording=gaRecordingIdentity(files,labels);
end

function [id,conflict,label]=headerID(file)
id='';conflict=false;label='';
[~,~,ext]=fileparts(file);if ~strcmpi(ext,'.txt'),return;end
% Repeated redraws reuse the small header; changed files invalidate the cache.
persistent cache
if isempty(cache),cache=containers.Map('KeyType','char','ValueType','any');end
try,d=dir(file);catch,return;end
if isempty(d) || d(1).isdir,return;end
stamp=[d(1).bytes d(1).datenum];
if isKey(cache,file)
    saved=cache(file);
    if isequal(saved.stamp,stamp),id=saved.id;conflict=saved.conflict;label=saved.label;return;end
end
fid=fopen(file,'r');if fid<0,return;end
guard=onCleanup(@()fclose(fid)); %#ok<NASGU>
prefix=fread(fid,65536,'*char')';
marker=regexpi(prefix,'(?:^|[\r\n])#[ \t]*ROI_MEMBERS[ \t]*:','start','once');
if ~isempty(marker),prefix=prefix(1:marker-1);end
for field={'TraceSourceScan|SourceRecording','SourceFile','FileLabel|Dataset'}
    token=regexpi(prefix,['(?:^|[\r\n])#[ \t]*(?:' field{1} ')[ \t]*:[ \t]*([^\r\n]*)'],'tokens','once');
    if ~isempty(token) && ~isempty(strtrim(token{1})),label=strtrim(token{1});break;end
end
fields={'Animal[_ ]?ID|Subject[_ ]?ID','TraceSourceScan|SourceRecording','SourceFile|FileLabel|Dataset'};
for k=1:numel(fields)
    tokens=regexpi(prefix,['(?:^|[\r\n])#[ \t]*(?:' fields{k} ')[ \t]*:[ \t]*([^\r\n]*)'],'tokens');
    found={};
    for j=1:numel(tokens)
        if k==1,candidate=explicitID(tokens{j}{1});else,candidate=parseLabel(tokens{j}{1},false);end
        if ~isempty(candidate),found{end+1}=candidate;end %#ok<AGROW>
    end
    if ~isempty(found)
        id=found{1};conflict=numel(unique(cellfun(@canonical,found,'UniformOutput',false)))>1;break;
    end
end
if cache.Count>=4096,remove(cache,keys(cache));end
cache(file)=struct('stamp',stamp,'id',id,'conflict',conflict,'label',label);
end

function id=parseLabel(text,allowBareNumber)
id='';parts=regexp(asText(text),'[\\/]','split');
for k=numel(parts):-1:1
    value=parts{k};
    patterns={ ...
        '(?:^|[^A-Z0-9])(?:B6J|C57BL6J|C57|BL6J)[_ -]+(?:256|512|1024|2048)[_ -]+(\d{3,6})(?=$|[^A-Z0-9])', ...
        '(?:^|[^A-Z0-9])(?:B6J|C57BL6J|C57|BL6J)[_ -]+(\d{3,6})(?=$|[^A-Z0-9])', ...
        '(?:^|[^A-Z0-9])([A-Z]{1,8}\d{6}[A-Z]?)(?=[_ -]S\d+|$|[.])', ...
        '(?:^|[^A-Z0-9])(?:ANIMAL|MOUSE|RAT|SUBJECT|TIER)[_ -]*([A-Z]*\d+[A-Z]*)(?=$|[^A-Z0-9])'};
    for p=1:numel(patterns)
        token=regexpi(value,patterns{p},'tokens','once');
        if ~isempty(token),id=token{1};return;end
    end
    if allowBareNumber && ~isempty(regexp(value,'^\d{3,6}$','once'))
        number=str2double(value);
        dateLike=numel(value)==6 && str2double(value(3:4))>=1 && str2double(value(3:4))<=12 ...
            && str2double(value(5:6))>=1 && str2double(value(5:6))<=31;
        if (number<1900 || number>2199) && ~dateLike,id=value;return;end
    end
end
end

function id=explicitID(value)
value=asText(value);id='';
if isempty(value) || any(strcmpi(value,{'N/A','NA','NaN','Unknown','None','Missing','Unassigned','Subject','Animal'})) ...
        || ~isempty(regexpi(value,'^S\d+$|^ROI(?:[_ -]|$)|^SCM(?:[_ -]|$)|\.(txt|mat)$','once'))
    return;
end
parsed=parseLabel(value,false);
if ~isempty(parsed),id=parsed;
elseif ~isempty(regexp(value,'^[A-Za-z0-9][A-Za-z0-9 _.-]*$','once')),id=value;end
end

function key=canonical(id)
key=lower(strtrim(id));
end

function text=asText(value)
text='';try,if ischar(value) || (isstring(value) && isscalar(value)),text=strtrim(char(value));end,catch,end
end
