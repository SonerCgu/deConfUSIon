function fig=fusiLightSuiteAnatomyReview(session,result)
% Display anatomy as anatomy, never as a signed percent-change map.
% Contrast/opacity affect graphics only; saved mapped values are unchanged.
atlas=session.opts.atlas;anatomy=result.vreg;
assert(isequal(size(atlas,[1 2 3]),size(anatomy,[1 2 3])), ...
    'Mapped anatomy and vascular atlas must share the atlas grid.');
valid=isfinite(anatomy)&anatomy>0;
atlasValues=atlas(isfinite(atlas));lim=double([min(atlasValues(:)) max(atlasValues(:))]);
if isempty(lim)||lim(2)<=lim(1),lim=[0 1];end
index=zeros(1,3);
for d=1:3
    other=setdiff(1:3,d);counts=squeeze(sum(sum(valid,other(1)),other(2)));
    slices=find(counts>0);if isempty(slices),index(d)=round(size(atlas,d)/2);else,index(d)=round(median(slices));end
end
fig=figure('Name','deConfUSIon | LightSuite mapped anatomy review','NumberTitle','off', ...
    'MenuBar','none','ToolBar','none','Color',[.035 .045 .045], ...
    'Position',[80 90 1260 740],'WindowScrollWheelFcn',@scroll);
setappdata(fig,'LightSuiteMappedAnatomyReview',true);
uicontrol(fig,'Style','text','Units','normalized','Position',[.025 .895 .95 .085], ...
    'String',{'REGISTERED ANATOMY ON THE VASCULAR ATLAS', ...
    'Gray: original linear atlas. Cyan: enhanced acquired anatomy. Black / transparent: no acquired positive anatomy. Compare vessel alignment and field-of-view coverage.'}, ...
    'FontSize',12,'HorizontalAlignment','left');
mode=uicontrol(fig,'Style','popupmenu','Units','normalized','Position',[.025 .82 .29 .055], ...
    'String',{'Overlay: anatomy + atlas','Vascular atlas only','Registered anatomy only'}, ...
    'FontSize',12,'Callback',@(~,~)render());
uicontrol(fig,'Style','text','Units','normalized','Position',[.35 .825 .14 .04], ...
    'String','Anatomy opacity','FontSize',12,'HorizontalAlignment','left');
opacity=uicontrol(fig,'Style','slider','Units','normalized','Position',[.49 .835 .23 .025], ...
    'Min',0,'Max',1,'Value',.65,'Callback',@(~,~)render(),'Tag','LightSuiteMappedOpacity');
uicontrol(fig,'Style','pushbutton','Units','normalized','Position',[.76 .82 .215 .055], ...
    'String','Open project folder','Callback',@(~,~)winopen(session.opts.savepath));
uicontrol(fig,'Style','text','Units','normalized','Position',[.025 .775 .13 .03], ...
    'String','Atlas contrast','HorizontalAlignment','left');
atlasGain=uicontrol(fig,'Style','slider','Units','normalized','Position',[.16 .785 .24 .02], ...
    'Min',.4,'Max',3,'Value',1,'Callback',@(~,~)render(),'Tag','LightSuiteMappedAtlasContrast');
uicontrol(fig,'Style','text','Units','normalized','Position',[.45 .775 .17 .03], ...
    'String','Anatomy contrast','HorizontalAlignment','left');
anatomyGain=uicontrol(fig,'Style','slider','Units','normalized','Position',[.63 .785 .24 .02], ...
    'Min',.4,'Max',3,'Value',1,'Callback',@(~,~)render(),'Tag','LightSuiteMappedAnatomyContrast');
