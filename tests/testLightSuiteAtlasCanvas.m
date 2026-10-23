function tests=testLightSuiteAtlasCanvas
% Optional LightSuite dependencies and Transformix are required for these tests.
tests=functiontests(localfunctions);
end

function setupOnce(testCase)
addpath(fileparts(fileparts(mfilename('fullpath'))));deConfUSIon_setup();
cfg=fusiLightSuiteConfig();
assumeTrue(testCase,isfile(fullfile(cfg.elastixBin,'transformix.exe'))&&isfolder(cfg.lightSuite));
folder=tempname;mkdir(folder);cfg.outputFolder=folder;guard=fusiLightSuitePaths(cfg); %#ok<NASGU>
shape=[12 16 8];p=[3 1 2];voxel=[.1 .15 .1];
prepared=size(imresize3(ones(shape(abs(p)),'single'),'Scale',voxel(abs(p))/.05));atlasSize=[24 40 52];
[y,x,z]=ndgrid(1:atlasSize(1),1:atlasSize(2),1:atlasSize(3));atlas=single(20+2*y+5*x+3*z);
theta=22*pi/180;M=eye(4);M(1:3,1:3)=[cos(theta) 0 sin(theta);0 1 0;-sin(theta) 0 cos(theta)];
M(4,1:3)=(atlasSize([2 1 3])+1)/2-(prepared([2 1 3])+1)/2*M(1:3,1:3);
tform_affine_samp20um_to_atlas_10um_px=affine3d(M); %#ok<NASGU>
save(fullfile(folder,'transform_params.mat'),'tform_affine_samp20um_to_atlas_10um_px');
% A spatially varying cubic B-spline, not an identity deformation fixture.
[gx,gy,gz]=ndgrid(1:5,1:5,1:5);coefficients=[.03*sin(gx(:)+gz(:));.02*cos(gy(:));.04*sin(gz(:)+gy(:))];
params=struct('Transform','BSplineTransform','NumberOfParameters',numel(coefficients),'TransformParameters',coefficients', ...
    'InitialTransformParametersFileName','NoInitialTransform','HowToCombineTransforms','Compose', ...
    'FixedImageDimension',3,'MovingImageDimension',3,'Size',prepared([2 1 3]),'Index',[0 0 0], ...
    'Spacing',[.05 .05 .05],'Origin',[0 0 0],'Direction',reshape(eye(3),1,9),'UseDirectionCosines',true, ...
    'BSplineTransformSplineOrder',3,'GridDirection',reshape(eye(3),1,9),'GridIndex',[0 0 0], ...
    'GridOrigin',[-1.625 -1.625 -1.625],'GridSize',[5 5 5],'GridSpacing',[1.6 1.6 1.6], ...
    'ResampleInterpolator','FinalBSplineInterpolator','FinalBSplineInterpolationOrder',1, ...
    'Resampler','DefaultResampler','DefaultPixelValue',0,'ResultImageFormat','mhd','ResultImagePixelType','float');
elastix_paramStruct2txt(fullfile(folder,'bspline_atlas_to_samp_20um.txt'),params);
s=struct('config',cfg,'inputSize',shape,'opts',struct('sample',ones(shape,'single'),'sample_res',voxel, ...
    'atlas',atlas,'atlas_res',[.05 .05 .05],'permute_sample_to_atlas',p,'savepath',folder));
s.opts.annotation=ones(atlasSize,'uint16');
s.opts.parcelinfo=table(1,{'structure'},{'test-region'},{'TST'},{'Test region'},255,0,0, ...
    'VariableNames',{'parcellation_index','parcellation_term_set_name','parcellation_term_label', ...
    'parcellation_term_acronym','parcellation_term_name','red','green','blue'});
testCase.TestData.session=s;testCase.TestData.folder=folder;
end

function testReviewUsesFullReferenceWithoutIntermediateCropping(testCase)
s=testCase.TestData.session;guard=fusiLightSuitePaths(s.config); %#ok<NASGU>
v=fusiLightSuiteReviewVolumes(s);
atlas=s.opts.atlas;atlas=max(0,atlas-imgaussfilt3(atlas,4*round(.3./s.opts.atlas_res)+1));
p=s.opts.permute_sample_to_atlas;
ratio=s.opts.sample_res(abs(p))./s.opts.atlas_res;
prepared=imresize3(permuteBrainVolume(s.opts.sample,p),'Scale',ratio);
query=cell(1,3);
for axis=1:3
    coordinates=.5+((1:size(prepared,axis))-.5)/ratio(axis);
    if p(axis)<0,coordinates=fliplr(s.inputSize(abs(p(axis)))+1-coordinates);end
    query{abs(p(axis))}=coordinates;
