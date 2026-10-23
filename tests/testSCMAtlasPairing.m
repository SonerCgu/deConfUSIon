function tests=testSCMAtlasPairing
tests=functiontests(localfunctions);
end
function setupOnce(~)
addpath(fileparts(fileparts(mfilename('fullpath'))));deConfUSIon_setup();
end

function testMatchingControlSurvivesItsIndependentTopCutoff(testCase)
[A,L,info,opt]=fixture();reports=scmRankAtlasRoles(A,10,L,info,opt);
verifyEqual(testCase,reports{1}.table.AtlasID,1);
verifyEqual(testCase,reports{2}.table.AtlasID,[2;1]);
verifyEqual(testCase,reports{2}.table.Rank,[1;2]);
verifyEqual(testCase,reports{2}.table.MeanPSC_pct,[20;4],'AbsTol',1e-10);
for k=1:numel(reports)
    reports{k}.sourceScanLabel='scan3';reports{k}.sourceScanKey='animal1413/scan3';reports{k}.sourceScanIndex=1;
end
candidates=scmAtlasRankingCandidates(reports,opt,10,6);
[index,note]=scmAtlasCounterpart(candidates,1);verifyEqual(testCase,index,3);verifyEmpty(testCase,note);
verifyEqual(testCase,candidates{index}.atlasRegion.id,candidates{1}.atlasRegion.id);
verifyEqual(testCase,candidates{index}.selectionRank,2);
onlyTarget=opt;onlyTarget.roiSelection='Target';paired=scmRankAtlasRoles(A,10,L,info,onlyTarget);
verifyNumElements(testCase,paired,2);verifyEqual(testCase,paired{2}.table.AtlasID,1);
cropped=L;cropped(:,5:end,:)=0;missing=scmRankAtlasRoles(A,10,cropped,info,opt);
verifyNumElements(testCase,missing,1);verifyEqual(testCase,missing{1}.role,'Target');
% Similar names, different scans, times or baselines must never be paired.
bad=candidates;bad{3}.searchScanKey='animal1413/scan4';verifyEmpty(testCase,scmAtlasCounterpart(bad,1));
bad=candidates;bad{3}.signalSec=[30 40];verifyEmpty(testCase,scmAtlasCounterpart(bad,1));
bad=candidates;bad{3}.baselineSec=[10 20];verifyEmpty(testCase,scmAtlasCounterpart(bad,1));
bad=candidates;bad{3}.atlasRegion.id=2;verifyEmpty(testCase,scmAtlasCounterpart(bad,1));
bad=[candidates candidates(3)];[index,note]=scmAtlasCounterpart(bad,1);
verifyEmpty(testCase,index);verifyTrue(testCase,contains(note,'Several'));
end

function testDrawnMidlineMatchesPreviewAndVolumeMembership(testCase)
[A,L,info,opt]=fixture();opt.midlineXY=[2 1;6 6];
[left,right]=scmSearchSideMasks(opt,size(L));
verifyFalse(testCase,any(left(:)&right(:)));verifyTrue(testCase,all(left(:)|right(:)));
verifyEqual(testCase,sum(left,2),[2;2;3;4;5;6]);
search=opt;search.boundsXY=[1 8 1 6];search.polygons=cell(3,2);search.atlasLabels=L;search.excludedAtlasIDs=[];
regions=scmSearchRegions(search,2,false(6,8));
verifyEqual(testCase,regions(1).mask,left&L(:,:,2)>0);verifyEqual(testCase,regions(2).mask,right&L(:,:,2)>0);
reports=scmRankAtlasRoles(A,10,L,info,opt);
for k=1:numel(reports)
    mask=left;if strcmp(reports{k}.imageSide,'Image-right'),mask=right;end
    mask=repmat(mask,1,1,size(L,3));
    for r=1:height(reports{k}.table)
        indices=reports{k}.regionVoxelIndices{r};verifyTrue(testCase,all(mask(indices)));
        verifyEqual(testCase,numel(indices),nnz(mask&L==reports{k}.table.AtlasID(r)));
    end
