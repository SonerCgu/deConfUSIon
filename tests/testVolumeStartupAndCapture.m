function tests=testVolumeStartupAndCapture
tests=functiontests(localfunctions);
end
function setupOnce(t)
addpath(fileparts(fileparts(mfilename('fullpath'))));deConfUSIon_setup();
folder=tempname;mkdir(folder);shape=[20 24 16];
[y,x,z]=ndgrid(1:shape(1),1:shape(2),1:shape(3));
radius=((y-10)/8).^2+((x-12)/10).^2+((z-8)/6).^2;
u=single(radius<1).*(.45+.4*single(mod(x,4)==0));
focus=single(((y-10)/3).^2+((x-12)/4).^2+((z-8)/3).^2<1);
psc=cat(4,focus*8,focus*20,focus*28);
d=struct('PSC',psc,'I',repmat(u,1,1,1,3),'TR',1, ...
 'par',struct('voxelSizeUm',[100 150 150],'exportPath',folder), ...
 'underlay',u,'underlayProcessed',true,'underlayLabel','Saved test anatomy', ...
 'label','PSC export regression','inputIsPSC',true,'transformed',false, ...
 'mask',[],'maskIsInclude',true,'applyMask',false,'interpol',1,'frame',1, ...
 'caxis',[0 30],'baseline',struct('start',0,'end',1,'mode','sec'), ...
 'volumeBackend','Volume rendering');
t.TestData=struct('folder',folder,'data',d);
end
function teardownOnce(t)
folder=char(java.io.File(t.TestData.folder).getCanonicalPath());temporary=char(java.io.File(tempdir).getCanonicalPath());
assert(startsWith([folder filesep],[temporary filesep])&&~strcmp(folder,temporary));rmdir(folder,'s');
end
function testStartupIgnoresSavedLightSuiteLink(t)
assumeTrue(t,usejava('awt'));d=t.TestData.data;d.volumeBackend='Surface rendering';
selection=struct('kind','LightSuite','projectFolder',fullfile(t.TestData.folder,'unavailable_saved_project'), ...
 'registrationStage','affine_bspline');fusiVolumeAtlasLink('set',d.par,selection);
link=fullfile(d.par.exportPath,'Registration','3DModel_Atlas.json');before=fileread(link);
f=fusiVolumeGUI(d);cleanup=onCleanup(@()delete(f)); %#ok<NASGU>
verifyFalse(t,isappdata(f,'FUSIVolumeAtlasLastError'), ...
 'Opening 3D must not try the saved LightSuite project, even when that project is unavailable.');
verifyFalse(t,isappdata(f,'FUSIVolumeAtlasSelection'));
state=getappdata(f,'FUSIVolumeExport');verifyFalse(t,isfield(state.metadata,'atlasProvenance'));
verifyEqual(t,fileread(link),before);verifyEmpty(t,findall(0,'Tag','VolumeAtlasLoadProgress'));
button=findall(f,'Tag','VolumeLoadAtlas');verifyEqual(t,char(button.Enable),'on');
end
function testHDCaptureRetainsDarkBackgroundAnatomyAndPSC(t)
assumeTrue(t,usejava('awt')&&exist('viewer3d','file')==2&&exist('volshow','file')==2);
previous=get(groot,'DefaultFigureInvertHardcopy');set(groot,'DefaultFigureInvertHardcopy','on');
restoreDefault=onCleanup(@()set(groot,'DefaultFigureInvertHardcopy',previous)); %#ok<NASGU>
f=fusiVolumeGUI(t.TestData.data);cleanup=onCleanup(@()delete(f)); %#ok<NASGU>
resolution=findall(f,'Tag','VolumeMovieResolution');resolution.Value='Full HD (1920 px)';
state=getappdata(f,'FUSIVolumeExport');assertFalse(t,isempty(state.viewer));
canvas=fusiVolumeMovieCanvas(f,state,true);closeCanvas=onCleanup(canvas.close); %#ok<NASGU>
assertTrue(t,contains(canvas.method,'high-DPI'),'Exercise the print-based HD capture path.');
pixels=canvas.capture();verifyDarkFrame(t,pixels);
paper=canvas.capture(true);verifyDarkFrame(t,paper);
canvas.showFrame(pixels);drawnow;
preview=findall(canvas.previewFigure,'Tag','VolumeMoviePixelPreview');assertFalse(t,isempty(preview));
verifyDarkFrame(t,preview.CData);
verifyEqual(t,max(size(pixels,[1 2])),1920,'AbsTol',2);
verifyFalse(t,isempty(findall(canvas.figure,'Tag','MovieVoxelPlane')));
end
function testSavedPSCVideoRetainsAnatomyAndDarkBackground(t)
assumeTrue(t,usejava('awt')&&exist('viewer3d','file')==2&&exist('volshow','file')==2);
f=fusiVolumeGUI(t.TestData.data);cleanup=onCleanup(@()delete(f)); %#ok<NASGU>
resolution=findall(f,'Tag','VolumeMovieResolution');verifyEqual(t,resolution.Value,'HD (1080 px)');
verifyFalse(t,isappdata(f,'FUSIVolumePrepareExport'));
state=getappdata(f,'FUSIVolumeExport');assertFalse(t,isempty(state.viewer));
movie=fullfile(t.TestData.folder,'psc_default.mp4');report=fusiExportVolume(f,movie,3,'timeseries');
for file={report.file,report.paperFile}
 video=VideoReader(file{1});count=0;
 while hasFrame(video),pixels=readFrame(video);verifyDarkFrame(t,pixels);count=count+1;end
 verifyEqual(t,count,3);
end
metadata=jsondecode(fileread(report.settingsFile));verifyEqual(t,metadata.movieOriginalFrames(:)',1:3);
verifyEqual(t,max(metadata.movieOutputSizeYX),1080,'AbsTol',2);
after=getappdata(f,'FUSIVolumeExport');verifyEqual(t,after.metadata.settings,state.metadata.settings);
verifyEqual(t,after.viewer.CameraPosition,state.viewer.CameraPosition);
end
function verifyDarkFrame(t,pixels)
background=all(pixels<20,3);verifyGreaterThan(t,nnz(background)/numel(background),.25, ...
 'Export must preserve the black scene background instead of printing it white.');
grey=max(pixels,[],3)-min(pixels,[],3)<8 & max(pixels,[],3)>25 & max(pixels,[],3)<225;
verifyGreaterThan(t,nnz(grey),100,'The anatomical underlay must remain visible.');
red=double(pixels(:,:,1))>double(pixels(:,:,2))+20 & double(pixels(:,:,1))>double(pixels(:,:,3))+20;
verifyGreaterThan(t,nnz(red),100,'The PSC overlay must remain visible.');
end
