function varargout=DataIO(action,varargin)
% Durable analysis saves, plus compatibility with previously queued saves.
% 'save' and legacy 'enqueue' return only after the final MAT exists.
% Its staging file stays beside that destination, never in the system tempdir.
if strcmp(action,'write')
    destination=varargin{1}; payload=varargin{2}; temporary=varargin{3};
    if exist(destination,'file'), error('deConfUSIon:SaveExists','Output already exists: %s',destination); end
    folder=fileparts(destination); if isempty(folder), folder=pwd; end
    if ~exist(folder,'dir'), mkdir(folder); end
    save(temporary,'-struct','payload','-v7.3','-nocompression');
    info=whos('-file',temporary);
    if ~all(ismember(fieldnames(payload),{info.name})), error('deConfUSIon:SaveVerify','Incomplete staged MAT file: %s',temporary); end
    if isfield(payload,'newData') && isfield(payload.newData,'I')
        imageInfo=h5info(temporary,'/newData/I');
        if ~isequal(double(imageInfo.Dataspace.Size),double(size(payload.newData.I)))
            error('deConfUSIon:SaveVerify','Saved image dimensions differ from the analysis result: %s',temporary);
        end
    end
    % A commit record is written only after save() and verification finish.
    % It lets the next session recover a complete file if publication fails.
    stage=dir(temporary);
    record=struct('version',1,'complete',true,'destination',destination, ...
        'localFile',temporary,'bytes',stage.bytes,'variables',{fieldnames(payload)}, ...
        'imageSize',size(payload.newData.I),'imageClass',class(payload.newData.I));
    writeRecoveryRecord(temporary,record);
    publishCompleteStage(temporary,destination);
    return;
