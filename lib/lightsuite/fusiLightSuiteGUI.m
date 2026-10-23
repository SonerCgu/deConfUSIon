function fig=fusiLightSuiteGUI(data,meta,overrides)
% Independent optional workspace. All manual choices and output are resumable.
if nargin<1,data=[];end
if nargin<2||isempty(meta),meta=struct();end
if nargin<3,overrides=struct();end
cfg=fusiLightSuiteConfig(overrides);session=[];histFolder='';guideStep=1;busyStarted=[];
useSeed=isstruct(data)&&isfield(data,'I')&&~isempty(data.I);
if isempty(cfg.sourceFile)
    if isstruct(data)&&isfield(data,'sourcePath')&&isfield(data,'sourceFileName')
        cfg.sourceFile=fullfile(data.sourcePath,data.sourceFileName);
    elseif isfield(meta,'loadedFile')&&isfile(meta.loadedFile)
        cfg.sourceFile=char(meta.loadedFile);
    elseif isstruct(data)&&isfield(data,'lazyFile')
        cfg.sourceFile=char(data.lazyFile);
    end
end
fig=figure('Name','deConfUSIon | LightSuite experimental workspace','NumberTitle','off', ...
    'Color',[.055 .075 .08],'MenuBar','none','ToolBar','none','Position',[120 80 1120 850]);
tabs=uipanel(fig,'Units','normalized','Position',[.02 .18 .96 .755],'BorderType','none');
panels=gobjects(1,4);tabButtons=gobjects(1,4);
tabNames={'3D fUSI registration','Histology sections','Fiber / probe trajectories','Dependencies'};
for ti=1:4
    panels(ti)=uipanel(tabs,'Units','normalized','Position',[0 0 1 .90],'BorderType','none','Visible','off');
    tabButtons(ti)=uicontrol(tabs,'Style','pushbutton','Units','normalized', ...
        'Position',[.005+(ti-1)*.25 .925 .24 .065],'String',tabNames{ti}, ...
        'FontSize',11,'FontWeight','bold','Callback',@(~,~)selectTab(ti));
end
t1=panels(1);t2=panels(2);t3=panels(3);t4=panels(4);
activity=uicontrol(fig,'Style','text','Units','normalized','Position',[.025 .137 .95 .03], ...
    'String','READY | Select a recording or open a saved project','FontSize',12,'FontWeight','bold', ...
    'HorizontalAlignment','left','Tag','LightSuiteWorkflowActivity');
status=uicontrol(fig,'Style','edit','Max',5,'Min',0,'Units','normalized','Position',[.025 .018 .95 .11], ...
    'String',{'Experimental optional method. Review all geometry, landmarks, affine and nonlinear diagnostic views.'; ...
    'LightSuite: Karamanlis et al. (2026), DOI 10.64898/2026.10.13.757638. Existing registration is unchanged.'}, ...
    'HorizontalAlignment','left','FontSize',11,'Enable','inactive','BackgroundColor',[.08 .12 .13],'ForegroundColor',[.85 .95 .89]);
label(t1,[.03 .88 .92 .08],['GUIDED WORKFLOW: start at 1. Confirm orientation, finish your landmark pairs, then review the fitted alignment. ' ...
    'The next step opens automatically; accepting the review saves anatomy, regions, backgrounds and masks.']);
file=editrow(t1,.80,'Recording',cfg.sourceFile,@pickFile);
file.Tag='LightSuiteRecording';file.Callback=@recordingEdited;
if useSeed&&isempty(file.String),file.String='Loaded Studio dataset (in memory)';end
if useSeed,file.TooltipString='The active Studio dataset is selected. Prepare uses its current in-memory data. Browse to select a different recording.';end
out=editrow(t1,.71,'Output folder',cfg.outputFolder,@pickOutput);
label(t1,[.03 .62 .4 .05],'Voxel spacing along input dimensions [mm]');
spacing=uicontrol(t1,'Style','edit','Units','normalized','Position',[.43 .62 .28 .055], ...
    'String',num2str(cfg.voxelSizeMm),'FontSize',12,'BackgroundColor','w','Tag','LightSuiteSpacing');
uicontrol(t1,'Style','pushbutton','Units','normalized','Position',[.73 .62 .23 .055], ...
    'String','Read metadata spacing','FontSize',11,'Callback',@readGeometry);
guided=uicontrol(t1,'Style','checkbox','Units','normalized','Position',[.03 .55 .93 .045], ...
    'String','Continue automatically between steps (orientation and fit review still require your confirmation)', ...
    'Value',1,'FontSize',12,'Callback',@(~,~)refreshWorkflow(),'Tag','LightSuiteGuidedWorkflow');
