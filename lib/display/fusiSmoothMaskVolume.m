function mask=fusiSmoothMaskVolume(mask,radius,slices,restrictMask)
% Smooth selected XY planes independently; never mix neighboring slices.
if nargin<3 || isempty(slices),slices=1:size(mask,3);end
if nargin<4,restrictMask=[];end
assert((isnumeric(mask) || islogical(mask)) && ndims(mask)<=3, ...
    'deConfUSIon:SmoothMaskInput','Supply a binary mask volume.');
assert(isscalar(radius) && isfinite(radius) && radius>=0, ...
    'deConfUSIon:SmoothMaskRadius','Smoothing radius must be nonnegative.');
assert(all(isfinite(slices) & slices==round(slices) & slices>=1 & slices<=size(mask,3)), ...
    'deConfUSIon:SmoothMaskSlices','Choose valid slice indices.');
if ~isempty(restrictMask)
    assert(isequal(size(restrictMask),size(mask)), ...
        'deConfUSIon:SmoothMaskRestriction','Restriction must match the mask.');
    restrictMask=isfinite(restrictMask) & restrictMask~=0;
end
mask=isfinite(mask) & mask~=0;radius=round(radius);
for z=unique(slices(:)')
    plane=mask(:,:,z);
    if radius>0 && any(plane(:))
        if exist('strel','file')==2 && exist('imfill','file')==2
            se=strel('disk',radius,0);
            plane=imfill(imclose(imopen(plane,se),se),'holes');
        else
            kernel=ones(2*radius+1);kernel=kernel/sum(kernel(:));
            plane=conv2(double(plane),kernel,'same')>.5;
        end
    end
    if ~isempty(restrictMask),plane=plane & restrictMask(:,:,z);end
    mask(:,:,z)=plane;
end
end
