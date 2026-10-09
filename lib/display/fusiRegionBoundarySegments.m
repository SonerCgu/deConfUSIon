function [x,y]=fusiRegionBoundarySegments(L)
% One NaN-separated line traces categorical boundaries at voxel edges.
L=abs(double(L));L(~isfinite(L))=0;
[row,col]=find(L(:,1:end-1)~=L(:,2:end));
x=[col'+.5;col'+.5;nan(1,numel(col))];y=[row'-.5;row'+.5;nan(1,numel(row))];
[row,col]=find(L(1:end-1,:)~=L(2:end,:));
x=[x(:)' reshape([col'-.5;col'+.5;nan(1,numel(col))],1,[])];
y=[y(:)' reshape([row'+.5;row'+.5;nan(1,numel(row))],1,[])];
end
