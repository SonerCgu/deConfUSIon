function test_processing_regressions(part)
% Disposable MATLAB session; no acquisition files are modified.
if nargin<1, part='all'; end
root=fileparts(fileparts(mfilename('fullpath'))); addpath(root);
if any(strcmp(part,{'numeric','all'})), numericTests(); end
if any(strcmp(part,{'studio','all'})), studioTests(); end
if any(strcmp(part,{'review','all'})), reviewTests(); end
if any(strcmp(part,{'decomposition','all'})), decompositionTests(); end
if any(strcmp(part,{'colors','all'})), colorTests(root); end
fprintf('PASS processing regressions: %s\n',part);
end

function reviewTests()
X=reshape(single(1:6*7*8),6,7,8); X=X/max(X(:));
g=struct('originalSize',[6 7 8],'permutation',[3 2 1], ...
    'originalSpacingUm',[50 50 50],'atlasVoxelSizeUm',[50 50 50]);
expected=permute(flip(flip(permute(X,g.permutation),3),2),[3 1 2]);
T=struct('M',eye(4),'size',size(expected),'scanGeometry',g);
Y=AtlasRegistration('warp',cat(4,X,X*2),T);
assert(isequal(Y(:,:,:,1),expected) && isequal(Y(:,:,:,2),expected*2));
regions=ones(size(expected)); regions(1:2,:,:)=-2; regions(3,:,:)=0;
info=struct('rgb',[1 0 0;0 1 0],'name',{{'Red region','Green region'}});
folder=tempname; mkdir(folder);
b=AtlasRegistration('review',expected,expected,regions,info,eye(4),[50 50 50],folder,false);
assert(isequal(niftiread(b.atlas),niftiread(b.anatomy)));
labels=niftiread(b.regions); assert(labels(1,1,1)==1 && labels(1,3,1)==0 && labels(1,4,1)==2);
header=niftiinfo(b.anatomy); assert(isequal(header.ImageSize,size(permute(expected,[3 1 2]))));
assert(norm(header.Transform.T-diag([.05 -.05 -.05 1]),'fro')<1e-7);
txt=fileread(b.colors); assert(contains(txt,'Green region') && contains(txt,'Red region'));
assert(~isfile(fullfile(folder,'Transformation.mat')));
assert(~isempty(AtlasRegistration('itksnap')));
fprintf('Review bundle validated: %s\n',b.folder);
end

function decompositionTests()
for dims={[12 13 70],[12 13 54 70]}
    data=struct('I',single(100+randn(dims{1})),'TR',1);
    for method={'pca','ica'}
        t=timer('ExecutionMode','fixedSpacing','Period',.3,'TimerFcn',@cancelComponents);
        guard=onCleanup(@()delete(t)); start(t);
        if strcmp(method{1},'pca'), [out,stats]=pca_denoise(data,tempdir,'raw test',struct('nCompMax',10));
        else, [out,stats]=ica_denoise(data,tempdir,'raw test',struct('nCompMax',10)); end
        assert(~stats.applied && isequal(out.I,data.I)); clear guard;
    end
end
end
function cancelComponents(~,~)
f=findall(0,'Type','figure');
for k=1:numel(f)
    if ~isempty(regexp(get(f(k),'Name'),'^(PCA|ICA) -','once'))
        cb=get(f(k),'CloseRequestFcn');
        if isa(cb,'function_handle') && strcmp(get(f(k),'WaitStatus'),'waiting')
            cb(f(k),[]);
        end
    end
end
end

function colorTests(root)
run_fusi_studio; f=getappdata(0,'deConfUSIonMainFigure'); c=onCleanup(@()delete(f)); %#ok<NASGU>
state=guidata(f); state.isLoaded=true; state.datasets.raw=struct('I',ones(5,6,20,'single'),'TR',1); state.activeDataset='raw'; guidata(f,state);
target=[];
for k=1:numel(state.allButtons)
    b=get(state.allButtons{k},'UserData');
    if strcmpi(get(b.text,'String'),'Specific QC'), target=state.allButtons{k}; end
