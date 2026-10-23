function selection=fusiGeometricMaskDialog(U,seed,options)
% Preview/edit a geometric mask without changing the Mask Editor on cancel.
% The preview uses native coordinates and the editor's visual orientation.
selection=[];shape=size(U,[1 2 3]);nY=shape(1);nX=shape(2);nZ=shape(3);
assert(isequal(size(seed,[1 2 3]),shape),'deConfUSIon:RectanglePreview','Anatomy and proposal must match.');
if nargin<3,options=struct();end
if ~isfield(options,'validSlices'),options.validSlices=reshape(any(any(seed,1),2),1,[]);end
if ~isfield(options,'restriction'),options.restriction=[];end
if ~isfield(options,'slice'),options.slice=ceil(nZ/2);end
if ~isfield(options,'flipUD'),options.flipUD=true;end
if ~isfield(options,'aspect'),options.aspect=[1 1 1];end
if ~isfield(options,'inset'),options.inset=0;end
if ~isfield(options,'target'),options.target='brain / underlay';end
if ~isfield(options,'label'),options.label='';end
if ~isfield(options,'shape'),options.shape='rectangle';end
if ~isfield(options,'followSlices'),options.followSlices=nZ>1 && ~isempty(strfind(lower(options.target),'overlay'));end
validSlices=logical(reshape(options.validSlices,1,[]));
[~,proposal]=fusiGeometricMaskVolume(seed,[],options.restriction,validSlices);
bounds=proposal.bounds;inferred=~isempty(bounds);
if isempty(bounds),bounds=[1 nX 1 nY];end
z=max(1,min(nZ,round(options.slice)));inset=options.inset;busy=false;cachedZ=NaN;baseRGB=[];
fixedBounds=bounds;
[autoBounds,sliceReport]=fusiSliceMaskBounds(seed,validSlices);
missing=any(~isfinite(autoBounds),2);autoBounds(missing,:)=repmat(bounds,nnz(missing),1);
sliceBounds=autoBounds;followSlices=logical(options.followSlices) && nZ>1;
if followSlices,bounds=fromPosition(toPosition(sliceBounds(z,:)));end
C=deConfUSIon_ui('palette');
f=figure('Name',['Auto mask preview - ' options.label],'Tag','FUSIGeometricMaskDialog', ...
    'NumberTitle','off','MenuBar','none','ToolBar','none','Color',C.background,'InvertHardcopy','off', ...
    'Units','pixels','Position',[150 90 1060 760],'WindowStyle','modal', ...
    'CloseRequestFcn',@cancel,'WindowScrollWheelFcn',@scroll);
guard=onCleanup(@()deleteDialog(f)); %#ok<NASGU>
ctrl('text',['Auto mask: ' options.target],[.035 .94 .93 .04],[]);
ctrl('text','Drag the blue box or enter bounds. Follow slice size adapts the shape as you scroll.', ...
    [.035 .89 .93 .04],[]);
ax=axes('Parent',f,'Units','normalized','Position',[.035 .19 .68 .67]);
im=image(ax,zeros(nY,nX,3));im.Tag='RectanglePreviewImage';
axis(ax,'image');axis(ax,'off');
if options.flipUD,ax.YDir='reverse';else,ax.YDir='normal';end
ax.XLim=[.5 nX+.5];ax.YLim=[.5 nY+.5];ax.DataAspectRatio=options.aspect;
hold(ax,'on');
shapeControl=ctrl('popupmenu',{'Rectangle (straight edges)','Ellipse (rounded)'},[.75 .83 .215 .04],@refresh);
shapeControl.Tag='GeometricShape';shapeControl.Value=1+strcmp(options.shape,'ellipse');
followControl=ctrl('checkbox','Follow slice size',[.75 .79 .215 .03],@toggleFollow);
followControl.Value=double(followSlices);followControl.Tag='GeometricFollowSlices';
followControl.TooltipString='Fit each slice to its own Doppler envelope. Resizing the current box adjusts the other slices proportionally.';
if nZ==1,followControl.Enable='off';end
edits=gobjects(1,4);labels={'Left','Right','Top','Bottom'};
if ~options.flipUD,labels(3:4)={'Bottom','Top'};end
for k=1:4
    yy=.74-(k-1)*.06;
    ctrl('text',labels{k},[.75 yy .11 .035],[]);
    edits(k)=ctrl('edit',num2str(bounds(k)),[.87 yy .095 .04],@editBounds);
    edits(k).Tag=['RectangleBound' num2str(k)];
