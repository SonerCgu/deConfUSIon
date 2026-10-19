function fig=fusiLightSuiteRegistrationReview(session,onDecision)
% Interactive anatomical review, independent of whether the inverse is valid.
if nargin<2,onDecision=[];end
volumes=fusiLightSuiteReviewVolumes(session);
shape=size(volumes.sample);index=max(1,round(shape/2));
sampleLimits=limits(volumes.sample);atlasLimits=limits([volumes.atlas{1}(:);volumes.atlas{2}(:)]);
planeNames={'Coronal / AP','Horizontal (axial) / DV','Sagittal / ML'};
stageNames={'AFFINE','AFFINE + B-SPLINE'};axisNames={'AP','DV','ML'};
fig=figure('Name','deConfUSIon | Interactive LightSuite registration review', ...
    'NumberTitle','off','Color',[.035 .045 .045],'MenuBar','none','ToolBar','figure', ...
    'Position',[65 65 1320 890],'WindowScrollWheelFcn',@scroll,'WindowKeyPressFcn',@key);
guard=fusiLightSuitePaths(session.config);setappdata(fig,'LightSuitePathGuard',guard);
label([.025 .925 .95 .055],['Compare the SAME slice: sample in gray, registered vascular atlas in cyan. ' ...
    'Solid colored lines are atlas region boundaries, not landmarks.']);
view=control('popupmenu',[.025 .86 .22 .045], ...
    [planeNames {'All three planes'}],@(~,~)render(),'LightSuiteReviewPlane');
mode=control('popupmenu',[.26 .86 .22 .045], ...
    {'Vessel overlay','Boundary overlay','Checkerboard','Sample only','Atlas only'},@(~,~)render(),'LightSuiteReviewMode');
boundaries=control('checkbox',[.50 .86 .15 .045],'Region boundaries',@(~,~)render(),'LightSuiteReviewBoundaries');boundaries.Value=1;
colors=control('popupmenu',[.66 .86 .13 .045],{'Yellow','White','Magenta','Cyan'},@(~,~)render(),'LightSuiteReviewColor');
width=control('popupmenu',[.80 .86 .08 .045],{'1 px','2 px','3 px'},@(~,~)render(),'LightSuiteReviewWidth');width.Value=2;
control('pushbutton',[.89 .86 .085 .045],'Help',@helpReview,'LightSuiteReviewHelp');
label([.025 .80 .13 .035],'Atlas opacity');
opacity=slider([.15 .812 .22 .023],0,1,.55,@(~,~)render(),'LightSuiteReviewOpacity');
label([.41 .80 .15 .035],'Sample contrast');
contrast=slider([.56 .812 .20 .023],.4,2.5,1,@(~,~)render(),'LightSuiteReviewContrast');
control('pushbutton',[.80 .79 .175 .045],'Reset display / zoom',@resetDisplay,'LightSuiteReviewReset');
ax=gobjects(2,3);images=gobjects(2,3);sliceSliders=gobjects(1,3);sliceNumbers=gobjects(1,3);sliceLabels=gobjects(1,3);
for rowIndex=1:2
    for planeIndex=1:3
        ax(rowIndex,planeIndex)=axes(fig,'Units','normalized','Visible','off');
        images(rowIndex,planeIndex)=image(ax(rowIndex,planeIndex),zeros(2,2,3,'single'));
        set(ax(rowIndex,planeIndex),'YDir','reverse','XTick',[],'YTick',[]);axis(ax(rowIndex,planeIndex),'image');
    end
end
for planeIndex=1:3
    left=.025+(planeIndex-1)*.325;
    sliceLabels(planeIndex)=label([left .235 .30 .033],'');
    sliceSliders(planeIndex)=slider([left .21 .22 .022],1,max(2,shape(planeIndex)),index(planeIndex), ...
        @(src,~)setSlice(planeIndex,src.Value),sprintf('LightSuiteReviewSlice%d',planeIndex));
    sliceSliders(planeIndex).SliderStep=[1/max(1,shape(planeIndex)-1) min(1,10/max(1,shape(planeIndex)-1))];
    sliceNumbers(planeIndex)=control('edit',[left+.23 .195 .07 .045],num2str(index(planeIndex)), ...
        @(src,~)setSlice(planeIndex,str2double(src.String)),sprintf('LightSuiteReviewIndex%d',planeIndex));