axesHandles=gobjects(1,3);images=gobjects(1,3);sliders=gobjects(1,3);numbers=gobjects(1,3);labels=gobjects(1,3);
names={'Coronal / AP','Horizontal / DV','Sagittal / ML'};
for d=1:3
    left=.025+(d-1)*.325;
    axesHandles(d)=axes(fig,'Units','normalized','Position',[left .25 .30 .51]);
    images(d)=image(axesHandles(d),zeros(2,2,3,'single'));axis(axesHandles(d),'image');
    set(axesHandles(d),'XTick',[],'YTick',[],'YDir','reverse');
    labels(d)=uicontrol(fig,'Style','text','Units','normalized','Position',[left .19 .30 .04], ...
        'String','','FontSize',12);
    sliders(d)=uicontrol(fig,'Style','slider','Units','normalized','Position',[left .15 .23 .025], ...
        'Min',1,'Max',max(2,size(atlas,d)),'Value',index(d), ...
        'SliderStep',[1/max(1,size(atlas,d)-1) min(1,10/max(1,size(atlas,d)-1))], ...
        'Callback',@(src,~)setSlice(d,src.Value),'Tag',sprintf('LightSuiteMappedSlice%d',d));
    numbers(d)=uicontrol(fig,'Style','edit','Units','normalized','Position',[left+.24 .137 .06 .05], ...
        'String',num2str(index(d)),'Callback',@(src,~)setSlice(d,str2double(src.String)));
end
uicontrol(fig,'Style','text','Units','normalized','Position',[.025 .025 .95 .08], ...
    'String',{'Scroll over a panel, drag its slider, or type a slice number. No percent-change scale is applied to anatomy.', ...
    'Next: export native region labels in the workspace. Use the original recording with those labels in SCM / Video / FC; anatomy_in_atlas.mat is an anatomical QC result, not a warped functional recording.'}, ...
    'HorizontalAlignment','left','FontSize',12);
fusiLightSuiteStyle(fig);fusiLightSuiteLabelWindow(fig,session);render();
    function setSlice(d,value)
        if isfinite(value),index(d)=max(1,min(size(atlas,d),round(value)));end
        render();
    end
    function scroll(~,event)
        cursor=get(fig,'CurrentPoint');bounds=getpixelposition(fig);xy=cursor./bounds(3:4);
        if xy(2)<.13||xy(2)>.79,return;end
        d=floor((xy(1)-.025)/.325)+1;
        if d>=1&&d<=3,setSlice(d,index(d)+event.VerticalScrollCount);end
    end
    function render()
        for dim=1:3
            sub={':',':',':'};sub{dim}=index(dim);
            A=single(squeeze(atlas(sub{:})));B=single(squeeze(anatomy(sub{:})));
            inside=isfinite(B)&B>0;A(~isfinite(A))=0;
            A=min(1,max(0,(A-lim(1))/(lim(2)-lim(1))*atlasGain.Value));
            % Background zeros and missing acquisition stay transparent.
            B=min(1,fusiStandardDopplerDisplay(B)*anatomyGain.Value);B(~inside)=0;
            if mode.Value==2,rgb=repmat(A,1,1,3);
            elseif mode.Value==3,rgb=repmat(B,1,1,3);
            else
                alpha=opacity.Value*sqrt(B).*single(inside);
                rgb=repmat(A.*(1-alpha),1,1,3)+cat(3,.18*B,B,.82*B).*alpha;
            end
            set(images(dim),'CData',rgb,'XData',[1 size(A,2)],'YData',[1 size(A,1)]);
            set(axesHandles(dim),'XLim',[.5 size(A,2)+.5],'YLim',[.5 size(A,1)+.5]);
            remaining=setdiff(1:3,dim);res=session.opts.atlas_res;
            axesHandles(dim).DataAspectRatio=[1 res(remaining(2))/res(remaining(1)) 1];
            title(axesHandles(dim),names{dim},'Color',[.82 .94 .89],'FontSize',13);
            labels(dim).String=sprintf('Slice %d / %d',index(dim),size(atlas,dim));
            sliders(dim).Value=index(dim);numbers(dim).String=num2str(index(dim));
        end
        drawnow limitrate;
    end
end
