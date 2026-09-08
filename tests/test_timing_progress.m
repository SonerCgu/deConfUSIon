function test_timing_progress(part)
if nargin<1, part='all'; end
root=fileparts(fileparts(mfilename('fullpath'))); addpath(root);
if any(strcmp(part,{'timing','all'})), timingTests(); end
if any(strcmp(part,{'progress','all'})), progressTests(root); end
if any(strcmp(part,{'setup','all'})), setupTests(root); end
if any(strcmp(part,{'cache','all'})), cacheTest(); end
if any(strcmp(part,{'motor','all'})), motorTimingTests(); end
if any(strcmp(part,{'launch','all'})), motorLaunchTest(); end
fprintf('PASS timing/progress: %s\n',part);
end

function motorTimingTests()
raw=struct('I',ones(3,4,44,'single'),'TR',.385);
source=struct('TR',.385,'frameCount',44,'durationSec',44*.385);
for nt=[2244 89]
    originalTR=.385; if nt==89, originalTR=9.625; end
    D=struct('I',single(100+randn(3,4,4,nt)),'TR',originalTR*44/2244, ...
        'acquisitionTiming',source,'motorInfo',struct('TR',.385,'reconstructedFramesPerSlice',2244));
    [fixed,notice]=deConfUSIon_signal('timing',D,raw);
    assert(abs(fixed.TR-originalTR)<1e-10 && ~isempty(notice));
    assert(abs(fixed.displayDurationSec-863.94)<1e-8 && isequal(fixed.I,D.I));
    [again,notice]=deConfUSIon_signal('timing',fixed,raw);
    assert(again.TR==fixed.TR && isempty(notice));
    proc=computePSC(fixed.I,fixed.TR,struct('interpol',1),struct('start',20,'end',40));
    assert(isequal(size(proc.PSC),size(D.I)));
    [out,stats]=pca_denoise(fixed,tempdir,'motor_regression', ...
        struct('nCompMax',5,'autoSelect',[1 2 3],'autoApply',true));
    assert(stats.applied && isequal(size(out.I),size(fixed.I)) && out.TR==fixed.TR);
    fprintf('PASS motor %d frames: TR %.6g s; PCA preserves frames and timing.\n',nt,fixed.TR);
end
try
    computePSC(ones(3,4,10,'single'),1,struct('interpol',100),struct('start',20,'end',40));
    error('test:MissingError','Invalid baseline accepted');
catch ME
    assert(strcmp(ME.identifier,'deConfUSIon:BadBaseline'));
end
end

function motorLaunchTest()
run_fusi_studio; f=getappdata(0,'deConfUSIonMainFigure'); guard=onCleanup(@()delete(f)); %#ok<NASGU>
state=guidata(f); state.isLoaded=true; state.exportPath=tempname; mkdir(state.exportPath);
state.loadedName='Motor timing launch regression'; state.loadedFile='';
raw=struct('I',ones(8,9,44,'single'),'TR',.385);
D=struct('I',single(100+randn(8,9,4,89)),'TR',9.625*44/2244, ...
    'acquisitionTiming',struct('TR',.385,'frameCount',44,'durationSec',44*.385), ...
    'motorInfo',struct('TR',.385,'reconstructedFramesPerSlice',2244),'isStepMotor',true);
state.datasets=struct('raw',raw,'processed',D); state.activeDataset='processed'; guidata(f,state);
for method={'SCM GUI','Video GUI'}
    setappdata(f,'deconf_std_workflow_step',struct('name',method{1},'base1',20,'base2',40,'sig1',60,'sig2',90));
    for k=1:numel(state.allButtons)
        b=get(state.allButtons{k},'UserData');
        if strcmp(get(b.text,'String'),method{1}), b.callback(state.allButtons{k},[]); break; end
    end
    if strcmp(method{1},'SCM GUI')
        ax=findall(0,'Tag','SCMTimeCourseAxes'); assert(numel(ax)==1); child=ancestor(ax,'figure');
    else
        child=findall(0,'Type','figure','Name','fUSI Video Analysis'); assert(numel(child)==1);
    end
    current=guidata(f); assert(abs(current.datasets.processed.TR-9.625)<1e-8);
    delete(child);
    if strcmp(method{1},'SCM GUI')
        % Force Video to compute once, then confirm it publishes its cache.
        current.datasets.processed=rmfield(current.datasets.processed,{'PSC','bg','deconfPscKey','deconfPscDatasetKey'});
        guidata(f,current);
    else
        assert(isfield(current.datasets.processed,'PSC') && strcmp(current.datasets.processed.deconfPscDatasetKey,'processed'));
    end
