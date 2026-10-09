function deConfUSIon_FC_layout(fig,rangeCallback)
% Persistent data/time/export controls and large coloured workspace buttons.
if ~isgraphics(fig)||~isappdata(fig,'FUSIFCLayout'),return;end
ui=getappdata(fig,'FUSIFCLayout');bg=[.08 .10 .13];fg=[.95 .95 .95];
green=[.10 .39 .29];amber=[.48 .31 .08];violet=[.35 .25 .49];cyan=[.08 .35 .40];red=[.52 .20 .24];
if ~isfield(ui,'navigation')
 ui.navigation=panel('Subject and slices');ui.timePanel=panel('Time: injection / stimulation');
 ui.displayPanel=panel('Image and labels');ui.exportPanel=panel('Save / Group Analysis');
 set(ui.dataPanel,'Parent',ui.controlPanel,'Title','Data and atlas');
 set(ui.seedPanel,'Parent',ui.controlPanel,'Title','Seed correlation');
 set(ui.roiPanel,'Parent',ui.controlPanel,'Title','Region correlation');set(ui.savePanel,'Visible','off');
 set(findall(ui.controlPanel,'Type','uicontrol'),'Visible','off');
 set(ui.subject,'Parent',ui.navigation);set(ui.sliceSlider,'Parent',ui.navigation);set(ui.sliceEdit,'Parent',ui.navigation);
 s=guidata(fig);ui.range=uicontrol(ui.navigation,'Style','edit','Tag','FCAnalysisSliceRange', ...
  'String',sprintf('%d %d',s.analysisSliceRange),'Callback',rangeCallback, ...
  'TooltipString','Inclusive analysis slices. Display slice is independent. Changing the range clears calculated FC.');
 ui.pages=[ui.seedPanel ui.roiPanel ui.displayPanel];ui.activePage=1;ui.pageButtons=gobjects(1,3);
 titles={'Seed settings','Region settings','Image / labels'};
 for k=1:3
  ui.pageButtons(k)=uicontrol(ui.controlPanel,'Style','pushbutton','String',titles{k}, ...
   'Tag',sprintf('FCSettingsPage%d',k),'Callback',@(src,event)selectPage(k),'FontWeight','bold');
 end
 placeCallbacks(ui.dataPanel,{'onLoadData','onLoadMask','onLoadAtlas','onLoadNames','onLoadUnderlay', ...
  'onUseSCMAtlasWarp','onManualAlignLabels','onOpenRegionKey','onLoadSegmentation','onAtlasLine','onMaskLine'});
 placeCallbacks(ui.timePanel,{'onEpochMode','onEpochEdit','onEpochApply'});
 placeCallbacks(ui.exportPanel,{'onExportGroupAnalysis','onSaveAll','onExportCSV'});
 placeCallbacks(ui.roiPanel,{'onRegionMode','onCustomRegionList','onClearCustomRegions','onSelectHeatmapSeed','onStrongestHeatmap'});
 placeCallbacks(ui.displayPanel,{'onUnderlayStyle','onUnderlay','onOverlay','onColorSettings','onShowHemisphere','onSliceRegionOnly', ...
  'onMatrixTickMode','onResetView','onHelp','onClose'});
 set(ui.displayControls,'Parent',ui.displayPanel);
 set(findall(fig,'Title','Display controls'),'Visible','off');
 ui.grouping=uicontrol(ui.dataPanel,'Style','popupmenu','String',{'Detailed atlas','Merged subdivisions'}, ...
  'Tag','FCAtlasGranularity','Callback',getappdata(fig,'FUSIFCRegionGrouping'));
 for pair={{'onLoadUnderlay','Histology / image'},{'onLoadNames','Region names'},{'onLoadAtlas','Region labels'},{'onExportGroupAnalysis','Export to Group'}}
  entry=pair{1};set(handles(fig,entry{1},'pushbutton'),'String',entry{2});
 end
 setappdata(fig,'FUSIFCLayout',ui);