end
persistent jobs poller polling
if isempty(jobs), jobs=struct('path',{},'temporary',{},'state',{},'error',{},'cursor',{},'payload',{},'process',{},'transferTemp',{},'transferError',{},'staged',{}); end
switch action
    case {'save','enqueue'}
        % Old assembled GUI callbacks still call 'enqueue'. They must obey
        % the same durable contract, even before that GUI is relaunched.
        destination=char(varargin{1}); payload=preparePayload(varargin{2},destination);
        if exist(destination,'file') || any(strcmp({jobs.path},destination))
            error('deConfUSIon:SaveExists','Choose a new output path: %s',destination);
        end
        if isequal(polling,true), error('deConfUSIon:SaveBusy','Another save is still writing.'); end
        folder=fileparts(destination); if isempty(folder), folder=pwd; end
        temporary=[destination '.saving'];
        if isfile(temporary), temporary=[tempname(folder) '.saving']; end
        k=numel(jobs)+1;
        jobs(k)=struct('path',destination,'temporary',temporary,'state','saving','error','','cursor',1,'payload',payload, ...
            'process',[],'transferTemp','','transferError',[temporary '.error'],'staged',false);
        polling=true; guard=onCleanup(@()DataIO('unlockpoll')); %#ok<NASGU>
        updateSaveStatus(jobs);
        fprintf('[Save] Writing result: %s\n',destination);
        try
            DataIO('write',destination,payload,temporary);
            jobs(k).state='saved'; jobs(k).payload=[];
            fprintf('[Save] Saved and verified: %s\n',destination);
        catch ME
            jobs(k).state='failed'; jobs(k).error=ME.message;
            if isfile([temporary '.json'])
                jobs(k).staged=true; jobs(k).payload=[];
            end
            updateSaveStatus(jobs);
            error('deConfUSIon:SaveFailed','Result was NOT saved to %s.\n%s\nRetry from Save queue. Any unfinished file is retained at %s.',destination,ME.message,temporary);
        end
        updateSaveStatus(jobs);
        if nargout, varargout{1}=destination; end
    case 'flushstudio'
        % Preserve old in-memory results when relaunching after a queued-save
        % session. Never treat a lazy placeholder or partial disk stage as data.
        studio=varargin{1};
        if ~isstruct(studio) || ~isfield(studio,'datasets'), return; end
        DataIO('wait');
        keys=fieldnames(studio.datasets);
        for k=1:numel(keys)
            d=studio.datasets.(keys{k});
            if ~isstruct(d) || ~isfield(d,'savedFile') || isempty(d.savedFile) || ...
                    isfile(d.savedFile) || ~isfield(d,'I') || isempty(d.I) || ...
                    (isfield(d,'isLazy') && d.isLazy), continue; end
            DataIO('save',d.savedFile,struct('newData',d));
        end
    case 'recover'
        % Recover only explicitly completed stages. An incomplete legacy
        % .pending file has no record and is never presented as saved data.
        if isempty(varargin), folders={tempdir}; else, folders=varargin{1}; end
        if ischar(folders) || isstring(folders), folders=cellstr(folders); end
        report=struct('path',{},'state',{},'error',{});
        for ff=1:numel(folders)
            records=[dir(fullfile(folders{ff},'*.saving.json')); ...
                dir(fullfile(folders{ff},'*.deconf.pending.json'))];
            for rr=1:numel(records)
                recordPath=fullfile(records(rr).folder,records(rr).name);
                temporary=recordPath(1:end-5); destination='';
                try
                    record=jsondecode(fileread(recordPath));
                    destination=char(record.destination);
                    k=find(strcmp({jobs.path},destination),1,'last');
                    % Never steal a live queue's file while its transfer is
                    % running; wait/flush handles that job in this session.
                    if ~isempty(k) && ismember(jobs(k).state,{'queued','saving'}), continue; end
                    publishCompleteStage(temporary,destination);
                    outcome='saved'; message='';
                    fprintf('[Save recovery] Saved and verified: %s\n',destination);
                catch ME
                    outcome='failed'; message=ME.message;
                    warning('deConfUSIon:SaveRecovery','Retained save stage %s: %s',temporary,message);
                end
                report(end+1)=struct('path',destination,'state',outcome,'error',message); %#ok<AGROW>
                if isempty(destination), continue; end
                k=find(strcmp({jobs.path},destination),1,'last');
                if isempty(k), k=numel(jobs)+1; end
                jobs(k)=struct('path',destination,'temporary',temporary,'state',outcome,'error',message, ...
                    'cursor',1,'payload',[],'process',[],'transferTemp','','transferError','','staged',true);
            end
        end
        updateSaveStatus(jobs);
        if nargout, varargout{1}=report; end
    case 'poll'
        % MATLAB file I/O may dispatch timers. Never let two polls write or
        % finalize the same staged file at the same time.
        if isequal(polling,true), return; end
        polling=true;
        pollGuard=onCleanup(@()DataIO('unlockpoll')); %#ok<NASGU>
        % Do not compete for memory/network I/O during an active analysis.
        studios=allchild(0); % Direct figure children, not the entire graphics tree.
        for h=reshape(studios,1,[])
            if isempty(varargin) && isequal(getappdata(h,'StudioActionBusy'),true), return; end
            if isempty(varargin)
                busyUntil=getappdata(h,'deConfUSIonInteractionUntil');
                if isnumeric(busyUntil) && isscalar(busyUntil) && busyUntil>now
                    return; % Resume automatically after the viewer becomes idle.
                end
            end
        end
        k=find(strcmp({jobs.state},'saving'),1);
        if isempty(k), k=find(strcmp({jobs.state},'queued'),1); end
        if ~isempty(k)
            try
                J=jobs(k);
                if J.staged
                    if isempty(J.process)
                        J.process=launchTransfer(J.temporary,J.path,J.transferTemp,J.transferError);
                    elseif J.process.HasExited
                        if J.process.ExitCode~=0
                            message='Background transfer failed; local staged data retained.';
                            if isfile(J.transferError), message=fileread(J.transferError); end
                            error('deConfUSIon:SaveTransfer','%s',message);
                        end
                        J.process.Dispose(); J.process=[];
                        J.state='saved'; J.payload=[];
                        delete(J.temporary);
                        if isfile([J.temporary '.json']), delete([J.temporary '.json']); end
                        if isfile(J.transferError), delete(J.transferError); end
                        fprintf('[Save queue] saved: %s\n',J.path);
                    end
                    jobs(k)=J;
                else
                I=J.payload.newData.I; dims=size(I);
                if strcmp(J.state,'queued')
                    metadata=J.payload; metadata.newData.I=zeros(0,'like',I);
                    save(J.temporary,'-struct','metadata','-v7.3','-nocompression');
                    if isreal(I) && (isa(I,'single') || isa(I,'double'))
                        % matfile expansion creates compressed image chunks.
                        % Create explicit uncompressed chunks to avoid repeated
                        % compression while assembling a large matrix-probe MAT.
                        [tile,~]=saveTile(dims,1,2*1024^2/8);
                        chunkDims=dims;
                        for d=1:numel(dims)
                            if isnumeric(tile{d}), chunkDims(d)=numel(tile{d}); end
                        end
                        h5create(J.temporary,'/imageData',dims,'Datatype',class(I),'ChunkSize',chunkDims);
                        h5writeatt(J.temporary,'/imageData','MATLAB_class',class(I));
                    else
                        M=matfile(J.temporary,'Writable',true);
                        last=num2cell(dims); M.imageData(last{:})=cast(0,'like',I);
                    end
                    J.state='saving';
                end
                M=matfile(J.temporary,'Writable',true);
                % Tile spatial dimensions too: one 3D volume can itself be
                % hundreds of MB. Bound every write to at most 2 MB.
                [subs,nextCursor]=saveTile(dims,J.cursor,2*1024^2/8);
                M.imageData(subs{:})=I(subs{:});
                J.cursor=nextCursor;
                if J.cursor>numel(I)
                    clear M;
                    file=H5F.open(J.temporary,'H5F_ACC_RDWR','H5P_DEFAULT');
                    guard=onCleanup(@()H5F.close(file));
                    H5L.delete(file,'/newData/I','H5P_DEFAULT');
                    H5L.move(file,'/imageData',file,'/newData/I','H5P_DEFAULT','H5P_DEFAULT');
                    clear guard;
                    J.staged=true;
                    fid=fopen([J.temporary '.json'],'w');
                    if fid<0, error('deConfUSIon:SaveRecovery','Cannot write recovery manifest.'); end
                    fprintf(fid,'%s',jsonencode(struct('destination',J.path,'localFile',J.temporary))); fclose(fid);
                    J.payload=[]; jobs(k)=J; % Local MAT is now the recovery copy.
                    J.process=launchTransfer(J.temporary,J.path,J.transferTemp,J.transferError);
                end
                jobs(k)=J;
                end
            catch ME
                jobs(k).state='failed'; jobs(k).error=ME.message;
                fprintf(2,'[Save queue] FAILED: %s | %s\n',jobs(k).path,ME.message);
            end
        end
        active=sum(ismember({jobs.state},{'queued','saving'}));
        updateSaveStatus(jobs);
        if active==0 && ~isempty(poller) && isvalid(poller), stop(poller); end
    case 'status'
        if isempty(varargin), varargout{1}=jobs; else
            k=find(strcmp({jobs.path},varargin{1}),1,'last');
            if isempty(k), varargout{1}=''; else, varargout{1}=jobs(k).state; end
        end
    case 'unlockpoll'
        polling=false;
    case 'wait'
        while any(ismember({jobs.state},{'queued','saving'}))
            DataIO('poll',true); drawnow; pause(.1);
        end
        if any(strcmp({jobs.state},'failed')), error('deConfUSIon:SaveFailed','%s',strjoin({jobs(strcmp({jobs.state},'failed')).error},newline)); end
    case 'show'
        f=figure('Name','Save queue','NumberTitle','off','MenuBar','none','ToolBar','none');
        rows=cell(numel(jobs),1);
        for k=1:numel(jobs), rows{k}=sprintf('%s | %s | %s',upper(jobs(k).state),jobs(k).path,jobs(k).error); end
        if isempty(rows), rows={'No queued saves.'}; end
        uicontrol(f,'Style','listbox','Units','normalized','Position',[.03 .18 .94 .77],'String',rows,'FontSize',12);
        uicontrol(f,'Style','pushbutton','Units','normalized','Position',[.03 .05 .29 .08], ...
            'String','Retry failed saves','Callback',@(~,~)DataIO('retry'));
        uicontrol(f,'Style','pushbutton','Units','normalized','Position',[.355 .05 .29 .08], ...
            'String','Refresh','Callback',@(~,~)refreshQueue(f));
        uicontrol(f,'Style','pushbutton','Units','normalized','Position',[.68 .05 .29 .08], ...
            'String','Close','Callback',@(~,~)delete(f));
        deConfUSIon_ui('present',f);
    case 'retry'
        for k=find(strcmp({jobs.state},'failed'))
            if endsWith(jobs(k).temporary,'.saving') || (jobs(k).staged && isfile([jobs(k).temporary '.json']))
                % Durable saves also retry durably; they have no queue timer.
                polling=true; retryGuard=onCleanup(@()DataIO('unlockpoll'));
                try
                    if jobs(k).staged
                        publishCompleteStage(jobs(k).temporary,jobs(k).path);
                    else
                        DataIO('write',jobs(k).path,jobs(k).payload,jobs(k).temporary);
                    end
                    jobs(k).state='saved'; jobs(k).payload=[]; jobs(k).error='';
                    fprintf('[Save] Saved and verified: %s\n',jobs(k).path);
                catch ME
                    jobs(k).error=ME.message;
                    fprintf(2,'[Save] Retry failed: %s | %s\n',jobs(k).path,ME.message);
                end
                clear retryGuard;
                continue;
            end
            if ~isempty(jobs(k).process), try, jobs(k).process.Dispose(); catch, end, end
            if isfile(jobs(k).transferTemp), delete(jobs(k).transferTemp); end
            jobs(k).process=[]; jobs(k).transferTemp=[tempname(fileparts(jobs(k).path)) '.pending'];
            if jobs(k).staged
                jobs(k).state='saving';
            else
                jobs(k).temporary=[tempname(tempdir) '.deconf.pending'];
                jobs(k).transferError=[jobs(k).temporary '.error'];
                jobs(k).state='queued'; jobs(k).cursor=1;
            end
            jobs(k).error='';
        end
        updateSaveStatus(jobs);
        if ~isempty(poller) && isvalid(poller) && strcmp(poller.Running,'off'), start(poller); end
    otherwise, error('deConfUSIon:DataIOAction','Unknown action %s',action);
