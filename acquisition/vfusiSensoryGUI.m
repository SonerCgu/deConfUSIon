function fig=vfusiSensoryGUI(parent,override)
% Companion configuration/test panel; opening it cannot start the scanner.
if nargin<1,parent=[];end
c=vfusiSensoryConfig();if ~isempty(parent)&&isappdata(parent,'sensoryConfig'),c=vfusiSensoryConfig(getappdata(parent,'sensoryConfig'));end
if nargin>1,c=vfusiSensoryConfig(override);end
if isempty(c.python_exe)
    candidate=fullfile(getenv('LOCALAPPDATA'),'Programs','PsychoPy','python.exe');if isfile(candidate),c.python_exe=candidate;end
end
p=jsondecode(fileread(c.protocol_file));
fig=uifigure('Name','Visual / whisker / camera setup','Color','k','Position',[120 80 1000 800],'Tag','VFUSISensoryGUI');
root=uigridlayout(fig,[4 1],'RowHeight',{48,'1x',76,46},'BackgroundColor','k');
title=uilabel(root,'Text','Sensory stimulation + USB face recording','FontColor','w','FontSize',22);
tabs=uitabgroup(root);controls=struct();
protocol=uitab(tabs,'Title','Protocol');pg=grid(protocol,11);
add(pg,1,'Preset','preset',{'combo','neuron_grating','retinotopy','whisker_mock'},p.protocol);
add(pg,2,'Baseline (s)','baseline',[],p.baseline_s);add(pg,3,'Stimulus (s)','duration',[],p.stimulus_s);
add(pg,4,'Recovery (s)','recovery',[],p.recovery_s);add(pg,5,'Repeats per direction','repeats',[],p.repetitions);
add(pg,6,'Directions (screen degrees)','directions',[],sprintf('%g ',p.directions_deg));
add(pg,7,'Spatial frequency (cycles/degree)','sf',[],p.spatial_frequency_cpd);
add(pg,8,'Temporal frequency (cycles/s)','tf',[],p.temporal_frequency_hz);add(pg,9,'Contrast (0-1)','contrast',[],p.contrast);
add(pg,10,'Grating texture','texture',{'sqr','sin'},p.texture);
add(pg,11,'Shuffle directions','randomize',[],logical(p.randomize));
wtab=uitab(tabs,'Title','Mock whisker');wg=grid(wtab,4);
add(wg,1,'Mock whisker enabled','whisker',[],logical(p.whisker.enabled));
add(wg,2,'Whisker frequency (Hz)','whiskerHz',[],p.whisker.frequency_hz);
add(wg,3,'Peak angle amplitude (deg, MOCK)','whiskerAmp',[],p.whisker.amplitude_deg);
note=uilabel(wg,'Text','Mock output writes a requested sinusoidal angle trace. No COM port, piezo or motor is driven. Amplitude is peak (20 degrees = 40 degrees peak-to-peak). Use TEST MOCK to inspect it.','WordWrap','on','FontColor','w','FontSize',15);note.Layout.Row=4;note.Layout.Column=[1 2];wg.RowHeight{4}=100;
view=uitab(tabs,'Title','Visual display');vg=grid(view,7);
add(vg,1,'Active monitor width (cm)','width',[],p.monitor.width_cm);add(vg,2,'Eye to monitor distance (cm)','distance',[],p.monitor.distance_cm);
add(vg,3,'Monitor pixels (width height)','pixels',[],sprintf('%d %d',p.monitor.size_px));
add(vg,4,'Screen index (0 = first display)','screen',[],p.monitor.screen);
add(vg,5,'Fullscreen for actual sessions','fullscreen',[],logical(p.monitor.fullscreen));
add(vg,6,'Projection correction','warp',{'none','spherical'},p.monitor.warp);
note=uilabel(vg,'Text','Measure monitor geometry and calibrate mouseMon in PsychoPy Monitor Center. Retinotopy bar width/speed, checker reversal rate, monitor profile name, eyepoint and seed are editable in Advanced JSON. Directions are screen-relative: 0 right, 90 up, 180 left, 270 down.','WordWrap','on','FontColor','w','FontSize',14);note.Layout.Row=7;note.Layout.Column=[1 2];vg.RowHeight{7}=120;
camtab=uitab(tabs,'Title','USB camera');cg=grid(camtab,7);
add(cg,1,'Record face camera','camera',[],logical(p.camera.enabled));add(cg,2,'USB device index','device',[],p.camera.device);
add(cg,3,'Requested camera FPS','fps',[],p.camera.fps);
add(cg,4,'Camera backend','cameraBackend',{'usb','mock'},p.camera.backend);
add(cg,5,'Camera pixels (width height)','cameraPixels',[],sprintf('%d %d',p.camera.width,p.camera.height));
if ~isfield(p.camera,'record_until_scan_stop'),p.camera.record_until_scan_stop=true;end
add(cg,6,'Record until scanner STOP','cameraUntilStop',[],logical(p.camera.record_until_scan_stop));
note=uilabel(cg,'Text','USB timestamps are host frame receive times, not TTL/exposure times. The camera opens while arming and records on scan start. Choose mock to test AVI recording without opening a camera.','WordWrap','on','FontColor','w','FontSize',14);note.Layout.Row=7;note.Layout.Column=[1 2];cg.RowHeight{7}=100;
sync=uitab(tabs,'Title','Connection');sg=grid(sync,7);
add(sg,1,'Use during scanner acquisition','mode',{'disabled','mock','psychopy'},c.mode);
add(sg,2,'PsychoPy Python executable','python',[],c.python_exe);add(sg,3,'Local UDP port','port',[],c.udp_port);
add(sg,4,'Visual onset marker','marker',{'mock','serial'},p.sync.marker);
add(sg,5,'Arduino COM port (serial marker only)','serial',[],p.sync.serial_port);
add(sg,6,'Output folder','output',[],c.output_dir);
explanation=uilabel(sg,'Text','1. Save settings. 2. Test mock or screen preview. 3. ARM PsychoPy before START in the controller. Settings default disabled. The optional callback sends one software START and records scanner indices. Existing StimBox/PulsePal ports are separate.','WordWrap','on','FontColor','w','FontSize',14);explanation.Layout.Row=7;explanation.Layout.Column=[1 2];sg.RowHeight{7}=120;
advanced=uitab(tabs,'Title','Advanced JSON');ag=uigridlayout(advanced,[2 1],'RowHeight',{'1x',42},'BackgroundColor','k');
jsonText=uitextarea(ag,'Value',splitlines(string(jsonencode(p,'PrettyPrint',true))),'FontName','Consolas','FontSize',13);
uibutton(ag,'Text','Import edited JSON into controls','ButtonPushedFcn',@importJSON);
status=uilabel(root,'Text','No acquisition or output hardware has been started.','WordWrap','on','FontColor','w','FontSize',14);
buttons=uigridlayout(root,[1 4],'BackgroundColor','k');
uibutton(buttons,'Text','SAVE SETTINGS','BackgroundColor',[.15 .5 .25],'FontColor','w','ButtonPushedFcn',@saveSettings);
uibutton(buttons,'Text','TEST MOCK (no hardware)','BackgroundColor',[.2 .4 .75],'FontColor','w','ButtonPushedFcn',@(~,~)launch('--dry-run'));
uibutton(buttons,'Text','SCREEN PREVIEW','BackgroundColor',[.2 .4 .75],'FontColor','w','ButtonPushedFcn',@(~,~)launch('--preview'));
uibutton(buttons,'Text','ARM PsychoPy worker','BackgroundColor',[.15 .5 .25],'FontColor','w','ButtonPushedFcn',@(~,~)launch('--listen'));
controls.preset.ValueChangedFcn=@choosePreset;
    function g=grid(tab,n)
        g=uigridlayout(tab,[n 2],'ColumnWidth',{360,'1x'},'RowHeight',repmat({36},1,n),'Scrollable','on','BackgroundColor','k');
    end
    function add(g,row,label,name,choices,value)
        lab=uilabel(g,'Text',label,'FontSize',15,'FontColor','w');lab.Layout.Row=row;lab.Layout.Column=1;
        if ~isempty(choices),h=uidropdown(g,'Items',choices,'Value',value);
        elseif islogical(value),h=uicheckbox(g,'Text','','Value',value);
        elseif isnumeric(value),h=uieditfield(g,'numeric','Value',value);
        else,h=uieditfield(g,'text','Value',value);end
        h.Tag=['Sensory_' name];h.FontSize=15;h.Layout.Row=row;h.Layout.Column=2;controls.(name)=h;
    end
    function choosePreset(~,~)
        switch controls.preset.Value
            case 'combo',v=[12 12 0 3];dirs='0 90 180 270';
            case 'neuron_grating',v=[20 16 5 10];dirs='0';
            case 'retinotopy',v=[2.1 14 0 1];dirs='0';
            otherwise,v=[14 6 15 1];dirs='0';
        end
        controls.baseline.Value=v(1);controls.duration.Value=v(2);controls.recovery.Value=v(3);controls.repeats.Value=v(4);controls.directions.Value=dirs;
        controls.whisker.Value=strcmp(controls.preset.Value,'whisker_mock');
    end
    function [config,protocol]=collect()
        if ~isempty(parent)&&ishandle(parent)&&isappdata(parent,'isRunning')&&getappdata(parent,'isRunning')
            error('Finish the active acquisition before changing or launching sensory settings.');
        end
        protocol=p;protocol.protocol=controls.preset.Value;protocol.baseline_s=controls.baseline.Value;
        protocol.stimulus_s=controls.duration.Value;protocol.recovery_s=controls.recovery.Value;protocol.repetitions=controls.repeats.Value;
        protocol.directions_deg=sscanf(controls.directions.Value,'%f')';protocol.spatial_frequency_cpd=controls.sf.Value;
        protocol.temporal_frequency_hz=controls.tf.Value;protocol.contrast=controls.contrast.Value;protocol.texture=controls.texture.Value;
        protocol.randomize=controls.randomize.Value;protocol.whisker.enabled=controls.whisker.Value;protocol.whisker.frequency_hz=controls.whiskerHz.Value;protocol.whisker.amplitude_deg=controls.whiskerAmp.Value;
        protocol.monitor.width_cm=controls.width.Value;protocol.monitor.distance_cm=controls.distance.Value;
        protocol.monitor.size_px=sscanf(controls.pixels.Value,'%f')';protocol.monitor.screen=controls.screen.Value;protocol.monitor.fullscreen=controls.fullscreen.Value;protocol.monitor.warp=controls.warp.Value;
        protocol.camera.enabled=controls.camera.Value;protocol.camera.device=controls.device.Value;protocol.camera.fps=controls.fps.Value;protocol.camera.backend=controls.cameraBackend.Value;
        protocol.camera.record_until_scan_stop=controls.cameraUntilStop.Value;
        pixels=sscanf(controls.cameraPixels.Value,'%f')';if numel(pixels)~=2,error('Enter two camera pixel dimensions.');end
        protocol.camera.width=pixels(1);protocol.camera.height=pixels(2);
        protocol.sync.source='udp';protocol.sync.port=controls.port.Value;protocol.sync.marker=controls.marker.Value;protocol.sync.serial_port=controls.serial.Value;
        protocol.output_dir=controls.output.Value;
        config=c;config.mode=controls.mode.Value;config.python_exe=controls.python.Value;config.output_dir=controls.output.Value;config.udp_port=controls.port.Value;
        if isempty(config.output_dir),error('Choose an output folder.');end
        if ~isfolder(config.output_dir),mkdir(config.output_dir);end
        config.protocol_file=fullfile(config.output_dir,['Protocol_' datestr(now,'yyyy-mm-dd_HH-MM-SS-FFF') '.json']);
        fid=fopen(config.protocol_file,'w');if fid<0,error('Cannot save protocol.');end
        guard=onCleanup(@()fclose(fid));fprintf(fid,'%s',jsonencode(protocol,'PrettyPrint',true));clear guard;
        config=vfusiSensoryConfig(config);
        % The standard-library validator imports no display or hardware code.
        if isfile(config.python_exe)
            runner=fullfile(fileparts(mfilename('fullpath')),'sensory','stimulus_runner.py');
            info=System.Diagnostics.ProcessStartInfo(config.python_exe);
            info.Arguments=sprintf('"%s" --config "%s" --validate-only',runner,config.protocol_file);
            info.UseShellExecute=false;info.CreateNoWindow=true;info.RedirectStandardOutput=true;info.RedirectStandardError=true;
            process=System.Diagnostics.Process.Start(info);out=process.StandardOutput.ReadToEndAsync();err=process.StandardError.ReadToEndAsync(); %#ok<NASGU>
            if ~process.WaitForExit(15000),process.Kill();error('Protocol validation timed out.');end
            if process.ExitCode~=0,error(char(err.Result));end
        elseif ~strcmp(config.mode,'disabled')
            error('Choose a Python executable so the protocol can be validated.');
        end
    end
    function saveSettings(~,~)
        try
            [c,p]=collect();
            if ~isempty(parent)&&ishandle(parent),setappdata(parent,'sensoryConfig',c);end
            status.Text=['Saved (' c.mode '): ' c.protocol_file];
            jsonText.Value=splitlines(string(jsonencode(p,'PrettyPrint',true)));
        catch ME,status.Text=ME.message;end
    end
    function importJSON(~,~)
        try
            extra=mergeProtocol(p,jsondecode(strjoin(cellstr(jsonText.Value),newline)));
            % Import through a new panel so all visible fields match JSON.
            file=[tempname '.json'];fid=fopen(file,'w');fprintf(fid,'%s',jsonencode(extra));fclose(fid);
            imported=c;imported.protocol_file=file;
            vfusiSensoryGUI(parent,imported);
            delete(fig);
        catch ME,status.Text=ME.message;end
    end
    function result=mergeProtocol(base,extra)
        if ~isstruct(extra)||~isscalar(extra),error('JSON must be a configuration object.');end
        result=base;names=fieldnames(extra);
        for ii=1:numel(names)
            key=names{ii};
            if isfield(base,key)&&isstruct(base.(key))&&isstruct(extra.(key))
                result.(key)=mergeProtocol(base.(key),extra.(key));
            else,result.(key)=extra.(key);end
        end
    end
    function launch(flag)
        try
            [config,protocol]=collect();
            if ~isfile(config.python_exe),error('Choose the python.exe bundled with PsychoPy.');end
            runner=fullfile(fileparts(mfilename('fullpath')),'sensory','stimulus_runner.py');
            info=System.Diagnostics.ProcessStartInfo(config.python_exe);
            info.Arguments=sprintf('"%s" --config "%s" %s',runner,config.protocol_file,flag);
            info.WorkingDirectory=fileparts(runner);info.UseShellExecute=false;info.CreateNoWindow=true;
            info.RedirectStandardOutput=true;info.RedirectStandardError=true;
            process=System.Diagnostics.Process.Start(info);out=process.StandardOutput.ReadToEndAsync();err=process.StandardError.ReadToEndAsync();
            setappdata(fig,'sensoryWorker',struct('process',process,'stdout',out,'stderr',err));
            if strcmp(flag,'--dry-run')
                limit=tic;
                while ~process.WaitForExit(100)
                    drawnow;if ~isvalid(fig),return;end
                    if toc(limit)>60,process.Kill();error('Mock planning exceeded 60 seconds. Shorten the protocol.');end
                end
                if process.ExitCode~=0,error(char(err.Result));end
                status.Text=strtrim(char(out.Result));
            elseif strcmp(flag,'--listen')
                config.mode='psychopy';
                status.Text='Starting display; waiting for a verified READY response...';drawnow;
                ready=false;limit=tic;
                while toc(limit)<90 && ~process.HasExited
                    try,probe=vfusiSensoryRun(config);delete(probe);ready=true;break;catch,end
                    drawnow;
                end
                if ~ready
                    if process.HasExited,error(char(err.Result));else,error('Worker not READY yet. Check the display and port.');end
                end
                controls.mode.Value='psychopy';c=config;p=protocol;
                if ~isempty(parent),setappdata(parent,'sensoryConfig',c);end
                status.Text='PsychoPy READY verified. Start the functional scan in the controller. Escape closes the stimulus worker.';
                if strcmp(protocol.protocol,'whisker_mock'),status.Text=[status.Text ' Whisker output remains MOCK ONLY.'];end
            else,status.Text='Preview launched: Space starts the shortened preview; Escape stops. Scanner is untouched.';end
        catch ME,status.Text=['Error: ' ME.message];end
    end
end
