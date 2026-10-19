function fig=fusiLightSuiteLandmarks(session)
% Full-volume paired landmark editor; writes the upstream LightSuite format.
% Stored coordinates remain [AP DV ML timestamp] on the original, oriented
% sample grid and fixed atlas grid. Display contrast never changes these data.
s=session;assert(s.orientationConfirmed,'Confirm orientation before placing landmarks.');
p=s.opts.permute_sample_to_atlas;
sample=permute(single(s.opts.sample),abs(p));
for d=1:3,if p(d)<0,sample=flip(sample,d);end,end
atlas=s.opts.atlas;volumes={sample,atlas};
resolution={s.opts.sample_res(abs(p)),s.opts.atlas_res};
points={zeros(0,4),zeros(0,4)};pending=[];dirty=false;selected=[];view=1;mode=1;
indices=[round(size(sample,1)/2) round(size(atlas,1)/2)];
file=fullfile(s.opts.savepath,'control_points_minimal.mat');backedUp=false;
readOnly=isfile(fullfile(s.opts.savepath,'transform_params.mat'));
if isfile(file)
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
limits={[0 1],[0 1]};
% The vascular atlas is a published intensity template, not raw probe data.
% Keep its native linear window; Mask Editor enhancement is sample-only.
atlasValues=atlas(isfinite(atlas));
atlasLimits=double([min(atlasValues(:)) max(atlasValues(:))]);
if isempty(atlasLimits)||atlasLimits(2)<=atlasLimits(1),atlasLimits=[0 1];end
fig=figure('Name','deConfUSIon | LightSuite paired landmarks','NumberTitle','off', ...
    'Color',[.035 .045 .045],'MenuBar','none','ToolBar','none','Position',[80 60 1220 850], ...
    'WindowKeyPressFcn',@key,'WindowScrollWheelFcn',@scroll,'CloseRequestFcn',@closeWindow);
setappdata(fig,'deConfUSIonNoMaximize',true);setappdata(fig,'LightSuiteLandmarkEditor',true);
uicontrol(fig,'Style','text','Units','normalized','Position',[.025 .865 .95 .11], ...
    'String',{'MATCH THE SAME ANATOMICAL FEATURE: 1. Choose slices independently below each image.  2. Click your sample on the left.  3. Click the matching atlas feature on the right.', ...
    'Use recognizable vessel bifurcations and the midline. Spread pairs across AP, DV and ML; do not select all points in one plane. Save before fitting.', ...
    'Mouse wheel over either image changes THAT image''s slice. Left/right arrows: sample. Up/down arrows: atlas. Esc: cancel pending point. S: save.'}, ...
    'HorizontalAlignment','left','FontSize',12);
plane=uicontrol(fig,'Style','popupmenu','Units','normalized','Position',[.025 .805 .27 .045], ...
    'String',{'Coronal: AP slices','Horizontal: DV slices','Sagittal: ML slices'},'Callback',@changePlane,'Tag','LightSuiteLandmarkPlane');
modeControl=uicontrol(fig,'Style','popupmenu','Units','normalized','Position',[.31 .805 .25 .045], ...
    'String',{'Mark matching points','Inspect: zoom','Inspect: pan'},'Callback',@changeMode,'Tag','LightSuiteLandmarkMode');
contrast=uicontrol(fig,'Style','popupmenu','Units','normalized','Position',[.575 .805 .17 .045], ...
    'String',{'Anatomy: Mask Editor','Anatomy: vessels','Anatomy: full range'},'Callback',@changeContrast, ...
    'TooltipString','Changes your anatomy only. The vascular atlas always uses its original linear intensity range.');
uicontrol(fig,'Style','pushbutton','Units','normalized','Position',[.755 .805 .055 .045], ...
    'String','Help','Callback',@(~,~)fusiLightSuiteLandmarkHelp());
uicontrol(fig,'Style','pushbutton','Units','normalized','Position',[.825 .805 .15 .045], ...
    'String','Save pairs (S)','Callback',@(~,~)savePairs(),'Tag','LightSuiteLandmarkSave');
