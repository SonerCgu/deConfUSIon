function [I_filt, stats] = filtering(I, TR, exportPath, opts)
% =========================================================================
% fUSI Studio - Robust Butterworth Filtering Engine
% =========================================================================
% MATLAB 2017b+ compatible.
%
% PATCH PURPOSE
%   1) Robust for single-slice 2D+time data [Y X T].
%   2) Robust for step-motor / multi-slice data [Y X Z T].
%   3) Static 2D images [Y X] are returned unchanged instead of erroring.
%   4) Filters temporal fluctuations and restores voxelwise mean image.
%      This prevents dark / low-resolution-looking filtered output.
%   5) Saves higher-resolution QC PNGs.
% =========================================================================

tStart = tic;

if nargin < 3 || isempty(exportPath)
    exportPath = pwd;
end

if nargin < 4 || isempty(opts)
    opts = struct();
end

if isempty(I) || ~isnumeric(I)
    error('Input I must be a non-empty numeric array.');
end

origClass = class(I);
dims = size(I);
nd = ndims(I);

if numel(TR) > 1
    TR = TR(end);
end
TR = double(TR);

if ~isfinite(TR) || TR <= 0
    error('Invalid TR. TR must be a positive scalar in seconds.');
end

% -------------------------------------------------------------------------
% Options
% -------------------------------------------------------------------------
opts.type        = lower(strtrim(char(getOpt(opts,'type','band'))));
opts.FcLow       = scalarNum(getOpt(opts,'FcLow',0.01), 0.01);
opts.FcHigh      = scalarNum(getOpt(opts,'FcHigh',0.20), 0.20);
opts.order       = scalarNum(getOpt(opts,'order',4), 4);
opts.trimStart   = scalarNum(getOpt(opts,'trimStart',0), 0);
opts.trimEnd     = scalarNum(getOpt(opts,'trimEnd',0), 0);
opts.useTaper    = boolScalar(getOpt(opts,'useTaper',true), true);
opts.saveQC      = boolScalar(getOpt(opts,'saveQC',true), true);
opts.chunkSize   = scalarNum(getOpt(opts,'chunkSize',50000), 50000);
opts.tag         = char(getOpt(opts,'tag',datestr(now,'yyyymmdd_HHMMSS')));
opts.restoreMean = boolScalar(getOpt(opts,'restoreMean',true), true);

opts.tag = regexprep(opts.tag,'[^\w\-]','_');

if strcmpi(opts.type,'low-pass') || strcmpi(opts.type,'lowpass') || strcmpi(opts.type,'lpf')
    opts.type = 'low';
elseif strcmpi(opts.type,'high-pass') || strcmpi(opts.type,'highpass') || strcmpi(opts.type,'hpf')
    opts.type = 'high';
elseif strcmpi(opts.type,'band-pass') || strcmpi(opts.type,'bandpass') || strcmpi(opts.type,'bpf')
    opts.type = 'band';
end

if ~ismember(opts.type, {'low','high','band'})
    error('Invalid filter type. Use opts.type = low, high, or band.');
end

opts.order = max(1,min(6,round(opts.order)));
opts.trimStart = max(0,opts.trimStart);
opts.trimEnd   = max(0,opts.trimEnd);
opts.chunkSize = max(1000,round(opts.chunkSize));

% -------------------------------------------------------------------------
% Detect temporal dimension
% -------------------------------------------------------------------------
if nd == 2
    nt = 1;
    timeDim = 0;
    I_filt = I;
    stats = makeSkipStats(tStart, opts, TR, dims, timeDim, nt, origClass, ...
        'Static 2D image has no temporal dimension. Returned unchanged.');
    warning('Filtering skipped: static 2D image [Y X] has no temporal dimension.');
    return;
elseif nd == 3
    nt = dims(3);
    timeDim = 3;
elseif nd == 4
    nt = dims(4);
    timeDim = 4;
else
    error('Data must be 2D [Y X], 3D [Y X T], or 4D [Y X Z T].');
end

if nt < 2
    I_filt = I;
    stats = makeSkipStats(tStart, opts, TR, dims, timeDim, nt, origClass, ...
        'Too few time points for temporal filtering. Returned unchanged.');
    warning('Too few time points for temporal filtering, T=%d. Returned unchanged.', nt);
    return;
end

Fs  = 1 / TR;
Nyq = Fs / 2;

if Fs <= 0 || Nyq <= 0
    error('Invalid sampling frequency computed from TR.');
end

% -------------------------------------------------------------------------
% Cutoff validation with Nyquist-safe clamping
% -------------------------------------------------------------------------
FcLow  = opts.FcLow;
FcHigh = opts.FcHigh;

minCutoff = max(eps, Nyq * 1e-6);
maxCutoff = 0.95 * Nyq;

