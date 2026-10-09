function proc = computePSC(I, TR, par, baseline)
% computePSC (UPDATED: supports 2D + matrix probe 3D)
% ------------------------------------------------------------
% Classic PSC pipeline.
%
% Supports input:
%   - 2D probe:     I = [Y X T]
%   - Matrix probe: I = [Y X Z T]
%
% Steps:
% 1) temporal interpolation (integer factor N)  -> preserves Z
% 2) baseline window (seconds -> frames in interpolated grid)
% 3) PSC = (I1 - ab) ./ ab * 100
% 4) LPF (butter + filter) along time, memory-safe
% 5) connectivity suppression (2D per-slice per-frame)
% 6) gaussian spatial smoothing (2D per-slice per-frame)
% 7) background = mean over time -> log compression (preserves Z)
%
% IMPORTANT:
% - Interpolation increases INTERNAL samples only
% - Effective TR is adjusted so total time stays constant
% ------------------------------------------------------------

deConfUSIon_setup();
d = ndims(I);
assert(d==3 || d==4, 'computePSC: I must be [Y X T] or [Y X Z T].');
assert(isscalar(TR) && isfinite(TR) && TR>0, 'computePSC: TR must be positive scalar.');

if d == 3
    [nY,nX,nVols] = size(I);
    nZ = 1;
else
    [nY,nX,nZ,nVols] = size(I);
end

Tmax_orig = (nVols - 1) * TR;
externalBaseline=fusiBaselineReference('isExternal',baseline);
if externalBaseline, externalMean=fusiBaselineReference('validate',baseline.reference,size(I,1:d-1)); end
% Validate before allocating/interpolating a potentially multi-GB recording.
if ~externalBaseline && (~isscalar(baseline.start) || ~isscalar(baseline.end) || ...
        ~isfinite(baseline.start) || ~isfinite(baseline.end) || ...
        baseline.start<0 || baseline.end<=baseline.start || ...
        baseline.start>Tmax_orig || baseline.end<0)
    error('deConfUSIon:BadBaseline', ...
        'Baseline must overlap 0-%.6g seconds (%d frames, TR %.6g s). Choose a valid window.',Tmax_orig,nVols,TR);
end

%% 1) Temporal interpolation (integer factor N)
baselineProgress(par,'Preparing current scan time series...');
I = single(I);
N = 1;
if isfield(par,'interpol') && ~isempty(par.interpol)
    N = max(1, round(par.interpol));
end

% Time grid: correct length preserves endpoints
% nFrames = (nVols-1)*N + 1
I1 = interpFilmND(I, N);
nFrames = size(I1, ndims(I1));  % last dim is time
TR_eff  = TR / N;
Tmax_eff = (nFrames - 1) * TR_eff;

%% 2) Baseline window (sec ? interpolated frames)
if externalBaseline
    ab=externalMean;
    b0=baseline.reference.frames(1);b1=baseline.reference.frames(2);
else
b0 = round(baseline.start / TR_eff) + 1;
b1 = round(baseline.end   / TR_eff) + 1; % inclusive

b0 = max(1, b0);
b1 = min(nFrames, b1);

if ~isfinite(b0) || ~isfinite(b1) || b0 > b1 || b1 < 1 || b0 > nFrames
    error('deConfUSIon:BadBaseline','Baseline does not overlap the acquisition. Choose a valid window.');
end

% Compute baseline mean, preserving Z if present
if d == 3
    ab = deConfUSIon_signal('mean',I1(:,:,b0:b1),3);
else
    ab = deConfUSIon_signal('mean',I1(:,:,:,b0:b1),4);
end
end

validBaseline = isfinite(ab) & ab > 0;
ab(~validBaseline) = NaN;

%% 3) PSC
baselineProgress(par,'Normalizing current scan against the baseline...');
if d == 3
    PSC = bsxfun(@rdivide, bsxfun(@minus, I1, ab), ab) * 100;   % [Y X T]
