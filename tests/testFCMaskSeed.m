function tests=testFCMaskSeed
tests=functiontests(localfunctions);
end
function setupOnce(test)
deConfUSIon_setup();test.TestData.folder=tempname;mkdir(test.TestData.folder);
test.TestData.visible=get(groot,'DefaultFigureVisible');set(groot,'DefaultFigureVisible','off');
t=single(sin((0:79)*.2));I=repmat(reshape(-10+t,1,1,1,80),12,18,3,1);
I(:,10:18,:,:)=repmat(reshape(-5-t,1,1,1,80),12,9,3,1);I(12,18,:,:)=0;
A=-ones(12,18,3,'int32');A(:,10:18,:)=1;A(2:3,11:12,2)=2;A(12,18,:)=0;
T=struct('labels',[-1;1;2],'names',{{'L MOp';'R MOp';'VL'}}, ...
 'fullNames',{{'Left primary motor area';'Right primary motor area';'Lateral ventricle'}});
D=struct('I',I,'TR',.48,'roiAtlas',A,'functionalSource','PSC', ...
 'fcPowerReference',single(reshape(1:12*18*3,12,18,3)),'voxelSizeUm',[100 150 150]);
opts=struct('askMaskAtStart',false,'askAtlasAtStart',false,'debugRethrow',true,'roiNameTable',T,'roiMinVox',2);
f=FunctionalConnectivity(D,test.TestData.folder,'mask_seed_test',opts);
test.TestData.figure=f;test.TestData.initialWindowState=f.WindowState;test.TestData.data=D;test.TestData.opts=opts;
end
function teardownOnce(test)
delete(test.TestData.figure);set(groot,'DefaultFigureVisible',test.TestData.visible);rmdir(test.TestData.folder,'s');
end
function testAutomaticMaskIncludesNegativeSignalAndExcludesCSF(test)
s=guidata(test.TestData.figure);subj=s.subjects(1);
verifyTrue(test,subj.mask(6,4,2));verifyFalse(test,subj.mask(2,11,2));verifyFalse(test,subj.mask(12,18,2));
verifyEqual(test,subj.referenceMedian,test.TestData.data.fcPowerReference);
verifyTrue(test,contains(subj.maskSource,'no intensity cutoff'));
end
function testNoIntensityMaskStillExcludesVentricles(test)
f=test.TestData.figure;h=findall(f,'Tag','FCMaskPolicy');h.Value=3;h.Callback(h,[]);
s=guidata(f);verifyEqual(test,s.subjects(1).maskPolicy,'none');verifyFalse(test,s.subjects(1).mask(2,11,2));
h.Value=1;h.Callback(h,[]);
end
function testSeedMathAndClickRefresh(test)
f=test.TestData.figure;s=guidata(f);s.slice=2;s.seedX=4;s.seedY=6;s.seedBoxSize=1;s.useSliceOnly=true;s.seedRegionMode=false;guidata(f,s);
press(f,'onComputeSeedCurrent');s=guidata(f);r=s.seedResults{1,1};
verifyGreaterThan(test,r.rMap(6,4,2),.9999);verifyLessThan(test,r.rMap(6,15,2),-.9999);
select=getappdata(f,'FUSIFCSelectSeed');select(15,6,2);
s=guidata(f);verifyEqual(test,s.seedResults{1,1}.seedInfo.x,15);
verifyGreaterThan(test,s.seedResults{1,1}.rMap(6,15,2),.9999);verifyLessThan(test,s.seedResults{1,1}.rMap(6,4,2),-.9999);
h=findall(f,'Tag','FCSeedRegionMode');h.Value=1;h.Callback(h,[]);press(f,'onComputeSeedCurrent');s=guidata(f);
verifyTrue(test,s.seedResults{1,1}.seedInfo.regionMode);
expected=s.subjects(1).mask(:,:,2)&s.subjects(1).roiAtlas(:,:,2)==1;
verifyEqual(test,s.seedResults{1,1}.seedMask(:,:,2),expected);
verifyFalse(test,any(s.seedResults{1,1}.seedMask(2:3,11:12,2),'all'));
end
function testCompareGeometryAndHemisphereCallback(test)
f=test.TestData.figure;press(f,'onComputeROICurrent');press(f,'onCompareROI');
press(f,'onShowHemisphere');ax=findall(f,'Tag','FCCompareMap');
verifyEqual(test,ax.DataAspectRatio,[1 1.5 1],'AbsTol',1e-10);
h=findall(f,'Tag','FCRegionNames');h.Value=1;h.Callback(h,[]);h.Value=0;h.Callback(h,[]);
copies=findall(f,'Tag','FCPageHemisphereMode');copies(1).Value=2;copies(1).Callback(copies(1),[]);
verifyEqual(test,guidata(f).roiHemiMode,'left');verifyEqual(test,get(findall(f,'Tag','FCHemisphereMode'),'Value'),2);
h=findall(f,'Tag','FCHemisphereMode');h.Value=1;h.Callback(h,[]);
end
function testLayoutSeparationsAndColours(test)
f=test.TestData.figure;verifyEqual(test,test.TestData.initialWindowState,'maximized');
f.WindowState='normal';f.Position=[20 20 1400 900];deConfUSIon_FC_layout(f);ui=getappdata(f,'FUSIFCLayout');
p=getpixelposition(ui.timePanel);b=getpixelposition(ui.pageButtons(1));verifyGreaterThanOrEqual(test,p(2)-b(2)-b(4),20);
for name={'onSaveAll','onExportGroupAnalysis','onExportCSV'}
 h=findCallback(f,name{1},'pushbutton');verifyGreaterThan(test,h.BackgroundColor(2),h.BackgroundColor(1));