switch opts.type
    case 'low'
        if ~isfinite(FcHigh) || FcHigh <= 0
            FcHigh = min(0.20, maxCutoff);
        end
        if FcHigh >= Nyq
            warning('Low-pass FcHigh %.6g Hz is >= Nyquist %.6g Hz. Clamping.', FcHigh, Nyq);
        end
        FcHigh = min(max(FcHigh, minCutoff), maxCutoff);
        FcLow = 0;

    case 'high'
        if ~isfinite(FcLow) || FcLow <= 0
            FcLow = min(0.01, maxCutoff);
        end
        if FcLow >= Nyq
            warning('High-pass FcLow %.6g Hz is >= Nyquist %.6g Hz. Clamping.', FcLow, Nyq);
        end
        FcLow = min(max(FcLow, minCutoff), maxCutoff);
        FcHigh = 0;

    case 'band'
        if ~isfinite(FcLow) || FcLow <= 0
            FcLow = 0.01;
        end
        if ~isfinite(FcHigh) || FcHigh <= 0
            FcHigh = 0.20;
        end
        if FcHigh >= Nyq
            warning('Band-pass FcHigh %.6g Hz is >= Nyquist %.6g Hz. Clamping.', FcHigh, Nyq);
        end
        FcHigh = min(max(FcHigh, minCutoff*10), maxCutoff);
        FcLow  = max(FcLow, minCutoff);
        if FcLow >= FcHigh
            warning('Band-pass FcLow >= FcHigh after safety checks. Adjusting low cutoff.');
            FcLow = max(minCutoff, 0.20 * FcHigh);
        end
end

opts.FcLow = FcLow;
opts.FcHigh = FcHigh;

% -------------------------------------------------------------------------
% Trimming window
% -------------------------------------------------------------------------
trimStartFrames = round(opts.trimStart / TR);
trimEndFrames   = round(opts.trimEnd   / TR);

idx1 = 1 + trimStartFrames;
idx2 = nt - trimEndFrames;

if idx1 >= idx2
    error('Trimming removes the entire signal. Reduce trimStart/trimEnd.');
end

nFiltFrames = idx2 - idx1 + 1;

% -------------------------------------------------------------------------
% Filter design
% -------------------------------------------------------------------------
switch opts.type
    case 'low'
        Wn = FcHigh / Nyq;
        [b,a] = butter(opts.order, Wn, 'low');

    case 'high'
        Wn = FcLow / Nyq;
        [b,a] = butter(opts.order, Wn, 'high');

    case 'band'
        Wn = [FcLow FcHigh] / Nyq;
        [b,a] = butter(opts.order, Wn, 'bandpass');
end

minFiltLen = 3 * max(length(a), length(b));
useSinglePassFallback = false;
if nFiltFrames <= minFiltLen
    useSinglePassFallback = true;
    warning(['Filtered segment is short for zero-phase filtfilt ', ...
        'available frames=%d, recommended minimum=%d. Using single-pass fallback.'], ...
        nFiltFrames, minFiltLen + 1);
end

unstable = any(abs(roots(a)) >= 1);
if unstable
    warning('Butterworth filter may be unstable. Consider reducing filter order.');
end

% -------------------------------------------------------------------------
% QC folder
% -------------------------------------------------------------------------
qcFolder = fullfile(exportPath,'Preprocessing','QC_filtering');
if opts.saveQC && ~exist(qcFolder,'dir')
    mkdir(qcFolder);
end

tag = opts.tag;
freqRespFile = '';
globalMeanFile = '';
spectrumFile = '';

% -------------------------------------------------------------------------
% Frequency response QC
% -------------------------------------------------------------------------
if opts.saveQC
    try
        [H,F] = freqz(b,a,1024,Fs);
        figResp = figure('Visible','off','Color','w','Position',[100 100 1000 650]);
        plot(F,abs(H),'LineWidth',1.5);
        xlabel('Frequency (Hz)');
        ylabel('|H(f)|');
        title('Butterworth Frequency Response');
        grid on;
        freqRespFile = fullfile(qcFolder, ['QC_filtering_FrequencyResponse_' tag '.png']);
        safePrintPng(figResp, freqRespFile);
        close(figResp);
    catch ME
        warning('Could not save filtering frequency response QC: %s', ME.message);
    end
end

% -------------------------------------------------------------------------
% Prepare data
% -------------------------------------------------------------------------
flatOrig = reshape(double(I), [], nt);
flatOut  = flatOrig;

gs_before = finiteMeanCols(flatOrig);

% IMPORTANT FIX: remove voxelwise mean before filtering, then restore it.
% This preserves the anatomical/mean image in the filtered dataset.
segOrig = flatOrig(:, idx1:idx2);
voxelMean = finiteMeanRows(segOrig);
segWork = bsxfun(@minus, segOrig, voxelMean);