end
set(ui.controlPanel,'Units','normalized','Position',[.008 .055 .335 .936],'BackgroundColor',bg);
set(ui.viewPanel,'Units','normalized','Position',[.35 .055 .642 .936]);
cp=getpixelposition(ui.controlPanel);w=cp(3)-18;H=cp(4)-25;gap=7;
unit=max(24,min(32,(H-40)/25));font=11;if unit>=30,font=12;end
y=H;
block(ui.navigation,2*unit+25);block(ui.dataPanel,4*unit+25);
block(ui.timePanel,4*unit+25);block(ui.exportPanel,unit+25);
navY=y-unit;
for k=1:3,put(ui.pageButtons(k),[9+(k-1)*(w+gap)/3 navY (w-2*gap)/3 unit-3]);end
y=navY-gap;
for p=ui.pages,set(p,'Units','pixels','Position',[9 6 w max(100,y-6)],'BackgroundColor',bg,'ForegroundColor',fg,'FontSize',12);end
pageColours=[green;violet;cyan];
for k=1:3,set(ui.pages(k),'Visible',onoff(k==ui.activePage));set(ui.pageButtons(k),'BackgroundColor',pageColours(k,:)*(.55+.45*(k==ui.activePage)));end
set(ui.status,'Parent',fig,'Units','normalized','Position',[.01 .006 .98 .039],'Visible','on','FontSize',11);
label(ui.navigation,'Subject',[10 2*unit-7 w*.47 17]);put(ui.subject,[10 unit-8 w*.47 unit-4]);
label(ui.navigation,'Display / analysis slices',[w*.51 2*unit-7 w*.46 17]);
put(ui.sliceSlider,[w*.51 unit-6 w*.27 unit-9]);put(ui.sliceEdit,[w*.81 unit-8 w*.15 unit-4]);
label(ui.navigation,'Calculate slices',[10 4 w*.47 17]);put(ui.range,[w*.51 3 w*.45 unit-4]);
buttons(ui.dataPanel,{'onLoadData','onLoadMask','onLoadSegmentation'},1,3);
buttons(ui.dataPanel,{'onLoadAtlas','onLoadNames','onOpenRegionKey'},2,3);
buttons(ui.dataPanel,{'onLoadUnderlay','onUseSCMAtlasWarp','onManualAlignLabels'},3,3);
put(ui.grouping,row(ui.dataPanel,4,1,3));controls(ui.dataPanel,{'onAtlasLine','onMaskLine'},4,3,2,'checkbox');
fields(ui.timePanel,{'onEpochMode','onEpochEdit'},1,3,{'Period','Start (min)','End (min)'},{'popupmenu','edit'});
fields(ui.timePanel,{'onEpochEdit'},3,3,{'Window (min)'},{'edit'},3);
controls(ui.timePanel,{'onEpochEdit'},4,3,2,'checkbox');buttonsAt(ui.timePanel,{'onEpochApply'},4,3,3);
buttons(ui.exportPanel,{'onExportGroupAnalysis','onExportCSV','onSaveAll'},1,3);
buttons(ui.seedPanel,{'onComputeSeedCurrent','onComputeSeedAll'},1,2);
fields(ui.seedPanel,{'onSeedEdit'},2,3,{'X (column)','Y (row)','Size (px)'},{'edit'});
controls(ui.seedPanel,{'onSliceOnly'},4,1,1,'checkbox');
fields(ui.seedPanel,{'onSeedDisplay','onSeedThr'},5,2,{'Map values','Threshold |r|'},{'popupmenu','edit'});
buttons(ui.seedPanel,{'onLoadScmROI'},8,1);
buttons(ui.roiPanel,{'onComputeROICurrent','onComputeROIAll','onComputePeriods'},1,3);
fields(ui.roiPanel,{'onROISpace','onROIThr'},2,2,{'Matrix values','Threshold |r|'},{'popupmenu','edit'});
fields(ui.roiPanel,{'onRegionMode','onROIOrder'},4,2,{'Hemisphere','Region order'},{'popupmenu'});
fields(ui.roiPanel,{'onCompareROI','onTopN'},6,2,{'Seed / compare region','Strongest N'},{'popupmenu','edit'});
buttons(ui.roiPanel,{'onCompareROI','onSelectHeatmapSeed','onStrongestHeatmap'},8,3);
buttons(ui.roiPanel,{'onCustomRegionList','onClearCustomRegions'},9,2);
buttons(ui.roiPanel,{'onComparePagePrev','onComparePageNext'},10,2);
fields(ui.displayPanel,{'onUnderlayStyle','onUnderlay'},1,2,{'Contrast preset','Reference image'},{'popupmenu'});
fields(ui.displayPanel,{'onUnderlayStyle'},3,2,{'Underlay gamma','Underlay sharpness'},{'edit'});
fields(ui.displayPanel,{'onOverlay','onMatrixTickMode'},5,2,{'Overlay','Heatmap labels'},{'popupmenu'});
colourFields=ui.displayControls(5:7);colourTitles={'Colour map','Seed limit','Opacity (0-1)'};
for k=1:3
 q=row(ui.displayPanel,8,k,3);put(colourFields(k),q);q(2)=q(2)+q(4)+2;q(4)=17;label(ui.displayPanel,colourTitles{k},q);
end
controls(ui.displayPanel,{'onShowHemisphere','onSliceRegionOnly'},9,2,1,'checkbox');
buttons(ui.displayPanel,{'onResetView','onHelp','onClose'},10,3);
set(findall(fig,'Style','togglebutton'),'FontSize',13,'FontWeight','bold');drawnow limitrate nocallbacks;
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
   if ~isempty(regexp(cb,'onExport|onSave','once')),colour=amber;end
   if ~isempty(regexp(cb,'onClose|onClearCustomRegions','once')),colour=red;end
   set(h,'BackgroundColor',colour,'FontWeight','bold');
  end
 end
 function label(p,str,pos)
  tag=['FCLabel_' regexprep(str,'\W','_')];h=findall(p,'Tag',tag);
  if isempty(h),h=uicontrol(p,'Style','text','Tag',tag);end
  set(h,'String',str,'Units','pixels','Position',pos,'FontSize',font,'BackgroundColor',bg,'ForegroundColor',fg,'Visible','on','HorizontalAlignment','left');
 end
 function q=row(p,r,c,n)
  pos=getpixelposition(p);step=min(unit,(pos(4)-23)/10.2);
  if any(p==[ui.dataPanel ui.timePanel ui.exportPanel]),step=unit;end
  width=(pos(3)-20-(n-1)*gap)/n;q=[10+(c-1)*(width+gap) pos(4)-23-r*step width max(16,step-4)];
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
