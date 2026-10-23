function volumes=fusiLightSuiteReviewVolumes(session)
% Recreate the actual affine and nonlinear atlas overlays on the sample grid.
% Uses the forward image-pull transform, so an invalid inverse can be inspected.
guard=fusiLightSuitePaths(session.config); %#ok<NASGU>
opts=session.opts;p=opts.permute_sample_to_atlas;
sample=permuteBrainVolume(opts.sample,p);
ratio=opts.sample_res(abs(p))./opts.atlas_res;
sample=imresize3(single(sample),'Scale',ratio);
% Native-coordinate query centres corresponding exactly to imresize3's
% prepared display grid. Atlas detail is retained without an affine crop.
query=cell(1,3);
for axis=1:3
    coordinates=.5+((1:size(sample,axis))-.5)/ratio(axis);
    if p(axis)<0,coordinates=fliplr(session.inputSize(abs(p(axis)))+1-coordinates);end
    query{abs(p(axis))}=coordinates;
end
atlas=single(opts.atlas);
atlas=atlas-imgaussfilt3(atlas,4*round(.3./opts.atlas_res)+1);atlas=max(0,atlas);
labels=resampleAnnotation(opts.annotation,opts.parcelinfo,'structure');
% Pull from the full atlas once. Cropping the affine image to the sample
% before applying B-spline displacement creates artificial blank edge bands.
sampler=fusiLightSuiteAtlasSampling(session,[],false,query);
affine=permuteBrainVolume(sampler.sample(atlas,'affine','linear',false),p);
affineLabels=permuteBrainVolume(sampler.sample(labels,'affine','nearest',false),p);
nonlinear=permuteBrainVolume(sampler.sample(atlas,'affine_bspline','linear',false),p);
nonlinearLabels=permuteBrainVolume(sampler.sample(labels,'affine_bspline','nearest',false),p);
assert(isequal(size(sample),size(affine),size(nonlinear)), ...
    'deConfUSIon:LightSuiteReviewGrid','Review volumes do not share the prepared sample grid.');
volumes=struct('sample',sample,'atlas',{{affine,nonlinear}}, ...
    'labels',{{affineLabels,nonlinearLabels}},'spacingMm',opts.atlas_res, ...
    'sampleDisplay',[],'sampleDisplayMeta',struct());
[displayImage,displayMeta]=fusiLightSuiteLandmarkUnderlay(session);
if ~isempty(displayImage)
    volumes.sampleDisplay=imresize3(permuteBrainVolume(displayImage,p),'OutputSize',size(sample),'Method','linear');
    volumes.sampleDisplayMeta=displayMeta;
end
end
