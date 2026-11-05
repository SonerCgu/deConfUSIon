function testBModeUnderlay(exampleFile)
% Regression coverage for static display loading and the real SCM callbacks.
addpath(fileparts(fileparts(mfilename('fullpath'))));deConfUSIon_setup();
work=tempname;mkdir(work);oldVisible=get(0,'DefaultFigureVisible');oldRng=rng;
set(0,'DefaultFigureVisible','off');owned=containers.Map({'figures'},{gobjects(0)});
guard=onCleanup(@()cleanupTest(work,oldVisible,oldRng,owned));
ny=24;nx=32;plane=reshape(single(1:ny*nx),ny,nx);
I=plane;metadata=struct('imageType','bmode');events=struct();
file=fullfile(work,'B-Mode_scan1.mat');save(file,'I','metadata','events');
[rgb,info]=fusiReadBModeUnderlay(file,[ny nx 1]);
assert(isequal(size(rgb),[ny nx 3])&&strcmp(info.field,'I')&&all(isfinite(rgb(:))));
assert(isequal(rgb(:,:,1),rgb(:,:,2)));
assert(rgb(2,1,1)<rgb(end-1,1,1),'Image row order was reversed.');
I=cat(3,plane,2*plane,3*plane);volume=fullfile(work,'three_planes.mat');save(volume,'I');
v=fusiReadBModeUnderlay(volume,[ny nx 3]);
assert(isequal(size(v),[ny nx 3 3])&&~isequal(v(:,:,:,1),v(:,:,:,3)));
I=cat(4,I,2*I);classic=fullfile(work,'time_classic.mat');modern=fullfile(work,'time_v73.mat');
save(classic,'I','-v7');save(modern,'I','-v7.3');
a=fusiReadBModeUnderlay(classic,[ny nx 3]);b=fusiReadBModeUnderlay(modern,[ny nx 3]);
assert(max(abs(a(:)-b(:)))<1e-6,'Classic and chunked temporal means disagree.');
movie=fusiReadBModeUnderlay(volume,[ny nx 1]);
assert(isequal(size(movie),[ny nx 3]));
png=fullfile(work,'anatomy.png');color=uint8(cat(3,255*ones(ny,nx),zeros(ny,nx),zeros(ny,nx)));
imwrite(color,png);[p,pngInfo]=fusiReadBModeUnderlay(png,[ny nx 1]);
assert(isempty(pngInfo.field)&&pngInfo.isRGB&&all(reshape(p(:,:,1),[],1)==1)&&all(reshape(p(:,:,2),[],1)==0));
% A static image must await an explicit slice assignment for a volume.
snapshotFile=fullfile(work,'B-Mode_snapshot.mat');I=reshape(single(1:543*616),543,616);save(snapshotFile,'I');
[snapshot,snapshotInfo]=fusiReadBModeUnderlay(snapshotFile,[90 64 54]);
assert(isequal(size(snapshot),[543 616 3])&&snapshotInfo.isSnapshot&&~snapshotInfo.isTemporalMean);
assert(isequal(snapshotInfo.spatialSize,[543 616 1])&&isequal(snapshotInfo.recordingSize,[90 64 54]));
assert(snapshotInfo.needsSliceMapping&&~any(snapshotInfo.validSlices),'An unmapped snapshot must not be repeated over a volume.');
assert(snapshot(1,1,1)<snapshot(end,end,1),'Snapshot orientation or intensity ordering changed.');
[shared,sharedInfo]=fusiReadBModeUnderlay(file,[ny nx 3]);
assert(isequal(size(shared),[ny nx 3])&&sharedInfo.needsSliceMapping,'A snapshot must not be expanded into a fabricated volume.');
bad=fullfile(work,'wrong_grid.mat');I=ones(ny+1,nx,2,2);save(bad,'I');
fails(@()fusiReadBModeUnderlay(bad,[ny nx 1]),'deConfUSIon:BModeGrid');
resized=fusiReadBModeUnderlay(volume,[ny+1 nx 3]);assert(isequal(size(resized),[ny+1 nx 3 3]));
[~,unassigned]=fusiReadBModeUnderlay(volume,[ny nx 4]);assert(unassigned.needsSliceMapping);
complexFile=fullfile(work,'iq.mat');I=complex(plane,plane);save(complexFile,'I');
fails(@()fusiReadBModeUnderlay(complexFile,[ny nx 1]),'deConfUSIon:BModeComplex');
emptyFile=fullfile(work,'empty.mat');I=NaN(ny,nx);save(emptyFile,'I');
fails(@()fusiReadBModeUnderlay(emptyFile,[ny nx 1]),'deConfUSIon:BModeEmpty');
fprintf('PASS: MAT, PNG, RGB, high-resolution static snapshot, 3-slice grayscale, classic/v7.3 temporal mean and invalid inputs.\n');

