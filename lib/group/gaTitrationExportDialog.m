function [options,applied]=gaTitrationExportDialog(R,S,options,parent,renderer)
% Review paper proportions and position statistical labels before export.
if nargin<3||isempty(options),options=struct();end
if nargin<4,parent=[];end
if nargin<5||isempty(renderer)
    renderer=@(container,current)gaTitrationPublication('render',container,R,S,current);
end
original=options;applied=false;finished=false;
if ~isfield(options,'showLegend'),options.showLegend=field(S,'titrationShowLegend',true);end
annotationAx=[];rendering=false;pendingRefresh=false;
presets=gaTitrationPublication('presets');
bg=[.1 .1 .1];fg=[.95 .95 .95];edit=[.16 .16 .16];
visible=get(groot,'DefaultFigureVisible');
if ~isempty(parent)&&isgraphics(parent),visible=get(parent,'Visible');end
screen=get(groot,'ScreenSize');sz=min([1180 780],screen(3:4)-[80 100]);
f=figure('Name',field(options,'title','Titration publication export preview'),'NumberTitle','off', ...
    'MenuBar','none','ToolBar','none','Visible','off','WindowStyle','normal', ...
    'Position',[80 70 sz],'Color',bg,'Tag','GA_TitrationExportDialog', ...
    'CloseRequestFcn',@cancel,'WindowKeyPressFcn',@onKey);
guard=onCleanup(@()deleteIfValid(f)); %#ok<NASGU>
uicontrol(f,'Style','text','String','Publication export preview','Units','normalized', ...
    'Position',[.025 .925 .24 .05],'BackgroundColor',bg,'ForegroundColor',fg, ...
    'HorizontalAlignment','left','FontSize',14,'FontWeight','bold');
uicontrol(f,'Style','text','String','Layout','Units','normalized','Position',[.025 .865 .22 .03], ...
    'BackgroundColor',bg,'ForegroundColor',fg,'HorizontalAlignment','left');
names=cell(1,numel(presets));
for i=1:numel(presets),names{i}=sprintf('%s (%g x %g mm)',presets(i).name,presets(i).widthMM,presets(i).heightMM);end
layout=uicontrol(f,'Style','popupmenu','String',names,'Units','normalized', ...
    'Position',[.025 .815 .23 .045],'BackgroundColor',edit,'ForegroundColor',fg, ...
    'Value',max(1,min(numel(presets),field(options,'preset',1))), ...
    'Tag','GA_TitrationExportLayout','Callback',@refresh);
uicontrol(f,'Style','text','String','Background','Units','normalized','Position',[.025 .76 .22 .03], ...
    'BackgroundColor',bg,'ForegroundColor',fg,'HorizontalAlignment','left');
theme=uicontrol(f,'Style','popupmenu','String',{'Light','Dark'},'Units','normalized', ...
    'Position',[.025 .71 .23 .045],'BackgroundColor',edit,'ForegroundColor',fg, ...
    'Value',1+double(strcmpi(field(options,'theme','Light'),'Dark')), ...
    'Tag','GA_TitrationExportTheme','Callback',@refresh);
uicontrol(f,'Style','text','String','Output','Units','normalized','Position',[.025 .655 .22 .03], ...
    'BackgroundColor',bg,'ForegroundColor',fg,'HorizontalAlignment','left');
formats={'PNG (600 dpi)','PDF (vector)','PNG + PDF'};
format=uicontrol(f,'Style','popupmenu','String',formats,'Units','normalized', ...
    'Position',[.025 .605 .23 .045],'BackgroundColor',edit,'ForegroundColor',fg, ...
    'Tag','GA_TitrationExportFormat');
stored=field(options,'format','PNG');v=find(strcmpi({'PNG','PDF','Both'},stored),1);if ~isempty(v),set(format,'Value',v);end
showLegend=uicontrol(f,'Style','checkbox','String','Show legend','Units','normalized', ...
    'Position',[.025 .55 .23 .035],'BackgroundColor',bg,'ForegroundColor',fg, ...
    'Value',double(logical(options.showLegend)),'Tag','GA_ExportShowLegend','Callback',@refresh);
uicontrol(f,'Style','text','String','Legend position','Units','normalized','Position',[.025 .505 .22 .03], ...
    'BackgroundColor',bg,'ForegroundColor',fg,'HorizontalAlignment','left');
legendKeys={'above-right','above-left','inside-northeast','inside-northwest','inside-southeast','inside-southwest'};
legendNames={'Above plot: right','Above plot: left','Inside: top right','Inside: top left','Inside: bottom right','Inside: bottom left'};
whichLegend=find(strcmp(legendKeys,field(options,'legendPosition','above-right')),1);if isempty(whichLegend),whichLegend=1;end
legendPosition=uicontrol(f,'Style','popupmenu','String',legendNames,'Value',whichLegend, ...
    'Units','normalized','Position',[.025 .455 .23 .045],'BackgroundColor',edit,'ForegroundColor',fg, ...
    'Tag','GA_ExportLegendPosition','Callback',@refresh);
