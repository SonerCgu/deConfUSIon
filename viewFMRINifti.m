function fig = viewFMRINifti(path)
% Independent NIfTI viewer: never changes Studio/fUSI state or colormaps.
deConfUSIon_setup();
[V,info]=readFMRINifti(path);
sz=size(V); sz(end+1:4)=1;
spacing=double(info.PixelDimensions); spacing(end+1:3)=1;
spacing(~isfinite(spacing)|spacing<=0)=1;
index=max(1,round(sz/2));
v=V(isfinite(V));
if isempty(v), limits=[0 1]; else, limits=double([min(v) max(v)]); end
signed=limits(1)<0 && limits(2)>0;
if signed
    % Robust display limits reveal the map without changing stored values.
    nz=sort(abs(double(v(v~=0))));
    limits=[-1 1]*nz(max(1,ceil(.98*numel(nz))));
end
support=isfinite(V(:,:,:,index(4))) & V(:,:,:,index(4))~=0;
if any(support(:))
    [x,y,z]=ind2sub(sz(1:3),find(support));
    index(1:3)=round(([min(x) min(y) min(z)]+[max(x) max(y) max(z)])/2);
end
if limits(1)==limits(2), limits=limits+[-.5 .5]; end
[~,name,ext]=fileparts(path);
fig=figure('Name',['NIfTI volume | ' name ext],'NumberTitle','off', ...
    'Color',[.12 .12 .12],'Position',[100 100 1200 650],'Tag','FMRINiftiViewer');
ax=gobjects(1,3); im=gobjects(1,3);
for a=1:3
    ax(a)=axes('Parent',fig,'Position',[.04+(a-1)*.325 .27 .28 .62], ...
        'Color','k','XColor','w','YColor','w');
    im(a)=imagesc(ax(a),zeros(2)); axis(ax(a),'image');
    set(ax(a),'YDir','normal','Color','k','XColor','w','YColor','w');
    caxis(ax(a),limits); cb=colorbar(ax(a)); set(cb,'Color','w');
    uicontrol(fig,'Style','slider','Units','normalized', ...
        'Position',[.04+(a-1)*.325 .15 .28 .04],'Min',1,'Max',max(2,sz(a)), ...
        'Value',index(a),'SliderStep',[1/max(1,sz(a)-1) min(1,10/max(1,sz(a)-1))], ...
        'Enable',onOff(sz(a)>1),'Callback',@(src,~)move(a,src));
end
if signed
    c=linspace(0,1,128)'; colormap(fig,[c c ones(128,1);ones(128,1) flipud(c) flipud(c)]);
else, colormap(fig,gray(256)); end
uicontrol(fig,'Style','text','Units','normalized','Position',[.02 .92 .96 .06], ...
    'String',sprintf('Native voxel axes (not anatomical labels) | %s | %s',info.SpaceUnits,path), ...
    'BackgroundColor',[.12 .12 .12],'ForegroundColor','w');
uicontrol(fig,'Style','text','Units','normalized','Position',[.02 .04 .20 .04], ...
    'String','Display range (min max):','BackgroundColor',[.12 .12 .12],'ForegroundColor','w');
uicontrol(fig,'Style','edit','Units','normalized','Position',[.22 .04 .23 .04], ...
    'String',sprintf('%.6g %.6g',limits),'Callback',@setRange);
if sz(4)>1
    uicontrol(fig,'Style','slider','Units','normalized','Position',[.55 .04 .40 .04], ...
        'Min',1,'Max',sz(4),'Value',index(4),'SliderStep',[1/(sz(4)-1) min(1,10/(sz(4)-1))], ...
        'Callback',@(src,~)move(4,src));
else
    uicontrol(fig,'Style','pushbutton','Units','normalized','Position',[.60 .04 .30 .05], ...
        'String','Open in SCM','Tag','NiftiOpenSCM','Callback',@(~,~)openNiftiSCM(path));
end
setappdata(fig,'NiftiInfo',info); setappdata(fig,'SourceFile',path);
drawSlices();
    function move(a,src)
        index(a)=min(sz(a),max(1,round(get(src,'Value')))); drawSlices();
    end
    function drawSlices()
        planes={squeeze(V(index(1),:,:,index(4)))', ...
            squeeze(V(:,index(2),:,index(4)))',V(:,:,index(3),index(4))'};
        dims={[2 3],[1 3],[1 2]};
        for b=1:3
            d=dims{b};
            alpha=isfinite(planes{b});
            if signed, alpha=alpha & planes{b}~=0; end
            set(im(b),'CData',planes{b},'AlphaData',double(alpha),'XData',[0 (sz(d(1))-1)*spacing(d(1))], ...
                'YData',[0 (sz(d(2))-1)*spacing(d(2))]);
            axis(ax(b),'image');
            xlabel(ax(b),sprintf('Voxel axis %d (%s)',d(1),info.SpaceUnits));
            ylabel(ax(b),sprintf('Voxel axis %d (%s)',d(2),info.SpaceUnits));
            title(ax(b),sprintf('Axis %d: %d/%d | volume %d/%d',b,index(b),sz(b),index(4),sz(4)),'Color','w');
        end
    end
    function setRange(src,~)
        r=sscanf(get(src,'String'),'%f');
        if numel(r)==2 && all(isfinite(r)) && r(2)>r(1)
            limits=r(:)'; for b=1:3, caxis(ax(b),limits); end
        else, set(src,'String',sprintf('%.6g %.6g',limits)); end
    end
end
function s=onOff(tf)
if tf, s='on'; else, s='off'; end
end
