function varargout = AtlasRegistration(action,varargin)
% Automatic linear atlas alignment. Transforms remain compatible with the
% toolbox's affine3d/Transformation.mat convention (moving -> atlas voxels).
switch lower(action)
    case 'settings', varargout{1}=settingsDialog(varargin{:});
    case 'register', [varargout{1:nargout}]=registerVolume(varargin{:});
    case 'register2d', [varargout{1:nargout}]=registerPlane(varargin{:});
    case 'greedy', varargout{1}=findGreedy();
    case 'geometry', varargout{1}=geometryDialog(varargin{:});
    case 'itksnap', varargout{1}=findSnap();
    case 'review', varargout{1}=exportReview(varargin{:});
    case 'warp', varargout{1}=warpSeries(varargin{:});
    case 'prepare', varargout{1}=prepareAnatomy(varargin{:});
    case 'planematrix', varargout{1}=planeMatrix(varargin{:});
    case 'previewcuts', [varargout{1:nargout}]=previewCuts(varargin{:});
    otherwise, error('deConfUSIon:AtlasAction','Unknown atlas action: %s',action);
end
end

function cfg=settingsDialog(parent)
C=deConfUSIon_ui('palette'); cfg=[]; exe=findGreedy();
f=figure('Name','Automatic 3D registration','NumberTitle','off', ...
    'MenuBar','none','ToolBar','none','Color',C.background, ...
    'Units','pixels','Position',[100 100 920 620],'WindowStyle','modal', ...
    'CloseRequestFcn',@cancel);
label(f,[.04 .87 .92 .09], ...
    'Align the 3D anatomy to the atlas, then inspect all three planes before saving.',C,15);
label(f,[.04 .73 .25 .06],'Registration engine',C,12);
engine=uicontrol(f,'Style','popupmenu','Units','normalized','Position',[.31 .74 .64 .055], ...
    'String',{'ITK-SNAP / Greedy (external)','MATLAB (built in)'}, ...
    'Value',1+isempty(exe),'BackgroundColor',C.input,'ForegroundColor',C.text,'FontName','Arial','FontSize',12, ...
    'Tag','RegistrationEngine','Callback',@engineChanged);
label(f,[.04 .62 .25 .06],'Atlas target',C,12);
target=uicontrol(f,'Style','popupmenu','Units','normalized','Position',[.31 .63 .64 .055], ...
    'String',{'Vascular atlas (Doppler anatomy)','Histology atlas (multimodal)'}, ...
    'BackgroundColor',C.input,'ForegroundColor',C.text,'FontName','Arial','FontSize',12);
label(f,[.04 .51 .25 .06],'Transform',C,12);
model=uicontrol(f,'Style','popupmenu','Units','normalized','Position',[.31 .52 .64 .055], ...
    'String',{'Rigid: rotation and translation','Rigid then affine: also size and shear'}, ...
    'BackgroundColor',C.input,'ForegroundColor',C.text,'FontName','Arial','FontSize',12);
useCurrent=uicontrol(f,'Style','checkbox','Units','normalized', ...
    'Position',[.04 .41 .91 .055],'String','Refine current manual alignment; otherwise search anatomy-based starting positions', ...
    'BackgroundColor',C.background,'ForegroundColor',C.text,'FontName','Arial','FontSize',12,'Value',0);
review=uicontrol(f,'Style','checkbox','Units','normalized','Position',[.04 .35 .91 .05], ...
    'String','Greedy only: open one ITK-SNAP review with anatomy over the selected atlas', ...
    'Tag','OpenSnapReview','Value',~isempty(findSnap()),'BackgroundColor',C.background,'ForegroundColor',C.text,'FontSize',12);
label(f,[.04 .19 .92 .15], ...
    ['1. Confirm voxel sizes and array order in Scan geometry.  2. Run automatic registration.' newline ...
     '3. Check boundaries, ventricles and vessels across slices. Use Undo auto to reject the result.' newline ...
     'Rigid preserves shape. Affine adds scaling and shear. Partial brain coverage may need manual initialization.'],C,12);
label(f,[.04 .145 .92 .05],['Greedy: ' exe],C,10);
button(f,[.04 .035 .20 .075],'Help',C.blue,@(~,~)deConfUSIon_ui('help','Registration'));
button(f,[.54 .035 .24 .075],'Run registration',C.green,@run);
button(f,[.80 .035 .16 .075],'Cancel',C.danger,@cancel);
engineChanged([],[]); movegui(f,'center');
if nargin>0 && isscalar(parent) && isgraphics(parent)
    set(f,'Name',['Automatic 3D registration | ' get(parent,'Name')]);
    figure(f);
end
if isgraphics(f), uiwait(f); end
    function run(~,~)
        if get(engine,'Value')==1 && isempty(exe)
            errordlg('Greedy was not found. Install ITK-SNAP or add its bin folder to PATH, or select MATLAB.','Registration engine'); return;
        end
        cfg=struct('engine','greedy','target','vascular','model','rigid', ...
            'useCurrent',logical(get(useCurrent,'Value')),'executable',exe, ...
            'maxDimension',160,'iterations',[100 50 20],'openReview',logical(get(review,'Value')));
        if get(engine,'Value')==2, cfg.engine='matlab'; cfg.openReview=false; end
        if get(target,'Value')==2, cfg.target='histology'; end
        if get(model,'Value')==2, cfg.model='affine'; end
        delete(f);
    end
    function cancel(~,~), delete(f); end
    function engineChanged(~,~)
        if get(engine,'Value')==2, set(review,'Enable','off','Value',0);
        else, set(review,'Enable','on','Value',~isempty(findSnap())); end
    end
