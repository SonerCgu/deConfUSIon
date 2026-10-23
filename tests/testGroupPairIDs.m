function tests=testGroupPairIDs
tests=functiontests(localfunctions);
end

function setupOnce(~)
addpath(fileparts(fileparts(mfilename('fullpath'))));deConfUSIon_setup();
end

function testEditingAnimalUpdatesOnlyAutomaticPairs(testCase)
T=rows({'1355','1355','1287','1287'});
T(:,5)={'1336';'1336';'custom-pair';'custom-pair'};
[T,changed]=gaSyncAnimalPairIDs(T,{'1336';'1336';'old-name';'old-name'});
verifyEqual(testCase,T(:,5),{'1355';'1355';'custom-pair';'custom-pair'});
verifyEqual(testCase,changed,[1 2]);
end

function testOldListRepairsHistorical1336After1355Correction(testCase)
T=legacyRows();
[fixed,changed]=gaSyncAnimalPairIDs(T);
verifyEqual(testCase,fixed(:,5),fixed(:,2));verifyEqual(testCase,changed,[3 4]);
% Exercise the paired-test entry point even without first opening the GUI.
v=[2;9;4;13];g=T(:,3);S=settings();
actual=GroupAnalysis_Common('computeStats',v,g,S,T);
verifyEqual(testCase,actual.pairing.nPairs,2);
verifyEqual(testCase,actual.pairing.keys,{'1336','1355'});
verifyEqual(testCase,actual.pairing.rows,[2 1;4 3]);
verifyEqual(testCase,actual.pairing.updatedPairIDRows,[3 4]);
for tail={'both','right','left'}
    S.testTail=tail{1};actual=GroupAnalysis_Common('computeStats',v,g,S,T);
    [~,p,ci,stats]=ttest([9;13],[2;4],'Tail',tail{1});
    verifyEqual(testCase,actual.p,p,'AbsTol',1e-12);
    verifyEqual(testCase,actual.t,stats.tstat,'AbsTol',1e-12);
    verifyEqual(testCase,actual.ci,ci(:)','AbsTol',1e-10);
end
order=[4 1 3 2];shuffled=GroupAnalysis_Common('computeStats',v(order),g(order),S,T(order,:));
verifyEqual(testCase,shuffled.p,actual.p,'AbsTol',1e-12);
end

function testSavedCorrectionAndCustomPairLabelsSurviveRoundTrip(testCase)
T=legacyRows();T{1,5}='custom-match';T{2,5}='custom-match';
subj=gaSyncAnimalPairIDs(T);file=[tempname '.mat'];guard=onCleanup(@()delete(file)); %#ok<NASGU>
save(file,'subj');L=load(file);fixed=gaSyncAnimalPairIDs(L.subj);
verifyEqual(testCase,fixed,subj);verifyEqual(testCase,fixed(1:2,5),{'custom-match';'custom-match'});
verifyEqual(testCase,fixed(3:4,5),{'1355';'1355'});
end

function testConflictingSourcesDoNotRewriteCustomPairID(testCase)
T=rows({'1355','1355'});T(:,5)={'1336'};
T(:,6)={fullfile(tempdir,'RGRO_260817_1024_MM_B6J_1287_scan3.mat')};
T(:,7)={fullfile(tempdir,'RGRO_260817_1024_MM_B6J_1336_scan13','ROI_mean.txt')};
[fixed,changed]=gaSyncAnimalPairIDs(T);
verifyEqual(testCase,fixed(:,5),{'1336';'1336'});verifyEmpty(testCase,changed);
end

function testRepeatedScanIsStillRejectedAsDuplicateAnimal(testCase)
T=legacyRows();T(3:4,2)={'1336'};
verifyError(testCase,@()GroupAnalysis_Common('computeStats',[2;9;4;13],T(:,3),settings(),T), ...
    'GroupAnalysis:Pairing');
end

function testGUIEditKeepsHiddenPairInSyncAndInvalidatesOldResult(testCase)
f=GroupAnalysis();guard=onCleanup(@()delete(f));f.Visible='off'; %#ok<NASGU>
S=guidata(f);S.subj=rows({'1336','1336'});S.subj(:,5)={'1336'};
S.previewConnectAnimals=false;S.testType='None';S.lastROI=struct('oldResult',true);
V=repmat({''},2,10);V(:,1)={true};V(:,2)=S.subj(:,2);V(:,5)=S.subj(:,3);V(:,6)=S.subj(:,4);
S.hTable.Data=V;guidata(f,S);
for row=1:2
    V=S.hTable.Data;V{row,2}='1355';S.hTable.Data=V;
    S.hTable.CellEditCallback(S.hTable,struct('Indices',[row 2],'PreviousData','1336','NewData','1355'));
    S=guidata(f);
end
verifyEqual(testCase,S.subj(:,2),{'1355';'1355'});
verifyEqual(testCase,S.subj(:,5),{'1355';'1355'});verifyEmpty(testCase,fieldnames(S.lastROI));
end

function T=legacyRows()
T=rows({'1336','1336','1355','1355'});T(:,5)={'1336'};
for r=1:4
    scan=18;if r>2,scan=13;end
    T{r,7}=fullfile(tempdir,sprintf('RGRO_260817_1024_MM_B6J_1336_scan%d',scan),'ROI','ROI_mean.txt');
end
end

function T=rows(ids)
T=repmat({''},numel(ids),9);T(:,1)={true};T(:,2)=ids(:);
T(:,3)=repmat({'Control';'PACAP'},numel(ids)/2,1);
T(:,4)=repmat({'CondB';'CondA'},numel(ids)/2,1);
end

function S=settings()
S=struct('testType','Paired t-test (matched PairID / animal)','alpha',.05, ...
    'testTail','right','colorMode','Scheme','manualGroupA','PACAP','manualGroupB','Control');
end
