function [tc,tidx]=fusiCommonModeTimecourses(I,maskVol,Nblock,maxFrames)
% Same fixed spatial blocks and mask means as QC, without copying a full
% double 3D frame for every block at every time point.
ny=size(I,1);nx=size(I,2);nz=1;if ndims(I)==4,nz=size(I,3);end
Tin=size(I,ndims(I));Nblock=max(2,round(Nblock));
xe=round(linspace(1,nx+1,Nblock+1));ye=round(linspace(1,ny+1,Nblock+1));
ze=round(linspace(1,nz+1,Nblock+1));
step=1;if Tin>maxFrames,step=ceil(Tin/maxFrames);end;tidx=1:step:Tin;
tc=zeros(Nblock^3,numel(tidx));count=0;flat=reshape(I,[],Tin);
for bz=1:Nblock
 z=ze(bz):ze(bz+1)-1;if isempty(z),continue;end
 for by=1:Nblock
  y=ye(by):ye(by+1)-1;if isempty(y),continue;end
  for bx=1:Nblock
   x=xe(bx):xe(bx+1)-1;if isempty(x),continue;end
   m=maskVol(y,x,z);if nnz(m)<30,continue;end
   [yy,xx,zz]=ndgrid(y,x,z);indices=sub2ind([ny nx nz],yy(:),xx(:),zz(:));indices=indices(m(:));
   count=count+1;chunkT=max(1,floor(32*1024^2/(8*numel(indices)*2)));
   for first=1:chunkT:numel(tidx)
    last=min(numel(tidx),first+chunkT-1);
    values=double(flat(indices,tidx(first:last)));values(~isfinite(values))=0;
    tc(count,first:last)=mean(values,1);
   end
  end
 end
end
tc=tc(1:count,:);
end
