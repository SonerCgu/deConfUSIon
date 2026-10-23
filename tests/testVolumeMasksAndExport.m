function tests=testVolumeMasksAndExport
tests=functiontests(localfunctions);
end
function setupOnce(t)
addpath(fileparts(fileparts(mfilename('fullpath'))));deConfUSIon_setup();
folder=tempname;mkdir(folder);shape=[8 10 6];
[y,x,z]=ndgrid(1:shape(1),1:shape(2),1:shape(3));u=single((y+2*x+3*z)/46);
brainMask=true(shape);brainMask(1:2,:,:)=false;
overlayMask=true(shape);overlayMask(:,1:3,:)=false;
maskEditorInfo=struct('hasBrainMask',true,'hasOverlayMask',true,'flipUD_display',true);
sliceUnderlayProcessed=u;file=fullfile(folder,'ME_both.mat');
save(file,'sliceUnderlayProcessed','brainMask','overlayMask','maskEditorInfo');
PSC=cat(4,u+5,u+15,u+25);
d=struct('PSC',PSC,'I',PSC,'TR',1,'par',struct('voxelSizeUm',[100 150 150],'exportPath',folder), ...
 'underlay',u,'underlayLabel','Initial','label','Test','inputIsPSC',true,'transformed',false, ...
 'mask',[],'maskIsInclude',true,'applyMask',false,'interpol',1,'frame',1,'caxis',[0 30], ...
 'baseline',struct('start',0,'end',1,'mode','sec'),'volumeBackend','Surface rendering');
opt=struct('mode','Frame','frame',1,'intervalMin',[0 0],'slices',[1 6], ...
 'spacing',[.1 .15 .15],'units','mm','applyMask',true,'applyOverlayMask',true, ...
 'underlaySource','Video underlay','underlayPreset','Video / saved Mask Editor');
