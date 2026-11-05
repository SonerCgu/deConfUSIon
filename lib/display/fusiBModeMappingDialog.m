function selection=fusiBModeMappingDialog(rgb,shape,metadata,getDoppler,initial)
% Review montage crop, panel order and explicit Doppler slice correspondence.
selection=[];details=[];candidate=[];
if nargin<5||isempty(initial)
    if size(rgb,4)==1
        initial=fusiBModeMontageLayout(rgb,shape(3),metadata);
        if initial.rows*initial.cols==1,initial=struct('kind','planes','sliceIndices',1);end
    else
        initial=struct('kind','planes','sliceIndices',1:min(size(rgb,4),shape(3)));
    end
end
if strcmp(initial.kind,'planes')
    initial.rows=1;initial.cols=1;initial.trim=0;initial.count=size(rgb,4);
    initial.bounds=[1 1 size(rgb,2) size(rgb,1)];initial.order='row-major';
    initial.sliceIndices(end+1:initial.count)=0;
end
screen=get(0,'ScreenSize');width=min(1320,max(640,screen(3)-100));height=min(860,max(480,screen(4)-100));
f=figure('Name','Map B-mode panels to Doppler slices','NumberTitle','off','MenuBar','none', ...
    'ToolBar','none','Color',[.08 .09 .11],'Units','pixels','Position',[50 50 width height], ...
    'WindowStyle','modal','CloseRequestFcn',@cancel,'Visible','on','Tag','SCM_BModeMappingDialog');
