function result=fusiVideoExportDialog(q,nSlices,currentSlice,currentLabel,isVolume)
% Choose export scope independently of the playback checkbox.
if nargin<5,isVolume=false;end
result=[];C=deConfUSIon_ui('palette');included=[];labels={};
if ~isempty(q),included=find(fusiScanSequence('included',q));labels=fusiScanSequence('labels',q);end
scopeNames={'All included scans in their chosen order','Selected signal overlay only'};
f=figure('Name','Export video','NumberTitle','off','MenuBar','none','ToolBar','none', ...
    'Color',C.background,'Units','pixels','Position',[220 160 760 440], ...
    'Resize','off','WindowStyle','modal','CloseRequestFcn',@cancel);
guard=onCleanup(@()deleteFigure(f)); %#ok<NASGU>
control('text','Scans to export',[20 396 720 24],[]);
scope=control('popupmenu',scopeNames,[20 359 720 30],@refresh);
scope.Tag='VideoExportScope';scope.Value=1;if numel(included)<2,scope.Value=2;end
list=control('listbox',{''},[20 175 720 175],[]);list.Tag='VideoExportScans';list.Enable='inactive';
control('text',sprintf('Slices to export (1-%d)',nSlices),[20 139 240 24],[]);
initialSlices=currentSlice;if isnumeric(initialSlices),initialSlices=num2str(initialSlices);end
sliceEdit=control('edit',char(initialSlices),[265 137 475 30],[]);sliceEdit.Tag='VideoExportSlices';
if nSlices==1,sliceEdit.Enable='off';end
control('text',sprintf('Examples: 1 2 10   |   1,2,10   |   7:9   |   all slices: 1:%d',nSlices),[20 102 720 26],[]);
note=control('text','',[20 53 720 43],[]);note.Tag='VideoExportStatus';
button=control('pushbutton','Cancel',[440 12 130 34],@cancel);button.BackgroundColor=C.danger;button.Tag='VideoExportCancel';
button=control('pushbutton','Export MP4',[590 12 150 34],@accept);button.BackgroundColor=C.success;button.Tag='VideoExportStart';
refresh();uiwait(f);deleteFigure(f);
    function h=control(style,label,position,callback)
        h=uicontrol(f,'Style',style,'String',label,'Position',position,'FontSize',11, ...
            'ForegroundColor',C.text,'BackgroundColor',C.background,'HorizontalAlignment','left');
        if ~isempty(callback),h.Callback=callback;end
    end
    function refresh(varargin)
        if scope.Value==1
            if isempty(included),scope.Value=2;refresh();return;end
            list.String=labels(included);list.Value=1;
            note.String=sprintf('%d included scans: one continuous movie per selected slice, plus its paper-ready companion.',numel(included));
            if isVolume,note.String=sprintf('%d included scans: one 3D time-series movie. Selected slices retain their original depths; the atlas context stays complete.',numel(included));end
        else
            list.String={currentLabel};list.Value=1;
            note.String='Exports only the currently selected signal scan.';
        end
        note.ForegroundColor=C.text;
    end
    function accept(varargin)
        try
            slices=fusiMovieExportSlices(sliceEdit.String,nSlices);
            mode='sequence';if scope.Value==2,mode='current';end
            result=struct('scope',mode,'slices',slices);uiresume(f);
        catch ME,note.String=ME.message;note.ForegroundColor=C.danger;end
    end
    function cancel(varargin),result=[];uiresume(f);end
end
function deleteFigure(f),if isgraphics(f),delete(f);end,end
