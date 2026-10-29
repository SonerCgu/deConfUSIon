function varargout=gaGroupPublication(action,varargin)
% Physical paper layouts for ordinary Group Analysis export previews/files.
switch lower(action)
    case 'presets'
        varargout{1}=gaTitrationPublication('presets');
    case 'render'
        varargout{1}=renderPaper(varargin{:});
    otherwise
        error('GroupAnalysis:GroupPublicationAction','Unknown publication action: %s',action);
end
end

function ax=renderPaper(parent,renderFcn,options)
if nargin<3,options=struct();end
if ~isgraphics(parent)||~any(strcmp(get(parent,'Type'),{'figure','uipanel'}))
    error('GroupAnalysis:GroupPublicationParent','A figure or panel is needed for the publication preview.');
end
if ~isa(renderFcn,'function_handle')
    error('GroupAnalysis:GroupPublicationRenderer','An axes rendering function is needed.');
end
presets=gaGroupPublication('presets');index=setting(options,'preset',1);
if ischar(index)||isstring(index),index=find(strcmpi({presets.name},char(index)),1);end
if ~isnumeric(index)||~isscalar(index)||~isfinite(index)||index<1||index>numel(presets)||index~=fix(index)
    error('GroupAnalysis:GroupPublicationPreset','Choose Compact, Square or Wide.');
end
preset=presets(index);preview=logical(setting(options,'preview',true));
theme=setting(options,'theme','Light');bg=[1 1 1];fg=[0 0 0];
if strcmpi(theme,'Dark'),bg=[0 0 0];fg=[1 1 1];end
ppi=get(groot,'ScreenPixelsPerInch');if ~isfinite(ppi)||ppi<=0,ppi=96;end
pixelsPerMM=ppi/25.4;base=[preset.widthMM preset.heightMM]*pixelsPerMM;
viewport=getpixelposition(parent);inset=0;if preview,inset=12;end
usable=max([1 1],viewport(3:4)-2*inset);scale=min(usable./base);
if ~preview,scale=min(1,scale);end
if ~isfinite(scale)||scale<=0
    error('GroupAnalysis:GroupPublicationSize','The preview panel has no usable space.');
end
paperSize=base*scale;canvasRect=[(viewport(3:4)-paperSize)/2 paperSize];
delete(findall(parent,'Tag','GA_TitrationPaperCanvas'));
canvas=uipanel('Parent',parent,'Units','pixels','Position',canvasRect, ...
    'BorderType','none','BackgroundColor',bg,'Tag','GA_TitrationPaperCanvas');
guard=onCleanup(@()deleteIfUnfinished(canvas)); %#ok<NASGU>
w=paperSize(1);h=paperSize(2);mm=pixelsPerMM*scale;font=9;lineWidth=.8;
left=14*mm;right=5*mm;bottom=12*mm;top=3*mm;gap=2*mm;
ax=axes('Parent',canvas,'Units','pixels','Position',[left bottom w-left-right h-bottom-top]);
renderFcn(ax,theme);
% The original renderer supplies the numerical values, selected axis limits,
% colours and comparison text. This wrapper changes only their presentation.
limits=ylim(ax);xLimits=xlim(ax);
set(ax,'Units','pixels','FontUnits','points','FontName','Arial','FontSize',font*scale, ...
    'FontWeight','normal','LineWidth',lineWidth*scale,'Color',bg, ...
    'XColor',fg,'YColor',fg,'Box','off','TickDir','out','Layer','top', ...
    'TitleFontSizeMultiplier',1,'LabelFontSizeMultiplier',1,'TitleFontWeight','normal', ...
    'Tag','GA_TitrationPublicationAxes','XLim',xLimits,'YLim',limits);
setappdata(ax,'GA_ExportScale',scale);
% GUI markers are deliberately larger. Use physical paper sizes here, and
% scale both area and line width so the preview matches the saved figure.
set(findall(ax,'Tag','GA_ROI_Animals'),'SizeData',32*scale^2,'LineWidth',.5*scale);
set(findall(ax,'Tag','GA_ROI_Mean'),'LineWidth',1.5*scale);
pairs=findall(ax,'Tag','GA_ROI_ANIMAL_PAIR');
for pair=pairs(:)',set(pair,'LineWidth',get(pair,'LineWidth')*scale);end
texts=findall(ax,'Type','text');
set(texts,'FontUnits','points','FontName','Arial','FontSize',font*scale,'FontWeight','normal');
labels=findall(ax,'Tag','GA_ROI_PLabel');brackets=findall(ax,'Tag','GA_ROI_PBracket');
set(brackets,'LineWidth',lineWidth*scale,'Clipping','off');
set(labels,'Clipping','off');
drawnow nocallbacks;
% Reserve enough space for actual tick strings and selected axis names.
% This includes rotated or longer group names in ordinary group plots.
tight=get(ax,'TightInset');
left=max(left,tight(1)+2*mm);bottom=max(bottom,tight(2)+2*mm);
right=max(right,tight(3)+2*mm);dataWidth=w-left-right;
if dataWidth<20*mm
    error('GroupAnalysis:GroupPublicationDense','These axis labels need more space. Choose Square or Wide.');