end
% Exercise the real graphical-button dispatcher, including cleanup on error.
h=state.allButtons{k}; ud=get(h,'UserData'); ud.enabled=true; ud.callback=@(~,~)error('test:CallbackFailure','Deliberate regression-test error'); set(h,'UserData',ud);
click=get(ud.text,'ButtonDownFcn'); click(ud.text,[]);
state=guidata(f); assert(contains(get(state.statusText,'String'),'CRASHED'));
assert(~getappdata(f,'StudioActionBusy')); assert(strcmp(get(findobj(f,'Tag','datasetDropdown'),'Enable'),'on'));
errors=findall(0,'Type','figure','Name','Action failed'); delete(errors);
fprintf('PASS repaired motor SCM/Video launch and callback error recovery.\n');
end

function cacheTest()
run_fusi_studio; f=getappdata(0,'deConfUSIonMainFigure'); guard=onCleanup(@()delete(f)); %#ok<NASGU>
state=guidata(f); state.isLoaded=true; state.exportPath=tempname; mkdir(state.exportPath);
state.loadedName='PSC cache regression'; state.loadedFile='';
data=struct('I',single(100+randn(8,9,90)),'TR',.5,'PSC',ones(8,9,90,'single')*999, ...
    'bg',ones(8,9),'deconfPscKey',[0 1 .5 90 1],'deconfPscDatasetKey','raw');
state.datasets=struct('raw',data,'processed',data); state.activeDataset='processed'; guidata(f,state);
setappdata(f,'deconf_std_workflow_step',struct('name','SCM GUI','base1',0,'base2',1,'sig1',10,'sig2',15));
for k=1:numel(state.allButtons)
    b=get(state.allButtons{k},'UserData');
    if strcmp(get(b.text,'String'),'SCM GUI'), b.callback(state.allButtons{k},[]); break; end
end
after=guidata(f); D=after.datasets.processed;
assert(strcmp(D.deconfPscDatasetKey,'processed') && max(D.PSC(:))<999,'Child dataset reused its parent PSC.');
assert(isequal(D.I,data.I));
scmAxes=findall(0,'Tag','SCMTimeCourseAxes'); assert(numel(scmAxes)==1);
limits=get(scmAxes,'XLim'); assert(abs(limits(2)-45/60)<1e-8);
delete(ancestor(scmAxes,'figure'));
% Reopening the same dataset/window is a cache hit, even if the signal
% interval changes (PSC depends on the baseline, not the mapping interval).
step=getappdata(f,'deconf_std_workflow_step'); step.sig1=15; step.sig2=20; setappdata(f,'deconf_std_workflow_step',step);
b.callback(state.allButtons{k},[]);
after=guidata(f);
if ~isempty(after.logBoxJava), logText=char(after.logBoxJava.getText());
else, logText=strjoin(cellstr(get(after.logBox,'String')),newline); end
assert(contains(logText,'Reusing cached PSC'));
delete(ancestor(findall(0,'Tag','SCMTimeCourseAxes'),'figure'));
fprintf('PASS actual Studio PSC cache identity and duration propagation.\n');
end

function timingTests()
raw=struct('I',ones(3,4,2000,'single'),'TR',.448);
folder='Z:\fUS\Project_PACAP_AVATAR_SC\AnalysedData\MPI_Data\RGRO_260813_1024_MM_B6J_1287\RGRO_13082026_MM_B6J_1024_1287_PACAPvscsf01nM_4_FUS_104646\Preprocessing';
files=dir(fullfile(folder,'*.mat'));
for k=1:numel(files)
    file=fullfile(folder,files(k).name);
    tr=h5read(file,'/newData/TR'); nt=h5read(file,'/newData/nVols');
    D=struct('I',ones(3,4,nt,'single'),'TR',tr,'PSC',zeros(3,4,nt,'single'),'TotalTimeSec',nt*tr);
    try, D.originalTotalTimeSec=h5read(file,'/newData/originalTotalTimeSec'); catch, end
    [fixed,notice]=deConfUSIon_signal('timing',D,raw);
    assert(abs(fixed.TR*nt-896)<1e-8 && fixed.displayDurationSec==896);
    assert(isequal(fixed.I,D.I));
    [again,second]=deConfUSIon_signal('timing',fixed,raw);
    assert(again.TR==fixed.TR && isempty(second),'Repeated selection changed timing again.');
    if tr==.32 || tr==16, assert(~isempty(notice) && ~isfield(fixed,'PSC')); end
    fprintf('%s: TR %.3f -> %.3f; duration %.3f s\n',files(k).name,tr,fixed.TR,fixed.displayDurationSec);