t.TestData=struct('folder',folder,'file',file,'data',d,'opt',opt,'u',u,'brain',brainMask,'overlay',overlayMask);
end
function teardownOnce(t)
folder=char(java.io.File(t.TestData.folder).getCanonicalPath());temporary=char(java.io.File(tempdir).getCanonicalPath());
assert(startsWith([folder filesep],[temporary filesep])&&~strcmp(folder,temporary));rmdir(folder,'s');
end
function testSavedAppearanceAndSeparateMaskRoles(t)
d=fusiVolumeReadMaskBundle(t.TestData.data,t.TestData.file);o=t.TestData.opt;
S=fusiVolumeSnapshot(d,o);brain=t.TestData.brain;overlay=t.TestData.overlay;
verifyEqual(t,S.underlay(brain),t.TestData.u(brain));
verifyEqual(t,S.underlayValid,brain);verifyTrue(t,all(S.signal(~brain)==0));
verifyEqual(t,isfinite(S.psc),overlay);
o.applyMask=false;B=fusiVolumeSnapshot(d,o);verifyTrue(t,all(B.underlayValid(:)));verifyEqual(t,isfinite(B.psc),overlay);
o.applyMask=true;o.applyOverlayMask=false;B=fusiVolumeSnapshot(d,o);verifyEqual(t,B.underlayValid,brain);verifyTrue(t,all(isfinite(B.psc(:))));
o=t.TestData.opt;o.frame=2;B=fusiVolumeSnapshot(d,o,S);verifyEqual(t,B.underlay,S.underlay);
verifyEqual(t,double(B.psc(overlay)-S.psc(overlay)),10*ones(nnz(overlay),1),'AbsTol',1e-5);
end
function testOverlayOnlyImportPreservesAnatomyAndEmptyMask(t)
d=fusiVolumeReadMaskBundle(t.TestData.data,t.TestData.file);
overlayMask=false(size(d.underlay));file=fullfile(t.TestData.folder,'emptyOverlay.mat');save(file,'overlayMask');
B=fusiVolumeReadMaskBundle(d,file,'overlay');verifyEqual(t,B.underlay,d.underlay);verifyEqual(t,B.brainMask,d.brainMask);
S=fusiVolumeSnapshot(B,t.TestData.opt);verifyTrue(t,all(isnan(S.psc(:))));verifyEqual(t,S.underlayValid,d.brainMask);
end
function testUnrelatedGridRejected(t)
sliceUnderlayProcessed=zeros(9,10,6);maskEditorInfo=struct();file=fullfile(t.TestData.folder,'wrongGrid.mat');
save(file,'sliceUnderlayProcessed','maskEditorInfo');
verifyError(t,@()fusiVolumeReadMaskBundle(t.TestData.data,file),'SCM:MaskEditorDimensions');
end
function testLegacyTimeMaskKeepsAnExplicitlyEmptyFrameEmpty(t)
d=t.TestData.data;shape=size(d.underlay);d.mask=cat(4,true(shape),false(shape),true(shape));
o=t.TestData.opt;o.frame=2;S=fusiVolumeSnapshot(d,o);
verifyTrue(t,all(isnan(S.psc(:))));verifyFalse(t,any(S.underlayValid(:)));verifyFalse(t,any(S.signal(:)));
% A globally empty legacy mask still means no mask has been drawn.
d.mask=false(shape);S=fusiVolumeSnapshot(d,o);verifyTrue(t,all(isfinite(S.psc(:))));
end
function testSmallModelessWindowsKeepOwnerVisible(t)
assumeTrue(t,usejava('awt'));f=uifigure('Position',[60 60 700 500]);cleanup=onCleanup(@()delete(f)); %#ok<NASGU>
enabled=uibutton(f);disabled=uibutton(f,'Enable','off');original=f.Position;
popup=fusiVolumeAtlasSourcePopup(f,@(~)[]);verifyEqual(t,popup.WindowStyle,'normal');verifyEqual(t,popup.Position(3:4),[450 220]);
verifyEqual(t,char(enabled.Enable),'on');delete(popup);
p=fusiVolumeAtlasProgress(f);verifyEqual(t,p.window.WindowStyle,'normal');verifyEqual(t,char(enabled.Enable),'off');
p.update(.6,'Checking saved registration');p.close();verifyFalse(t,isgraphics(p.window));
verifyEqual(t,char(enabled.Enable),'on');verifyEqual(t,char(disabled.Enable),'off');verifyEqual(t,char(f.Visible),'on');verifyEqual(t,f.Position,original);
p=fusiVolumeAtlasProgress(f);p.window.CloseRequestFcn(p.window,[]);
verifyError(t,@()p.update(.7,'Cancelled'),'deConfUSIon:ProcessingCancelled');p.close();verifyEqual(t,char(enabled.Enable),'on');
end
function testNativeMasksFollowAnAlreadyAppliedAtlasMapping(t)
d=t.TestData.data;shape=[12 14 6];d.nativePower=d.I;d.transformed=true;
d.PSC=zeros([shape 3],'single');M=[1 0 0;0 1 0;2 2 1];
d.scanMapping=struct('kind','2D','matrices',{repmat({M},1,6)},'sourceSlices',1:6,'transpose',false(1,6));
B=fusiVolumeReadMaskBundle(d,t.TestData.file);
verifySize(t,B.underlay,shape);verifyTrue(t,B.maskImportAlignment.warpedFromNative);
for z=1:6
 expected=imwarp(t.TestData.overlay(:,:,z),affine2d(M),'nearest','OutputView',imref2d(shape(1:2)));
 verifyEqual(t,B.overlayMask(:,:,z),expected);
