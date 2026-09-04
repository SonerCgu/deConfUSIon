function [I_corr, stats] = deConfUSIon_driftcompensation_core(I, TR, exportPath, opts)
% =========================================================================
% deConfUSIon - Signal Drift Compensation Engine  (v2)
% =========================================================================
% MATLAB 2017b - 2023b. No toolbox dependencies beyond base MATLAB.
%
% WHY SEVERAL METHODS EXIST
%   In pharmacological fUSI the drug response is SLOW, i.e. it lives in the
%   same frequency band as the drift. Anything that separates them purely by
%   frequency (high-pass, DCT, aggressive polynomials) removes the response
%   together with the drift. The methods below differ in HOW they tell the
%   two apart: by time window, by robustness, by space, or by measurement.
%
% METHODS (opts.method)
%   'anchor'    RECOMMENDED when the response returns towards baseline.
%               Fits the trend on the pre-injection window AND a late tail
%               window, then INTERPOLATES between them. Stable, because the
%               fit is bracketed by data instead of extrapolated.
%
%   'baseline'  Fits only on pre-injection frames and EXTRAPOLATES.
%               Cannot absorb the response, but the slope error grows with
%               the extrapolation distance - unstable for long runs.
%               A stability warning is issued automatically.
%
%   'robust'    Whole-run polynomial fit with iteratively reweighted least
%               squares (Tukey bisquare). The response epochs behave like
%               outliers and get down-weighted, so the trend follows the
%               drift. Good when the response is short relative to the run.
%
%   'poly'      Plain whole-run polynomial detrend (classic detrending).
%               Most stable numerically, but WILL absorb part of a sustained
%               response. Use with a low order and check the QC plot.
%
%   'vehicle'   Subtracts a vehicle / aCSF scan of the same animal in
%               fractional-change space. Measured drift + injection artefact.
%
%   'glm'       BEST when the injection time is known. Fits drift basis AND
%               an explicit response model (transient gamma + sustained
%               boxcar) in ONE design, then removes ONLY the drift part.
%               The response is protected because it is modelled, not
%               assumed away. Reports collinearity between the two blocks.
%
%   'compcor'   Multi-component CompCor: takes the top-K principal
%               components of a NOISE region (mask, or automatically the
%               low-signal voxels) and regresses them out. Captures
%               spatially heterogeneous drift that a single ROI misses.
%
%   'spline'    Robust piecewise-linear (hat-basis) drift with knots every
%               knotSec seconds, fitted with IRLS weights. Follows drift that
%               is NOT polynomial (probe warm-up, coupling steps) while the
%               response is down-weighted. Most flexible time-domain option.
%
%   'dct'       Discrete-cosine high-pass (SPM style): removes everything
%               slower than cutoffSec. Simple and standard, but it CANNOT
%               distinguish a slow response from drift - only use when the
%               response is clearly faster than the cutoff.
%
%   'reference' Regresses out the mean time course of a non-responsive mask
%               (single time course). Simpler predecessor of 'compcor'.
%
% INPUT
%   I           [Y X T] or [Y X Z T]
%   TR          seconds per frame
%   exportPath  folder for the QC PNG
%   opts        struct (see below)
%
% OPTS
%   .method        see above                                (default 'anchor')
%   .baselineSec   [t0 t1] pre-injection window             (default [0 60])
%   .tailSec       [t0 t1] late window, 'anchor' only       (default last 25%)
%   .polyOrder     0..3                                     (default 1)
%   .robustIter    IRLS iterations, 'robust' only           (default 5)
%   .restoreMode   'baseline' | 'runmean' | 'none'          (default 'baseline')
%   .vehicleI / .vehicleTR / .vehicleSmoothSec              ('vehicle')
%   .refMask                                                ('reference')
%   .chunkVoxels   voxels per chunk                         (default 50000)
%   .verbose                                                (default true)
%
% OUTPUT
%   I_corr, stats (incl. QC path, drift reduction, stability diagnostics)
%
% PIPELINE ORDER
%   After motion / frame rejection / scrubbing, BEFORE computePSC.
% =========================================================================

tStart = tic;

% ------------------------------------------------------------------ inputs
if nargin < 2 || isempty(TR)
    error('driftcompensation:NoTR','TR (seconds per frame) is required.');
end
if nargin < 3 || isempty(exportPath), exportPath = pwd; end
if nargin < 4 || isempty(opts), opts = struct(); end
if isempty(I) || ~isnumeric(I)
    error('driftcompensation:BadInput','Input I must be a non-empty numeric array.');
end

if numel(TR) > 1, TR = TR(end); end
TR = double(TR);
if ~isfinite(TR) || TR <= 0
    error('driftcompensation:BadTR','Invalid TR: must be a positive scalar in seconds.');
