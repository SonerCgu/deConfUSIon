function tests=testAutomaticSCM
tests=functiontests(localfunctions);
end

function setupOnce(test)
test.applyFixture(matlab.unittest.fixtures.PathFixture(fileparts(fileparts(mfilename('fullpath')))));
end

function testDialogSmoke(test)
ctx=struct('sizeYXZ',[12 16 2],'slice',1,'roiSize',2,'baselineSec',[0 10], ...
    'signalSec',[40 70],'TR',10,'nT',8,'underlay',@(z)repmat(linspace(0,1,16),12,1,3),'mask',@(z)true(12,16));
t=timer('StartDelay',2,'ExecutionMode','fixedSpacing','Period',1,'TimerFcn',@acceptDialog); cleanup=onCleanup(@()delete(t)); %#ok<NASGU>
start(t); opt=scmAutoSearchDialog(ctx);
verifyNotEmpty(test,opt); verifyTrue(test,opt.bilateral); verifyEqual(test,opt.signalSec,[40 70],'AbsTol',1e-6);
verifyEqual(test,opt.slice,2);
    function acceptDialog(~,~)
        f=findall(0,'Type','figure','Name','Automatic SCM | time and anatomical search regions');
        if isempty(f)||~isequal(getappdata(f,'SCMSearchDialogReady'),true), return; end
        stop(t);
        try
            cb=findall(f,'Style','checkbox','String','Separate left/right target and control');
            set(cb,'Value',1); fn=get(cb,'Callback'); fn(cb,[]); drawnow;
            sl=findall(f,'Tag','SearchSlice'); set(sl,'Value',2); fn=get(sl,'Callback'); fn(sl,[]);
            verifyEqual(test,get(f,'Color'),[0 0 0]);
            set(findall(f,'Tag','SearchPlateau'),'String','99');
            b=findall(f,'Tag','SearchGo'); fn=get(b,'Callback'); fn(b,[]);
            verifyTrue(test,contains(get(findall(f,'Tag','SearchStatus'),'String'),'Cannot start'));
            set(findall(f,'Tag','SearchPlateau'),'String','0');
            frame=getframe(f); imwrite(frame.cdata,fullfile(tempdir,'deConfUSIon_auto_search_preview.png'));
            b=findall(f,'Tag','SearchGo'); fn=get(b,'Callback'); fn(b,[]);
        catch ME
            delete(f); rethrow(ME);
        end
    end
end

function testBilateralArtifactExclusion(test)
% Large superficial artifact must not displace either intracerebral ROI.
A=zeros(12,16,8,'single'); A(1:2,:,5:8)=1000;
A(5:6,3:4,5:8)=12; A(8:9,12:13,5:8)=7;
o=options(1); o.boundsXY=[1 16 3 12];
r=scmSearchRegions(o,1,true(12,16)); cfg=config(1);
left=AutomaticSCM('search',A,10,cfg,r(1).mask);
right=AutomaticSCM('search',A,10,cfg,r(2).mask);
verifyEqual(test,left.boundsXY,[3 4 5 6]); verifyEqual(test,left.meanPSC,12,'AbsTol',1e-9);
verifyEqual(test,right.boundsXY,[12 13 8 9]); verifyEqual(test,right.meanPSC,7,'AbsTol',1e-9);
verifyEqual(test,{r.role},{'Target','Control'});
o.leftIsTarget=false; r=scmSearchRegions(o,1,true(12,16));
verifyEqual(test,{r.role},{'Control','Target'});
end

function testWindowChangesMaximum(test)
A=zeros(12,16,8); A(4:5,3:4,3:4)=20; A(8:9,5:6,5:8)=8;
cfg=config(1); cfg.signalSec=[20 30];
r=AutomaticSCM('search',A,10,cfg,true(12,16)); verifyEqual(test,r.boundsXY,[3 4 4 5]);
cfg.signalSec=[40 70]; r=AutomaticSCM('search',A,10,cfg,true(12,16));
verifyEqual(test,r.boundsXY,[5 6 8 9]); verifyEqual(test,r.signalFrames,5:8);
end