ax=gobjects(1,2);imageHandle=gobjects(1,2);slider=gobjects(1,2);number=gobjects(1,2);sliceLabel=gobjects(1,2);
names={'YOUR SAMPLE','VASCULAR ATLAS'};
for createSide=1:2
    left=.025+(createSide-1)*.50;
    ax(createSide)=axes(fig,'Units','normalized','Position',[left .36 .45 .39]);
    imageHandle(createSide)=imagesc(ax(createSide),zeros(2));colormap(ax(createSide),gray(256));axis(ax(createSide),'image');
    ax(createSide).YDir='reverse';ax(createSide).XTick=[];ax(createSide).YTick=[];
    set(imageHandle(createSide),'ButtonDownFcn',@(~,~)clickImage(createSide),'Tag',sprintf('LightSuiteLandmarkImage%d',createSide));
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
uicontrol(fig,'Style','text','Units','normalized','Position',[.025 .195 .61 .025], ...
    'String','PAIR        SAMPLE [AP DV ML]                         ATLAS [AP DV ML]', ...
    'HorizontalAlignment','left','FontSize',10);
% A native listbox keeps the unused viewport dark too; classic UITable leaves
% its empty Java viewport white even when row BackgroundColor is dark.
pairList=uicontrol(fig,'Style','listbox','Units','normalized','Position',[.025 .065 .61 .13], ...
    'String',{'No paired landmarks yet.'},'FontSize',11,'Callback',@selectPair,'Tag','LightSuiteLandmarkPairs');
uicontrol(fig,'Style','pushbutton','Units','normalized','Position',[.665 .165 .31 .05], ...
    'String','Delete selected pair / undo last','Callback',@deletePair);
uicontrol(fig,'Style','pushbutton','Units','normalized','Position',[.665 .108 .31 .05], ...
    'String','Cancel pending sample point (Esc)','Callback',@cancelPending);
uicontrol(fig,'Style','pushbutton','Units','normalized','Position',[.665 .05 .31 .05], ...
    'String','Save and close','Callback',@saveAndClose);
status=uicontrol(fig,'Style','text','Units','normalized','Position',[.025 .004 .95 .037], ...
    'String','','FontSize',11,'HorizontalAlignment','left','Tag','LightSuiteLandmarkStatus');
