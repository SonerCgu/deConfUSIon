function [mesh,indices]=fusiVolumeVoxelFaces(mask,spacing,slices)
% Exposed voxel faces, without interpolation, smoothing, or mesh reduction.
mask=logical(mask);sz=[size(mask,1) size(mask,2) size(mask,3)];
[y,x,z]=ndgrid((.5:sz(1)+.5)*spacing(1),(.5:sz(2)+.5)*spacing(2), ...
    ((.5:sz(3)+.5)+slices(1)-1)*spacing(3));
mesh=struct('vertices',single([x(:) y(:) z(:)]),'faces',zeros(0,4,'uint32'));indices=zeros(0,1);
padded=false(sz+2);padded(2:end-1,2:end-1,2:end-1)=mask;
vertexSize=sz+1;
offsets={ [0 0 0;0 1 0;0 1 1;0 0 1], [1 0 0;1 0 1;1 1 1;1 1 0], ...
    [0 0 0;0 0 1;1 0 1;1 0 0], [0 1 0;1 1 0;1 1 1;0 1 1], ...
    [0 0 0;1 0 0;1 1 0;0 1 0], [0 0 1;0 1 1;1 1 1;1 0 1] };
directions=[-1 0 0;1 0 0;0 -1 0;0 1 0;0 0 -1;0 0 1];
faces=cell(1,6);source=cell(1,6);
for side=1:6
    d=directions(side,:);
    neighbor=padded((2:sz(1)+1)+d(1),(2:sz(2)+1)+d(2),(2:sz(3)+1)+d(3));
    source{side}=find(mask & ~neighbor);[r,c,s]=ind2sub(sz,source{side});f=zeros(numel(r),4,'uint32');
    for corner=1:4
        o=offsets{side}(corner,:);f(:,corner)=uint32(sub2ind(vertexSize,r+o(1),c+o(2),s+o(3)));
    end
    faces{side}=f;
end
mesh.faces=vertcat(faces{:});indices=vertcat(source{:});
end
