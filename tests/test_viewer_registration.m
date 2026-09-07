function test_viewer_registration(part)
% Run in a disposable MATLAB process; uses synthetic data and temporary files.
if nargin<1, part='all'; end
root=fileparts(fileparts(mfilename('fullpath'))); addpath(root);
if any(strcmp(part,{'viewer','all'})), testViewer(root); end
if any(strcmp(part,{'registration','all'})), testRegistration(); end
if any(strcmp(part,{'cancel','all'})), testCancel(); end
if any(strcmp(part,{'dialogs','all'})), testDialogs(root); end
fprintf('PASS: %s\n',part);
end

function testDialogs(root)
out=fullfile(root,'validation'); if ~exist(out,'dir'), mkdir(out); end
t=timer('StartDelay',1,'TimerFcn',@(~,~)pressDialog('Automatic 3D registration','Cancel',fullfile(out,'registration_setup.png')));
c=onCleanup(@()delete(t)); %#ok<NASGU>
start(t); cfg=AtlasRegistration('settings',[]); assert(isempty(cfg)); clear c;
scan=struct('Data',ones(90,64,54,'single'),'voxelSize',[.04 .1 .08]);
atlas=struct('VoxelSize',[50 50 50]);
t=timer('StartDelay',1,'TimerFcn',@(~,~)pressDialog('3D scan geometry','Continue',fullfile(out,'registration_geometry.png')));
c=onCleanup(@()delete(t)); %#ok<NASGU>
start(t); result=AtlasRegistration('geometry',scan,atlas);
assert(isequal(size(result.Data),[54 90 64]));
assert(isequal(result.VoxelSize,[80 40 100]));
assert(isequal(result.Geometry.originalSize,[90 64 54]));
end

function pressDialog(name,buttonName,path)
f=findall(0,'Type','figure','Name',name); assert(numel(f)==1);
buttons=findall(f,'Style','pushbutton','String',buttonName); assert(numel(buttons)==1);
drawnow; frame=getframe(f); imwrite(frame.cdata,path);
cb=get(buttons,'Callback'); cb(buttons,[]);
end

function testViewer(root)
[yy,xx]=ndgrid(1:90,1:64); base=single(yy+xx*.12);
for is3D=[false true]
    if is3D, I=repmat(base,[1 1 54 4]); else, I=repmat(base,[1 1 4]); end
    f=fUSI_Live_Studio(I,1,struct('voxelSize',[.03 .25 .4]),'orientation regression');
    cleanup=onCleanup(@()close(f)); %#ok<NASGU>
    pause(.5); drawnow;
    im=findall(f,'Type','image'); assert(numel(im)==1);
    ax=ancestor(im,'axes'); D=get(im,'CData');
    assert(mean(D(1,:))>mean(D(end,:)),'The original row-flipped CData convention was lost.');
    assert(mean(D(:,1))<mean(D(:,end)),'An unwanted horizontal flip was introduced.');
    assert(strcmp(get(ax,'YDir'),'normal'));
    assert(isequal(get(ax,'DataAspectRatio'),[1 1 1]),'The image is stretched.');
    assert(diff(get(ax,'XLim'))==64 && diff(get(ax,'YLim'))==90,'The frame is clipped.');
    set(f,'Units','pixels','Position',[40 40 1100 720],'WindowState','normal'); drawnow;
    assert(isequal(get(ax,'DataAspectRatio'),[1 1 1]),'Resizing stretches the image.');
    if is3D
        if ~exist(fullfile(root,'validation'),'dir'), mkdir(fullfile(root,'validation')); end
        exportgraphics(ax,fullfile(root,'validation','viewer_restored.png'));
    end
    clear cleanup;
end
end

function [F,V,truth]=phantom()
[y,x,z]=ndgrid(1:60,1:52,1:54);
F=single(exp(-((x-24).^2/90+(y-30).^2/160+(z-26).^2/150)) ...
    +.75*exp(-((x-32).^2/18+(y-23).^2/30+(z-38).^2/23)) ...
    +.4*exp(-((x-17).^2/9+(y-42).^2/20+(z-21).^2/55)) ...
    +.6*exp(-((x-40).^2/12+(y-45).^2/16+(z-40).^2/10)) ...
    +.5*exp(-((x-12).^2/11+(y-20).^2/9+(z-12).^2/16)));
theta=3*pi/180;
A=[cos(theta) sin(theta) 0 0;-sin(theta) cos(theta) 0 0;0 0 1 0;2 -1 2 1];
V=imwarp(F,affine3d(A),'OutputView',imref3d(size(F)));
truth=inv(A);
end

function testRegistration()
[F,V,truth]=phantom();
cfg=struct('engine','greedy','model','rigid','target','vascular','maxDimension',80, ...
    'iterations',[100 60 30],'voxelSizeUm',[50 50 50]);
