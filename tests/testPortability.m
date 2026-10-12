function tests=testPortability
tests=functiontests(localfunctions);
end
function setupOnce(test)
deConfUSIon_setup();
test.TestData.root=tempname;mkdir(test.TestData.root);
test.TestData.oldRoots=getpref('deConfUSIon','dataRoots',{});
test.TestData.hadRoots=ispref('deConfUSIon','dataRoots');
setpref('deConfUSIon','dataRoots',{}); % Fixtures must not compete with mounted user projects.
end
function teardownOnce(test)
if test.TestData.hadRoots,setpref('deConfUSIon','dataRoots',test.TestData.oldRoots);
elseif ispref('deConfUSIon','dataRoots'),rmpref('deConfUSIon','dataRoots');end
rmdir(test.TestData.root,'s');
end
function testDesktopArgumentsRemainLiteral(test)
folder=fullfile(test.TestData.root,'Mouse ü & $(literal)');
verifyEqual(test,fusiDesktopFolderCommand(folder,'mac'),{'/usr/bin/open',folder});
verifyEqual(test,fusiDesktopFolderCommand(folder,'win'),{'explorer.exe',folder});
verifyEqual(test,fusiDesktopFolderCommand(folder,'linux'),{'xdg-open',folder});
verifyError(test,@()fusiDesktopFolderCommand(folder,'unknown'),'deConfUSIon:Platform');
end
function testNativeMacBundleDiscovery(test)
bundle=fullfile(test.TestData.root,'ITK-SNAP.app');
binary=fullfile(bundle,'Contents','MacOS','ITK-SNAP');mkdir(fileparts(binary));
f=fopen(binary,'w');fclose(f);
old=getpref('deConfUSIon','itksnapExecutable','');had=ispref('deConfUSIon','itksnapExecutable');
guard=onCleanup(@()restorePref('itksnapExecutable',had,old)); %#ok<NASGU>
setpref('deConfUSIon','itksnapExecutable',bundle);
verifyEqual(test,fusiFindRegistrationExecutable('snap','mac'),binary);
end
function testWindowsSavedPathOnAnotherMount(test)
project=fullfile(test.TestData.root,'Project_MMP9');session='RGRO_261007_1024_MM_B6J_1362';
raw=fullfile(project,'RawData',session,[session '_scan9.mat']);mkdir(fileparts(raw));
f=fopen(raw,'w');fclose(f);
old=['__unmounted_volume__:/fUS/Project_MMP9/RawData/' session '_scan9.mat'];
verifyEqual(test,fusiFindMovedDataPath(old,{project}),raw);
fusiRememberDataRoot(raw);
verifyEqual(test,fusiFindMovedDataPath(old),raw);
verifyEqual(test,fusiFindMovedDataPath(strrep(raw,filesep,'\'),{}),raw);
wrong=fullfile(test.TestData.root,'OtherProject');mkdir(wrong);
verifyEqual(test,fusiFindMovedDataPath(old,{wrong}),old);
end
function testAmbiguousMountIsNotChosen(test)
roots=cell(1,2);
for k=1:2
    roots{k}=fullfile(test.TestData.root,sprintf('mount%d',k),'ProjectSame');
    folder=fullfile(roots{k},'RawData');mkdir(folder);
    f=fopen(fullfile(folder,'scan.mat'),'w');fclose(f);
end
old='__unmounted_volume__:/fUS/ProjectSame/RawData/scan.mat';
verifyEqual(test,fusiFindMovedDataPath(old,roots),old);
end
function testMetadataCalibrationHasNoDriveDependency(test)
g=fusiVolumeGeometry(struct('voxelSizeUm',[100 150 150]),[80 64 54],'');
verifyEqual(test,g.spacingUm,[100 150 150]);
verifyEqual(test,g.fieldOfViewMm,[8 9.6 8.1],'AbsTol',1e-10);
verifyFalse(test,isfield(g,'referenceSequence'));
end
function testMP4WriterAndReader(test)
assumeTrue(test,ispc||ismac,'MATLAB MPEG-4 encoding is supported on Windows and macOS.');
file=fullfile(test.TestData.root,'movie ü spaces.mp4');v=VideoWriter(file,'MPEG-4');v.FrameRate=5;open(v);
for k=1:5,writeVideo(v,repmat(uint8(20*k),48,64,3));end
close(v);reader=VideoReader(file);count=0;
while hasFrame(reader),readFrame(reader);count=count+1;end
verifyEqual(test,count,5);
end
function restorePref(name,had,old)
if had,setpref('deConfUSIon',name,old);elseif ispref('deConfUSIon',name),rmpref('deConfUSIon',name);end
end