end
h=findCallback(f,'onClose','pushbutton');verifyGreaterThan(test,h.BackgroundColor(1),h.BackgroundColor(2)*3);
h=findCallback(f,'onHelp','pushbutton');verifyGreaterThan(test,h.BackgroundColor(3),h.BackgroundColor(2));
end
function testMismatchedMaskIsRejected(test)
D=test.TestData.data;D.mask=true(18,12,5);
verifyError(test,@()FunctionalConnectivity(D,test.TestData.folder,'bad_mask',test.TestData.opts),'deConfUSIon:FCMaskGrid');
end
function testSavedMaskSemanticsAndGrid(test)
M=false(12,18,3);M(2,3,2)=true;
verifyEqual(test,fusiFCReadMask(struct('mask',M,'maskIsInclude',false),[12 18 3]),~M);
verifyError(test,@()fusiFCReadMask(struct('mask',true(18,12,3)),[12 18 3]),'deConfUSIon:FCMaskGrid');
verifyError(test,@()fusiFCReadMask(struct('mask',true(12,18,5)),[12 18 3]),'deConfUSIon:FCMaskGrid');
end
function testMaskEditorBundleIntersectsMasks(test)
brain=true(12,18,3);brain(1,:,:)=false;signal=true(size(brain));signal(:,1,:)=false;
S=struct('maskEditorInfo',struct('hasBrainMask',true,'hasOverlayMask',true), ...
 'anatomical_reference',ones(size(brain)),'brainMask',brain,'overlayMask',signal, ...
 'brainMaskIsInclude',true,'overlayMaskIsInclude',true);
verifyEqual(test,fusiFCReadMask(S,[12 18 3]),brain&signal);
end
function press(f,name)
h=findCallback(f,name,'');h.Callback(h,[]);
end
function h=findCallback(f,name,style)
h=[];all=findall(f,'Type','uicontrol');
if strcmp(name,'onHelp'),h=findall(f,'Style','pushbutton','String','Help');return;end
for c=reshape(all,1,[])
 if isa(c.Callback,'function_handle')&&endsWith(func2str(c.Callback),['/' name])&&(isempty(style)||strcmp(c.Style,style)),h=c;return;end
end
assert(~isempty(h),'Test control not found: %s',name);
end
