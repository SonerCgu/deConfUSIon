function gaTitrationBrackets(action,ax,varargin)
% Pairwise annotations live above the data axes, never inside its Y limits.
% Owners reserve L.requiredTopPixels, then call 'layout' after positioning or
% font changes. This keeps user-entered Y limits exact in previews/exports.
switch lower(action)
    case 'draw'
        D=varargin{1};S=varargin{2};centres=varargin{3};dataTop=varargin{4};fg=varargin{5};
        if ~value(S,'titrationShowP',true),return;end
        result=D.comparisonResults;specs=result.comparisons;
        specs=specs(arrayfun(@(s)strcmp(s.status,'ok')&&isfinite(s.pAdjusted),specs));
        if isempty(specs),return;end
        keys={D.categories.key};intervals=zeros(numel(specs),2);
        for i=1:numel(specs)
            intervals(i,:)=sort([find(strcmp(keys,specs(i).leftKey),1) find(strcmp(keys,specs(i).rightKey),1)]);
        end
        [~,order]=sort(intervals(:,2)-intervals(:,1));levels=zeros(size(specs));occupied={};
        for i=order(:)'
            level=1;span=intervals(i,:)+[-.12 .12];
            while level<=numel(occupied)&&any(occupied{level}(:,1)<=span(2)&occupied{level}(:,2)>=span(1)),level=level+1;end
            if level>numel(occupied),occupied{level}=zeros(0,2);end
            occupied{level}(end+1,:)=span;levels(i)=level;
        end
        lines=gobjects(numel(specs),1);labels=lines;limits=ylim(ax);
        % Annotation lines must not participate in autoscaling, including
        % while the graphics are first being created.
        set(ax,'YLim',limits,'YLimMode','manual');
        hold(ax,'on');
        for i=1:numel(specs)
            x=centres(intervals(i,:));p=specs(i).pAdjusted;
            textP=gaFormatPValue(p);
            if ~strcmpi(result.correction,'None')&&result.familySize>1,textP=regexprep(textP,'^p','p_adj');end
            stars=gaSignificanceStars(p);
            if p>=result.alpha,stars='n.s.';elseif strcmp(stars,'n.s.'),stars='*';end
            mode=value(S,'titrationPDisplay','Both');
            % Legacy p-values-only settings also show stars, matching the
            % standard group plot. Formatting never changes the tested p.
            if strcmpi(mode,'Stars'),label=stars;else,label=[stars '   ' textP];end
            if strcmpi(get(ax,'XScale'),'log'),mid=sqrt(prod(x));else,mid=mean(x);end
            mid=toNormalized(ax,mid,'X');
            lines(i)=plot(ax,[x(1) x(1) x(2) x(2)],repmat(limits(2),1,4),'Color',fg,'LineWidth',1, ...
                'Clipping','off','HandleVisibility','off','Tag','GA_TitrationBracket');
            labels(i)=text(ax,mid,1,label,'Units','normalized','HorizontalAlignment','center','VerticalAlignment','bottom', ...
                'FontName','Arial','FontSize',10,'FontWeight','bold','Color',fg, ...
                'Interpreter','none','Clipping','off','Tag','GA_TitrationPValue');
        end
        setappdata(ax,'GA_TitrationBracketLayout',struct('lines',lines,'labels',labels,'levels',levels, ...
            'dataTop',dataTop,'baseLimits',limits,'familySize',result.familySize, ...
            'intervals',intervals,'centres',centres,'requiredTopPixels',0,'normalizedHeight',0));
        layout(ax);hold(ax,'off');
    case 'layout',layout(ax);
end
end