% -------------------------------------------------------------------------
% Optional taper on fluctuation signal only, not on absolute image intensity
% -------------------------------------------------------------------------
taperLength = 0;
if opts.useTaper && (opts.trimStart > 0 || opts.trimEnd > 0)
    taperLength = min(round(2/TR), floor(nFiltFrames/4));
    if taperLength > 5
        try
            g = gausswin(2*taperLength)';
        catch
            x = linspace(-2.5, 2.5, 2*taperLength);
            g = exp(-0.5 * x.^2);
        end
        g = g ./ max(g);
        left  = g(1:taperLength);
        right = g(taperLength+1:end);
        segWork(:, 1:taperLength) = bsxfun(@times, segWork(:, 1:taperLength), left);
        segWork(:, end-taperLength+1:end) = bsxfun(@times, segWork(:, end-taperLength+1:end), right);
    end
end

% -------------------------------------------------------------------------
% Chunked filtering
% -------------------------------------------------------------------------
nVox = size(segWork,1);
chunkSize = opts.chunkSize;
nChunks = ceil(nVox / chunkSize);
nFallbackChunks = 0;
nFailedChunks = 0;

for c = 1:nChunks
    s = (c-1)*chunkSize + 1;
    e = min(c*chunkSize, nVox);

    block = segWork(s:e,:);
    valid = all(isfinite(block),2) & std(block,0,2) > 1e-8;

    if any(valid)
        [blockValid, usedFallback, failedBlock] = filterBlock(block(valid,:), b, a, useSinglePassFallback);
        block(valid,:) = blockValid;
        if usedFallback
            nFallbackChunks = nFallbackChunks + 1;
        end
        if failedBlock
            nFailedChunks = nFailedChunks + 1;
        end
    end

    segWork(s:e,:) = block;
end

if opts.restoreMean
    flatOut(:, idx1:idx2) = bsxfun(@plus, segWork, voxelMean);
else
    flatOut(:, idx1:idx2) = segWork;
end

I_filt = reshape(flatOut, dims);

gs_after = finiteMeanCols(flatOut);
t = (0:nt-1) * TR;

% -------------------------------------------------------------------------
% QC global mean
% -------------------------------------------------------------------------
if opts.saveQC
    try
        fig1 = figure('Visible','off','Color','w','Position',[100 100 1100 650]);
        plot(t, gs_before, 'k', 'LineWidth', 1.0);
        hold on;
        plot(t, gs_after, 'r', 'LineWidth', 1.5);
        xlabel('Time (s)');
        ylabel('Global Mean');
        legend('Before','After');
        title('Filtering QC - Global Mean, Mean Restored');
        grid on;
        globalMeanFile = fullfile(qcFolder, ['QC_filtering_GlobalMean_' tag '.png']);
        safePrintPng(fig1, globalMeanFile);
        close(fig1);
    catch ME
        warning('Could not save filtering global mean QC: %s', ME.message);
    end
end

% -------------------------------------------------------------------------
% QC spectrum
% -------------------------------------------------------------------------
if opts.saveQC
    try
        nHalf = floor(nt/2) + 1;
        f = (0:nHalf-1) * (Fs / nt);
        g1 = gs_before;
        g2 = gs_after;
        g1(~isfinite(g1)) = 0;
        g2(~isfinite(g2)) = 0;
        g1 = g1 - mean(g1);
        g2 = g2 - mean(g2);
        X1 = abs(fft(g1));
        X2 = abs(fft(g2));
        fig2 = figure('Visible','off','Color','w','Position',[100 100 1100 650]);
        plot(f, X1(1:nHalf), 'k', 'LineWidth', 1.0);
        hold on;
        plot(f, X2(1:nHalf), 'r', 'LineWidth', 1.5);
        xlabel('Frequency (Hz)');
        ylabel('Amplitude');
        legend('Before','After');
        title('Filtering QC - Spectrum');
        grid on;
        spectrumFile = fullfile(qcFolder, ['QC_filtering_Spectrum_' tag '.png']);
        safePrintPng(fig2, spectrumFile);
        close(fig2);
    catch ME
        warning('Could not save filtering spectrum QC: %s', ME.message);
    end
end

