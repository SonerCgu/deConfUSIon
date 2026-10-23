function progress=fusiVolumeAtlasProgress(owner)
% Small modeless progress window; restore the model instead of hiding it.
p=owner.Position;wasVisible=owner.Visible;windowState=owner.WindowState;
position=[p(1)+max(10,(p(3)-480)/2) p(2)+max(20,(p(4)-205)/2) 480 205];
window=uifigure('Name','Loading atlas','Position',position,'WindowStyle','normal','Resize','off', ...
    'Visible','off','Tag','VolumeAtlasLoadProgress','CloseRequestFcn',@cancel, ...
    'CreateFcn',@(h,~)setappdata(h,'deConfUSIonNoMaximize',true));
setappdata(window,'deConfUSIonNoMaximize',true);setappdata(window,'VolumeOwner',owner);
grid=uigridlayout(window,[4 1],'RowHeight',{62 26 30 32},'Padding',[16 10 16 10]);
message=uilabel(grid,'Text','Preparing saved atlas...','WordWrap','on','FontSize',13);
bar=uigauge(grid,'linear','Limits',[0 100],'Value',0);bar.MajorTicks=[];bar.MinorTicks=[];
elapsedLabel=uilabel(grid,'Text','The current phase is shown above.');
button=uibutton(grid,'Text','Cancel','ButtonPushedFcn',@cancel);
controls=findall(owner,'-property','Enable');states=get(controls,'Enable');if ischar(states),states={states};end
for k=1:numel(controls),try,controls(k).Enable='off';catch,end,end
released=false;cancelled=false;started=tic;window.Visible='on';drawnow;
progress=struct('window',window,'update',@update,'release',@release,'close',@close);
    function cancel(varargin)
        cancelled=true;message.Text='Cancellation requested. Finishing the current read...';button.Enable='off';
    end
    function update(fraction,text)
        if ~isvalid(owner)||~isvalid(window)||cancelled,error('deConfUSIon:ProcessingCancelled','Atlas loading cancelled.');end
        message.Text=text;if isfinite(fraction),bar.Value=min(100,max(0,100*fraction));end
        elapsedLabel.Text=sprintf('Elapsed %.0f s',toc(started));drawnow;
        if ~isvalid(owner)||~isvalid(window)||cancelled,error('deConfUSIon:ProcessingCancelled','Atlas loading cancelled.');end
    end
    function release()
        if released,return;end
        for k=1:numel(controls),if isvalid(controls(k)),try,controls(k).Enable=states{k};catch,end,end,end
        released=true;
    end
    function close()
        release();if isvalid(window),delete(window);end
        if isvalid(owner)&&strcmp(wasVisible,'on')
            owner.Visible='on';
            if strcmp(owner.WindowState,'minimized'),owner.WindowState=windowState;end
            figure(owner);drawnow nocallbacks;
        end
    end
end
