function varargout = fusiLightSuite(action,varargin)
%FUSILIGHTSUITE Resumable optional registration, histology and implant API.
switch lower(char(action))
    case 'gui', [varargout{1:nargout}]=fusiLightSuiteGUI(varargin{:});
    case 'config',varargout{1}=fusiLightSuiteConfig(varargin{:});
    case 'dependencies', [varargout{1:nargout}]=fusiLightSuiteDependencies(varargin{:});
    case 'prepare',varargout{1}=prepareLoaded(varargin{:});
    case 'preparefile',varargout{1}=prepareFile(varargin{:});
    case 'load',varargout{1}=readSession(varargin{:});
    case 'landmarks',openLandmarks(varargin{:});
    case 'register',varargout{1}=fitRegistration(varargin{:});
    case 'apply',varargout{1}=applyRegistration(varargin{:});
    case 'review', [varargout{1:nargout}]=reviewRegistration(varargin{:});
    case 'histology', [varargout{1:nargout}]=histologyAction(varargin{:});
    case 'trace',traceImplant(varargin{:});
    case 'validatepoints',varargout{1}=validatePoints(varargin{:});
    case 'orientation',varargout{1}=setOrientation(varargin{:});
    case 'geometry',varargout{1}=spacingFromMeta(fusiLightSuiteConfig(),varargin{1});
    case 'exportregions',varargout{1}=exportNativeRegions(varargin{:});
    case 'exportunderlays',varargout{1}=exportNativeUnderlays(varargin{:});
    case 'revise',varargout{1}=newProjectFromFit(varargin{:});
    case 'validatefit',varargout{1}=validateFit(varargin{:});
    case 'inspectfit',varargout{1}=inspectFit(varargin{:});
    case 'repairinverse',varargout{1}=repairInverse(varargin{:});
    otherwise,error('deConfUSIon:LightSuiteAction','Unknown LightSuite action: %s',action);
end
end

function bundle=exportNativeRegions(folder,progressFcn)
if nargin<2,progressFcn=[];end
reportExport(progressFcn,NaN,'Checking accepted fit and native geometry...');
s=readSession(folder);assert(s.fitReviewed,'Review and accept the registration overlays before exporting region labels.');
guard=fusiLightSuitePaths(s.config); %#ok<NASGU>
validateFit(s,false);
reportExport(progressFcn,NaN,'Mapping both atlas stages onto the acquired native grid...');
[referenceLabels,~,regions]=resampleAnnotation(s.opts.annotation,s.opts.parcelinfo,'structure');
sampler=fusiLightSuiteAtlasSampling(s,progressFcn);
reportExport(progressFcn,NaN,'Mapping anatomical hemispheres onto the native grid...');
H=uint8(zeros(size(s.opts.annotation)));mid=size(H,3)/2;
% Official Allen CCF2020 ML increases from anatomical left to right (PIR).
H(:,:,1:floor(mid))=2;H(:,:,floor(mid)+1:end)=1;H(s.opts.annotation==0)=0;
info=struct('name',{cellstr(regions.name)},'acr',{cellstr(regions.acronym)}, ...
    'rgb',[regions.R regions.G regions.B]/255,'groupingMode','Structure');
[~,exportID]=fileparts(tempname);
baseMeta=struct('kind','deConfUSIon_LightSuite_native_regions', ...
    'nativeSize',s.inputSize(1:3),'voxelSizeMm',s.opts.sample_res, ...
    'arrayOrder','same input array dimensions; no new orientation or crop', ...
    'atlasAxes','AP DV ML','reference',s.reference,'transformFile',fullfile(s.opts.savepath,'transform_params.mat'), ...
    'sourceCommit',s.sourceCommit,'fitReviewed',true,'nearestLabels',true,'exportedAt',datestr(now,30), ...
    'exportSchema',3,'exportID',exportID, ...
    'hemisphereConvention','official CCF2020 PIR: first ML half=left; second ML half=right', ...
    'explanation','Registered atlas sampled onto the exact original recording grid; no functional data are resampled.');
stages={'affine_bspline','affine'};bundles=cell(1,2);
for stageIndex=1:2
    files=fusiLightSuiteNativeFiles(s.opts.savepath,stages{stageIndex});
    [labels,displayLabels]=sampler.sample(referenceLabels,files.stage,'nearest');
    hemisphere=sampler.sample(H,files.stage,'nearest',false);labels(hemisphere==0)=0;
    q=baseMeta;q.registrationStage=files.stage;q.registrationStageName=files.name;
    bundle=struct('atlasRegionLabels3D',uint16(labels),'atlasInfoRegions',info, ...
        'leftHemisphereMask',hemisphere==2,'rightHemisphereMask',hemisphere==1,'lightSuiteNativeMeta',q, ...
        'atlasDisplayRegionLabels3D',uint16(displayLabels),'lightSuiteDisplayGeometry',sampler.geometry);
    fusiLightSuiteRegionInput(bundle,s.inputSize(1:3));
    save(files.regions,'-struct','bundle','-v7.3');bundles{stageIndex}=bundle;
    reportExport(progressFcn,NaN,['Saving editable native tissue mask: ' files.name '...']);
    [~,excluded]=fusiAtlasRegionCatalog(labels,info);
    brainMask=labels>0&~ismember(labels,excluded);overlayMask=brainMask; %#ok<NASGU>
    brainImage=single(s.opts.sample);lightSuiteMaskMeta=q; %#ok<NASGU>
    save(files.mask,'brainMask','overlayMask','brainImage','lightSuiteMaskMeta','-v7.3');