end

opts = localDefault(opts,'method','anchor');
opts = localDefault(opts,'polyOrder',1);
opts = localDefault(opts,'robustIter',5);
opts = localDefault(opts,'nComp',3); % DRIFT_COMPCOR_SAFE_DEFAULT
opts = localDefault(opts,'knotSec',120);
opts = localDefault(opts,'cutoffSec',240);
opts = localDefault(opts,'restoreMode','baseline');
opts = localDefault(opts,'chunkVoxels',50000);
opts = localDefault(opts,'verbose',true);
opts = localDefault(opts,'vehicleSmoothSec',15);
opts = localDefault(opts,'tag',datestr(now,'yyyymmdd_HHMMSS'));

if isfield(opts,'restoreMean') && ~isempty(opts.restoreMean) && ~opts.restoreMean
    opts.restoreMode = 'none';
end
restoreMode = lower(strtrim(opts.restoreMode));
if ~any(strcmp(restoreMode,{'baseline','runmean','none'}))
    error('driftcompensation:BadRestoreMode', ...
        'opts.restoreMode must be ''baseline'', ''runmean'' or ''none'' (got ''%s'').', restoreMode);
end

origClass = class(I);
dims = size(I);
nd   = ndims(I);
if nd == 3
    ny = dims(1); nx = dims(2); nz = 1;  T = dims(3);
elseif nd == 4
    ny = dims(1); nx = dims(2); nz = dims(3); T = dims(4);
else
    error('driftcompensation:BadDims', ...
        'Need a 3D [Y X T] or 4D [Y X Z T] time series (got %d dims).', nd);
end
if T < 8
    error('driftcompensation:TooShort','Time series too short (T=%d).',T);
end

V = ny*nx*nz;
t = (0:T-1)' * TR;

% ------------------------------------------------------------- windows
if ~isfield(opts,'baselineSec') || isempty(opts.baselineSec)
    opts.baselineSec = [0 min(60, t(end))];
end
bs = double(opts.baselineSec(:))';
if numel(bs) ~= 2 || ~all(isfinite(bs)) || bs(2) <= bs(1)
    error('driftcompensation:BadBaseline','opts.baselineSec must be [t0 t1] with t1 > t0.');
end
bIdx = find(t >= bs(1) & t <= bs(2));
if numel(bIdx) < 4
    error('driftcompensation:BaselineTooShort', ...
        'Baseline [%g %g] s holds only %d frames (need >= 4). TR=%g s, run=%g s.', ...
        bs(1), bs(2), numel(bIdx), TR, t(end));
end

method = lower(strtrim(opts.method));

ts_ = [];
tIdx = [];
if strcmp(method,'anchor')
    if ~isfield(opts,'tailSec') || isempty(opts.tailSec)
        opts.tailSec = [t(end) - 0.25*t(end), t(end)];
    end
    ts_ = double(opts.tailSec(:))';
    if numel(ts_) ~= 2 || ~all(isfinite(ts_)) || ts_(2) <= ts_(1)
        error('driftcompensation:BadTail','opts.tailSec must be [t0 t1] with t1 > t0.');
    end
    if ts_(1) <= bs(2)
        error('driftcompensation:TailOverlapsBaseline', ...
            'Tail window must start after the baseline ends (tail %g s <= baseline end %g s).', ...
            ts_(1), bs(2));
    end
    tIdx = find(t >= ts_(1) & t <= ts_(2));
    if numel(tIdx) < 4
        error('driftcompensation:TailTooShort', ...
            'Tail [%g %g] s holds only %d frames (need >= 4).', ts_(1), ts_(2), numel(tIdx));
    end
end

p = round(double(opts.polyOrder));
if ~isfinite(p) || p < 0 || p > 3
    error('driftcompensation:BadPolyOrder','polyOrder must be 0..3 (got %g).',opts.polyOrder);
end
if strcmp(method,'glm') && p > 1
    warning('driftcompensation:HigherOrderGLM', ...
        ['Quadratic/cubic GLM drift can overlap strongly with a slow drug response. ' ...
         'Use linear order 1 as the primary analysis and higher orders only as sensitivity checks.']);
end

if opts.verbose
    fprintf('[Drift] method=%s | dims=[%s] | TR=%.4f s | T=%d | baseline %.1f-%.1f s (%d fr)\n', ...
        method, num2str(dims), TR, T, bs(1), bs(2), numel(bIdx));
    if ~isempty(tIdx)
        fprintf('[Drift] tail %.1f-%.1f s (%d fr)\n', ts_(1), ts_(2), numel(tIdx));
    end
end

