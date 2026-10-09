function canvas=fusiVolumeMovieCanvas(source,state,showPreview)
% Native graphics canvas for surface/slab movies, avoiding web-app capture.
% Clone the actual displayed geometry/textures, camera and overlays. PSC is
% never recalculated or downsampled here. Volumes use synchronous OpenGL
% voxel-plane compositing, avoiding stale asynchronous viewer3d screenshots.
rect=getpixelposition(state.scene,true);
edge=fusiVolumeMovieEdge(source,rect(3:4));scale=edge/max(rect(3:4));
if nargin<3,showPreview=false;end
stripHeight=60*double(showPreview);
sceneSize=max(2,round(rect(3:4)*scale));
screen=get(0,'ScreenSize');oversized=any(sceneSize+[0 stripHeight]>screen(3:4)-[80 100]);captureScale=1;
if oversized
    fitEdge=min([720 (screen(3)-100)*edge/sceneSize(1) (screen(4)-160-stripHeight)*edge/sceneSize(2)]);
    captureScale=edge/max(2,fitEdge);scale=scale/captureScale;
    sceneSize=max(2,round(rect(3:4)*scale));captureScale=edge/max(sceneSize);
end
isVolume=~isempty(state.viewer) && isvalid(state.viewer);
movieFig=figure('Visible','off','Color','k','MenuBar','none','ToolBar','none', ...
    'NumberTitle','off','Name','3D movie export','Units','pixels', ...
    'Position',[40 40 sceneSize+[0 stripHeight]],'Renderer','opengl','Resize','off');
complete=false;guard=onCleanup(@closeOnFailure);
previewFig=movieFig;previewImage=[];previewAx=[];previewClock=tic;lastPreview=-Inf;
if isVolume,body=state.viewer.Parent;else,body=state.axes;end
ax=axes(movieFig,'Units','pixels','Position',relativePosition(body), ...
    'Color','k','XColor','w','YColor','w','ZColor','w');
labels=findall(state.scene,'Type','uilabel');copies=gobjects(size(labels));
for k=1:numel(labels)
    copies(k)=uicontrol(movieFig,'Style','text','Units','pixels', ...
        'BackgroundColor','k','ForegroundColor',labels(k).FontColor, ...
        'FontSize',max(8,labels(k).FontSize*scale),'FontWeight',labels(k).FontWeight, ...
        'HorizontalAlignment',labels(k).HorizontalAlignment);
end
images=findall(state.scene,'Type','uiimage');imageAxes=gobjects(size(images));imageCopies=gobjects(size(images));
for k=1:numel(images)
    imageAxes(k)=axes(movieFig,'Units','pixels','Position',relativePosition(images(k)),'Visible','off');
    imageCopies(k)=image(imageAxes(k),images(k).ImageSource);axis(imageAxes(k),'off');
end
bars=findall(state.scene,'Tag','VolumeRulerLine');barCopies=gobjects(size(bars));
for k=1:numel(bars)
    barCopies(k)=uipanel(movieFig,'Units','pixels','BackgroundColor','w','BorderType','none');
end
sourceChildren=gobjects(0);clonedChildren=gobjects(0);copyProperties={};
sync();method='Native graphics canvas; exact displayed surface/slab geometry and textures';
if isVolume,method='Synchronous OpenGL voxel-plane volume compositor; full-resolution displayed RGB/alpha';end
% Visible native GETFRAME avoids the slow hidden-figure printing path. The
% progress strip is cropped out of both files. Hidden batch callers remain
% hidden and keep the high-resolution off-screen capture fallback.
if showPreview
    if ~oversized,movieFig.Visible=source.Visible;
    else
        % Windows clips oversized visible figures. Keep the requested HD
        % canvas off screen and preview its captured pixels in a fitted
        % image window; never resize/downsample the encoded movie.
        previewScale=min([1 900/sceneSize(1) (screen(4)-180-stripHeight)/sceneSize(2)]);
        previewSize=max(2,round(sceneSize*previewScale));
        previewFig=figure('Visible',source.Visible,'Color','k','MenuBar','none','ToolBar','none', ...
            'NumberTitle','off','Position',[40 40 previewSize+[0 stripHeight]],'Resize','off');
        previewAx=axes(previewFig,'Units','pixels','Position',[1 stripHeight+1 previewSize],'Visible','off');
        previewImage=image(previewAx,zeros(2,2,3,'uint8'),'Tag','VolumeMoviePixelPreview');axis(previewAx,'image');axis(previewAx,'off');
    end
