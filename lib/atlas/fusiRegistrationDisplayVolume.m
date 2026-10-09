function D=fusiRegistrationDisplayVolume(V,preset)
% Registration anatomy display only; optimizer always uses original power.
if nargin<2,preset='Mask Editor standard';end
V=single(V);valid=isfinite(V) & V~=0;values=sort(V(valid));
D=zeros(size(V),'single');if isempty(values),return;end
lo=values(max(1,round(.01*numel(values))));hi=values(max(1,round(.998*numel(values))));
if hi<=lo,hi=max(values);lo=0;end
D=min(1,max(0,(V-lo)/max(eps('single'),hi-lo)));D(~valid)=0;
switch preset
    case 'Mask Editor standard'
        standardInput=V;
        % Saved log-Doppler underlays can be entirely negative. The Mask
        % Editor power preset clips negative input, so first window these
        % display pixels into 0..1 rather than showing an empty overlay.
        % Raw optimizer inputs and quantitative PSC are never changed.
        if max(values)<=0,standardInput=D;end
        for k=1:size(D,1),D(k,:,:)=fusiStandardDopplerDisplay(squeeze(standardInput(k,:,:)));end
    case 'Log Doppler'
        D=log1p(30*D)/log(31);
    case 'Vessel detail'
        % Enhance each coronal view locally, as in an anatomical brainImage.
        % Blend CLAHE with linear power to limit amplification of faint noise.
        for k=1:size(D,1)
            plane=squeeze(D(k,:,:));
            detail=adapthisteq(plane,'ClipLimit',.005,'NumTiles',[8 8]);
            D(k,:,:)=.65*detail+.35*plane;
        end
        D(~valid)=0;
end
end