% ------------------------------------------------- stability diagnostics
baseSpan  = max(t(bIdx)) - min(t(bIdx));
extrapLen = t(end) - max(t(bIdx));
if baseSpan > 0
    extrapRatio = extrapLen / baseSpan;
else
    extrapRatio = Inf;
end

if strcmp(method,'baseline')
    if p >= 2 && extrapRatio > 2
        warning('driftcompensation:UnstableExtrapolation', ...
            ['Order %d extrapolated over %.1fx the baseline span is numerically unstable. ' ...
             'Use order 1, or better the ''anchor'' method.'], p, extrapRatio);
    elseif p >= 1 && extrapRatio > 5
        warning('driftcompensation:LongExtrapolation', ...
            ['Baseline trend is extrapolated over %.1fx the baseline span; ' ...
             'small slope errors are amplified accordingly. Consider ''anchor'' or ''robust''.'], ...
            extrapRatio);
    end
end

% ------------------------------------------------- reshape to voxels x time
Y = reshape(single(I), V, T);
finiteMask = all(isfinite(Y),2);
if ~any(finiteMask)
    error('driftcompensation:AllNonFinite','No finite voxels found.');
end

baseMean = mean(Y(:,bIdx),2);
runMean  = mean(Y,2);
meanImgBefore = reshape(runMean,[ny nx nz]);
meanTC_before = localSafeMean(Y, finiteMask);

driftEstimate = zeros(V,T,'single');
fitIdx  = [];
wUsed   = [];
glmCollinearity = NaN;
compcorVar      = NaN;

% scaled time for conditioning
tc = (t - mean(t)) / max(eps, std(t));
Af = localVander(tc, p);