end
sliceLabel=ctrl('text','',[.75 .515 .215 .03],[]);
sliceSlider=ctrl('slider','',[.75 .475 .215 .025],@browse);
set(sliceSlider,'Min',1,'Max',max(2,nZ),'Value',z,'SliderStep',[1 1]/max(1,nZ-1));
sliceSlider.Tag='RectangleSlice';if nZ==1,sliceSlider.Enable='off';end
ctrl('text','Apply to',[.75 .435 .215 .035],[]);
scope=ctrl('popupmenu',{'All slices (same shape)','Current slice only'},[.75 .39 .215 .04],@refresh);
scope.Tag='RectangleScope';if nZ==1,scope.Value=2;scope.Enable='off';end
ctrl('text','Inset edges (voxels)',[.75 .32 .215 .035],[]);
insetEdit=ctrl('edit',num2str(inset),[.75 .28 .10 .04],@editInset);insetEdit.Tag='RectangleInset';
if isempty(options.restriction),restrictionText={'Weak signal inside the','shape stays included.'};
else,restrictionText={'Clipped to the brain mask.','Its holes stay excluded.'};end
ctrl('text',restrictionText,[.75 .17 .215 .085],[]);
status=ctrl('text','',[.035 .085 .93 .075],[]);status.Tag='RectangleStatus';
cancelBtn=ctrl('pushbutton','Cancel',[.68 .025 .12 .05],@cancel);cancelBtn.Tag='RectangleCancel';
apply=ctrl('pushbutton','Apply mask',[.82 .025 .145 .05],@accept);
apply.BackgroundColor=C.success;apply.FontWeight='bold';apply.Tag='RectangleApply';
% Modern ROI handles provide interactive edge/corner resizing. Older MATLAB
% falls back to imrect; without either, the numeric bounds remain editable.
roi=[];listeners={};
pos=toPosition(bounds);
if exist('drawrectangle','file')==2
    roi=drawrectangle(ax,'Position',pos,'Color',[.2 .7 1],'LineWidth',1.5,'FaceAlpha',0);
    roi.Tag='RectangleROI';
    roi.Deletable=false;roi.DrawingArea=[.5 .5 nX nY];
    listeners{1}=addlistener(roi,'MovingROI',@roiMoved);
    listeners{2}=addlistener(roi,'ROIMoved',@roiSnapped);
elseif exist('imrect','file')==2
    roi=imrect(ax,pos);setColor(roi,[.2 .7 1]); %#ok<IMRECT>
    setPositionConstraintFcn(roi,makeConstrainToRectFcn('imrect',[.5 nX+.5],[.5 nY+.5]));
    addNewPositionCallback(roi,@legacyMoved);
else
    roi=rectangle(ax,'Position',pos,'EdgeColor',[.2 .7 1],'LineWidth',1.5);
