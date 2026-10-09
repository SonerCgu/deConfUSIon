function canvas=fusiVolumeWebMovieCanvas(source,state,scale)
% A compact export-only viewer avoids snapshotting controls on every frame.
% Reuse the same viewer3d volume renderer and full-resolution RGBA arrays.
rect=getpixelposition(state.scene,true);sizePx=max(2,round(rect(3:4)*scale));
movieFig=uifigure('Visible','on','Color','k','Name','3D volume movie export', ...
    'Position',[40 40 sizePx],'AutoResizeChildren','off','Tag','FUSIVolumeMovieCanvas');
complete=false;guard=onCleanup(@closeOnFailure);
original=state.viewer;volumes=original.Children;v=volumes(1);
pos=relativePosition(original.Parent);pos(3:4)=original.Position(3:4)*scale;
viewer=viewer3d(movieFig,'Units','pixels','Position',pos,'BackgroundColor','k','BackgroundGradient','off');
volume=volshow(v.Data,'Parent',viewer,'RenderingStyle',v.RenderingStyle,'AlphaData',v.AlphaData, ...
    'DataLimits',v.DataLimits,'SpecularReflectance',v.SpecularReflectance,'Transformation',v.Transformation);
viewer.Interactions='none';viewer.Denoising='off';viewer.ScaleBar='off';viewer.Box=original.Box;
viewer.SpatialUnits=original.SpatialUnits;
labels=findall(state.scene,'Type','uilabel');copies=gobjects(size(labels));
for k=1:numel(labels)
    copies(k)=uilabel(movieFig,'BackgroundColor','k','FontColor',labels(k).FontColor, ...
        'FontSize',max(8,labels(k).FontSize*scale),'FontWeight',labels(k).FontWeight, ...
        'HorizontalAlignment',labels(k).HorizontalAlignment,'WordWrap',labels(k).WordWrap);
end
images=findall(state.scene,'Type','uiimage');imageCopies=gobjects(size(images));
for k=1:numel(images)
    imageCopies(k)=uiimage(movieFig,'ImageSource',images(k).ImageSource,'ScaleMethod','stretch');
end
bars=findall(state.scene,'Tag','VolumeRulerLine');barCopies=gobjects(size(bars));
for k=1:numel(bars),barCopies(k)=uipanel(movieFig,'BackgroundColor','w','BorderType','none');end
lastFrame=[];sync();drawnow;pause(.5);drawnow;
canvas=struct('capture',@capture,'close',@closeCanvas,'figure',movieFig, ...
    'method',sprintf('Compact viewer3d canvas (%d px longest edge); full-resolution RGBA volume',max(sizePx)));
complete=true;clear guard;
    function pos=relativePosition(object)
        pos=getpixelposition(object,true);pos(1:2)=pos(1:2)-rect(1:2);pos=pos*scale;
    end
    function sync()
        if ~isvalid(source),error('deConfUSIon:ProcessingCancelled','Viewer closed during export.');end
        live=getappdata(source,'FUSIVolumeExport');key={[]};
        if isfield(live.metadata,'originalFrames'),key={live.metadata.originalFrames};end
        if ~isequal(key,lastFrame)
            volume.Data=v.Data;volume.AlphaData=v.AlphaData;lastFrame=key;
        end
        viewer.CameraPosition=original.CameraPosition;viewer.CameraTarget=original.CameraTarget;
        viewer.CameraUpVector=original.CameraUpVector;viewer.CameraZoom=original.CameraZoom;
        for j=1:numel(labels)
            h=labels(j);if ~isvalid(h),continue;end
            copies(j).Text=h.Text;copies(j).Position=relativePosition(h);copies(j).Visible=effectiveVisible(h);
        end
        for j=1:numel(images)
            imageCopies(j).Position=relativePosition(images(j));imageCopies(j).Visible=effectiveVisible(images(j));
        end
        for j=1:numel(bars)
            barCopies(j).Position=relativePosition(bars(j));barCopies(j).Visible=effectiveVisible(bars(j));
        end
    end
    function pixels=capture()
        sync();frame=getframe(movieFig);pixels=frame.cdata;
    end
    function closeCanvas()
        if isvalid(movieFig),delete(movieFig);end
    end
    function closeOnFailure()
        if ~complete,closeCanvas();end
    end
end
function value=effectiveVisible(h)
value='on';
while ~isempty(h) && isprop(h,'Visible')
    if strcmp(h.Visible,'off'),value='off';return;end
    h=h.Parent;
end
end
