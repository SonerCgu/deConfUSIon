function tests=testSCMNativeUnderlay
tests=functiontests(localfunctions);
end
function setupOnce(test)
deConfUSIon_setup();test.TestData.visible=get(groot,'DefaultFigureVisible');set(groot,'DefaultFigureVisible','off');
test.TestData.folder=tempname;mkdir(test.TestData.folder);rng(93);
test.TestData.PSC=single(3+randn(12,18,40));test.TestData.bg=reshape(1:216,12,18);
test.TestData.mask=true(12,18);test.TestData.mask(1,:)=false;
test.TestData.par=struct('interpol',1,'exportPath',test.TestData.folder,'loadedPath',test.TestData.folder, ...
 'voxelSizeUm',[100 150 150]);
test.TestData.baseline=struct('start',0,'end',5,'sigStart',10,'sigEnd',20,'mode','sec');
end
function teardownOnce(test)
set(groot,'DefaultFigureVisible',test.TestData.visible);rmdir(test.TestData.folder,'s');
end
function testHistologyUsesGrayscaleInsteadOfRGBPreview(test)
f=openSCM(test);guard=onCleanup(@()delete(f)); %#ok<NASGU>
files=makeRegistration(test.TestData.folder,[16 22]);loadFile=getappdata(f,'FUSILoadUnderlay');
loadFile(files.regions);read=getappdata(f,'FUSIUnderlayData');r=read();verifyEqual(test,r.underlayMode,'regions');
loadFile(files.histology);r=read();verifyTrue(test,r.isAtlasWarped);verifyEqual(test,r.underlay,files.histologyData);
verifyEmpty(test,r.regionLabels);verifyEqual(test,r.underlayMode,'histology');verifyTrue(test,contains(selectedMode(f),'Histology'));
loadFile(files.vascular);r=read();verifyEqual(test,r.underlay,files.vascularData);verifyEqual(test,r.underlayMode,'vascular');
verifyTrue(test,contains(selectedMode(f),'Vascular'));
end
function testResetRestoresNativeMovieMaskImageAndGeometry(test)
f=openSCM(test);guard=onCleanup(@()delete(f)); %#ok<NASGU>
read=getappdata(f,'FUSIUnderlayData');native=read();files=makeRegistration(test.TestData.folder,[16 22]);
loadFile=getappdata(f,'FUSILoadUnderlay');loadFile(files.histology);warped=read();
verifySize(test,warped.PSC,[16 22 40]);verifyNotEmpty(test,warped.mapping);
press(f,'RESET TO NATIVE');r=read();verifyEqual(test,r.PSC,native.PSC);verifyEqual(test,r.underlay,native.underlay);
verifyEqual(test,r.mask,native.mask);verifyEqual(test,r.maskIsInclude,native.maskIsInclude);verifyFalse(test,r.isAtlasWarped);
verifyEmpty(test,r.mapping);verifyEmpty(test,r.atlasRegionSearch);verifyEmpty(test,r.regionLabels);verifyEmpty(test,r.transformFile);
verifyEqual(test,r.imageGeometry,native.imageGeometry);verifyEqual(test,double(r.displayRGB),double(native.displayRGB),'AbsTol',1e-7);verifyEqual(test,r.appearance,native.appearance);
h=atlasPopup(f);verifyEqual(test,h.Enable,'off');verifyEmpty(test,getappdata(h,'AtlasUnderlayEntries2D'));
% A second reset must remain native, and a subsequent explicit load must work.
press(f,'RESET TO NATIVE');verifyEqual(test,read().PSC,native.PSC);
loadFile(files.histology);verifyTrue(test,read().isAtlasWarped);verifyEqual(test,read().underlayMode,'histology');
end
function testSameGridRegistrationStillResetsExactly(test)
f=openSCM(test);guard=onCleanup(@()delete(f)); %#ok<NASGU>
read=getappdata(f,'FUSIUnderlayData');native=read();files=makeRegistration(test.TestData.folder,[12 18]);
loadFile=getappdata(f,'FUSILoadUnderlay');loadFile(files.histology);warped=read();verifyTrue(test,warped.isAtlasWarped);
verifyNotEqual(test,warped.PSC,native.PSC);press(f,'RESET TO NATIVE');r=read();verifyEqual(test,r.PSC,native.PSC);
verifyEqual(test,r.underlay,native.underlay);verifyEqual(test,double(r.displayRGB),double(native.displayRGB),'AbsTol',1e-7);verifyEmpty(test,r.mapping);
end
function testDropdownSwitchRetainsRequestedMode(test)
f=openSCM(test);guard=onCleanup(@()delete(f)); %#ok<NASGU>
files=makeRegistration(test.TestData.folder,[16 22]);loadFile=getappdata(f,'FUSILoadUnderlay');loadFile(files.histology);
h=atlasPopup(f);h.Value=3;h.Callback(h,[]);read=getappdata(f,'FUSIUnderlayData');verifyEqual(test,read().underlayMode,'regions');
h=atlasPopup(f);h.Value=1;h.Callback(h,[]);r=read();verifyEqual(test,r.underlayMode,'histology');verifyEqual(test,r.underlay,files.histologyData);
verifyEmpty(test,r.regionLabels);
end
function testResetRestoresInitialUnderlayAfterNativeReplacement(test)
f=openSCM(test);guard=onCleanup(@()delete(f)); %#ok<NASGU>
loadFile=getappdata(f,'FUSILoadUnderlay');bg=flipud(test.TestData.bg);file=fullfile(test.TestData.folder,'native_bg.mat');save(file,'bg');loadFile(file);
mask=test.TestData.mask;mask(:,1:3)=false;file=fullfile(test.TestData.folder,'native_mask.mat');save(file,'mask');loadMask=getappdata(f,'FUSILoadMask');loadMask(file);
read=getappdata(f,'FUSIUnderlayData');native=read();files=makeRegistration(test.TestData.folder,[16 22]);loadFile(files.histology);press(f,'RESET TO NATIVE');r=read();
verifyEqual(test,r.underlay,test.TestData.bg);verifyEqual(test,r.mask,native.mask);verifyEqual(test,r.PSC,test.TestData.PSC);
end
function testMissingSnapshotDoesNotRaiseUndefinedVariable(test)
power=single(100+rand(12,18,40));P=computePSC(power,1,test.TestData.par,test.TestData.baseline);
f=SCM_gui(P.PSC,P.bg,1,test.TestData.par,test.TestData.baseline,40,power,[],[],[],test.TestData.mask,true,'Legacy snapshot recovery');
guard=onCleanup(@()delete(f)); %#ok<NASGU>
rmappdata(f,'SCMInitialNativeUnderlay');files=makeRegistration(test.TestData.folder,[16 22]);
loadFile=getappdata(f,'FUSILoadUnderlay');loadFile(files.histology);press(f,'RESET TO NATIVE');read=getappdata(f,'FUSIUnderlayData');r=read();
verifyFalse(test,r.isAtlasWarped);verifyEqual(test,double(r.underlay),double(P.bg),'AbsTol',1e-5);verifyEqual(test,r.PSC,P.PSC);verifyEmpty(test,r.mapping);
end
function testLoadAtlasButtonAcceptsFileOrFolder(test)
f=openSCM(test);guard=onCleanup(@()delete(f)); %#ok<NASGU>
verifyNotEmpty(test,findall(f,'String','LOAD ATLAS'));files=makeRegistration(test.TestData.folder,[16 22]);
loadAtlas=getappdata(f,'FUSILoadAtlas');loadAtlas(files.histology);read=getappdata(f,'FUSIUnderlayData');verifyEqual(test,read().underlayMode,'histology');
press(f,'RESET TO NATIVE');loadAtlas(test.TestData.folder);verifyTrue(test,read().isAtlasWarped);
end
function f=openSCM(test)
f=SCM_gui(test.TestData.PSC,test.TestData.bg,1,test.TestData.par,test.TestData.baseline,40, ...
 [],[],[],[],test.TestData.mask,true,'SCM native reset test');
