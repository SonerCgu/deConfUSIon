function varargout=gaExportBrackets(action,ax,varargin)
% Move export-only statistical annotations without changing data or tests.
% Offsets are physical points from the renderer's automatic positions. The
% same offsets therefore survive preview scaling and PNG/PDF rendering.
if ~isgraphics(ax,'axes')
    if strcmpi(action,'capture'),varargout{1}=emptyOffsets();end
    return;
end
switch lower(action)
    case 'apply'
        finishForAxes(ax);groups=annotationGroups(ax);
        offsets=emptyOffsets();if ~isempty(varargin),offsets=varargin{1};end
        for k=1:numel(groups)
            at=[];if isstruct(offsets)&&all(isfield(offsets,{'key','dx','dy'})),at=find(strcmp({offsets.key},groups(k).key),1);end
            delta=[0 0];
            if ~isempty(at)&&isnumeric(offsets(at).dx)&&isscalar(offsets(at).dx)&& ...
                    isnumeric(offsets(at).dy)&&isscalar(offsets(at).dy)&&all(isfinite([offsets(at).dx offsets(at).dy]))
                delta=[offsets(at).dx offsets(at).dy];
            end
            groups(k)=placeGroup(ax,groups(k),delta);
        end
        setappdata(ax,'GA_ExportBracketGroups',groups);
    case 'capture'
        groups=annotationGroups(ax);out=emptyOffsets();
        for k=1:numel(groups),out(k)=struct('key',groups(k).key,'dx',groups(k).offset(1),'dy',groups(k).offset(2));end %#ok<AGROW>
        varargout{1}=out;
    case 'enable'
        groups=annotationGroups(ax);
        for k=1:numel(groups)
            handles=[groups(k).line groups(k).label];
            for h=handles(:)'
                if ~isappdata(h,'GA_ExportOriginalClick')
                    setappdata(h,'GA_ExportOriginalClick',struct('callback',{get(h,'ButtonDownFcn')}, ...
                        'hitTest',get(h,'HitTest'),'pickableParts',get(h,'PickableParts')));
                end
                set(h,'HitTest','on','PickableParts','all','ButtonDownFcn',@(src,evt)beginDrag(ax,groups(k).key));
            end
        end
        if ~isappdata(ax,'GA_ExportBracketDeleteListener')
            fig=ancestor(ax,'figure');
            listener=addlistener(ax,'ObjectBeingDestroyed',@(src,evt)finishDrag(fig));
            setappdata(ax,'GA_ExportBracketDeleteListener',listener);
        end
    case 'disable'
        finishForAxes(ax);groups=annotationGroups(ax);
        for k=1:numel(groups)
            for h=[groups(k).line groups(k).label]
                if isgraphics(h)&&isappdata(h,'GA_ExportOriginalClick')
                    old=getappdata(h,'GA_ExportOriginalClick');
                    set(h,'ButtonDownFcn',old.callback,'HitTest',old.hitTest,'PickableParts',old.pickableParts);
                    rmappdata(h,'GA_ExportOriginalClick');
                end
            end
        end
        if isappdata(ax,'GA_ExportBracketDeleteListener')
            listener=getappdata(ax,'GA_ExportBracketDeleteListener');rmappdata(ax,'GA_ExportBracketDeleteListener');delete(listener);
        end
    case 'reset'
        gaExportBrackets('apply',ax,emptyOffsets());
    case 'move'
        groups=annotationGroups(ax);key=varargin{1};at=find(strcmp({groups.key},key),1);
        if isempty(at),return;end
        delta=[varargin{2} varargin{3}];
        if ~isnumeric(delta)||numel(delta)~=2||any(~isfinite(delta)),return;end
        groups(at)=placeGroup(ax,groups(at),delta);
        setappdata(ax,'GA_ExportBracketGroups',groups);
        if nargout,varargout{1}=gaExportBrackets('capture',ax);end
    otherwise
        error('GroupAnalysis:ExportBracketsAction','Unknown annotation action: %s',action);