end
verifyError(testCase,@()scmSearchSideMasks(struct('midlineXY',[1 2;5 2]),[6 8]),'deConfUSIon:SearchMidline');
end

function testDrawRemoveRedrawInRealEditor(testCase)
assumeTrue(testCase,usejava('awt'));[~,L,info]=fixture();
pointer=struct('xy',[3 1],'inside',true,'kind','normal','leftDown',true,'rightDown',false);
ctx=struct('sizeYXZ',size(L),'slice',2,'roiSize',2,'signalSec',[20 40],'baselineSec',[0 10], ...
    'TR',10,'nT',6,'atlasLabels',L,'atlasRegionInfo',info,'initialROIMode',4, ...
    'underlay',@(~)zeros(6,8,3),'mask',@(~)true(6,8),'pointerInputFcn',@readPointer);
[~,~,~,initial]=fixture();initial.sliceRange=[2 3];initial.metric='peak';initial.direction='decrease';initial.minCoverage=.9;
ctx.initialSearchOptions=initial;
driverError='';started=tic;driver=timer('ExecutionMode','fixedSpacing','Period',.2,'StartDelay',.2,'TimerFcn',@drive);
cleanup=onCleanup(@()releaseTimer(driver));start(driver);opt=scmAutoSearchDialog(ctx);clear cleanup;
verifyEmpty(testCase,driverError);verifyNotEmpty(testCase,opt);
verifyEqual(testCase,opt.midlineXY,[3 1;5 6]);verifyTrue(testCase,opt.bilateral);
verifyEqual(testCase,opt.sliceRange,[2 3]);verifyEqual(testCase,opt.topCount,[1 1]);verifyEqual(testCase,opt.metric,'peak');
verifyEqual(testCase,opt.direction,'decrease');verifyEqual(testCase,opt.minCoverage,.9,'AbsTol',1e-12);
    function q=readPointer(~,~),q=pointer;end
    function drag(f)
        button=findall(f,'Tag','SearchDrawMidline');button.Callback(button,[]);
        pointer.xy=[3 1];pointer.leftDown=true;f.WindowButtonDownFcn(f,[]);
        pointer.xy=[5 6];f.WindowButtonMotionFcn(f,[]);
        pointer.leftDown=false;f.WindowButtonUpFcn(f,[]);
    end
    function drive(~,~)
        f=findall(0,'Name','Automatic SCM | time and anatomical search regions');if isempty(f),return;end
        f=f(1);
        try
            assert(toc(started)<30,'Midline editor timed out.');
            if ~isappdata(f,'SCMSearchDialogReady')||~strcmp(f.WaitStatus,'waiting'),return;end
            stop(driver);drag(f);
            assert(strcmp(findall(f,'Tag','SearchSplit').Enable,'off'));
            line=findall(f,'Tag','SearchMidline');assert(numel(line)==1);
            x=line.XData;slider=findall(f,'Tag','SearchSlice');slider.Value=3;slider.Callback(slider,[]);
            line=findall(f,'Tag','SearchMidline');assert(isequal(line.XData,x));
            remove=findall(f,'Tag','SearchRemoveMidline');remove.Callback(remove,[]);
            assert(findall(f,'Tag','SearchSeparateSides').Value==0);assert(isempty(findall(f,'Tag','SearchMidline')));
            drag(f);go=findall(f,'Tag','SearchGo');go.Callback(go,[]);
            assert(~strcmp(f.WaitStatus,'waiting'),'Midline settings were not accepted.');
        catch ME,driverError=getReport(ME,'extended','hyperlinks','off');delete(f);end
    end
end

