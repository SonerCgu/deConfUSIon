function fig=fusiLightSuiteLandmarks(session,onContinue)
% Full-volume paired landmark editor; writes the upstream LightSuite format.
% Stored coordinates remain [AP DV ML timestamp] on the original, oriented
% sample grid and fixed atlas grid. Display contrast never changes these data.
if nargin<2,onContinue=[];end
s=session;assert(s.orientationConfirmed,'Confirm orientation before placing landmarks.');
p=s.opts.permute_sample_to_atlas;
sample=permute(single(s.opts.sample),abs(p));
for d=1:3,if p(d)<0,sample=flip(sample,d);end,end
atlas=s.opts.atlas;volumes={sample,atlas};
[editedUnderlay,editedMeta]=fusiLightSuiteLandmarkUnderlay(s);
if ~isempty(editedUnderlay)
    editedUnderlay=permute(editedUnderlay,abs(p));
    for d=1:3,if p(d)<0,editedUnderlay=flip(editedUnderlay,d);end,end
end
resolution={s.opts.sample_res(abs(p)),s.opts.atlas_res};
points={zeros(0,4),zeros(0,4)};pending=[];dirty=false;selected=[];view=1;mode=1;
busy=false;actionClock=[];lastAction='Editor opened';lastDuration=0;lastSaved='';displayCache={[],[]};renderCount=[0 0];
indices=[round(size(sample,1)/2) round(size(atlas,1)/2)];
wantedIndices=indices;scrollTimer=[];
% Revisited slices reuse their display pixels. Bound the cache independently
% of recording size; optimizer inputs and saved coordinates always stay raw.
planeKeys=zeros(0,4);planePixels={};planeLimits=zeros(0,2);planeAges=[];planeSizes=[];
cacheBytes=0;cacheClock=0;cacheHits=0;preparedCount=[0 0];
maxCacheBytes=64*1024^2;maxCacheEntries=96;
file=fullfile(s.opts.savepath,'control_points_minimal.mat');backedUp=false;
readOnly=isfile(fullfile(s.opts.savepath,'transform_params.mat'));
if isfile(file)
    stamp=dir(file);lastSaved=datestr(stamp.datenum,'HH:MM:SS');
    saved=load(file,'sample_points','atlas_points');
    assert(all(isfield(saved,{'sample_points','atlas_points'})),'Unrecognized landmark file.');
    assert(iscell(saved.sample_points)&&iscell(saved.atlas_points)&& ...
        numel(saved.sample_points)==numel(saved.atlas_points),'Invalid landmark cell layout.');
    assert(all(cellfun(@(a,b)size(a,1)==size(b,1),saved.sample_points,saved.atlas_points)), ...
        'deConfUSIon:LightSuiteUnequalPoints','The existing landmark file has incomplete pairs. Preserve it and use a new project, or repair its unmatched points before fitting.');
    for loadIndex=1:numel(saved.sample_points)
        points{1}=[points{1};saved.sample_points{loadIndex}];points{2}=[points{2};saved.atlas_points{loadIndex}]; %#ok<AGROW>
    end
end
% Standard contrast is computed only for the displayed planes. Do not sort
% both complete volumes merely to initialize unused linear window limits.
% The vascular atlas is a published intensity template, not raw probe data.
% Keep its native linear window; Mask Editor enhancement is sample-only.
atlasValues=atlas(isfinite(atlas));
atlasLimits=double([min(atlasValues(:)) max(atlasValues(:))]);
if isempty(atlasLimits)||atlasLimits(2)<=atlasLimits(1),atlasLimits=[0 1];end
fig=figure('Name','deConfUSIon | LightSuite paired landmarks','NumberTitle','off', ...
    'Color',[.035 .045 .045],'MenuBar','none','ToolBar','none','Position',[80 60 1220 900], ...
    'WindowKeyPressFcn',@key,'WindowScrollWheelFcn',@scroll,'CloseRequestFcn',@closeWindow, ...
    'DeleteFcn',@deleteScrollTimer,'Interruptible','off','BusyAction','queue');
setappdata(fig,'deConfUSIonNoMaximize',true);setappdata(fig,'LightSuiteLandmarkEditor',true);
setappdata(fig,'FUSILandmarkClick',@clickPoint);
setappdata(fig,'FUSILandmarkScroll',@queueStep);
fusiLightSuiteLabelWindow(fig,s,[.025 .957 .70 .03]);
saveState=uicontrol(fig,'Style','text','Units','normalized','Position',[.73 .957 .245 .03], ...
    'String','','FontSize',12,'FontWeight','bold','HorizontalAlignment','right','Tag','LightSuiteLandmarkSaveState');
