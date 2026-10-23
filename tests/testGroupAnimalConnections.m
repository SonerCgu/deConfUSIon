function tests=testGroupAnimalConnections
tests=functiontests(localfunctions);
end

function setupOnce(~)
addpath(fileparts(fileparts(mfilename('fullpath'))));deConfUSIon_setup();
end

function testSourceHeadersDistinguishAnimalsInOneSharedFolder(testCase)
fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
folder=fullfile(fixture.Folder,'RGRO_260407_1024_MM_B6J_9999','ROI_Bundle_shared');mkdir(folder);
T=rows({'','', '', ''},{'Control','PACAP','Control','PACAP'});
animals={'1413','1413','1005','1005'};
for k=1:4
    file=fullfile(folder,sprintf('ROI_Scan%d_mean.txt',k));writeROI(file,animals{k});T{k,7}=file;
    [id,info]=gaAnimalIdentity(file);verifyEqual(testCase,id,animals{k});verifyFalse(testCase,info.conflict);
end
[f,ax]=newAxes();guard=onCleanup(@()delete(f)); %#ok<NASGU>
values=[12;25;9;18];x=[.9;1.9;1.1;2.1];
[lines,ids,report]=GroupAnalysis_Common('connectAnimalPoints',ax,T,values,x,{'Control','PACAP'},[0 0 0],[.2 .4 .6]);
verifyEqual(testCase,sort(ids),{'1005','1413'});verifyEqual(testCase,numel(lines),2);
verifyEmpty(testCase,report.conflictingRows);verifyEmpty(testCase,report.missingRows);
for k=1:numel(lines)
    indices=lines(k).UserData.rows;
    verifyEqual(testCase,lines(k).XData,x(indices)');verifyEqual(testCase,lines(k).YData,values(indices)');
    verifyEqual(testCase,lines(k).Color,[.2 .4 .6]);
end
end

function testFilenameAndNearestAnimalParentBeatOuterFolder(testCase)
root=fullfile(tempdir,'RGRO_260407_1024_MM_B6J_9999');
file=fullfile(root,'RGRO_261018_1024_MM_B6J_1413','ROI_Bundle_20261022','ROI_Control_mean.txt');
[id,info]=gaAnimalIdentity(file);verifyEqual(testCase,id,'1413');verifyEqual(testCase,info.source,'Nearest animal folder');
file=fullfile(root,'ROI_RGRO_261018_1024_MM_B6J_1005_scan3_mean.txt');
[id,info]=gaAnimalIdentity(file);verifyEqual(testCase,id,'1005');verifyEqual(testCase,info.source,'Recording filename');
end

function testGenericFoldersAndMissingIDsNeverCreatePairs(testCase)
T=rows({'N/A','Unknown'},{'Control','PACAP'});
T(:,7)={fullfile(tempdir,'Shared','ROI_Bundle_20261022','ROI_Control_mean.txt'); ...
    fullfile(tempdir,'Shared','ROI_Bundle_20261022','ROI_Target_mean.txt')};
[f,ax]=newAxes();guard=onCleanup(@()delete(f)); %#ok<NASGU>
[lines,~,report]=GroupAnalysis_Common('connectAnimalPoints',ax,T,[1;3],[1;2],{'Control','PACAP'},[0 0 0]);
verifyEmpty(testCase,lines);verifyEqual(testCase,report.missingRows,[1 2]);
end

function testDateAndYearFoldersAreNotAnimalIDs(testCase)
for folder={'2026','260407','20261022'}
    file=fullfile(tempdir,folder{1},'Shared_ROIs','ROI_Target_mean.txt');
    [id,~]=gaAnimalIdentity(file);verifyEmpty(testCase,id);
end
end

function testManuallyCorrectedTableIDOverridesHistoricalSourceLabel(testCase)
fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
T=rows({'1413','1413'},{'Control','PACAP'});
for k=1:2
    file=fullfile(fixture.Folder,sprintf('ROI_%d.txt',k));
    animals={'1413','1005'};writeROI(file,animals{k});T{k,7}=file;
end
[f,ax]=newAxes();guard=onCleanup(@()delete(f)); %#ok<NASGU>
[lines,ids,report]=GroupAnalysis_Common('connectAnimalPoints',ax,T,[1;3],[1;2],{'Control','PACAP'},[0 0 0]);
verifyEqual(testCase,numel(lines),1);verifyEqual(testCase,ids,{'1413'});
verifyEmpty(testCase,report.conflictingRows);verifyEqual(testCase,report.sourceMismatchRows,2);
verifyNotEmpty(testCase,report.identityNotes{2});
end

function testRepeated1336ConnectsOnlyWithinTheSameScan(testCase)
T=rows(repmat({'1336'},1,4),{'Control','PACAP','Control','PACAP'});
scans=[18 19 19 18];
for k=1:4
    T{k,7}=fullfile(tempdir,'RGRO_260817_1024_MM_B6J_1336', ...
        sprintf('RGRO_260817_1024_MM_B6J_1336_scan%d',scans(k)),'ROI','ROI_20261022','ROI_mean.txt');
