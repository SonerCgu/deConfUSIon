function [mesh,indices]=fusiVolumeSlabGeometry(mask,sampling,thicknessMm,origin)
% Lateral tissue walls for an averaged coronal slab. Pixel edges are exact.
% Front/back textures are separate; holes and exterior background stay open.
if nargin<4,origin=[0 0];end
validateattributes(thicknessMm,{'numeric'},{'scalar','finite','positive'});
mask=logical(mask);[nr,nc]=size(mask);
padded=false(nr+2,nc+2);padded(2:end-1,2:end-1)=mask;
directions=[-1 0;1 0;0 -1;0 1];
corners={ [0 0;0 1], [1 1;1 0], [1 0;0 0], [0 1;1 1] };
vertices=cell(1,4);indices=cell(1,4);
for side=1:4
    d=directions(side,:);neighbor=padded((2:nr+1)+d(1),(2:nc+1)+d(2));
    indices{side}=find(mask & ~neighbor);[r,c]=ind2sub([nr nc],indices{side});
    o=corners{side};a=[origin(1)+(c-1+o(1,2))*sampling(2),origin(2)+(r-1+o(1,1))*sampling(1)];
    b=[origin(1)+(c-1+o(2,2))*sampling(2),origin(2)+(r-1+o(2,1))*sampling(1)];
    n=numel(r);z=ones(n,1)*thicknessMm/2;
    % Four consecutive vertices per quad, matching the per-face color index.
    v=cat(3,[a -z],[b -z],[b z],[a z]);
    vertices{side}=reshape(permute(v,[3 1 2]),[],3);
end
indices=vertcat(indices{:});v=vertcat(vertices{:});
mesh=struct('vertices',v,'faces',reshape(1:size(v,1),4,[])');
end
