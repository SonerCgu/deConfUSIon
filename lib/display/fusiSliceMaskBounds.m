function [bounds,report]=fusiSliceMaskBounds(seed,validSlices)
% Fit a clean XY envelope independently in each slice of a Doppler proposal.
% Interior intensity holes do not affect the shape. Missing outlines can be
% interpolated within a continuous usable run, never across a blank plane.
shape=size(seed,[1 2 3]);seed=isfinite(seed) & seed~=0;
if nargin<2 || isempty(validSlices),validSlices=reshape(any(any(seed,1),2),1,[]);end
assert(numel(validSlices)==shape(3),'deConfUSIon:SliceMaskSupport','Slice support must match the proposal.');
validSlices=logical(reshape(validSlices,1,[]));bounds=nan(shape(3),4);
detected=false(1,shape(3));interpolated=detected;
for z=find(validSlices)
    plane=seed(:,:,z);if ~any(plane(:)),continue;end
    bounds(z,:)=[profileBounds(sum(plane,1)) profileBounds(sum(plane,2))];
    detected(z)=true;
end
edges=diff([false validSlices false]);starts=find(edges==1);ends=find(edges==-1)-1;
for k=1:numel(starts)
    run=starts(k):ends(k);known=run(detected(run));missing=run(~detected(run));
    if isempty(known) || isempty(missing),continue;end
    if numel(known)==1
        bounds(missing,:)=repmat(bounds(known,:),numel(missing),1);
    else
        query=min(known(end),max(known(1),missing));
        bounds(missing,:)=interp1(known,bounds(known,:),query,'linear');
    end
    interpolated(missing)=true;
end
report=struct('detectedSlices',detected,'interpolatedSlices',interpolated, ...
    'unresolvedSlices',validSlices & ~detected & ~interpolated);
end

function out=profileBounds(profile)
profile=double(profile(:));tail=.005*sum(profile);
first=find(cumsum(profile)>tail,1,'first');
last=numel(profile)-find(cumsum(flipud(profile))>tail,1,'first')+1;
out=[first last];
end