guard=onCleanup(@()deleteIfValid(f));
movegui(f,'center');
axSource=axes('Parent',f,'Units','normalized','Position',[.03 .36 .44 .58]);
axB=axes('Parent',f,'Units','normalized','Position',[.53 .62 .19 .30]);
axD=axes('Parent',f,'Units','normalized','Position',[.77 .62 .19 .30]);
set(axD,'Tag','SCM_BModeDopplerPreview');
axBlend=axes('Parent',f,'Units','normalized','Position',[.62 .36 .27 .23]);
set([axB axD axBlend],'NextPlot','replacechildren','YDir','reverse');
label('Panel to inspect',[.53 .29 .15 .035]);
popPanel=control('popupmenu',{'1'},[.68 .29 .28 .035],@preview);
set(popPanel,'Tag','SCM_BModeMappingPanel');
label('Rows',[.03 .24 .045 .035]);ebRows=edit(num2str(initial.rows),[.075 .24 .055 .035]);
label('Columns',[.145 .24 .065 .035]);ebCols=edit(num2str(initial.cols),[.21 .24 .055 .035]);
label('Panels',[.28 .24 .055 .035]);ebCount=edit(num2str(initial.count),[.335 .24 .055 .035]);
label('Trim (px)',[.405 .24 .065 .035]);ebTrim=edit(num2str(initial.trim),[.47 .24 .045 .035]);
popKind=control('popupmenu',{'Montage panels','Individual image planes'},[.55 .24 .20 .035],@kindChanged);
set(popKind,'Value',1+strcmp(initial.kind,'planes'));
popOrder=control('popupmenu',{'Left to right, then down','Top to bottom, then right'},[.77 .24 .20 .035],@changed);
set(popOrder,'Value',1+strcmp(initial.order,'column-major'));
label('Image area: left top right bottom',[.03 .18 .24 .035]);
ebBounds=edit(sprintf('%d %d %d %d',initial.bounds),[.27 .18 .30 .035]);
label('Image area excludes axes, labels and outer margins.',[.59 .18 .38 .035]);
label('Doppler slice for each panel (0 = skip)',[.03 .12 .29 .035]);
ebSlices=edit(formatIndices(initial.sliceIndices),[.32 .12 .65 .035]);
set(ebSlices,'Tag','SCM_BModeSliceAssignments');
status=label('',[.03 .025 .69 .075]);set(status,'ForegroundColor',[1 .82 .35]);
apply=control('pushbutton','Apply mapping',[.74 .035 .11 .045],@accept);
set(apply,'Tag','SCM_BModeMappingApply');
control('pushbutton','Cancel',[.87 .035 .10 .045],@cancel);
if size(rgb,4)>1,set(popKind,'Enable','off');end
update();setappdata(f,'FUSIBModeMappingReady',true);uiwait(f);deleteIfValid(f);

    function h=label(text,position)
        h=uicontrol(f,'Style','text','String',text,'Units','normalized','Position',position, ...
            'BackgroundColor',[.08 .09 .11],'ForegroundColor','w','HorizontalAlignment','left','FontSize',10);
    end
    function h=control(style,text,position,callback)
        h=uicontrol(f,'Style',style,'String',text,'Units','normalized','Position',position, ...
            'BackgroundColor',[.20 .22 .25],'ForegroundColor','w','FontSize',10,'Callback',callback);
    end
    function h=edit(text,position)
        h=control('edit',text,position,@changed);set(h,'HorizontalAlignment','left');
    end
    function changed(~,~),update();end
    function kindChanged(~,~)
        if get(popKind,'Value')==1
            seed=fusiBModeMontageLayout(rgb,shape(3),metadata);
            set(ebRows,'String',num2str(seed.rows));set(ebCols,'String',num2str(seed.cols));
            set(ebCount,'String',num2str(seed.count));set(ebTrim,'String',num2str(seed.trim));
            set(ebBounds,'String',sprintf('%d %d %d %d',seed.bounds));set(popOrder,'Value',1);
            indices=seed.sliceIndices;
        else
            count=size(rgb,4);set(ebCount,'String',num2str(count));indices=zeros(1,count);
            n=min(count,shape(3));indices(1:n)=1:n;
        end
        set(ebSlices,'String',formatIndices(indices));update();
    end
    function ok=update()
        ok=false;
        try
            montage=get(popKind,'Value')==1;enabled='off';if montage,enabled='on';end
            set([ebRows ebCols ebCount ebTrim ebBounds popOrder],'Enable',enabled);
            if montage
                order='row-major';if get(popOrder,'Value')==2,order='column-major';end
                candidate=struct('kind','montage','rows',str2double(get(ebRows,'String')), ...
                    'cols',str2double(get(ebCols,'String')),'count',str2double(get(ebCount,'String')), ...
                    'trim',str2double(get(ebTrim,'String')),'bounds',parseIndices(get(ebBounds,'String')), ...
                    'order',order,'sliceIndices',parseIndices(get(ebSlices,'String')));
            else
                candidate=struct('kind','planes','sliceIndices',parseIndices(get(ebSlices,'String')));
            end
            [~,details]=fusiMapBModeSlices(rgb,shape,candidate);
            candidate=details.selection;
            names=cell(1,details.panelCount);
            for k=1:details.panelCount
                names{k}=sprintf('Panel %d -> Doppler slice %d',k,candidate.sliceIndices(k));
                if candidate.sliceIndices(k)==0,names{k}=sprintf('Panel %d (skipped)',k);end
            end
            selected=min(get(popPanel,'Value'),numel(names));set(popPanel,'String',names,'Value',selected);
            image(axSource,rgb(:,:,:,1));axis(axSource,'image');axis(axSource,'off');hold(axSource,'on');
            if montage
                for k=1:details.panelCount
                    b=details.panelBoxes(k,:);
                    rectangle(axSource,'Position',[b(1:2) b(3:4)-b(1:2)],'EdgeColor',[.2 .9 .8],'LineWidth',.5);
                    text(axSource,b(1)+2,b(2)+2,num2str(k),'Color','y','FontSize',8,'VerticalAlignment','top');
                end
            end
            hold(axSource,'off');title(axSource,'B-mode panels and crop','Color','w');
            missing=find(~details.validSlices);
            message=sprintf('%d panels; %d/%d Doppler slices mapped. Check the crop and correspondence before applying.', ...
                details.panelCount,nnz(details.validSlices),shape(3));
            if ~isempty(missing),message=[message ' Doppler-only slices: ' formatIndices(missing) '.'];end
            set(status,'String',message);set(apply,'Enable','on');preview();ok=true;
        catch ME
            set(status,'String',ME.message);set(apply,'Enable','off');
        end
    end
    function preview(varargin)
        if isempty(details),return;end
        k=get(popPanel,'Value');z=candidate.sliceIndices(k);
        if strcmp(candidate.kind,'montage')
            b=details.panelBoxes(k,:);B=fusiResizeDisplayLayer(rgb(b(2):b(4),b(1):b(3),:),shape(1:2));
        else
            B=fusiResizeDisplayLayer(rgb(:,:,:,k),shape(1:2));
        end
        D=zeros(size(B),'single');caption='Unassigned; panel will be skipped';
        if z>0,D=single(getDoppler(z));caption=sprintf('Doppler slice %d',z);end
        show(axB,B,sprintf('B-mode panel %d',k));show(axD,D,caption);show(axBlend,.5.*B+.5.*D,'50% blend');
    end
    function show(ax,I,caption)
        image(ax,I);axis(ax,'image');axis(ax,'off');title(ax,caption,'Color','w');
    end
    function accept(~,~)
        if update(),selection=candidate;uiresume(f);end
    end
    function cancel(~,~),selection=[];uiresume(f);end
end

function indices=parseIndices(text)
tokens=regexp(strtrim(regexprep(text,'[\[\]]','')),'[,;\s]+','split');indices=[];
for k=1:numel(tokens)
    assert(~isempty(regexp(tokens{k},'^-?\d+(:-?\d+){0,2}$','once')), ...
        'deConfUSIon:BModeMapping','Use whole slice numbers or ranges such as 1:52.');
    values=sscanf(strrep(tokens{k},':',' '),'%d')';
    if numel(values)==1,v=values;
    elseif numel(values)==2
        step=1;if values(2)<values(1),step=-1;end
        assert(abs(diff(values))<=4096,'deConfUSIon:BModeMapping','Slice range is too large.');v=values(1):step:values(2);
    else
        assert(values(2)~=0&&abs((values(3)-values(1))/values(2))<=4096, ...
            'deConfUSIon:BModeMapping','Invalid slice range.');v=values(1):values(2):values(3);
    end
    indices=[indices v]; %#ok<AGROW>
    assert(numel(indices)<=4096,'deConfUSIon:BModeMapping','Too many slice numbers.');
end
end

function text=formatIndices(indices)
if numel(indices)>1&&all(diff(indices)==1),text=sprintf('%d:%d',indices(1),indices(end));
else,text=strtrim(sprintf('%d ',indices));end
end

function deleteIfValid(f)
if isgraphics(f),delete(f);end
end
