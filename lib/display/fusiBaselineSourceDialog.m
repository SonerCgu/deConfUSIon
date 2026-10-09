function baseline=fusiBaselineSourceDialog(current,TR,shape,startPath,context)
% Pick RAW once, list its saved analyses immediately, read only at Apply.
if nargin<5,context=struct();end
baseline=[];if nargin<4||~isfolder(startPath),startPath=pwd;end
startPath=fusiBaselineRawStart(context,startPath);
entries=[];rawFile='';rawInfo=[];selectedInfo=[];ref=[];selectedFile='';factor=1;
matrix=numel(shape)==3&&shape(3)>1;[rawTR,confirmedTR]=fusiBaselineAcquisitionTR(context,TR,matrix);
targetGeometry=context;
C=deConfUSIon_ui('palette');bg=C.background;fg=C.text;
f=figure('Name','Baseline source','NumberTitle','off','MenuBar','none','ToolBar','none', ...
    'Color',bg,'Units','pixels','Position',[180 140 850 610],'Resize','off','WindowStyle','modal','CloseRequestFcn',@cancel);
guard=onCleanup(@()deleteIfValid(f)); %#ok<NASGU>
control('text','Use a baseline from this scan, or another scan of the same animal.',[20 562 810 30],[]);
mode=control('popupmenu',{'Another scan / shared reference','Current scan'},[20 526 810 30],@modeChanged);
rawBtn=control('pushbutton','1. Select RAW reference scan...',[20 480 810 36],@pickRaw);
set(rawBtn,'Tag','BaselineRawScan');
fileText=control('text','Select a raw MAT file; its AnalysedData choices appear below.',[20 435 810 40],[]);
control('text','2. Reference dataset (from this raw scan''s AnalysedData folder)',[20 401 810 28],[]);
dataset=control('popupmenu',{'Select a raw scan first'},[20 365 810 30],@selectDataset);
control('text','Acquisition TR (s), before averaging',[20 306 225 44],[]);
trEdit=control('edit',sprintf('%.9g',rawTR),[250 318 120 30],@timingChanged);
trEdit.TooltipString='TR is time between raw frames, in seconds. Defaults to the current scan; averaging changes the analysed dataset TR shown on the right.';
timingHint=sprintf('TR = time between raw frames. Current scan preset: %.6g s. The analysed TR includes averaging.',rawTR);
interval=control('text',timingHint,[390 309 440 44],[]);
rangeText=control('text','3. Baseline window in reference scan (s): start / end',[20 263 500 30],[]);
w=[0 TR];if isfield(current,'start'),w=[current.start current.end];end
first=control('edit',sprintf('%.9g',w(1)),[570 263 120 30],[]);
last=control('edit',sprintf('%.9g',w(2)),[710 263 120 30],[]);
gridText=control('text','Choose comparable processing (e.g. PC1 + imregdemons). Different depth ranges use recorded origins and overlapping voxels; uncovered voxels are excluded.',[20 188 810 65],[]);
loadBtn=control('pushbutton','Load saved reference...',[20 132 245 34],@loadReference);
saveBtn=control('pushbutton','Save reference...',[285 132 245 34],@saveReference);
status=control('text','Only the chosen baseline frames will be loaded when you click Apply.',[20 65 810 58],[]);
cancelBtn=control('pushbutton','Cancel',[570 14 120 36],@cancel);
applyBtn=control('pushbutton','Apply baseline',[710 14 120 36],@apply);
set(cancelBtn,'BackgroundColor',C.danger,'FontWeight','bold','Tag','BaselineSourceCancel');
set(applyBtn,'BackgroundColor',C.success,'FontWeight','bold','Tag','BaselineSourceApply');
set([rawBtn loadBtn],'BackgroundColor',C.blue,'FontWeight','bold');
set(saveBtn,'BackgroundColor',C.yellow,'FontWeight','bold');
set(mode,'Tag','BaselineSourceMode');set(dataset,'Tag','BaselineSourceDataset');
set(first,'Tag','BaselineSourceStart');set(last,'Tag','BaselineSourceEnd');set(trEdit,'Tag','BaselineSourceTR');
set(status,'Tag','BaselineSourceStatus');set(interval,'Tag','BaselineDatasetTR');
if fusiBaselineReference('isExternal',current),ref=current.reference;showRef();
else,mode.Value=1;modeChanged();end
uiwait(f);deleteIfValid(f);
    function h=control(style,label,pos,cb)
        h=uicontrol(f,'Style',style,'String',label,'Position',pos,'FontSize',11,'ForegroundColor',fg,'BackgroundColor',bg,'HorizontalAlignment','left');
        if ~isempty(cb),h.Callback=cb;end
    end
    function modeChanged(~,~)
        external=mode.Value==1;enabled='off';if external,enabled='on';end
        set([rawBtn dataset trEdit loadBtn saveBtn],'Enable',enabled);set([first last],'Enable','on');
        if external&&~isempty(ref),set([first last trEdit],'Enable','off');end
        if external,rangeText.String='3. Baseline window in reference scan (s): start / end';
        else,rangeText.String='Baseline window in current scan (s): start / end';end
    end
    function pickRaw(~,~)
        [n,p]=uigetfile('*.mat','Select RAW reference scan (analysed results are chosen next)',startPath);
        if isequal(n,0),return;end
        try
            status.String='Reading scan header and listing saved preprocessing results...';f.Pointer='watch';drawnow;
            rawFile=fullfile(p,n);startPath=p;rawInfo=fusiBaselineFileInfo(rawFile);
            entries=fusiBaselineDatasets(rawFile);dataset.String={entries.label};dataset.Value=1;
            fileText.String=[n newline p];fileText.TooltipString=rawFile;ref=[];
            if ~matrix&&~confirmedTR&&isfinite(rawInfo.TR),trEdit.String=sprintf('%.9g',rawInfo.TR);end
            selectDataset();
        catch ME,status.String=ME.message;end
        f.Pointer='arrow';
    end
    function selectDataset(~,~)
        if isempty(entries),return;end
        try
            ref=[];selectedFile=entries(dataset.Value).file;
            if dataset.Value==1,selectedInfo=rawInfo;else,selectedInfo=fusiBaselineFileInfo(selectedFile);end
            factor=1;
            if dataset.Value>1&&isfinite(selectedInfo.TR)&&isfinite(selectedInfo.acquisitionTR)
                factor=selectedInfo.TR/selectedInfo.acquisitionTR;
            elseif dataset.Value>1&&mod(rawInfo.nFrames,selectedInfo.nFrames)==0
                factor=rawInfo.nFrames/selectedInfo.nFrames;
            end
            % Check geometry now, before reading hundreds of baseline frames.
            mock=struct('mean',ones(selectedInfo.spatialSize,'single'),'spatialSize',selectedInfo.spatialSize);
            [~,note]=fusiBaselineAlignReference(mock,shape,rawInfo.metadata,targetGeometry);
            gridText.String=[note newline 'Matching physical voxels are used; this does not correct motion between scans.'];
            mode.Value=1;modeChanged();timingChanged();
            status.String=sprintf('%d choices found. Selected: %s. No movie loaded yet; click Apply.',numel(entries),entries(dataset.Value).label);
        catch ME,selectedInfo=[];status.String=ME.message;end
    end
    function timingChanged(~,~)
        if isempty(selectedInfo),return;end
        interval.String=sprintf('Analysed TR: %.6g s/sample = %.6g frames x %.6g s acquisition TR. Range: 0-%.6g s.', ...
            str2double(trEdit.String)*factor,factor,str2double(trEdit.String),(selectedInfo.nFrames-1)*str2double(trEdit.String)*factor);
    end
    function r=makeReference()
        if ~isempty(ref)
            geometry=struct();if isfield(ref,'sourceGeometry'),geometry=ref.sourceGeometry;end
            [r,~]=fusiBaselineAlignReference(ref,shape,geometry,targetGeometry);return;
        end
        assert(~isempty(selectedInfo),'deConfUSIon:BaselineSelection','Select a valid raw scan and a dataset from its dropdown first.');
        baseTR=str2double(trEdit.String);assert(isfinite(baseTR)&&baseTR>0,'deConfUSIon:BaselineTR','Enter a positive raw frame interval in seconds.');
        p=struct('rawFile',rawFile,'datasetLabel',entries(dataset.Value).label,'rawTR',baseTR,'temporalFactor',factor, ...
            'storedDatasetTR',selectedInfo.TR);
        progress=fusiBaselineProgress('open','Loading reference baseline');
        pg=onCleanup(@()fusiBaselineProgress('close',progress)); %#ok<NASGU>
        r=fusiBaselineReadWindow(selectedInfo,baseTR*factor,[str2double(first.String) str2double(last.String)],p, ...
            @(fraction,message)fusiBaselineProgress('update',progress,fraction,message));
        [r,note]=fusiBaselineAlignReference(r,shape,rawInfo.metadata,targetGeometry);gridText.String=note;
        fusiBaselineProgress('close',progress);fusiBaselineReference('validate',r,shape);
    end
    function loadReference(~,~)
        [n,p]=uigetfile('*.mat','Saved shared baseline mean map',startPath);if isequal(n,0),return;end
        try
            s=load(fullfile(p,n),'reference');ref=s.reference;
            geometry=struct();if isfield(ref,'sourceGeometry'),geometry=ref.sourceGeometry;end
            [ref,note]=fusiBaselineAlignReference(ref,shape,geometry,targetGeometry);
            gridText.String=note;selectedInfo=[];showRef();status.String='Saved mean map loaded; no movie needs to be loaded.';
        catch ME,ref=[];status.String=ME.message;end
    end
    function showRef()
        mode.Value=1;modeChanged();fileText.String=fusiBaselineReference('label',struct('reference',ref));
        first.String=sprintf('%.9g',ref.windowSec(1));last.String=sprintf('%.9g',ref.windowSec(2));
        if isfield(ref,'rawTR'),trEdit.String=sprintf('%.9g',ref.rawTR);end
        interval.String=sprintf('Saved analysed TR: %.6g s/sample. This reference window is fixed.',ref.TR);
        status.String='Reference mean already available; Apply will reuse it.';
        set([first last trEdit],'Enable','off');
    end
    function saveReference(~,~)
        try
            [n,p]=uiputfile('*.mat','Save reusable baseline mean map','SharedBaseline.mat');if isequal(n,0),return;end
            reference=makeReference();save(fullfile(p,n),'reference','-v7.3');ref=reference;showRef();status.String='Reference saved; Apply will reuse this mean map.';
        catch ME,status.String=ME.message;end
    end
    function apply(~,~)
        applyBtn.Enable='off';f.Pointer='watch';status.String='Applying baseline...';drawnow;
        try
            b=current;if isfield(b,'reference'),b=rmfield(b,'reference');end
            if mode.Value==1,b.reference=makeReference();b.start=b.reference.windowSec(1);b.end=b.reference.windowSec(2);
            else
                b.start=str2double(first.String);b.end=str2double(last.String);
                assert(isfinite(b.start)&&isfinite(b.end)&&b.start>=0&&b.end>b.start,'deConfUSIon:BaselineWindow','Enter a positive-duration baseline window.');
            end
            b.mode='sec';baseline=b;uiresume(f);
        catch ME,status.String=ME.message;end
        if isgraphics(f),applyBtn.Enable='on';f.Pointer='arrow';end
    end
    function cancel(~,~),baseline=[];uiresume(f);end
end
function deleteIfValid(f)
if isgraphics(f),delete(f);end
end
