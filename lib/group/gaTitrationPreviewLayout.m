function gaTitrationPreviewLayout(ax,viewport)
% Fit the live bottom graph and a separate annotation/legend band. The data
% limits remain the user's limits; extra space is figure space, not PSC.
if nargin<2,viewport=[.095 .06 .85 .285];end
container=get(ax,'Parent');bounds=getpixelposition(container);width=bounds(3);height=bounds(4);
box=viewport.*[width height width height];
setappdata(ax,'GA_TitrationAnnotationScale',1);
lg=legendFor(ax);legendHeight=0;
if ~isempty(lg)
    set(lg,'Orientation','horizontal','NumColumns',max(1,numel(lg.String)),'Units','pixels');
    drawnow nocallbacks;p=get(lg,'Position');legendHeight=p(4)+8;
end
labels=findall(ax,'Tag','GA_TitrationPValue');font=10;
set(labels,'FontSize',font,'FontWeight','bold');
chartWidth=min(box(3),max(300,1.9*box(4)));
left=box(1)+(box(3)-chartWidth)/2;
% Measure at the final plot width. Long labels can require another level
% when a wide GUI axes becomes a balanced preview panel.
set(ax,'Units','pixels','Position',[left box(2) chartWidth max(50,box(4)-legendHeight-8)]);
gaTitration('layoutannotations',ax);band=0;
if isappdata(ax,'GA_TitrationBracketLayout')
    L=getappdata(ax,'GA_TitrationBracketLayout');band=L.requiredTopPixels;
end
while band>box(4)-legendHeight-58&&~isempty(labels)&&font>8
    font=font-.5;set(labels,'FontSize',font);
    gaTitration('layoutannotations',ax);L=getappdata(ax,'GA_TitrationBracketLayout');band=L.requiredTopPixels;
end
if band>box(4)-legendHeight-58&&~isempty(labels)
    % Tighten only the gaps before sacrificing a readable label size.
    for annotationScale=[.75 .5]
        setappdata(ax,'GA_TitrationAnnotationScale',annotationScale);gaTitration('layoutannotations',ax);
        L=getappdata(ax,'GA_TitrationBracketLayout');band=L.requiredTopPixels;
        if band<=box(4)-legendHeight-58,break;end
    end
end
dataHeight=max(50,box(4)-band-legendHeight-8);
set(ax,'Units','pixels','Position',[left box(2) chartWidth dataHeight]);
gaTitration('layoutannotations',ax);
if ~isempty(lg)&&isgraphics(lg)
    if isappdata(ax,'GA_TitrationBracketLayout')
        L=getappdata(ax,'GA_TitrationBracketLayout');band=L.requiredTopPixels;
    end
    p=get(lg,'Position');p(1)=left+chartWidth-p(3);p(2)=box(2)+dataHeight+band+6;
    set(lg,'Position',p);
end
set(ax,'Units','normalized');
setappdata(ax,'GA_TitrationLiveViewport',viewport);
end

function lg=legendFor(ax)
lg=[];
try,lg=get(ax,'Legend');catch,end
if isempty(lg)||~isgraphics(lg),lg=[];end
end
