function Y=fusiWarpAtlasForDisplay(X,T,missingOutside)
% Apply native geometry and affine once, then present coronal atlas slices.
if nargin<3,missingOutside=false;end
displayOrder=[];
if isfield(T,'displayPermutation')
 displayOrder=T.displayPermutation;
 assert(isequal(displayOrder,[2 3 1]),'deConfUSIon:AtlasDisplayOrder','Unsupported atlas display permutation.');
 assert(isfield(T,'atlasCanonicalSize'),'deConfUSIon:AtlasDisplayOrder','Missing canonical atlas grid.');
 T.size=T.atlasCanonicalSize;T.outSize=T.atlasCanonicalSize;
end
Y=AtlasRegistration('warp',X,T);
if missingOutside
 support=AtlasRegistration('warp',ones(size(X,[1 2 3]),'single'),T)>=1-1e-5;
 for frame=1:size(Y,4),values=Y(:,:,:,frame);values(~support)=NaN;Y(:,:,:,frame)=values;end
end
if ~isempty(displayOrder),Y=permute(Y,[displayOrder 4]);end
end
