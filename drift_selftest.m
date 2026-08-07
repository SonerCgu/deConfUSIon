function drift_selftest(exportPath)
% =========================================================================
% drift_selftest - verifies driftcompensation.m on synthetic data
% =========================================================================
%   drift_selftest                 % writes QC into a temp folder
%   drift_selftest('C:\temp\qc')
%
% Builds a time series where the TRUTH IS KNOWN:
%   signal = baseline level + drift + drug response + noise
% and then checks, for every method, whether
%   (a) the drift is removed,
%   (b) the DRUG RESPONSE SURVIVES,
%   (c) the mean image is preserved.
%
% This is the test that matters: a method that removes the drift but eats
% the response is worse than doing nothing.
% =========================================================================

if nargin < 1 || isempty(exportPath)
    exportPath = fullfile(tempdir,'drift_selftest');
end
if exist(exportPath,'dir') ~= 7, mkdir(exportPath); end

rng(42);

% ------------------------------------------------------------ synthetic
TR   = 1;            % s
T    = 600;          % frames -> 600 s
ny   = 24; nx = 24;
t    = (0:T-1)'*TR;

baseLevel = 1000;                     % arbitrary units
tInj      = 120;                      % injection at 120 s
respLen   = 150;                      % response duration

% drift: slow saturating ramp (probe warm-up like) - NOT a pure polynomial
drift = 80*(1 - exp(-t/300)) + 0.02*t;

% response: gamma-variate, returns to baseline by ~330 s
dt  = max(0,t - tInj);
tau = respLen/4;
resp = (dt./tau).^2 .* exp(-dt./tau);
resp(t < tInj) = 0;
resp = 60 * resp / max(resp);          % 6% of baseline at peak

% two voxel classes: responders (centre) and non-responders (rim)
[XX,YY] = meshgrid(1:nx,1:ny);
R = sqrt((XX-nx/2).^2 + (YY-ny/2).^2);
respMask  = R < 6;                     % responders
noiseMask = R > 10;                    % never respond -> reference region

I = zeros(ny,nx,T,'single');
for k = 1:T
    frame = baseLevel + drift(k) + 3*randn(ny,nx);
    frame(respMask) = frame(respMask) + resp(k);
    I(:,:,k) = single(frame);
end

truthResp = resp;
fprintf('\n=== drift_selftest ===\n');
fprintf('T=%d, TR=%g s, drift range %.1f, response peak %.1f (%.1f%% of baseline)\n\n', ...
    T, TR, max(drift)-min(drift), max(resp), 100*max(resp)/baseLevel);

% ------------------------------------------------------------- methods
tests = { ...
  'glm',      struct('injectionSec',tInj,'responseSec',respLen,'polyOrder',1); ...
  'compcor',  struct('refMask',noiseMask,'nComp',3); ...
  'anchor',   struct('tailSec',[420 600],'polyOrder',1); ...
  'spline',   struct('knotSec',150); ...
  'robust',   struct('polyOrder',1); ...
  'baseline', struct('polyOrder',1); ...
  'poly',     struct('polyOrder',1); ...
  'dct',      struct('cutoffSec',200); ...
  'reference',struct('refMask',noiseMask)};

fprintf('%-11s %10s %10s %10s %10s\n','method','driftRed%','respKept%','meanImgR','level');
fprintf('%s\n', repmat('-',1,56));

results = struct();
for i = 1:size(tests,1)
    m = tests{i,1};
    o = tests{i,2};
    o.method      = m;
    o.baselineSec = [0 tInj];
    o.verbose     = false;
    o.tag         = ['selftest_' m];

    ws = warning('off','all');
    try
        [Ic, st] = driftcompensation(I, TR, exportPath, o);
    catch ME
        warning(ws);
        fprintf('%-11s   FAILED: %s\n', m, ME.message);
        continue;
    end
    warning(ws);

    Yc = reshape(Ic, ny*nx, T);

    % response recovered in responder voxels, referenced to their baseline
    rIdx = find(respMask(:));
    rc   = mean(double(Yc(rIdx,:)),1)';
    rc   = rc - mean(rc(t <= tInj));
    denom = sum(truthResp.^2);
    if denom > 0
        respKept = 100 * (truthResp' * rc) / denom;   % regression slope vs truth
    else
        respKept = NaN;
    end

    % residual drift measured on NON-responding voxels
    nIdx = find(noiseMask(:));
    nc   = mean(double(Yc(nIdx,:)),1)';
    nc   = nc - mean(nc(t <= tInj));
    driftRed = 100*(1 - (max(nc)-min(nc)) / (max(drift)-min(drift)));

    % level preservation
    lvl = mean(mean(double(Yc(:, t <= tInj))));

    fprintf('%-11s %10.1f %10.1f %10.4f %10.1f\n', ...
        m, driftRed, respKept, st.meanImageCorr, lvl);

    results.(m) = struct('driftRed',driftRed,'respKept',respKept, ...
                         'meanImageCorr',st.meanImageCorr,'level',lvl,'stats',st);
end

fprintf('%s\n', repmat('-',1,56));
fprintf(['\nHow to read this:\n' ...
         '  driftRed%%   100 = drift fully removed from non-responding tissue\n' ...
         '  respKept%%   100 = drug response fully preserved, 0 = destroyed\n' ...
         '  meanImgR    correlation of the mean image before/after (want ~1.0)\n' ...
         '  level       baseline level after correction (truth = %.0f)\n\n'], baseLevel);
fprintf('A good method scores HIGH on both driftRed and respKept.\n');
fprintf('QC images written to: %s\n\n', exportPath);

assignin('base','drift_selftest_results',results);
end
