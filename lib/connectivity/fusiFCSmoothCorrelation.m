function out=fusiFCSmoothCorrelation(values,includeMask,sigma)
% Display-only, normalized in-plane Gaussian smoothing of signed Pearson r.
% Excluded/undefined pixels stay undefined; no smoothing across Z or time.
out=double(values);
if nargin<3||~isfinite(sigma)||sigma<=0,return;end
assert(ismatrix(values),'deConfUSIon:FCSmoothing','Smooth one displayed slice at a time.');
if isempty(includeMask),includeMask=true(size(values));end
assert(isequal(size(includeMask),size(values)),'deConfUSIon:FCSmoothing','Smoothing mask must match the displayed slice.');
valid=logical(includeMask)&isfinite(values);
radius=max(1,ceil(3*sigma));x=-radius:radius;g=exp(-.5*(x/sigma).^2);g=g/sum(g);
data=double(values);data(~valid)=0;
weights=conv2(g',g,double(valid),'same');smooth=conv2(g',g,data,'same');
out(:)=NaN;out(valid)=max(-1,min(1,smooth(valid)./weights(valid)));
end