end
[f,ax]=newAxes();guard=onCleanup(@()delete(f)); %#ok<NASGU>
[lines,ids,report]=GroupAnalysis_Common('connectAnimalPoints',ax,T,[1;8;3;5],[1;2;1.1;2.1],{'Control','PACAP'},[0 0 0]);
verifyEqual(testCase,numel(lines),2);verifyEqual(testCase,ids,{'1336','1336'});
verifyEmpty(testCase,report.duplicateIDs);
for k=1:2
    pairedRows=lines(k).UserData.rows;verifyEqual(testCase,scans(pairedRows(1)),scans(pairedRows(2)));
end
end

function testSameScanNumberOnDifferentDaysDoesNotCrossConnect(testCase)
T=rows(repmat({'1336'},1,4),{'Control','Control','PACAP','PACAP'});
dates={'260817','260831','260831','260817'};
for k=1:4
    T{k,7}=fullfile(tempdir,sprintf('RGRO_%s_1024_MM_B6J_1336_scan18',dates{k}),'ROI','ROI_mean.txt');
end
[f,ax]=newAxes();guard=onCleanup(@()delete(f)); %#ok<NASGU>
[lines,~,~]=GroupAnalysis_Common('connectAnimalPoints',ax,T,[1;2;3;4],[1;1.1;2;2.1],{'Control','PACAP'},[0 0 0]);
verifyEqual(testCase,numel(lines),2);
for k=1:2
    r=lines(k).UserData.rows;verifyEqual(testCase,dates{r(1)},dates{r(2)});
end
end

function test1287LegacyResolutionOrderAndFUSClockID(testCase)
file=fullfile(tempdir,'RGRO_260813_1024_MM_B6J_1287', ...
    'RGRO_13082026_MM_B6J_1024_1287_PACAPvscsf01nM_4_FUS_104646','ROI','ROI_20261021_170149','ROI_mean.txt');
[id,identity]=gaAnimalIdentity(file);verifyEqual(testCase,id,'1287');
verifyEqual(testCase,identity.recording.scanID,'fus104646');
verifyEqual(testCase,identity.recording.date,'20260813');
verifyEqual(testCase,GroupAnalysis_Common('guessSubjectID',file),'1287');
meta=GroupAnalysis_Common('extractMetaFromSources','','',file,'');verifyEqual(testCase,meta.animalID,'1287');
end

function testRepeatedScansInDifferentSessionsStaySeparate(testCase)
T=rows(repmat({'1336'},1,4),{'Control','Control','PACAP','PACAP'});
sessions=[1 2 2 1];
for k=1:4
    T{k,7}=fullfile(tempdir,'RGRO_260817_1024_MM_B6J_1336',sprintf('Session_%03d',sessions(k)), ...
        'FUS_2','ROI','ROI_mean.txt');
end
[f,ax]=newAxes();guard=onCleanup(@()delete(f)); %#ok<NASGU>
[lines,~,~]=GroupAnalysis_Common('connectAnimalPoints',ax,T,[1;2;3;4],[1;1.1;2;2.1],{'Control','PACAP'},[0 0 0]);
verifyEqual(testCase,numel(lines),2);
for k=1:2
    r=lines(k).UserData.rows;verifyEqual(testCase,sessions(r(1)),sessions(r(2)));
end
end

function test1355ManualRenameStillConnects(testCase)
T=rows({'1355','1355'},{'Control','PACAP'});
T(:,7)={fullfile(tempdir,'RGRO_260817_1024_MM_B6J_1336_scan13','ROI','ROI_Control.txt'); ...
    fullfile(tempdir,'RGRO_260817_1024_MM_B6J_1336_scan13','ROI','ROI_Target.txt')};
[f,ax]=newAxes();guard=onCleanup(@()delete(f)); %#ok<NASGU>
[lines,ids,report]=GroupAnalysis_Common('connectAnimalPoints',ax,T,[1;3],[1;2],{'Control','PACAP'},[0 0 0]);
verifyEqual(testCase,numel(lines),1);verifyEqual(testCase,ids,{'1355'});
verifyEqual(testCase,report.sourceMismatchRows,[1 2]);
end

function testDuplicateObservationsAreNotSilentlyAveraged(testCase)
T=rows({'1413','1413','1413'},{'Control','Control','PACAP'});
[f,ax]=newAxes();guard=onCleanup(@()delete(f)); %#ok<NASGU>
[lines,~,report]=GroupAnalysis_Common('connectAnimalPoints',ax,T,[1;2;4],[.9;1.1;2],{'Control','PACAP'},[0 0 0]);
verifyEmpty(testCase,lines);verifyEqual(testCase,report.duplicateIDs,{'1413'});
end

