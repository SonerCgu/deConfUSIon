function [I_filt, stats] = filtering(I, TR, exportPath, opts)
% =========================================================================
% fUSI Studio - Temporal filtering (IIR, FIR, and discrete FFT)
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

deConfUSIon_setup();
if ischar(I)||isstring(I)
    if strcmpi(char(I),'setup') && nargin>=2 && isstruct(TR)
        I_filt=showTemporalFilterSetup(TR); stats=[]; return;
    end
    error('Filtering:Action','Unknown filtering action.');
end
tStart = tic;

if nargin < 3 || isempty(exportPath)
    exportPath = pwd;
end

if nargin < 4 || isempty(opts)
    opts = struct();
end
progress=deConfUSIon_ui('progress','Filtering',getOpt(opts,'showProgress',true));
progressGuard=onCleanup(@()deConfUSIon_ui('progressclose',progress)); %#ok<NASGU>

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
suppliedOptions=opts;
opts.type        = lower(strtrim(char(getOpt(opts,'type','band'))));
opts.FcLow       = scalarNum(getOpt(opts,'FcLow',0.01), 0.01);
opts.FcHigh      = scalarNum(getOpt(opts,'FcHigh',0.20), 0.20);
opts.method=lower(strtrim(char(getOpt(opts,'method','butter'))));
aliases={'butterworth','chebyshev i','chebyshev ii','elliptic','fir (hamming)','fft (strict bins)'};
methods={'butter','cheby1','cheby2','ellip','fir','fft'};
match=find(strcmpi(aliases,opts.method),1); if ~isempty(match), opts.method=methods{match}; end
if ~any(strcmp(methods,opts.method)), error('Filtering:Method','Unknown filter method: %s',opts.method); end
methodNames={'Butterworth','Chebyshev I','Chebyshev II','Elliptic','FIR (Hamming)','FFT (strict bins)'};
methodName=methodNames{find(strcmp(methods,opts.method),1)};
defaultOrder=4; if strcmp(opts.method,'fir'), defaultOrder=16; end
opts.order=scalarNum(getOpt(opts,'order',defaultOrder),defaultOrder);
opts.passbandRippleDb=scalarNum(getOpt(opts,'passbandRippleDb',.5),.5);
opts.stopbandAttenuationDb=scalarNum(getOpt(opts,'stopbandAttenuationDb',60),60);
if opts.passbandRippleDb<=0||opts.stopbandAttenuationDb<=opts.passbandRippleDb
    error('Filtering:Specification','Ripple must be positive and stopband attenuation must exceed ripple.');
end
opts.trimStart   = scalarNum(getOpt(opts,'trimStart',0), 0);
opts.trimEnd     = scalarNum(getOpt(opts,'trimEnd',0), 0);
opts.useTaper    = boolScalar(getOpt(opts,'useTaper',true), true);
opts.saveQC      = boolScalar(getOpt(opts,'saveQC',true), true);
opts.chunkSize   = scalarNum(getOpt(opts,'chunkSize',50000), 50000);
opts.tag         = char(getOpt(opts,'tag',datestr(now,'yyyymmdd_HHMMSS')));
opts.restoreMean = boolScalar(getOpt(opts,'restoreMean',true), true);
% Reject invalid supplied numbers rather than silently substituting defaults.
numericFields={'FcLow','FcHigh','order','passbandRippleDb','stopbandAttenuationDb','trimStart','trimEnd','chunkSize'};
for ni=1:numel(numericFields)
    field=numericFields{ni};
    if isfield(suppliedOptions,field) && ~isempty(suppliedOptions.(field))
        value=suppliedOptions.(field);
        if ~isnumeric(value)||~isscalar(value)||~isfinite(value)
            error('Filtering:Specification','%s must be a finite numeric scalar.',field);
        end
    end
end

opts.tag = regexprep(opts.tag,'[^\w\-]','_');

if strcmpi(opts.type,'low-pass') || strcmpi(opts.type,'lowpass') || strcmpi(opts.type,'lpf')
    opts.type = 'low';
