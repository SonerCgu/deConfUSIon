function tests=testAtlasPicker
tests=functiontests(localfunctions);
end
function setupOnce(test)
deConfUSIon_setup();test.TestData.folder=tempname;mkdir(test.TestData.folder);
rawFolder=fullfile(test.TestData.folder,'RawData','animal');mkdir(rawFolder);raw=fullfile(rawFolder,'animal_scan1.mat');
I=ones(4,6,10,'single');save(raw,'I');
root=fullfile(test.TestData.folder,'AnalysedData','animal','animal_scan1');mkdir(root);
atlasFolder=fullfile(root,'Registration2D');mkdir(atlasFolder);atlasUnderlay=ones(8,12);atlasMode='histology'; %#ok<NASGU>
histology=fullfile(atlasFolder,'AtlasUnderlay_histology_slice008.mat');save(histology,'atlasUnderlay','atlasMode');
maskFolder=fullfile(root,'Masks');mkdir(maskFolder);mask=true(4,6);maskFile=fullfile(maskFolder,'mask.mat');save(maskFile,'mask');
test.TestData.raw=raw;test.TestData.root=root;test.TestData.atlas=atlasFolder;test.TestData.histology=histology;test.TestData.mask=maskFile;
end
function teardownOnce(test),rmdir(test.TestData.folder,'s');end
function testRawCallerStartsAtMatchingAnimalAtlas(test)
par=struct('loadedFile',test.TestData.raw,'underlayStartPath',fileparts(test.TestData.mask));
options=fusiUnderlayPickerOptions(par,fileparts(test.TestData.raw),'',test.TestData.mask);
verifyEqual(test,options.startPath,test.TestData.atlas);verifyEqual(test,options.defaultFile,fullfile(test.TestData.atlas,'*.mat'));
end
function testFileChoiceStartsInAtlasFolder(test)
dialogs=struct('kind',@()'Single file','file',@pick);
[selected,options]=fusiChooseAtlasSource(struct(),test.TestData.root,'',test.TestData.mask,dialogs);
verifyEqual(test,selected,test.TestData.histology);verifyEqual(test,options.sourceKind,'Single file');
 function [name,folder]=pick(filter,title,start)
  verifyTrue(test,contains(title,'Load atlas'));verifyNotEmpty(test,filter);verifyEqual(test,start,fullfile(test.TestData.atlas,'*.mat'));
  [folder,name,ext]=fileparts(test.TestData.histology);name=[name ext];
 end
end
function testFolderChoiceStartsInAtlasFolder(test)
dialogs=struct('kind',@()'Folder','folder',@pick);
[selected,options]=fusiChooseAtlasSource(struct(),test.TestData.root,'','',dialogs);
verifyEqual(test,selected,test.TestData.atlas);verifyEqual(test,options.sourceKind,'Folder');
 function selected=pick(start,title)
  verifyEqual(test,start,test.TestData.atlas);verifyTrue(test,contains(title,'atlas/session'));selected=test.TestData.atlas;
 end
end
function testCancelDoesNotLoadAnotherFolder(test)
dialogs=struct('kind',@()'Cancel');[selected,~]=fusiChooseAtlasSource(struct(),test.TestData.root,'','',dialogs);verifyEmpty(test,selected);
end
function testDated3DBundleStartsAtActualUnderlays(test)
root=tempname(test.TestData.folder);mkdir(root);bundle=fullfile(root,'Registration','AtlasRegistration_2026-10-12','AtlasUnderlays3D','20261012_010000');mkdir(bundle);
atlasMode='histology';atlasUnderlay=ones(8,12,4);save(fullfile(bundle,'Histology.mat'),'atlasMode','atlasUnderlay');
options=fusiUnderlayPickerOptions(struct(),root,'','');verifyEqual(test,options.startPath,bundle);
end