% Rendered vendor snapshot: incorrect 1x1 header, outer labels, 8x7 grid,
% 52 anatomical panels followed by four black padding cells.
montageFile=fullfile(work,'rendered_montage.mat');I=.94*ones(543,616);
xe=round(linspace(35,580,8));ye=round(linspace(13,523,9));
for k=1:56
    r=floor((k-1)/7)+1;c=mod(k-1,7)+1;value=0;if k<=52,value=.12+.012*k;end
    I(ye(r)+1:ye(r+1)-1,xe(c)+1:xe(c+1)-1)=value;
end
I(5:9,20:24)=0;metadata=struct('vendor_rendered_montage',true,'vendor_grid_rows',1,'vendor_grid_cols',1);
save(montageFile,'I','metadata');[source,header]=fusiReadBModeUnderlay(montageFile,[ny nx 54]);
assert(header.needsSliceMapping);
layout=fusiBModeMontageLayout(source,54,header.metadata);
assert(layout.rows==8&&layout.cols==7&&layout.count==52,'Montage grid/padding detection failed.');
[anatomy,anatomyInfo]=fusiReadBModeUnderlay(montageFile,[ny nx 54],layout);
assert(isequal(size(anatomy),[ny nx 3 54])&&all(anatomyInfo.validSlices(1:52))&&~any(anatomyInfo.validSlices(53:54)));
means=squeeze(mean(mean(mean(anatomy(:,:,:,1:52),1),2),3));assert(all(diff(means)>0),'Panel order changed or panel borders leaked into the anatomy.');
reverse=layout;reverse.sliceIndices=52:-1:1;
reversed=fusiReadBModeUnderlay(montageFile,[ny nx 54],reverse);
assert(isequal(reversed(:,:,:,1:52),anatomy(:,:,:,52:-1:1)));
columnOrder=layout;columnOrder.order='column-major';
columnMapped=fusiReadBModeUnderlay(montageFile,[ny nx 54],columnOrder);
assert(isequal(columnMapped(:,:,:,2),anatomy(:,:,:,8)),'Column-major panel order is incorrect.');
duplicate=layout;duplicate.sliceIndices(2)=1;
fails(@()fusiReadBModeUnderlay(montageFile,[ny nx 54],duplicate),'deConfUSIon:BModeMapping');
invalid=layout;invalid.bounds(1)=0;
fails(@()fusiReadBModeUnderlay(montageFile,[ny nx 54],invalid),'deConfUSIon:BModeMapping');
[~,cancelled]=fusiReadBModeUnderlay(montageFile,[ny nx 54],@(~,~)[]);
assert(cancelled.needsSliceMapping&&~any(cancelled.validSlices));
fprintf('PASS: rendered montage crop, 8x7 grid, 52 panels, row order, reversed assignments, missing slices, invalid and cancelled mappings.\n');
if nargin>0
    % Optional regression against the supplied 543x616 vendor capture.
    [realSource,realHeader]=fusiReadBModeUnderlay(exampleFile,[90 64 54]);
    realLayout=fusiBModeMontageLayout(realSource,54,realHeader.metadata);
    assert(realLayout.rows==8&&realLayout.cols==7&&realLayout.count==52);
    [realMapped,realInfo]=fusiReadBModeUnderlay(exampleFile,[90 64 54],realLayout);
    assert(isequal(size(realMapped),[90 64 3 54])&&nnz(realInfo.validSlices)==52&&~any(realInfo.validSlices(53:54)));
    fprintf('PASS: supplied vendor file, 52 extracted panels and two unassigned Doppler slices.\n');
end

