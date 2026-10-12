function tests=testFCUsability
tests=functiontests(localfunctions);
end
function setupOnce(test)
deConfUSIon_setup();test.TestData.visible=get(groot,'DefaultFigureVisible');set(groot,'DefaultFigureVisible','off');
test.TestData.folder=tempname;mkdir(test.TestData.folder);rng(19);
I=100+randn(12,18,3,100,'single');A=-ones(12,18,3,'int32');A(:,10:18,:)=1;
T=struct('labels',[-1;1],'names',{{'L_MOp';'R_MOp'}},'fullNames',{{'Left primary motor area';'Right primary motor area'}});
test.TestData.D=struct('I',I,'TR',1,'roiAtlas',A,'voxelSizeUm',[100 150 150]);
test.TestData.opts=struct('askMaskAtStart',false,'askAtlasAtStart',false,'debugRethrow',true,'roiNameTable',T,'roiMinVox',2);
test.TestData.f=FunctionalConnectivity(test.TestData.D,test.TestData.folder,'usability',test.TestData.opts);
end
function teardownOnce(test)
if isfield(test.TestData,'f')&&isgraphics(test.TestData.f),delete(test.TestData.f);end
set(groot,'DefaultFigureVisible',test.TestData.visible);rmdir(test.TestData.folder,'s');
end
function testSettingsFitWithoutScroll(test)
f=test.TestData.f;verifyTrue(test,getappdata(f,'FUSIFCStartupReady'));
for size=[1200 720;1400 900;1900 1000]'
 f.WindowState='normal';f.Position=[20 20 size'];deConfUSIon_FC_layout(f);
 for k=1:4
  ui=getappdata(f,'FUSIFCLayout');h=ui.pageButtons(k);h.Callback(h,[]);ui=getappdata(f,'FUSIFCLayout');
  verifyEmpty(test,findall(f,'Tag','FCSettingsScroll'));
  bounds=getpixelposition(ui.pages(k));controls=findall(ui.pages(k),'Type','uicontrol','Visible','on');
  for c=reshape(controls,1,[])
   p=getpixelposition(c);verifyGreaterThanOrEqual(test,p(2),0,c.Tag);verifyLessThanOrEqual(test,p(2)+p(4),bounds(4),c.Tag);
  end
 end
end
end
function testNoImplicitAtlasCropAndNoMaskOverlay(test)
f=test.TestData.f;s=guidata(f);s.subjects(1).roiAtlas(6,6,2)=0;
s.subjects(1)=fusiFCExcludeNonTissue(s.subjects(1));verifyTrue(test,s.subjects(1).mask(6,6,2));
s.showMaskLine=true;s.overlayMode='mask';guidata(f,s);press(f,'FCHideOverlays');
s=guidata(f);verifyFalse(test,s.showMaskLine);verifyEqual(test,s.overlayMode,'seed_fc');
h=findall(f,'Tag','FCMaskBoundary');verifyTrue(test,all(h.AlphaData==0,'all'));verifyEqual(test,findall(f,'Tag','FCOverlayMode').Value,1);
end
function testReadableRulerAfterOtherAxisStyle(test)
f=test.TestData.f;ax=findall(f,'Tag','FCSeedMap');s=guidata(f);
ax.XColor=[.2 .2 .2];ax.XLabel.Color=[.2 .2 .2];fusiFCImageGeometry(ax,[100 150 150],[s.Y s.X],s.fcRuler);
verifyGreaterThan(test,min(ax.XColor),.9);verifyGreaterThan(test,min(ax.XLabel.Color),.9);
bar=findall(ax,'Tag','SCM_PhysicalRuler','Type','text');verifyEqual(test,bar.Color,[1 1 1]);verifyEqual(test,bar.BackgroundColor,[0 0 0]);
end
function testCatalogHasNamesAcronymsAndCounts(test)
f=test.TestData.f;catalogFcn=getappdata(f,'FUSIFCRegionCatalog');catalog=catalogFcn();
verifyTrue(test,all(contains({catalog.name},'primary motor area')));
verifyTrue(test,all(contains({catalog.acronym},'MOp')));verifyTrue(test,all([catalog.voxelCount]>0));
verifyFalse(test,any(contains({catalog.acronym},'primary motor')));
verifyTrue(test,all(fusiRegionSearchMatch({catalog.acronym},{catalog.name},'motor cortex')));
end
function testColourRangeAndVerticalLegend(test)
f=test.TestData.f;h=findall(f,'Tag','FCPearsonLimit');h(1).String='.4';h(1).Callback(h(1),[]);
verifyEqual(test,numel(h),3);ui=getappdata(f,'FUSIFCLayout');verifyTrue(test,any([h.Parent]==ui.displayPanel));
verifyEqual(test,guidata(f).roiCLim,.4);verifyTrue(test,all(strcmp(get(h,'String'),'0.4')));
pressCallback(f,'onComputeROICurrent');h=findall(f,'Style','togglebutton','String','Graph');h.Callback(h,[]);
axesList=findall(f,'Type','axes');found=false;
for ax=reshape(axesList,1,[])
 if strcmp(ax.YLabel.String,'Pearson r')&&numel(ax.YTick)==3
  ticks=str2double(string(ax.YTickLabel));verifyEqual(test,ax.YDir,'normal');verifyEqual(test,ticks(:),[-.4;0;.4]);found=true;
 end
end
verifyTrue(test,found);
end
function testMergedHemisphereSelection(test)
f=test.TestData.f;h=findall(f,'Tag','FCHemisphereMode');h.Value=5;h.Callback(h,[]);
verifyEqual(test,guidata(f).roiHemiMode,'merged');pressCallback(f,'onComputeROICurrent');
g=findall(f,'Style','togglebutton','String','Graph');g.Callback(g,[]);
axesList=findall(f,'Type','axes');found=false;
for ax=reshape(axesList,1,[])
 if isappdata(ax,'FUSIFCNetwork'),r=getappdata(ax,'FUSIFCNetwork');verifySize(test,r.R,[1 1]);verifyEqual(test,r.R,1,'AbsTol',1e-12);found=true;end
end
verifyTrue(test,found);h.Value=1;h.Callback(h,[]);
end
function testAnalysedTRChangesLocalBaselineSamples(test)
f=test.TestData.f;D=test.TestData.D;b=struct('start',0,'end',10,'mode','sec');
setappdata(f,'FUSIFCBaselineRequest',b);press(f,'FCBaselineSource');
h=findall(f,'Tag','FCAnalysedTR');h.String='2';h.Callback(h,[]);s=guidata(f);
verifyEqual(test,s.subjects(1).TR,2);verifyEqual(test,s.fcScanSequence.scans{1}.TR,2);
P=computePSC(D.I,2,struct('interpol',1),b);verifyEqual(test,s.subjects(1).I4,P.PSC,'AbsTol',single(2e-5));
verifyEmpty(test,s.roiResults{1,1});h.String='1';h.Callback(h,[]);press(f,'FCResetBaseline');
end
function testBilateralFCUsesVoxelWeightsAndSignedIDs(test)
Y=4;X=8;T=60;A=repmat(int32([-1 -1 1 1 -2 2 2 2]),Y,1);ids=[-1 1 -2 2];
traces=[sin((1:T)'/3) cos((1:T)'/6) sin((1:T)'/4) cos((1:T)'/8)];
V=zeros(Y*X,T,'single');
for k=1:4,V(A(:)==ids(k),:)=100+repmat(single(traces(:,k)'),nnz(A==ids(k)),1);end
D=struct('I',reshape(V,Y,X,1,T),'TR',1,'roiAtlas',A);
names=struct('labels',ids(:),'names',{{'L_MOp';'R_MOp';'L_CPu';'R_CPu'}}, ...
 'fullNames',{{'Left primary motor area';'Right primary motor area';'Left caudoputamen';'Right caudoputamen'}});
opts=test.TestData.opts;opts.roiNameTable=names;
f=FunctionalConnectivity(D,test.TestData.folder,'weighted',opts);guard=onCleanup(@()delete(f)); %#ok<NASGU>
h=findall(f,'Tag','FCHemisphereMode');h.Value=5;h.Callback(h,[]);pressCallback(f,'onComputeROICurrent');
h=findall(f,'Style','togglebutton','String','Graph');h.Callback(h,[]);
res=guidata(f).roiResults{1,1};merged=zeros(T,2);
for k=1:2,group=abs(res.labels)==k;merged(:,k)=res.meanTS(:,group)*res.counts(group)/sum(res.counts(group));end
expected=corrcoef(merged);found=false;
for ax=reshape(findall(f,'Type','axes'),1,[])
 if isappdata(ax,'FUSIFCNetwork'),r=getappdata(ax,'FUSIFCNetwork');verifySize(test,r.R,[2 2]);verifyEqual(test,r.R(1,2),expected(1,2),'AbsTol',1e-12);found=true;end
end
verifyTrue(test,found);c=getappdata(f,'FUSIFCRegionCatalog');cat=c();verifyFalse(test,any(startsWith({cat.name},{'Left','Right'})));
end
function testSelectionAppliesToHeatmapAndNetwork(test)
f=test.TestData.f;setappdata(f,'FUSIFCRegionSelectionRequest',1);pressCallback(f,'onCustomRegionList');s=guidata(f);
verifyEqual(test,s.fcSelectedRegionIdx,1);
h=findall(f,'Style','togglebutton','String','Graph');h.Callback(h,[]);
ax=findall(f,'Type','axes');found=false;
for a=reshape(ax,1,[]),if isappdata(a,'FUSIFCNetwork'),result=getappdata(a,'FUSIFCNetwork');verifySize(test,result.R,[1 1]);found=true;end,end
verifyTrue(test,found);pressCallback(f,'onClearCustomRegions');
end
function testExternalBaselineAndReset(test)
f=test.TestData.f;ref=fusiBaselineReference('build',test.TestData.D.I,1,[0 10]);
ref.mean=ref.mean*2;b=struct('start',0,'end',10,'mode','sec','reference',ref);
setappdata(f,'FUSIFCBaselineRequest',b);press(f,'FCBaselineSource');s=guidata(f);
verifyEqual(test,s.subjects(1).functionalSource,'PSC');expected=(test.TestData.D.I-ref.mean)./ref.mean*100;
verifyEqual(test,s.subjects(1).I4,expected,'AbsTol',single(2e-5));
press(f,'FCResetBaseline');s=guidata(f);verifyEqual(test,s.subjects(1).I4,test.TestData.D.I);verifyEqual(test,s.subjects(1).functionalSource,'I');
end
function testUnderlayImportsMaskEditorSemantics(test)
f=test.TestData.f;D=test.TestData.D;maskEditorInfo=struct('hasBrainMask',true,'hasOverlayMask',true);
anatomical_reference=mean(D.I,4);brainMask=true(size(anatomical_reference));brainMask(1,:,:)=false;
overlayMask=true(size(brainMask));overlayMask(:,1,:)=false;brainMaskIsInclude=true;overlayMaskIsInclude=true;
file=fullfile(test.TestData.folder,'MaskEditor.mat');save(file,'maskEditorInfo','anatomical_reference','brainMask','overlayMask','brainMaskIsInclude','overlayMaskIsInclude');
loadUnderlay=getappdata(f,'FUSILoadUnderlay');loadUnderlay(file);s=guidata(f);
verifyEqual(test,s.subjects(1).baseMask,brainMask&overlayMask);verifyEqual(test,s.subjects(1).maskPolicy,'provided');verifyFalse(test,s.showMaskLine);
verifyTrue(test,all(isnan(s.subjects(1).displayUnderlay(1,:,:)),'all'));
end
function testNameListDoesNotLoseAnatomy(test)
f=test.TestData.f;file=fullfile(test.TestData.folder,'Names.txt');fid=fopen(file,'w');fprintf(fid,'1,MOp\n');fclose(fid);
loadNames=getappdata(f,'FUSILoadRegionNames');loadNames(file);s=guidata(f);
verifyTrue(test,all(contains(s.subjects(1).roiNameTable.fullNames,'primary motor area')));
delete(findall(groot,'Name','Atlas region abbreviations'));
end
function testNetworkSignsAndPaperExport(test)
f=figure('Visible','off');guard=onCleanup(@()delete(f));ax=axes(f); %#ok<NASGU>
R=[1 .3 -.8;.3 1 .6;-.8 .6 1];cmap=[0 0 1;1 1 1;1 0 0];
[g,h]=fusiFCNetworkPlot(ax,R,{'A';'B';'C'},.2,1,cmap);
verifyEqual(test,numedges(g),3);verifyEqual(test,h.EdgeCData(:),g.Edges.Weight(:));
verifyEqual(test,sort(g.Edges.Weight),[-.8;.3;.6]);
r=struct('R',R,'names',{{'A';'B';'C'}},'fullNames',{{'Area A';'Area B';'Area C'}},'threshold',.2,'colourLimit',1,'cmap',cmap,'caption','Synthetic verification');
files=fusiFCExportPaperFigure(r,fullfile(test.TestData.folder,'paper'));
verifyTrue(test,all(cellfun(@isfile,files)));S=load(files{4});verifyEqual(test,S.result.R,R);
csv=readcell(files{5});verifyEqual(test,csv{2,4},-.8);key=readtable(files{6});verifyEqual(test,key.FullName,{'Area A';'Area B';'Area C'});
verifyEqual(test,key.Abbreviation,{'A';'B';'C'});
end
function press(f,tag),h=findall(f,'Tag',tag);h.Callback(h,[]);end
function pressCallback(f,name)
for h=reshape(findall(f,'Type','uicontrol'),1,[])
 if isa(h.Callback,'function_handle')&&endsWith(func2str(h.Callback),['/' name]),h.Callback(h,[]);return;end
end
error('No callback %s',name);
end
