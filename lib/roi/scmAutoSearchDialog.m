function opt=scmAutoSearchDialog(ctx)
% Anatomy-only editor. Drawing never blocks callbacks or waits for extra clicks.
opt=[]; nz=ctx.sizeYXZ(3); ny=ctx.sizeYXZ(1); nx=ctx.sizeYXZ(2); z=ctx.slice;
accepted=false; armed=false; dragging=false; anchor=[]; rubber=[];
paintedMask=[]; painting=false; eraseStroke=false; lastPoint=[];strokeRadius=8;
hAnatomy=[];hShade=[];underlaySlice=NaN;baseIncluded=true(ny,nx);lastPaintDraw=tic;
anatomyX=[1 nx];anatomyY=[1 ny];
if isfield(ctx,'underlayXData'),anatomyX=ctx.underlayXData;end
if isfield(ctx,'underlayYData'),anatomyY=ctx.underlayYData;end
mouseButtonsAvailable=false;
if ispc
    try,NET.addAssembly('System.Windows.Forms');mouseButtonsAvailable=true;catch,end
end
f=figure('Name','Automatic SCM | time and anatomical search regions','NumberTitle','off', ...
    'MenuBar','none','ToolBar','none','Position',[80 60 1300 850],'Color','k','WindowStyle','modal','Pointer','crosshair');
setappdata(f,'deConfUSIonNoMaximize',true);
ax=axes('Parent',f,'Units','normalized','Position',[.47 .365 .50 .33],'Tag','SearchAnatomyAxes');
pWhich=control('popupmenu',[.47 .94 .50 .045], ...
    {'Mark Target and Control','Mark Target only','Mark Control only'},@preview);
set(pWhich,'Tag','SearchROISelection','TooltipString', ...
    'Choose which ROIs to search and mark. The side setting below defines Target and Control.');
set(pWhich,'Visible','off');
cbTarget=control('checkbox',[.47 .94 .24 .045],'Search Target',@roleTicks);
cbControl=control('checkbox',[.73 .94 .24 .045],'Search Control',@roleTicks);
set(cbTarget,'Tag','SearchTargetEnabled','Value',1);set(cbControl,'Tag','SearchControlEnabled','Value',1);
set(pWhich,'Callback',@rolePopup);
cbBrush=control('checkbox',[.47 .88 .27 .04],'Brush enabled',@brushMode);
set(cbBrush,'Tag','SearchBrushMode','Value',1);
control('text',[.75 .88 .13 .04],'Radius (pixels)',[]);
eBrush=control('edit',[.88 .88 .09 .04],'8',[]);set(eBrush,'Tag','SearchBrushRadius');
btEmpty=control('pushbutton',[.47 .825 .24 .04],'Clear painted area',@(~,~)fillPaint(false));set(btEmpty,'Tag','SearchPaintClear');
btFill=control('pushbutton',[.73 .825 .24 .04],'Fill painted area',@(~,~)fillPaint(true));set(btFill,'Tag','SearchPaintFill');
catalog=struct('id',{},'acronym',{},'name',{},'displayName',{},'voxelCount',{});excluded=[];
hasAtlas=isfield(ctx,'atlasLabels')&&~isempty(ctx.atlasLabels)&&isfield(ctx,'atlasRegionInfo');
if hasAtlas,[catalog,excluded]=fusiAtlasRegionCatalog(ctx.atlasLabels,ctx.atlasRegionInfo);end
selectedAtlasRegions=catalog([]);
pAtlas=control('popupmenu',[.47 .765 .335 .04],[{'Atlas: all labelled brain tissue'} {catalog.displayName}],@atlasRegionChanged);
set(pAtlas,'Tag','SearchAtlasRegion','TooltipString','Choose one region here, or use Choose regions to tick several. Each region is searched separately.');
btRegions=control('pushbutton',[.815 .765 .155 .04],'Choose regions...',@chooseAtlasRegions);set(btRegions,'Tag','SearchChooseAtlasRegions','FontSize',10);
control('text',[.47 .717 .36 .03],'Minimum ROI in selected region (%)',[]);
eCoverage=control('edit',[.84 .715 .13 .04],'75',@preview);set(eCoverage,'Tag','SearchAtlasCoverage');
set(eCoverage,'TooltipString','75-100%. Remaining pixels may be in neighbouring labelled brain tissue. Every pixel must avoid ventricles, fit the painted area and selected side, and have valid acquired samples. The uploaded SCM mask is ignored.');
if ~hasAtlas
 set(pAtlas,'String',{'Atlas: load a registered Regions underlay first'},'Enable','off');set([eCoverage btRegions],'Enable','off');
