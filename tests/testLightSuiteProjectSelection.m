function tests=testLightSuiteProjectSelection
tests=functiontests(localfunctions);
end
function setupOnce(t)
addpath(fileparts(fileparts(mfilename('fullpath'))));deConfUSIon_setup();
folder=tempname;mkdir(folder);root=fullfile(folder,'LightSuite');mkdir(root);
revision=fullfile(root,'Registration_20261023_145523_119');mkdir(revision);
pending=fullfile(root,'Registration_20261023_160000_000');mkdir(pending);
for path={root,revision}
 marker=1;save(fullfile(path{1},'LightSuite_Native_Regions.mat'),'marker');
 save(fullfile(path{1},'transform_params.mat'),'marker');
 sample_points={ones(6,3)};if strcmp(path{1},revision),sample_points={ones(43,3)};end %#ok<NASGU>
 save(fullfile(path{1},'control_points_minimal.mat'),'sample_points');
end
old=java.io.File(fullfile(root,'transform_params.mat'));old.setLastModified(int64(java.lang.System.currentTimeMillis()-86400000));
t.TestData=struct('folder',folder,'root',root,'revision',revision,'pending',pending);
end
function teardownOnce(t)
folder=char(java.io.File(t.TestData.folder).getCanonicalPath());temporary=char(java.io.File(tempdir).getCanonicalPath());
assert(startsWith([folder filesep],[temporary filesep])&&~strcmp(folder,temporary));rmdir(folder,'s');
end
function testParentOffersOriginalAndExportedRevision(t)
actual=fusiLightSuiteChooseAtlasProject(t.TestData.root,@chooseRevision);
verifyEqual(t,actual,t.TestData.revision);
 function [index,ok]=chooseRevision(varargin)
  q=struct();for k=1:2:numel(varargin),q.(varargin{k})=varargin{k+1};end
  verifyEqual(t,numel(q.ListString),2);
  verifyTrue(t,contains(q.ListString{1},'6 landmarks'));verifyTrue(t,contains(q.ListString{2},'43 landmarks'));
  verifyEqual(t,q.InitialValue,2);index=2;ok=true;
 end
end
function testCancelDoesNotFallBackToOldFit(t)
actual=fusiLightSuiteChooseAtlasProject(t.TestData.root,@(varargin)deal([],false));verifyEmpty(t,actual);
end
function testExactRevisionHasNoAdditionalPrompt(t)
actual=fusiLightSuiteChooseAtlasProject(t.TestData.revision,@unexpected);
verifyEqual(t,actual,t.TestData.revision);
end
function testSCMFolderPickerRoutesToChosenRevision(t)
d=struct('kind',@()'LightSuite folder','folder',@(varargin)t.TestData.root, ...
 'project',@(varargin)deal(2,true),'error',@unexpected);
[file,options]=fusiChooseAtlasSource(struct('exportPath',t.TestData.folder),t.TestData.folder,'','',d);
verifyEqual(t,file,fullfile(t.TestData.revision,'LightSuite_Native_Regions.mat'));
verifyEqual(t,options.startPath,t.TestData.revision);
d.project=@(varargin)deal([],false);
file=fusiChooseAtlasSource(struct('exportPath',t.TestData.folder),t.TestData.folder,'','',d);verifyEmpty(t,file);
end
function varargout=unexpected(varargin)
error('A single explicitly selected project must not open another dialog.');
end
