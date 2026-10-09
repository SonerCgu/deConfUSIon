function [u,info] = fusiVolumeBaseline(data)
% Reference anatomy/vascular signal from the SAME baseline as Video PSC.
u=[];info=struct('available',false,'frames',[],'timeSec',[]);
if fusiBaselineReference('isExternal',data.baseline)
    % The reference stays in native coordinates; it is not an atlas underlay.
    if ndims(data.I)==4&&~(isfield(data,'transformed')&&data.transformed)
        r=data.baseline.reference;u=fusiBaselineReference('validate',r,size(data.I,1:3));
        info=struct('available',true,'frames',r.frames,'timeSec',r.windowSec,'source',fusiBaselineReference('label',data.baseline));
    end
    return;
end
if data.inputIsPSC || ndims(data.I)~=4 || ~isstruct(data.baseline) ...
        || ~all(isfield(data.baseline,{'start','end'})),return;end
b=double([data.baseline.start data.baseline.end]);
if any(~isfinite(b)) || b(1)<0 || b(2)<b(1),return;end
n=size(data.I,4);idx=round(b/data.TR)+1;
idx=[max(1,idx(1)) min(n,idx(2))];if idx(1)>idx(2),return;end
u=zeros(size(data.I,1),size(data.I,2),size(data.I,3),'single');valid=true(size(u));
for k=idx(1):idx(2)
    a=single(data.I(:,:,:,k));valid=valid & isfinite(a);a(~isfinite(a))=0;
    u=u+a/(idx(2)-idx(1)+1);
end
u(~valid)=NaN;
info=struct('available',true,'frames',idx,'timeSec',(idx-1)*data.TR);
end