activity=uicontrol(fig,'Style','text','Units','normalized','Position',[.025 .916 .95 .032], ...
    'String','OPENING | Preparing landmark views...','FontSize',12,'FontWeight','bold', ...
    'HorizontalAlignment','left','Tag','LightSuiteLandmarkActivity');
activity.Position(3)=.70;
uicontrol(fig,'Style','pushbutton','Units','normalized','Position',[.75 .914 .225 .035], ...
    'String','Load edited underlay...','FontSize',10,'Callback',@loadUnderlay,'Tag','LightSuiteLandmarkLoadUnderlay', ...
    'TooltipString','Choose a Mask Editor export from this animal''s Visualization folder. Display only; fitting uses the original anatomy.');
uicontrol(fig,'Style','text','Units','normalized','Position',[.025 .836 .95 .072], ...
    'String',{'MATCH THE SAME ANATOMICAL FEATURE: 1. Choose slices independently below each image.  2. Click your sample on the left.  3. Click the matching atlas feature on the right.', ...
    'Use recognizable vessel bifurcations and the midline. Spread pairs across AP, DV and ML; do not select all points in one plane. Save before fitting.', ...
    'Mouse wheel changes the image under the pointer. Right-click: undo last click. Arrows: sample left/right; atlas up/down. Esc: cancel pending. S: save.'}, ...
    'HorizontalAlignment','left','FontSize',11);
plane=uicontrol(fig,'Style','popupmenu','Units','normalized','Position',[.025 .805 .27 .045], ...
    'String',{'Coronal: AP slices','Horizontal: DV slices','Sagittal: ML slices'},'Callback',@changePlane,'Tag','LightSuiteLandmarkPlane');
modeControl=uicontrol(fig,'Style','popupmenu','Units','normalized','Position',[.31 .805 .25 .045], ...
    'String',{'Mark matching points','Inspect: zoom','Inspect: pan'},'Callback',@changeMode,'Tag','LightSuiteLandmarkMode');
contrast=uicontrol(fig,'Style','popupmenu','Units','normalized','Position',[.575 .805 .17 .045], ...
    'String',{'Anatomy: Mask Editor','Anatomy: vessels','Anatomy: full range','Saved edited underlay'},'Callback',@changeContrast, ...
    'Tag','LightSuiteLandmarkContrast','TooltipString','Changes your anatomy display only. Saved edited underlay uses native pixels from your Mask Editor export.');
if ~isempty(editedUnderlay),contrast.Value=4;end
uicontrol(fig,'Style','pushbutton','Units','normalized','Position',[.755 .805 .055 .045], ...
    'String','Help','Callback',@(~,~)fusiLightSuiteLandmarkHelp());
uicontrol(fig,'Style','pushbutton','Units','normalized','Position',[.825 .805 .15 .045], ...
    'String','Save pairs (S)','Callback',@(~,~)savePairs(),'Tag','LightSuiteLandmarkSave');
ax=gobjects(1,2);imageHandle=gobjects(1,2);slider=gobjects(1,2);number=gobjects(1,2);sliceLabel=gobjects(1,2);
pairMarkers=gobjects(1,2);selectedMarkers=gobjects(1,2);pointLabels={gobjects(0),gobjects(0)};
names={'YOUR SAMPLE','VASCULAR ATLAS'};
for createSide=1:2
    left=.025+(createSide-1)*.50;
    ax(createSide)=axes(fig,'Units','normalized','Position',[left .36 .45 .39]);
    imageHandle(createSide)=imagesc(ax(createSide),zeros(2));colormap(ax(createSide),gray(256));axis(ax(createSide),'image');
    ax(createSide).YDir='reverse';ax(createSide).XTick=[];ax(createSide).YTick=[];
    title(ax(createSide),names{createSide},'Color',[.8 .96 .88],'FontSize',13);
    set(imageHandle(createSide),'ButtonDownFcn',@(~,~)clickImage(createSide),'Tag',sprintf('LightSuiteLandmarkImage%d',createSide));
    pairMarkers(createSide)=markerLine(createSide,[.3 1 .65],'o',8,1.5);
    selectedMarkers(createSide)=markerLine(createSide,[1 .72 .2],'o',8,1.5);
    sliceLabel(createSide)=uicontrol(fig,'Style','text','Units','normalized','Position',[left .305 .45 .035], ...
        'String','','HorizontalAlignment','left','FontSize',12);
    uicontrol(fig,'Style','pushbutton','Units','normalized','Position',[left .25 .045 .045], ...
        'String','<','Callback',@(~,~)step(createSide,-1));
    slider(createSide)=uicontrol(fig,'Style','slider','Units','normalized','Position',[left+.055 .26 .28 .025], ...
        'Min',1,'Max',2,'Value',1,'Callback',@(src,~)setSlice(createSide,get(src,'Value')), ...
        'Tag',sprintf('LightSuiteLandmarkSlice%d',createSide));
    uicontrol(fig,'Style','pushbutton','Units','normalized','Position',[left+.345 .25 .045 .045], ...
        'String','>','Callback',@(~,~)step(createSide,1));
    number(createSide)=uicontrol(fig,'Style','edit','Units','normalized','Position',[left+.395 .25 .055 .045], ...
        'String','1','Callback',@(src,~)setSlice(createSide,str2double(get(src,'String'))));
