function varargout=gaTitrationPublication(action,varargin)
% Physical paper layouts shared by the live export preview and saved figure.
switch lower(action)
    case 'presets'
        varargout{1}=paperPresets();
    case 'render'
        varargout{1}=renderPaper(varargin{:});
    otherwise
        error('GroupAnalysis:TitrationPublicationAction','Unknown publication action: %s',action);
end
end

function presets=paperPresets()
presets=struct('name',{'Compact','Square','Wide'}, ...
    'widthMM',{85,90,140},'heightMM',{75,90,90});
end

function ax=renderPaper(parent,R,S,options)
if nargin<4,options=struct();end
if ~isgraphics(parent)||~any(strcmp(get(parent,'Type'),{'figure','uipanel'}))
    error('GroupAnalysis:TitrationPublicationParent','A figure or panel is needed for the publication preview.');
end
presets=paperPresets();index=setting(options,'preset',1);
if ischar(index)||isstring(index),index=find(strcmpi({presets.name},char(index)),1);end
if ~isnumeric(index)||~isscalar(index)||~isfinite(index)||index<1||index>numel(presets)||index~=fix(index)
    error('GroupAnalysis:TitrationPublicationPreset','Choose Compact, Square or Wide.');
end
preset=presets(index);preview=logical(setting(options,'preview',true));
dark=strcmpi(setting(options,'theme','Light'),'Dark');
bg=[1 1 1];fg=[0 0 0];if dark,bg=[0 0 0];fg=[1 1 1];end
colA=setting(options,'colA',[0 .447 .741]);colB=setting(options,'colB',[.6 .6 .6]);
% ScreenPixelsPerInch is normally 96 logical pixels. Using its actual value
% also keeps final point sizes physical at a scaled Windows display DPI.
ppi=get(groot,'ScreenPixelsPerInch');if ~isfinite(ppi)||ppi<=0,ppi=96;end
pixelsPerMM=ppi/25.4;
base=[preset.widthMM preset.heightMM]*pixelsPerMM;
viewport=getpixelposition(parent);inset=0;if preview,inset=12;end
usable=max([1 1],viewport(3:4)-2*inset);
scale=min(usable./base);if ~preview,scale=min(1,scale);end
if ~isfinite(scale)||scale<=0,error('GroupAnalysis:TitrationPublicationSize','The preview panel has no usable space.');end
paperSize=base*scale;canvasRect=[(viewport(3:4)-paperSize)/2 paperSize];
% Delete this renderer's previous canvas only. Other GUI controls and plots
% belonging to the owner are not affected when the user changes layouts.
delete(findall(parent,'Tag','GA_TitrationPaperCanvas'));
canvas=uipanel('Parent',parent,'Units','pixels','Position',canvasRect, ...
    'BorderType','none','BackgroundColor',bg,'Tag','GA_TitrationPaperCanvas');
canvasGuard=onCleanup(@()deleteIfUnfinished(canvas)); %#ok<NASGU>
w=paperSize(1);h=paperSize(2);mm=pixelsPerMM*scale;
% Use the same point size for every exported label. Preview scaling applies
% to all text together; crowded comparisons must never shrink p-values alone.
font=9;lineWidth=.8;
left=14*mm;right=5*mm;bottom=12*mm;top=3*mm;legendGap=2*mm;
dataWidth=max(20*mm,w-left-right);
initialHeight=max(20*mm,h-bottom-top);
ax=axes('Parent',canvas,'Units','pixels','Position',[left bottom dataWidth initialHeight], ...
    'Color',bg,'XColor',fg,'YColor',fg,'FontName','Arial','FontSize',font*scale, ...
    'FontWeight','normal','LineWidth',lineWidth*scale,'Box','off','Layer','top','Tag','GA_TitrationPublicationAxes');
setappdata(ax,'GA_TitrationAnnotationScale',scale);
setappdata(ax,'GA_ExportScale',scale);
plotSettings=S;
if isfield(options,'showLegend'),plotSettings.titrationShowLegend=logical(options.showLegend);end
gaTitration('plot',ax,R,plotSettings,fg,colA,colB,logical(setting(options,'showAnimalLabels',false)));
title(ax,'');
set(ax,'FontName','Arial','FontSize',font*scale,'FontWeight','normal','LineWidth',lineWidth*scale, ...
    'Box','off','TickDir','out','XColor',fg,'YColor',fg,'Color',bg,'XGrid','off','YGrid','off', ...
    'TitleFontSizeMultiplier',1,'LabelFontSizeMultiplier',1,'TitleFontWeight','normal');
