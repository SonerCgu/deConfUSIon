function fig=SCM_static_gui(V,bg,par)
% Static SCM mode: spatial measurements only; no invented samples or TR.
deConfUSIon_setup();
assert(isnumeric(V)&&~isempty(V)&&ndims(V)<=3,'deConfUSIon:StaticDimensions','Expected a 2D/3D map.');
V=single(V); sz=size(V); sz(end+1:3)=1;
if ~isfield(par,'valueKind'), par.valueKind='intensity'; end
units='intensity'; if strcmp(par.valueKind,'percent'), units='%'; end
if ~isfield(par,'sourceFile'), par.sourceFile=''; end
if ~isfield(par,'axisPermutation'), par.axisPermutation=[2 1 3]; end
if ~isempty(bg), assert(isequal(size(bg),size(V)),'deConfUSIon:UnderlayGrid','Underlay must match the map grid.'); end
z=max(1,round(sz(3)/2)); rois=struct([]); boxes=gobjects(0); underlayFile='';
occupied=find(any(reshape(isfinite(V)&V~=0,[],sz(3)),1));
if ~isempty(occupied), z=occupied(ceil(numel(occupied)/2)); end
v=double(V(isfinite(V)&V~=0)); if isempty(v), v=0; end
lim=[min(v) max(v)];
if lim(1)<0
    a=sort(abs(v)); lim=[-1 1]*a(max(1,ceil(.98*numel(a))));
end
if diff(lim)==0, lim=lim+[-.5 .5]; end
fig=figure('Name','SCM Viewer | static NIfTI','NumberTitle','off','Tag','SCMStaticViewer', ...
    'Color',[.08 .08 .08],'Position',[80 80 1240 780]);
ax=axes(fig,'Position',[.05 .29 .60 .63]);
h=imagesc(ax,V(:,:,z)); axis(ax,'image'); set(ax,'Color','k','XColor','w','YColor','w');
colormap(ax,gray(256)); cb=colorbar(ax); cb.Color='w'; cb.Label.String=units;
set(h,'ButtonDownFcn',@clickROI);
ctl('text',[.69 .92 .29 .04],['Static map (' units ') | no time dimension'],[]);
ctl('text',[.69 .855 .13 .035],'Slice',[]);
slice=ctl('slider',[.82 .855 .14 .035],'',@redraw);
set(slice,'Min',1,'Max',max(2,sz(3)),'Value',z,'SliderStep',[1/max(1,sz(3)-1) min(1,10/max(1,sz(3)-1))]);
if sz(3)==1, set(slice,'Enable','off'); end
ctl('text',[.69 .80 .13 .035],'Range min max',[]);
range=ctl('edit',[.82 .80 .14 .035],sprintf('%g %g',lim),@redraw);
ctl('text',[.69 .745 .13 .035],['Threshold |' units '|'],[]);
threshold=ctl('edit',[.82 .745 .14 .035],'0',@redraw);
ctl('text',[.69 .69 .13 .035],'Overlay alpha',[]);
alpha=ctl('slider',[.82 .69 .14 .035],'',@redraw); set(alpha,'Value',1);
ctl('text',[.69 .635 .13 .035],'Colormap',[]);
cmap=ctl('popupmenu',[.82 .635 .14 .035],{'Gray','Blackbody','Signed'},@redraw);
if strcmp(par.valueKind,'percent'), set(cmap,'Value',3); end
ctl('text',[.69 .58 .13 .035],'ROI width (px)',[]);
width=ctl('edit',[.82 .58 .14 .035],'5',[]);
ctl('text',[.69 .525 .13 .035],'ROI center X Y',[]);
xy=ctl('edit',[.82 .525 .14 .035],'',[]);
add=ctl('pushbutton',[.69 .475 .27 .04],'Add ROI (or click image)',@addROI); set(add,'Tag','StaticSCMAddROI');
set(xy,'Tag','StaticSCMROICenter'); set(width,'Tag','StaticSCMROIWidth');
ctl('pushbutton',[.69 .42 .27 .04],'Load aligned NIfTI underlay',@loadUnderlay);
ctl('pushbutton',[.69 .365 .27 .04],'Export map + ROI bundle (MAT)',@exportBundle);
ctl('pushbutton',[.69 .31 .27 .04],'Export ROI statistics (CSV)',@exportROI);
ctl('pushbutton',[.69 .255 .27 .04],'Export SCM image (PNG)',@exportImage);
if ~isempty(par.sourceFile)
    ctl('pushbutton',[.69 .10 .27 .04],'Open three-plane viewer',@(~,~)viewFMRINifti(par.sourceFile));
