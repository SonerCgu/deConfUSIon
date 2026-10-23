function tests=testLightSuiteDisplayControls
tests=functiontests(localfunctions);
end
function setupOnce(~)
addpath(fileparts(fileparts(mfilename('fullpath'))));deConfUSIon_setup();
end

function testParentUnassignedLabelsKeepIdentityAndFullDescription(testCase)
info=struct('name',{{'Pallidum, unassigned','Thalamus, unassigned','Globus pallidus, external segment','Background'}}, ...
    'acr',{{'PAL-unassigned','TH_unassigned','GPe','unassigned'}});
[catalog,excluded]=fusiAtlasRegionCatalog(uint16([1 2 3 4]),info);
verifyEqual(testCase,[catalog.id],[3 1 2]);
verifyEqual(testCase,{catalog.acronym},{'GPe','PAL','TH'});
verifyEqual(testCase,catalog(2).name,'Pallidum, unassigned');
verifyEqual(testCase,excluded,4);
verifyEqual(testCase,fusiAtlasDisplayAcronym('unassigned'),'unassigned');
verifyEqual(testCase,info.acr{1},'PAL-unassigned');
end

function testEditedUnderlayUsesNativePixelsAndOnlyBrainMask(testCase)
[s,folder]=fixture();cleanup=onCleanup(@()removeFixture(folder)); %#ok<NASGU>
processed=reshape(single(linspace(0,1,120)),[4 6 5]);brainMask=true(size(processed));brainMask(1,:,:)=false;
maskBundle=struct('sliceUnderlayProcessed',processed,'brainMask',brainMask, ...
    'overlayMask',false(size(processed)),'maskEditorInfo',struct('hasBrainMask',true,'hasOverlayMask',true,'flipUD_display',true)); %#ok<NASGU>
file=fullfile(folder,'edited.mat');save(file,'maskBundle');
[actual,meta]=fusiLightSuiteLandmarkUnderlay(s,file);expected=processed;expected(~brainMask)=0;
verifyEqual(testCase,actual,expected);verifyTrue(testCase,meta.processed);
verifyEqual(testCase,s.opts.sample,ones(4,6,5,'single'));
bad=maskBundle;bad.sliceUnderlayProcessed=processed(:,:,1);bad.brainMask=[];maskBundle=bad;save(file,'maskBundle');
verifyError(testCase,@()fusiLightSuiteLandmarkUnderlay(s,file),'deConfUSIon:LightSuiteLandmarkUnderlayGrid');
end

function testVisualizationFolderBelongsToRecordingAndRevision(testCase)
[s,folder]=fixture();cleanup=onCleanup(@()removeFixture(folder)); %#ok<NASGU>
vis=fullfile(folder,'Visualization');mkdir(vis);
s.inputMetadata=struct('visualizationPath',vis);verifyEqual(testCase,fusiLightSuiteVisualizationFolder(s),vis);
s.inputMetadata=struct();s.opts.savepath=fullfile(folder,'Registration','LightSuite','Registration_20261023_120000');mkdir(s.opts.savepath);
verifyEqual(testCase,fusiLightSuiteVisualizationFolder(s),vis);
end

function testLandmarkEditorImportsAndRestoresEditedNativeUnderlay(testCase)
assumeTrue(testCase,usejava('awt'));
[s,folder]=fixture();cleanup=onCleanup(@()removeFixture(folder)); %#ok<NASGU>
s.opts.permute_sample_to_atlas=[-3 1 -2];
sliceUnderlayProcessed=reshape(single(linspace(0,1,120)),[4 6 5]); %#ok<NASGU>
maskEditorInfo=struct('hasBrainMask',false,'hasOverlayMask',false,'flipUD_display',true); %#ok<NASGU>
file=fullfile(folder,'edited.mat');save(file,'sliceUnderlayProcessed','maskEditorInfo');
f=fusiLightSuiteLandmarks(s);windowCleanup=onCleanup(@()delete(f)); %#ok<NASGU>
setappdata(f,'LightSuiteLandmarkUnderlayRequest',file);button=findall(f,'Tag','LightSuiteLandmarkLoadUnderlay');button.Callback(button,[]);
verifyFalse(testCase,isappdata(f,'LightSuiteLastError'));
contrast=findall(f,'Tag','LightSuiteLandmarkContrast');verifyEqual(testCase,contrast.Value,4);
[actual,meta]=fusiLightSuiteLandmarkUnderlay(s);verifyEqual(testCase,actual,sliceUnderlayProcessed);verifyEqual(testCase,meta.sourceFile,file);
V=permute(sliceUnderlayProcessed,[3 1 2]);V=flip(flip(V,1),3);
image=findall(f,'Type','image');sampleAxes=[];
for k=1:numel(image)
    if isequal(size(image(k).CData),[4 6]),sampleAxes=image(k);break;end
end
verifyNotEmpty(testCase,sampleAxes);verifyEqual(testCase,sampleAxes.CData,squeeze(V(round(size(V,1)/2),:,:)));
clear windowCleanup;
f=fusiLightSuiteLandmarks(s);windowCleanup=onCleanup(@()delete(f)); %#ok<NASGU>
contrast=findall(f,'Tag','LightSuiteLandmarkContrast');verifyEqual(testCase,contrast.Value,4);
end

function [s,folder]=fixture()
folder=tempname;mkdir(folder);
s=struct('orientationConfirmed',true,'inputSize',[4 6 5 10], ...
    'config',fusiLightSuiteConfig(struct('outputFolder',folder)), ...
    'opts',struct('sample',ones(4,6,5,'single'),'sample_res',[.1 .15 .15], ...
    'atlas',reshape(single(1:720),[8 10 9]),'atlas_res',[.05 .05 .05], ...
    'permute_sample_to_atlas',[3 1 2],'savepath',folder));
end

function testMappedReviewHasIndependentAtlasAndAnatomyContrast(testCase)
assumeTrue(testCase,usejava('awt'));
[s,folder]=fixture();cleanup=onCleanup(@()removeFixture(folder)); %#ok<NASGU>
result=struct('vreg',flip(s.opts.atlas,2));
f=fusiLightSuiteAnatomyReview(s,result);windowCleanup=onCleanup(@()delete(f)); %#ok<NASGU>
images=findall(f,'Type','image');initial=get(images,'CData');
atlas=findall(f,'Tag','LightSuiteMappedAtlasContrast');atlas.Value=2;atlas.Callback(atlas,[]);
withAtlas=get(images,'CData');verifyTrue(testCase,any(cellfun(@(a,b)~isequal(a,b),initial,withAtlas)));
anatomy=findall(f,'Tag','LightSuiteMappedAnatomyContrast');anatomy.Value=.5;anatomy.Callback(anatomy,[]);
withAnatomy=get(images,'CData');verifyTrue(testCase,any(cellfun(@(a,b)~isequal(a,b),withAtlas,withAnatomy)));
verifyEqual(testCase,result.vreg,flip(s.opts.atlas,2));
end
function removeFixture(folder)
resolved=char(java.io.File(folder).getCanonicalPath());temporary=char(java.io.File(tempdir).getCanonicalPath());
assert(startsWith([resolved filesep],[temporary filesep])&&~strcmp(resolved,temporary));
if isfolder(resolved),rmdir(resolved,'s');end
end