function layout(ax)
if ~isappdata(ax,'GA_TitrationBracketLayout'),return;end
L=getappdata(ax,'GA_TitrationBracketLayout');
if isempty(L.labels)||any(~isgraphics(L.labels))||any(~isgraphics(L.lines)),return;end
% A measured pixel band is independent of the Y range and of axes height.
% Publication rendering can scale the physical gaps along with its fonts.
scale=1;
if isappdata(ax,'GA_TitrationAnnotationScale'),scale=getappdata(ax,'GA_TitrationAnnotationScale');end
if ~isnumeric(scale)||~isscalar(scale)||~isfinite(scale)||scale<=0,scale=1;end
drawnow nocallbacks;
pixelPosition=getpixelposition(ax,true);height=max(1,pixelPosition(4));width=max(1,pixelPosition(3));
textHeight=0;spans=zeros(numel(L.labels),2);xEnds=zeros(numel(L.labels),2);
categoryX=toNormalized(ax,L.centres,'X');
gaps=diff(sort(unique(categoryX)));gaps=gaps(gaps>0);
if isempty(gaps),gap=1;else,gap=min(gaps);end
for i=1:numel(L.labels)
    endpoints=reshape(sort(categoryX(L.intervals(i,:))),1,[]);inset=min(.04*gap,.15*diff(endpoints));
    xEnds(i,:)=endpoints+[inset -inset];
    pos=get(L.labels(i),'Position');pos(1)=mean(endpoints);set(L.labels(i),'Position',pos);
    box=get(L.labels(i),'Extent');
    % Keep the label inside the horizontal plotting span at either edge.
    halfWidth=box(3)/2;
    if box(3)<.98,pos(1)=min(1-.01-halfWidth,max(.01+halfWidth,pos(1)));set(L.labels(i),'Position',pos);end
    box=get(L.labels(i),'Extent');textHeight=max(textHeight,box(4)*height);
    spans(i,:)=[min(xEnds(i,1),box(1)) max(xEnds(i,2),box(1)+box(3))]+[-2 2]*scale/width;
end
% Long labels can occupy more horizontal room than their bracket. Rebuild
% levels using the actual extents so adjacent independent pairs do not clash.
[~,order]=sort(diff(xEnds,1,2));levels=zeros(size(L.levels));occupied={};
for i=order(:)'
    level=1;
    while level<=numel(occupied)&&any(occupied{level}(:,1)<=spans(i,2)&occupied{level}(:,2)>=spans(i,1)),level=level+1;end
    if level>numel(occupied),occupied{level}=zeros(0,2);end
    occupied{level}(end+1,:)=spans(i,:);levels(i)=level;
end
cap=3*scale;bottomGap=5*scale;textGap=2*scale;rowGap=5*scale;
step=textHeight+textGap+cap+rowGap;start=bottomGap+cap;
for i=1:numel(L.lines)
    above=start+(levels(i)-1)*step;
    y=fromNormalized(ax,1+[above-cap above above above-cap]/height,'Y');
    x=fromNormalized(ax,xEnds(i,:),'X');
    set(L.lines(i),'XData',[x(1) x(1) x(2) x(2)],'YData',y);
    pos=get(L.labels(i),'Position');pos(2)=1+(above+textGap)/height;set(L.labels(i),'Position',pos);
end
L.levels=levels;
L.requiredTopPixels=ceil(start+(max(levels)-1)*step+textGap+textHeight+4*scale);
L.normalizedHeight=L.requiredTopPixels/height;
L.annotationScale=scale;
setappdata(ax,'GA_TitrationBracketLayout',L);
end

function normalized=toNormalized(ax,coordinate,dimension)
limits=get(ax,[dimension 'Lim']);
if strcmpi(get(ax,[dimension 'Scale']),'log'),coordinate=log10(coordinate);limits=log10(limits);end
normalized=(coordinate-limits(1))/diff(limits);
end

function coordinate=fromNormalized(ax,normalized,dimension)
limits=get(ax,[dimension 'Lim']);isLog=strcmpi(get(ax,[dimension 'Scale']),'log');
if isLog,limits=log10(limits);end
coordinate=limits(1)+normalized*diff(limits);
if isLog,coordinate=10.^coordinate;end
end

function out=value(S,name,fallback)
out=fallback;if isfield(S,name)&&~isempty(S.(name)),out=S.(name);end
end