end
end

function payload=preparePayload(payload,destination)
% Save consistent labels with the result, not a cached label from its parent.
if ~isstruct(payload) || ~isfield(payload,'newData') || ~isstruct(payload.newData) || ...
        ~isfield(payload.newData,'I') || isempty(payload.newData.I)
    error('deConfUSIon:EmptySave','Analysis output contains no image data to save.');
end
d=payload.newData;
if isfield(d,'deconfPscKey')
    d=rmfield(d,intersect(fieldnames(d),{'PSC','bg','I1','deconfPscKey','deconfPscDatasetKey'}));
end
d.isLazy=false; d.savedFile=destination; d.lazyFile=destination;
if isfield(d,'displayNameFull') && ~isempty(d.displayNameFull)
    payload.displayNameFull=d.displayNameFull;
    payload.preprocDisplayName=d.displayNameFull;
    payload.HUMOR_fullDisplayName=d.displayNameFull;
    d.displayNameShort=deConfUSIon_display_short_name(d.displayNameFull,d,destination);
    payload.displayNameShort=d.displayNameShort;
end
if isfield(d,'datasetSortTime'), payload.datasetSortTime=d.datasetSortTime; end
payload.newData=d;
end

function refreshQueue(f)
delete(f); DataIO('show');
end

function updateSaveStatus(jobs)
active=sum(ismember({jobs.state},{'queued','saving'})); failed=sum(strcmp({jobs.state},'failed'));
if active==0 && failed==0
    label=sprintf('SAVES  |  %d verified',sum(strcmp({jobs.state},'saved')));