elseif strcmpi(opts.type,'high-pass') || strcmpi(opts.type,'highpass') || strcmpi(opts.type,'hpf')
    opts.type = 'high';
elseif strcmpi(opts.type,'band-pass') || strcmpi(opts.type,'bandpass') || strcmpi(opts.type,'bpf')
    opts.type = 'band';
elseif any(strcmpi(opts.type,{'band-stop','bandstop','notch'}))
    opts.type='stop';
end

if ~ismember(opts.type, {'low','high','band','stop'})
    error('Filtering:Type','Use opts.type = low, high, band, or stop.');
end

if ~strcmp(opts.method,'fft')
    maxOrder=12; if strcmp(opts.method,'fir'), maxOrder=2000; end
    if opts.order<1||opts.order>maxOrder||opts.order~=round(opts.order)
        error('Filtering:Order','%s order must be an integer between 1 and %d.',methodName,maxOrder);
    end
else
    opts.order=0; % FFT masking has no polynomial filter order.
end
if opts.trimStart<0||opts.trimEnd<0, error('Filtering:Trim','Trim times must be nonnegative.'); end
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
% Cutoffs are never silently changed. TR determines the actual Nyquist limit.
% -------------------------------------------------------------------------
FcLow=opts.FcLow; FcHigh=opts.FcHigh;
switch opts.type
    case 'low'
        if FcHigh<=0||FcHigh>=Nyq, error('Filtering:Cutoff','High cutoff must be >0 and < Nyquist %.6g Hz.',Nyq); end
        FcLow=0;
    case 'high'
        if FcLow<=0||FcLow>=Nyq, error('Filtering:Cutoff','Low cutoff must be >0 and < Nyquist %.6g Hz.',Nyq); end
        FcHigh=0;
    otherwise
        if FcLow<=0||FcLow>=FcHigh||FcHigh>=Nyq
            error('Filtering:Cutoff','Cutoffs must satisfy 0 < low < high < Nyquist %.6g Hz.',Nyq);
        end
end
opts.FcLow=FcLow; opts.FcHigh=FcHigh;

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
% Filter design. Forward/backward filtering squares the magnitude response.
% Ripple and attenuation settings below describe this final response (dB).
% -------------------------------------------------------------------------
switch opts.type
    case 'low', Wn=FcHigh/Nyq; designType='low';
    case 'high', Wn=FcLow/Nyq; designType='high';
    case 'band', Wn=[FcLow FcHigh]/Nyq; designType='bandpass';
    case 'stop', Wn=[FcLow FcHigh]/Nyq; designType='stop';
end
sos=[]; gain=1; poles=[]; b=[]; a=[];
if strcmp(opts.method,'fft')
    minFiltLen=0; frequency=(0:nFiltFrames-1)*(Fs/nFiltFrames);
    absoluteFrequency=min(frequency,Fs-frequency);
    switch opts.type
        case 'low', keepBins=absoluteFrequency<=FcHigh;
        case 'high', keepBins=absoluteFrequency>=FcLow;
        case 'band', keepBins=absoluteFrequency>=FcLow & absoluteFrequency<=FcHigh;
        case 'stop', keepBins=absoluteFrequency<FcLow | absoluteFrequency>FcHigh;
    end
    % Symmetric mask preserves real output. This is a periodic DFT projection,
    % not a causal brick-wall filter or a motion-artifact detector.
elseif strcmp(opts.method,'fir')
    if any(strcmp(opts.type,{'high','stop'})) && mod(opts.order,2)
        error('Filtering:Order','High-pass/band-stop FIR requires an even order.');
    end
    b=fir1(opts.order,Wn,designType,hamming(opts.order+1)); a=1;
    minFiltLen=3*opts.order;