end
pendingMarker=markerLine(1,[1 .7 .15],'+',16,2);
uicontrol(fig,'Style','text','Units','normalized','Position',[.025 .195 .61 .025], ...
    'String','PAIR        SAMPLE [AP DV ML]                         ATLAS [AP DV ML]', ...
    'HorizontalAlignment','left','FontSize',10);
% A native listbox keeps the unused viewport dark too; classic UITable leaves
% its empty Java viewport white even when row BackgroundColor is dark.
pairList=uicontrol(fig,'Style','listbox','Units','normalized','Position',[.025 .065 .61 .13], ...
    'String',{'No paired landmarks yet.'},'FontSize',11,'Callback',@selectPair,'Tag','LightSuiteLandmarkPairs');
uicontrol(fig,'Style','pushbutton','Units','normalized','Position',[.665 .165 .15 .05], ...
    'String','Undo last click','Callback',@undoLastPoint,'Tag','LightSuiteLandmarkUndo');
uicontrol(fig,'Style','pushbutton','Units','normalized','Position',[.825 .165 .15 .05], ...
    'String','Delete selected pair','Callback',@deletePair,'Tag','LightSuiteLandmarkDelete');
uicontrol(fig,'Style','pushbutton','Units','normalized','Position',[.665 .108 .31 .05], ...
    'String','Cancel pending sample point (Esc)','Callback',@cancelPending);
continueText='Save and close';if isa(onContinue,'function_handle'),continueText='Save + continue to fit';end
continueButton=uicontrol(fig,'Style','pushbutton','Units','normalized','Position',[.665 .05 .31 .05], ...
    'String',continueText,'Callback',@saveAndClose,'Tag','LightSuiteLandmarkContinue','FontWeight','bold');
status=uicontrol(fig,'Style','text','Units','normalized','Position',[.025 .004 .95 .037], ...
    'String','','FontSize',11,'HorizontalAlignment','left','Tag','LightSuiteLandmarkStatus');
fusiLightSuiteStyle(fig);fusiLightSuiteLabelWindow(fig,s,[.025 .957 .70 .03]);
continueButton.BackgroundColor=[.05 .38 .28];continueButton.ForegroundColor=[.9 1 .95];
if readOnly
    continueButton.String='Close read-only editor';
    set(findall(fig,'Tag','LightSuiteLandmarkSave'),'Enable','off');
    set(findall(fig,'Tag','LightSuiteLandmarkUndo'),'Enable','off');
    set(findall(fig,'Tag','LightSuiteLandmarkDelete'),'Enable','off');
end
set(findall(fig,'Type','uicontrol'),'Interruptible','off','BusyAction','cancel');
scrollTimer=timer('ExecutionMode','singleShot','StartDelay',.025, ...
    'Name','deConfUSIon LightSuite landmark scrolling','ObjectVisibility','off','TimerFcn',@flushScroll);
