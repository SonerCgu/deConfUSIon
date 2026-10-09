function [rgb,alpha,info,v,background] = fusiVolumeRGBA(S,s,background)
% Explicit straight-alpha composition; reuse Video's PSC transfer exactly.
if nargin<3,background=[];end
v=S.psc;
if s.overlaySmoothSigma>0 && exist('imgaussfilt','file')==2
    for z=1:size(v,3)
        a=v(:,:,z);finite=isfinite(a);a(~finite)=0;
        a=imgaussfilt(a,s.overlaySmoothSigma,'FilterSize',max(3,2*ceil(2*s.overlaySmoothSigma)+1),'Padding','replicate');
        a(~finite)=NaN;v(:,:,z)=a;
    end
end
if isempty(background)
u=S.underlay;signal=S.signal;
gamma=1;gain=1;
if isfield(s,'underlayGamma'),gamma=s.underlayGamma;end
if isfield(s,'underlayGain'),gain=s.underlayGain;end
u=min(1,max(0,u).^gamma*gain);
cut=s.underlayCutoff; rayOpacity=s.underlayOpacity;
if s.autoBackground
    profile=fusiVolumeAutoAppearance(S);cut=profile.cutoff;rayOpacity=profile.opacity;
end
support=S.underlayValid & signal>=cut;
if s.autoBackground && (gamma~=1 || gain~=1)
    % Keep overall anatomy attenuation balanced when display contrast rises,
    % rather than obscuring PSC with a brighter opaque foreground.
    before=sum(S.underlay(support),'double');after=sum(u(support),'double');
    if after>0,rayOpacity=rayOpacity*before/after;end
end
% Ray opacity is deliberately separate from the 2D overlay opacity. Raising
% this to one makes the acquisition faces opaque; the control explains this.
ab=u*rayOpacity;ab(~support)=0;
if isfield(s,'showDoppler') && ~s.showDoppler,ab(:)=0;end
alpha=ab;rgb=repmat(u.*ab,1,1,1,3);
if isfield(S,'atlasReference')
    tissue=S.atlasReference;atlasOpacity=.025;
    if isfield(s,'atlasOpacity'),atlasOpacity=s.atlasOpacity;end
    tissueWeight=single(S.atlasBrainMask).*max(.15,tissue);atlasTone=tissue;
    if isfield(s,'atlasOpacityMode') && strcmp(s.atlasOpacityMode,'overall')
        % The UI specifies overall context opacity, not opacity at every
        % one of hundreds of tissue voxels. A 20% context must not become an
        % opaque shell that hides the functional signal behind it.
        pathWeight=1;
        for axis=1:3,pathWeight=max(pathWeight,max(sum(tissueWeight,axis),[],'all'));end
        at=1-(1-min(1,atlasOpacity)).^(tissueWeight/pathWeight);
        % Preserve a readable tissue outline at low overall opacity without
        % increasing foreground attenuation of deep functional responses.
        atlasTone=min(1,1.5*sqrt(max(0,tissue)));
    else,at=atlasOpacity*tissueWeight;end
    % Neutral blue-gray tissue shows the complete atlas brain independently
    % of the animal's limited Doppler field. No PSC is invented there.
    if isfield(s,'atlasOpacityMode') && strcmp(s.atlasOpacityMode,'overall')
        atlasRGB=cat(4,.85*atlasTone,.90*atlasTone,.95*atlasTone).*at;
    else,atlasRGB=cat(4,.65*tissue,.75*tissue,.85*tissue).*at;end
    rgb=rgb+atlasRGB.*(1-ab);alpha=ab+at.*(1-ab);
end
background=struct('rgb',rgb,'alpha',alpha,'cut',cut,'rayOpacity',rayOpacity,'visibleFraction',nnz(ab>0)/numel(ab));
else
    rgb=background.rgb;alpha=background.alpha;cut=background.cut;rayOpacity=background.rayOpacity;
end
if s.showPSC
    transfer=s.display;
    if isfield(s,'clearPSC'),transfer.colormap=fusiVolumePSCColormap(transfer.colormap,s.clearPSC);end
    [~,ap,color]=fusiOverlayAppearance(double(v),transfer,1);
    limit=max(0,min(1,s.display.alphaPct/100));
    if isfield(s,'clearPSC') && s.clearPSC && limit>0
        ap=limit*sqrt(ap/limit); % Lift the visible ramp, retain zero-alpha voxels.
    end
    if isfield(s,'pscStrength'),ap=min(limit,ap*s.pscStrength);end
    % Avoid burying responses behind bright foreground vessels / atlas tissue.
    % This is an independent display transfer; it never alters PSC or masks.
    if isfield(s,'clearPSC') && s.clearPSC
        envelope=imgaussfilt3(single(ap),1,'Padding','replicate');
        attenuation=1-.8*min(1,envelope/max(limit,eps));
        rgb=rgb.*attenuation;alpha=alpha.*attenuation;
    end
    if isfield(S,'atlasCoverageMask'),ap(~S.atlasCoverageMask)=0;end
    % Faint-Doppler hiding controls the vascular background, not the Video
    % PSC transfer. Low baseline power alone must not erase a valid response.
    ap=single(ap);
    rgb=rgb.*(1-ap)+color.*ap;alpha=alpha.*(1-ap)+ap;
end
rgb=rgb./max(alpha,eps('single'));rgb=min(1,max(0,rgb));
info=struct('effectiveBackgroundCutoff',cut,'effectiveVesselOpacity',rayOpacity,'visibleDopplerFraction',background.visibleFraction, ...
    'opacityRule','Inherited Doppler display brightness times ray opacity; PSC uses the Video GUI transfer.');
info.clearPSC=isfield(s,'clearPSC') && s.clearPSC;
info.pscStrength=1;if isfield(s,'pscStrength'),info.pscStrength=s.pscStrength;end
if isfield(s,'atlasOpacityMode'),info.atlasOpacityMode=s.atlasOpacityMode;end
end
