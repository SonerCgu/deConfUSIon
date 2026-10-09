function [D,alpha]=fusiRegistrationOverlayAppearance(raw,window,gain,gamma,opacity,invert)
% Appearance only, applied to cached cuts. Registration intensities stay intact.
if nargin<6,invert=false;end
assert(numel(window)==2 && all(isfinite(window)) && window(2)>window(1), ...
 'deConfUSIon:OverlayWindow','Anatomy window maximum must exceed its minimum.');
assert(isscalar(gain)&&isfinite(gain)&&gain>0 && isscalar(gamma)&&isfinite(gamma)&&gamma>0, ...
 'deConfUSIon:OverlayAppearance','Vessel gain and gamma must be positive finite numbers.');
U=min(1,max(0,(single(raw)-window(1))/(window(2)-window(1))));
U=min(1,max(0,U*gain)).^(1/gamma);
alpha=single(min(1,max(0,opacity)))*U.^.25;
alpha(~isfinite(raw)|raw<=0)=0;
D=U;if invert,D=1-D;end
D(~isfinite(raw))=0;
end
