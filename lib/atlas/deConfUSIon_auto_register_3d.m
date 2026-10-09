function [Transf, info] = deConfUSIon_auto_register_3d(atlas, scananatomy, opts)
% deConfUSIon_auto_register_3d
% =============================================================
% Automatic initial atlas registration for deConfUSIon.
%
% Produces a Transformation struct in EXACTLY the convention used by
% registration_ccf, so the result can be handed straight to the GUI as
% the initial transform and then refined by hand:
%
%     Transf.M     4x4, used as affine3d(M) with row-vector convention
%     Transf.size  output grid size = size(atlas reference volume)
%
% registration_ccf sets R.T0 = Transf.M, with scale = [1 1 1] and
% Trot = eye(4), so the GUI opens showing this alignment and every
% manual control still works from there. Nothing is locked.
%
% USAGE
%   [Transf, info] = deConfUSIon_auto_register_3d(atlas, anatomic)
%   [Transf, info] = deConfUSIon_auto_register_3d(atlas, anatomic, opts)
%
% opts fields (all optional)
%   .verbose      true      print progress
%   .maxLevel     4         coarsest downsample factor
%   .fixedField   'auto'    'Vascular' | 'Histology' | 'auto'
%   .rotRangeDeg  16        half-range of the coarse rotation search
%   .rotStepDeg   4         step of the coarse rotation search
%   .logFcn       []        function handle for log messages
%
% info fields
%   .modality, .score0, .score, .improved, .stages, .dofMask, .elapsed
%
% METHOD (each stage is only accepted if it improves the score)
%   0  resample anatomy onto the atlas grid via interpolate3D
%   1  moment matching: centroid + per-axis RMS extent -> translation+scale
%   2  coarse rotation search, axis by axis, on a downsampled grid
%   3  Nelder-Mead refinement of the active parameters, coarse then fine
%
% Similarity metric is normalised mutual information, which tolerates the
% different contrast of power-Doppler anatomy versus the atlas reference.
%
% ASCII only. MATLAB 2017b compatible.
% Requires: imwarp / affine3d / imref3d (already used by registration_ccf).
% =============================================================

tStart = tic;

if nargin < 3 || isempty(opts) || ~isstruct(opts)
    opts = struct();
end
opts = setDefault(opts,'verbose',      true);
opts = setDefault(opts,'maxLevel',     4);
opts = setDefault(opts,'fixedField',   'auto');
opts = setDefault(opts,'rotRangeDeg',  16);
opts = setDefault(opts,'rotStepDeg',   4);
opts = setDefault(opts,'logFcn',       []);

Transf = struct('M', eye(4), 'size', []);
info   = struct();

%% ---------------------------------------------------------
% 1) VALIDATE
%% ---------------------------------------------------------
if ~isstruct(atlas)
    error('deConfUSIon_auto_register_3d: atlas must be a struct.');
end
if ~isstruct(scananatomy) || ~isfield(scananatomy,'Data') || isempty(scananatomy.Data)
    error('deConfUSIon_auto_register_3d: scananatomy needs a non-empty .Data field.');
end

% Pick the atlas reference volume. registration_ccf uses Vascular as the
% default underlay (R.ms1 = R.mapVascular), so match that grid.
fixedName = '';
if strcmpi(opts.fixedField,'auto')
    if isfield(atlas,'Vascular') && ~isempty(atlas.Vascular)
        fixedName = 'Vascular';
    elseif isfield(atlas,'Histology') && ~isempty(atlas.Histology)
        fixedName = 'Histology';
    end
else
    if isfield(atlas, opts.fixedField)
        fixedName = opts.fixedField;
    end
end
if isempty(fixedName)
    error('deConfUSIon_auto_register_3d: atlas has no usable Vascular or Histology volume.');
end

F = double(atlas.(fixedName));
if ndims(F) ~= 3
    error('deConfUSIon_auto_register_3d: atlas.%s must be a 3D volume.', fixedName);
end
Transf.size = size(F);

%% ---------------------------------------------------------
% 2) DETECT MODALITY
%% ---------------------------------------------------------
if exist('deConfUSIon_detect_modality','file') == 2
    det = deConfUSIon_detect_modality(scananatomy, []);
else
    det = struct('modality','3d_probe','nZ',size(scananatomy.Data,3), ...
                 'confidence','low','reason','detector not found', ...
                 'dofMask',true(1,9),'zRatio',NaN,'voxelKnown',false);
end
info.modality = det.modality;
info.detect   = det;
info.dofMask  = det.dofMask;

logMsg(opts, sprintf('[auto-reg] Modality: %s (%s) - %s', ...
    det.modality, det.confidence, det.reason));