else
    % expand ab across time without huge repmat
    PSC = bsxfun(@rdivide, bsxfun(@minus, I1, ab), ab) * 100;   % [Y X Z T]
end
PSC = single(PSC);

%% 4) LPF (memory-safe, along time)
baselineProgress(par,'Applying temporal filtering...');
if isfield(par,'LPF') && ~isempty(par.LPF) && par.LPF > 0
    % NOTE: this assumes par.LPF is already normalized (0..1) as in your pipeline
    try
        [B,A] = butter(4, par.LPF, 'low');
    catch ME
        warning('LPF skipped (butter failed): %s', ME.message);
        B=[]; A=[];
    end

    if ~isempty(B)
        if d == 3
            % PSC: [Y X T] -> reshape to [Y*X, T] in chunks
            PSC = lpf_time_chunks_3d(PSC, B, A);
        else
            % PSC: [Y X Z T] -> reshape to [Y*(X*Z), T] in chunks
            PSC = lpf_time_chunks_4d(PSC, B, A);
        end
    end
end

%% 5) Connectivity suppression (2D per slice/frame)
if isfield(par,'conectSize') && ~isempty(par.conectSize) && par.conectSize > 0
    h   = fspecial('disk', par.conectSize);
    lev = par.conectLev;

    if d == 3
        for k = 1:nFrames
            mask = filter2(h, PSC(:,:,k) > lev).^2;
            PSC(:,:,k) = PSC(:,:,k) .* mask;
        end
    else
        for z = 1:nZ
            for k = 1:nFrames
                tmp  = PSC(:,:,z,k);
                mask = filter2(h, tmp > lev).^2;
                PSC(:,:,z,k) = tmp .* mask;
            end
        end
    end
end

%% 6) Gaussian spatial smoothing (2D per slice/frame)
baselineProgress(par,'Applying spatial filtering...');
if isfield(par,'gaussSize') && ~isempty(par.gaussSize) && par.gaussSize > 0
    sig = 0;
    if isfield(par,'gaussSig') && ~isempty(par.gaussSig)
        sig = par.gaussSig;
    end
    hG = fspecial('gaussian', par.gaussSize, sig);

    if d == 3
        for k = 1:nFrames
            PSC(:,:,k) = smoothFiniteFrame(PSC(:,:,k),hG);
        end
    else
        for z = 1:nZ
            for k = 1:nFrames
                PSC(:,:,z,k) = smoothFiniteFrame(PSC(:,:,z,k),hG);
            end
        end
    end
end

%% 7) Background (log compressed, preserves Z)
baselineProgress(par,'Preparing current scan display...');
if d == 3
    bg = mean(I, 3);            % [Y X]
else
    bg = mean(I, 4);            % [Y X Z]
end

m = max(bg(:));
if m <= 0 || ~isfinite(m)
    bg = zeros(size(bg), 'single');
else
    bg = 20 * log10(bg ./ m);
end

%% Output
proc = struct();
proc.I1             = I1;
proc.PSC            = PSC;
proc.bg             = double(bg);      % keep as double for display tools
proc.nFrames        = nFrames;
proc.nVols          = nVols;
proc.TR             = TR;              % original
proc.TR_eff         = TR_eff;          % effective TR after interpolation
proc.Tmax           = Tmax_eff;
proc.Tmax_orig      = Tmax_orig;
proc.baselineFrames = [b0 b1];
proc.baselineValidMask = validBaseline;
proc.baselineWindowSec = ([b0 b1]-1)*TR_eff;
proc.baselineMean = ab;
proc.baseline = baseline;
if externalBaseline, proc.baselineWindowSec=baseline.reference.windowSec; end
proc.isMatrixProbe  = (d == 4);
proc.nZ             = nZ;

end

%% ============================================================
function I1 = interpFilmND(I, N)
% interpFilmND - integer-factor temporal interpolation along last dim
% Keeps endpoints: nFrames = (nVols-1)*N + 1
%
% Input:
%   - I:  [Y X T] or [Y X Z T]
% Output:
%   - I1: [Y X T'] or [Y X Z T']

