% GA_AUTO_ERROR_PRINT_PATCH_V1
function varargout = GroupAnalysis_Map(action, varargin)
% GroupAnalysis_Map - self-contained map backend for modular GroupAnalysis.
% MATLAB 2017b + 2023b compatible.

if nargin < 1 || isempty(action)
    error('GroupAnalysis_Map requires an action string.');
end

actionIn = strtrim(char(action));
key = lower(actionIn);
key = regexprep(key,'[^a-z0-9]','');

switch key
    case 'getcachedgroupbundle'
        [G, cache] = localGetCachedGroupBundle(varargin{:});
        varargout = localPackOut(nargout, G, cache);
    case 'buildpreviewmapfrombundle'
        [mapNow, winInfoTxt] = localBuildPreviewMapFromBundle(varargin{:});
        varargout = localPackOut(nargout, mapNow, winInfoTxt);
    case 'resolvepreviewunderlay'
        U = localResolvePreviewUnderlay(varargin{:});
        varargout = localPackOut(nargout, U);
    case 'renderpscoverlay'
        h = localRenderPSCOverlay(varargin{:});
        varargout = localPackOut(nargout, h);
    case 'runpscmapanalysis'
        [R, cacheOut] = localRunPSCMapAnalysis(varargin{:});
        varargout = localPackOut(nargout, R, cacheOut);
    case 'loadgroupunderlayfile'
        U = localLoadGroupUnderlayFile(varargin{:});
        varargout = localPackOut(nargout, U);
    case 'exportmapdisplaypng'
        localExportMapDisplayPNG(varargin{:});
        varargout = {};
    case 'buildgroupanalysisvideoexportga'
        E = localBuildGroupAnalysisVideoExportGA(varargin{:});
        varargout = localPackOut(nargout, E);
    case 'onexportgroupmappptfrommain'
        localExportGroupMapPPTCompat(varargin{:});
        varargout = {};
    otherwise
        error('Unsupported GroupAnalysis_Map action: %s', actionIn);
end
end

function out = localPackOut(nout, varargin)
if nout == 0
    out = {};
else
    out = varargin(1:min(nout,numel(varargin)));
end
end

function [G, cache] = localGetCachedGroupBundle(cache, bundleFile)
if nargin < 1 || isempty(cache), cache = struct(); end
if nargin < 2 || isempty(bundleFile), error('Bundle file is empty.'); end
bundleFile = strtrimSafeLocal(bundleFile);
if exist(bundleFile,'file') ~= 2, error('Bundle file not found: %s', bundleFile); end
key = ['GB||' bundleFile];
if isstruct(cache) && isfield(cache,'groupBundle') && isa(cache.groupBundle,'containers.Map')
    try
        if isKey(cache.groupBundle,key), G = cache.groupBundle(key); return; end
    catch
    end
end
L = load(bundleFile);
G = [];
if isfield(L,'G') && isstruct(L.G)
    G = L.G;
else
    f = fieldnames(L);
    for i = 1:numel(f)
        X = L.(f{i});
        if isstruct(X) && (isfield(X,'pscAtlas4D') || isfield(X,'scmMapAtlas') || isfield(X,'underlay2D'))
            G = X;
            break;
        end
    end
end
if isempty(G) || ~isstruct(G), error('Bundle MAT does not contain a valid G/group struct: %s', bundleFile); end
try
    if ~isstruct(cache), cache = struct(); end
    if ~isfield(cache,'groupBundle') || ~isa(cache.groupBundle,'containers.Map')
        cache.groupBundle = containers.Map('KeyType','char','ValueType','any');
    end
    cache.groupBundle(key) = G;
catch
end
end

function [mapNow, winInfoTxt] = localBuildPreviewMapFromBundle(S, G)
% GA_STEPMOTOR_SCM_MAP_PATCH_V1
winInfoTxt = '';
G = localApplySliceFromStateToBundle(S,G);
src = localGetCharField(S,'mapSource','Recompute from exported PSC');
useGlobal = localGetLogicalField(S,'mapUseGlobalWindows',true);
sigma = localGetNumField(S,'mapSigma',0);
hasPSC = isfield(G,'pscAtlas4D') && ~isempty(G.pscAtlas4D);
hasMap = localHasExportedMap(G);
if (useGlobal || ~strcmpi(src,'Use exported SCM map')) && hasPSC
    bw = localGetVecField(S,'mapGlobalBaseSec',[30 240]);
    sw = localGetVecField(S,'mapGlobalSigSec',[840 900]);
    mapNow = localRecomputeMapFromPSC(G,bw,sw,sigma);
    winInfoTxt = sprintf('base %.0f-%.0fs | sig %.0f-%.0fs',bw(1),bw(2),sw(1),sw(2));