end
sampler=fusiLightSuiteAtlasSampling(s,[],false,query);
verifyEqual(testCase,v.sample,prepared);
verifyEqual(testCase,v.spacingMm,s.opts.atlas_res);
for stage=1:2
    stages={'affine','affine_bspline'};
    expected=sampler.sample(atlas,stages{stage},'linear',false);
    verifyEqual(testCase,v.atlas{stage},permuteBrainVolume(expected,p));
    % Labels at acquired edges must not be blanked by an affine crop before
    % the B-spline samples the full reference.
    expected=sampler.sample(s.opts.annotation,stages{stage},'nearest',false);
    verifyEqual(testCase,v.labels{stage},permuteBrainVolume(expected,p));
    verifyGreaterThan(testCase,nnz(expected([1 end],:,:)),0);
end
end

function teardownOnce(testCase)
if ~isfield(testCase.TestData,'folder'),return;end
folder=testCase.TestData.folder;
% Remove only this test's newly allocated temporary directory.
resolved=char(java.io.File(folder).getCanonicalPath());temporary=char(java.io.File(tempdir).getCanonicalPath());
assert(startsWith([resolved filesep],[temporary filesep])&&~strcmp(resolved,temporary));
if isfolder(resolved),rmdir(resolved,'s');end
end

function testFullCanvasContainsReferenceOutsideRecording(testCase)
s=testCase.TestData.session;sampler=fusiLightSuiteAtlasSampling(s);g=sampler.geometry;
[native,display]=sampler.sample(s.opts.atlas,'affine_bspline');
verifySize(testCase,native,s.inputSize);verifyLessThan(testCase,g.xData(1),1);
verifyGreaterThan(testCase,g.xData(2),s.inputSize(2));verifyLessThan(testCase,g.yData(1),1);
verifyGreaterThan(testCase,g.yData(2),s.inputSize(1));
[y,x]=ndgrid(linspace(g.yData(1),g.yData(2),size(display,1)),linspace(g.xData(1),g.xData(2),size(display,2)));
outside=y<1|y>s.inputSize(1)|x<1|x>s.inputSize(2);
verifyGreaterThan(testCase,nnz(display(:,:,4).*outside),100);
verifyFalse(testCase,any(reshape(display([1 end],:,:),[],1)));
verifyFalse(testCase,any(reshape(display(:,[1 end],:),[],1)));
end

function testNativeSamplingMatchesTransformixPointMode(testCase)
s=testCase.TestData.session;shape=s.inputSize;guard=fusiLightSuitePaths(s.config); %#ok<NASGU>
tr=load(fullfile(s.opts.savepath,'transform_params.mat'));
forward=fullfile(s.opts.savepath,'bspline_atlas_to_samp_20um.txt');original=fileread(forward);
permutations={[3 1 2],[-3 1 -2],[3 -1 -2],[3 1 2]};
for variant=1:numel(permutations)
    p=permutations{variant};s.opts.permute_sample_to_atlas=p;
    if variant==4,s.opts.sample_res=[.105 .147 .113];end
    sampler=fusiLightSuiteAtlasSampling(s);
    native=sampler.sample(s.opts.atlas,'affine_bspline','linear',false);
    [y,x,z]=ndgrid(3:3:shape(1)-2,3:4:shape(2)-2,2:2:shape(3)-1);raw=[y(:) x(:) z(:)];
    prepared=raw(:,abs(p));
    for a=1:3,if p(a)<0,prepared(:,a)=shape(abs(p(a)))+1-prepared(:,a);end,end
    prepared=.5+(prepared-.5).*s.opts.sample_res(abs(p))/.05;
    moved=transformix((prepared(:,[2 1 3])-1)*.05,forward,'pointtype','point','verbose',false);
    if isstruct(moved),moved=moved.OutputPoint;end
    q=transformPointsForward(tr.tform_affine_samp20um_to_atlas_10um_px,moved/.05+1);
    inside=all(q>=1&q<=size(s.opts.atlas,[2 1 3]),2);
    expected=20+2*q(inside,2)+5*q(inside,1)+3*q(inside,3);
    index=sub2ind(shape,raw(inside,1),raw(inside,2),raw(inside,3));
    verifyGreaterThan(testCase,numel(index),5);
    verifyEqual(testCase,double(native(index)),expected,'AbsTol',.01);