function testExplicitIDsNormalizeCaseAndWhitespaceWithoutPartialMatching(testCase)
T=rows({'  Animal-A1  ','a1','1413','14130'},{'Control','PACAP','Control','PACAP'});
[f,ax]=newAxes();guard=onCleanup(@()delete(f)); %#ok<NASGU>
[lines,ids,report]=GroupAnalysis_Common('connectAnimalPoints',ax,T,[1;2;3;4],[.9;1.9;1.1;2.1],{'Control','PACAP'},[0 0 0]);
verifyEqual(testCase,numel(lines),1);verifyEqual(testCase,ids,{'a1'});
verifyEqual(testCase,sort(report.unmatchedIDs),{'1413','14130'});
end

function testExportRendererLinesMeetTheJitteredAnimalMarkers(testCase)
T=rows({'1413','1005','1005','1413'},{'Control','Control','PACAP','PACAP'});
R=struct('mode','ROI Timecourse','metricVals',[1;2;5;4],'subjTable',{T}, ...
    'groupNames',{{'Control','PACAP'}},'metricName','Maximum signal change (%)');
S=struct('lastROI',R,'previewConnectAnimals',true,'previewPairColor',[.1 .4 .7]);
[f,ax]=newAxes();guard=onCleanup(@()delete(f)); %#ok<NASGU>
GroupAnalysis_Common('exportOnePreview',ax,2,S,'Light');
lines=findall(ax,'Tag','GA_ROI_ANIMAL_PAIR');verifyEqual(testCase,numel(lines),2);
markers=findall(ax,'Type','scatter');coordinates=[];
for k=1:numel(markers),coordinates=[coordinates;markers(k).XData(:) markers(k).YData(:)];end %#ok<AGROW>
for k=1:numel(lines)
    for p=1:numel(lines(k).XData)
        verifyTrue(testCase,any(all(abs(coordinates-[lines(k).XData(p) lines(k).YData(p)])<1e-12,2)));
    end
end
end

function testLineColorWidthAndOpacityOnLightAndDarkBackgrounds(testCase)
T=rows({'1336','1336'},{'Control','PACAP'});base=[.2 .4 .8];
for background={[1 1 1],[0 0 0]}
    [f,ax]=newAxes();guard=onCleanup(@()delete(f)); %#ok<NASGU>
    ax.Color=background{1};
    [connections,~,~]=GroupAnalysis_Common('connectAnimalPoints',ax,T,[3;8],[1;2], ...
        {'Control','PACAP'},[1 1 1],base,struct('lineWidth',3.5,'opacity',.3));
    verifyEqual(testCase,numel(connections),1);
    verifyEqual(testCase,connections.LineWidth,3.5);
    verifyEqual(testCase,connections.Color,.3*base+.7*background{1},'AbsTol',1e-12);
    verifyEqual(testCase,connections.UserData.lineColor,base);
    verifyEqual(testCase,connections.UserData.lineOpacity,.3);
    verifyEqual(testCase,connections.YData,[3 8]);
end
end

function testLineStyleSettingsReachExportRenderer(testCase)
T=rows({'1287','1287'},{'Control','PACAP'});
R=struct('mode','ROI Timecourse','metricVals',[2;7],'subjTable',{T}, ...
    'groupNames',{{'Control','PACAP'}},'metricName','Maximum signal change (%)');
S=struct('lastROI',R,'previewConnectAnimals',true,'previewPairColor',[1 0 0], ...
    'previewPairLineWidth',4,'previewPairOpacity',.4);
[f,ax]=newAxes();guard=onCleanup(@()delete(f)); %#ok<NASGU>
GroupAnalysis_Common('exportOnePreview',ax,2,S,'Light');
connections=findall(ax,'Tag','GA_ROI_ANIMAL_PAIR');
verifyEqual(testCase,connections.LineWidth,4);verifyEqual(testCase,connections.Color,[1 .6 .6],'AbsTol',1e-12);
verifyEqual(testCase,sort(connections.YData),[2 7]);verifyEqual(testCase,S.lastROI.metricVals,[2;7]);
end

function T=rows(ids,groups)
T=repmat({''},numel(ids),9);T(:,1)={true};T(:,2)=ids(:);T(:,3)=groups(:);
end

function writeROI(file,animal)
fid=fopen(file,'w');guard=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'# ROI export from SCM_gui: selected ROI ensemble\n');
fprintf(fid,'# FileLabel: RGRO_261018_1024_MM_B6J_%s_scan3\n',animal);
fprintf(fid,'# TraceSourceScan: RGRO_261018_1024_MM_B6J_%s_scan3\n',animal);
fprintf(fid,'# ROI_MEMBERS: []\n# columns: time_sec time_min PSC\n0 0 1\n');
end

function [f,ax]=newAxes()
f=figure('Visible','off','Color','w');ax=axes(f);hold(ax,'on');
end
