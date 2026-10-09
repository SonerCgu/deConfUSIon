function mask=scmPaintMask(mask,fromXY,toXY,radius,erase)
% Continuous round stroke in image coordinates, including its caps.
assert(ismatrix(mask)&&~isempty(mask),'deConfUSIon:PaintMask','A nonempty 2-D mask is required.');
assert(numel(fromXY)==2&&numel(toXY)==2&&all(isfinite([fromXY(:);toXY(:)]))&& ...
    isscalar(radius)&&isfinite(radius)&&radius>0,'deConfUSIon:PaintMask','Brush points and radius must be finite; radius must be positive.');
mask=logical(mask);[ny,nx]=size(mask);a=double(fromXY(:)');b=double(toXY(:)');
xs=max(1,ceil(min(a(1),b(1))-radius)):min(nx,floor(max(a(1),b(1))+radius));
ys=max(1,ceil(min(a(2),b(2))-radius)):min(ny,floor(max(a(2),b(2))+radius));
if isempty(xs)||isempty(ys),return;end
[X,Y]=meshgrid(xs,ys);d=b-a;den=sum(d.^2);
if den==0,u=zeros(size(X));else,u=max(0,min(1,((X-a(1))*d(1)+(Y-a(2))*d(2))/den));end
stroke=(X-a(1)-u*d(1)).^2+(Y-a(2)-u*d(2)).^2<=radius^2;
if erase,mask(ys,xs)=mask(ys,xs)&~stroke;else,mask(ys,xs)=mask(ys,xs)|stroke;end
end