elseif hasMap
    mapNow = localGetExportedMap(G);
    if sigma > 0, mapNow = localSmooth2D(mapNow,sigma); end
    winInfoTxt = 'exported SCM map';
elseif hasPSC
    bw = localGetVecField(S,'mapGlobalBaseSec',[30 240]);
    sw = localGetVecField(S,'mapGlobalSigSec',[840 900]);
    mapNow = localRecomputeMapFromPSC(G,bw,sw,sigma);
    winInfoTxt = sprintf('PSC fallback base %.0f-%.0fs | sig %.0f-%.0fs',bw(1),bw(2),sw(1),sw(2));
else
    error('Bundle has neither pscAtlas4D nor an exported SCM map.');
end
mapNow = double(localSqueeze2D(mapNow,G));
mapNow(~isfinite(mapNow)) = 0;
end

function tf = localHasExportedMap(G)
names = {'scmMapSignedAtlas','scmMapAtlas','mapAtlas','pscMapAtlas','scmMap','PSCmap','pscMap','map','scmMapDisplayAtlas','overlay2D','groupMap2D'};
tf = false;
for i = 1:numel(names)
    if isfield(G,names{i}) && ~isempty(G.(names{i}))
        tf = true; return;
    end
end
end

function M = localGetExportedMap(G)
names = {'scmMapSignedAtlas','scmMapAtlas','mapAtlas','pscMapAtlas','scmMap','PSCmap','pscMap','map','scmMapDisplayAtlas','overlay2D','groupMap2D'};
for i = 1:numel(names)
    if isfield(G,names{i}) && ~isempty(G.(names{i}))
        M = localSqueeze2D(G.(names{i}),G);
        return;
    end
end
error('No exported map field found.');
end

function map2 = localRecomputeMapFromPSC(G,bw,sw,sigma)
% Integrated V6 robust for single-slice [Y X T], step-motor [Y X Z T], and static maps.
PSC = double(G.pscAtlas4D);
PSC(~isfinite(PSC)) = 0;
TR = localGetNumField(G,'TR',NaN);
if ~isfinite(TR) || TR <= 0
    try, if isfield(G,'tsec') && numel(G.tsec)>1, TR = median(diff(double(G.tsec(:)))); end, catch, end
end
if ~isfinite(TR) || TR <= 0, TR = 1; end
if ndims(PSC) == 4
    z = localPickZ(G,size(PSC,3)); z = max(1,min(size(PSC,3),round(z)));
    P = squeeze(PSC(:,:,z,:));
elseif ndims(PSC) == 3
    P = PSC;
elseif ndims(PSC) == 2
    map2 = PSC; map2(~isfinite(map2)) = 0; return;
else
    error('Unsupported pscAtlas4D dimensionality: %d', ndims(PSC));
end
if ndims(P) == 2
    map2 = P; map2(~isfinite(map2)) = 0; return;
end
if ndims(P) ~= 3, error('Selected PSC data is not [Y X T]. Size: %s', mat2str(size(P))); end
T = size(P,3);
if T < 2, map2 = P(:,:,1); map2(~isfinite(map2))=0; return; end
if numel(bw)<2 || any(~isfinite(bw(1:2))), bw = [0 max(TR,0.2*T*TR)]; end
if numel(sw)<2 || any(~isfinite(sw(1:2))), sw = [max(0,0.7*T*TR) T*TR]; end
b0 = max(1,min(T,floor(bw(1)/TR)+1)); b1 = max(1,min(T,floor(bw(2)/TR)+1));
s0 = max(1,min(T,floor(sw(1)/TR)+1)); s1 = max(1,min(T,floor(sw(2)/TR)+1));
if b1 < b0, tmp=b0; b0=b1; b1=tmp; end
if s1 < s0, tmp=s0; s0=s1; s1=tmp; end
baseMap = mean(P(:,:,b0:b1),3); sigMap = mean(P(:,:,s0:s1),3);
map2 = sigMap - baseMap;
if sigma > 0, map2 = localSmooth2D(map2,sigma); end
map2(~isfinite(map2)) = 0;
end