end
control('text',[.47 .26 .29 .04],'Top per role / region (0 = all slices)',[]);
control('text',[.77 .295 .08 .025],'Target',[]);
control('text',[.88 .295 .08 .025],'Control',[]);
eTopTarget=control('edit',[.77 .255 .08 .04],'0',[]);set(eTopTarget,'Tag','SearchTopTarget');
eTopControl=control('edit',[.88 .255 .08 .04],'0',[]);set(eTopControl,'Tag','SearchTopControl');
set([eTopTarget eTopControl],'TooltipString','Keep N per role AND selected atlas region, one ROI per slice; 0 keeps every candidate. Each selected region retains its own results. Selected maxima are exploratory.');
if nz==1,set([eTopTarget eTopControl],'Enable','off');end
timingText=control('text',[.025 .94 .425 .035],'',[]);
set(timingText,'HorizontalAlignment','left','Tag','SearchScanTiming');
pScan=[];
if isfield(ctx,'scanLabels')&&~isempty(ctx.scanLabels)
    pScan=control('popupmenu',[.025 .903 .405 .034],[{'Originally loaded scan (Load fUSI Data selection)','All loaded scans: strongest ROI per region/role/slice'} ctx.scanLabels],@updateScanTiming);
    set(pScan,'Tag','SearchScanScope','FontSize',10,'Value',1,'TooltipString','Default is the dataset that opened this SCM. Search times apply separately within each chosen scan; switching the overlay does not change this default.');
end
eSize=editrow(.86,'',num2str(ctx.roiSize),'SearchROISize');
pROIMode=control('popupmenu',[.025 .86 .235 .045],{'ROI: square pixels','ROI: X/Y micrometres','ROI: whole atlas region'},@roiModeChanged);
set(pROIMode,'Tag','SearchROIMode');
eWidth=control('edit',[.27 .86 .075 .045],'1000',@preview);set(eWidth,'Tag','SearchROIWidthUm','TooltipString','X: horizontal width (um)','Visible','off');
eHeight=control('edit',[.355 .86 .075 .045],'1000',@preview);set(eHeight,'Tag','SearchROIHeightUm','TooltipString','Y: vertical height (um)','Visible','off');
sizeInfo=control('text',[.025 .82 .405 .032],'',[]);set(sizeInfo,'Tag','SearchROIPhysicalSize','HorizontalAlignment','left','FontSize',10);
if ~isfield(ctx,'spacingUm'),ctx.spacingUm=[NaN NaN NaN];end
if isfield(ctx,'sizeUm'),set(eWidth,'String',num2str(ctx.sizeUm(1)));set(eHeight,'String',num2str(ctx.sizeUm(2)));end
if isfield(ctx,'sizeMode')&&strcmp(ctx.sizeMode,'um'),set(pROIMode,'Value',2);end
set(eSize,'Callback',@preview);
eTime=editrow(.79,'Search start/end (min per scan)',sprintf('%.9g %.9g',ctx.signalSec/60),'SearchTime');
set(eTime,'TooltipString','Times start at zero in each selected scan. 7 14 searches minutes 7-14 separately in every selected scan, irrespective of stitched plot order. Shorter scans are skipped, not truncated.');
label(.755,'7 14 = minutes 7-14 within EACH selected scan.');
duration=0; if isfield(ctx,'plateauSec'), duration=ctx.plateauSec/60; end
eDuration=editrow(.72,'Plateau duration (minutes)', num2str(duration),'SearchPlateau');
label(.66,'0 = whole interval. E.g. 5 15 with duration 2 searches');
label(.63,'every 2-minute window between 5 and 15 minutes.');
eBounds=editrow(.56,'X start/end, Y start/end',sprintf('1 %d 1 %d',nx,ny),'SearchBounds');
set(eBounds,'Callback',@preview);
button(.49,'Draw rectangle: click and drag on image',@arm);
button(.43,'Reset search rectangle to full image',@reset);
cbBoth=control('checkbox',[.025 .36 .41 .04],'Separate left/right target and control',@preview);
set(cbBoth,'Value',1);
eSplit=editrow(.30,'Left/right boundary (X)',num2str(floor(nx/2)),'SearchSplit'); set(eSplit,'Callback',@preview);
label(.24,'Target side (as displayed in the image):');
pRole=control('popupmenu',[.025 .19 .405 .045],{'LEFT = Target / RIGHT = Control','RIGHT = Target / LEFT = Control'},@preview);
set(pRole,'Tag','SearchTargetSide');
cbAll=control('checkbox',[.025 .125 .24 .04],'Slice range: from / to',@rangeMode); set(cbAll,'Value',double(nz>1),'Tag','SearchSliceRangeEnabled');
eFirst=control('edit',[.27 .125 .07 .045],'1',@preview);set(eFirst,'Tag','SearchSliceStart');
eLast=control('edit',[.36 .125 .07 .045],num2str(nz),@preview);set(eLast,'Tag','SearchSliceEnd');
set(cbAll,'TooltipString','Checked: search the inclusive slice range. Unchecked: search only the previewed slice.');
if nz==1, set([cbAll eFirst eLast],'Enable','off'); end
pDisplay=control('popupmenu',[.025 .075 .405 .045], ...
    {'Display: keep current','Display: shared limits across animals','Display: automatic per animal (99th percentile)'},[]);
