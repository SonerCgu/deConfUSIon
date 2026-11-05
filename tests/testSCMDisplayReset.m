function testSCMDisplayReset()
% Real callbacks: B-mode appearance/blend/reset and checked native atlas layers.
addpath(fileparts(fileparts(mfilename('fullpath'))));deConfUSIon_setup();
work=tempname;mkdir(work);oldVisible=get(0,'DefaultFigureVisible');
set(0,'DefaultFigureVisible','off');owned=containers.Map({'figures'},{gobjects(0)});
guard=onCleanup(@()cleanup(work,oldVisible,owned)); %#ok<NASGU>
ny=24;nx=32;plane=reshape(single(linspace(0,1,ny*nx)),ny,nx);
rgb=uint8(repmat(102+25*plane,[1 1 3]));bfile=fullfile(work,'bmode.png');imwrite(rgb,bfile);
PSC=repmat(reshape(single(linspace(0,5,80)),1,1,80),ny,nx,1);
par=struct('loadedFile',fullfile(work,'raw.mat'),'exportPath',work);
baseline=struct('start',0,'end',10,'sigStart',40,'sigEnd',60,'mode','sec');
f=SCM_gui(PSC,plane,1,par,baseline,80);owned('figures')=f;
getData=getappdata(f,'FUSIUnderlayData');initial=getData();
loadB=getappdata(f,'FUSILoadBMode');loadB(bfile);b=getData();
assert(b.bmode.mode==2&&strcmp(get(findobj(f,'Tag','SCM_BModeBlend'),'Enable'),'on'));
assert(range(b.displayRGB(:))>.8,'Low-contrast B-mode was not auto-windowed.');
auto=findobj(f,'Tag','SCM_BModeAutoContrast');set(auto,'Value',0);invoke(auto);raw=getData();
assert(range(raw.displayRGB(:))<.15,'Disabling B-mode auto contrast changed the saved pixel scale.');
set(auto,'Value',1);invoke(auto);
gamma=findobj(f,'Tag','SCM_UnderlayGamma');set(gamma,'Value',.45);invoke(gamma);bright=getData();
assert(~isequal(bright.displayRGB,b.displayRGB)&&isequal(bright.appearance,initial.appearance),'B-mode gamma leaked into Doppler appearance.');
contrast=findobj(f,'Tag','SCM_UnderlayContrast');set(contrast,'Value',1.4);invoke(contrast);
brightness=findobj(f,'Tag','SCM_UnderlayBrightness');set(brightness,'Value',.05);invoke(brightness);adjusted=getData();
blend=findobj(f,'Tag','SCM_BModeBlend');set(blend,'Value',.35);invoke(blend);mixed=getData();
expected=.65*single(initial.displayRGB)+.35*adjusted.displayRGB;
assert(mixed.bmode.mode==3&&max(abs(mixed.displayRGB(:)-expected(:)))<1e-6,'Dragging pure B-mode did not blend with unchanged Doppler.');
reset=findobj(f,'Tag','SCM_ResetNative');invoke(reset);native=getData();
assert(native.bmode.mode==1&&sameRGB(native.displayRGB,initial.displayRGB),'Reset left B-mode active.');
assert(isequal(native.bmode.appearance,adjusted.bmode.appearance),'Reset lost the B-mode appearance.');
assert(isequaln(native.PSC,initial.PSC)&&isequaln(native.mask,initial.mask),'Display controls modified measurements.');
source=findobj(f,'Tag','SCM_BackgroundSource');set(source,'Value',2);invoke(source);again=getData();
assert(sameRGB(again.displayRGB,adjusted.displayRGB),'B-mode appearance was not retained after native reset.');
invoke(reset);