else
    label=sprintf('SAVES  |  %d pending  |  %d FAILED',active,failed);
end
h=findall(0,'Tag','SaveQueueStatus');
for k=1:numel(h), set(h(k),'String',label); end
end

function writeRecoveryRecord(temporary,record)
% Publish the small record atomically; a half-written JSON is not a commit.
pending=[temporary '.jtmp'];
fid=fopen(pending,'w');
if fid<0, error('deConfUSIon:SaveRecovery','Cannot write recovery record: %s',pending); end
guard=onCleanup(@()fclose(fid));
fprintf(fid,'%s',jsonencode(record)); clear guard;
[ok,message]=movefile(pending,[temporary '.json'],'f');
if ~ok, error('deConfUSIon:SaveRecovery','%s',message); end
end

function publishCompleteStage(temporary,destination)
% Recovery never loads the movie into memory and never overwrites a result.
recordPath=[temporary '.json'];
if ~isfile(recordPath)
    error('deConfUSIon:IncompleteSave','A complete staged MAT and its recovery record are required.');
end
record=jsondecode(fileread(recordPath));
if ~isfield(record,'localFile') || ~strcmpi(char(record.localFile),temporary) || ...
        ~isfield(record,'destination') || ~strcmpi(char(record.destination),destination) || ...
        (isfield(record,'version') && (~isfield(record,'complete') || ~isequal(record.complete,true)))
    error('deConfUSIon:IncompleteSave','The recovery record does not certify this staged file.');