else
    switch opts.method
        case 'butter', [z,poles,gain]=butter(opts.order,Wn,designType);
        case 'cheby1', [z,poles,gain]=cheby1(opts.order,opts.passbandRippleDb/2,Wn,designType);
        case 'cheby2', [z,poles,gain]=cheby2(opts.order,opts.stopbandAttenuationDb/2,Wn,designType);
        case 'ellip', [z,poles,gain]=ellip(opts.order,opts.passbandRippleDb/2,opts.stopbandAttenuationDb/2,Wn,designType);
    end
    [sos,gain]=zp2sos(z,poles,gain);
    [b,a]=zp2tf(z,poles,gain); % For reporting only; filtering uses stable SOS.
    minFiltLen=3*numel(poles);
end
useSinglePassFallback=false;
if nFiltFrames<=minFiltLen
    error('Filtering:ShortSignal','%s needs at least %d frames for zero-phase filtering; available: %d. Reduce order/trimming or use FFT.',methodName,minFiltLen+1,nFiltFrames);
end
unstable=any(abs(poles)>=1);
if unstable, error('Filtering:Unstable','Filter poles are unstable. Reduce order or adjust cutoffs.'); end

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
        if strcmp(opts.method,'fft')
            F=absoluteFrequency(1:floor(nFiltFrames/2)+1); H=double(keepBins(1:numel(F)));
        elseif ~isempty(sos)
            [H,F]=freqz(sos,1024,Fs); H=abs(gain*H).^2;
        else
            [H,F]=freqz(b,a,1024,Fs); H=abs(H).^2;
        end
        if opts.restoreMean, H(F==0)=1; end
        figResp = figure('Visible','off','Color','w','Position',[100 100 1000 650]);
        plot(F,abs(H),'LineWidth',1.5);
        xlabel('Frequency (Hz)');
        ylabel('Final amplitude gain');
        title([methodName ' - final zero-phase magnitude response']);
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
Iflat = reshape(I, [], nt);          % shared read-only view, original class
nVox  = size(Iflat,1);

outFlat = single(Iflat);             % one single-precision output copy

% taper vector over the filtered segment (same for every voxel)
taperLength = 0;
taperVec = ones(1, nFiltFrames);
if opts.useTaper && (opts.trimStart > 0 || opts.trimEnd > 0)
    taperLength = min(round(2/TR), floor(nFiltFrames/4));
    if taperLength > 5
        try
            g = gausswin(2*taperLength)';
        catch
            xx = linspace(-2.5, 2.5, 2*taperLength);
            g = exp(-0.5 * xx.^2);
        end
        g = g ./ max(g);
        taperVec(1:taperLength)         = g(1:taperLength);
        taperVec(end-taperLength+1:end) = g(taperLength+1:end);
    end
end

% Each voxel has several double work arrays during filtfilt. Bound the
% working set by time-series length rather than a fixed 50,000-voxel block.
chunkSize = min(opts.chunkSize,max(1,floor(128*1024^2/(8*nt*12))));
nChunks   = ceil(nVox / chunkSize);
nFallbackChunks = 0;
nFailedChunks   = 0;
nUnfilteredVoxels=0;

sumBefore = zeros(1, nt); cntBefore = zeros(1, nt);
sumAfter  = zeros(1, nt); cntAfter  = zeros(1, nt);