function U = localResolvePreviewUnderlay(S,G,mapNow)
G = localApplySliceFromStateToBundle(S,G);
targetSz = size(mapNow); targetSz = targetSz(1:2);
mode = localGetCharField(S,'mapUnderlayMode','Bundle underlay');

if strcmpi(mode,'Loaded custom underlay') && isfield(S,'mapLoadedUnderlay') && ~isempty(S.mapLoadedUnderlay)
    U = localAnyTo2D(S.mapLoadedUnderlay,targetSz,G);
    return;
end

% New SCM bundle underlay library exported by SCM_gui.
bundleMode = '';
mlow = lower(strtrimSafeLocal(mode));
if ~isempty(strfind(mlow,'normal')),   bundleMode = 'normal';   end
if ~isempty(strfind(mlow,'histology')), bundleMode = 'histology'; end
if ~isempty(strfind(mlow,'vascular')),  bundleMode = 'vascular';  end
if ~isempty(strfind(mlow,'regions')),   bundleMode = 'regions';   end
if isempty(bundleMode) && ~isempty(strfind(mlow,'bundle'))
    bundleMode = 'selected';
end

if ~isempty(bundleMode)
    U = localGetBundleUnderlayByMode(G,bundleMode,targetSz);
    if ~isempty(U)
        return;
    end
end

names = {'underlay2D','underlayAtlas2D','underlayAtlas','commonUnderlay','brainImage','bg','bgAtlas','meanAtlas','anatomyAtlas'};
U = [];
for i = 1:numel(names)
    if isfield(G,names{i}) && ~isempty(G.(names{i}))
        U = G.(names{i});
        break;
    end
end
if isempty(U), U = zeros(targetSz); end
U = localAnyTo2D(U,targetSz,G);
end

function U = localGetBundleUnderlayByMode(G,modeName,targetSz)
U = [];
try
    if ~isfield(G,'underlays') || ~isstruct(G.underlays)
        return;
    end

    modeName = lower(strtrimSafeLocal(modeName));
    if strcmpi(modeName,'selected')
        modeName = '';
        try, modeName = lower(strtrimSafeLocal(G.underlaySelectedMode)); catch, end
        if isempty(modeName), modeName = 'normal'; end
    end

    order = {modeName,'normal','histology','vascular','regions'};
    for kk = 1:numel(order)
        fn = order{kk};
        if isempty(fn), continue; end
        if isfield(G.underlays,fn)
            E = G.underlays.(fn);
            if isstruct(E) && isfield(E,'data') && ~isempty(E.data)
                U = localAnyTo2D(E.data,targetSz,G);
                return;
            elseif isnumeric(E) || islogical(E)
                U = localAnyTo2D(E,targetSz,G);
                return;
            end
        end
    end
catch
    U = [];
end
end
function mode = localMapPolarityModeV11(R)
% SCM_gui signMode equivalent for GroupAnalysis_Map display.
mode = 1;
try
    pol = lower(strtrim(char(localGetCharField(R,'polarity','Positive only'))));
catch
    pol = 'positive only';
end
if ~isempty(strfind(pol,'negative')) && isempty(strfind(pol,'positive'))
    mode = 2;
elseif ~isempty(strfind(pol,'+')) || ~isempty(strfind(pol,'both')) || ~isempty(strfind(pol,'pos/neg')) || ~isempty(strfind(pol,'positive + negative'))
    mode = 3;
else
    mode = 1;
end
end

