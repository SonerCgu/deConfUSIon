function tests=testSCMAtlasRanking
tests=functiontests(localfunctions);
end
function setupOnce(~)
addpath(fileparts(fileparts(mfilename('fullpath'))));deConfUSIon_setup();
end

function testMeansUseAllVoxelsAcrossSlicesAndExcludeNonTissue(testCase)
[A,L,info,opt]=fixture();r=scmRankAtlasRegions(A,10,L,info,opt);
verifyEqual(testCase,r.table.Abbreviation,{'A';'B';'C'});
verifyEqual(testCase,r.table.MeanPSC_pct,[20;15;-30],'AbsTol',1e-10);
verifyEqual(testCase,r.table.PeakPSC_pct,[20;25;-30],'AbsTol',1e-10);
verifyEqual(testCase,r.table.PeakTime_min,[20;40;20]/60,'AbsTol',1e-12);
verifyEqual(testCase,r.table.UsableVoxels,[5;12;1]);
verifyEqual(testCase,r.table.NumberSlices,[2;3;1]);
verifyEqual(testCase,r.traces(:,3:5),[20 20 20;5 15 25;-30 -30 -30],'AbsTol',1e-10);
verifyEqual(testCase,sort(double(r.regionVoxelIndices{1})),find(abs(L)==1));
verifyEqual(testCase,r.excludedAtlasIDs,[3 4]);
verifyEqual(testCase,r.settings.signalFrames,3:5);
end

function testMetricDirectionAndTopCount(testCase)
[A,L,info,opt]=fixture();opt.metric='peak';r=scmRankAtlasRegions(A,10,L,info,opt);
verifyEqual(testCase,r.table.Abbreviation,{'B';'A';'C'});
verifyEqual(testCase,r.table.ChangePSC_pct,[25;20;-30],'AbsTol',1e-10);
opt.direction='decrease';r=scmRankAtlasRegions(A,10,L,info,opt);
verifyEqual(testCase,r.table.Abbreviation,{'C';'B';'A'});
verifyEqual(testCase,r.table.PeakPSC_pct,[-30;5;20],'AbsTol',1e-10);
opt.direction='absolute';opt.topCount=2;r=scmRankAtlasRegions(A,10,L,info,opt);
verifyEqual(testCase,r.table.Abbreviation,{'C';'B'});
verifyEqual(testCase,r.table.ChangePSC_pct,[-30;25],'AbsTol',1e-10);
verifyEqual(testCase,r.eligibleRegionCount,3);
end

function testSliceAndTimeRestrictionsChangeRegionalMeans(testCase)
[A,L,info,opt]=fixture();opt.sliceRange=[2 2];opt.signalSec=[30 40];
r=scmRankAtlasRegions(A,10,L,info,opt);
verifyEqual(testCase,r.table.Abbreviation,{'B';'A';'C'});
verifyEqual(testCase,r.table.MeanPSC_pct,[20;0;-30],'AbsTol',1e-10);
verifyEqual(testCase,r.table.UsableVoxels,[4;4;1]);
verifyEqual(testCase,r.table.FirstSlice,2*ones(3,1));
verifyEqual(testCase,r.table.LastSlice,2*ones(3,1));
end

function testExactPerVoxelBaselineAndExternalReference(testCase)
A=zeros(2,2,5,'single');A(1,1,:)=[0 0 20 20 20];A(2,1,:)=[100 100 120 120 120];
L=int16([1 0;1 0]);info=struct('name',{{'Tissue'}},'acr',{{'TST'}});
opt=struct('baselineSec',[0 10],'signalSec',[20 40],'topCount',0);
r=scmRankAtlasRegions(A,10,L,info,opt);
verifyEqual(testCase,r.table.MeanPSC_pct,15,'AbsTol',1e-10);
opt.baselineMode='external';r=scmRankAtlasRegions(A,10,L,info,opt);
verifyEqual(testCase,r.table.MeanPSC_pct,70,'AbsTol',1e-10);
verifyEmpty(testCase,r.settings.baselineFrames);
end

