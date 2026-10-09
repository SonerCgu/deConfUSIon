function a=fusiRegistrationOverlayAlpha(v,window,opacity)
% Keep dim acquisition background transparent, without changing anatomy.
u=min(1,max(0,(single(v)-window(1))/max(eps,window(2)-window(1))));
a=single(opacity)*u.^.25;a(~isfinite(v) | v<=0)=0;
end
