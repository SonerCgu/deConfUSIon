function deConfUSIon_FC_layout(fig,rangeCallback)
% Shared scan/time controls, clearly selected pages and readable fields.
if ~isgraphics(fig)||~isappdata(fig,'FUSIFCLayout'),return;end
ui=getappdata(fig,'FUSIFCLayout');bg=[.08 .10 .13];fg=[.95 .95 .95];
green=[.10 .50 .30];amber=[.48 .31 .08];violet=[.35 .25 .49];cyan=[.08 .35 .40];red=[.72 .16 .18];blue=[.12 .36 .78];
if ~isfield(ui,'navigation')
 ui.navigation=panel('1. Scans and baseline');ui.timePanel=panel('2. Time window in each scan');
 ui.displayPanel=panel('Image and labels');ui.exportPanel=panel('Save / Group Analysis');
 set(ui.dataPanel,'Parent',ui.controlPanel,'Title','Data and atlas');
 set(ui.seedPanel,'Parent',ui.controlPanel,'Title','Seed correlation');
 set(ui.roiPanel,'Parent',ui.controlPanel,'Title','Region correlation');set(ui.savePanel,'Visible','off');
 set(findall(ui.controlPanel,'Type','uicontrol'),'Visible','off');
 set(ui.subject,'Parent',ui.navigation);set(ui.sliceSlider,'Parent',ui.navigation);set(ui.sliceEdit,'Parent',ui.navigation);
 s=guidata(fig);ui.range=uicontrol(ui.navigation,'Style','edit','Tag','FCAnalysisSliceRange', ...
  'String',sprintf('%d %d',s.analysisSliceRange),'Callback',rangeCallback, ...
  'TooltipString','Inclusive analysis slices. Display slice is independent. Changing the range clears calculated FC.');
 ui.viewport=panel('');set(ui.viewport,'BorderType','none');
 ui.pages=[ui.seedPanel ui.roiPanel ui.displayPanel ui.dataPanel];set(ui.pages,'Parent',ui.viewport);
 ui.activePage=1;ui.pageButtons=gobjects(1,4);
 titles={'Seed settings','Region settings','Image / labels','Data / atlas'};
 for k=1:4
  ui.pageButtons(k)=uicontrol(ui.controlPanel,'Style','togglebutton','String',titles{k}, ...
   'Tag',sprintf('FCSettingsPage%d',k),'Callback',@(src,event)selectPage(k),'FontWeight','bold');
 end
 ui.scrollMax=0;
 placeCallbacks(ui.dataPanel,{'onLoadData','onLoadMask','onLoadAtlas','onLoadNames','onLoadUnderlay', ...
  'onUseSCMAtlasWarp','onManualAlignLabels','onOpenRegionKey','onLoadSegmentation','onAtlasLine','onMaskLine'});
 placeCallbacks(ui.timePanel,{'onEpochMode','onEpochEdit','onEpochApply'});
 placeCallbacks(ui.navigation,{'onRegionMode','onManageScans','onBaselineSource','onResetBaseline'});
 hemi=handles(ui.navigation,'onRegionMode','popupmenu');
 for p=ui.displayPanel
  uicontrol(p,'Style','popupmenu','String',hemi.String,'Value',hemi.Value,'Tag','FCPageHemisphereMode', ...
   'Callback',hemi.Callback,'TooltipString','Shared hemisphere selection for region matrices and image labels.');
 end
 placeCallbacks(ui.exportPanel,{'onExportGroupAnalysis','onSaveAll','onExportCSV','onCompareScans','onHelp','onClose'});
 placeCallbacks(ui.roiPanel,{'onCustomRegionList','onClearCustomRegions','onSelectHeatmapSeed','onStrongestHeatmap','onROIScope','onRegionSlices'});
 placeCallbacks(ui.displayPanel,{'onUnderlayStyle','onUnderlay','onOverlay','onColorSettings','onShowHemisphere','onSliceRegionOnly','onRegionNames', ...
  'onMatrixTickMode','onResetView','onHideOverlays','onOverlaySmoothing'});
 set(ui.displayControls,'Parent',ui.displayPanel);
 set(findall(ui.savePanel,'Tag','FCPearsonLimit'),'Parent',ui.displayPanel);
 set(findall(fig,'Title','Display controls'),'Visible','off');
 ui.grouping=uicontrol(ui.dataPanel,'Style','popupmenu','String',{'Detailed subdivisions','Merge anatomical subdivisions'}, ...
  'Tag','FCAtlasGranularity','Callback',getappdata(fig,'FUSIFCRegionGrouping'));
 for pair={{'onLoadUnderlay','Histology / image'},{'onLoadNames','Region names'},{'onLoadAtlas','Region labels'},{'onExportGroupAnalysis','Export to Group'},{'onCustomRegionList','Choose regions...'},{'onClearCustomRegions','All regions'}}
  entry=pair{1};set(handles(fig,entry{1},'pushbutton'),'String',entry{2});
 end
 setappdata(fig,'FUSIFCLayout',ui);