function testCoverageUsesFixedSupportAndDoesNotFillMissingFrames(testCase)
[A,L,info,opt]=fixture();idx=find(L==2);matrix=reshape(A,[],6);matrix(idx(1),4)=NaN;matrix(idx(2),6)=NaN;
A=reshape(matrix,size(A));r=scmRankAtlasRegions(A,10,L,info,opt);row=find(r.table.AtlasID==2);
verifyEqual(testCase,r.table.UsableVoxels(row),11);
verifyEqual(testCase,r.table.Coverage_pct(row),100*11/12,'AbsTol',1e-10);
verifyTrue(testCase,isnan(r.traces(row,6)));
verifyFalse(testCase,ismember(uint32(idx(1)),r.regionVoxelIndices{row}));
verifyTrue(testCase,ismember(uint32(idx(2)),r.regionVoxelIndices{row}));
opt.minCoverage=1;r=scmRankAtlasRegions(A,10,L,info,opt);
verifyFalse(testCase,ismember(2,r.table.AtlasID));
verifyTrue(testCase,ismember(2,r.omitted.AtlasID));
% Never silently replace a completely invalid region with zero signal.
A(:)=NaN;r=scmRankAtlasRegions(A,10,L,info,opt);
verifyEmpty(testCase,r.table);verifySize(testCase,r.traces,[0 6]);
end

function testRejectsWrongGridInvalidTimesAndInsufficientSamples(testCase)
[A,L,info,opt]=fixture();
verifyError(testCase,@()scmRankAtlasRegions(A,10,L(:,1:3,:),info,opt),'deConfUSIon:AtlasRankingGrid');
opt.signalSec=[20 60];verifyError(testCase,@()scmRankAtlasRegions(A,10,L,info,opt),'deConfUSIon:AtlasRankingTime');
opt.signalSec=[20 21];verifyError(testCase,@()scmRankAtlasRegions(A,10,L,info,opt),'deConfUSIon:AtlasRankingTime');
opt.signalSec=[20 40];opt.sliceRange=[3 4];
verifyError(testCase,@()scmRankAtlasRegions(A,10,L,info,opt),'deConfUSIon:AtlasRankingSlices');
end

function testScanRankingsStaySeparateAndShortScansAreSkipped(testCase)
[A,L,info,opt]=fixture();b=struct('mode','sec','start',0,'end',10);
power=100+A;q=fusiScanSequence('init',struct(),power,10,'First');
other=fusiScanSequence('init',struct(),100+2*A,10,'Second');
short=fusiScanSequence('init',struct(),power(:,:,:,1:3),10,'Short');
q.scans=[q.scans other.scans short.scans];q.normMode='local';q.localWindowSec=[0 10];
opt.baselineMode='local';opt.scanScope='all';opt.scanIndex=[];
ctx=struct('power',power,'par',struct(),'mapping',[],'displayShape',size(L));
[reports,skipped]=scmRankAtlasScanSequence(A,10,q,b,L,info,opt,ctx);
verifyNumElements(testCase,reports,2);verifyNumElements(testCase,skipped,1);
verifyEqual(testCase,reports{1}.table.MeanPSC_pct,[20;15;-30],'AbsTol',1e-10);
verifyEqual(testCase,reports{2}.table.MeanPSC_pct,[40;30;-60],'AbsTol',1e-4);
verifyEqual(testCase,reports{2}.sourceScanKey,other.scans{1}.key);
verifyEqual(testCase,reports{2}.settings.signalSec,[20 40]);
opt.scanScope='single';opt.scanIndex=3;
verifyError(testCase,@()scmRankAtlasScanSequence(A,10,q,b,L,info,opt,ctx),'deConfUSIon:AtlasRankingTime');
end

