function atlasPoints=registrationPointsToAtlas(displayPoints,tr,registrationUm,folder,volumeSize)
% Exact point-mode adapter for LightSuite implant annotation.
% Clicks are already in the permuted/flipped registration display grid.
% Evaluate the original image-pull transform directly in physical mm, then
% restore MATLAB's 1-based intrinsic coordinates before the inverse affine.
% Do not flip the display coordinates a second time or negate a sampled
% inverse displacement field.
assert(isnumeric(displayPoints)&&size(displayPoints,2)==3&&all(isfinite(displayPoints(:))), ...
    'deConfUSIon:LightSuiteTrackPoints','Track points must be finite N x 3 display-grid coordinates.');
assert(isscalar(registrationUm)&&isfinite(registrationUm)&&registrationUm>0,'Invalid registration resolution.');
if nargin>=5&&~isempty(volumeSize)
    assert(all(displayPoints>=1,'all')&&all(displayPoints<=double(volumeSize(1:3)),'all'), ...
        'Track points lie outside the registration display volume.');
end
forward=fullfile(folder,'bspline_atlas_to_samp_20um.txt');
assert(isfile(forward),'deConfUSIon:LightSuiteTrackForward', ...
    'The original atlas-to-sample image-pull B-spline file is required for exact implant-point mapping.');
p=elastix_parameter_read(forward);
assert(numel(p.Spacing)==3&&numel(p.Origin)==3&&numel(p.Direction)==9,'Invalid 3-D registration parameter geometry.');
assert(all(abs(double(p.Spacing(:)')-registrationUm*1e-3)<1e-8), ...
    'Registration TIFF spacing and B-spline parameter spacing differ.');
direction=reshape(double(p.Direction),3,3)';
physical=((double(displayPoints(:,[2 1 3]))-1).*double(p.Spacing(:)'))*direction'+double(p.Origin(:)');
warped=transformix(physical,forward,'pointtype','point','verbose',false);
if isstruct(warped)&&isfield(warped,'OutputPoint'),warped=warped.OutputPoint;end
assert(isequal(size(warped),size(physical))&&all(isfinite(warped(:))), ...
    'deConfUSIon:LightSuiteTrackTransform','Transformix did not return a finite point for every annotation.');
intrinsic=((warped-double(p.Origin(:)'))/direction')./double(p.Spacing(:)')+1;
atlasPoints=tr.tform_affine_samp20um_to_atlas_10um_px.transformPointsForward(intrinsic);
assert(all(isfinite(atlasPoints(:))),'Implant atlas coordinates are nonfinite.');
end