end

function scan=geometryDialog(scan,atlas)
% Confirm array order and independent spacings; never infer a left/right flip.
C=deConfUSIon_ui('palette'); original=scan; sz=size(scan.Data);
v=[100 100 80]; order=1;
if isfield(scan,'VoxelSize') && numel(scan.VoxelSize)>=3
    w=double(scan.VoxelSize(1:3));
    if all(isfinite(w)) && all(w>0) && ~isequal(w(:)',[1 1 1])
        v=w(:)';
    end
end
if isfield(scan,'voxelSize') && numel(scan.voxelSize)>=3
    v=double(scan.voxelSize(1:3)); v=v(:)'; order=1;
    % Explicitly show conversion in the dialog; user confirms these values.
    if max(v)<10, v=v*1000; end
end
if isfield(scan,'arrayOrder') && strcmp(scan.arrayOrder,'DV-LR-AP'), order=1; end
scan=[];
f=figure('Name','3D scan geometry','NumberTitle','off','MenuBar','none','ToolBar','none', ...
    'Color',C.background,'Position',[150 150 880 480],'WindowStyle','modal','CloseRequestFcn',@cancel);
label(f,[.04 .79 .92 .15],sprintf(['Confirm geometry before registration. Array size: %s\n' ...
    'Spacing is per array dimension, in micrometres (1000 um = 1 mm).'],mat2str(sz)),C,14);
label(f,[.04 .65 .22 .08],'Array order',C,12);
hOrder=uicontrol(f,'Style','popupmenu','Units','normalized','Position',[.28 .66 .67 .08], ...
    'String',{'Coronal stack: depth x left/right x slices (Studio / matrix probe)','Legacy acquisition layout (original paper convention)'}, ...
    'Value',order,'BackgroundColor',C.input,'ForegroundColor',C.text,'FontName','Arial','FontSize',12);
hV=gobjects(1,3);
for k=1:3
    label(f,[.04+(k-1)*.32 .46 .28 .08],sprintf('Dimension %d spacing (um)',k),C,12);
    hV(k)=uicontrol(f,'Style','edit','Units','normalized','Position',[.04+(k-1)*.32 .36 .27 .08], ...
        'String',num2str(v(k)),'BackgroundColor',C.input,'ForegroundColor',C.text,'FontName','Arial','FontSize',12);
end
flipAP=uicontrol(f,'Style','checkbox','Units','normalized','Position',[.04 .245 .9 .045], ...
    'String','Reverse coronal slice order (if acquired posterior to anterior)', ...
    'BackgroundColor',C.background,'ForegroundColor',C.text,'Value',0);
label(f,[.04 .125 .92 .11], ...
    'Coronal frames keep their row/column orientation. Slice number maps to atlas anterior/posterior. Verify slice direction and left/right using landmarks; no automatic mirror is applied.',C,11);
button(f,[.61 .04 .21 .085],'Continue',C.green,@accept);
button(f,[.84 .04 .12 .085],'Cancel',C.danger,@cancel);
movegui(f,'center'); if isgraphics(f), uiwait(f); end
    function accept(~,~)
        vv=arrayfun(@(h)str2double(get(h,'String')),hV);
        if any(~isfinite(vv)) || any(vv<=0)
            errordlg('Enter three positive, finite voxel spacings.','Scan geometry'); return;
        end
        av=double(atlas.VoxelSize(:)');
        if any(av<=0) || any(~isfinite(av)), error('Invalid atlas voxel spacing.'); end
        % The bundled atlas uses micrometres. Refuse implausibly large grids
        % rather than allocating hundreds of GB after a unit-entry mistake.
        if get(hOrder,'Value')==1, perm=[3 1 2]; else, perm=[1 2 3]; end
        target=round((sz(perm)-1).*vv(perm)./av)+1;
        if any(target<4) || prod(target)>1e8
            errordlg(sprintf('These values would create an atlas-grid volume of %s. Check units and array order.',mat2str(target)),'Scan geometry'); return;
        end
        scan=original; scan.Data=permute(scan.Data,perm); scan.VoxelSize=vv(perm);
        scan.Geometry=struct('originalSize',sz,'originalSpacingUm',vv,'permutation',perm, ...
            'atlasVoxelSizeUm',av,'confirmed',true);
        if get(hOrder,'Value')==1
            scan.Geometry.convention='coronal_stack_v2';
            scan.Geometry.flipAxes=[];
            if get(flipAP,'Value'), scan.Data=flip(scan.Data,1); scan.Geometry.flipAxes=1; end
        else
            scan.Geometry.convention='legacy_paper';
        end
        delete(f);
    end
    function cancel(~,~), scan=[]; delete(f); end
end

function [M,report]=registerVolume(fixed,moving,cfg,initial)
% Inputs are already resampled/oriented by interpolate3D. All registration
% here uses that same atlas grid; the acquired 4D samples are never modified.
if nargin<4, initial=eye(4); end
validateattributes(fixed,{'numeric'},{'real','nonempty'});
validateattributes(moving,{'numeric'},{'real','nonempty'});
if ndims(fixed)~=3 || ndims(moving)~=3 || min(size(moving))<4 || min(size(fixed))<4
    error('deConfUSIon:AtlasVolume','Automatic registration requires a true 3D anatomy (at least 4 samples per axis).');
end
fixed=robustVolume(fixed); moving=robustVolume(moving);
cfg=defaults(cfg); factor=max(1,ceil(max([size(fixed) size(moving)])/cfg.maxDimension));
F=fixed(1:factor:end,1:factor:end,1:factor:end);
V=moving(1:factor:end,1:factor:end,1:factor:end);
if cfg.useCurrent
    start=initial;
else
    start=eye(4);
    sf=size(fixed); sm=size(moving);
    start(4,1:3)=(sf([2 1 3])-sm([2 1 3]))/2;
end
originalStart=start; initReport=[];
if ~cfg.useCurrent && cfg.searchInitialization
    [start,initReport]=chooseInitial3D(F,V,factor,start,cfg);
end
report=struct('engine',cfg.engine,'model',cfg.model,'target',cfg.target, ...
    'sampleStride',factor,'voxelSizeUm',cfg.voxelSizeUm,'initialMatrix',start, ...
    'created',datestr(now,30),'reviewRequired',true,'log','');
report.initialization=initReport;
report.originalMatrix=originalStart;
progress(cfg,'Preparing 3D anatomy and atlas...');
switch lower(cfg.engine)
    case 'greedy'
        if isempty(cfg.executable), cfg.executable=findGreedy(); end
        if isempty(cfg.executable), error('deConfUSIon:GreedyMissing','ITK-SNAP Greedy was not found. Select MATLAB or install ITK-SNAP.'); end
        work=tempname; mkdir(work); cleanup=onCleanup(@()removeWork(work)); %#ok<NASGU>
        fp=fullfile(work,'fixed.nii'); mp=fullfile(work,'moving.nii');
        % NIfTI array axes are (row,column,slice). imwarp instead uses
        % (column,row,slice). H handles this swap AND zero/one based origins.
        spacing=double(cfg.voxelSizeUm(:)')/1000;
        writeNifti(F,fp,spacing*factor); writeNifti(V,mp,spacing*factor);
        H=[0 spacing(1) 0 -spacing(1); spacing(2) 0 0 -spacing(2); ...
            0 0 spacing(3) -spacing(3); 0 0 0 1];
        initFile=fullfile(work,'initial.mat'); writeMatrix(initFile,H/start'/H);
        rigidFile=fullfile(work,'rigid.mat'); affineFile=fullfile(work,'affine.mat');
        logFile=fullfile(work,'greedy.log');
        schedule=sprintf('%dx',cfg.iterations); schedule(end)=[];
        metric={'NMI'};
        if strcmpi(cfg.target,'vascular'), metric={'NCC','2x2x2'}; end
        common=[{'-d','3','-a','-m'} metric {'-i',fp,mp,'-n',schedule,'-threads','4','-float'}];
        if strcmpi(cfg.target,'vascular'), common=[common {'-jitter','0'}]; end
        progress(cfg,'ITK-SNAP Greedy: multiresolution rigid registration...');
        runProcess(cfg.executable,[common {'-dof','6','-ia',initFile,'-o',rigidFile}],logFile,cfg);
        resultFile=rigidFile;
        if strcmpi(cfg.model,'affine')
            progress(cfg,'ITK-SNAP Greedy: refining scale and shear...');
            runProcess(cfg.executable,[common {'-dof','12','-ia',rigidFile,'-o',affineFile}],logFile,cfg);
            resultFile=affineFile;
        end
        G=dlmread(resultFile); % Greedy: fixed RAS -> moving RAS, column vectors.
        if ~isequal(size(G),[4 4]) || any(~isfinite(G(:))) || rcond(G)<1e-12
            error('deConfUSIon:AtlasTransform','Greedy returned an invalid transform.');
        end
        M=(H\(G\H))';
        report.log=fileread(logFile);
        report.rasPullMatrix=G;
        % Compare one external reslice with MATLAB before accepting the
        % coordinate conversion. This detects header/origin convention errors.
        checkFile=fullfile(work,'resliced.nii');
        runProcess(cfg.executable,{'-d','3','-rf',fp,'-rm',mp,checkFile,'-r',resultFile},logFile,cfg);
        external=single(niftiread(checkFile));
        internal=imwarp(V,sampleReference(size(V),factor),affine3d(M), ...
            'OutputView',sampleReference(size(F),factor));
        % Greedy and imwarp use different extrapolation at the outer half
        % voxel. Compare the shared interior, where both use trilinear
        % interpolation, so bright boundary voxels do not cause false alarms.
        interior=ones(size(V),'single');
        interior([1 end],:,:)=0; interior(:,[1 end],:)=0; interior(:,:,[1 end])=0;
        valid=imwarp(interior,sampleReference(size(V),factor),affine3d(M), ...
            'OutputView',sampleReference(size(F),factor))>.999;
        report.resliceRelativeError=norm(double(external(valid)-internal(valid)))/max(eps,norm(double(external(valid))));
        if report.resliceRelativeError>.03
            error('deConfUSIon:AtlasCoordinates','Greedy and MATLAB reslices disagree (%.2f percent); the previous transform is preserved.',100*report.resliceRelativeError);
        end
    case 'matlab'
        progress(cfg,'MATLAB: multiresolution rigid registration...');
        % Spatial references retain original voxel coordinates while using
        % decimated images, so translation is not scaled a second time.
        rf=sampleReference(size(F),factor); rm=sampleReference(size(V),factor);
        [optimizer,metric]=imregconfig('multimodal');
        optimizer.MaximumIterations=max(200,max(cfg.iterations)); optimizer.InitialRadius=0.0001;
        optimizer.GrowthFactor=1.01; optimizer.Epsilon=1e-7;
        metric.UseAllPixels=true;
        fitMoving=V; fitRef=rm; base=eye(4); t=affine3d(start);
        if cfg.useCurrent
            % Fit an incremental rigid transform after the manual alignment.
            % This also accepts a manual start containing scale or shear.
            fitMoving=imwarp(V,rm,affine3d(start),'OutputView',rf);
            fitRef=rf; base=start; t=affine3d(eye(4));
        else
            progress(cfg,'MATLAB: aligning anatomy position before rotation...');
            t=matlabFit(fitMoving,fitRef,F,rf,'translation',optimizer,metric,t,2);
        end
        progress(cfg,'MATLAB: refining rigid alignment...');
        levels=min(3,floor(log2(min([size(F) size(V)])))-1);
        t=matlabFit(fitMoving,fitRef,F,rf,'rigid',optimizer,metric,t,levels);
        if strcmpi(cfg.model,'affine')
            progress(cfg,'MATLAB: refining scale and shear...');
            t=matlabFit(fitMoving,fitRef,F,rf,'affine',optimizer,metric,t,2);
        end
        M=base*t.T;
    otherwise, error('deConfUSIon:AtlasEngine','Unknown registration engine.');
end
progress(cfg,'Checking the proposed transform...');
scales=svd(M(1:3,1:3));
if any(~isfinite(M(:))) || det(M(1:3,1:3))<=0 || min(scales)<.5 || max(scales)>2
    error('deConfUSIon:AtlasTransform','Automatic alignment produced an implausible flip or scale. The previous alignment is preserved. Check geometry or refine a manual starting position.');
end
ref=sampleReference(size(F),factor); movingRef=sampleReference(size(V),factor);
before=imwarp(V,movingRef,affine3d(start),'OutputView',ref);
after=imwarp(V,movingRef,affine3d(M),'OutputView',ref);
originalBefore=imwarp(V,movingRef,affine3d(originalStart),'OutputView',ref);
report.nmiBefore=normalizedMI(F,originalBefore);
report.nmiInitialized=normalizedMI(F,before); report.nmiAfter=normalizedMI(F,after);
report.foregroundOverlap=nnz(F>.05 & after>.05)/max(1,min(nnz(F>.05),nnz(after>.05)));
report.retainedForeground=nnz(after>.05)/max(1,nnz(V>.05)*det(M(1:3,1:3)));
retainedBefore=nnz(before>.05)/max(1,nnz(V>.05)*det(start(1:3,1:3)));
report.refinementAccepted=true; report.refinementNote='';
if report.retainedForeground<min(.65,.8*retainedBefore) || report.nmiAfter<report.nmiInitialized
    % Keep the valid, scored initialization when the numerical optimizer
    % drifts. Report this explicitly instead of presenting a failed fine fit.
    report.refinementAccepted=false;
    report.refinementNote='Fine fit reduced similarity or coverage; retained the scored starting proposal. Review or refine a manual alignment.';
    report.rejectedOptimizerMatrix=M; report.rejectedOptimizerNMI=report.nmiAfter;
    M=start; after=before; report.nmiAfter=report.nmiInitialized;
    report.retainedForeground=retainedBefore;
    report.foregroundOverlap=nnz(F>.05 & after>.05)/max(1,min(nnz(F>.05),nnz(after>.05)));
end
if nnz(after>.05)<.05*nnz(V>.05) || report.foregroundOverlap<.01
    error('deConfUSIon:AtlasOverlap','The proposed alignment has almost no brain overlap. Check geometry or start from a manual alignment.');
end
report.matrix=M;
end

function [start,report]=chooseInitial3D(F,V,step,center,cfg)
% Compare the box center with intensity-centroid/AP offsets on the existing
% oriented physical grid. Never introduce a reflection or change scan spacing.
progress(cfg,'Scoring anatomy-based starting positions...');
rf=sampleReference(size(F),step); rv=sampleReference(size(V),step);
centroid=@(X) volumeCentroid(X,step);
base=center; base(4,1:3)=centroid(F)-centroid(V);
starts=center;
for ap=[-30 -15 0 15 30]
    for dv=[-16 -8 0 8 16]
        seed=base; seed(4,1:2)=seed(4,1:2)+[dv ap];
        starts(:,:,end+1)=seed; %#ok<AGROW>
    end
end
scores=-inf(1,size(starts,3)); overlap=scores;
for k=1:size(starts,3)
    checkCancel(cfg);
    W=imwarp(V,rv,affine3d(starts(:,:,k)),'OutputView',rf);
    overlap(k)=nnz(W>.05 & F>.05)/max(1,nnz(W>.05));
    retained=nnz(W>.05)/max(1,nnz(V>.05));
    if retained>=.65 && overlap(k)>=.05
        scores(k)=normalizedMI(F,W);
    end
end
[best,k]=max(scores); if ~isfinite(best), k=1; end
start=starts(:,:,k);
report=struct('candidateMatrices',starts,'nmi',scores,'overlap',overlap,'selected',k, ...
    'method','box/foreground centers plus AP/depth translation candidates; no mirrors');
end

function c=volumeCentroid(V,step)
% Winsorized weights reduce domination by one very bright vessel or artifact.
W=double(min(V,.5)); W(V<.05)=0; total=sum(W(:));
if total<=0, error('deConfUSIon:AtlasEmpty','No foreground for initialization.'); end
sx=squeeze(sum(sum(W,1),3)); sy=squeeze(sum(sum(W,2),3)); sz=squeeze(sum(sum(W,1),2));
c=[sum(sx(:).*(1:numel(sx))') sum(sy(:).*(1:numel(sy))') sum(sz(:).*(1:numel(sz))')]/total;
c=1+(c-1)*step;
end

function [A,report]=registerPlane(fixed,moving,cfg,initial)
% Deterministic bounded similarity search on full source pixels. Prewarping
% into the atlas before optimization would permanently crop a partial FOV.
% Incremental similarities preserve the editor's independent scales/rotation.
if nargin<3, cfg=struct(); end
if nargin<4, initial=eye(3); initial(3,1:2)=([size(fixed,2) size(fixed,1)]-[size(moving,2) size(moving,1)])/2; end
cfg=defaults(cfg);
maskUsed=isfield(cfg,'movingMask') && ~isempty(cfg.movingMask);
if maskUsed
    assert(isequal(size(cfg.movingMask),size(moving)),'Source brain mask dimensions do not match anatomy.');
    moving=single(moving); moving(~logical(cfg.movingMask))=0;
end
F=robustVolume(fixed); V=robustVolume(moving);
assert(ismatrix(F)&&ismatrix(V),'deConfUSIon:AtlasPlane','2D registration requires two anatomy planes.');
assert(isequal(size(initial),[3 3])&&all(isfinite(initial(:)))&&det(initial(1:2,1:2))>0,'Invalid initial 2D transform.');
rf=imref2d(size(F)); pre=imwarp(V,affine2d(initial),'OutputView',rf);
report=struct('initialMatrix',initial,'target',cfg.target,'reviewRequired',true,'created',datestr(now,30), ...
    'method','bounded multiscale normalized mutual information; no mirrors or shear');
report.sourceMaskUsed=maskUsed;
retained0=nnz(pre>.05)/max(1,nnz(V>.05)*det(initial(1:2,1:2)));
A=initial; best=score(A); report.nmiBefore=normalizedMI(F,pre);
if ~cfg.useCurrent && cfg.searchInitialization
    progress(cfg,'Comparing image and foreground centers...');
    cf=volumeCentroid(F,1); cv=volumeCentroid(V,1);
    seed=initial; seed(3,1:2)=cf(1:2)-cv(1:2)*initial(1:2,1:2);
    for dy=[-24 -12 0 12 24]
        B=seed; B(3,2)=B(3,2)+dy; s=score(B);
        if s>best, A=B; best=s; end
    end
end
% Coarse-to-fine coordinate descent uses the same deterministic objective for
% vascular and histology; Doppler/atlas intensities are not assumed identical.
schedule=[16 6 .08;8 3 .04;4 1.5 .02;2 .75 .01;1 .35 .005];
for level=1:size(schedule,1)
    progress(cfg,sprintf('Refining coronal alignment: level %d/%d...',level,size(schedule,1)));
    steps=[schedule(level,1)*[1 1] schedule(level,2:3)];
    for sweep=1:6
        changed=false;
        for dim=1:4
            origin=A;
            for sign=[-1 1]
                checkCancel(cfg); delta=zeros(1,4); delta(dim)=sign*steps(dim);
                B=planeIncrement(origin,delta,size(F)); s=score(B);
                if s>best+1e-7, A=B; best=s; changed=true; end
            end
        end
        if ~changed, break; end
    end
end
after=imwarp(V,affine2d(A),'OutputView',rf);
report.nmiAfter=normalizedMI(F,after);
report.retainedFraction=nnz(after>.05)/max(1,nnz(V>.05)*det(A(1:2,1:2)));
report.matrix=A; report.changed=norm(A-initial,'fro')>1e-6;
if ~isfinite(best)
    error('deConfUSIon:AtlasOverlap','No valid plane overlap. Choose the approximate coronal atlas slice and position the anatomy, then retry.');
end
    function s=score(B)
        scale=svd(initial(1:2,1:2)\B(1:2,1:2));
        if any(scale<.7|scale>1.4), s=-inf; return; end
        W=imwarp(V,affine2d(B),'OutputView',rf);
        retained=nnz(W>.05)/max(1,nnz(V>.05)*det(B(1:2,1:2)));
        overlap=nnz(F>.05 & W>.05)/max(1,nnz(W>.05));
        if retained<min(.65,.8*retained0) || overlap<.1, s=-inf; return; end
        s=normalizedMI(F,W);
    end
end

function B=planeIncrement(A,d,sz)
c=([sz(2) sz(1)]+1)/2; angle=d(3)*pi/180; scale=exp(d(4));
R=scale*[cos(angle) sin(angle);-sin(angle) cos(angle)];
T=eye(3); T(1:2,1:2)=R; T(3,1:2)=c-c*R+d(1:2); B=A*T;
end

function t=matlabFit(V,rv,F,rf,model,optimizer,metric,initial,levels)
lastwarn('');
t=imregtform(V,rv,F,rf,model,optimizer,metric, ...
    'InitialTransformation',initial,'PyramidLevels',levels);
message=lastwarn;
if contains(lower(message),'diverg')
    error('deConfUSIon:AtlasConvergence','MATLAB optimization diverged. Previous alignment preserved; refine a manual start or try Greedy.');
end
end

function cfg=defaults(cfg)
d=struct('engine','greedy','target','vascular','model','rigid','useCurrent',false, ...
    'executable','','voxelSizeUm',[50 50 50],'maxDimension',160, ...
    'iterations',[100 50 20],'progressFcn',[],'cancelFcn',[],'searchInitialization',true);
names=fieldnames(d);
for k=1:numel(names), if ~isfield(cfg,names{k}), cfg.(names{k})=d.(names{k}); end, end
end

function ref=sampleReference(sz,step)
ref=imref3d(sz,[1-step/2 1+(sz(2)-.5)*step], ...
    [1-step/2 1+(sz(1)-.5)*step],[1-step/2 1+(sz(3)-.5)*step]);
end

function V=robustVolume(V)
V=single(V); valid=isfinite(V); samples=V(valid & V~=0);
if numel(samples)<32, error('deConfUSIon:AtlasEmpty','Anatomy or atlas contains too few valid nonzero voxels.'); end
lim=double(prctile(samples,[1 99.5]));
if lim(2)<=lim(1), error('deConfUSIon:AtlasConstant','Use a continuous anatomy image; a constant/binary label volume cannot be intensity registered.'); end
V(~valid)=0; V=min(1,max(0,(V-lim(1))/(lim(2)-lim(1))));
% Doppler spans orders of magnitude. A fixed square-root compression keeps
% weaker vessels represented in the MI histogram instead of collapsing them
% into its zero bin. This is registration-only; source amplitudes stay intact.
V=sqrt(V);
end

function nmi=normalizedMI(A,B)
idx=isfinite(A)&isfinite(B)&(A>.03|B>.03);
a=min(31,floor(double(A(idx))*32))+1; b=min(31,floor(double(B(idx))*32))+1;
P=accumarray([a b],1,[32 32]); P=P/max(1,sum(P(:)));
pa=sum(P,2); pb=sum(P,1); entropy=@(p)-sum(p(p>0).*log(p(p>0)));
nmi=(entropy(pa)+entropy(pb))/max(eps,entropy(P(:)));
end

function writeNifti(V,path,spacing)
niftiwrite(V,path);
info=niftiinfo(path); info.PixelDimensions=spacing; info.SpaceUnits='Millimeter';
info.Transform=affine3d(diag([spacing 1])); info.TransformName='Sform';
niftiwrite(V,path,info);
end

function writeMatrix(path,M)
fid=fopen(path,'w'); assert(fid>=0,'Cannot write temporary registration matrix.');
c=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%.17g %.17g %.17g %.17g\n',M');
end

function runProcess(executable,args,logFile,cfg)
% Launch directly with an argument list: no shell quoting, PATH mutations or
% visible command window, including executable names containing spaces.
list=java.util.ArrayList(); list.add(java.lang.String(executable));
for k=1:numel(args), list.add(java.lang.String(args{k})); end
builder=java.lang.ProcessBuilder(list); builder.redirectErrorStream(true);
builder.redirectOutput(java.io.File(logFile)); process=builder.start();
c=onCleanup(@()process.destroy()); %#ok<NASGU>
while true
    drawnow; checkCancel(cfg);
    try, code=process.exitValue(); break; catch, pause(.10); end
end
if code~=0
    msg=fileread(logFile); if numel(msg)>2200, msg=msg(end-2199:end); end
    error('deConfUSIon:GreedyFailed','Greedy failed (exit %d): %s',code,msg);
end
end

function progress(cfg,msg)
checkCancel(cfg);
if ~isempty(cfg.progressFcn), cfg.progressFcn(msg); end
drawnow;
end
function checkCancel(cfg)
if ~isempty(cfg.cancelFcn) && cfg.cancelFcn()
    error('deConfUSIon:AtlasCancelled','Automatic registration cancelled. Previous alignment preserved.');
end
end

function exe=findGreedy()
exe=''; candidates={getpref('deConfUSIon','greedyExecutable','')};
dirs=strsplit(getenv('PATH'),pathsep);
if ispc, name='greedy.exe'; else, name='greedy'; end
for k=1:numel(dirs), candidates{end+1}=fullfile(dirs{k},name); end %#ok<AGROW>
if ispc
    installs=dir(fullfile(getenv('ProgramFiles'),'ITK-SNAP*'));
    for k=numel(installs):-1:1, candidates{end+1}=fullfile(installs(k).folder,installs(k).name,'bin',name); end %#ok<AGROW>
end
for k=1:numel(candidates)
    if ~isempty(candidates{k}) && exist(candidates{k},'file')==2, exe=candidates{k}; return; end
end
end

function Y=warpSeries(X,T)
% Apply the same native -> resampled/oriented -> atlas mapping in every
% consumer. Legacy matrices without geometry retain their direct-grid use.
if isfield(T,'warpA'), matrix=T.warpA; else, matrix=T.M; end
if isfield(T,'outSize'), target=T.outSize; else, target=T.size; end
target=double(target(1:3));
assert(all(isfinite(target) & target>=1 & target==round(target)),'Invalid atlas output size.');
count=size(X,4); Y=zeros([target count],'single'); ref=imref3d(target);
for frame=1:count
    D=X(:,:,:,frame);
    if isfield(T,'scanGeometry') && ~isempty(T.scanGeometry)
        g=T.scanGeometry;
        if ~isequal([size(D,1) size(D,2) size(D,3)],g.originalSize)
            error('deConfUSIon:AtlasGeometryMismatch','Data dimensions differ from the anatomy used for this transform. Select a matching native dataset.');
        end
        if ~isfield(g,'atlasVoxelSizeUm'), error('deConfUSIon:AtlasGeometryMissing','Re-save this transform in 3D registration to include the atlas spacing.'); end
        D=double(permute(D,g.permutation));
        if isfield(g,'convention') && strcmp(g.convention,'coronal_stack_v2')
            if isfield(g,'flipAxes'), for axis=g.flipAxes, D=flip(D,axis); end, end
            prepared=prepareAnatomy(struct('Data',D,'VoxelSize',g.originalSpacingUm(g.permutation),'Geometry',g), ...
                struct('VoxelSize',g.atlasVoxelSizeUm));
            D=prepared.Data;
        else
        sv=double(g.originalSpacingUm(g.permutation)); av=double(g.atlasVoxelSizeUm);
        dims=[size(D,1) size(D,2) size(D,3)]; n=round((dims-1).*sv./av)+1;
        [q1,q2,q3]=ndgrid((0:n(1)-1)*av(1)/sv(1)+1, ...
            (0:n(2)-1)*av(2)/sv(2)+1,(0:n(3)-1)*av(3)/sv(3)+1);
        D=interpn(D,q1,q2,q3,'linear',0);
        D=permute(flip(flip(D,3),2),[3 1 2]);
        end
    end
    Y(:,:,:,frame)=imwarp(D,affine3d(double(matrix)),'OutputView',ref,'Interp','linear');
    drawnow limitrate;
end
end

function scan=prepareAnatomy(scan,atlas)
% Prepared coronal stacks use the bundled atlas order [AP DV LR]. Legacy
% paper inputs retain the original interpolation and flip/permute contract.
v2=isfield(scan,'Geometry') && isfield(scan.Geometry,'convention') && strcmp(scan.Geometry.convention,'coronal_stack_v2');
if ~v2
    scan=interpolate3D(atlas,scan); return;
end
D=single(scan.Data); sz=[size(D,1) size(D,2) size(D,3)];
sv=double(scan.VoxelSize(:)'); av=double(atlas.VoxelSize(:)');
assert(numel(sv)==3 && numel(av)==3 && all(isfinite([sv av])) && all([sv av]>0),'Invalid geometry spacings.');
n=round((sz-1).*sv./av)+1;
if prod(n)>1e8 || any(n<2), error('deConfUSIon:AtlasGrid','Implausible resampled grid; check voxel spacings.'); end
[q1,q2,q3]=ndgrid((0:n(1)-1)*av(1)/sv(1)+1,(0:n(2)-1)*av(2)/sv(2)+1,(0:n(3)-1)*av(3)/sv(3)+1);
scan.Data=interpn(D,q1,q2,q3,'linear',0); scan.VoxelSize=av;
end

function M=planeMatrix(A,plane)
% MATLAB volume coordinates are [DV AP LR] for atlas data [AP DV LR].
switch lower(plane)
    case 'coronal', axes=[3 1]; % screen horizontal LR, vertical DV
    case 'axial', axes=[3 2];   % screen horizontal LR, vertical AP
    case 'sagittal', axes=[2 1];% screen horizontal AP, vertical DV
    otherwise, error('deConfUSIon:AtlasPlane','Unknown plane.');
end
M=eye(4); M(axes,axes)=A(1:2,1:2); M(4,axes)=A(3,1:2);
end

function [cor,axi,sag]=previewCuts(D,M,sz,index)
% Reslice only the three visible planes for a responsive drag preview.
invM=inv(M);
[u,v]=meshgrid(1:sz(3),1:sz(2)); cor=sample(v,index(1)*ones(size(v)),u);
[u,v]=meshgrid(1:sz(3),1:sz(1)); axi=sample(index(2)*ones(size(v)),v,u);
[u,v]=meshgrid(1:sz(1),1:sz(2)); sag=sample(v,u,index(3)*ones(size(v)));
    function image=sample(x,y,z)
        points=[x(:) y(:) z(:) ones(numel(x),1)]*invM;
        image=reshape(interp3(D,points(:,1),points(:,2),points(:,3),'linear',0),size(x));
    end
end

function exe=findSnap()
exe=getpref('deConfUSIon','itksnapExecutable','');
if ~isempty(exe) && exist(exe,'file')==2, return; end
exe=''; greedy=findGreedy();
if ispc, name='ITK-SNAP.exe'; else, name='itksnap'; end
dirs=[{fileparts(greedy)} strsplit(getenv('PATH'),pathsep)];
for k=1:numel(dirs)
    candidate=fullfile(dirs{k},name);
    if exist(candidate,'file')==2, exe=candidate; return; end
end
end

function bundle=exportReview(fixed,moving,regions,regionInfo,M,spacingUm,folder,launch)
% A separate review bundle never overwrites the accepted Transformation.mat.
if nargin<8, launch=true; end
exe=findSnap();
if launch && isempty(exe), error('deConfUSIon:SnapMissing','ITK-SNAP was not found. Set the deConfUSIon itksnapExecutable preference.'); end
assert(isequal(size(fixed),size(regions)),'Atlas image and labels must share the same grid.');
spacing=double(spacingUm(:)')/1000;
parent=fullfile(folder,'AutoReview'); if ~exist(parent,'dir'), mkdir(parent); end
[~,unique]=fileparts(tempname(parent));
folder=fullfile(parent,[datestr(now,'yyyymmdd_HHMMSS') '_' unique]); mkdir(folder);
bundle=struct('folder',folder,'atlas',fullfile(folder,'atlas.nii'), ...
    'anatomy',fullfile(folder,'aligned_anatomy.nii'),'regions',fullfile(folder,'regions.nii'), ...
    'colors',fullfile(folder,'region_colors.txt'),'executable',exe,'launched',false);
aligned=imwarp(single(moving),affine3d(M),'OutputView',imref3d(size(fixed)),'Interp','linear');
writeReviewNifti(single(fixed),bundle.atlas,spacing);
writeReviewNifti(aligned,bundle.anatomy,spacing);
ids=uniqueValues(regions); [~,labelIndex]=ismember(regions,ids); labels=uint32(labelIndex); clear labelIndex;
fid=fopen(bundle.colors,'w'); assert(fid>=0,'Could not write review label colors.');
cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'0 0 0 0 0 0 0 "Background"\n');
mapping=cell(numel(ids),3);
for k=1:numel(ids)
    row=abs(double(ids(k)));
    color=[160 160 160]; title=sprintf('Atlas ID %g',ids(k));
    if isstruct(regionInfo) && isfield(regionInfo,'rgb') && row>=1 && row<=size(regionInfo.rgb,1) && row==round(row)
        color=double(regionInfo.rgb(row,:)); if max(color)<=1, color=color*255; end
        for field={'name','acr'}
            if isfield(regionInfo,field{1}) && numel(regionInfo.(field{1}))>=row
                names=regionInfo.(field{1});
                if iscell(names), title=char(names{row}); elseif isstring(names), title=char(names(row)); end
                break;
            end
        end
    end
    title=regexprep(title,'["\r\n]',' ');
    fprintf(fid,'%d %d %d %d 1 1 1 "%s (atlas ID %g)"\n',k,round(color),title,ids(k));
    mapping(k,:)={k,ids(k),title};
end
clear cleanup;
writeReviewNifti(labels,bundle.regions,spacing);
save(fullfile(folder,'ReviewProposal.mat'),'M','spacingUm','mapping');
fid=fopen(fullfile(folder,'README.txt'),'w');
fprintf(fid,['Review proposal only. The accepted Transformation.mat is unchanged.\n' ...
    'Review NIfTI axes are [LR AP DV], permuted from toolbox [AP DV LR].\n' ...
    'Atlas AP increases posteriorly and DV ventrally: the RAS header includes both direction signs.\n' ...
    'Check vessels, ventricles and boundaries in all planes and at the edges of scan coverage.\n' ...
    'Q/E adjusts overlay opacity; W toggles the overlay; S toggles segmentation.\n' ...
    'Verify anatomical handedness against acquisition landmarks; the NIfTI grid alone cannot establish probe left/right.\n' ...
    'Return to MATLAB to adjust alignment or Undo auto; use Save reviewed to accept.\n' ...
    'ITK-SNAP segmentation edits do not update the MATLAB transform automatically.\n']); fclose(fid);
if launch
    % Only anatomy is an overlay. Keep the selected vascular/histology atlas
    % fixed underneath; region labels are available on disk but start hidden.
    args={exe,'-g',bundle.atlas,'-o',bundle.anatomy};
    list=java.util.ArrayList(); for k=1:numel(args), list.add(java.lang.String(args{k})); end
    builder=java.lang.ProcessBuilder(list); builder.redirectErrorStream(true);
    builder.redirectOutput(java.io.File(fullfile(folder,'itksnap.log')));
    process=builder.start(); % Requested interactive viewer; do not destroy it on return.
    bundle.process=process;
    bundle.launched=true;
end
end

function writeReviewNifti(V,path,spacing)
% Atlas = AP x DV x LR; NIfTI spatial axes = LR x AP x DV.
V=permute(V,[3 1 2]); spacing=spacing([3 1 2]);
niftiwrite(V,path); info=niftiinfo(path);
info.PixelDimensions=spacing; info.SpaceUnits='Millimeter';
info.Transform=affine3d(diag([spacing.*[1 -1 -1] 1])); info.TransformName='Sform';
niftiwrite(V,path,info);
end

function ids=uniqueValues(regions)
ids=unique(regions(:)); ids=ids(isfinite(ids) & ids~=0);
end

function removeWork(work)
% Delete only this invocation's immediate temporary files; never recurse.
try
    d=dir(work);
    for k=1:numel(d), if ~d(k).isdir, delete(fullfile(work,d(k).name)); end, end
    rmdir(work);
catch
end
end

function label(f,pos,str,C,fs)
uicontrol(f,'Style','text','Units','normalized','Position',pos,'String',str, ...
    'FontName','Arial','FontSize',fs,'HorizontalAlignment','left', ...
    'BackgroundColor',C.background,'ForegroundColor',C.text);
end
function h=button(f,pos,str,color,callback)
h=uicontrol(f,'Style','pushbutton','Units','normalized','Position',pos,'String',str, ...
    'FontName','Arial','FontSize',12,'FontWeight','bold','BackgroundColor',color, ...
    'ForegroundColor','w','Callback',callback);
end
