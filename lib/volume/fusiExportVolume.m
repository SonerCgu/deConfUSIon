function report=fusiExportVolume(fig, filename, nFrames, movieType)
% Export only the 3D scene, legend and caption; retain settings alongside it.
filename=fusiAnalysisOutputPath(filename);
destinationFolder=fileparts(filename);
if ~isempty(destinationFolder)&&~isfolder(destinationFolder),mkdir(destinationFolder);end
if nargin<3,nFrames=120;end
if nargin<4,movieType='rotation';end
started=tic;captureFallbacks=0;lastProgress=-Inf;movieCanvas=[];paperFile='';
captureMethod='In-memory scene getframe; exportapp fallback if unavailable';
if isappdata(fig,'FUSIVolumePlayback'),pb=getappdata(fig,'FUSIVolumePlayback');pb.stop();else,pb=[];end
if ~isappdata(fig,'FUSIVolumeExport')
    error('deConfUSIon:VolumeExport','Apply a valid volume view before exporting.');
end
state=getappdata(fig,'FUSIVolumeExport');
if isappdata(fig,'FUSIVolumeExportBusy')&&getappdata(fig,'FUSIVolumeExportBusy')
    error('deConfUSIon:VolumeExportBusy','A volume export is already running.');
end
setappdata(fig,'FUSIVolumeExportBusy',true);
controls=findall(fig,'-property','Enable');enabled=get(controls,'Enable');
if ischar(enabled),enabled={enabled};end
lock=@()lockControls(controls);setappdata(fig,'FUSIVolumeExportLock',lock);lock();
unlock=onCleanup(@()finishExport(fig,controls,enabled)); %#ok<NASGU>
if ~isempty(state.viewer) && isvalid(state.viewer)
    view=state.viewer;
    state.metadata.camera=struct('position',view.CameraPosition,'target',view.CameraTarget, ...
        'up',view.CameraUpVector,'zoom',view.CameraZoom);
else
    view=state.axes;
    state.metadata.camera=struct('position',view.CameraPosition,'target',view.CameraTarget, ...
        'up',view.CameraUpVector,'viewAngle',view.CameraViewAngle);
end
[~,~,extension]=fileparts(filename);
if strcmpi(extension,'.png')
    % viewer3d can be omitted from exportapp's compositor. Use the same
    % synchronous scene renderer as movies so the actual brain is captured.
    movieCanvas=fusiVolumeMovieCanvas(fig,state);closeCanvas=onCleanup(@()movieCanvas.close());
    captureMethod=movieCanvas.method;imwrite(movieCanvas.capture(),filename);
