function fv=fusiVolumeSurfaceMesh(V,threshold,spacing,slices,maxFaces)
% Bound preview mesh cost without resampling or modifying analysis data.
if nargin<5,maxFaces=25000;end
stride=max(1,ceil(max(size(V))/96));
indices={1:stride:size(V,1),1:stride:size(V,2),1:stride:size(V,3)};
small=single(V(indices{:}));small(~isfinite(small))=0;
padded=zeros(size(small)+2,'single');padded(2:end-1,2:end-1,2:end-1)=small;
fv=isosurface(padded,threshold);
if isempty(fv.vertices),return;end
if size(fv.faces,1)>maxFaces,fv=reducepatch(fv,maxFaces);end
fv.vertices=((fv.vertices-2)*stride+1).*[spacing(2) spacing(1) spacing(3)];
fv.vertices(:,3)=fv.vertices(:,3)+(slices(1)-1)*spacing(3);
end
