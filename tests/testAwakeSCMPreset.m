function tests=testAwakeSCMPreset
tests=functiontests(localfunctions);
end
function setupOnce(test)
test.applyFixture(matlab.unittest.fixtures.PathFixture(fileparts(fileparts(mfilename('fullpath')))));
end
function testPresetOrder(test)
s=standardizedAnalysis('E'); s=s([s.run]);
verifyEqual(test,{s.name},{'PCA / ICA','Imregdemons','Mask Editor','Time-Course Viewer','SCM GUI'});
verifyEqual(test,s(1).pcaDropPC,1); verifyEqual(test,s(1).pcaAutoApply,1);
verifyEqual(test,s(2).nsub,50); verifyEqual(test,s(5).base1,30);
verifyEqual(test,[s(5).cmin s(5).cmax s(5).amin s(5).amax],[0 30 5 10]);
end
function testShortScanWindows(test)
[w,ok]=scmAwakeSearchWindow(10,61); verifyTrue(test,ok); verifyEqual(test,w,[240 600]);
[w,ok]=scmAwakeSearchWindow(10,101); verifyTrue(test,ok); verifyEqual(test,w,[240 960]);
[~,ok]=scmAwakeSearchWindow(10,40); verifyFalse(test,ok);
[~,ok]=scmAwakeSearchWindow(10,20); verifyFalse(test,ok);
[~,ok]=scmAwakeSearchWindow(100,5); verifyFalse(test,ok); % Frame grid cannot hold three samples after minute 4.
end
function testSpatialUnits(test)
c=scmSpatialCalibration(struct('voxelSize',[.1 .05 .2])); verifyTrue(test,all(isnan(c.spacingUm)));
c=scmSpatialCalibration(struct('voxelSize',[.1 .05 .2],'voxelSizeUnits','mm'));
verifyEqual(test,c.spacingUm,[100 50 200],'AbsTol',1e-10);
p=struct('meta',struct('rawMetadata',struct('voxelSize',[.1 .05 .2],'nifti',struct('SpaceUnits','Millimeter'))));
c=scmSpatialCalibration(p); verifyEqual(test,c.spacingUm,[100 50 200],'AbsTol',1e-10);
c=scmSpatialCalibration(struct('voxelSizeUm',[NaN 50 200])); verifyTrue(test,all(isnan(c.spacingUm)));
end
function testNativeScannerMetadata(test)
m=struct('imageDim',3,'voxelSize',[.1 .15 .15],'imageSize',[90 64 54], ...
    'origen',[7 0 0],'imageType','doppler');
p=struct('scmSizeYXZ',[90 64 54],'meta',struct('rawMetadata',struct('metadata',m)));
c=scmSpatialCalibration(p); verifyEqual(test,c.spacingUm,[100 150 150],'AbsTol',1e-8);
p.scmSizeYXZ=[90 128 54]; c=scmSpatialCalibration(p); verifyTrue(test,all(isnan(c.spacingUm)));
p.scmSizeYXZ=[267 256 1]; m.voxelSize=[.045 .045]; m.imageDim=2; m.imageSize=[267 256];
p.meta.rawMetadata.metadata=m; c=scmSpatialCalibration(p); verifyEqual(test,c.spacingUm(1:2),[45 45]);
verifyTrue(test,isnan(c.spacingUm(3)));
ref=scmProbeSpacing('matrix'); verifyEqual(test,ref.spacingUm,[100 150 150]);
end
function testAwakeSearchAndRuler(test)
folder=test.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
fid=fopen(fullfile(folder.Folder,'questdlg.m'),'w');fprintf(fid,'function x=questdlg(varargin)\nx=''Ruler settings'';\nend\n');fclose(fid);
fid=fopen(fullfile(folder.Folder,'listdlg.m'),'w');fprintf(fid,'function [i,ok]=listdlg(varargin)\ni=3;ok=true;\nend\n');fclose(fid);
test.applyFixture(matlab.unittest.fixtures.PathFixture(folder.Folder));
s=standardizedAnalysis('E'); step=s(find(strcmp({s.name},'SCM GUI'),1));
setappdata(0,'deconf_std_workflow_step',step); cleanup=onCleanup(@clearStep); %#ok<NASGU>
A=zeros(20,24,2,61,'single'); A(5:9,3:7,:,16:28)=15; A(11:15,17:21,:,16:28)=8;
f=SCM_gui(A,ones(20,24,2),10,struct('voxelSizeUm',[100 100 200]),struct('start',0,'end',60,'sigStart',240,'sigEnd',600),61,'awake_test');
g=onCleanup(@()closeFigures(f)); %#ok<NASGU>
a=getappdata(f,'AutomaticROISelections'); verifyEqual(test,numel(a),4);
verifyEqual(test,get(findall(f,'Tag','SCM_DisplayRange'),'String'),'0 30');
verifyEqual(test,get(findall(f,'Tag','SCM_SmoothingSigma'),'String'),'0');
b=findall(f,'Tag','SCM_ScaleSettings'); cb=get(b,'Callback'); cb(b,[]);
r=findall(f,'Tag','SCM_PhysicalRuler'); verifyNotEmpty(test,r);
lineObjects=findall(f,'Type','line','Tag','SCM_PhysicalRuler');
spans=arrayfun(@(h)max(get(h,'XData'))-min(get(h,'XData')),lineObjects);
verifyTrue(test,any(abs(spans-15)<1e-9)); % 1500 um = 15 columns at 100 um.
frame=getframe(f); imwrite(frame.cdata,fullfile(tempdir,'scm_awake_scale.png'));
end
function clearStep
if isappdata(0,'deconf_std_workflow_step'),rmappdata(0,'deconf_std_workflow_step');end
end
function closeFigures(f)
for r=reshape(findall(0,'Tag','AutomaticROICandidateReview'),1,[])
 if isequal(getappdata(r,'SCMOwner'),f),delete(r);end
end
if isgraphics(f),delete(f);end
end