end
if captureScale>1,method=[method '; high-DPI raster capture at requested output resolution'];end
canvas=struct('capture',@capture,'close',@closeCanvas,'figure',movieFig,'method',method, ...
    'stripHeight',stripHeight,'previewFigure',previewFig,'showFrame',@showFrame);
complete=true;clear guard;
    function pos=relativePosition(object)
        pos=getpixelposition(object,true);pos(1:2)=pos(1:2)-rect(1:2);pos=pos*scale;pos(2)=pos(2)+stripHeight;
    end
    function sync()
        if ~isvalid(source),error('deConfUSIon:ProcessingCancelled','Viewer closed during export.');end
        if isVolume
            if isappdata(source,'FUSIVolumeMovieVolume')
                volume=getappdata(source,'FUSIVolumeMovieVolume');
            else
                volumes=state.viewer.Children;volume=volumes(1);
            end
            movieCamera=state.viewer;if isappdata(source,'FUSIVolumeMovieCamera'),movieCamera=getappdata(source,'FUSIVolumeMovieCamera');end
            fusiVolumeTextureSlices(ax,volume,movieCamera,ax.Position(3:4));
        else
        original=state.axes;
        geometryChanged=false;
        if isequal(original.Children,sourceChildren) && all(isgraphics(clonedChildren))
            for j=1:numel(sourceChildren)
                if isa(sourceChildren(j),'matlab.graphics.primitive.Patch') && ...
                        (~isequaln(sourceChildren(j).Vertices,clonedChildren(j).Vertices) || ...
                         ~isequaln(sourceChildren(j).Faces,clonedChildren(j).Faces))
                    geometryChanged=true;break;
                end
            end
        end
        if ~isequal(original.Children,sourceChildren) || any(~isgraphics(clonedChildren)) || geometryChanged
            delete(ax.Children);sourceChildren=original.Children;clonedChildren=copyobj(sourceChildren,ax);
            copyProperties=cell(size(sourceChildren));
            for j=1:numel(sourceChildren)
                if isa(sourceChildren(j),'matlab.graphics.primitive.Patch')
                    % Updating both XYZ/CData and Faces/Vertices representations
                    % can crash MATLAB's patch converter. Clone changed meshes;
                    % only update vertex colors when geometry is unchanged.
                    candidates={'FaceVertexCData','Visible'};
                else
                    candidates={'CData','AlphaData','XData','YData','ZData','Visible','String','Position'};
                end
                copyProperties{j}=candidates(cellfun(@(name)isprop(sourceChildren(j),name),candidates));
            end
        else
            % Slab/surface objects persist across frames. Reuse their movie
            % counterparts instead of deleting and cloning the whole scene.
            for j=1:numel(sourceChildren)
                names=copyProperties{j};set(clonedChildren(j),names,get(sourceChildren(j),names));
            end
        end
        properties={'XLim','YLim','ZLim','DataAspectRatio','PlotBoxAspectRatio','Projection', ...
            'CameraPosition','CameraTarget','CameraUpVector','CameraViewAngle','Visible', ...
            'XTick','YTick','ZTick','FontSize','XDir','YDir','ZDir'};
        for j=1:numel(properties),ax.(properties{j})=original.(properties{j});end
        ax.FontSize=max(8,original.FontSize*scale);
        for name={'Title','XLabel','YLabel','ZLabel'}
            ax.(name{1}).String=original.(name{1}).String;ax.(name{1}).Color='w';
        end
        ax.Position=relativePosition(original);
        end
        for j=1:numel(labels)
            h=labels(j);if ~isvalid(h),continue;end
            copies(j).String=h.Text;copies(j).Position=relativePosition(h);
            if strcmp(h.Tag,'VolumeRecordingTime')
                p=ax.Position;stampWidth=min(p(3)-20,230*scale);
                copies(j).Position=[p(1)+p(3)-stampWidth-10 p(2)+p(4)-35*scale stampWidth 30*scale];
            end
            copies(j).HorizontalAlignment=h.HorizontalAlignment;
            copies(j).Visible=effectiveVisible(h);
        end
        for j=1:numel(images)
            imageCopies(j).CData=images(j).ImageSource;
            imageAxes(j).Position=relativePosition(images(j));
            imageCopies(j).Visible=effectiveVisible(images(j));
        end
        for j=1:numel(bars)
            barCopies(j).Position=relativePosition(bars(j));barCopies(j).Visible=effectiveVisible(bars(j));
        end
    end
    function pixels=capture(paper)
        if nargin<1,paper=false;end
        if ~paper,sync();end
        if paper
            decorations=[copies(:);imageCopies(:);barCopies(:);findall(ax,'Type','text');findall(ax,'Type','quiver');findall(ax,'Type','line')];
            visible=get(decorations,'Visible');if ischar(visible),visible={visible};end
            axesVisible=ax.Visible;restore=onCleanup(@()restoreAnnotations(decorations,visible,axesVisible));
            set(copies,'Visible','off');set(imageCopies,'Visible','off');set(barCopies,'Visible','off');
            set(findall(ax,'Type','text'),'Visible','off');set(findall(ax,'Type','quiver'),'Visible','off');
            set(findall(ax,'Type','line'),'Visible','off');
            ax.Visible='off';
            time=findobj(labels,'Tag','VolumeRecordingTime');
            if ~isempty(time)
                j=find(labels==time(1),1);copies(j).Visible='on';
                p=ax.Position;stampWidth=min(p(3)-20,230*scale);
                copies(j).Position=[p(1)+p(3)-stampWidth-10 p(2)+p(4)-35*scale stampWidth 30*scale];
                copies(j).HorizontalAlignment='right';
            end
            pixels=captureNative();
            % Clip in image coordinates; getframe(rect) warns when web layout
            % rounding places one border pixel outside the figure.
            p=ax.Position;p(2)=p(2)-stripHeight;paperScale=size(pixels,[2 1])./sceneSize;
            x1=max(1,round(p(1)*paperScale(1))+1);x2=min(size(pixels,2),round((p(1)+p(3))*paperScale(1)));
            y1=max(1,size(pixels,1)-round((p(2)+p(4))*paperScale(2))+1);y2=min(size(pixels,1),size(pixels,1)-round(p(2)*paperScale(2)));
            pixels=pixels(y1:y2,x1:x2,:);clear restore;return;
        else
            pixels=captureNative();
        end
    end
    function pixels=captureNative()
        if captureScale>1
            % MATLAB's printing/getframe setup clamps figure height even
            % when hidden. Render the same full-resolution voxel textures
            % from a fitted physical canvas at the requested raster DPI.
            dpi=ceil(get(0,'ScreenPixelsPerInch')*captureScale);
            movieFig.PaperUnits='inches';movieFig.PaperPositionMode='manual';
            movieFig.PaperPosition=[0 0 movieFig.Position(3:4)*captureScale/dpi];
            previous=warning('off','MATLAB:print:ExcludesUIInFutureRelease');restoreWarning=onCleanup(@()warning(previous));
            pixels=print(movieFig,'-RGBImage',sprintf('-r%d',dpi));
            clear restoreWarning;
        else
            frame=getframe(movieFig);pixels=frame.cdata;
        end
        if stripHeight>0
            scaleY=size(pixels,1)/movieFig.Position(4);
            pixels=pixels(1:min(size(pixels,1),round(sceneSize(2)*scaleY)),:,:);
        end
    end
    function showFrame(pixels)
        if isempty(previewImage)||~isgraphics(previewImage),return;end
        now=toc(previewClock);if now-lastPreview<.2,return;end;lastPreview=now;
        stride=max(1,ceil(max(size(pixels,[1 2]))/900));
        previewImage.CData=pixels(1:stride:end,1:stride:end,:);
        previewImage.XData=[1 size(previewImage.CData,2)];previewImage.YData=[1 size(previewImage.CData,1)];
        previewAx.XLim=[.5 size(previewImage.CData,2)+.5];previewAx.YLim=[.5 size(previewImage.CData,1)+.5];
    end
    function restoreAnnotations(handles,visible,axesVisible)
        valid=isgraphics(handles);set(handles(valid),{'Visible'},visible(valid));
        if isgraphics(ax),ax.Visible=axesVisible;end
    end
    function closeCanvas()
        if isvalid(previewFig)&&previewFig~=movieFig,delete(previewFig);end
        if isvalid(movieFig),delete(movieFig);end
    end
    function closeOnFailure()
        if ~complete,closeCanvas();end
    end
end
function value=effectiveVisible(h)
value='on';
while ~isempty(h) && isprop(h,'Visible')
    % A hidden source window can still be exported (batch / minimized UI).
    % Only hidden content panels and controls should suppress annotations.
    if isgraphics(h,'figure'),return;end
    if strcmp(h.Visible,'off'),value='off';return;end
    h=h.Parent;
end
end