nextLabel=label(t1,[.03 .495 .93 .035],'');nextLabel.FontWeight='bold';nextLabel.Tag='LightSuiteNextStep';
stepButtons=gobjects(1,6);
stepButtons(1)=button(t1,[.03 .405 .29 .075],'1  Prepare + start',@prepare);
stepButtons(2)=button(t1,[.35 .405 .29 .075],'2  Confirm orientation',@orientation);
stepButtons(3)=button(t1,[.67 .405 .29 .075],'3  Edit landmarks',@landmarks);
stepButtons(4)=button(t1,[.03 .315 .29 .075],'4  Fit registration',@fit);
stepButtons(5)=button(t1,[.35 .315 .29 .075],'5  Review + accept',@review);
stepButtons(6)=button(t1,[.67 .315 .29 .075],'6  Save all outputs',@saveOutputs);
for k=1:6,stepButtons(k).Tag=sprintf('LightSuiteStep%d',k);end
resumeButton=button(t1,[.03 .215 .29 .065],'Open existing project',@resume);resumeButton.Tag='LightSuiteOpenProject';
button(t1,[.35 .215 .29 .065],'Open output folder',@openOutput);
rerunButton=button(t1,[.67 .215 .29 .065],'Re-register (new version)',@revise);
set(rerunButton,'Tag','LightSuiteReregister','TooltipString', ...
    'Create a timestamped subfolder in this project. Edit copied landmarks or recheck orientation and place new pairs. The previous registration is preserved.');
exportButton=button(t1,[.03 .12 .93 .075],'SAVE / EXPORT BOTH ATLAS STAGES + MASKS',@exportRegions);
exportButton.Tag='LightSuiteExportOutputs';exportButton.FontWeight='bold';
tutorialButtons=[button(t1,[.03 .035 .45 .055],'HELP: choosing landmarks',@(~,~)fusiLightSuiteLandmarkHelp()), ...
    button(t1,[.51 .035 .45 .055],'HELP: using saved outputs',@outputHelp)];

label(t2,[.03 .84 .93 .13],['Serial histology TIFF or CZI sections: prepare copies, review order / flips / crop bounds, align, confirm cutting angle, ' ...
    'place landmarks and refine every section. This adapter keeps the upstream 1.25 um processing / 20 um registration / 10 um atlas convention.']);
histSource=editrow(t2,.75,'Sections folder','',@pickHistInput);
histOut=editrow(t2,.66,'Output folder','',@pickHistOutput);
label(t2,[.03 .56 .2 .05],'Pixel size (um)');hp=smallEdit(t2,[.21 .56 .14 .055],'');
label(t2,[.38 .56 .25 .05],'Section spacing (um)');hs=smallEdit(t2,[.63 .56 .14 .055],'');
label(t2,[.03 .48 .2 .05],'Channel names');hc=smallEdit(t2,[.21 .48 .35 .055],'DAPI,GFP');
label(t2,[.59 .48 .2 .05],'Reg. channel');hr=smallEdit(t2,[.78 .48 .18 .055],'DAPI');
label(t2,[.03 .4 .35 .05],'Atlas AP indices (10 um)');ha=smallEdit(t2,[.37 .4 .22 .055],'180 1079');
button(t2,[.03 .3 .21 .07],'1  Prepare copies',@histPrepare);
button(t2,[.27 .3 .21 .07],'2  Order / crop',@(~,~)histRun('order'));
button(t2,[.51 .3 .21 .07],'3  Initial alignment',@(~,~)histRun('align'));
button(t2,[.75 .3 .21 .07],'4  Cutting angle',@(~,~)histRun('angle'));
button(t2,[.03 .2 .21 .07],'5  Landmarks',@(~,~)histRun('landmarks'));
button(t2,[.27 .2 .21 .07],'6  Refine sections',@(~,~)histRun('register'));
button(t2,[.51 .2 .21 .07],'7  Atlas volume',@(~,~)histRun('volume'));
button(t2,[.75 .2 .21 .07],'8  Regional intensity',@(~,~)histRun('intensities'));
button(t2,[.03 .09 .27 .07],'Open histology project',@histResume);
button(t2,[.34 .09 .27 .07],'Cell detection settings',@histCells);
uicontrol(t2,'Style','pushbutton','Units','normalized','Position',[.65 .09 .31 .07], ...
    'String','Cell atlas mapping: validation pending','Enable','off','FontSize',10, ...
    'TooltipString','The serial-section point-coordinate chain needs independent validation. Registered intensities and native detection overlays are available.');

