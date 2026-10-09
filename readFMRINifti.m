function [V,info] = readFMRINifti(path)
% Read physical NIfTI values without resampling or reorienting voxel data.
info=niftiinfo(path);
sz=double(info.ImageSize);
assert(numel(sz)<=4,'deConfUSIon:NiftiDimensions','Only 2D, 3D and 4D NIfTI images are supported.');
V=single(niftiread(info));
% niftiread returns stored voxel values; slope zero means no scaling.
slope=double(info.MultiplicativeScaling); offset=double(info.AdditiveOffset);
if isfinite(slope)&&slope~=0
    V=V*slope;
    if isfinite(offset), V=V+offset; end
end
end