[M,report]=AtlasRegistration('register',F,V,cfg);
points=[15 20 18;28 31 30;32 42 38];
want=transformPointsForward(affine3d(truth),points);
got=transformPointsForward(affine3d(M),points);
err=sqrt(mean(sum((want-got).^2,2)));
fprintf('Greedy landmark RMS error: %.4f voxels; NMI %.3f -> %.3f\n',err,report.nmiBefore,report.nmiAfter);
assert(err<1.2,'Greedy/MATLAB coordinates or transform direction are wrong.');
assert(report.nmiAfter>report.nmiBefore);
assert(report.resliceRelativeError<.03);
cfg.model='affine'; [M,~]=AtlasRegistration('register',F,V,cfg);
got=transformPointsForward(affine3d(M),points);
fprintf('Greedy affine landmark RMS: %.4f voxels\n',sqrt(mean(sum((want-got).^2,2))));
assert(sqrt(mean(sum((want-got).^2,2)))<1.4,'Affine coordinates are wrong.');
cfg.model='rigid'; cfg.engine='matlab'; cfg.maxDimension=80;
[M,report]=AtlasRegistration('register',F,V,cfg);
got=transformPointsForward(affine3d(M),points);
assert(sqrt(mean(sum((want-got).^2,2)))<1.5,'MATLAB alignment failed.');
assert(report.nmiAfter>report.nmiBefore);
% Refinement must accept an already rotated/scaled manual transform.
cfg.useCurrent=true; manual=truth; manual(1:3,1:3)=manual(1:3,1:3)*1.005;
[refined,~]=AtlasRegistration('register',F,V,cfg,manual);
got=transformPointsForward(affine3d(refined),points);
assert(sqrt(mean(sum((want-got).^2,2)))<1.5,'Manual-start refinement lost its rotation/scale.');
cfg.useCurrent=false;
cfg.engine='greedy'; cfg.cancelFcn=@()true;
try
    AtlasRegistration('register',F,V,cfg);
    error('test:NoCancel','Expected cancellation.');
catch ME, assert(strcmp(ME.identifier,'deConfUSIon:AtlasCancelled')); end
% Real class/UI: regression for proposal, undo, save metadata and no autosave.
atlas=struct('Histology',uint16(F*255)+1,'Vascular',F,'Regions',ones(size(F)), ...
    'VoxelSize',[50 50 50],'Lines',struct('Cor',{{}},'Sag',{{}},'Tra',{{}}), ...
    'infoRegions',struct('rgb',[0 0 0;1 1 1]));
scan=struct('Data',flip(flip(permute(V,[2 3 1]),2),3),'VoxelSize',[50 50 50]);
work=tempname; mkdir(work);
R=registration_ccf(atlas,scan,[],@disp,work);
c=onCleanup(@()delete(R.H.figure1)); %#ok<NASGU>
assert(~isempty(findall(R.H.figure1,'Tag','Automatic3DRegistration')));
before=R.getCurrentTransform();
cfg.cancelFcn=[]; cfg.model='rigid'; cfg.maxDimension=80;
R.onAutoRegister(cfg);
assert(~R.autoBusy && ~isempty(R.autoReport),'Auto GUI did not install a proposal.');
assert(exist(fullfile(work,'Transformation.mat'),'file')==0,'Auto registration must not silently save.');
R.onSave(); s=load(fullfile(work,'Transformation.mat'));
assert(isfield(s.Transf,'autoRegistration') && isequal(s.Transf.M,R.getCurrentTransform().M));
R.onUndoAuto(); after=R.getCurrentTransform();
assert(norm(before.M-after.M,'fro')<1e-10,'Undo did not restore the preceding transform.');
R.scanGeometry=struct('originalSize',size(scan.Data),'originalSpacingUm',[50 50 50], ...
    'permutation',[1 2 3],'confirmed',true);
source=fullfile(work,'static_anatomy.mat'); save(source,'scan');
R.funcFiles={source}; R.funcLabels={'synthetic anatomy'};
R.onRegisterFunctional();
out=dir(fullfile(work,'*_registered_to_atlas_*.mat'));
assert(numel(out)==1,'Static 3D anatomy was not registered.');
s=load(fullfile(work,out(1).name));
assert(isequal(size(s.registered.Data),size(F)),'The volume was collapsed or treated as a time series.');
raw=scan; scan=struct('Data',cat(4,raw.Data,raw.Data*2),'VoxelSize',[50 50 50]);
source4=fullfile(work,'volumetric_series.mat'); save(source4,'scan');
R.funcFiles={source4}; R.onRegisterFunctional();
out4=dir(fullfile(work,'volumetric_series_registered_to_atlas_*.mat'));
assert(numel(out4)==1);
s=load(fullfile(work,out4(1).name));
assert(isequal(size(s.registered.Data),[size(F) 2]));
delta=double(s.registered.Data(:,:,:,2)-2*s.registered.Data(:,:,:,1));
assert(norm(delta(:))<1e-3,'Registration altered the relative time-course amplitudes.');
% Invalid engine fails without changing the current transform or UI state.
cfg.engine='invalid'; R.onAutoRegister(cfg);
assert(~R.autoBusy && isequal(R.getCurrentTransform().M,after.M));
files=dir(fullfile(work,'*.mat'));
for k=1:numel(files), delete(fullfile(work,files(k).name)); end
rmdir(work);
end

