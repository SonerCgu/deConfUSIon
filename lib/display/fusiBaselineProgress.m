function varargout=fusiBaselineProgress(action,varargin)
% A readable, cancellable progress view. Percentages reflect real work.
switch action
    case 'open'
        C=deConfUSIon_ui('palette');labels={};if numel(varargin)>1,labels=varargin{2};end
        h=figure('Name',varargin{1},'Tag','FUSIBaselineProgress','NumberTitle','off','MenuBar','none','ToolBar','none', ...
            'Color',C.background,'Position',[420 220 660 350+24*numel(labels)],'Resize','off', ...
            'WindowStyle','modal','CloseRequestFcn',@cancelProcessing,'DeleteFcn',@deleteProgress);
        setappdata(h,'deConfUSIonNoMaximize',true);setappdata(h,'Cancelled',false);
        height=h.Position(4);
        heading=label(h,[24 height-55 612 30],'Preparing...','FUSIProgressHeading',C);heading.FontWeight='bold';heading.FontSize=14;
        label(h,[24 height-115 612 58],'Reading recordings and preparing time courses.','FUSIProgressStage',C);
        ax=axes('Parent',h,'Units','pixels','Position',[24 height-153 542 20], ...
            'XLim',[0 1],'YLim',[0 1],'XTick',[],'YTick',[],'Color',C.panel,'Box','on');
        fill=patch(ax,[0 0 0 0],[0 0 1 1],C.blue,'EdgeColor','none','Tag','FUSIProgressFill');
        percent=label(h,[574 height-163 62 34],'0%','FUSIProgressPercent',C);percent.FontWeight='bold';
        rows=gobjects(1,numel(labels));
        for k=1:numel(labels),rows(k)=label(h,[24 height-187-24*k 612 24],sprintf('  %d. %s',k,labels{k}),'FUSIProgressScan',C);end
        clock=label(h,[24 81 612 27],'Elapsed 0 s','FUSIProgressElapsed',C);
        hint=label(h,[24 48 438 30],'Network reads can take a few seconds. Cancel stops after the current read.','FUSIProgressHint',C);hint.FontSize=10;
        uicontrol(h,'Style','pushbutton','String','Cancel','Tag','FUSIProgressCancel','Position',[506 30 130 36], ...
            'BackgroundColor',C.danger,'ForegroundColor',C.text,'FontSize',12,'Callback',@cancelProcessing);
        s=struct('heading',heading,'stage',findobj(h,'Tag','FUSIProgressStage'),'fill',fill,'percent',percent, ...
            'clock',clock,'rows',rows,'labels',{labels},'started',tic,'updated',tic,'message','','fraction',0,'roi',1,'roiCount',1);
        setappdata(h,'ProgressState',s);
        tm=timer('ExecutionMode','fixedSpacing','Period',.5,'BusyMode','drop','TimerFcn',@progressClock,'UserData',h);
        setappdata(h,'ProgressClock',tm);start(tm);drawnow;varargout{1}=h;
    case 'roi'
        h=varargin{1};checkCancelled(h);s=getappdata(h,'ProgressState');s.roi=varargin{2};s.roiCount=varargin{3};setappdata(h,'ProgressState',s);
    case 'scan'
        h=varargin{1};checkCancelled(h);s=getappdata(h,'ProgressState');index=varargin{2};fraction=varargin{3};
        fraction=max(0,min(1,fraction));n=max(1,numel(s.labels));
        s.heading.String=sprintf('ROI %d / %d  |  Scan %d / %d',s.roi,s.roiCount,index,n);
        for k=1:numel(s.rows)
            mark='Waiting';if k<index||k==index&&fraction>=1,mark='Ready';elseif k==index,mark='Reading';end
            s.rows(k).String=sprintf('%s  |  %d. %s',mark,k,s.labels{k});
        end
        setappdata(h,'ProgressState',s);
        update(h,(index-1+fraction)/n,varargin{4});
    case 'update',update(varargin{:});
    case 'close'
        h=varargin{1};if isgraphics(h),delete(h);end
end
end
function h=label(f,pos,str,tag,C)
h=uicontrol(f,'Style','text','String',str,'Position',pos,'Tag',tag,'HorizontalAlignment','left', ...
    'BackgroundColor',C.background,'ForegroundColor',C.text,'FontSize',11);
end
function update(h,fraction,message)
checkCancelled(h);s=getappdata(h,'ProgressState');if isempty(fraction),fraction=0;end
fraction=min(1,max(0,fraction));
% Keep state exact, but repaint at most ten times/second. Distinct stage
% messages must not trigger dozens of full GUI renders for one fast ROI.
% Flush immediately before a potentially blocking disk/network read.
repaint=fraction>=1||contains(message,'disk / network')||toc(s.updated)>=.1;
scan=regexp(message,'^Scan (\d+)/(\d+):','tokens','once');
if ~isempty(scan)&&~isempty(s.labels)
    index=str2double(scan{1});n=str2double(scan{2});
    s.heading.String=sprintf('ROI %d / %d  |  Scan %d / %d',s.roi,s.roiCount,index,n);
    for k=1:numel(s.rows)
        mark='Waiting';if k<index||k==index&&fraction>=index/n-1e-9,mark='Ready';elseif k==index,mark='Reading';end
        s.rows(k).String=sprintf('%s  |  %d. %s',mark,k,s.labels{k});
    end
end
fraction=(s.roi-1+fraction)/s.roiCount;
s.fill.XData=[0 fraction fraction 0];s.percent.String=sprintf('%d%%',floor(100*fraction));
s.stage.String=message;s.clock.String=elapsedText(toc(s.started));s.message=message;s.fraction=fraction;
if repaint,s.updated=tic;end
if isempty(s.labels),s.heading.String='Processing recordings';end
setappdata(h,'ProgressState',s);if repaint,drawnow;end;checkCancelled(h);
end
function checkCancelled(h)
assert(isgraphics(h)&&~getappdata(h,'Cancelled'),'deConfUSIon:ProcessingCancelled','Processing cancelled.');
end
function cancelProcessing(h,~)
if ~strcmp(h.Type,'figure'),h=ancestor(h,'figure');end
setappdata(h,'Cancelled',true);
button=findobj(h,'Tag','FUSIProgressCancel');set(button,'String','Cancelling...','Enable','off');
end
function progressClock(tm,~)
h=tm.UserData;if ~isgraphics(h),return;end
s=getappdata(h,'ProgressState');if ~isempty(s)&&isgraphics(s.clock),s.clock.String=elapsedText(toc(s.started));end
end
function s=elapsedText(seconds)
seconds=floor(seconds);s=sprintf('Elapsed %d min %02d s',floor(seconds/60),mod(seconds,60));
end
function deleteProgress(h,~)
tm=getappdata(h,'ProgressClock');if isa(tm,'timer')&&isvalid(tm),stop(tm);delete(tm);end
end