end
key={getpixelposition(fig),ui.activePage};
if isfield(ui,'layoutKey')&&isequal(ui.layoutKey,key),return;end
ui.layoutKey=key;
set(ui.controlPanel,'Units','normalized','Position',[.008 .045 .335 .946],'BackgroundColor',bg,'Title','Analysis settings','FontSize',13);
set(ui.viewPanel,'Units','normalized','Position',[.35 .045 .642 .946]);
cp=getpixelposition(ui.controlPanel);w=cp(3)-18;H=cp(4)-25;gap=12;
unit=min(36,max(20,floor((H-142)/19)));font=12;if unit<30,font=11;end;if unit<24,font=10;end
y=H;
block(ui.navigation,4*unit+64);block(ui.timePanel,3*unit+22);
y=y-16; % Separate per-scan timing from the settings page buttons.
footerHeight=2*unit+22;
set(ui.exportPanel,'Units','pixels','Position',[9 6 w footerHeight],'Title','Save and help');
navY=y-unit;
for k=1:4,put(ui.pageButtons(k),[9+(k-1)*(w+gap)/4 navY (w-3*gap)/4 unit]);end
y=navY-gap;
viewportHeight=max(1,y-footerHeight-2*gap);
set(ui.viewport,'Units','pixels','Position',[9 footerHeight+gap w viewportHeight]);
step=min(unit,(viewportHeight-23)/8);ui.settingsStep=step;ui.scrollMax=0;
for k=1:4,set(ui.pages(k),'Units','pixels','Position',[0 0 w viewportHeight], ...
 'BackgroundColor',bg,'ForegroundColor',fg,'FontSize',12,'BorderType','none','FontWeight','bold');end
pageColours=[green;violet;cyan;amber];titles={'3. Seed FC','3. Region FC','3. Image and labels','3. Data and atlas'};
buttonTitles={'Seed FC','Regions','Image / labels','Data / atlas'};
if w<400,buttonTitles={'Seed','Regions','Image','Data / atlas'};end
for k=1:4
 set(ui.pages(k),'Visible',onoff(k==ui.activePage),'Title',titles{k});
 set(ui.pageButtons(k),'String',buttonTitles{k},'Value',double(k==ui.activePage), ...
  'BackgroundColor',[.15 .18 .23],'ForegroundColor',[.73 .76 .80],'FontWeight','normal', ...
  'TooltipString',['Switch to ' titles{k} '. Scan, hemisphere, time and export controls remain visible.']);
 if k==ui.activePage,set(ui.pageButtons(k),'String',buttonTitles{k}, ...
  'BackgroundColor',pageColours(k,:),'ForegroundColor','w','FontWeight','bold');end
