function rgb=fusiRegionLabelRGB(labels,info,scheme)
if nargin<3,scheme='Atlas';end
L=abs(double(labels));L(~isfinite(L))=0;n=max(1,max(L(:)));
lut=fusiRegionColorLUT(info,n,scheme);valid=L>=1&L<=size(lut,1)&L==round(L);ix=L;ix(~valid)=1;
rgb=zeros([size(L,1) size(L,2) 3 size(L,3)],'uint8');
for channel=1:3
 values=reshape(uint8(round(255*lut(ix(:),channel))),size(L));values(~valid)=0;
 rgb(:,:,channel,:)=reshape(values,size(L,1),size(L,2),1,[]);
end
end