end
assert(~isempty(target));
t=timer('ExecutionMode','fixedSpacing','Period',.5,'TimerFcn',@captureQC);
g=onCleanup(@()delete(t)); %#ok<NASGU>
start(t); b=get(target,'UserData'); b.callback(target,[]);
    function captureQC(~,~)
        dlg=findall(0,'Type','figure');
        dlg=dlg(arrayfun(@(h)startsWith(get(h,'Name'),'Select Specific QC Modules'),dlg));
        if isempty(dlg) || isempty(findall(dlg,'Style','pushbutton','String','Cancel')), return; end
        deConfUSIon_ui('style',dlg);
        chips=findall(dlg,'Type','uipanel'); n=0;
        for h=reshape(chips,1,[])
            if isequal(getappdata(h,'PreserveColors'),true)
                n=n+1; rgb=get(h,'BackgroundColor'); assert(max(rgb)-min(rgb)>.15);
                pos=get(h,'Position'); assert(pos(2)>0);
            end
        end
        assert(n==12); drawnow;
        frame=getframe(dlg); imwrite(frame.cdata,fullfile(root,'validation','specific_qc_restored.png'));
        cancel=findall(dlg,'Style','pushbutton','String','Cancel'); cb=get(cancel,'Callback'); cb(cancel,[]);
    end
end

