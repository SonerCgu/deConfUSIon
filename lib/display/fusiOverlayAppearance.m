function [dispMap,alphaMap,rgb] = fusiOverlayAppearance(rawMap,s,baseMask)
% Video GUI's display transfer, shared with the 3D viewer. No data changes.
if nargin<3,baseMask=1;end
thr=s.maskThreshold;a=max(0,min(100,s.alphaPct));
mMin=s.modMinAbs;mMax=s.modMaxAbs;
if mMax<mMin,tmp=mMin;mMin=mMax;mMax=tmp;end
switch s.signMode
    case 1,showMask=rawMap>0;dispMap=rawMap;
    case 2,showMask=rawMap<0;dispMap=abs(min(rawMap,0));
    otherwise,showMask=isfinite(rawMap) & rawMap~=0;dispMap=rawMap;
end
thrMask=double(abs(rawMap)>=thr & showMask).*double(baseMask);
if ~s.alphaModEnable
    alphaMap=(a/100).*thrMask;
else
    effLo=max(mMin,thr);effHi=mMax;
    mag=abs(rawMap);mag(~showMask)=NaN;
    if ~isfinite(effHi) || effHi<=effLo
        tmp=mag(isfinite(mag));
        if isempty(tmp),effHi=effLo+eps;else,effHi=max(tmp);end
    end
    if ~isfinite(effHi) || effHi<=effLo,effHi=effLo+eps;end
    modv=(abs(rawMap)-effLo)./max(eps,effHi-effLo);
    modv(~isfinite(modv))=0;modv=min(max(modv,0),1);modv(~showMask)=0;
    if s.signMode==1,modulation=modv;else,modulation=.20+.80.*modv;end
    alphaMap=(a/100).*modulation.*thrMask;
end
alphaMap(~isfinite(alphaMap))=0;alphaMap=min(max(alphaMap,0),1);
if nargout>2
    scale=(dispMap-s.caxis(1))./(diff(s.caxis)+eps);scale=min(1,max(0,scale));
    index=double(uint8(scale*(size(s.colormap,1)-1)))+1;
    rgb=reshape(single(s.colormap(index(:),:)),[size(rawMap) 3]);
end
end
