function tests=testFCCrossSlice
tests=functiontests(localfunctions);
end
function setupOnce(test)
deConfUSIon_setup();test.TestData.visibility=get(groot,'DefaultFigureVisible');set(groot,'DefaultFigureVisible','off');
test.TestData.folder=tempname;mkdir(test.TestData.folder);rng(211);
T=80;t=(1:T)';traces=[sin(t/5) cos(t/7) -sin(t/5) sin(t/5)+.2*cos(t/7)];
A=zeros(8,12,3,'int32');A(:,1:6,1)=-1;A(:,7:12,1)=1;A(:,1:6,3)=-2;A(:,7:12,3)=2;
I=100+randn(8,12,3,T,'single');ids=[-1 1 -2 2];
for k=1:4,mask=A==ids(k);D=reshape(I,[],T);D(mask(:),:)=repmat(single(100+traces(:,k)'),nnz(mask),1);I=reshape(D,size(I));end
table=struct('labels',ids','names',{{'L_CPu';'R_CPu';'L_DG';'R_DG'}}, ...
 'fullNames',{{'Left caudoputamen';'Right caudoputamen';'Left dentate gyrus';'Right dentate gyrus'}});
test.TestData.traces=traces;
test.TestData.D=struct('I',I,'TR',1,'roiAtlas',A,'voxelSizeUm',[100 150 150]);
test.TestData.opts=struct('askMaskAtStart',false,'askAtlasAtStart',false,'debugRethrow',true,'roiNameTable',table,'roiMinVox',2);
test.TestData.f=FunctionalConnectivity(test.TestData.D,test.TestData.folder,'cross_slice',test.TestData.opts);
end
function teardownOnce(test)
if isgraphics(test.TestData.f),delete(test.TestData.f);end
set(groot,'DefaultFigureVisible',test.TestData.visibility);rmdir(test.TestData.folder,'s');
end
function testCrossSliceMathAndIdentity(test)
f=test.TestData.f;selectPairs(f,[-1 1 -2 2],[1 1 3 3]);pressCallback(f,'onComputeROICurrent');s=guidata(f);res=s.roiResults{1,1};
expected=fusiFCCorrelationMatrix(double(single(100+test.TestData.traces)));
verifyEqual(test,res.M,expected,'AbsTol',1e-10);verifyEqual(test,res.M(1,3),-1,'AbsTol',1e-10);
verifyEqual(test,res.roiSlices,[1;1;3;3]);verifyEqual(test,res.atlasLabels,[-1;1;-2;2]);
verifyEqual(test,res.meanTS,double(single(100+test.TestData.traces)),'AbsTol',1e-10);
verifyTrue(test,all(contains(res.fullNames,{'caudoputamen';'caudoputamen';'dentate gyrus';'dentate gyrus'})));
verifyTrue(test,startsWith(res.fullNames{1},'Left'));verifyTrue(test,startsWith(res.fullNames{2},'Right'));
verifyEqual(test,res.labelMap(2,2,3),res.labels(3));verifyEqual(test,res.labelMap(2,2,2),0);
catalogFcn=getappdata(f,'FUSIFCRegionCatalog');cat=catalogFcn();verifyTrue(test,all([cat.voxelCount]==48));verifyTrue(test,all(contains({cat.acronym},'slice')));
% Scrolling does not replace custom ROIs with just the current slice.
s.slice=2;guidata(f,s);pressCallback(f,'onShowHemisphere');g=findall(f,'Style','togglebutton','String','Graph');g.Callback(g,[]);
axesList=findall(f,'Type','axes');found=false;
for ax=reshape(axesList,1,[])
 if isappdata(ax,'FUSIFCNetwork'),data=getappdata(ax,'FUSIFCNetwork');verifySize(test,data.R,[4 4]);found=true;end
end
verifyTrue(test,found);h=findall(f,'Tag','FCGraphExplanation');txt=strjoin(cellstr(h.String),' ');verifyTrue(test,contains(txt,'not anatomical distance'));verifyTrue(test,contains(txt,'not a significance test'));
end
function testSameRegionDifferentSlicesStaysSeparate(test)
s=guidata(test.TestData.f);subj=s.subjects(1);subj.roiAtlas(:,:,2)=subj.roiAtlas(:,:,1);
subj.mask(:,:,2)=true;subj.I4(:,:,2,:)=subj.I4(:,:,1,:)+reshape(single(sin((1:80)/3)),1,1,1,80);
q=struct('label',{-1,1,-1,1},'slice',{1,1,2,2});r=fusiFCRegionSliceResult(subj,q,1:80,2);
verifyEqual(test,numel(unique(abs(r.labels))),2);verifyNotEqual(test,r.labels(1),r.labels(3));
f=test.TestData.f;s.subjects(1)=subj;s.fcRegionSliceSelections=q;s.sliceRegionOnly=false;s.roiResults{1,1}=r;guidata(f,s);
h=findall(f,'Tag','FCHemisphereMode');h.Value=5;h.Callback(h,[]);g=findall(f,'Style','togglebutton','String','Graph');g.Callback(g,[]);
for ax=reshape(findall(f,'Type','axes'),1,[])
 if isappdata(ax,'FUSIFCNetwork'),data=getappdata(ax,'FUSIFCNetwork');verifySize(test,data.R,[2 2]);verifyTrue(test,all(contains(data.names,'slice')));end
end
% IDs are independent of entry order.
r2=fusiFCRegionSliceResult(subj,q([4 2 1 3]),1:80,2);verifyEqual(test,r2.labels,r.labels([4 2 1 3]));
h.Value=1;h.Callback(h,[]);
end
function testMissingAnatomyDoesNotFallBackToOtherSlice(test)
s=guidata(test.TestData.f);q=struct('label',{-2,-1},'slice',{1,1});
verifyError(test,@()fusiFCRegionSliceResult(s.subjects(1),q,1:80,2),'deConfUSIon:FCEmptyRegionSlice');
end
function testLiveDialogAddsAcrossSlices(test)
s=guidata(test.TestData.f);failure=[];initial=struct('label',{},'slice',{});
timerObj=timer('ExecutionMode','fixedSpacing','Period',.2,'StartDelay',.2,'TimerFcn',@operate);
guard=onCleanup(@()delete(timerObj));start(timerObj); %#ok<NASGU>
[selected,ok]=fusiFCRegionSliceDialog(s.subjects(1),initial,[1 3]);stop(timerObj);
if ~isempty(failure),rethrow(failure);end
verifyTrue(test,ok);verifyEqual(test,[selected.slice],[1 3]);verifyEqual(test,[selected.label],[-1 -2]);
 function operate(~,~)
  d=findall(0,'Tag','FCRegionSliceDialog');if isempty(d)||~isappdata(d,'FUSIFCRegionSliceReady'),return;end
  try
   search=findall(d,'Tag','FCRegionSliceSearch');list=findall(d,'Tag','FCRegionSliceList');z=findall(d,'Tag','FCRegionSliceZ');
   search.String='Left caudoputamen';search.Callback(search,[]);verifyEqual(test,numel(cellstr(list.String)),1);
   z.String='1';button=findall(d,'String','Add regions at these slices');button.Callback(button,[]);
   search.String='Left dentate';search.Callback(search,[]);z.String='3';button.Callback(button,[]);
   entries=findall(d,'Tag','FCRegionSliceEntries');verifySize(test,entries.Data,[2 4]);verifyEqual(test,cell2mat(entries.Data(:,4)),[48;48]);
   button=findall(d,'String','Use regions / slices');button.Callback(button,[]);
  catch ME
   failure=ME;button=findall(d,'String','Cancel');button.Callback(button,[]);
  end
 end
end
function testMaskedSpatialSmoothing(test)
A=zeros(13,13);A(7,7)=1;mask=true(size(A));mask(:,10:13)=false;A(7,5)=NaN;
B=fusiFCSmoothCorrelation(A,mask,1);verifyTrue(test,isnan(B(7,5)));verifyTrue(test,all(isnan(B(:,10:13)),'all'));
verifyGreaterThan(test,B(7,8),0);verifyLessThan(test,B(7,7),1);verifyTrue(test,all(abs(B(isfinite(B)))<=1));
constant=fusiFCSmoothCorrelation(.4*ones(13),mask,2);verifyEqual(test,constant(mask),.4*ones(nnz(mask),1),'AbsTol',1e-12);
verifyEqual(test,fusiFCSmoothCorrelation(A,mask,0),A);
end
function testDisplaySmoothingDoesNotChangeResults(test)
f=test.TestData.f;selectPairs(f,[-1 -2],[1 3]);pressCallback(f,'onComputeROICurrent');pressCallback(f,'onComputeSeedCurrent');before=guidata(f);
h=findall(f,'Tag','FCOverlaySmooth');verifyFalse(test,logical(h.Value));h.Value=1;h.Callback(h,[]);after=guidata(f);
verifyEqual(test,after.seedResults,before.seedResults);verifyEqual(test,after.roiResults,before.roiResults);verifyTrue(test,after.fcOverlaySmooth);
h.Value=0;h.Callback(h,[]);
end
function testNavigationCaptionsDoNotOverlapControls(test)
f=test.TestData.f;
for dims=[1200 720;1900 1000]'
 f.WindowState='normal';f.Position=[20 20 dims'];deConfUSIon_FC_layout(f);ui=getappdata(f,'FUSIFCLayout');
 caption=findall(f,'Tag','FCLabel_Calculate_slices');p=getpixelposition(caption);editPos=getpixelposition(ui.range);scanPos=getpixelposition(ui.subject);
 verifyGreaterThanOrEqual(test,p(2),editPos(2)+editPos(4)+3);verifyLessThanOrEqual(test,p(2)+p(4),scanPos(2)-3);
 verifyGreaterThanOrEqual(test,p(4),22);
end
end
function testGroupRoundtripKeepsCrossSliceIdentity(test)
f=test.TestData.f;selectPairs(f,[-1 1 -2 2],[1 1 3 3]);pressCallback(f,'onComputeROICurrent');source=guidata(f).roiResults{1,1};
pressCallback(f,'onExportGroupAnalysis');files=dir(fullfile(test.TestData.folder,'GroupAnalysis','FunctionalConnectivity','FC_GroupBundle*.mat'));
verifyNotEmpty(test,files);S=load(fullfile(files(end).folder,files(end).name),'fcBundle');record=S.fcBundle.subjects(1);
verifyEqual(test,record.labels,source.labels);verifyEqual(test,record.labelMap,source.labelMap);verifyEqual(test,record.roiScope,'region-slice');
verifyEqual(test,record.roiSlices,source.roiSlices);verifyEqual(test,record.atlasLabels,source.atlasLabels);
verifyEqual(test,record.R,source.M);verifyEqual(test,record.sliceResults(1).labels,source.labels(1:2));
FC=GroupAnalysis_FC('loadFCGroupBundlesFromFiles',{fullfile(files(end).folder,files(end).name)},struct());
verifyEqual(test,FC.subjects(1).roiSlices,source.roiSlices);verifyEqual(test,FC.subjects(1).labelMap,source.labelMap);
[R,~]=fusiFCGroupMatrix(FC.subjects(1),'All slices');verifyEqual(test,R,source.M);
mixed=struct('roiScope',{'region-slice','volume'});
verifyError(test,@()fusiFCValidateAtlasGroup(mixed),'deConfUSIon:FCROIScopeMismatch');
end
function testSaveKeepsExactSpatialLabels(test)
f=test.TestData.f;selectPairs(f,[-1 -2],[1 3]);pressCallback(f,'onComputeROICurrent');s=guidata(f);source=s.roiResults{1,1};
pressCallback(f,'onSaveAll');path=fullfile(s.qcDir,['FC_GroupBundle_' s.tag '.mat']);verifyTrue(test,isfile(path));
B=load(path,'fcBundle');verifyEqual(test,B.fcBundle.subjects(1).labelMap,source.labelMap);
verifyEqual(test,B.fcBundle.subjects(1).roiSlices,source.roiSlices);verifyEqual(test,B.fcBundle.subjects(1).labels,source.labels);
end
function selectPairs(f,ids,slices)
q=struct('label',num2cell(ids),'slice',num2cell(slices));setappdata(f,'FUSIFCRegionSliceRequest',q);press(f,'FCRegionSlices');
end
function press(f,tag),h=findall(f,'Tag',tag);h.Callback(h,[]);end
function pressCallback(f,name)
hs=findall(f,'Type','uicontrol');for h=reshape(hs,1,[]),if isa(h.Callback,'function_handle')&&endsWith(func2str(h.Callback),['/' name]),h.Callback(h,[]);return;end,end
error('Missing callback %s',name);
end