function [posLo,posHi,negHi] = localMapColorLimitsV11(R)
posLo = 0; posHi = 100; negHi = 100;
try
    ca = localGetVecField(R,'caxis',[0 100]);
    ca = double(ca(:)');
    if numel(ca) >= 2 && all(isfinite(ca(1:2)))
        posLo = ca(1); posHi = ca(2);
    end
catch
end
try
    nca = localGetVecField(R,'negCaxis',[-max(abs([posLo posHi 100])) 0]);
    nca = double(nca(:)');
    if numel(nca) >= 2 && all(isfinite(nca(1:2)))
        negHi = max(abs(nca(1:2)));
    end
catch
end
if ~isfinite(posLo), posLo = 0; end
if ~isfinite(posHi) || posHi <= posLo
    tmp = max(abs([posLo posHi 100]));
    if ~isfinite(tmp) || tmp <= 0, tmp = 100; end
    posLo = 0; posHi = tmp;
end
if ~isfinite(negHi) || negHi <= 0
    negHi = max(abs([posLo posHi 100]));
end
if ~isfinite(negHi) || negHi <= 0, negHi = 100; end
end

function [posCM,negMagCM,signedCM] = localMapSCMColormapsV11(n)
if nargin < 1 || isempty(n), n = 256; end
n = max(2,round(n));
if exist('blackbdy_iso','file') == 2
    posCM = blackbdy_iso(n);
else
    posCM = hot(n);
end
posCM = min(max(posCM,0),1);
if ~isempty(posCM), posCM(1,:) = [0 0 0]; end
nNeg = floor(n/2);
nPos = n - nNeg;
if exist('winter_brain_fsl','file') == 2
    negSigned = winter_brain_fsl(max(nNeg,2));
else
    negSigned = winter(max(nNeg,2));
end
negSigned = negSigned(1:nNeg,:);
if nNeg > 0
    negSigned = negSigned .* repmat(linspace(1,0,nNeg)',1,3);
    negSigned(end,:) = [0 0 0];
end
if exist('blackbdy_iso','file') == 2
    posSigned = blackbdy_iso(max(nPos,2));
else
    posSigned = hot(max(nPos,2));
end
posSigned = posSigned(1:nPos,:);
if ~isempty(posSigned), posSigned(1,:) = [0 0 0]; end
signedCM = min(max([negSigned; posSigned],0),1);
negMagCM = flipud(negSigned);
if isempty(negMagCM)
    if exist('winter_brain_fsl','file') == 2, negMagCM = winter_brain_fsl(n); else, negMagCM = winter(n); end
end
negMagCM = min(max(negMagCM,0),1);
if ~isempty(negMagCM), negMagCM(1,:) = [0 0 0]; end
end

function RGB = localMapColorizeV11(V,lo,hi,CM)
V = double(V);
if hi <= lo, hi = lo + eps; end
t = (V - lo) ./ max(eps,(hi-lo));
t(~isfinite(t)) = 0;
t = min(max(t,0),1);
idx = 1 + round(t .* (size(CM,1)-1));
idx = max(1,min(size(CM,1),idx));
RGB = zeros([size(V) 3]);
for cc=1:3
    C = CM(:,cc);
    RGB(:,:,cc) = reshape(C(idx(:)),size(V));
end
end

function h = localRenderPSCOverlay(ax,U,M,R,styleName,showCB)
% V11: exact SCM_gui-style sign handling and alpha modulation for live GroupAnalysis display.
if nargin < 6, showCB = true; end
if nargin < 5 || isempty(styleName), styleName = 'Dark'; end
if isempty(ax) || ~ishghandle(ax)
    error('Invalid axes handle for map rendering.');
end

M = double(M);
M(~isfinite(M)) = 0;

if isfield(R,'flipUDPreview') && logical(R.flipUDPreview)
    M = flipud(M);
    U = localFlipUD(U);
end

U = localAnyTo2D(U,size(M),struct());
Ug = localToGray(U);
Urgb = localToRGB(U);

brainMask = Ug > max(0.02,0.15*max(Ug(:)));
try, brainMask = imfill(brainMask,'holes'); catch, end
try, brainMask = bwareaopen(brainMask,max(10,round(0.001*numel(brainMask)))); catch, end
if nnz(brainMask) < 10, brainMask = true(size(Ug)); end

cla(ax);
try, delete(findall(ancestor(ax,'figure'),'Type','ColorBar')); catch, end
image(ax,Urgb);
axis(ax,'image'); axis(ax,'off'); hold(ax,'on');

[posLo,posHi,negHi] = localMapColorLimitsV11(R);
mode = localMapPolarityModeV11(R);
[posCM,negMagCM,signedCM] = localMapSCMColormapsV11(256);

switch mode
    case 1
        showMask = M > 0;
        dispMap = M;
        CM = posCM; CA = [posLo posHi];
        RGB = localMapColorizeV11(dispMap,posLo,posHi,posCM);
    case 2
        showMask = M < 0;
        dispMap = abs(min(M,0));
        CM = negMagCM; CA = [0 negHi];
        RGB = localMapColorizeV11(dispMap,0,negHi,negMagCM);
    otherwise
        showMask = isfinite(M) & M ~= 0;
        dispMap = M;
        CM = signedCM; CA = [-negHi posHi];
        RGB = localMapColorizeV11(dispMap,-negHi,posHi,signedCM);
end

thr = abs(localGetNumField(R,'threshold',0));
thrMask = double((abs(M) >= thr) & showMask) .* double(brainMask);

a = localGetNumField(R,'alphaPercent',100);
a = max(0,min(100,a))/100;
alphaModOn = localGetLogicalField(R,'alphaModOn',true);
mMin = localGetNumField(R,'modMin',15);
mMax = localGetNumField(R,'modMax',30);
if mMax < mMin, tmp=mMin; mMin=mMax; mMax=tmp; end

if ~alphaModOn
    A = a .* thrMask;
else
    effLo = max(mMin,thr);
    effHi = mMax;
    mag = abs(M);
    mag(~showMask) = NaN;
    if ~isfinite(effHi) || effHi <= effLo
        tmpv = mag(isfinite(mag));
        if isempty(tmpv), effHi = effLo + eps; else, effHi = max(tmpv); end
    end
    if ~isfinite(effHi) || effHi <= effLo, effHi = effLo + eps; end
    modv = (abs(M) - effLo) ./ max(eps,(effHi-effLo));
    modv(~isfinite(modv)) = 0;
    modv = min(max(modv,0),1);
    modv(~showMask) = 0;
    if mode == 1
        A = a .* modv .* thrMask;
    else
        A = a .* (0.20 + 0.80 .* modv) .* thrMask;
    end
end

A(~isfinite(A)) = 0;
A = min(max(A,0),1);
for cc=1:3
    C = RGB(:,:,cc);
    C(A <= 0) = 0;
    RGB(:,:,cc) = C;
end

h = image(ax,RGB);
set(h,'AlphaData',A);
try, set(h,'AlphaDataMapping','none'); catch, end
colormap(ax,CM);
try, caxis(ax,CA); catch, end
if showCB
    cb = colorbar(ax);
    try, set(cb,'Color',[1 1 1]); catch, end
end
if strcmpi(styleName,'Light')
    try, set(ax,'Color',[1 1 1]); catch, end
else
    try, set(ax,'Color',[0 0 0]); catch, end
end
axis(ax,'image'); axis(ax,'off');
hold(ax,'off');
end

function [R, cacheOut] = localRunPSCMapAnalysis(S,subjActive,mapIdx,cacheIn)
if nargin < 4 || isempty(cacheIn), cacheIn = struct(); end
cacheOut = cacheIn;
maps = {}; underlays = {}; subjects = {};
for i = 1:size(subjActive,1)
    bf = '';
    try, bf = strtrimSafeLocal(subjActive{i,8}); catch, end
    if isempty(bf) || exist(bf,'file') ~= 2, continue; end
    [G, cacheOut] = localGetCachedGroupBundle(cacheOut,bf);
    [m,~] = localBuildPreviewMapFromBundle(S,G);
    u = localResolvePreviewUnderlay(S,G,m);
    origRow = i;
    try, if nargin >= 3 && numel(mapIdx) >= i, origRow = mapIdx(i); end; catch, end
    [m,u] = localApplyHemisphereFlip(S,origRow,m,u);
    maps{end+1,1} = m;
    underlays{end+1,1} = u;
    try, subjects{end+1,1} = subjActive{i,2}; catch, subjects{end+1,1} = sprintf('S%d',i); end
end
if isempty(maps), error('No valid maps could be built from selected bundles.'); end
refSz = size(maps{1}); refSz = refSz(1:2);
N = numel(maps);
stack = nan(refSz(1),refSz(2),N);
ustack = nan(refSz(1),refSz(2),N);
for i = 1:N
    stack(:,:,i) = localResizeLike(double(maps{i}),refSz);
    ug = localToGray(localAnyTo2D(underlays{i},refSz,struct()));
    ustack(:,:,i) = localResizeLike(ug,refSz);
end
summaryName = localGetCharField(S,'mapSummary','Mean');
if strcmpi(summaryName,'Median')
    groupMap = localNanMedian3(stack);
else
    groupMap = localNanMean3(stack);
end
commonUnderlay = localNanMean3(ustack);
R = struct();
R.mode = 'Group Maps';
R.groupMap = groupMap;
R.commonUnderlay = commonUnderlay;
R.n = N;
R.mapSummary = summaryName;
R.subjects = subjects;
R.maps = maps;
R.note = 'Built by GroupAnalysis_Map self-contained backend.';
end

function U = localLoadGroupUnderlayFile(fp)
fp = strtrimSafeLocal(fp);
if exist(fp,'file') ~= 2, error('Underlay file not found: %s',fp); end
[~,~,ext] = fileparts(fp); ext = lower(ext);
if strcmp(ext,'.mat')
    L = load(fp); f = fieldnames(L); U = [];
    for i = 1:numel(f)
        if isnumeric(L.(f{i})) || islogical(L.(f{i}))
            U = L.(f{i}); break;
        end
    end
    if isempty(U), error('No numeric image variable found in MAT underlay.'); end
else
    U = imread(fp);
end
end

function localExportMapDisplayPNG(outFile,D,styleName)
if nargin < 3, styleName = 'Dark'; end
figBg = [0 0 0]; if strcmpi(styleName,'Light'), figBg = [1 1 1]; end
f = figure('Visible','off','Color',figBg,'InvertHardcopy','off','MenuBar','none','ToolBar','none','NumberTitle','off');
set(f,'Position',[100 100 1000 800]);
ax = axes('Parent',f,'Units','normalized','Position',[0.06 0.08 0.82 0.84]);
localRenderPSCOverlay(ax,D.underlay,D.map,D.render,styleName,true);
try, title(ax,D.title,'Color',[1 1 1],'FontWeight','bold','Interpreter','none'); catch, end
set(f,'PaperPositionMode','auto');
print(f,outFile,'-dpng','-r300');
close(f);
end

function E = localBuildGroupAnalysisVideoExportGA(S,mapIdx)
if isfield(S,'lastMAP') && isstruct(S.lastMAP) && isfield(S.lastMAP,'groupMap')
    M = S.lastMAP.groupMap; U = S.lastMAP.commonUnderlay;
else
    [R,~] = localRunPSCMapAnalysis(S,S.subj(mapIdx,:),mapIdx,S.cache);
    M = R.groupMap; U = R.commonUnderlay;
end
E = struct();
E.underlay2D = U;
E.brainImage = U;
E.overlay2D = M;
E.groupMap2D = M;
E.functional4D = repmat(double(U),[1 1 1 1]);
E.psc4D = repmat(double(M),[1 1 1 1]);
E.created = datestr(now);
E.note = 'GroupAnalysis video export generated from group map.';
end



function G = localApplySliceFromStateToBundle(S,G)
try
    z = localGetNumField(S,'mapCurrentSlice',NaN);
    if isfinite(z) && z >= 1
        z = round(z);
        G.currentSlice = z;
        G.sliceIdx = z;
        G.zIndex = z;
        G.atlasSliceIndex = z;
    end
catch
end
end

function localExportGroupMapPPTCompat(hFig,makePPT)
% Compatibility handler for old map-backend PPT export action.
if nargin < 2 || isempty(makePPT), makePPT = true; end
if nargin < 1 || isempty(hFig) || ~ishghandle(hFig)
    error('Invalid GroupAnalysis figure handle.');
end
try
    GA_exportGroupMeanSCMBundle_Interactive(hFig,makePPT);
catch ME
    % If the exporter is only available as a local function inside GroupAnalysis.m,
    % trigger the visible button callback instead.
    if makePPT
        h = findall(hFig,'String','Export PPT');
    else
        h = findall(hFig,'String','Export Data SCM');
    end
    if isempty(h)
        rethrow(ME);
    end
    cb = get(h(1),'Callback');
    if isa(cb,'function_handle')
        feval(cb,h(1),[]);
    elseif iscell(cb) && ~isempty(cb) && isa(cb{1},'function_handle')
        feval(cb{1},h(1),[],cb{2:end});
    else
        rethrow(ME);
    end
end
end

function [M,U] = localApplyHemisphereFlip(S,rowIdx,M,U)
mode = localGetCharField(S,'mapFlipMode','Off');
if strcmpi(mode,'Off'), return; end
side = 'Unknown';
try, if rowIdx <= numel(S.rowPacapSide), side = strtrimSafeLocal(S.rowPacapSide{rowIdx}); end; catch, end
ref = localGetCharField(S,'mapRefPacapSide','Left');
doFlip = false;
if strcmpi(mode,'Flip right-injected animals') && strcmpi(side,'Right'), doFlip = true; end
if strcmpi(mode,'Flip left-injected animals') && strcmpi(side,'Left'), doFlip = true; end
if strcmpi(mode,'Align to Reference Hemisphere')
    if strcmpi(ref,'Left') && strcmpi(side,'Right'), doFlip = true; end
    if strcmpi(ref,'Right') && strcmpi(side,'Left'), doFlip = true; end
end
if doFlip
    M = fliplr(M);
    if ndims(U) == 3 && size(U,3) == 3, U = U(:,end:-1:1,:); else, U = fliplr(U); end
end
end

function A = localSqueeze2D(A,G)
A = double(A);
if ndims(A) == 2, return; end
if ndims(A) == 3
    if size(A,3) == 1
        A = A(:,:,1);
    else
        z = localPickZ(G,size(A,3));
        A = A(:,:,z);
    end
else
    error('Cannot squeeze this array to 2D.');
end
end

function z = localPickZ(G,nZ)
z = round(nZ/2);
names = {'currentSlice','sliceIdx','zIndex','atlasSliceIndex'};
for i = 1:numel(names)
    try
        if isfield(G,names{i}) && ~isempty(G.(names{i}))
            zz = double(G.(names{i})(1));
            if isfinite(zz), z = round(zz); break; end
        end
    catch
    end
end
z = max(1,min(nZ,z));
end

function U = localAnyTo2D(U,targetSz,G)
if nargin < 3, G = struct(); end
U = double(U);
if ndims(U) == 3 && size(U,3) == 3 && size(U,1) == targetSz(1) && size(U,2) == targetSz(2)
    U = localResizeLike(U,targetSz); return;
end
if ndims(U) == 3
    z = localPickZ(G,size(U,3));
    U = U(:,:,z);
elseif ndims(U) > 3
    U = squeeze(U);
    if ndims(U) > 2, U = U(:,:,1); end
end
U = localResizeLike(U,targetSz);
end

function B = localResizeLike(A,sz)
if numel(sz) > 2, sz = sz(1:2); end
if ndims(A) == 3 && size(A,3) == 3
    B = zeros(sz(1),sz(2),3);
    for c = 1:3, B(:,:,c) = localResizeLike(A(:,:,c),sz); end
    return;
end
if isequal(size(A),sz), B = A; return; end
try
    B = imresize(A,sz,'bilinear');
catch
    [Y,X] = size(A);
    [xq,yq] = meshgrid(linspace(1,X,sz(2)),linspace(1,Y,sz(1)));
    B = interp2(double(A),xq,yq,'linear',0);
end
end

function RGB = localToRGB(U)
if ndims(U) == 3 && size(U,3) == 3
    RGB = double(U);
    mx = max(RGB(:));
    if isfinite(mx) && mx > 1, RGB = RGB ./ 255; end
    RGB = min(max(RGB,0),1);
else
    G = localToGray(U);
    RGB = repmat(G,[1 1 3]);
end
end

function G = localToGray(U)
U = double(U);
if ndims(U) == 3 && size(U,3) == 3
    U = 0.2989*U(:,:,1) + 0.5870*U(:,:,2) + 0.1140*U(:,:,3);
end
U(~isfinite(U)) = 0;
mn = min(U(:)); mx = max(U(:));
if isfinite(mx) && isfinite(mn) && mx > mn
    G = (U-mn)./(mx-mn);
else
    G = zeros(size(U));
end
end

function A = localFlipUD(A)
if ndims(A) == 3 && size(A,3) == 3, A = A(end:-1:1,:,:); else, A = flipud(A); end
end


function B = localSmooth2D(A,sigma)
if sigma <= 0, B = A; return; end
try, B = imgaussfilt(A,sigma); return; catch, end
r = max(1,ceil(3*sigma));
x = -r:r; g = exp(-(x.^2)/(2*sigma^2)); g = g./sum(g);
B = conv2(conv2(double(A),g,'same'),g','same');
end

function M = localNanMean3(X)
X = double(X);
if isempty(X), M = []; return; end
if ndims(X) < 3, M = X; return; end
n = sum(isfinite(X),3); X(~isfinite(X)) = 0;
M = sum(X,3)./max(1,n); M(n==0) = NaN;
end

function M = localNanMedian3(X)
X = double(X);
if isempty(X), M = []; return; end
if ndims(X) < 3, M = X; return; end
nY = size(X,1); nX = size(X,2); nN = size(X,3);
Y = reshape(X,[],nN); m = nan(size(Y,1),1);
for i = 1:size(Y,1)
    v = Y(i,:); v = v(isfinite(v));
    if ~isempty(v), m(i) = median(v); end
end
M = reshape(m,nY,nX);
end

function s = localGetCharField(S,name,fb)
s = fb;
try, if isstruct(S) && isfield(S,name) && ~isempty(S.(name)), s = strtrimSafeLocal(S.(name)); end; catch, end
end

function v = localGetNumField(S,name,fb)
v = fb;
try, if isstruct(S) && isfield(S,name) && ~isempty(S.(name)), v = double(S.(name)(1)); end; catch, end
if ~isfinite(v), v = fb; end
end

function v = localGetVecField(S,name,fb)
v = fb;
try
    if isstruct(S) && isfield(S,name) && numel(S.(name)) >= 2
        vv = double(S.(name)(1:2));
        if all(isfinite(vv)), v = vv(:)'; end
    end
catch
end
if numel(v) < 2 || v(2) <= v(1), v = fb; end
end

function v = localGetLogicalField(S,name,fb)
v = fb;
try, if isstruct(S) && isfield(S,name) && ~isempty(S.(name)), v = logical(S.(name)); end; catch, end
end

function s = strtrimSafeLocal(x)
try
    if isempty(x), s = ''; else, s = strtrim(char(x)); end
catch
    s = '';
end
end
function onExportGroupMapPPT_fromMain(varargin)
% Parser-safe Group Map PPT export helper.
hFig = [];
if nargin >= 1
    hFig = varargin{1};
end
if isempty(hFig) || ~ishghandle(hFig)
    hFig = gcf;
end
if isempty(hFig) || ~ishghandle(hFig)
    error('Invalid GroupAnalysis figure handle.');
end

S = guidata(hFig);
if isempty(S) || ~isstruct(S)
    error('Could not read GroupAnalysis GUI state.');
end
if ~isfield(S,'axMap1') || ~ishghandle(S.axMap1)
    error('Could not find current Group Map preview axis.');
end

startDir = pwd;
try
    if isfield(S,'outDir') && ~isempty(S.outDir) && exist(S.outDir,'dir') == 7
        startDir = S.outDir;
    elseif isfield(S,'opt') && isfield(S.opt,'startDir') && ~isempty(S.opt.startDir) && exist(S.opt.startDir,'dir') == 7
        startDir = S.opt.startDir;
    end
catch
end

defName = ['GroupMap_' datestr(now,'yyyymmdd_HHMMSS') '.pptx'];
[f,p] = uiputfile({'*.pptx','PowerPoint (*.pptx)'}, 'Save Group Map PPT', fullfile(startDir,defName));
if isequal(f,0)
    return;
end

outFile = fullfile(p,f);
[~,baseName] = fileparts(outFile);
pngFile = fullfile(p,[baseName '_preview.png']);

% Capture the existing preview axis directly. No visible new figure is created.
try
    fr = getframe(S.axMap1);
    imwrite(fr.cdata,pngFile);
catch MEcap
    try, GA_printErrorLocal(MEcap,'caught error in GroupAnalysis_Map.m'); catch, end
    error('Could not capture map preview axis: %s', MEcap.message);
end

if ~(ispc && exist('actxserver','file') == 2)
    error('PowerPoint export requires Windows with PowerPoint installed. PNG was saved here: %s', pngFile);
end

ppt = [];
pres = [];
try
    ppt = actxserver('PowerPoint.Application');
    ppt.Visible = 1;
    pres = ppt.Presentations.Add;

    sw = pres.PageSetup.SlideWidth;
    sh = pres.PageSetup.SlideHeight;

    slide = pres.Slides.Add(1,12);

    tb = slide.Shapes.AddTextbox(1,30,20,sw-60,35);
    tr = tb.TextFrame.TextRange;
    tr.Text = 'Group Map Preview';
    tr.Font.Size = 24;
    tr.Font.Bold = 1;

    slide.Shapes.AddPicture(pngFile,0,1,35,70,sw-70,sh-105);

    pres.SaveAs(outFile);
    pres.Close;
    ppt.Quit;

    fprintf('[saved] %s\n', outFile);
catch MEppt
    try, GA_printErrorLocal(MEppt,'caught error in GroupAnalysis_Map.m'); catch, end
    try, if ~isempty(pres), pres.Close; end, catch, end
    try, if ~isempty(ppt), ppt.Quit; end, catch, end
    error('PowerPoint export failed. PNG was saved here: %s. Reason: %s', pngFile, MEppt.message);
end
end


%%% GA_GROUPANALYSIS_SCM_PPT_PATCH_V3_START




















%%% GA_GROUPANALYSIS_SCM_PPT_PATCH_V3_END