end
legendStyle=struct('font',font,'scale',scale,'fg',fg,'width',w,'height',h, ...
    'left',left,'right',right,'top',top,'gap',gap,'mm',mm,'dataWidth',dataWidth);
[lg,legendBox,legendHeight]=gaPublicationLegend('measure',ax,options,legendStyle);
titleHandle=get(ax,'Title');titleHeight=0;
if hasText(get(titleHandle,'String'))
    set(titleHandle,'Units','pixels');box=get(titleHandle,'Extent');titleHeight=box(4)+gap;
end
% A separate annotation band keeps brackets away from points and keeps a
% manual y-axis maximum exact. No extra range is added to the measured data.
required=summaryHeight(labels,brackets,scale,mm);
dataHeight=h-bottom-top-legendHeight-titleHeight-required;
if dataHeight<20*mm
    error('GroupAnalysis:GroupPublicationDense','These labels need more space. Choose Square or Wide.');
end
dataBox=[left bottom dataWidth dataHeight];set(ax,'Position',dataBox,'XLim',xLimits,'YLim',limits);
positionSummary(ax,labels,brackets,scale,mm);
if titleHeight>0
    set(titleHandle,'Units','pixels','Position',[dataWidth/2 dataHeight+required+gap 0], ...
        'HorizontalAlignment','center','VerticalAlignment','bottom');
end
if ~isempty(legendBox)
    [~,legendBox]=gaPublicationLegend('place',ax,options,legendStyle,legendBox);
end
drawnow nocallbacks;
gaExportBrackets('apply',ax,setting(options,'annotationOffsets',struct('key',{},'dx',{},'dy',{})));
gaPublicationTheme(ax,theme);
meta=struct('preset',index,'presetName',preset.name,'widthMM',preset.widthMM, ...
    'heightMM',preset.heightMM,'canvasPixelRect',canvasRect,'scale',scale, ...
    'pixelsPerMM',mm,'dataBox',dataBox,'annotationBandPixels',required, ...
    'legendBox',legendBox,'ylim',limits,'theme',theme,'preview',preview, ...
    'annotationFontPoints',font,'tickFontPoints',font,'axisLabelFontPoints',font, ...
    'minimumAnnotationFontPoints',font,'plotKind','Groups');
setappdata(ax,'GA_TitrationPaper',meta);setappdata(canvas,'GA_TitrationPaper',meta);
setappdata(parent,'GA_TitrationPaper',meta);setappdata(canvas,'GA_TitrationPaperComplete',true);
end

function height=summaryHeight(labels,brackets,scale,mm)
height=0;if isempty(labels)&&isempty(brackets),return;end
textHeight=0;
for label=labels(:)'
    units=get(label,'Units');set(label,'Units','pixels');box=get(label,'Extent');set(label,'Units',units);
    textHeight=max(textHeight,box(4));
end
cap=3*scale;if isempty(brackets),cap=0;end
height=ceil(2*mm+cap+2*scale+textHeight+mm);
end

function positionSummary(ax,labels,brackets,scale,mm)
box=getpixelposition(ax);height=box(4);width=box(3);cap=3*scale;
if isempty(brackets),cap=0;end
above=2*mm+cap;
limits=ylim(ax);
for bracket=brackets(:)'
    y=get(bracket,'YData');normalized=1+above/height;
    shape=zeros(size(y));if numel(shape)>=4,shape([1 end])=-3*scale/height;end
    set(bracket,'YData',fromNormalized(normalized+shape,limits,get(ax,'YScale')));
end
for label=labels(:)'
    set(label,'Units','normalized');pos=get(label,'Position');
    pos(2)=1+(above+2*scale)/height;set(label,'Position',pos);
    extent=get(label,'Extent');half=extent(3)/2;
    if extent(3)*width>width+10*mm
        error('GroupAnalysis:GroupPublicationDense','The statistical label needs more space. Choose Square or Wide.');
    end
    pos(1)=min(1-half,max(half,pos(1)));set(label,'Position',pos);
end
end

function value=fromNormalized(value,limits,axisScale)
if strcmpi(axisScale,'log'),limits=log10(limits);end
value=limits(1)+value*diff(limits);
if strcmpi(axisScale,'log'),value=10.^value;end
end

function out=setting(S,name,fallback)
out=fallback;if isstruct(S)&&isfield(S,name)&&~isempty(S.(name)),out=S.(name);end
end

function tf=hasText(value)
if iscell(value),tf=any(cellfun(@hasText,value));else,tf=~isempty(strtrim(char(value)));end
end

function deleteIfUnfinished(canvas)
if isgraphics(canvas)&&~isappdata(canvas,'GA_TitrationPaperComplete'),delete(canvas);end
end