atlasMode='regions';atlasRegionLabels2D=zeros(ny,nx);atlasRegionLabels2D(4:20,3:14)=1;atlasRegionLabels2D(4:20,19:30)=2;
atlasInfoRegions=struct('name',{{'Region one','Region two'}},'acr',{{'R1','R2'}},'rgb',[1 0 0;0 1 0]);
atlasUnderlayRGB=fusiRegionLabelRGB(atlasRegionLabels2D,atlasInfoRegions);
atlasFile=fullfile(work,'native_regions.mat');save(atlasFile,'atlasMode','atlasRegionLabels2D','atlasInfoRegions','atlasUnderlayRGB');
loadAtlas=getappdata(f,'FUSILoadUnderlay');loadAtlas(atlasFile);
names=findobj(f,'Tag','AtlasRegionLabelsToggle');lines=findobj(f,'Tag','AtlasRegionLinesToggle');
set(names,'Value',1);invoke(names);set(lines,'Value',1);invoke(lines);
assert(~isempty(findobj(f,'Tag','AtlasRegionAbbreviation','Visible','on'))&&~isempty(findobj(f,'Tag','AtlasRegionBoundary','Visible','on')));
invoke(reset);native=getData();
assert(get(names,'Value')==1&&get(lines,'Value')==1&&sameRGB(native.displayRGB,initial.displayRGB));
assert(isequal(native.nativeRegionAnnotations.labels,atlasRegionLabels2D));
assert(~isempty(findobj(f,'Tag','AtlasRegionAbbreviation','Visible','on'))&&~isempty(findobj(f,'Tag','AtlasRegionBoundary','Visible','on')),'Checked atlas overlays disappeared on native reset.');
invoke(reset);set(source,'Value',2);invoke(source);
assert(~isempty(findobj(f,'Tag','AtlasRegionAbbreviation','Visible','on')),'Native atlas labels were lost on B-mode selection.');
set(names,'Value',0);invoke(names);
assert(isempty(findobj(f,'Tag','AtlasRegionAbbreviation','Visible','on'))&&~isempty(findobj(f,'Tag','AtlasRegionBoundary','Visible','on')));
set(lines,'Value',0);invoke(lines);invoke(reset);
assert(get(names,'Value')==0&&get(lines,'Value')==0&&isempty(findobj(f,'Tag','AtlasRegionBoundary','Visible','on')));

ctx=struct('labels',atlasRegionLabels2D,'info',atlasInfoRegions);
T=eye(3);T(3,1)=2;shifted=ctx;shifted.labels=imwarp(ctx.labels,affine2d(T),'nearest','OutputView',imref2d([ny nx]));
mapping=struct('kind','2D','matrices',{{T}},'sourceSlices',1,'transpose',false);
restored=fusiNativeRegionOverlay(shifted,mapping,[ny nx 1]);assert(isequal(restored.labels,ctx.labels));
transposed=ctx;transposed.labels=ctx.labels';mapping.matrices={eye(3)};mapping.transpose=true;
restored=fusiNativeRegionOverlay(transposed,mapping,[ny nx 1]);assert(isequal(restored.labels,ctx.labels));
mapping.transpose=false;mapping.sourceSlices=2;
restored=fusiNativeRegionOverlay(ctx,mapping,[ny nx 3]);assert(isequal(restored.labels(:,:,2),ctx.labels)&&~any(restored.labels(:,:,[1 3]),'all'));
L=reshape(uint16(1:60),4,5,3);volume=struct('labels',permute(L,[2 3 1]),'info',atlasInfoRegions);
mapping=struct('kind','3DDirect','transform',struct('M',eye(4),'displayPermutation',[2 3 1]));
restored=fusiNativeRegionOverlay(volume,mapping,[4 5 3]);assert(isequal(restored.labels,L));
g=struct('originalSize',[4 5 3],'permutation',[1 2 3],'originalSpacingUm',[1 1 1],'atlasVoxelSizeUm',[1 1 1]);
mapping=struct('kind','3D','transform',struct('M',eye(4),'scanGeometry',g));
restored=fusiNativeRegionOverlay(volume,mapping,[4 5 3]);assert(isequal(restored.labels,L));
fprintf('PASS: B-mode auto contrast, independent tone, direct blend, native reset, checked atlas layers, 2D shift/transpose/motor planes and 3D native annotation sampling.\n');
end
function invoke(h),cb=get(h,'Callback');cb(h,[]);end
function yes=sameRGB(a,b),yes=isequal(size(a),size(b))&&max(abs(double(a(:))-double(b(:))))<1e-6;end
function cleanup(work,visible,owned)
f=owned('figures');delete(f(isgraphics(f)));set(0,'DefaultFigureVisible',visible);
assert(startsWith(work,tempdir));if isfolder(work),rmdir(work,'s');end
end
