function tests=testVolumeLightSuite
tests=functiontests(localfunctions);
end
function setupOnce(testCase)
addpath(fileparts(fileparts(mfilename('fullpath'))));deConfUSIon_setup();cfg=fusiLightSuiteConfig();
assumeTrue(testCase,isfile(fullfile(cfg.elastixBin,'transformix.exe')));
folder=tempname;mkdir(folder);project=fullfile(folder,'Mouse_1413','Mouse_1413_scan3','Registration','LightSuite');mkdir(project);
cfg.outputFolder=project;guard=fusiLightSuitePaths(cfg); %#ok<NASGU>
shape=[8 10 6];voxel=[.1 .15 .15];p=[3 1 2];atlasSize=[28 30 40];
[a,b,c]=ndgrid(1:atlasSize(1),1:atlasSize(2),1:atlasSize(3));atlas=single(a+2*b+3*c);
opts=struct('sample',ones(shape,'single'),'sample_res',voxel,'permute_sample_to_atlas',p, ...
    'atlas',atlas,'histology',atlas,'annotation',ones(atlasSize,'uint16'),'atlas_res',[.05 .05 .05],'savepath',project);
session=struct('schema','deConfUSIon-LightSuite-v1','opts',opts,'config',cfg,'inputSize',shape, ...
    'fitReviewed',true,'registrationComplete',true,'orientationConfirmed',true,'inputMetadata',struct()); %#ok<NASGU>
save(fullfile(project,'deconfusion_lightsuite_session.mat'),'session');
M=eye(4);M(4,1:3)=[7 5 5];tform_affine_samp20um_to_atlas_10um_px=affine3d(M); %#ok<NASGU>
tform_bspline_samp20um_to_atlas_20um_px=fullfile(project,'bspline_samp_to_atlas_20um.txt'); %#ok<NASGU>
save(fullfile(project,'transform_params.mat'),'tform_affine_samp20um_to_atlas_10um_px','tform_bspline_samp20um_to_atlas_20um_px');
prepared=ceil(shape(abs(p)).*voxel(abs(p))/.05);
params=struct('Transform','TranslationTransform','NumberOfParameters',3,'TransformParameters',[.05 0 0], ...
    'InitialTransformParametersFileName','NoInitialTransform','HowToCombineTransforms','Compose', ...
    'FixedImageDimension',3,'MovingImageDimension',3,'Size',prepared([2 1 3]),'Index',[0 0 0], ...
    'Spacing',[.05 .05 .05],'Origin',[0 0 0],'Direction',reshape(eye(3),1,9),'UseDirectionCosines',true, ...
    'ResampleInterpolator','FinalBSplineInterpolator','FinalBSplineInterpolationOrder',1, ...
    'Resampler','DefaultResampler','DefaultPixelValue',0,'ResultImageFormat','mhd','ResultImagePixelType','float');
elastix_paramStruct2txt(fullfile(project,'bspline_atlas_to_samp_20um.txt'),params);
params.TransformParameters=[-.05 0 0];elastix_paramStruct2txt(tform_bspline_samp20um_to_atlas_20um_px,params);
[y,x,z]=ndgrid(1:shape(1),1:shape(2),1:shape(3));native=single(y+2*x+3*z);PSC=cat(4,native,native+10,native+20);
root=fileparts(fileparts(project));
data=struct('PSC',PSC,'I',PSC,'TR',1,'par',struct('voxelSizeUm',1000*voxel,'exportPath',root), ...
    'underlay',native,'label','Test mouse 1413 scan3','underlayLabel','Native anatomy','inputIsPSC',true, ...
    'transformed',false,'mask',[],'maskIsInclude',true,'applyMask',false,'interpol',1,'frame',1, ...
    'caxis',[0 80],'baseline',struct('start',0,'end',1,'mode','sec'),'volumeBackend','Surface rendering');
