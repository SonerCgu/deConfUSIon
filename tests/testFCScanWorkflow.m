function tests=testFCScanWorkflow
tests=functiontests(localfunctions);
end
function setupOnce(test)
deConfUSIon_setup();test.TestData.root=tempname;mkdir(test.TestData.root);
test.TestData.visibility=get(groot,'DefaultFigureVisible');set(groot,'DefaultFigureVisible','off');
test.TestData.figures=findall(groot,'Type','figure');
end
function teardownOnce(test)
delete(setdiff(findall(groot,'Type','figure'),test.TestData.figures));
set(groot,'DefaultFigureVisible',test.TestData.visibility);rmdir(test.TestData.root,'s');
end
function testLazySelectionLocalTimingAndGroupExport(test)
rng(31);folder=test.TestData.root;files=cell(1,3);TRs=[1 2 1];
atlas=zeros(12,16,3,'int32');atlas(:,1:8,:)=-1;atlas(:,9:16,:)=1;
for k=1:3
    signal=reshape(single(sin((0:59)*.2)),1,1,1,[]);
    I=100+3*randn(12,16,3,60,'single')+10*signal;
    if k==1,I(1,1,1,:)=100;end % Per-scan valid masks may differ without invalidating other results.
    % Slice 2 differs from the other slices, exposing accidental whole-volume
    % fallback when a comparison scan's movie has been released.
    if k==2,I(:,9:16,2,:)=100+3*randn(12,8,1,60,'single')-10*signal;end
    newData=struct('I',I,'TR',TRs(k),'metadata',struct('voxelSizeUm',[100 150 150]));
    files{k}=fullfile(folder,sprintf('Animal_scan%d.mat',k+5));save(files{k},'newData','-v7.3');
end
T=struct('labels',[-1;1],'names',{{'L MOp';'R MOp'}},'fullNames',{{'Left primary motor area';'Right primary motor area'}});
data=struct('I',I,'TR',1,'mask',true(size(atlas)),'roiAtlas',atlas,'sourceFile',files{3}, ...
    'savedFile',files{3},'name','scan8','voxelSizeUm',[100 150 150]);
opts=struct('askMaskAtStart',false,'askAtlasAtStart',false,'debugRethrow',true,'roiNameTable',T,'roiMinVox',4);
f=FunctionalConnectivity(data,folder,'FC_test',opts);guard=onCleanup(@()delete(f)); %#ok<NASGU>
set(f,'WindowState','normal','Position',[10 10 1200 720]);deConfUSIon_FC_layout(f);
q=fusiScanSequence('init',struct('loadedFile',files{3},'fusiSequencePowerFile',files{3}),I,1,'scan8');
for k=1:3,q.scans{k}=fusiScanSequence('describe',files{k},files{k},sprintf('scan%d',k+5),TRs(k));end
q.active=3;q.originalKey=q.scans{3}.key;q.scans{2}.includeTrace=false;
setappdata(f,'FUSIFCScanSequenceRequest',q);press(f,'FCScansOrder');
s=guidata(f);verifyEqual(test,s.currentSubject,3);verifyEmpty(test,s.subjects(1).I4);
sizePreset=findall(f,'Tag','FCSeedSizePreset');sizePreset.Value=3;sizePreset.Callback(sizePreset,[]);
verifyEqual(test,guidata(f).seedBoxSize,8);
setappdata(f,'FUSIFCCompareRequest',[3 1]);press(f,'FCCompareScans');
r=getappdata(f,'FUSIFCScanComparison');verifyEqual(test,r.scanIndices,[3 1]);
verifyLessThan(test,max(abs(r.difference(:))),.15);
s=guidata(f);verifyEmpty(test,s.roiResults{2,1});
ui=getappdata(f,'FUSIFCLayout');h=findall(ui.roiPanel,'Style','popupmenu');
strings={h.String};verifyTrue(test,any(cellfun(@(v)iscell(v)&&any(contains(v,'primary motor area')),strings)));
for mode=[2 3 1]
    h=findall(f,'Tag','FCHemisphereMode');h.Value=mode;h.Callback(h,[]);s=guidata(f);
    expected={'both','left','right'};verifyEqual(test,s.roiHemiMode,expected{mode});
end
s=guidata(f);verifyFalse(test,s.subjects(1).mask(1,1,1));verifyNotEmpty(test,s.roiResults{1,1});
% Same 10-second local interval yields 10 samples at TR=1 and 5 at TR=2.
s=guidata(f);s.fcScanSequence.scans{2}.includeTrace=true;s.fcEpochMode='during';
s.currentEpoch=3;s.fcInjStartMin=10/60;s.fcInjEndMin=20/60;guidata(f,s);
setappdata(f,'FUSIFCCompareRequest',[1 2]);press(f,'FCCompareScans');
s=guidata(f);verifyEqual(test,s.roiResults{1,3}.timeIdx,11:20);
verifyEqual(test,s.roiResults{2,3}.timeIdx,6:10);
comparison=getappdata(f,'FUSIFCScanComparison');
verifyLessThan(test,comparison.comparison(1,2),-.8);
verifyTrue(test,comparison.sliceRegionOnly);verifyEqual(test,comparison.displaySlice,2);
s.fcScanSequence.scans{3}.includeTrace=false;guidata(f,s);
export=getappdata(f,'FUSIFCExportGroup');file=export();B=load(file,'fcBundle');
verifyEqual(test,[B.fcBundle.subjects.hasROI],[true true false]);
verifyEqual(test,[B.fcBundle.subjects(1:2).nSlices],[3 3]);
verifyEqual(test,B.fcBundle.subjects(1).sourceFile,files{1});
verifyEqual(test,B.fcBundle.subjects(1).powerFile,files{1});
verifyEqual(test,B.fcBundle.subjects(1).animalId,'Animal');
verifyEqual(test,numel(B.fcBundle.subjects(1).sliceResults),3);
[FC,~]=GroupAnalysis_FC('loadFCGroupBundlesFromFiles',{file},struct());
verifyEqual(test,FC.nSubjects,2);verifyEqual(test,FC.subjects(1).roiSourceFile,files{1});
verifyEqual(test,FC.subjects(1).animalId,'Animal');verifyEqual(test,numel(FC.subjects(1).sliceResults),3);
verifyEqual(test,FC.subjects(1).R,B.fcBundle.subjects(1).R);
verifyEqual(test,FC.subjects(1).baseline,B.fcBundle.subjects(1).baseline);
verifyEqual(test,FC.subjects(1).maskPolicy,B.fcBundle.subjects(1).maskPolicy);
% Restore the original data even when its disk file is unavailable.
s=guidata(f);s.subjects(3).I4=[];s.fcScanSequence.scans{3}.file='';
s=fusiFCLoadScan(s,3);verifyEqual(test,s.subjects(3).I4,I);
end
function press(f,tag)
h=findall(f,'Tag',tag);h.Callback(h,[]);
end