end
bundle=bundles{1};
[backgrounds,affineBackgrounds]=fusiLightSuiteNativeBackgrounds(s,bundles{1}.lightSuiteNativeMeta, ...
    progressFcn,bundles{2}.lightSuiteNativeMeta,sampler);
files=fusiLightSuiteNativeFiles(s.opts.savepath);save(files.backgrounds,'-struct','backgrounds','-v7.3');
files=fusiLightSuiteNativeFiles(s.opts.savepath,'affine');save(files.backgrounds,'-struct','affineBackgrounds','-v7.3');
reportExport(progressFcn,1,'Both stages saved: native regions, atlas backgrounds and editable tissue masks.');
fusiLightSuiteLog('SAVED',s,'AFFINE and AFFINE + B-SPLINE native atlases, backgrounds and masks.\nFolder: %s',s.opts.savepath);
end

function backgrounds=exportNativeUnderlays(folder,progressFcn,checkFit)
if nargin<2,progressFcn=[];end
if nargin<3,checkFit=true;end
s=readSession(folder);assert(s.fitReviewed,'Accept the LightSuite registration before exporting backgrounds.');
if checkFit,validateFit(s,false);end
files=fusiLightSuiteNativeFiles(s.opts.savepath);affineFiles=fusiLightSuiteNativeFiles(s.opts.savepath,'affine');
if ~isfile(files.regions)||~isfile(affineFiles.regions)
    exportNativeRegions(s,progressFcn);backgrounds=load(files.backgrounds);return;
end
S=load(files.regions);A=load(affineFiles.regions);
if ~isfield(S.lightSuiteNativeMeta,'exportSchema')||S.lightSuiteNativeMeta.exportSchema<3|| ...
        ~isfield(A.lightSuiteNativeMeta,'exportSchema')||A.lightSuiteNativeMeta.exportSchema<3|| ...
        ~isfield(S.lightSuiteNativeMeta,'exportID')||~isfield(A.lightSuiteNativeMeta,'exportID')|| ...
        ~strcmp(S.lightSuiteNativeMeta.exportID,A.lightSuiteNativeMeta.exportID)
    exportNativeRegions(s,progressFcn);backgrounds=load(files.backgrounds);return;
end
fusiLightSuiteRegionInput(S,s.inputSize(1:3));
fusiLightSuiteRegionInput(A,s.inputSize(1:3));
[backgrounds,affineBackgrounds]=fusiLightSuiteNativeBackgrounds(s,S.lightSuiteNativeMeta,progressFcn,A.lightSuiteNativeMeta);
save(files.backgrounds,'-struct','backgrounds','-v7.3');
save(affineFiles.backgrounds,'-struct','affineBackgrounds','-v7.3');
end

function reportExport(callback,fraction,message)
if ~isempty(callback),callback(fraction,message);end
end