% -------------------------------------------------------------------------
% Stats
% -------------------------------------------------------------------------
stats = struct();
stats.filterType = opts.type;
stats.order = opts.order;
stats.Fs = Fs;
stats.TR = TR;
stats.Nyquist = Nyq;
stats.FcLow = FcLow;
stats.FcHigh = FcHigh;
stats.Wn = Wn;
stats.trimStart = opts.trimStart;
stats.trimEnd = opts.trimEnd;
stats.trimStartFrames = trimStartFrames;
stats.trimEndFrames = trimEndFrames;
stats.filteredFrameStart = idx1;
stats.filteredFrameEnd = idx2;
stats.nFilteredFrames = nFiltFrames;
stats.useTaper = opts.useTaper;
stats.taperLengthFrames = taperLength;
stats.restoreMean = opts.restoreMean;
stats.meanRestorationMethod = 'voxelwise temporal mean over filtered segment';
stats.chunkSize = chunkSize;
stats.nChunks = nChunks;
stats.nVoxels = nVox;
stats.nFallbackChunks = nFallbackChunks;
stats.nFailedChunks = nFailedChunks;
stats.unstable = unstable;
stats.usedSinglePassFallback = useSinglePassFallback;
stats.minFiltFiltFramesRecommended = minFiltLen + 1;
stats.b = b;
stats.a = a;
stats.qcFolder = qcFolder;
stats.qcFrequencyResponseFile = freqRespFile;
stats.qcGlobalMeanFile = globalMeanFile;
stats.qcSpectrumFile = spectrumFile;
stats.inputSize = dims;
stats.inputClass = origClass;
stats.timeDim = timeDim;
stats.skipped = false;
stats.processingTime = toc(tStart);
stats.optsResolved = opts;

end

% =========================================================================
% Helper functions
% =========================================================================
function v = getOpt(s, name, defaultVal)
if isstruct(s) && isfield(s,name) && ~isempty(s.(name))
    v = s.(name);
else
    v = defaultVal;
end
end

function x = scalarNum(x, defaultVal)
try
    x = double(x);
    if isempty(x)
        x = defaultVal;
        return;
    end
    x = x(1);
catch
    x = defaultVal;
end
if ~isfinite(x)
    x = defaultVal;
end
end

function tf = boolScalar(v, defaultVal)
if nargin < 2
    defaultVal = false;
end
tf = defaultVal;
if isempty(v)
    return;
end
if islogical(v)
    tf = v(1);
elseif isnumeric(v)
    tf = isfinite(v(1)) && v(1) ~= 0;
elseif ischar(v)
    vv = lower(strtrim(v));
    if any(strcmp(vv,{'true','on','yes','y','1'}))
        tf = true;
    elseif any(strcmp(vv,{'false','off','no','n','0'}))
        tf = false;
    end
end
end

function m = finiteMeanRows(X)
mask = isfinite(X);
X2 = X;
X2(~mask) = 0;
cnt = sum(mask,2);
den = max(cnt,1);
m = sum(X2,2) ./ den;
m(cnt == 0) = 0;
end

function m = finiteMeanCols(X)
mask = isfinite(X);
X2 = X;
X2(~mask) = 0;
cnt = sum(mask,1);
den = max(cnt,1);
m = sum(X2,1) ./ den;
m(cnt == 0) = NaN;
end

function [Y, usedFallback, failedBlock] = filterBlock(X, b, a, forceSinglePass)
usedFallback = false;
failedBlock = false;
if isempty(X)
    Y = X;
    return;
end
try
    if forceSinglePass
        usedFallback = true;
        Y = filter(b,a,X')';
    else
        Y = filtfilt(b,a,X')';
    end
catch
    try
        usedFallback = true;
        Y = filter(b,a,X')';
    catch
        failedBlock = true;
        warning('Filtering failed for one chunk. Keeping that chunk unchanged.');
        Y = X;
    end
end
end

function safePrintPng(figHandle, fileName)
try
    set(figHandle,'PaperPositionMode','auto');
    print(figHandle, fileName, '-dpng', '-r220');
catch
    saveas(figHandle, fileName);
end
end

function stats = makeSkipStats(tStart, opts, TR, dims, timeDim, nt, origClass, reason)
Fs = 1 / TR;
stats = struct();
stats.filterType = opts.type;
stats.order = opts.order;
stats.Fs = Fs;
stats.TR = TR;
stats.Nyquist = Fs / 2;
stats.FcLow = opts.FcLow;
stats.FcHigh = opts.FcHigh;
stats.Wn = [];
stats.trimStart = opts.trimStart;
stats.trimEnd = opts.trimEnd;
stats.trimStartFrames = 0;
stats.trimEndFrames = 0;
stats.filteredFrameStart = 1;
stats.filteredFrameEnd = nt;
stats.nFilteredFrames = nt;
stats.useTaper = false;
stats.taperLengthFrames = 0;
stats.restoreMean = true;
stats.chunkSize = opts.chunkSize;
stats.nChunks = 0;
stats.nVoxels = 0;
stats.unstable = false;
stats.usedSinglePassFallback = false;
stats.b = [];
stats.a = [];
stats.qcFolder = '';
stats.qcFrequencyResponseFile = '';
stats.qcGlobalMeanFile = '';
stats.qcSpectrumFile = '';
stats.inputSize = dims;
stats.inputClass = origClass;
stats.timeDim = timeDim;
stats.skipped = true;
stats.skipReason = reason;
stats.processingTime = toc(tStart);
stats.optsResolved = opts;
end