status=uicontrol(f,'Style','text','String','','Units','normalized','Position',[.025 .31 .23 .13], ...
    'BackgroundColor',bg,'ForegroundColor',fg,'HorizontalAlignment','left','FontSize',10, ...
    'Tag','GA_TitrationExportStatus');
uicontrol(f,'Style','pushbutton','String','Reset p-value positions','Units','normalized', ...
    'Position',[.025 .245 .23 .05],'Callback',@resetPositions,'Tag','GA_ExportResetPositions');
uicontrol(f,'Style','text','String',{'Drag a p-value or its bracket to move them together.', ...
    'Your y-axis limits stay fixed.'}, ...
    'Units','normalized','Position',[.025 .135 .23 .105],'BackgroundColor',bg, ...
    'ForegroundColor',fg,'HorizontalAlignment','left','FontSize',10);
applyButton=uicontrol(f,'Style','pushbutton','String','Continue to export...','Units','normalized', ...
    'Position',[.025 .065 .23 .06],'BackgroundColor',[.22 .7 .52],'Callback',@apply, ...
    'Tag','GA_TitrationExportApply');
uicontrol(f,'Style','pushbutton','String','Cancel','Units','normalized', ...
    'Position',[.025 .01 .23 .045],'Callback',@cancel,'Tag','GA_TitrationExportCancel');
preview=uipanel(f,'Units','normalized','Position',[.28 .04 .70 .92], ...
    'BackgroundColor',[.22 .22 .22],'BorderType','none','Tag','GA_TitrationExportCanvas');
set(f,'SizeChangedFcn',@refresh);refresh();movegui(f,'center');
set(f,'WindowStyle','modal','Visible',visible);
if strcmpi(visible,'on'),figure(f);end
if ~finished&&isgraphics(f),uiwait(f);end
disableDragging();deleteIfValid(f);
if ~applied,options=original;end

    function current=readOptions()
        current=options;current.preset=get(layout,'Value');
        items=get(theme,'String');current.theme=items{get(theme,'Value')};
        kinds={'PNG','PDF','Both'};current.format=kinds{get(format,'Value')};
        current.showLegend=logical(get(showLegend,'Value'));
        current.legendPosition=legendKeys{get(legendPosition,'Value')};
        current.preview=true;
    end
    function refresh(varargin) %#ok<INUSD>
        if ~isgraphics(f)||~isgraphics(preview),return;end
        if rendering,pendingRefresh=true;return;end
        rendering=true;refreshGuard=onCleanup(@finishRefresh); %#ok<NASGU>
        set(applyButton,'Enable','off');
        capturePositions();disableDragging();
        try
            current=readOptions();ax=renderer(preview,current);annotationAx=ax;
            if current.showLegend,set(legendPosition,'Enable','on');else,set(legendPosition,'Enable','off');end
            gaExportBrackets('enable',ax);
            limits=ylim(ax);p=presets(current.preset);
            set(status,'String',{sprintf('%s: %g x %g mm',p.name,p.widthMM,p.heightMM), ...
                sprintf('Data y-range: %g to %g',limits(1),limits(2)), ...
                'Export keeps the positions shown here.'});
            set(applyButton,'Enable','on');
        catch ME
            set(status,'String',ME.message);set(applyButton,'Enable','off');
        end
    end
    function apply(~,~)
        if rendering||strcmp(get(applyButton,'Enable'),'off'),return;end
        capturePositions();disableDragging();
        options=readOptions();options.preview=false;applied=true;finished=true;uiresume(f);
    end
    function cancel(~,~),disableDragging();finished=true;uiresume(f);end
    function onKey(~,evt),if strcmp(evt.Key,'escape'),cancel([],[]);end;end
    function finishRefresh()
        rendering=false;
        if pendingRefresh&&~finished&&isgraphics(f),pendingRefresh=false;refresh();end
    end
    function capturePositions()
        if ~isempty(annotationAx)&&isgraphics(annotationAx)
            options.annotationOffsets=gaExportBrackets('capture',annotationAx);
        end
    end
    function disableDragging()
        if ~isempty(annotationAx)&&isgraphics(annotationAx),gaExportBrackets('disable',annotationAx);end
    end
    function resetPositions(~,~)
        if rendering,return;end
        if ~isempty(annotationAx)&&isgraphics(annotationAx),gaExportBrackets('reset',annotationAx);end
        options.annotationOffsets=struct('key',{},'dx',{},'dy',{});refresh();
    end
end

function out=field(S,name,fallback)
out=fallback;if isfield(S,name)&&~isempty(S.(name)),out=S.(name);end
end
function deleteIfValid(f)
if isgraphics(f),delete(f);end
end