function testInitiallyEmptyThenPreviewAndCheckExactPair(testCase)
assumeTrue(testCase,usejava('awt'));[A,L,info,opt]=fixture();
[f,folder]=openFixture(A,L,info);cleanup=onCleanup(@()releaseFixture(f,folder)); %#ok<NASGU>
reader=getappdata(f,'FUSIUnderlayData');run=getappdata(f,'FUSIAtlasRegionRanking');run(opt);
if isappdata(f,'AtlasRankingLastError'),rethrow(getappdata(f,'AtlasRankingLastError'));end
review=findall(0,'Tag','AutomaticROICandidateReview');review=review(1);
table=findall(review,'Tag','CandidateTable');verifyFalse(testCase,any(cell2mat(table.Data(:,10))));
data=reader();verifyEmpty(testCase,data.roiDefinitions);verifyEmpty(testCase,findall(f,'Tag','SCM_SavedROI'));
candidates=getappdata(review,'AutomaticCandidates');
target=find(cellfun(@(c)strcmp(c.role,'Target')&&c.atlasRegion.id==1,candidates),1);
control=find(cellfun(@(c)strcmp(c.role,'Control')&&c.atlasRegion.id==1,candidates),1);
other=find(cellfun(@(c)c.atlasRegion.id==2,candidates),1);
ids=[candidates{target}.roiId candidates{control}.roiId];
order=getappdata(table,'CandidateIndices');row=find(order==target);
table.CellSelectionCallback(table,struct('Indices',[row 4]));
verifyFalse(testCase,any(cell2mat(table.Data(:,10))));
verifyEqual(testCase,sort(getappdata(review,'PreviewROIIds')),sort(ids));
verifyEqual(testCase,value(review,'Target'),30,'AbsTol',1e-10);verifyEqual(testCase,value(review,'Control'),4,'AbsTol',1e-10);
drawnow;frame=getframe(review);imwrite(frame.cdata,fullfile(tempdir,'deConfUSIon_AtlasPairedPreview_20261023.png'));
data=reader();verifyNumElements(testCase,data.roiDefinitions,2);
verifyTrue(testCase,all(cellfun(@(c)c.previewOnly,data.roiDefinitions)));
check(table,row,true);
verifyEqual(testCase,sort(getappdata(table,'ExportROIIds')),sort(ids));
verifyEmpty(testCase,getappdata(review,'PreviewROIIds'));
order=getappdata(table,'CandidateIndices');verifyFalse(testCase,table.Data{find(order==other),10});
data=reader();verifyNumElements(testCase,data.roiDefinitions,2);verifyFalse(testCase,any(cellfun(@(c)c.previewOnly,data.roiDefinitions)));
verifyEqual(testCase,value(review,'Target'),30,'AbsTol',1e-10);verifyEqual(testCase,value(review,'Control'),4,'AbsTol',1e-10);
check(table,row,false);verifyFalse(testCase,any(cell2mat(table.Data(:,10))));data=reader();verifyEmpty(testCase,data.roiDefinitions);
verifyEmpty(testCase,value(review,'Target'));verifyEmpty(testCase,value(review,'Control'));
% Filtering must not match another scan or an unrelated high-response Control.
check(table,row,true);bundle=findall(review,'Tag','SCM_ExportROIBundles');bundle.Callback(bundle,[]);
if isappdata(review,'LastBundleExportError'),error('%s',getappdata(review,'LastBundleExportError'));end
files=getappdata(review,'LastBundleFiles');verifyNumElements(testCase,files,4);
controlFile=files(cellfun(@(p)~isempty(regexp(p,'[\\/][^\\/]*Control[^\\/]*_mean\.txt$','once')),files));
exported=readmatrix(controlFile{1},'FileType','text','CommentStyle','#');
verifyEqual(testCase,mean(exported(3:5,3)),4,'AbsTol',1e-9);
% Explicitly unchecking a Control is retained when another row is marked.
check(table,find(order==control),false);check(table,find(order==other),true);
verifyFalse(testCase,table.Data{find(order==control),10});verifyEqual(testCase,value(review,'Control'),20,'AbsTol',1e-10);
pair=findall(review,'Tag','CandidatePairOpposite');pair.Value=0;pair.Callback(pair,[]);
pair.Value=1;pair.Callback(pair,[]);verifyTrue(testCase,table.Data{find(order==control),10});
verifyEqual(testCase,value(review,'Control'),12,'AbsTol',1e-10);
clearButton=findall(review,'Tag','CandidateClearSelection');clearButton.Callback(clearButton,[]);
verifyFalse(testCase,any(cell2mat(table.Data(:,10))));data=reader();verifyEmpty(testCase,data.roiDefinitions);
drawnow;frame=getframe(review);imwrite(frame.cdata,fullfile(tempdir,'deConfUSIon_AtlasPairing_20261023.png'));
end