elseif strcmpi(extension,'.mp4')
    timeSeries=any(strcmpi(movieType,{'timeseries','combined'}));rotateCamera=~strcmpi(movieType,'timeseries');
    if timeSeries
        if isfield(state.metadata,'slabs') && isfield(state.metadata.slabs,'requestedTimeRowMinutes') && ~isempty(state.metadata.slabs.requestedTimeRowMinutes)
            error('deConfUSIon:StackTimeMovie','Clear Stack > Time rows to export progressing PSC frames. Fixed time rows can be exported as PNG or camera rotation.');
        end
        if isfield(state.metadata,'atlasOnly') && state.metadata.atlasOnly
            error('deConfUSIon:VolumeExport','The reference atlas has no acquired animal time series. Export a camera rotation instead.');
        end
        if isempty(pb),error('deConfUSIon:VolumeExport','This viewer does not provide time-series playback.');end
        movieInfo=pb.get();nFrames=numel(movieInfo.frames);
        restoreFrame=onCleanup(@()restorePlaybackFrame(fig,pb,movieInfo));
    end
    if nFrames<2 || nFrames~=round(nFrames),error('deConfUSIon:VolumeExport','Movie frame count must be an integer >= 2.');end
    if ~isempty(state.viewer) && isvalid(state.viewer)
        camera=state.viewer;position=camera.CameraPosition;target=camera.CameraTarget;up=camera.CameraUpVector;
        zoom=camera.CameraZoom;
    else
        camera=state.axes;position=camera.CameraPosition;target=camera.CameraTarget;up=camera.CameraUpVector;
        zoom=[];
    end
    restore=onCleanup(@()restoreVolumeCamera(fig,camera,position,target,up,zoom));
    virtualVolumeCamera=~isempty(zoom);
    if virtualVolumeCamera
        movieCamera=struct('CameraPosition',position,'CameraTarget',target,'CameraUpVector',up,'CameraZoom',zoom);
        setappdata(fig,'FUSIVolumeMovieCamera',movieCamera);
    end
    motion=struct('path','Orbit around current view','speed',360/(nFrames/24),'amplitude',20);
    if isappdata(fig,'FUSIVolumeMotion'),getMotion=getappdata(fig,'FUSIVolumeMotion');motion=getMotion();end
    acquisitionCount=nFrames;repeats=1;encodedFPS=24;
    if timeSeries
        encodedFPS=movieInfo.FPS;
        if rotateCamera
            % Smooth camera motion even with a low acquired-frame rate.
            % Hold each measured PSC volume for its exact GUI frame duration;
            % never interpolate functional values or drop acquired frames.
            repeats=max(1,ceil(24/movieInfo.FPS));encodedFPS=movieInfo.FPS*repeats;
            nFrames=acquisitionCount*repeats;
        end
    end
    paperFile=fusiPaperMoviePath(filename);
    stage=fusiMovieStage({filename,paperFile});discardStage=onCleanup(stage.cleanup);
    writer=VideoWriter(stage.files{1},'MPEG-4');writer.FrameRate=encodedFPS;writer.Quality=100;
    open(writer);closeWriter=onCleanup(@()close(writer));
    paperWriter=VideoWriter(stage.files{2},'MPEG-4');paperWriter.FrameRate=writer.FrameRate;paperWriter.Quality=writer.Quality;
    open(paperWriter);closePaper=onCleanup(@()close(paperWriter));
    if (~isempty(state.viewer) && isvalid(state.viewer)) || (~isempty(state.axes) && isvalid(state.axes))
        try
            movieCanvas=fusiVolumeMovieCanvas(fig,state,true);
            closeCanvas=onCleanup(@()movieCanvas.close());
            captureMethod=movieCanvas.method;
        catch ME
            error('deConfUSIon:VolumeMovieCanvas','Cannot initialize the synchronous movie renderer: %s',ME.message);
        end
    end
    % Warm up the asynchronous web viewer once. GETFRAME flushes pending
    % draws itself; movies need neither a PNG round-trip nor a fixed sleep.
    if isempty(movieCanvas) && isappdata(fig,'FUSIVolumeWaitRender'),wait=getappdata(fig,'FUSIVolumeWaitRender');wait();end
    preview=fusiVolumeExportPreview(fig,filename,nFrames,movieCanvas.previewFigure,movieCanvas.stripHeight);
    closePreview=onCleanup(preview.close); %#ok<NASGU>
    notifyProgress(0,nFrames);
    lastAcquisition=0;
    for k=0:nFrames-1
        if ~isvalid(fig),error('deConfUSIon:ProcessingCancelled','Time-series export cancelled by closing the viewer.');end
        if preview.isCancelled(),error('deConfUSIon:ProcessingCancelled','Movie export cancelled.');end
        if timeSeries
            acquisition=floor(k/repeats)+1;
            if acquisition~=lastAcquisition
                if isfield(pb,'exportFrame'),pb.exportFrame(movieInfo.frames(acquisition));else,pb.setFrame(movieInfo.frames(acquisition));end
                lastAcquisition=acquisition;
            end
            if ~virtualVolumeCamera,camera.CameraPosition=position;camera.CameraTarget=target;camera.CameraUpVector=up;end
        end
        if rotateCamera
            [movingPosition,movingUp]=fusiVolumeCameraMotion(position,target,up,k/encodedFPS,motion);
            if virtualVolumeCamera,movieCamera.CameraPosition=movingPosition;movieCamera.CameraUpVector=movingUp;
            else,camera.CameraPosition=movingPosition;camera.CameraUpVector=movingUp;end
        end
        if virtualVolumeCamera,setappdata(fig,'FUSIVolumeMovieCamera',movieCamera);end
        updateDecorations();
        pixels=captureScene(true);
        % MPEG-4 requires even dimensions; crop at most one border pixel.
        pixels=pixels(1:2*floor(size(pixels,1)/2),1:2*floor(size(pixels,2)/2),:);
        writeVideo(writer,pixels);
        paperPixels=movieCanvas.capture(true);
        paperPixels=paperPixels(1:2*floor(size(paperPixels,1)/2),1:2*floor(size(paperPixels,2)/2),:);
        writeVideo(paperWriter,paperPixels);
        movieCanvas.showFrame(pixels);
        preview.update(k+1,toc(started));
        notifyProgress(k+1,nFrames);
    end
    close(writer);clear closeWriter;
    close(paperWriter);clear closePaper;
    stage.commit();clear discardStage;
    if timeSeries,clear restoreFrame;end
    clear restore;