set([get(ax,'XLabel') get(ax,'YLabel')],'FontName','Arial','FontSize',font*scale,'FontWeight','normal');
set(findall(ax,'Tag','GA_TitrationAnimals'),'SizeData',32*scale^2,'LineWidth',.5*scale);
set(findall(ax,'Tag','GA_TitrationMean'),'LineWidth',1.5*scale);
set(findall(ax,'Tag','GA_TitrationError'),'LineWidth',.9*scale,'CapSize',4*scale);
set(findall(ax,'Tag','GA_TitrationPair'),'LineWidth',.9*scale);
set(findall(ax,'Tag','GA_TitrationAnimalLabel'),'FontName','Arial','FontSize',font*scale,'FontWeight','normal');
labels=findall(ax,'Tag','GA_TitrationPValue');
set(labels,'FontName','Arial','FontSize',font*scale,'FontWeight','normal');
set(findall(ax,'Tag','GA_TitrationBracket'),'LineWidth',lineWidth*scale);
% A manual data-axis maximum is a hard bound. Annotation placement is
% independent of those limits and cannot expand them.
limits=ylim(ax);cfg=setting(S,'plotBot',struct('auto',true));
if ~setting(cfg,'auto',true)&&setting(cfg,'ymax',1)>setting(cfg,'ymin',0)
    lo=setting(cfg,'ymin',0);if setting(cfg,'forceZero',false),lo=0;end
    limits=[lo cfg.ymax];ylim(ax,limits);
end
legendStyle=struct('font',font,'scale',scale,'fg',fg,'width',w,'height',h, ...
    'left',left,'right',right,'top',top,'gap',legendGap,'mm',mm,'dataWidth',dataWidth);
[lg,legendBox,legendHeight]=gaPublicationLegend('measure',ax,options,legendStyle);
gaTitration('layoutannotations',ax);
required=annotationHeight(ax);maxBand=h-bottom-top-legendHeight-20*mm;
% Preserve uniform typography even for dense comparison families. Larger
% paper presets provide more annotation space without changing text sizes.
if required>maxBand
    error('GroupAnalysis:TitrationPublicationDense', ...
        'These comparison labels need more space at a readable font size. Choose Square or Wide, or select fewer comparisons.');
end
dataHeight=h-bottom-top-legendHeight-required;
dataBox=[left bottom dataWidth dataHeight];set(ax,'Position',dataBox);ylim(ax,limits);
gaTitration('layoutannotations',ax);ylim(ax,limits);
required=annotationHeight(ax);
if ~isempty(lg)
    [~,legendBox]=gaPublicationLegend('place',ax,options,legendStyle,legendBox);
end
drawnow nocallbacks;
gaExportBrackets('apply',ax,setting(options,'annotationOffsets',struct('key',{},'dx',{},'dy',{})));
gaPublicationTheme(ax,setting(options,'theme','Light'));
meta=struct('preset',index,'presetName',preset.name,'widthMM',preset.widthMM, ...
    'heightMM',preset.heightMM,'canvasPixelRect',canvasRect,'scale',scale, ...
    'pixelsPerMM',mm,'dataBox',dataBox,'annotationBandPixels',required, ...
    'legendBox',legendBox,'ylim',limits,'theme',setting(options,'theme','Light'), ...
    'preview',preview,'annotationFontPoints',font,'tickFontPoints',font, ...
    'axisLabelFontPoints',font,'minimumAnnotationFontPoints',font);
setappdata(ax,'GA_TitrationPaper',meta);setappdata(canvas,'GA_TitrationPaper',meta);
setappdata(parent,'GA_TitrationPaper',meta);setappdata(canvas,'GA_TitrationPaperComplete',true);
end

function height=annotationHeight(ax)
height=0;
if isappdata(ax,'GA_TitrationBracketLayout')
    layout=getappdata(ax,'GA_TitrationBracketLayout');
    if isfield(layout,'requiredTopPixels'),height=layout.requiredTopPixels;end
end
end

function out=setting(S,name,fallback)
out=fallback;if isstruct(S)&&isfield(S,name)&&~isempty(S.(name)),out=S.(name);end
end

function deleteIfUnfinished(canvas)
if isgraphics(canvas)&&~isappdata(canvas,'GA_TitrationPaperComplete'),delete(canvas);end
end