label(t3,[.04 .72 .91 .24],['Trajectories require a visible implant / damage track in a registered whole-brain histology volume. ' ...
    'This is manual annotation followed by a line/cylinder fit and atlas-region lookup. ' ...
    'fUSI cannot identify an invisible fiber, infer expression, or replace histology. ' ...
    'Choose a LightSuite whole-brain output folder containing nested regopts.opts, transform_params.mat and the 20 um registration TIFF. ' ...
    'Serial-section and fUSI registration chains are different and are rejected by this launcher.']);
traceFolder=editrow(t3,.62,'Registered volume','',@pickTrace);
label(t3,[.04 .51 .28 .055],'Fiber diameter (um)');diam=smallEdit(t3,[.35 .51 .18 .055],'500');
label(t3,[.57 .51 .21 .055],'Channel (optional)');channel=smallEdit(t3,[.8 .51 .16 .055],'');
button(t3,[.04 .38 .43 .085],'Trace optical fiber / GRIN lens',@(~,~)trace('fiber'));
button(t3,[.53 .38 .43 .085],'Trace linear probe trajectory',@(~,~)trace('probe'));
button(t3,[.04 .23 .43 .075],'Whole-brain registration guide',@(~,~)web('https://lightsuite.readthedocs.io/en/latest/usage_volume/','-browser'));
button(t3,[.53 .23 .43 .075],'Probe / implant guide',@(~,~)web('https://lightsuite.readthedocs.io/en/latest/usage_tracing/','-browser'));
label(t3,[.04 .055 .92 .125],['In the annotation window, click the visible track over several sections. 1-9 selects an implant; S saves; F fits. ' ...
    'Diameter and channel must reflect the real implant / image. Inspect the trajectory and atlas registration before interpreting traversed regions.']);

label(t4,[.03 .85 .93 .11],['Optional dependencies live outside the toolbox, under deConfUSIon_ExternalTools. ' ...
    'The installer downloads pinned open-source code, Elastix 5.1.0 and published atlas resources. Licensed MATLAB toolboxes must already be available.']);
