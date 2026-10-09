function r=scmStaticROI(V,z,xy,width)
% Raw, finite voxel statistics, independent of threshold/display smoothing.
assert(numel(xy)==2 && all(isfinite(xy)) && isscalar(width) && isfinite(width) && width>=1, ...
    'deConfUSIon:StaticROI','Enter a finite X Y center and positive ROI width.');
assert(isscalar(z)&&isfinite(z)&&z>=1&&z<=size(V,3),'deConfUSIon:StaticROI','Invalid slice.');
xy=round(xy); width=round(width); z=round(z);
assert(xy(1)>=1&&xy(1)<=size(V,2)&&xy(2)>=1&&xy(2)<=size(V,1), ...
    'deConfUSIon:StaticROI','ROI center is outside the image.');
x0=max(1,xy(1)-floor((width-1)/2)); x1=min(size(V,2),xy(1)+ceil((width-1)/2));
y0=max(1,xy(2)-floor((width-1)/2)); y1=min(size(V,1),xy(2)+ceil((width-1)/2));
v=double(V(y0:y1,x0:x1,z)); v=v(isfinite(v));
r=struct('slice',z,'x0',x0,'x1',x1,'y0',y0,'y1',y1,'n',numel(v), ...
    'mean',NaN,'median',NaN,'sd',NaN,'min',NaN,'max',NaN);
if ~isempty(v)
    r.mean=mean(v); r.median=median(v); r.min=min(v); r.max=max(v);
    if numel(v)>1, r.sd=std(v,0); end
end
end
