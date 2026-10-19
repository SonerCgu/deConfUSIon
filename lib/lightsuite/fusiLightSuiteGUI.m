function fig=fusiLightSuiteGUI(data,meta,overrides)
% Independent optional workspace. All manual choices and output are resumable.
if nargin<1,data=[];end
if nargin<2||isempty(meta),meta=struct();end
if nargin<3,overrides=struct();end
cfg=fusiLightSuiteConfig(overrides);session=[];histFolder='';
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
    'Color',[.055 .075 .08],'MenuBar','none','ToolBar','none','Position',[120 80 1060 790]);
tabs=uipanel(fig,'Units','normalized','Position',[.02 .17 .96 .81],'BorderType','none');
panels=gobjects(1,4);tabButtons=gobjects(1,4);
tabNames={'3D fUSI registration','Histology sections','Fiber / probe trajectories','Dependencies'};
for ti=1:4
    panels(ti)=uipanel(tabs,'Units','normalized','Position',[0 0 1 .90],'BorderType','none','Visible','off');
    tabButtons(ti)=uicontrol(tabs,'Style','pushbutton','Units','normalized', ...
        'Position',[.005+(ti-1)*.25 .925 .24 .065],'String',tabNames{ti}, ...
        'FontSize',11,'FontWeight','bold','Callback',@(~,~)selectTab(ti));
end
t1=panels(1);t2=panels(2);t3=panels(3);t4=panels(4);
status=uicontrol(fig,'Style','edit','Max',5,'Min',0,'Units','normalized','Position',[.025 .025 .95 .125], ...
    'String',{'Experimental optional method. Review all geometry, landmarks, affine and nonlinear diagnostic views.'; ...
    'LightSuite: Karamanlis et al. (2026), DOI 10.64898/2026.10.13.757638. Existing registration is unchanged.'}, ...
    'HorizontalAlignment','left','FontSize',11,'Enable','inactive','BackgroundColor',[.08 .12 .13],'ForegroundColor',[.85 .95 .89]);
label(t1,[.03 .9 .92 .07],['Alternative vascular-atlas registration: prepare anatomy, confirm orientation, place matching landmarks, ' ...
    'then fit affine + B-spline transforms. This is landmark-guided, not an unattended fit.']);
file=editrow(t1,.82,'Recording',cfg.sourceFile,@pickFile);
file.Tag='LightSuiteRecording';file.Callback=@recordingEdited;
if useSeed&&isempty(file.String),file.String='Loaded Studio dataset (in memory)';end
if useSeed,file.TooltipString='The active Studio dataset is selected. Prepare uses its current in-memory data. Browse to select a different recording.';end
out=editrow(t1,.73,'Output folder',cfg.outputFolder,@pickOutput);
label(t1,[.03 .635 .4 .05],'Voxel spacing along input dimensions [mm]');
spacing=uicontrol(t1,'Style','edit','Units','normalized','Position',[.43 .635 .28 .055], ...
    'String',num2str(cfg.voxelSizeMm),'FontSize',12,'BackgroundColor','w','Tag','LightSuiteSpacing');
uicontrol(t1,'Style','pushbutton','Units','normalized','Position',[.73 .635 .23 .055], ...
    'String','Read metadata spacing','FontSize',11,'Callback',@readGeometry);