%% ---------------------------------------------------------
% 3) BRING ANATOMY ONTO THE ATLAS GRID
%    (same call registration_ccf makes internally)
%% ---------------------------------------------------------
sc = scananatomy;
sc.Data = normalizeVol(double(sc.Data));
if ~isfield(sc,'VoxelSize') || isempty(sc.VoxelSize)
    sc.VoxelSize = [1 1 1];
end

if exist('interpolate3D','file') ~= 2
    error('deConfUSIon_auto_register_3d: interpolate3D.m not found on the path.');
end
tmp = interpolate3D(atlas, sc);
Mv  = normalizeVol(double(tmp.Data));

% interpolate3D returns the atlas voxel grid but not necessarily the atlas
% array size; pad or crop so both live on the same lattice.
Mv = fitToSize(Mv, size(F));

F  = normalizeVol(F);

logMsg(opts, sprintf('[auto-reg] Fixed: atlas.%s %s | Moving: %s', ...
    fixedName, joinSize(size(F)), joinSize(size(Mv))));

%% ---------------------------------------------------------
% 4) CENTROID OF THE FIXED VOLUME (rotation centre)
%% ---------------------------------------------------------
[cF, sF, okF] = volMoments(F);
[cM, sM, okM] = volMoments(Mv);

if ~okF || ~okM
    warning('deConfUSIon_auto_register_3d:EmptyVolume', ...
        'One volume is effectively empty. Returning identity.');
    info.score0 = 0; info.score = 0; info.improved = false;
    info.stages = {}; info.elapsed = toc(tStart);
    return;
end

% moments come back as [dim1 dim2 dim3] = [y x z]
% affine3d uses x = dim2, y = dim1, z = dim3
C = [cF(2) cF(1) cF(3)];

nLevels = max(1, round(opts.maxLevel));
dsList  = unique([nLevels, max(1,round(nLevels/2))], 'stable');

score0 = nmiScore(F, Mv);
best   = [0 0 0, 0 0 0, 1 1 1];
info.score0 = score0;
stages = {};
stages{end+1} = sprintf('identity: NMI = %.4f', score0); %#ok<AGROW>
logMsg(opts, sprintf('[auto-reg] identity          NMI = %.4f', score0));

%% ---------------------------------------------------------
% 5) STAGE 1 - MOMENT MATCHING
%% ---------------------------------------------------------
p = best;
if info.dofMask(7), p(7) = safeRatio(sF(2), sM(2)); end   % sx <- dim2
if info.dofMask(8), p(8) = safeRatio(sF(1), sM(1)); end   % sy <- dim1
if info.dofMask(9), p(9) = safeRatio(sF(3), sM(3)); end   % sz <- dim3

% translation is measured AFTER scaling about C, so warp once and re-measure
W = warpVol(Mv, matFromParams(p, C), size(F));
[cW, ~, okW] = volMoments(W);
if okW
    if info.dofMask(1), p(1) = cF(2) - cW(2); end
    if info.dofMask(2), p(2) = cF(1) - cW(1); end
    if info.dofMask(3), p(3) = cF(3) - cW(3); end
end

sMom = nmiScore(F, warpVol(Mv, matFromParams(p, C), size(F)));
if sMom > score0
    best = p;
    stages{end+1} = sprintf('moment match: NMI = %.4f', sMom); %#ok<AGROW>
    logMsg(opts, sprintf('[auto-reg] moment match      NMI = %.4f', sMom));
else
    stages{end+1} = sprintf('moment match rejected (NMI = %.4f)', sMom); %#ok<AGROW>
    logMsg(opts, sprintf('[auto-reg] moment match      NMI = %.4f  (rejected)', sMom));
end

%% ---------------------------------------------------------
% 6) STAGE 2 - COARSE ROTATION SEARCH
%    fminsearch perturbs a zero start by only 2.5e-4, so rotation must be
%    seeded explicitly or it is never explored.
%% ---------------------------------------------------------
rotAxes = find(info.dofMask(4:6)) + 3;
if ~isempty(rotAxes)
    ds = dsList(1);
    Fd = F(1:ds:end, 1:ds:end, 1:ds:end);
    angles = deg2radLocal(-abs(opts.rotRangeDeg):abs(opts.rotStepDeg):abs(opts.rotRangeDeg));
    bestS  = nmiScore(Fd, downs(warpVol(Mv, matFromParams(best, C), size(F)), ds));

    for sweep = 1:2
        for k = rotAxes
            trial = best;
            for a = angles
                trial(k) = a;
                s = nmiScore(Fd, downs(warpVol(Mv, matFromParams(trial, C), size(F)), ds));
                if s > bestS
                    bestS = s;
                    best  = trial;
                end
            end
        end
    end
    sRot = nmiScore(F, warpVol(Mv, matFromParams(best, C), size(F)));
    stages{end+1} = sprintf('rotation search: NMI = %.4f', sRot); %#ok<AGROW>
    logMsg(opts, sprintf('[auto-reg] rotation search   NMI = %.4f  (%.1f %.1f %.1f deg)', ...
        sRot, best(4)*180/pi, best(5)*180/pi, best(6)*180/pi));