end
function files=makeRegistration(folder,shape)
hist=reshape(linspace(10,100,prod(shape)),shape);vascular=flipud(hist.^2);
labels=uint16(ones(shape));labels(:,ceil(shape(2)/2):end)=2;
info=struct('name',{{'Primary motor area';'Caudoputamen (CPu)'}},'acr',{{'MOp';'CPu'}},'rgb',[255 0 0;0 100 255]);
Reg2D=struct('type','simple_coronal_2d','A',[1 0 0;0 1 0;2 3 1],'outputSize',shape, ...
 'sourceSize',[12 18],'sourceSliceIndex',1,'atlasSliceIndex',8,'atlasMode','regions', ...
 'histologyImage',hist,'vascularImage',vascular,'regionsImage',labels,'atlasInfoRegions',info,'atlasVoxelSizeYXZUm',[25 25 NaN]);
transform=fullfile(folder,'CoronalRegistration2D.mat');save(transform,'Reg2D');
files=struct('histology','','vascular','','regions','','histologyData',hist,'vascularData',vascular);
for mode={'histology','vascular','regions'}
 atlasMode=mode{1};atlasUnderlay=Reg2D.([atlasMode 'Image']);
 atlasUnderlayRGB=repmat(double(atlasUnderlay),1,1,3);brainImage=atlasUnderlay;
 atlasRegionLabels2D=double(labels);atlasInfoRegions=info; %#ok<NASGU>
 files.(atlasMode)=fullfile(folder,sprintf('AtlasUnderlay_%s_slice008.mat',atlasMode));
 save(files.(atlasMode),'atlasUnderlay','atlasUnderlayRGB','brainImage','atlasMode','Reg2D','atlasRegionLabels2D','atlasInfoRegions');
end
end
function press(f,label),h=findall(f,'Style','pushbutton','String',label);h.Callback(h,[]);end
function h=atlasPopup(f)
hs=findall(f,'Style','popupmenu');h=[];
for c=reshape(hs,1,[])
 if isa(c.Callback,'function_handle')&&endsWith(func2str(c.Callback),'/atlasUnderlayChoiceCB'),h=c;return;end
end
error('Missing atlas dropdown');
end
function value=selectedMode(f),h=atlasPopup(f);items=cellstr(h.String);value=items{h.Value};end