function testSliceSpecificPolygonAndFullSupport(test)
o=options(2); o.polygons{2,1}=[2.5 3.5;4.5 3.5;4.5 5.5;2.5 5.5];
A=zeros(12,16,2,8); A(8:9,5:6,:,5:8)=50; A(4:5,3:4,2,5:8)=9;
r=scmSearchRegions(o,2,true(12,16));
c=AutomaticSCM('search',A,10,config(2),r(1).mask);
verifyEqual(test,c.boundsXY,[3 4 4 5]); verifyEqual(test,c.meanPSC,9,'AbsTol',1e-9);
r=scmSearchRegions(o,1,true(12,16));
c=AutomaticSCM('search',A,10,config(1),r(1).mask); verifyEqual(test,c.meanPSC,50,'AbsTol',1e-9);
r=scmSearchRegions(o,2,true(12,16)); r(1).mask(4,3)=false;
verifyError(test,@()AutomaticSCM('search',A,10,config(2),r(1).mask),'deConfUSIon:SearchCoverage');
end

function testInvalidRegionsAndFiniteCoverage(test)
o=options(1); o.polygons{1,1}=[1 1;12 1;12 12;1 12];
verifyError(test,@()scmSearchRegions(o,1,true(12,16)),'deConfUSIon:SearchOverlap');
o=options(1); o.boundsXY=[0 16 1 12];
verifyError(test,@()scmSearchRegions(o,1,true(12,16)),'deConfUSIon:SearchBounds');
A=zeros(12,16,8); A(:,:,6)=NaN;
verifyError(test,@()AutomaticSCM('search',A,10,config(1),true(12,16)),'deConfUSIon:SearchCoverage');
cfg=config(1); cfg.signalSec=[40 100];
verifyError(test,@()AutomaticSCM('search',zeros(size(A)),10,cfg,true(12,16)),'deConfUSIon:ProtocolWindow');
end

function testExactRebaseAndFixedProtocol(test)
A=10*ones(12,16,8); A(4:5,3:4,5:8)=32;
c=AutomaticSCM('search',A,10,config(1),true(12,16)); verifyEqual(test,c.meanPSC,20,'AbsTol',1e-9);
p=struct('name','test','referenceSizeYXZ',[12 16 1],'roiSizeYX',[2 2], ...
    'targetXYZ',[3 4 1],'controlXYZ',[12 8 1],'baselineSec',[0 10],'signalSec',[40 70]);
r=AutomaticSCM(A,10,p,[],'synthetic');
verifyEqual(test,r.rois(1).signalMean,20,'AbsTol',1e-9); verifyEqual(test,r.rois(2).signalMean,0);
end

function o=options(nz)
o=struct('boundsXY',[1 16 1 12],'bilateral',true,'splitX',8,'leftIsTarget',true);
o.polygons=cell(nz,2);
end
function c=config(z)
c=struct('size',2,'slice',z,'baselineSec',[0 10],'signalSec',[40 70]);
end

function testSlidingPlateau(test)
A=zeros(12,16,31); % 10 s TR, search 30-300 s; 60 s plateau.
A(4:5,3:4,11:17)=20; A(8:9,12:13,8)=100; % spike averages below sustained plateau
cfg=config(1); cfg.signalSec=[30 300]; cfg.plateauSec=60;
r=AutomaticSCM('search',A,10,cfg,true(12,16));
verifyEqual(test,r.boundsXY,[3 4 4 5]); verifyEqual(test,r.signalSec,[100 160]);
verifyEqual(test,r.meanPSC,20,'AbsTol',1e-9); verifyEqual(test,r.actualWindowSpanSec,60);
verifyEqual(test,r.searchIntervalSec,[30 300]); verifyEqual(test,r.windowsTested,22);
A(4,3,12)=NaN; r=AutomaticSCM('search',A,10,cfg,true(12,16));
verifyTrue(test,all(isfinite(r.meanPSC))); % a nonfinite plateau cannot retain full support
verifyNotEqual(test,r.boundsXY,[3 4 4 5]);
end