end
% A process can stop after publication but before removing its record. That
% completed final MAT is still valid; don't turn a cleanup interruption into
% a permanently failed queue entry on the next launch.
if ~isfile(temporary)
    if isfile(destination) && isfield(record,'version') && isequal(record.complete,true)
        verifyCompleteFile(destination,record);
        removeRecoveryRecord(recordPath);
        return;
    end
    error('deConfUSIon:IncompleteSave','The certified stage is missing; retained its recovery record.');
end
if exist(destination,'file') || exist(destination,'dir')
    error('deConfUSIon:SaveExists','Output already exists; retained the staged result: %s',destination);
end
[~,~,extension]=fileparts(destination);
if ~strcmpi(extension,'.mat'), error('deConfUSIon:SaveRecovery','Recovery destination must be a MAT file.'); end
verifyCompleteFile(temporary,record);
stage=dir(temporary);
folder=fileparts(destination); if isempty(folder), folder=pwd; end
if ~exist(folder,'dir'), mkdir(folder); end
sourceFolder=fileparts(temporary);
if strcmpi(char(java.io.File(sourceFolder).getCanonicalPath()),char(java.io.File(folder).getCanonicalPath()))
    publishWithoutOverwrite(temporary,destination);
else
    % A legacy stage may be on another volume. Copy beside the destination,
    % check the complete byte count, then publish with a no-overwrite rename.
    pending=[tempname(folder) '.pending'];
    [ok,message]=copyfile(temporary,pending);
    if ~ok, error('deConfUSIon:SaveTransfer','%s',message); end
    copied=dir(pending);
    if copied.bytes~=stage.bytes, error('deConfUSIon:SaveVerify','Recovery copy size differs from the complete stage.'); end
    publishWithoutOverwrite(pending,destination);
    delete(temporary);
