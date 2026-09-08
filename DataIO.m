function varargout=DataIO(action,varargin)
% Atomic, cooperative MAT saves (timer I/O uses MATLAB's foreground thread).
% Bounded writes between GUI
% events avoid a full blocking image save. HDF5 links finalize without copies.
if strcmp(action,'write')
    destination=varargin{1}; payload=varargin{2}; temporary=varargin{3};
    if exist(destination,'file'), error('deConfUSIon:SaveExists','Output already exists: %s',destination); end
    save(temporary,'-struct','payload','-v7.3','-nocompression');
    info=whos('-file',temporary);
    if ~all(ismember(fieldnames(payload),{info.name})), error('deConfUSIon:SaveVerify','Incomplete staged MAT file: %s',temporary); end
    [ok,msg]=movefile(temporary,destination);
    if ~ok, error('deConfUSIon:SavePublish','%s',msg); end
    return;
end
persistent jobs poller polling
if isempty(jobs), jobs=struct('path',{},'temporary',{},'state',{},'error',{},'cursor',{},'payload',{}); end
switch action
    case 'enqueue'
        destination=varargin{1}; payload=varargin{2};
        % Viewer caches are reproducible and can dwarf the actual metadata.
        % Never synchronously write a second complete PSC movie as metadata.
        if isfield(payload,'newData') && isfield(payload.newData,'deconfPscKey')
            caches=intersect(fieldnames(payload.newData),{'PSC','bg','I1','deconfPscKey','deconfPscDatasetKey'});
            payload.newData=rmfield(payload.newData,caches);
        end
        if exist(destination,'file') || any(strcmp({jobs.path},destination))
            error('deConfUSIon:SaveExists','Choose a new output path: %s',destination);
        end
        folder=fileparts(destination); if ~exist(folder,'dir'), mkdir(folder); end
        temporary=[tempname(folder) '.pending'];
        jobs(end+1)=struct('path',destination,'temporary',temporary,'state','queued','error','','cursor',1,'payload',payload);
        if isempty(poller) || ~isvalid(poller)
            poller=timer('Name','deConfUSIon_SaveQueue','ExecutionMode','fixedSpacing','Period',.15,'BusyMode','drop','TimerFcn',@(~,~)DataIO('poll'));
        end
        if strcmp(poller.Running,'off'), start(poller); end
        if nargout, varargout{1}=destination; end
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
                J=jobs(k); I=J.payload.newData.I; dims=size(I); T=dims(end);
                if strcmp(J.state,'queued')
                    metadata=J.payload; metadata.newData.I=zeros(0,'like',I);
                    save(J.temporary,'-struct','metadata','-v7.3','-nocompression');
                    M=matfile(J.temporary,'Writable',true);
                    last=num2cell(dims); M.imageData(last{:})=cast(0,'like',I);
                    J.state='saving';
                end
                M=matfile(J.temporary,'Writable',true);
                chunk=max(1,floor(8*1024^2/(8*prod(dims(1:end-1)))));
                idx=J.cursor:min(T,J.cursor+chunk-1);
                subs=repmat({':'},1,ndims(I)); subs{end}=idx;
                M.imageData(subs{:})=I(subs{:});
                J.cursor=idx(end)+1;
                if J.cursor>T
                    clear M;
                    file=H5F.open(J.temporary,'H5F_ACC_RDWR','H5P_DEFAULT');
                    guard=onCleanup(@()H5F.close(file));
                    H5L.delete(file,'/newData/I','H5P_DEFAULT');
                    H5L.move(file,'/imageData',file,'/newData/I','H5P_DEFAULT','H5P_DEFAULT');
                    clear guard;
                    if exist(J.path,'file'), error('deConfUSIon:SaveExists','Output already exists: %s',J.path); end
                    [ok,msg]=movefile(J.temporary,J.path);
                    if ~ok, error('deConfUSIon:SavePublish','%s',msg); end
                    J.state='saved'; J.payload=[];
                    fprintf('[Save queue] saved: %s\n',J.path);
                end
                jobs(k)=J;
            catch ME
                jobs(k).state='failed'; jobs(k).error=ME.message;
                fprintf(2,'[Save queue] FAILED: %s | %s\n',jobs(k).path,ME.message);
            end
        end
        active=sum(ismember({jobs.state},{'queued','saving'})); failed=sum(strcmp({jobs.state},'failed'));
        h=findall(0,'Tag','SaveQueueStatus');
        for k=1:numel(h)
            if active==0 && failed==0
                label='SAVE QUEUE  |  idle';
            else
                label=sprintf('SAVE QUEUE  |  %d pending  |  %d failed',active,failed);
            end
            set(h(k),'String',label);
        end
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
            jobs(k).temporary=[tempname(fileparts(jobs(k).path)) '.pending'];
            jobs(k).state='queued'; jobs(k).error='';
            jobs(k).cursor=1;
        end
        if ~isempty(poller) && isvalid(poller) && strcmp(poller.Running,'off'), start(poller); end
    otherwise, error('deConfUSIon:DataIOAction','Unknown action %s',action);
end
end

function refreshQueue(f)
delete(f); DataIO('show');
end
