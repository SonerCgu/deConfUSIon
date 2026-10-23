function recording=gaRecordingIdentity(files,labels)
% Identify the source recording, excluding ROI role/export/processing suffixes.
% Numeric FUS clock IDs and standard scan IDs are both supported. Acquisition
% date and session distinguish reused scan numbers in the same animal.
if nargin<2,labels={};end
if ischar(files) || isstring(files),files=cellstr(files);end
if ischar(labels) || isstring(labels),labels=cellstr(labels);end
recording=struct('key','','scanID','','session','','date','','folder','');
for k=1:numel(files)
    file=strrep(char(files{k}),'\','/');slash=find(file=='/',1,'last');
    if ~isempty(slash),recording.folder=lower(file(1:slash-1));break;end
end
% Source headers describe the measured scan. Fill absent date/session fields
% from the nearest acquisition folders, never from the ROI export timestamp.
texts=[labels(:);files(:)];
for k=1:numel(texts)
    parts=regexp(char(texts{k}),'[\\/]','split');
    for p=numel(parts):-1:1
        value=parts{p};
        if isempty(recording.scanID)
            token=regexpi(value,'(?:^|[^A-Z0-9])FUS[_ -]*(\d+)(?=$|[^0-9])','tokens','once');
            if ~isempty(token)
                recording.scanID=['fus' token{1}];
            else
                token=regexpi(value,'(?:^|[^A-Z0-9])scan[_ -]*0*(\d+)(?:[_ -]([A-Z][A-Z0-9]*))?','tokens','once');
                if ~isempty(token)
                    recording.scanID=['scan' num2str(str2double(token{1}))];
                    if numel(token)>1 && ~isempty(token{2}) && ...
                            ~any(strcmpi(token{2},{'ROI','ROIs','Control','Ctrl','Target','Mean','allROIs','selected','search', ...
                                'frameRej','imreg','clean','filtered','processed','standardized'})) && ...
                            isempty(regexpi(token{2},'^(selected|search|top)\d','once'))
                        recording.scanID=[recording.scanID '_' lower(token{2})];
                    end
                end
            end
        end
        if isempty(recording.session)
            token=regexpi(value,'(?:^|[^A-Z0-9])(?:Session|Sess|S)[_ -]*0*(\d+)(?=$|[^A-Z0-9])','tokens','once');
            if ~isempty(token),recording.session=['s' num2str(str2double(token{1}))];end
        end
        if isempty(recording.date)
            token=regexpi(value,'(?:^|[^A-Z0-9])([A-Z]+)[_ -](\d{8}|\d{6})(?=[_ -])','tokens','once');
            if ~isempty(token) && ~any(strcmpi(token{1},{'ROI','SCM','Mask','ME','Export','QC','Video'}))
                recording.date=normalizeDate(token{2});
            end
        end
    end
end
if ~isempty(recording.scanID)
    recording.key=strjoin({recording.date,recording.session,recording.scanID},'|');
elseif ~isempty(recording.folder)
    % An exact export directory can match its own Target/Control files when
    % old files lack any scan label. Multiple rows per group remain ambiguous.
    recording.key=['folder|' recording.folder];
end
end

function out=normalizeDate(value)
out='';
if numel(value)==6
    year=2000+str2double(value(1:2));month=str2double(value(3:4));day=str2double(value(5:6));
elseif numel(value)==8 && str2double(value(1:4))>=1900 && str2double(value(1:4))<=2199
    year=str2double(value(1:4));month=str2double(value(5:6));day=str2double(value(7:8));
else
    year=str2double(value(5:8));month=str2double(value(3:4));day=str2double(value(1:2));
end
if year>=1900 && year<=2199 && month>=1 && month<=12 && day>=1 && day<=31
    out=sprintf('%04d%02d%02d',year,month,day);
end
end