set(pDisplay,'Tag','SearchDisplayMode','Value',1,'TooltipString', ...
    'Shared limits support direct animal comparisons. Automatic contrast uses the same rule but different numbers; neither changes ROI measurements.');
sharedDisplay=scmSharedDisplay();
control('pushbutton',[.47 .12 .50 .04],'Remember current SCM limits for all animals',@rememberDisplay);
pWindow=control('popupmenu',[.025 .015 .405 .045], ...
    {'Different best window per ROI / slice','Same best window across scans / slices'},[]);
set(pWindow,'Tag','SearchWindowMode','Value',1);
set(pWindow,'TooltipString','A shared window uses the same minutes within each scan, never the concatenated plot timeline.');
sliceText=control('text',[.48 .22 .48 .035],'',[]);
sl=control('slider',[.49 .18 .46 .025],'',@changeSlice);
set(sl,'Min',1,'Max',max(2,nz),'Value',z,'SliderStep',[1/max(1,nz-1) min(1,5/max(1,nz-1))],'Tag','SearchSlice');
if nz==1, set(sl,'Enable','off'); end
status=control('text',[.47 .065 .50 .05],'Brush ready: paint with left-drag, erase with right-drag. Your mask applies to all slices.',[]);
set(status,'HorizontalAlignment','left','Tag','SearchStatus');
if hasAtlas
    set(status,'String','Atlas search ignores the uploaded SCM mask. Brush: left-drag adds, right-drag erases (all slices).');
end
go=control('pushbutton',[.47 .015 .31 .05],'GO / Start analysis',@accept);
set(go,'BackgroundColor',[.05 .4 .24],'FontWeight','bold','Tag','SearchGo');
control('pushbutton',[.80 .015 .17 .05],'Cancel',@(~,~)delete(f));
set(f,'WindowScrollWheelFcn',@scroll,'WindowButtonDownFcn',@mouseDown, ...
    'WindowButtonMotionFcn',@mouseMove,'WindowButtonUpFcn',@mouseUp,'WindowKeyPressFcn',@key, ...
    'Interruptible','off','BusyAction','queue');
