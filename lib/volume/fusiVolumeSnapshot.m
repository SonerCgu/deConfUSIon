function S = fusiVolumeSnapshot(data, opt, anatomy)
% Prepare a native-grid 3D view without changing the source arrays.
% PSC uses acquired samples, not additional interpolated time points. Missing
% data/masked samples remain missing; the mean requires full voxel support.
sz = [size(data.PSC,1) size(data.PSC,2) size(data.PSC,3)];
if ndims(data.PSC) ~= 4 || sz(3) < 2
    error('deConfUSIon:VolumeShape','A 3D recording [row column slice time] is required.');
end
step = max(1, round(data.interpol));
indices = 1:step:size(data.PSC,4);
timeSec = (indices-1)*data.TR/step;
if strcmp(opt.mode,'Frame')
    selected = round(opt.frame);
    if selected<1 || selected>numel(indices)
        error('deConfUSIon:VolumeTime','Frame is outside the recording.');
    end
else
    limits = double(opt.intervalMin(:)')*60;
    if numel(limits)~=2 || any(~isfinite(limits)) || limits(1)>limits(2) ...
            || limits(1)<0 || limits(2)>timeSec(end)+1e-6
        error('deConfUSIon:VolumeTime','Choose an interval inside 0 to %.6g min.',timeSec(end)/60);
    end
    selected = find(timeSec>=limits(1)-1e-6 & timeSec<=limits(2)+1e-6);
    if isempty(selected), error('deConfUSIon:VolumeTime','The interval contains no acquired samples.'); end
end
z = round(double(opt.slices(:)'));
if numel(z)~=2 || any(~isfinite(z)) || z(1)<1 || z(2)>sz(3) || z(1)>=z(2)
    error('deConfUSIon:VolumeSlices','Choose at least two consecutive slices inside 1 to %d.',sz(3));
end
spacing = double(opt.spacing(:)');
if numel(spacing)~=3 || any(~isfinite(spacing) | spacing<=0)
    error('deConfUSIon:VolumeSpacing','Row, column and slice spacing must all be positive.');
end
keep = true(sz(1),sz(2),z(2)-z(1)+1);
overlayMask=isfield(opt,'applyOverlayMask') && opt.applyOverlayMask;
acc = zeros(size(keep),'double');
for k=selected
    a = double(data.PSC(:,:,z(1):z(2),indices(k)));
    good = isfinite(a);
    if (opt.applyMask || overlayMask) && isfield(data,'mask') && ~isempty(data.mask)
        m = logical(data.mask(:,:,:,min(k,size(data.mask,4))));
        % Match Video GUI: an empty mask imposes no restriction.
        if any(m(:))
            m=m(:,:,z(1):z(2));
            if ~data.maskIsInclude, m=~m; end
            good=good & m;
        end
    end
    keep=keep & good;
    a(~good)=0; acc=acc+a;
end
psc = single(acc/numel(selected)); psc(~keep)=NaN;
% Anatomy is invariant across movie frames unless a time-dependent ROI mask
% is applied to it. Reuse the already prepared display arrays in that case.
if nargin>=3 && ~isempty(anatomy) && ~opt.applyMask
    S=anatomy;S.psc=psc;S.timeSec=[timeSec(selected(1)) timeSec(selected(end))];
    S.originalFrames=selected;S.frameCount=numel(selected);return;
end
u = data.underlay; note='';reference='Video underlay';
if isfield(opt,'underlaySource') && strcmp(opt.underlaySource,'Baseline Doppler') ...
        && isfield(data,'baselineUnderlay') && ~isempty(data.baselineUnderlay)
    u=data.baselineUnderlay;reference='Baseline Doppler';
    % Apply the Video contrast controls to the same logarithmic Doppler
    % representation it normally uses. The raw baseline is retained below.
    peak=max(u(:),[],'omitnan');
    u=20*log10(max(u,eps('single'))/max(peak,eps('single')));
end
if ndims(u)==4 && size(u,3)==3 && size(u,4)==sz(3) && isequal([size(u,1) size(u,2)],sz(1:2))
    u = reshape(single(u(:,:,1,:))*.2989+single(u(:,:,2,:))*.5870+single(u(:,:,3,:))*.1140,sz);
    note='RGB underlay converted to luminance.';
elseif ~isequal([size(u,1) size(u,2) size(u,3)],sz) || ndims(u)>3
    if isfield(data,'inputIsPSC') && data.inputIsPSC
        error('deConfUSIon:VolumeUnderlay','Select a full 3D Doppler underlay before opening the volume view. The current underlay is a single plane.');
    end
    if ~isequal([size(data.I,1) size(data.I,2) size(data.I,3)],sz) || ndims(data.I)~=4
        error('deConfUSIon:VolumeUnderlay','The underlay and recording must share the same 3D grid.');
    end
    u = zeros(sz,'single');
    valid = true(sz);
    for k=1:size(data.I,4)
        a=single(data.I(:,:,:,k)); valid=valid & isfinite(a); a(~isfinite(a))=0;
        u=u+a/size(data.I,4);
    end
    u(~valid)=NaN;
    note='Single-plane underlay replaced by the recording mean Doppler volume.';
end
u = single(u(:,:,z(1):z(2)));
validU = isfinite(u);
if opt.applyMask, validU=validU & keep; end
values=sort(double(u(validU)));
if isempty(values), error('deConfUSIon:VolumeUnderlay','No finite underlay voxels remain.'); end
lo=values(max(1,round(.01*numel(values))));
hi=values(max(1,round(.995*numel(values))));
if hi<=lo, lo=min(values); hi=max(values); end
raw=u;
processor=[];
if strcmp(reference,'Baseline Doppler') && isfield(data,'processBaseline'),processor=data.processBaseline;
elseif isfield(data,'processUnderlay'),processor=data.processUnderlay;end
preset='Video / saved Mask Editor';
if isfield(opt,'underlayPreset'),preset=opt.underlayPreset;end
standard=strcmp(preset,'Mask Editor standard') || ...
    (~isa(processor,'function_handle') && strcmp(preset,'Video / saved Mask Editor'));
if isfield(data,'underlayProcessed') && data.underlayProcessed && strcmp(reference,'Video underlay') && strcmp(preset,'Video / saved Mask Editor')
    u=min(1,max(0,raw));u(~validU)=0;
elseif standard && isfield(data,'baselineUnderlay') && ~isempty(data.baselineUnderlay)
    for k=1:size(u,3),u(:,:,k)=fusiStandardDopplerDisplay(data.baselineUnderlay(:,:,z(1)+k-1));end
    u(~validU)=0;
elseif isa(processor,'function_handle')
    for k=1:size(u,3)
        a=processor(raw(:,:,k));
        u(:,:,k)=single(.2989*a(:,:,1)+.5870*a(:,:,2)+.1140*a(:,:,3));
    end
    u(~validU)=0;
elseif hi<=lo
    u(:)=0; u(validU)=1;
else
    u=min(1,max(0,(u-lo)/(hi-lo))); u(~validU)=0;
end
% Background detection uses linear baseline power, not the stretched display
% contrast, so a dark/noisy acquisition face cannot become an opaque wall.
signal=u;
if isfield(data,'baselineUnderlay') && ~isempty(data.baselineUnderlay)
    signal=single(data.baselineUnderlay(:,:,z(1):z(2)));
    v=sort(double(signal(isfinite(signal) & signal>0)));
    if ~isempty(v)
        peak=v(max(1,round(.995*numel(v))));
        signal=min(1,max(0,signal/max(peak,eps)));signal(~isfinite(signal))=0;
    else
        signal(:)=0;
    end
end
S=struct('underlay',u,'underlayValid',validU,'psc',psc,'spacing',spacing, ...
    'units',opt.units,'slices',z,'timeSec',[timeSec(selected(1)) timeSec(selected(end))], ...
    'originalFrames',selected,'frameCount',numel(selected),'underlayRange',[lo hi], ...
    'note',note,'maskApplied',logical(opt.applyMask),'overlayMaskApplied',overlayMask, ...
    'signal',signal,'underlaySource',reference,'source',data.label);
end