function check(table,row,enabled)
data=table.Data;data{row,10}=enabled;table.Data=data;
table.CellEditCallback(table,struct('Indices',[row 10],'NewData',enabled));
end
function n=value(review,role)
n=get(findall(review,'Tag',['Candidate' role 'AverageValue']),'UserData');
end
function [A,L,info,opt]=fixture()
L=zeros(6,8,3,'uint16');L(2:4,2:3,:)=1;L(2:4,6:7,:)=1;L(5,1,2)=2;L(5,8,2)=2;
info=struct('name',{{'Caudoputamen','Other tissue'}},'acr',{{'CPu','OTH'}},'rgb',[1 .2 .1;.2 .8 .5]);
A=zeros(6,8,3,6,'single');V=reshape(A,[],6);[~,x,~]=ind2sub(size(L),1:numel(L));x=reshape(x,size(L));
V(find(L==1&x<=4),3:5)=30;V(find(L==1&x>4),3:5)=repmat([2 4 6],nnz(L==1&x>4),1);
V(find(L==2&x<=4),3:5)=10;V(find(L==2&x>4),3:5)=20;A=reshape(V,size(A));
opt=struct('roiMode','atlasRanking','bilateral',true,'leftIsTarget',true,'splitX',4,'roiSelection','Both', ...
    'baselineSec',[0 10],'signalSec',[20 40],'sliceRange',[1 3],'topCount',[1 1], ...
    'metric','mean','direction','increase','minCoverage',1);
end
function [f,folder]=openFixture(A,L,info)
folder=tempname;mkdir(folder);shape=size(L);[~,x,~]=ndgrid(1:shape(1),1:shape(2),1:shape(3));
q=struct('kind','deConfUSIon_LightSuite_native_regions','nativeSize',shape,'voxelSizeMm',[.1 .1 .1], ...
    'fitReviewed',true,'arrayOrder','native','transformFile',fullfile(folder,'transform_params.mat'), ...
    'exportSchema',3,'exportID','pair-test','registrationStage','affine_bspline','registrationStageName','Affine + B-spline');
R=struct('atlasRegionLabels3D',L,'atlasInfoRegions',info,'leftHemisphereMask',L>0&x<=4, ...
    'rightHemisphereMask',L>0&x>4,'lightSuiteNativeMeta',q);files=fusiLightSuiteNativeFiles(folder);save(files.regions,'-struct','R');
b=struct('mode','sec','start',0,'end',10,'sigStart',20,'sigEnd',40);
par=struct('selectorRoot',folder,'exportPath',folder);f=SCM_gui(A,ones(shape),10,par,b,6,'Paired atlas test');
load=getappdata(f,'FUSILoadAtlas');load(files.regions);
end
function releaseTimer(t)
if isvalid(t),stop(t);delete(t);end
end
function releaseFixture(f,folder)
reviews=findall(0,'Tag','AutomaticROICandidateReview');for r=reviews(:)',if isequal(getappdata(r,'SCMOwner'),f),delete(r);end,end
if isgraphics(f),delete(f);end
resolved=char(java.io.File(folder).getCanonicalPath());temporary=char(java.io.File(tempdir).getCanonicalPath());
assert(startsWith([resolved filesep],[temporary filesep])&&~strcmp(resolved,temporary));
if isfolder(resolved),rmdir(resolved,'s');end
end