end
verifyEqual(testCase,fileread(forward),original);
end

function testAtlasLoadingPreservesNativeOrientation(testCase)
assumeTrue(testCase,usejava('awt'));
s=testCase.TestData.session;shape=s.inputSize;sampler=fusiLightSuiteAtlasSampling(s);
geometry=sampler.geometry;geometry.uprightVectorXY=-abs(geometry.uprightVectorXY);
folder=fullfile(testCase.TestData.folder,'portable');mkdir(folder);
info=struct('name',{{'Test region'}},'acr',{{'TST'}},'rgb',[1 0 0]);
for stage={'affine_bspline','affine'}
    files=fusiLightSuiteNativeFiles(folder,stage{1});
    [L,displayLabels]=sampler.sample(ones(size(s.opts.atlas),'single'),stage{1},'nearest');
    q=struct('kind','deConfUSIon_LightSuite_native_regions','nativeSize',shape, ...
        'voxelSizeMm',s.opts.sample_res,'fitReviewed',true,'arrayOrder','native', ...
        'transformFile',fullfile(s.opts.savepath,'transform_params.mat'),'exportSchema',3,'exportID','test', ...
        'registrationStage',stage{1},'registrationStageName',files.name);
    R=struct('atlasRegionLabels3D',uint16(L),'atlasInfoRegions',info, ...
        'leftHemisphereMask',L>0,'rightHemisphereMask',false(shape),'lightSuiteNativeMeta',q, ...
        'atlasDisplayRegionLabels3D',uint16(displayLabels),'lightSuiteDisplayGeometry',geometry);
    [native,display]=sampler.sample(s.opts.atlas,stage{1});
    B=struct('vascularImage',native,'vascularDisplayImage',display, ...
        'lightSuiteUnderlayMeta',q,'lightSuiteDisplayGeometry',geometry);
    brainImage=reshape(single(1:prod(shape)),shape);lightSuiteMaskMeta=q; %#ok<NASGU>
    save(files.mask,'brainImage','lightSuiteMaskMeta');
    save(files.regions,'-struct','R');save(files.backgrounds,'-struct','B');
end

PSC=ones([shape 31],'single');PSC(2:5,3:7,:,:)=30;
baseline=struct('mode','sec','start',0,'end',20,'sigStart',60,'sigEnd',200);
f=SCM_gui(PSC,ones(shape),10,struct(),baseline,31,'Native orientation regression');
cleanup=onCleanup(@()delete(f)); %#ok<NASGU>
loader=getappdata(f,'FUSILoadAtlas');loader(folder);reader=getappdata(f,'FUSIUnderlayData');
overlay=findall(f,'Tag','SCM_OverlayImage');ax=overlay.Parent;
upright=findall(f,'Tag','SCM_AtlasUpright');stages=findall(f,'Tag','AtlasRegistrationStage');background=findall(f,'Tag','AtlasUnderlayChoice');
verifyEqual(testCase,upright.Value,0);
nativeView=[.5 shape(2)+.5;.5 shape(1)+.5];verifyEqual(testCase,[ax.XLim;ax.YLim],nativeView);
fullReference=findall(f,'Tag','SCM_AtlasFullReference');verifyEqual(testCase,fullReference.Value,0);
field=findall(f,'Tag','SCM_RecordedField');verifyEqual(testCase,char(field.Visible),'off');
fullReference.Value=1;callback=fullReference.Callback;callback(fullReference,[]);
initialView=[ax.XLim;ax.YLim];verifyEqual(testCase,char(field.Visible),'on');
verifyGreaterThan(testCase,diff(initialView(1,:)),shape(2));
for si=[1 2 1]
    stages.Value=si;callback=stages.Callback;callback(stages,[]);
    for mode=1:2
        background.Value=mode;callback=background.Callback;callback(background,[]);
        actual=reader();verifyEqual(testCase,actual.PSC,PSC);
        verifyEqual(testCase,ax.View,[0 90]);verifyEqual(testCase,ax.XDir,'normal');
        verifyEqual(testCase,ax.YDir,'reverse');verifyEqual(testCase,ax.CameraUpVector,[0 -1 0]);
        verifyEqual(testCase,overlay.XData,[1 shape(2)]);verifyEqual(testCase,overlay.YData,[1 shape(1)]);
        verifyEqual(testCase,[ax.XLim;ax.YLim],initialView);
        physical=getappdata(f,'SCMROIPhysicalSize');
        verifyEqual(testCase,physical.spacingYXUm,s.opts.sample_res(1:2)*1000);
    end
    recorded=find(strcmp(background.String,'Recorded anatomy'),1);verifyNotEmpty(testCase,recorded);
    background.Value=recorded;callback=background.Callback;callback(background,[]);
    actual=reader();verifyEqual(testCase,actual.underlay,brainImage);verifyEqual(testCase,actual.PSC,PSC);
    verifyEqual(testCase,[ax.XLim;ax.YLim],initialView);
