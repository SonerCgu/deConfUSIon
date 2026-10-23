function result=fusiLightSuiteLandmarkResiduals(session)
% Measure saved pair agreement through the same composed map as atlas export.
s=fusiLightSuite('load',session);file=fullfile(s.opts.savepath,'control_points_minimal.mat');
result=struct('available',false,'nPairs',0,'message','No saved paired landmarks for an anatomical fit check.');
if ~isfile(file),return;end
C=load(file,'sample_points','atlas_points');
if ~all(isfield(C,{'sample_points','atlas_points'})),return;end
a=C.sample_points;b=C.atlas_points;
if iscell(a),a=cat(1,a{:});end
if iscell(b),b=cat(1,b{:});end
if isempty(a)&&isempty(b),return;end
assert(size(a,1)==size(b,1)&&size(a,2)>=3&&size(b,2)>=3,'Saved landmark pairs are incomplete.');
a=double(a(:,1:3));b=double(b(:,1:3));assert(all(isfinite([a(:);b(:)])),'Saved landmark pairs are nonfinite.');
guard=fusiLightSuitePaths(s.config); %#ok<NASGU>
voxel=double(s.opts.atlas_res);p=abs(s.opts.permute_sample_to_atlas);
prepared=.5+(a-.5).*double(s.opts.sample_res(p))./voxel;
xyz=(prepared(:,[2 1 3])-1).*voxel([2 1 3]);
moved=transformix(xyz,fullfile(s.opts.savepath,'bspline_atlas_to_samp_20um.txt'), ...
    'pointtype','point','verbose',false);
if isstruct(moved),moved=moved.OutputPoint;end
tr=load(fullfile(s.opts.savepath,'transform_params.mat'),'tform_affine_samp20um_to_atlas_10um_px');
mapped=transformPointsForward(tr.tform_affine_samp20um_to_atlas_10um_px,moved./voxel([2 1 3])+1);
errorMm=(mapped(:,[2 1 3])-b).*voxel;errors=vecnorm(errorMm,2,2);
[~,order]=sort(errors,'descend');span=(max(a,[],1)-min(a,[],1))./max(1,double(s.inputSize(p))-1);
nativeDiagonal=norm(double(s.opts.sample_res));
result=struct('available',true,'nPairs',size(a,1),'pairErrorsMm',errors, ...
    'medianMm',median(errors),'p95Mm',quantile(errors,.95),'maxMm',max(errors), ...
    'worstPairIDs',order(1:min(5,end))','sampleSpanFractionAPDVML',span, ...
    'nativeVoxelDiagonalMm',nativeDiagonal,'reviewSuggested', ...
    quantile(errors,.95)>2*nativeDiagonal||any(span<.5), ...
    'scope','Agreement at fitted landmarks, not independent anatomical validation. Limited landmark span leaves other slices weakly constrained.');
result.message=sprintf(['Landmarks: %d pairs | median %.3g mm | p95 %.3g mm | max %.3g mm (pair %d). ' ...
    'Landmark span AP/DV/ML: %.0f/%.0f/%.0f%% of the sample.'], ...
    result.nPairs,result.medianMm,result.p95Mm,result.maxMm,order(1),100*span);
if result.reviewSuggested,result.message=[result.message ' Inspect mismatched pairs and slices beyond the marked planes before accepting.'];end
end
