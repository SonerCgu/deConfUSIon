function fig=fusiVolumeReviewAtlas(S,display)
% Orthogonal slices share one 3D transform; no independent plane alignment.
assert(isfield(S,'atlasReference'),'deConfUSIon:VolumeAtlas','Load an atlas transform first.');
fig=uifigure('Name','Atlas alignment | coronal, axial and sagittal','Color','k','Position',[80 100 1440 700]);
layout=uigridlayout(fig,[1 3],'ColumnWidth',{'1x','1x','1x'},'BackgroundColor','k');
names={'Coronal / AP','Axial / DV','Sagittal / LR'};dims=[3 1 2];
axesList=gobjects(1,3);indices=gobjects(1,3);
for plane=1:3
    panel=uipanel(layout,'Title',names{plane},'FontSize',16,'ForegroundColor','w','BackgroundColor','k');
    grid=uigridlayout(panel,[4 1],'RowHeight',{'1x',34,34,64},'BackgroundColor','k');
    imagePanel=uipanel(grid,'BorderType','none','BackgroundColor','k');imagePanel.Layout.Row=1;
    ax=uiaxes(imagePanel,'Units','normalized','Position',[.12 .12 .85 .85], ...
        'PositionConstraint','outerposition','Color','k','XColor','w','YColor','w','FontSize',13);
    n=size(S.psc,dims(plane));
    index=uieditfield(grid,'numeric','Value',round(n/2),'Limits',[1 n],'RoundFractionalValues','on');
    index.Layout.Row=2;index.FontColor='w';index.BackgroundColor='k';
    selector=uidropdown(grid,'Items',{'Doppler alignment','PSC response','Acquired coverage','Atlas anatomy'}, ...
        'FontColor','w','BackgroundColor','k','Tag',sprintf('AtlasReviewOverlay%d',plane));
    selector.Layout.Row=3;
    if ~any(S.underlayValid(:)),selector.Value='Atlas anatomy';end
    note=uilabel(grid,'Text','Atlas grayscale is reference tissue. Red Doppler and colored PSC are acquired data; coverage marks the sampled region.', ...
        'WordWrap','on','FontSize',13,'FontColor','w'); %#ok<NASGU>
    note.Layout.Row=4;
    axesList(plane)=ax;indices(plane)=index;
    index.ValueChangedFcn=@(~,~)drawPlane(ax,index.Value,plane,selector.Value);
    selector.ValueChangedFcn=@(~,~)drawPlane(ax,index.Value,plane,selector.Value);
end
drawnow nocallbacks;
for plane=1:3
    selector=findobj(fig,'Tag',sprintf('AtlasReviewOverlay%d',plane));
    drawPlane(axesList(plane),indices(plane).Value,plane,selector.Value);
end
setappdata(fig,'AtlasReviewAxes',axesList);setappdata(fig,'AtlasReviewIndices',indices);
    function drawPlane(ax,index,plane,overlay)
        u=cut(S.atlasReference,index,plane);p=cut(S.psc,index,plane);
        switch overlay
            case 'PSC response',[~,a,color]=fusiOverlayAppearance(double(p),display,1);
            case 'Doppler alignment'
                v=cut(S.underlay,index,plane);valid=cut(S.underlayValid,index,plane);
                a=.65*single(valid).*sqrt(v);color=cat(3,v,.15*v,.08*v);
            case 'Acquired coverage'
                valid=cut(S.atlasCoverageMask,index,plane);a=.35*single(valid);
                color=cat(3,zeros(size(u),'single'),ones(size(u),'single'),ones(size(u),'single'));
            otherwise,a=zeros(size(u),'single');color=zeros([size(u) 3],'single');
        end
        rgb=repmat(single(u),1,1,3).*(1-single(a))+color.*single(a);
        spacing=S.spacing;
        switch plane
            case 1,sx=spacing(2);sy=spacing(1);xl='LR';yl='DV';
            case 2,sx=spacing(2);sy=spacing(3);xl='LR';yl='AP';
            otherwise,sx=spacing(3);sy=spacing(1);xl='AP';yl='DV';
        end
        image(ax,[0 (size(rgb,2)-1)*sx],[0 (size(rgb,1)-1)*sy],rgb);
        axis(ax,'image');xlabel(ax,[xl ' (mm, atlas grid)']);ylabel(ax,[yl ' (mm, atlas grid)']);
        heading=sprintf('%s index %d | time %.4g-%.4g min',names{plane},index,S.timeSec/60);
        if isfield(S,'atlasOnly') && S.atlasOnly,heading=sprintf('%s index %d | reference atlas',names{plane},index);end
        title(ax,heading,'Color','w');
    end
end
function V=cut(V,index,plane)
switch plane
    case 1,V=V(:,:,index);
    case 2,V=squeeze(V(index,:,:))';
    otherwise,V=squeeze(V(:,index,:));
end
end
