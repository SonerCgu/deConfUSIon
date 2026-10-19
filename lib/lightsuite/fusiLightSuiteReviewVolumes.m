function volumes=fusiLightSuiteReviewVolumes(session)
% Recreate the actual affine and nonlinear atlas overlays on the sample grid.
% Uses the forward image-pull transform, so an invalid inverse can be inspected.
guard=fusiLightSuitePaths(session.config); %#ok<NASGU>
opts=session.opts;p=opts.permute_sample_to_atlas;
sample=permuteBrainVolume(opts.sample,p);
sample=imresize3(single(sample),'Scale',opts.sample_res(abs(p))./opts.atlas_res);
tr=load(fullfile(opts.savepath,'transform_params.mat'));
atlas=single(opts.atlas);
atlas=atlas-imgaussfilt3(atlas,4*round(.3./opts.atlas_res)+1);atlas=max(0,atlas);
labels=resampleAnnotation(opts.annotation,opts.parcelinfo,'structure');
tform=tr.tform_affine_samp20um_to_atlas_10um_px.invert;
ref=imref3d(size(sample));
affine=imwarp(atlas,imref3d(size(atlas)),tform,'OutputView',ref);
affineLabels=imwarp(labels,imref3d(size(labels)),tform,'nearest','OutputView',ref);
forward=fullfile(opts.savepath,'bspline_atlas_to_samp_20um.txt');
nonlinear=transformix(affine,forward,'movingscale',opts.atlas_res,'verbose',false);
nonlinearLabels=transformAnnotationVolume(forward,affineLabels,opts.atlas_res);
assert(isequal(size(sample),size(affine),size(nonlinear)), ...
    'deConfUSIon:LightSuiteReviewGrid','Review volumes do not share the prepared sample grid.');
volumes=struct('sample',sample,'atlas',{{affine,nonlinear}}, ...
    'labels',{{affineLabels,nonlinearLabels}},'spacingMm',opts.atlas_res);
end