end
end
function testGUILoadMasksAndResolutionExport(t)
assumeTrue(t,usejava('awt'));d=t.TestData.data;f=fusiVolumeGUI(d);cleanup=onCleanup(@()delete(f)); %#ok<NASGU>
loader=getappdata(f,'FUSIVolumeLoadMasks');loader(t.TestData.file,'both');verifyFalse(t,isappdata(f,'FUSIVolumeMaskLastError'));
getData=getappdata(f,'FUSIVolumeData');actual=getData();verifyEqual(t,actual.PSC,d.PSC);verifyEqual(t,actual.baseline,d.baseline);
verifyEqual(t,actual.underlay,t.TestData.u);verifyEqual(t,actual.overlayMask,t.TestData.overlay);
resolution=findall(f,'Tag','VolumeMovieResolution');verifyEqual(t,resolution.Value,'HD (1080 px)');
verifyEqual(t,fusiVolumeMovieEdge(f,[200 300]),1080);
% Small high-contrast raster test: output must be rendered at the selected
% size even when the GUI/monitor is smaller. No screen-sized screenshot.
resolution.Value='Full HD (1920 px)';file=fullfile(t.TestData.folder,'sharp.png');fusiExportVolume(f,file);
pixels=imread(file);verifyEqual(t,max(size(pixels,[1 2])),1920,'AbsTol',2);
metadata=jsondecode(fileread([file '.json']));verifyEqual(t,metadata.maskOverlayFile,t.TestData.file);
verifyEqual(t,metadata.imageOutputSizeYX(:)',size(pixels,[1 2]));
button=findall(f,'Tag','VolumeLoadMasks');verifyEqual(t,char(button.Enable),'on');
% Failure leaves the existing model and saved masks intact.
loader(fullfile(t.TestData.folder,'wrongGrid.mat'),'both');verifyTrue(t,isappdata(f,'FUSIVolumeMaskLastError'));
actual=getData();verifyEqual(t,actual.underlay,t.TestData.u);
button=findall(f,'Tag','VolumeLoadAtlas');button.ButtonPushedFcn(button,[]);
popup=getappdata(f,'FUSIVolumeAtlasSourceDialog');verifyTrue(t,isgraphics(popup));verifyEqual(t,popup.WindowStyle,'normal');
delete(popup);verifyEqual(t,char(f.Visible),'on');
loadAtlas=getappdata(f,'FUSIVolumeLoadAtlas');position=f.Position;
loadAtlas(fullfile(t.TestData.folder,'missing_transform.mat'));
verifyTrue(t,isappdata(f,'FUSIVolumeAtlasLastError'));verifyEqual(t,char(f.Visible),'on');verifyEqual(t,f.Position,position);
verifyEmpty(t,findall(0,'Tag','VolumeAtlasLoadProgress'));
end
function testVolumeRendererKeepsNativeVoxelsInHDVideoAndFullHDImage(t)
assumeTrue(t,usejava('awt')&&exist('viewer3d','file')==2&&exist('volshow','file')==2);
d=t.TestData.data;d.volumeBackend='Volume rendering';f=fusiVolumeGUI(d);cleanup=onCleanup(@()delete(f)); %#ok<NASGU>
state=getappdata(f,'FUSIVolumeExport');assertFalse(t,isempty(state.viewer));
movie=fullfile(t.TestData.folder,'volume_hd.mp4');fusiExportVolume(f,movie,3,'timeseries');
v=VideoReader(movie);verifyEqual(t,max([v.Width v.Height]),1080,'AbsTol',2);
settings=jsondecode(fileread([movie '.json']));verifyEqual(t,settings.movieOriginalFrames(:)',1:3);
verifyTrue(t,contains(settings.movieCapture,'full-resolution displayed RGB/alpha'));
resolution=findall(f,'Tag','VolumeMovieResolution');resolution.Value='Full HD (1920 px)';
file=fullfile(t.TestData.folder,'volume_full_hd.png');fusiExportVolume(f,file);
pixels=imread(file);verifyEqual(t,max(size(pixels,[1 2])),1920,'AbsTol',2);
% Quantify actual rendered content, rather than accepting a blank large file.
colored=max(pixels,[],3)-min(pixels,[],3)>40;verifyGreaterThan(t,nnz(colored),1000);
end