rawA=fullfile(work,'RawData','animalA');rawB=fullfile(work,'RawData','animalB');
analysisA=fullfile(work,'AnalysedData','animalA','scan1','Preprocessing');
mkdir(rawA);mkdir(rawB);mkdir(analysisA);
I=plane;rawFile=fullfile(rawA,'scan1.mat');save(rawFile,'I');
assert(strcmp(fusiBModeRawStart(struct('loadedFile',rawFile),rawB),rawA));
assert(strcmp(fusiBModeRawStart(struct(),analysisA),rawA));
assert(strcmp(fusiBModeRawStart(struct('loadedPath',analysisA),rawB),rawA));
rawFileB=fullfile(rawB,'scan2.mat');save(rawFileB,'I');
assert(strcmp(fusiBModeRawStart(struct('rawFile',rawFileB,'loadedFile',rawFile),analysisA),rawB));
fprintf('PASS: picker starts in the specific animal folder, including analysed-folder fallback.\n');

rng(1);PSC=single(rand(ny,nx,80));bg=plane;
par=struct('loadedFile',rawFile,'exportPath',analysisA,'rawPath',rawA);
baseline=struct('start',0,'end',10,'sigStart',40,'sigEnd',60,'mode','sec');
f=SCM_gui(PSC,bg,1,par,baseline,80);owned('figures')=[owned('figures') f];drawnow;
getData=getappdata(f,'FUSIUnderlayData');base=getData();
xy=findobj(f,'Tag','SCM_ROICenter');set(xy,'String','12 12');invoke(findobj(f,'Tag','SCM_AddROI'));
trace=findobj(f,'Tag','SCM_SavedROI');assert(~isempty(trace));traces=get(trace,'YData');
current=getData();roi=current.roiDefinitions;assert(~isempty(roi));
baselineState=getappdata(f,'FUSIGetBaselineState');before=baselineState();
overlay=findobj(f,'Tag','SCM_OverlayImage');map=get(overlay,'CData');alpha=get(overlay,'AlphaData');
loadB=getappdata(f,'FUSILoadBMode');loadB(file);B=getData();
assert(B.bmode.mode==2&&B.bmode.available&&~isequal(B.displayRGB,base.displayRGB));
assert(isequaln(B.PSC,base.PSC)&&isequaln(B.underlay,base.underlay)&&isequaln(B.mask,base.mask));
source=findobj(f,'Tag','SCM_BackgroundSource');slider=findobj(f,'Tag','SCM_BModeBlend');
for k=1:10
    set(source,'Value',1);invoke(source);nowData=getData();
    assert(sameRGB(nowData.displayRGB,base.displayRGB),'Doppler display changed by %g.',max(abs(double(nowData.displayRGB(:))-double(base.displayRGB(:)))));
    set(source,'Value',2);invoke(source);nowData=getData();assert(isequal(nowData.displayRGB,B.displayRGB));
end
set(source,'Value',3);invoke(source);
for weight=[0 .5 1]
    set(slider,'Value',weight);invoke(slider);nowData=getData();
    expected=(1-weight).*base.displayRGB+weight.*B.displayRGB;
    assert(max(abs(nowData.displayRGB(:)-expected(:)))<1e-6);
end
current=getData();assert(isequaln(get(trace,'YData'),traces)&&isequaln(current.roiDefinitions,roi));
assert(isequaln(baselineState(),before)&&isequaln(get(overlay,'CData'),map)&&isequaln(get(overlay,'AlphaData'),alpha));
old=getData();fails(@()loadB(bad),'deConfUSIon:BModeGrid');after=getData();
assert(isequal(old.displayRGB,after.displayRGB)&&strcmp(after.bmode.file,file));
loadB('');after=getData();assert(isequal(old.displayRGB,after.displayRGB));
fprintf('PASS: real SCM switches and blend endpoints preserve PSC, masks, map/alpha, ROI definitions and curves. Failed/cancelled loads preserve the previous view.\n');