switch method

    % =============================================== WINDOWED POLYNOMIAL
    case {'baseline','anchor','poly'}

        switch method
            case 'baseline', fitIdx = bIdx(:);
            case 'anchor',   fitIdx = unique([bIdx(:); tIdx(:)]);
            case 'poly',     fitIdx = (1:T)';
        end
        if numel(fitIdx) <= p
            error('driftcompensation:TooFewFitFrames', ...
                'Only %d frames available for a polynomial of order %d.', numel(fitIdx), p);
        end

        Aw = Af(fitIdx,:);
        for c0 = 1:opts.chunkVoxels:V
            c1  = min(V, c0 + opts.chunkVoxels - 1);
            blk = double(Y(c0:c1, fitIdx))';
            coef = Aw \ blk;
            driftEstimate(c0:c1,:) = single((Af * coef)');
        end

    % ================================================== ROBUST (IRLS)
    case {'robust','irls'}

        % 1) derive shared temporal weights from the global mean time course
        g = double(meanTC_before(:));
        w = ones(T,1);
        for it = 1:max(1,round(opts.robustIter))
            sw   = sqrt(w);
            coef = (bsxfun(@times, Af, sw)) \ (g .* sw);
            r    = g - Af*coef;
            s    = 1.4826 * median(abs(r - median(r)));
            if ~isfinite(s) || s <= 0, break; end
            u = r / (4.685*s);
            w = (abs(u) < 1) .* (1 - u.^2).^2;
            if all(w == 0), w = ones(T,1); break; end
        end
        wUsed = w;

        % 2) weighted least squares per voxel with those shared weights
        sw  = sqrt(w);
        Awt = bsxfun(@times, Af, sw);
        for c0 = 1:opts.chunkVoxels:V
            c1  = min(V, c0 + opts.chunkVoxels - 1);
            blk = double(Y(c0:c1,:))';
            coef = Awt \ bsxfun(@times, blk, sw);
            driftEstimate(c0:c1,:) = single((Af * coef)');
        end
        fitIdx = find(w > 0.05);

    % ============================================== VEHICLE / aCSF SCAN
    case {'vehicle','vehicle_subtract','acsf'}

        if ~isfield(opts,'vehicleI') || isempty(opts.vehicleI)
            error('driftcompensation:NoVehicle','opts.vehicleI is required for method ''vehicle''.');
        end
        Vh = opts.vehicleI;
        if ~isnumeric(Vh)
            error('driftcompensation:BadVehicle','opts.vehicleI must be numeric.');
        end
        vdims = size(Vh);
        if ndims(Vh) ~= nd
            error('driftcompensation:VehicleDimMismatch', ...
                'Vehicle has %d dims, drug scan has %d.', ndims(Vh), nd);
        end
        if ~isequal(vdims(1:end-1), dims(1:end-1))
            error('driftcompensation:VehicleGridMismatch', ...
                ['Vehicle grid [%s] does not match drug scan [%s]. Both scans must be ' ...
                 'pre-processed onto the same grid (same slices, same registration).'], ...
                num2str(vdims(1:end-1)), num2str(dims(1:end-1)));
        end

        vTR = TR;
        if isfield(opts,'vehicleTR') && ~isempty(opts.vehicleTR) && isfinite(double(opts.vehicleTR(end)))
            vTR = double(opts.vehicleTR(end));
        end
        Tv = vdims(end);
        tv = (0:Tv-1)' * vTR;
        Yv = reshape(single(Vh), V, Tv);

        vbIdx = find(tv >= bs(1) & tv <= bs(2));
        if numel(vbIdx) < 4
            vbIdx = 1:min(Tv, max(4, numel(bIdx)));
            warning('driftcompensation:VehicleBaselineFallback', ...
                'Vehicle baseline window empty; using the first %d frames.', numel(vbIdx));
        end
        vBase = mean(Yv(:,vbIdx),2);

        denom = vBase; denom(~isfinite(denom) | denom == 0) = NaN;
        Fv = bsxfun(@rdivide, bsxfun(@minus, Yv, vBase), denom);
        Fv(~isfinite(Fv)) = 0;

        wSec = double(opts.vehicleSmoothSec);
        if isfinite(wSec) && wSec > 0
            wlen = max(1, round(wSec / vTR));
            if wlen > 1
                Fv = single(movmean(double(Fv), wlen, 2, 'Endpoints','shrink'));
            end
        end

        if Tv ~= T || abs(vTR - TR) > 1e-9
            Fv = single(interp1(tv, double(Fv)', t, 'linear','extrap')');
        end
        driftEstimate = single(bsxfun(@times, Fv, baseMean));

    % ================================================== REFERENCE REGION
    case {'reference','reference_roi','refroi'} % DRIFT_COMPCOR_SWITCH_FIX

        if ~isfield(opts,'refMask') || isempty(opts.refMask)
            error('driftcompensation:NoRefMask','opts.refMask is required for method ''reference''.');
        end
        M = opts.refMask;
        if ~isequal(size(M), dims(1:end-1)) && numel(M) ~= V
            error('driftcompensation:RefMaskMismatch', ...
                'refMask size [%s] does not match spatial grid [%s].', ...
                num2str(size(M)), num2str(dims(1:end-1)));
        end
        m = logical(M(:));
        if nnz(m) < 5
            error('driftcompensation:RefMaskTooSmall','Reference mask has only %d voxels.',nnz(m));
        end

        ref = double(localSafeMean(Y, m & finiteMask));
        ref = ref(:) - mean(ref(bIdx));
        sd  = std(ref); if sd > 0, ref = ref/sd; end

        X = [ones(T,1), ref];
        for c0 = 1:opts.chunkVoxels:V
            c1  = min(V, c0 + opts.chunkVoxels - 1);
            blk = double(Y(c0:c1,:))';
            beta = X \ blk;
            beta(1,:) = 0;
            driftEstimate(c0:c1,:) = single((X*beta)');
        end


    % ============================================ GLM (MODELLED RESPONSE)
    case {'glm','model'}

        if ~isfield(opts,'injectionSec') || isempty(opts.injectionSec)
            opts.injectionSec = bs(2);
        end
        ti = double(opts.injectionSec(1));
        if ~isfinite(ti) || ti < 0 || ti >= t(end)
            error('driftcompensation:BadInjection', ...
                'injectionSec = %g s is outside the run (0 .. %g s).', ti, t(end));
        end
        if ~isfield(opts,'responseSec') || isempty(opts.responseSec)
            opts.responseSec = 0.25 * t(end);
        end
        L = double(opts.responseSec(1));
        if ~isfinite(L) || L <= 0
            error('driftcompensation:BadResponseLen','responseSec must be > 0.');
        end

        dt  = max(0, t - ti);
        tau = max(TR, L/4);
        rg = (dt./tau).^2 .* exp(-dt./tau);
        rg(t < ti) = 0;
        if max(rg) > 0, rg = rg / max(rg); end
        rb = double(t >= ti & t <= ti + L);
        wS = max(1, round((L/8)/TR));
        if wS > 1, rb = movmean(rb, wS, 'Endpoints','shrink'); end
        if max(rb) > 0, rb = rb / max(rb); end
        R = [rg(:), rb(:)];
        R = R(:, std(R,0,1) > 0);
        if isempty(R)
            error('driftcompensation:EmptyResponseModel', ...
                'Response model is degenerate - check injectionSec / responseSec.');
        end

        [Aart, artifactInfo] = deConfUSIon_build_artifact_regressors( ...
            Y, dims(1:end-1), finiteMask, t, opts, R);

        nD = size(Af,2);
        nR = size(R,2);
        nA = size(Aart,2);
        X  = [Af, R, Aart];

        Xz = bsxfun(@minus, X, mean(X,1));
        sdX = std(Xz,0,1); sdX(sdX == 0) = 1;
        Xz = bsxfun(@rdivide, Xz, sdX);
        Cxx = abs(Xz' * Xz) / max(1,(T-1));
        cross = Cxx(2:nD, nD+1:nD+nR);
        if isempty(cross), glmCollinearity = 0; else, glmCollinearity = max(cross(:)); end
        if nA > 0
            ca = Cxx(nD+nR+1:end,nD+1:nD+nR);
            if isempty(ca), artifactResponseCollinearity = 0; else, artifactResponseCollinearity = max(ca(:)); end
        else
            artifactResponseCollinearity = NaN;
        end
        if glmCollinearity > 0.8
            warning('driftcompensation:GLMCollinear', ...
                'Drift and protected response are %.0f%% correlated. Consider lower trend order.',100*glmCollinearity);
        end
        if isfinite(artifactResponseCollinearity) && artifactResponseCollinearity > 0.8
            warning('driftcompensation:ArtifactResponseCollinear', ...
                'Artifact and protected response are %.0f%% correlated. Persistent artifact may be inseparable from real response.',100*artifactResponseCollinearity);
        end
        if rank(X) < size(X,2)
            error('driftcompensation:GLMRankDeficient', ...
                'Joint GLM is rank deficient. Disable persistent artifact/CCA or reduce regressors.');
        end

        for c0 = 1:opts.chunkVoxels:V
            c1   = min(V, c0 + opts.chunkVoxels - 1);
            blk  = double(Y(c0:c1,:))';
            beta = X \ blk;
            nuisance = Af * beta(1:nD,:);
            if nA > 0
                nuisance = nuisance + Aart * beta(nD+nR+1:nD+nR+nA,:);
            end
            driftEstimate(c0:c1,:) = single(nuisance');
        end
        fitIdx = (1:T)';

    % ==================================================== COMPCOR VARIANTS / GSR
    case {'compcor','acompcor'}

        if ~isfield(opts,'compcorMode') || isempty(opts.compcorMode)
            opts.compcorMode = 'tcompcor';
        end
        if ~isfield(opts,'nComp') || isempty(opts.nComp)
            opts.nComp = 5;
        end
        Rcc = zeros(T,0);
        if isfield(opts,'protectResponse') && opts.protectResponse && ...
                isfield(opts,'injectionSec') && isfield(opts,'responseSec') && ...
                ~isempty(opts.injectionSec) && ~isempty(opts.responseSec)
            ti2 = double(opts.injectionSec(1));
            L2  = double(opts.responseSec(1));
            dt2 = max(0,t-ti2);
            tau2 = max(TR,L2/4);
            r1 = (dt2./tau2).^2 .* exp(-dt2./tau2);
            r1(t<ti2)=0; if max(r1)>0, r1=r1/max(r1); end
            r2 = double(t>=ti2 & t<=ti2+L2);
            if max(r2)>0, r2=r2/max(r2); end
            Rcc = [r1(:),r2(:)];
            Rcc = Rcc(:,std(Rcc,0,1)>0);
        end

        [PCs, compcorInfo] = deConfUSIon_build_compcor_regressors( ...
            Y, dims(1:end-1), finiteMask, baseMean, t, bIdx, opts, Rcc);
        compcorVar = compcorInfo.variancePercent;

        X = [ones(T,1), Rcc, PCs];
        nKeep = 1 + size(Rcc,2);
        if rank(X) < size(X,2)
            error('driftcompensation:CompCorRankDeficient', ...
                'CompCor design is rank deficient after response protection.');
        end
        for c0 = 1:opts.chunkVoxels:V
            c1   = min(V, c0 + opts.chunkVoxels - 1);
            blk  = double(Y(c0:c1,:))';
            beta = X \ blk;
            nuisance = PCs * beta(nKeep+1:end,:);
            driftEstimate(c0:c1,:) = single(nuisance');
        end
        fitIdx = (1:T)';

        if opts.verbose
            fprintf('[Drift] %s: %d regressors from %d voxels [%s], %.1f%% variance, response leakage %.3f\n', ...
                compcorInfo.mode, compcorInfo.nComponents, compcorInfo.nVoxels, ...
                compcorInfo.source, compcorInfo.variancePercent, compcorInfo.maxResponseCorrelation);
        end

    % =================================== SPLINE (ROBUST PIECEWISE-LINEAR)
    case {'spline','piecewise'}

        kSec = double(opts.knotSec);
        if ~isfinite(kSec) || kSec <= 0
            error('driftcompensation:BadKnotSec','knotSec must be > 0.');
        end
        knots = (0:kSec:t(end))';
        if knots(end) < t(end), knots(end+1) = t(end); end
        if numel(knots) < 2
            error('driftcompensation:TooFewKnots', ...
                'knotSec = %g s gives fewer than 2 knots for a %g s run.', kSec, t(end));
        end

        % hat (tent) basis - one column per knot, partition of unity
        B = zeros(T, numel(knots));
        for kk = 1:numel(knots)
            if kk > 1
                seg = t >= knots(kk-1) & t <= knots(kk);
                B(seg,kk) = (t(seg)-knots(kk-1)) / max(eps,(knots(kk)-knots(kk-1)));
            end
            if kk < numel(knots)
                seg = t >= knots(kk) & t <= knots(kk+1);
                B(seg,kk) = (knots(kk+1)-t(seg)) / max(eps,(knots(kk+1)-knots(kk)));
            end
        end
        B = B(:, sum(B,1) > 0);

        % IRLS weights from the global mean so the response is down-weighted
        g = double(meanTC_before(:));
        w = ones(T,1);
        for it = 1:max(1,round(opts.robustIter))
            sw = sqrt(w);
            cf = (bsxfun(@times,B,sw)) \ (g.*sw);
            r  = g - B*cf;
            sMad = 1.4826*median(abs(r - median(r)));
            if ~isfinite(sMad) || sMad <= 0, break; end
            u = r/(4.685*sMad);
            w = (abs(u)<1).*(1-u.^2).^2;
            if all(w==0), w = ones(T,1); break; end
        end
        wUsed = w;

        sw  = sqrt(w);
        Bwt = bsxfun(@times,B,sw);
        if rank(Bwt) < size(Bwt,2)
            error('driftcompensation:SplineRankDeficient', ...
                'Knot spacing %g s is too fine for the down-weighted frames - increase knotSec.', kSec);
        end
        for c0 = 1:opts.chunkVoxels:V
            c1 = min(V, c0 + opts.chunkVoxels - 1);
            blk = double(Y(c0:c1,:))';
            cf  = Bwt \ bsxfun(@times,blk,sw);
            driftEstimate(c0:c1,:) = single((B*cf)');
        end
        fitIdx = find(w > 0.05);

    % ============================================ DCT HIGH-PASS (SPM STYLE)
    case {'dct','highpass'}

        cSec = double(opts.cutoffSec);
        if ~isfinite(cSec) || cSec <= 0
            error('driftcompensation:BadCutoff','cutoffSec must be > 0.');
        end
        nK = floor(2*t(end)/cSec) + 1;
        nK = max(1, min(nK, T-1));

        D = zeros(T, nK);
        for kk = 1:nK
            D(:,kk) = cos(pi*(2*(0:T-1)'+1)*kk/(2*T));
        end
        X = [ones(T,1), D];

        if cSec > 0.5*t(end)
            warning('driftcompensation:CutoffTooLow', ...
                ['Cutoff %g s is longer than half the run (%g s); the basis is nearly ' ...
                 'constant and removes little.'], cSec, t(end));
        end
        warning('driftcompensation:DCTRemovesSlowSignal', ...
            ['DCT removes EVERY component slower than %g s, including a drug response ' ...
             'on that timescale. Verify on a known responsive ROI.'], cSec);

        for c0 = 1:opts.chunkVoxels:V
            c1 = min(V, c0 + opts.chunkVoxels - 1);
            blk = double(Y(c0:c1,:))';
            beta = X \ blk;
            beta(1,:) = 0;
            driftEstimate(c0:c1,:) = single((X*beta)');
        end
        fitIdx = (1:T)';

    otherwise
        error('driftcompensation:UnknownMethod', ...
            ['Unknown method ''%s''. Use anchor | baseline | robust | poly | glm | ' ...
             'compcor | spline | dct | vehicle | reference.'], opts.method);
end

% -------------------------------------------------------------- apply
driftEstimate(~isfinite(driftEstimate)) = 0;
Ycorr = Y - driftEstimate;

switch restoreMode
    case 'baseline'
        % Subtracting a fitted trend removes the constant term too. computePSC
        % divides by the baseline, so the pre-injection level must go back in.
        curBase = mean(Ycorr(:,bIdx),2);
        Ycorr   = bsxfun(@plus, Ycorr, baseMean - curBase);
    case 'runmean'
        curRun = mean(Ycorr,2);
        Ycorr  = bsxfun(@plus, Ycorr, runMean - curRun);
    case 'none'
        % leave centred
end

Ycorr(~finiteMask,:) = Y(~finiteMask,:);

meanTC_after = localSafeMean(Ycorr, finiteMask);
meanImgAfter = reshape(mean(Ycorr,2),[ny nx nz]);

% ----------------------------------------------------------- diagnostics
negBefore = sum(Y(:) < 0);
negAfter  = sum(Ycorr(:) < 0);
if negAfter > negBefore && negBefore == 0
    warning('driftcompensation:NegativeValues', ...
        ['%d samples became negative after correction - a sign of an unstable ' ...
         'extrapolated trend. Try order 1, a longer baseline, or the ''anchor'' method.'], negAfter);
end

gBefore = double(meanTC_before(:));
gAfter  = double(meanTC_after(:));
baseSD  = std(gBefore(bIdx));
removedAtEnd = abs(gBefore(end) - gAfter(end));
if baseSD > 0
    stabilityIndex = removedAtEnd / baseSD;
else
    stabilityIndex = NaN;
end
if isfinite(stabilityIndex) && stabilityIndex > 20 && any(strcmp(method,{'baseline','poly'}))
    warning('driftcompensation:LargeCorrection', ...
        ['The removed trend at the end of the run is %.1fx the baseline noise SD. ' ...
         'That is a very large correction - inspect the QC plot before trusting it.'], stabilityIndex);
end

I_corr = reshape(Ycorr, dims);
if ~strcmpi(origClass,'single')
    I_corr = cast(I_corr, origClass);
end

% -------------------------------------------------------------- QC figure
qcFile = '';
try
    if exist(exportPath,'dir') ~= 7, mkdir(exportPath); end
    qcDir = fullfile(exportPath,'Preprocessing');
    if exist(qcDir,'dir') ~= 7, mkdir(qcDir); end

    f = figure('Visible','off','Color','w','Position',[100 100 1300 800]);

    subplot(2,2,1); hold on; grid on;
    plot(t, gBefore,'-','LineWidth',1.3,'Color',[0.20 0.35 0.85]);
    plot(t, gAfter ,'-','LineWidth',1.3,'Color',[0.85 0.25 0.20]);
    yl = get(gca,'YLim');
    patch([bs(1) bs(2) bs(2) bs(1)],[yl(1) yl(1) yl(2) yl(2)], ...
        [0.35 0.80 0.35],'FaceAlpha',0.14,'EdgeColor','none');
    if ~isempty(ts_)
        patch([ts_(1) ts_(2) ts_(2) ts_(1)],[yl(1) yl(1) yl(2) yl(2)], ...
            [0.95 0.70 0.25],'FaceAlpha',0.14,'EdgeColor','none');
    end
    set(gca,'YLim',yl,'Layer','top');
    xlabel('Time [s]'); ylabel('Mean signal [a.u.]');
    title(sprintf('Global mean  |  method = %s, order = %d', method, p),'Interpreter','none');
    legend({'before','after'},'Location','best');

    subplot(2,2,2); hold on; grid on;
    plot(t, gBefore - gAfter,'-','LineWidth',1.3,'Color',[0.30 0.30 0.30]);
    if ~isempty(wUsed)
        yyaxis right;
        plot(t, wUsed,'-','LineWidth',1.0);
        ylabel('IRLS weight'); ylim([-0.05 1.15]);
        yyaxis left;
    end
    xlabel('Time [s]'); ylabel('Removed [a.u.]');
    title(sprintf('Removed trend  |  restore = %s  |  stability = %.1f x SD', ...
        restoreMode, stabilityIndex),'Interpreter','none');

    zc = max(1, ceil(nz/2));
    mb = double(meanImgBefore(:,:,zc));
    ma = double(meanImgAfter(:,:,zc));
    lo = min([mb(isfinite(mb)); ma(isfinite(ma))]);
    hi = max([mb(isfinite(mb)); ma(isfinite(ma))]);
    if ~isfinite(lo) || ~isfinite(hi) || hi <= lo, lo = 0; hi = 1; end

    subplot(2,2,3);
    imagesc(mb,[lo hi]); axis image off; colormap(gca,'gray'); colorbar;
    title(sprintf('Mean image BEFORE (slice %d)', zc));

    subplot(2,2,4);
    imagesc(ma,[lo hi]); axis image off; colormap(gca,'gray'); colorbar;
    title('Mean image AFTER (same scale)');

    qcFile = fullfile(qcDir, sprintf('driftQC_%s_%s.png', method, opts.tag));
    print(f,'-dpng','-r150', qcFile);
    close(f);
catch ME
    warning('driftcompensation:QCFailed','QC figure failed: %s', ME.message);
    qcFile = '';
end

% ------------------------------------------------------------------ stats
stats = struct();
stats.method            = method;
stats.TR                = TR;
stats.baselineSec       = bs;
stats.tailSec           = ts_;
stats.baselineFrames    = numel(bIdx);
stats.fitFrames         = numel(fitIdx);
stats.polyOrder         = p;
stats.robustIter        = opts.robustIter;
stats.glmCollinearity   = glmCollinearity;
stats.compcorVarPercent = compcorVar;
if exist('compcorInfo','var'), stats.compcorInfo = compcorInfo; end
if exist('artifactInfo','var'), stats.artifactInfo = artifactInfo; end
if exist('artifactResponseCollinearity','var'), stats.artifactResponseCollinearity = artifactResponseCollinearity; end
if exist('compcorInfo','var'), stats.compcorInfo = compcorInfo; end
if exist('artifactInfo','var'), stats.artifactInfo = artifactInfo; end
if exist('artifactResponseCollinearity','var'), stats.artifactResponseCollinearity = artifactResponseCollinearity; end
if isfield(opts,'knotSec'),   stats.knotSec   = opts.knotSec;   end
if isfield(opts,'cutoffSec'), stats.cutoffSec = opts.cutoffSec; end
if isfield(opts,'injectionSec'), stats.injectionSec = opts.injectionSec; end
if isfield(opts,'responseSec'),  stats.responseSec  = opts.responseSec;  end
if isfield(opts,'nComp'),        stats.nComp        = opts.nComp;        end
if isfield(opts,'compcorMode'),  stats.compcorMode  = opts.compcorMode;  end
if isfield(opts,'compcorFrac'),  stats.compcorFrac  = opts.compcorFrac;  end
if isfield(opts,'artifactMode'), stats.artifactMode = opts.artifactMode; end
if isfield(opts,'ccaThreshold'), stats.ccaThreshold = opts.ccaThreshold; end
if isfield(opts,'compcorMode'),  stats.compcorMode  = opts.compcorMode;  end
if isfield(opts,'compcorFrac'),  stats.compcorFrac  = opts.compcorFrac;  end
if isfield(opts,'artifactMode'), stats.artifactMode = opts.artifactMode; end
if isfield(opts,'ccaThreshold'), stats.ccaThreshold = opts.ccaThreshold; end
stats.restoreMode       = restoreMode;
stats.qcFile            = qcFile;
stats.meanTC_before     = meanTC_before;
stats.meanTC_after      = meanTC_after;
stats.extrapolationRatio = extrapRatio;
stats.stabilityIndex     = stabilityIndex;
stats.driftRangeBefore  = double(max(gBefore) - min(gBefore));
stats.driftRangeAfter   = double(max(gAfter)  - min(gAfter));
if stats.driftRangeBefore > 0
    stats.driftReductionPercent = 100*(1 - stats.driftRangeAfter/stats.driftRangeBefore);
else
    stats.driftReductionPercent = 0;
end

mbv = double(meanImgBefore(:)); mav = double(meanImgAfter(:));
gv = isfinite(mbv) & isfinite(mav);
if nnz(gv) > 2
    cc = corrcoef(mbv(gv), mav(gv));
    stats.meanImageCorr = cc(1,2);
    dm = mean(abs(mbv(gv)));
    if dm > 0
        stats.meanImageShiftPercent = 100*mean(abs(mav(gv)-mbv(gv)))/dm;
    else
        stats.meanImageShiftPercent = NaN;
    end
else
    stats.meanImageCorr = NaN;
    stats.meanImageShiftPercent = NaN;
end
stats.negativeSamplesBefore = negBefore;
stats.negativeSamplesAfter  = negAfter;
stats.elapsedSec = toc(tStart);

if opts.verbose
    fprintf('[Drift] done in %.2f s | range %.4g -> %.4g (%.1f%% reduction)\n', ...
        stats.elapsedSec, stats.driftRangeBefore, stats.driftRangeAfter, stats.driftReductionPercent);
    fprintf('[Drift] restore=%s | mean-image corr=%.4f | stability=%.1f x baseline SD\n', ...
        restoreMode, stats.meanImageCorr, stabilityIndex);
end

end % ======================================================== main function


% =========================================================================
%  LOCAL HELPERS
% =========================================================================
function s = localDefault(s, fieldName, val)
if ~isfield(s, fieldName) || isempty(s.(fieldName))
    s.(fieldName) = val;
end
end

function A = localVander(x, p)
x = double(x(:));
A = ones(numel(x), p+1);
for k = 1:p
    A(:,k+1) = x.^k;
end
end

function m = localSafeMean(Y, mask)
if nargin < 2 || isempty(mask), mask = true(size(Y,1),1); end
mask = logical(mask(:));
if ~any(mask)
    m = zeros(1,size(Y,2));
    return;
end
blk = double(Y(mask,:));
blk(~isfinite(blk)) = NaN;
m = nanmeanCompat(blk,1);
end


function m = nanmeanCompat(X, dim)
n = sum(isfinite(X), dim);
X(~isfinite(X)) = 0;
s = sum(X, dim);
n(n == 0) = NaN;
m = s ./ n;
end
