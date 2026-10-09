function result=fusiScanSequenceDialog(q,b,startPath)
% Add up to ten raw scans; pick a saved power dataset without loading movies.
result=[];q=fusiScanSequence('reference',q,b);entries=[];raw='';C=deConfUSIon_ui('palette');maxScans=fusiScanSequence('maxScans');
if ~isfield(q,'normMode'),q.normMode='shared';end
if ~isfield(q,'localWindowSec')||any(~isfinite(q.localWindowSec))
    local=b;if isfield(b,'localBaseline'),local=b.localBaseline;end;q.localWindowSec=[local.start local.end];
end
f=figure('Name','Scan sequence','NumberTitle','off','MenuBar','none','ToolBar','none', ...
    'Color',C.background,'Units','pixels','Position',[180 80 900 740],'Resize','off','WindowStyle','modal','CloseRequestFcn',@cancel);
guard=onCleanup(@()deleteDialogFigure(f)); %#ok<NASGU>
ctrl('text',sprintf('Compare up to %d scans. Full movies load as needed; other time courses read only the ROI.',maxScans),[20 697 860 28],[]);
list=ctrl('listbox',{''},[20 485 680 202],@selectRow);list.Tag='SequenceScanList';
include=ctrl('checkbox','Include selected scan in curves / 3D sequence',[20 443 400 32],@toggleInclude);include.Tag='SequenceIncludeScan';
all=ctrl('pushbutton','Select all',[450 443 115 32],@selectAll);all.Tag='SequenceSelectAll';
none=ctrl('pushbutton','Unselect all',[575 443 125 32],@selectNone);none.Tag='SequenceSelectNone';
up=ctrl('pushbutton','Move up',[720 645 160 34],@(~,~)move(-1));up.Tag='SequenceMoveUp';
down=ctrl('pushbutton','Move down',[720 601 160 34],@(~,~)move(1));down.Tag='SequenceMoveDown';
remove=ctrl('pushbutton','Remove scan',[720 557 160 34],@removeRow);remove.BackgroundColor=C.danger;remove.Tag='SequenceRemove';
sort=ctrl('pushbutton','Sort by acquisition time',[720 501 160 46],@sortRows);sort.BackgroundColor=C.blue;sort.Tag='SequenceSort';
sort.TooltipString='Uses recorded acquisition time when available, otherwise the raw file modification time. Manual moves preserve your chosen order.';
orderText=ctrl('text','',[20 415 860 25],[]);
normalization=ctrl('popupmenu',{'Shared baseline: retain differences between scans','Normalize each scan to its own baseline window'},[20 367 860 30],@normalizationChanged);
normalization.Tag='SequenceNormalization';normalization.Value=1+strcmp(q.normMode,'local');
ctrl('text','Per-scan baseline start / end (s)',[20 321 290 30],[]);
baseStart=ctrl('edit',sprintf('%.9g',q.localWindowSec(1)),[320 325 110 30],[]);baseStart.Tag='SequenceBaselineStart';
baseEnd=ctrl('edit',sprintf('%.9g',q.localWindowSec(2)),[450 325 110 30],[]);baseEnd.Tag='SequenceBaselineEnd';
normalization.TooltipString='Per-scan normalization can remove baseline offsets and can also hide a real sustained difference. It changes PSC curves and the selected signal overlay.';
rawBtn=ctrl('pushbutton','1. Select RAW scan to add...',[20 278 860 36],@pickRaw);rawBtn.BackgroundColor=C.blue;rawBtn.Tag='SequenceRawScan';
fileText=ctrl('text','Choose the raw scan; then select its preprocessing below.',[20 238 860 32],[]);
dataset=ctrl('popupmenu',{'Select a raw scan first'},[20 200 860 30],[]);dataset.Tag='SequenceDataset';
ctrl('text','Acquisition TR (s), before averaging',[20 157 295 30],[]);
tr=ctrl('edit',sprintf('%.9g',q.scans{q.active}.rawTR),[320 160 110 30],[]);tr.Tag='SequenceTR';
add=ctrl('pushbutton','2. Add selected scan',[450 153 430 38],@addRow);add.BackgroundColor=C.success;add.Tag='SequenceAdd';
if ~isfield(q,'underlayMode'),q.underlayMode='keep';end
underlay=ctrl('popupmenu',{'Overlay change: keep current anatomy and contrast','Overlay change: choose selected scan Mask Editor bundle','Overlay change: selected scan default Doppler underlay'},[20 116 860 30],[]);
underlay.Tag='SequenceUnderlayMode';modes={'keep','mask','default'};underlay.Value=find(strcmp(modes,q.underlayMode),1);
shareAtlas=ctrl('checkbox','Share the loaded atlas alignment and regions across all scans (same positioning)',[20 87 860 26],@atlasSharingChanged);
shareAtlas.Tag='SequenceShareAtlas';shareAtlas.Value=fusiScanSequence('shareAtlas',q);
shareAtlas.TooltipString='Register one scan and load its atlas underlay once. The other scans use that alignment, with native grid origins respected. Their full movies are placed on the atlas only when selected or searched.';
status=ctrl('text','Tick scans for comparison / 3D playback. The signal selector keeps every loaded scan.',[20 57 860 28],[]);status.Tag='SequenceStatus';
cancelBtn=ctrl('pushbutton','Cancel',[610 14 120 36],@cancel);cancelBtn.BackgroundColor=C.danger;cancelBtn.Tag='SequenceCancel';
apply=ctrl('pushbutton','Use sequence',[750 14 130 36],@accept);apply.BackgroundColor=C.success;apply.Tag='SequenceApply';
normalizationChanged();atlasSharingChanged();refresh();uiwait(f);
deleteDialogFigure(f);
    function h=ctrl(style,label,pos,cb)
        h=uicontrol(f,'Style',style,'String',label,'Position',pos,'FontSize',11, ...
            'ForegroundColor',C.text,'BackgroundColor',C.background,'HorizontalAlignment','left');
        if ~isempty(cb),h.Callback=cb;end
    end
    function refresh()
        rows=cell(1,numel(q.scans));
        for k=1:numel(rows)
            d=q.scans{k};mark='';if k==q.active,mark=' [overlay]';end
            included=fusiScanSequence('included',q);tick='[ ]';if included(k),tick='[x]';end
            original='';if isfield(q,'originalKey')&&strcmp(d.key,q.originalKey),original=' [originally loaded]';end
            rows{k}=sprintf('%s %d. %s%s%s | %.6g s/sample | %d samples',tick,k,d.label,mark,original,d.TR,d.nFrames);
        end
        list.String=rows;list.Value=max(1,min(list.Value,numel(rows)));selectRow();
        if strcmp(q.orderMode,'time'),orderText.String='Order: acquisition time (raw file time is used when a recorded timestamp is unavailable).';
        else,orderText.String='Order: manual. Move up/down changes the order of the stitched curves.';end
        add.Enable='on';rawBtn.Enable='on';if numel(q.scans)>=maxScans,add.Enable='off';rawBtn.Enable='off';end
    end
    function selectRow(~,~)
        included=fusiScanSequence('included',q);include.Value=included(list.Value);
        up.Enable='on';down.Enable='on';remove.Enable='on';
        if list.Value==1,up.Enable='off';end
        if list.Value==numel(q.scans),down.Enable='off';end
        if list.Value==q.active,remove.Enable='off';end
        if isfield(q,'originalKey')&&strcmp(q.scans{list.Value}.key,q.originalKey),remove.Enable='off';end
    end
    function toggleInclude(~,~),q.scans{list.Value}.includeTrace=logical(include.Value);refresh();end
    function selectAll(~,~),for k=1:numel(q.scans),q.scans{k}.includeTrace=true;end;refresh();end
    function selectNone(~,~),for k=1:numel(q.scans),q.scans{k}.includeTrace=false;end;refresh();end
    function move(direction)
        a=list.Value;z=a+direction;if z<1||z>numel(q.scans),return;end
        active=q.scans{q.active}.key;q.scans([a z])=q.scans([z a]);q.orderMode='manual';
        q.active=find(cellfun(@(d)strcmp(d.key,active),q.scans),1);list.Value=z;refresh();
    end
    function sortRows(~,~),q=fusiScanSequence('sort',q);refresh();end
    function removeRow(~,~)
        a=list.Value;if a==q.active||isfield(q,'originalKey')&&strcmp(q.scans{a}.key,q.originalKey),return;end
        q.scans(a)=[];if a<q.active,q.active=q.active-1;end;refresh();
    end
    function pickRaw(~,~)
        [n,p]=uigetfile('*.mat','Select RAW scan (saved preprocessing is selected below)',startPath);if isequal(n,0),return;end
        f.Pointer='watch';status.String='Reading scan header and saved dataset names...';drawnow;
        try
            raw=fullfile(p,n);startPath=p;entries=fusiBaselineDatasets(raw);dataset.String={entries.label};dataset.Value=1;
            fileText.String=n;fileText.TooltipString=raw;status.String='Choose comparable preprocessing and click Add selected scan. No movie has been loaded.';
        catch ME,status.String=ME.message;entries=[];end
        f.Pointer='arrow';
    end
    function addRow(~,~)
        if isempty(entries)||numel(q.scans)>=maxScans,return;end
        f.Pointer='watch';drawnow;
        try
            e=entries(dataset.Value);d=fusiScanSequence('describe',raw,e.file,e.label,str2double(tr.String));
            assert(~any(cellfun(@(s)strcmpi(s.key,d.key),q.scans)),'deConfUSIon:ScanSequenceDuplicate','That scan/dataset is already in the sequence.');
            % Reject incompatible grids before any full movie is read.
            mock=struct('mean',ones(d.spatialSize,'single'),'spatialSize',d.spatialSize);
            fusiBaselineAlignReference(mock,q.scans{q.active}.spatialSize,d.geometry,q.scans{q.active}.geometry);
            q.scans{end+1}=d;if strcmp(q.orderMode,'time'),q=fusiScanSequence('sort',q);end
            refresh();status.String='Scan added. Add another scan, change the order, or click Use sequence.';
        catch ME,status.String=ME.message;end
        f.Pointer='arrow';
    end
    function normalizationChanged(~,~)
        enabled='off';q.normMode='shared';if normalization.Value==2,enabled='on';q.normMode='local';end
        set([baseStart baseEnd],'Enable',enabled);
    end
    function accept(~,~)
        q.underlayMode=modes{underlay.Value};
        q.shareAtlasMapping=logical(shareAtlas.Value);
        q.localWindowSec=[str2double(baseStart.String) str2double(baseEnd.String)];
        if strcmp(q.normMode,'local')&&(any(~isfinite(q.localWindowSec))||q.localWindowSec(1)<0||q.localWindowSec(2)<=q.localWindowSec(1))
            status.String='Enter a positive baseline window that fits within every scan.';return;
        end
        result=q;uiresume(f);
    end
    function atlasSharingChanged(varargin)
        underlay.Enable='on';
        if shareAtlas.Value&&isfield(q,'atlasRegistered')&&q.atlasRegistered
            underlay.Enable='off';status.String='One atlas alignment is shared across every loaded scan; no separate registration files are required.';
        end
    end
    function cancel(~,~),result=[];uiresume(f);end
end
function deleteDialogFigure(f),if isgraphics(f),delete(f);end,end
