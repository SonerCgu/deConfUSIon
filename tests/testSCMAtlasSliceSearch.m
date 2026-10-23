function tests=testSCMAtlasSliceSearch
tests=functiontests(localfunctions);
end

function setupOnce(~)
addpath(fileparts(fileparts(mfilename('fullpath'))));deConfUSIon_setup();
end

function testWholeRegionDialogKeepsAllCPuSlicesByDefault(testCase)
assumeTrue(testCase,usejava('awt'));
[A,opt,cfg,ctx]=fixture();
opt=runDialog(ctx,[]);
verifyEqual(testCase,opt.roiMode,'region');
verifyEqual(testCase,opt.topCount,[0 0]);
verifyEqual(testCase,scmSearchSlices(opt,size(A,3)),1:6);
[found,skipped]=scmSearchCandidates(A,ctx.TR,cfg,opt,scmSearchSlices(opt,6),ctx.mask);
if any(opt.topCount>0),found=scmTopCandidates(found,opt.topCount);end
verifyBothSides(testCase,found,2:5);
verifyNumElements(testCase,skipped,4); % CPu is absent on the two end slices.
end

function testChangingROIModeKeepsExplicitTargetAndControlLimits(testCase)
assumeTrue(testCase,usejava('awt'));
[~,~,~,ctx]=fixture();
opt=runDialog(ctx,[2 3]);
verifyEqual(testCase,opt.topCount,[2 3]);
end

function testWholeRegionIndependentAndSharedWindowsKeepEverySlice(testCase)
[A,opt,cfg,ctx]=fixture();opt.roiMode='region';
for shared=[false true]
    opt.sharedWindow=shared;
    [found,skipped]=scmSearchCandidates(A,ctx.TR,cfg,opt,1:6,ctx.mask);
    verifyBothSides(testCase,found,2:5);verifyNumElements(testCase,skipped,4);
    for k=1:numel(found)
        c=found{k};verifyEqual(testCase,c.pixelCount,20);
        expected=10+c.slice;if strcmp(c.role,'Target'),expected=expected+10;end
        verifyEqual(testCase,c.meanPSC,expected,'AbsTol',1e-12);
        verifyEqual(testCase,c.roiMode,'region');
    end
end
end

function testRectangularMaximaStaySeparateForEachSliceAndRole(testCase)
[A,opt,cfg,ctx]=fixture();opt.roiMode='rectangle';
[found,~]=scmSearchCandidates(A,ctx.TR,cfg,opt,1:6,ctx.mask);
verifyBothSides(testCase,found,2:5);
for k=1:numel(found),verifyEqual(testCase,found{k}.pixelCount,4);end
end

function testExplicitLimitsAndScanRankingStillWorkPerSlice(testCase)
[A,opt,cfg,ctx]=fixture();opt.roiMode='region';
found=scmSearchCandidates(A,ctx.TR,cfg,opt,1:6,ctx.mask);
pool={};
for k=1:numel(found)
    first=found{k};first.searchScanKey='scan-A';
    second=first;second.searchScanKey='scan-B';second.meanPSC=first.meanPSC+1;
    pool=[pool {first second}]; %#ok<AGROW>
end
allSlices=scmSelectScanCandidates(pool);
verifyBothSides(testCase,allSlices,2:5);
verifyTrue(testCase,all(cellfun(@(c)strcmp(c.searchScanKey,'scan-B'),allSlices)));
verifyBothSides(testCase,scmTopCandidates(allSlices,[0 0]),2:5);
limited=scmTopCandidates(allSlices,[1 1]);
verifyBothSides(testCase,limited,5);
end

function testExplicitSliceRangeAndCurrentSliceRemainAvailable(testCase)
[A,opt,cfg,ctx]=fixture();opt.roiMode='region';opt.sliceRange=[3 4];
found=scmSearchCandidates(A,ctx.TR,cfg,opt,scmSearchSlices(opt,6),ctx.mask);
verifyBothSides(testCase,found,3:4);
opt.allSlices=false;opt.slice=3;
found=scmSearchCandidates(A,ctx.TR,cfg,opt,scmSearchSlices(opt,6),ctx.mask);
verifyBothSides(testCase,found,3);
end