testCase.TestData=struct('folder',folder,'project',project,'session',session,'data',data,'M',M);
end
function teardownOnce(testCase)
if ~isfield(testCase.TestData,'folder'),return;end
folder=testCase.TestData.folder;resolved=char(java.io.File(folder).getCanonicalPath());temporary=char(java.io.File(tempdir).getCanonicalPath());
assert(startsWith([resolved filesep],[temporary filesep])&&~strcmp(resolved,temporary));rmdir(resolved,'s');
end
function testFolderAndTransformMATResolveTheSameSavedProject(testCase)
folder=testCase.TestData.project;
[matched,a]=fusiVolumeLightSuiteSelection(folder);verifyTrue(testCase,matched);
[matched,b]=fusiVolumeLightSuiteSelection(fullfile(folder,'transform_params.mat'));verifyTrue(testCase,matched);verifyEqual(testCase,a,b);
verifyEqual(testCase,a.registrationStage,'affine_bspline');
verifyFalse(testCase,fusiVolumeLightSuiteSelection(struct('M',eye(4))));
end
function testMappingPreservesFramesAndKeepsMissingCoverageMissing(testCase)
d=testCase.TestData.data;ctx=fusiVolumeAtlasContext(d,testCase.TestData.project,[],40);
S=snapshot(d,1);first=ctx.frameMapper(S,false);S.psc=d.PSC(:,:,:,2);second=ctx.frameMapper(S,true);
valid=isfinite(first.psc);verifyGreaterThan(testCase,nnz(valid),20);verifyGreaterThan(testCase,nnz(~valid),20);
verifyEqual(testCase,double(second.psc(valid)-first.psc(valid)),10*ones(nnz(valid),1),'AbsTol',1e-4);
verifyFalse(testCase,any(isfinite(first.psc(~ctx.coverageMask))));
verifyEqual(testCase,first.atlasProvenance.registrationStage,'affine_bspline');
verifyEqual(testCase,ctx.spacingYXZmm,[.05 .05 .05]);
selection=struct('kind','LightSuite','projectFolder',testCase.TestData.project,'registrationStage','affine');
affine=fusiVolumeAtlasContext(d,selection,[],40,ctx);other=affine.frameMapper(snapshot(d,1),false);
both=valid&isfinite(other.psc);verifyGreaterThan(testCase,nnz(both),20);
verifyGreaterThan(testCase,max(abs(other.psc(both)-first.psc(both))),.1);
end
function testInverseQueriesMatchIndependentPhysicalTransformixPoints(testCase)
s=testCase.TestData.session;guard=fusiLightSuitePaths(s.config); %#ok<NASGU>
mapper=fusiLightSuiteAtlasToNative(s);xyz=[10 9 10;15 15 20;20 10 24];
prepared=transformPointsInverse(affine3d(testCase.TestData.M),xyz);
moved=transformix((prepared-1)*.05,mapper.inverseFile,'pointtype','point','verbose',false);
if isstruct(moved),moved=moved.OutputPoint;end
p=s.opts.permute_sample_to_atlas;prepared=moved/.05+1;prepared=prepared(:,[2 1 3]);
prepared=.5+(prepared-.5)./(s.opts.sample_res(abs(p))/.05);expected=zeros(size(prepared));expected(:,abs(p))=prepared;
verifyEqual(testCase,mapper.query(xyz,'affine_bspline'),expected,'AbsTol',1e-5);
end
function testSlabsUseSavedWarpAndDoNotFillUnacquiredTissue(testCase)
d=testCase.TestData.data;ctx=fusiVolumeAtlasContext(d,testCase.TestData.project,[],40);
slabs=ctx.slabMapper(snapshot(d,1),[1 14 28],50,'Vascular');
verifyTrue(testCase,all(isnan(slabs.psc(:,:,1)),'all'));verifyGreaterThan(testCase,nnz(isfinite(slabs.psc(:,:,2))),10);
verifyEqual(testCase,slabs.sampleSpacingUm,50);verifySize(testCase,slabs.psc,[30 40 3]);
end
function testReuseLinksStayWithinAnimalAndSurviveReload(testCase)
d=testCase.TestData.data;[~,selection]=fusiVolumeLightSuiteSelection(testCase.TestData.project);
fusiVolumeAtlasLink('set',d.par,selection);verifyEqual(testCase,fusiVolumeAtlasLink('get',d.par),selection);
animal=fileparts(d.par.exportPath);other=struct('exportPath',fullfile(animal,'Mouse_1413_scan4'));mkdir(other.exportPath);
verifyEqual(testCase,fusiVolumeAtlasLink('get',other),selection);
different=struct('exportPath',fullfile(testCase.TestData.folder,'Mouse_1414','Mouse_1414_scan3'));mkdir(different.exportPath);
verifyEmpty(testCase,fusiVolumeAtlasLink('get',different));
fusiVolumeAtlasLink('clear',other);verifyEmpty(testCase,fusiVolumeAtlasLink('get',other));
end
function testDifferentNativeGridIsRejectedWithoutChangingFit(testCase)
d=testCase.TestData.data;d.PSC=d.PSC(1:end-1,:,:,:);
verifyError(testCase,@()fusiVolumeAtlasContext(d,testCase.TestData.project,[],40),'deConfUSIon:VolumeLightSuiteGrid');
end
function testLandmarkErrorsAreIndependentOfInverseConsistency(testCase)
s=testCase.TestData.session;project=s.opts.savepath;file=fullfile(project,'control_points_minimal.mat');
cleanup=onCleanup(@()delete(file)); %#ok<NASGU>
% A known 0.05 mm X translation followed by a saved affine translation.
sample_points={[1 1 1;6 8 10;3 4 5;2 6 8;5 3 7]};
a=sample_points{1};prepared=.5+(a-.5).*s.opts.sample_res(abs(s.opts.permute_sample_to_atlas))/.05;
atlas_points={prepared+[0 1 0]+testCase.TestData.M(4,[2 1 3])}; %#ok<NASGU>
save(file,'sample_points','atlas_points');r=fusiLightSuiteLandmarkResiduals(s);
verifyTrue(testCase,r.available);verifyLessThan(testCase,r.maxMm,1e-5);
atlas_points{1}(4,2)=atlas_points{1}(4,2)+20;save(file,'sample_points','atlas_points');
r=fusiLightSuiteLandmarkResiduals(s);verifyEqual(testCase,r.maxMm,1,'AbsTol',1e-5);
verifyEqual(testCase,r.worstPairIDs(1),4);verifyTrue(testCase,r.reviewSuggested);
verifyEqual(testCase,r.nPairs,5);
report=fusiLightSuite('inspectfit',s);verifyTrue(testCase,report.passed);
verifyEqual(testCase,report.landmarks.worstPairIDs(1),4);
verifyTrue(testCase,contains(report.message,'Landmarks: 5 pairs'));
end
function testStandardAffineRegistrationRemainsCompatible(testCase)
d=testCase.TestData.data;s=testCase.TestData.session;p=abs(s.opts.permute_sample_to_atlas);
atlas=struct('Histology',s.opts.atlas,'Vascular',s.opts.atlas,'Regions',s.opts.annotation,'VoxelSize',[50 50 50]);
g=struct('originalSize',s.inputSize,'originalSpacingUm',1000*s.opts.sample_res, ...
    'permutation',p,'atlasVoxelSizeUm',[50 50 50],'convention','coronal_stack_v2');