function testCancel()
oldDir=pwd; cwdGuard=onCleanup(@()cd(oldDir)); %#ok<NASGU>
mock=tempname; mkdir(mock); fid=fopen(fullfile(mock,'uigetfile.m'),'w');
fprintf(fid,['function [file,path]=uigetfile(varargin)\n' ...
    'file=0; path=0; if isappdata(0,''TestOptionsPath''), file=''test.mat''; path=getappdata(0,''TestOptionsPath''); end\nend\n']); fclose(fid);
c=onCleanup(@()removeMock(mock)); %#ok<NASGU>
run_fusi_studio; f=getappdata(0,'deConfUSIonMainFigure');
addpath(mock,'-begin');
state=guidata(f); buttons=state.allButtons; ud=get(buttons{1},'UserData');
feval(ud.callback,buttons{1},[]); drawnow;
assert(~isappdata(f,'LoadInProgress'),'Cancelled initial load left a stale load guard.');
state=guidata(f); assert(~state.isLoaded);
state.isLoaded=true; state.datasets.raw=struct('I',ones(4,5,6),'TR',1); state.activeDataset='raw';
guidata(f,state);
feval(ud.callback,buttons{1},[]); drawnow;
assert(~isappdata(f,'LoadInProgress'),'Cancelled replacement load left a stale load guard.');
restored=guidata(f); assert(restored.isLoaded && isequal(restored.datasets.raw.I,state.datasets.raw.I));
feval(ud.callback,buttons{1},[]); % A second attempt must still return normally.
assert(~isappdata(f,'LoadInProgress'));
% Cancel after the file read and setup dialog, when the live state has
% already been cleared. Use temporary dependency stubs to avoid real files.
mkdir(fullfile(mock,'RawData')); setappdata(0,'TestOptionsPath',fullfile(mock,'RawData'));
fid=fopen(fullfile(mock,'loadFUSIData.m'),'w');
fprintf(fid,'function [d,m]=loadFUSIData(varargin)\nd=struct(''I'',ones(4,5,6),''TR'',1); m=struct(''rawMetadata'',struct());\nend\n'); fclose(fid);
fid=fopen(fullfile(mock,'studio_load_options_dark_dialog.m'),'w');
fprintf(fid,['function [tr,folder,cancel,probe,def]=studio_load_options_dark_dialog(tr,folder,a,b,probe,def,varargin)\n' ...
    'cancel=true; setappdata(0,''TestOptionsReached'',true);\nend\n']); fclose(fid);
cd(mock); clear loadFUSIData studio_load_options_dark_dialog; rehash;
feval(ud.callback,buttons{1},[]); drawnow;
if ~isappdata(0,'TestOptionsReached')
    restored=guidata(f);
    if ~isempty(restored.logBoxJava), disp(char(restored.logBoxJava.getText())); end
    disp(which('uigetfile')); disp(which('loadFUSIData')); disp(which('studio_load_options_dark_dialog'));
end
assert(isappdata(0,'TestOptionsReached'),'Load did not reach the setup cancellation.');
rmappdata(0,'TestOptionsReached');
rmappdata(0,'TestOptionsPath');
assert(~isappdata(f,'LoadInProgress'));
restored=guidata(f);
assert(restored.isLoaded && strcmp(restored.activeDataset,'raw'));
assert(isequal(restored.datasets.raw.I,state.datasets.raw.I));
assert(strcmp(get(restored.statusText,'String'),'OK  PROGRAM READY'));
colors=[];
for k=2:numel(buttons)
    b=get(buttons{k},'UserData'); assert(b.enabled);
    colors(end+1,:)=get(b.rect,'FaceColor'); %#ok<AGROW>
end
assert(size(unique(colors,'rows'),1)==9,'Sections should have distinct button colors.');
delete(f);
end
function removeMock(folder)
if strcmp(pwd,folder), cd(fileparts(folder)); end
rmpath(folder);
files=dir(fullfile(folder,'*.m'));
for k=1:numel(files), delete(fullfile(folder,files(k).name)); end
dirs=dir(folder);
for k=1:numel(dirs)
    if dirs(k).isdir && ~any(strcmp(dirs(k).name,{'.','..'})), rmdir(fullfile(folder,dirs(k).name)); end
end
rmdir(folder);
end