end
end

function groups=annotationGroups(ax)
if isappdata(ax,'GA_ExportBracketGroups')
    groups=getappdata(ax,'GA_ExportBracketGroups');
    if all(arrayfun(@(g)isgraphics(g.label)&&all(isgraphics(g.line)),groups)),return;end
end
groups=struct('key',{},'line',{},'label',{},'baseX',{},'baseY',{},'baseLabel',{},'baseExtent',{},'offset',{});
if isappdata(ax,'GA_TitrationBracketLayout')
    L=getappdata(ax,'GA_TitrationBracketLayout');
    for k=1:numel(L.labels)
        if ~isgraphics(L.labels(k))||~isgraphics(L.lines(k)),continue;end
        key=sprintf('titration_%d_%d',L.intervals(k,1),L.intervals(k,2));
        groups(end+1)=baseline(ax,key,L.lines(k),L.labels(k)); %#ok<AGROW>
    end
end
labels=findall(ax,'Tag','GA_ROI_PLabel');lines=findall(ax,'Tag','GA_ROI_PBracket');
for k=1:numel(labels)
    key='roi_summary';if numel(labels)>1,key=sprintf('roi_summary_%d',k);end
    line=[];if k<=numel(lines),line=lines(k);end
    groups(end+1)=baseline(ax,key,line,labels(k)); %#ok<AGROW>
end
setappdata(ax,'GA_ExportBracketGroups',groups);
end

function group=baseline(ax,key,line,label)
drawnow nocallbacks;
units=get(label,'Units');set(label,'Units','normalized');
position=get(label,'Position');extent=get(label,'Extent');set(label,'Units',units);
x=[];y=[];
if ~isempty(line)
    x=toNormalized(ax,get(line,'XData'),'X');y=toNormalized(ax,get(line,'YData'),'Y');
    % Annotation movement must never take part in data autoscaling.
    set(line,'XLimInclude','off','YLimInclude','off');
end
group=struct('key',key,'line',line,'label',label,'baseX',x,'baseY',y, ...
    'baseLabel',position,'baseExtent',extent,'offset',[0 0]);
end

function group=placeGroup(ax,group,points)
pixelsPerPoint=pointScale(ax);box=getpixelposition(ax,true);size=max(1,box(3:4));
delta=points*pixelsPerPoint./size;
extent=group.baseExtent;lower=extent(1:2);upper=extent(1:2)+extent(3:4);
if ~isempty(group.line)
    lower=min(lower,[min(group.baseX) min(group.baseY)]);upper=max(upper,[max(group.baseX) max(group.baseY)]);
end
canvas=ancestor(ax,'uipanel');
if isempty(canvas)
    canvas=ancestor(ax,'figure');canvasBox=getpixelposition(canvas);canvasBox=[1 1 canvasBox(3:4)];
else
    canvasBox=getpixelposition(canvas,true);
end
padding=2*exportScale(ax);
minimum=(canvasBox(1:2)+padding-box(1:2))./size-lower;
maximum=(canvasBox(1:2)+canvasBox(3:4)-padding-box(1:2))./size-upper;
for k=1:2
    if minimum(k)<=maximum(k),delta(k)=min(maximum(k),max(minimum(k),delta(k)));
    else,delta(k)=mean([minimum(k) maximum(k)]);end
end
limits={get(ax,'XLim'),get(ax,'YLim')};modes={get(ax,'XLimMode'),get(ax,'YLimMode')};
set(ax,'XLimMode','manual','YLimMode','manual');
if ~isempty(group.line)
    set(group.line,'XData',fromNormalized(ax,group.baseX+delta(1),'X'), ...
        'YData',fromNormalized(ax,group.baseY+delta(2),'Y'));