T=struct('M',testCase.TestData.M,'size',size(s.opts.atlas),'scanGeometry',g);
ctx=fusiVolumeAtlasContext(d,T,atlas,40);mapped=ctx.frameMapper(snapshot(d,1),false);
verifyGreaterThan(testCase,nnz(isfinite(mapped.psc)),20);verifyTrue(testCase,mapped.atlasProvenance.unsaved);
verifyEqual(testCase,ctx.spacingYXZmm,[.05 .05 .05]);
end
function testGUIAppliesSavedStagesAndExportCarriesProvenance(testCase)
assumeTrue(testCase,usejava('awt'));
d=testCase.TestData.data;f=fusiVolumeGUI(d);cleanup=onCleanup(@()delete(f)); %#ok<NASGU>
loader=getappdata(f,'FUSIVolumeLoadAtlas');loader(fullfile(testCase.TestData.project,'transform_params.mat'));
verifyFalse(testCase,isappdata(f,'FUSIVolumeAtlasLastError'));
state=getappdata(f,'FUSIVolumeExport');verifyEqual(testCase,state.metadata.atlasProvenance.kind,'LightSuite');
stage=findall(f,'Tag','VolumeAtlasStage');stage.Value='Affine only';stage.ValueChangedFcn(stage,[]);
verifyFalse(testCase,isappdata(f,'FUSIVolumeAtlasLastError'));
state=getappdata(f,'FUSIVolumeExport');verifyEqual(testCase,state.metadata.atlasProvenance.registrationStage,'affine');
verifyEqual(testCase,state.metadata.atlasProvenance.projectFolder,testCase.TestData.project);
resolution=findall(f,'Tag','VolumeMovieResolution');resolution.Value=resolution.Items{1};
png=fullfile(testCase.TestData.folder,'registered.png');fusiExportVolume(f,png);
saved=jsondecode(fileread([png '.json']));verifyEqual(testCase,saved.atlasProvenance.registrationStage,'affine');
movie=fullfile(testCase.TestData.folder,'registered.mp4');report=fusiExportVolume(f,movie,3,'timeseries');
verifyTrue(testCase,isfile(report.file));video=VideoReader(report.file);verifyGreaterThan(testCase,video.Duration,0);
saved=jsondecode(fileread(report.settingsFile));verifyEqual(testCase,saved.atlasProvenance.projectFolder,testCase.TestData.project);
verifyEqual(testCase,saved.movieOriginalFrames(:)',1:3);
setappdata(f,'FUSIVolumeRegistrationChoice','LightSuite');button=findall(f,'Tag','VolumeAdjustAtlas');button.ButtonPushedFcn(button,[]);
window=getappdata(f,'FUSIVolumeLightSuiteWindow');verifyTrue(testCase,isgraphics(window));delete(window);
end
function S=snapshot(d,frame)
shape=size(d.PSC,[1 2 3]);
S=struct('psc',d.PSC(:,:,:,frame),'underlay',d.underlay/50,'signal',d.underlay/50, ...
    'underlayValid',true(shape),'slices',[1 shape(3)],'spacing',[.1 .15 .15],'units','mm','note','');
end
function testExportReusesCurrentAtlasGridAndCamera(t)
assumeTrue(t,usejava('awt'));
root=fullfile(t.TestData.folder,'CurrentGridExport');mkdir(root);
project=fullfile(root,'Registration','LightSuite');copyfile(t.TestData.project,project);
session=t.TestData.session;session.opts.savepath=project;
session.opts.atlas=repmat(session.opts.atlas,6,1,1);
session.opts.histology=session.opts.atlas;session.opts.annotation=ones(size(session.opts.atlas),'uint16');
save(fullfile(project,'deconfusion_lightsuite_session.mat'),'session');
d=t.TestData.data;d.par.exportPath=root;
f=fusiVolumeGUI(d);cleanup=onCleanup(@()delete(f)); %#ok<NASGU>
loadAtlas=getappdata(f,'FUSIVolumeLoadAtlas');loadAtlas(project);
verifyFalse(t,isappdata(f,'FUSIVolumeAtlasLastError'));
preview=getappdata(f,'FUSIVolumeExport');verifyEqual(t,preview.metadata.atlasProvenance.displayStride,2);camera=preview.axes.CameraPosition;
verifyFalse(t,isappdata(f,'FUSIVolumePrepareExport'));
% Even an explicitly selected larger raster must not secretly rebuild the
% atlas at a different sampling or change the PSC transfer / camera.
resolution=findall(f,'Tag','VolumeMovieResolution');resolution.Value='Full HD (1920 px)';
movie=fullfile(root,'current_grid.mp4');fusiExportVolume(f,movie,2,'rotation');
metadata=jsondecode(fileread([movie '.json']));verifyEqual(t,metadata.atlasProvenance.displayStride,2);
video=VideoReader(movie);verifyEqual(t,max([video.Width video.Height]),1920,'AbsTol',2);
verifyEqual(t,metadata.movieEncodingQuality,100);
restored=getappdata(f,'FUSIVolumeExport');verifyEqual(t,restored.metadata.atlasProvenance.displayStride,2);
verifyEqual(t,restored.axes.CameraPosition,camera);verifyEqual(t,restored.metadata.settings,preview.metadata.settings);
verifyEqual(t,char(f.Visible),'on');verifyEmpty(t,findall(0,'Tag','VolumeAtlasLoadProgress'));
button=findall(f,'Tag','VolumeLoadMasks');verifyEqual(t,char(button.Enable),'on');
verifyFalse(t,isappdata(f,'FUSIVolumeExportBusy'));
end