roiModeChanged(); updateScanTiming(); setappdata(f,'SCMSearchDialogReady',true); uiwait(f);
if isgraphics(f), if accepted, opt=collect(); end; delete(f); end

    function h=control(style,pos,str,cb)
        bg=[.12 .12 .12]; if any(strcmp(style,{'text','checkbox'})), bg=[0 0 0]; end
        h=uicontrol(f,'Style',style,'Units','normalized','Position',pos,'String',str, ...
            'BackgroundColor',bg,'ForegroundColor','w','FontSize',12,'Callback',cb);
        setappdata(h,'PreserveColors',true);
    end
    function label(y,str)
        h=control('text',[.025 y .425 .035],str,[]); set(h,'HorizontalAlignment','left');
    end
    function h=editrow(y,str,value,tag)
        h=control('text',[.025 y .235 .04],str,[]); set(h,'HorizontalAlignment','left');
        h=control('edit',[.27 y .16 .045],value,[]); set(h,'Tag',tag);
    end
    function button(y,str,cb), control('pushbutton',[.025 y .405 .045],str,cb); end
    function updateScanTiming(varargin)
        durations=ctx.nT*ctx.TR/60;description='Acquisition';
        if isfield(ctx,'scanTiming')&&~isempty(ctx.scanTiming)
            choice=1;if ~isempty(pScan),choice=get(pScan,'Value');end
            indices=ctx.originalScanIndex;description='Original scan';
            if choice==2,indices=1:numel(ctx.scanTiming);description='Each scan';
            elseif choice>2,indices=choice-2;description='Selected scan';end
            durations=cellfun(@(d)d.nFrames*d.TR/60,ctx.scanTiming(indices));
        end
        range=sprintf('%.3g',max(durations));
        if min(durations)~=max(durations),range=sprintf('%.3g-%.3g',min(durations),max(durations));end
        set(timingText,'String',sprintf('Baseline: %.3g-%.3g min | %s: %s min',ctx.baselineSec/60,description,range), ...
            'TooltipString','Scan-relative time: every scan starts at 0. In all-scan searches, recordings that cannot cover the complete requested interval are skipped and reported.');
    end
    function o=collect()
        o=struct('size',str2double(get(eSize,'String')),'signalSec',60*sscanf(strrep(get(eTime,'String'),',',' '),'%f')', ...
            'plateauSec',60*str2double(get(eDuration,'String')),'sharedWindow',get(pWindow,'Value')==2, ...
            'boundsXY',sscanf(strrep(get(eBounds,'String'),',',' '),'%f')','bilateral',logical(get(cbBoth,'Value')), ...
            'splitX',str2double(get(eSplit,'String')),'leftIsTarget',get(pRole,'Value')==1, ...
            'allSlices',logical(get(cbAll,'Value')),'slice',z,'cleanDisplay',false, ...
            'sliceRange',[str2double(get(eFirst,'String')) str2double(get(eLast,'String'))]);
        o.scanScope='original';o.scanIndex=[];
        if ~isempty(pScan)
            value=get(pScan,'Value');if value==2,o.scanScope='all';elseif value>2,o.scanScope='single';o.scanIndex=value-2;end
        end
        modes={'keep','shared','adaptive'};o.displayMode=modes{get(pDisplay,'Value')};o.sharedDisplay=sharedDisplay;
        o.polygons=cell(nz,2); % Keep the region helper/backward metadata contract.
        choices={'Both','Target','Control'}; o.roiSelection=choices{get(pWhich,'Value')};
        if ~strcmp(o.roiSelection,'Both'),o.bilateral=true;end
        o.topCount=[str2double(get(eTopTarget,'String')) str2double(get(eTopControl,'String'))];
        o.roiMode='rectangle';o.sizeMode='pixels';o.spacingUm=ctx.spacingUm;
        o.sizeUm=[str2double(get(eWidth,'String')) str2double(get(eHeight,'String'))];
        if get(pROIMode,'Value')==3,o.roiMode='region';
        else
            if get(pROIMode,'Value')==2,o.sizeMode='um';end
            geometry=scmROI('size',o,ctx.spacingUm);o.sizeXY=geometry.sizeXY;
        end
        if strcmp(o.roiSelection,'Target'),o.topCount(2)=0;elseif strcmp(o.roiSelection,'Control'),o.topCount(1)=0;end
        o.paintMasks=repmat({paintedMask},1,nz);
        if hasAtlas
            o.atlasLabels=ctx.atlasLabels;o.excludedAtlasIDs=excluded;
            o.minAtlasCoverage=str2double(get(eCoverage,'String'))/100;
            if strcmp(o.roiMode,'region'),o.minAtlasCoverage=1;end
            o.atlasRegions=selectedAtlasRegions;o.atlasRegion=[];
            if numel(selectedAtlasRegions)==1,o.atlasRegion=selectedAtlasRegions;end
            if isfield(ctx,'atlasProvenance'),o.atlasProvenance=ctx.atlasProvenance;end
        end
    end
    function roleTicks(~,~)
        if cbTarget.Value&&cbControl.Value,pWhich.Value=1;
        elseif cbTarget.Value,pWhich.Value=2;
        elseif cbControl.Value,pWhich.Value=3;
        else,status.String='Select Target, Control, or both.';set(go,'Enable','off');return;end
        set(go,'Enable','on');
        if pWhich.Value~=1,cbBoth.Value=1;end
        preview();
    end
    function rolePopup(~,~)
        cbTarget.Value=pWhich.Value~=3;cbControl.Value=pWhich.Value~=2;roleTicks([],[]);
    end
    function atlasRegionChanged(~,~)
        selectedAtlasRegions=catalog([]);value=get(pAtlas,'Value');
        if value>1,selectedAtlasRegions=catalog(value-1);end
        updateRegionChoice();preview();
    end
    function chooseAtlasRegions(~,~)
        if isappdata(f,'SCMAtlasRegionsRequest')
            ids=getappdata(f,'SCMAtlasRegionsRequest');rmappdata(f,'SCMAtlasRegionsRequest');
            regions=catalog(ismember([catalog.id],ids));ok=true;
        else
            [regions,ok]=scmAtlasRegionSelectionDialog(catalog,selectedAtlasRegions);
        end
        if ~ok,return;end
        selectedAtlasRegions=regions;updateRegionChoice();preview();
    end
    function updateRegionChoice()
        first='Atlas: all labelled brain tissue';value=1;
        if numel(selectedAtlasRegions)>1,first=sprintf('Atlas: %d regions selected',numel(selectedAtlasRegions));
        elseif numel(selectedAtlasRegions)==1,value=1+find([catalog.id]==selectedAtlasRegions.id,1);end
        set(pAtlas,'String',[{first} {catalog.displayName}],'Value',value);
        names={selectedAtlasRegions.displayName};if isempty(names),names={'All labelled brain tissue'};end
        set(pAtlas,'TooltipString',strjoin(names,newline));
    end
    function roiModeChanged(varargin)
        physical=get(pROIMode,'Value')==2;whole=get(pROIMode,'Value')==3;
        set(eSize,'Visible',onoff(~physical),'Enable',onoff(~whole));
        set([eWidth eHeight],'Visible',onoff(physical));
        set(eCoverage,'Enable',onoff(hasAtlas&&~whole));
        if whole
            set([eTopTarget eTopControl],'String','1');
            set(eSize,'Visible','off');
        end
        preview();
    end
    function s=onoff(v),s='off';if v,s='on';end,end
    function rangeMode(~,~)
        enabled='off';if get(cbAll,'Value'),enabled='on';end
        set([eFirst eLast],'Enable',enabled);preview();
    end
    function changeSlice(~,~)
        if dragging||painting,set(sl,'Value',z);return;end
        z=round(get(sl,'Value')); set(sl,'Value',z); preview();
    end
    function rememberDisplay(~,~)
        try
            assert(isfield(ctx,'display'),'Current SCM display settings are unavailable.');
            sharedDisplay=scmSharedDisplay('set',ctx.display);
            set(pDisplay,'Value',2);
            set(status,'String',sprintf('Shared limits saved: color %g to %g%%; alpha ramp %g to %g%%.',sharedDisplay.caxis,sharedDisplay.modMin,sharedDisplay.modMax),'ForegroundColor','w');
        catch ME, set(status,'String',ME.message,'ForegroundColor',[1 .45 .3]); end
    end
    function scroll(~,event)
        if dragging||painting, return; end
        z=max(1,min(nz,z+event.VerticalScrollCount)); set(sl,'Value',z); preview();
    end
    function preview(varargin)
        if dragging, return; end
        if painting,updatePaintShade();return;end
        try
            if isempty(hAnatomy)||~isgraphics(hAnatomy)||underlaySlice~=z
                anatomy=ctx.underlay(z);
                assert(~isempty(anatomy),'deConfUSIon:SearchPreview','The anatomy underlay is empty.');
                if isempty(hAnatomy)||~isgraphics(hAnatomy)
                    hAnatomy=image(ax,'CData',anatomy,'XData',anatomyX,'YData',anatomyY,'Tag','SearchAnatomyImage');
                else
                    set(hAnatomy,'CData',anatomy,'XData',anatomyX,'YData',anatomyY);
                end
                underlaySlice=z;
            end
            if isappdata(f,'SCMSearchPreviewError')
                rmappdata(f,'SCMSearchPreviewError');set(go,'Enable','on');
                set(status,'String','Anatomy preview restored. Left-drag paints; right-drag erases.','ForegroundColor','w');
            end
        catch ME
            underlaySlice=NaN;
            if ~isempty(hAnatomy)&&isgraphics(hAnatomy),set(hAnatomy,'Visible','off');end
            setappdata(f,'SCMSearchPreviewError',ME.message);
            set(go,'Enable','off');
            set(sliceText,'String',sprintf('Slice %d / %d - anatomy preview unavailable',z,nz));
            set(status,'String',sprintf('Cannot show anatomy: %s Change slice to retry, or reopen with another SCM underlay.',ME.message), ...
                'ForegroundColor',[1 .45 .3]);return;
        end
        set(hAnatomy,'Visible','on');
        delete(findall(ax,'Tag','SearchRegionOutline'));
        axis(ax,'image'); set(ax,'YDir','reverse','XColor','w','YColor','w','Color','k'); hold(ax,'on');
        if isfield(ctx,'viewAspect'),set(ax,'DataAspectRatio',ctx.viewAspect);end
        set(ax,'FontSize',12);
        set(sliceText,'String',sprintf('Slice %d / %d - scroll mouse wheel or move slider',z,nz));
        try
            o=collect(); searched=scmSearchSlices(o,nz);
            if strcmp(o.roiMode,'region')
                set(sizeInfo,'String','Whole region per side/slice; each chosen region keeps its own maximum.');
            else
                geometry=scmROI('size',o,ctx.spacingUm);
                set(sizeInfo,'String',sprintf('Actual X/Y: %d x %d px | %.6g x %.6g um',geometry.sizeXY,geometry.sizeXYUm));
                set(sizeInfo,'TooltipString',sprintf('Requested X/Y: %.6g x %.6g um. %s',geometry.requestedSizeUm,geometry.roundingRule));
            end
            if ~ismember(z,searched)
                set(sliceText,'String',sprintf('Slice %d / %d - preview only (outside search range)',z,nz));
            end
            % Cache eligibility independently of paint. During a stroke only
            % this mask's alpha changes; anatomy and contours stay in place.
            o.paintMasks=cell(1,nz);
            r=scmSearchRegions(o,z,ctx.mask(z)); included=false(ny,nx);baseIncluded=false(ny,nx);
            for k=1:numel(r)
                shown=r(k).mask;if ~isempty(r(k).atlasRegionMask),shown=shown&r(k).atlasRegionMask;end
                baseIncluded=baseIncluded|shown;
                if ~isempty(paintedMask),shown=shown&paintedMask;end
                included=included|shown;
                c=[1 .55 .05]; if strcmp(r(k).role,'Control'), c=[.05 .65 1]; end
                padded=zeros(ny+2,nx+2); padded(2:end-1,2:end-1)=double(shown);
                if any(shown(:))
                    [~,outline]=contour(ax,0:nx+1,0:ny+1,padded,[.5 .5],'Color',c,'LineWidth',2);
                    set(outline,'Tag','SearchRegionOutline');
                    [yy,xx]=find(shown);name=r(k).role;
                    if ~isempty(r(k).atlasRegion),name=[r(k).atlasRegion.acronym ' / ' name];end
                    text(ax,mean(xx),min(yy),name,'Color',c, ...
                        'FontWeight','bold','FontSize',14,'HorizontalAlignment','center','VerticalAlignment','top', ...
                        'BackgroundColor','k','Tag','SearchRegionOutline');
                end
            end
            if isempty(hShade)||~isgraphics(hShade)
                hShade=image(ax,zeros(ny,nx,3),'Tag','SearchPaintShade');
            end
            set(hShade,'AlphaData',.55*double(~included));uistack(hShade,'top');
            xlim(ax,[.5 nx+.5]); ylim(ax,[.5 ny+.5]);
        catch ME
            set(status,'String',ME.message,'ForegroundColor',[1 .45 .3]);
        end
        hold(ax,'off');
    end
    function arm(~,~)
        finishStroke(false);
        armed=true; set(cbBrush,'Value',0); set(f,'Pointer','crosshair');
        set(status,'String','Drag from one corner to the opposite corner. Release to apply; Esc cancels.','ForegroundColor','w');
    end
    function p=point(), q=get(ax,'CurrentPoint'); p=q(1,1:2); end
    function q=pointerInput()
        % An optional reader makes real dialog callbacks testable without
        % moving the user's cursor. Studio uses the native input below.
        if isfield(ctx,'pointerInputFcn')
            q=ctx.pointerInputFcn(f,ax);return;
        end
        p=point();hit=hittest(f);
        inside=isequal(hit,ax)||isequal(ancestor(hit,'axes'),ax);
        q=struct('xy',p,'inside',inside,'kind',get(f,'SelectionType'),'leftDown',true,'rightDown',true);
        if mouseButtonsAvailable
            try
                buttons=System.Windows.Forms.Control.MouseButtons;
                names=char(buttons.ToString);
                q.leftDown=contains(names,'Left');q.rightDown=contains(names,'Right');
            catch
                mouseButtonsAvailable=false;
            end
        end
    end
    function mouseDown(~,~)
        q=pointerInput();
        if get(cbBrush,'Value')
            if ~q.inside,return;end
            kind=q.kind;if ~any(strcmp(kind,{'normal','alt'})),return;end
            if (strcmp(kind,'normal')&&~q.leftDown)||(strcmp(kind,'alt')&&~q.rightDown),return;end
            p=q.xy;if any(p<[.5 .5])||any(p>[nx+.5 ny+.5]),return;end
            radius=str2double(get(eBrush,'String'));
            if ~isfinite(radius)||radius<=0||radius>max(nx,ny)
                set(status,'String','Brush radius must be positive and no larger than the image.');return;
            end
            eraseStroke=strcmp(kind,'alt');strokeRadius=radius;
            if isempty(paintedMask),paintedMask=repmat(eraseStroke,ny,nx);end
            painting=true;lastPoint=[];set(go,'Enable','off');paintTo(p,true);return;
        end
        if ~armed||~strcmp(q.kind,'normal')||~q.leftDown||~q.inside, return; end
        p=q.xy; if any(p<[.5 .5])||any(p>[nx+.5 ny+.5]), return; end
        anchor=p;lastPoint=p;dragging=true; set(go,'Enable','off');
        rubber=rectangle(ax,'Position',[p .01 .01],'EdgeColor','y','LineWidth',2,'LineStyle','--');
    end
    function mouseMove(~,~)
        if ~painting&&~dragging,return;end
        q=pointerInput();
        held=q.leftDown;if painting&&eraseStroke,held=q.rightDown;end
        if ~held||(painting&&~q.inside)
            % Mouse-up can happen outside the window. Never join the last
            % stroke to a later hover position after that release.
            finishStroke(false);return;
        end
        if painting
            p=max([.5 .5],min([nx+.5 ny+.5],q.xy));paintTo(p,false);return;
        end
        p=max([.5 .5],min([nx+.5 ny+.5],q.xy));lastPoint=p;
        set(rubber,'Position',[min(anchor,p) max([.01 .01],abs(p-anchor))]); drawnow limitrate nocallbacks;
    end
    function mouseUp(~,~)
        finishStroke(true);
    end
    function finishStroke(includeEndpoint)
        if ~painting&&~dragging,return;end
        wasPainting=painting;wasDragging=dragging;
        % Clear gesture flags before any drawing or callback processing.
        painting=false;dragging=false;
        p=lastPoint;
        if includeEndpoint
            q=pointerInput();
            if q.inside,p=max([.5 .5],min([nx+.5 ny+.5],q.xy));end
        end
        if wasPainting
            if includeEndpoint&&~isempty(p)
                paintedMask=scmPaintMask(paintedMask,lastPoint,p,strokeRadius,eraseStroke);
            end
            set(status,'String','Painted mask applied to ALL slices. Left adds; right erases.','ForegroundColor','w');
        elseif wasDragging
            lo=max([1 1],ceil(min(anchor,p)));hi=min([nx ny],floor(max(anchor,p)));
            armed=false;set(cbBrush,'Value',1);set(f,'Pointer','crosshair');
            if all(hi>=lo),set(eBounds,'String',sprintf('%d %d %d %d',lo(1),hi(1),lo(2),hi(2)));end
            set(status,'String','Rectangle applied to every searched slice. Ready to start.','ForegroundColor','w');
        end
        lastPoint=[];anchor=[];if isgraphics(rubber),delete(rubber);end;rubber=[];
        set(go,'Enable','on');preview();drawnow limitrate nocallbacks;
    end
    function key(~,event)
        if strcmp(event.Key,'escape'),finishStroke(false);armed=false;set(cbBrush,'Value',0);set(go,'Enable','on');set(f,'Pointer','arrow');preview();end
    end
    function reset(~,~)
        finishStroke(false);armed=false;paintedMask=[];set(cbBrush,'Value',1);set(go,'Enable','on');set(f,'Pointer','crosshair');
        set(eBounds,'String',sprintf('1 %d 1 %d',nx,ny)); preview();
    end
    function brushMode(~,~)
        finishStroke(false);armed=false;set(go,'Enable','on');
        if get(cbBrush,'Value')
            set(f,'Pointer','crosshair');set(status,'String','First left stroke starts empty; first right stroke starts full. Painting, Clear and Fill apply to ALL slices.','ForegroundColor','w');
        else,set(f,'Pointer','arrow');end
    end
    function fillPaint(value)
        finishStroke(false);paintedMask=repmat(logical(value),ny,nx);preview();
        set(status,'String','Area updated on ALL slices. This mask stays active when the brush is switched off.','ForegroundColor','w');
    end
    function paintTo(p,forceDraw)
        from=lastPoint;if isempty(from),from=p;end
        paintedMask=scmPaintMask(paintedMask,from,p,strokeRadius,eraseStroke);
        lastPoint=p;
        if forceDraw||toc(lastPaintDraw)>=1/60
            % Our own refresh cap keeps rendering bounded. MATLAB's
            % additional limitrate cap would reduce brush feedback to 20 Hz.
            updatePaintShade();drawnow nocallbacks;lastPaintDraw=tic;
        end
    end
    function updatePaintShade()
        if isempty(hShade)||~isgraphics(hShade),return;end
        included=baseIncluded;if ~isempty(paintedMask),included=included&paintedMask;end
        set(hShade,'AlphaData',.55*double(~included));
    end
    function accept(~,~)
        try
            o=collect(); w=o.signalSec;
            whole=strcmp(o.roiMode,'region');
            if whole
                assert(hasAtlas&&~isempty(o.atlasRegions),'Select one or several named atlas regions for whole-region analysis.');
            else
                geometry=scmROI('size',o,ctx.spacingUm);xy=geometry.sizeXY;
                assert(xy(1)<=nx&&xy(2)<=ny,'ROI width/height must fit the image.');
            end
            searchTR=ctx.TR;searchNT=ctx.nT;
            if isfield(ctx,'scanTiming')
                index=ctx.originalScanIndex;
                if strcmp(o.scanScope,'all'),[~,index]=max(cellfun(@(d)d.nFrames*d.TR,ctx.scanTiming));
                elseif strcmp(o.scanScope,'single'),index=o.scanIndex;end
                searchTR=ctx.scanTiming{index}.TR;searchNT=ctx.scanTiming{index}.nFrames;
            end
            assert(numel(w)==2&&all(isfinite(w))&&w(1)>=0&&w(2)>w(1)&&w(2)<=searchNT*searchTR+max(1e-9,searchTR*1e-6), ...
                'Search start/end must be increasing and inside the acquisition (minutes).');
            scmSearchWindows(w,o.plateauSec,searchTR,searchNT);
            slices=scmSearchSlices(o,nz);
            assert(all(isfinite(o.topCount)&o.topCount>=0&o.topCount==round(o.topCount)), ...
                'Top ROI counts must be whole numbers; 0 keeps all candidates.');
            active=[true true];if strcmp(o.roiSelection,'Target'),active(2)=false;elseif strcmp(o.roiSelection,'Control'),active(1)=false;end
            assert(all(o.topCount(active)<=numel(slices)), ...
                'Top ROI count cannot exceed the number of searched slices (one candidate per role per slice).');
            if hasAtlas
                assert(isfinite(o.minAtlasCoverage)&&o.minAtlasCoverage>=.75&&o.minAtlasCoverage<=1,'Minimum atlas coverage must be 75-100 percent.');
            end
            anyFits=false;
            for zz=slices
                rr=scmSearchRegions(o,zz,ctx.mask(zz));
                if hasAtlas||~isempty(o.paintMasks{zz})
                    for ri=1:numel(rr)
                        if whole
                            eligible=rr(ri).mask&rr(ri).atlasRegionMask;
                        else
                            kernel=ones(xy(2),xy(1));np=prod(xy);
                            eligible=conv2(double(rr(ri).mask),kernel,'valid')==np;
                            if ~isempty(rr(ri).atlasRegionMask)
                                eligible=eligible&conv2(double(rr(ri).atlasRegionMask),kernel,'valid')>=ceil(o.minAtlasCoverage*np-1e-9);
                            end
                        end
                        anyFits=anyFits||any(eligible(:));
                    end
                end
            end
            if hasAtlas||any(~cellfun(@isempty,o.paintMasks(slices)))
                assert(anyFits,'Chosen region/painted area cannot fit this ROI on any searched slice with the selected coverage, side and mask. Reduce the ROI size or change the slice range.');
            end
            b=o.boundsXY;
            if ~whole,assert(xy(1)<=b(2)-b(1)+1&&xy(2)<=b(4)-b(3)+1,'ROI width/height is larger than the search rectangle.');end
            set(status,'String','Starting analysis...','ForegroundColor','w'); drawnow;
            accepted=true; uiresume(f);
        catch ME
            set(status,'String',['Cannot start: ' ME.message],'ForegroundColor',[1 .45 .3]); drawnow;
        end
    end
end