end
[~,sourceName,sourceExt]=fileparts(par.sourceFile);
status=ctl('text',[.04 .945 .62 .035],[sourceName sourceExt],[]);
set(status,'TooltipString',par.sourceFile);
ctl('text',[.69 .17 .27 .075], ...
    'ROI statistics use original values. Temporal processing needs the original 4D series.',[]);
table=uitable(fig,'Units','normalized','Position',[.04 .03 .61 .19], ...
    'ColumnName',{'ROI','Slice','X0','X1','Y0','Y1','N','Mean','Median','SD','Min','Max'}, ...
    'Data',cell(0,12));
setappdata(fig,'StaticMap',V); setappdata(fig,'StaticMapMetadata',par);
redraw();
    function c=ctl(style,pos,str,callback)
        c=uicontrol(fig,'Style',style,'Units','normalized','Position',pos,'String',str, ...
            'BackgroundColor',[.16 .16 .16],'ForegroundColor','w','FontSize',11);
        if ~isempty(callback), set(c,'Callback',callback); end
    end
    function redraw(varargin)
        z=min(sz(3),max(1,round(get(slice,'Value'))));
        r=sscanf(get(range,'String'),'%f'); th=str2double(get(threshold,'String'));
        if numel(r)~=2||any(~isfinite(r))||r(2)<=r(1)||~isfinite(th)||th<0
            set(status,'String','Enter an increasing display range and a nonnegative threshold.'); return;
        end
        lim=r(:)'; cm=gray(256);
        if get(cmap,'Value')==2, cm=blackbdy_iso(256);
        elseif get(cmap,'Value')==3
            q=linspace(0,1,128)'; cm=[q q ones(128,1);ones(128,1) flipud(q) flipud(q)];
        end
        M=double(V(:,:,z)); valid=isfinite(M)&abs(M)>th;
        ix=1+round(255*max(0,min(1,(M-lim(1))/diff(lim)))); ix(~isfinite(ix))=1;
        rgb=reshape(cm(ix(:),:),[sz(1:2) 3]);
        base=zeros(sz(1:2));
        if ~isempty(bg)
            B=double(bg(:,:,z)); b=B(isfinite(B));
            if ~isempty(b), base=(B-min(b))/max(eps,max(b)-min(b)); base(~isfinite(base))=0; end
        end
        a=double(valid)*get(alpha,'Value');
        rgb=bsxfun(@times,rgb,a)+repmat(base.*(1-a),1,1,3);
        set(h,'CData',rgb); colormap(ax,cm); caxis(ax,lim);
        title(ax,sprintf('Static SCM | slice %d/%d | %s',z,sz(3),units),'Color','w');
        xlabel(ax,sprintf('X / column (voxel axis %d)',par.axisPermutation(2)));
        ylabel(ax,sprintf('Y / row (voxel axis %d)',par.axisPermutation(1)));
        if isfield(par,'niftiInfo')
            sp=par.niftiInfo.PixelDimensions;
            sp(end+1:3)=1; sp(~isfinite(sp)|sp<=0)=1;
            daspect(ax,[sp(par.axisPermutation(1)) sp(par.axisPermutation(2)) 1]);
        end
        delete(boxes(isgraphics(boxes))); boxes=gobjects(0);
        for k=1:numel(rois)
            aroi=rois(k); if aroi.slice~=z, continue; end
            boxes(end+1)=rectangle(ax,'Position',[aroi.x0-.5 aroi.y0-.5 aroi.x1-aroi.x0+1 aroi.y1-aroi.y0+1], ...
                'EdgeColor','g','LineWidth',1.5,'HitTest','off'); %#ok<AGROW>
        end
        setappdata(fig,'StaticROIs',rois);
    end
    function clickROI(~,~)
        p=get(ax,'CurrentPoint'); set(xy,'String',sprintf('%g %g',round(p(1,1:2)))); addROI();
    end
    function addROI(varargin)
        try
            r=scmStaticROI(V,z,sscanf(get(xy,'String'),'%f')',str2double(get(width,'String')));
            if isempty(rois), rois=r; else, rois(end+1)=r; end
            rows=cell(numel(rois),12);
            for k=1:numel(rois), rows(k,:)=[{k} struct2cell(rois(k))']; end
            set(table,'Data',rows); redraw();
        catch ME, set(status,'String',ME.message); end
    end
    function loadUnderlay(~,~)
        [f,p]=uigetfile({'*.nii;*.nii.gz','NIfTI underlay'},'Choose underlay on the SAME spatial grid',fileparts(par.sourceFile));
        if isequal(f,0), return; end
        try
            [B,ni]=readFMRINifti(fullfile(p,f));
            assert(ndims(B)<=3,'deConfUSIon:UnderlayGrid','Choose a static underlay.');
            B=permute(B,par.axisPermutation);
            assert(isequal(size(B),size(V)),'deConfUSIon:UnderlayGrid','Different dimensions: register/resample the underlay to the map grid first.');
            if isfield(par,'niftiInfo')
                original=par.niftiInfo;
                assert(strcmp(ni.SpaceUnits,original.SpaceUnits)&& ...
                    max(abs(ni.Transform.T(:)-original.Transform.T(:)))<1e-5, ...
                    'deConfUSIon:UnderlayGrid','Spatial transforms differ: register the underlay to the map grid first.');
            end
            bg=B; underlayFile=fullfile(p,f); set(alpha,'Value',.7); redraw();
        catch ME, errordlg(ME.message,'Underlay'); end
    end
    function exportBundle(~,~)
        [f,p]=uiputfile('*.mat','Export static SCM bundle','StaticSCM.mat'); if isequal(f,0), return; end
        StaticSCM=struct('schemaVersion',1,'domain','static-spatial','map',V,'underlay',bg, ...
            'underlayFile',underlayFile,'metadata',par,'axes',{{'Y','X','Z'}},'rois',rois, ...
            'displayRange',lim,'threshold',str2double(get(threshold,'String'))); %#ok<NASGU>
        save(fullfile(p,f),'StaticSCM','-v7.3');
    end
    function exportROI(~,~)
        if isempty(rois), set(status,'String','Add an ROI first.'); return; end
        [f,p]=uiputfile('*.csv','Export static ROI statistics','StaticROI.csv'); if isequal(f,0), return; end
        T=struct2table(rois); T.units=repmat({units},height(T),1); T.sourceFile=repmat({par.sourceFile},height(T),1);
        T.rowVoxelAxis=repmat(par.axisPermutation(1),height(T),1);
        T.columnVoxelAxis=repmat(par.axisPermutation(2),height(T),1);
        T.sliceVoxelAxis=repmat(par.axisPermutation(3),height(T),1);
        writetable(T,fullfile(p,f));
    end
    function exportImage(~,~)
        [f,p]=uiputfile('*.png','Export SCM image','StaticSCM.png'); if isequal(f,0), return; end
        exportgraphics(ax,fullfile(p,f),'Resolution',300,'BackgroundColor','black');
    end
end