function testPlateauSamplingAndBounds(test)
[starts,width]=scmSearchWindows([35 240],60,33.5,20);
verifyEqual(test,starts,3:6); verifyEqual(test,width,3);
verifyError(test,@()scmSearchWindows([35 90],60,33.5,20),'deConfUSIon:PlateauWindow');
verifyError(test,@()scmSearchWindows([0 200],-1,10,30),'deConfUSIon:PlateauWindow');
end

function testStartToMarkedCandidates(test)
runMarkedCandidates(test,1,false);
end
function test3DVolumeModeStart(test)
runMarkedCandidates(test,2,true);
end
function testSharedWindowGUI(test)
runMarkedCandidates(test,2,false,true);
end
function runMarkedCandidates(test,nz,volMode,shared)
if nargin<4, shared=false; end
% Exercise the real SCM button -> dialog -> analysis -> markers/review workflow.
folder=test.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
fid=fopen(fullfile(folder.Folder,'questdlg.m'),'w');
fprintf(fid,'function x=questdlg(varargin)\nx=''Find and review ROI''; if strcmp(varargin{2},''ROI export label''), x=''Target''; end\nend\n'); fclose(fid);
fid=fopen(fullfile(folder.Folder,'listdlg.m'),'w'); fprintf(fid,'function [i,ok]=listdlg(varargin)\ni=1; ok=true;\nend\n'); fclose(fid);
fid=fopen(fullfile(folder.Folder,'msgbox.m'),'w'); fprintf(fid,'function h=msgbox(varargin)\nh=[];\nend\n'); fclose(fid);
exportRoot=fullfile(folder.Folder,'AnalysedData'); mkdir(exportRoot);
test.applyFixture(matlab.unittest.fixtures.PathFixture(folder.Folder));
A=zeros(12,16,31,'single'); A(5:6,3:4,11:17)=220; A(8:9,12:13,18:24)=12;
baseline=struct('start',0,'end',10,'sigStart',30,'sigEnd',300);
if volMode, baseline=struct('mode','vol','start',1,'end',2,'sigStart',4,'sigEnd',31); end
if nz>1, A=repmat(reshape(A,12,16,1,31),1,1,nz,1); end
f=SCM_gui(A,ones(12,16,nz),10,struct('selectorRoot',exportRoot),baseline,31,'automatic_synthetic_test');
cleanup=onCleanup(@()closeTestFigures(f)); %#ok<NASGU>
% Inactive hover must survive slice navigation and discard queued previews.
h=findall(f,'Tag','SCM_HoverToggle'); toggle=get(h,'Callback');
verifyEqual(test,get(h,'String'),'HOVER ACTIVE');
toggle(h,[]); verifyEqual(test,get(h,'String'),'HOVER INACTIVE');
verifyFalse(test,getappdata(h,'HoverActive'));
sliders=findall(f,'Style','slider');
for sh=reshape(sliders,1,[])
    cb=get(sh,'Callback');
    if isa(cb,'function_handle') && contains(func2str(cb),'sliceChanged'), cb(sh,[]); end
end
verifyEqual(test,get(h,'String'),'HOVER INACTIVE');
move=get(f,'WindowButtonMotionFcn'); move(f,[]); pause(.1);
verifyFalse(test,getappdata(h,'HoverActive'));
toggle(h,[]); verifyEqual(test,get(h,'String'),'HOVER ACTIVE');