end
units=get(group.label,'Units');set(group.label,'Units','normalized');
position=group.baseLabel;position(1:2)=position(1:2)+delta;set(group.label,'Position',position,'Units',units);
set(ax,'XLim',limits{1},'YLim',limits{2},'XLimMode',modes{1},'YLimMode',modes{2});
group.offset=delta.*size/pixelsPerPoint;
end

function beginDrag(ax,key)
if ~isgraphics(ax,'axes'),return;end
fig=ancestor(ax,'figure');finishDrag(fig);
offsets=gaExportBrackets('capture',ax);at=find(strcmp({offsets.key},key),1);if isempty(at),return;end
state=struct('ax',ax,'key',key,'start',figurePoint(fig),'offset',[offsets(at).dx offsets(at).dy], ...
    'motion',{get(fig,'WindowButtonMotionFcn')},'up',{get(fig,'WindowButtonUpFcn')},'pointer',get(fig,'Pointer'));
setappdata(fig,'GA_ExportBracketDrag',state);
set(fig,'WindowButtonMotionFcn',@(src,evt)drag(fig),'WindowButtonUpFcn',@(src,evt)finishDrag(fig),'Pointer','fleur');
end

function drag(fig)
if ~isgraphics(fig)||~isappdata(fig,'GA_ExportBracketDrag'),return;end
state=getappdata(fig,'GA_ExportBracketDrag');
if ~isgraphics(state.ax),finishDrag(fig);return;end
delta=(figurePoint(fig)-state.start)/pointScale(state.ax);
points=state.offset+delta;
gaExportBrackets('move',state.ax,state.key,points(1),points(2));drawnow limitrate nocallbacks;
end

function finishForAxes(ax)
fig=ancestor(ax,'figure');
if isgraphics(fig)&&isappdata(fig,'GA_ExportBracketDrag')
    state=getappdata(fig,'GA_ExportBracketDrag');if isequal(state.ax,ax),finishDrag(fig);end
end
end

function finishDrag(fig)
if ~isgraphics(fig)||~isappdata(fig,'GA_ExportBracketDrag'),return;end
state=getappdata(fig,'GA_ExportBracketDrag');rmappdata(fig,'GA_ExportBracketDrag');
try,set(fig,'WindowButtonMotionFcn',state.motion,'WindowButtonUpFcn',state.up,'Pointer',state.pointer);catch,end
end

function scale=pointScale(ax)
ppi=get(groot,'ScreenPixelsPerInch');if ~isfinite(ppi)||ppi<=0,ppi=96;end
scale=ppi/72*exportScale(ax);
end

function point=figurePoint(fig)
% Figure CurrentPoint follows Figure.Units; drag deltas need pixels even if
% a caller created a physical-size figure with centimeter units.
units=get(fig,'Units');
if strcmpi(units,'pixels'),point=get(fig,'CurrentPoint');return;end
set(fig,'Units','pixels');point=get(fig,'CurrentPoint');set(fig,'Units',units);
end

function scale=exportScale(ax)
scale=1;if isappdata(ax,'GA_ExportScale'),scale=getappdata(ax,'GA_ExportScale');end
if ~isnumeric(scale)||~isscalar(scale)||~isfinite(scale)||scale<=0,scale=1;end
end

function value=toNormalized(ax,value,dimension)
limits=get(ax,[dimension 'Lim']);
if strcmpi(get(ax,[dimension 'Scale']),'log'),value=log10(value);limits=log10(limits);end
value=(value-limits(1))/diff(limits);
if strcmpi(get(ax,[dimension 'Dir']),'reverse'),value=1-value;end
end

function value=fromNormalized(ax,value,dimension)
limits=get(ax,[dimension 'Lim']);
if strcmpi(get(ax,[dimension 'Dir']),'reverse'),value=1-value;end
logarithmic=strcmpi(get(ax,[dimension 'Scale']),'log');if logarithmic,limits=log10(limits);end
value=limits(1)+value*diff(limits);if logarithmic,value=10.^value;end
end

function offsets=emptyOffsets()
offsets=struct('key',{},'dx',{},'dy',{});
end