for c = 1:nChunks
    deConfUSIon_ui('progressupdate',progress,.05+.9*(c-1)/nChunks,sprintf('Filtering voxel block %d of %d',c,nChunks));
    s = (c-1)*chunkSize + 1;
    e = min(c*chunkSize, nVox);

    rawChunk = double(Iflat(s:e, :));          % double only this chunk

    mb = isfinite(rawChunk);
    tb = rawChunk; tb(~mb) = 0;
    sumBefore = sumBefore + sum(tb,1);
    cntBefore = cntBefore + sum(mb,1);

    seg   = rawChunk(:, idx1:idx2);
    vmask = isfinite(seg);
    segz  = seg; segz(~vmask) = 0;
    vcnt  = sum(vmask,2); vcnt(vcnt==0) = 1;
    voxelMean = sum(segz,2) ./ vcnt;

    work = bsxfun(@minus, seg, voxelMean);
    work = bsxfun(@times, work, taperVec);

    finiteRows=all(isfinite(work),2);
    nUnfilteredVoxels=nUnfilteredVoxels+sum(~finiteRows);
    valid=finiteRows & std(work,0,2)>0;
    if any(valid)
        usedFb=false; failedB=false;
        if strcmp(opts.method,'fft')
            spectrum=fft(work(valid,:),[],2);
            wv=real(ifft(bsxfun(@times,spectrum,keepBins),[],2));
        elseif ~isempty(sos)
            wv=filtfilt(sos,gain,work(valid,:)')';
        else
            wv=filtfilt(b,a,work(valid,:)')';
        end
        if any(~isfinite(wv(:))), error('Filtering:Nonfinite','Filtering produced nonfinite values. Reduce order or revise cutoffs.'); end
        work(valid,:) = wv;
        if usedFb,  nFallbackChunks = nFallbackChunks + 1; end
        if failedB, nFailedChunks   = nFailedChunks + 1;   end
    end

    if opts.restoreMean
        % Keep the Doppler baseline exactly; restored DC is an explicit
        % exception to high-pass/band-pass rejection below the low cutoff.
        work(finiteRows,:)=bsxfun(@minus,work(finiteRows,:),mean(work(finiteRows,:),2));
        seg = bsxfun(@plus, work, voxelMean);
    else
        seg = work;
    end

    outFlat(s:e, idx1:idx2) = single(seg);

    oc  = double(outFlat(s:e, :));
    ma  = isfinite(oc);
    ta  = oc; ta(~ma) = 0;
    sumAfter = sumAfter + sum(ta,1);
    cntAfter = cntAfter + sum(ma,1);
end

I_filt = reshape(outFlat, dims);
deConfUSIon_ui('progressupdate',progress,.95,'Preparing filtering QC reports');

gs_before = sumBefore ./ max(cntBefore,1); gs_before(cntBefore==0) = NaN;
gs_after  = sumAfter  ./ max(cntAfter,1);  gs_after(cntAfter==0)  = NaN;
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
stats.method=opts.method;
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
stats.methodName=methodName;
stats.designOrder=opts.order;
if ~isempty(poles), stats.designOrder=numel(poles); end
stats.effectiveTwoPassOrder=2*stats.designOrder;
stats.passbandRippleDb=opts.passbandRippleDb;
stats.stopbandAttenuationDb=opts.stopbandAttenuationDb;
stats.zeroPhase=true;
stats.sos=sos; stats.gain=gain;
stats.nUnfilteredNonfiniteVoxels=nUnfilteredVoxels;
stats.strictFFT=strcmp(opts.method,'fft');
stats.frequencyBoundary='FFT masks exact finite-record bins; IIR/FIR have transition bands. Restored DC is exempt.';
if stats.strictFFT
    stats.frequencyBinsHz=absoluteFrequency; stats.keptFrequencyBins=keepBins;
end
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
deConfUSIon_ui('progressupdate',progress,1,'Filtering complete');
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
stats.method=opts.method;
families={'butter','cheby1','cheby2','ellip','fir','fft'};
names={'Butterworth','Chebyshev I','Chebyshev II','Elliptic','FIR (Hamming)','FFT (strict bins)'};
stats.methodName=names{find(strcmp(families,opts.method),1)};
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

function opts=showTemporalFilterSetup(data)
opts=[]; TR=double(data.TR(end)); Fs=1/TR; Nyq=Fs/2;
nt=size(data.I,ndims(data.I));
defaultHigh=min(.20,.8*Nyq); defaultLow=min(.001,.2*defaultHigh);
bg=[.04 .04 .045]; panel=[.09 .09 .10]; editBg=[.02 .02 .025]; fg=[.96 .96 .96];
dlg=figure('Name','Temporal Filtering Setup','Tag','deConfUSIonTemporalFilterSetup', ...
    'Color',bg,'MenuBar','none','ToolBar','none','NumberTitle','off', ...
    'Units','pixels','Position',[35 40 1480 900],'WindowStyle','modal', ...
    'Visible','off','CloseRequestFcn',@onCancel,'KeyPressFcn',@onKey);
uicontrol(dlg,'Style','text','String','Temporal filtering','Units','normalized', ...
    'Position',[.04 .925 .92 .05],'BackgroundColor',bg,'ForegroundColor',fg,'FontSize',20,'FontWeight','bold');
uicontrol(dlg,'Style','text','String',sprintf('TR %.4g s | Fs %.6g Hz | Nyquist %.6g Hz | %d samples | %.2f min',TR,Fs,Nyq,nt,(nt-1)*TR/60), ...
    'Units','normalized','Position',[.04 .875 .92 .04],'BackgroundColor',bg,'ForegroundColor',fg,'FontSize',12);
left=uipanel(dlg,'Units','normalized','Position',[.04 .225 .46 .63],'Title','Filter settings', ...
    'BackgroundColor',panel,'ForegroundColor',fg,'FontSize',12);
right=uipanel(dlg,'Units','normalized','Position',[.52 .225 .44 .63],'Title','Response and interpretation', ...
    'BackgroundColor',panel,'ForegroundColor',fg,'FontSize',12);
methods={'butter','cheby1','cheby2','ellip','fir','fft'};
names={'Butterworth','Chebyshev I','Chebyshev II','Elliptic','FIR (Hamming)','FFT (strict bins)'};
types={'band','low','high','stop'};
hType=rowControl('Filter type',.90,'popupmenu',{'Band-pass','Low-pass','High-pass','Band-stop / notch'},1);
hMethod=rowControl('Filter family',.81,'popupmenu',names,1);
hOrder=rowControl('Order / prototype',.72,'edit','4',[]);
set(hOrder,'TooltipString','IIR band-pass/stop has twice the prototype order. Two-pass filtering doubles it again. FIR order is the number of taps minus one.');
hLow=rowControl('Low cutoff (Hz)',.63,'edit',num2str(defaultLow,'%.6g'),[]);
hHigh=rowControl('High cutoff (Hz)',.54,'edit',num2str(defaultHigh,'%.6g'),[]);
hRipple=rowControl('Final passband ripple (dB)',.45,'edit','0.5',[]);
hAtten=rowControl('Final stopband attenuation (dB)',.36,'edit','60',[]);
hTrimStart=rowControl('Trim start (s)',.27,'edit','0',[]);
hTrimEnd=rowControl('Trim end (s)',.18,'edit','0',[]);
hMean=uicontrol(dlg,'Style','checkbox','String','Preserve voxel mean (Doppler baseline; retains DC)', ...
    'Value',1,'Units','normalized','Position',[.04 .165 .49 .04],'BackgroundColor',bg,'ForegroundColor',fg,'FontSize',12,'Callback',@refresh);
hTaper=uicontrol(dlg,'Style','checkbox','String','Taper trim edges','Value',1, ...
    'Units','normalized','Position',[.55 .165 .19 .04],'BackgroundColor',bg,'ForegroundColor',fg,'FontSize',12);
hQC=uicontrol(dlg,'Style','checkbox','String','Save QC plots','Value',1, ...
    'Units','normalized','Position',[.77 .165 .19 .04],'BackgroundColor',bg,'ForegroundColor',fg,'FontSize',12);
hAdvice=uicontrol(right,'Style','text','Units','normalized','Position',[.05 .57 .90 .38], ...
    'BackgroundColor',panel,'ForegroundColor',fg,'FontSize',12,'HorizontalAlignment','left');
ax=axes(right,'Units','normalized','Position',[.13 .13 .82 .37],'Color',panel,'XColor',fg,'YColor',fg,'FontSize',11);
hStatus=uicontrol(dlg,'Style','text','String','Ready','Units','normalized','Position',[.04 .10 .92 .045], ...
    'BackgroundColor',bg,'ForegroundColor',[.6 .9 1],'FontSize',12,'HorizontalAlignment','left');
uicontrol(dlg,'Style','pushbutton','String','Reset defaults','Units','normalized','Position',[.04 .025 .22 .065], ...
    'BackgroundColor',[.2 .48 .95],'ForegroundColor','w','FontSize',13,'Callback',@onReset);
uicontrol(dlg,'Style','pushbutton','String','RUN FILTERING','Tag','TemporalFilterRun','Units','normalized','Position',[.52 .025 .24 .065], ...
    'BackgroundColor',[.12 .68 .35],'ForegroundColor','w','FontSize',13,'FontWeight','bold','Callback',@onRun);
uicontrol(dlg,'Style','pushbutton','String','Cancel','Tag','TemporalFilterCancel','Units','normalized','Position',[.78 .025 .18 .065], ...
    'BackgroundColor',[.78 .22 .22],'ForegroundColor','w','FontSize',13,'Callback',@onCancel);
set(hMethod,'Callback',@methodChanged);
setappdata(dlg,'FilterControls',struct('type',hType,'method',hMethod,'order',hOrder,'low',hLow, ...
    'high',hHigh,'ripple',hRipple,'attenuation',hAtten,'restoreMean',hMean, ...
    'trimStart',hTrimStart,'trimEnd',hTrimEnd,'saveQC',hQC,'status',hStatus,'responseAxes',ax));
refresh();
if ~isgraphics(dlg), return; end
movegui(dlg,'center'); set(dlg,'Visible','on'); drawnow;
if isgraphics(dlg), waitfor(dlg); end

    function h=rowControl(label,y,style,str,value)
        uicontrol(left,'Style','text','String',label,'Units','normalized','Position',[.035 y .55 .06], ...
            'BackgroundColor',panel,'ForegroundColor',fg,'HorizontalAlignment','left','FontSize',12);
        h=uicontrol(left,'Style',style,'String',str,'Units','normalized','Position',[.59 y .37 .066], ...
            'BackgroundColor',editBg,'ForegroundColor',fg,'FontSize',12,'Callback',@refresh);
        if ~isempty(value), set(h,'Value',value); end
    end
    function methodChanged(~,~)
        method=methods{get(hMethod,'Value')};
        if strcmp(method,'fir'), set(hOrder,'String','16');
        elseif ~strcmp(method,'fft'), set(hOrder,'String','4'); end
        refresh();
    end
    function o=readOptions()
        o=struct('type',types{get(hType,'Value')},'method',methods{get(hMethod,'Value')}, ...
            'order',str2double(get(hOrder,'String')),'FcLow',str2double(get(hLow,'String')), ...
            'FcHigh',str2double(get(hHigh,'String')),'passbandRippleDb',str2double(get(hRipple,'String')), ...
            'stopbandAttenuationDb',str2double(get(hAtten,'String')), ...
            'trimStart',str2double(get(hTrimStart,'String')),'trimEnd',str2double(get(hTrimEnd,'String')), ...
            'restoreMean',logical(get(hMean,'Value')),'useTaper',logical(get(hTaper,'Value')), ...
            'saveQC',logical(get(hQC,'Value')),'showProgress',false,'chunkSize',50000);
        if strcmp(o.type,'low'), o.FcLow=0; elseif strcmp(o.type,'high'), o.FcHigh=0; end
        if strcmp(o.method,'fft'), o.order=0; end
        values=[o.order o.FcLow o.FcHigh o.passbandRippleDb o.stopbandAttenuationDb o.trimStart o.trimEnd];
        if any(~isfinite(values)), error('Filtering:Specification','All active settings must be finite numbers.'); end
        if o.trimStart<0||o.trimEnd<0, error('Filtering:Trim','Trim times must be nonnegative.'); end
    end
    function refresh(~,~)
        type=types{get(hType,'Value')}; method=methods{get(hMethod,'Value')};
        set(hLow,'Enable','on'); set(hHigh,'Enable','on');
        if strcmp(type,'low'), set(hLow,'Enable','off'); elseif strcmp(type,'high'), set(hHigh,'Enable','off'); end
        set(hOrder,'Enable','on'); if strcmp(method,'fft'), set(hOrder,'Enable','off'); end
        set(hRipple,'Enable','off'); set(hAtten,'Enable','off');
        if any(strcmp(method,{'cheby1','ellip'})), set(hRipple,'Enable','on'); end
        if any(strcmp(method,{'cheby2','ellip'})), set(hAtten,'Enable','on'); end
        descriptions={ ...
            'Butterworth: smooth passband; gradual transition. Cutoff gives -6 dB after two passes.', ...
            'Chebyshev I: steeper transition, with passband ripple. Cutoffs are passband edges.', ...
            'Chebyshev II: smooth passband, stopband ripple. Cutoffs are stopband edges; desired slow signals should lie farther inside the passband.', ...
            'Elliptic: sharp transition for a given order, with passband and stopband ripple. Cutoffs are passband edges.', ...
            'FIR: finite impulse response, Hamming window; increase order for a narrower transition. Needs more time samples. Cutoffs lie inside the transition.', ...
            'FFT: zero all discrete frequency bins outside the chosen passband. Assumes a periodic record; may ring around spikes or edges. Frequency resolution is Fs / filtered sample count.'};
        set(hAdvice,'String',{descriptions{get(hMethod,'Value')},' ', ...
            'Two-pass IIR/FIR filtering is zero phase. Ripple/attenuation are final two-pass values.', ...
            'Preserve mean retains the DC baseline even with high-pass/band-pass.', ...
            'Motion spikes contain slow frequencies too. Review Despike / Scrubbing before filtering.'});
        try
            o=readOptions(); o.saveQC=false;
            % Design through the production engine so the preview cannot
            % disagree with the filter that will actually be applied.
            probe=zeros(1,1,nt); probe(1,1,ceil(nt/2))=1;
            [~,st]=filtering(probe,TR,tempdir,o);
            if st.strictFFT
                count=floor(st.nFilteredFrames/2)+1;
                f=st.frequencyBinsHz(1:count); h=double(st.keptFrequencyBins(1:count));
            elseif ~isempty(st.sos)
                [h,f]=freqz(st.sos,1024,Fs); h=abs(st.gain*h).^2;
            else
                [h,f]=freqz(st.b,st.a,1024,Fs); h=abs(h).^2;
            end
            if o.restoreMean, h(f==0)=1; end
            cla(ax); plot(ax,f,20*log10(max(abs(h),1e-6)),'Color',[.3 .8 1],'LineWidth',1.8);
            set(ax,'Color',panel,'XColor',fg,'YColor',fg); ylim(ax,[-100 5]); xlim(ax,[0 Nyq]); grid(ax,'on');
            xlabel(ax,'Frequency (Hz)','Color',fg); ylabel(ax,'Final gain (dB)','Color',fg);
            message=sprintf('%s | %s | %d filtered samples | settings valid',names{get(hMethod,'Value')},type,st.nFilteredFrames);
            set(hStatus,'String',message,'ForegroundColor',[.6 .9 1]);
        catch ME
            cla(ax); set(hStatus,'String',ME.message,'ForegroundColor',[1 .65 .25]);
        end
    end
    function onRun(~,~)
        try
            o=readOptions(); o.saveQC=false;
            [~,~]=filtering(zeros(1,1,nt),TR,tempdir,o); % Validate before closing.
            o.saveQC=logical(get(hQC,'Value')); o.showProgress=true; o.cancelled=false;
            opts=o; delete(dlg);
        catch ME
            set(hStatus,'String',ME.message,'ForegroundColor',[1 .65 .25]);
        end
    end
    function onReset(~,~)
        set(hType,'Value',1); set(hMethod,'Value',1); set(hOrder,'String','4');
        set(hLow,'String',num2str(defaultLow,'%.6g')); set(hHigh,'String',num2str(defaultHigh,'%.6g'));
        set(hRipple,'String','.5'); set(hAtten,'String','60');
        set(hTrimStart,'String','0'); set(hTrimEnd,'String','0');
        set(hMean,'Value',1); set(hTaper,'Value',1); set(hQC,'Value',1); refresh();
    end
    function onCancel(~,~), opts=[]; delete(dlg); end
    function onKey(~,event)
        if strcmp(event.Key,'escape'), onCancel([],[]); end
    end
end