t=timer('StartDelay',1,'ExecutionMode','fixedSpacing','Period',1,'TimerFcn',@startSearch);
timerCleanup=onCleanup(@()delete(t)); %#ok<NASGU>
start(t); b=findall(f,'Style','pushbutton','String','Automatic analysis'); fn=get(b,'Callback'); fn(b,[]);
% A second unsaved run must replace previews and reuse consecutive IDs.
start(t); b=findall(f,'Style','pushbutton','String','Automatic analysis'); fn=get(b,'Callback'); fn(b,[]);
audit=getappdata(f,'AutomaticROISelections');
verifyEqual(test,numel(audit),2*nz);
verifyEqual(test,cellfun(@(c)c.roiId,audit),1:2*nz);
if numel(audit)==2*nz
    verifyEqual(test,{audit{1}.role,audit{2}.role},{'Target','Control'});
    verifyEqual(test,audit{1}.signalSec,[100 160]);
    if shared, verifyEqual(test,audit{2}.signalSec,[100 160]);
    else, verifyEqual(test,audit{2}.signalSec,[170 230]); end
end
reviews=findall(0,'Tag','AutomaticROICandidateReview');
reviews=reviews(arrayfun(@(h)isequal(getappdata(h,'SCMOwner'),f),reviews));
verifyNotEmpty(test,reviews);
if ~isempty(reviews)
    tbl=findall(reviews,'Type','uitable'); initialRows=get(tbl,'Data');
    u=findall(reviews,'Tag','CandidateTimeUnits'); set(u,'Value',2); cb=get(u,'Callback'); cb(u,[]);
    secondsRows=get(tbl,'Data'); headers=get(tbl,'ColumnName'); verifyEqual(test,headers{8},'Start (s)');
    mins=str2double(regexprep(initialRows(:,8),'<[^>]*>',''));
    secs=str2double(regexprep(secondsRows(:,8),'<[^>]*>',''));
    verifyEqual(test,secs,60*mins,'AbsTol',1e-3);
    set(u,'Value',1); cb(u,[]);

    verifyTrue(test,all(cellfun(@(x)contains(x,'#ff3030'),initialRows(:,1))));
    frame=getframe(reviews); imwrite(frame.cdata,fullfile(tempdir,'deConfUSIon_candidate_review.png'));
    fn=get(tbl,'CellSelectionCallback'); fn(tbl,struct('Indices',[2 1]));
    role=findall(reviews,'Tag','CandidateRoleFilter'); set(role,'Value',3); fn=get(role,'Callback'); fn(role,[]);
    rows=get(tbl,'Data'); verifyTrue(test,all(strcmp(regexprep(rows(:,3),'<[^>]*>',''),'Control')));
    sortBy=findall(reviews,'Tag','CandidateSort'); set(sortBy,'Value',4); fn=get(sortBy,'Callback'); fn(sortBy,[]);
    rows=get(tbl,'Data'); verifyEqual(test,str2double(regexprep(rows(:,1),'<[^>]*>',''))',(nz:-1:1));
    % Select one Control while filtered, then a Target from the full table.
    edit=get(tbl,'CellEditCallback'); edit(tbl,struct('Indices',[1 10],'NewData',true));
    chosen=getappdata(tbl,'ExportROIIds'); verifyEqual(test,numel(chosen),1);
    set(role,'Value',2); fn=get(role,'Callback'); fn(role,[]);
    edit(tbl,struct('Indices',[1 10],'NewData',true));
    verifyEqual(test,numel(getappdata(tbl,'ExportROIIds')),2);
    rows=get(tbl,'Data'); verifyTrue(test,contains(rows{1,2},'#16803c'));
    % Toggling off/on updates the same stable selection, not the row number.
    edit(tbl,struct('Indices',[1 10],'NewData',false));
    verifyEqual(test,getappdata(tbl,'ExportROIIds'),chosen);
    edit(tbl,struct('Indices',[1 10],'NewData',true));
    b=findall(reviews,'String','Export SELECTED ROIs (TXT)'); fn=get(b,'Callback'); fn(b,[]);
    files=dir(fullfile(exportRoot,'ROI','*.txt')); verifyEqual(test,numel(files),2);
    contents=arrayfun(@(d)fileread(fullfile(d.folder,d.name)),files,'UniformOutput',false);
    verifyEqual(test,sum(cellfun(@(x)contains(x,'# ROI_LABEL: Ctrl'),contents)),1);
    verifyEqual(test,sum(cellfun(@(x)contains(x,'# ROI_LABEL: Target'),contents)),1);
    pause(.8); % Exercise the deliberate export-button debounce, not a second-click race.
    b=findall(f,'String','EXPORT ROIs (TXT)'); fn=get(b,'Callback'); fn(b,[]);
    files=dir(fullfile(exportRoot,'ROI','*.txt')); verifyEqual(test,numel(files),2+2*nz);
    % Saved marks remain identifiable when a later preview is generated.
    start(t); b=findall(f,'String','Automatic analysis'); fn=get(b,'Callback'); fn(b,[]);
    savedAudit=getappdata(f,'AutomaticROISelections');
    verifyEqual(test,cellfun(@(c)c.roiId,savedAudit),1:4*nz);
    b=findall(f,'Tag','SCM_ClearAllROIs'); fn=get(b,'Callback'); fn(b,[]);
    verifyEmpty(test,getappdata(f,'AutomaticROISelections')); verifyFalse(test,isgraphics(reviews));
    start(t); b=findall(f,'String','Automatic analysis'); fn=get(b,'Callback'); fn(b,[]);
    fresh=getappdata(f,'AutomaticROISelections');
    verifyEqual(test,cellfun(@(c)c.roiId,fresh),1:2*nz);
    verifyEqual(test,numel(dir(fullfile(exportRoot,'ROI','*.txt'))),2+2*nz);
end
closeTestFigures(f);
    function startSearch(~,~)
        dialog=findall(0,'Type','figure','Name','Automatic SCM | time and anatomical search regions');
        if isempty(dialog)||~isequal(getappdata(dialog,'SCMSearchDialogReady'),true), return; end
        stop(t);
        set(findall(dialog,'Tag','SearchROISize'),'String','2');
        set(findall(dialog,'Tag','SearchTime'),'String','0.5 5');
        set(findall(dialog,'Tag','SearchPlateau'),'String','1');
        set(findall(dialog,'Tag','SearchWindowMode'),'Value',1+double(shared));
        goButton=findall(dialog,'Tag','SearchGo'); goCallback=get(goButton,'Callback'); goCallback(goButton,[]);
    end
end
function closeTestFigures(f)
reviews=findall(0,'Tag','AutomaticROICandidateReview');
for r=reshape(reviews,1,[])
    if isequal(getappdata(r,'SCMOwner'),f), delete(r); end
end
if isgraphics(f), delete(f); end
end

function testSharedWindowAndRanking(test)
A=zeros(12,16,2,31); A(5:6,3:4,1,11:17)=20; A(5:6,3:4,2,18:24)=250;
A(8:9,12:13,:,11:17)=15; A(8:9,12:13,:,18:24)=10;
o=options(2); o.sharedWindow=true; cfg=config(1); cfg.signalSec=[30 300]; cfg.plateauSec=60;
[c,skip]=scmSearchCandidates(A,10,cfg,o,1:2,@(~)true(12,16));
verifyEmpty(test,skip); verifyEqual(test,numel(c),4);
verifyTrue(test,all(cellfun(@(r)isequal(r.signalSec,[170 230]),c)));
verifyTrue(test,all(cellfun(@(r)strcmp(r.windowMode,'shared'),c)));
verifyEqual(test,c{3}.meanPSC,250,'AbsTol',1e-9); verifyEqual(test,c{2}.meanPSC,10,'AbsTol',1e-9);
verifyEqual(test,scmCandidateOrder(c,'All',[1 2],1),[3 2 4 1]);
verifyEqual(test,scmCandidateOrder(c,'Control',[1 2],4),[4 2]);
verifyEqual(test,scmCandidateOrder(c,'Target',[2 2],3),3);
verifyEmpty(test,scmCandidateOrder(c,'Search',[1 2],1));
o.sharedWindow=false; c=scmSearchCandidates(A,10,cfg,o,1:2,@(~)true(12,16));
verifyEqual(test,c{1}.signalSec,[100 160]); verifyEqual(test,c{3}.signalSec,[170 230]);
end