setappdata(fig,'LightSuiteLandmarkScrollTimer',scrollTimer);
pairList.FontName='Consolas';perform('Preparing the first image planes',@initialize);
fusiLightSuiteLog('LANDMARKS',s,'Editor ready. Right-click undoes the last click; S saves without closing.');
    function initialize(),updateImages(true);updateTable();updateStatus();end
    function ok=perform(message,action)
        ok=false;if busy||~isgraphics(fig),return;end
        cancelScroll();
        if isappdata(fig,'LightSuiteLastError'),rmappdata(fig,'LightSuiteLastError');end
        busy=true;actionClock=tic;lastAction=message;
        setappdata(fig,'LightSuiteLandmarkBusy',true);fig.Pointer='watch';showActivity(message,true);
        cleanup=onCleanup(@()finishAction(fig));
        try,action();ok=true;
        catch err
            setappdata(fig,'LightSuiteLastError',err);lastAction=['ERROR: ' err.message];
            status.String=lastAction;fusiLightSuiteLog('ERROR',s,err.message);
        end
    end
    function finishAction(window)
        if ~isgraphics(window),return;end
        lastDuration=toc(actionClock);busy=false;window.Pointer='arrow';setappdata(window,'LightSuiteLandmarkBusy',false);
        updateSaveState();showActivity(lastAction,false);
    end
    function showActivity(message,working)
        if working
            activity.String=sprintf('BUSY | %s | started %s',message,datestr(now,'HH:MM:SS'));
            activity.ForegroundColor=[1 .78 .3];
        else
            activity.String=sprintf('READY | %s (%.2f s)',message,lastDuration);activity.ForegroundColor=[.5 1 .72];
            if startsWith(message,'ERROR:'),activity.String=message;activity.ForegroundColor=[1 .45 .4];end
        end
        drawnow nocallbacks;
    end
    function updateSaveState()
        if readOnly,text='FITTED / READ ONLY';color=[.9 .8 .5];
        elseif ~isempty(pending),text='PENDING POINT / NOT SAVED';color=[1 .75 .3];
        elseif dirty,text='UNSAVED CHANGES';color=[1 .75 .3];
        elseif isempty(lastSaved),text='NOT SAVED YET';color=[.75 .8 .8];
        else,text=['SAVED ' lastSaved];color=[.5 1 .72];end
        set(saveState,'String',text,'ForegroundColor',color,'TooltipString',file);
    end
    function refreshMarkers()
        remaining=setdiff(1:3,view,'stable');for side=1:2,drawPoints(side,remaining);end
        updateSaveState();drawnow limitrate nocallbacks;
    end
    function lim=displayLimits(V,q)
        values=double(V(isfinite(V)&V>0));
        if isempty(values),lim=[0 1];else,lim=quantile(values,q);end
        if lim(2)<=lim(1),lim(2)=lim(1)+1;end
    end
    function changePlane(~,~)
        if busy,return;end
        perform('Changing view plane',@changePlaneImpl);
    end
    function changePlaneImpl()
        view=plane.Value;
        for side=1:2,indices(side)=round(size(volumes{side},view)/2);end
        wantedIndices=indices;
        updateImages(true);
    end
    function changeMode(~,~)
        if busy,return;end
        mode=modeControl.Value;zoom(fig,'off');pan(fig,'off');
        if mode==2,zoom(fig,'on');elseif mode==3,pan(fig,'on');end
        updateStatus();
    end
    function changeContrast(~,~)
        if busy,return;end
        if contrast.Value==4&&isempty(editedUnderlay),contrast.Value=1;loadUnderlay();return;end
        perform('Updating sample contrast',@()updateImages(false,1));
    end
    function loadUnderlay(varargin)
        if busy,return;end
        if isappdata(fig,'LightSuiteLandmarkUnderlayRequest')
            selectedFile=getappdata(fig,'LightSuiteLandmarkUnderlayRequest');rmappdata(fig,'LightSuiteLandmarkUnderlayRequest');
        else
            [name,folder]=uigetfile('*.mat','Choose this recording''s edited Mask Editor underlay', ...
                fullfile(fusiLightSuiteVisualizationFolder(s),'*.mat'));
            if isequal(name,0),return;end;selectedFile=fullfile(folder,name);
        end
        perform('Loading edited landmark underlay',@()applyEditedUnderlay(selectedFile));
    end
    function applyEditedUnderlay(selectedFile)
        [displayImage,displayMeta]=fusiLightSuiteLandmarkUnderlay(s,selectedFile);
        save(fullfile(s.opts.savepath,'landmark_underlay.mat'),'displayImage','displayMeta','-v7.3');
        editedUnderlay=displayImage;editedMeta=displayMeta;contrast.Value=4;
        editedUnderlay=permute(editedUnderlay,abs(p));
        for d=1:3,if p(d)<0,editedUnderlay=flip(editedUnderlay,d);end,end
        displayCache{1}=[];planeKeys=zeros(0,4);planePixels={};planeLimits=zeros(0,2);planeAges=[];planeSizes=[];cacheBytes=0;
        setappdata(fig,'LightSuiteLandmarkUnderlay',displayMeta);updateImages(false,1);
        status.String=['Edited underlay loaded (display only): ' selectedFile];
    end
    function setSlice(side,value)
        if busy,return;end
        cancelScroll();
        if ~isfinite(value),number(side).String=num2str(indices(side));return;end
        value=max(1,min(size(volumes{side},view),round(value)));if value==indices(side),return;end
        target=indices;target(side)=value;navigateTo(target);
    end
    function step(side,delta),setSlice(side,indices(side)+delta);end
    function queueStep(side,delta)
        if busy||~isgraphics(fig),return;end
        wantedIndices(side)=max(1,min(size(volumes{side},view),wantedIndices(side)+delta));
        % Keep every wheel increment, but draw only the latest requested slice
        % once per burst. Restarting on every tick would delay continuous scroll.
        if strcmp(scrollTimer.Running,'off'),start(scrollTimer);end
    end
    function flushScroll(~,~)
        if ~isgraphics(fig)||busy,return;end
        navigateTo(wantedIndices);
    end
    function cancelScroll()
        if ~isempty(scrollTimer)&&isvalid(scrollTimer)&&strcmp(scrollTimer.Running,'on'),stop(scrollTimer);end
        wantedIndices=indices;
    end
    function deleteScrollTimer(varargin)
        if ~isempty(scrollTimer)&&isvalid(scrollTimer),stop(scrollTimer);delete(scrollTimer);end
    end
    function navigateTo(target)
        changed=find(target~=indices);if isempty(changed),return;end
        if isappdata(fig,'LightSuiteLastError'),rmappdata(fig,'LightSuiteLastError');end
        busy=true;setappdata(fig,'LightSuiteLandmarkBusy',true);
        cleanup=onCleanup(@()finishNavigation(fig));
        try
            indices=target;wantedIndices=indices;updateImages(false,changed);
            message='READY | Browse slices; click a matching feature when the view is steady.';
            if ~strcmp(activity.String,message),activity.String=message;activity.ForegroundColor=[.5 1 .72];end
        catch err
            setappdata(fig,'LightSuiteLastError',err);status.String=err.message;
            activity.String=['ERROR: ' err.message];activity.ForegroundColor=[1 .45 .4];
            fusiLightSuiteLog('ERROR',s,err.message);
        end
    end
    function finishNavigation(window)
        if ~isgraphics(window),return;end
        busy=false;setappdata(window,'LightSuiteLandmarkBusy',false);
        % One repaint per combined wheel burst. Finish it before accepting a
        % landmark click so displayed pixels and stored slice indices agree.
        drawnow nocallbacks;
    end
    function scroll(~,event)
        % Hit testing alone misses the letterboxed margin and text/controls
        % around an image. Use the pointer's figure coordinates for each panel.
        cursor=get(fig,'CurrentPoint');bounds=getpixelposition(fig);xy=cursor./bounds(3:4);
        if xy(2)<.24||xy(2)>.79,return;end
        if xy(1)>=.025&&xy(1)<=.475,queueStep(1,event.VerticalScrollCount);
        elseif xy(1)>=.525&&xy(1)<=.975,queueStep(2,event.VerticalScrollCount);end
    end
    function updateImages(reset,sides)
        if nargin<2,sides=1:2;end
        remaining=setdiff(1:3,view,'stable');axisNames={'AP','DV','ML'};
        for side=reshape(sides,1,[])
            V=volumes{side};n=size(V,view);indices(side)=max(1,min(n,indices(side)));
            contrastKey=0;if side==1,contrastKey=contrast.Value;end
            cacheKey=[view indices(side) contrastKey];
            if ~isequal(displayCache{side},cacheKey)
                [image,imageLimits]=preparedPlane(side,cacheKey);
                set(imageHandle(side),'CData',image);
                if reset,set(imageHandle(side),'XData',[1 size(image,2)],'YData',[1 size(image,1)]);end
                ax(side).CLim=imageLimits;
                displayCache{side}=cacheKey;renderCount(side)=renderCount(side)+1;
            end
            image=imageHandle(side).CData;res=resolution{side};
            if reset
                ax(side).DataAspectRatio=[1 res(remaining(2))/res(remaining(1)) 1];
                ax(side).XLim=[.5 size(image,2)+.5];ax(side).YLim=[.5 size(image,1)+.5];
                set(slider(side),'Max',max(2,n),'SliderStep',[1/max(1,n-1) min(1,10/max(1,n-1))]);
            end
            slider(side).Value=indices(side);number(side).String=num2str(indices(side));
            sliceLabel(side).String=sprintf('%s | %s slice %d / %d | %.4g mm per slice',names{side},axisNames{view},indices(side),n,res(view));
            drawPoints(side,remaining);
        end
        setappdata(fig,'LightSuiteLandmarkRenderCount',renderCount);
        setappdata(fig,'LightSuiteLandmarkCache',struct('hits',cacheHits,'prepared',preparedCount, ...
            'bytes',cacheBytes,'entries',numel(planePixels),'limitBytes',maxCacheBytes));
    end
    function [image,imageLimits]=preparedPlane(side,cacheKey)
        key=[side cacheKey];cacheClock=cacheClock+1;
        cached=find(all(planeKeys==key,2),1);
        if ~isempty(cached)
            image=planePixels{cached};imageLimits=planeLimits(cached,:);
            planeAges(cached)=cacheClock;cacheHits=cacheHits+1;return;
        end
        V=volumes{side};remaining=setdiff(1:3,view,'stable');
        sub={':',':',':'};sub{view}=indices(side);image=squeeze(V(sub{:}));
        if side==2
            imageLimits=atlasLimits;
        elseif contrast.Value==4
            image=squeeze(editedUnderlay(sub{:}));imageLimits=[0 1];
            if ~editedMeta.processed,imageLimits=displayLimits(image,[.01 .995]);end
        elseif contrast.Value==1
            % Enhance the native plane before the same permutation and flips
            % used by the raw image; stored data/points remain unchanged.
            nativeAxis=abs(p(view));nativeIndex=indices(side);
            if p(view)<0,nativeIndex=size(s.opts.sample,nativeAxis)-nativeIndex+1;end
            nativeSub={':',':',':'};nativeSub{nativeAxis}=nativeIndex;
            nativeImage=fusiStandardDopplerDisplay(squeeze(s.opts.sample(nativeSub{:})));
            nativeRemaining=setdiff(1:3,nativeAxis,'stable');
            desired=abs(p(remaining));[~,order]=ismember(desired,nativeRemaining);
            image=permute(nativeImage,order);
            for imageDim=1:2,if p(remaining(imageDim))<0,image=flip(image,imageDim);end,end
            imageLimits=[0 1];
        else
            choices={[.01 .995],[.05 .98],[0 1]};imageLimits=displayLimits(image,choices{contrast.Value});
        end
        preparedCount(side)=preparedCount(side)+1;info=whos('image');bytes=info.bytes;
        if bytes>maxCacheBytes,return;end
        while cacheBytes+bytes>maxCacheBytes||numel(planePixels)>=maxCacheEntries
            [~,oldest]=min(planeAges);cacheBytes=cacheBytes-planeSizes(oldest);
            planeKeys(oldest,:)=[];planePixels(oldest)=[];planeLimits(oldest,:)=[];
            planeAges(oldest)=[];planeSizes(oldest)=[];
        end
        planeKeys(end+1,:)=key;planePixels{end+1}=image;planeLimits(end+1,:)=imageLimits;
        planeAges(end+1)=cacheClock;planeSizes(end+1)=bytes;cacheBytes=cacheBytes+bytes;
    end
    function h=markerLine(side,color,shape,markerSize,width)
        h=line(ax(side),NaN,NaN,'LineStyle','none','Marker',shape,'Color',color, ...
            'MarkerSize',markerSize,'LineWidth',width,'Tag','LightSuitePairMarker', ...
            'HitTest','off','PickableParts','none','Visible','off');
    end
    function drawPoints(side,remaining)
        P=points{side};visible=find(abs(P(:,view)-indices(side))<=.5);
        ordinary=visible(~ismember(visible,selected));highlight=visible(ismember(visible,selected));
        set(pairMarkers(side),'XData',P(ordinary,remaining(2)),'YData',P(ordinary,remaining(1)),'Visible','on');
        set(selectedMarkers(side),'XData',P(highlight,remaining(2)),'YData',P(highlight,remaining(1)),'Visible','on');
        labels=pointLabels{side};
        for position=1:numel(visible)
            index=visible(position);
            color=[.3 1 .65];if isequal(selected,index),color=[1 .72 .2];end
            if position>numel(labels)
                labels(position)=text(ax(side),0,0,'','BackgroundColor',[0 0 0],'Margin',1,'FontWeight','bold', ...
                    'Tag','LightSuitePairMarker','HitTest','off','PickableParts','none');
            end
            set(labels(position),'Position',[P(index,remaining(2))+1 P(index,remaining(1)) 0], ...
                'String',num2str(index),'Color',color,'Visible','on');
        end
        set(labels(numel(visible)+1:end),'Visible','off');pointLabels{side}=labels;
        if side==1&&~isempty(pending)&&abs(pending(view)-indices(1))<=.5
            set(pendingMarker,'XData',pending(remaining(2)),'YData',pending(remaining(1)),'Visible','on');
        elseif side==1
            pendingMarker.Visible='off';
        end
    end
    function clickImage(side)
        cursor=ax(side).CurrentPoint;clickPoint(side,cursor(1,1:2),fig.SelectionType);
    end
    function clickPoint(side,xy,selectionType)
        if busy||mode~=1||readOnly,return;end
        % A click belongs to the image the user can currently see, never to a
        % queued wheel target that has not been drawn yet.
        cancelScroll();
        if strcmp(selectionType,'alt'),undoLastPoint();return;end
        if ~strcmp(selectionType,'normal'),return;end
        remaining=setdiff(1:3,view,'stable');V=volumes{side};
        if any(xy<.5)||xy(1)>size(V,remaining(2))+.5||xy(2)>size(V,remaining(1))+.5,return;end
        P=zeros(1,4);P(view)=indices(side);P(remaining)=[xy(2) xy(1)];P(4)=now;
        if side==1
            if ~isempty(pending),status.String='Complete the pending pair on the atlas, or press Esc to cancel it first.';return;end
            pending=P;
        else
            if isempty(pending),status.String='First click a recognizable anatomical feature in YOUR SAMPLE (left).';return;end
            points{1}(end+1,:)=pending;points{2}(end+1,:)=P;pending=[];dirty=true;selected=size(points{1},1);updateTable();
        end
        refreshMarkers();updateStatus();
        lastAction=sprintf('%d complete pairs',size(points{1},1));
        if ~isempty(pending),lastAction=[lastAction ' | Sample marked: click the matching atlas feature'];end
        lastDuration=0;showActivity(lastAction,false);
    end
    function undoLastPoint(varargin)
        if busy||readOnly,return;end
        if ~isempty(pending)
            pending=[];lastAction='Undid the pending sample point';
        elseif ~isempty(points{1})
            % Reverse the last atlas click; retain its sample for correction.
            times=points{2}(:,4);index=find(times==max(times),1,'last');
            pending=points{1}(index,:);points{1}(index,:)=[];points{2}(index,:)=[];
            dirty=true;selected=[];updateTable();lastAction='Undid the last atlas point; click its replacement on the atlas';
        else,lastAction='No landmark clicks to undo';end
        lastDuration=0;refreshMarkers();updateStatus();showActivity(lastAction,false);
    end
    function updateTable()
        rows=cell(size(points{1},1),1);
        for k=1:numel(rows),rows{k}=sprintf('%3d    %-32s    %s',k,mat2str(points{1}(k,1:3),5),mat2str(points{2}(k,1:3),5));end
        if isempty(rows),rows={'No pairs yet. Mark the sample first, then the matching atlas feature.'};end
        pairList.Value=1;pairList.String=rows;
        if ~isempty(selected),pairList.Value=min(selected,numel(rows));end
    end
    function selectPair(src,~)
        if busy||isempty(points{1}),return;end
        perform('Showing the selected landmark pair',@showSelected);
        function showSelected()
        selected=src.Value;view=1;plane.Value=1;
        indices=[round(points{1}(selected,1)) round(points{2}(selected,1))];wantedIndices=indices;updateImages(true);updateStatus();
        end
    end
    function deletePair(~,~)
        if busy||readOnly,return;end
        if ~isempty(pending),cancelPending();return;end
        if isempty(points{1}),return;end
        index=selected;if isempty(index),index=size(points{1},1);end
        points{1}(index,:)=[];points{2}(index,:)=[];selected=[];dirty=true;
        updateTable();refreshMarkers();updateStatus();
    end
    function cancelPending(varargin)
        if busy,return;end
        pending=[];refreshMarkers();updateStatus();
    end
    function updateStatus()
        n=size(points{1},1);ready=n>=5;
        if ready,ready=rank(points{1}(:,1:3)-mean(points{1}(:,1:3),1))==3&&rank(points{2}(:,1:3)-mean(points{2}(:,1:3),1))==3;end
        detail='Need at least 5 pairs spanning AP, DV and ML; more well-distributed pairs improve coverage.';
        if ready,detail='3D landmark spread passes the minimum numerical requirement. Anatomical accuracy still needs review.';end
        if readOnly,detail='Read-only: this project already has a fitted transform. Use a new project for different landmarks.';
        elseif ~isempty(pending),detail='Sample point pending: navigate the ATLAS to the same feature, then click it to complete this pair.';
        elseif mode~=1,detail='Inspect mode: zoom/pan the images. Choose Mark matching points to add a pair.';end
        status.String=sprintf('%d paired landmarks | %s',n,detail);
        updateSaveState();
    end
    function ok=savePairs()
        ok=false;if busy,return;end
        if isfile(fullfile(s.opts.savepath,'transform_params.mat')),readOnly=true;end
        if readOnly,status.String='This fitted project is read-only. Use a new project for a different fit.';return;end
        if ~isempty(pending),status.String='Finish the pending sample/atlas pair or press Esc before saving.';return;end
        ok=perform('Saving landmark pairs to disk',@writePairs);
    end
    function writePairs()
        if isfile(file)&&~backedUp
            backup=[file '.before_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))];
            [copied,message]=copyfile(file,backup);assert(copied,'deConfUSIon:LightSuiteLandmarkBackup','Backup failed: %s',message);
            backedUp=true;
        end
        sample_points=repmat({zeros(0,4)},size(sample,1)*4,1);atlas_points=sample_points;
        for k=1:size(points{1},1)
            slot=(max(1,min(size(sample,1),round(points{1}(k,1))))-1)*4+1;
            sample_points{slot}(end+1,:)=points{1}(k,:);atlas_points{slot}(end+1,:)=points{2}(k,:);
        end
        atlas2sample_tform=eye(4);has_fit=false; %#ok<NASGU>
        editor=struct('name','deConfUSIon full-volume paired editor','coordinates','AP DV ML timestamp; 1-based intrinsic indices','version',1); %#ok<NASGU>
        temporary=fullfile(s.opts.savepath,'control_points_minimal.pending.mat');
        save(temporary,'sample_points','atlas_points','atlas2sample_tform','has_fit','editor','-v7');
        [moved,message]=movefile(temporary,file,'f');assert(moved,'deConfUSIon:LightSuiteLandmarkSave','Could not save: %s',message);
        dirty=false;lastSaved=datestr(now,'HH:MM:SS');lastAction=sprintf('SAVED %d complete pairs at %s',size(points{1},1),lastSaved);
        status.String=[lastAction '. Save pairs keeps the editor open; use the green button when finished.'];
        fusiLightSuiteLog('SAVED',s,'%d complete landmark pairs.\nFile: %s',size(points{1},1),file);
    end
    function saveAndClose(~,~)
        if busy,return;end
        if readOnly,delete(fig);return;end
        if isa(onContinue,'function_handle')
            n=size(points{1},1);spans=n>=5;
            if spans,spans=rank(points{1}(:,1:3)-mean(points{1}(:,1:3),1))==3&&rank(points{2}(:,1:3)-mean(points{2}(:,1:3),1))==3;end
            if ~spans,status.String='Before fitting: add at least 5 complete pairs spanning AP, DV and ML.';return;end
        end
        if savePairs()
            delete(fig);
            if isa(onContinue,'function_handle'),onContinue();end
        end
    end
    function closeWindow(~,~)
        if busy,return;end
        cancelScroll();
        if readOnly||(~dirty&&isempty(pending)),delete(fig);return;end
        choice=fusiLightSuiteChoice('Save landmark changes?', ...
            'The source recording and atlas are unchanged. Only complete matched pairs can be saved.', ...
            {'Save and close','Discard unsaved edits','Keep editing'});
        if strcmp(choice,'Save and close'),saveAndClose();
        elseif strcmp(choice,'Discard unsaved edits'),delete(fig);end
    end
    function key(~,event)
        if busy,return;end
        switch event.Key
            case 'leftarrow',step(1,-1);
            case 'rightarrow',step(1,1);
            case 'uparrow',step(2,-1);
            case 'downarrow',step(2,1);
            case 'escape',cancelPending();
            case 's',savePairs();
            case {'delete','backspace'},deletePair();
        end
    end
end