fusiLightSuiteStyle(fig);pairList.FontName='Consolas';updateImages(true);updateTable();updateStatus();
    function lim=displayLimits(V,q)
        values=double(V(isfinite(V)&V>0));
        if isempty(values),lim=[0 1];else,lim=quantile(values,q);end
        if lim(2)<=lim(1),lim(2)=lim(1)+1;end
    end
    function changePlane(~,~)
        view=plane.Value;
        for side=1:2,indices(side)=round(size(volumes{side},view)/2);end
        updateImages(true);
    end
    function changeMode(~,~)
        mode=modeControl.Value;zoom(fig,'off');pan(fig,'off');
        if mode==2,zoom(fig,'on');elseif mode==3,pan(fig,'on');end
        updateStatus();
    end
    function changeContrast(~,~)
        choices={[.01 .995],[.05 .98],[0 1]};q=choices{contrast.Value};
        limits{1}=displayLimits(volumes{1},q);
        updateImages(false);
    end
    function setSlice(side,value)
        if ~isfinite(value),number(side).String=num2str(indices(side));return;end
        indices(side)=max(1,min(size(volumes{side},view),round(value)));updateImages(false);
    end
    function step(side,delta),setSlice(side,indices(side)+delta);end
    function scroll(~,event)
        % Hit testing alone misses the letterboxed margin and text/controls
        % around an image. Use the pointer's figure coordinates for each panel.
        cursor=get(fig,'CurrentPoint');bounds=getpixelposition(fig);xy=cursor./bounds(3:4);
        if xy(2)<.24||xy(2)>.79,return;end
        if xy(1)>=.025&&xy(1)<=.475,step(1,event.VerticalScrollCount);
        elseif xy(1)>=.525&&xy(1)<=.975,step(2,event.VerticalScrollCount);end
    end
    function updateImages(reset)
        remaining=setdiff(1:3,view,'stable');axisNames={'AP','DV','ML'};
        for side=1:2
            V=volumes{side};n=size(V,view);indices(side)=max(1,min(n,indices(side)));
            sub={':',':',':'};sub{view}=indices(side);image=squeeze(V(sub{:}));
            if side==2
                imageLimits=atlasLimits;
            elseif contrast.Value==1
                % Use the same native coronal display as Mask Editor before
                % selecting another orientation; stored data/points stay raw.
                if side==1
                    nativeAxis=abs(p(view));nativeIndex=indices(side);
                    if p(view)<0,nativeIndex=size(s.opts.sample,nativeAxis)-nativeIndex+1;end
                    nativeSub={':',':',':'};nativeSub{nativeAxis}=nativeIndex;
                    nativeImage=squeeze(s.opts.sample(nativeSub{:}));
                    nativeImage=fusiStandardDopplerDisplay(nativeImage);
                    % Display enhancement must follow the same axis permutation
                    % and flips as the raw plane used to place coordinates.
                    nativeRemaining=setdiff(1:3,nativeAxis,'stable');
                    desired=abs(p(remaining));[~,order]=ismember(desired,nativeRemaining);
                    image=permute(nativeImage,order);
                    for imageDim=1:2,if p(remaining(imageDim))<0,image=flip(image,imageDim);end,end
                end
                imageLimits=[0 1];
            else,imageLimits=limits{side};end
            set(imageHandle(side),'CData',image,'XData',[1 size(image,2)],'YData',[1 size(image,1)]);
            ax(side).CLim=imageLimits;res=resolution{side};ax(side).DataAspectRatio=[1 res(remaining(2))/res(remaining(1)) 1];
            if reset,ax(side).XLim=[.5 size(image,2)+.5];ax(side).YLim=[.5 size(image,1)+.5];end
            set(slider(side),'Max',max(2,n),'Value',indices(side),'SliderStep',[1/max(1,n-1) min(1,10/max(1,n-1))]);
            number(side).String=num2str(indices(side));
            sliceLabel(side).String=sprintf('%s | %s slice %d / %d | %.4g mm per slice',names{side},axisNames{view},indices(side),n,res(view));
            title(ax(side),names{side},'Color',[.8 .96 .88],'FontSize',13);
            drawPoints(side,remaining);
        end
        drawnow limitrate;
    end
    function drawPoints(side,remaining)
        delete(findall(ax(side),'Tag','LightSuitePairMarker'));P=points{side};
        visible=find(abs(P(:,view)-indices(side))<=.5);hold(ax(side),'on');
        for index=visible(:)'
            color=[.3 1 .65];if isequal(selected,index),color=[1 .72 .2];end
            plot(ax(side),P(index,remaining(2)),P(index,remaining(1)),'o','Color',color, ...
                'LineWidth',1.5,'MarkerSize',8,'Tag','LightSuitePairMarker','HitTest','off','PickableParts','none');
            text(ax(side),P(index,remaining(2))+1,P(index,remaining(1)),num2str(index), ...
                'Color',color,'BackgroundColor',[0 0 0],'Margin',1,'FontWeight','bold', ...
                'Tag','LightSuitePairMarker','HitTest','off','PickableParts','none');
        end
        if side==1&&~isempty(pending)&&abs(pending(view)-indices(1))<=.5
            plot(ax(1),pending(remaining(2)),pending(remaining(1)),'+','Color',[1 .7 .15], ...
                'LineWidth',2,'MarkerSize',16,'Tag','LightSuitePairMarker','HitTest','off','PickableParts','none');
        end
        hold(ax(side),'off');
    end
    function clickImage(side)
        if mode~=1||readOnly,return;end
        cursor=ax(side).CurrentPoint;xy=cursor(1,1:2);remaining=setdiff(1:3,view,'stable');V=volumes{side};
        if any(xy<.5)||xy(1)>size(V,remaining(2))+.5||xy(2)>size(V,remaining(1))+.5,return;end
        P=zeros(1,4);P(view)=indices(side);P(remaining)=[xy(2) xy(1)];P(4)=now;
        if side==1
            if ~isempty(pending),status.String='Complete the pending pair on the atlas, or press Esc to cancel it first.';return;end
            pending=P;
        else
            if isempty(pending),status.String='First click a recognizable anatomical feature in YOUR SAMPLE (left).';return;end
            points{1}(end+1,:)=pending;points{2}(end+1,:)=P;pending=[];dirty=true;selected=size(points{1},1);updateTable();
        end
        updateImages(false);updateStatus();
    end
    function updateTable()
        rows=cell(size(points{1},1),1);
        for k=1:numel(rows),rows{k}=sprintf('%3d    %-32s    %s',k,mat2str(points{1}(k,1:3),5),mat2str(points{2}(k,1:3),5));end
        if isempty(rows),rows={'No pairs yet. Mark the sample first, then the matching atlas feature.'};end
        pairList.Value=1;pairList.String=rows;
    end
    function selectPair(src,~)
        if isempty(points{1}),return;end
        selected=src.Value;view=1;plane.Value=1;
        indices=[round(points{1}(selected,1)) round(points{2}(selected,1))];updateImages(true);updateStatus();
    end
    function deletePair(~,~)
        if readOnly,return;end
        if ~isempty(pending),cancelPending();return;end
        if isempty(points{1}),return;end
        index=selected;if isempty(index),index=size(points{1},1);end
        points{1}(index,:)=[];points{2}(index,:)=[];selected=[];dirty=true;
        updateTable();updateImages(false);updateStatus();
    end
    function cancelPending(varargin),pending=[];updateImages(false);updateStatus();end
    function updateStatus()
        n=size(points{1},1);ready=n>=5;
        if ready,ready=rank(points{1}(:,1:3)-mean(points{1}(:,1:3),1))==3&&rank(points{2}(:,1:3)-mean(points{2}(:,1:3),1))==3;end
        detail='Need at least 5 pairs spanning AP, DV and ML; more well-distributed pairs improve coverage.';
        if ready,detail='3D landmark spread passes the minimum numerical requirement. Anatomical accuracy still needs review.';end
        if readOnly,detail='Read-only: this project already has a fitted transform. Use a new project for different landmarks.';
        elseif ~isempty(pending),detail='Sample point pending: navigate the ATLAS to the same feature, then click it to complete this pair.';
        elseif mode~=1,detail='Inspect mode: zoom/pan the images. Choose Mark matching points to add a pair.';end
        status.String=sprintf('%d paired landmarks | %s',n,detail);
    end
    function ok=savePairs()
        ok=false;
        if isfile(fullfile(s.opts.savepath,'transform_params.mat')),readOnly=true;end
        if readOnly,status.String='This fitted project is read-only. Use a new project for a different fit.';return;end
        if ~isempty(pending),status.String='Finish the pending sample/atlas pair or press Esc before saving.';return;end
        if isfile(file)&&~backedUp
            backup=[file '.before_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))];
            [copied,message]=copyfile(file,backup);if ~copied,status.String=['Backup failed: ' message];return;end
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
        [moved,message]=movefile(temporary,file,'f');if ~moved,status.String=['Could not save: ' message];return;end
        dirty=false;ok=true;status.String=sprintf('Saved %d complete pairs. You can continue editing or return to Fit affine + B-spline.',size(points{1},1));
    end
    function saveAndClose(~,~)
        if readOnly,delete(fig);elseif savePairs(),delete(fig);end
    end
    function closeWindow(~,~)
        if readOnly||(~dirty&&isempty(pending)),delete(fig);return;end
        choice=fusiLightSuiteChoice('Save landmark changes?', ...
            'The source recording and atlas are unchanged. Only complete matched pairs can be saved.', ...
            {'Save and close','Discard unsaved edits','Keep editing'});
        if strcmp(choice,'Save and close'),saveAndClose();
        elseif strcmp(choice,'Discard unsaved edits'),delete(fig);end
    end
    function key(~,event)
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