end

%% ---------------------------------------------------------
% 7) STAGE 3 - NELDER-MEAD REFINEMENT (coarse then fine)
%% ---------------------------------------------------------
SCL = [8 8 8, 0.12 0.12 0.12, 0.08 0.08 0.08];
OFF = [0 0 0, 0 0 0, 1 1 1];
act = find(info.dofMask);

nmOpts = optimset('Display','off','TolX',1e-3,'TolFun',1e-5, ...
                  'MaxIter',3000,'MaxFunEvals',6000);

for ii = 1:numel(dsList)
    ds = dsList(ii);
    Fd = F(1:ds:end, 1:ds:end, 1:ds:end);

    refBest = best;
    costFcn = @(q) -nmiScore(Fd, downs(warpVol(Mv, ...
                    matFromParams(unpackParams(q, refBest, act, OFF, SCL), C), ...
                    size(F)), ds));

    q0 = (refBest(act) - OFF(act)) ./ SCL(act);
    sBefore = -costFcn(q0);

    try
        qOpt = fminsearch(costFcn, q0, nmOpts);
    catch ME
        logMsg(opts, ['[auto-reg] fminsearch failed: ' ME.message]);
        continue;
    end

    cand  = unpackParams(qOpt, refBest, act, OFF, SCL);
    sAfter = nmiScore(Fd, downs(warpVol(Mv, matFromParams(cand, C), size(F)), ds));

    if sAfter > sBefore && all(isfinite(cand)) && all(abs(cand(7:9)) > 1e-6)
        best = cand;
    end

    sNow = nmiScore(F, warpVol(Mv, matFromParams(best, C), size(F)));
    stages{end+1} = sprintf('refine ds=%d: NMI = %.4f', ds, sNow); %#ok<AGROW>
    logMsg(opts, sprintf('[auto-reg] refine ds=%d       NMI = %.4f', ds, sNow));
end

%% ---------------------------------------------------------
% 8) FINALISE - never return something worse than identity
%% ---------------------------------------------------------
scoreFinal = nmiScore(F, warpVol(Mv, matFromParams(best, C), size(F)));

if scoreFinal <= score0
    logMsg(opts, '[auto-reg] No improvement over identity. Returning identity.');
    Transf.M     = eye(4);
    info.score   = score0;
    info.improved = false;
else
    Transf.M     = matFromParams(best, C);
    info.score   = scoreFinal;
    info.improved = true;
end

info.params      = best;
info.paramNames  = {'tx','ty','tz','rx','ry','rz','sx','sy','sz'};
info.rotationDeg = best(4:6) * 180/pi;
info.centre      = C;
info.fixedField  = fixedName;
info.stages      = stages;
info.elapsed     = toc(tStart);

logMsg(opts, sprintf('[auto-reg] FINAL NMI %.4f (identity %.4f, gain %+.1f%%) in %.1f s', ...
    info.score, score0, 100*(info.score/max(score0,eps) - 1), info.elapsed));

end % ===================== main =====================


%% =====================================================================
%  LOCAL FUNCTIONS
%% =====================================================================

function M = matFromParams(p, C)
% Build the 4x4 for affine3d (row-vector convention: [x y z 1] * M).
% Rotation and scale act about the fixed-volume centroid C, which keeps
% rotation decoupled from translation and makes the search well behaved.
tx = p(1); ty = p(2); tz = p(3);
rx = p(4); ry = p(5); rz = p(6);
sx = p(7); sy = p(8); sz = p(9);

Rx = [1 0 0; 0 cos(rx) -sin(rx); 0 sin(rx) cos(rx)];
Ry = [cos(ry) 0 sin(ry); 0 1 0; -sin(ry) 0 cos(ry)];
Rz = [cos(rz) -sin(rz) 0; sin(rz) cos(rz) 0; 0 0 1];

A = Rz * Ry * Rx * diag([sx sy sz]);

L = eye(4);
L(1:3,1:3) = A.';          % transpose: row-vector convention

M = transMat(-C) * L * transMat(C) * transMat([tx ty tz]);
end


function M = transMat(t)
M = eye(4);
M(4,1:3) = t(:).';
end


function W = warpVol(V, M, outSize)
try
    W = imwarp(V, affine3d(M), 'OutputView', imref3d(outSize), ...
               'Interp', 'linear', 'FillValues', 0);