% Verify the three spatial planes remain independent in the actual viewer.
f3=SCM_gui(single(rand(ny,nx,3,80)),repmat(plane,1,1,3),1,par,baseline,80);owned('figures')=[owned('figures') f3]; %#ok<NASGU>
load3=getappdata(f3,'FUSILoadBMode');load3(volume);
data3=getappdata(f3,'FUSIUnderlayData');slice=getappdata(f3,'FUSISetSlice');
slice(1);first=data3();slice(3);last=data3();assert(~isequal(first.displayRGB,last.displayRGB));
fprintf('PASS: 3D SCM displays the corresponding B-mode slice.\n');
% A single image belongs only to its explicitly selected slice.
source3=findobj(f3,'Tag','SCM_BackgroundSource');slider3=findobj(f3,'Tag','SCM_BModeBlend');
set(source3,'Value',1);invoke(source3);
slice(1);doppler1=data3();slice(2);doppler2=data3();slice(3);beforeSnapshot=data3();
overlay3=findobj(f3,'Tag','SCM_OverlayImage');
map3=get(overlay3,'CData');alpha3=get(overlay3,'AlphaData');
fails(@()load3(snapshotFile),'deConfUSIon:BModeSliceMapping');
afterFailure=data3();assert(isequal(afterFailure.displayRGB,beforeSnapshot.displayRGB));
load3(snapshotFile,struct('kind','planes','sliceIndices',2));snapshot3=data3();
assert(isequal(size(snapshot3.displayRGB),[ny nx 3])&&snapshot3.bmode.available&& ...
    isequal(snapshot3.bmode.info.validSlices,[false true false]));
assert(isequaln(snapshot3.PSC,beforeSnapshot.PSC)&&isequaln(snapshot3.underlay,beforeSnapshot.underlay)&&isequaln(snapshot3.mask,beforeSnapshot.mask));
assert(isequaln(get(overlay3,'CData'),map3)&&isequaln(get(overlay3,'AlphaData'),alpha3));
assert(isequal(snapshot3.imageGeometry.underlayX,beforeSnapshot.imageGeometry.underlayX)&& ...
    isequal(snapshot3.imageGeometry.underlayY,beforeSnapshot.imageGeometry.underlayY)&& ...
    isequal(snapshot3.imageGeometry.overlayX,beforeSnapshot.imageGeometry.overlayX)&& ...
    isequal(snapshot3.imageGeometry.overlayY,beforeSnapshot.imageGeometry.overlayY));
slice(1);first=data3();slice(3);last=data3();
assert(isequal(first.displayRGB,doppler1.displayRGB)&&isequal(last.displayRGB,beforeSnapshot.displayRGB));
assert(strcmp(get(slider3,'Enable'),'off'),'Blend must be disabled on an unmapped slice.');
slice(2);B2=data3();assert(~isequal(B2.displayRGB,doppler2.displayRGB));
set(source3,'Value',3);invoke(source3);
set(slider3,'Value',0);invoke(slider3);zero=data3();assert(isequal(zero.displayRGB,doppler2.displayRGB));
set(slider3,'Value',1);invoke(slider3);one=data3();assert(isequal(one.displayRGB,B2.displayRGB));
set(slider3,'Value',.5);invoke(slider3);half=data3();
expected=.5*(doppler2.displayRGB+B2.displayRGB);assert(max(abs(half.displayRGB(:)-expected(:)))<1e-6);
slice(3);last=data3();assert(isequal(last.displayRGB,beforeSnapshot.displayRGB));
% The real SCM must show different extracted panels on different slices.
firstThree=layout;firstThree.sliceIndices(4:end)=0;
load3(montageFile,firstThree);set(source3,'Value',2);invoke(source3);
slice(1);first=data3();slice(3);last=data3();assert(~isequal(first.displayRGB,last.displayRGB));
assert(isequaln(first.PSC,beforeSnapshot.PSC)&&isequaln(last.mask,beforeSnapshot.mask));
fprintf('PASS: per-panel SCM switching, explicit single-slice assignment, missing-slice fallback, blend endpoints and measurement geometry.\n');
fprintf('All B-mode regression checks passed.\n');

end

function invoke(h)
callback=get(h,'Callback');callback(h,[]);
end

function equal=sameRGB(a,b)
% The initial SCM texture is double; its display cache uses single precision.
equal=isequal(size(a),size(b))&&max(abs(double(a(:))-double(b(:))))<1e-6;
end

function fails(fn,id)
try
    fn();
catch ME
    assert(strcmp(ME.identifier,id),'Unexpected error: %s',ME.message);return;
end
error('Expected failure: %s',id);
end

function cleanupTest(work,oldVisible,oldRng,owned)
figures=owned('figures');delete(figures(isgraphics(figures)));set(0,'DefaultFigureVisible',oldVisible);
rng(oldRng);
assert(startsWith(work,tempdir),'Test cleanup must stay inside tempdir.');
if isfolder(work),rmdir(work,'s');end
end