depTable=uitable(t4,'Units','normalized','Position',[.03 .2 .93 .62],'ColumnWidth',{250 70 100 420});
button(t4,[.03 .07 .27 .075],'Check dependencies',@checkDeps);
button(t4,[.35 .07 .27 .075],'Install / complete setup',@installDeps);
button(t4,[.67 .07 .29 .075],'Choose external tools folder',@chooseTools);
setappdata(fig,'LightSuiteSeedData',data);setappdata(fig,'LightSuiteSeedMeta',meta);
setappdata(fig,'FUSILightSuiteProjectStart',@projectStart);
setappdata(fig,'FUSILightSuiteOpenProject',@(folder)safe(@()resumeImpl(folder)));
fusiLightSuiteStyle(fig);selectTab(1);refreshIdentity();refreshWorkflow();
set(tutorialButtons,'BackgroundColor',[.12 .18 .27],'ForegroundColor',[.68 .83 1]);
set(guided,'ForegroundColor',[.6 .88 1]);
checkDeps();
try,readGeometryImpl();catch ME,note(['Geometry metadata: ' ME.message]);end
    function selectTab(index)
        set(panels,'Visible','off');panels(index).Visible='on';
        set(tabButtons,'BackgroundColor',[.07 .12 .10],'ForegroundColor',[.68 .81 .74]);
        set(tabButtons(index),'BackgroundColor',[.13 .32 .23],'ForegroundColor',[.85 1 .92]);
    end
    function h=label(parent,pos,str)
        h=uicontrol(parent,'Style','text','Units','normalized','Position',pos,'String',str,'HorizontalAlignment','left','FontSize',11,'BackgroundColor',parent.BackgroundColor);
    end
    function h=smallEdit(parent,pos,str)
        h=uicontrol(parent,'Style','edit','Units','normalized','Position',pos,'String',str,'FontSize',12,'BackgroundColor','w','HorizontalAlignment','left');
    end
    function h=editrow(parent,y,title,value,callback)
        label(parent,[.03 y .18 .055],title);h=smallEdit(parent,[.21 y .65 .06],value);
        button(parent,[.88 y .08 .06],'...',callback);
    end
    function h=button(parent,pos,str,callback)
        h=uicontrol(parent,'Style','pushbutton','Units','normalized','Position',pos,'String',str,'FontSize',11,'Callback',callback);
    end
    function note(str)
        if iscell(str),status.String=str;else,status.String={char(str)};end
        fusiLightSuiteLog('STATUS',currentContext(),str);refreshIdentity();refreshWorkflow();drawnow;
    end
    function safe(callback)
        if isequal(getappdata(fig,'LightSuiteBusy'),true),return;end
        if isappdata(fig,'LightSuiteLastError'),rmappdata(fig,'LightSuiteLastError');end
        setappdata(fig,'LightSuiteBusy',true);fig.Pointer='watch';busyStarted=tic;
        activity.String=['BUSY | Started ' datestr(now,'HH:MM:SS')];activity.ForegroundColor=[1 .78 .3];drawnow nocallbacks;
        cleanup=onCleanup(@()releaseBusy(fig)); %#ok<NASGU>
        try,callback();catch ME
            note(ME.message);setappdata(fig,'LightSuiteLastError',ME);fusiLightSuiteLog('ERROR',currentContext(),ME.message);
            if ~strcmp(ME.identifier,'deConfUSIon:ProcessingCancelled')
                fusiLightSuiteChoice('LightSuite',ME.message,{'Close'});
            end
        end
    end
    function releaseBusy(window)
        if isgraphics(window)
            setappdata(window,'LightSuiteBusy',false);window.Pointer='arrow';
            activity.String=sprintf('READY | Last operation finished in %.1f s',toc(busyStarted));activity.ForegroundColor=[.5 1 .72];
            if isappdata(window,'LightSuiteLastError'),activity.String='ACTION NEEDED | Check the message below';activity.ForegroundColor=[1 .6 .35];end
        end
    end
    function context=currentContext()
        if ~isempty(session),context=session;
        else
            config=cfg;config.sourceFile=file.String;config.outputFolder=out.String;
            context=struct('config',config,'inputMetadata',meta);
        end
    end
    function refreshIdentity(),fusiLightSuiteLabelWindow(fig,currentContext(),[.025 .95 .95 .033]);end
    function refreshWorkflow()
        palette=[.10 .28 .42;.36 .27 .08;.28 .18 .42;.12 .26 .4;.39 .25 .08;.05 .37 .26];
        for n=1:6
            color=palette(n,:);stepButtons(n).FontWeight='normal';
            if n==guideStep,color=min(1,color*1.5);stepButtons(n).FontWeight='bold';end
            set(stepButtons(n),'BackgroundColor',color,'ForegroundColor',[.93 .97 1]);
        end
        set(exportButton,'BackgroundColor',[.06 .4 .27],'ForegroundColor',[.9 1 .93]);
        messages={'NEXT: 1 Prepare anatomy','CONFIRM: 2 Orientation','EDIT: 3 Landmarks, then Save + continue', ...
            'NEXT: 4 Fit registration','CONFIRM: 5 Review the alignment','NEXT: 6 Save all outputs','SAVED: atlas, backgrounds, masks and mapped anatomy'};
        nextLabel.String=messages{guideStep};nextLabel.ForegroundColor=[.55 1 .76];
        if guideStep==2||guideStep==5,nextLabel.ForegroundColor=[1 .8 .35];end
        setappdata(fig,'LightSuiteWorkflowStep',guideStep);
    end
    function h=progressWindow(titleText)
        id=fusiLightSuiteIdentity(currentContext());h=deConfUSIon_ui('progress',[titleText ' | ' id.label],true);
        setappdata(h,'LightSuiteIdentity',id);
    end
    function updateProgress(h,fraction,message)
        deConfUSIon_ui('progressupdate',h,fraction,message);
        if isgraphics(fig),activity.String=['BUSY | ' message];activity.ForegroundColor=[1 .78 .3];end
    end
    function pickFile(~,~),[n,p]=uigetfile({'*.mat;*.nii;*.nii.gz','fUSI recording'},'Select volumetric recording');if ~isequal(n,0),file.String=fullfile(p,n);recordingEdited();end,end
    function recordingEdited(varargin),useSeed=false;session=[];meta=struct();guideStep=1;spacing.String='';safe(@readGeometryImpl);end
    function pickOutput(~,~),p=uigetdir(pwd,'Dedicated LightSuite analysis output folder');if ~isequal(p,0),out.String=p;end,end
    function openOutput(~,~),if isfolder(out.String),winopen(out.String);end,end
    function readGeometry(~,~),safe(@readGeometryImpl);end
    function readGeometryImpl()
        if useSeed
            [mm,source]=fusiLightSuiteInputSpacing(getappdata(fig,'LightSuiteSeedData'),getappdata(fig,'LightSuiteSeedMeta'),file.String);
        else
            meta=fusiLightSuiteReadMetadata(file.String);[mm,source]=fusiLightSuiteSpacing(meta);
        end
        g=struct('voxelSizeMm',mm,'spacingSource',source);
        if isempty(g.voxelSizeMm),note('This header does not identify a supported physical spacing. Enter measured mm values for dimensions 1, 2 and 3.');
        else,spacing.String=num2str(g.voxelSizeMm,10);cfg.spacingSource=g.spacingSource;note(['Spacing read automatically [mm]: ' num2str(g.voxelSizeMm) '. ' g.spacingSource]);end
    end
    function prepare(~,~),safe(@prepareImpl);end
    function prepareImpl()
        if isempty(strtrim(spacing.String)),readGeometryImpl();end
        cfg.voxelSizeMm=sscanf(spacing.String,'%f')';cfg.outputFolder=out.String;
        if ~useSeed||~strcmp(file.String,'Loaded Studio dataset (in memory)'),cfg.sourceFile=file.String;end
        assert(numel(cfg.voxelSizeMm)==3&&all(isfinite(cfg.voxelSizeMm)&cfg.voxelSizeMm>0),'Enter three positive voxel spacings in mm.');
        guideStep=1;progress=progressWindow('Preparing LightSuite anatomy');
        cleanup=onCleanup(@()deConfUSIon_ui('progressclose',progress)); %#ok<NASGU>
        cfg.progressFcn=@(fraction,message)updateProgress(progress,fraction,message);
        note('Preparing a median anatomical template. Reading at most 101 frames; this may take time on a network drive.');
        seed=getappdata(fig,'LightSuiteSeedData');
        if useSeed&&~isempty(seed)&&isstruct(seed)&&isfield(seed,'I')
            session=fusiLightSuite('prepare',seed,getappdata(fig,'LightSuiteSeedMeta'),cfg);
        else,session=fusiLightSuite('preparefile',file.String,cfg);end
        guideStep=2;note('Anatomy prepared. Confirm the physical orientation next.');clear cleanup;
        if guided.Value,orientationImpl();end
    end
    function orientation(~,~),safe(@orientationImpl);end
    function orientationImpl()
        session=needSession();guideStep=2;refreshWorkflow();p=fusiLightSuiteOrientation(session);
        if ~isempty(p)
            session=fusiLightSuite('orientation',session,p);guideStep=3;note('Orientation confirmed. Place matching anatomical landmarks next.');
            if guided.Value,landmarksImpl();end
        else,note('Orientation was not confirmed. Return to step 2 when ready.');end
    end
    function landmarks(~,~),safe(@landmarksImpl);end
    function landmarksImpl()
        s=needSession();continuation=[];
        existing=getappdata(fig,'LightSuiteLandmarkWindow');
        if ~isempty(existing)&&isgraphics(existing)
            identity=getappdata(existing,'LightSuiteIdentity');
            if strcmp(identity.projectFolder,s.opts.savepath),figure(existing);return;end
        end
        if ~isfile(fullfile(s.opts.savepath,'transform_params.mat'))
            guideStep=3;if guided.Value,continuation=@()landmarksFinished(s.opts.savepath);end
        end
        editor=fusiLightSuiteLandmarks(s,continuation);setappdata(fig,'LightSuiteLandmarkWindow',editor);
        note('Landmark editor ready. Save pairs (S) keeps editing; Save + continue finishes editing and starts the fit.');
    end
    function landmarksFinished(projectFolder)
        if ~isgraphics(fig),return;end
        if ~strcmp(projectFolder,session.opts.savepath),note('Landmarks saved for another project. Open that project before fitting.');return;end
        guideStep=4;refreshWorkflow();if guided.Value,safe(@fitImpl);else,note('Landmarks saved. Run step 4 when ready.');end
    end
    function fit(~,~),safe(@fitImpl);end
    function fitImpl()
        guideStep=4;progress=progressWindow('LightSuite registration: current stage');
        cleanup=onCleanup(@()deConfUSIon_ui('progressclose',progress)); %#ok<NASGU>
        note('Fitting affine and B-spline transforms. The progress window reports the current optimization stage and iteration budget.');
        session=fusiLightSuite('register',needSession(), ...
            @(fraction,message)updateProgress(progress,fraction,message));
        guideStep=5;note('Fit saved. Review the affine and nonlinear alignment before accepting.');clear cleanup;
        if guided.Value,reviewImpl();end
    end
    function exportRegions(~,~),safe(@exportRegionsImpl);end
    function exportRegionsImpl()
        progress=progressWindow('Saving LightSuite native atlas backgrounds');
        cleanup=onCleanup(@()deConfUSIon_ui('progressclose',progress)); %#ok<NASGU>
        fusiLightSuite('exportregions',needSession(), ...
            @(fraction,message)updateProgress(progress,fraction,message));
        note({'Saved BOTH atlas stages: Affine only and Affine + B-spline, with regions, available backgrounds and masks.'; ...
            'Use the same original recording grid. Click How to use the outputs for the next steps.'});
        fusiLightSuiteLog('SAVED',needSession(),'Native regions, available atlas backgrounds and masks.\nFolder: %s',session.opts.savepath);
        callback=getappdata(fig,'LightSuiteOutputsSavedCallback');
        if isa(callback,'function_handle'),callback(session.opts.savepath);end
    end
    function revise(~,~),safe(@reviseImpl);end
    function reviseImpl()
        s=needSession();choice=fusiLightSuiteChoice('New registration version', ...
            ['A new timestamped subfolder will preserve the current fit. ' ...
             'Reuse and correct the paired landmarks, or recheck orientation and start new pairs.'], ...
            {'Edit copied landmarks','Recheck orientation','Cancel'});
        if isempty(choice)||strcmp(choice,'Cancel'),return;end
        mode='landmarks';if strcmp(choice,'Recheck orientation'),mode='orientation';end
        session=fusiLightSuite('revise',s,[],mode);out.String=session.opts.savepath;refreshIdentity();
        note(['New version: ' session.opts.savepath '. Previous fit preserved. Review the new fit before saving its atlas outputs.']);
        if strcmp(mode,'orientation'),guideStep=2;orientationImpl();else,guideStep=3;landmarksImpl();end
    end
    function outputHelp(~,~)
        f=figure('Name','deConfUSIon | Use LightSuite outputs','NumberTitle','off','Color',[.035 .045 .045], ...
            'MenuBar','none','ToolBar','none','Position',[170 140 900 610]);
        uicontrol(f,'Style','text','Units','normalized','Position',[.045 .10 .91 .85], ...
            'HorizontalAlignment','left','FontSize',13,'String',{ ...
            '1. REVIEW: select coronal, horizontal/axial and sagittal planes. Scroll slices and compare the affine and nonlinear vessel overlays, checkerboard and solid region boundaries. Accept only if vessels, geometry and coverage agree.'; ...
            'If alignment is wrong, click Do not accept. Use Re-register (new version). Choose Edit copied landmarks, or Recheck orientation to start new pairs. Each run gets a timestamped subfolder; refit and review there.'; ''; ...
            '2. GUIDED SAVE: Accept + save all outputs closes review, maps anatomy and exports regions, available backgrounds and masks automatically. anatomy_in_atlas.mat is for anatomical QC, not a functional movie.'; ''; ...
            '3. MANUAL SAVE: step 6 saves all outputs. SAVE / EXPORT BOTH ATLAS STAGES + MASKS exports Affine only and Affine + B-spline on the original recording grid.'; ''; ...
            '4. SCM / VIDEO: open the same native recording, click LOAD ATLAS, choose LightSuite folder, and select the project folder. Choose Vascular, Histology or Regions. In SCM, Registration stage switches the alignment; EXPORT ATLAS copies both stages to a portable folder.'; ''; ...
            '5. MASK EDITOR: open the same native recording, Load external underlay, and select LightSuite_Native_Mask.mat. Review and edit the imported tissue mask before saving.'; ''; ...
            '6. FC: load the same recording, then load ROI / atlas labels from LightSuite_Native_Regions.mat. Names and hemispheres are included.'; ''; ...
            'Keep the complete project: transform_params.mat, B-spline parameter files, landmarks and session metadata form one transform chain. There is no single affine Transformation.mat for this nonlinear fit.'; ...
            'Do not reuse native labels after cropping, resampling or changing orientation. They do not register another scan automatically.'});
        uicontrol(f,'Style','pushbutton','Units','normalized','Position',[.71 .025 .245 .06], ...
            'String','Close','Callback',@(~,~)delete(f));fusiLightSuiteStyle(f);
    end
    function p=projectStart()
        p=fusiLightSuiteProjectStart(file.String,out.String,meta);
    end
    function resume(~,~)
        picker=getappdata(fig,'FUSILightSuiteFolderPicker');
        if isempty(picker),picker=@uigetdir;end
        p=picker(projectStart(),'Existing deConfUSIon LightSuite project');
        if ~isequal(p,0),safe(@()resumeImpl(p));end
    end
    function resumeImpl(p)
        session=fusiLightSuite('load',p);useSeed=false;out.String=p;file.String=session.config.sourceFile;spacing.String=num2str(session.opts.sample_res);
        meta=struct();if isfield(session,'inputMetadata'),meta=session.inputMetadata;end
        if ~session.orientationConfirmed,guideStep=2;
        elseif isfile(fullfile(p,'transform_params.mat'))
            guideStep=5;if session.fitReviewed,guideStep=6;end
            if session.fitReviewed&&all(cellfun(@(name)isfile(fullfile(p,name)), ...
                    {'anatomy_in_atlas.mat','LightSuite_Native_Regions.mat','LightSuite_Native_Backgrounds.mat','LightSuite_Native_Mask.mat', ...
                    'LightSuite_Affine_Native_Regions.mat','LightSuite_Affine_Native_Backgrounds.mat','LightSuite_Affine_Native_Mask.mat'})),guideStep=7;end
        elseif isfile(fullfile(p,'control_points_minimal.mat')),guideStep=4;
        else,guideStep=3;end
        note('Resumed LightSuite project. The next required step is highlighted.');
    end
    function s=needSession(),if isempty(session),session=fusiLightSuite('load',out.String);end;s=session;end
    function review(~,~),safe(@reviewImpl);end
    function reviewImpl()
        s=needSession();guideStep=5;note('Preparing interactive affine / nonlinear review volumes...');
        reviewWindow=fusiLightSuiteRegistrationReview(s,@reviewChanged);setappdata(fig,'LightSuiteReviewWindow',reviewWindow);
        if guided.Value
            acceptButton=findall(reviewWindow,'Tag','LightSuiteReviewAccept');
            set(acceptButton,'String','Accept + save all outputs','BackgroundColor',[.05 .4 .27],'FontWeight','bold');
        end
        note('Review: select a plane, scroll through slices and compare the vessel overlay and solid region boundaries. Numerical status is shown before acceptance.');
    end
    function reviewChanged(s,message,action)
        if ~isgraphics(fig),return;end
        if ~strcmp(s.opts.savepath,session.opts.savepath),note('This review belongs to another project. Open that project before continuing.');return;end
        session=s;if strcmp(action,'accept'),guideStep=6;end;note(message);
        if strcmp(action,'accept')&&guided.Value
            reviewWindow=getappdata(fig,'LightSuiteReviewWindow');if ~isempty(reviewWindow)&&isgraphics(reviewWindow),delete(reviewWindow);end
            safe(@saveOutputsImpl);
        end
    end
    function saveOutputs(~,~),safe(@saveOutputsImpl);end
    function saveOutputsImpl()
        s=needSession();assert(s.fitReviewed,'Review and accept the fit in step 5 before saving the atlas outputs.');
        guideStep=6;note('Saving mapped anatomy, native atlas backgrounds, region labels and editable tissue masks...');
        mapImpl(false);exportRegionsImpl();guideStep=7;refreshWorkflow();
        note({'SAVED: LightSuite analysis outputs are ready.';['Folder: ' s.opts.savepath]; ...
            'SCM / Video: LOAD ATLAS > LightSuite folder. Mask Editor: LightSuite_Native_Mask.mat.'});
        fusiLightSuiteLog('SAVED',s,'ALL OUTPUTS READY\nFolder: %s',s.opts.savepath);
    end
    function mapImpl(showReview)
        if nargin<1,showReview=true;end
        progress=progressWindow('Saving LightSuite mapped anatomy');
        cleanup=onCleanup(@()deConfUSIon_ui('progressclose',progress)); %#ok<NASGU>
        deConfUSIon_ui('progressupdate',progress,NaN,'Applying the accepted transform chain to one anatomical volume...');
        s=needSession();r=fusiLightSuite('apply',s,s.opts.sample,true);
        updateProgress(progress,NaN,'Saving mapped anatomy...');
        save(fullfile(s.opts.savepath,'anatomy_in_atlas.mat'),'-struct','r','-v7.3');
        if showReview,fusiLightSuiteAnatomyReview(s,r);end
        updateProgress(progress,1,'Mapped anatomy saved.');
        note('Mapped anatomy saved in anatomy_in_atlas.mat. Saving native atlas labels, backgrounds and masks next.');
    end
    function checkDeps(~,~),safe(@checkDepsImpl);end
    function checkDepsImpl(),r=fusiLightSuiteDependencies(cfg);depTable.Data=table2cell(r.table);depTable.ColumnName=r.table.Properties.VariableNames;note(sprintf('Dependency check: fUSI %d | TIFF histology %d | CZI %d. %s',r.fusiReady,r.histologyReady,r.cziReady,r.elastixVersion));end
    function installDeps(~,~),safe(@installImpl);end
    function installImpl()
        note('Installing pinned optional dependencies and atlas files outside the toolbox. Downloading the Allen reference may take several minutes.');
        script=fullfile(fileparts(mfilename('fullpath')),'install_lightsuite_dependencies.ps1');
        [code,txt]=system(sprintf('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%s" -Destination "%s" -IncludeHistology',script,cfg.externalRoot));
        assert(code==0,'Dependency installation failed: %s',txt);checkDepsImpl();
    end
    function chooseTools(~,~)
        p=uigetdir(cfg.externalRoot,'Folder containing LightSuite, matlab_elastix, yamlmatlab, etc.');
        if isequal(p,0),return;end
        names={'lightSuite','matlabElastix','yamlMatlab','bcpd','elastixBin','allenAtlas','vascularAtlas','bioformats','bfmatlab'};
        old=cfg.externalRoot;for k=1:numel(names),cfg.(names{k})=strrep(cfg.(names{k}),old,p);end
        cfg.externalRoot=p;paths=struct('externalRoot',p);for k=1:numel(names),paths.(names{k})=cfg.(names{k});end
        setpref('deConfUSIonLightSuite','paths',paths);checkDeps();
    end
    function pickHistInput(~,~),p=uigetdir(pwd,'Serial TIFF / CZI sections folder');if ~isequal(p,0),histSource.String=p;end,end
    function pickHistOutput(~,~),p=uigetdir(pwd,'Dedicated histology output folder');if ~isequal(p,0),histOut.String=p;end,end
    function histPrepare(~,~),safe(@histPrepareImpl);end
    function histPrepareImpl()
        fs=[dir(fullfile(histSource.String,'*.tif'));dir(fullfile(histSource.String,'*.tiff'));dir(fullfile(histSource.String,'*.czi'))];
        isCzi=endsWith({fs.name},'.czi','IgnoreCase',true);
        if any(isCzi),fs=fs(isCzi);end % CZI mode takes priority over its TIFF previews.
        [~,order]=sort(lower(string({fs.name})));fs=fs(order);paths=fullfile({fs.folder},{fs.name});
        o=struct('pixelSizeUm',str2double(hp.String),'sectionSpacingUm',str2double(hs.String), ...
            'channelNames',{strtrim(strsplit(hc.String,','))},'registrationChannel',strtrim(hr.String), ...
            'atlasAPLimits',sscanf(ha.String,'%f')');
        assert(numel(o.atlasAPLimits)==2&&all(o.atlasAPLimits>=1)&all(o.atlasAPLimits<=1320),'Enter two valid Allen 10 um AP indices.');
        note('Preparing histology analysis copies. Raw sections will remain unchanged.');
        histFolder=fusiLightSuite('histology','prepare',histOut.String,paths,o);note('Prepared. Review order, crop bounds and exclusions before initial alignment.');
    end
    function histRun(stage),safe(@()histRunImpl(stage));end
    function histRunImpl(stage),assert(~isempty(histFolder),'Prepare or open a histology project first.');note(['Running histology stage: ' stage]);fusiLightSuite('histology',stage,histFolder);note(['Finished / opened histology stage: ' stage '. Save decisions in each window.']);end
    function histResume(~,~),p=uigetdir(pwd,'Folder with sliceinfo.mat or histology_project.txt');if ~isequal(p,0),histFolder=p;histOut.String=p;note('Histology project selected.');end,end
    function histCells(~,~),safe(@histCellsImpl);end
    function histCellsImpl()
        a=inputdlg({'Detection channel indices','Cell diameter (um)','SBR thresholds [detection expansion]'},'Exploratory cell detection',1,{'2','14','.75 .4'});
        if isempty(a),return;end
        fusiLightSuite('histology','cells',histFolder,sscanf(a{1},'%f')',str2double(a{2}),sscanf(a{3},'%f')');
        note('Cell detection finished. Inspect diagnostic images before regional counts.');
    end
    function histMapCells(~,~),safe(@histMapCellsImpl);end
    function histMapCellsImpl(),a=inputdlg('Channel indices','Map detected cells',1,{'2'});if isempty(a),return;end;fusiLightSuite('histology','mapcells',histFolder,sscanf(a{1},'%f')');note('Detected cell coordinates mapped to the atlas.');end
    function pickTrace(~,~),p=uigetdir(pwd,'Registered LightSuite whole-brain histology');if ~isequal(p,0),traceFolder.String=p;end,end
    function trace(kind),safe(@()traceImpl(kind));end
    function traceImpl(kind)
        args={};ch=str2double(channel.String);if isfinite(ch),args={'Channel',ch};end
        if strcmp(kind,'fiber'),d=str2double(diam.String);assert(isfinite(d)&&d>0,'Enter a positive measured fiber diameter.');args=[args {'Diameter',d}];end
        fusiLightSuite('trace',traceFolder.String,kind,args{:});
    end
end