function numericTests()
rng(42); X=randn(1500,160); X=X-mean(X,2);
[U,s,W,energy]=deConfUSIon_signal('basis',single(X),12);
[ue,se,~]=svd(double(single(X))','econ');
assert(norm(s-diag(se(1:12,1:12)))/norm(s)<1e-6);
assert(norm(U*U'-ue(:,1:12)*ue(:,1:12)','fro')<1e-5);
assert(norm(double(single(X))*U-W*diag(s),'fro')<1e-8*norm(X,'fro'));
assert(abs(energy-sum(double(single(X(:))).^2))<1e-6*energy);
% Long single-slice recordings use the bounded-pass approximation. Check
% mathematical residuals, orthogonality, total energy and RNG isolation.
long=single(randn(180,8)*randn(8,4200)+.005*randn(180,4200));
long=long-mean(long,2); randomState=rng;
[uf,sf,wf,ef,info]=deConfUSIon_signal('basis',long,8);
assert(info.approximate && info.powerIterations==2 && isequal(randomState,rng));
[~,se,~]=svd(double(long'),'econ');
assert(norm(sf-diag(se(1:8,1:8)))/norm(sf)<1e-5);
assert(norm(uf'*uf-eye(8),'fro')<1e-8 && norm(wf'*wf-eye(8),'fro')<1e-8);
assert(norm(double(long)*uf-wf*diag(sf),'fro')<1e-8*norm(double(long),'fro'));
assert(info.relativeResidual<1e-5 && abs(ef-sum(double(long(:)).^2))<1e-8*ef);
clear long uf sf wf se;
try
    deConfUSIon_signal('basis',single(X),12,struct('cancelFcn',@()true));
    error('test:NoCancel','Cancel was ignored.');
catch ME, assert(strcmp(ME.identifier,'deConfUSIon:DecompositionCancelled')); end
name=deConfUSIon_display_name_from_sources('WT250408_S1_104909_FUS_104909_FUS_104909_raw',struct(),'');
assert(strcmp(name,'WT250408_S1_104909_raw'),name);
name=deConfUSIon_display_name_from_sources('Mouse250407_S1_Ringer_FUS_151142_Mouse250407_S1_Ringer_FUS_151142_raw',struct(),'');
assert(strcmp(name,'Mouse250407_S1_Ringer_FUS_151142_raw'),name);
d=struct('preprocessing','Butterworth filtering');
name=deConfUSIon_best_visible_dataset_name('WT250408_S1_104909_raw',d,'');
assert(contains(name,'filter') && ~endsWith(name,'raw'),name);
name=deConfUSIon_best_visible_dataset_name('WT250408_S1_104909_raw',struct(),'D:\Animal\Preprocessing\legacy.mat');
assert(endsWith(name,'processed'),name);

out=tempname; mkdir(out); fprintf('Temporary test outputs: %s\n',out);
for spatial={[5 6],[5 6 3],[5 6 54]}
    dims=[spatial{1} 90]; I=single(100+randn(dims));
    for method={'pacap_response','glm','compcor','anchor','vehicle','spline','robust','baseline','poly','dct','reference'}
        opts=struct('method',method{1},'baselineSec',[0 15],'injectionSec',20, ...
            'responseSec',20,'tailSec',[65 85],'vehicleI',I,'vehicleTR',1, ...
            'refMask',true(spatial{1}),'makeQC',false,'saveQC',false);
        [O,st]=DriftCompensation('run',I,1,out,opts);
        assert(isequal(size(O),size(I)) && all(isfinite(O(:))),method{1});
        assert(isstruct(st));
    end
    path=fullfile(out,sprintf('save_%d.mat',numel(I)));
    DataIO('enqueue',path,struct('newData',struct('I',I,'TR',1),'displayNameFull','test'));
    DataIO('wait'); S=load(path);
    assert(isequal(S.newData.I,I) && strcmp(DataIO('status',path),'saved'));
end
end

function studioTests()
run_fusi_studio; f=getappdata(0,'deConfUSIonMainFigure'); c=onCleanup(@()delete(f)); %#ok<NASGU>
state=guidata(f); state.isLoaded=true;
state.loadedFile=''; state.loadedName='WT250408_S1_104909';
state.exportPath=tempname; mkdir(state.exportPath);
fprintf('Studio test outputs: %s\n',state.exportPath);
state.datasets=struct('raw',struct('I',single(100+randn(6,7,90)),'TR',1,'displayNameFull','WT250408_S1_104909_raw'));
state.activeDataset='raw'; guidata(f,state);
buttons=state.allButtons; filterButton=[];
for k=1:numel(buttons)
    b=get(buttons{k},'UserData');
    if strcmpi(get(b.text,'String'),'Filtering')
        b.enabled=true; set(buttons{k},'UserData',b); filterButton=buttons{k};
    end
end
assert(~isempty(filterButton));
step=struct('name','Filtering','filterType',2,'fcLow',0,'fcHigh',.2,'filterOrder',2);
setappdata(f,'deconf_std_workflow_step',step);
% Invoke the actual button guard and actual filtering/save/publication code.
click=get(filterButton,'ButtonDownFcn'); click(filterButton,[]);
state=guidata(f); assert(numel(fieldnames(state.datasets))==2,'The first output was lost.');
first=state.activeDataset; assert(~strcmp(first,'raw'));
dd=findobj(f,'Tag','datasetDropdown'); keys=get(dd,'UserData');
assert(strcmp(keys{get(dd,'Value')},first),'Latest output was not selected immediately.');
assert(~getappdata(f,'StudioActionBusy'),'Action guard did not release.');
DataIO('wait'); saved=load(state.datasets.(first).savedFile);
assert(isequal(saved.newData.I,state.datasets.(first).I));
% A second analysis must immediately expose its own result, not the first.
click(filterButton,[]); state=guidata(f);
assert(numel(fieldnames(state.datasets))==3 && ~strcmp(state.activeDataset,first));
keys=get(dd,'UserData'); assert(strcmp(keys{get(dd,'Value')},state.activeDataset));
DataIO('wait');
% Guard rejects clicks dispatched while an operation is still active.
setappdata(f,'StudioActionBusy',true); click(filterButton,[]);
after=guidata(f); assert(numel(fieldnames(after.datasets))==3);
setappdata(f,'StudioActionBusy',false);
end