catch
    W = zeros(outSize);
end
end


function V = downs(V, ds)
if ds > 1
    V = V(1:ds:end, 1:ds:end, 1:ds:end);
end
end


function p = unpackParams(qActive, base, act, OFF, SCL)
p = base;
p(act) = OFF(act) + qActive(:).' .* SCL(act);
end


function s = nmiScore(A, B)
% Normalised mutual information on the union of the two supports.
% Returns 1 for independent images, higher for aligned ones.
nBins = 48;

A = A(:); B = B(:);
m = (A > 0) | (B > 0);
if nnz(m) < 200
    s = 0; return;
end
A = A(m); B = B(m);

rA = max(A) - min(A); if rA <= 0, s = 0; return; end
rB = max(B) - min(B); if rB <= 0, s = 0; return; end

ai = floor((A - min(A)) / rA * (nBins - 1)) + 1;
bi = floor((B - min(B)) / rB * (nBins - 1)) + 1;
ai = min(max(ai,1), nBins);
bi = min(max(bi,1), nBins);

H = accumarray([ai bi], 1, [nBins nBins]);
H = H / sum(H(:));

pa = sum(H,2);
pb = sum(H,1);

hA  = entropyLocal(pa);
hB  = entropyLocal(pb);
hAB = entropyLocal(H(:));

if hAB <= eps
    s = 0;
else
    s = (hA + hB) / hAB;
end
end


function e = entropyLocal(p)
p = p(p > 0);
e = -sum(p .* log(p));
end


function [c, s, ok] = volMoments(V)
% Centroid and per-axis RMS extent of the suprathreshold support.
c = [0 0 0]; s = [1 1 1]; ok = false;

mx = max(V(:));
if ~isfinite(mx) || mx <= 0
    return;
end

thr = 0.30 * mx;
idx = find(V > thr);
if numel(idx) < 50
    thr = 0.10 * mx;
    idx = find(V > thr);
end
if numel(idx) < 50
    return;
end

[i1, i2, i3] = ind2sub(size(V), idx);
w = double(V(idx));
sw = sum(w);

c = [sum(w.*i1) sum(w.*i2) sum(w.*i3)] / sw;
s = sqrt([ sum(w.*(i1-c(1)).^2) sum(w.*(i2-c(2)).^2) sum(w.*(i3-c(3)).^2) ] / sw);
s(~isfinite(s) | s <= 0) = 1;
ok = true;
end


function r = safeRatio(a, b)
if ~isfinite(a) || ~isfinite(b) || b <= 0 || a <= 0
    r = 1;
else
    r = a / b;
    if r < 0.25, r = 0.25; end
    if r > 4.0,  r = 4.0;  end
end
end


function V = normalizeVol(V)
V(~isfinite(V)) = 0;
lo = prctileLocal(V(:), 1);
hi = prctileLocal(V(:), 99);
if hi <= lo
    lo = min(V(:)); hi = max(V(:));
end
if hi <= lo
    V = zeros(size(V)); return;
end
V = (V - lo) / (hi - lo);
V(V < 0) = 0;
V(V > 1) = 1;
end


function v = prctileLocal(x, p)
x = x(isfinite(x));
if isempty(x), v = 0; return; end
x = sort(x(:));
n = numel(x);
r = max(1, min(n, round(p/100 * n)));
v = x(r);
end


function V = fitToSize(V, tgt)
% Centre-pad or centre-crop V to tgt without rescaling intensities.
cur = size(V);
if numel(cur) < 3, cur(3) = 1; end
if isequal(cur, tgt), return; end

out = zeros(tgt);
n   = min(cur, tgt);

sIn  = floor((cur - n)/2) + 1;
sOut = floor((tgt - n)/2) + 1;

out(sOut(1):sOut(1)+n(1)-1, sOut(2):sOut(2)+n(2)-1, sOut(3):sOut(3)+n(3)-1) = ...
    V(sIn(1):sIn(1)+n(1)-1, sIn(2):sIn(2)+n(2)-1, sIn(3):sIn(3)+n(3)-1);

V = out;
end


function r = deg2radLocal(d)
r = d * pi / 180;
end


function s = joinSize(sz)
s = ['[' strtrim(sprintf('%d ', sz)) ']'];
end


function opts = setDefault(opts, name, val)
if ~isfield(opts, name) || isempty(opts.(name))
    opts.(name) = val;
end
end


function logMsg(opts, msg)
if isfield(opts,'logFcn') && isa(opts.logFcn,'function_handle')
    try, opts.logFcn(msg); catch, end
end
if isfield(opts,'verbose') && opts.verbose
    fprintf('%s\n', msg);
end
end