end
setappdata(fig,'FUSIFCLayout',ui);
set(ui.status,'Parent',fig,'Units','normalized','Position',[.01 .006 .98 .039],'Visible','on','FontSize',11);
pos=getpixelposition(ui.navigation);top=pos(4);
set(findall(ui.navigation,'Tag','FCLabel_Selected_scan'),'Visible','off');
scanY=3*unit+44;captionY=3*unit+14;sliceY=2*unit+14;hemiY=unit+10;
put(ui.subject,[10 scanY w*.64 unit-4]);put(handles(ui.navigation,'onManageScans','pushbutton'),[w*.68 scanY w*.29 unit-4]);
label(ui.navigation,'Display slice',[10 captionY w*.47 22]);label(ui.navigation,'Calculate slices',[w*.51 captionY w*.46 22]);
put(ui.sliceSlider,[10 sliceY+2 w*.31 unit-7]);put(ui.sliceEdit,[w*.34 sliceY w*.13 unit-4]);
put(ui.range,[w*.51 sliceY w*.45 unit-4]);
label(ui.navigation,'Hemisphere',[10 hemiY w*.25 unit-4]);
put(handles(ui.navigation,'onRegionMode','popupmenu'),[w*.28 hemiY w*.69 unit-4]);
set(handles(ui.navigation,'onRegionMode','popupmenu'),'Tag','FCHemisphereMode');
put(handles(ui.navigation,'onBaselineSource','pushbutton'),[10 6 w*.63 unit-4]);
put(handles(ui.navigation,'onResetBaseline','pushbutton'),[w*.67 6 w*.30 unit-4]);
timeFields=[handles(ui.timePanel,'onEpochMode','popupmenu') handles(ui.timePanel,'onEpochEdit','edit')];
timeTitles={'Period','Start (min)','End (min)'};
for k=1:3,q=fixedRow(ui.timePanel,2,k,3);put(timeFields(k),q);q(2)=q(2)+q(4)+2;q(4)=17;label(ui.timePanel,timeTitles{k},q);end
inline(timeFields(4),'Win min',fixedRow(ui.timePanel,3,1,3));
put(handles(ui.timePanel,'onEpochEdit','checkbox'),fixedRow(ui.timePanel,3,2,3));put(handles(ui.timePanel,'onEpochApply','pushbutton'),fixedRow(ui.timePanel,3,3,3));
buttons(ui.exportPanel,{'onExportGroupAnalysis','onExportCSV','onSaveAll'},1,3);
buttons(ui.exportPanel,{'onCompareScans','onHelp','onClose'},2,3);
buttons(ui.seedPanel,{'onComputeSeedCurrent','onComputeSeedAll'},1,2);
hs=handles(ui.seedPanel,'onSeedEdit','edit');names={'X (column)','Y (row)','Size (px)'};
for k=1:3,q=row(ui.seedPanel,3,k,3);put(hs(k),q);q(2)=q(2)+q(4)+2;q(4)=17;label(ui.seedPanel,names{k},q);end
controls(ui.seedPanel,{'onSeedSizePreset'},4,3,1,'popupmenu');controls(ui.seedPanel,{'onSeedSmaller','onSeedLarger'},4,3,2,'pushbutton');
controls(ui.seedPanel,{'onSliceOnly','onSeedRegionMode'},5,2,1,'checkbox');
inline(handles(ui.seedPanel,'onSeedDisplay','popupmenu'),'Values',row(ui.seedPanel,6,1,2));
inline(handles(ui.seedPanel,'onSeedThr','edit'),'Min |r|',row(ui.seedPanel,6,2,2));
inline(findall(ui.seedPanel,'Tag','FCPearsonLimit'),'Colour +/-r',row(ui.seedPanel,7,1,2));
put(findall(ui.seedPanel,'Tag','FCColourMap'),row(ui.seedPanel,7,2,2));buttons(ui.seedPanel,{'onLoadScmROI'},8,1);
inline(findall(ui.roiPanel,'Tag','FCROIScope'),'ROIs',row(ui.roiPanel,1,1,2));
buttons(ui.roiPanel,{'onRegionSlices'},1,2);put(findall(ui.roiPanel,'Tag','FCRegionSlices'),row(ui.roiPanel,1,2,2));
buttons(ui.roiPanel,{'onComputeROICurrent','onComputeROIAll','onComputePeriods'},2,3);
inline(handles(ui.roiPanel,'onROISpace','popupmenu'),'Values',row(ui.roiPanel,3,1,2));
inline(handles(ui.roiPanel,'onROIThr','edit'),'Min |r|',row(ui.roiPanel,3,2,2));
inline(handles(ui.roiPanel,'onROIOrder','popupmenu'),'Sort',row(ui.roiPanel,4,1,2));
inline(findall(ui.roiPanel,'Tag','FCPearsonLimit'),'Colour +/-r',row(ui.roiPanel,4,2,2));
inline(handles(ui.roiPanel,'onCompareROI','popupmenu'),'Seed region',row(ui.roiPanel,5,1,1));
buttons(ui.roiPanel,{'onSelectHeatmapSeed','onStrongestHeatmap','onCompareROI'},6,3);
buttons(ui.roiPanel,{'onCustomRegionList','onClearCustomRegions'},7,2);
controls(ui.roiPanel,{'onComparePagePrev','onComparePageNext'},8,3,1,'pushbutton');inline(handles(ui.roiPanel,'onTopN','edit'),'Top N',row(ui.roiPanel,8,3,3));
set(findall(ui.displayPanel,'Tag','FCPageHemisphereMode'),'Visible','off');
put(findall(ui.displayPanel,'Tag','FCOverlaySmooth'),row(ui.displayPanel,1,1,2));
inline(findall(ui.displayPanel,'Tag','FCOverlaySigma'),'Sigma (px)',row(ui.displayPanel,1,2,2));
inline(handles(ui.displayPanel,'onUnderlayStyle','popupmenu'),'Contrast',row(ui.displayPanel,2,1,2));
inline(handles(ui.displayPanel,'onUnderlay','popupmenu'),'Underlay',row(ui.displayPanel,2,2,2));
hs=handles(ui.displayPanel,'onUnderlayStyle','edit');inline(hs(1),'Gamma',row(ui.displayPanel,3,1,2));inline(hs(2),'Sharpness',row(ui.displayPanel,3,2,2));
inline(handles(ui.displayPanel,'onOverlay','popupmenu'),'Overlay',row(ui.displayPanel,4,1,1));
put(ui.displayControls(5),row(ui.displayPanel,5,1,2));inline(findall(ui.displayPanel,'Tag','FCPearsonLimit'),'Colour +/-r',row(ui.displayPanel,5,2,2));
inline(ui.displayControls(7),'Opacity',row(ui.displayPanel,6,1,3));inline(ui.displayControls(6),'Z limit',row(ui.displayPanel,6,2,3));
put(handles(ui.displayPanel,'onMatrixTickMode','popupmenu'),row(ui.displayPanel,6,3,3));
controls(ui.displayPanel,{'onShowHemisphere','onSliceRegionOnly','onRegionNames'},7,3,1,'checkbox');
buttons(ui.displayPanel,{'onHideOverlays','onResetView'},8,2);
buttons(ui.dataPanel,{'onLoadData','onLoadMask','onLoadSegmentation'},1,3);
buttons(ui.dataPanel,{'onLoadAtlas','onLoadNames','onOpenRegionKey'},2,3);
buttons(ui.dataPanel,{'onLoadUnderlay','onUseSCMAtlasWarp','onManualAlignLabels'},3,3);
inline(ui.grouping,'Anatomy',row(ui.dataPanel,4,1,1));controls(ui.dataPanel,{'onAtlasLine','onMaskLine'},5,2,1,'checkbox');
inline(findall(ui.dataPanel,'Tag','FCMaskPolicy'),'Tissue',row(ui.dataPanel,6,1,1));
inline(findall(ui.dataPanel,'Tag','FCAnalysedTR'),'Analysed TR (s)',row(ui.dataPanel,7,1,1));
q=row(ui.dataPanel,8,1,1);put(findall(ui.dataPanel,'Tag','FCMaskSource'),q);
if isfield(ui,'viewButtons')
 for k=1:numel(ui.viewButtons),set(ui.viewButtons(k),'Units','normalized','Position',[.02+(k-1)*.163 .925 .15 .05],'FontSize',12,'FontWeight','bold');end