function s=newProjectFromFit(folder,destination,mode)
% Preserve the old fit, while making its paired landmarks editable again.
s=readSession(folder);original=s.opts.savepath;
if nargin<3||isempty(mode),mode='landmarks';end
assert(any(strcmp(mode,{'landmarks','orientation'})),'Choose landmarks or orientation revision mode.');
if nargin<2||isempty(destination)
    base=fullfile(original,['Registration_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);
    destination=base;attempt=1;
    while isfolder(destination)||isfile(destination),destination=sprintf('%s_%02d',base,attempt);attempt=attempt+1;end
end
cfg=s.config;cfg.outputFolder=char(destination);
validatePreparationDestination(cfg);
assert(~isfolder(destination)||isempty(setdiff({dir(destination).name},{'.','..'})), ...
    'Choose a new empty folder for the revision; existing outputs are preserved.');
if ~isfolder(destination),mkdir(destination);end
s.opts.savepath=char(destination);s.config.outputFolder=char(destination);
s.fitReviewed=false;s.registrationComplete=false;s.created=datestr(now,30);
s.revisedFrom=original;
for name={'numericValidation','landmarkValidation','reviewed','landmarkSummary','inverseRebuilt'}
    if isfield(s,name{1}),s=rmfield(s,name{1});end
end
cp=fullfile(original,'control_points_minimal.mat');
if strcmp(mode,'orientation')
    % Landmarks belong to the old prepared orientation and cannot be reused
    % after changing the signed permutation. Preserve them only in the parent.
    s.orientationConfirmed=false;s.config.orientationConfirmed=false;
elseif isfile(cp)
    [ok,message]=copyfile(cp,fullfile(destination,'control_points_minimal.mat'));
    assert(ok,'Cannot copy the paired landmarks: %s',message);
end
displayFile=fullfile(original,'landmark_underlay.mat');
if isfile(displayFile),copyfile(displayFile,fullfile(destination,'landmark_underlay.mat'));end
saveSession(s);
fusiLightSuiteLog('PREPARED',s,'New registration version (%s).\nPrevious fit preserved in: %s\nNew project: %s',mode,original,destination);
end

function s=setOrientation(folder,permutation)
s=readSession(folder);p=double(permutation(:)');
assert(isequal(sort(abs(p)),1:3),'Each input axis must appear exactly once.');
assert(~isfile(fullfile(s.opts.savepath,'control_points_minimal.mat'))&& ...
    ~isfile(fullfile(s.opts.savepath,'transform_params.mat')), ...
    'Orientation is locked after landmarks exist. Prepare a new project to change it.');
s.opts.permute_sample_to_atlas=p;s.config.permutation=p;
s.orientationConfirmed=true;s.config.orientationConfirmed=true;saveSession(s);
end

function session=prepareFile(filename,cfg)
% Efficient for ordinary v7.3 4-D I files; no full six-gigabyte copy needed.
if nargin<2,cfg=struct();end
cfg=fusiLightSuiteConfig(cfg);cfg.sourceFile=char(filename);
validatePreparationDestination(cfg);
reportPreparation(cfg,0,'Inspecting recording metadata...');
[~,~,ext]=fileparts(filename);
if ~strcmpi(ext,'.mat')
    [data,meta]=loadFUSIData(filename);session=prepareLoaded(data,meta,cfg);return;
end
W=whos('-file',filename);ii=find(strcmp({W.name},'I'),1);
if ~isempty(ii)&&numel(W(ii).size)==4&&all(W(ii).size(1:3)>1)&&H5F.is_hdf5(filename)
    meta=fusiLightSuiteReadMetadata(filename);
    cfg=spacingFromMeta(cfg,meta);validatePreparationSpacing(cfg);
    m=matfile(filename);n=W(ii).size(4);frames=unique(round(linspace(max(1,ceil(.1*n)),max(1,floor(.9*n)),min(n,cfg.maxTemplateFrames))));
    volume=zeros([W(ii).size(1:3) numel(frames)],'single');
    for k=1:numel(frames)
        reportPreparation(cfg,.05+.55*(k-1)/numel(frames),sprintf('Sampling anatomy: frame %d/%d (recording frame %d)',k,numel(frames),frames(k)));
        volume(:,:,:,k)=single(m.I(:,:,:,frames(k)));
        if mod(k,10)==0,fprintf('LightSuite template: sampled frame %d/%d\n',k,numel(frames));drawnow limitrate;end
    end
    reportPreparation(cfg,NaN,'Computing median anatomy from sampled frames...');
    template=median(volume,4,'omitnan');clear volume;
    session=writePrepared(template,meta,cfg,frames,W(ii).size);
else
    [data,meta]=loadFUSIData(filename);
    session=prepareLoaded(data,meta,cfg);
end
end

function session=prepareLoaded(data,meta,cfg)
if nargin<3,cfg=struct();end
cfg=fusiLightSuiteConfig(cfg);
validatePreparationDestination(cfg);
if isempty(cfg.voxelSizeMm)
    [cfg.voxelSizeMm,cfg.spacingSource]=fusiLightSuiteInputSpacing(data,meta,cfg.sourceFile);
end
validatePreparationSpacing(cfg);
assert(~(isfield(data,'inputIsPSC')&&isequal(data.inputIsPSC,true))&& ...
    ~(isfield(meta,'inputIsPSC')&&isequal(meta.inputIsPSC,true)), ...
    'deConfUSIon:LightSuitePSCAnatomy','Prepare registration from vascular anatomy / Doppler intensity, not a centered PSC movie. Apply the accepted transform to native-grid PSC measurements afterwards.');
assert(isstruct(data)&&isfield(data,'I')&&ndims(data.I)==4&&size(data.I,3)>1, ...
    'deConfUSIon:LightSuite3D','Select a volumetric [row column plane time] recording. Use the histology tab for serial sections.');
assert(~isfield(data,'isStepMotor')||~data.isStepMotor,'A step-motor recording is not a simultaneous 3-D time series.');
n=size(data.I,4);frames=unique(round(linspace(max(1,ceil(.1*n)),max(1,floor(.9*n)),min(n,cfg.maxTemplateFrames))));
volume=zeros([size(data.I,1:3) numel(frames)],'single');
for k=1:numel(frames)
    reportPreparation(cfg,.05+.55*(k-1)/numel(frames),sprintf('Sampling anatomy: frame %d/%d',k,numel(frames)));
    volume(:,:,:,k)=single(data.I(:,:,:,frames(k)));
end
reportPreparation(cfg,NaN,'Computing median anatomy from sampled frames...');
template=median(volume,4,'omitnan');clear volume;
session=writePrepared(template,meta,cfg,frames,size(data.I));
end

function cfg=spacingFromMeta(cfg,meta)
% Explicit mm entries take priority; known native scanner schemas are shared
% with the existing spatial calibration reader used by SCM.
if ~isempty(cfg.voxelSizeMm),return;end
[cfg.voxelSizeMm,cfg.spacingSource]=fusiLightSuiteSpacing(meta);
end
function validatePreparationSpacing(cfg)
assert(numel(cfg.voxelSizeMm)==3&&all(isfinite(cfg.voxelSizeMm)&cfg.voxelSizeMm>0), ...
    'deConfUSIon:LightSuiteSpacing','No supported physical spacing was found. Enter measured mm values for the three input array dimensions.');
end
function validatePreparationDestination(cfg)
assert(~isempty(cfg.outputFolder),'Choose a dedicated LightSuite output folder.');
assert(~isfile(fullfile(cfg.outputFolder,'deconfusion_lightsuite_session.mat')), ...
    'deConfUSIon:LightSuiteExisting','A project already exists in this folder. Use Open existing project to resume, or choose a new output folder.');
end
function reportPreparation(cfg,fraction,message)
if isa(cfg.progressFcn,'function_handle'),cfg.progressFcn(fraction,message);end
end

function session=writePrepared(template,meta,cfg,frames,inputSize)
assert(~(isfield(meta,'inputIsPSC')&&isequal(meta.inputIsPSC,true)), ...
    'Prepare the anatomical template from Doppler intensity, not a PSC movie.');
assert(numel(cfg.voxelSizeMm)==3&&all(isfinite(cfg.voxelSizeMm))&&all(cfg.voxelSizeMm>0), ...
    'deConfUSIon:LightSuiteSpacing','Confirm the voxel size in mm for EACH input array dimension. No spacing or unit will be guessed.');
p=double(cfg.permutation(:)');assert(isequal(sort(abs(p)),1:3),'Invalid signed sample-to-atlas axis permutation.');
assert(~isempty(cfg.outputFolder),'Choose a dedicated output folder for this recording.');
folder=char(cfg.outputFolder);if ~isfolder(folder),mkdir(folder);end
assert(~isfile(fullfile(folder,'deconfusion_lightsuite_session.mat')), ...
    'deConfUSIon:LightSuiteExisting','A LightSuite project already exists in this output folder. Open it to resume or choose another folder.');
guard=fusiLightSuitePaths(cfg); %#ok<NASGU>
reportPreparation(cfg,NaN,'Checking registration dependencies...');
report=fusiLightSuiteDependencies(cfg);assert(report.fusiReady,'deConfUSIon:LightSuiteMissing','Missing or incompatible optional dependencies. Use Check / Install dependencies.');
reportPreparation(cfg,NaN,'Reading the vascular atlas template...');
[atlas,ai]=fusiLightSuiteReadNifti(fullfile(cfg.vascularAtlas,'vessel_atlas_template.nii.gz'));
reportPreparation(cfg,NaN,'Reading atlas region labels...');
[labels,li]=fusiLightSuiteReadNifti(fullfile(cfg.vascularAtlas,'vessel_atlas_annotation.nii.gz'));
assert(isequal(size(atlas),size(labels))&&isequal(size(atlas),[264 160 228]),'The vascular atlas must be the matching AP x DV x ML published grid.');
assert(all(abs(double(ai.PixelDimensions(1:3))-.05)<1e-9)&&all(abs(double(li.PixelDimensions(1:3))-.05)<1e-9),'Vascular atlas must be 50 um isotropic.');
reportPreparation(cfg,NaN,'Matching atlas region metadata...');
parcelinfo=readtable(fullfile(cfg.allenAtlas,'parcellation_to_parcellation_term_membership.csv'));
assert(all(ismember(unique(double(labels(:))),[0;double(parcelinfo.parcellation_index(:))])), 'Atlas label values and parcellation table do not match.');
template(~isfinite(template))=0;
assert(nnz(template)>100&&max(template(:))>min(template(:)),'Anatomical template is empty or constant.');
opts=struct('sample',template,'sample_res',double(cfg.voxelSizeMm(:)'), ...
    'atlas',atlas,'annotation',labels,'atlas_res',[.05 .05 .05], ...
    'parcelinfo',parcelinfo,'permute_sample_to_atlas',p,'savepath',folder, ...
    'mousename',matlab.lang.makeValidName(cfg.name),'bspline_spatial_scale',cfg.bsplineSpacingMm, ...
    'n_histogram_bins',cfg.histogramBins);
sessionConfig=cfg;sessionConfig.progressFcn=[];
session=struct('schema','deConfUSIon-LightSuite-v1','workflow','fusi', ...
    'opts',opts,'config',sessionConfig,'inputSize',double(inputSize),'templateFrames',frames, ...
    'inputMetadata',meta,'orientationConfirmed',logical(cfg.orientationConfirmed), ...
    'reference','LightSuite published vascular atlas, Zenodo 21338217, Allen CCF2020 AP/DV/ML, 50um', ...
    'sourceCommit',report.sourceCommit,'elastixVersion',report.elastixVersion, ...
    'created',datestr(now,30),'fitReviewed',false,'registrationComplete',false);
reportPreparation(cfg,NaN,'Saving anatomy, geometry and registration project...');
saveSession(session);
reportPreparation(cfg,1,'Anatomy prepared. Confirm orientation next.');
fusiLightSuiteLog('PREPARED',session,'Anatomy %s from %d sampled frames.\nProject: %s',mat2str(size(template)),numel(frames),folder);
end

function session=readSession(folder)
if isstruct(folder),session=folder;return;end
file=fullfile(char(folder),'deconfusion_lightsuite_session.mat');
assert(isfile(file),'Select a deConfUSIon LightSuite output folder.');
S=load(file,'session');session=S.session;
assert(strcmp(session.schema,'deConfUSIon-LightSuite-v1'),'Unrecognized project schema.');
session.opts.savepath=char(folder);session.config.outputFolder=char(folder);
end

function saveSession(session)
folder=session.opts.savepath;
save(fullfile(folder,'deconfusion_lightsuite_session.mat'),'session','-v7.3');
opts=session.opts;save(fullfile(folder,'regopts.mat'),'-struct','opts','-v7.3');
summary=rmfield(session,intersect({'opts','inputMetadata'},fieldnames(session)));
summary.axes='input array dimensions -> signed permutation -> atlas AP,DV,ML; indices are MATLAB 1-based';
summary.spacingUnits='mm';summary.rawUnmodified=true;
fid=fopen(fullfile(folder,'deconfusion_lightsuite_provenance.json'),'w');
assert(fid>=0,'Cannot write LightSuite project provenance.');c=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',jsonencode(summary,'PrettyPrint',true));
end

function openLandmarks(folder)
s=readSession(folder);assert(s.orientationConfirmed,'Confirm sample-to-atlas orientation in the workspace before placing landmarks.');
fusiLightSuiteLandmarks(s);
end

function attachGuard(guard,before)
after=findall(groot,'Type','figure');made=setdiff(after,before);
if ~isempty(made),for k=1:numel(made),setappdata(made(k),'deConfUSIonLightSuitePathGuard',guard);end,end
end

function result=validatePoints(folder)
s=readSession(folder);cpfile=fullfile(s.opts.savepath,'control_points_minimal.mat');
assert(isfile(cpfile),'Place and save matched landmarks first (S in the LightSuite control-point window).');
cp=load(cpfile);assert(isfield(cp,'sample_points')&&isfield(cp,'atlas_points'),'Unrecognized landmark file.');
n1=cellfun(@(x)size(x,1),cp.sample_points);n2=cellfun(@(x)size(x,1),cp.atlas_points);
assert(all(n1==n2),'deConfUSIon:LightSuiteUnequalPoints','Some sample/atlas halves have unequal counts. Correct them; no unmatched sets will be silently dropped.');
a=cat(1,cp.sample_points{:});b=cat(1,cp.atlas_points{:});
assert(size(a,1)>=5,'deConfUSIon:LightSuiteFewPoints','At least five landmark pairs spanning three dimensions are required; more are normally needed.');
assert(all(isfinite(a(:)))&&all(isfinite(b(:))),'Nonfinite landmarks are invalid.');
assert(rank(a(:,1:3)-mean(a(:,1:3),1))==3&&rank(b(:,1:3)-mean(b(:,1:3),1))==3, ...
    'deConfUSIon:LightSuiteCoplanar','Landmarks must span AP, DV and ML, not lie in a single plane.');
result=struct('nPairs',size(a,1),'rankSample',3,'rankAtlas',3);
end

function session=fitRegistration(folder,progressFcn)
if nargin<2,progressFcn=[];end
session=readSession(folder);
assert(session.orientationConfirmed,'Confirm orientation before fitting.');
points=validatePoints(session);guard=fusiLightSuitePaths(session.config); %#ok<NASGU>
check=fusiLightSuiteDependencies(session.config);assert(check.fusiReady,'Missing optional dependencies.');
assert(~isfile(fullfile(session.opts.savepath,'transform_params.mat')), ...
    'deConfUSIon:LightSuiteFitExists','A transform already exists. Use a new project folder for a different fit; existing results are preserved.');
progressGuard=fusiLightSuiteFitProgress('begin',progressFcn,session); %#ok<NASGU>
multiobjRegistrationFusi(session.opts,session.config.landmarkWeight,false);
fusiLightSuiteFitProgress('stage','4/4 Numerical transform checks and saving');
session.numericValidation=validateFit(session,true);
session.registrationComplete=true;session.landmarkSummary=points;session.fitReviewed=false;saveSession(session);
fusiLightSuiteFitProgress('update',1,'Fit saved; review all diagnostic overlays.');
fusiLightSuiteLog('FIT SAVED',session,'Review the affine AND B-spline alignment before accepting.\nProject: %s',session.opts.savepath);
end

function result=applyRegistration(folder,data,saveFullVolumes)
if nargin<3,saveFullVolumes=false;end
s=readSession(folder);assert(s.fitReviewed,'Review and accept the diagnostic affine / B-spline overlays in the workspace first.');
assert(isfile(fullfile(s.opts.savepath,'transform_params.mat')),'No registration transform exists.');
validateFit(s,false);
if isstruct(data),assert(isfield(data,'I'),'Expected data.I or a numeric map/movie.');data=data.I;end
assert(isnumeric(data)&&isequal(size(data,[1 2 3]),s.inputSize(1:3)), ...
    'deConfUSIon:LightSuiteApplyGrid','Input must have the exact native grid used to prepare this registration. Do not apply it to cropped, resampled or differently oriented data.');
if saveFullVolumes
    bytes=2*prod(size(s.opts.atlas))*size(data,4)*4;
    assert(bytes/2^30<=s.config.maxAtlasMovieGiB,'Full affine and nonlinear movies would require %.1f GiB. Use regional timecourses or smaller chunks.',bytes/2^30);
end
guard=fusiLightSuitePaths(s.config); %#ok<NASGU>
warningState=warning('off','applyFusiTransforms:noRigidTransform');
warningCleanup=onCleanup(@()warning(warningState)); %#ok<NASGU>
% A single-session fit uses this exact native grid: the rigid step is identity.
result=applyFusiTransforms(s.opts,single(data),s.opts.sample_res,logical(saveFullVolumes),[]);
% Upstream 2cf948c assumes 10 um here; correct the physical volume for 50um.
ids=double(s.opts.annotation(:));counts=accumarray(ids+1,1,[max(ids)+1 1]);
result.areavols=counts(double(result.groupidx)+1)*prod(s.opts.atlas_res);
result.areavols_units='mm^3';result.areavols_scope='Total atlas region volume, not acquired or valid voxel coverage';
result.atlasVoxelSizeMm=s.opts.atlas_res;result.atlasAxes={'AP','DV','ML'};
result.registrationFile=fullfile(s.opts.savepath,'transform_params.mat');
result.sourceCommit=s.sourceCommit;result.exploratory=true;
end

function varargout=reviewRegistration(folder,accept)
s=readSession(folder);
if nargin>1&&logical(accept)
    assert(isfile(fullfile(s.opts.savepath,'transform_params.mat')), ...
        'Run registration, then inspect the affine and nonlinear volumes in all three planes.');
    s.numericValidation=validateFit(s,false);s.landmarkValidation=fusiLightSuiteLandmarkResiduals(s);
    s.fitReviewed=true;s.reviewed=datestr(now,30);saveSession(s);
elseif nargin>1
    s.fitReviewed=false;
    if isfield(s,'reviewed'),s=rmfield(s,'reviewed');end
    saveSession(s);
end
if nargout,varargout{1}=s;end
end

function varargout=histologyAction(stage,folder,varargin)
cfg=fusiLightSuiteConfig();guard=fusiLightSuitePaths(cfg); %#ok<NASGU>
check=fusiLightSuiteDependencies(cfg);assert(check.histologyReady,'Missing TIFF histology dependencies.');
switch lower(stage)
    case 'prepare'
        % TIFFs are copied into the selected analysis folder. Raw inputs are
        % never reordered, flipped, overwritten, or given sidecar files.
        input=varargin{1};options=varargin{2};
        assert(numel(input)>=2,'Serial histology needs at least two sections. Use existing 2D registration for an independent single slice.');
        assert(~isempty(strtrim(folder))&&isAbsolutePath(folder),'Choose a dedicated absolute histology analysis folder.');
        assert(~strcmpi(char(java.io.File(folder).getCanonicalPath),fileparts(fileparts(fileparts(mfilename('fullpath'))))), ...
            'The toolbox root cannot be a histology output folder.');
        assert(options.pixelSizeUm>0&&options.sectionSpacingUm>0,'Specify measured pixel size and section spacing in um.');
        assert(numel(options.atlasAPLimits)==2&&all(isfinite(options.atlasAPLimits))&& ...
            all(options.atlasAPLimits==round(options.atlasAPLimits))&&options.atlasAPLimits(1)>=1&& ...
            options.atlasAPLimits(2)<=1320&&diff(options.atlasAPLimits)>0,'Atlas AP range must be two ascending integer indices within 1..1320.');
        assert(nnz(strcmpi(options.channelNames,options.registrationChannel))==1, ...
            'Registration channel must exactly match one channel name.');
        extensions=cell(size(input));for k=1:numel(input),[~,~,extensions{k}]=fileparts(input{k});end
        isCzi=strcmpi(extensions,'.czi');assert(~any(isCzi)||all(isCzi),'Choose either CZI inputs or TIFF inputs, not both formats.');
        for k=1:numel(input)
            assert(~strcmpi(char(java.io.File(folder).getCanonicalPath),char(java.io.File(fileparts(input{k})).getCanonicalPath)), ...
                'Use an analysis output folder separate from the raw sections folder.');
        end
        assert(~isfolder(fullfile(folder,'inputs')),'This histology project exists. Open it to resume.');
        mkdir(fullfile(folder,'inputs'));paths=cell(size(input));
        for k=1:numel(input)
            [~,~,ext]=fileparts(input{k});assert(any(strcmpi(ext,{'.tif','.tiff','.czi'})),'Use TIFF or CZI sections.');
            if strcmpi(ext,'.czi'),assert(check.cziReady,'CZI requires BioformatsImage and OME Bio-Formats.');end
            paths{k}=fullfile(folder,'inputs',sprintf('section_%05d%s',k,ext));copyfile(input{k},paths{k});
        end
        info=struct('filepaths',{paths},'mousename','histology','pxsize',[options.pixelSizeUm options.pixelSizeUm], ...
            'channames',{options.channelNames},'slicethickness',options.sectionSpacingUm, ...
            'px_process',1.25,'px_register',20,'px_atlas',10,'atlasaplims',options.atlasAPLimits, ...
            'regchan',options.registrationChannel,'denoisedapi',false,'medianfiltreg',false,'use_gpu',false);
        info=getSliceInfo(info);generateSliceVolume(info,info.regchan);
        % generateSliceVolume writes the enriched sliceinfo.mat itself.
        histologyFolder=info.procpath;
        fid=fopen(fullfile(folder,'histology_project.txt'),'w');fprintf(fid,'%s',histologyFolder);fclose(fid);
        if nargout,varargout{1}=histologyFolder;end
    otherwise
        marker=fullfile(folder,'histology_project.txt');if isfile(marker),folder=strtrim(fileread(marker));end
        q=load(fullfile(folder,'sliceinfo.mat'),'sliceinfo');info=q.sliceinfo;
        assert(info.px_process==1.25&&info.px_register==20&&info.px_atlas==10, ...
            'This adapter currently validates the upstream 1.25/20/10 um histology contract only.');
        switch lower(stage)
            case 'order'
                before=findall(groot,'Type','figure');SliceOrderEditor(info.volorder);attachGuard(guard,before);
            case 'align'
                generateReordedVolume(info);alignSliceVolume(info.slicevol,info);
            case 'angle'
                opts=load(fullfile(folder,'regopts.mat'));before=findall(groot,'Type','figure');determineCuttingAngleGUI(opts);attachGuard(guard,before);
            case 'landmarks'
                opts=load(fullfile(folder,'regopts.mat'));before=findall(groot,'Type','figure');matchControlPointsInSlices(opts);attachGuard(guard,before);
            case 'register'
                opts=load(fullfile(folder,'regopts.mat'));opts.cpwt=.4;registerSlicesToAtlas(opts);
            case 'volume'
                tr=load(fullfile(folder,'transform_params.mat'));generateRegisteredSliceVolume(info,tr);
            case 'intensities'
                generateSliceIntensitiesCSV(info,'writetocsv',true);
                correctHistologyHemispheres(info.procpath);
            case 'cells'
                channel=varargin{1};assert(all(channel>=1&channel<=numel(info.channames)),'Invalid channel index.');
                assert(isscalar(varargin{2})&&isfinite(varargin{2})&&varargin{2}>0,'Cell diameter must be positive and finite.');
                assert(numel(varargin{3})==2&&all(isfinite(varargin{3}))&&all(varargin{3}>0),'Specify two positive SBR thresholds.');
                info.celldiam=varargin{2};info.thresuse=single(varargin{3});info.debug=true;
                extractCellsFromSliceVolume(info,channel);
            case 'mapcells'
                error('deConfUSIon:LightSuiteSlicePointValidation', ...
                    ['Atlas mapping of detected serial-section cells is not enabled: the upstream point-coordinate chain needs independent validation. ' ...
                    'Registration, registered fluorescence volumes, regional intensities and native detection overlays are available.']);
            otherwise,error('Unknown histology stage: %s',stage);
        end
end
end

function report=inspectFit(folder)
% Expected validation failures are data for the review UI, not callback errors.
report=struct('passed',false,'message','','identifier','','validation',[]);
try
    report.validation=validateFit(folder,false);report.passed=true;
    r=report.validation.roundTrip;
    report.message=sprintf('Numerical check passed: max %.3g mm; p95 %.3g mm. Now inspect anatomical alignment in all three planes.',r.maxMm,r.p95Mm);
    report.landmarks=fusiLightSuiteLandmarkResiduals(readSession(folder));
    report.message=sprintf('%s\n%s',report.message,report.landmarks.message);
catch ME
    report.passed=false;report.message=ME.message;report.identifier=ME.identifier;
end
end

function session=repairInverse(folder,progressFcn)
if nargin<2,progressFcn=[];end
session=readSession(folder);guard=fusiLightSuitePaths(session.config); %#ok<NASGU>
progressGuard=fusiLightSuiteFitProgress('begin',progressFcn,session); %#ok<NASGU>
fusiLightSuiteFitProgress('stage','Rebuilding inverse; keeping the saved fit until checks pass');
session.numericValidation=validateFit(session,true);
session.registrationComplete=true;session.fitReviewed=false;
session.inverseRebuilt=datestr(now,30);
if isfield(session,'reviewed'),session=rmfield(session,'reviewed');end
saveSession(session);
fusiLightSuiteFitProgress('update',1,'Inverse passed. Review the anatomy before accepting.');
end

function result=validateFit(folder,allowRetry,inverseOverride)
% A successful process exit does not guarantee a usable inverse. The pinned
% upstream inverse optimizer can diverge while still writing a result file.
if nargin<2,allowRetry=false;end
s=readSession(folder);guard=fusiLightSuitePaths(s.config); %#ok<NASGU>
tr=load(fullfile(s.opts.savepath,'transform_params.mat'));
forward=fullfile(s.opts.savepath,'bspline_atlas_to_samp_20um.txt');
inverse=tr.tform_bspline_samp20um_to_atlas_20um_px;
if nargin>2&&~isempty(inverseOverride),inverse=inverseOverride;end
affine=tr.tform_affine_samp20um_to_atlas_10um_px;
if isprop(affine,'A'),matrix=double(affine.A);else,matrix=double(affine.T);end
assert(all(isfinite(matrix(:)))&&det(matrix(1:3,1:3))>0, ...
    'deConfUSIon:LightSuiteAffineInvalid','The affine transform is nonfinite, singular or reflects the confirmed anatomy. Review geometry and landmarks.');
limit=max(5,norm(double(s.inputSize(1:3)).*double(s.opts.sample_res)));
[okForward,forwardMax]=checkField(forward,limit);
assert(okForward,'deConfUSIon:LightSuiteForwardInvalid','The forward deformation is nonfinite or implausibly large. Do not accept this fit; review geometry and landmarks.');
[okInverse,inverseMax]=checkField(inverse,limit);retried=false;
roundTrip=struct('passed',false,'maxMm',Inf,'p95Mm',Inf,'rmsMm',Inf,'nPoints',0);
if okInverse,roundTrip=checkRoundTrip(forward,inverse,s);end
if (~okInverse||~roundTrip.passed)&&allowRetry
    fprintf('LightSuite inverse failed checks; building and validating a separate inverse candidate.\n');
    candidate=fusiLightSuiteBuildInverse(forward,tempname(s.opts.savepath));
    validated=validateFit(s,false,candidate);
    if isfile(inverse),copyfile(inverse,[tempname(s.opts.savepath) '_previous_inverse.txt']);end
    copyfile(candidate,inverse,'f');retried=true;
    inverseMax=validated.inverseMaxDisplacementMm;roundTrip=validated.roundTrip;okInverse=true;
end
assert(okInverse,'deConfUSIon:LightSuiteInverseInvalid', ...
    ['The inverse deformation is nonfinite or implausibly large. The fit is not usable for mapping. ' ...
    'Review geometry and landmarks or use the established deConfUSIon registration route.']);
assert(roundTrip.passed,'deConfUSIon:LightSuiteRoundTrip', ...
    'Forward/inverse consistency failed: max %.3g mm, 95th percentile %.3g mm. Required max <= %.3g mm and p95 <= %.3g mm. Do not accept or map with this fit.', ...
    roundTrip.maxMm,roundTrip.p95Mm,2*max(s.opts.atlas_res),max(s.opts.atlas_res));
result=struct('finite',true,'forwardMaxDisplacementMm',forwardMax, ...
    'inverseMaxDisplacementMm',inverseMax,'maximumAllowedMm',limit,'stableInverseRetry',retried, ...
    'roundTrip',roundTrip, ...
    'scope','Numerical field validity only; not anatomical registration accuracy');
end

function result=checkRoundTrip(forward,inverse,s)
p=elastix_parameter_read(forward);dims=double(p.Size(:)');
[x,y,z]=ndgrid(linspace(.1*(dims(1)-1),.9*(dims(1)-1),5), ...
    linspace(.1*(dims(2)-1),.9*(dims(2)-1),5),linspace(.1*(dims(3)-1),.9*(dims(3)-1),5));
direction=reshape(double(p.Direction),3,3)';
points=([x(:) y(:) z(:)].*double(p.Spacing(:)'))*direction'+double(p.Origin(:)');
cpfile=fullfile(s.opts.savepath,'control_points_minimal.mat');
if isfile(cpfile)
    c=load(cpfile,'sample_points');a=cat(1,c.sample_points{:});
    if ~isempty(a)
        spacing=s.opts.sample_res(abs(s.opts.permute_sample_to_atlas));
        native=(a(:,[2 1 3])-1).*spacing([2 1 3]);points=[points;native]; %#ok<AGROW>
    end
end
f=mapPoints(points,forward);back=mapPoints(f,inverse);
g=mapPoints(points,inverse);again=mapPoints(g,forward);
errors=[vecnorm(back-points,2,2);vecnorm(again-points,2,2)];
result=struct('passed',false,'maxMm',Inf,'p95Mm',Inf,'rmsMm',Inf,'nPoints',numel(errors));
if any(~isfinite(errors)),return;end
result.maxMm=max(errors);result.p95Mm=quantile(errors,.95);result.rmsMm=sqrt(mean(errors.^2));
result.passed=result.maxMm<=2*max(s.opts.atlas_res)&&result.p95Mm<=max(s.opts.atlas_res);
end

function output=mapPoints(points,file)
output=transformix(points,file,'pointtype','point','verbose',false);
if isstruct(output)&&isfield(output,'OutputPoint'),output=output.OutputPoint;end
assert(isequal(size(output),size(points)),'Transformix did not return all validation points.');
end

function [ok,maxValue]=checkField(file,limit)
ok=false;maxValue=Inf;
if ~isfile(file),return;end
p=elastix_parameter_read(file);
if ~isfield(p,'TransformParameters')||any(~isfinite(p.TransformParameters))||any(abs(p.TransformParameters)>1e6),return;end
D=transformix([],file,'verbose',false);
if isempty(D)||any(~isfinite(D(:))),return;end
maxValue=max(abs(D(:)));ok=maxValue<=limit;
end

function tf=isAbsolutePath(p)
p=char(p);tf=~isempty(regexp(p,'^[A-Za-z]:[\\/]|^\\\\|^/','once'));
end

function correctHistologyHemispheres(folder)
% Official CCF2020 PIR: first ML half is left, second is right. The pinned
% upstream intensity exporter labels these halves in the opposite order.
files=dir(fullfile(folder,'volume_registered','chan*_intensities.csv'));
for k=1:numel(files)
    csv=fullfile(files(k).folder,files(k).name);T=readtable(csv,'Delimiter',';','VariableNamingRule','preserve');
    old=T.Properties.VariableNames;names=old;
    names(strcmp(old,'RightSideIntensity'))={'LeftSideIntensity'};
    names(strcmp(old,'LeftSideIntensity'))={'RightSideIntensity'};
    names(strcmp(old,'RightSideVolume[mm3]'))={'LeftSideVolume[mm3]'};
    names(strcmp(old,'LeftSideVolume[mm3]'))={'RightSideVolume[mm3]'};
    T.Properties.VariableNames=names;writetable(T,csv,'Delimiter',';');
    [~,stem]=fileparts(csv);mat=fullfile(files(k).folder,[stem '.mat']);
    if isfile(mat)
        hemisphereOrder={'Left','Right'}; %#ok<NASGU>
        hemisphereConvention='Official CCF2020 PIR, ML increases from anatomical left to right'; %#ok<NASGU>
        save(mat,'hemisphereOrder','hemisphereConvention','-append');
    end
end
end

function traceImplant(folder,kind,varargin)
% The upstream tracing GUI requires a whole-brain registration chain, not
% fUSI or serial-slice regopts. Reject incompatible files before it opens.
cfg=fusiLightSuiteConfig();guard=fusiLightSuitePaths(cfg);
assert(isfile(fullfile(folder,'regopts.mat'))&&isfile(fullfile(folder,'transform_params.mat')),'Choose an existing registered LightSuite whole-brain histology folder.');
q=load(fullfile(folder,'regopts.mat'));tr=load(fullfile(folder,'transform_params.mat'));
assert(isfield(q,'opts')&&isstruct(q.opts)&&isfield(q.opts,'regvolpath')&&isfield(q.opts,'registres'), ...
    'deConfUSIon:LightSuiteTracingSchema', ['This is not a compatible whole-brain LightSuite project. fUSI and serial-section transforms have a different coordinate chain. ' ...
    'Register a visible implant histology volume with LightSuite whole-brain registration first.']);
assert(q.opts.registres==20&&isfield(tr,'how_to_perm'),'Implant tracing requires the supported 20 um whole-brain registration grid.');
before=findall(groot,'Type','figure');
switch lower(kind)
    case 'fiber',annotateGRINLens(folder,varargin{:});
    case 'probe',annotateNeuropixelsProbes(folder,varargin{:});
    otherwise,error('Choose fiber or probe.');
end
attachGuard(guard,before);
end
