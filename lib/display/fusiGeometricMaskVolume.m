function [mask,report]=fusiGeometricMaskVolume(seed,bounds,restrictMask,validSlices,shapeMode)
% Replace an intensity proposal by XY rectangles or ellipses.
% bounds = [left right firstRow lastRow], inclusive native voxel indices;
% supply one row for a shared shape, or Z rows for slice-dependent geometry.
% Weak/zero signal inside the rectangle is included deliberately. This is a
% geometric field selection, not an anatomical segmentation or resampling.
if nargin<2,bounds=[];end
if nargin<3,restrictMask=[];end
if nargin<5 || isempty(shapeMode),shapeMode='rectangle';end
assert(any(strcmp(shapeMode,{'rectangle','ellipse'})), ...
    'deConfUSIon:MaskShape','Choose rectangle or ellipse.');
assert((isnumeric(seed) || islogical(seed)) && ~isempty(seed) && ndims(seed)<=3, ...
    'deConfUSIon:RectangleSeed','Supply a nonempty scalar mask volume.');
shape=size(seed,[1 2 3]);seed=isfinite(seed) & seed~=0;
if nargin<4 || isempty(validSlices)
    validSlices=reshape(any(any(seed,1),2),1,[]);
end
assert(numel(validSlices)==shape(3),'deConfUSIon:RectangleSlices','Slice support must match the volume.');
validSlices=logical(reshape(validSlices,1,[]));
if ~isempty(restrictMask)
    assert(isequal(size(restrictMask,[1 2 3]),shape), ...
        'deConfUSIon:RectangleRestriction','Restriction must match the volume.');
    restrictMask=isfinite(restrictMask) & restrictMask~=0;
end
mask=false(shape);
report=struct('method',['3D probe ' shapeMode],'shape',shapeMode,'bounds',[],'boundsBySlice',[], ...
    'validSlices',validSlices,'voxelCount',0,'restrictionApplied',~isempty(restrictMask));
if isempty(bounds)
    % Pool neighboring slices instead of chasing each slice's intensity.
    % Trim only the outer 0.5% of support per axis so isolated pixels do not
    % stretch the rectangle to the image edge. Interior holes never survive.
    support=sum(seed(:,:,validSlices),3);
    if ~any(support(:)),return;end
    x=profileBounds(sum(support,1));y=profileBounds(sum(support,2));
    bounds=[x y];
end
if isvector(bounds) && numel(bounds)==4,bounds=bounds(:)';end
assert(isnumeric(bounds) && size(bounds,2)==4 && any(size(bounds,1)==[1 shape(3)]) && all(isfinite(bounds(:))), ...
    'deConfUSIon:RectangleBounds','Supply four finite bounds, or one row of bounds per slice.');
bounds=round(double(bounds));
bounds(:,1:2)=min(shape(2),max(1,bounds(:,1:2)));
bounds(:,3:4)=min(shape(1),max(1,bounds(:,3:4)));
assert(all(bounds(:,1)<=bounds(:,2) & bounds(:,3)<=bounds(:,4)), ...
    'deConfUSIon:RectangleBounds','Rectangle bounds must be ordered.');
boxes=bounds;if size(boxes,1)==1,boxes=repmat(boxes,shape(3),1);end
for z=find(validSlices)
    b=boxes(z,:);
    if strcmp(shapeMode,'ellipse')
        [y,x]=ndgrid(b(3):b(4),b(1):b(2));
        center=[mean(b(1:2)) mean(b(3:4))];
        radius=[diff(b(1:2))+1 diff(b(3:4))+1]/2;
        mask(b(3):b(4),b(1):b(2),z)= ...
            ((x-center(1))/radius(1)).^2+((y-center(2))/radius(2)).^2<=1;
    else
        mask(b(3):b(4),b(1):b(2),z)=true;
    end
end
if ~isempty(restrictMask),mask=mask & restrictMask;end
report.bounds=bounds;report.boundsBySlice=boxes;report.voxelCount=nnz(mask);
end

function bounds=profileBounds(profile)
profile=double(profile(:));tail=.005*sum(profile);
first=find(cumsum(profile)>tail,1,'first');
last=numel(profile)-find(cumsum(flipud(profile))>tail,1,'first')+1;
bounds=[first last];
end