end
refresh();setappdata(f,'FUSIGeometricMaskReady',true);uiwait(f);
deleteDialog(f);

    function h=ctrl(style,label,pos,callback)
        h=uicontrol(f,'Style',style,'String',label,'Units','normalized','Position',pos, ...
            'FontName','Arial','FontSize',11,'ForegroundColor',C.text, ...
            'BackgroundColor',C.background,'HorizontalAlignment','left');
        if ~isempty(callback),h.Callback=callback;end
    end
    function pos=toPosition(b)
        pos=[b(1)-.5 b(3)-.5 b(2)-b(1)+1 b(4)-b(3)+1];
    end
    function b=fromPosition(pos)
        b=round([pos(1)+.5 pos(1)+pos(3)-.5 pos(2)+.5 pos(2)+pos(4)-.5]);
        b(1:2)=min(nX,max(1,b(1:2)));b(3:4)=min(nY,max(1,b(3:4)));
        b(2)=max(b(1),b(2));b(4)=max(b(3),b(4));
    end
    function editBounds(~,~)
        b=arrayfun(@(e)str2double(e.String),edits);
        if any(~isfinite(b)) || b(1)>b(2) || b(3)>b(4)
            syncEdits();return;
        end
        setEditedBounds(fromPosition(toPosition(b)));syncROI();refresh();
    end
    function editInset(~,~)
        value=str2double(insetEdit.String);
        if isfinite(value),inset=max(0,round(value));end
        refresh();
    end
    function syncEdits()
        for j=1:4,edits(j).String=num2str(bounds(j));end
    end
    function syncROI()
        busy=true;cleanup=onCleanup(@release); %#ok<NASGU>
        if isa(roi,'imrect'),setPosition(roi,toPosition(bounds));
        else,roi.Position=toPosition(bounds);end
    end
    function release(),busy=false;end
    function boxes=scaleBoxes(boxes,old,new)
        oldCenter=[mean(old(1:2)) mean(old(3:4))];newCenter=[mean(new(1:2)) mean(new(3:4))];
        factor=[diff(new(1:2))+1 diff(new(3:4))+1]./[diff(old(1:2))+1 diff(old(3:4))+1];
        center=[mean(boxes(:,1:2),2) mean(boxes(:,3:4),2)];
        span=[boxes(:,2)-boxes(:,1)+1 boxes(:,4)-boxes(:,3)+1].*factor;
        center=(center-oldCenter).*factor+newCenter;
        boxes=[center(:,1)-(span(:,1)-1)/2 center(:,1)+(span(:,1)-1)/2 ...
            center(:,2)-(span(:,2)-1)/2 center(:,2)+(span(:,2)-1)/2];
    end
    function setEditedBounds(b)
        if followSlices
            sliceBounds=scaleBoxes(sliceBounds,sliceBounds(z,:),b);
        else
            fixedBounds=b;
        end
        bounds=b;
    end
    function toggleFollow(src,~)
        followSlices=logical(src.Value);
        if followSlices,sliceBounds=scaleBoxes(autoBounds,autoBounds(z,:),bounds);
        else,fixedBounds=bounds;end
        syncROI();refresh();
    end
    function roiMoved(~,evt)
        if busy,return;end
        setEditedBounds(fromPosition(evt.CurrentPosition));refresh();
    end
    function roiSnapped(~,evt)
        roiMoved([],evt);syncROI();
    end
    function legacyMoved(pos)
        if busy,return;end
        setEditedBounds(fromPosition(pos));refresh();
    end
    function browse(src,~),z=round(src.Value);showSlice();end
    function scroll(~,evt)
        z=max(1,min(nZ,z+sign(evt.VerticalScrollCount)));showSlice();
    end
    function showSlice()
        if followSlices,bounds=fromPosition(toPosition(sliceBounds(z,:)));else,bounds=fixedBounds;end
        syncROI();refresh();
    end
    function slices=selectedSlices()
        if scope.Value==2,slices=z;else,slices=1:nZ;end
    end
    function b=insetBounds(b)
        if nargin==0,b=bounds;end
        amount=min(inset,floor(min([diff(b(1:2)) diff(b(3:4))])/2));
        b=b+[amount -amount amount -amount];insetEdit.String=num2str(inset);
    end
    function shapeMode=selectedShape()
        modes={'rectangle','ellipse'};shapeMode=modes{shapeControl.Value};
    end
    function refresh(~,~)
        b=insetBounds();syncEdits();sliceSlider.Value=z;
        if followSlices,scope.String={'All slices (follow size)','Current slice only'};
        else,scope.String={'All slices (same shape)','Current slice only'};end
        sliceLabel.String=sprintf('Preview slice %d / %d',z,nZ);
        if cachedZ~=z
            plane=double(U(:,:,z));finite=isfinite(plane);values=plane(finite);
            if isempty(values),plane(:)=0;
            else
                limits=prctile(values,[2 99.5]);span=diff(limits);
                plane=min(1,max(0,(plane-limits(1))/max(eps,span)));plane(~finite)=0;
                plane=sqrt(plane);
            end
            baseRGB=repmat(plane,1,1,3);cachedZ=z;
        end
        restriction=[];if ~isempty(options.restriction),restriction=options.restriction(:,:,z);end
        m=fusiGeometricMaskVolume(seed(:,:,z),b,restriction,validSlices(z),selectedShape());
        rgb=baseRGB;green=[.15 1 .3];
        edge=m & conv2(double(m),ones(3),'same')<9;
        for c=1:3
            channel=rgb(:,:,c);channel(m)=.82*channel(m)+.18*green(c);channel(edge)=green(c);rgb(:,:,c)=channel;
        end
        im.CData=rgb;slices=selectedSlices();
        usable=nnz(validSlices(slices));
        if usable==0,apply.Enable='off';else,apply.Enable='on';end
        info=sprintf('%d x %d voxels; %d slice(s). Scroll to review before applying.', ...
            diff(b(1:2))+1,diff(b(3:4))+1,usable);
        if ~validSlices(z),info=[info ' This slice has no usable Doppler and will stay empty.'];end
        if followSlices
            info=[info ' Size follows each slice.'];
            if sliceReport.unresolvedSlices(z),info=[info ' No local outline: adjust this box manually.'];end
        end
        if ~inferred,info=['No boundary detected: adjust the full-image box manually. ' info];end
        status.String=info;drawnow limitrate;
    end
    function accept(~,~)
        slices=selectedSlices();if ~any(validSlices(slices)),return;end
        outerBoxes=repmat(fixedBounds,nZ,1);if followSlices,outerBoxes=sliceBounds;end
        boxes=outerBoxes;
        for zz=1:nZ
            outerBoxes(zz,:)=fromPosition(toPosition(outerBoxes(zz,:)));
            boxes(zz,:)=insetBounds(outerBoxes(zz,:));
        end
        selection=struct('bounds',insetBounds(),'outerBounds',bounds, ...
            'inset',inset,'slices',slices,'previewSlice',z,'shape',selectedShape(), ...
            'boundsBySlice',boxes,'outerBoundsBySlice',outerBoxes,'followSlices',followSlices, ...
            'sliceBoundsReport',sliceReport);
        uiresume(f);
    end
    function cancel(~,~),selection=[];uiresume(f);end
end

function deleteDialog(f)
if isgraphics(f),delete(f);end
end