label(t1,[.03 .565 .92 .05],'Confirm units and each axis. Preparation reads at most 101 time points for a median anatomy; it does not preprocess the recording.');
button(t1,[.03 .47 .29 .07],'1  Prepare anatomy',@prepare);
button(t1,[.35 .47 .29 .07],'2  Confirm orientation',@orientation);
button(t1,[.67 .47 .29 .07],'3  Place / edit landmarks',@landmarks);
button(t1,[.03 .36 .29 .07],'4  Fit affine + B-spline',@fit);
button(t1,[.35 .36 .29 .07],'5  Interactive fit review',@review);
button(t1,[.67 .36 .29 .07],'6  Map anatomy to atlas',@mapAnatomy);
button(t1,[.03 .25 .29 .07],'Open existing project',@resume);
button(t1,[.35 .25 .29 .07],'Open output folder',@openOutput);
button(t1,[.67 .25 .29 .07],'Landmark instructions',@(~,~)fusiLightSuiteLandmarkHelp());
button(t1,[.03 .16 .29 .065],'Export native region labels',@exportRegions);
button(t1,[.35 .16 .29 .065],'Revise fit in new project',@revise);
button(t1,[.67 .16 .29 .065],'How to use the outputs',@outputHelp);
label(t1,[.03 .015 .93 .11],['Keep in mind: five noncoplanar pairs are the minimum, not an accuracy target. ' ...
    'Spread many landmarks over the acquired brain. Compare affine and nonlinear overlays; examine local over-warping. ' ...
    'Atlas coordinates are AP x DV x ML, 50 um. Raw probe origin is retained as provenance and never treated as a CCF origin. ' ...
    'Full atlas movies are off by default; use the script API for regional timecourses.']);

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
fusiLightSuiteStyle(fig);selectTab(1);
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
    function button(parent,pos,str,callback)
        uicontrol(parent,'Style','pushbutton','Units','normalized','Position',pos,'String',str,'FontSize',11,'Callback',callback);
    end
    function note(str)
        if iscell(str),status.String=str;else,status.String={char(str)};end
        drawnow;
    end
    function safe(callback)
        if isequal(getappdata(fig,'LightSuiteBusy'),true),return;end
        setappdata(fig,'LightSuiteBusy',true);fig.Pointer='watch';cleanup=onCleanup(@()releaseBusy(fig)); %#ok<NASGU>
        try,callback();catch ME
            note(ME.message);setappdata(fig,'LightSuiteLastError',ME);
            if ~strcmp(ME.identifier,'deConfUSIon:ProcessingCancelled')
                fusiLightSuiteChoice('LightSuite',ME.message,{'Close'});
            end
        end
    end
    function releaseBusy(window),if isgraphics(window),setappdata(window,'LightSuiteBusy',false);window.Pointer='arrow';end,end
    function pickFile(~,~),[n,p]=uigetfile({'*.mat;*.nii;*.nii.gz','fUSI recording'},'Select volumetric recording');if ~isequal(n,0),useSeed=false;file.String=fullfile(p,n);spacing.String='';safe(@readGeometryImpl);end,end
    function recordingEdited(~,~),useSeed=false;spacing.String='';safe(@readGeometryImpl);end
    function pickOutput(~,~),p=uigetdir(pwd,'Dedicated LightSuite analysis output folder');if ~isequal(p,0),out.String=p;end,end
    function openOutput(~,~),if isfolder(out.String),winopen(out.String);end,end
    function readGeometry(~,~),safe(@readGeometryImpl);end
    function readGeometryImpl()
        if useSeed
            [mm,source]=fusiLightSuiteInputSpacing(getappdata(fig,'LightSuiteSeedData'),getappdata(fig,'LightSuiteSeedMeta'),file.String);
        else
            [mm,source]=fusiLightSuiteSpacing(fusiLightSuiteReadMetadata(file.String));
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
        progress=deConfUSIon_ui('progress','Preparing LightSuite anatomy',true);
        cleanup=onCleanup(@()deConfUSIon_ui('progressclose',progress)); %#ok<NASGU>
        cfg.progressFcn=@(fraction,message)deConfUSIon_ui('progressupdate',progress,fraction,message);
        note('Preparing a median anatomical template. Reading at most 101 frames; this may take time on a network drive.');
        seed=getappdata(fig,'LightSuiteSeedData');
        if useSeed&&~isempty(seed)&&isstruct(seed)&&isfield(seed,'I')
            session=fusiLightSuite('prepare',seed,getappdata(fig,'LightSuiteSeedMeta'),cfg);
        else,session=fusiLightSuite('preparefile',file.String,cfg);end
        note('Anatomy prepared. Next confirm orientation; the recording and established affine registration have not been changed.');
    end
    function orientation(~,~),safe(@orientationImpl);end
    function orientationImpl()
        session=needSession();p=fusiLightSuiteOrientation(session);
        if ~isempty(p),session=fusiLightSuite('orientation',session,p);note('Orientation confirmed. Place matching anatomical landmarks next.');end
    end
    function landmarks(~,~),safe(@()fusiLightSuite('landmarks',needSession()));end
    function fit(~,~),safe(@fitImpl);end
    function fitImpl()
        progress=deConfUSIon_ui('progress','LightSuite registration: current stage',true);
        cleanup=onCleanup(@()deConfUSIon_ui('progressclose',progress)); %#ok<NASGU>
        note('Fitting affine and B-spline transforms. The progress window reports the current optimization stage and iteration budget.');
        session=fusiLightSuite('register',needSession(), ...
            @(fraction,message)deConfUSIon_ui('progressupdate',progress,fraction,message));
        note('Fit and numerical inverse checks finished. Review both affine and nonlinear diagnostic overlays before accepting.');
    end
    function exportRegions(~,~),safe(@exportRegionsImpl);end
    function exportRegionsImpl()
        progress=deConfUSIon_ui('progress','Export LightSuite native atlas labels',true);
        cleanup=onCleanup(@()deConfUSIon_ui('progressclose',progress)); %#ok<NASGU>
        fusiLightSuite('exportregions',needSession(), ...
            @(fraction,message)deConfUSIon_ui('progressupdate',progress,fraction,message));
        note({'Saved LightSuite_Native_Regions.mat for SCM / Video / FC / Segmentation, and LightSuite_Native_Mask.mat for Mask Editor.'; ...
            'Use the same original recording grid. Click How to use the outputs for the next steps.'});
    end
    function revise(~,~),safe(@reviseImpl);end
    function reviseImpl()
        s=needSession();destination=fullfile(fileparts(s.opts.savepath), ...
            ['LightSuite_Revision_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);
        session=fusiLightSuite('revise',s,destination);out.String=destination;
        note(['Revision project created: ' destination '. The old fit is preserved. Edit landmarks (step 3), fit again (4), then review (5).']);
        fusiLightSuite('landmarks',session);
    end
    function outputHelp(~,~)
        f=figure('Name','deConfUSIon | Use LightSuite outputs','NumberTitle','off','Color',[.035 .045 .045], ...
            'MenuBar','none','ToolBar','none','Position',[170 140 900 610]);
        uicontrol(f,'Style','text','Units','normalized','Position',[.045 .10 .91 .85], ...
            'HorizontalAlignment','left','FontSize',13,'String',{ ...
            '1. REVIEW: select coronal, horizontal/axial and sagittal planes. Scroll slices and compare the affine and nonlinear vessel overlays, checkerboard and solid region boundaries. Accept only if vessels, geometry and coverage agree.'; ...
            'If alignment is wrong, click Do not accept. Use Revise fit in new project, edit paired landmarks, refit and review.'; ''; ...
            '2. MAP ANATOMY (optional): step 6 saves anatomy_in_atlas.mat and opens an anatomical QC viewer. This is not a functional movie.'; ''; ...
            '3. EXPORT: click Export native region labels. This saves atlas IDs / hemisphere masks on the original recording grid.'; ''; ...
            '4. SCM / VIDEO: open the same native recording, click LOAD ATLAS, and select the project folder or LightSuite_Native_Regions.mat.'; ''; ...
            '5. MASK EDITOR: open the same native recording, Load external underlay, and select LightSuite_Native_Mask.mat. Review and edit the imported tissue mask before saving.'; ''; ...
            '6. FC: load the same recording, then load ROI / atlas labels from LightSuite_Native_Regions.mat. Names and hemispheres are included.'; ''; ...
            'Keep the complete project: transform_params.mat, B-spline parameter files, landmarks and session metadata form one transform chain. There is no single affine Transformation.mat for this nonlinear fit.'; ...
            'Do not reuse native labels after cropping, resampling or changing orientation. They do not register another scan automatically.'});
        uicontrol(f,'Style','pushbutton','Units','normalized','Position',[.71 .025 .245 .06], ...
            'String','Close','Callback',@(~,~)delete(f));fusiLightSuiteStyle(f);
    end
    function resume(~,~),p=uigetdir(pwd,'Existing deConfUSIon LightSuite project');if ~isequal(p,0),safe(@()resumeImpl(p));end,end
    function resumeImpl(p),session=fusiLightSuite('load',p);useSeed=false;out.String=p;file.String=session.config.sourceFile;spacing.String=num2str(session.opts.sample_res);note('Resumed LightSuite project.');end
    function s=needSession(),if isempty(session),session=fusiLightSuite('load',out.String);end;s=session;end
    function review(~,~),safe(@reviewImpl);end
    function reviewImpl()
        s=needSession();note('Preparing interactive affine / nonlinear review volumes...');
        fusiLightSuiteRegistrationReview(s,@reviewChanged);
        note('Review: select a plane, scroll through slices and compare the vessel overlay and solid region boundaries. Numerical status is shown before acceptance.');
    end
    function reviewChanged(s,message),session=s;note(message);end
    function mapAnatomy(~,~),safe(@mapImpl);end
    function mapImpl()
        progress=deConfUSIon_ui('progress','Mapping LightSuite anatomy',false);
        cleanup=onCleanup(@()deConfUSIon_ui('progressclose',progress)); %#ok<NASGU>
        deConfUSIon_ui('progressupdate',progress,NaN,'Applying the accepted transform chain to one anatomical volume...');
        s=needSession();r=fusiLightSuite('apply',s,s.opts.sample,true);
        deConfUSIon_ui('progressupdate',progress,NaN,'Saving mapped anatomy and preparing three orthogonal views...');
        save(fullfile(s.opts.savepath,'anatomy_in_atlas.mat'),'-struct','r','-v7.3');
        fusiLightSuiteAnatomyReview(s,r);
        deConfUSIon_ui('progressupdate',progress,1,'Anatomical QC viewer ready.');
        note('Anatomy mapped and saved. Inspect the three orthogonal views; then Export native region labels to use the atlas with your original recording in SCM / Video / FC / Mask Editor.');
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
