function preview=fusiVolumeExportPreview(source,filename,total,window,stripHeight)
% Progress and Cancel share the native movie window. Controls sit outside
% the captured scene, so the visible preview is the actual encoded model.
cancelled=false;lastUpdate=-Inf;clock=tic;
message=uicontrol(window,'Style','text','Units','pixels','Position',[12 21 max(100,window.Position(3)-160) stripHeight-25], ...
    'String','Preparing movie renderer...','BackgroundColor',[.06 .07 .09],'ForegroundColor','w', ...
    'FontSize',11,'HorizontalAlignment','left');
bar=uipanel(window,'Units','pixels','Position',[12 8 max(100,window.Position(3)-160) 6], ...
    'BorderType','none','BackgroundColor',[.18 .2 .24]);
fill=uipanel(bar,'Units','normalized','Position',[0 0 .001 1], ...
    'BorderType','none','BackgroundColor',[.18 .7 .45]);
uicontrol(window,'Style','pushbutton','Units','pixels','Position',[window.Position(3)-136 8 124 stripHeight-16], ...
    'String','Cancel export','FontSize',11,'BackgroundColor',[.6 .16 .18], ...
    'ForegroundColor','w','Callback',@cancel,'Tag','VolumeMovieCancel');
message.TooltipString=['Saving both movies to ' fileparts(filename)];
window.Tag='VolumeMoviePreview';window.Name='3D movie export | Live preview';window.CloseRequestFcn=@cancel;
preview=struct('figure',window,'update',@update,'isCancelled',@isCancelled,'close',@closePreview);
setappdata(source,'FUSIVolumeExportPreview',preview);
drawnow limitrate;
    function update(done,elapsed)
        if cancelled||~isvalid(window),return;end
        now=toc(clock);if done~=total && now-lastUpdate<.2,return;end
        lastUpdate=now;
        fraction=max(.001,done/total);fill.Position=[0 0 fraction 1];
        if done>0
            message.String=sprintf('Frame %d / %d (%.0f%%) | %.1f frames/s | about %.0f s left', ...
                done,total,100*done/total,done/max(eps,elapsed),elapsed*(total-done)/done);
        end
        drawnow limitrate;
    end
    function value=isCancelled()
        value=cancelled||~isvalid(window)||~isvalid(source);
    end
    function cancel(varargin)
        cancelled=true;
        if isvalid(message),message.String='Cancelling after the current frame...';end
    end
    function closePreview()
        if isvalid(source)&&isappdata(source,'FUSIVolumeExportPreview'),rmappdata(source,'FUSIVolumeExportPreview');end
    end
end