end
status=control('edit',[.025 .095 .95 .085], ...
    'Checking forward/inverse consistency. Please wait...',[],'LightSuiteReviewStatus');
set(status,'Max',4,'Min',0,'Enable','inactive','HorizontalAlignment','left','FontSize',11);
accept=control('pushbutton',[.025 .025 .27 .055],'Accept reviewed fit',@(~,~)perform('accept'),'LightSuiteReviewAccept');accept.Enable='off';
rebuild=control('pushbutton',[.31 .025 .25 .055],'Rebuild inverse + recheck',@(~,~)perform('repair'),'LightSuiteReviewRepair');
reject=control('pushbutton',[.575 .025 .14 .055],'Do not accept',@(~,~)perform('reject'),'LightSuiteReviewReject');
recheck=control('pushbutton',[.73 .025 .12 .055],'Recheck',@(~,~)check,'LightSuiteReviewRecheck');
control('pushbutton',[.865 .025 .11 .055],'Close',@(~,~)delete(fig),'LightSuiteReviewClose');
fusiLightSuiteStyle(fig);render();check();

    function h=control(style,pos,text,callback,tag)
        h=uicontrol(fig,'Style',style,'Units','normalized','Position',pos,'String',text, ...
            'FontSize',11,'Callback',callback,'Tag',tag);
    end
    function h=label(pos,text)
        h=uicontrol(fig,'Style','text','Units','normalized','Position',pos,'String',text, ...
            'FontSize',11,'HorizontalAlignment','left');
    end
    function h=slider(pos,lo,hi,value,callback,tag)
        h=uicontrol(fig,'Style','slider','Units','normalized','Position',pos, ...
            'Min',lo,'Max',hi,'Value',value,'Callback',callback,'Tag',tag);
    end
    function setSlice(dim,value)
        if isfinite(value),index(dim)=min(shape(dim),max(1,round(value)));end
        render();
    end
    function resetDisplay(~,~)
        opacity.Value=.55;contrast.Value=1;mode.Value=1;boundaries.Value=1;width.Value=2;render();
    end
    function scroll(~,event)
        cursor=get(fig,'CurrentPoint');bounds=getpixelposition(fig);xy=cursor./bounds(3:4);
        for dim=1:3
            for stage=1:2
                p=ax(stage,dim).Position;
                if strcmp(ax(stage,dim).Visible,'on')&&xy(1)>=p(1)&&xy(1)<=sum(p([1 3]))&&xy(2)>=p(2)&&xy(2)<=sum(p([2 4]))
                    setSlice(dim,index(dim)+event.VerticalScrollCount);return;
                end
            end
        end
    end
    function key(~,event)
        if view.Value>3,return;end
        if any(strcmp(event.Key,{'rightarrow','uparrow'})),setSlice(view.Value,index(view.Value)+1);
        elseif any(strcmp(event.Key,{'leftarrow','downarrow'})),setSlice(view.Value,index(view.Value)-1);end
    end
    function render()
        allPlanes=view.Value==4;
        for dim=1:3
            active=allPlanes||view.Value==dim;
            sliceSliders(dim).Enable=onoff(active);sliceNumbers(dim).Enable=onoff(active);
            sliceSliders(dim).Value=index(dim);sliceNumbers(dim).String=num2str(index(dim));
            sliceLabels(dim).String=sprintf('%s: %d / %d',planeNames{dim},index(dim),shape(dim));
            for stage=1:2
                axis(ax(stage,dim),'off');ax(stage,dim).Visible='off';images(stage,dim).Visible=onoff(active);
                if ~active,ax(stage,dim).Title.Visible='off';continue;end
                if allPlanes,pos=[.035+(dim-1)*.325 .55-(stage-1)*.255 .285 .205];
                else,pos=[.04+(stage-1)*.49 .32 .43 .42];end
                ax(stage,dim).Position=pos;ax(stage,dim).Visible='on';
                S=normalize(slice(volumes.sample,dim),sampleLimits,contrast.Value);
                A=normalize(slice(volumes.atlas{stage},dim),atlasLimits,1);
                L=slice(volumes.labels{stage},dim);
                gray=repmat(S,1,1,3);cyan=cat(3,.10*A,A,.90*A);
                switch mode.Value
                    case 1,alpha=opacity.Value*sqrt(A);rgb=gray.*(1-alpha)+cyan.*alpha;
                    case 2,rgb=gray;
                    case 3
                        [r,c]=ndgrid(1:size(S,1),1:size(S,2));tile=mod(floor((r-1)/20)+floor((c-1)/20),2)==0;
                        rgb=gray.*tile+repmat(A,1,1,3).*(~tile);
                    case 4,rgb=gray;
                    case 5,rgb=repmat(A,1,1,3);
                end
                if boundaries.Value
                    edge=false(size(L));
                    edge(2:end,:)=L(2:end,:)~=L(1:end-1,:);
                    edge(:,2:end)=edge(:,2:end)|L(:,2:end)~=L(:,1:end-1);
                    edge=edge&(L>0);
                    if width.Value>1,edge=imdilate(edge,ones(width.Value));end
                    palette=[1 .9 .05;1 1 1;1 .2 .85;.1 1 1];color=palette(colors.Value,:);
                    for channel=1:3,C=rgb(:,:,channel);C(edge)=color(channel);rgb(:,:,channel)=C;end
                end
                set(images(stage,dim),'CData',rgb,'XData',[1 size(S,2)],'YData',[1 size(S,1)]);
                set(ax(stage,dim),'XLim',[.5 size(S,2)+.5],'YLim',[.5 size(S,1)+.5],'XTick',[],'YTick',[],'YDir','reverse');
                remaining=setdiff(1:3,dim);if dim==3,remaining=fliplr(remaining);end
                res=volumes.spacingMm;ax(stage,dim).DataAspectRatio=[1 res(remaining(2))/res(remaining(1)) 1];
                title(ax(stage,dim),sprintf('%s | %s | slice %d',stageNames{stage},planeNames{dim},index(dim)), ...
                    'Color',[.85 .95 .9],'FontSize',12,'Visible','on');
                xlabel(ax(stage,dim),[axisNames{remaining(2)} ' (columns)']);ylabel(ax(stage,dim),[axisNames{remaining(1)} ' (rows)']);
            end
        end
        setappdata(fig,'LightSuiteReviewIndices',index);drawnow limitrate;
    end
    function S=slice(V,dim)
        sub={':',':',':'};sub{dim}=index(dim);S=squeeze(V(sub{:}));
        if dim==3,S=S';end % sagittal: DV vertical, AP horizontal
    end
    function check()
        if ~isgraphics(fig),return;end
        status.String='Checking numerical consistency...';accept.Enable='off';drawnow;
        report=fusiLightSuite('inspectfit',session);
        if ~isgraphics(fig),return;end
        setappdata(fig,'LightSuiteReviewValidation',report);
        if report.passed
            accept.Enable='on';status.ForegroundColor=[.6 1 .7];status.String=report.message;
        else
            status.ForegroundColor=[1 .8 .45];status.String=[report.message ' Rebuild the inverse and recheck. If this still fails, revise landmarks / geometry and refit in a new project.'];
        end
    end
    function perform(action)
        if isequal(getappdata(fig,'LightSuiteReviewBusy'),true),return;end
        setappdata(fig,'LightSuiteReviewBusy',true);set([accept rebuild reject recheck],'Enable','off');fig.Pointer='watch';
        cleanup=onCleanup(@()releaseReview(fig,[rebuild reject recheck])); %#ok<NASGU>
        try
            switch action
                case 'accept'
                    session=fusiLightSuite('review',session,true);
                    message='Fit accepted after numerical checks and your anatomical review. Mapping and native-label export are available.';
                case 'reject'
                    session=fusiLightSuite('review',session,false);
                    message='Fit not accepted. Revise landmarks / geometry in a new project, then refit and review.';
                case 'repair'
                    status.String='Building a separate inverse candidate. The saved inverse is replaced only after it passes.';drawnow;
                    session=fusiLightSuite('repairinverse',session,@progress);
                    message='Inverse rebuilt and passed the unchanged numerical limits. Inspect the anatomy before accepting.';
            end
            if isa(onDecision,'function_handle'),onDecision(session,message);end
            if ~isgraphics(fig),return;end
            if strcmp(action,'repair'),check();status.String=[message ' ' status.String];
            else,status.String=message;accept.Enable='off';end
        catch ME
            if ~isgraphics(fig),return;end
            setappdata(fig,'LightSuiteLastError',ME);accept.Enable='off';
            status.ForegroundColor=[1 .8 .45];status.String=[ME.message ' Acceptance / mapping remain blocked until checks pass. Inspect geometry / landmarks or revise in a new project.'];
            % Keep this window and current slices open; no uncaught callback.
        end
    end
    function progress(~,message),if isgraphics(status),status.String=message;drawnow;end,end
    function helpReview(~,~)
        help=figure('Name','How to review a LightSuite fit','NumberTitle','off', ...
            'MenuBar','none','ToolBar','none','Position',[190 100 920 680]);
        uicontrol(help,'Style','text','Units','normalized','Position',[.04 .13 .92 .82], ...
            'HorizontalAlignment','left','FontSize',13,'String',{ ...
            '1. Select Coronal, Horizontal/axial or Sagittal. Scroll over an image, drag its slice slider or type a slice number. Both stages show the same slice.'; ...
            '2. Compare the acquired vessels (gray) with registered atlas vessels (cyan). Use opacity, contrast, checkerboard or sample/atlas-only views. Use the toolbar to zoom / pan.'; ...
            '3. Solid region outlines show anatomical parcels. Change their color / width or turn them off to inspect vessel alignment. Region lines alone do not prove a correct fit.'; ...
            '4. Inspect several slices through acquired coverage in ALL THREE planes. Coronal and axial views are useful, but sagittal views reveal AP/DV mismatch, distorted shape and over-warping.'; ...
            '5. Numerical consistency means forward then inverse returns to the same point. It is separate from anatomical accuracy. A failed check blocks acceptance and mapping.'; ...
            '6. Rebuild inverse + recheck can repair inverse optimization. If checks still fail, do not accept: revise geometry / landmark pairs and fit a new project. Close keeps the previous decision.'});
        uicontrol(help,'Style','pushbutton','Units','normalized','Position',[.73 .035 .23 .065], ...
            'String','Close','Callback',@(~,~)delete(help));fusiLightSuiteStyle(help);
    end
end

function lim=limits(V)
v=single(V(isfinite(V)&V>0));if isempty(v),lim=[0 1];else,lim=double(quantile(v,[.03 .995]));end
if lim(2)<=lim(1),lim=[lim(1) lim(1)+1];end
end
function S=normalize(S,lim,gain)
S=single(S);S(~isfinite(S))=0;S=min(1,max(0,(S-lim(1))/(lim(2)-lim(1))*gain));
end
function str=onoff(value)
if value,str='on';else,str='off';end
end
function releaseReview(window,buttons)
if ~isgraphics(window),return;end
setappdata(window,'LightSuiteReviewBusy',false);window.Pointer='arrow';
set(buttons(isgraphics(buttons)),'Enable','on');
end