function testExportKeepsSignsCurvesSettingsAndMembership(testCase)
[A,L,info,opt]=fixture();r=scmRankAtlasRegions(A,10,L,info,opt);
r.sourceScanLabel='Animal 1413 scan3';r.sourceScanIndex=2;
folder=tempname;mkdir(folder);cleanup=onCleanup(@()removeTemporary(folder)); %#ok<NASGU>
paths=scmExportAtlasRanking({r},{'Short scan skipped'},folder);verifyTrue(testCase,all(cellfun(@isfile,paths)));
tab=readtable(fullfile(folder,'Scan_02_AtlasRanking.csv'));
verifyEqual(testCase,tab.ChangePSC_pct,[20;15;-30],'AbsTol',1e-10);
verifyEqual(testCase,tab.SourceScan,repmat({'Animal 1413 scan3'},3,1));
curves=readtable(fullfile(folder,'Scan_02_AtlasRanking_Curves.csv'));
verifyEqual(testCase,curves.AtlasID_2_PSC_pct,r.traces(2,:)','AbsTol',1e-10);
saved=load(fullfile(folder,'AtlasRanking.mat'));
verifyEqual(testCase,saved.reports{1}.regionVoxelIndices,r.regionVoxelIndices);
verifyEqual(testCase,saved.reports{1}.settings,r.settings);
verifyEqual(testCase,saved.skipped,{'Short scan skipped'});
end

function testUnifiedBlackSettingsCollectSidesAndPreserveOtherROIModes(testCase)
assumeTrue(testCase,usejava('awt'));
[~,L,info]=fixture();
ctx=struct('sizeYXZ',[4 5 3],'signalSec',[20 40],'baselineSec',[0 10], ...
    'baselineMode','local','TR',10,'nT',6,'atlasLabels',L,'atlasRegionInfo',info);
driverError='';started=tic;driver=timer('ExecutionMode','fixedSpacing','Period',.2,'StartDelay',.2,'TimerFcn',@drive);
cleanup=onCleanup(@()releaseTimer(driver));start(driver);opt=scmAtlasRankingDialog(ctx);clear cleanup;
verifyEmpty(testCase,driverError);verifyNotEmpty(testCase,opt);
verifyEqual(testCase,opt.sliceRange,[2 3]);verifyEqual(testCase,opt.topCount,[2 3]);
verifyEqual(testCase,opt.metric,'peak');verifyEqual(testCase,opt.direction,'absolute');
verifyEqual(testCase,opt.signalSec,[20 40],'AbsTol',1e-10);
verifyTrue(testCase,opt.bilateral);verifyFalse(testCase,opt.leftIsTarget);
verifyEqual(testCase,opt.splitX,2);verifyEqual(testCase,opt.roiMode,'atlasRanking');
    function drive(~,~)
        f=findall(0,'Name','Automatic SCM | time and anatomical search regions');if isempty(f),return;end
        f=f(1);
        try
            assert(toc(started)<30,'Settings dialog timed out.');
            if ~isappdata(f,'SCMSearchDialogReady')||~strcmp(f.WaitStatus,'waiting'),return;end
            stop(driver);
            assert(isequal(f.Color,[0 0 0]));
            assert(f.Position(3)>=min(1400,get(0,'ScreenSize')*[0;0;1;0]-80));
            mode=findall(f,'Tag','SearchROIMode');assert(mode.Value==4);
            sizeInput=findall(f,'Tag','SearchROISize');assert(strcmp(sizeInput.Visible,'off'));
            assert(strcmp(findall(f,'Tag','SearchBrushMode').Enable,'off'));
            target=findall(f,'Tag','SearchTopTarget');control=findall(f,'Tag','SearchTopControl');
            target.String='2';control.String='3';
            mode.Value=1;mode.Callback(mode,[]);assert(strcmp(sizeInput.Visible,'on'));
            assert(strcmp(target.String,'0')&&strcmp(control.String,'0'));
            mode.Value=4;mode.Callback(mode,[]);assert(strcmp(target.String,'2')&&strcmp(control.String,'3'));
            set(findall(f,'Tag','SearchSliceStart'),'String','2');set(findall(f,'Tag','SearchSliceEnd'),'String','3');
            set(findall(f,'Tag','SearchRankingMetric'),'Value',2);set(findall(f,'Tag','SearchRankingDirection'),'Value',3);
            set(findall(f,'Tag','SearchTargetSide'),'Value',2);set(findall(f,'Tag','SearchSplit'),'String','2');
            preview=findall(f,'Tag','SearchTargetSide');preview.Callback(preview,[]);
            assert(~isempty(findall(f,'Tag','SearchLoadFixedProtocol')));
            drawnow;frame=getframe(f);imwrite(frame.cdata,fullfile(tempdir,'deConfUSIon_UnifiedAutomaticSettings_20261023.png'));
            go=findall(f,'Tag','SearchGo');go.Callback(go,[]);
            assert(~strcmp(f.WaitStatus,'waiting'),'Dialog rejected valid settings.');
        catch ME,driverError=ME.message;delete(f);end
    end
end

function testSCMLightSuiteRankingWorksWithVascularUnderlay(testCase)
assumeTrue(testCase,usejava('awt'));
[A,L,info,opt]=fixture();L=abs(L);info.rgb=lines(numel(info.name));shape=size(L);
folder=tempname;mkdir(folder);cleanupFolder=onCleanup(@()removeTemporary(folder)); %#ok<NASGU>
q=struct('kind','deConfUSIon_LightSuite_native_regions','nativeSize',shape, ...
    'voxelSizeMm',[.1 .1 .1],'fitReviewed',true,'arrayOrder','native', ...
    'transformFile',fullfile(folder,'transform_params.mat'),'exportSchema',3,'exportID','ranking-test', ...
    'registrationStage','affine_bspline','registrationStageName','Affine + B-spline');
R=struct('atlasRegionLabels3D',L,'atlasInfoRegions',info,'leftHemisphereMask',L>0, ...
    'rightHemisphereMask',false(shape),'lightSuiteNativeMeta',q);
files=fusiLightSuiteNativeFiles(folder);save(files.regions,'-struct','R');
B=struct('vascularImage',ones(shape,'single'),'lightSuiteUnderlayMeta',q);save(files.backgrounds,'-struct','B');
b=struct('mode','sec','start',0,'end',10,'sigStart',20,'sigEnd',40);
par=struct('selectorRoot',folder,'exportPath',folder);
f=SCM_gui(A,ones(shape),10,par,b,6,'Atlas ranking test');
cleanup=onCleanup(@()closeRankingGUI(f)); %#ok<NASGU>
loader=getappdata(f,'FUSILoadAtlas');loader(files.regions);
popup=findall(f,'Tag','AtlasUnderlayChoice');popup.Value=find(strcmp(popup.String,'Vascular'),1);popup.Callback(popup,[]);
reader=getappdata(f,'FUSIUnderlayData');before=reader();verifyEqual(testCase,before.underlayMode,'vascular');
reports=runFromAutomaticButton(f);
if isappdata(f,'AtlasRankingLastError'),rethrow(getappdata(f,'AtlasRankingLastError'));end
verifyNumElements(testCase,reports,1);
verifyEqual(testCase,reports{1}.table.MeanPSC_pct,[20;15;-30],'AbsTol',1e-10);
verifyEqual(testCase,reports{1}.settings.atlasProvenance.file,files.regions);
after=reader();verifyEqual(testCase,after.PSC,before.PSC);verifyEmpty(testCase,after.roiDefinitions);
review=findall(0,'Tag','AutomaticROICandidateReview');review=review(1);verifyEqual(testCase,review.Color,[0 0 0]);
grid=findall(review,'Tag','CandidateTable');verifyEqual(testCase,size(grid.Data,2),15);
verifyFalse(testCase,any(cell2mat(grid.Data(:,10))));
verifyTrue(testCase,isappdata(grid,'CandidateDarkViewportApplied'));
verifyTrue(testCase,contains(grid.Data{2,4},'Region B'));
grid.CellSelectionCallback(grid,struct('Indices',[2 4]));
slider=findall(f,'Tag','FUSISliceSlider');verifyEqual(testCase,slider.Value,3); % Representative B slice = 1, slider reverses Z.
% Roles can be assigned directly in the same candidate table.
data=grid.Data;data{1,3}='Control';grid.Data=data;
grid.CellEditCallback(grid,struct('Indices',[1 3],'NewData','Control'));
data=grid.Data;data{2,3}='Target';grid.Data=data;
grid.CellEditCallback(grid,struct('Indices',[2 3],'NewData','Target'));
for row=1:2
    data=grid.Data;data{row,10}=true;grid.Data=data;
    grid.CellEditCallback(grid,struct('Indices',[row 10],'NewData',true));
end
verifyEqual(testCase,get(findall(review,'Tag','CandidateTargetAverageValue'),'UserData'),15,'AbsTol',1e-10);
verifyEqual(testCase,get(findall(review,'Tag','CandidateControlAverageValue'),'UserData'),20,'AbsTol',1e-10);
audit=scmAutomaticROISelections(f);verifyEqual(testCase,audit{2}.role,'Target');
verifyEqual(testCase,audit{2}.activeSlices,1:3);verifyEqual(testCase,audit{2}.pixelCount,12);
roiCurves=findall(f,'Tag','SCM_SavedROI');matched=roiCurves(arrayfun(@(h)isequal(getappdata(h,'SCMROIId'),audit{2}.roiId),roiCurves));
verifyNumElements(testCase,matched,1);verifyEqual(testCase,matched.Color,[1 .55 .05]);
% A volume ROI still appears on another slice, with the same ID and trace.
browse=getappdata(f,'FUSISetSlice');browse(3);
after=reader();verifyEqual(testCase,after.PSC,A);
sliceFilter=findall(review,'Tag','CandidateSliceFilter');sliceFilter.String='3 3';sliceFilter.Callback(sliceFilter,[]);
verifyTrue(testCase,any(contains(string(grid.Data(:,4)),'Region B')));
sliceFilter.String='1 3';sliceFilter.Callback(sliceFilter,[]);
export=getappdata(review,'AtlasRankingExport');paths=export(fullfile(folder,'export'));
verifyTrue(testCase,all(cellfun(@isfile,paths)));
saved=readtable(fullfile(folder,'export','Scan_01_AtlasRanking_Search.csv'));
verifyEqual(testCase,saved.AssignedRole,{'Control';'Target';'Search'});
bundle=findall(review,'Tag','SCM_ExportROIBundles');bundle.Callback(bundle,[]);
if isappdata(review,'LastBundleExportError'),error('%s',getappdata(review,'LastBundleExportError'));end
bundleFiles=getappdata(review,'LastBundleFiles');verifyNumElements(testCase,bundleFiles,4);
verifyTrue(testCase,all(cellfun(@isfile,bundleFiles)));
verifyTrue(testCase,contains(fileread(bundleFiles{1}),'AtlasVolumeRanking'));
drawnow;frame=getframe(review);imwrite(frame.cdata,fullfile(tempdir,'deConfUSIon_UnifiedAtlasReview_20261023.png'));
end

function testImageSidesHaveIndependentRankingsAndCanBeReversed(testCase)
[A,L,info,opt]=fixture();opt.topCount=[1 2];opt.bilateral=true;opt.leftIsTarget=true;opt.splitX=2;opt.roiSelection='Both';
reports=scmRankAtlasRoles(A,10,L,info,opt);
verifyNumElements(testCase,reports,2);verifyEqual(testCase,reports{1}.role,'Target');verifyEqual(testCase,reports{2}.role,'Control');
verifyEqual(testCase,reports{1}.table.Abbreviation,{'A'});verifyEqual(testCase,reports{2}.table.Abbreviation,{'B'});
verifyEqual(testCase,reports{1}.table.MeanPSC_pct,20,'AbsTol',1e-10);
verifyEqual(testCase,reports{2}.table.MeanPSC_pct,15,'AbsTol',1e-10);
folder=tempname;mkdir(folder);cleanup=onCleanup(@()removeTemporary(folder)); %#ok<NASGU>
for k=1:numel(reports),reports{k}.sourceScanLabel='Same scan';reports{k}.sourceScanIndex=1;end
scmExportAtlasRanking(reports,{},folder);
target=readtable(fullfile(folder,'Scan_01_AtlasRanking_Target.csv'));
control=readtable(fullfile(folder,'Scan_01_AtlasRanking_Control.csv'));
verifyEqual(testCase,target.Abbreviation,{'A'});verifyEqual(testCase,control.Abbreviation,{'B'});
opt.leftIsTarget=false;reports=scmRankAtlasRoles(A,10,L,info,opt);
verifyEqual(testCase,reports{1}.role,'Control');verifyEqual(testCase,reports{1}.table.Abbreviation,{'A';'C'});
verifyEqual(testCase,reports{2}.role,'Target');verifyEqual(testCase,reports{2}.table.Abbreviation,{'B'});
opt.roiSelection='Target';reports=scmRankAtlasRoles(A,10,L,info,opt);
verifyNumElements(testCase,reports,1);verifyEqual(testCase,reports{1}.role,'Target');
verifyEqual(testCase,reports{1}.imageSide,'Image-right');
end

function [A,L,info,opt]=fixture()
L=zeros(4,5,3,'int16');L(1,1,1)=-1;L(1:2,1:2,2)=1;
L(3:4,4:5,:)=2;L(4,1,:)=3;L(4,2,:)=4;L(3,1,2)=5;
info=struct('name',{{'Region A','Region B','Lateral ventricle','root','Region C'}}, ...
    'acr',{{'A','B','VL','root','C'}});
A=zeros([size(L) 6],'single');matrix=reshape(A,[],6);
matrix(find(L==-1),3:5)=100;matrix(find(L==2),3:5)=repmat([5 15 25],nnz(L==2),1);
matrix(find(L==5),3:5)=-30;matrix(find(L==3|L==4),3:5)=999;
A=reshape(matrix,size(A));
opt=struct('signalSec',[20 40],'baselineSec',[0 10],'sliceRange',[1 3], ...
    'topCount',0,'minCoverage',.75,'metric','mean','direction','increase');
end
function releaseTimer(t)
if isvalid(t),stop(t);delete(t);end
end
function reports=runFromAutomaticButton(owner)
driverError='';started=tic;
driver=timer('ExecutionMode','fixedSpacing','Period',.2,'StartDelay',.2,'TimerFcn',@drive);
cleanup=onCleanup(@()releaseTimer(driver));start(driver);
button=findall(owner,'Style','pushbutton','String','Automatic analysis');button.Callback(button,[]);clear cleanup;
assert(isempty(driverError),'AtlasRanking:GUI','%s',driverError);
reports=getappdata(owner,'AtlasRankingReports');
    function drive(~,~)
        f=findall(0,'Name','Automatic SCM | time and anatomical search regions');if isempty(f),return;end
        f=f(1);
        try
            assert(toc(started)<30,'Automatic analysis dialog timed out.');
            if ~isappdata(f,'SCMSearchDialogReady')||~strcmp(f.WaitStatus,'waiting'),return;end
            stop(driver);
            mode=findall(f,'Tag','SearchROIMode');mode.Value=4;mode.Callback(mode,[]);
            both=findall(f,'Tag','SearchSeparateSides');both.Value=0;both.Callback(both,[]);
            set(findall(f,'Tag','SearchTopTarget'),'String','0');set(findall(f,'Tag','SearchTopControl'),'String','0');
            go=findall(f,'Tag','SearchGo');go.Callback(go,[]);
            assert(~strcmp(f.WaitStatus,'waiting'),'Unified analysis did not accept the ranking request.');
        catch ME,driverError=ME.message;delete(f);end
    end
end
function closeRankingGUI(f)
reviews=findall(0,'Tag','AutomaticROICandidateReview');
for r=reviews(:)',if isequal(getappdata(r,'SCMOwner'),f),delete(r);end,end
if isgraphics(f),delete(f);end
end
function removeTemporary(folder)
resolved=char(java.io.File(folder).getCanonicalPath());temporary=char(java.io.File(tempdir).getCanonicalPath());
assert(startsWith([resolved filesep],[temporary filesep])&&~strcmp(resolved,temporary));
if isfolder(resolved),rmdir(resolved,'s');end
end