end
mainButtons=setdiff(findall(fig,'Style','togglebutton'),ui.pageButtons);
set(mainButtons,'FontSize',max(11,font),'FontWeight','bold');
set(findall(fig,'Tag','FCPaperFigure'),'BackgroundColor',green,'ForegroundColor','w');
graphText=findall(fig,'Tag','FCGraphExplanation');
if ~isempty(graphText)&&isappdata(graphText,'FUSIFCGraphText')
 set(graphText,'String',textwrap(graphText,getappdata(graphText,'FUSIFCGraphText')));
end
drawnow limitrate nocallbacks;
 function p=panel(title)
  p=uipanel(ui.controlPanel,'Title',title,'BackgroundColor',bg,'ForegroundColor',fg,'FontSize',12);
 end
 function selectPage(k)
  u=getappdata(fig,'FUSIFCLayout');u.activePage=k;setappdata(fig,'FUSIFCLayout',u);deConfUSIon_FC_layout(fig);
 end
 function block(p,height)
  y=y-height;set(p,'Units','pixels','Position',[9 y w height],'BackgroundColor',bg,'ForegroundColor',fg,'FontSize',12);y=y-gap;
 end
 function put(h,pos)
  if isempty(h),return;end
  set(h,'Units','pixels','Position',pos,'Visible','on','FontSize',font,'FontName','Arial', ...
   'BackgroundColor',[.13 .17 .22],'ForegroundColor',fg);
  if strcmp(h.Style,'pushbutton')
   colour=[.23 .28 .34];cb='';if isa(h.Callback,'function_handle'),cb=func2str(h.Callback);end
   if h.Parent==ui.dataPanel,colour=violet;end
   if h.Parent==ui.displayPanel,colour=cyan;end
   if ~isempty(regexp(cb,'onCompute|onEpochApply|onCompareROI','once')),colour=green;end
   if ~isempty(regexp(cb,'onExport|onSave','once')),colour=green;end
   if ~isempty(regexp(cb,'onHelp','once'))||strcmpi(h.String,'Help'),colour=blue;end
   if ~isempty(regexp(cb,'onClose|onClearCustomRegions|onResetBaseline','once')),colour=red;end
   if ~isempty(regexp(cb,'onManageScans|onBaselineSource|onRegionSlices','once')),colour=blue;end
   set(h,'BackgroundColor',colour,'FontWeight','bold');
  end
 end
 function h=label(p,str,pos)
  tag=['FCLabel_' regexprep(str,'\W','_')];h=findall(p,'Tag',tag);
  if isempty(h),h=uicontrol(p,'Style','text','Tag',tag);end
  set(h,'String',str,'Units','pixels','Position',pos,'FontSize',font,'FontName','Arial','BackgroundColor',bg,'ForegroundColor',fg,'Visible','on','HorizontalAlignment','left');
 end
 function q=row(p,r,c,n)
  pos=getpixelposition(p);stride=step;if p==ui.exportPanel,stride=unit;end
  width=(pos(3)-20-(n-1)*gap)/n;q=[10+(c-1)*(width+gap) pos(4)-23-r*stride width max(16,stride-6)];
  if p==ui.exportPanel,q(2)=pos(4)-19-r*unit;q(4)=unit-4;end
 end
 function q=fixedRow(p,r,c,n)
  pos=getpixelposition(p);width=(pos(3)-20-(n-1)*gap)/n;q=[10+(c-1)*(width+gap) pos(4)-19-r*unit width unit-4];
 end
 function inline(h,title,q)
  if isempty(h),return;end
  caption=label(h(1).Parent,title,q);extent=caption.Extent;
  lw=min(q(3)*.65,max(36,extent(3)+6));set(caption,'Position',[q(1) q(2) lw q(4)]);
  q(1)=q(1)+lw+4;q(3)=q(3)-lw-4;put(h,q);
 end
 function hemiField(p)
  q=row(p,2,1,1);put(findall(p,'Tag','FCPageHemisphereMode'),q);q(2)=q(2)+q(4)+2;q(4)=17;label(p,'Hemisphere for regions / labels',q);
 end
 function hh=handles(p,name,style)
  hh=gobjects(0);all=flip(findall(p,'Type','uicontrol'));
  for h=reshape(all,1,[])
   cb=h.Callback;if isa(cb,'function_handle')&&~isempty(regexp(func2str(cb),['(?<!\w)' name '(?!\w)'],'once'))&& ...
    (isempty(style)||strcmp(h.Style,style)),hh(end+1)=h;end %#ok<AGROW>
  end
  if isempty(hh)&&strcmp(name,'onHelp'),hh=findall(p,'Style','pushbutton','String','Help');end
 end
 function placeCallbacks(p,names)
  for j=1:numel(names),set(handles(fig,names{j},''),'Parent',p);end
 end
 function buttons(p,names,r,n),buttonsAt(p,names,r,n,1);end
 function buttonsAt(p,names,r,n,start),controls(p,names,r,n,start,'pushbutton');end
 function controls(p,names,r,n,start,style)
  for j=1:numel(names),hs=handles(p,names{j},style);if ~isempty(hs),put(hs(1),row(p,r,j+start-1,n));end,end
 end
 function fields(p,names,r,n,titles,styles,skip)
  if nargin<7,skip=0;end
  hs=gobjects(0);
  for j=1:numel(names),style=styles{min(j,numel(styles))};hs=[hs handles(p,names{j},style)];end %#ok<AGROW>
  hs=hs(arrayfun(@(h)any(strcmp(h.Style,{'edit','popupmenu'})),hs));
  if skip>0,hs=hs(skip:end);end
  for j=1:min(numel(titles),numel(hs))
   q=row(p,r+1,j,n);put(hs(j),q);q(2)=q(2)+q(4)+2;q(4)=17;label(p,titles{j},q);
  end
 end
end
function s=onoff(b),s='off';if b,s='on';end,end
