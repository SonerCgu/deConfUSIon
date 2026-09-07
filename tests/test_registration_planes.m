function test_registration_planes(part)
if nargin<1, part='synthetic'; end
root=fileparts(fileparts(mfilename('fullpath'))); addpath(root);
if strcmp(part,'real'), realScan(root); return; end
[dv,lr,ap]=ndgrid(1:16,1:19,1:13); native=single(dv+20*lr+400*ap);
g=struct('convention','coronal_stack_v2','permutation',[3 1 2], ...
    'originalSize',size(native),'originalSpacingUm',[50 50 50],'atlasVoxelSizeUm',[50 50 50],'flipAxes',[]);
scan=struct('Data',permute(native,g.permutation),'VoxelSize',[50 50 50],'Geometry',g);
prepared=AtlasRegistration('prepare',scan,struct('VoxelSize',[50 50 50]));
assert(isequal(squeeze(prepared.Data(7,:,:)),native(:,:,7)),'Coronal acquisition was transposed or flipped.');
A=eye(3); A(3,1:2)=[2 3]; M=AtlasRegistration('planematrix',A,'coronal');
assert(isequal(M(4,1:3),[3 0 2]),'Coronal drag changed AP rather than LR/DV.');
for plane={'axial','sagittal'}
    P=AtlasRegistration('planematrix',A,plane{1});
    if strcmp(plane{1},'axial'), want=[0 3 2]; else, want=[3 2 0]; end
    assert(isequal(P(4,1:3),want));
end
D=prepared.Data; T=struct('M',M,'size',size(D),'scanGeometry',g);
out=AtlasRegistration('warp',cat(4,native,native*2),T);
want=imwarp(D,affine3d(M),'OutputView',imref3d(size(D)));
assert(isequal(out(:,:,:,1),want) && isequal(out(:,:,:,2),want*2));
[cor,axi,sag]=AtlasRegistration('previewcuts',D,M,size(D),[7 8 9]);
assert(isequal(cor,squeeze(want(7,:,:))) && isequal(axi,squeeze(want(:,8,:))) && isequal(sag,squeeze(want(:,:,9))'));
atlas=struct('Histology',uint16(D/max(D(:))*255)+1,'Vascular',D,'Regions',ones(size(D)), ...
    'VoxelSize',[50 50 50],'Lines',struct('Cor',{{}},'Sag',{{}},'Tra',{{}}),'infoRegions',struct('rgb',[0 0 0;1 1 1]));
folder=tempname; mkdir(folder); R=registration_ccf(atlas,scan,[],@disp,folder);
guard=onCleanup(@()delete(R.H.figure1)); %#ok<NASGU>
under=findall(R.H.axes4,'Tag','FixedAtlas'); over=findall(R.H.axes4,'Tag','MovingAnatomy');
before=get(under,'CData'); opacity=findall(R.H.figure1,'Tag','AnatomyOpacity');
set(opacity,'Value',.25); R.onOverlayChanged();
assert(isequal(before,get(under,'CData')) && isequal(get(under,'AlphaData'),1));
alpha=get(over,'AlphaData'); assert(max(alpha(:))==.25);
R.r1.T0=A; R.previewAlignment();
assert(isequal(R.getCurrentTransform().M,M)); R.onApply();
assert(isequal(R.getCurrentTransform().M,M),'Mouse commit applied the coronal drag twice.');
assert(norm(R.ms2.D(:)-reshape(imwarp(R.DataNoScale,affine3d(M),'OutputView',imref3d(size(D))),[],1))<1e-8);
fprintf('PASS coronal geometry, all-plane drags, preview/commit and anatomy-only opacity.\n');
end

function realScan(root)
S=load(fullfile(root,'validation','scan5_anatomy.mat')); A=load(fullfile(root,'allen_brain_atlas.mat')); atlas=A.atlas;
g=struct('convention','coronal_stack_v2','permutation',[3 1 2], ...
    'originalSize',size(S.anatomy),'originalSpacingUm',S.voxelSizeUm,'atlasVoxelSizeUm',atlas.VoxelSize,'flipAxes',[],'confirmed',true);
scan=struct('Data',permute(S.anatomy,[3 1 2]),'VoxelSize',S.voxelSizeUm([3 1 2]),'Geometry',g);
folder=fullfile(root,'validation','scan5_registration'); if ~isfolder(folder), mkdir(folder); end
R=registration_ccf(atlas,scan,[],@disp,folder); guard=onCleanup(@()delete(R.H.figure1)); %#ok<NASGU>
cfg=struct('engine','matlab','model','rigid','target','vascular','maxDimension',160,'iterations',[150 80 30],'openReview',true);
t=tic; R.onAutoRegister(cfg); elapsed=toc(t);
assert(~isempty(R.autoReport),'MATLAB automatic registration did not produce a proposal.');
assert(isempty(R.reviewBundle),'MATLAB registration launched ITK-SNAP.');
R.ms1.x0=132; R.refresh(); drawnow; shot=getframe(R.H.figure1); imwrite(shot.cdata,fullfile(root,'validation','scan5_matlab_registration.png'));
report=R.autoReport; Transf=R.getCurrentTransform(); save(fullfile(folder,'ValidationProposal.mat'),'report','Transf','elapsed');
fprintf('REAL scan5 MATLAB rigid: %.3f s; NMI %.5f -> %.5f; overlap %.3f\n',elapsed,report.nmiBefore,report.nmiAfter,report.foregroundOverlap);
% The explicit review action launches once, and repeated clicks reuse it.
R.onReviewSnap(); assert(~isempty(R.reviewBundle) && R.reviewBundle.launched);
process=R.reviewBundle.process; processGuard=onCleanup(@()process.destroy()); %#ok<NASGU>
bundleFolder=R.reviewBundle.folder; pause(2); assert(process.isAlive());
R.onReviewSnap(); assert(strcmp(bundleFolder,R.reviewBundle.folder),'Repeated review opened a second viewer.');
assert(isequal(niftiread(R.reviewBundle.atlas),permute(single(R.mapVascular.D),[3 1 2])));
fprintf('PASS real scan5 proposal, MATLAB-only run, vascular review, single ITK-SNAP launch.\n');
end