else
    error('deConfUSIon:VolumeExport','Choose a .png or .mp4 filename.');
end
metadata=state.metadata;metadata.exportedAt=char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
metadata.exportFile=filename;
if isappdata(fig,'FUSIVolumeExportIdentity')
    identity=getappdata(fig,'FUSIVolumeExportIdentity');
    if strcmp(identity.folder,fileparts(filename)),metadata.exportIdentity=identity;end
end
metadata.exportSeconds=toc(started);
metadata.sceneCapture=captureMethod;
if strcmpi(extension,'.mp4')
    metadata.movieFrames=nFrames;metadata.movieFPS=encodedFPS;metadata.movieType='Camera rotation of a static selected volume';
    if timeSeries
        metadata.movieAcquisitionFPS=movieInfo.FPS;metadata.movieType='Acquired PSC time series with fixed camera';
        metadata.movieOriginalFrames=movieInfo.frames;metadata.movieTimeSec=movieInfo.timeSec;
        metadata.movieRepeatsPerAcquisition=repeats;
        metadata.movieEncodedOriginalFrames=repelem(movieInfo.frames,repeats);
        if isfield(movieInfo,'sequence')&&movieInfo.sequence
            metadata.movieScanIndices=movieInfo.scanIndices;metadata.movieScanLocalFrames=movieInfo.localFrames;
            metadata.movieScanLocalTimeSec=movieInfo.localTimeSec;metadata.movieScanLabels=movieInfo.scanLabels;
            metadata.movieScanKeys=movieInfo.scanKeys;metadata.movieSampleTRSec=movieInfo.sampleTRSec;
            metadata.movieSequenceTime='Continuous display timeline; local acquisition time restarts at each scan. Gaps between acquisitions are not inferred.';
        end
        if rotateCamera,metadata.movieType='Acquired PSC time series with simultaneous selected camera motion';end
    end
    if rotateCamera
        metadata.movieCameraMotion=motion;metadata.movieCameraMotion.durationSec=nFrames/encodedFPS;
        if any(strcmp(motion.path,{'Orbit around current view','Oblique orbit'})),metadata.movieRotationDegrees=motion.speed*nFrames/encodedFPS;end
    end
    metadata.movieCapture=captureMethod;
    metadata.movieCaptureFallbacks=captureFallbacks;
    metadata.movieEncodingQuality=100;
    metadata.movieSampling='Every selected acquired frame retains its GUI duration. Combined rotation holds PSC constant within each acquired frame and adds smooth camera steps; no temporal PSC interpolation, skipped samples or PSC renormalization.';
    metadata.movieOutputSizeYX=size(pixels,[1 2]);
    metadata.paperReadyFile=paperFile;metadata.paperReadyOutputSizeYX=size(paperPixels,[1 2]);
    metadata.paperReadyAnnotations='Acquisition time only, top right; identical acquired frames and camera motion.';
    resolution=findobj(fig,'Tag','VolumeMovieResolution');if ~isempty(resolution),metadata.movieResolutionRequested=resolution.Value;end