end
removeRecoveryRecord(recordPath);
end

function verifyCompleteFile(file,record)
info=whos('-file',file);
imageInfo=h5info(file,'/newData/I');
if ~any(strcmp({info.name},'newData')) || any(strcmp({info.name},'imageData')) || ...
        any(strcmp({imageInfo.Attributes.Name},'MATLAB_empty')) || isempty(imageInfo.Dataspace.Size)
    error('deConfUSIon:IncompleteSave','The staged image series is incomplete.');
end
stage=dir(file);
if isfield(record,'bytes') && stage.bytes~=double(record.bytes)
    error('deConfUSIon:SaveVerify','Staged file size changed after it was completed.');
end
if isfield(record,'variables') && ~all(ismember(cellstr(record.variables),{info.name}))
    error('deConfUSIon:SaveVerify','A staged output variable is missing.');
end
if isfield(record,'imageSize') && ~isequal(double(imageInfo.Dataspace.Size(:)),double(record.imageSize(:)))
    error('deConfUSIon:SaveVerify','Staged image dimensions changed after completion.');
end
if isfield(record,'imageClass') && ~strcmp(char(h5readatt(file,'/newData/I','MATLAB_class')),record.imageClass)
    error('deConfUSIon:SaveVerify','Staged image class changed after completion.');
end
end

function removeRecoveryRecord(recordPath)
try, delete(recordPath);
catch ME
    warning('deConfUSIon:SaveRecordCleanup','Result is saved; could not remove recovery record %s: %s',recordPath,ME.message);
end
end

function publishWithoutOverwrite(source,destination)
% No REPLACE_EXISTING: a destination created during copying is also safe.
src=java.io.File(source); dst=java.io.File(destination);
javaMethod('move','java.nio.file.Files',src.toPath(),dst.toPath(),javaArray('java.nio.file.CopyOption',0));
end

function [subs,next]=saveTile(dims,cursor,maxElements)
% Contiguous column-major tiles; first split dimension varies, later ones
% are singleton coordinates. No padding, reshaping or type conversion.
axis=find(cumprod(dims)>maxElements,1);
if isempty(axis), axis=numel(dims); end
stride=prod(dims(1:axis-1));
coords=cell(1,numel(dims)); [coords{:}]=ind2sub(dims,cursor);
count=min(dims(axis)-coords{axis}+1,max(1,floor(maxElements/stride)));
subs=coords; for d=1:axis-1, subs{d}=':'; end
subs{axis}=coords{axis}+(0:count-1); next=cursor+stride*count;
end

function process=launchTransfer(source,destination,pending,errorFile)
% Paths are literals inside an encoded script, never executable shell text.
quote=@(s)['''' strrep(char(s),'''','''''') ''''];
script=sprintf(['$ErrorActionPreference=''Stop''; try {' ...
    '[IO.File]::Copy(%s,%s,$false); ' ...
    'if ((Get-Item -LiteralPath %s).Length -ne (Get-Item -LiteralPath %s).Length) { throw ''File size mismatch'' }; ' ...
    '[IO.File]::Move(%s,%s); exit 0 ' ...
    '} catch { [IO.File]::WriteAllText(%s,$_.Exception.Message); exit 1 }'], ...
    quote(source),quote(pending),quote(source),quote(pending),quote(pending),quote(destination),quote(errorFile));
bytes=System.Text.Encoding.Unicode.GetBytes(script);
encoded=char(System.Convert.ToBase64String(bytes));
info=System.Diagnostics.ProcessStartInfo();
info.FileName='powershell.exe';
info.Arguments=['-NoProfile -NonInteractive -EncodedCommand ' encoded];
info.UseShellExecute=false; info.CreateNoWindow=true;
info.WindowStyle=System.Diagnostics.ProcessWindowStyle.Hidden;
process=System.Diagnostics.Process.Start(info);
end