end
D=deConfUSIon_signal('timing',raw); [cut,~]=Motion('chop',D,10,20);
cut=deConfUSIon_signal('timing',cut,raw); assert(cut.displayDurationSec<896 && cut.TR==raw.TR);
% Different sample spacing must not change the automatic SCM x-axis extent.
for nt=[40 80]
    tr=896/nt; p=struct('displayDurationSec',896,'exportPath',tempdir);
    base=struct('start',0,'end',30,'sigStart',60,'sigEnd',90,'mode','sec');
    f=SCM_gui(single(randn(12,13,nt)),ones(12,13),tr,p,base,nt,'timing test');
    guard=onCleanup(@()delete(f)); button=findall(f,'Style','pushbutton','String','Compute SCM'); cb=get(button,'Callback'); cb(button,[]);
    ax=findall(f,'Tag','SCMTimeCourseAxes'); limits=get(ax,'XLim'); assert(abs(limits(2)-896/60)<1e-8);
    clear guard;
end
end

function progressTests(root)
h=deConfUSIon_ui('progress','Validation'); pause(1.1);
deConfUSIon_ui('progressupdate',h,.4,'Processing voxel blocks');
assert(isequal(getappdata(h,'deConfUSIonNoMaximize'),true));
drawnow; shot=getframe(h); imwrite(shot.cdata,fullfile(root,'validation','processing_progress.png'));
setappdata(h,'CancelProcessing',true);
try, deConfUSIon_ui('progressupdate',h,.5,'Cancelled'); error('test:NoCancel','Cancellation failed.');
catch ME, assert(strcmp(ME.identifier,'deConfUSIon:ProcessingCancelled')); end
deConfUSIon_ui('progressclose',h);
outFolder=tempname; mkdir(outFolder);
for dims={[12 13 40],[12 13 3 40]}
    I=single(100+randn(dims{1}));
    [F,~]=filtering(I,1,outFolder,struct('type','low','FcHigh',.2,'saveQC',false)); assert(isequal(size(F),size(I)));
    [D,~]=despike(I,5,outFolder,'progress_test'); assert(isequal(size(D),size(I)));
    cfg=struct('cancelled',false,'method','DVARS','interpMethod','linear','doTrim',false);
    [S,stats]=scrubbing(I,1,outFolder,'progress_test',cfg); assert(isequal(size(S),size(I)) && isfinite(stats.threshold));
    Q=frameRateQC(I,1,'test',false); delete(Q.figCombined);
    rejected=false(1,40); rejected(10:12)=true; D=interpolateRejectedVolumes(I,rejected); assert(isequal(size(D),size(I)));
    for motor=[false true]
        R=imregdemons_preprocess(I,1,struct('nsub',10,'saveQC',false,'showQC',false,'stepMotorMode',motor));
        shape=dims{1}; shape(end)=4; assert(isequal(size(R.I),shape));
    end
    assert(isempty(findall(0,'Tag','deConfUSIonProgress')),'A finished operation left progress open.');
end
end

function setupTests(root)
run_fusi_studio; f=getappdata(0,'deConfUSIonMainFigure'); guard=onCleanup(@()delete(f)); %#ok<NASGU>
state=guidata(f); state.isLoaded=true; state.exportPath=tempdir; state.loadedName='baseline test';
for kind=1:4
    dims=[12 13 600]; if kind>1, dims=[12 13 3 600]; end
    if kind==4, dims=[12 13 10]; end
    D=struct('I',ones(dims,'single'),'TR',.5); if kind==3, D.probeType='2D Step Motor'; end
    state.datasets=struct('raw',D); state.activeDataset='raw'; guidata(f,state);
    expected=[30 240]; if kind==2, expected=[30 60]; elseif kind==3, expected=[20 40]; end
    if kind==4, expected=[0 4.5]; end
    for method={'SCM GUI','Video GUI'}
        reached=false;
        watcher=timer('ExecutionMode','fixedSpacing','Period',.3,'TimerFcn',@checkSetup);
        timerGuard=onCleanup(@()delete(watcher)); start(watcher);
        for k=1:numel(state.allButtons)
            b=get(state.allButtons{k},'UserData');
            if strcmp(get(b.text,'String'),method{1}), b.callback(state.allButtons{k},[]); break; end
        end
        assert(reached); clear timerGuard;
    end
end
    function checkSetup(~,~)
        entry=findall(0,'Tag','SetupBaselineStart'); if isempty(entry), return; end
        dialog=ancestor(entry,'figure'); if strcmp(get(dialog,'Visible'),'off'), return; end
        endEntry=findall(dialog,'Tag','SetupBaselineEnd');
        assert(isequal([str2double(get(entry,'String')) str2double(get(endEntry,'String'))],expected));
        assert(get(entry,'FontSize')==18 && get(endEntry,'FontSize')==18);
        if kind==2 && strcmp(method{1},'SCM GUI')
            drawnow; shot=getframe(dialog); imwrite(shot.cdata,fullfile(root,'validation','matrix_baseline_setup.png'));
        end
        reached=true; stop(watcher); cancel=findall(dialog,'Style','pushbutton','String','CANCEL'); cb=get(cancel,'Callback'); cb(cancel,[]);
    end
end