end
fid=fopen([filename '.json'],'w');
if fid<0,error('deConfUSIon:VolumeExport','Image saved, but cannot write settings JSON.');end
closeFile=onCleanup(@()fclose(fid));
fprintf(fid,'%s',jsonencode(metadata,'PrettyPrint',true));
clear closeFile;
report=struct('file',filename,'paperFile',paperFile,'settingsFile',[filename '.json'],'seconds',toc(started));
setappdata(fig,'FUSIVolumeLastExport',report);
fprintf('3D export saved: %s\nSettings saved: %s\nExport completed in %.1f seconds.\n',report.file,report.settingsFile,report.seconds);
if ~isempty(paperFile),fprintf('Paper-ready MP4 saved: %s\n',paperFile);end

    function pixels=captureScene(fast)
        if fast
            if ~isempty(movieCanvas),pixels=movieCanvas.capture();return;end
            try
                % Capture only the scene, including legend and live caption.
                % This bypasses full-app image encoding, disk I/O and decoding.
                frame=getframe(fig,getpixelposition(state.scene,true));
                pixels=frame.cdata;return;
            catch
                % Retain compatibility when getframe is unavailable on a host.
                captureFallbacks=captureFallbacks+1;
            end
        end
        if isappdata(fig,'FUSIVolumeWaitRender'),wait=getappdata(fig,'FUSIVolumeWaitRender');wait();end
        drawnow;
        % exportapp captures the web-based UI as a whole. getframe can omit
        % or clip uilabels when a viewer3d shares the uifigure compositor.
        captureFile=[tempname '.png'];
        removeCapture=onCleanup(@()removeTemporaryCapture(captureFile));
        exportapp(fig,captureFile);pixels=imread(captureFile);clear removeCapture;
        rect=getpixelposition(state.scene,true);
        % Account for high-DPI screen capture versus MATLAB logical pixels.
        fp=getpixelposition(fig);sx=size(pixels,2)/fp(3);sy=size(pixels,1)/fp(4);
        x1=max(1,round(rect(1)*sx)+1);x2=min(size(pixels,2),round((rect(1)+rect(3))*sx));
        y1=max(1,size(pixels,1)-round((rect(2)+rect(4))*sy)+1);
        y2=min(size(pixels,1),size(pixels,1)-round(rect(2)*sy));
        pixels=pixels(y1:y2,x1:x2,:);
    end
    function notifyProgress(done,total)
        elapsed=toc(started);
        if done~=total && elapsed-lastProgress<.5,return;end
        lastProgress=elapsed;
        if isappdata(fig,'FUSIVolumeExportProgress')
            callback=getappdata(fig,'FUSIVolumeExportProgress');callback(done,total,elapsed,filename);
        end
    end
    function updateDecorations()
        if isvalid(fig) && isappdata(fig,'FUSIVolumeUpdateDecorations')
            callback=getappdata(fig,'FUSIVolumeUpdateDecorations');callback();
        end
    end
end

function lockControls(controls)
valid=isvalid(controls);set(controls(valid),'Enable','off');
end

function finishExport(fig,controls,enabled)
valid=isvalid(controls);set(controls(valid),{'Enable'},enabled(valid));
if ~isvalid(fig),return;end
for name={'FUSIVolumeExportBusy','FUSIVolumeExportLock'}
    if isappdata(fig,name{1}),rmappdata(fig,name{1});end
end
end

function removeTemporaryCapture(filename)
if isfile(filename),delete(filename);end
end

function restorePlaybackFrame(fig,pb,info)
if isvalid(fig),pb.restore(info);end
end

function restoreVolumeCamera(fig,camera,position,target,up,zoom)
if isvalid(fig)&&isappdata(fig,'FUSIVolumeMovieCamera'),rmappdata(fig,'FUSIVolumeMovieCamera');end
if isvalid(camera)
    camera.CameraPosition=position;camera.CameraTarget=target;camera.CameraUpVector=up;
    if ~isempty(zoom),camera.CameraZoom=zoom;end
    if isvalid(fig) && isappdata(fig,'FUSIVolumeUpdateDecorations')
        callback=getappdata(fig,'FUSIVolumeUpdateDecorations');callback();
    end
end
end
