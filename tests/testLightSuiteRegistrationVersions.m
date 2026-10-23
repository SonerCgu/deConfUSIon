function tests=testLightSuiteRegistrationVersions
tests=functiontests(localfunctions);
end
function setupOnce(testCase)
addpath(fileparts(fileparts(mfilename('fullpath'))));deConfUSIon_setup();
folder=tempname;mkdir(folder);cfg=fusiLightSuiteConfig(struct('outputFolder',folder));
session=struct('schema','deConfUSIon-LightSuite-v1','workflow','fusi', ...
    'config',cfg,'opts',struct('savepath',folder,'sample',reshape(single(1:240),[6 8 5]), ...
    'sample_res',[.1 .15 .15],'permute_sample_to_atlas',[3 1 2]), ...
    'inputSize',[6 8 5 31],'inputMetadata',struct(),'orientationConfirmed',true, ...
    'fitReviewed',true,'registrationComplete',true,'inverseRebuilt',true,'created','old');
session.config.orientationConfirmed=true;session.landmarkValidation=struct('medianMm',1.5);
save(fullfile(folder,'deconfusion_lightsuite_session.mat'),'session');
pairs=struct('sample_points',[1 2 3;4 5 6],'atlas_points',[2 3 4;5 6 7]);
save(fullfile(folder,'control_points_minimal.mat'),'-struct','pairs');
displayImage=single(session.opts.sample/240);displayMeta=struct('processed',true,'sourceFile','edited.mat'); %#ok<NASGU>
save(fullfile(folder,'landmark_underlay.mat'),'displayImage','displayMeta');
sentinel='Old fit must survive';fid=fopen(fullfile(folder,'transform_params.mat'),'w');fwrite(fid,sentinel);fclose(fid);
testCase.TestData.folder=folder;testCase.TestData.session=session;
end
function teardownOnce(testCase)
folder=testCase.TestData.folder;resolved=char(java.io.File(folder).getCanonicalPath());temporary=char(java.io.File(tempdir).getCanonicalPath());
assert(startsWith([resolved filesep],[temporary filesep])&&~strcmp(resolved,temporary));rmdir(resolved,'s');
end
function testTimestampedChildrenPreserveFitAndGeometry(testCase)
folder=testCase.TestData.folder;original=testCase.TestData.session;
first=fusiLightSuite('revise',folder);second=fusiLightSuite('revise',folder);
verifyEqual(testCase,fileparts(first.opts.savepath),folder);verifyNotEqual(testCase,first.opts.savepath,second.opts.savepath);
verifyTrue(testCase,startsWith(string(first.opts.savepath),string(fullfile(folder,'Registration_'))));
verifyEqual(testCase,first.opts.sample,original.opts.sample);verifyEqual(testCase,first.opts.sample_res,original.opts.sample_res);
verifyFalse(testCase,first.fitReviewed);verifyFalse(testCase,first.registrationComplete);verifyFalse(testCase,isfield(first,'inverseRebuilt'));
verifyFalse(testCase,isfield(first,'landmarkValidation'));
verifyTrue(testCase,isfile(fullfile(first.opts.savepath,'control_points_minimal.mat')));
verifyFalse(testCase,isfile(fullfile(first.opts.savepath,'transform_params.mat')));
display=fusiLightSuiteLandmarkUnderlay(first);verifyEqual(testCase,display,single(original.opts.sample/240));
verifyEqual(testCase,fileread(fullfile(folder,'transform_params.mat')),'Old fit must survive');
S=load(fullfile(folder,'deconfusion_lightsuite_session.mat'));verifyEqual(testCase,S.session,original);
end
function testOrientationRevisionRequiresNewPairs(testCase)
folder=testCase.TestData.folder;revision=fusiLightSuite('revise',folder,[],'orientation');
verifyFalse(testCase,revision.orientationConfirmed);verifyFalse(testCase,revision.config.orientationConfirmed);
verifyFalse(testCase,isfile(fullfile(revision.opts.savepath,'control_points_minimal.mat')));
verifyTrue(testCase,isfile(fullfile(folder,'control_points_minimal.mat')));
revision=fusiLightSuite('orientation',revision,[-3 1 -2]);
verifyTrue(testCase,revision.orientationConfirmed);verifyEqual(testCase,revision.opts.permute_sample_to_atlas,[-3 1 -2]);
end