if N <= 1
    I1 = I;
    return;
end

d = ndims(I);
if d == 3
    [nY,nX,nT] = size(I);
    nZ = 1;
    nFrames = (nT-1)*N + 1;

    t  = 1:nT;
    tq = linspace(1, nT, nFrames);

    V = reshape(I, [nY*nX, nT]);               % [Vox T]
    Vq = zeros(nY*nX, nFrames, 'single');

    % chunked interp to avoid huge temp doubles
    chunk = max(1,floor(32*1024^2/(24*(nT+nFrames))));
    for s = 1:chunk:size(V,1)
        e = min(size(V,1), s+chunk-1);
        Vq(s:e,:) = single(interp1(t, double(V(s:e,:)).', tq, 'linear', 'extrap')).';
    end

    I1 = reshape(Vq, [nY, nX, nFrames]);

else
    [nY,nX,nZ,nT] = size(I);
    nFrames = (nT-1)*N + 1;

    t  = 1:nT;
    tq = linspace(1, nT, nFrames);

    V = reshape(I, [nY*nX*nZ, nT]);            % [Vox T]
    Vq = zeros(nY*nX*nZ, nFrames, 'single');

    chunk = max(1,floor(32*1024^2/(24*(nT+nFrames))));
    for s = 1:chunk:size(V,1)
        e = min(size(V,1), s+chunk-1);
        Vq(s:e,:) = single(interp1(t, double(V(s:e,:)).', tq, 'linear', 'extrap')).';
    end

    I1 = reshape(Vq, [nY, nX, nZ, nFrames]);
end

end

%% ============================================================
function PSC = lpf_time_chunks_3d(PSC, B, A)
% PSC: [Y X T]  -> filter along T
[nY,nX,nT] = size(PSC);
V = reshape(PSC, [nY*nX, nT]);           % [vox T]

chunk = max(1,floor(32*1024^2/(32*nT)));
nPad = 3*(max(numel(B),numel(A))-1);
for s = 1:chunk:size(V,1)
    e = min(size(V,1), s+chunk-1);
    tmp = double(V(s:e,:));
    if size(tmp,2) > nPad
        tmp = filtfilt(B, A, tmp.').';
    else
        tmp = filter(B, A, tmp, [], 2);
    end
    V(s:e,:) = single(tmp);
end

PSC = reshape(V, [nY,nX,nT]);
end

function PSC = lpf_time_chunks_4d(PSC, B, A)
% PSC: [Y X Z T] -> filter along T
[nY,nX,nZ,nT] = size(PSC);
V = reshape(PSC, [nY*nX*nZ, nT]);        % [vox T]

chunk = max(1,floor(32*1024^2/(32*nT)));
nPad = 3*(max(numel(B),numel(A))-1);
for s = 1:chunk:size(V,1)
    e = min(size(V,1), s+chunk-1);
    tmp = double(V(s:e,:));
    if size(tmp,2) > nPad
        tmp = filtfilt(B, A, tmp.').';
    else
        tmp = filter(B, A, tmp, [], 2);
    end
    V(s:e,:) = single(tmp);
end

PSC = reshape(V, [nY,nX,nZ,nT]);
end

function out = smoothFiniteFrame(in,kernel)
% Keep invalid baselines invalid without spreading NaNs into valid tissue.
valid=isfinite(in);
if all(valid(:)), out=filter2(kernel,in); return; end
values=in; values(~valid)=0;
weights=filter2(kernel,double(valid));
% Preserve the existing zero-padding behavior at the image boundary.
fullWeights=filter2(kernel,ones(size(in)));
out=filter2(kernel,values).*fullWeights./weights;
out(~valid | weights<=0)=NaN;
end

function baselineProgress(par,message)
if isfield(par,'baselineProgressFcn'),par.baselineProgressFcn(message);end
end