function verifyBothSides(testCase,found,expectedSlices)
verifyNumElements(testCase,found,2*numel(expectedSlices));
for role={'Target','Control'}
    selected=found(cellfun(@(c)strcmp(c.role,role{1}),found));
    verifyEqual(testCase,sort(cellfun(@(c)c.slice,selected)),expectedSlices);
    verifyTrue(testCase,all(cellfun(@(c)c.atlasRegion.id==1,selected)));
end
end

function [A,opt,cfg,ctx]=fixture()
shape=[12 20 6];TR=60;nT=16;
labels=2*ones(shape,'int16');A=zeros([shape nT],'single');
for z=2:5
    labels(4:8,3:6,z)=-1;labels(3:7,14:17,z)=1;
    A(4:8,3:6,z,3:end)=20+z;A(3:7,14:17,z,3:end)=10+z;
end
region=struct('id',1,'acronym','CPu','name','Caudoputamen', ...
    'displayName','CPu | Caudoputamen','voxelCount',nnz(abs(labels)==1));
opt=struct('size',2,'signalSec',[120 600],'plateauSec',120,'sharedWindow',false, ...
    'boundsXY',[1 20 1 12],'bilateral',true,'splitX',10,'leftIsTarget',true, ...
    'allSlices',true,'slice',3,'sliceRange',[1 6],'polygons',{cell(6,2)}, ...
    'roiSelection','Both','topCount',[0 0],'atlasLabels',labels,'atlasRegions',region, ...
    'excludedAtlasIDs',[],'minAtlasCoverage',1);
cfg=struct('size',2,'slice',3,'baselineSec',[0 60],'signalSec',opt.signalSec,'plateauSec',120);
ctx=struct('sizeYXZ',shape,'slice',3,'roiSize',2,'baselineSec',[0 60], ...
    'signalSec',opt.signalSec,'plateauSec',120,'TR',TR,'nT',nT, ...
    'underlay',@(z)zeros([shape(1:2) 3]),'mask',@(z)false(shape(1:2)), ...
    'spacingUm',[100 100 100],'atlasLabels',labels, ...
    'atlasRegionInfo',struct('name',{{'Caudoputamen','Other tissue'}},'acr',{{'CPu','Other'}}));
% An atlas search must not be restricted by the uploaded SCM display mask.
end

function opt=runDialog(ctx,explicitCounts)
% Drive the real modal dialog, including mode callbacks and the GO button.
driverError='';dialog=[];started=tic;
driver=timer('ExecutionMode','fixedSpacing','Period',.2,'StartDelay',.2,'TimerFcn',@drive);
cleanup=onCleanup(@()releaseDriver(driver));
start(driver);opt=scmAutoSearchDialog(ctx);
clear cleanup;
assert(isempty(driverError),'SCMAtlasSliceSearch:Dialog','%s',driverError);
assert(~isempty(opt),'SCMAtlasSliceSearch:Dialog','The search dialog was not accepted.');
    function drive(~,~)
        dialog=findall(0,'Type','figure','Name','Automatic SCM | time and anatomical search regions');
        if isempty(dialog),return;end
        dialog=dialog(1);
        try
            assert(toc(started)<30,'Timed out waiting for the automatic-search dialog.');
            if ~isappdata(dialog,'SCMSearchDialogReady'),return;end
            stop(driver);
            mode=findall(dialog,'Tag','SearchROIMode');
            target=findall(dialog,'Tag','SearchTopTarget');control=findall(dialog,'Tag','SearchTopControl');
            if ~isempty(explicitCounts)
                target.String=num2str(explicitCounts(1));control.String=num2str(explicitCounts(2));
            end
            atlas=findall(dialog,'Tag','SearchAtlasRegion');
            atlas.Value=find(contains(string(atlas.String),'CPu'),1);atlas.Callback(atlas,[]);
            mode.Value=3;mode.Callback(mode,[]);
            if ~isempty(explicitCounts)
                mode.Value=1;mode.Callback(mode,[]);
                mode.Value=3;mode.Callback(mode,[]);
            end
            go=findall(dialog,'Tag','SearchGo');go.Callback(go,[]);
            if strcmp(dialog.WaitStatus,'waiting')
                status=findall(dialog,'Tag','SearchStatus');error('Search was not accepted: %s',status.String);
            end
        catch ME
            driverError=getReport(ME,'extended','hyperlinks','off');
            if isgraphics(dialog),delete(dialog);end
        end
    end
end

function releaseDriver(driver)
if isvalid(driver),stop(driver);delete(driver);end
end