end
fullReference.Value=0;callback=fullReference.Callback;callback(fullReference,[]);
verifyEqual(testCase,[ax.XLim;ax.YLim],nativeView);verifyEqual(testCase,char(field.Visible),'off');
actual=reader();verifyEqual(testCase,actual.PSC,PSC);
upright.Value=1;callback=upright.Callback;callback(upright,[]);
verifyLessThan(testCase,ax.CameraUpVector(2),0);
loader(folder);verifyEqual(testCase,upright.Value,0);verifyEqual(testCase,ax.CameraUpVector,[0 -1 0]);
end

function testReviewWorksWithSignedSampleAxes(testCase)
s=testCase.TestData.session;s.opts.permute_sample_to_atlas=[-3 1 -2];
guard=fusiLightSuitePaths(s.config); %#ok<NASGU>
v=fusiLightSuiteReviewVolumes(s);p=s.opts.permute_sample_to_atlas;
expected=imresize3(permuteBrainVolume(s.opts.sample,p),'Scale',s.opts.sample_res(abs(p))./s.opts.atlas_res);
verifyEqual(testCase,v.sample,expected);verifyEqual(testCase,size(v.atlas{1}),size(expected));
verifyEqual(testCase,size(v.atlas{2}),size(expected));
end

function testFractionalReviewGridMatchesPhysicalPointsWithSignedAxes(testCase)
s=testCase.TestData.session;s.opts.permute_sample_to_atlas=[-3 1 -2];s.opts.sample_res=[.105 .147 .113];
guard=fusiLightSuitePaths(s.config); %#ok<NASGU>
shape=s.inputSize;query={linspace(.75,shape(1)+.25,18),linspace(.6,shape(2)+.4,24),linspace(.7,shape(3)+.3,12)};
sampler=fusiLightSuiteAtlasSampling(s,[],false,query);actual=sampler.sample(s.opts.atlas,'affine_bspline');
[iy,ix,iz]=ndgrid(3:4:16,3:5:22,2:3:11);
raw=[reshape(query{1}(iy),[],1) reshape(query{2}(ix),[],1) reshape(query{3}(iz),[],1)];
p=s.opts.permute_sample_to_atlas;prepared=raw(:,abs(p));
for axis=1:3,if p(axis)<0,prepared(:,axis)=shape(abs(p(axis)))+1-prepared(:,axis);end,end
prepared=.5+(prepared-.5).*s.opts.sample_res(abs(p))/.05;
moved=transformix((prepared(:,[2 1 3])-1)*.05,fullfile(s.opts.savepath,'bspline_atlas_to_samp_20um.txt'),'pointtype','point','verbose',false);
if isstruct(moved),moved=moved.OutputPoint;end
tr=load(fullfile(s.opts.savepath,'transform_params.mat'));q=transformPointsForward(tr.tform_affine_samp20um_to_atlas_10um_px,moved/.05+1);
inside=all(q>=1&q<=size(s.opts.atlas,[2 1 3]),2);verifyGreaterThan(testCase,nnz(inside),5);
expected=20+2*q(inside,2)+5*q(inside,1)+3*q(inside,3);
index=sub2ind(size(actual),iy(inside),ix(inside),iz(inside));
verifyEqual(testCase,double(actual(index)),expected,'AbsTol',.01);
end
