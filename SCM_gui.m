function fig = SCM_gui(PSC, bg, TR, par, baseline, nVolsOrig, varargin)
% SCM_gui - fUSI Studio SCM viewer/controller
% MATLAB 2017b + 2023b compatible, ASCII-safe.
%
% Expected PSC dimensions:
%   [Y X T] or [Y X Z T]

%% ---------------- SAFETY ----------------
deConfUSIon_setup();
if nargin < 4 || isempty(par), par = struct(); end
if nargin < 5 || isempty(baseline), baseline = struct(); end
if nargin < 6 || isempty(nVolsOrig), nVolsOrig = []; end

% Static maps have spatial dimensions only. Do not fabricate a time axis or
% pass them through the temporal baseline/PSC calculation below.
if isfield(par,'staticVolume') && isequal(par.staticVolume,true)
    fig=SCM_static_gui(PSC,bg,par);
    return;
end

assert(isscalar(TR) && isfinite(TR) && TR > 0, 'TR must be positive scalar');

d = ndims(PSC);
assert(d == 3 || d == 4, 'PSC must be [Y X T] or [Y X Z T]');

if d == 3
    [nY, nX, nT] = size(PSC);
    nZ = 1;
else
    [nY, nX, nZ, nT] = size(PSC);
end

if ~(isnumeric(nVolsOrig) && isscalar(nVolsOrig) && isfinite(nVolsOrig))
    varargin  = [{nVolsOrig} varargin];
    nVolsOrig = nT; %#ok<NASGU>
end

%% ---------------- OPTIONALS ----------------
fileLabel = '';
if ~isempty(varargin)
    lastArg = varargin{end};
    if ischar(lastArg) || (exist('isstring','builtin') && isstring(lastArg) && isscalar(lastArg))
        fileLabel = char(lastArg);
        varargin  = varargin(1:end-1);
    end
end
if isempty(fileLabel), fileLabel = 'SCM'; end
if exist('isstring','builtin') && isstring(fileLabel), fileLabel = char(fileLabel); end
if ~ischar(fileLabel), fileLabel = 'SCM'; end

passedMask = [];
baselineRaw=[];
if ~isempty(varargin)&&isnumeric(varargin{1})&&~isempty(varargin{1}),baselineRaw=varargin{1};end
if isfield(par,'baselineRawIsPSC')&&par.baselineRawIsPSC,baselineRaw=[];end
passedMaskIsInclude = true;
if numel(varargin) >= 5
    passedMask = varargin{5};
end
if numel(varargin) >= 6
    v6 = varargin{6};
    isBoolScalar = (islogical(v6) && isscalar(v6)) || ...
        (isnumeric(v6) && isscalar(v6) && (v6 == 0 || v6 == 1));
    if ~isempty(passedMask) && isBoolScalar
        passedMaskIsInclude = logical(v6);
    end
end

%% ---------------- TIME / BASELINE MODE ----------------
tsec = (0:nT-1) * TR;
tmin = tsec / 60;
displayEndMin=max(tmin);
if isfield(par,'displayDurationSec') && isfiniteScalar(par.displayDurationSec) && par.displayDurationSec>=tsec(end)
    displayEndMin=par.displayDurationSec/60;
end

modeStr = 'sec';
if isstruct(baseline) && isfield(baseline,'mode') && ~isempty(baseline.mode)
    try
        modeStr = lower(char(baseline.mode));
    catch
        modeStr = 'sec';
    end
end
isVolMode = (strncmpi(modeStr, 'vol', 3) || strncmpi(modeStr, 'idx', 3));
localBaselineReset=baseline;
if isfield(baseline,'localBaseline'),localBaselineReset=baseline.localBaseline;end

baseStart0 = 30;
baseEnd0   = 240;
sigStart0  = 840;
sigEnd0    = 900;
if isstruct(baseline)
    if isfield(baseline,'start')    && isfiniteScalar(baseline.start),    baseStart0 = baseline.start; end
    if isfield(baseline,'end')      && isfiniteScalar(baseline.end),      baseEnd0   = baseline.end;   end
    if isfield(baseline,'sigStart') && isfiniteScalar(baseline.sigStart), sigStart0  = baseline.sigStart; end
    if isfield(baseline,'sigEnd')   && isfiniteScalar(baseline.sigEnd),   sigEnd0    = baseline.sigEnd;   end
end

% DECONF_STD_SCM_APPDATA_V10
try
    stdStep = [];
    if isappdata(0,'deconf_std_workflow_step')
        stdStep = getappdata(0,'deconf_std_workflow_step');
    end
    if isstruct(stdStep) && isfield(stdStep,'name') && strcmpi(strtrim(stdStep.name),'SCM GUI')
        % DECONF_STD_SCM_POPUP_BASELINE: keep baselineStart from SCM popup
        % DECONF_STD_SCM_POPUP_BASELINE: keep baselineEnd from SCM popup
        if ~isstruct(par), par = struct(); end
        par.standardizedWorkflow = true;
        par.standardCaxis = [-100 100];
        if isfield(stdStep,'cmin') && isfinite(double(stdStep.cmin)), par.standardCaxis(1) = double(stdStep.cmin); end
        if isfield(stdStep,'cmax') && isfinite(double(stdStep.cmax)), par.standardCaxis(2) = double(stdStep.cmax); end
        par.previewCaxis = par.standardCaxis;
        par.caxis = par.standardCaxis;
        par.standardSignMode = 3;
        par.standardAlphaModEnable = true;
        par.standardAlphaPct = 100;
        par.standardModMinAbs = -20;
        par.standardModMaxAbs = 20;
        if isfield(stdStep,'amin') && isfinite(double(stdStep.amin)), par.standardModMinAbs = double(stdStep.amin); end
        if isfield(stdStep,'amax') && isfinite(double(stdStep.amax)), par.standardModMaxAbs = double(stdStep.amax); end
    end
catch
end

% DECONF_STD_SCM_APPDATA_V11
try
    stdStep = [];
    if isappdata(0,'deconf_std_workflow_step')
        stdStep = getappdata(0,'deconf_std_workflow_step');
    end
    if isstruct(stdStep) && isfield(stdStep,'name') && strcmpi(strtrim(stdStep.name),'SCM GUI')
        % DECONF_STD_SCM_POPUP_BASELINE: keep baselineStart from SCM popup
        % DECONF_STD_SCM_POPUP_BASELINE: keep baselineEnd from SCM popup
        if ~exist('par','var') || ~isstruct(par), par = struct(); end
        par.standardizedWorkflow = true;
        par.standardCaxis = [-100 100];
        if isfield(stdStep,'cmin') && isfinite(double(stdStep.cmin)), par.standardCaxis(1) = double(stdStep.cmin); end
        if isfield(stdStep,'cmax') && isfinite(double(stdStep.cmax)), par.standardCaxis(2) = double(stdStep.cmax); end
        par.previewCaxis = par.standardCaxis;
        par.caxis = par.standardCaxis;
        par.standardSignMode = 3;
        par.standardAlphaModEnable = true;
        par.standardAlphaPct = 100;
        par.standardModMinAbs = -20;
        par.standardModMaxAbs = 20;
        if isfield(stdStep,'amin') && isfinite(double(stdStep.amin)), par.standardModMinAbs = double(stdStep.amin); end
        if isfield(stdStep,'amax') && isfinite(double(stdStep.amax)), par.standardModMaxAbs = double(stdStep.amax); end
    end
catch
end

%% ---------------- STATE ----------------
state = struct();
state.baseKey=[]; state.baseMean=[];
state.signalKey=[]; state.signalMean=[];
state.z   = max(1, round(nZ/2));
state.cax = [0 30];
state.alphaModOn = true;
state.modMin = 5;
state.modMax = 10;
state.signMode = 1;           % 1 positive, 2 negative magnitude, 3 signed
state.prevSignMode = 1;
% DECONF_STD_SCM_STATE_FORCE_V11
try
    if exist('par','var') && isstruct(par) && isfield(par,'standardizedWorkflow') && par.standardizedWorkflow
        if isfield(par,'standardCaxis') && numel(par.standardCaxis) == 2
            state.cax = double(par.standardCaxis(:)).';
        else
            state.cax = [-100 100];
        end
        state.alphaModOn = true;
        state.signMode = 3;
        state.prevSignMode = 3;
        if isfield(par,'standardModMinAbs') && isfinite(double(par.standardModMinAbs)), state.modMin = double(par.standardModMinAbs); else, state.modMin = -20; end
        if isfield(par,'standardModMaxAbs') && isfinite(double(par.standardModMaxAbs)), state.modMax = double(par.standardModMaxAbs); else, state.modMax = 20; end
    end
catch
end
% DECONF_STD_SCM_FORCE_ALPHA_V8
try
    if isfield(par,'standardizedWorkflow') && par.standardizedWorkflow
        if isfield(par,'standardCaxis') && numel(par.standardCaxis) == 2
            state.cax = double(par.standardCaxis(:)).';
        else
            state.cax = [-100 100];
        end
        state.alphaModOn = true;
        if isfield(par,'standardModMinAbs') && ~isempty(par.standardModMinAbs)
            state.modMin = double(par.standardModMinAbs);
        else
            state.modMin = -20;
        end
        if isfield(par,'standardModMaxAbs') && ~isempty(par.standardModMaxAbs)
            state.modMax = double(par.standardModMaxAbs);
        else
            state.modMax = 20;
        end
        state.signMode = 3;
        state.prevSignMode = 3;
% DECONF_STD_SCM_STATE_FORCE_V11
try
    if exist('par','var') && isstruct(par) && isfield(par,'standardizedWorkflow') && par.standardizedWorkflow
        if isfield(par,'standardCaxis') && numel(par.standardCaxis) == 2
            state.cax = double(par.standardCaxis(:)).';
        else
            state.cax = [-100 100];
        end
        state.alphaModOn = true;
        state.signMode = 3;
        state.prevSignMode = 3;
        if isfield(par,'standardModMinAbs') && isfinite(double(par.standardModMinAbs)), state.modMin = double(par.standardModMinAbs); else, state.modMin = -20; end
        if isfield(par,'standardModMaxAbs') && isfinite(double(par.standardModMaxAbs)), state.modMax = double(par.standardModMaxAbs); else, state.modMax = 20; end
    end
catch
end
    end
catch
end
% DECONF_OPTA_V2 : positive-only sign mode when the display range starts at >= 0
try
    if isfield(par,'standardizedWorkflow') && ~isempty(par.standardizedWorkflow) && par.standardizedWorkflow ...
            && isfield(par,'standardCaxis') && numel(par.standardCaxis) == 2 ...
            && isfinite(double(par.standardCaxis(1))) && double(par.standardCaxis(1)) >= 0
        par.standardSignMode = 1;
    end
catch
end
% DECONF_STD_SCM_DISPLAY_V71
try
    if isfield(par,'standardCaxis') && numel(par.standardCaxis) == 2, state.cax = double(par.standardCaxis(:)).'; end
    if isfield(par,'standardAlphaModEnable') && ~isempty(par.standardAlphaModEnable), state.alphaModOn = logical(par.standardAlphaModEnable); end
    if isfield(par,'standardModMinAbs') && ~isempty(par.standardModMinAbs), state.modMin = double(par.standardModMinAbs); end
    if isfield(par,'standardModMaxAbs') && ~isempty(par.standardModMaxAbs), state.modMax = double(par.standardModMaxAbs); end
    if isfield(par,'standardSignMode') && ~isempty(par.standardSignMode)
        state.signMode = max(1,min(3,round(double(par.standardSignMode))));
        state.prevSignMode = state.signMode;
    end
catch
end
% DECONF_STD_SCM_DISPLAY_V61
try
    if isfield(par,'standardCaxis') && numel(par.standardCaxis) == 2
        state.cax = double(par.standardCaxis(:)).';
    elseif isfield(par,'previewCaxis') && numel(par.previewCaxis) == 2
        state.cax = double(par.previewCaxis(:)).';
    end
    if isfield(par,'standardAlphaModEnable') && ~isempty(par.standardAlphaModEnable), state.alphaModOn = logical(par.standardAlphaModEnable); end
    if isfield(par,'standardModMinAbs') && ~isempty(par.standardModMinAbs), state.modMin = double(par.standardModMinAbs); end
    if isfield(par,'standardModMaxAbs') && ~isempty(par.standardModMaxAbs), state.modMax = double(par.standardModMaxAbs); end
    if isfield(par,'standardSignMode') && ~isempty(par.standardSignMode)
        state.signMode = max(1,min(3,round(double(par.standardSignMode))));
        state.prevSignMode = state.signMode;
    end
catch
end
% Standalone SCM opens with the requested unsmoothed positive display.
if ~isfield(par,'standardizedWorkflow') || ~par.standardizedWorkflow
    state.cax=[0 30]; state.signMode=1; state.prevSignMode=1;
    state.alphaModOn=true; state.modMin=5; state.modMax=10;
end
state.lastSignedMap = zeros(nY, nX);
state.hoverMaxPts   = 1200;
state.hoverStride   = max(1, ceil(nT / state.hoverMaxPts));
state.hoverIdx      = 1:state.hoverStride:nT;
state.tminHover     = tmin(state.hoverIdx);
state.timeWindowKey = [];
state.tcFixY = false;
state.tcFixX = false;
state.tcYLim = [0 100];
state.tcXLim = [0 displayEndMin];
state.referenceMode=1;
state.referenceTraceCache={};
state.referenceTraceError='';
state.tcSmoothOn=false;state.tcSmoothSeconds=60;state.pendingSlice=[];state.tcLiveAllScans=false;
state.scanSequence=[];
state.retainedUnderlay=[];
state.originalScanKey='';
if ~isempty(baselineRaw)
    state.scanSequence=fusiScanSequence('init',par,baselineRaw,TR,fileLabel);
    state.originalScanKey=state.scanSequence.originalKey;
    if numel(state.scanSequence.scans)>1,state.referenceMode=4;end
end
state.isAtlasWarped = false;
state.atlasTransformFile = '';
state.lastAtlasTransformFile = '';
state.atlas2DWarpDirection = 'ask';   % 'as_saved' or 'inverse'
% Step-motor multi-slice atlas warp metadata
state.isStepMotorAtlasWarped = false;
state.stepMotorAtlasFolder = '';
state.stepMotorAtlasTransformFiles = {};
state.stepMotorAtlasSourceIdx = [];
state.stepMotorAtlasAtlasIdx = [];
state.isColorUnderlay = false;
state.regionLabelUnderlay = [];
state.regionColorLUT = [];
state.regionInfo = struct();
state.atlasDisplay3D=[];
state.atlasInPlaneSpacingUm=[NaN NaN NaN];
state.atlasUnderlays = struct();
state.atlasUnderlayChoice = 'normal';
state.lastAtlasUnderlayBuildMessage = '';
state.lastTcExportLabel = 'Target';
state.singleScmExportBusy = false;
state.lastSingleScmExportStampSec = -inf;
state.seriesExportBusy = false;
state.lastSeriesExportStampSec = -inf;
state.seriesExportSliceRange = [1 nZ];

roi = struct();
roi.size = 5;
roi.sizeMode='pixels';roi.sizeUm=[1000 1000];roi.revision=0;roi.sizingById={};
roi.viewKey='native';roi.viewShape=[nY nX nZ];roi.viewMapping=[];roi.viewBanks={};roi.hiddenDefinitions={};
state.currentROIMapping=[];
state.physicalScale=true;state.sharpPixels=true;
roi.colors = lines(12);
roi.isFrozen = false;
roi.nextId = 1;
roi.exportedIds = [];
roi.lastAddStamp = 0;
roi.addBusy = false;
roi.lastHoverXY = [-inf -inf];
roi.pendingHover = [];
roi.hoverScheduled = false;
roi.savedTcBounds = zeros(0,6);
roi.hoverStats = [];
roi.sessionSetId = 0;
roi.lastExportLabel = 'Target';
roi.exportBusy = false;
roi.lastExportStampSec = -inf;

ROI_byZ = cell(1, nZ);
for zz = 1:nZ
    ROI_byZ{zz} = struct('id', {}, 'x1', {}, 'x2', {}, 'y1', {}, 'y2', {}, 'color', {});
end
roiHandles = gobjects(0);
roiPlotPSC = gobjects(0);
roiTextHandles = gobjects(0);

uState = struct();
uState.mode       = 3;
uState.brightness = -0.04;
uState.contrast   = 1.10;
uState.gamma      = 0.95;
uState.conectSize = 18;
uState.conectLev  = 35;
MAX_CONSIZE = 300;
MAX_CONLEV  = 500;

origPSC = PSC;
origBG  = bg;
origPassedMask = passedMask;
origPassedMaskIsInclude=passedMaskIsInclude;
startupAtlasNote = '';

% Auto-fix bad startup case: atlas/histology underlay with native PSC.
autoFixStartupAtlasUnderlayIfNeeded();
roi.viewShape=[nY nX nZ];if state.isAtlasWarped,roi.viewKey=['atlas|' state.atlasTransformFile];roi.viewMapping=state.currentROIMapping;end

%% ---------------- MASK INIT ----------------
if isempty(passedMask)
    passedMask = deriveMaskFromUnderlay(bg, nY, nX, nZ, nT);
    passedMaskIsInclude = true;
end
mask2D = getMaskForCurrentSlice();

%% ---------------- FIGURE ----------------
figW0 = 1880;
figH0 = 1160;
scr = get(0, 'ScreenSize');
x0 = max(20, round((scr(3)-figW0)/2));
y0 = max(40, round((scr(4)-figH0)/2));

fig = figure( ...
    'Name', 'SCM Viewer', ...
    'Color', [0.05 0.05 0.05], ...
    'Position', [x0 y0 figW0 figH0], ...
    'MenuBar', 'none', ...
    'ToolBar', 'none', ...
    'NumberTitle', 'off');

set(fig, 'DefaultUicontrolFontName', 'Arial');
set(fig, 'DefaultUicontrolFontSize', 15);
try
    set(fig, 'WindowState', 'maximized');
catch
    scr2 = get(0, 'ScreenSize');
    set(fig, 'Position', [1 1 max(1200, scr2(3)-20) max(850, scr2(4)-80)]);
end

%% ---------------- COLORS ----------------
bgPanel   = [0.10 0.10 0.11];
bgTabOn   = [0.24 0.24 0.25];
bgTabOff  = [0.14 0.14 0.15];
bgEdit    = [0.18 0.18 0.19];
bgEditDis = [0.22 0.22 0.23];
fgMain    = [0.97 0.97 0.98];
fgSub     = [0.82 0.90 1.00];
fgImp     = [1.00 0.60 0.60];
colBtnPrimary = [0.24 0.52 0.30];
colBtnExport  = [0.20 0.38 0.62];
colBtnNeutral = [0.28 0.28 0.30];
colBtnDanger  = [0.72 0.18 0.18];

%% ---------------- MAIN IMAGE AXIS ----------------
ax = axes('Parent', fig, 'Units', 'pixels');
axis(ax, 'image');
axis(ax, 'off');
% ===== 3D PROBE ASPECT FIX (nZ>1 only; 2D untouched) =====
if exist('nZ','var') && nZ > 1
    probeViewAspect = 1.0;   % DECONF_ASPECT_V1
    try
        if exist('par','var'), probeViewAspect = deConfUSIon_utils('deConfUSIon_view_aspect',par);
        else,                  probeViewAspect = deConfUSIon_utils('deConfUSIon_view_aspect'); end
    catch, probeViewAspect = 1.0; end
    if exist('par','var') && isstruct(par) && isfield(par,'probeViewAspect') ...
            && isscalar(par.probeViewAspect) && isfinite(par.probeViewAspect) && par.probeViewAspect > 0
        probeViewAspect = double(par.probeViewAspect);
    end
    set(ax, 'DataAspectRatio', [1 probeViewAspect 1]);
end
set(ax, 'YDir', 'reverse');
hold(ax, 'on');

bg2 = getBg2DForSlice(state.z);
hBG = image(ax, renderUnderlayRGB(bg2));
set(hBG,'XData',[1 nX],'YData',[1 nY]);
hOV = imagesc(ax, zeros(nY, nX));
set(hOV, 'AlphaData', zeros(nY, nX));

cmapNames = { ...
    'blackbdy_iso', ...
    'winter_brain_fsl', ...
    'signed_blackbdy_winter', ...
    'hot', 'parula', 'turbo', 'jet', 'gray', 'bone', 'copper', 'pink', ...
    'viridis', 'plasma', 'magma', 'inferno'};
% DECONF_STD_SCM_SIGNED_CMAP_INIT
try
    if exist('par','var') && isstruct(par) && isfield(par,'standardizedWorkflow') && par.standardizedWorkflow
        % DECONF_OPTA_V2 : a diverging map wastes half its range on a 0-50 % display
        if exist('state','var') && isstruct(state) && isfield(state,'signMode') && double(state.signMode) == 1
            setOverlayColormap('blackbdy_iso');
        else
            setOverlayColormap('signed_blackbdy_winter');
        end
    elseif exist('state','var') && isstruct(state) && isfield(state,'signMode') && double(state.signMode) == 3
        setOverlayColormap('signed_blackbdy_winter');
    else
        setOverlayColormap('blackbdy_iso');
    end
catch
    setOverlayColormap('blackbdy_iso');
end
caxis(ax, state.cax);

cb = colorbar(ax);
cb.Color = 'w';
cb.Label.String = 'Signal change (%)';
cb.Label.FontWeight = 'bold';
cb.FontSize = 12;
set(cb, 'Units', 'pixels');

hLiveRect = rectangle(ax, 'Position', [1 1 1 1], ...
    'EdgeColor', [0 1 0], 'LineWidth', 2, 'Visible', 'off');

txtSliceOverlay = text(ax, 0.985, 0.985, '', ...
    'Units', 'normalized', 'Color', [0.86 0.93 1.00], ...
    'FontSize', 12, 'FontWeight', 'bold', ...
    'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
    'Interpreter', 'none', 'Visible', 'off');
hold(ax, 'off');

txtTitle = uicontrol(fig, 'Style', 'text', 'String', makeFullTitle(fileLabel), ...
    'Units', 'pixels', 'ForegroundColor', [0.95 0.95 0.95], ...
    'BackgroundColor', [0.05 0.05 0.05], 'FontSize', 16, ...
    'FontWeight', 'bold', 'HorizontalAlignment', 'center');

%% ---------------- TIMECOURSE AXIS ----------------
axTC = axes('Parent', fig, 'Units', 'pixels', ...
    'Tag','SCMTimeCourseAxes', ...
    'Color', [0.05 0.05 0.05], 'XColor', 'w', 'YColor', 'w', ...
    'LineWidth', 1.2, 'Box', 'on', 'Layer', 'top');
hold(axTC, 'on');
grid(axTC, 'on');
axTC.FontSize = 12;
try
    axTC.GridAlpha = 0.18;
    axTC.MinorGridAlpha = 0.10;
    axTC.XMinorGrid = 'off';
    axTC.YMinorGrid = 'off';
catch
end
xlabel(axTC, 'Time (min)', 'Color', 'w', 'FontSize', 13, 'FontWeight', 'bold');
ylTC = ylabel(axTC, 'PSC (%)', 'Color', 'w', 'FontSize', 13, 'FontWeight', 'bold');
try
    set(ylTC, 'Units', 'normalized', 'Position', [-0.022 0.50 0], 'Clipping', 'off');
catch
end

hBasePatch = patch(axTC, [0 0 0 0], [0 0 0 0], [1 0.2 0.2], ...
    'FaceAlpha', 0.16, 'EdgeColor', 'none', 'Visible', 'off');
hSigPatch = patch(axTC, [0 0 0 0], [0 0 0 0], [1 0.6 0.15], ...
    'FaceAlpha', 0.16, 'EdgeColor', 'none', 'Visible', 'off');
hBaseTxt = text(axTC, 0, 0, '', 'Color', [1.00 0.35 0.35], ...
    'FontSize', 11, 'FontWeight', 'bold', 'Visible', 'off');
hSigTxt = text(axTC, 0, 0, '', 'Color', [1.00 0.75 0.35], ...
    'FontSize', 11, 'FontWeight', 'bold', 'Visible', 'off');
hLivePSC = plot(axTC, state.tminHover, nan(1, numel(state.tminHover)), ':', 'LineWidth', 3.0);
hLivePSC.Color = [1.00 0.60 0.10];
hLivePSC.Visible = 'off';
set(hBasePatch,'Tag','SCM_BaselineBand');
set(hLivePSC,'Tag','SCM_LiveROI');
hScanBoundary=plot(axTC,[0 0],[0 1],'--','Color',[.8 .85 .9],'Visible','off','Tag','SCM_ScanBoundary');
hReferenceScanTxt=text(axTC,0,0,'','Color',[1 .6 .6],'FontSize',10,'FontWeight','bold', ...
    'Interpreter','none','Clipping','on','VerticalAlignment','top', ...
    'BackgroundColor',[.05 .05 .05],'Margin',1,'Visible','off','Tag','SCM_ReferenceScanLabel');
hCurrentScanTxt=text(axTC,0,0,'','Color',[.6 .85 1],'FontSize',10,'FontWeight','bold', ...
    'Interpreter','none','Clipping','on','VerticalAlignment','top','HorizontalAlignment','center', ...
    'BackgroundColor',[.05 .05 .05],'Margin',1,'Visible','off','Tag','SCM_CurrentScanLabel');
hSequenceLabels=gobjects(0);hSequenceBoundaries=gobjects(0);
hSequenceBaselineBands=gobjects(0);
hRoiCoordTxt = text(axTC, 0.99, 1.12, '', ...
    'Units', 'normalized', 'HorizontalAlignment', 'right', ...
    'VerticalAlignment', 'top', 'Color', [0.92 0.92 0.92], ...
    'FontSize', 11, 'FontWeight', 'bold', 'Interpreter', 'none', 'Visible', 'off');

%% ---------------- HIDDEN SLICE SLIDER ----------------
slZ = uicontrol(fig, 'Style', 'slider', 'Units', 'pixels', ...
    'Min', 1, 'Max', max(1,nZ), 'Value', nZ-state.z+1, ...
    'SliderStep', [1/max(1,nZ-1) 5/max(1,nZ-1)], ...
    'Callback', @sliceChanged, 'Visible', 'off', 'Enable', 'off','Tag','FUSISliceSlider');
txtZ = uicontrol(fig, 'Style', 'text', 'Units', 'pixels', 'String', '', ...
    'ForegroundColor', [0.85 0.9 1], 'BackgroundColor', get(fig,'Color'), ...
    'HorizontalAlignment', 'left', 'FontWeight', 'bold', 'FontSize', 13, ...
    'Visible', 'off');

%% ---------------- RIGHT PANEL ----------------
controlsPanel = uipanel('Parent', fig, 'Title', 'SCM Controls', ...
    'Units', 'pixels', 'BackgroundColor', bgPanel, 'ForegroundColor', fgMain, ...
    'FontSize', 17, 'FontWeight', 'bold');

tabBar = uipanel('Parent', controlsPanel, 'Units', 'pixels', ...
    'BorderType', 'none', 'BackgroundColor', bgPanel);
btnTabOverlay = uicontrol(tabBar, 'Style', 'togglebutton', 'String', 'Overlay', ...
    'Units', 'pixels', 'Callback', @(~,~)switchTab('overlay'), ...
    'BackgroundColor', bgTabOn, 'ForegroundColor', fgMain, ...
    'FontName', 'Arial', 'FontSize', 14, 'FontWeight', 'bold', 'Value', 1);
btnTabUnderlay = uicontrol(tabBar, 'Style', 'togglebutton', 'String', 'Underlay', ...
    'Units', 'pixels', 'Callback', @(~,~)switchTab('underlay'), ...
    'BackgroundColor', bgTabOff, 'ForegroundColor', fgMain, ...
    'FontName', 'Arial', 'FontSize', 14, 'FontWeight', 'bold', 'Value', 0);

controlViewport=uipanel('Parent',controlsPanel,'Units','pixels','BorderType','none','BackgroundColor',bgPanel);
controlScroll=uicontrol('Parent',controlsPanel,'Style','slider','Units','pixels','Min',0,'Max',1,'Value',1,'Callback',@scrollControls);
pOverlay = uipanel('Parent', controlViewport, 'Units', 'pixels', ...
    'BorderType', 'none', 'BackgroundColor', bgPanel);
pUnderlay = uipanel('Parent', controlViewport, 'Units', 'pixels', ...
    'BorderType', 'none', 'BackgroundColor', bgPanel, 'Visible', 'off');
info1 = uicontrol(controlsPanel, 'Style', 'text', 'String', '', ...
    'Units', 'pixels', 'ForegroundColor', fgSub, 'BackgroundColor', bgPanel, ...
    'HorizontalAlignment', 'left', 'FontName', 'Arial', 'FontSize', 12, 'FontWeight', 'bold');

pad = 18; rowH = 36; gap = 9; sliderH = 20; groupGap = 15; wideBtnH = 38; smallBtnH = 34;

mkLbl = @(pp,s) uicontrol(pp, 'Style', 'text', 'String', s, 'Units', 'pixels', ...
    'ForegroundColor', fgMain, 'BackgroundColor', bgPanel, 'HorizontalAlignment', 'left', ...
    'FontName', 'Arial', 'FontSize', 13, 'FontWeight', 'bold');
mkLblImp = @(pp,s) uicontrol(pp, 'Style', 'text', 'String', s, 'Units', 'pixels', ...
    'ForegroundColor', fgImp, 'BackgroundColor', bgPanel, 'HorizontalAlignment', 'left', ...
    'FontName', 'Arial', 'FontSize', 13, 'FontWeight', 'bold');
mkValBox = @(pp,s) uicontrol(pp, 'Style', 'edit', 'String', s, 'Units', 'pixels', ...
    'BackgroundColor', bgEditDis, 'ForegroundColor', fgMain, 'HorizontalAlignment', 'center', ...
    'FontName', 'Arial', 'FontSize', 13, 'FontWeight', 'bold', 'Enable', 'inactive');
mkEdit = @(pp,s,cbk) uicontrol(pp, 'Style', 'edit', 'String', s, 'Units', 'pixels', ...
    'BackgroundColor', bgEdit, 'ForegroundColor', fgMain, 'FontName', 'Arial', ...
    'FontSize', 13, 'FontWeight', 'bold', 'Callback', cbk);
mkSlider = @(pp,minv,maxv,val,cbk) uicontrol(pp, 'Style', 'slider', 'Units', 'pixels', ...
    'Min', minv, 'Max', maxv, 'Value', val, 'Callback', cbk);
mkPopup = @(pp,choices,val,cbk) uicontrol(pp, 'Style', 'popupmenu', 'String', choices, ...
    'Value', val, 'Units', 'pixels', 'Callback', cbk, 'BackgroundColor', bgEdit, ...
    'ForegroundColor', fgMain, 'FontName', 'Arial', 'FontSize', 13, 'FontWeight', 'bold');
mkChk = @(pp,s,val,cbk) uicontrol(pp, 'Style', 'checkbox', 'String', s, 'Units', 'pixels', ...
    'Value', val, 'Callback', cbk, 'BackgroundColor', bgPanel, 'ForegroundColor', fgMain, ...
    'FontName', 'Arial', 'FontSize', 13, 'FontWeight', 'bold');
mkBtn = @(pp,lbl,cbk,bgcol,fs) uicontrol(pp, 'Style', 'pushbutton', 'String', lbl, ...
    'Units', 'pixels', 'Callback', cbk, 'BackgroundColor', bgcol, 'ForegroundColor', fgMain, ...
    'FontName', 'Arial', 'FontSize', fs, 'FontWeight', 'bold');

%% ---------------- Overlay controls ----------------
lblROIsz = mkPopup(pOverlay,{sprintf('ROI size [px; X %c Y]',215),sprintf('ROI size [%cm; X %c Y]',181,215)},1,@roiSizeModeChanged);
set(lblROIsz,'Tag','SCM_ROISizeMode','TooltipString','Pixels: legacy square. Micrometres: separate physical width X and height Y.');
slROI = mkSlider(pOverlay, 1, 220, roi.size, @(~,~)setROIsize());
set(slROI,'Tag','SCM_ROISizeSlider');
txtROIsz = mkEdit(pOverlay, sprintf('%d', roi.size), @onRoiSizeEdited);
set(txtROIsz,'Tag','SCM_ROISize');
set(txtROIsz, 'TooltipString', 'Type ROI size in pixels, then press Enter.');
ebRoiWidth=mkEdit(pOverlay,'1000',@roiPhysicalEdited);set(ebRoiWidth,'Tag','SCM_ROIWidthUm','Visible','off','TooltipString','X: horizontal width in micrometres');
ebRoiHeight=mkEdit(pOverlay,'1000',@roiPhysicalEdited);set(ebRoiHeight,'Tag','SCM_ROIHeightUm','Visible','off','TooltipString','Y: vertical height in micrometres');
txtROIPhysical=mkLbl(pOverlay,'');
set(txtROIPhysical,'Tag','SCM_ROIPhysicalSize','ForegroundColor',fgSub);

lblRoiXY = mkLbl(pOverlay, 'Add ROI by center (x y)');
ebRoiXY = mkEdit(pOverlay, '', @roiXYNoop);
set(ebRoiXY,'Tag','SCM_ROICenter');
set(ebRoiXY, 'TooltipString', 'Type x y, for example 120 80 or 120,80, then press Enter.');
set(ebRoiXY, 'KeyPressFcn', @roiXYKey);
btnRoiAddXY = mkBtn(pOverlay, 'ADD ROI', @addRoiFromXY, colBtnNeutral, 12);
set(btnRoiAddXY,'Tag','SCM_AddROI');

lblBase = mkLblImp(pOverlay, 'Baseline window (s)');
btnBaselineSource=mkBtn(pOverlay,'Baseline source...',@baselineSourceChanged,[0.25 0.40 0.65],13);
btnResetBaseline=mkBtn(pOverlay,'Reset local baseline',@resetLocalBaseline,[0.25 0.45 0.35],13);
set(btnResetBaseline,'Tag','SCM_ResetLocalBaseline','TooltipString','Restore this scan/animal''s baseline window from before the shared reference.');
set(btnBaselineSource,'Tag','SCM_BaselineSource','TooltipString',fusiBaselineReference('label',baseline));
setappdata(fig,'FUSIGetBaselineState',@getBaselineState);
btnScans=mkBtn(pOverlay,'Scans / order...',@manageScanSequence,[.20 .38 .62],12);
set(btnScans,'Tag','SCM_ScanSequence','TooltipString','Add up to ten raw scans, choose preprocessing, and change their time-course order.');
popOverlayScan=uicontrol(pOverlay,'Style','popupmenu','String',{'Overlay: current scan'}, ...
    'BackgroundColor',bgEdit,'ForegroundColor',fgMain,'FontSize',10,'Callback',@overlayScanChanged,'Tag','SCM_OverlayScan');
popOverlayScan.TooltipString='Select which scan supplies the SCM signal overlay. The sequence time courses retain all scans.';
setappdata(fig,'FUSIGetScanSequence',@getScanSequence);
setappdata(fig,'FUSIRemoveROI',@removeNearestRoi);
setappdata(fig,'AutomaticROISelections',scmAutomaticROISelections(fig));
setappdata(fig,'FUSIQueueHover',@queueHover);
setappdata(fig,'FUSIRenderHover',@renderPendingHover);
ebBase = mkEdit(pOverlay, sprintf('%g-%g', baseStart0, baseEnd0), @onWindowEdited);
set(ebBase,'Tag','SCM_BaselineWindow','TooltipString','Baseline in seconds. Press Enter or leave the field to refresh maps and all ROI curves.');
set(ebBase, 'ForegroundColor', [1.00 0.35 0.35]);
set(ebBase, 'KeyPressFcn', @windowKeyPress);
if fusiBaselineReference('isExternal',baseline),set(ebBase,'Enable','off');set(lblBase,'String','Source baseline (s)');end
lblSig = mkLblImp(pOverlay, 'Signal window (s)');
ebSig = mkEdit(pOverlay, sprintf('%g-%g', sigStart0, sigEnd0), @onWindowEdited);
set(ebSig, 'ForegroundColor', [1.00 0.35 0.35]);
set(ebSig, 'KeyPressFcn', @windowKeyPress);

lblAlpha = mkLbl(pOverlay, 'Overlay alpha (%)');
slAlpha = mkSlider(pOverlay, 0, 100, 100, @updateView);
txtAlpha = mkValBox(pOverlay, '100');
lblThr = mkLblImp(pOverlay, 'Threshold (abs %)');
ebThr = mkEdit(pOverlay, '0', @updateView);
set(ebThr, 'ForegroundColor', [1.00 0.35 0.35]);
lblCax = mkLblImp(pOverlay, 'Display range (min max)');
ebCax = mkEdit(pOverlay, sprintf('%g %g', state.cax(1), state.cax(2)), @updateView);
set(ebCax, 'ForegroundColor', [1.00 0.35 0.35]);
lblSignMode = mkLblImp(pOverlay, 'Signal sign display');
popSignMode = mkPopup(pOverlay, {'Positive only','Negative only','Positive + Negative'}, state.signMode, @updateView);
lblAlphaMod = mkLblImp(pOverlay, 'Alpha modulation');
cbAlphaMod = mkChk(pOverlay, 'Scale by |SCM|', double(state.alphaModOn), @alphaModToggled);
set(cbAlphaMod,'TooltipString','Scale overlay opacity by the absolute SCM percentage.');
lblModMin = mkLblImp(pOverlay, 'Mod Min (abs %)');
ebModMin = mkEdit(pOverlay, sprintf('%g', state.modMin), @updateView);
set(ebModMin, 'ForegroundColor', [1.00 0.35 0.35]);
lblModMax = mkLblImp(pOverlay, 'Mod Max (abs %)');
ebModMax = mkEdit(pOverlay, sprintf('%g', state.modMax), @updateView);
set(ebModMax, 'ForegroundColor', [1.00 0.35 0.35]);
lblMap = mkLbl(pOverlay, 'Colormap');
popMap = mkPopup(pOverlay, cmapNames, 1, @updateView);
% DECONF_STD_SCM_SIGNED_CMAP_POPUP
try
    if exist('par','var') && isstruct(par) && isfield(par,'standardizedWorkflow') && par.standardizedWorkflow
        set(popMap,'Value',findPopupIndexByName(popMap,'signed_blackbdy_winter'));
        setOverlayColormap('signed_blackbdy_winter');
    elseif exist('state','var') && isstruct(state) && isfield(state,'signMode') && double(state.signMode) == 3
        set(popMap,'Value',findPopupIndexByName(popMap,'signed_blackbdy_winter'));
        setOverlayColormap('signed_blackbdy_winter');
    end
catch
end
lblSigma = mkLblImp(pOverlay, 'SCM smoothing sigma');
ebSigma = mkEdit(pOverlay, '0', @computeSCM);
set(ebSigma,'Tag','SCM_SmoothingSigma');
btnScale=mkBtn(pOverlay,'Scale / units',@scaleSettings,colBtnNeutral,10);
set(btnScale,'Tag','SCM_ScaleSettings');
par.scmSizeYXZ=[nY nX nZ]; spatial=scmSpatialCalibration(par); rulerStep=500;
setappdata(fig,'SCMRulerVisible',true);
scaleListeners=[addlistener(ax,'XLim','PostSet',@spatialScaleAxisChanged); addlistener(ax,'YLim','PostSet',@spatialScaleAxisChanged)];
setappdata(fig,'SCMScaleListeners',scaleListeners);
set(ebSigma, 'ForegroundColor', [1.00 0.35 0.35]);
set(ebCax,'Tag','SCM_DisplayRange');
set(ebSig,'Tag','SCM_SignalWindow');
deConfUSIon_ui('liveedit',[ebBase ebSig ebThr ebCax ebModMin ebModMax ebSigma]);

btnRoiExport   = mkBtn(pOverlay, 'EXPORT ROIs (TXT)', @exportROIsCB, colBtnExport, 13);
btnScmExport   = mkBtn(pOverlay, 'EXPORT SCM IMAGE', @exportSCMImageCB, colBtnExport, 13);
btnTcPng       = mkBtn(pOverlay, 'EXPORT TIME COURSE PNG', @exportTimecoursePngCB, colBtnExport, 13);
btnScmSeries   = mkBtn(pOverlay, 'EXPORT PPT', @exportScmSeries1minCB, colBtnExport, 12);
set(btnScmSeries, 'TooltipString', 'Export SCM time windows to PowerPoint and images. Choose the first and last slice in the export dialog.');
btnGroupBundle = mkBtn(pOverlay, 'EXPORT SCM BUNDLE', @exportForGroupAnalysisCB, colBtnPrimary, 12);
btnOpenGroupBundle = mkBtn(pOverlay, 'OPEN GROUP BUNDLE', @openGroupBundleCB, colBtnPrimary, 12);
btnClearROIs = mkBtn(pOverlay, 'CLEAR ALL ROIs', @clearAllMarkedROIs, colBtnDanger, 12);
set(btnClearROIs,'Tag','SCM_ClearAllROIs');
btnUnfreeze    = mkBtn(pOverlay, 'HOVER ACTIVE', @unfreezeHover, [.10 .48 .20], 12);
set(btnUnfreeze,'Tag','SCM_HoverToggle');

%% ---------------- Underlay controls ----------------
lblUnderMode = mkLbl(pUnderlay, 'Underlay view');
popUnder = mkPopup(pUnderlay, { ...
    '1) Legacy (mat2gray)', ...
    '2) Robust clip (1..99%)', ...
    '3) VideoGUI robust (0.5..99.5%)', ...
    '4) Vessel enhance (conectSize/Lev)', ...
    '5) Saved appearance (0..1)'}, uState.mode, @underlayModeChanged);
lblAtlasChoice=mkLbl(pUnderlay,'Atlas underlay');
popAtlasChoice=mkPopup(pUnderlay,{'Load a saved atlas underlay first'},1,@atlasUnderlayChoiceCB);
set(popAtlasChoice,'Tag','AtlasUnderlayChoice','Enable','off');
cbRegionLabels=uicontrol(pUnderlay,'Style','checkbox','String','Region abbreviations','Value',0, ...
    'ForegroundColor','w','BackgroundColor',[.08 .08 .08],'FontSize',12, ...
    'Tag','AtlasRegionLabelsToggle','Callback',@updateRegionLabels);
btnRegionList=mkBtn(pUnderlay,'Region list',@showRegionList,[.20 .38 .62],12);
set(btnRegionList,'Tag','AtlasRegionListButton');
lblRegionScheme=mkLbl(pUnderlay,'Region colors');
popRegionScheme=mkPopup(pUnderlay,{'Atlas','Distinct','Pastel','Grayscale'},1,@regionAppearanceChanged);
set(popRegionScheme,'Tag','AtlasRegionColorScheme');
cbAtlasLines=uicontrol(pUnderlay,'Style','checkbox','String','Atlas region boundaries','Value',0, ...
    'ForegroundColor','w','BackgroundColor',[.08 .08 .08],'FontSize',12, ...
    'Tag','AtlasRegionLinesToggle','Callback',@updateRegionLabels);
cbShowRuler=mkChk(pUnderlay,sprintf('Show %cm ruler',181),1,@rulerVisibilityChanged);
set(cbShowRuler,'Tag','SCM_RulerToggle','FontSize',12, ...
    'TooltipString','Show or hide the physical scale bar and its micrometre label. Choose its length in Scale / units. ROI sizes and image scaling are unchanged.');
state.regionScheme='Atlas';
state.underlayRevision=0;state.renderedAtlasCache={};

state.atlasRegionSearch=[];
lblBri = mkLbl(pUnderlay, 'Underlay brightness');
cbPhysicalScale=mkChk(pUnderlay,'Physical X/Y scale',1,@imageAppearanceChanged);set(cbPhysicalScale,'Tag','SCM_PhysicalScale');
cbSharpPixels=mkChk(pUnderlay,'Sharp pixels',1,@imageAppearanceChanged);set(cbSharpPixels,'Tag','SCM_SharpPixels');
slBri = mkSlider(pUnderlay, -0.80, 0.80, uState.brightness, @underlaySliderChanged);
txtBri = mkValBox(pUnderlay, sprintf('%.2f', uState.brightness));
lblCon = mkLbl(pUnderlay, 'Underlay contrast');
slCon = mkSlider(pUnderlay, 0.10, 5.00, uState.contrast, @underlaySliderChanged);
txtCon = mkValBox(pUnderlay, sprintf('%.2f', uState.contrast));
lblGam = mkLbl(pUnderlay, 'Underlay gamma');
slGam = mkSlider(pUnderlay, 0.20, 4.00, uState.gamma, @underlaySliderChanged);
txtGam = mkValBox(pUnderlay, sprintf('%.2f', uState.gamma));
lblVsz = mkLbl(pUnderlay, 'Vessel conectSize (px)');
slVsz = mkSlider(pUnderlay, 0, MAX_CONSIZE, uState.conectSize, @underlaySliderChanged);
set(slVsz, 'SliderStep', [1/max(1,MAX_CONSIZE) 10/max(1,MAX_CONSIZE)]);
txtVsz = mkValBox(pUnderlay, sprintf('%d', uState.conectSize));
lblVlv = mkLbl(pUnderlay, sprintf('Vessel conectLev (0..%d)', MAX_CONLEV));
slVlv = mkSlider(pUnderlay, 0, MAX_CONLEV, uState.conectLev, @underlaySliderChanged);
set(slVlv, 'SliderStep', [1/max(1,MAX_CONLEV) 10/max(1,MAX_CONLEV)]);
txtVlv = mkValBox(pUnderlay, sprintf('%d', uState.conectLev));

btnLoadUnder = mkBtn(pUnderlay, 'LOAD NEW UNDERLAY', @loadNewUnderlayCB, colBtnNeutral, 12);
btnLoadAtlasFolder=mkBtn(pUnderlay,'LOAD ATLAS FOLDER',@loadAtlasUnderlayFolderCB,colBtnNeutral,12);
set(btnLoadAtlasFolder,'Tag','SCM_LoadAtlasFolder','TooltipString', ...
 'Choose one saved step-motor session folder. Loads all registered source planes and histology, vascular and region modes together.');
setappdata(fig,'FUSILoadUnderlay',@(file)loadNewUnderlayCB([],[],file));
setappdata(fig,'FUSILoadMask',@(file)loadMaskCB([],[],file));
setappdata(fig,'FUSIUnderlayData',@underlayData);
setappdata(fig,'FUSIWarpFunctionalToAtlas',@(varargin)warpFunctionalToAtlasCB([],[],varargin{:}));
setappdata(fig,'FUSISetSlice',@browseSlice);
btnWarpAtlas = mkBtn(pUnderlay, 'WARP FUNCTIONAL TO ATLAS', @warpFunctionalToAtlasCB, colBtnExport, 12);
btnResetWarp = mkBtn(pUnderlay, 'RESET TO NATIVE', @resetWarpToNativeCB, colBtnNeutral, 12);
btnSigUnder  = mkBtn(pUnderlay, 'SIGNAL UNDERLAY (sharp)', @signalUnderlayCB, colBtnNeutral, 12);

%% ---------------- Time-course axis controls ----------------
tcAxisBar = uipanel('Parent', fig, 'Units', 'pixels', 'BorderType', 'none', ...
    'BackgroundColor', [0.05 0.05 0.05]);
cbTcFixY = uicontrol(tcAxisBar, 'Style', 'checkbox', 'String', 'Fix Y', ...
    'Units', 'pixels', 'Value', double(state.tcFixY), 'Callback', @tcAxisModeChanged, ...
    'BackgroundColor', [0.05 0.05 0.05], 'ForegroundColor', [0.95 0.95 0.95], ...
    'FontName', 'Arial', 'FontSize', 11, 'FontWeight', 'bold');
ebTcYLim = uicontrol(tcAxisBar, 'Style', 'edit', 'String', sprintf('%g %g', state.tcYLim(1), state.tcYLim(2)), ...
    'Units', 'pixels', 'BackgroundColor', bgEdit, 'ForegroundColor', fgMain, ...
    'FontName', 'Arial', 'FontSize', 11, 'FontWeight', 'bold', 'Callback', @tcAxisModeChanged);
btnTcYFromCax = uicontrol(tcAxisBar, 'Style', 'pushbutton', 'String', 'Y = CAX', ...
    'Units', 'pixels', 'Callback', @tcYFromCax, 'BackgroundColor', colBtnNeutral, ...
    'ForegroundColor', fgMain, 'FontName', 'Arial', 'FontSize', 10, 'FontWeight', 'bold');
cbTcFixX = uicontrol(tcAxisBar, 'Style', 'checkbox', 'String', 'Fix X', ...
    'Units', 'pixels', 'Value', double(state.tcFixX), 'Callback', @tcAxisModeChanged, ...
    'BackgroundColor', [0.05 0.05 0.05], 'ForegroundColor', [0.95 0.95 0.95], ...
    'FontName', 'Arial', 'FontSize', 11, 'FontWeight', 'bold');
ebTcXLim = uicontrol(tcAxisBar, 'Style', 'edit', 'String', sprintf('%g %g', state.tcXLim(1), state.tcXLim(2)), ...
    'Units', 'pixels', 'BackgroundColor', bgEdit, 'ForegroundColor', fgMain, ...
    'FontName', 'Arial', 'FontSize', 11, 'FontWeight', 'bold', 'Callback', @tcAxisModeChanged);
btnTcXAll = uicontrol(tcAxisBar, 'Style', 'pushbutton', 'String', 'X = ALL', ...
    'Units', 'pixels', 'Callback', @tcXAll, 'BackgroundColor', colBtnNeutral, ...
    'ForegroundColor', fgMain, 'FontName', 'Arial', 'FontSize', 10, 'FontWeight', 'bold');
lblReferenceTrace=uicontrol(tcAxisBar,'Style','text','String','Time courses:', ...
    'Units','pixels','BackgroundColor',[.05 .05 .05],'ForegroundColor',fgMain,'HorizontalAlignment','left','FontSize',11);
popReferenceTrace=uicontrol(tcAxisBar,'Style','popupmenu', ...
    'String',{'Baseline window before current scan','Entire reference scan before current','Hide reference trace','All scans in sequence'}, ...
    'Units','pixels','Value',state.referenceMode,'Tag','SCM_ReferenceTraceMode','Callback',@referenceTraceModeChanged, ...
    'BackgroundColor',bgEdit,'ForegroundColor',fgMain,'FontSize',11, ...
    'TooltipString','Display only: reference samples are placed before current t=0 with a scan boundary. SCM windows and calculations stay on the current scan.');
cbTcSmooth=uicontrol(tcAxisBar,'Style','checkbox','String','Smooth curves','Value',0, ...
    'BackgroundColor',[.05 .05 .05],'ForegroundColor',fgMain,'FontSize',11,'Callback',@timecourseSmoothingChanged,'Tag','SCM_TemporalSmooth');
ebTcSmooth=uicontrol(tcAxisBar,'Style','edit','String','60','Enable','off','BackgroundColor',bgEdit, ...
    'ForegroundColor',fgMain,'FontSize',11,'Callback',@timecourseSmoothingChanged,'Tag','SCM_TemporalSmoothSeconds');
lblTcSmooth=mkLbl(tcAxisBar,'s window');
cbTcSmooth.TooltipString='Display-only centred sliding average. Each scan and finite segment is smoothed separately; SCM maps and ROI TXT measurements remain unchanged.';
cbNormalizeScans=uicontrol(tcAxisBar,'Style','checkbox','String','Normalize each scan','Value',0,'Enable','off', ...
    'BackgroundColor',[.05 .05 .05],'ForegroundColor',fgMain,'FontSize',11,'Callback',@normalizeScansChanged,'Tag','SCM_NormalizeScans');
cbNormalizeScans.TooltipString='PSC = 100*(power - this scan''s voxelwise baseline mean)/baseline mean. The defined window is used independently within every scan. No maximum scaling. Configure seconds in Scans / order...; uncheck to restore the shared reference.';
cbLiveAllScans=uicontrol(tcAxisBar,'Style','checkbox','String','Live all scans','Value',0,'Enable','off', ...
    'BackgroundColor',[.05 .05 .05],'ForegroundColor',fgMain,'FontSize',10,'Callback',@liveAllScansChanged,'Tag','SCM_LiveAllScans');
cbLiveAllScans.TooltipString='Off: hover previews the selected scan immediately; click or ADD ROI to compare all scans. On: update all scans when the pointer pauses; the first read can take longer.';

%% ---------------- Bottom buttons ----------------
btnCompute = uicontrol(fig, 'Style', 'pushbutton', 'String', 'Compute SCM', ...
    'Units', 'pixels', 'Callback', @computeSCM, 'BackgroundColor', colBtnPrimary, ...
    'ForegroundColor', 'w', 'FontSize', 15, 'FontWeight', 'bold');
btnAutomatic = uicontrol(fig,'Style','pushbutton','String','Automatic analysis', ...
    'Units','pixels','Callback',@automaticAnalysisCB,'BackgroundColor',[.23 .42 .30], ...
    'ForegroundColor','w','FontSize',12,'FontWeight','bold', ...
    'TooltipString','Run a saved fixed-ROI protocol (JSON); coordinates must match the current anatomy.');
btnMaskQuick = uicontrol(fig, 'Style', 'pushbutton', 'String', 'LOAD MASK', ...
    'Units', 'pixels', 'Callback', @loadMaskCB, 'BackgroundColor', colBtnNeutral, ...
    'ForegroundColor', 'w', 'FontSize', 15, 'FontWeight', 'bold');
btnOpenVid = uicontrol(fig, 'Style', 'pushbutton', 'String', 'Open Video GUI', ...
    'Units', 'pixels', 'Callback', @openVideo, 'BackgroundColor', colBtnNeutral, ...
    'ForegroundColor', 'w', 'FontSize', 15, 'FontWeight', 'bold');
setappdata(fig,'FUSIOpenVideo',@(cfg)openVideo([],[],cfg));
btnHelp = uicontrol(fig, 'Style', 'pushbutton', 'String', 'HELP', ...
    'Units', 'pixels', 'Callback', @showHelp, 'BackgroundColor', colBtnExport, ...
    'ForegroundColor', 'w', 'FontSize', 15, 'FontWeight', 'bold');
btnClose = uicontrol(fig, 'Style', 'pushbutton', 'String', 'CLOSE', ...
    'Units', 'pixels', 'Callback', @closeSCM, 'BackgroundColor', colBtnDanger, ...
    'ForegroundColor', 'w', 'FontSize', 15, 'FontWeight', 'bold');

%% ---------------- CALLBACKS / INIT ----------------
% Coalesce motion into the latest ROI. Do not queue a full trace redraw for
% every mouse event; the timer also renders the last position after stopping.
hoverTimer = timer('ExecutionMode','fixedSpacing','Period',0.10, ...
    'StartDelay',0.08,'BusyMode','drop','TimerFcn',@renderPendingHover, ...
    'Name','SCM live ROI');
sliceTimer=timer('ExecutionMode','singleShot','StartDelay',.08,'BusyMode','drop', ...
    'TimerFcn',@renderPendingSlice,'Name','SCM latest slice');
set(fig,'DeleteFcn',@disposeHoverTimer);
set(fig, 'WindowButtonMotionFcn', @mouseMove);
set(fig, 'WindowButtonDownFcn', @mouseClick);
set(fig, 'WindowScrollWheelFcn', @mouseScroll);
set(fig, 'ResizeFcn', @resizeSCM);

% DECONF_STD_SCM_CONTROL_SYNC_V10
try
    set(ebCax,'String',sprintf('%g %g',state.cax(1),state.cax(2)));
    set(cbAlphaMod,'Value',double(state.alphaModOn));
    set(ebModMin,'String',sprintf('%g',state.modMin));
    set(ebModMax,'String',sprintf('%g',state.modMax));
    set(popSignMode,'Value',state.signMode);
    set(slAlpha,'Value',100);
    set(txtAlpha,'String','100');
catch
end
% DECONF_STD_SCM_CONTROL_SYNC_V11
try
    if exist('par','var') && isstruct(par) && isfield(par,'standardizedWorkflow') && par.standardizedWorkflow
        set(ebCax,'String',sprintf('%g %g',state.cax(1),state.cax(2)));
        set(cbAlphaMod,'Value',double(state.alphaModOn));
        set(ebModMin,'String',sprintf('%g',state.modMin));
        set(ebModMax,'String',sprintf('%g',state.modMax));
        set(popSignMode,'Value',state.signMode);
        set(slAlpha,'Value',100);
        set(txtAlpha,'String','100');
    end
catch
end
if state.signMode==1
    set(popMap,'Value',findPopupIndexByName(popMap,'blackbdy_iso'));
    setOverlayColormap('blackbdy_iso');
end
alphaModToggled();
updateUnderlayControlsEnable();
updateInfoLines();
deConfUSIon_ui('present',fig);
layoutUI();
restoreAtlasDisplayContext();
refreshScanSequenceControls();
tcAxisModeChanged();
updateSliceIndicators();
computeSCM();
redrawROIsForCurrentSlice();
if exist('stdStep','var') && isstruct(stdStep) && isfield(stdStep,'awake3DAutoSearch') && isequal(stdStep.awake3DAutoSearch,true)
    automaticPeakROI(true);
end

if ~isempty(startupAtlasNote)
    try
        set(info1, 'String', shortenPath(startupAtlasNote, 110), 'TooltipString', startupAtlasNote);
    catch
    end
end

%% ==========================================================
% UI LAYOUT
%% ==========================================================
function switchTab(which)
    which = lower(char(which));
    if strcmp(which, 'overlay')
        set(pOverlay, 'Visible', 'on');
        set(pUnderlay, 'Visible', 'off');
        set(btnTabOverlay, 'Value', 1, 'BackgroundColor', bgTabOn, 'ForegroundColor', fgMain);
        set(btnTabUnderlay, 'Value', 0, 'BackgroundColor', bgTabOff, 'ForegroundColor', [0.88 0.88 0.90]);
    else
        set(pOverlay, 'Visible', 'off');
        set(pUnderlay, 'Visible', 'on');
        set(btnTabOverlay, 'Value', 0, 'BackgroundColor', bgTabOff, 'ForegroundColor', [0.88 0.88 0.90]);
        set(btnTabUnderlay, 'Value', 1, 'BackgroundColor', bgTabOn, 'ForegroundColor', fgMain);
    end
end

function layoutUI()
    if ~isgraphics(fig), return; end
    pos = get(fig, 'Position');
    W = pos(3); Hh = pos(4);

    leftM = 64; rightM = 24; topM = 38; botM = 46; gapX = 28; gapY = 24;
    panelW = min(760, max(520, round(0.36 * W)));
    btnH = max(28,min(40,round(Hh*0.033))); btnGap = 6;

    yClose = 12; yHelp = yClose;
    yOpen = yClose + btnH + btnGap;
    yMask = yOpen + btnH + btnGap;
    yComp = yMask + btnH + btnGap;
    buttonsTop = yComp + btnH;

    panelX = W - rightM - panelW;
    panelY = buttonsTop + 14;
    panelH = max(320, Hh - panelY - topM);
    set(controlsPanel, 'Position', [panelX panelY panelW panelH]);
    computeW=floor((panelW-10)/2);
    set(btnCompute, 'Position', [panelX yComp computeW btnH],'FontSize',12);
    set(btnAutomatic,'Position',[panelX+computeW+10 yComp panelW-computeW-10 btnH]);
    set(btnMaskQuick, 'Position', [panelX yMask panelW btnH]);
    set(btnOpenVid,   'Position', [panelX yOpen panelW btnH]);
    halfW = floor((panelW - 14) / 2);
    set(btnHelp,  'Position', [panelX yHelp halfW btnH]);
    set(btnClose, 'Position', [panelX + halfW + 14 yClose halfW btnH]);

    tcCtrlH = 60;
    tcCtrlGap = 40; % Reserve room for ticks and the stitched-time axis label.
    tcHfull = min(300, max(280, round(0.28 * Hh)));
    tcPlotH = max(120, tcHfull - tcCtrlH - tcCtrlGap);
    cbW = 18; cbGap = 10; imgRightGap = 26;
    axH = max(340, Hh - botM - tcHfull - gapY - topM);
    axX = leftM;
    leftW = max(360, panelX - axX - gapX - cbW - cbGap - imgRightGap);
    axY = botM + tcHfull + gapY;
    set(ax, 'Position', [axX axY leftW axH]);
    cbH = round(0.84 * axH); cbY = axY + round(0.08 * axH); cbX = axX + leftW + cbGap;
    try, set(cb, 'Position', [cbX cbY cbW cbH]); catch, end
    tcLeftPad = 8;
    narrowTC=leftW-tcLeftPad<760;
    if narrowTC,tcCtrlH=116;tcPlotH=max(120,tcHfull-tcCtrlH-tcCtrlGap);end
    set(axTC, 'Position', [axX + tcLeftPad, botM + tcCtrlH + tcCtrlGap, leftW - tcLeftPad, tcPlotH]);
    set(tcAxisBar, 'Position', [axX + tcLeftPad, botM - 6, leftW - tcLeftPad, tcCtrlH]);

    hh=24; y=32+56*narrowTC; x=4; wChk=62; wEdit=95; wBtn=72; g=8;
    set(cbTcFixY,'Position',[x y wChk hh]); x=x+wChk+g;
    set(ebTcYLim,'Position',[x y wEdit hh]); x=x+wEdit+g;
    set(btnTcYFromCax,'Position',[x y wBtn hh]);
    y=3+56*narrowTC; x=4;
    set(cbTcFixX,'Position',[x y wChk hh]); x=x+wChk+g;
    set(ebTcXLim,'Position',[x y wEdit hh]); x=x+wEdit+g;
    set(btnTcXAll,'Position',[x y wBtn hh]);
    barWidth=leftW-tcLeftPad;xRef=320;yRef=32;if narrowTC,xRef=4;yRef=31;end
    set(lblReferenceTrace,'Position',[xRef yRef+2 125 22]);
    popupWidth=max(80,min(380,barWidth-xRef-284));
    set(popReferenceTrace,'Position',[xRef+130 yRef popupWidth hh]);
    liveX=xRef+140+popupWidth;set(cbLiveAllScans,'Position',[liveX yRef max(80,min(140,barWidth-liveX-4)) hh]);
    set(cbTcSmooth,'Position',[xRef 3 145 hh]);set(ebTcSmooth,'Position',[xRef+150 3 80 hh]);set(lblTcSmooth,'Position',[xRef+237 3 75 hh]);
    set(cbTcSmooth,'String','Smooth curves');set(lblTcSmooth,'String','s window');
    set(cbNormalizeScans,'Position',[xRef+320 3 220 hh],'String','Normalize each scan');
    if narrowTC
        set(cbTcSmooth,'Position',[4 3 100 hh],'String','Smooth');set(ebTcSmooth,'Position',[109 3 60 hh]);set(lblTcSmooth,'Position',[175 3 25 hh],'String','s');
        set(cbNormalizeScans,'Position',[210 3 max(120,barWidth-214) hh],'String','Normalize scans');
    end

    set(slZ, 'Visible', 'off', 'Enable', 'off');
    set(txtZ, 'Visible', 'off');
    set(txtTitle, 'Position', [axX axY + axH + 10 leftW + cbGap + cbW 28], ...
        'String', makeFullTitle(fileLabel), 'Visible', 'on');
    try
        set(ylTC, 'Units', 'normalized', 'Position', [-0.022 0.50 0], 'Clipping', 'off');
    catch
    end

    tabH = 32; statusH = 34; titlePad = 18;
    set(tabBar, 'Position', [12 panelH - tabH - titlePad panelW - 24 tabH]);
    btnW = floor((panelW - 24 - 10) / 2);
    set(btnTabOverlay, 'Position', [0 0 btnW tabH]);
    set(btnTabUnderlay, 'Position', [btnW + 10 0 btnW tabH]);
    contentX = 12; contentY = 14 + statusH;
    contentW = panelW - 24;
    contentH = panelH - tabH - titlePad - statusH - 20;
    % Keep the two-tab control panel in the visible viewport. Scaling child
    % positions on every resize accumulated rounding errors and made edits
    % appear increasingly slow or drift out of alignment.
    canvasH=contentH; viewW=contentW;
    set(controlViewport,'Position',[contentX contentY viewW contentH]);
    set(controlScroll,'Visible','off','Enable','off');
    set(pOverlay,'Position',[0 0 viewW contentH]);
    set(pUnderlay,'Position',[0 0 viewW contentH]);
    set(info1, 'Position', [contentX 8 contentW statusH]);
    layoutOverlay(viewW,canvasH); layoutUnder(viewW,canvasH);

end

function scrollControls(~,~)
    vp=get(controlViewport,'Position'); p=get(pOverlay,'Position');
    p(2)=(vp(4)-p(4))*get(controlScroll,'Value');
    set(pOverlay,'Position',p); set(pUnderlay,'Position',p);
end
function spatialScaleAxisChanged(~,~),if isgraphics(ax),updateSpatialScale();end,end
function resizeSCM(~,~),layoutUI();end
function closeSCM(~,~),if isgraphics(fig),delete(fig);end,end

function layoutOverlay(w, h)
    compact = (h < 700);
    if compact
        rowHLoc = 28; gapLoc = 4; groupGapLoc = 7; sliderHLoc = 16; wideBtnHLoc = 30; smallBtnHLoc = 28;
    else
        rowHLoc = rowH; gapLoc = gap; groupGapLoc = groupGap; sliderHLoc = sliderH; wideBtnHLoc = wideBtnH; smallBtnHLoc = smallBtnH;
    end
    xLabel = pad; wLabel = min(220,round(w*0.42)); wVal = 95; xVal = w - pad - wVal;
    xCtrl = xLabel + wLabel + 16; wCtrl = max(90, xVal - xCtrl - 12);
    y = h - rowHLoc;

    set(lblROIsz, 'Position', [xLabel y wLabel rowHLoc]);
    set(slROI, 'Position', [xCtrl y + round((rowHLoc-sliderHLoc)/2) wCtrl sliderHLoc]);
    set(txtROIsz, 'Position', [xVal y wVal rowHLoc]);
    roiAvailable=w-xCtrl-pad;roiHalf=(roiAvailable-10)/2;
    set(ebRoiWidth,'Position',[xCtrl y roiHalf rowHLoc]);set(ebRoiHeight,'Position',[xCtrl+roiHalf+10 y roiHalf rowHLoc]);
    set(txtROIPhysical,'Position',[xLabel y-22 w-2*pad 22]);
    y = y - (rowHLoc + gapLoc + 22);

    set(lblRoiXY, 'Position', [xLabel y wLabel rowHLoc]);
    set(ebRoiXY, 'Position', [xCtrl y wCtrl rowHLoc]);
    set(btnRoiAddXY, 'Position', [xVal y wVal rowHLoc]);
    y = y - (rowHLoc + groupGapLoc);

    baselineWidth=(w-2*pad-10)/2;
    set(btnBaselineSource,'Position',[xLabel y baselineWidth rowHLoc]);
    set(btnResetBaseline,'Position',[xLabel+baselineWidth+10 y baselineWidth rowHLoc]);y=y-(rowHLoc+gapLoc);
    set(btnScans,'Position',[xLabel y baselineWidth rowHLoc]);
    set(popOverlayScan,'Position',[xLabel+baselineWidth+10 y baselineWidth rowHLoc]);y=y-(rowHLoc+gapLoc);
    setRowEditOverlay(lblBase, ebBase); setRowEditOverlay(lblSig, ebSig);
    y = y + (gapLoc - groupGapLoc);
    setRowSliderOverlay(lblAlpha, slAlpha, txtAlpha);
    setRowEditOverlay(lblThr, ebThr);
    setRowEditOverlay(lblCax, ebCax);
    set(lblSignMode, 'Position', [xLabel y wLabel rowHLoc]);
    set(popSignMode, 'Position', [xCtrl y (w-xCtrl-pad) rowHLoc]);
    y = y - (rowHLoc + gapLoc);
    set(lblAlphaMod, 'Position', [xLabel y wLabel rowHLoc]);
    set(cbAlphaMod, 'Position', [xCtrl y (w-xCtrl-pad) rowHLoc]);
    y = y - (rowHLoc + gapLoc);
    setRowEditOverlay(lblModMin, ebModMin);
    setRowEditOverlay(lblModMax, ebModMax);
    set(lblMap, 'Position', [xLabel y wLabel rowHLoc]);
    set(popMap, 'Position', [xCtrl y (w-xCtrl-pad) rowHLoc]);
    y = y - (rowHLoc + groupGapLoc);
    set(btnScale,'Position',[xCtrl y max(70,xVal-xCtrl-8) rowHLoc]);
    setRowEditOverlay(lblSigma, ebSigma);
    y = y - 2;
btnW2 = floor((w - 2*pad - 10) / 2);

set(btnRoiExport, 'Position', [xLabel y btnW2 wideBtnHLoc]);
set(btnScmExport, 'Position', [xLabel + btnW2 + 10 y btnW2 wideBtnHLoc]);
y = y - (wideBtnHLoc + gapLoc);

set(btnTcPng, 'Position', [xLabel y btnW2 wideBtnHLoc]);
set(btnScmSeries, 'Position', [xLabel + btnW2 + 10 y btnW2 wideBtnHLoc]);
y = y - (wideBtnHLoc + gapLoc);

set(btnGroupBundle, 'Position', [xLabel y btnW2 wideBtnHLoc]);
set(btnOpenGroupBundle, 'Position', [xLabel + btnW2 + 10 y btnW2 wideBtnHLoc]);
y = y - (wideBtnHLoc + groupGapLoc);

set(btnUnfreeze, 'Position', [xLabel y btnW2 smallBtnHLoc]);
set(btnClearROIs,'Position',[xLabel+btnW2+10 y btnW2 smallBtnHLoc]);

    function setRowEditOverlay(lbl, ed)
        set(lbl, 'Position', [xLabel y wLabel rowHLoc]);
        set(ed, 'Position', [xVal y wVal rowHLoc]);
        y = y - (rowHLoc + gapLoc);
    end
    function setRowSliderOverlay(lbl, sl, valbox)
        set(lbl, 'Position', [xLabel y wLabel rowHLoc]);
        set(sl, 'Position', [xCtrl y + round((rowHLoc-sliderHLoc)/2) wCtrl sliderHLoc]);
        set(valbox, 'Position', [xVal y wVal rowHLoc]);
        y = y - (rowHLoc + gapLoc);
    end
end

function layoutUnder(w, h)
    compact = (h < 700);
    if compact
        rowHLoc = 30; gapLoc = 5; groupGapLoc = 8; sliderHLoc = 16; wideBtnHLoc = 32;
    else
        rowHLoc = rowH; gapLoc = gap; groupGapLoc = groupGap; sliderHLoc = sliderH; wideBtnHLoc = wideBtnH;
    end
    xLabel = pad; wLabel = min(220,round(w*0.42)); wVal = 95; xVal = w - pad - wVal;
    xCtrl = xLabel + wLabel + 16; wCtrl = max(90, xVal - xCtrl - 12);
    y = h - rowHLoc;
    set(lblUnderMode, 'Position', [xLabel y wLabel rowHLoc]);
    set(popUnder, 'Position', [xCtrl y (w-xCtrl-pad) rowHLoc]);
    y=y-(rowHLoc+gapLoc);
    set(lblAtlasChoice,'Position',[xLabel y wLabel rowHLoc]);
    set(popAtlasChoice,'Position',[xCtrl y (w-xCtrl-pad) rowHLoc]);
    y=y-(rowHLoc+gapLoc);
    set(cbRegionLabels,'Position',[xLabel y max(160,round(w*.52)) rowHLoc]);
    set(btnRegionList,'Position',[xVal y wVal rowHLoc]);
    y=y-(rowHLoc+gapLoc);
    set(lblRegionScheme,'Position',[xLabel y wLabel rowHLoc]);
    set(popRegionScheme,'Position',[xCtrl y (w-xCtrl-pad) rowHLoc]);
    y=y-(rowHLoc+gapLoc);
    rulerX=round(w*.58);
    set(cbAtlasLines,'Position',[xLabel y rulerX-xLabel-10 rowHLoc]);
    set(findall(fig,'Tag','SCM_RulerToggle'),'Position',[rulerX y w-rulerX-pad rowHLoc]);
    y=y-(rowHLoc+gapLoc);
    set(cbPhysicalScale,'Position',[xLabel y round(w*.55) rowHLoc]);set(cbSharpPixels,'Position',[round(w*.58) y round(w*.38) rowHLoc]);
    y = y - (rowHLoc + groupGapLoc);
    setRowSliderUnder(lblBri, slBri, txtBri);
    setRowSliderUnder(lblCon, slCon, txtCon);
    setRowSliderUnder(lblGam, slGam, txtGam);
    setRowSliderUnder(lblVsz, slVsz, txtVsz);
    setRowSliderUnder(lblVlv, slVlv, txtVlv);
    y = y - 2;
    loadWidth=round((w-2*pad-8)/2);
    set(btnLoadUnder, 'Position', [xLabel y loadWidth wideBtnHLoc]);
    set(findall(fig,'Tag','SCM_LoadAtlasFolder'),'Position',[xLabel+loadWidth+8 y loadWidth wideBtnHLoc]);
    y = y - (wideBtnHLoc + gapLoc);
    set(btnWarpAtlas, 'Position', [xLabel y (w-2*pad) wideBtnHLoc]);
    y = y - (wideBtnHLoc + gapLoc);
    set(btnResetWarp, 'Position', [xLabel y (w-2*pad) wideBtnHLoc]);
    y = y - (wideBtnHLoc + gapLoc);
    set(btnSigUnder, 'Position', [xLabel y (w-2*pad) wideBtnHLoc]);

    function setRowSliderUnder(lbl, sl, valbox)
        set(lbl, 'Position', [xLabel y wLabel rowHLoc]);
        set(sl, 'Position', [xCtrl y + round((rowHLoc-sliderHLoc)/2) wCtrl sliderHLoc]);
        set(valbox, 'Position', [xVal y wVal rowHLoc]);
        y = y - (rowHLoc + gapLoc);
    end
end

%% ==========================================================
% CALLBACKS
%% ==========================================================
function s=getBaselineState()
    s=struct('baseline',baseline,'PSC',PSC,'map',state.lastSignedMap);
end

function refreshScanSequenceControls()
    q=state.scanSequence;set(btnScans,'Enable','on');set(popOverlayScan,'Enable','off');
    set(cbNormalizeScans,'Enable','off','Value',0);
    if isempty(q),set(btnScans,'Enable','off');return;end
    labels=fusiScanSequence('labels',q);
    for si=1:numel(labels)
        original='';if strcmp(q.scans{si}.key,state.originalScanKey),original=' [originally loaded]';end
        labels{si}=sprintf('Overlay %d: %s%s',si,labels{si},original);
    end
    set(popOverlayScan,'String',labels,'Value',q.active,'TooltipString',labels{q.active});
    if numel(labels)>1,set(popOverlayScan,'Enable','on');end
    if ~isempty(baselineRaw),set(cbNormalizeScans,'Enable','on','Value',double(strcmp(q.normMode,'local')));end
    set(cbLiveAllScans,'Enable','off');if numel(labels)>1||fusiBaselineReference('isExternal',baseline),set(cbLiveAllScans,'Enable','on');end
end

function q=getScanSequence()
    q=state.scanSequence;
end

function manageScanSequence(~,~)
    try
        if isappdata(fig,'FUSIScanSequenceError'),rmappdata(fig,'FUSIScanSequenceError');end
        assert(~isempty(baselineRaw),'deConfUSIon:ScanSequencePower','Open an absolute power dataset from Studio to compare scans.');
        if isempty(state.scanSequence),state.scanSequence=fusiScanSequence('init',par,baselineRaw,TR,fileLabel);end
        q=state.scanSequence;
        q.atlasRegistered=state.isAtlasWarped;
        if isappdata(fig,'FUSIScanSequenceRequest'),q=getappdata(fig,'FUSIScanSequenceRequest');rmappdata(fig,'FUSIScanSequenceRequest');
        else,q=fusiScanSequenceDialog(q,baseline,fusiBaselineRawStart(par,getDatasetRootForSelectors()));end
        if isempty(q),return;end
        q.originalKey=state.originalScanKey;
        assert(any(cellfun(@(d)strcmp(d.key,q.originalKey),q.scans)),'deConfUSIon:OriginalScan','Keep the originally loaded dataset in the scan list; untick it to hide its curve.');
        assert(numel(q.scans)<=fusiScanSequence('maxScans')&&q.active>=1&&q.active<=numel(q.scans),'deConfUSIon:ScanSequenceCount','Choose one to ten scans.');
        b=baseline;[b.sigStart,b.sigEnd]=parseRangeSafe(getStr(ebSig),sigStart0,sigEnd0);
        if ~fusiBaselineReference('isExternal',b)
            [b.start,b.end]=parseRangeSafe(getStr(ebBase),baseStart0,baseEnd0);
        end
        progress=fusiBaselineProgress('open','Preparing scan normalization');
        pg=onCleanup(@()fusiBaselineProgress('close',progress)); %#ok<NASGU>
        [q,b]=fusiScanSequence('prepare',q,b,baselineRaw,TR,par,@(fraction,message)fusiBaselineProgress('update',progress,fraction,message));
        setappdata(fig,'FUSIScanSequenceApplying',true);syncGuard=onCleanup(@()removeSequenceApplyingFlag()); %#ok<NASGU>
        setappdata(fig,'FUSIBaselineRequest',b);baselineSourceChanged();
        if isappdata(fig,'FUSIBaselineError'),error('deConfUSIon:ScanSequenceBaseline','%s',getappdata(fig,'FUSIBaselineError'));end
        state.scanSequence=q;par.scanSequence=q;state.referenceMode=4;if numel(q.scans)==1,state.referenceMode=3;end
        set(popReferenceTrace,'Value',state.referenceMode);
        state.referenceTraceCache={};state.timeWindowKey=[];refreshScanSequenceControls();computeSCM();redrawROIsForCurrentSlice();
        message='Shared baseline retained across all scans.';
        if strcmp(q.normMode,'local'),message='Each scan uses its own baseline window.';end
        set(info1,'String',[message ' Overlay selector changes the signal scan.']);
    catch ME
        if isappdata(fig,'FUSIScanSequenceRequest'),rmappdata(fig,'FUSIScanSequenceRequest');end
        setappdata(fig,'FUSIScanSequenceError',ME.message);set(info1,'String',['Scan sequence: ' ME.message]);
    end
end
function removeSequenceApplyingFlag()
    if isgraphics(fig)&&isappdata(fig,'FUSIScanSequenceApplying'),rmappdata(fig,'FUSIScanSequenceApplying');end
end
function normalizeScansChanged(~,~)
    q=state.scanSequence;if isempty(q)||isempty(baselineRaw),return;end
    q=fusiScanSequence('reference',q,baseline);
    q.normMode='shared';if get(cbNormalizeScans,'Value'),q.normMode='local';end
    setappdata(fig,'FUSIScanSequenceRequest',q);manageScanSequence();refreshScanSequenceControls();
end

function overlayScanChanged(~,~)
    q=state.scanSequence;index=get(popOverlayScan,'Value');if isempty(q)||index==q.active,return;end
    progress=fusiBaselineProgress('open','Loading selected overlay scan');
    guard=onCleanup(@()fusiBaselineProgress('close',progress)); %#ok<NASGU>
    try
        if isappdata(fig,'FUSIScanSequenceError'),rmappdata(fig,'FUSIScanSequenceError');end
        definitions=roiDefinitionsForCurrentView();displayDefinitions=definitions;
        source=q.scans{q.active};target=q.scans{index};mode='keep';if isfield(q,'underlayMode'),mode=q.underlayMode;end
        if state.isAtlasWarped&&fusiScanSequence('shareAtlas',q),mode='keep';end
        maskFile='';
        if strcmp(mode,'mask')
            if isappdata(fig,'FUSIOverlayUnderlayRequest'),maskFile=getappdata(fig,'FUSIOverlayUnderlayRequest');rmappdata(fig,'FUSIOverlayUnderlayRequest');
            else
                paths=fusiResolveAnalysisFolder(target.rawFile);[name,folder]=uigetfile('*.mat','Choose this scan''s Mask Editor underlay',paths.datasetFolder);
                if isequal(name,0),refreshScanSequenceControls();return;end;maskFile=fullfile(folder,name);
            end
        end
        retain=strcmp(mode,'keep');registered=retain&&state.isAtlasWarped;appearance=uState;
        anchor=state.retainedUnderlay;
        if retain&&(isempty(anchor)||anchor.revision~=state.underlayRevision)
            anchor=struct('source',source,'nativeBG',origBG,'revision',state.underlayRevision);
        end
        displayPSC=[];newMapping=[];nativeBG=procOrRetainedBG(anchor,target,retain);
        if registered,newMapping=scmRebaseROIMapping(state.currentROIMapping,source,target);end
        if state.isAtlasWarped
            native=[size(origPSC,1) size(origPSC,2) 1];if ndims(origPSC)==4,native(3)=size(origPSC,3);end
            definitions=scmROI('map',definitions,[nY nX nZ],native,roi.viewMapping,true,[NaN NaN NaN]);
        end
        mapped={};
        for di=1:numel(definitions)
            c=fusiScanSequence('mapROI',definitions{di},source,target);if ~isempty(c),mapped{end+1}=c;end %#ok<AGROW>
        end
        b=baseline;[b.sigStart,b.sigEnd]=parseRangeSafe(getStr(ebSig),sigStart0,sigEnd0);
        [q,b]=fusiScanSequence('prepare',q,b,baselineRaw,TR,par,@(fraction,message)fusiBaselineProgress('update',progress,fraction,message));
        [proc,b,newPar,I]=fusiScanSequence('load',q,index,b,par, ...
            @(fraction,message)fusiBaselineProgress('update',progress,fraction,message));
        if registered
            fusiBaselineProgress('update',progress,.9,'Placing the new signal on the retained atlas grid...');
            displayPSC=scmWarpMappedSeries(proc.PSC,newMapping,[nY nX nZ]);mapped=displayDefinitions;
        end
        newMask=fusiScanSequence('mapVolume',origPassedMask,source,target);
        par=newPar;state.scanSequence=par.scanSequence;TR=target.TR;baseline=b;
        if isfield(b,'localBaseline'),localBaselineReset=b.localBaseline;end
        state.referenceMode=4;set(popReferenceTrace,'Value',4);
        origPSC=proc.PSC;baselineRaw=I;nVolsOrig=target.nFrames;origPassedMask=newMask;
        if registered
            PSC=displayPSC;origBG=nativeBG;state.currentROIMapping=newMapping;roi.viewMapping=newMapping;
        else
            PSC=proc.PSC;bg=proc.bg;if retain&&~isempty(nativeBG),bg=nativeBG;end;origBG=bg;
            passedMask=newMask;state.isAtlasWarped=false;state.isStepMotorAtlasWarped=false;
            state.atlasDisplay3D=[];state.regionLabelUnderlay=[];state.regionInfo=struct();state.regionColorLUT=[];
            state.currentROIMapping=[];roi.viewMapping=[];state.pendingAtlasUnderlay3D=[];
            applyUnderlayMeta(defaultUnderlayMeta(),bg);
        end
        if retain
            uState=appearance;set(popUnder,'Value',uState.mode);
            set(slBri,'Value',uState.brightness);set(slCon,'Value',uState.contrast);set(slGam,'Value',uState.gamma);
            set(txtBri,'String',sprintf('%.2f',uState.brightness));set(txtCon,'String',sprintf('%.2f',uState.contrast));set(txtGam,'String',sprintf('%.2f',uState.gamma));
            anchor.revision=state.underlayRevision;state.retainedUnderlay=anchor;
        else,state.retainedUnderlay=[];end
        fileLabel=target.label;spatial=scmSpatialCalibration(par);isVolMode=false;
        set(ebBase,'String',sprintf('%.9g-%.9g',b.start,b.end),'Enable','on');set(lblBase,'String','Baseline window (s)');
        if fusiBaselineReference('isExternal',b),set(ebBase,'Enable','off');set(lblBase,'String','Source baseline (s)');end
        set(btnBaselineSource,'TooltipString',fusiBaselineReference('label',b));
        state.referenceTraceCache={};state.timeWindowKey=[];state.tcFixX=false;set(cbTcFixX,'Value',0);
        resetRoisAndRefreshAfterDataChange(false);
        if ~isempty(maskFile),loadMaskCB([],[],maskFile);end
        for di=1:numel(mapped),if mapped{di}.sourceAutomatic,mapped{di}=candidateForBaseline(mapped{di});end,end
        installROIDefinitions(mapped);redrawROIsForCurrentSlice();refreshScanSequenceControls();layoutUI();
        set(info1,'String',['Signal overlay: ' target.label ' | Underlay: ' mode]);
    catch ME
        setappdata(fig,'FUSIScanSequenceError',ME.message);set(info1,'String',['Scan switch failed: ' ME.message]);refreshScanSequenceControls();
    end
end

function U=procOrRetainedBG(anchor,target,retain)
    U=[];if ~retain||isempty(anchor),return;end
    offset=fusiScanSequence('offset',anchor.source,target);
    if all(offset==0)&&isequal(anchor.source.spatialSize,target.spatialSize),U=anchor.nativeBG;return;end
    if numel(anchor.source.spatialSize)==2&&ndims(anchor.nativeBG)==3&&size(anchor.nativeBG,3)==3
        for channel=1:3,U(:,:,channel)=fusiScanSequence('mapVolume',anchor.nativeBG(:,:,channel),anchor.source,target);end
    else,U=fusiScanSequence('mapVolume',anchor.nativeBG,anchor.source,target);end
end

function baselineSourceChanged(~,~)
    try
        if isappdata(fig,'FUSIBaselineError'),rmappdata(fig,'FUSIBaselineError');end
        assert(~isempty(baselineRaw),'deConfUSIon:BaselineRaw','This SCM contains PSC only. Open the raw/preprocessed scan from Studio to select an absolute baseline.');
        if isappdata(fig,'FUSIBaselineRequest')
            b=getappdata(fig,'FUSIBaselineRequest');rmappdata(fig,'FUSIBaselineRequest');
        else
            current=baseline;[current.start,current.end]=parseRangeSafe(getStr(ebBase),baseStart0,baseEnd0);
            if isVolMode,current.start=(current.start-1)*TR;current.end=(current.end-1)*TR;end
            b=fusiBaselineSourceDialog(current,TR,size(baselineRaw,1:ndims(baselineRaw)-1),getDatasetRootForSelectors(),par);
        end
        if isempty(b),return;end
        if ~fusiBaselineReference('isExternal',baseline)&&fusiBaselineReference('isExternal',b)
            localBaselineReset=baseline;
            [localBaselineReset.start,localBaselineReset.end]=parseRangeSafe(getStr(ebBase),baseStart0,baseEnd0);
            if isVolMode,localBaselineReset.start=(localBaselineReset.start-1)*TR;localBaselineReset.end=(localBaselineReset.end-1)*TR;end
            localBaselineReset.mode='sec';
        end
        if fusiBaselineReference('isExternal',b),b.localBaseline=localBaselineReset;end
        sequenceBaseline=[];
        if ~isempty(state.scanSequence)&&numel(state.scanSequence.scans)>1&&~isappdata(fig,'FUSIScanSequenceApplying')
            sequenceBaseline=state.scanSequence;
            if fusiBaselineReference('isExternal',b)
                sequenceBaseline.normMode='shared';
            elseif strcmp(sequenceBaseline.normMode,'local')
                sequenceBaseline.localWindowSec=[b.start b.end];
            else
                sequenceBaseline.sharedReference=[];
            end
            [sequenceBaseline,b]=fusiScanSequence('prepare',sequenceBaseline,b,baselineRaw,TR,par);
        end
        if fusiBaselineNeedsRecalculation(baseline,b)
            proc=fusiApplyBaseline(baselineRaw,TR,par,b,nT);updatedPSC=proc.PSC;
            if state.isAtlasWarped,updatedPSC=scmWarpMappedSeries(proc.PSC,state.currentROIMapping,[nY nX nZ]);end
            PSC=updatedPSC;origPSC=proc.PSC;
            count=getappdata(fig,'FUSIBaselineRecomputations');if isempty(count),count=0;end
            setappdata(fig,'FUSIBaselineRecomputations',count+1);
        end
        baseline=b;isVolMode=false;
        if ~isempty(sequenceBaseline),state.scanSequence=sequenceBaseline;par.scanSequence=sequenceBaseline;refreshScanSequenceControls();end
        if ~fusiBaselineReference('isExternal',b)&&state.referenceMode==4&& ...
                (isempty(state.scanSequence)||numel(state.scanSequence.scans)<2)
            state.referenceMode=3;set(popReferenceTrace,'Value',3);
        end
        baseStart0=b.start;baseEnd0=b.end;
        set(ebBase,'String',sprintf('%.9g-%.9g',b.start,b.end),'Enable','on');set(lblBase,'String','Baseline window (s)');
        if fusiBaselineReference('isExternal',b),set(ebBase,'Enable','off');set(lblBase,'String','Source baseline (s)');end
        set(btnBaselineSource,'TooltipString',fusiBaselineReference('label',b));
        state.baseKey=[];state.signalKey=[];state.timeWindowKey=[];roi.hoverStats=[];
        state.referenceTraceCache={};state.referenceTraceError='';
        state.tcFixX=false;set(cbTcFixX,'Value',0);set(ebTcXLim,'Enable','off');
        audit=scmAutomaticROISelections(fig);
        for ai=1:numel(audit)
            c=candidateForBaseline(audit{ai});tc=scmROI('trace',PSC,c);
            c.meanPSC=mean(tc(c.signalFrames));
            c.method='Fixed ROI and signal window retained after baseline change';
            c.selection='Reference changed; score recomputed. Rerun Automatic analysis to select new peaks.';
            audit{ai}=c;
        end
        setappdata(fig,'AutomaticROISelections',audit);
        if ~isappdata(fig,'FUSIScanSequenceApplying'),computeSCM();redrawROIsForCurrentSlice();end
        set(hLivePSC,'Visible','off');roi.lastHoverXY=[-inf -inf];
        set(info1,'String',['Baseline: ' fusiBaselineReference('label',baseline)]);
    catch ME
        setappdata(fig,'FUSIBaselineError',ME.message);set(info1,'String',['Baseline failed: ' ME.message]);
    end
end

function resetLocalBaseline(~,~)
    if ~fusiBaselineReference('isExternal',baseline)
        set(info1,'String','This scan already uses its local baseline window.');return;
    end
    setappdata(fig,'FUSIBaselineRequest',localBaselineReset);baselineSourceChanged();
end

function c=candidateForBaseline(c)
    c.baselineMode='local';
    if fusiBaselineReference('isExternal',baseline)
        c.baselineMode='external';c.baselineReference=baseline.reference;
        r=baseline.reference;c.baselineFrames=r.frames(1):r.frames(2);
        c.baselineSec=r.windowSec;c.baselineSampleSec=(c.baselineFrames-1)*r.TR;
    else
        [b0,b1]=selectedBaselineFrames();c.baselineFrames=b0:b1;
        c.baselineSec=tsec([b0 b1]);c.baselineSampleSec=tsec(c.baselineFrames);
        if isfield(c,'baselineReference'),c=rmfield(c,'baselineReference');end
    end
end

function onWindowEdited(~,~)
    % Refresh persistent and hover ROIs from the same source used by export.
    try
        [v0,v1]=parseRangeSafe(getStr(ebBase),NaN,NaN);
        if ~isfinite(v0) || ~isfinite(v1) || v1<v0, return; end
        if isVolMode, lastAllowed=nT; firstAllowed=1; else, lastAllowed=tsec(end); firstAllowed=0; end
        if ~fusiBaselineReference('isExternal',baseline)&&(v0<firstAllowed || v1>lastAllowed), return; end
        if ~isempty(state.scanSequence)&&numel(state.scanSequence.scans)>1&&strcmp(state.scanSequence.normMode,'local')
            window=[v0 v1];if isVolMode,window=(window-1)*TR;end
            if ~isequal(window,state.scanSequence.localWindowSec)
                updatedSequence=state.scanSequence;updatedSequence.localWindowSec=window;
                setappdata(fig,'FUSIScanSequenceRequest',updatedSequence);manageScanSequence();
                if isappdata(fig,'FUSIScanSequenceError')
                    set(ebBase,'String',sprintf('%.9g-%.9g',state.scanSequence.localWindowSec));
                end
                return;
            end
        end
        computeSCM();
        redrawROIsForCurrentSlice();
        if strcmp(get(hLiveRect,'Visible'),'on')
            % The displayed rectangle is authoritative, including ROIs added
            % by coordinates and pinned ROIs whose size has since changed.
            bounds=get(hLiveRect,'Position');
            x1=round(bounds(1)); y1=round(bounds(2));
            x2=x1+round(bounds(3))-1; y2=y1+round(bounds(4))-1;
            tc=computeRoiPSC_idx(state.z,x1,x2,y1,y2,state.hoverIdx);
            setLiveCurve(tc,state.z,x1,x2,y1,y2);
        end
        roi.lastHoverXY=[-inf -inf];
        applyTimecourseAxisMode(); drawnow;
    catch ME
        errordlg(ME.message,'SCM window');
    end
end

function windowKeyPress(src,evt)
    try
        key=lower(char(evt.Key));
        if any(strcmp(key,{'return','enter'}))
            onWindowEdited(src,evt);
        end
    catch
    end
end

function roiXYNoop(~,~), end

function sliceChanged(~,~)
    zNew = round(nZ - get(slZ, 'Value') + 1);
    state.z = clamp(zNew, 1, nZ);
    set(slZ, 'Value', nZ - state.z + 1);
    mask2D = getMaskForCurrentSlice();
    updateSCMUnderlayDisplay(state.z);
    roi.pendingHover=[];
    set(hLiveRect, 'Visible', 'off');
    set(hLivePSC, 'Visible', 'off');
    set(hRoiCoordTxt, 'Visible', 'off', 'String', '');
    updateSliceIndicators(); updateInfoLines(); computeSCM(); redrawROIsForCurrentSlice();
end

function unfreezeHover(~,~)
    setHoverActive(roi.isFrozen);
    set(hLiveRect, 'Visible', 'off');
    set(hLivePSC, 'Visible', 'off');
    set(hRoiCoordTxt, 'Visible', 'off', 'String', '');
    applyTimecourseAxisMode();
end

function setHoverActive(active)
    roi.isFrozen = ~active;
    roi.pendingHover=[]; roi.lastHoverXY=[-inf -inf];
    roi.hoverScheduled=false;
    if ~isempty(hoverTimer) && isvalid(hoverTimer), stop(hoverTimer); end
    if active
        set(btnUnfreeze,'String','HOVER ACTIVE','BackgroundColor',[.10 .48 .20],'ForegroundColor','w');
    else
        set(btnUnfreeze,'String','HOVER INACTIVE','BackgroundColor',[.65 .12 .12],'ForegroundColor','w');
    end
    setappdata(btnUnfreeze,'HoverActive',logical(active));
end

function setROIsize()
    roi.revision=roi.revision+1;
    roi.size = max(1, round(get(slROI, 'Value')));
    set(txtROIsz, 'String', sprintf('%d', roi.size));
    updateROIPhysicalSize();
    applyTimecourseAxisMode();
end

function onRoiSizeEdited(~,~)
    roi.revision=roi.revision+1;
    v = str2double(strtrim(getStr(txtROIsz)));
    if ~isfinite(v), v = roi.size; end
    roi.size = max(1, min(220, round(v)));
    set(slROI, 'Value', roi.size);
    set(txtROIsz, 'String', sprintf('%d', roi.size));
    updateROIPhysicalSize();
end

function roiSizeModeChanged(~,~)
    requested=get(lblROIsz,'Value')==2;
    if requested
        try,scmROI('size',struct('sizeMode','um','sizeUm',roi.sizeUm),currentROISpacingUm());
        catch ME,set(lblROIsz,'Value',1);set(info1,'String',ME.message);requested=false;end
    end
    roi.sizeMode='pixels';if requested,roi.sizeMode='um';end
    pixelVis='on';physicalVis='off';if requested,pixelVis='off';physicalVis='on';end
    set([slROI txtROIsz],'Visible',pixelVis);set([ebRoiWidth ebRoiHeight],'Visible',physicalVis);
    roi.revision=roi.revision+1;roi.pendingHover=[];roi.hoverStats=[];updateROIPhysicalSize();
end
function roiPhysicalEdited(~,~)
    requested=[str2double(getStr(ebRoiWidth)) str2double(getStr(ebRoiHeight))];
    try
        scmROI('size',struct('sizeMode','um','sizeUm',requested),currentROISpacingUm());roi.sizeUm=requested;
        roi.revision=roi.revision+1;roi.pendingHover=[];roi.hoverStats=[];updateROIPhysicalSize();
    catch ME
        set(ebRoiWidth,'String',num2str(roi.sizeUm(1)));set(ebRoiHeight,'String',num2str(roi.sizeUm(2)));set(info1,'String',ME.message);
    end
end
function imageAppearanceChanged(~,~)
    state.physicalScale=logical(get(cbPhysicalScale,'Value'));state.sharpPixels=logical(get(cbSharpPixels,'Value'));
    syncSCMImageGeometry();drawnow limitrate;
end
function spacing=currentROISpacingUm()
    spacing=spatial.spacingUm;
    if state.isAtlasWarped || state.isStepMotorAtlasWarped
        % ROI coordinates belong to the functional grid, not the finer
        % reference texture or the original acquisition after resampling.
        spacing=state.atlasInPlaneSpacingUm;
        if ~isempty(state.atlasDisplay3D),spacing=state.atlasDisplay3D.spacingUm;end
        if any(~isfinite(spacing(1:2)) | spacing(1:2)<=0) && isfield(par,'atlasVoxelSizeYXZUm')
            spacing=par.atlasVoxelSizeYXZUm;
        end
    end
end

function updateROIPhysicalSize()
    spacing=currentROISpacingUm();
    if strcmp(roi.sizeMode,'um')&&any(~isfinite(spacing(1:2))|spacing(1:2)<=0)
        roi.sizeMode='pixels';set(lblROIsz,'Value',1);set([slROI txtROIsz],'Visible','on');set([ebRoiWidth ebRoiHeight],'Visible','off');
    end
    [x1,x2,y1,y2]=roiBounds(ceil(nX/2),ceil(nY/2));
    counts=[x2-x1+1 y2-y1+1]; % width (columns), height (rows)
    known=numel(spacing)>=2 && all(isfinite(spacing(1:2)) & spacing(1:2)>0);
    dimensions=[NaN NaN];
    if known
        dimensions=counts.*spacing([2 1]);
        label=sprintf('(%.6g %c %.6g %cm; X %c Y)',dimensions(1),215,dimensions(2),181,215);
        detail=sprintf(['ROI footprint: %d columns x %d rows = %.6g x %.6g um (X x Y).\n' ...
            'First value: X = horizontal width = columns x %.6g um.\n' ...
            'Second value: Y = vertical height = rows x %.6g um.\n' ...
            'Uses the current functional pixel grid. Atlas display texture upsampling does not change ROI size.\n' ...
            'ROI bounds are clipped at image edges; the ROI preview reports that actual size.\n' ...
            'Pixel spacing describes sampling, not acoustic resolution.'], ...
            counts(1),counts(2),dimensions(1),dimensions(2),spacing(2),spacing(1));
    else
        label=sprintf('(%cm size unavailable - set Scale / units)',181);
        detail='Physical ROI size requires verified row and column spacing for the current functional grid. Use Scale / units to calibrate it.';
    end
    if strcmp(roi.sizeMode,'um')
        label=sprintf('Actual %.6g %c %.6g %cm; %d %c %d px (X %c Y)',dimensions(1),215,dimensions(2),181,counts(1),215,counts(2),215);
        detail=sprintf('Requested %.6g x %.6g um (X x Y). Nearest whole native pixels; no interpolation.\n%s',roi.sizeUm,detail);
    elseif any(counts~=roi.size)
        detail=sprintf('%s\nSelected size %d uses the existing centered ROI bounds (%d x %d pixels here).',detail,roi.size,counts(1),counts(2));
        if known,label=sprintf('%s [%d %c %d px]',label,counts(1),215,counts(2));end
    end
    set(txtROIPhysical,'String',label,'TooltipString',detail);
    set(txtROIsz,'TooltipString',['Type ROI size in pixels, then press Enter.' newline detail]);
    set(slROI,'TooltipString',detail);
    setappdata(fig,'SCMROIPhysicalSize',struct('selectedSize',roi.size,'pixelsXY',counts, ...
        'sizeXYUm',dimensions,'spacingYXUm',spacing(1:2),'calibrated',known,'sizeMode',roi.sizeMode,'requestedSizeUm',roi.sizeUm));
end

function label=roiCoordinateText(z,x1,x2,y1,y2)
    label=sprintf('ROI z=%d | x:%d-%d  y:%d-%d',z,x1,x2,y1,y2);
    spacing=currentROISpacingUm();
    if numel(spacing)>=2 && all(isfinite(spacing(1:2)) & spacing(1:2)>0)
        label=sprintf('%s | %.6g %c %.6g %cm (X %c Y)',label,(x2-x1+1)*spacing(2),215,(y2-y1+1)*spacing(1),181,215);
    end
end

function roiXYKey(~, evt)
    try
        if isfield(evt,'Key') && (strcmpi(evt.Key,'return') || strcmpi(evt.Key,'enter'))
            addRoiFromXY();
        end
    catch
    end
end

function mouseMove(~,~)
    if roi.isFrozen, roi.pendingHover=[]; return; end
    if ~isPointerOverImageAxis()
        roi.pendingHover=[];
        return;
    end
    cp = get(ax, 'CurrentPoint');
    x = round(cp(1,1)); ypix = round(cp(1,2));
    if x < 1 || x > nX || ypix < 1 || ypix > nY
        roi.pendingHover=[];
        set(hLiveRect, 'Visible', 'off');
        set(hLivePSC, 'Visible', 'off');
        set(hRoiCoordTxt, 'Visible', 'off', 'String', '');
        applyTimecourseAxisMode();
        return;
    end
    queueHover(x,ypix);
end

function queueHover(x,ypix)
    setappdata(fig,'deConfUSIonInteractionUntil',now+0.75/86400);
    roi.pendingHover=[state.z x ypix roi.revision];
    roi.lastHoverMove=now;
    [x1,x2,y1,y2]=roiBounds(x,ypix);
    set(hLiveRect,'Position',[x1 y1 x2-x1+1 y2-y1+1],'Visible','on');
    if ~roi.hoverScheduled
        roi.hoverScheduled=true;
        start(hoverTimer);
    end
end

function renderPendingHover(~,~)
    if ~isgraphics(fig), disposeHoverTimer(); return; end
    if roi.isFrozen || isempty(roi.pendingHover)
        roi.hoverScheduled=false;
        stop(hoverTimer); return;
    end
    if state.tcLiveAllScans&&(sequenceTraceShown()||referenceTraceShown())&&isfield(roi,'lastHoverMove')&&(now-roi.lastHoverMove)*86400<.25,return;end
    target=roi.pendingHover; roi.pendingHover=[];
    if target(1)~=state.z || target(4)~=roi.revision, return; end
    x=target(2); ypix=target(3);
    if isequal(roi.lastHoverXY,target) && strcmp(get(hLiveRect,'Visible'),'on'), return; end
    [x1,x2,y1,y2] = roiBounds(x, ypix);
    col = roi.colors(mod(numel(ROI_byZ{state.z}), size(roi.colors,1))+1, :);
    set(hLiveRect, 'Position', [x1 y1 x2-x1+1 y2-y1+1], 'EdgeColor', col, 'Visible', 'on');
    set(hRoiCoordTxt, 'String', roiCoordinateText(state.z,x1,x2,y1,y2), 'Visible', 'on');
    tc = computeHoverPSC(x1,x2,y1,y2);
    if isempty(tc) || numel(tc) ~= numel(state.tminHover)
        set(hLivePSC, 'Visible', 'off');
        return;
    end
    setLiveCurve(tc,state.z,x1,x2,y1,y2);
    roi.lastHoverXY=target;
    applyTimecourseAxisMode();
    drawnow limitrate nocallbacks;
end

function disposeHoverTimer(~,~)
    closeCandidateReviews();
    if ~isempty(hoverTimer) && isvalid(hoverTimer)
        stop(hoverTimer); delete(hoverTimer);
    end
    if ~isempty(sliceTimer)&&isvalid(sliceTimer),stop(sliceTimer);delete(sliceTimer);end
end

function mouseClick(~,~)
    if roi.addBusy || ~isPointerOverImageAxis(), return; end
    cp = get(ax, 'CurrentPoint');
    x = round(cp(1,1)); ypix = round(cp(1,2));
    if x < 1 || x > nX || ypix < 1 || ypix > nY, return; end
    type = get(fig, 'SelectionType');
    if strcmp(type, 'normal')
        addRoiAtCenter(x, ypix);
    elseif strcmp(type, 'alt')
        removeNearestRoi(x, ypix);
    end
end

function mouseScroll(~, evt)
    if nZ <= 1 || ~isPointerOverImageAxis(), return; end
    dz = sign(evt.VerticalScrollCount);
    if dz == 0, return; end
    current=state.z;if ~isempty(state.pendingSlice),current=state.pendingSlice;end
    state.pendingSlice=clamp(current+evt.VerticalScrollCount,1,nZ);
    roi.pendingHover=[];
    if strcmp(sliceTimer.Running,'off'),start(sliceTimer);end
end

function renderPendingSlice(~,~)
    if ~isgraphics(fig)||isempty(state.pendingSlice),return;end
    target=state.pendingSlice;state.pendingSlice=[];if target~=state.z,browseSlice(target);end
end

function browseSlice(z)
    validateattributes(z,{'numeric'},{'scalar','finite'});
    state.z = clamp(round(z), 1, nZ);
    mask2D = getMaskForCurrentSlice();
    updateSCMUnderlayDisplay(state.z);
    roi.pendingHover=[];
    set(hRoiCoordTxt, 'Visible', 'off', 'String', '');
    updateSliceIndicators(); updateInfoLines(); computeSCM(); redrawROIsForCurrentSlice();
end

function addRoiFromXY(~,~)
    tNow = now;
    if roi.lastAddStamp ~= 0 && (tNow - roi.lastAddStamp) * 86400 < 0.20, return; end
    roi.lastAddStamp = tNow;
    s = strtrim(getStr(ebRoiXY));
    if isempty(s), return; end
    s = strrep(s, ',', ' ');
    v = sscanf(s, '%f');
    if numel(v) < 2 || ~isfinite(v(1)) || ~isfinite(v(2))
        warndlg('Enter ROI center as: x y   for example 120 80 or 120,80', 'Add ROI');
        return;
    end
    addRoiAtCenter(round(v(1)), round(v(2)));
end

function addRoiAtCenter(x, ypix)
    if roi.addBusy, return; end
    roi.addBusy=true;
    roi.addAppearance=struct('pointer',get(fig,'Pointer'),'info',get(info1,'String'), ...
        'loadingInfo',sprintf('Adding ROI %d: calculating its time course...',roi.nextId));
    set(fig,'Pointer','watch');set(info1,'String',roi.addAppearance.loadingInfo);
    guard=onCleanup(@finishRoiAdd); %#ok<NASGU>
    setHoverActive(false);
    if sequenceTraceShown()||referenceTraceShown(),drawnow limitrate nocallbacks;end
    x = clamp(round(x), 1, nX); ypix = clamp(round(ypix), 1, nY);
    [x1,x2,y1,y2] = roiBounds(x, ypix);
    tc = computeRoiPSC_atSlice(state.z, x1, x2, y1, y2);
    if numel(tc) ~= nT, return; end
    col = roi.colors(mod(numel(ROI_byZ{state.z}), size(roi.colors,1))+1, :);
    r=struct('id', roi.nextId, 'x1', x1, 'x2', x2, 'y1', y1, 'y2', y2, 'color', col);
    ROI_byZ{state.z}(end+1) = r;
    sizing=scmROI('size',struct('size',roi.size,'sizeMode',roi.sizeMode,'sizeUm',roi.sizeUm),currentROISpacingUm());
    sizing.boundsXY=[x1 x2 y1 y2];sizing.sizeXY=[x2-x1+1 y2-y1+1];
    if sizing.calibrated,sizing.sizeXYUm=sizing.sizeXY.*sizing.spacingUm([2 1]);end
    roi.sizingById{roi.nextId}=sizing;
    roi.nextId = roi.nextId + 1;
    % Adding one ROI must not recalculate or replace the existing curves.
    setappdata(fig,'FUSICurveReadBatch',[1 1]);
    drawRoiForCurrentSlice(r,scmAutomaticROISelections(fig),tc);
    set(hLiveRect, 'Position', [x1 y1 x2-x1+1 y2-y1+1], 'EdgeColor', col, 'Visible', 'on');
    tcHover = tc(state.hoverIdx);
    if ~isempty(tcHover) && numel(tcHover) == numel(state.tminHover)
        setLiveCurve(tcHover,state.z,x1,x2,y1,y2);
    else
        set(hLivePSC, 'Visible', 'off');
    end
    set(hRoiCoordTxt, 'String', roiCoordinateText(state.z,x1,x2,y1,y2), 'Visible', 'on');
    applyTimecourseAxisMode();

end

function finishRoiAdd()
    appearance=roi.addAppearance;roi.addBusy=false;
    closeCurveReadProgress();
    if ~isgraphics(fig),return;end
    set(fig,'Pointer',appearance.pointer);
    if isequal(get(info1,'String'),appearance.loadingInfo),set(info1,'String',appearance.info);end
    roi.addAppearance=[];
end

function removeNearestRoi(x, ypix)
    roi.pendingHover=[];
    if ~isempty(ROI_byZ{state.z})
        ROI = ROI_byZ{state.z};
        ctr = arrayfun(@(r)[(r.x1+r.x2)/2, (r.y1+r.y2)/2], ROI, 'UniformOutput', false);
        ctr = cat(1, ctr{:});
        [~, i] = min(sum((ctr - [x ypix]).^2, 2));
        removedID=ROI(i).id;
        for zz=1:nZ,marks=ROI_byZ{zz};ROI_byZ{zz}=marks([marks.id]~=removedID);end
        audit=scmAutomaticROISelections(fig);audit=audit(~cellfun(@(c)c.roiId==removedID,audit));setappdata(fig,'AutomaticROISelections',audit);
        roi.hiddenDefinitions=roi.hiddenDefinitions(~cellfun(@(c)c.roiId==removedID,roi.hiddenDefinitions));
        for bi=1:numel(roi.viewBanks)
            definitions=roi.viewBanks{bi}.definitions;
            roi.viewBanks{bi}.definitions=definitions(~cellfun(@(c)c.roiId==removedID,definitions));
        end
        if numel(roi.sizingById)>=removedID,roi.sizingById{removedID}=[];end
        pruneRoiGraphics(removedID);
    end
    set(hLiveRect, 'Visible', 'off');
    set(hLivePSC, 'Visible', 'off');
    set(hRoiCoordTxt, 'Visible', 'off', 'String', '');
    applyTimecourseAxisMode();
end

function pruneRoiGraphics(id)
    roiHandles=removeGraphicsForId(roiHandles,id);
    roiTextHandles=removeGraphicsForId(roiTextHandles,id);
    roiPlotPSC=removeGraphicsForId(roiPlotPSC,id);
    roi.savedTcBounds=zeros(0,6);
    for h=reshape(roiPlotPSC,1,[]),roi.savedTcBounds(end+1,:)=traceBounds(h.XData,h.YData);end
    applyTimecourseAxisMode();drawnow limitrate nocallbacks;
end
function handles=removeGraphicsForId(handles,id)
    keep=true(size(handles));
    for k=1:numel(handles)
        if ~isgraphics(handles(k)),keep(k)=false;
        elseif isequal(getappdata(handles(k),'SCMROIId'),id),delete(handles(k));keep(k)=false;end
    end
    handles=handles(keep);
end

function [x1,x2,y1,y2] = roiBounds(x, ypix)
    if strcmp(roi.sizeMode,'um')
        s=scmROI('size',struct('sizeMode','um','sizeUm',roi.sizeUm),currentROISpacingUm());xy=s.sizeXY;
        x1=max(1,x-floor((xy(1)-1)/2));x2=min(nX,x+ceil((xy(1)-1)/2));
        y1=max(1,ypix-floor((xy(2)-1)/2));y2=min(nY,ypix+ceil((xy(2)-1)/2));return;
    end
    hlf = floor(roi.size/2);
    x1 = max(1, x-hlf); x2 = min(nX, x+hlf);
    y1 = max(1, ypix-hlf); y2 = min(nY, ypix+hlf);
end

%% ==========================================================
% SCM COMPUTATION / DISPLAY
%% ==========================================================
function computeSCM(~,~)
    [b0,b1] = parseRangeSafe(getStr(ebBase), 30, 240);
    [s0,s1] = parseRangeSafe(getStr(ebSig), 840, 900);
    sig = str2double(getStr(ebSigma));
    if ~isfinite(sig) || sig<0, sig = 0; set(ebSigma,'String','0'); end
    if ~isVolMode
        b0i = clamp(round(b0/TR)+1, 1, nT);
        b1i = clamp(round(b1/TR)+1, 1, nT);
        s0i = clamp(round(s0/TR)+1, 1, nT);
        s1i = clamp(round(s1/TR)+1, 1, nT);
    else
        b0i = clamp(round(b0), 1, nT);
        b1i = clamp(round(b1), 1, nT);
        s0i = clamp(round(s0), 1, nT);
        s1i = clamp(round(s1), 1, nT);
    end
    if b1i < b0i, tmp=b0i; b0i=b1i; b1i=tmp; end
    if s1i < s0i, tmp=s0i; s0i=s1i; s1i=tmp; end
    [b0i,b1i]=selectedBaselineFrames();
    baseMap = cachedBaseline(state.z,b0i,b1i);
    sigKey=[state.z s0i s1i];
    if ~isequal(state.signalKey,sigKey)
        state.signalMean=windowMean(state.z,s0i:s1i);
        state.signalKey=sigKey;
    end
    sigMap = state.signalMean;
    map = 100*(sigMap-baseMap)./(100+baseMap);
    map(~isfinite(baseMap) | 100+baseMap<=sqrt(eps('single')))=NaN;
    if sig > 0, map = smooth2D_gauss(map, sig); end
    mask2D = SCM_localMaskToMapSize_20260504(mask2D, map);
    map(~mask2D) = 0;
    state.lastSignedMap = map;
    set(hOV, 'CData', map);
    updateView();
    applyTimecourseAxisMode();
    updateSpatialScale();
end

function scaleSettings(~,~)
    raw=mat2str(spatial.rawSpacing);
    choice=questdlg(sprintf(['Voxel spacing [row column slice] in um: %s\n%s\nRaw spacing: %s\n' ...
        'Sampling spacing is not acoustic resolution.'],mat2str(spatial.spacingUm),spatial.source,raw), ...
        'Spatial scale','Ruler settings','Probe presets','Calibrate spacing','Ruler settings');
    if strcmp(choice,'Probe presets')
        [ix,ok]=listdlg('PromptString','Use only for native data from the matching sequence (not resampled data)', ...
            'SelectionMode','single','ListSize',[560 140], ...
            'ListString',{'Matrix: row 100 / column 150 / slice 150 um','Linear: row 45 / column 45 um; motor spacing unknown'});
        if ~ok, return; end
        profiles={'matrix','linear'}; calibration=scmProbeSpacing(profiles{ix});
        if nX~=calibration.expectedColumns || (ix==1 && nZ~=calibration.expectedSlices)
            warndlg('Current dimensions do not match this native sequence grid. Calibrate current spacing for cropped/resampled data.','Spatial scale'); return;
        end
        spatial=calibration; rulerStep=500;
    elseif strcmp(choice,'Calibrate spacing')
        currentSpacing=currentROISpacingUm();
        answer=inputdlg({'Row spacing (um)','Column spacing (um)','Slice spacing (um, NaN if unknown)'}, ...
            'Confirm spacing in CURRENT image coordinates',1,arrayfun(@num2str,currentSpacing,'UniformOutput',false));
        if isempty(answer), return; end
        v=str2double(answer)';
        if any(~isfinite(v(1:2)) | v(1:2)<=0) || ~(isnan(v(3)) || (isfinite(v(3)) && v(3)>0))
            warndlg('Enter positive row/column spacing. Slice spacing may be NaN.','Spatial scale'); return;
        end
        if state.isAtlasWarped || state.isStepMotorAtlasWarped
            state.atlasInPlaneSpacingUm=v;
        else
            spatial.spacingUm=v; spatial.source='User-confirmed spacing for current image.';
        end
    elseif strcmp(choice,'Ruler settings')
        [ix,ok]=listdlg('PromptString','Ruler tick interval','SelectionMode','single', ...
            'ListString',{'Off','50 um','100 um','200 um','250 um','300 um','500 um','750 um','1000 um','1500 um','2000 um','5000 um'});
        if ~ok, return; end
        values=[0 50 100 200 250 300 500 750 1000 1500 2000 5000]; selectedStep=values(ix);
        setappdata(fig,'SCMRulerVisible',selectedStep>0);
        set(findall(fig,'Tag','SCM_RulerToggle'),'Value',double(selectedStep>0));
        if selectedStep>0,rulerStep=selectedStep;end % Off retains the last chosen length.
        currentSpacing=currentROISpacingUm();
        if selectedStep>0 && any(~isfinite(currentSpacing(1:2)))
            setappdata(fig,'SCMRulerVisible',false);
            set(findall(fig,'Tag','SCM_RulerToggle'),'Value',0); warndlg('Units could not be verified. Use Scale / units > Probe presets for these sequences, or Calibrate spacing.','Spatial scale');
        end
    end
    updateSpatialScale();
end

function rulerVisibilityChanged(src,~)
    enabled=logical(get(src,'Value'));setappdata(fig,'SCMRulerVisible',enabled);
    if enabled && rulerStep<=0,rulerStep=500;end
    updateSpatialScale();
    drawnow limitrate;
end

function updateSpatialScale()
    updateROIPhysicalSize();
    sig=str2double(getStr(ebSigma)); if ~isfinite(sig), sig=0; end
    detail=sprintf(['Gaussian sigma = %.3g pixels in each in-plane axis; FWHM = %.3g pixels.\n' ...
        'No smoothing across slices. Sigma 0 = off. Voxel spacing is not acoustic resolution.\n' ...
        'The ruler uses the spacing of the current native or atlas grid.\n' ...
        'Spacing [row column slice] um: %s\n%s'],sig,2.35482*sig,mat2str(spatial.spacingUm),spatial.source);
    if all(isfinite(spatial.spacingUm(1:2)))
        detail=sprintf('%s\nSigma [row column] = %s um; FWHM = %s um.',detail, ...
            mat2str(sig*spatial.spacingUm(1:2),4),mat2str(2.35482*sig*spatial.spacingUm(1:2),4));
    end
    set(ebSigma,'TooltipString',detail); set(btnScale,'TooltipString',detail);
    label='SCM smoothing sigma (px)';
    if all(isfinite(spatial.spacingUm(1:2))) && ~state.isAtlasWarped && ~state.isStepMotorAtlasWarped
        label=sprintf('Sigma px | %.3g / %.3g um',sig*spatial.spacingUm(1:2));
    end
    set(lblSigma,'String',label);
    setappdata(fig,'SCMSpatialCalibration',spatial);
    enabled=true;
    if isappdata(fig,'SCMRulerVisible'),enabled=logical(getappdata(fig,'SCMRulerVisible'));end
    fusiDrawScaleBar(ax,currentROISpacingUm(),max(eps,rulerStep),enabled&&rulerStep>0);
end

function alphaModToggled(~,~)
    state.alphaModOn = logical(get(cbAlphaMod, 'Value'));
    if state.alphaModOn
        set(ebModMin, 'Enable', 'on', 'ForegroundColor', [1.00 0.35 0.35], 'BackgroundColor', [0.20 0.20 0.20]);
        set(ebModMax, 'Enable', 'on', 'ForegroundColor', [1.00 0.35 0.35], 'BackgroundColor', [0.20 0.20 0.20]);
    else
        set(ebModMin, 'Enable', 'off', 'ForegroundColor', [0.55 0.55 0.55], 'BackgroundColor', [0.16 0.16 0.16]);
        set(ebModMax, 'Enable', 'off', 'ForegroundColor', [0.55 0.55 0.55], 'BackgroundColor', [0.16 0.16 0.16]);
    end
    updateView();
end

function updateView(~,~)
    a = get(slAlpha, 'Value');
    set(txtAlpha, 'String', sprintf('%.0f', a));
    caxv = sscanf(strrep(getStr(ebCax), ',', ' '), '%f');
    if numel(caxv) >= 2 && all(isfinite(caxv(1:2))) && caxv(2) ~= caxv(1)
        state.cax = caxv(1:2).';
        if state.cax(2) < state.cax(1), state.cax = fliplr(state.cax); end
    end
    newSignMode = get(popSignMode, 'Value');
    state.signMode = newSignMode;
    if newSignMode ~= state.prevSignMode
        if newSignMode == 3
            set(popMap, 'Value', findPopupIndexByName(popMap, 'signed_blackbdy_winter'));
        elseif newSignMode == 2
            set(popMap, 'Value', findPopupIndexByName(popMap, 'winter_brain_fsl'));
        else
            set(popMap, 'Value', findPopupIndexByName(popMap, 'blackbdy_iso'));
        end
        state.prevSignMode = newSignMode;
    end
    setOverlayColormap(getCurrentPopupStringLocal(popMap));
    mMin = str2double(getStr(ebModMin)); if ~isfinite(mMin), mMin = state.modMin; end
    mMax = str2double(getStr(ebModMax)); if ~isfinite(mMax), mMax = state.modMax; end
    if mMax < mMin, tmp=mMin; mMin=mMax; mMax=tmp; end
    state.modMin = mMin; state.modMax = mMax;
    [dispMap, alpha] = buildDisplayedOverlay(state.lastSignedMap, mask2D);
    set(hOV, 'CData', dispMap, 'AlphaData', alpha);
    caxis(ax, state.cax);
end

function [dispMap, alpha] = buildDisplayedOverlay(rawMap, localMask)
    rawMap = double(rawMap);
    localMask = SCM_localMaskToMapSize_20260504(localMask, rawMap);

    a = get(slAlpha, 'Value');
    thr = str2double(getStr(ebThr)); if ~isfinite(thr), thr = 0; end
    mMin = str2double(getStr(ebModMin)); if ~isfinite(mMin), mMin = state.modMin; end
    mMax = str2double(getStr(ebModMax)); if ~isfinite(mMax), mMax = state.modMax; end
    if mMax < mMin, tmp=mMin; mMin=mMax; mMax=tmp; end
    switch state.signMode
        case 1
            showMask = rawMap > 0;
            dispMap = rawMap;
        case 2
            showMask = rawMap < 0;
            dispMap = abs(min(rawMap, 0));
        otherwise
            showMask = isfinite(rawMap) & rawMap ~= 0;
            dispMap = rawMap;
    end
    baseMask = double(localMask);
    thrMask = double((abs(rawMap) >= thr) & showMask) .* baseMask;
    if ~state.alphaModOn
        alpha = (a/100) .* thrMask;
        return;
    end
    effLo = max(mMin, thr);
    effHi = mMax;
    mag = abs(rawMap); mag(~showMask) = NaN;
    if ~isfinite(effHi) || effHi <= effLo
        tmpv = mag(isfinite(mag));
        if isempty(tmpv), effHi = effLo + eps; else, effHi = max(tmpv); end
    end
    if ~isfinite(effHi) || effHi <= effLo, effHi = effLo + eps; end
    modv = (abs(rawMap) - effLo) ./ max(eps, (effHi - effLo));
    modv(~isfinite(modv)) = 0;
    modv = min(max(modv, 0), 1);
    modv(~showMask) = 0;
    if state.signMode == 1
        alpha = (a/100) .* modv .* thrMask;
    else
        alpha = (a/100) .* (0.20 + 0.80 .* modv) .* thrMask;
    end
end

%% ==========================================================
% UNDERLAY CONTROLS
%% ==========================================================
function underlayModeChanged(~,~)
    uState.mode = get(popUnder, 'Value');
    updateUnderlayControlsEnable();
    updateSCMUnderlayDisplay(state.z);
    updateInfoLines();
end

function underlaySliderChanged(~,~)
    uState.brightness = get(slBri, 'Value');
    uState.contrast   = get(slCon, 'Value');
    uState.gamma      = get(slGam, 'Value');
    uState.conectSize = clamp(round(get(slVsz, 'Value')), 0, MAX_CONSIZE);
    uState.conectLev  = clamp(round(get(slVlv, 'Value')), 0, MAX_CONLEV);
    set(txtBri, 'String', sprintf('%.2f', uState.brightness));
    set(txtCon, 'String', sprintf('%.2f', uState.contrast));
    set(txtGam, 'String', sprintf('%.2f', uState.gamma));
    set(txtVsz, 'String', sprintf('%d', uState.conectSize));
    set(txtVlv, 'String', sprintf('%d', uState.conectLev));
    updateSCMUnderlayDisplay(state.z);
    updateInfoLines();
end

function updateUnderlayControlsEnable()
    isVessel = (uState.mode == 4);
    set(slVsz, 'Enable', onoff(isVessel)); set(txtVsz, 'Enable', onoff(isVessel));
    set(slVlv, 'Enable', onoff(isVessel)); set(txtVlv, 'Enable', onoff(isVessel));
end

function updateSliceIndicators()
    if nZ > 1
        if isgraphics(slZ), set(slZ, 'Value', nZ - state.z + 1); end
        if isgraphics(txtZ), set(txtZ, 'String', '', 'Visible', 'off'); end
        if isgraphics(txtSliceOverlay)
            set(txtSliceOverlay, 'String', sprintf('Slice %d / %d', state.z, nZ), 'Visible', 'on');
        end
    else
        if isgraphics(txtZ), set(txtZ, 'String', '', 'Visible', 'off'); end
        if isgraphics(txtSliceOverlay), set(txtSliceOverlay, 'String', '', 'Visible', 'off'); end
    end
end

function updateInfoLines()
    modeNames = {'Legacy','Robust(1..99)','VideoGUI(0.5..99.5)','Vessel enhance','Saved appearance'};
    m = uState.mode; if m < 1 || m > numel(modeNames), m = 3; end
    atlasTxt = '';
    if state.isAtlasWarped, atlasTxt = ' | ATLAS'; end
    message=sprintf('TR = %.4gs | Slice %d/%d | Underlay: %s%s', TR, state.z, nZ, modeNames{m}, atlasTxt);
    if state.isAtlasWarped && ~isempty(state.atlasTransformFile)
        [folder,name,ext]=fileparts(state.atlasTransformFile);[~,version]=fileparts(folder);
        message={message,['Transform: ' version '/' name ext]};
        set(info1,'TooltipString',state.atlasTransformFile);
    end
    set(info1,'String',message);
end

function s = onoff(tf)
    if tf, s = 'on'; else, s = 'off'; end
end

%% ==========================================================
% MASK / UNDERLAY FILE PICKERS
%% ==========================================================
function loadMaskCB(~,~,selectedFile)
    if nargin>=3&&~isempty(selectedFile)
        fullf=char(selectedFile);
    else
    startPath = getMaskStartPath();
    [f,p] = uigetfileStartIn( ...
        {'*.mat;*.nii;*.nii.gz', 'Mask / bundle files (*.mat, *.nii, *.nii.gz)'; ...
         '*.mat', 'MAT mask bundle (*.mat)'; ...
         '*.nii;*.nii.gz', 'NIfTI mask (*.nii, *.nii.gz)'; ...
         '*.*', 'All files (*.*)'}, ...
        'Select overlay mask / bundle', startPath);
    if isequal(f,0), return; end
fullf = fullfile(p,f);
    end
try
    % If user accidentally selects an SCM_GroupExport bundle via LOAD MASK,
    % load it properly as a full SCM bundle instead of trying to read it as a mask.
    if isScmGroupBundleFileLocal(fullf)
        G = loadScmGroupBundleLocal(fullf);
        applyScmGroupBundleLocal(G, fullf);
        return;
    end

    B = [];
        [~,~,ext] = fileparts(fullf); ext = lower(ext);
        if strcmp(ext, '.mat')
            B = readScmBundleFile(fullf);
            if isfield(B,'isMaskEditor') && B.isMaskEditor
                applyMaskEditorBundleLocal(B, fullf, true);
                return;
            end
            if ~isempty(B.overlayMask)
                passedMask = fitBundleMaskToCurrentScm(B.overlayMask);
                passedMaskIsInclude = B.overlayMaskIsInclude;
            elseif ~isempty(B.brainMask)
                passedMask = fitBundleMaskToCurrentScm(B.brainMask);
                passedMaskIsInclude = B.brainMaskIsInclude;
            else
                [passedMask, passedMaskIsInclude] = readMask(fullf, 'overlayPreferred');
                passedMask = fitBundleMaskToCurrentScm(passedMask);
            end
           if ~isempty(B) && isstruct(B) && ~isempty(B.brainImage)
    U = squeeze(double(B.brainImage));

    if ~state.isAtlasWarped && isValidBundleUnderlayForCurrentScm(U)
        bg = prepareBundleUnderlayForCurrentScm(U);
        applyUnderlayMeta(defaultUnderlayMeta(), bg);
        origBG = bg;

        fprintf('[SCM] Loaded bundle underlay with size: %s\n', mat2str(size(bg)));
    elseif state.isAtlasWarped
        fprintf('[SCM] Loaded masks; retained the current atlas underlay.\n');
    else
        fprintf(['[SCM] Bundle underlay ignored because it is not a true slice-matched underlay.\n' ...
                 '      Underlay size: %s | SCM expects Y X Z = [%d %d %d]\n'], ...
                 mat2str(size(U)), nY, nX, nZ);
    end
end
        else
            [passedMask, passedMaskIsInclude] = readMask(fullf, 'overlayPreferred');
            passedMask = fitBundleMaskToCurrentScm(passedMask);
        end
        mask2D = getMaskForCurrentSlice();
        updateSCMUnderlayDisplay(state.z);
        if ~isempty(B) && isstruct(B)
            set(info1, 'String', sprintf('Loaded mask bundle: %s | field: %s', shortenPath(fullf,65), B.loadedField));
        else
            set(info1, 'String', sprintf('Loaded mask: %s', shortenPath(fullf,65)));
        end
        set(info1, 'TooltipString', fullf);
        computeSCM();
    catch ME
        errordlg(ME.message, 'Mask / bundle load failed');
    end
end


function applyMaskEditorBundleLocal(B, fullf, maskOnly)
    if nargin<3,maskOnly=false;end
    % LOAD MASK changes membership, not the chosen registered anatomy.
    % Keep its full-resolution texture, grid and region catalog intact.
    keepRegisteredUnderlay=maskOnly && state.isAtlasWarped;
    % Validate the entire bundle before changing the viewer. A grayscale
    % three-slice export must never be mistaken for a single RGB image.
    expected = [nY nX nZ];
    nativeSize=[size(origPSC,1) size(origPSC,2) 1];
    if ndims(origPSC)==4,nativeSize(3)=size(origPSC,3);end
    nativeBundle=B;
    context=struct('sizeYXZ',expected,'nativeSizeYXZ',nativeSize, ...
        'isAtlasWarped',state.isAtlasWarped,'mapping',state.currentROIMapping);
    [B,alignment]=scmReadMaskEditorBundle('align',B,context);
    U = B.image;
    if ndims(U) > 3 || ~isequal([size(U,1) size(U,2) size(U,3)], expected)
        error('SCM:MaskEditorDimensions', ...
            'Mask Editor underlay size %s does not match SCM [Y X Z] = %s. Load a bundle in the current SCM space.', ...
            mat2str(size(U)), mat2str(expected));
    end
    names = {'brainMask','overlayMask'};
    for k = 1:numel(names)
        M = B.(names{k});
        if ~isempty(M) && (ndims(M) > 3 || ...
                ~isequal([size(M,1) size(M,2) size(M,3)], expected))
            error('SCM:MaskEditorDimensions','Saved %s does not match the SCM slices.',names{k});
        end
    end
    if ~isempty(B.brainMask)
        % NaN records excluded pixels independently of black in-brain pixels.
        % The renderer keeps this boundary black even after slider changes.
        U(~B.brainMask) = NaN;
    end
    if ~keepRegisteredUnderlay
        bg = U;
        applyUnderlayMeta(defaultUnderlayMeta(), bg);
        state.isColorUnderlay = false;
    end
    if ~isempty(B.includeMask)
        passedMask = B.includeMask;
        passedMaskIsInclude = true;
    end
    if ~keepRegisteredUnderlay,applyRecommendedUnderlayDisplayForModeLocal('normal');end
    if B.isProcessed && ~keepRegisteredUnderlay
        uState.mode = 5;
        uState.brightness = 0;
        uState.contrast = 1;
        uState.gamma = 1;
        set(popUnder,'Value',5);
        set(slBri,'Value',0); set(txtBri,'String','0.00');
        set(slCon,'Value',1); set(txtCon,'String','1.00');
        set(slGam,'Value',1); set(txtGam,'String','1.00');
        updateUnderlayControlsEnable();
    end
    if ~state.isAtlasWarped
        origBG = bg;
        origPassedMask = passedMask;
        origPassedMaskIsInclude = passedMaskIsInclude;
    elseif alignment.warpedFromNative
        % Reset to native must recover the newly loaded mask, not an old one.
        origBG=nativeBundle.image;
        if ~isempty(nativeBundle.brainMask),origBG(~nativeBundle.brainMask)=NaN;end
        if ~isempty(nativeBundle.includeMask)
            origPassedMask=nativeBundle.includeMask;origPassedMaskIsInclude=true;
        end
    end
    mask2D = getMaskForCurrentSlice();
    updateROIPhysicalSize();
    updateSCMUnderlayDisplay(state.z);
    computeSCM();
    if keepRegisteredUnderlay
        set(info1,'String',['Loaded masks; retained current atlas anatomy and scale: ' shortenPath(fullf,65)], ...
            'TooltipString',fullf);
    elseif alignment.warpedFromNative
        set(info1,'String',['Loaded native Mask Editor bundle using the applied atlas transform: ' shortenPath(fullf,65)]);
    else
        set(info1,'String',['Loaded Mask Editor underlay and masks: ' shortenPath(fullf,65)], ...
            'TooltipString',fullf);
    end
end

function showRegionList(~,~)
    labels=state.regionLabelUnderlay;info=state.regionInfo;
    if ~isempty(state.atlasRegionSearch),labels=state.atlasRegionSearch.labels;info=state.atlasRegionSearch.info;end
    if isempty(labels)
        ctx=getappdata(popAtlasChoice,'AtlasRegionContext2D');
        if ~isempty(ctx),labels=ctx.labels;info=ctx.info;end
    end
    fusiRegionListDialog(labels,info);
end
function updateRegionLabels(varargin)
    labels=[];xData=[];yData=[];
    z=state.z;
    namesShown=logical(get(cbRegionLabels,'Value'));linesShown=logical(get(cbAtlasLines,'Value'));
    regionInfoForDisplay=state.regionInfo;
    if (namesShown||linesShown)&&state.isColorUnderlay&&~isempty(state.regionLabelUnderlay)
        if ~isempty(state.atlasDisplay3D)&&isfield(state.atlasDisplay3D,'getLabels')
            labels=state.atlasDisplay3D.getLabels(z);xData=state.atlasDisplay3D.xData;yData=state.atlasDisplay3D.yData;
        else,labels=state.regionLabelUnderlay(:,:,min(z,size(state.regionLabelUnderlay,3)));end
    elseif (namesShown||linesShown)&&~isempty(state.atlasRegionSearch)
        ctx=state.atlasRegionSearch;regionInfoForDisplay=ctx.info;
        if isfield(ctx,'displayProvider')
            labels=ctx.displayProvider.getLabels(z);xData=ctx.displayProvider.xData;yData=ctx.displayProvider.yData;
        else,labels=ctx.labels(:,:,min(z,size(ctx.labels,3)));end
    end
    if isempty(xData),xData=[1 size(labels,2)];yData=[1 size(labels,1)];end
    fusiRegionAnnotations(ax,labels,regionInfoForDisplay,namesShown, ...
        [state.underlayRevision z],xData,yData);
    fusiRegionBoundaryOverlay(ax,labels,linesShown,[state.underlayRevision z],xData,yData);
end
function regionAppearanceChanged(src,~)
    choices=get(src,'String');state.regionScheme=choices{get(src,'Value')};
    state.renderedAtlasCache={};updateSCMUnderlayDisplay(state.z);
end
function refreshRegistered2DUnderlays()
    if ~state.isAtlasWarped || (isfield(state,'atlasUnderlayKey')&&~isempty(state.atlasUnderlayKey)),return;end
    files={state.atlasTransformFile};
    if state.isStepMotorAtlasWarped,files=state.stepMotorAtlasTransformFiles;end
    if state.isStepMotorAtlasWarped&&isfield(state,'stepMotorUnderlayBundle')&& ...
            ~isempty(state.stepMotorUnderlayBundle)&&strcmp(state.atlasTransformFile,state.stepMotorUnderlayBundle.folder)
        bundle=state.stepMotorUnderlayBundle;entries=bundle.entries;names=bundle.names;ctx=bundle.context;
    else
        [entries,names,ctx]=fusiAtlasUnderlayLibrary2D(files,[nY nX nZ]);
    end
    state.atlasInPlaneSpacingUm=[NaN NaN NaN];
    if isempty(entries),updateROIPhysicalSize();return;end
    state.atlasInPlaneSpacingUm=entries{1}.meta.voxelSizeUm;
    updateROIPhysicalSize();
    selected=1;
    for k=1:numel(entries)
        if (state.isColorUnderlay&&entries{k}.meta.isColor&&strcmp(entries{k}.grouping,'Detailed'))||(~state.isColorUnderlay&&strcmp(entries{k}.meta.atlasMode,'histology')),selected=k;end
    end
    setappdata(popAtlasChoice,'AtlasUnderlayEntries2D',entries);setappdata(popAtlasChoice,'AtlasRegionContext2D',ctx);
    setappdata(popAtlasChoice,'AtlasUnderlayFiles',{});
    set(popAtlasChoice,'String',names,'Value',selected,'Enable','on');
    state.atlasRegionSearch=ctx;
    if state.isColorUnderlay&&~isempty(ctx)
        state.regionLabelUnderlay=entries{selected}.meta.regionLabels;state.regionInfo=entries{selected}.meta.regionInfo;
    end
end
function result=underlayData()
    result=struct('PSC',PSC,'underlay',bg,'mask',passedMask,'maskIsInclude',passedMaskIsInclude, ...
        'isAtlasWarped',state.isAtlasWarped,'mapping',state.currentROIMapping,'regionLabels',state.regionLabelUnderlay, ...
        'roiDefinitions',{roiDefinitionsForCurrentView()}, ...
        'regionInfo',state.regionInfo,'atlasRegionSearch',state.atlasRegionSearch,'transformFile',state.atlasTransformFile, ...
        'imageGeometry',struct('xlim',ax.XLim,'ylim',ax.YLim,'aspect',ax.DataAspectRatio, ...
        'underlayX',hBG.XData,'underlayY',hBG.YData,'overlayX',hOV.XData,'overlayY',hOV.YData, ...
        'underlayTextureSize',size(hBG.CData,[1 2])),'displayRGB',hBG.CData);
end
function atlasUnderlayChoiceCB(~,~)
    entries=getappdata(popAtlasChoice,'AtlasUnderlayEntries2D');
    if ~isempty(entries)
        entry=entries{get(popAtlasChoice,'Value')};
        bg=entry.data;applyUnderlayMeta(entry.meta,bg);
        applyRecommendedUnderlayDisplayForModeLocal(entry.meta.atlasMode);
        state.atlasRegionSearch=getappdata(popAtlasChoice,'AtlasRegionContext2D');
        if entry.meta.isColor
            state.atlasRegionSearch.labels=entry.meta.regionLabels;state.atlasRegionSearch.info=entry.meta.regionInfo;
            state.atlasRegionSearch.provenance.grouping=entry.grouping;
        end
        setappdata(popAtlasChoice,'AtlasUnderlayEntries2D',entries);set(popAtlasChoice,'Enable','on');updateSCMUnderlayDisplay(state.z);computeSCM();return;
    end
    files=getappdata(popAtlasChoice,'AtlasUnderlayFiles');if isempty(files),return;end
    groups=getappdata(popAtlasChoice,'AtlasUnderlayGroupings');k=get(popAtlasChoice,'Value');
    loadNewUnderlayCB([],[],struct('file',files{k},'grouping',groups{k}));
end
function refreshAtlasUnderlayChoices(space)
    setappdata(popAtlasChoice,'AtlasUnderlayEntries2D',{});
    bundle=state.pendingAtlasUnderlay3D;
    [names,files,selected,groups]=fusiAtlasUnderlayChoices(bundle.file);
    if isempty(names),set(popAtlasChoice,'Enable','off');return;end
    set(popAtlasChoice,'String',names,'Value',selected,'Enable','on');
    setappdata(popAtlasChoice,'AtlasUnderlayFiles',files);
    setappdata(popAtlasChoice,'AtlasUnderlayGroupings',groups);
    if bundle.meta.isColor&&isfield(bundle.meta,'regionGrouping')
        selected=find(strcmp(files,bundle.file)&strcmp(groups,bundle.meta.regionGrouping),1);
        if ~isempty(selected),set(popAtlasChoice,'Value',selected);end
    end
    state.atlasRegionSearch=fusiAtlasSearchContext(bundle,space,state.atlasRegionSearch);
end
function loadAtlasUnderlayFolderCB(~,~)
    folder=uigetdir(getUnderlayStartPathFast(),'Choose a saved atlas session or underlay folder');
    if isequal(folder,0),return;end
    % The folder button also accepts the dated 3D Histology/Regions bundle.
    for filename={'Histology.mat','Vascular.mat','Regions.mat'}
        file=fullfile(folder,filename{1});
        if isfile(file)
            contents=whos('-file',file);
            if ismember('atlasUnderlayMeta',{contents.name}),loadNewUnderlayCB([],[],file);return;end
        end
    end
    loadNewUnderlayCB([],[],folder);
end
function applyStepMotorUnderlayBundle(bundle)
    sourceCount=1;if ndims(origPSC)==4,sourceCount=size(origPSC,3);end
    assert(sourceCount==bundle.sourceNSlices,'deConfUSIon:StepMotorSourceMismatch', ...
        'This registration was saved for %d source slices; the current recording has %d.',bundle.sourceNSlices,sourceCount);
    [PSCnew,report]=warpFunctionalSeriesToAtlasStepMotor(origPSC,bundle.regList);
    state.stepMotorUnderlayBundle=bundle;
    PSC=PSCnew;passedMask=[];passedMaskIsInclude=true;
    state.isAtlasWarped=true;state.isStepMotorAtlasWarped=true;state.atlasUnderlayKey=[];state.pendingAtlasUnderlay3D=[];
    state.atlasTransformFile=bundle.folder;state.lastAtlasTransformFile=report.files{1};
    state.stepMotorAtlasFolder=bundle.folder;state.stepMotorAtlasTransformFiles=report.files;
    state.stepMotorAtlasSourceIdx=report.sourceIdx;state.stepMotorAtlasAtlasIdx=report.atlasIdx;
    entry=bundle.entries{bundle.selected};bg=entry.data;applyUnderlayMeta(entry.meta,bg);
    applyRecommendedUnderlayDisplayForModeLocal(entry.meta.atlasMode);
    state.atlasUnderlayChoice=entry.meta.atlasMode;
    setTitleAtlasStepMotor(report);resetRoisAndRefreshAfterDataChange(true);
    set(popAtlasChoice,'Value',bundle.selected);atlasUnderlayChoiceCB([],[]);
    set(btnWarpAtlas,'String','STEP MOTOR ATLAS-WARPED');
    set(info1,'String',sprintf('Loaded step-motor session: %d/%d source planes | %s', ...
        report.nUsed,sourceCount,bundle.names{bundle.selected}),'TooltipString',bundle.sessionFile);
end
function loadNewUnderlayCB(~,~,selectedFile)
    ensureUnderlayStateFields();
    groupingOverride='';
    if nargin>=3&&isstruct(selectedFile)
        groupingOverride=selectedFile.grouping;selectedFile=selectedFile.file;
    end
    if nargin<3 || isa(selectedFile,'function_handle')
    picker=[];if nargin>=3,picker=selectedFile;end
    lastFile='';if isfield(state,'lastUnderlayFile'),lastFile=state.lastUnderlayFile;end
    [fullf,options]=fusiChooseUnderlayFile(par,getDatasetRootForSelectors(),state.atlasTransformFile,lastFile,picker);
    setappdata(fig,'FUSIUnderlayPickerOptions',options);
    if isempty(fullf),return;end
    else,fullf=char(selectedFile);end
    try
        motorBundle=fusiReadStepMotorUnderlays2D(fullf);
        if ~isempty(motorBundle)
            applyStepMotorUnderlayBundle(motorBundle);state.lastUnderlayFile=fullf;return;
        elseif isfolder(fullf)
            warpFunctionalToAtlasStepMotorFolder(fullf);state.lastUnderlayFile=fullf;return;
        end
        [Uraw, meta] = readUnderlayFile(fullf);
        if isfield(meta,'registrationBundle3D') && meta.registrationBundle3D
            [Uraw,meta]=fusiAtlasRegroupUnderlay3D(Uraw,meta,groupingOverride);
            assert(isequal(double(meta.transform.scanGeometry.originalSize),double(size(origPSC,[1 2 3]))), ...
                'deConfUSIon:AtlasGeometryMismatch','This underlay was saved for a different native recording grid.');
            bundle=struct('file',fullf,'underlay',Uraw,'meta',meta);
            apply3DAtlasWarp(bundle);
            state.lastUnderlayFile=fullf;
            return;
        end
        state.lastUnderlayFile=fullf;
        if isfield(meta,'maskEditorBundle')
            applyMaskEditorBundleLocal(meta.maskEditorBundle, fullf);
            return;
        end
        Uraw = squeeze(Uraw);
        if isempty(Uraw) || ~(isnumeric(Uraw) || islogical(Uraw))
            error('Selected underlay is empty or not numeric/RGB: %s', fullf);
        end

        if state.isAtlasWarped
            if doesUnderlayMatchCurrentDisplay(Uraw)
                U = validateAndPrepareUnderlay(Uraw, fullf);
            elseif doesUnderlayMatchOriginalDisplay(Uraw)
                tfFile = getBestTransformForUnderlay(fullf, Uraw);
                if isempty(tfFile) || exist(tfFile,'file') ~= 2
                    error('Current SCM is atlas-warped, but no transform could be found to warp native underlay.');
                end
                S = load(tfFile); T = extractAtlasWarpStruct(S);
                U = warpUnderlayForCurrentDisplay(Uraw, T);
                U = validateAndPrepareUnderlay(U, fullf);
            else
                error('Selected underlay does not match current atlas display or original native display.');
            end
            bg = U; applyUnderlayMeta(meta, bg);
            refreshRegistered2DUnderlays();
            updateSCMUnderlayDisplay(state.z);
            set(info1, 'String', ['Loaded atlas-space underlay: ' shortenPath(fullf,85)], 'TooltipString', fullf);
            % DECONF_STD_SCM_LATE_FORCE_V9
try
    if exist('par','var') && isstruct(par) && isfield(par,'standardizedWorkflow') && par.standardizedWorkflow
        state.cax = [-100 100];
        state.signMode = 3;
        state.prevSignMode = 3;
% DECONF_STD_SCM_STATE_FORCE_V11
try
    if exist('par','var') && isstruct(par) && isfield(par,'standardizedWorkflow') && par.standardizedWorkflow
        if isfield(par,'standardCaxis') && numel(par.standardCaxis) == 2
            state.cax = double(par.standardCaxis(:)).';
        else
            state.cax = [-100 100];
        end
        state.alphaModOn = true;
        state.signMode = 3;
        state.prevSignMode = 3;
        if isfield(par,'standardModMinAbs') && isfinite(double(par.standardModMinAbs)), state.modMin = double(par.standardModMinAbs); else, state.modMin = -20; end
        if isfield(par,'standardModMaxAbs') && isfinite(double(par.standardModMaxAbs)), state.modMax = double(par.standardModMaxAbs); else, state.modMax = 20; end
    end
catch
end
        state.alphaModOn = true;
        state.modMin = -20;
        state.modMax = 20;
    end
catch
end
drawnow;
            return;
        end

       % ---------------------------------------------------------
% Important atlas/histology guard:
% If this file looks like an atlas/histology registration export,
% try to use its transform even if image size already matches native PSC.
% Otherwise SCM wrongly treats atlas-space histology as native underlay.
% ---------------------------------------------------------
if doesUnderlayMatchCurrentDisplay(Uraw)

    didAtlasApply = false;

    if isAtlasLikeUnderlayFile(fullf)
        tfFile0 = getBestTransformForUnderlay(fullf, Uraw);

        if ~isempty(tfFile0) && exist(tfFile0,'file') == 2
            try
           S0 = load(tfFile0);
T0 = extractAtlasWarpStruct(S0);
T0 = force2DOutputSizeFromTargetUnderlay(T0, Uraw);
T0 = askAndApply2DWarpDirection(T0, 'Atlas/histology underlay warp');

                if doesUnderlayMatchTransformOutput(Uraw, T0)
                    PSC = warpFunctionalSeriesToAtlas(origPSC, T0);

                    passedMask = [];
                    passedMaskIsInclude = true;

                    state.isAtlasWarped = true;
                    state.atlasTransformFile = tfFile0;
                    state.lastAtlasTransformFile = tfFile0;

                    bg = validateAndPrepareUnderlay(Uraw, fullf);
                    applyUnderlayMeta(meta, bg);

                    try
                        set(btnWarpAtlas, 'String', 'ALREADY WARPED TO ATLAS');
                    catch
                    end

                    setTitleAtlas(T0);
                    resetRoisAndRefreshAfterDataChange(true);

                    set(info1, 'String', ...
                        ['Loaded atlas/histology underlay and warped functional: ' shortenPath(fullf,70)], ...
                        'TooltipString', fullf);

                    didAtlasApply = true;
                    % DECONF_STD_SCM_LATE_FORCE_V9
try
    if exist('par','var') && isstruct(par) && isfield(par,'standardizedWorkflow') && par.standardizedWorkflow
        state.cax = [-100 100];
        state.signMode = 3;
        state.prevSignMode = 3;
% DECONF_STD_SCM_STATE_FORCE_V11
try
    if exist('par','var') && isstruct(par) && isfield(par,'standardizedWorkflow') && par.standardizedWorkflow
        if isfield(par,'standardCaxis') && numel(par.standardCaxis) == 2
            state.cax = double(par.standardCaxis(:)).';
        else
            state.cax = [-100 100];
        end
        state.alphaModOn = true;
        state.signMode = 3;
        state.prevSignMode = 3;
        if isfield(par,'standardModMinAbs') && isfinite(double(par.standardModMinAbs)), state.modMin = double(par.standardModMinAbs); else, state.modMin = -20; end
        if isfield(par,'standardModMaxAbs') && isfinite(double(par.standardModMaxAbs)), state.modMax = double(par.standardModMaxAbs); else, state.modMax = 20; end
    end
catch
end
        state.alphaModOn = true;
        state.modMin = -20;
        state.modMax = 20;
    end
catch
end
drawnow;
                    return;
                end

            catch MEatlas
                % Fall through to normal native underlay loading.
                try
                    set(info1, 'String', ...
                        ['Atlas-like file found, but transform use failed: ' MEatlas.message], ...
                        'TooltipString', fullf);
                catch
                end
            end
        end
    end

    if ~didAtlasApply
        bg = validateAndPrepareUnderlay(Uraw, fullf);
        applyUnderlayMeta(meta, bg);
        origBG = bg;
        updateSCMUnderlayDisplay(state.z);
        set(info1, 'String', ['Loaded native underlay: ' shortenPath(fullf,85)], 'TooltipString', fullf);
        % DECONF_STD_SCM_LATE_FORCE_V9
try
    if exist('par','var') && isstruct(par) && isfield(par,'standardizedWorkflow') && par.standardizedWorkflow
        state.cax = [-100 100];
        state.signMode = 3;
        state.prevSignMode = 3;
% DECONF_STD_SCM_STATE_FORCE_V11
try
    if exist('par','var') && isstruct(par) && isfield(par,'standardizedWorkflow') && par.standardizedWorkflow
        if isfield(par,'standardCaxis') && numel(par.standardCaxis) == 2
            state.cax = double(par.standardCaxis(:)).';
        else
            state.cax = [-100 100];
        end
        state.alphaModOn = true;
        state.signMode = 3;
        state.prevSignMode = 3;
        if isfield(par,'standardModMinAbs') && isfinite(double(par.standardModMinAbs)), state.modMin = double(par.standardModMinAbs); else, state.modMin = -20; end
        if isfield(par,'standardModMaxAbs') && isfinite(double(par.standardModMaxAbs)), state.modMax = double(par.standardModMaxAbs); else, state.modMax = 20; end
    end
catch
end
        state.alphaModOn = true;
        state.modMin = -20;
        state.modMax = 20;
    end
catch
end
drawnow;
        return;
    end
end

        tfFile = getBestTransformForUnderlay(fullf, Uraw);
        if isempty(tfFile) || exist(tfFile,'file') ~= 2
            [ft,pt] = uigetfileStartIn({'*.mat','Transform files (*.mat)'}, ...
                sprintf('Auto-detection failed. Select transform file manually.\nExamples: CoronalRegistration2D*.mat or Transformation*.mat'), ...
                getTransformStartPath());
            if isequal(ft,0), return; end
            tfFile = fullfile(pt,ft);
        end
       S = load(tfFile);
T = extractAtlasWarpStruct(S);
T = force2DOutputSizeFromTargetUnderlay(T, Uraw);
T = askAndApply2DWarpDirection(T, 'Atlas/histology underlay warp');
        if ~doesUnderlayMatchTransformOutput(Uraw, T)
            error(['Selected underlay size [%d %d] does not match current native SCM size [%d %d] ' ...
                   'and also does not match transform output size.'], size(Uraw,1), size(Uraw,2), nY, nX);
        end
        PSC = warpFunctionalSeriesToAtlas(origPSC, T);
        passedMask = [];
        passedMaskIsInclude = true;
        state.isAtlasWarped = true;
        state.atlasTransformFile = tfFile;
        state.lastAtlasTransformFile = tfFile;
        try, set(btnWarpAtlas, 'String', 'ALREADY WARPED TO ATLAS'); catch, end
        bg = validateAndPrepareUnderlay(Uraw, fullf);
        applyUnderlayMeta(meta, bg);
        resetRoisAndRefreshAfterDataChange(true);
        updateSCMUnderlayDisplay(state.z);
        setTitleAtlas(T);
        set(info1, 'String', ['Loaded atlas underlay and warped functional: ' shortenPath(fullf,70)], 'TooltipString', fullf);
        % DECONF_STD_SCM_LATE_FORCE_V9
try
    if exist('par','var') && isstruct(par) && isfield(par,'standardizedWorkflow') && par.standardizedWorkflow
        state.cax = [-100 100];
        state.signMode = 3;
        state.prevSignMode = 3;
% DECONF_STD_SCM_STATE_FORCE_V11
try
    if exist('par','var') && isstruct(par) && isfield(par,'standardizedWorkflow') && par.standardizedWorkflow
        if isfield(par,'standardCaxis') && numel(par.standardCaxis) == 2
            state.cax = double(par.standardCaxis(:)).';
        else
            state.cax = [-100 100];
        end
        state.alphaModOn = true;
        state.signMode = 3;
        state.prevSignMode = 3;
        if isfield(par,'standardModMinAbs') && isfinite(double(par.standardModMinAbs)), state.modMin = double(par.standardModMinAbs); else, state.modMin = -20; end
        if isfield(par,'standardModMaxAbs') && isfinite(double(par.standardModMaxAbs)), state.modMax = double(par.standardModMaxAbs); else, state.modMax = 20; end
    end
catch
end
        state.alphaModOn = true;
        state.modMin = -20;
        state.modMax = 20;
    end
catch
end
drawnow;
    catch ME
        if nargin>=3,rethrow(ME);end
        errordlg(ME.message, 'Load underlay failed');
    end
end

%% ==========================================================
% ATLAS WARP
%% ==========================================================
function warpFunctionalToAtlasCB(source,~,selectedFile)
    try
        if nargin<3,selectedFile='';end
        bundle=[];
        picker=[];
        if nargin>=3&&isa(selectedFile,'function_handle'),picker=selectedFile;selectedFile='';end
        % Real button clicks always ask which 3D transform to use. Discovery
        % only supplies the initial folder; it must not apply an affine.
        hasPaired3D=isfield(state,'pendingAtlasUnderlay3D')&&~isempty(state.pendingAtlasUnderlay3D);
        if ~isempty(picker)||(nargin<3&&isgraphics(source)&&hasPaired3D)
            lastFile='';if isfield(state,'lastUnderlayFile'),lastFile=state.lastUnderlayFile;end
            [selectedFile,options]=fusiChooseAtlasTransformFile(par,getDatasetRootForSelectors(), ...
                state.atlasTransformFile,lastFile,picker);
            setappdata(fig,'FUSIAtlasTransformPickerOptions',options);
            if isempty(selectedFile),return;end
        end
        if ~isempty(selectedFile)
            if isfolder(selectedFile),warpFunctionalToAtlasStepMotorFolder(char(selectedFile));return;end
            motorBundle=fusiReadStepMotorUnderlays2D(selectedFile);
            if ~isempty(motorBundle),applyStepMotorUnderlayBundle(motorBundle);return;end
            selectedPayload=load(selectedFile);selectedTransform=extractAtlasWarpStruct(selectedPayload);
            if isfield(selectedTransform,'type')&&strcmpi(selectedTransform.type,'simple_coronal_2d')
                selectedTransform=askAndApply2DWarpDirection(selectedTransform,'Saved coronal registration');
                PSC=warpFunctionalSeriesToAtlas(origPSC,selectedTransform);
                state.isAtlasWarped=true;state.isStepMotorAtlasWarped=false;state.atlasUnderlayKey=[];
                state.atlasTransformFile=char(selectedFile);state.lastAtlasTransformFile=char(selectedFile);
                bg=makeFunctionalContrastFallbackUnderlay(PSC);
                resetRoisAndRefreshAfterDataChange(true);
                entries=getappdata(popAtlasChoice,'AtlasUnderlayEntries2D');
                if ~isempty(entries),atlasUnderlayChoiceCB([],[]);end
                return;
            end
            bundle=fusiFindAtlasUnderlay3D(par,getDatasetRootForSelectors(),selectedFile,'',size(origPSC,[1 2 3]));
            assert(~isempty(bundle),'deConfUSIon:AtlasGeometryMismatch','No matching saved 3D alignment was found in this file.');
        elseif isfield(state,'pendingAtlasUnderlay3D') && ~isempty(state.pendingAtlasUnderlay3D),bundle=state.pendingAtlasUnderlay3D;
        elseif size(origPSC,3)>1
            lastFile='';if isfield(state,'lastUnderlayFile'),lastFile=state.lastUnderlayFile;end
            bundle=fusiFindAtlasUnderlay3D(par,getDatasetRootForSelectors(),state.atlasTransformFile,lastFile,size(origPSC,[1 2 3]));
        end
        if ~isempty(bundle)
            if nargin<3&&isgraphics(source)&&~hasPaired3D
                [file,options]=fusiChooseAtlasTransformFile(par,getDatasetRootForSelectors(), ...
                    fusiAtlasPairedTransformFile(bundle.meta,bundle.file),bundle.file);
                setappdata(fig,'FUSIAtlasTransformPickerOptions',options);if isempty(file),return;end
                bundle=fusiFindAtlasUnderlay3D(par,getDatasetRootForSelectors(),file,bundle.file,size(origPSC,[1 2 3]));
                assert(~isempty(bundle),'deConfUSIon:AtlasGeometryMismatch','The selected transform does not match this native recording grid.');
            end
            apply3DAtlasWarp(bundle);return;
        end
    catch ME
        setappdata(fig,'FUSIAtlasWarpLastError',ME);if nargin>=3,rethrow(ME);end
        errordlg(ME.message,'3D atlas warp failed');return;
    end
    state.atlasUnderlayKey=[];

    if state.isAtlasWarped
        choice0 = questdlg(['Functional data is already in atlas space.' newline newline ...
            'Reapply atlas warp from original native PSC?'], ...
            'Already atlas-warped', ...
            'Reapply from native', 'Cancel', 'Cancel');

        if isempty(choice0) || strcmpi(choice0,'Cancel')
            return;
        end
    end

    % For step-motor / multi-slice data, default to folder mode.
    if nZ > 1
        defaultMode = 'Step Motor folder';
    else
        defaultMode = 'Single transform';
    end

    modeChoice = questdlg([ ...
        'Choose atlas warp mode:' newline newline ...
        'Single transform:' newline ...
        '  Uses one CoronalRegistration2D / Transformation MAT file.' newline ...
        '  For 4D data with a 2D transform, this warps only one source slice.' newline newline ...
        'Step Motor folder:' newline ...
        '  Select a folder. SCM searches all MAT files inside it.' newline ...
        '  Files are matched by source001, source002, slice001, etc.' newline ...
        '  Each transform is applied to the matching functional slice.'], ...
        'Warp functional to atlas', ...
        'Single transform', 'Step Motor folder', 'Cancel', defaultMode);

    if isempty(modeChoice) || strcmpi(modeChoice,'Cancel')
        return;
    end

    if strcmpi(modeChoice,'Step Motor folder')
        warpFunctionalToAtlasStepMotorFolder();
    else
        warpFunctionalToAtlasSingleFile();
    end
end

function warpFunctionalToAtlasSingleFile()

    startDir = getTransformStartPath();

    [f,p] = uigetfileStartIn({'*.mat','Transform files (*.mat)'}, ...
        'Select atlas Transformation / CoronalRegistration2D', startDir);

    if isequal(f,0)
        return;
    end

    try
        tfFile = fullfile(p,f);

        S = load(tfFile);
T = extractAtlasWarpStruct(S);
if isfield(T,'scanGeometry') && strcmp(T.scanGeometry.convention,'coronal_stack_v2')
    bundle=fusiFindAtlasUnderlay3D(par,getDatasetRootForSelectors(),tfFile,'',size(origPSC,[1 2 3]));
    assert(~isempty(bundle),'deConfUSIon:AtlasGeometryMismatch','The 3D transform does not match this recording.');
    apply3DAtlasWarp(bundle);return;
end
T = askAndApply2DWarpDirection(T, 'Single atlas warp');

PSC = warpFunctionalSeriesToAtlas(origPSC, T);

        state.atlasUnderlayChoice = askAtlasUnderlayChoiceLocal('single');
        [state.atlasUnderlays, bgAuto, bgMsg, metaAuto] = buildAtlasUnderlayLibrarySingleLocal(tfFile, T, PSC, state.atlasUnderlayChoice);
        if ~isempty(bgAuto)
            bg = bgAuto;
            applyUnderlayMeta(metaAuto, bg);
            applyRecommendedUnderlayDisplayForModeLocal(state.atlasUnderlayChoice);
            state.lastAtlasUnderlayBuildMessage = bgMsg;
        end

        passedMask = [];
        passedMaskIsInclude = true;

        state.isAtlasWarped = true;
        state.isStepMotorAtlasWarped = false;

        state.atlasTransformFile = tfFile;
        state.lastAtlasTransformFile = tfFile;

        state.stepMotorAtlasFolder = '';
        state.stepMotorAtlasTransformFiles = {};
        state.stepMotorAtlasSourceIdx = [];
        state.stepMotorAtlasAtlasIdx = [];

        try
            set(btnWarpAtlas, 'String', 'ALREADY WARPED TO ATLAS');
        catch
        end

        setTitleAtlas(T);
        resetRoisAndRefreshAfterDataChange(true);

        msg = 'Functional data warped to atlas.';

        if isfield(T,'type') && strcmpi(char(T.type), 'simple_coronal_2d')
            msg = 'Functional data warped with 2D coronal registration.';
        end

        set(info1, 'String', msg, 'TooltipString', tfFile);

    catch ME
        errordlg(ME.message, 'Atlas warp failed');
    end
end


function warpFunctionalToAtlasStepMotorFolder(folderPath)

    startDir = getStepMotorTransformStartPath();

    if nargin<1
    folderPath = uigetdir(startDir, ...
        'Select Step Motor Registration2D folder containing source001/source002 transforms');
    end

    if isequal(folderPath,0)
        return;
    end

    try
        motorBundle=fusiReadStepMotorUnderlays2D(folderPath);
        if ~isempty(motorBundle),applyStepMotorUnderlayBundle(motorBundle);return;end
        state.stepMotorUnderlayBundle=[];
        regList = collectStepMotorRegistration2DTransforms(folderPath);
regList = askAndApply2DWarpDirectionToRegList(regList, 'Step Motor atlas warp');
        if isempty(regList)
            error(['No valid Step Motor Registration2D transforms found in:' newline ...
                   folderPath newline newline ...
                   'Expected files like:' newline ...
                   '  CoronalRegistration2D_source001_atlas112_histology.mat' newline ...
                   '  CoronalRegistration2D_source002_atlas115_histology.mat' newline ...
                   'or filenames containing source001 / source002 / slice001.']);
        end

        if ndims(origPSC) == 4
            nSourceSlices = size(origPSC,3);
        else
            nSourceSlices = 1;
        end

        foundIdx = [regList.sourceIdx];
        foundIdx = foundIdx(isfinite(foundIdx));
        foundIdx = unique(foundIdx(:).');

        missingIdx = setdiff(1:nSourceSlices, foundIdx);

        if nSourceSlices > 1 && ~isempty(missingIdx)
            msg = sprintf([ ...
                'Found transforms for %d/%d source slices.\n\n' ...
                'Found source slices:\n%s\n\n' ...
                'Missing source slices:\n%s\n\n' ...
                'Continue using only the found slices?'], ...
                numel(foundIdx), nSourceSlices, ...
                compactIndexList(foundIdx), ...
                compactIndexList(missingIdx));

            ch = questdlg(msg, ...
                'Missing Step Motor transforms', ...
                'Continue', 'Cancel', 'Cancel');

            if isempty(ch) || strcmpi(ch,'Cancel')
                return;
            end
        end

        [PSCnew, report] = warpFunctionalSeriesToAtlasStepMotor(origPSC, regList);

        if isempty(PSCnew) || report.nUsed < 1
            error('No slices were warped. Check source001/source002 numbering and transform files.');
        end

        PSC = PSCnew;

        passedMask = [];
        passedMaskIsInclude = true;

        state.isAtlasWarped = true;
        state.isStepMotorAtlasWarped = true;

        state.atlasTransformFile = folderPath;
        state.lastAtlasTransformFile = report.files{1};

        state.stepMotorAtlasFolder = folderPath;
        state.stepMotorAtlasTransformFiles = report.files;
        state.stepMotorAtlasSourceIdx = report.sourceIdx;
        state.stepMotorAtlasAtlasIdx = report.atlasIdx;

       % ---------------------------------------------------------
% Build ALL atlas underlay choices for Step Motor atlas-space SCM.
% The displayed underlay is user-selected, but all modes are saved later.
if nargin<1,state.atlasUnderlayChoice=askAtlasUnderlayChoiceLocal('step-motor');
else,state.atlasUnderlayChoice='histology';end
[state.atlasUnderlays, bgNew, bgMsg, metaNew] = buildAtlasUnderlayLibraryStepMotorLocal(report.usedRegList, report.outSize, PSCnew, bg, state.atlasUnderlayChoice);
if isempty(bgNew)
    bgNew = makeFunctionalContrastFallbackUnderlay(PSCnew);
    bgMsg = 'functional contrast fallback; no atlas underlay was readable';
    metaNew = defaultUnderlayMeta();
end
bg = bgNew;
applyUnderlayMeta(metaNew, bg);
applyRecommendedUnderlayDisplayForModeLocal(state.atlasUnderlayChoice);
state.lastAtlasUnderlayBuildMessage = bgMsg;
        try
            set(btnWarpAtlas, 'String', 'STEP MOTOR ATLAS-WARPED');
        catch
        end

        setTitleAtlasStepMotor(report);
        resetRoisAndRefreshAfterDataChange(true);

       msg = sprintf('Step Motor atlas warp complete: %d slices warped. Underlay: %s', report.nUsed, bgMsg);
        set(info1, 'String', msg, 'TooltipString', folderPath);

    catch ME
        errordlg(ME.message, 'Step Motor atlas warp failed');
    end
end

function resetWarpToNativeCB(~,~)
    try
        PSC = origPSC;
        bg = origBG;
        applyUnderlayMeta(defaultUnderlayMeta(),bg);
        passedMask = origPassedMask;
        passedMaskIsInclude = origPassedMaskIsInclude;
       state.isAtlasWarped = false;
state.isStepMotorAtlasWarped = false;

state.atlasTransformFile = '';
state.lastAtlasTransformFile = '';
state.atlasUnderlayKey=[];state.atlasSliceSampling=[];

state.stepMotorAtlasFolder = '';
state.stepMotorAtlasTransformFiles = {};
state.stepMotorAtlasSourceIdx = [];
state.stepMotorAtlasAtlasIdx = [];
        try, set(btnWarpAtlas, 'String', 'WARP FUNCTIONAL TO ATLAS'); catch, end
        set(txtTitle, 'String', fileLabel);
        resetRoisAndRefreshAfterDataChange(true);
        retained=getappdata(fig,'SCMROIDefinitions');
        set(info1, 'String', sprintf('Returned to native functional space. Retained %d ROIs; mapped masks remain one ROI across slices.',numel(retained)), 'TooltipString', '');
    catch ME
        errordlg(ME.message, 'Reset to native failed');
    end
end

function setTitleAtlas(T)
    try
        if isfield(T,'type') && strcmpi(char(T.type), 'simple_coronal_2d') && ...
                isfield(T,'atlasSliceIndex') && isfinite(T.atlasSliceIndex)
            set(txtTitle, 'String', sprintf('%s | warped to atlas coronal slice %d', fileLabel, round(T.atlasSliceIndex)));
        else
            set(txtTitle, 'String', sprintf('%s | warped to atlas', fileLabel));
        end
    catch
        set(txtTitle, 'String', sprintf('%s | warped to atlas', fileLabel));
    end
end

function resetRoisAndRefreshAfterDataChange(preserveROIs)
    if nargin<1,preserveROIs=false;end
    state.referenceTraceCache={};
    definitions={};targetKey='native';mapping=[];
    if state.isAtlasWarped,targetKey=['atlas|' state.atlasTransformFile];mapping=state.currentROIMapping;
    else,mapping=roi.viewMapping;end
    if preserveROIs
        definitions=roiDefinitionsForCurrentView();
        same=cellfun(@(b)strcmp(b.key,roi.viewKey)&&isequal(b.shape,roi.viewShape),roi.viewBanks);roi.viewBanks(same)=[];
        roi.viewBanks{end+1}=struct('key',roi.viewKey,'shape',roi.viewShape,'definitions',{definitions});
        if numel(roi.viewBanks)>8,roi.viewBanks(1)=[];end
    else,roi.viewBanks={};roi.hiddenDefinitions={};end
    closeCandidateReviews();
    setappdata(fig,'AutomaticROISelections',{});
    state.baseKey=[]; state.signalKey=[];
    refreshDimsAfterPSCChange();
    refreshRegistered2DUnderlays();
    syncSCMImageGeometry();
    ROI_byZ = cell(1, nZ);
    for zzi = 1:nZ
        ROI_byZ{zzi} = struct('id', {}, 'x1', {}, 'x2', {}, 'y1', {}, 'y2', {}, 'color', {});
    end
    if preserveROIs
        targetShape=[nY nX nZ];restored={};remaining=definitions;
        for bi=numel(roi.viewBanks):-1:1
            bank=roi.viewBanks{bi};if ~strcmp(bank.key,targetKey)||~isequal(bank.shape,targetShape),continue;end
            for di=numel(remaining):-1:1
                match=find(cellfun(@(c)c.roiId==remaining{di}.roiId,bank.definitions),1);
                if ~isempty(match),restored{end+1}=bank.definitions{match};remaining(di)=[];end %#ok<AGROW>
            end
            break;
        end
        if ~isempty(remaining)
            sourceShape=roi.viewShape;
            if startsWith(roi.viewKey,'atlas|')&&state.isAtlasWarped
                nativeShape=[size(origPSC,1) size(origPSC,2) 1];if ndims(origPSC)==4,nativeShape(3)=size(origPSC,3);end
                remaining=scmROI('map',remaining,sourceShape,nativeShape,roi.viewMapping,true,[NaN NaN NaN]);sourceShape=nativeShape;
            end
            restored=[restored scmROI('map',remaining,sourceShape,targetShape,mapping,~state.isAtlasWarped,currentROISpacingUm())];
        end
        installROIDefinitions(restored);
        roi.viewKey=targetKey;roi.viewShape=targetShape;roi.viewMapping=mapping;
    else
        roi.nextId = 1;roi.sizingById={};roi.viewKey=targetKey;roi.viewShape=[nY nX nZ];roi.viewMapping=mapping;
    end
    roi.exportedIds = []; setHoverActive(isempty(definitions));
    deleteIfValid(roiHandles); roiHandles = gobjects(0);
    deleteIfValid(roiPlotPSC); roiPlotPSC = gobjects(0);
    deleteIfValid(roiTextHandles); roiTextHandles = gobjects(0);
    mask2D = getMaskForCurrentSlice();
    if isgraphics(slZ)
        set(slZ, 'Min', 1, 'Max', max(1,nZ), 'Value', nZ-state.z+1, ...
            'SliderStep', [1/max(1,max(1,nZ-1)) 5/max(1,max(1,nZ-1))], ...
            'Visible', 'off', 'Enable', 'off');
    end
    if isgraphics(txtZ), set(txtZ, 'String', '', 'Visible', 'off'); end
    updateSliceIndicators();
    set(hLiveRect, 'Visible', 'off');
    set(hLivePSC, 'XData', state.tminHover, 'YData', nan(1,numel(state.tminHover)), 'Visible', 'off');
    set(hRoiCoordTxt, 'Visible', 'off', 'String', '');
    updateSCMUnderlayDisplay(state.z);
    set(hOV, 'CData', zeros(nY,nX), 'AlphaData', zeros(nY,nX));
    updateInfoLines(); computeSCM(); redrawROIsForCurrentSlice(); % DECONF_STD_SCM_LATE_FORCE_V9
try
    if exist('par','var') && isstruct(par) && isfield(par,'standardizedWorkflow') && par.standardizedWorkflow
        state.cax = [-100 100];
        state.signMode = 3;
        state.prevSignMode = 3;
% DECONF_STD_SCM_STATE_FORCE_V11
try
    if exist('par','var') && isstruct(par) && isfield(par,'standardizedWorkflow') && par.standardizedWorkflow
        if isfield(par,'standardCaxis') && numel(par.standardCaxis) == 2
            state.cax = double(par.standardCaxis(:)).';
        else
            state.cax = [-100 100];
        end
        state.alphaModOn = true;
        state.signMode = 3;
        state.prevSignMode = 3;
        if isfield(par,'standardModMinAbs') && isfinite(double(par.standardModMinAbs)), state.modMin = double(par.standardModMinAbs); else, state.modMin = -20; end
        if isfield(par,'standardModMaxAbs') && isfinite(double(par.standardModMaxAbs)), state.modMax = double(par.standardModMaxAbs); else, state.modMax = 20; end
    end
catch
end
        state.alphaModOn = true;
        state.modMin = -20;
        state.modMax = 20;
    end
catch
end
drawnow;
end

function definitions=roiDefinitionsForCurrentView()
    definitions=roi.hiddenDefinitions;audit=scmAutomaticROISelections(fig);seen=[];
    for zz=1:numel(ROI_byZ)
        for mark=ROI_byZ{zz}
            if ismember(mark.id,seen),continue;end;seen(end+1)=mark.id; %#ok<AGROW>
            c=[];for ai=1:numel(audit),if audit{ai}.roiId==mark.id,c=audit{ai};break;end,end
            automatic=~isempty(c);
            if isempty(c)&&numel(roi.sizingById)>=mark.id,c=roi.sizingById{mark.id};end
            if isempty(c),c=struct('boundsXY',[mark.x1 mark.x2 mark.y1 mark.y2]);end
            c.roiId=mark.id;c.color=mark.color;c.sourceAutomatic=automatic;
            if ~isfield(c,'slice'),c.slice=zz;end
            if ~isfield(c,'activeSlices'),c.activeSlices=zz;end
            definitions{end+1}=c; %#ok<AGROW>
        end
    end
end
function installROIDefinitions(definitions)
    roi.hiddenDefinitions={};audit={};
    for di=1:numel(definitions)
        c=definitions{di};
        if isfield(c,'roiMaskVolumeIndices')&&isempty(c.roiMaskVolumeIndices)
            roi.hiddenDefinitions{end+1}=c;continue; %#ok<AGROW>
        end
        slices=c.slice;if isfield(c,'activeSlices'),slices=c.activeSlices;end
        for zz=slices
            m=scmROI('mask',c,zz,[nY nX nZ]);[yy,xx]=find(m);if isempty(xx),continue;end
            ROI_byZ{zz}(end+1)=struct('id',c.roiId,'x1',min(xx),'x2',max(xx),'y1',min(yy),'y2',max(yy),'color',c.color);
        end
        if c.sourceAutomatic
            if isfield(c,'roiMaskVolumeIndices')
                trace=scmROI('trace',PSC,c);c.meanPSC=mean(trace(c.signalFrames));
            end
            audit{end+1}=c; %#ok<AGROW>
        else,roi.sizingById{c.roiId}=c;end
    end
    setappdata(fig,'AutomaticROISelections',audit);
    if ~isempty(definitions),roi.nextId=max(roi.nextId,1+max(cellfun(@(c)c.roiId,definitions)));end
    setappdata(fig,'SCMROIDefinitions',definitions);
end

function autoFixStartupAtlasUnderlayIfNeeded()
    try
        if isempty(bg) || ~(isnumeric(bg) || islogical(bg)), return; end
        U = squeeze(bg);
        if isempty(U) || ndims(U) < 2, return; end
       % Do not automatically return only because the pixel size matches.
% Atlas/histology exports can have the same pixel dimensions as native data
% but still be in atlas coordinates.
sameSizeAsFunctional = (size(U,1) == nY && size(U,2) == nX);

if sameSizeAsFunctional
    % Without a filename, startup auto-fix cannot safely know whether this is
    % native or atlas space. Therefore keep it native here.
    % Atlas-like files loaded via LOAD NEW UNDERLAY are handled in loadNewUnderlayCB.
    return;
end
        tfFile = getBestTransformForUnderlay('', U);
        if isempty(tfFile) || exist(tfFile,'file') ~= 2
            startupAtlasNote = ['Startup underlay size did not match PSC, but no atlas transform was found. Using fallback native underlay.'];
            bg = makeNativeFallbackUnderlayFromPSC(origPSC);
            return;
        end
        S = load(tfFile); T = extractAtlasWarpStruct(S);
        if ~doesUnderlayMatchTransformOutput(U, T)
            startupAtlasNote = ['Startup underlay did not match PSC size or transform output. Using fallback native underlay.'];
            bg = makeNativeFallbackUnderlayFromPSC(origPSC);
            return;
        end
        PSC = warpFunctionalSeriesToAtlas(origPSC, T);
        state.isAtlasWarped = true;
        state.atlasTransformFile = tfFile;
        state.lastAtlasTransformFile = tfFile;
        refreshDimsAfterPSCChange();
        bg = validateAndPrepareUnderlay(U, 'startup underlay');
        applyUnderlayMeta(defaultUnderlayMeta(), bg);
        startupAtlasNote = ['Startup atlas underlay detected. Functional data auto-warped using: ' tfFile];
    catch ME
        startupAtlasNote = ['Startup atlas guard failed: ' ME.message];
        try, bg = makeNativeFallbackUnderlayFromPSC(origPSC); catch, end
    end
end

function refreshDimsAfterPSCChange()
    dNow = ndims(PSC);
    if dNow == 3
        [nY, nX, nT] = size(PSC); nZ = 1;
    elseif dNow == 4
        [nY, nX, nZ, nT] = size(PSC);
    else
        error('PSC must be [Y X T] or [Y X Z T].');
    end
    tsec = (0:nT-1) * TR;
    tmin = tsec / 60;
    displayEndMin=max(tmin);
    if isfield(par,'displayDurationSec') && isfiniteScalar(par.displayDurationSec) && par.displayDurationSec>=tsec(end)
        displayEndMin=par.displayDurationSec/60;
    end
    state.hoverStride = max(1, ceil(nT / state.hoverMaxPts));
    state.hoverIdx = 1:state.hoverStride:nT;
    state.tminHover = tmin(state.hoverIdx);
    state.z = max(1, min(state.z, nZ));
    state.lastSignedMap = zeros(nY, nX);
    state.timeWindowKey=[];
    roi.lastHoverXY=[-inf -inf];
    roi.pendingHover=[];
    roi.hoverStats=[];
end

function syncSCMImageGeometry()
    % A changed CData size does not update an image object's coordinate span.
    % Both layers must share the complete current grid, including atlas edges.
    xData=[1 nX];yData=[1 nY];
    if ~isempty(state.atlasDisplay3D)
        xData=state.atlasDisplay3D.xData;yData=state.atlasDisplay3D.yData;
    end
    set(hBG,'XData',xData,'YData',yData);
    set(hOV,'XData',[1 nX],'YData',[1 nY]);
    aspect=1;
    if ~isempty(state.atlasDisplay3D)
        spacing=state.atlasDisplay3D.spacingUm;aspect=spacing(2)/spacing(1);
    elseif state.isAtlasWarped || state.isStepMotorAtlasWarped
        % Mask/native underlay textures can clear the atlas texture provider.
        % Their pixels still belong to the current functional atlas grid.
        spacing=currentROISpacingUm();
        if all(isfinite(spacing(1:2)) & spacing(1:2)>0),aspect=spacing(2)/spacing(1);end
    elseif nZ>1
        aspect=deConfUSIon_utils('deConfUSIon_view_aspect',par);
    end
    if ~isequal(ax.XLim,xData+[-.5 .5]),set(ax,'XLim',xData+[-.5 .5]);end
    if ~isequal(ax.YLim,yData+[-.5 .5]),set(ax,'YLim',yData+[-.5 .5]);end
    set(ax,'YDir','reverse','DataAspectRatio',[1 aspect 1],'PlotBoxAspectRatioMode','auto','Color','k');
    if ~state.physicalScale,set(ax,'DataAspectRatio',[1 1 1]);end
    interpolation='bilinear';if state.sharpPixels,interpolation='nearest';end
    for imageHandle=[hBG hOV],if isprop(imageHandle,'Interpolation'),set(imageHandle,'Interpolation',interpolation);end,end
end

%% ==========================================================
% EXPORTS
%% ==========================================================
function automaticAnalysisCB(~,~)
    choice=questdlg('Find and review peak ROIs (current or all slices), or load a fixed protocol?', ...
        'Automatic analysis','Find and review ROI','Load fixed protocol','Cancel','Find and review ROI');
    if strcmp(choice,'Find and review ROI'), automaticPeakROI(); return; end
    if ~strcmp(choice,'Load fixed protocol'), return; end
    [name,folder]=uigetfile('*.json','Select a prespecified Automatic SCM protocol');
    if isequal(name,0), return; end
    set(btnAutomatic,'Enable','off');
    guard=onCleanup(@()set(btnAutomatic,'Enable','on')); %#ok<NASGU>
    try
        P=getSimpleExportPaths();
        protocol=jsondecode(fileread(fullfile(folder,name)));
        if fusiBaselineReference('isExternal',baseline),protocol.baselineMode='external';protocol.baselineReference=baseline.reference;end
        result=AutomaticSCM(PSC,TR,protocol,fullfile(P.roiDir,'Automatic'),fileLabel);
        msgbox(sprintf(['Fixed target/control ROI traces exported to:\n%s\n\n' ...
            'Protocol coordinates must have been chosen independently of this response, on the matching anatomy. ' ...
            'Display alpha and color range do not affect these measurements.'],result.outputFolder), ...
            'Automatic analysis complete');
    catch ME
        errordlg(ME.message,'Automatic analysis');
    end
end

function automaticPeakROI(useAwakePreset)
    if nargin<1, useAwakePreset=false; end
    if isappdata(fig,'AutomaticROILastError'),rmappdata(fig,'AutomaticROILastError');end
    [s0,s1]=parseRangeSafe(getStr(ebSig),360,540);
    if isVolMode, s0=(s0-1)*TR; s1=(s1-1)*TR; end
    try, [b0,b1]=selectedBaselineFrames();
    catch ME, errordlg(ME.message,'ROI search'); return; end
    ctx=struct('sizeYXZ',[nY nX nZ],'slice',state.z,'roiSize',roi.size, ...
        'baselineSec',tsec([b0 b1]),'signalSec',[s0 s1],'TR',TR,'nT',nT, ...
        'underlay',@currentUnderlayDisplayRGB,'underlayXData',hBG.XData,'underlayYData',hBG.YData, ...
        'mask',@(z)getMaskForSlice(z));
    ctx.spacingUm=currentROISpacingUm();ctx.sizeMode=roi.sizeMode;ctx.sizeUm=roi.sizeUm;ctx.viewAspect=ax.DataAspectRatio;
    if ~isempty(state.scanSequence)
        ctx.scanLabels=fusiScanSequence('labels',state.scanSequence);ctx.scanTiming=state.scanSequence.scans;
        ctx.originalScanIndex=find(cellfun(@(d)strcmp(d.key,state.originalScanKey),state.scanSequence.scans),1);
    end
    if ~isempty(state.atlasRegionSearch)
        ctx.atlasLabels=state.atlasRegionSearch.labels;ctx.atlasRegionInfo=state.atlasRegionSearch.info;
        ctx.atlasProvenance=state.atlasRegionSearch.provenance;
    elseif ~isempty(state.regionLabelUnderlay)&&isfield(state.regionInfo,'name')
        ctx.atlasLabels=state.regionLabelUnderlay;ctx.atlasRegionInfo=state.regionInfo;
    end
    if useAwakePreset
        [window,canSearch,note]=scmAwakeSearchWindow(TR,nT);
        setappdata(fig,'AwakeSearchStatus',note);
        if ~canSearch
            set(info1,'String',note,'TooltipString',note); return;
        end
        opt=struct('size',5,'signalSec',window,'plateauSec',180,'sharedWindow',true, ...
            'boundsXY',[1 nX 1 nY],'bilateral',true,'splitX',floor(nX/2),'leftIsTarget',true, ...
            'allSlices',true,'slice',state.z,'cleanDisplay',true,'polygons',{cell(nZ,2)});
        if isfield(ctx,'atlasLabels')
            opt.atlasLabels=ctx.atlasLabels;[~,opt.excludedAtlasIDs]=fusiAtlasRegionCatalog(ctx.atlasLabels,ctx.atlasRegionInfo);
            opt.atlasRegion=[];opt.minAtlasCoverage=.75;
            if isfield(ctx,'atlasProvenance'),opt.atlasProvenance=ctx.atlasProvenance;end
        end
    else
        ctx.plateauSec=180; ctx.roiSize=6; ctx.signalSec=[420 840];
        ctx.display=struct('caxis',sscanf(strrep(getStr(ebCax),',',' '),'%f')', ...
            'modMin',str2double(getStr(ebModMin)),'modMax',str2double(getStr(ebModMax)), ...
            'alphaPercent',get(slAlpha,'Value'),'signMode',get(popSignMode,'Value'));
        opt=scmAutoSearchDialog(ctx); if isempty(opt), return; end
    end
    n=opt.size; interval=opt.signalSec/60; cleanDisplay=opt.cleanDisplay;
    set(btnAutomatic,'Enable','off'); guard=onCleanup(@()set(btnAutomatic,'Enable','on')); %#ok<NASGU>
    setappdata(fig,'StudioActionBusy',true); busyGuard=onCleanup(@()setappdata(fig,'StudioActionBusy',false)); %#ok<NASGU>
    try
        [b0,b1]=selectedBaselineFrames();
        cfg=struct('size',n,'slice',opt.slice,'baselineSec',tsec([b0 b1]),'signalSec',60*interval,'plateauSec',opt.plateauSec);
        if fusiBaselineReference('isExternal',baseline),cfg.baselineMode='external';cfg.baselineReference=baseline.reference;end
        cfg.spacingUm=currentROISpacingUm();
        [baselineEntered0,baselineEntered1]=parseRangeSafe(getStr(ebBase),baseStart0,baseEnd0);
        cfg.configuredBaselineRange=[baselineEntered0 baselineEntered1];
        cfg.configuredBaselineUnits='s';
        if isVolMode,cfg.configuredBaselineUnits='volume indices';end
        slices=scmSearchSlices(opt,nZ);
        progress=deConfUSIon_ui('progress','Searching ROI candidates',true);
        pg=onCleanup(@()deConfUSIon_ui('progressclose',progress)); %#ok<NASGU>
        if isempty(state.scanSequence)
            [candidates,skipped]=scmSearchCandidates(PSC,TR,cfg,opt,slices,@getMaskForSlice, ...
                @(fraction,message)deConfUSIon_ui('progressupdate',progress,fraction,message));
        else
            searchContext=struct('power',baselineRaw,'par',par,'mapping',state.currentROIMapping,'displayShape',[nY nX nZ]);
            [candidates,skipped]=scmSearchScanSequence(PSC,TR,state.scanSequence,baseline,cfg,opt,slices,@getMaskForSlice,searchContext, ...
                @(fraction,message)deConfUSIon_ui('progressupdate',progress,fraction,message));
        end
        clear pg;
        if isempty(candidates)
            set(info1,'String','No complete ROI found in the eligible search area and available frames. Adjust search settings.'); return;
        end
        if isfield(opt,'topCount')&&any(opt.topCount>0)
            candidates=scmTopCandidates(candidates,opt.topCount);
        end
        displayProfile=[];
        if isfield(opt,'displayMode') && strcmp(opt.displayMode,'shared')
            displayProfile=scmSharedDisplay('validate',opt.sharedDisplay);
        elseif isfield(opt,'displayMode') && strcmp(opt.displayMode,'adaptive')
            displayProfile=scmAutomaticDisplay(PSC,candidates,opt,@getMaskForSlice);
            displayProfile.signMode=get(popSignMode,'Value');
            if displayProfile.signMode==3, displayProfile.caxis=[-1 1]*displayProfile.caxis(2); end
        end
        % Publish marks only after the search completes. Cancellation leaves
        % existing ROIs and display untouched.
        replaceUnsavedAutomaticROIs();
        audit=scmAutomaticROISelections(fig); if isempty(audit), audit={}; end
        highSlices=cellfun(@(c)c.slice,candidates(cellfun(@(c)c.meanPSC>200,candidates)));
        for ci=1:numel(candidates)
            candidate=candidates{ci}; bounds=candidate.boundsXY; id=roi.nextId; zz=candidate.slice;
            color=[1 .55 .05]; if strcmp(candidate.role,'Control'), color=[.05 .65 1]; end
            if ismember(zz,highSlices), color=[1 .15 .15]; end
            ROI_byZ{zz}(end+1)=struct('id',id,'x1',bounds(1),'x2',bounds(2),'y1',bounds(3),'y2',bounds(4),'color',color);
            roi.nextId=id+1; candidate.roiId=id; candidate.source=fileLabel;
            if isfield(candidate,'searchScanLabel'),candidate.source=candidate.searchScanLabel;end
            candidate.displayPresetApplied=cleanDisplay;
            if ~isempty(displayProfile), candidate.automaticDisplay=displayProfile; end
            audit{end+1}=candidate; candidates{ci}=candidate; %#ok<AGROW>
        end
        setappdata(fig,'AutomaticROISelections',audit);
        setappdata(fig,'AutomaticROISearchSummary',struct('searchedSlices',slices,'skippedRegions',{skipped}, ...
            'candidateSlices',cellfun(@(c)c.slice,candidates),'parameters',candidates{1}.searchParameters));
        if isVolMode, shown=60*interval/TR+1; else, shown=60*interval; end
        set(ebSig,'String',sprintf('%.9g-%.9g',shown));
        if cleanDisplay
            set(ebSigma,'String','0');
            set(popMap,'Value',findPopupIndexByName(popMap,'blackbdy_iso'));
            setOverlayColormap('blackbdy_iso');
            set(ebCax,'String','0 30'); set(popSignMode,'Value',1);
            set(cbAlphaMod,'Value',1); set(ebModMin,'String','5'); set(ebModMax,'String','10');
            set(slAlpha,'Value',get(slAlpha,'Max')); alphaModToggled([],[]);
        end
        if ~isempty(displayProfile)
            set(ebCax,'String',sprintf('%.9g %.9g',displayProfile.caxis));
            set(cbAlphaMod,'Value',1);set(ebModMin,'String',num2str(displayProfile.modMin,9));set(ebModMax,'String',num2str(displayProfile.modMax,9));
            set(slAlpha,'Value',displayProfile.alphaPercent);set(popSignMode,'Value',displayProfile.signMode);
            setappdata(fig,'AutomaticDisplayProfile',displayProfile);alphaModToggled([],[]);
        end
        [~,order]=sort(cellfun(@(c)c.meanPSC,candidates),'descend'); candidates=candidates(order);
        candidate=candidates{1}; id=candidate.roiId;
        showAutomaticWindow(candidate);
        if nZ>1, set(slZ,'Value',nZ-candidate.slice+1); sliceChanged([],[]); end
        setHoverActive(false);
        computeSCM([],[]); redrawROIsForCurrentSlice();
        set(hRoiCoordTxt,'Visible','on','String',sprintf('Peak ROI %d | %d voxels | mean %.3g%% | %d baseline / %d signal frames | review before export',id,candidate.pixelCount,candidate.meanPSC,numel(candidate.baselineFrames),numel(candidate.signalFrames)));
        showCandidateReview(candidates,skipped);
    catch ME
        setappdata(fig,'AutomaticROILastError',ME);
        if ~strcmp(ME.identifier,'deConfUSIon:ProcessingCancelled'), errordlg(ME.message,'ROI search'); end
    end
end

function showCandidateReview(candidates,skipped)
    closeCandidateReviews();
    review=figure('Name',['Automatic ROI candidates | ' fileLabel],'Tag','AutomaticROICandidateReview', ...
        'NumberTitle','off','MenuBar','none','ToolBar','none','Color','k','Position',[160 100 1280 760]);
    setappdata(review,'deConfUSIonNoMaximize',true); setappdata(review,'SCMOwner',fig);
    order=[]; selected=[]; exportIds=[];
    if any(cellfun(@(c)isfield(c,'requestedTopN')&&c.requestedTopN>0,candidates))
        exportIds=cellfun(@(c)c.roiId,candidates);
    end
    description=sprintf('%d candidates. Green = marked for export; red text = slice with mean PSC >200%%. Click a row to view its window.\nExploratory maxima. Shared mode uses the globally strongest candidate window for all slices.',numel(candidates));
    if ~isempty(skipped), description=sprintf('%s\nNo valid ROI: %s',description,strjoin(skipped,', ')); end
    summary=scmSearchParameterSummary(candidates,skipped,fileLabel);
    brief=strsplit(summary,newline);brief=brief(1:min(7,numel(brief)));
    hParameters=ctl('text',[.025 .755 .95 .23],strjoin(brief,newline),[]);
    set(hParameters,'Tag','CandidateSearchParameters','HorizontalAlignment','left','FontSize',12, ...
        'BackgroundColor','k','TooltipString',summary);
    setappdata(review,'SearchParameterSummary',summary);
    description=description(1:min(numel(description),300));
    role=ctl('popupmenu',[.025 .72 .18 .05],{'All','Target','Control','Search'},@refresh);
    set(role,'Tag','CandidateRoleFilter');
    sortBy=ctl('popupmenu',[.225 .72 .25 .05],{'Maximum PSC first','Minimum PSC first','Slice ascending','Slice descending'},@refresh);
    set(sortBy,'Tag','CandidateSort');
    units=ctl('popupmenu',[.50 .72 .17 .05],{'Time: minutes','Time: seconds'},@refresh);
    set(units,'Tag','CandidateTimeUnits');
    sliceRange=ctl('edit',[.69 .72 .13 .05],sprintf('1 %d',nZ),@refresh); set(sliceRange,'Tag','CandidateSliceFilter','TooltipString','Slice range: start end (inclusive)');
    ctl('pushbutton',[.84 .72 .135 .05],'Show maximum',@showMaximum);
    tbl=uitable(review,'Units','normalized','Position',[.025 .23 .95 .46],'Data',cell(0,10), ...
        'ColumnName',{'Slice','ROI','Role','Region','Mean PSC (%)','Center X','Center Y','Start (min)','End (min)','Export'}, ...
        'ColumnEditable',[false(1,9) true],'ColumnFormat',[repmat({'char'},1,9) {'logical'}], ...
        'ColumnWidth',{55 55 85 200 115 80 80 110 110 75},'CellEditCallback',@markForExport, ...
        'FontSize',12,'ForegroundColor','w','CellSelectionCallback',@reviewSlice,'Tag','CandidateTable');
    msg=ctl('text',[.025 .155 .95 .06],'',[]); set(msg,'Tag','CandidateStatus');
    ctl('pushbutton',[.025 .065 .25 .07],'Export SELECTED ROIs (TXT)',@exportSelected);
    ctl('pushbutton',[.29 .065 .25 .07],'Choose Target + Control to export',@exportPair);
    ctl('pushbutton',[.555 .065 .24 .07],'Clear ALL marked ROIs',@clearAllMarkedROIs);
    ctl('pushbutton',[.82 .065 .155 .07],'Close','delete(gcbf)');
    bundleButton=ctl('pushbutton',[.025 .005 .95 .05],'Export checked ROIs: per-role bundle + averaged TXT (one observation per role)',@exportBundles);
    set(bundleButton,'Tag','SCM_ExportROIBundles');
    refresh();
    function h=ctl(style,pos,str,cb)
        h=uicontrol(review,'Style',style,'Units','normalized','Position',pos,'String',str, ...
            'BackgroundColor',[.10 .10 .10],'ForegroundColor','w','FontSize',11,'Callback',cb);
    end
    function refresh(varargin)
        range=sscanf(get(sliceRange,'String'),'%f')';
        if numel(range)==1, range=[range range]; end
        if numel(range)~=2||any(~isfinite(range))||any(range<1|range>nZ|range~=round(range))
            set(msg,'String',sprintf('Enter a slice or two slice numbers within 1-%d.',nZ)); return;
        end
        roles=get(role,'String'); order=scmCandidateOrder(candidates,roles{get(role,'Value')},range,get(sortBy,'Value'));
        highSlices=cellfun(@(c)c.slice,candidates(cellfun(@(c)c.meanPSC>200,candidates)));
        divisor=60; unit='min';
        if get(units,'Value')==2, divisor=1; unit='s'; end
        headers=get(tbl,'ColumnName'); headers{8}=['Start (' unit ')']; headers{9}=['End (' unit ')'];
        set(tbl,'ColumnName',headers);
        rows=cell(numel(order),10);
        for row=1:numel(order)
            c=candidates{order(row)};
            regionText=c.region;
            if isfield(c,'searchScanLabel'),regionText=[regionText ' | ' c.searchScanLabel];end
            if strcmp(c.roiMode,'region'),regionText=sprintf('%s | %d voxels',regionText,c.pixelCount);
            elseif all(isfinite(c.sizeXYUm)),regionText=sprintf('%s | %.6g x %.6g um',regionText,c.sizeXYUm);end
            values={c.slice c.roiId c.role regionText c.meanPSC mean(c.boundsXY(1:2)) mean(c.boundsXY(3:4)) c.signalSampleSec(1)/divisor c.signalSampleSec(end)/divisor};
            for col=1:9
                v=values{col}; if isnumeric(v), v=sprintf('%.6g',v); end
                if ismember(c.slice,highSlices), v=['<html><font color="#ff3030">' v '</font></html>']; end
                rows{row,col}=v;
            end
            rows{row,10}=ismember(c.roiId,exportIds);
        end
        set(tbl,'Data',rows); setappdata(tbl,'CandidateIndices',order);
        selected=[]; updateExportAppearance(false);
    end
    function updateExportAppearance(preserve)
        % Avoid replacing Data after checkbox edits. Preserve the native
        % viewport around recoloring too: MATLAB also resets it for colors.
        colors=repmat([.10 .10 .10],max(1,numel(order)),1);
        colors(2:2:end,:)=repmat([.14 .14 .14],floor(size(colors,1)/2),1);
        if ~isempty(order)
            checked=ismember(cellfun(@(c)c.roiId,candidates(order)),exportIds);
            colors(checked,:)=repmat([22 128 60]/255,nnz(checked),1);
        end
        scmCandidateTableColors(tbl,colors,preserve); setappdata(tbl,'ExportROIIds',exportIds);
        set(msg,'String',sprintf('%d / %d shown; %d selected for export (including hidden rows).',numel(order),numel(candidates),numel(exportIds)));
    end
    function markForExport(~,event)
        if isempty(event.Indices)||event.Indices(2)~=10||event.Indices(1)>numel(order), return; end
        if (isstruct(event)&&isfield(event,'Error') || isobject(event)&&isprop(event,'Error')) && ~isempty(event.Error)
            set(msg,'String','The checkbox edit failed; export selection was kept.'); return;
        end
        id=candidates{order(event.Indices(1))}.roiId;
        if logical(event.NewData), exportIds=unique([exportIds id],'stable');
        else, exportIds(exportIds==id)=[]; end
        % MATLAB already committed the checkbox to Data. Keep the row order,
        % selection, column widths and both scroll positions intact.
        updateExportAppearance(true);
    end
    function exportSelected(~,~)
        if isempty(exportIds)
            set(msg,'String','Tick the Export checkbox for at least one ROI first.'); return;
        end
        exportROIsCB([],[],[],exportIds);
    end
    function exportBundles(~,~)
        if isempty(exportIds),set(msg,'String','Tick Export for the ROIs to average, or choose top-N in automatic analysis.');return;end
        if roi.exportBusy,return;end
        roi.exportBusy=true;lock=onCleanup(@releaseRoiExportLock); %#ok<NASGU>
        try
            chosen=candidates(ismember(cellfun(@(c)c.roiId,candidates),exportIds));
            P=getSimpleExportPaths();[files,folder]=scmExportROIBundles(PSC,TR,chosen,P.roiDir,fileLabel);
            roi.exportedIds=unique([roi.exportedIds exportIds]);
            setappdata(review,'LastBundleFiles',files);setappdata(review,'LastSearchParameterFile',fullfile(folder,'Analysis_Parameters.txt'));
            set(msg,'String',sprintf('Saved %d files to %s. In Group Analysis load mean OR allROIs, not both.',numel(files),folder));
        catch ME,set(msg,'String',['Bundle export failed: ' ME.message]);end
    end
    function reviewSlice(~,event)
        if isempty(event.Indices)||~isgraphics(fig), return; end
        selected=order(event.Indices(1,1)); displayCandidate(candidates{selected});
    end
    function showMaximum(~,~)
        if isempty(order), return; end
        [~,ix]=max(cellfun(@(c)c.meanPSC,candidates(order))); selected=order(ix); displayCandidate(candidates{selected});
    end
end

function displayCandidate(c)
    showAutomaticWindow(c);
    if nZ>1, set(slZ,'Value',nZ-c.slice+1); sliceChanged([],[]); end
    setHoverActive(false); computeSCM([],[]); redrawROIsForCurrentSlice();
    set(hRoiCoordTxt,'Visible','on','String',sprintf('ROI %d | %s | slice %d | mean %.3g%% | %.3g-%.3g min', ...
        c.roiId,c.role,c.slice,c.meanPSC,c.signalSampleSec(1)/60,c.signalSampleSec(end)/60));
end

function replaceUnsavedAutomaticROIs()
    roi.viewBanks={};roi.hiddenDefinitions={};
    % Replace previews only after the new search succeeds. Keep manual marks
    % and marks already written to TXT; exported file numbering is separate.
    audit=scmAutomaticROISelections(fig);
    remove=[];
    for ai=1:numel(audit)
        if ~ismember(audit{ai}.roiId,roi.exportedIds), remove(end+1)=audit{ai}.roiId; end %#ok<AGROW>
    end
    closeCandidateReviews();
    existing=[];
    for zz=1:nZ
        marks=ROI_byZ{zz}; marks=marks(~ismember([marks.id],remove)); ROI_byZ{zz}=marks;
        existing=[existing [marks.id]]; %#ok<AGROW>
    end
    if ~isempty(audit), audit=audit(~cellfun(@(c)ismember(c.roiId,remove),audit)); end
    setappdata(fig,'AutomaticROISelections',audit);
    roi.nextId=max([0 existing])+1;
end

function clearAllMarkedROIs(~,~)
    for zz=1:nZ
        ROI_byZ{zz}=struct('id',{},'x1',{},'x2',{},'y1',{},'y2',{},'color',{});
    end
    % Reviews and audit records are cleared together, so IDs can safely restart.
    roi.nextId=1; roi.exportedIds=[];
    roi.sizingById={};
    roi.viewBanks={};roi.hiddenDefinitions={};
    setappdata(fig,'AutomaticROISelections',{}); setappdata(fig,'AutomaticROISearchSummary',[]);
    roi.pendingHover=[]; setHoverActive(false);
    set(hLiveRect,'Visible','off'); set(hLivePSC,'Visible','off');
    closeCandidateReviews(); redrawROIsForCurrentSlice(); set(hRoiCoordTxt,'Visible','off');
end

function exportPair(~,~)
    ids=[]; names={};
    for zz=1:nZ
        for rr=ROI_byZ{zz}
            if ismember(rr.id,ids),continue;end
            ids(end+1)=rr.id; %#ok<AGROW>
            names{end+1}=sprintf('ROI %d | slice %d | X %d-%d, Y %d-%d',rr.id,zz,rr.x1,rr.x2,rr.y1,rr.y2); %#ok<AGROW>
        end
    end
    if numel(ids)<2, warndlg('Mark at least two ROIs first.','Export pair'); return; end
    [ti,ok]=listdlg('PromptString','Choose ONE Target ROI','SelectionMode','single','ListString',names,'ListSize',[470 300]);
    if ~ok, return; end
    remaining=setdiff(1:numel(ids),ti,'stable');
    [ci,ok]=listdlg('PromptString','Choose ONE Control ROI','SelectionMode','single','ListString',names(remaining),'ListSize',[470 300]);
    if ~ok, return; end
    exportROIsCB([],[],[ids(ti) ids(remaining(ci))]);
end

function showAutomaticWindow(c)
    shown=c.signalSec; if isVolMode, shown=shown/TR+1; end
    set(ebSig,'String',sprintf('%.9g-%.9g',shown));
end

function closeCandidateReviews()
    reviews=findall(0,'Tag','AutomaticROICandidateReview');
    for r=reshape(reviews,1,[])
        if isequal(getappdata(r,'SCMOwner'),fig), delete(r); end
    end
end

function exportROIsCB(~,~,pairIds,selectedIds)
    if nargin<3, pairIds=[]; end
    if nargin<4, selectedIds=[]; end
    if roi.exportBusy, return; end
    tNowSec = now * 86400;
    if (tNowSec - roi.lastExportStampSec) < 0.75, return; end
    roi.exportBusy = true;
    cleanupObj = onCleanup(@releaseRoiExportLock); %#ok<NASGU>
    try
        nTot = 0;
        for zz = 1:nZ, nTot = nTot + numel(ROI_byZ{zz}); end
        if nTot == 0
            warndlg('No ROIs to export. Add ROIs first.', 'Export ROIs'); return;
        end
        P = getSimpleExportPaths(); roiDir = P.roiDir; safeMkdirIfNeeded(roiDir);
        if ~isempty(selectedIds)
            labelTag='Selected';
        elseif isempty(pairIds)
            labelTag = askExportLabel(roi.lastExportLabel, 'ROI export label');
        else
            labelTag='Target_and_Ctrl';
        end
        if isempty(labelTag), return; end
        roi.lastExportLabel = labelTag;
        roi.sessionSetId = roi.sessionSetId + 1;
        setId = roi.sessionSetId;
        dIdx = 1;
        flat = struct('z', {}, 'id', {}, 'x1', {}, 'x2', {}, 'y1', {}, 'y2', {}, 'color', {});
        for zz = 1:nZ
            ROI = ROI_byZ{zz};
            for k = 1:numel(ROI)
                r = ROI(k);
                flat(end+1) = struct('z', zz, 'id', r.id, 'x1', r.x1, 'x2', r.x2, 'y1', r.y1, 'y2', r.y2, 'color', r.color); %#ok<AGROW>
            end
        end
        % Oblique masks can have marks on several slices but represent one
        % volume ROI and one trace, not repeated observations.
        if ~isempty(flat),[~,uniqueIDs]=unique([flat.id],'stable');flat=flat(uniqueIDs);end
        if ~isempty(selectedIds)
            flat=flat(ismember([flat.id],selectedIds));
            assert(numel(flat)==numel(selectedIds),'A selected ROI is no longer marked. Refresh the candidate search.');
        end
        if ~isempty(pairIds)
            flat=flat(ismember([flat.id],pairIds));
            assert(numel(flat)==2,'The selected ROIs are no longer marked.');
        end
        keys = cell(numel(flat),1);
        for i = 1:numel(flat)
            keys{i} = sprintf('%d_%d_%d_%d_%d', flat(i).z, flat(i).x1, flat(i).x2, flat(i).y1, flat(i).y2);
        end
        if isempty(pairIds) && isempty(selectedIds)
            [~, ia] = unique(keys, 'stable'); flat = flat(sort(ia));
        elseif ~isempty(pairIds)
            assert(numel(unique(keys))==2,'Target and Control must not be the same spatial ROI.');
        end
        A = [[flat.z].' [flat.id].']; [~, ord] = sortrows(A, [1 2]); flat = flat(ord);
        for i = 1:numel(flat)
            r = flat(i); exportLabel=labelTag;
            if ~isempty(pairIds)
                exportLabel='Ctrl'; if r.id==pairIds(1), exportLabel='Target'; end
            end
            if ~isempty(selectedIds)
                audit=scmAutomaticROISelections(fig);
                for ai=1:numel(audit)
                    if audit{ai}.roiId==r.id && audit{ai}.slice==r.z
                        exportLabel=audit{ai}.role;
                        if strcmpi(exportLabel,'Control'), exportLabel='Ctrl'; end
                        break;
                    end
                end
            end
            [win0,win1]=parseRangeSafe(getStr(ebSig),840,900);
            exportSignalSec=[win0 win1];
            if isVolMode, exportSignalSec=(exportSignalSec-1)*TR; end
            selection=[]; audit=scmAutomaticROISelections(fig);
            for ai=1:numel(audit)
                if audit{ai}.roiId==r.id && audit{ai}.slice==r.z
                    selection=audit{ai}; exportSignalSec=selection.signalSec; break;
                end
            end
            windowTag=scmROIWindowTag(exportSignalSec,selection);
            outFile = fullfile(roiDir, sprintf('ROI%d_%s_%s_d%d.txt', setId, exportLabel, windowTag, dIdx));
            while exist(outFile,'file') == 2
                dIdx = dIdx + 1;
                outFile = fullfile(roiDir, sprintf('ROI%d_%s_%s_d%d.txt', setId, exportLabel, windowTag, dIdx));
            end
            fid = fopen(outFile, 'w');
            if fid < 0, error('Could not write ROI file: %s', outFile); end
            fileGuard=onCleanup(@()fclose(fid));
            fprintf(fid, '# ROI export from SCM_gui\n');
            fprintf(fid, '# Date: %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
            fprintf(fid, '# FileLabel: %s\n', fileLabel);
            fprintf(fid, '# TR_sec: %.6g\n', TR);
            fprintf(fid, '# nY nX nZ nT: %d %d %d %d\n', nY,nX,nZ,nT);
            fprintf(fid, '# ROI_SET_ID: %d\n', setId);
            fprintf(fid, '# ROI_LABEL: %s\n', exportLabel);
            fprintf(fid, '# ROI_D_INDEX: %d\n', dIdx);
            fprintf(fid, '# ROI_MARKER_ID: %d\n', r.id);
            fprintf(fid, '# WindowFilenameTag: %s\n',windowTag);
            fprintf(fid, '# SelectedSignalWindow_sec: %.9g %.9g\n',exportSignalSec);
            if ~isempty(selection)
                fprintf(fid, '# SearchInterval_sec: %.9g %.9g\n',selection.searchIntervalSec);
                fprintf(fid, '# PlateauDuration_sec: %.9g\n',selection.plateauSec);
            end
            roiSignalWindow=getStr(ebSig);
            audit=scmAutomaticROISelections(fig);
            for ai=1:numel(audit)
                if audit{ai}.roiId==r.id && audit{ai}.slice==r.z
                    fprintf(fid,'# AutomaticROISelection: %s\n',jsonencode(audit{ai}));
                    scmWriteAtlasSelectionHeader(fid,audit{ai});
                    scmROI('writeSize',fid,audit{ai});
                    shown=audit{ai}.signalSec; if isVolMode, shown=shown/TR+1; end
                    roiSignalWindow=sprintf('%.9g-%.9g',shown);
                end
            end
            fprintf(fid, '# SLICE: %d\n', r.z);
            fprintf(fid, '# BaselineWindow: %s\n', getStr(ebBase));
            fprintf(fid, '# PSC_REBASED: 1\n');
            if fusiBaselineReference('isExternal',baseline)
                fprintf(fid,'# PSC_REBASE_METHOD: absolute_power_vs_external_mean_per_voxel\n');
                fprintf(fid,'# PSC_BASELINE_TARGET: external_reference_mean_equals_0_percent\n# BaselineSource: %s\n',fusiBaselineReference('label',baseline));
                fprintf(fid,'# BaselineSourceFile: %s\n',baseline.reference.sourceFile);
                fprintf(fid,'# BaselineSource_TR_sec: %.12g\n# BaselineSourceFrames: %d %d\n',baseline.reference.TR,baseline.reference.frames);
            else
                fprintf(fid, '# PSC_REBASE_METHOD: exact_percent_rebase_per_voxel_100_times_P_minus_B_over_100_plus_B\n');
                fprintf(fid, '# PSC_BASELINE_TARGET: mean_selected_baseline_equals_0_percent\n');
            end

            fprintf(fid, '# SignalWindow: %s\n', roiSignalWindow);
            if isempty(selection)&&numel(roi.sizingById)>=r.id&&~isempty(roi.sizingById{r.id}),scmROI('writeSize',fid,roi.sizingById{r.id});end
            fprintf(fid, '# x1 x2 y1 y2\n%d %d %d %d\n', r.x1,r.x2,r.y1,r.y2);
            fprintf(fid, '# color_rgb\n%.6f %.6f %.6f\n', r.color(1),r.color(2),r.color(3));
            tc = computeRoiPSC_atSlice(r.z, r.x1, r.x2, r.y1, r.y2,r.id);
            if isempty(tc) || numel(tc) ~= nT, tc = nan(1,nT); end
            fprintf(fid, '# columns: time_sec\ttime_min\tPSC\n');
            for ii = 1:nT, fprintf(fid, '%.6f\t%.6f\t%.6f\n', tsec(ii), tmin(ii), tc(ii)); end
            clear fileGuard;
            roi.exportedIds=unique([roi.exportedIds r.id]);
            dIdx = dIdx + 1;
        end
        audit=scmAutomaticROISelections(fig);
        chosen=audit(cellfun(@(c)ismember(c.roiId,[flat.id]),audit));
        if ~isempty(chosen)
            summary=getappdata(fig,'AutomaticROISearchSummary');skipped={};
            if isstruct(summary)&&isfield(summary,'skippedRegions'),skipped=summary.skippedRegions;end
            parameterFile=scmExportSearchParameters(roiDir,chosen,fileLabel,skipped,sprintf('Analysis_Parameters_ROIset%d.txt',setId));
            setappdata(fig,'LastSearchParameterFile',parameterFile);
        end
        msgbox(sprintf('Exported %d ROI(s) to:\n%s\n(ROI set %d, %s)', numel(flat), roiDir, setId, labelTag), 'Export ROIs');
    catch ME
        errordlg(ME.message, 'ROI export failed');
    end
end

function releaseRoiExportLock()
    roi.exportBusy = false;
    roi.lastExportStampSec = now * 86400;
end

function exportSCMImageCB(~,~)
    if state.singleScmExportBusy, return; end
    tNowSec = now * 86400;
    if (tNowSec - state.lastSingleScmExportStampSec) < 0.75, return; end
    state.singleScmExportBusy = true;
    cleanupObj = onCleanup(@releaseSingleScmExportLock); %#ok<NASGU>

    tf = [];
    slidePng = '';
    try
        P = getSimpleExportPaths(); outDir = P.scmImageDir; safeMkdirIfNeeded(outDir);
        stamp = datestr(now, 'yyyymmdd_HHMMSS');
        baseName = sprintf('SCM_z%02d_%s', state.z, stamp);
        outPng = fullfile(outDir, [baseName '.png']);
        outTif = fullfile(outDir, [baseName '.tif']);
        outJpg = fullfile(outDir, [baseName '.jpg']);

        tf = figure('Visible','off','Color',[0.05 0.05 0.05],'InvertHardcopy','off','Units','pixels','Position',[200 120 1400 980]);
        ax2 = axes('Parent',tf,'Units','normalized','Position',[0.06 0.10 0.74 0.84]);
        axis(ax2,'image'); axis(ax2,'off'); set(ax2,'YDir','reverse'); hold(ax2,'on');
        image(ax2,'CData',get(hBG,'CData'),'XData',hBG.XData,'YData',hBG.YData);
        h2 = imagesc(ax2,hOV.XData,hOV.YData,get(hOV,'CData')); set(h2,'AlphaData',get(hOV,'AlphaData'));
        set(ax2,'DataAspectRatio',ax.DataAspectRatio,'XLim',ax.XLim,'YLim',ax.YLim);
        try, colormap(ax2, colormap(ax)); catch, colormap(ax2, colormap(fig)); end
        caxis(ax2, state.cax);

        ROI = ROI_byZ{state.z};
        for k = 1:numel(ROI)
            r = ROI(k);
            rectangle(ax2, 'Position', [r.x1 r.y1 r.x2-r.x1+1 r.y2-r.y1+1], 'EdgeColor', r.color, 'LineWidth', 2);
            text(ax2, r.x1, max(1,r.y1-2), sprintf('%d',r.id), 'Color', r.color, 'FontWeight','bold', ...
                'FontSize',12,'Interpreter','none','VerticalAlignment','bottom','BackgroundColor',[0 0 0],'Margin',1);
        end

        title(ax2, sprintf('%s | Slice %d/%d', fileLabel, state.z, nZ), 'Color','w','FontWeight','bold','Interpreter','none');
        cb2 = colorbar(ax2); cb2.Color = 'w'; cb2.Label.String = 'Signal change (%)'; cb2.FontSize = 12;
        set(tf,'PaperPositionMode','auto');
        print(tf,outPng,'-dpng','-r300','-opengl');
        print(tf,outTif,'-dtiff','-r300','-opengl');
        print(tf,outJpg,'-djpeg','-r300','-opengl');
        if isgraphics(tf), close(tf); end
        tf = [];

        % Retain the slide-ready PNG as a usable fallback, including when the
        % Report Generator toolbox is absent or the PPT writer fails.
        slidePng = fullfile(outDir, [baseName '_slide.png']);
        renderSingleScmSlidePNG(slidePng, outPng, fileLabel, state.z, nZ, state.cax, colormap(ax));
        pptPath = '';
        pptProblem = '';
        if canUsePptApi()
            try
                pptPath = chooseShortSinglePptPath(outDir, fileLabel, stamp);
                writePptFromSlidePNGs(pptPath, {slidePng});
            catch MEppt
                pptPath = '';
                pptProblem = MEppt.message;
                warning('SCM:PptExportFailed','SCM images were saved, but PowerPoint export failed: %s', pptProblem);
            end
        end

        if ~isempty(pptPath)
            set(info1,'String',sprintf('Saved SCM: %s (png/tif/jpg/ppt)', shortenPath(outDir,85)), 'TooltipString', outDir);
        else
            set(info1,'String',sprintf('Saved SCM: %s (png/tif/jpg)', shortenPath(outDir,85)), 'TooltipString', outDir);
        end
        if ~isempty(pptProblem)
            set(info1,'String',sprintf('Images saved; PPT failed. %s', shortenPath(outDir,85)), ...
                'TooltipString', sprintf('%s\n%s',outDir,pptProblem));
            warndlg(sprintf('SCM images and the slide PNG were saved to:\n%s\n\nPowerPoint export failed:\n%s', ...
                outDir,pptProblem), 'SCM images saved');
        end

    catch ME
        try, if ~isempty(tf) && isgraphics(tf), close(tf); end, catch, end
        errordlg(ME.message, 'Export SCM Image failed');
    end
end

function releaseSingleScmExportLock()
    state.singleScmExportBusy = false;
    state.lastSingleScmExportStampSec = now * 86400;
end

function exportTimecoursePngCB(~,~)
    tf = [];
    try
        P = getSimpleExportPaths(); outDir = P.scmTcDir; safeMkdirIfNeeded(outDir);
        labelTag = askExportLabel(state.lastTcExportLabel, 'Time course export label');
        if isempty(labelTag), return; end
        state.lastTcExportLabel = labelTag;
        stamp = datestr(now,'yyyymmdd_HHMMSS');
        baseName = sprintf('%s_%s_TimeCourse_%s', P.fileStem, labelTag, stamp);
        outPngGrid = fullfile(outDir, [baseName '_grid.png']);
        outPngNoGrid = fullfile(outDir, [baseName '_nogrid.png']);
        tf = figure('Visible','off','Color',[0.05 0.05 0.05],'InvertHardcopy','off','Units','pixels','Position',[150 120 1500 780]);
        ax2 = axes('Parent',tf,'Units','normalized','Position',[0.11 0.14 0.84 0.76], ...
            'Color',[0.05 0.05 0.05],'XColor','w','YColor','w','LineWidth',1.2,'Box','on','Layer','top');
        hold(ax2,'on'); grid(ax2,'on');
        xlabel(ax2,'Time (min)','Color','w','FontSize',13,'FontWeight','bold');
        hY = ylabel(ax2,'PSC (%)','Color','w','FontSize',13,'FontWeight','bold');
        try, set(hY,'Units','normalized','Position',[-0.028 0.50 0],'Clipping','off'); catch, end
        title(ax2, sprintf('%s | %s ROI Time Course', fileLabel, labelTag), 'Color','w','FontWeight','bold','Interpreter','none');
        ROI = ROI_byZ{state.z};
        for k = 1:numel(ROI)
            r = ROI(k); tc = computeRoiPSC_atSlice(state.z, r.x1, r.x2, r.y1, r.y2,r.id);
            if numel(tc) == nT
                c=referenceCandidate(state.z,r.x1,r.x2,r.y1,r.y2,r.id);
                [xPlot,yPlot]=stitchRoiTrace(tc,tmin,c);plot(ax2,xPlot,yPlot,':','Color',r.color,'LineWidth',2.6);
            end
        end
        if strcmp(get(hLivePSC,'Visible'),'on')
            plot(ax2, get(hLivePSC,'XData'), get(hLivePSC,'YData'), ':', 'Color', get(hLivePSC,'Color'), 'LineWidth', 3.0);
        end
        yl = get(axTC,'YLim'); if any(~isfinite(yl)) || yl(2) <= yl(1), yl = [-5 5]; end
        xl = get(axTC,'XLim'); if any(~isfinite(xl)) || xl(2) <= xl(1), xl = [tmin(1) tmin(end)]; end
        set(ax2,'YLim',yl,'XLim',xl);
        ax2.XLabel.String=axTC.XLabel.String;
        if sequenceTraceShown()
            copyobj([hSequenceLabels(:);hSequenceBoundaries(:);hSequenceBaselineBands(:);hBasePatch;hSigPatch;hBaseTxt;hSigTxt],ax2);
        elseif referenceTraceShown()
            line(ax2,[0 0],yl,'LineStyle','--','Color',[.8 .85 .9]);
            copyobj([hReferenceScanTxt hCurrentScanTxt],ax2);
        end
        if ~sequenceTraceShown(),applyExportWindowPatches(ax2, yl);end
        print(tf,outPngGrid,'-dpng','-r300','-opengl');
        grid(ax2,'off'); print(tf,outPngNoGrid,'-dpng','-r300','-opengl');
        if isgraphics(tf), close(tf); end
        set(info1,'String',['Saved time course PNGs to: ' shortenPath(outDir,90)], 'TooltipString', outDir);
    catch ME
        try, if ~isempty(tf) && isgraphics(tf), close(tf); end, catch, end
        errordlg(ME.message, 'Export time course PNG failed');
    end
end

function exportScmSeries1minCB(~,~)
    if state.seriesExportBusy, return; end
    tNowSec = now * 86400;
    if (tNowSec - state.lastSeriesExportStampSec) < 0.75, return; end
    state.seriesExportBusy = true;
    cleanupObj = onCleanup(@releaseSeriesExportLock); %#ok<NASGU>

    EXPORT_DPI_TILES  = 200;
    EXPORT_DPI_SLIDES = 200;
    SAVE_TIF = true;
    SAVE_JPG = true;

    figT = [];
    slideDir = '';
    outDir = '';
    slidePNGs = {};
    slideSpecs = {};

    try
        prompts = { ...
            'Injection start (sec). Empty if unknown:', ...
            'Window length (sec) (default 60):', ...
            'Max minutes to export (empty=all):', ...
            'Export PPT too? (1=yes,0=no) (default 1):', ...
            sprintf('First slice to export (1-%d):', nZ), ...
            sprintf('Last slice to export (1-%d, inclusive):', nZ)};
        defaults = {'', '60', '', '1', ...
            num2str(state.seriesExportSliceRange(1)), num2str(state.seriesExportSliceRange(2))};
        while true
            a = inputdlg(prompts, 'Export SCM series', 1, defaults);
            if isempty(a), return; end
            try
                exportSlices = scmExportSliceRange(a{5}, a{6}, nZ);
                break;
            catch ME
                if ~strcmp(ME.identifier, 'SCM:ExportSliceRange'), rethrow(ME); end
                uiwait(errordlg(ME.message, 'Choose slices to export', 'modal'));
                defaults = a; % Keep all entered settings while correcting the range.
            end
        end
        state.seriesExportSliceRange = exportSlices([1 end]);

        injSec = str2double(strtrim(a{1}));
        if ~isfinite(injSec), injSec = NaN; end

        winLen = str2double(strtrim(a{2}));
        if ~isfinite(winLen) || winLen <= 0, winLen = 60; end

        maxMin = str2double(strtrim(a{3}));
        if ~isfinite(maxMin) || maxMin <= 0, maxMin = NaN; end

        doPPT = str2double(strtrim(a{4}));
        if ~isfinite(doPPT), doPPT = 1; end
        doPPT = (doPPT ~= 0);

        P = getSimpleExportPaths();
        rootScm = P.scmSeriesDir;
        safeMkdirIfNeeded(rootScm);

        stamp = datestr(now, 'yyyymmdd_HHMMSS');
        outDir = fullfile(rootScm, ['SCM_series_' stamp]);
        safeMkdirIfNeeded(outDir);

        dirPNG = fullfile(outDir, 'tiles_png');
        dirTIF = fullfile(outDir, 'tiles_tif');
        dirJPG = fullfile(outDir, 'tiles_jpg');
        safeMkdirIfNeeded(dirPNG);
        safeMkdirIfNeeded(dirTIF);
        safeMkdirIfNeeded(dirJPG);

        % These are deliverables, not scratch files: they remain useful if
        % PPT export fails and can be inserted directly into PowerPoint.
        slideDir = fullfile(outDir, 'slides_png');
        safeMkdirIfNeeded(slideDir);

        try
            set(info1, 'String', {'Saving to:', shortenPath(outDir,120), 'Tip: hover here to see full path'});
            set(info1, 'TooltipString', outDir);
            % DECONF_STD_SCM_LATE_FORCE_V9
try
    if exist('par','var') && isstruct(par) && isfield(par,'standardizedWorkflow') && par.standardizedWorkflow
        state.cax = [-100 100];
        state.signMode = 3;
        state.prevSignMode = 3;
% DECONF_STD_SCM_STATE_FORCE_V11
try
    if exist('par','var') && isstruct(par) && isfield(par,'standardizedWorkflow') && par.standardizedWorkflow
        if isfield(par,'standardCaxis') && numel(par.standardCaxis) == 2
            state.cax = double(par.standardCaxis(:)).';
        else
            state.cax = [-100 100];
        end
        state.alphaModOn = true;
        state.signMode = 3;
        state.prevSignMode = 3;
        if isfield(par,'standardModMinAbs') && isfinite(double(par.standardModMinAbs)), state.modMin = double(par.standardModMinAbs); else, state.modMin = -20; end
        if isfield(par,'standardModMaxAbs') && isfinite(double(par.standardModMaxAbs)), state.modMax = double(par.standardModMaxAbs); else, state.modMax = 20; end
    end
catch
end
        state.alphaModOn = true;
        state.modMin = -20;
        state.modMax = 20;
    end
catch
end
drawnow;
        catch
        end

        [b0,b1] = parseRangeSafe(getStr(ebBase), 30, 240);
        if ~isVolMode
            b0i = clamp(round(b0/TR)+1, 1, nT);
            b1i = clamp(round(b1/TR)+1, 1, nT);
        else
            b0i = clamp(round(b0), 1, nT);
            b1i = clamp(round(b1), 1, nT);
        end
        if b1i < b0i
            tmp = b0i; b0i = b1i; b1i = tmp;
        end

        cm = colormap(ax);
        caxV = state.cax;

        sigma = str2double(getStr(ebSigma));
        if ~isfinite(sigma), sigma = 0; end

        thrStr  = strtrim(getStr(ebThr));
        caxStr  = strtrim(getStr(ebCax));
        baseStr = strtrim(getStr(ebBase));
        if fusiBaselineReference('isExternal',baseline),baseStr=fusiBaselineReference('label',baseline);end
        aStr    = sprintf('Alpha=%s%%', strtrim(getStr(txtAlpha)));
        modStr  = sprintf('AlphaMod=%d [%s..%s]', double(state.alphaModOn), ...
            strtrim(getStr(ebModMin)), strtrim(getStr(ebModMax)));
        sigStr  = sprintf('Sigma=%g', sigma);
        footerInfo = sprintf('Thr=%s | CAX=%s | Base=%s | %s | %s | %s', ...
            thrStr, caxStr, baseStr, aStr, modStr, sigStr);

        totalSec = (nT-1) * TR;
        starts = 0:winLen:(floor(totalSec/winLen)*winLen);
        if isfinite(maxMin)
            starts = starts(starts < maxMin*60);
        end

        figT = figure('Visible','off','Color',[0 0 0], ...
            'InvertHardcopy','off','Units','pixels','Position',[50 50 1200 880]);
        axT = axes('Parent',figT,'Units','normalized','Position',[0 0 1 1]);
        axis(axT,'image'); axis(axT,'off'); set(axT,'YDir','reverse'); hold(axT,'on');
        hBgT = image(axT, zeros(nY,nX,3));
        hT = imagesc(axT, zeros(nY,nX));
        set(hT,'AlphaData',zeros(nY,nX));
        colormap(axT, cm);
        caxis(axT, caxV);
        hold(axT,'off');
        set(figT,'PaperPositionMode','auto');

        nSavedTotal = 0;

        % Keep source slice numbers in filenames and labels, even for a subset.
        for zSel = exportSlices
            PSCz = getPSCForSlice(zSel);
            baseMap = cachedBaseline(zSel,b0i,b1i);
            maskLocal = getMaskForSlice(zSel);

            bgRGB = currentUnderlayDisplayRGB(zSel);
            set(hBgT,'CData',bgRGB,'XData',hBG.XData,'YData',hBG.YData);
            set(axT,'DataAspectRatio',ax.DataAspectRatio,'XLim',ax.XLim,'YLim',ax.YLim);

            tilePNG = {};
            tileLBL = {};

            for wi = 1:numel(starts)
                s0 = starts(wi);
                s1 = s0 + winLen;
                idxSig = find(tsec >= s0 & tsec < s1);
                if isempty(idxSig), continue; end

                sigMap = deConfUSIon_signal('mean',PSCz(:,:,idxSig),3);
                map = 100*(sigMap-baseMap)./(100+baseMap);
    map(~isfinite(baseMap) | 100+baseMap<=sqrt(eps('single')))=NaN;
                if sigma > 0, map = smooth2D_gauss(map, sigma); end
                map(~maskLocal) = 0;

                [dispMap, alpha] = buildDisplayedOverlay(map, maskLocal);
                set(hT, 'CData', dispMap, 'AlphaData', alpha);
                colormap(axT, cm);
                caxis(axT, caxV);

                minIdx = floor(s0 / winLen) + 1;
                phase = '';
                if isfinite(injSec)
                    if s1 <= injSec
                        phase = 'Baseline';
                    elseif s0 < injSec && s1 > injSec
                        phase = 'Injection';
                    else
                        piMin = floor((s0 - injSec)/winLen) + 1;
                        if piMin < 1, piMin = 1; end
                        phase = sprintf('%d min PI', piMin);
                    end
                end

                if isempty(phase)
                    lbl = sprintf('z=%d/%d | %.0f-%.0fs | %d min', zSel, nZ, s0, s1, minIdx);
                else
                    lbl = sprintf('z=%d/%d | %.0f-%.0fs | %d min (%s)', zSel, nZ, s0, s1, minIdx, phase);
                end

                baseName = sprintf('SCM_z%02d_w%03d_%0.0f-%0.0fs', zSel, minIdx, s0, s1);
                outPng = fullfile(dirPNG, [baseName '.png']);
                outTif = fullfile(dirTIF, [baseName '.tif']);
                outJpg = fullfile(dirJPG, [baseName '.jpg']);

                print(figT, outPng, '-dpng', sprintf('-r%d', EXPORT_DPI_TILES), '-opengl');
                if SAVE_TIF
                    print(figT, outTif, '-dtiff', sprintf('-r%d', EXPORT_DPI_TILES), '-opengl');
                end
                if SAVE_JPG
                    print(figT, outJpg, '-djpeg', sprintf('-r%d', EXPORT_DPI_TILES), '-opengl');
                end

                nSavedTotal = nSavedTotal + 1;
                tilePNG{end+1} = outPng; %#ok<AGROW>
                tileLBL{end+1} = lbl; %#ok<AGROW>

                try
                    set(info1, 'String', sprintf('Exporting slices %d-%d: slice %d/%d | %d tiles | %s', ...
                        exportSlices(1), exportSlices(end), zSel, nZ, nSavedTotal, shortenPath(outDir,55)));
                    set(info1, 'TooltipString', outDir);
                    drawnow limitrate;
                catch
                end
            end

            if isempty(tilePNG), continue; end

            perSlide = 6;
            nSlides = ceil(numel(tilePNG) / perSlide);
            fullTitle = sprintf('%s | z=%d/%d', makeFullTitle(fileLabel), zSel, nZ);
            shortTitle = sprintf('%s | z=%d/%d', getAnimalID(fileLabel), zSel, nZ);

            for si = 1:nSlides
                i0 = (si-1)*perSlide + 1;
                i1 = min(si*perSlide, numel(tilePNG));
                idx = i0:i1;
                if si == 1
                    tStr = fullTitle;
                else
                    tStr = shortTitle;
                end

                outSlide = fullfile(slideDir, sprintf('slide_z%02d_%02d.png', zSel, si));
                renderSlideMontagePNG(outSlide, tilePNG(idx), tileLBL(idx), cm, caxV, tStr, footerInfo, EXPORT_DPI_SLIDES);
                if exist(outSlide, 'file') ~= 2
                    error('Failed to create slide PNG: %s', outSlide);
                end

                slidePNGs{end+1} = outSlide; %#ok<AGROW>
                slideSpecs{end+1} = struct('pngList', {tilePNG(idx)}); %#ok<AGROW>

                try
                    set(info1, 'String', sprintf('Building PPT slides... slice %d/%d | slide %d/%d', ...
                        zSel, nZ, si, nSlides));
                    set(info1, 'TooltipString', outDir);
                    drawnow limitrate;
                catch
                end
            end
        end

        if ~isempty(figT) && isgraphics(figT)
            close(figT); figT = [];
        end

        if isempty(slidePNGs)
            errordlg('No windows exported (maybe too short recording or window settings).', 'SCM series');
            return;
        end

        pptPath = '';
        pptMsg = '';
        if doPPT
            if canUsePptApi()
                pptPath = chooseShortPptPath(outDir, fileLabel, stamp);
                try
                    writePptFromSlidePNGsWithEditableTiles(pptPath, slidePNGs, slideSpecs);
                    if exist(pptPath, 'file') ~= 2
                        error('PPT writer finished, but file was not found on disk.');
                    end
                    pptMsg = 'PPT + PNGs';
                catch MEppt
                    warning('[SCM SERIES] PPT creation failed: %s', MEppt.message);
                    pptPath = '';
                    pptMsg = ['Images saved; PPT failed: ' MEppt.message];
                end
            else
                pptMsg = 'Images + slide PNGs (PowerPoint API unavailable)';
            end
        else
            pptMsg = 'Images + slide PNGs';
        end

        if doPPT && isempty(pptPath)
            set(info1, 'String', ['Images saved; no PPT. ' shortenPath(outDir,85)], ...
                'TooltipString', sprintf('%s\n%s\nSlide PNGs: %s',outDir,pptMsg,slideDir));
        elseif isempty(pptPath)
            set(info1, 'String', ['DONE. Saved: ' shortenPath(outDir,80) '  (' pptMsg ')'], 'TooltipString', outDir);
        else
            set(info1, 'String', ['DONE. Saved: ' shortenPath(outDir,80) '  (PPT + PNGs)'], 'TooltipString', outDir);
        end

        fprintf('[SCM SERIES] DONE. Slices %d-%d of %d. Folder: %s\n', ...
            exportSlices(1), exportSlices(end), nZ, outDir);
        if ~isempty(pptPath), fprintf('[SCM SERIES] PPT: %s\n', pptPath); end

    catch ME
        try, if ~isempty(figT) && isgraphics(figT), close(figT); end, catch, end
        detail = ME.message;
        if ~isempty(outDir) && exist(outDir,'dir') == 7
            detail = sprintf('%s\n\nCompleted images are retained in:\n%s',detail,outDir);
            set(info1,'String',['Export stopped. Completed files: ' shortenPath(outDir,85)], 'TooltipString',detail);
        end
        errordlg(detail, 'Export SCM series failed');
    end
end

function releaseSeriesExportLock()
    state.seriesExportBusy = false;
    state.lastSeriesExportStampSec = now * 86400;
end


function renderSingleScmSlidePNG(outFile, imagePng, titleLabel, zSel, nZSel, caxV, cm)
    figS = figure('Visible','off','Color',[0 0 0],'InvertHardcopy','off');
    set(figS, 'Units','inches', 'Position',[0.5 0.5 13.333 7.5]);
    set(figS, 'PaperPositionMode','auto');

    ttl = sprintf('%s | z=%d/%d', makeFullTitle(titleLabel), zSel, nZSel);
    annotation(figS, 'textbox', [0.02 0.90 0.96 0.08], ...
        'String', ttl, 'Color','w', 'EdgeColor','none', 'FontName','Arial', ...
        'FontSize',16, 'FontWeight','bold', 'HorizontalAlignment','center', ...
        'Interpreter','none');

    axI = axes('Parent', figS, 'Position', [0.08 0.10 0.82 0.78]);
    imshow(imread(imagePng), 'Parent', axI);
    axis(axI, 'off');

    axCB = axes('Parent', figS, 'Position', [0.885 0.16 0.001 0.66], ...
        'Visible','off', 'XTick',[], 'YTick',[], 'XColor','none', 'YColor','none', 'Box','off');
    imagesc(axCB, [0 1; 0 1]);
    colormap(axCB, cm);
    caxis(axCB, caxV);
    cbx = colorbar(axCB, 'Position', [0.895 0.16 0.015 0.66]);
    cbx.Color = 'w';
    cbx.FontName = 'Arial';
    cbx.FontSize = 10;
    cbx.Label.String = 'Signal change (%)';
    cbx.Label.Color = 'w';
    cbx.TickDirection = 'out';
    cbx.Box = 'off';
    try, cbx.AxisLocation = 'out'; catch, end

    print(figS, outFile, '-dpng', '-r220', '-opengl');
    close(figS);
end

function renderSlideMontagePNG(outFile, pngList, lblList, cm, caxV, titleStr, footerStr, dpiVal)
    figS = figure('Visible','off','Color',[0 0 0],'InvertHardcopy','off');
    set(figS, 'Units','inches', 'Position',[0.5 0.5 13.333 7.5]);
    set(figS, 'PaperPositionMode','auto');

    annotation(figS, 'textbox', [0.02 0.885 0.96 0.11], ...
        'String', titleStr, 'Color','w', 'EdgeColor','none', 'FontName','Arial', ...
        'FontSize',14, 'FontWeight','bold', 'HorizontalAlignment','center', ...
        'Interpreter','none');

    annotation(figS, 'textbox', [0.42 0.01 0.56 0.06], ...
        'String', footerStr, 'Color','w', 'EdgeColor','none', 'FontName','Arial', ...
        'FontSize',11, 'FontWeight','bold', 'HorizontalAlignment','right', ...
        'Interpreter','none');

    axCB = axes('Parent', figS, 'Position', [0.010 0.14 0.001 0.74], ...
        'Visible','off', 'XTick',[], 'YTick',[], 'XColor','none', 'YColor','none', 'Box','off');
    imagesc(axCB, [0 1; 0 1]);
    colormap(axCB, cm);
    caxis(axCB, caxV);
    cbx = colorbar(axCB, 'Position', [0.018 0.14 0.015 0.74]);
    cbx.Color = 'w';
    cbx.FontName = 'Arial';
    cbx.FontSize = 10;
    cbx.Label.String = 'Signal change (%)';
    cbx.Label.Color = 'w';
    cbx.TickDirection = 'out';
    cbx.Box = 'off';
    try, cbx.AxisLocation = 'out'; catch, end

    x0 = 0.095;
    x1 = 0.98;
    yBot = 0.12;
    yTop = 0.86;
    gridH = (yTop - yBot);
    rowGap = 0.06;
    colGap = 0.02;
    cellH = (gridH - rowGap) / 2;
    cellW = (x1 - x0 - 2*colGap) / 3;

    for k = 1:3
        if k > numel(pngList), break; end
        x = x0 + (k-1)*(cellW+colGap);
        y = yBot + cellH + rowGap;
        axI = axes('Parent', figS, 'Position', [x y cellW cellH]);
        imshow(imread(pngList{k}), 'Parent', axI);
        axis(axI, 'off');
        annotation(figS, 'textbox', [x y+cellH+0.005 cellW 0.035], ...
            'String', lblList{k}, 'Color','w', 'EdgeColor','none', ...
            'FontName','Arial', 'FontSize',13, 'FontWeight','bold', ...
            'HorizontalAlignment','center', 'Interpreter','none');
    end

    for k = 4:6
        if k > numel(pngList), break; end
        ccol = k - 3;
        x = x0 + (ccol-1)*(cellW+colGap);
        y = yBot;
        axI = axes('Parent', figS, 'Position', [x y cellW cellH]);
        imshow(imread(pngList{k}), 'Parent', axI);
        axis(axI, 'off');
        annotation(figS, 'textbox', [x y+cellH+0.005 cellW 0.035], ...
            'String', lblList{k}, 'Color','w', 'EdgeColor','none', ...
            'FontName','Arial', 'FontSize',13, 'FontWeight','bold', ...
            'HorizontalAlignment','center', 'Interpreter','none');
    end

    print(figS, outFile, '-dpng', sprintf('-r%d', dpiVal), '-opengl');
    close(figS);
end

function writePptFromSlidePNGs(pptPath, slidePNGs)
    import mlreportgen.ppt.*
    if nargin < 2 || isempty(slidePNGs)
        error('No slide PNGs were provided for PPT export.');
    end
    pptDir = fileparts(pptPath);
    safeMkdirIfNeeded(pptDir);
    if exist(pptPath, 'file') == 2
        error('SCM:PptExists','The PowerPoint file already exists. Export again to create a new file: %s', pptPath);
    end
    stagedPath = [tempname(pptDir) '.pptx'];
    stagedGuard = onCleanup(@()deleteStagedPptLocal(stagedPath)); %#ok<NASGU>
    ppt = [];
    try
        ppt = Presentation(stagedPath);
        open(ppt);
        for i = 1:numel(slidePNGs)
            imgFile = slidePNGs{i};
            if exist(imgFile, 'file') ~= 2
                error('SCM:PptImageMissing','Slide image is missing: %s', imgFile);
            end
            try
                slide = add(ppt, 'Blank');
            catch
                slide = add(ppt);
            end
            pic = Picture(imgFile);
            pic.X = '0in';
            pic.Y = '0in';
            pic.Width = '13.333in';
            pic.Height = '7.5in';
            add(slide, pic);
        end
        close(ppt);
        scmPublishPpt(stagedPath, pptPath, numel(slidePNGs));
    catch ME
        try, if ~isempty(ppt), close(ppt); end, catch, end
        error('PowerPoint export failed: %s', ME.message);
    end
end

function writePptFromSlidePNGsWithEditableTiles(pptPath, slidePNGs, slideSpecs)
    import mlreportgen.ppt.*
    if nargin < 2 || isempty(slidePNGs)
        error('No slide PNGs were provided for PPT export.');
    end
    pptDir = fileparts(pptPath);
    safeMkdirIfNeeded(pptDir);
    if exist(pptPath, 'file') == 2
        error('SCM:PptExists','The PowerPoint file already exists. Export again to create a new file: %s', pptPath);
    end
    stagedPath = [tempname(pptDir) '.pptx'];
    stagedGuard = onCleanup(@()deleteStagedPptLocal(stagedPath)); %#ok<NASGU>

    slideW = 13.333;
    slideH = 7.5;
    x0 = 0.08;
    colGap = 0.02;
    yBot = 0.12;
    rowGap = 0.06;
    cellH = (0.86 - 0.12 - rowGap) / 2;
    cellW = (0.98 - 0.08 - 2*colGap) / 3;

    ppt = [];
    try
        ppt = Presentation(stagedPath);
        open(ppt);
        for i = 1:numel(slidePNGs)
            bgFile = slidePNGs{i};
            if exist(bgFile, 'file') ~= 2
                error('SCM:PptImageMissing','Slide background is missing: %s', bgFile);
            end
            try
                slide = add(ppt, 'Blank');
            catch
                slide = add(ppt);
            end

            bgPic = Picture(bgFile);
            bgPic.X = '0in';
            bgPic.Y = '0in';
            bgPic.Width = sprintf('%.3fin', slideW);
            bgPic.Height = sprintf('%.3fin', slideH);
            add(slide, bgPic);

            if i <= numel(slideSpecs) && isfield(slideSpecs{i}, 'pngList')
                pngList = slideSpecs{i}.pngList;
                nThis = min(6, numel(pngList));
                for k = 1:nThis
                    imgFile = pngList{k};
                    if exist(imgFile, 'file') ~= 2
                        error('SCM:PptImageMissing','SCM tile image is missing: %s', imgFile);
                    end
                    if k <= 3
                        cc = k - 1;
                        yNorm = yBot + cellH + rowGap;
                    else
                        cc = k - 4;
                        yNorm = yBot;
                    end
                    xNorm = x0 + cc*(cellW + colGap);
                    xIn = xNorm * slideW;
                    wIn = cellW * slideW;
                    hIn = cellH * slideH;
                    yIn = (1 - (yNorm + cellH)) * slideH;
                    pic = Picture(imgFile);
                    pic.X = sprintf('%.3fin', xIn);
                    pic.Y = sprintf('%.3fin', yIn);
                    pic.Width = sprintf('%.3fin', wIn);
                    pic.Height = sprintf('%.3fin', hIn);
                    add(slide, pic);
                end
            end
        end
        close(ppt);
        scmPublishPpt(stagedPath, pptPath, numel(slidePNGs));
    catch ME
        try, if ~isempty(ppt), close(ppt); end, catch, end
        error('PowerPoint export failed: %s', ME.message);
    end
end

function deleteStagedPptLocal(stagedPath)
    % Only the writer's private staging file is disposable. Exported images
    % and any previously published deck must survive a failed export.
    if exist(stagedPath,'file') == 2
        try, delete(stagedPath); catch, end
    end
end

function tf = canUsePptApi()
    tf = false;
    try
        tf = ~isempty(which('mlreportgen.ppt.Presentation'));
    catch
        tf = false;
    end
end

function pptPath = chooseShortPptPath(outDir, ~, stamp)
    pptPath = fullfile(outDir, sprintf('SCM_series_%s.pptx', stamp));
end

function pptPath = chooseShortSinglePptPath(outDir, ~, stamp)
    pptPath = fullfile(outDir, sprintf('SCM_%s.pptx', stamp));
end

function exportForGroupAnalysisCB(~,~)
    if ~state.isAtlasWarped
        warndlg(['Export for Group Analysis requires atlas-warped functional data.' newline ...
            'Please use "WARP FUNCTIONAL TO ATLAS" first.'], 'Group Analysis export');
        return;
    end
    try
        Pexp = getGroupBundleExportPathsLocal();
        safeMkdirIfNeeded(Pexp.bundleRoot); safeMkdirIfNeeded(Pexp.bundleDir);
        [b0,b1] = parseRangeSafe(getStr(ebBase),30,240);
        [s0,s1] = parseRangeSafe(getStr(ebSig),840,900);
        sigma = str2double(getStr(ebSigma)); if ~isfinite(sigma), sigma = 0; end
        thr = str2double(getStr(ebThr)); if ~isfinite(thr), thr = 0; end
        stamp = datestr(now,'yyyymmdd_HHMMSS');
        outFile = makeShortGroupBundleOutFileLocal(Pexp, stamp);
        G = struct();
        G.kind = 'SCM_GROUP_EXPORT'; G.version = '1.0'; G.created = datestr(now,'yyyy-mm-dd HH:MM:SS');
        G.fileLabel = fileLabel; G.loadedFile = safeParFieldLocal('loadedFile'); G.loadedPath = safeParFieldLocal('loadedPath'); G.exportPath = safeParFieldLocal('exportPath');
        G.animalID = Pexp.animalID; G.session = Pexp.session; G.scanID = Pexp.scanID; G.subjectKey = Pexp.subjectKey;
        G.isAtlasWarped = logical(state.isAtlasWarped); G.atlasTransformFile = state.atlasTransformFile; G.atlasSliceIndex = state.z;
        G.baseWindowStr = getStr(ebBase); G.sigWindowStr = getStr(ebSig); G.baseWindowSec = [b0 b1]; G.sigWindowSec = [s0 s1]; G.sigma = sigma;
        G.baseline=baseline;
        G.display = struct('threshold',thr,'caxis',state.cax,'alphaPercent',get(slAlpha,'Value'), ...
    'alphaModOn',logical(state.alphaModOn),'modMin',state.modMin,'modMax',state.modMax, ...
    'colormapName',getCurrentPopupStringLocal(popMap),'signMode',state.signMode);

% Store exact SCM colormap for GroupAnalysis PPT export.
try
    G.display.cmapMatrix = colormap(ax);
catch
    G.display.cmapMatrix = getCmap(getCurrentPopupStringLocal(popMap), 256);
end

% Useful marker so GroupAnalysis knows this bundle can be exported SCM-style.
G.display.exportStyle = 'SCM_gui_6tile_black_editable_ppt';
        G.TR = TR; G.tsec = tsec; G.tmin = tmin; G.nY = nY; G.nX = nX; G.nZ = nZ; G.nT = nT;
        G.pscAtlas4D = PSC; G.scmMapSignedAtlas = state.lastSignedMap; G.scmMapDisplayAtlas = get(hOV,'CData'); G.alphaAtlas = get(hOV,'AlphaData');
        ensureAtlasUnderlayLibraryForExportLocal();
        G.underlayAtlas = bg;
        G.underlays = state.atlasUnderlays;
        G.underlaySelectedMode = state.atlasUnderlayChoice;
        G.underlayBuildMessage = state.lastAtlasUnderlayBuildMessage;
        G.underlayInfo = struct();
        G.underlayInfo.availableModes = fieldnames(state.atlasUnderlays);
        G.underlayInfo.selectedMode = state.atlasUnderlayChoice;
        G.underlayInfo.isColorUnderlay = logical(state.isColorUnderlay);
        G.underlayInfo.regionLabelUnderlay = state.regionLabelUnderlay;
        G.underlayInfo.regionInfo = state.regionInfo;
        if ~isempty(state.atlasRegionSearch)
            G.atlasRegionLabels3D=state.atlasRegionSearch.labels;
            G.atlasInfoRegions=state.atlasRegionSearch.info;
            G.atlasRegionProvenance=state.atlasRegionSearch.provenance;
        end
        G.mask2DCurrentSlice = mask2D; G.maskAtlas = passedMask; G.maskIsInclude = passedMaskIsInclude; G.injectionSide = '?';
        [outFile, saveReport] = safeSaveScmGroupBundleLocal(outFile, G);

        % TARGETED_SCM_LOCAL_BUNDLE_COPY_20260622
        % Also copy the saved bundle into the loaded animal folder.
        localCopyFile = '';
        localCopyReport = '';
        try
            if isfield(Pexp,'localBundleDir') && ~isempty(Pexp.localBundleDir)
                safeMkdirIfNeeded(Pexp.localBundleDir);
                [~,copyName,copyExt] = fileparts(outFile);
                if isempty(copyExt), copyExt = '.mat'; end
                localCopyFile = fullfile(Pexp.localBundleDir, [copyName copyExt]);
                if ~strcmpi(char(localCopyFile), char(outFile))
                    copyfile(outFile, localCopyFile);
                    localCopyReport = sprintf('\n\nAdditional copy saved in loaded-animal folder:\n%s', localCopyFile);
                    fprintf('[SCM EXPORT] Additional local copy: %s\n', localCopyFile);
                end
            end
        catch MEcopy
            localCopyReport = sprintf('\n\nWarning: could not create additional loaded-animal copy:\n%s', MEcopy.message);
            try, warning('%s', strtrim(localCopyReport)); catch, end
        end

        tipFile = outFile;
        if ~isempty(localCopyFile)
            tipFile = sprintf('%s\nLocal copy: %s', outFile, localCopyFile);
        end
        set(info1,'String',['Group bundle saved: ' shortenPath(outFile,85)], 'TooltipString', tipFile);
        msgbox(sprintf('Saved GroupAnalysis bundle:\n%s%s', outFile, localCopyReport), 'SCM group export');
    catch ME
        errordlg(ME.message, 'Export for Group Analysis failed');
    end
end


%% PATCH_SCM_ATLAS_UNDERLAY_LIBRARY_V1
function modeName = askAtlasUnderlayChoiceLocal(contextName)
    modeName = 'normal';
    try
        labels = { ...
            'Normal / functional underlay (recommended)', ...
            'Histology atlas', ...
            'Vascular atlas', ...
            'Regions atlas'};
        vals = {'normal','histology','vascular','regions'};
        defIdx = 1;
        try
            if isfield(state,'atlasUnderlayChoice') && ~isempty(state.atlasUnderlayChoice)
                hit = find(strcmpi(vals, char(state.atlasUnderlayChoice)), 1);
                if ~isempty(hit), defIdx = hit; end
            end
        catch
            defIdx = 1;
        end
        prompt = {'Choose the atlas underlay to display after warping:', '', ...
            'All available underlays will also be saved into the SCM GroupAnalysis bundle.'};
        if nargin >= 1 && ~isempty(contextName)
            prompt{1} = sprintf('Choose the atlas underlay to display after %s atlas warp:', char(contextName));
        end
        [idx,tf] = listdlg('PromptString',prompt, 'SelectionMode','single', ...
            'ListString',labels, 'InitialValue',defIdx, 'ListSize',[620 245], 'Name','SCM atlas underlay');
        if tf && ~isempty(idx), modeName = vals{idx(1)}; end
    catch
        modeName = 'normal';
    end
end

function [lib, bgOut, msgOut, metaOut] = buildAtlasUnderlayLibrarySingleLocal(tfFile, T, PSCatlas, selectedMode)
    lib = emptyAtlasUnderlayLibraryLocal();
    metaNormal = defaultUnderlayMeta();
    Udefault = makeFunctionalContrastFallbackUnderlay(PSCatlas);
    lib.normal = packAtlasUnderlayEntryLocal('normal', Udefault, 'normal functional atlas-space underlay', metaNormal);

    outSize2 = currentOutputSizeFromDataLocal(PSCatlas);
    modes = {'histology','vascular','regions'};
    for ii = 1:numel(modes)
        modeName = modes{ii};
        [U,msg,meta] = readAtlasUnderlayModeFromRegFileLocal(tfFile, T, outSize2, modeName);
        if ~isempty(U)
            lib.(modeName) = packAtlasUnderlayEntryLocal(modeName, U, msg, meta);
        else
            lib.(modeName) = packAtlasUnderlayEntryLocal(modeName, [], ['not found: ' modeName], metaForAtlasModeLocal(modeName));
        end
    end

    [bgOut, metaOut, msgOut, selectedMode] = selectUnderlayFromLibraryLocal(lib, selectedMode);
    state.atlasUnderlayChoice = selectedMode;
end

function [lib, bgOut, msgOut, metaOut] = buildAtlasUnderlayLibraryStepMotorLocal(usedRegList, outSize2, PSCatlas, currentUnderlay, selectedMode)
    lib = emptyAtlasUnderlayLibraryLocal();

    metaNormal = defaultUnderlayMeta();
    Unormal = [];
    try
        if underlayMatchesTargetDims(currentUnderlay, round(outSize2(1)), round(outSize2(2)), getAtlasStackDepthLocal(PSCatlas))
            Unormal = double(currentUnderlay);
        end
    catch
        Unormal = [];
    end
    if isempty(Unormal)
        Unormal = makeFunctionalContrastFallbackUnderlay(PSCatlas);
    end
    lib.normal = packAtlasUnderlayEntryLocal('normal', Unormal, 'normal functional atlas-space underlay', metaNormal);

    modes = {'histology','vascular','regions'};
    for ii = 1:numel(modes)
        modeName = modes{ii};
        [U,msg,meta] = buildStepMotorAtlasUnderlayByModeLocal(usedRegList, outSize2, modeName);
        if ~isempty(U)
            lib.(modeName) = packAtlasUnderlayEntryLocal(modeName, U, msg, meta);
        else
            lib.(modeName) = packAtlasUnderlayEntryLocal(modeName, [], ['not found: ' modeName], metaForAtlasModeLocal(modeName));
        end
    end

    [bgOut, metaOut, msgOut, selectedMode] = selectUnderlayFromLibraryLocal(lib, selectedMode);
    state.atlasUnderlayChoice = selectedMode;
end

function [Uatlas, msg, meta] = buildStepMotorAtlasUnderlayByModeLocal(usedRegList, outSize2, modeName)
    Uatlas = [];
    msg = ['not found: ' modeName];
    meta = metaForAtlasModeLocal(modeName);

    if isempty(usedRegList) || isempty(outSize2) || numel(outSize2) < 2
        return;
    end

    yy = round(double(outSize2(1)));
    xx = round(double(outSize2(2)));
    nUse = numel(usedRegList);
    if yy < 1 || xx < 1 || nUse < 1, return; end

    Utmp = zeros(yy, xx, nUse, 'single');
    got = false(1,nUse);

    for rr = 1:nUse
        try
            T = usedRegList(rr).T;
            [Uplane,~,metaPlane] = readAtlasUnderlayModeFromRegFileLocal(usedRegList(rr).file, T, [yy xx], modeName);
            if isempty(Uplane), continue; end
            Uplane = fitPlaneToSizeLocal(Uplane, yy, xx);
            Uplane(~isfinite(Uplane)) = 0;
            if hasUsableUnderlaySignal(Uplane) || strcmpi(modeName,'regions')
                Utmp(:,:,rr) = single(Uplane);
                got(rr) = true;
                meta = metaPlane;
            end
        catch
        end
    end

    if ~any(got)
        return;
    end

    Utmp = fillMissingUnderlayPlanesLocal(Utmp, got);
    Uatlas = double(Utmp);
    if all(got)
        msg = sprintf('used %s atlas underlays from all %d Registration2D files', modeName, nUse);
    else
        msg = sprintf('used %s atlas underlays from %d/%d Registration2D files; missing planes were filled', modeName, nnz(got), nUse);
    end
end

function [U, msg, meta] = readAtlasUnderlayModeFromRegFileLocal(matFile, T, outSize2, modeName)
    U = [];
    msg = ['not found: ' modeName];
    meta = metaForAtlasModeLocal(modeName);

    if isempty(matFile) || exist(matFile,'file') ~= 2
        return;
    end

    try
        S = load(matFile);
    catch
        return;
    end

    [U,msg] = extractModeUnderlayFromStructLocal(S, T, outSize2, modeName, matFile);
    if ~isempty(U), return; end

    extFile = findExternalAtlasUnderlayFileLocal(matFile, modeName, T);
    if ~isempty(extFile)
        try
            S2 = load(extFile);
            [U,msg] = extractModeUnderlayFromStructLocal(S2, T, outSize2, modeName, extFile);
        catch
            U = [];
        end
    end
end

function [U, msg] = extractModeUnderlayFromStructLocal(S, T, outSize2, modeName, sourceLabel)
    U = [];
    msg = ['not found: ' modeName];

    fields = getAtlasModeFieldsLocal(modeName, T);
    sources = {S};
    wrappers = {'Reg2D','Transf','RegOut','Registration2D'};
    for ww = 1:numel(wrappers)
        if isfield(S,wrappers{ww}) && isstruct(S.(wrappers{ww}))
            sources{end+1} = S.(wrappers{ww}); %#ok<AGROW>
        end
    end

    for ss = 1:numel(sources)
        R = sources{ss};
        for ff = 1:numel(fields)
            fn = fields{ff};
            if isstruct(R) && isfield(R,fn)
                U = acceptAtlasModeCandidateLocal(R.(fn), T, outSize2, modeName);
                if ~isempty(U)
                    msg = sprintf('used %s from %s field %s', modeName, shortenPath(sourceLabel,70), fn);
                    return;
                end
            end
        end
    end
end

function fields = getAtlasModeFieldsLocal(modeName, T)
    modeName = lower(char(modeName));
    switch modeName
        case 'histology'
            fields = {'histologyImage','histologyUnderlay','histologyFixed','histology','atlasHistology','atlasUnderlayHistology'};
        case 'vascular'
            fields = {'vascularImage','vascularUnderlay','vascularFixed','vascular','atlasVascular','atlasUnderlayVascular'};
        case 'regions'
            fields = {'atlasRegionLabels2D','atlasRegionLabelsLR2D','regionsImage','regionsUnderlay','regionsFixed','regions','regionLabels','labelMap','atlasLabels','annotation'};
        otherwise
            fields = {};
    end

    try
        if isfield(T,'atlasMode') && strcmpi(char(T.atlasMode), modeName)
            fields = [fields {'fixedImage','fixedUnderlay','targetImage','targetUnderlay','atlasUnderlay','atlasUnderlayRGB'}];
        end
    catch
    end

    if strcmpi(modeName,'regions')
        fields = [fields {'atlasUnderlay'}];
    end
end

function U = acceptAtlasModeCandidateLocal(v, T, outSize2, modeName)
    U = [];
    if isempty(v), return; end

    if isstruct(v)
        subFields = getAtlasModeFieldsLocal(modeName, T);
        subFields = [subFields {'Data','data','image','img','I','underlay'}];
        for ii = 1:numel(subFields)
            if isfield(v,subFields{ii})
                U = acceptAtlasModeCandidateLocal(v.(subFields{ii}), T, outSize2, modeName);
                if ~isempty(U), return; end
            end
        end
        return;
    end

    if ~(isnumeric(v) || islogical(v)), return; end
    A = squeeze(double(v));
    if isempty(A) || ndims(A) < 2, return; end
    if size(A,1) < 16 || size(A,2) < 16, return; end
    if size(A,1) ~= outSize2(1) || size(A,2) ~= outSize2(2), return; end

    if ndims(A) == 2
        U = A;
        return;
    end

    if ndims(A) == 3
        if size(A,3) == 3
            if strcmpi(modeName,'regions')
                U = rgbToGrayLocal(A);
            else
                U = rgbToGrayLocal(A);
            end
            return;
        end
        zPick = round(size(A,3)/2);
        try
            if isfield(T,'atlasSliceIndex') && ~isempty(T.atlasSliceIndex) && isfinite(T.atlasSliceIndex)
                zPick = round(T.atlasSliceIndex);
            end
        catch
        end
        zPick = max(1,min(size(A,3),zPick));
        U = A(:,:,zPick);
        return;
    end

    if ndims(A) == 4
        if size(A,3) == 3
            zPick = 1;
            try
                if isfield(T,'atlasSliceIndex') && ~isempty(T.atlasSliceIndex) && isfinite(T.atlasSliceIndex)
                    zPick = round(T.atlasSliceIndex);
                end
            catch
            end
            zPick = max(1,min(size(A,4),zPick));
            U = rgbToGrayLocal(squeeze(A(:,:,:,zPick)));
            return;
        elseif size(A,4) == 3
            zPick = round(size(A,3)/2);
            try
                if isfield(T,'atlasSliceIndex') && ~isempty(T.atlasSliceIndex) && isfinite(T.atlasSliceIndex)
                    zPick = round(T.atlasSliceIndex);
                end
            catch
            end
            zPick = max(1,min(size(A,3),zPick));
            U = rgbToGrayLocal(squeeze(A(:,:,zPick,:)));
            return;
        end
    end
end

function extFile = findExternalAtlasUnderlayFileLocal(matFile, modeName, T)
    extFile = '';
    try
        [folder0,~,~] = fileparts(matFile);
        if isempty(folder0) || exist(folder0,'dir') ~= 7, return; end
        atlasIdx = NaN;
        if isfield(T,'atlasSliceIndex') && ~isempty(T.atlasSliceIndex) && isfinite(T.atlasSliceIndex)
            atlasIdx = round(T.atlasSliceIndex);
        end
        cand = {};
        if isfinite(atlasIdx)
            cand{end+1} = fullfile(folder0, sprintf('AtlasUnderlay_%s_slice%03d.mat', lower(modeName), atlasIdx)); %#ok<AGROW>
            cand{end+1} = fullfile(folder0, sprintf('*%s*slice%03d*.mat', lower(modeName), atlasIdx)); %#ok<AGROW>
        end
        cand{end+1} = fullfile(folder0, sprintf('*%s*.mat', lower(modeName))); %#ok<AGROW>
        for ii = 1:numel(cand)
            d0 = dir(cand{ii});
            if ~isempty(d0)
                extFile = fullfile(d0(1).folder, d0(1).name);
                return;
            end
        end
    catch
        extFile = '';
    end
end

function Utmp = fillMissingUnderlayPlanesLocal(Utmp, got)
    if all(got), return; end
    nUse = numel(got);
    firstGood = find(got,1,'first');
    if isempty(firstGood), return; end
    lastGood = firstGood;
    for rr = 1:nUse
        if got(rr)
            lastGood = rr;
        else
            nextGood = find(got & (1:nUse) >= rr, 1, 'first');
            if isempty(nextGood), nextGood = lastGood; end
            if rr > lastGood
                useIdx = lastGood;
            else
                useIdx = nextGood;
            end
            Utmp(:,:,rr) = Utmp(:,:,useIdx);
        end
    end
end

function meta = metaForAtlasModeLocal(modeName)
    meta = defaultUnderlayMeta();
    try, meta.atlasMode = lower(char(modeName)); catch, meta.atlasMode = ''; end
    if strcmpi(modeName,'regions')
        meta.isColor = true;
    end
end

function E = packAtlasUnderlayEntryLocal(modeName, U, msg, meta)
    if nargin < 4 || isempty(meta), meta = metaForAtlasModeLocal(modeName); end
    E = struct();
    E.mode = modeName;
    E.data = U;
    E.ok = ~isempty(U);
    E.message = msg;
    E.meta = meta;
end

function lib = emptyAtlasUnderlayLibraryLocal()
    lib = struct();
    names = {'normal','histology','vascular','regions'};
    for ii = 1:numel(names)
        lib.(names{ii}) = packAtlasUnderlayEntryLocal(names{ii}, [], 'not built', metaForAtlasModeLocal(names{ii}));
    end
end

function [bgOut, metaOut, msgOut, selectedMode] = selectUnderlayFromLibraryLocal(lib, selectedMode)
    if nargin < 2 || isempty(selectedMode), selectedMode = 'normal'; end
    selectedMode = lower(char(selectedMode));
    if ~isfield(lib, selectedMode) || ~lib.(selectedMode).ok
        if isfield(lib,'normal') && lib.normal.ok
            selectedMode = 'normal';
        else
            names = fieldnames(lib);
            for ii = 1:numel(names)
                if isfield(lib.(names{ii}),'ok') && lib.(names{ii}).ok
                    selectedMode = names{ii};
                    break;
                end
            end
        end
    end
    E = lib.(selectedMode);
    bgOut = E.data;
    metaOut = E.meta;
    msgOut = sprintf('%s selected; %s', selectedMode, E.message);
end

function outSize2 = currentOutputSizeFromDataLocal(X)
    outSize2 = [nY nX];
    try
        outSize2 = [size(X,1) size(X,2)];
    catch
    end
end

function zz = getAtlasStackDepthLocal(X)
    zz = 1;
    try
        if ndims(X) == 4
            zz = size(X,3);
        elseif ndims(X) == 3 && nZ > 1
            zz = size(X,3);
        end
    catch
        zz = 1;
    end
end

function applyRecommendedUnderlayDisplayForModeLocal(modeName)
    try
        modeName = lower(char(modeName));
    catch
        modeName = 'normal';
    end

    switch modeName
        case 'normal'
            uState.mode = 3;
            uState.brightness = -0.04;
            uState.contrast = 1.10;
            uState.gamma = 0.95;
        case {'histology','vascular'}
            uState.mode = 2;
            uState.brightness = 0;
            uState.contrast = 1;
            uState.gamma = 1;
        case 'regions'
            uState.mode = 2;
            uState.brightness = 0;
            uState.contrast = 1;
            uState.gamma = 1;
    end

    try
        set(popUnder, 'Value', uState.mode);
        set(slBri, 'Value', uState.brightness);
        set(slCon, 'Value', uState.contrast);
        set(slGam, 'Value', uState.gamma);
        set(txtBri, 'String', sprintf('%.2f', uState.brightness));
        set(txtCon, 'String', sprintf('%.2f', uState.contrast));
        set(txtGam, 'String', sprintf('%.2f', uState.gamma));
        updateUnderlayControlsEnable();
    catch
    end
end

function ensureAtlasUnderlayLibraryForExportLocal()
    try
        hasLib = isfield(state,'atlasUnderlays') && isstruct(state.atlasUnderlays) && ...
            isfield(state.atlasUnderlays,'normal') && isfield(state.atlasUnderlays.normal,'ok') && state.atlasUnderlays.normal.ok;
    catch
        hasLib = false;
    end

    if hasLib
        return;
    end

    lib = emptyAtlasUnderlayLibraryLocal();
    try
        if ~isempty(bg)
            lib.normal = packAtlasUnderlayEntryLocal('normal', bg, 'current SCM underlay fallback', defaultUnderlayMeta());
        else
            lib.normal = packAtlasUnderlayEntryLocal('normal', makeFunctionalContrastFallbackUnderlay(PSC), 'functional fallback', defaultUnderlayMeta());
        end
    catch
    end

    state.atlasUnderlays = lib;
    if ~isfield(state,'atlasUnderlayChoice') || isempty(state.atlasUnderlayChoice)
        state.atlasUnderlayChoice = 'normal';
    end
    if ~isfield(state,'lastAtlasUnderlayBuildMessage')
        state.lastAtlasUnderlayBuildMessage = 'fallback library built during export';
    end
end

function [outFileFinal, saveReport] = safeSaveScmGroupBundleLocal(outFile, G)
% PATCH_SCM_SAFE_SAVE_V2
    wantedOutFile = outFile;
    outFileFinal = outFile;
    saveReport = '';
    try
        if nargin < 2 || isempty(G)
            error('Bundle variable G is empty.');
        end

        [wantedDir,wantedName,wantedExt] = fileparts(wantedOutFile);
        if isempty(wantedExt), wantedExt = '.mat'; end
        if isempty(wantedName), wantedName = ['SCM_GroupExport_' datestr(now,'yyyymmdd_HHMMSS')]; end
        if isempty(wantedDir), wantedDir = pwd; end

        outCandidates = {};
        outCandidates{end+1} = fullfile(wantedDir, [wantedName wantedExt]);

        try
            scmDir = fileparts(mfilename('fullpath'));
            if ~isempty(scmDir)
                outCandidates{end+1} = fullfile(scmDir, 'SCM_GroupAnalysis_Exports', [wantedName wantedExt]);
            end
        catch
        end

        try
            up = userpath;
            if ~isempty(up)
                if iscell(up), up = up{1}; end
                semi = strfind(up, pathsep);
                if ~isempty(semi), up = up(1:semi(1)-1); end
                if ~isempty(up)
                    outCandidates{end+1} = fullfile(up, 'deConfUSIon_SCM_GroupExports', [wantedName wantedExt]);
                end
            end
        catch
        end

        outCandidates{end+1} = fullfile(tempdir, 'deConfUSIon_SCM_GroupExports', [wantedName wantedExt]);

        Gfull = sanitizeBundleForMatSaveLocal(G);
        Gsingle = convertLargeBundleArraysToSingleLocal(Gfull);
        Gslim = makeEmergencySlimBundleLocal(Gsingle);

        payloads = {Gfull, Gsingle, Gslim};
        payloadLabels = {'FULL', 'FULL_SINGLE_ARRAYS', 'EMERGENCY_SLIM_NO_4D_PSC'};
        allErrors = {}; 

        for pp = 1:numel(payloads)
            Gtry = payloads{pp};
            try
                if ~isfield(Gtry,'saveInfo') || ~isstruct(Gtry.saveInfo)
                    Gtry.saveInfo = struct();
                end
                Gtry.saveInfo.saver = 'SCM_gui safeSaveScmGroupBundleLocal V2';
                Gtry.saveInfo.payloadMode = payloadLabels{pp};
                Gtry.saveInfo.requestedOutFile = wantedOutFile;
                Gtry.saveInfo.savedAt = datestr(now,'yyyy-mm-dd HH:MM:SS');
            catch
            end

            for cc = 1:numel(outCandidates)
                destFile = outCandidates{cc};
                try
                    [ok,msg2,actualDest] = tryOneScmBundleSaveLocal(destFile, Gtry, payloadLabels{pp});
                    if ok
                        outFileFinal = actualDest;
                        if strcmp(actualDest, wantedOutFile) && strcmp(payloadLabels{pp},'FULL')
                            saveReport = sprintf('SCM bundle saved successfully: %s', actualDest);
                        else
                            saveReport = sprintf(['SCM bundle saved with fallback.' char(10) ...
                                'Requested: %s' char(10) ...
                                'Actual:    %s' char(10) ...
                                'Mode:      %s' char(10) ...
                                'Reason:    %s'], wantedOutFile, actualDest, payloadLabels{pp}, msg2);
                        end
                        fprintf('\n[SCM EXPORT]\n%s\n', saveReport);
                        if ~strcmp(payloadLabels{pp},'FULL')
                            try, warndlg(saveReport, 'SCM group export fallback'); catch, end
                        end
                        return;
                    else
                        allErrors{end+1} = sprintf('%s -> %s', destFile, msg2); %#ok<AGROW>
                    end
                catch MEtry
                    allErrors{end+1} = sprintf('%s -> %s', destFile, MEtry.message); %#ok<AGROW>
                end
            end
        end

        errTxt = sprintf('%s\n', allErrors{:});
        error(['Could not save SCM GroupAnalysis bundle after all fallback attempts.' char(10) char(10) errTxt]);
    catch ME
        error(['Could not save SCM GroupAnalysis bundle.' char(10) ME.message]);
    end
end

function [ok,msg,actualDest] = tryOneScmBundleSaveLocal(destFile, G, payloadLabel)
    destFile=fusiAnalysisOutputPath(destFile);
    ok = false;
    msg = '';
    actualDest = destFile;
    tmpFile = '';
    try
        [destDir,destName,destExt] = fileparts(destFile);
        if isempty(destExt), destExt = '.mat'; end
        if isempty(destDir), destDir = pwd; end
        if exist(destDir,'dir') ~= 7
            mkdir(destDir);
        end

        if ~isWritableFolderScmLocal(destDir)
            msg = 'destination folder is not writable';
            return;
        end

        actualDest = uniqueMatFileNameScmLocal(fullfile(destDir,[destName destExt]));
        tmpDir = fullfile(tempdir, 'deConfUSIon_SCM_tmp');
        if exist(tmpDir,'dir') ~= 7, mkdir(tmpDir); end
        tmpFile = fullfile(tmpDir, sprintf('__SCM_tmp_%s_%06d.mat', datestr(now,'yyyymmdd_HHMMSS_FFF'), randi(999999)));

        saveWorked = false;
        saveMsg = '';
        try
            save(tmpFile, 'G', '-v7.3', '-nocompression');
            saveWorked = true;
        catch ME1
            saveMsg = ME1.message;
            try
                save(tmpFile, 'G', '-v7.3');
                saveWorked = true;
            catch ME2
                saveMsg = [saveMsg ' | normal -v7.3: ' ME2.message];
            end
        end

        if ~saveWorked
            msg = ['MATLAB could not write temp MAT: ' saveMsg];
            try, if exist(tmpFile,'file')==2, delete(tmpFile); end, catch, end
            return;
        end

        info = whos('-file', tmpFile, 'G');
        if isempty(info)
            msg = 'temp MAT written but variable G could not be verified';
            try, delete(tmpFile); catch, end
            return;
        end

        [okCopy,copyMsg] = copyfile(tmpFile, actualDest, 'f');
        if ~okCopy
            msg = ['copy to destination failed: ' copyMsg];
            try, delete(tmpFile); catch, end
            return;
        end

        info2 = whos('-file', actualDest, 'G');
        if isempty(info2)
            msg = 'final MAT copied but variable G could not be verified';
            try, delete(tmpFile); catch, end
            return;
        end

        ok = true;
        msg = ['saved using payload ' payloadLabel];
        try, delete(tmpFile); catch, end
    catch ME
        msg = ME.message;
        try, if ~isempty(tmpFile) && exist(tmpFile,'file')==2, delete(tmpFile); end, catch, end
    end
end

function tf = isWritableFolderScmLocal(folderName)
    tf = false;
    try
        if exist(folderName,'dir') ~= 7, mkdir(folderName); end
        testFile = fullfile(folderName, ['__write_test_' datestr(now,'yyyymmdd_HHMMSS_FFF') '.tmp']);
        fid = fopen(testFile,'w');
        if fid < 0, return; end
        fprintf(fid,'test');
        fclose(fid);
        delete(testFile);
        tf = true;
    catch
        tf = false;
    end
end

function f2 = uniqueMatFileNameScmLocal(f1)
    f2 = f1;
    try
        [p,n,e] = fileparts(f1);
        if isempty(e), e = '.mat'; end
        k = 1;
        while exist(f2,'file') == 2
            f2 = fullfile(p, sprintf('%s_%02d%s', n, k, e));
            k = k + 1;
            if k > 999, break; end
        end
    catch
        f2 = f1;
    end
end

function G2 = sanitizeBundleForMatSaveLocal(G1)
    G2 = sanitizeOneValueForMatSaveLocal(G1, 0);
end

function v = sanitizeOneValueForMatSaveLocal(v, depth)
    if nargin < 2, depth = 0; end
    if depth > 12
        return;
    end
    try
        if isa(v,'function_handle')
            v = func2str(v);
            return;
        end
    catch
    end
    try
        if isgraphics(v)
            v = [];
            return;
        end
    catch
    end
    if isstruct(v)
        fn = fieldnames(v);
        for ii = 1:numel(v)
            for jj = 1:numel(fn)
                try
                    v(ii).(fn{jj}) = sanitizeOneValueForMatSaveLocal(v(ii).(fn{jj}), depth+1);
                catch
                    try, v(ii).(fn{jj}) = []; catch, end
                end
            end
        end
    elseif iscell(v)
        for ii = 1:numel(v)
            try
                v{ii} = sanitizeOneValueForMatSaveLocal(v{ii}, depth+1);
            catch
                v{ii} = [];
            end
        end
    else
        try
            if isobject(v)
                v = [];
            end
        catch
        end
    end
end

function G2 = convertLargeBundleArraysToSingleLocal(G1)
    G2 = G1;
    try, G2.pscAtlas4D = convertNumericToSingleIfLargeLocal(G2.pscAtlas4D); catch, end
    try, G2.scmMapSignedAtlas = convertNumericToSingleIfLargeLocal(G2.scmMapSignedAtlas); catch, end
    try, G2.scmMapDisplayAtlas = convertNumericToSingleIfLargeLocal(G2.scmMapDisplayAtlas); catch, end
    try, G2.alphaAtlas = convertNumericToSingleIfLargeLocal(G2.alphaAtlas); catch, end
    try, G2.underlayAtlas = convertNumericToSingleIfLargeLocal(G2.underlayAtlas); catch, end
    try
        if isfield(G2,'underlays') && isstruct(G2.underlays)
            f = fieldnames(G2.underlays);
            for ii = 1:numel(f)
                try
                    if isfield(G2.underlays.(f{ii}),'data')
                        G2.underlays.(f{ii}).data = convertNumericToSingleIfLargeLocal(G2.underlays.(f{ii}).data);
                    end
                catch
                end
            end
        end
    catch
    end
    try
        if ~isfield(G2,'saveInfo') || ~isstruct(G2.saveInfo), G2.saveInfo = struct(); end
        G2.saveInfo.note = 'Large double arrays may have been converted to single precision after full save failed.';
    catch
    end
end

function A = convertNumericToSingleIfLargeLocal(A)
    try
        if isnumeric(A) && isa(A,'double') && numel(A) > 1e5
            A = single(A);
        end
    catch
    end
end

function G2 = makeEmergencySlimBundleLocal(G1)
    G2 = G1;
    try
        if isfield(G2,'pscAtlas4D')
            G2.pscAtlas4D_originalSize = size(G2.pscAtlas4D);
            G2.pscAtlas4D_originalClass = class(G2.pscAtlas4D);
            try
                G2.pscAtlas4D_meanPreview = single(mean(G2.pscAtlas4D, ndims(G2.pscAtlas4D), 'omitnan'));
            catch
                try, G2.pscAtlas4D_meanPreview = single(mean(G2.pscAtlas4D, ndims(G2.pscAtlas4D))); catch, end
            end
            G2.pscAtlas4D = [];
        end
        if ~isfield(G2,'saveInfo') || ~isstruct(G2.saveInfo), G2.saveInfo = struct(); end
        G2.saveInfo.warning = 'Emergency slim bundle: full 4D PSC was removed because MATLAB could not write the complete bundle.';
    catch
    end
end

%% END_PATCH_SCM_ATLAS_UNDERLAY_LIBRARY_V1

function openGroupBundleCB(~,~)
    startPath = getGroupBundleOpenStartPathLocal();

    [f,p] = uigetfileStartIn( ...
        {'SCM_GroupExport*.mat;*.mat', 'SCM Group bundle (*.mat)'; ...
         '*.mat', 'MAT files (*.mat)'; ...
         '*.*', 'All files (*.*)'}, ...
        'Open SCM GroupAnalysis bundle', startPath);

    if isequal(f,0)
        return;
    end

    fullf = fullfile(p,f);

    try
        G = loadScmGroupBundleLocal(fullf);
        applyScmGroupBundleLocal(G, fullf);
    catch ME
        errordlg(ME.message, 'Open SCM group bundle failed');
    end
end


function tf = isScmGroupBundleFileLocal(fullf)
    tf = false;

    try
        if isempty(fullf) || exist(fullf,'file') ~= 2
            return;
        end

        W = whos('-file', fullf);
        names = {W.name};

        if any(strcmp(names, 'G'))
            tf = true;
            return;
        end

        % Fallback: detect by filename.
        [~,nm,~] = fileparts(fullf);
        nm = lower(nm);

        if ~isempty(strfind(nm, 'scm_groupexport')) || ...
                ~isempty(strfind(nm, 'group_export')) || ...
                ~isempty(strfind(nm, 'scm_group'))
            tf = true;
        end

    catch
        tf = false;
    end
end


function G = loadScmGroupBundleLocal(fullf)
    if isempty(fullf) || exist(fullf,'file') ~= 2
        error('Group bundle file not found: %s', fullf);
    end

    S = load(fullf);

    if isfield(S,'G') && isstruct(S.G)
        G = S.G;
    else
        % Fallback: search for a struct that looks like an SCM group export.
        G = [];
        fn = fieldnames(S);

        for ii = 1:numel(fn)
            v = S.(fn{ii});

            if isstruct(v)
                if isfield(v,'kind') && strcmpi(char(v.kind), 'SCM_GROUP_EXPORT')
                    G = v;
                    break;
                end

                if isfield(v,'pscAtlas4D') || isfield(v,'underlayAtlas') || isfield(v,'scmMapSignedAtlas')
                    G = v;
                    break;
                end
            end
        end

        if isempty(G)
            error(['This MAT file does not look like an SCM GroupAnalysis bundle.' newline ...
                   'Expected variable G with fields like G.pscAtlas4D and G.underlayAtlas.']);
        end
    end

    G = SCM_normalizeGroupBundlePSC_PATCH_V4(G, fullf);
end


function applyScmGroupBundleLocal(G, fullf)

    % ---------------------------------------------------------
    % 1) Load PSC data from bundle
    % ---------------------------------------------------------
    spatial=scmSpatialCalibration(struct()); rulerStep=0; % Never reuse another dataset's physical scale.
    setappdata(fig,'SCMRulerVisible',false);
    set(findall(fig,'Tag','SCM_RulerToggle'),'Value',0);
    state.atlasInPlaneSpacingUm=[NaN NaN NaN];
    PSC = G.pscAtlas4D;

    if ~(isnumeric(PSC) || islogical(PSC))
        error('G.pscAtlas4D is not numeric.');
    end

    if ~(ndims(PSC) == 3 || ndims(PSC) == 4)
        error('G.pscAtlas4D must be [Y X T] or [Y X Z T].');
    end

    % Treat loaded bundle as the new native/base state for this SCM session.
    baselineRaw=[];
    if isfield(G,'baseline'),baseline=G.baseline;
    elseif isfield(baseline,'reference'),baseline=rmfield(baseline,'reference');end
    set(ebBase,'Enable','on');set(lblBase,'String','Baseline window (s)');
    if fusiBaselineReference('isExternal',baseline),set(ebBase,'Enable','off');set(lblBase,'String','Source baseline (s)');end
    set(btnBaselineSource,'TooltipString',fusiBaselineReference('label',baseline));
    origPSC = PSC;
    state.lastUnderlayFile = '';
    state.pendingAtlasUnderlay3D = [];

    % ---------------------------------------------------------
    % 2) Load TR if present
    % ---------------------------------------------------------
    if isfield(G,'TR') && ~isempty(G.TR) && isnumeric(G.TR) && isscalar(G.TR) && isfinite(G.TR) && G.TR > 0
        TR = double(G.TR);
    end

    % Refresh nY/nX/nZ/nT/tsec/tmin after replacing PSC.
    refreshDimsAfterPSCChange();

    % ---------------------------------------------------------
    % 3) Load underlay
    % ---------------------------------------------------------
    if isfield(G,'underlayAtlas') && ~isempty(G.underlayAtlas)
        bg = G.underlayAtlas;
    else
        bg = makeNativeFallbackUnderlayFromPSC(PSC);
    end

    origBG = bg;

    % ---------------------------------------------------------
    % 4) Restore underlay metadata if present
    % ---------------------------------------------------------
    ensureUnderlayStateFields();

    state.isColorUnderlay = false;
    state.regionLabelUnderlay = [];
    state.regionColorLUT = [];
    state.regionInfo = struct();

    if isfield(G,'underlayInfo') && isstruct(G.underlayInfo)
        UI = G.underlayInfo;

        if isfield(UI,'isColorUnderlay') && ~isempty(UI.isColorUnderlay)
            state.isColorUnderlay = logical(UI.isColorUnderlay);
        end

        if isfield(UI,'regionLabelUnderlay') && ~isempty(UI.regionLabelUnderlay)
            state.regionLabelUnderlay = UI.regionLabelUnderlay;
        end

        if isfield(UI,'regionInfo') && ~isempty(UI.regionInfo)
            state.regionInfo = UI.regionInfo;
        end
    else
        applyUnderlayMeta(defaultUnderlayMeta(), bg);
    end

    % Important for Step Motor nZ == 3:
    % avoid interpreting Y X 3 grayscale slices as one RGB image.
    try
        if nZ > 1 && ndims(bg) == 3 && size(bg,3) == nZ
            state.isColorUnderlay = false;
        end
    catch
    end

    % ---------------------------------------------------------
    % 5) Load mask if present
    % ---------------------------------------------------------
    passedMask = [];
    passedMaskIsInclude = true;

    if isfield(G,'maskAtlas') && ~isempty(G.maskAtlas)
        passedMask = fitBundleMaskToCurrentScm(G.maskAtlas);
    elseif isfield(G,'mask2DCurrentSlice') && ~isempty(G.mask2DCurrentSlice)
        passedMask = fitBundleMaskToCurrentScm(G.mask2DCurrentSlice);
    end

    if isfield(G,'maskIsInclude') && ~isempty(G.maskIsInclude)
        passedMaskIsInclude = logical(G.maskIsInclude);
    end

    origPassedMask = passedMask;

    % ---------------------------------------------------------
    % 6) Restore label/title/meta
    % ---------------------------------------------------------
    if isfield(G,'fileLabel') && ~isempty(G.fileLabel)
        try
            fileLabel = char(G.fileLabel);
        catch
        end
    else
        [~,nm,~] = fileparts(fullf);
        fileLabel = nm;
    end

    state.isAtlasWarped = true;
    state.isStepMotorAtlasWarped = false;

    if isfield(G,'atlasTransformFile') && ~isempty(G.atlasTransformFile)
        try
            state.atlasTransformFile = char(G.atlasTransformFile);
            state.lastAtlasTransformFile = char(G.atlasTransformFile);
        catch
            state.atlasTransformFile = '';
            state.lastAtlasTransformFile = '';
        end
    else
        state.atlasTransformFile = fullf;
        state.lastAtlasTransformFile = fullf;
    end

    try
        if isfield(G,'atlasSliceIndex') && ~isempty(G.atlasSliceIndex) && isfinite(G.atlasSliceIndex)
            state.z = clamp(round(G.atlasSliceIndex), 1, nZ);
        else
            state.z = clamp(state.z, 1, nZ);
        end
    catch
        state.z = clamp(state.z, 1, nZ);
    end

    % ---------------------------------------------------------
    % 7) Restore GUI windows/settings
    % ---------------------------------------------------------
    if isfield(G,'baseWindowStr') && ~isempty(G.baseWindowStr)
        set(ebBase, 'String', char(G.baseWindowStr));
    elseif isfield(G,'baseWindowSec') && numel(G.baseWindowSec) >= 2
        set(ebBase, 'String', sprintf('%g-%g', G.baseWindowSec(1), G.baseWindowSec(2)));
    end

    if isfield(G,'sigWindowStr') && ~isempty(G.sigWindowStr)
        set(ebSig, 'String', char(G.sigWindowStr));
    elseif isfield(G,'sigWindowSec') && numel(G.sigWindowSec) >= 2
        set(ebSig, 'String', sprintf('%g-%g', G.sigWindowSec(1), G.sigWindowSec(2)));
    end

    if isfield(G,'sigma') && ~isempty(G.sigma) && isnumeric(G.sigma) && isscalar(G.sigma) && isfinite(G.sigma)
        set(ebSigma, 'String', sprintf('%g', G.sigma));
    end

    if isfield(G,'display') && isstruct(G.display)
        applyDisplaySettingsFromGroupBundleLocal(G.display);
    end

    % ---------------------------------------------------------
    % 8) Reset ROIs and redraw
    % ---------------------------------------------------------
    try
        set(btnWarpAtlas, 'String', 'GROUP BUNDLE LOADED');
    catch
    end

    try
        set(txtTitle, 'String', sprintf('%s | loaded SCM group bundle', makeFullTitle(fileLabel)));
    catch
        set(txtTitle, 'String', 'Loaded SCM group bundle');
    end

    resetRoisAndRefreshAfterDataChange();

    if isfield(G,'display') && isstruct(G.display)
        applyDisplaySettingsFromGroupBundleLocal(G.display);
        updateView();
    end

    mask2D = getMaskForCurrentSlice();

    try
        updateSCMUnderlayDisplay(state.z);
    catch
    end

    updateSliceIndicators();
    updateInfoLines();
    computeSCM();

    set(info1, 'String', ['Loaded SCM group bundle: ' shortenPath(fullf,85)], ...
        'TooltipString', fullf);

    fprintf('[SCM] Loaded GroupAnalysis SCM bundle:\n%s\n', fullf);
end


function applyDisplaySettingsFromGroupBundleLocal(D)

    if isempty(D) || ~isstruct(D)
        return;
    end

    try
        if isfield(D,'threshold') && ~isempty(D.threshold) && isfinite(D.threshold)
            set(ebThr, 'String', sprintf('%g', D.threshold));
        end
    catch
    end

    try
        if isfield(D,'caxis') && numel(D.caxis) >= 2 && all(isfinite(D.caxis(1:2)))
            state.cax = double(D.caxis(1:2));
            if state.cax(2) < state.cax(1)
                state.cax = fliplr(state.cax);
            end
            set(ebCax, 'String', sprintf('%g %g', state.cax(1), state.cax(2)));
        end
    catch
    end

    try
        if isfield(D,'alphaPercent') && ~isempty(D.alphaPercent) && isfinite(D.alphaPercent)
            set(slAlpha, 'Value', clamp(double(D.alphaPercent), 0, 100));
        end
    catch
    end

    try
        if isfield(D,'alphaModOn') && ~isempty(D.alphaModOn)
            state.alphaModOn = logical(D.alphaModOn);
            set(cbAlphaMod, 'Value', double(state.alphaModOn));
        end
    catch
    end

    try
        if isfield(D,'modMin') && ~isempty(D.modMin) && isfinite(D.modMin)
            state.modMin = double(D.modMin);
            set(ebModMin, 'String', sprintf('%g', state.modMin));
        end
    catch
    end

    try
        if isfield(D,'modMax') && ~isempty(D.modMax) && isfinite(D.modMax)
            state.modMax = double(D.modMax);
            set(ebModMax, 'String', sprintf('%g', state.modMax));
        end
    catch
    end

    try
        if isfield(D,'signMode') && ~isempty(D.signMode) && isfinite(D.signMode)
            state.signMode = clamp(round(double(D.signMode)), 1, 3);
            state.prevSignMode = state.signMode;
            set(popSignMode, 'Value', state.signMode);
        end
    catch
    end

    try
        if isfield(D,'colormapName') && ~isempty(D.colormapName)
            cmName = char(D.colormapName);
            set(popMap, 'Value', findPopupIndexByName(popMap, cmName));
        end
    catch
    end

    % DECONF_STD_SCM_CONTROL_SYNC_V10
try
    set(ebCax,'String',sprintf('%g %g',state.cax(1),state.cax(2)));
    set(cbAlphaMod,'Value',double(state.alphaModOn));
    set(ebModMin,'String',sprintf('%g',state.modMin));
    set(ebModMax,'String',sprintf('%g',state.modMax));
    set(popSignMode,'Value',state.signMode);
    set(slAlpha,'Value',100);
    set(txtAlpha,'String','100');
catch
end
% DECONF_STD_SCM_CONTROL_SYNC_V11
try
    if exist('par','var') && isstruct(par) && isfield(par,'standardizedWorkflow') && par.standardizedWorkflow
        set(ebCax,'String',sprintf('%g %g',state.cax(1),state.cax(2)));
        set(cbAlphaMod,'Value',double(state.alphaModOn));
        set(ebModMin,'String',sprintf('%g',state.modMin));
        set(ebModMax,'String',sprintf('%g',state.modMax));
        set(popSignMode,'Value',state.signMode);
        set(slAlpha,'Value',100);
        set(txtAlpha,'String','100');
    end
catch
end
alphaModToggled();

    try
        if isfield(D,'cmapMatrix') && ~isempty(D.cmapMatrix) && size(D.cmapMatrix,2) == 3
            colormap(ax, D.cmapMatrix);
        end
    catch
    end
end


function startPath = getGroupBundleOpenStartPathLocal()
    try
        root = getCentralAnalysedRootForGroupBundlesLocal(getDatasetRootForSelectors());

        cand = { ...
            fullfile(root,'GroupAnalysis','Bundles','SCM'), ...
            fullfile(root,'GroupAnalysis','Bundles'), ...
            fullfile(root,'SCM'), ...
            root, ...
            getStartPath(), ...
            pwd};

        startPath = firstExistingDir(cand);
    catch
        startPath = pwd;
    end
end

function applyExportWindowPatches(ax2, yl)
    [b0,b1] = parseRangeSafe(getStr(ebBase),30,240);
    [s0,s1] = parseRangeSafe(getStr(ebSig),840,900);
    if isVolMode
        b0s = (clamp(round(b0),1,nT)-1)*TR; b1s = (clamp(round(b1),1,nT)-1)*TR;
        s0s = (clamp(round(s0),1,nT)-1)*TR; s1s = (clamp(round(s1),1,nT)-1)*TR;
    else
        b0s = b0; b1s = b1; s0s = s0; s1s = s1;
    end
    if b1s < b0s, tmp=b0s; b0s=b1s; b1s=tmp; end
    if s1s < s0s, tmp=s0s; s0s=s1s; s1s=tmp; end
    yr = yl(2)-yl(1); if ~isfinite(yr) || yr <= 0, yr = 1; end
    yTxt = yl(2) - 0.06*yr;
    if referenceTraceShown()
        w=fusiReferenceTraceWindow(baseline.reference,state.referenceMode==2);b0s=w.baselinePlotSec(1);b1s=w.baselinePlotSec(2);
    end
    if ~fusiBaselineReference('isExternal',baseline)||referenceTraceShown()
    patch(ax2,[b0s b1s b1s b0s]/60,[yl(1) yl(1) yl(2) yl(2)],[1.0 0.2 0.2],'FaceAlpha',0.16,'EdgeColor','none');
    text(ax2,mean([b0s b1s])/60,yTxt,'Bas.','Color',[1.00 0.35 0.35],'FontSize',11,'FontWeight','bold','HorizontalAlignment','center','BackgroundColor',[0 0 0],'Margin',1,'Clipping','on');
    end
    patch(ax2,[s0s s1s s1s s0s]/60,[yl(1) yl(1) yl(2) yl(2)],[1.0 0.6 0.15],'FaceAlpha',0.16,'EdgeColor','none');
    text(ax2,mean([s0s s1s])/60,yTxt,'Sig.','Color',[1.00 0.80 0.35],'FontSize',11,'FontWeight','bold','HorizontalAlignment','center','BackgroundColor',[0 0 0],'Margin',1,'Clipping','on');
    try, uistack(findobj(ax2,'Type','line'),'top'); catch, end
end

%% ==========================================================
% VIDEO GUI
%% ==========================================================
function openVideo(~,~,launchCfg)
    try
        bStart = baseStart0; bEnd = baseEnd0;
        if fusiBaselineReference('isExternal',baseline),bStart=0;bEnd=min(TR,tsec(end));end
        if nargin<3,launchCfg=showScmVideoSetupDialogLocal('Video GUI',bStart,bEnd,1);end
        if isempty(launchCfg) || ~isstruct(launchCfg) || ~isfield(launchCfg,'cancelled') || launchCfg.cancelled, return; end
        baselineLocal = baseline;
        if ~isstruct(baselineLocal), baselineLocal = struct(); end
        if ~fusiBaselineReference('isExternal',baselineLocal)
            baselineLocal.start = launchCfg.baselineStart;
            baselineLocal.end = launchCfg.baselineEnd;
        end
        baselineLocal.mode = 'sec';
        parVideo = par;parVideo.fusiOriginalScanKey=state.originalScanKey;parVideo.scanSequence=state.scanSequence;
        parVideo.videoInputIsPSC = true;
        parVideo.selectorRoot = getDatasetRootForSelectors();
        parVideo.maskStartPath = getMaskStartPath();
        parVideo.underlayStartPath = getUnderlayStartPathFast();
        parVideo.transformStartPath = getTransformStartPath();
        if state.isAtlasWarped&&isfield(state,'atlasUnderlayKey')&&~isempty(state.atlasUnderlayKey)
            parVideo.fusiAtlasDisplayContext=atlasDisplayContext();
        elseif isfield(parVideo,'fusiAtlasDisplayContext'),parVideo=rmfield(parVideo,'fusiAtlasDisplayContext');end
        videoRaw=PSC;
        if ~isempty(baselineRaw)&&~state.isAtlasWarped,videoRaw=baselineRaw;parVideo.videoInputIsPSC=false;end
        child=play_fusi_video_final(videoRaw, videoRaw, PSC, bg, parVideo, 10, 240, TR, (nT-1)*TR, baselineLocal, ...
            passedMask, passedMaskIsInclude, nT, false, struct(), fileLabel, state.z);
        setappdata(fig,'FUSILastOpenedVideo',child);
    catch ME
        errordlg(ME.message, 'Open Video GUI failed');
    end
end

function ctx=atlasDisplayContext()
    ctx=struct('bundle',state.pendingAtlasUnderlay3D,'nativePSC',origPSC,'nativePower',baselineRaw,'nativeBG',origBG, ...
        'nativeMask',origPassedMask,'nativeMaskIsInclude',origPassedMaskIsInclude, ...
        'slice',state.z,'regionScheme',state.regionScheme,'appearance',uState,'mapping',state.currentROIMapping);
end
function restoreAtlasDisplayContext()
    if ~isfield(par,'fusiAtlasDisplayContext'),return;end
    ctx=par.fusiAtlasDisplayContext;bundle=ctx.bundle;
    [bg,meta,Tgrid,grid]=fusiCachedAtlasUnderlayView3D(bundle.underlay,bundle.meta,'atlas');
    assert(isequal(size(PSC,[1 2 3]),grid.outputSizeYXZ),'deConfUSIon:AtlasGeometryMismatch','Transferred atlas display and PSC grids differ.');
    origPSC=ctx.nativePSC;origBG=ctx.nativeBG;origPassedMask=ctx.nativeMask;origPassedMaskIsInclude=ctx.nativeMaskIsInclude;
    if isfield(ctx,'nativePower')&&~isempty(ctx.nativePower),baselineRaw=ctx.nativePower;par.baselineRawIsPSC=false;end
    state.isAtlasWarped=true;state.atlasUnderlayKey=bundle.meta.registrationKey;
    state.pendingAtlasUnderlay3D=bundle;state.atlasSliceSampling=grid;
    transformFile=fusiAtlasPairedTransformFile(meta,bundle.file);
    state.atlasTransformFile=transformFile;state.lastAtlasTransformFile=transformFile;
    state.currentROIMapping=struct('kind','3D','transform',Tgrid);
    if isfield(ctx,'mapping')&&~isempty(ctx.mapping),state.currentROIMapping=ctx.mapping;end
    roi.viewKey=['atlas|' transformFile];roi.viewShape=[nY nX nZ];roi.viewMapping=state.currentROIMapping;
    state.z=clamp(ctx.slice,1,nZ);par.atlasVoxelSizeYXZUm=meta.voxelSizeUm;
    applyUnderlayMeta(meta,bg);refreshAtlasUnderlayChoices('atlas');
    state.regionScheme=ctx.regionScheme;uState=ctx.appearance;
    options=get(popRegionScheme,'String');set(popRegionScheme,'Value',find(strcmp(options,state.regionScheme),1));
    set(slBri,'Value',uState.brightness);set(slCon,'Value',uState.contrast);set(slGam,'Value',uState.gamma);
    set(txtBri,'String',sprintf('%.2f',uState.brightness));set(txtCon,'String',sprintf('%.2f',uState.contrast));set(txtGam,'String',sprintf('%.2f',uState.gamma));
    set(btnWarpAtlas,'String','WARP TO ATLAS: CHOOSE TRANSFORM','TooltipString',transformFile);
    setappdata(fig,'FUSIAtlasAppliedTransformFile',transformFile);
    updateSCMUnderlayDisplay(state.z);
end

function cfg = showScmVideoSetupDialogLocal(titleStr, bStart, bEnd, interpDefault)
    cfg = [];
    try
        if exist('showScmVideoSetupDialog','file') == 2
            cfg = showScmVideoSetupDialog(titleStr, bStart, bEnd, interpDefault);
            return;
        end
    catch
    end
    a = inputdlg({'Baseline start (s):','Baseline end (s):','Interpolation factor:'}, titleStr, 1, ...
        {num2str(bStart), num2str(bEnd), num2str(interpDefault)});
    if isempty(a)
        cfg = struct('cancelled', true);
        return;
    end
    cfg = struct();
    cfg.cancelled = false;
    cfg.baselineStart = str2double(a{1}); if ~isfinite(cfg.baselineStart), cfg.baselineStart = bStart; end
    cfg.baselineEnd = str2double(a{2}); if ~isfinite(cfg.baselineEnd), cfg.baselineEnd = bEnd; end
    cfg.interp = str2double(a{3}); if ~isfinite(cfg.interp), cfg.interp = interpDefault; end
end

function showHelp(~,~)
    deConfUSIon_ui('help','SCM_gui'); return;
    bgFig = [0.06 0.06 0.07]; bgText = [0.12 0.12 0.14]; colTxt = [0.94 0.94 0.96];
    hf = figure('Name','SCM Help','Color',bgFig,'MenuBar','none','ToolBar','none','NumberTitle','off', ...
        'Resize','on','Position',[200 100 980 780],'WindowStyle','modal');
    guide = { ...
        'SCM Viewer - Guide'; ''; ...
        'OVERLAY'; ...
        '  - Threshold hides low |SCM|.'; ...
        '  - Display range sets overlay caxis.'; ...
        '  - Alpha modulation ON ramps alpha between Mod Min and Mod Max.'; ''; ...
        'UNDERLAY / FOLDERS'; ...
        '  - LOAD MASK starts in Masks/Mask/ROI/Registration first.'; ...
        '  - LOAD NEW UNDERLAY starts in Visualization first.'; ...
        '  - WARP FUNCTIONAL TO ATLAS starts in Registration2D/Registration first.'; ''; ...
        'ROI'; ...
        '  - Hover shows live ROI PSC.'; ...
        '  - Left click adds ROI.'; ...
        '  - Right click removes nearest ROI.'; ''; ...
        'EXPORT'; ...
        '  - Export ROI TXT, SCM image, time-course PNG, SCM series, and GroupAnalysis bundle.'};
    uicontrol(hf,'Style','edit','Units','normalized','Position',[0.03 0.03 0.94 0.94], ...
        'String',strjoin(guide,newline),'Max',2,'Min',0,'BackgroundColor',bgText,'ForegroundColor',colTxt, ...
        'FontName','Arial','FontSize',13,'HorizontalAlignment','left');
end

%% ==========================================================
% ROI / TIME COURSE HELPERS
%% ==========================================================
function tc = computeRoiPSC_atSlice(zSel, x1, x2, y1, y2,roiId)
    if nargin>=6
        audit=scmAutomaticROISelections(fig);
        for ai=1:numel(audit)
            if audit{ai}.roiId==roiId&&(audit{ai}.slice==zSel||isfield(audit{ai},'roiMaskVolumeIndices')),tc=scmROI('trace',PSC,candidateForBaseline(audit{ai}));return;end
        end
        if numel(roi.sizingById)>=roiId&&~isempty(roi.sizingById{roiId})&&isfield(roi.sizingById{roiId},'roiMaskVolumeIndices')
            c=candidateForBaseline(roi.sizingById{roiId});tc=scmROI('trace',PSC,c);return;
        end
    end
    tc=computeRoiPSC_idx(zSel,x1,x2,y1,y2,1:nT);
end

function tc=computeHoverPSC(x1,x2,y1,y2)
    bounds=[x1 x2 y1 y2]; idx=state.hoverIdx;
    area=(x2-x1+1)*(y2-y1+1);
    if area<=1024
        roi.hoverStats=[];
        tc=computeRoiPSC_idx(state.z,x1,x2,y1,y2,idx); return;
    end
    [b0,b1]=selectedBaselineFrames(); key=[state.z b0 b1];
    B=cachedBaseline(state.z,b0,b1); previous=roi.hoverStats;
    reuse=~isempty(previous) && isequal(previous.key,key) && ...
        isequal(previous.idx,idx) && previous.updates<100;
    if reuse
        old=previous.bounds;
        overlap=[max(x1,old(1)) min(x2,old(2)) max(y1,old(3)) min(y2,old(4))];
        overlapArea=max(0,overlap(2)-overlap(1)+1)*max(0,overlap(4)-overlap(3)+1);
        reuse=overlapArea>.5*max(area,(old(2)-old(1)+1)*(old(4)-old(3)+1));
    end
    if reuse
        sums=previous.sums; counts=previous.counts;
        removed=rectangleDifference(old,overlap); added=rectangleDifference(bounds,overlap);
        for k=1:size(removed,1)
            [s,c]=hoverWindowSums(removed(k,:),idx,B); sums=sums-s; counts=counts-c;
        end
        for k=1:size(added,1)
            [s,c]=hoverWindowSums(added(k,:),idx,B); sums=sums+s; counts=counts+c;
        end
        updates=previous.updates+1;
    else
        [sums,counts]=hoverWindowSums(bounds,idx,B); updates=0;
    end
    roi.hoverStats=struct('key',key,'idx',idx,'bounds',bounds,'sums',sums,'counts',counts,'updates',updates);
    tc=sums./max(1,counts); tc(counts==0)=NaN;
end

function parts=rectangleDifference(box,overlap)
    % Four non-overlapping strips; the shared interior needs no data read.
    parts=[box(1) overlap(1)-1 box(3) box(4); overlap(2)+1 box(2) box(3) box(4); ...
        overlap(1) overlap(2) box(3) overlap(3)-1; overlap(1) overlap(2) overlap(4)+1 box(4)];
    parts=parts(parts(:,1)<=parts(:,2) & parts(:,3)<=parts(:,4),:);
end

function [sums,counts]=hoverWindowSums(box,idx,B)
    sums=zeros(1,numel(idx)); counts=sums;
    yy=box(3):box(4);
    chunk=max(1,floor(8*1024^2/(16*numel(yy)*numel(idx))));
    for x=box(1):chunk:box(2)
        xx=x:min(box(2),x+chunk-1);
        if ndims(PSC)==3, X=PSC(yy,xx,idx); else, X=PSC(yy,xx,state.z,idx); end
        base=reshape(B(yy,xx),[],1); denominator=100+base;
        denominator(~isfinite(denominator) | denominator<=sqrt(eps('single')))=NaN;
        X=100*bsxfun(@rdivide,bsxfun(@minus,reshape(X,[],numel(idx)),base),denominator);
        valid=isfinite(X); X(~valid)=0;
        sums=sums+sum(double(X),1); counts=counts+sum(valid,1);
    end
end

function tc = computeRoiPSC_idx(zSel, x1, x2, y1, y2, idx)
    try
        idx=round(double(idx(:).')); idx=idx(isfinite(idx) & idx>=1 & idx<=nT);
        if ndims(PSC) == 3
            blk = PSC(y1:y2, x1:x2, idx);
        else
            zSel = clamp(round(zSel),1,nZ);
            blk = PSC(y1:y2, x1:x2, zSel, idx);
        end

        [b0,b1]=selectedBaselineFrames();
        B=cachedBaseline(zSel,b0,b1); B=reshape(B(y1:y2,x1:x2),[],1);
        denominator=100+B; denominator(~isfinite(denominator) | denominator<=sqrt(eps('single')))=NaN;
        blk=100*bsxfun(@rdivide,bsxfun(@minus,reshape(blk,[],numel(idx)),B),denominator);
        % Average all finite voxels with equal weight. Successive axis means
        % give columns with fewer valid voxels disproportionate weight.
        tc=deConfUSIon_signal('mean',blk,1);
        tc=double(tc(:).');

    catch
        tc = [];
    end
end

function B=cachedBaseline(z,b0,b1)
    if fusiBaselineReference('isExternal',baseline),B=zeros(nY,nX,'single');return;end
    key=[z b0 b1];
    if ~isequal(state.baseKey,key)
        state.baseMean=windowMean(z,b0:b1); state.baseKey=key;
    end
    B=state.baseMean;
end

function M=windowMean(z,idx)
    % Read only the selected slice/window, in bounded time chunks.
    total=zeros(nY,nX,'double'); count=zeros(nY,nX,'double');
    chunk=max(1,floor(16*1024^2/(12*nY*nX)));
    for a=1:chunk:numel(idx)
        q=idx(a:min(numel(idx),a+chunk-1));
        if ndims(PSC)==3, X=PSC(:,:,q); else, X=reshape(PSC(:,:,z,q),nY,nX,[]); end
        valid=isfinite(X); X(~valid)=0;
        total=total+sum(double(X),3); count=count+sum(valid,3);
    end
    M=single(total./count); M(count==0)=NaN;
end

function [b0i,b1i]=selectedBaselineFrames()
    if fusiBaselineReference('isExternal',baseline),b0i=1;b1i=1;return;end
    [b0,b1]=parseRangeSafe(getStr(ebBase),baseStart0,baseEnd0);
    if isVolMode, b0i=round(b0); b1i=round(b1);
    else, b0i=round(b0/TR)+1; b1i=round(b1/TR)+1; end
    if b0i<1 || b1i>nT || b1i<b0i
        error('deConfUSIon:SCMBaseline','Baseline must lie inside the acquisition and start before it ends.');
    end
end

function redrawROIsForCurrentSlice()
    traceGuard=onCleanup(@closeCurveReadProgress); %#ok<NASGU>
    deleteIfValid(roiHandles); roiHandles = gobjects(0);
    deleteIfValid(roiPlotPSC); roiPlotPSC = gobjects(0);
    deleteIfValid(roiTextHandles); roiTextHandles = gobjects(0);
    roi.savedTcBounds=zeros(0,6);
    ROI = ROI_byZ{state.z};
    audit=scmAutomaticROISelections(fig);
    for k = 1:numel(ROI)
        setappdata(fig,'FUSICurveReadBatch',[k numel(ROI)]);
        drawRoiForCurrentSlice(ROI(k),audit);
    end
    applyTimecourseAxisMode();
end

function drawRoiForCurrentSlice(r,audit,tc)
    markerLabel=sprintf('%d',r.id);
    for ai=1:numel(audit)
        if audit{ai}.roiId==r.id && (audit{ai}.slice==state.z||isfield(audit{ai},'roiMaskVolumeIndices')) && isfield(audit{ai},'role')
            markerLabel=sprintf('%d %s',r.id,audit{ai}.role); break;
        end
    end
    selection=[];for ai=1:numel(audit),if audit{ai}.roiId==r.id&&(audit{ai}.slice==state.z||isfield(audit{ai},'roiMaskVolumeIndices')),selection=audit{ai};break;end,end
    if isempty(selection)&&numel(roi.sizingById)>=r.id&&~isempty(roi.sizingById{r.id})&&isfield(roi.sizingById{r.id},'roiMaskVolumeIndices'),selection=roi.sizingById{r.id};end
    if ~isempty(selection)&&(isfield(selection,'roiMaskIndices')||isfield(selection,'roiMaskVolumeIndices'))
        m=scmROI('mask',selection,state.z,[nY nX nZ]);padded=zeros(nY+2,nX+2);padded(2:end-1,2:end-1)=double(m);
        previousPlot=ax.NextPlot;ax.NextPlot='add';restorePlot=onCleanup(@()set(ax,'NextPlot',previousPlot));
        [~,outline]=contour(ax,0:nX+1,0:nY+1,padded,[.5 .5],'LineColor',r.color,'LineWidth',2);roiHandles(end+1)=outline;
        clear restorePlot;
    else
        roiHandles(end+1) = rectangle(ax,'Position',[r.x1 r.y1 r.x2-r.x1+1 r.y2-r.y1+1], ...
            'EdgeColor',r.color,'LineWidth',2);
    end
    roiTextHandles(end+1) = text(ax,r.x1,max(1,r.y1-2),markerLabel, ...
        'Color',r.color,'FontWeight','bold','FontSize',12,'Interpreter','none', ...
        'VerticalAlignment','bottom','BackgroundColor',[0 0 0],'Margin',1); %#ok<AGROW>
    setappdata(roiHandles(end),'SCMROIId',r.id);setappdata(roiTextHandles(end),'SCMROIId',r.id);
    if nargin<3,tc=computeRoiPSC_atSlice(state.z,r.x1,r.x2,r.y1,r.y2,r.id);end
    if numel(tc) == nT
        c=referenceCandidate(state.z,r.x1,r.x2,r.y1,r.y2,r.id);
        [xPlot,yPlot]=stitchRoiTrace(tc,tmin,c);
        roi.savedTcBounds(end+1,:)=traceBounds(xPlot,yPlot);
        roiPlotPSC(end+1) = plot(axTC,xPlot,yPlot,':','Color',r.color,'LineWidth',2.4,'Tag','SCM_SavedROI'); %#ok<AGROW>
        setappdata(roiPlotPSC(end),'SCMROIId',r.id);
    end
end

function deleteIfValid(h)
    if isempty(h), return; end
    for i = 1:numel(h)
        if isgraphics(h(i)), delete(h(i)); end
    end
end

function c=referenceCandidate(z,x1,x2,y1,y2,roiId)
    c=struct('boundsXY',[x1 x2 y1 y2],'slice',z);
    if nargin<6,return;end
    audit=scmAutomaticROISelections(fig);
    for ai=1:numel(audit)
        if audit{ai}.roiId==roiId,c=audit{ai};return;end
    end
    if numel(roi.sizingById)>=roiId&&~isempty(roi.sizingById{roiId})
        mask=roi.sizingById{roiId};
        if isfield(mask,'roiMaskVolumeIndices'),c=mask;end
    end
end

function yes=hasReferenceSamples(whole)
    yes=false;if ~fusiBaselineReference('isExternal',baseline),return;end
    r=baseline.reference;frames=r.frames(1):r.frames(2);if whole,frames=1:r.nFrames;end
    if isfield(r,'tracePower')&&isfield(r,'traceFrames')&&all(ismember(frames,r.traceFrames)),yes=true;return;end
    if isfield(r,'sourceFile')&&~isempty(r.sourceFile),yes=isfile(fusiFindMovedDataPath(r.sourceFile));end
end

function yes=referenceTraceShown()
    yes=state.referenceMode<3&&hasReferenceSamples(state.referenceMode==2);
end

function yes=sequenceTraceShown()
    yes=state.referenceMode==4&&~isempty(state.scanSequence)&&numel(state.scanSequence.scans)>1&& ...
        any(fusiScanSequence('included',state.scanSequence))&& ...
        (fusiBaselineReference('isExternal',baseline)||strcmp(state.scanSequence.normMode,'local'));
end

function [start,finish,owner]=sequenceWindows()
    L=fusiScanSequence('layout',state.scanSequence);start=L(state.scanSequence.active).startSec;finish=max([L.endSec],[],'omitnan');owner=[];
    if strcmp(state.scanSequence.normMode,'local'),owner=state.scanSequence.active;return;end
    r=baseline.reference;
    for si=1:numel(L)
        d=state.scanSequence.scans{si};
        if (~isempty(r.sourceFile)&&strcmpi(fusiFindMovedDataPath(r.sourceFile),d.file))|| ...
                (~isempty(r.rawFile)&&strcmpi(fusiFindMovedDataPath(r.rawFile),d.rawFile)),owner=si;break;end
    end
end

function referenceTraceModeChanged(~,~)
    state.referenceMode=get(popReferenceTrace,'Value');state.referenceTraceError='';state.timeWindowKey=[];
    if state.referenceMode==4&&(isempty(state.scanSequence)||numel(state.scanSequence.scans)<2)
        state.referenceMode=1;set(popReferenceTrace,'Value',1);set(info1,'String','Use Scans / order... to add scans first.');
    end
    if state.referenceMode==2&&~hasReferenceSamples(true)
        state.referenceMode=1;set(popReferenceTrace,'Value',1);
        set(info1,'String','The whole reference requires its source file. Showing available baseline samples.');
    end
    state.tcFixX=false;set(cbTcFixX,'Value',0);set(ebTcXLim,'Enable','off');
    set(hLivePSC,'Visible','off');roi.lastHoverXY=[-inf -inf];redrawROIsForCurrentSlice();
end

function setLiveCurve(tc,z,x1,x2,y1,y2)
    c=referenceCandidate(z,x1,x2,y1,y2);
    if ~state.tcLiveAllScans&&(sequenceTraceShown()||referenceTraceShown())
        xPlot=state.tminHover;if sequenceTraceShown(),[start,~]=sequenceWindows();xPlot=xPlot+start/60;end
        yPlot=smoothDisplayCurve(xPlot,tc);
    else,[xPlot,yPlot]=stitchRoiTrace(tc,state.tminHover,c);
    end
    set(hLivePSC,'XData',xPlot,'YData',yPlot,'Visible','on');
end
function liveAllScansChanged(~,~)
    state.tcLiveAllScans=logical(get(cbLiveAllScans,'Value'));
    roi.lastHoverXY=[-inf -inf];set(hLivePSC,'Visible','off');
end

function [xPlot,yPlot]=stitchRoiTrace(tc,currentTimeMin,c)
    xPlot=currentTimeMin;yPlot=tc;
    sequence=sequenceTraceShown();if ~referenceTraceShown()&&~sequence,yPlot=smoothDisplayCurve(xPlot,yPlot);return;end
    try
        key=struct('mode',state.referenceMode,'bounds',c.boundsXY,'slice',c.slice,'view',roi.viewKey,'revision',roi.revision);
        for field={'roiMaskIndices','roiMaskSizeYX','roiMaskVolumeIndices','roiMaskSizeYXZ'}
            if isfield(c,field{1}),key.(field{1})=c.(field{1});end
        end
        series=[];
        for ci=1:numel(state.referenceTraceCache)
            item=state.referenceTraceCache{ci};if isequal(item.key,key),series=item.series;break;end
        end
        if isempty(series)
            if state.isAtlasWarped
                nativeShape=[size(origPSC,1) size(origPSC,2) 1];if ndims(origPSC)==4,nativeShape(3)=size(origPSC,3);end
                mapped=scmROI('map',{c},[nY nX nZ],nativeShape,roi.viewMapping,true,[NaN NaN NaN]);c=mapped{1};
            end
            if sequence
                progress=getappdata(fig,'FUSICurveReadProgress');
                if isempty(progress)||~isgraphics(progress)
                    q=state.scanSequence;labels=fusiScanSequence('labels',q);labels=labels(fusiScanSequence('included',q));
                    progress=fusiBaselineProgress('open','Loading all-scan ROI time courses',labels);
                end
                batch=getappdata(fig,'FUSICurveReadBatch');
                if isempty(batch),pg=onCleanup(@()fusiBaselineProgress('close',progress)); %#ok<NASGU>
                else,setappdata(fig,'FUSICurveReadProgress',progress);fusiBaselineProgress('roi',progress,batch(1),batch(2));end
                [sx,sy,notes]=fusiScanSequence('trace',state.scanSequence,baseline,c, ...
                    @(fraction,message)fusiBaselineProgress('update',progress,fraction,message),baselineRaw);
                clear pg;series=struct('x',sx,'y',sy);
                if ~isempty(notes),set(info1,'String',strjoin(notes,' | '));end
            else,series=fusiBaselineRoiTrace(baseline.reference,c,state.referenceMode==2);end
            state.referenceTraceCache{end+1}=struct('key',key,'series',series);
            while numel(state.referenceTraceCache)>96||sum(cellfun(@referenceSeriesBytes,state.referenceTraceCache))>32*1024^2
                state.referenceTraceCache(1)=[];
            end
        end
        if sequence,xPlot=series.x;yPlot=series.y;
        else
            w=fusiReferenceTraceWindow(baseline.reference,state.referenceMode==2);
            xPlot=[(series.timeSec+w.shiftSec)/60 NaN currentTimeMin];yPlot=[series.PSC NaN tc];
        end
    catch ME
        if strcmp(ME.identifier,'deConfUSIon:ProcessingCancelled'),set(info1,'String','ROI curve read cancelled. Select the ROI again to retry.');
        elseif ~strcmp(state.referenceTraceError,ME.message)
            state.referenceTraceError=ME.message;set(info1,'String',['Reference curve: ' ME.message]);
        end
    end
    yPlot=smoothDisplayCurve(xPlot,yPlot);
end

function closeCurveReadProgress()
    if ~isgraphics(fig),return;end
    progress=getappdata(fig,'FUSICurveReadProgress');if ~isempty(progress),fusiBaselineProgress('close',progress);rmappdata(fig,'FUSICurveReadProgress');end
    if isappdata(fig,'FUSICurveReadBatch'),rmappdata(fig,'FUSICurveReadBatch');end
end

function bytes=referenceSeriesBytes(item)
    if isfield(item.series,'x'),bytes=16*numel(item.series.x);
    else,bytes=16*numel(item.series.PSC);end
end

function y=smoothDisplayCurve(x,y)
    if state.tcSmoothOn,y=fusiSmoothTimecourse(x,y,state.tcSmoothSeconds);end
end
function timecourseSmoothingChanged(~,~)
    seconds=str2double(getStr(ebTcSmooth));
    if ~isfinite(seconds)||seconds<=0,set(ebTcSmooth,'String',sprintf('%.9g',state.tcSmoothSeconds));return;end
    state.tcSmoothSeconds=seconds;state.tcSmoothOn=logical(get(cbTcSmooth,'Value'));
    enabled='off';if state.tcSmoothOn,enabled='on';end;set(ebTcSmooth,'Enable',enabled);
    set(hLivePSC,'Visible','off');roi.lastHoverXY=[-inf -inf];state.timeWindowKey=[];redrawROIsForCurrentSlice();
end

function label=shortScanLabel(context,fallback)
    label=fallback;
    for field={'rawFile','loadedFile','sourceFile'}
        if ~isfield(context,field{1})||isempty(context.(field{1})),continue;end
        [~,stem]=fileparts(context.(field{1}));
        token=regexp(stem,'(?:^|_)(scan\d+(?:_[^.]*)?)$','tokens','once','ignorecase');
        if ~isempty(token),label=token{1};return;end
    end
end

function tcAxisModeChanged(~,~)
    state.tcFixY = logical(get(cbTcFixY,'Value'));
    state.tcFixX = logical(get(cbTcFixX,'Value'));
    [y0,y1] = parseAxisPair(getStr(ebTcYLim), state.tcYLim(1), state.tcYLim(2));
    [x0,x1] = parseAxisPair(getStr(ebTcXLim), state.tcXLim(1), state.tcXLim(2));
    state.tcYLim = [y0 y1]; state.tcXLim = [x0 x1];
    if state.tcFixY, set(ebTcYLim,'Enable','on','BackgroundColor',bgEdit); else, set(ebTcYLim,'Enable','off','BackgroundColor',bgEditDis); end
    if state.tcFixX, set(ebTcXLim,'Enable','on','BackgroundColor',bgEdit); else, set(ebTcXLim,'Enable','off','BackgroundColor',bgEditDis); end
    applyTimecourseAxisMode();
end

function tcYFromCax(~,~)
    set(ebTcYLim, 'String', sprintf('%g %g', state.cax(1), state.cax(2)));
    set(cbTcFixY, 'Value', 1);
    tcAxisModeChanged();
end

function tcXAll(~,~)
    first=tmin(1);if referenceTraceShown(),w=fusiReferenceTraceWindow(baseline.reference,state.referenceMode==2);first=w.plotWindowSec(1)/60;end
    finish=displayEndMin;if sequenceTraceShown(),[~,finish]=sequenceWindows();first=0;finish=finish/60;end
    set(ebTcXLim, 'String', sprintf('%g %g', first, finish));
    set(cbTcFixX, 'Value', 1);
    tcAxisModeChanged();
end

function applyTimecourseAxisMode()
    if ~isgraphics(axTC), return; end
    enabled='off';if fusiBaselineReference('isExternal',baseline)||(~isempty(state.scanSequence)&&numel(state.scanSequence.scans)>1),enabled='on';end
    set(popReferenceTrace,'Enable',enabled);
    xAuto=state.tcXLim; yAuto=state.tcYLim;
    if ~state.tcFixX || ~state.tcFixY, [xAuto, yAuto] = getAutoTcLimits(); end
    if state.tcFixX, xUse = state.tcXLim; else, xUse = xAuto; end
    if state.tcFixY, yUse = state.tcYLim; else, yUse = yAuto; end
    if ~isequal(get(axTC,'XLim'),xUse)
        set(axTC,'XLim',xUse); applyTimecourseXTicks(xUse);
    end
    if ~isequal(get(axTC,'YLim'),yUse), set(axTC,'YLim',yUse); end
    drawTimeWindows();
end

function [xLimAuto, yLimAuto] = getAutoTcLimits()
    bounds=roi.savedTcBounds;
    if isgraphics(hLivePSC) && strcmp(get(hLivePSC,'Visible'),'on')
        bounds(end+1,:)=traceBounds(get(hLivePSC,'XData'),get(hLivePSC,'YData'));
    end
    if sum(bounds(:,3)) >= 2
        xLimAuto = [min(bounds(:,1)) max(bounds(:,2))]; if xLimAuto(2) <= xLimAuto(1), xLimAuto(2) = xLimAuto(1) + eps; end
    else
        xLimAuto = [tmin(1) tmin(end)];
    end
    xLimAuto(2)=max(xLimAuto(2),displayEndMin);
    if referenceTraceShown(),w=fusiReferenceTraceWindow(baseline.reference,state.referenceMode==2);xLimAuto(1)=min(xLimAuto(1),w.plotWindowSec(1)/60);end
    if sequenceTraceShown(),[~,finish]=sequenceWindows();xLimAuto=[0 finish/60];end
    if sum(bounds(:,6)) >= 2
        y0 = min(bounds(:,4)); y1 = max(bounds(:,5));
        if y1 > y0
            padY = max(0.15*(y1-y0), 0.5); yLimAuto = [y0-padY y1+padY];
        else
            yLimAuto = [y0-1 y1+1];
        end
    else
        yLimAuto = [-5 5];
    end
end

function bounds=traceBounds(x,y)
    x=x(isfinite(x)); y=y(isfinite(y));
    bounds=[inf -inf numel(x) inf -inf numel(y)];
    if ~isempty(x), bounds(1:2)=[min(x) max(x)]; end
    if ~isempty(y), bounds(4:5)=[min(y) max(y)]; end
end

function applyTimecourseXTicks(xLimNow)
    span = xLimNow(2)-xLimNow(1);
    if ~isfinite(span) || span <= 0
        set(axTC,'XTickMode','auto','XTickLabelMode','auto'); return;
    end
    if span <= 5, stepMin = 1; elseif span <= 15, stepMin = 2; elseif span<=40,stepMin=5;
    else
        targetStep=span/8;unit=10^floor(log10(targetStep));niceSteps=[1 2 5 10]*unit;
        stepMin=niceSteps(find(niceSteps>=targetStep,1));
    end
    ticks = ceil(xLimNow(1)/stepMin)*stepMin : stepMin : floor(xLimNow(2)/stepMin)*stepMin;
    if isempty(ticks), ticks = [xLimNow(1) xLimNow(2)]; end
    if numel(ticks) == 1, ticks = unique([xLimNow(1) ticks xLimNow(2)]); end
    if referenceTraceShown() && xLimNow(1)<0 && ~any(ticks<0)
        ticks=unique([round(xLimNow(1),2) ticks]);
    end
    ticks = ticks(isfinite(ticks));
    set(axTC,'XTick',ticks,'XTickMode','manual','XTickLabelMode','auto','XTickLabelRotation',0);
end

function drawTimeWindows()
    if ~isgraphics(axTC), return; end
    [b0,b1] = parseRangeSafe(getStr(ebBase),30,240);
    [s0,s1] = parseRangeSafe(getStr(ebSig),840,900);
    if isVolMode
        b0s = (clamp(round(b0),1,nT)-1)*TR; b1s = (clamp(round(b1),1,nT)-1)*TR;
        s0s = (clamp(round(s0),1,nT)-1)*TR; s1s = (clamp(round(s1),1,nT)-1)*TR;
    else
        b0s = b0; b1s = b1; s0s = s0; s1s = s1;
    end
    if b1s < b0s, tmp=b0s; b0s=b1s; b1s=tmp; end
    if s1s < s0s, tmp=s0s; s0s=s1s; s1s=tmp; end
    yl = get(axTC,'YLim'); if any(~isfinite(yl)) || yl(2) <= yl(1), yl = [-5 5]; set(axTC,'YLim',yl); end
    external=fusiBaselineReference('isExternal',baseline);
    showReference=referenceTraceShown();
    sequence=sequenceTraceShown();owner=[];
    if showReference,w=fusiReferenceTraceWindow(baseline.reference,state.referenceMode==2);b0s=w.baselinePlotSec(1);b1s=w.baselinePlotSec(2);end
    if sequence
        [start,~,owner]=sequenceWindows();L=fusiScanSequence('layout',state.scanSequence);s0s=s0s+start;s1s=s1s+start;
        if ~isempty(owner)
            window=[baseline.start baseline.end];if external,window=baseline.reference.windowSec;end
            b0s=window(1)+L(owner).startSec;b1s=window(2)+L(owner).startSec;
        end
    end
    key=[b0s b1s s0s s1s yl external showReference state.referenceMode get(axTC,'XLim')];
    if isequaln(state.timeWindowKey,key), return; end
    firstDraw=isempty(state.timeWindowKey);
    state.timeWindowKey=key;
    yr = yl(2)-yl(1); if ~isfinite(yr) || yr <= 0, yr = 1; end
    xb = [b0s b1s b1s b0s]/60; xs = [s0s s1s s1s s0s]/60;
    yb = [yl(1) yl(1) yl(2) yl(2)]; ys = yb;
    set(hBasePatch,'XData',xb,'YData',yb,'FaceColor',[1.00 0.20 0.20],'FaceAlpha',0.16,'Visible','on');
    set(hSigPatch,'XData',xs,'YData',ys,'FaceColor',[1.00 0.60 0.15],'FaceAlpha',0.16,'Visible','on');
    yTxt = yl(2) - 0.06*yr;
    if showReference||sequence,yTxt=yl(2)-.18*yr;end
    set(hBaseTxt,'Position',[mean(xb) yTxt 0],'String','Bas.','Visible','on','HorizontalAlignment','center','VerticalAlignment','middle','BackgroundColor',[0 0 0],'Margin',1,'Clipping','on');
    set(hSigTxt,'Position',[mean(xs) yTxt 0],'String','Sig.','Visible','on','HorizontalAlignment','center','VerticalAlignment','middle','BackgroundColor',[0 0 0],'Margin',1,'Clipping','on');
    if external&&~showReference&&(~sequence||isempty(owner)),set([hBasePatch hBaseTxt],'Visible','off');end
    deleteIfValid(hSequenceLabels);deleteIfValid(hSequenceBoundaries);hSequenceLabels=gobjects(0);hSequenceBoundaries=gobjects(0);
    deleteIfValid(hSequenceBaselineBands);hSequenceBaselineBands=gobjects(0);
    if showReference
        set(hScanBoundary,'XData',[0 0],'YData',yl,'Visible','on');
        refLabel=shortScanLabel(baseline.reference,'Reference scan');curLabel=shortScanLabel(par,'Current scan');
        set(hReferenceScanTxt,'Position',[w.plotWindowSec(1)/60 yl(2)-.025*yr 0], ...
            'String',['Reference: ' refLabel],'Visible','on');
        set(hCurrentScanTxt,'Position',[max(0,get(axTC,'XLim')*[0;1])/2 yl(2)-.025*yr 0], ...
            'String',['Current: ' curLabel ' (t = 0)'],'Visible','on');
        axTC.XLabel.String='Stitched time (min; current scan starts at 0)';
    elseif sequence
        set([hScanBoundary hReferenceScanTxt hCurrentScanTxt],'Visible','off');
        for si=1:numel(L)
            if ~isfinite(L(si).startSec),continue;end
            if strcmp(state.scanSequence.normMode,'local')&&si~=owner
                window=(state.scanSequence.localWindowSec+L(si).startSec)/60;
                hSequenceBaselineBands(end+1)=patch(axTC,window([1 2 2 1]),yb,[1 .2 .2], ...
                    'FaceAlpha',.10,'EdgeColor','none','Tag','SCM_SequenceBaseline');
                try,uistack(hSequenceBaselineBands(end),'bottom');catch,end
            end
            color=[.8 .8 .85];label=L(si).label;if si==state.scanSequence.active,color=[.55 .85 1];label=[label ' (overlay)'];end
            hSequenceLabels(end+1)=text(axTC,mean([L(si).startSec L(si).endSec])/60,yl(2)-.025*yr,label, ...
                'Color',color,'FontSize',10,'FontWeight','bold','HorizontalAlignment','center','VerticalAlignment','top', ...
                'BackgroundColor',[.05 .05 .05],'Margin',1,'Clipping','on','Interpreter','none','Tag','SCM_SequenceLabel');
            if L(si).startSec>0,hSequenceBoundaries(end+1)=line(axTC,[L(si).startSec L(si).startSec]/60,yl, ...
                    'LineStyle','--','Color',[.8 .85 .9],'Tag','SCM_SequenceBoundary');end
        end
        axTC.XLabel.String='Sequence time (min; scans arranged consecutively)';
    else
        set([hScanBoundary hReferenceScanTxt hCurrentScanTxt],'Visible','off');axTC.XLabel.String='Time (min)';
    end
    if firstDraw
        try, uistack(hBasePatch,'bottom'); uistack(hSigPatch,'bottom'); catch, end
    end
end

%% ==========================================================
% DATA HELPERS
%% ==========================================================
function PSCz = getPSCForSlice(z)
    if ndims(PSC) == 3
        PSCz = PSC;
    else
        PSCz = squeeze(PSC(:,:,clamp(round(z),1,nZ),:));
    end
end

function tf = isValidBundleUnderlayForCurrentScm(U)
    tf = false;

    try
        if isempty(U)
            return;
        end

        U = squeeze(U);

        % 2D underlay is valid only for single-slice SCM.
        % For multi-slice data, accepting 2D is exactly what causes
        % the same underlay to appear on all slices.
        if ndims(U) == 2
            tf = (nZ == 1 && size(U,1) == nY && size(U,2) == nX);
            return;
        end

        % Grayscale stack: Y x X x Z
        if ndims(U) == 3
            if size(U,1) ~= nY || size(U,2) ~= nX
                return;
            end

            % Correct multi-slice underlay stack.
            if size(U,3) == nZ
                tf = true;
                return;
            end

            % RGB image is allowed only for single-slice display.
            if nZ == 1 && size(U,3) == 3
                tf = true;
                return;
            end

            return;
        end

        % RGB stack: Y x X x 3 x Z
        if ndims(U) == 4
            tf = (size(U,1) == nY && ...
                  size(U,2) == nX && ...
                  size(U,3) == 3  && ...
                  size(U,4) == nZ);
            return;
        end

    catch
        tf = false;
    end
end


function Uout = prepareBundleUnderlayForCurrentScm(U)
    U = squeeze(double(U));
    U(~isfinite(U)) = 0;

    if ndims(U) == 2
        Uout = U;
        return;
    end

    if ndims(U) == 3
        Uout = U;
        return;
    end

    % Convert RGB stack Y x X x 3 x Z to grayscale stack Y x X x Z.
    if ndims(U) == 4 && size(U,3) == 3 && size(U,4) == nZ
        Uout = zeros(nY,nX,nZ);

        for zz0 = 1:nZ
            RGB = squeeze(U(:,:,:,zz0));
            Uout(:,:,zz0) = 0.2989 .* RGB(:,:,1) + ...
                             0.5870 .* RGB(:,:,2) + ...
                             0.1140 .* RGB(:,:,3);
        end

        return;
    end

    error('prepareBundleUnderlayForCurrentScm: unsupported underlay size %s', mat2str(size(U)));
end


function bg2 = getBg2DForSlice(z)
    ensureUnderlayStateFields(); z = clamp(round(z),1,nZ);
    if isempty(bg), bg2 = zeros(nY,nX); return; end
    if state.isColorUnderlay&&~isempty(state.regionLabelUnderlay)&&ndims(bg)<=3&& ...
            isequal(size(state.regionLabelUnderlay,[1 2 3]),[nY nX nZ])
        bg2=state.regionLabelUnderlay(:,:,z);return;
    end
    if ndims(bg) == 2
        bg2 = fitUnderlayPlaneToCurrentDisplay(bg); return;
    end
    if ndims(bg) == 3
        if size(bg,3) == 3 && state.isColorUnderlay
            bg2 = fitUnderlayPlaneToCurrentDisplay(bg); return;
        end
        if nZ > 1 && size(bg,3) == nZ
            bg2 = fitUnderlayPlaneToCurrentDisplay(bg(:,:,z)); return;
        end
        if nZ == 1 && size(bg,3) == nT
            bg2 = fitUnderlayPlaneToCurrentDisplay(mean(bg,3)); return;
        end
        bg2 = fitUnderlayPlaneToCurrentDisplay(bg(:,:,max(1,min(size(bg,3),z)))); return;
    end
    if ndims(bg) == 4
        if size(bg,3) == 3 && state.isColorUnderlay && size(bg,4) >= 1
            zUse = max(1,min(size(bg,4),z)); bg2 = squeeze(bg(:,:,:,zUse)); bg2 = fitUnderlayPlaneToCurrentDisplay(bg2); return;
        end
        tmp = mean(bg,4);
        if ndims(tmp) == 3
            bg2 = tmp(:,:,max(1,min(size(tmp,3),z)));
        else
            bg2 = squeeze(tmp(:,:,1));
        end
        bg2 = fitUnderlayPlaneToCurrentDisplay(bg2); return;
    end
    bg2 = squeeze(bg); if ndims(bg2) > 2, bg2 = bg2(:,:,1); end
    bg2 = fitUnderlayPlaneToCurrentDisplay(bg2);
end

function U2 = fitUnderlayPlaneToCurrentDisplay(U2)
    if isempty(U2), U2 = zeros(nY,nX); return; end
    U2 = squeeze(U2);
    if ndims(U2) == 2
        if size(U2,1) ~= nY || size(U2,2) ~= nX
            try
                U2 = imresize(double(U2), [nY nX], 'bilinear');
            catch
                tmp = zeros(nY,nX); yy = min(nY,size(U2,1)); xx = min(nX,size(U2,2));
                tmp(1:yy,1:xx) = double(U2(1:yy,1:xx)); U2 = tmp;
            end
        end
        return;
    end
    if ndims(U2) == 3 && size(U2,3) == 3
        if size(U2,1) ~= nY || size(U2,2) ~= nX
            try
                U2 = imresize(double(U2), [nY nX], 'bilinear');
            catch
                tmp = zeros(nY,nX,3); yy = min(nY,size(U2,1)); xx = min(nX,size(U2,2));
                tmp(1:yy,1:xx,:) = double(U2(1:yy,1:xx,:)); U2 = tmp;
            end
        end
        return;
    end
    if ndims(U2) > 2
        U2 = fitUnderlayPlaneToCurrentDisplay(U2(:,:,1));
    end
end

function maskLocal = getMaskForCurrentSlice()
    maskLocal = getMaskForSlice(state.z);
end

function maskLocal = getMaskForSlice(zSel)
    if isempty(passedMask)
        maskLocal = true(nY,nX);
    else
        maskLocal = collapseMaskForSlice(passedMask, nY, nX, zSel, nZ);
        if ~passedMaskIsInclude, maskLocal = ~maskLocal; end
    end
end

function M = fitBundleMaskToCurrentScm(M0)
    M = [];
    if isempty(M0), return; end
    M0 = logical(M0);
    if ismatrix(M0)
        M = resizeMask2D(M0, nY, nX); return;
    end
    if ndims(M0) == 3
        if size(M0,1) ~= nY || size(M0,2) ~= nX
            tmp = false(nY,nX,size(M0,3));
            for zz = 1:size(M0,3), tmp(:,:,zz) = resizeMask2D(M0(:,:,zz), nY, nX); end
            M0 = tmp;
        end
        if nZ > 1 && size(M0,3) == nZ
            M = M0;
        elseif nZ == 1
            M = any(M0,3);
        else
            zIdx = round(linspace(1,size(M0,3),nZ)); zIdx = max(1,min(size(M0,3),zIdx));
            M = M0(:,:,zIdx);
        end
        return;
    end
    while ndims(M0) > 3, M0 = any(M0, ndims(M0)); end
    M = fitBundleMaskToCurrentScm(M0);
end


function M = SCM_localMaskToMapSize_20260504(M, mapOrY, nx)
    % Robust mask fitter for SCM maps loaded from GroupAnalysis bundles.
    try
        if nargin < 3
            ny = size(mapOrY,1);
            nx = size(mapOrY,2);
        else
            ny = mapOrY;
        end

        if isempty(M)
            M = true(ny,nx);
            return;
        end

        M = squeeze(M);

        if ndims(M) > 2
            % For a stack mask, use the current z if possible; otherwise collapse.
            try
                if exist('state','var') && isfield(state,'z') && size(M,3) >= state.z
                    M = M(:,:,state.z);
                else
                    M = any(M,3);
                end
            catch
                M = any(M,3);
            end
        end

        M = logical(M);

        if size(M,1) ~= ny || size(M,2) ~= nx
            try
                M = imresize(double(M), [ny nx], 'nearest') > 0.5;
            catch
                tmp = false(ny,nx);
                yy = min(ny,size(M,1));
                xx = min(nx,size(M,2));
                tmp(1:yy,1:xx) = M(1:yy,1:xx);
                M = tmp;
            end
        end

        M = logical(M);
    catch
        try
            M = true(size(mapOrY,1), size(mapOrY,2));
        catch
            M = true(nY,nX);
        end
    end
end

function M2 = resizeMask2D(M0, ny, nx)
    if size(M0,1) == ny && size(M0,2) == nx
        M2 = logical(M0);
    else
        try
            M2 = imresize(double(M0), [ny nx], 'nearest') > 0.5;
        catch
            M2 = false(ny,nx); yy = min(ny,size(M0,1)); xx = min(nx,size(M0,2));
            M2(1:yy,1:xx) = logical(M0(1:yy,1:xx));
        end
    end
end

function M2 = collapseMaskForSlice(M0, ny, nx, z, nZ_)
    if isempty(M0), M2 = true(ny,nx); return; end
    M0 = logical(M0);
    if ndims(M0) == 2
        M2 = M0;
    elseif ndims(M0) == 3
        if nZ_ > 1 && size(M0,3) == nZ_
            z = max(1,min(size(M0,3),round(z))); M2 = M0(:,:,z);
        else
            M2 = any(M0,3);
        end
    else
        tmp = M0;
        while ndims(tmp) > 3, tmp = any(tmp, ndims(tmp)); end
        M2 = collapseMaskForSlice(tmp, ny, nx, z, nZ_);
        return;
    end
    M2 = resizeMask2D(M2, ny, nx);
end

function M = deriveMaskFromUnderlay(bgIn, ny, nx, nz, nt)
    M = [];
    if isempty(bgIn) || ~(isnumeric(bgIn) || islogical(bgIn)), return; end
    try
        if ndims(bgIn) == 2
            V = reshape(double(bgIn), [ny nx 1]);
        elseif ndims(bgIn) == 3
            if nz > 1 && size(bgIn,3) == nz
                V = double(bgIn);
            elseif nz == 1 && size(bgIn,3) == nt
                V = reshape(mean(double(bgIn),3), [ny nx 1]);
            else
                V = reshape(double(bgIn(:,:,1)), [ny nx 1]);
            end
        elseif ndims(bgIn) == 4
            V = mean(double(bgIn),4);
        else
            return;
        end
        V = V(1:min(ny,size(V,1)),1:min(nx,size(V,2)),1:min(nz,size(V,3)));
        if size(V,1) < ny, V(end+1:ny,:,:) = 0; end
        if size(V,2) < nx, V(:,end+1:nx,:) = 0; end
        if size(V,3) < nz, V(:,:,end+1:nz) = 0; end
        fracZero = mean(V(:) == 0);
        if ~isfinite(fracZero) || fracZero < 0.02, M = []; return; end
        M = logical(V ~= 0);
        try
            for zz = 1:size(M,3), M(:,:,zz) = imfill(M(:,:,zz), 'holes'); end
        catch
        end
    catch
        M = [];
    end
end

function U = makeNativeFallbackUnderlayFromPSC(X)
    if ndims(X) == 3
        U = mean(double(X),3);
    elseif ndims(X) == 4
        U = mean(double(X),4);
    else
        U = zeros(nY,nX);
    end
    U(~isfinite(U)) = 0;
    if ndims(U) > 3
        U = squeeze(U);
        if ndims(U) > 3, U = U(:,:,1); end
    end
end

%% ==========================================================
% UNDERLAY PROCESSING / COLORMAPS
%% ==========================================================
function rgb = renderUnderlayRGB(Uin)
    ensureUnderlayStateFields();
    if state.isColorUnderlay
        rgb = convertUnderlayToColorRGB(Uin);
    elseif uState.mode == 5
        rgb = repmat(processUnderlay(Uin),[1 1 3]);
    else
        rgb = toRGB(processUnderlay(Uin));
    end
end

function rgb=currentUnderlayDisplayRGB(z)
    key=struct('slice',z,'revision',state.underlayRevision,'appearance',uState,'scheme',state.regionScheme);
    for k=1:numel(state.renderedAtlasCache)
        entry=state.renderedAtlasCache{k};if isequal(entry.key,key),rgb=entry.rgb;return;end
    end
    if isempty(state.atlasDisplay3D)
        U=getBg2DForSlice(z);
        if state.isColorUnderlay&&~isempty(state.regionLabelUnderlay)&&~strcmp(state.regionScheme,'Atlas')
            U=fusiRegionLabelRGB(state.regionLabelUnderlay(:,:,min(z,size(state.regionLabelUnderlay,3))),state.regionInfo,state.regionScheme);
        end
    else
        U=state.atlasDisplay3D.getSlice(z);
        if state.isColorUnderlay&&~strcmp(state.regionScheme,'Atlas')
            U=fusiRegionLabelRGB(state.atlasDisplay3D.getLabels(z),state.regionInfo,state.regionScheme);
        end
    end
    rgb=single(renderUnderlayRGB(U));
    bytes=numel(rgb)*4;
    if bytes<=64*1024^2
        while ~isempty(state.renderedAtlasCache)&&(numel(state.renderedAtlasCache)>=12|| ...
                sum(cellfun(@(e)numel(e.rgb)*4,state.renderedAtlasCache))+bytes>64*1024^2),state.renderedAtlasCache(1)=[];end
        state.renderedAtlasCache{end+1}=struct('key',key,'rgb',rgb);
    end
end

function updateSCMUnderlayDisplay(z)
    set(hBG,'CData',currentUnderlayDisplayRGB(z));
    syncSCMImageGeometry();updateRegionLabels();
end

function U = processUnderlay(Uin)
    excluded = ~isfinite(Uin);
    U = double(Uin); U(excluded) = 0;
    switch uState.mode
        case 1
            U = mat2gray_safe(U);
        case 2
            U = clip01_percentile(U, 1, 99);
        case 3
            U = clip01_percentile(U, 0.5, 99.5);
        case 4
            U = clip01_percentile(U, 0.5, 99.5);
            U = vesselEnhanceStrong(U, uState.conectSize, uState.conectLev);
            U = clip01_percentile(U, 0.5, 99.5);
        case 5
            % Mask Editor already applied its scaling, tone and enhancement.
            U = min(max(U,0),1);
        otherwise
            U = mat2gray_safe(U);
    end
    U = U*uState.contrast + uState.brightness;
    U = min(max(U,0),1);
    g = uState.gamma; if ~isfinite(g) || g <= 0, g = 1; end
    U = min(max(U.^g,0),1);
    U(excluded) = 0; % Brightness/enhancement must not reveal excluded tissue.
end

function U = vesselEnhanceStrong(U01, conectSizePx, conectLev_0_MAX)
    if conectSizePx <= 0, U = U01; return; end
    lev01 = (conectLev_0_MAX / max(1, MAX_CONLEV)); lev01 = min(max(lev01^0.75,0),1);
    thrMask = (U01 > lev01);
    r = max(1, min(MAX_CONSIZE, round(conectSizePx)));
    h = diskKernel(r);
    try, D = filter2(h, double(thrMask), 'same'); catch, D = conv2(double(thrMask), h, 'same'); end
    D = min(max(D,0),1);
    strength = 0.8 + 1.6*min(1, r/120);
    D2 = D.^2;
    U = min(max(U01 .* (1 + strength*D2) + 0.15*D2,0),1);
end

function h = diskKernel(r)
    r = max(1,round(r)); [x,y] = meshgrid(-r:r,-r:r); m = (x.^2 + y.^2) <= r^2;
    h = double(m); s = sum(h(:)); if s > 0, h = h/s; end
end

function rgb = convertUnderlayToColorRGB(U)
    U = squeeze(U);
    if ndims(U) == 3 && size(U,3) == 3
        rgb = double(U); if max(rgb(:)) > 1, rgb = rgb/255; end
        rgb = min(max(rgb,0),1); return;
    end
    L = double(U); L(~isfinite(L)) = 0;
    maxLab = max(L(:));
    if isempty(state.regionColorLUT) || size(state.regionColorLUT,1) < max(1,maxLab)
        state.regionColorLUT = fusiRegionColorLUT(state.regionInfo,max(1,maxLab));
    end
    rgb = zeros([size(L,1) size(L,2) 3], 'double');
    zmask = (L == 0);
    % Region 0 is always black.
    pos = find(L > 0);
    if ~isempty(pos)
        labs = round(L(pos)); labs(labs < 1) = 1; labs(labs > size(state.regionColorLUT,1)) = size(state.regionColorLUT,1);
        c = state.regionColorLUT(labs,:);
        tmp = reshape(rgb, [], 3); tmp(pos,:) = c; rgb = reshape(tmp, size(rgb));
    end
    rgb = min(max(rgb,0),1);
end

function lut = makeRegionColorLUT(n)
    if n <= 0, lut = zeros(1,3); return; end
    base = lines(max(n,12)); lut = base(1:n,:);
    if n > size(base,1)
        x = linspace(0,1,size(base,1)); xi = linspace(0,1,n); tmp = zeros(n,3);
        for k = 1:3, tmp(:,k) = interp1(x,base(:,k),xi,'linear'); end
        lut = min(max(tmp,0),1);
    end
end

function setOverlayColormap(name)
    cm = getCmap(name, 256);
    try, colormap(ax, cm); catch, colormap(fig, cm); end
end

function cm = getCmap(name, n)
    if nargin < 2, n = 256; end
    if exist('isstring','builtin') && isstring(name), name = char(name); end
    name = lower(strtrim(char(name)));
    if strcmp(name,'blackbdy_iso')
        if exist('blackbdy_iso','file'), cm = blackbdy_iso(n); else, cm = hot(n); end
        return;
    end
    if strcmp(name,'winter_brain_fsl')
        if exist('winter_brain_fsl','file'), cm = winter_brain_fsl(n); else, cm = winter(n); end
        return;
    end
    if strcmp(name,'signed_blackbdy_winter')
        nNeg = floor(n/2); nPos = n - nNeg;
        if exist('winter_brain_fsl','file'), neg = winter_brain_fsl(max(nNeg,2)); else, neg = winter(max(nNeg,2)); end
        neg = neg(1:nNeg,:); neg = neg .* repmat(linspace(1,0,nNeg)',1,3); if ~isempty(neg), neg(end,:) = [0 0 0]; end
        if exist('blackbdy_iso','file'), pos = blackbdy_iso(max(nPos,2)); else, pos = hot(max(nPos,2)); end
        pos = pos(1:nPos,:); if ~isempty(pos), pos(1,:) = [0 0 0]; end
        cm = min(max([neg; pos],0),1); return;
    end
    switch name
        case 'winter', cm = winter(n); return;
        case 'hot', cm = hot(n); return;
        case 'parula', cm = parula(n); return;
        case 'jet', cm = jet(n); return;
        case 'gray', cm = gray(n); return;
        case 'bone', cm = bone(n); return;
        case 'copper', cm = copper(n); return;
        case 'pink', cm = pink(n); return;
        case 'turbo'
            if exist('turbo','file'), cm = turbo(n); else, cm = jet(n); end
            return;
        case 'viridis'
            cm = interpAnchors([0.267 0.005 0.329;0.283 0.141 0.458;0.254 0.265 0.530;0.207 0.372 0.553;0.164 0.471 0.558;0.128 0.567 0.551;0.135 0.659 0.518;0.267 0.749 0.441;0.478 0.821 0.318;0.741 0.873 0.150],n); return;
        case 'plasma'
            cm = interpAnchors([0.050 0.030 0.528;0.280 0.040 0.650;0.500 0.060 0.650;0.700 0.170 0.550;0.850 0.350 0.420;0.940 0.550 0.260;0.990 0.750 0.140],n); return;
        case 'magma'
            cm = interpAnchors([0.001 0.000 0.015;0.100 0.060 0.230;0.250 0.080 0.430;0.450 0.120 0.500;0.650 0.210 0.420;0.820 0.370 0.280;0.930 0.610 0.210;0.990 0.870 0.400],n); return;
        case 'inferno'
            cm = interpAnchors([0.002 0.002 0.014;0.120 0.030 0.220;0.280 0.050 0.400;0.480 0.090 0.430;0.680 0.180 0.330;0.820 0.350 0.210;0.930 0.590 0.110;0.990 0.860 0.240],n); return;
    end
    cm = hot(n);
end

function cm = interpAnchors(anchors, n)
    x = linspace(0,1,size(anchors,1)); xi = linspace(0,1,n); cm = zeros(n,3);
    for k = 1:3, cm(:,k) = interp1(x,anchors(:,k),xi,'linear'); end
    cm = min(max(cm,0),1);
end

%% ==========================================================
% FILE READING / TRANSFORMS
%% ==========================================================
function [f,p] = uigetfileStartIn(filterSpec, dlgTitle, startPath)
    if nargin < 3 || isempty(startPath) || exist(startPath,'dir') ~= 7, startPath = pwd; end
    oldDir = pwd;
    cleanupObj = onCleanup(@()scmSafeCdBack(oldDir)); %#ok<NASGU>
    try, cd(startPath); catch, startPath = pwd; end
    try
        [f,p] = uigetfile(filterSpec, dlgTitle, fullfile(startPath, '*.*'));
    catch
        [f,p] = uigetfile(filterSpec, dlgTitle);
    end
end

function scmSafeCdBack(oldDir)
    try
        if ~isempty(oldDir) && exist(oldDir,'dir') == 7, cd(oldDir); end
    catch
    end
end

    function startPath = getMaskStartPath()
% Best folder for LOAD MASK / LOAD BUNDLE.
% Mask Editor exports and SCM/Video underlay-overlay bundles are usually
% in Visualization, so Visualization should stay first.

    try
        if isstruct(par) && isfield(par,'maskStartPath') && ...
                ~isempty(par.maskStartPath) && exist(char(par.maskStartPath),'dir') == 7
            startPath = char(par.maskStartPath);
            return;
        end
    catch
    end

    root = getDatasetRootForSelectors();

    cand = { ...
        fullfile(root,'Visualization'), ...
        fullfile(root,'Masks'), ...
        fullfile(root,'Mask'), ...
        fullfile(root,'ROI'), ...
        fullfile(root,'Registration2D'), ...
        fullfile(root,'Registration'), ...
        root, ...
        getStartPath(), ...
        pwd};

    startPath = firstExistingDir(cand);
end
    function startPath = getTransformStartPath()
% Best folder for WARP FUNCTIONAL TO ATLAS.
% CoronalRegistration2D*.mat should usually be in Registration2D.

    try
        if isstruct(par) && isfield(par,'transformStartPath') && ...
                ~isempty(par.transformStartPath) && exist(char(par.transformStartPath),'dir') == 7
            startPath = char(par.transformStartPath);
            return;
        end
    catch
    end

    root = getDatasetRootForSelectors();

    cand = { ...
        fullfile(root,'Registration2D'), ...
        fullfile(root,'Registration'), ...
        root, ...
        getStartPath(), ...
        pwd};

    startPath = firstExistingDir(cand);
end

    function startPath = getUnderlayStartPathFast()
    lastFile='';if isfield(state,'lastUnderlayFile'),lastFile=state.lastUnderlayFile;end
    options=fusiUnderlayPickerOptions(par,getDatasetRootForSelectors(),state.atlasTransformFile,lastFile);
    startPath=options.startPath;
end

function apply3DAtlasWarp(bundle)
    meta=bundle.meta;[newBG,viewMeta,Tgrid,gridInfo]=fusiCachedAtlasUnderlayView3D(bundle.underlay,meta,'atlas');
    reuse=state.isAtlasWarped && isfield(state,'atlasUnderlayKey') && isequal(state.atlasUnderlayKey,meta.registrationKey);
    if ~reuse,PSC=fusiWarpAtlasForDisplay(origPSC,Tgrid,true);end
    bg=newBG;passedMask=[];passedMaskIsInclude=true;
    state.pendingAtlasUnderlay3D=bundle;state.atlasUnderlayKey=meta.registrationKey;state.atlasSliceSampling=gridInfo;
    state.isAtlasWarped=true;state.isStepMotorAtlasWarped=false;
    if ~reuse,state.currentROIMapping=struct('kind','3D','transform',Tgrid);end
    transformFile=fusiAtlasPairedTransformFile(meta,bundle.file);
    state.atlasTransformFile=transformFile;state.lastAtlasTransformFile=transformFile;
    par.atlasVoxelSizeYXZUm=viewMeta.voxelSizeUm;
    applyUnderlayMeta(viewMeta,bg);
    refreshAtlasUnderlayChoices('atlas');
    if ~reuse,applyRecommendedUnderlayDisplayForModeLocal(meta.atlasMode);end
    if ~reuse,resetRoisAndRefreshAfterDataChange(true);else,updateSCMUnderlayDisplay(state.z);computeSCM();end
    setTitleAtlas(meta.transform);
    set(btnWarpAtlas,'String','WARP TO ATLAS: CHOOSE TRANSFORM','TooltipString',transformFile);
    [folder,name,ext]=fileparts(transformFile);[~,version]=fileparts(folder);
    set(info1,'String',sprintf('Atlas: %s | %s/%s%s | %d acquired slices', ...
        meta.atlasMode,version,name,ext,size(origPSC,3)),'TooltipString',transformFile);
    setappdata(fig,'FUSIAtlasAppliedTransformFile',transformFile);
end

function startPath = getStartPath()
    candDirs = {};
    try
        if isstruct(par)
            if isfield(par,'exportPath') && ~isempty(par.exportPath), candDirs{end+1} = char(par.exportPath); end %#ok<AGROW>
            if isfield(par,'loadedPath') && ~isempty(par.loadedPath), candDirs{end+1} = char(par.loadedPath); end %#ok<AGROW>
            if isfield(par,'rawPath') && ~isempty(par.rawPath), candDirs{end+1} = char(par.rawPath); end %#ok<AGROW>
            if isfield(par,'loadedFile') && ~isempty(par.loadedFile)
                lf = char(par.loadedFile); if exist(lf,'file') == 2, candDirs{end+1} = fileparts(lf); end %#ok<AGROW>
            end
        end
    catch
    end
    candDirs{end+1} = pwd;
    startPath = firstExistingDir(candDirs);
end

function root = getDatasetRootForSelectors()
    root = '';
    try
        if isstruct(par)
            if isfield(par,'selectorRoot') && ~isempty(par.selectorRoot) && exist(char(par.selectorRoot),'dir') == 7
                root = char(par.selectorRoot);
            elseif isfield(par,'exportPath') && ~isempty(par.exportPath) && exist(char(par.exportPath),'dir') == 7
                root = char(par.exportPath);
            elseif isfield(par,'loadedPath') && ~isempty(par.loadedPath) && exist(char(par.loadedPath),'dir') == 7
                root = char(par.loadedPath);
            elseif isfield(par,'loadedFile') && ~isempty(par.loadedFile)
                lf = char(par.loadedFile); if exist(lf,'file') == 2, root = fileparts(lf); end
            elseif isfield(par,'rawPath') && ~isempty(par.rawPath) && exist(char(par.rawPath),'dir') == 7
                root = char(par.rawPath);
            end
        end
    catch
        root = '';
    end
    if isempty(root), root = pwd; end
    try, root = guessAnalysedRoot(root); catch, end
    root = normalizeSelectorRoot(root);
end

function root = normalizeSelectorRoot(root)
    if isempty(root) || exist(root,'dir') ~= 7, root = pwd; return; end
    leafFolders = {'Visualization','Masks','Mask','ROI','Registration2D','Registration','SCM','Images','Series','Timecourse','PSC','Preprocessing','QC','Bundles'};
    for kk = 1:4
        [parentDir, leafName] = fileparts(root);
        if isempty(parentDir) || strcmp(parentDir,root), break; end
        if any(strcmpi(leafName, leafFolders)), root = parentDir; else, break; end
    end
end

function d = firstExistingDir(cand)
    d = pwd;
    for ii = 1:numel(cand)
        try
            c0 = cand{ii};
            if ~isempty(c0) && exist(c0,'dir') == 7, d = c0; return; end
        catch
        end
    end
end

function [U, meta] = readUnderlayFile(f)
    if ~exist(f,'file'), error('Underlay file not found: %s', f); end
    meta = defaultUnderlayMeta();
    isNiiGz = (numel(f) >= 7 && strcmpi(f(end-6:end), '.nii.gz'));
    if isNiiGz
        tmpDir = tempname; mkdir(tmpDir); gunzip(f,tmpDir); ddd = dir(fullfile(tmpDir,'*.nii'));
        if isempty(ddd), error('Failed to gunzip .nii.gz underlay.'); end
        U = double(niftiread(fullfile(tmpDir,ddd(1).name)));
        try, rmdir(tmpDir,'s'); catch, end
        return;
    end
    [~,~,e] = fileparts(f); e = lower(e);
    switch e
        case '.mat'
            [matched,U,meta]=fusiCachedAtlasUnderlay3D(f);if matched,return;end
            S = load(f); [U,meta] = extractUnderlayFromMatStruct(S);
        case '.nii'
            U = double(niftiread(f));
        case {'.png','.jpg','.jpeg','.tif','.tiff','.bmp'}
            U = imread(f); U = double(U); if ndims(U) == 3 && size(U,3) == 3, meta.isColor = true; end
        otherwise
            error('Unsupported underlay file type: %s', e);
    end
end

function meta = defaultUnderlayMeta()
    meta = struct('isColor',false,'regionLabels',[],'regionInfo',struct(),'atlasMode','');
end

function [U, meta] = extractUnderlayFromMatStruct(S)
    [matched,U,meta]=fusiReadAtlasUnderlay3D(S);if matched,return;end
    meta = defaultUnderlayMeta();
    B = scmReadMaskEditorBundle(S);
    if ~isempty(B)
        U = B.image;
        meta.maskEditorBundle = B;
        return;
    end
    if isfield(S,'atlasMode') && ~isempty(S.atlasMode)
        try, meta.atlasMode = char(S.atlasMode); catch, meta.atlasMode = ''; end
    end
    if strcmpi(meta.atlasMode,'regions')
        if isfield(S,'atlasUnderlayRGB') && ~isempty(S.atlasUnderlayRGB)
            U = double(S.atlasUnderlayRGB); meta.isColor = true;
        elseif isfield(S,'brainImage') && ~isempty(S.brainImage)
            U = double(S.brainImage); if ndims(U) == 3 && size(U,3) == 3, meta.isColor = true; end
        else
            error('Regions MAT file has no atlasUnderlayRGB / brainImage.');
        end
        if isfield(S,'atlasRegionLabels2D') && ~isempty(S.atlasRegionLabels2D), meta.regionLabels = double(S.atlasRegionLabels2D);
        elseif isfield(S,'atlasUnderlay') && ~isempty(S.atlasUnderlay), meta.regionLabels = double(S.atlasUnderlay); end
        if isfield(S,'atlasInfoRegions') && ~isempty(S.atlasInfoRegions), meta.regionInfo = S.atlasInfoRegions;
        elseif isfield(S,'infoRegions') && ~isempty(S.infoRegions), meta.regionInfo = S.infoRegions; end
        if ~isempty(meta.regionLabels),U=fusiRegionLabelRGB(meta.regionLabels,meta.regionInfo);end
        return;
    end
 pref = { ...
    'sliceUnderlayRaw', ...
    'sliceUnderlayProcessed', ...
    'anatomical_reference_raw', ...
    'anatomical_reference', ...
    'atlasUnderlayRGB', ...
    'atlasUnderlay', ...
    'underlay', ...
    'bg', ...
    'brainImage', ...
    'img', ...
    'I', ...
    'vascular', ...
    'histology', ...
    'regions', ...
    'Data'};
    for ii = 1:numel(pref)
        if isfield(S,pref{ii})
            v = S.(pref{ii});
            if isstruct(v) && isfield(v,'Data') && isnumeric(v.Data)
                U = double(v.Data); if ndims(U)==3 && size(U,3)==3, meta.isColor = true; end; return;
            elseif isnumeric(v) || islogical(v)
                U = double(v); if ndims(U)==3 && size(U,3)==3, meta.isColor = true; end; return;
            end
        end
    end
    fn = fieldnames(S);
    for ii = 1:numel(fn)
        v = S.(fn{ii});
        if isstruct(v) && isfield(v,'Data') && isnumeric(v.Data)
            U = double(v.Data); if ndims(U)==3 && size(U,3)==3, meta.isColor = true; end; return;
        elseif isnumeric(v) || islogical(v)
            U = double(v); if ndims(U)==3 && size(U,3)==3, meta.isColor = true; end; return;
        end
    end
    error('MAT underlay file has no usable numeric variable.');
end

function signalUnderlayCB(~,~)
    choices = {'P90 (sharp, clean)','Mean first 10 vols','First volume','Max'};
    [selIx, okSel] = listdlg('PromptString','Build underlay from signal:', ...
        'SelectionMode','single','ListString',choices,'InitialValue',1, ...
        'Name','Signal underlay','ListSize',[220 90]);
    if ~okSel || isempty(selIx), return; end
    dimT = ndims(PSC);
    Tf = size(PSC, dimT);
    if Tf > 600
        idxT = 1:ceil(Tf/600):Tf;
        subsSub = repmat({':'},1,dimT); subsSub{dimT} = idxT;
        Psub = double(PSC(subsSub{:}));
    else
        Psub = double(PSC);
    end
    dt2 = ndims(Psub);
    switch selIx
        case 1
            Is = sort(Psub, dt2); nq = size(Is, dt2);
            kq = max(1, min(nq, round(0.90*nq)));
            subsK = repmat({':'},1,dt2); subsK{dt2} = kq;
            U = Is(subsK{:});
        case 2
            nf = max(1, min(size(PSC,dimT), 10));
            subsN = repmat({':'},1,dimT); subsN{dimT} = 1:nf;
            U = mean(double(PSC(subsN{:})), dimT);
        case 3
            subs1 = repmat({':'},1,dimT); subs1{dimT} = 1;
            U = double(PSC(subs1{:}));
        otherwise
            U = max(Psub, [], dt2);
    end
    U = squeeze(U);
    bg = validateAndPrepareUnderlay(U, 'signal projection');
    applyUnderlayMeta(struct(), bg);
    origBG = bg;
    try, updateSCMUnderlayDisplay(state.z); catch, end
    try, set(info1, 'String', ['Underlay from signal: ' choices{selIx}]); catch, end
end

function U = validateAndPrepareUnderlay(U, fullf)
    U = squeeze(U);
    if isempty(U) || ~(isnumeric(U) || islogical(U)), error('Loaded underlay is not numeric or logical: %s', fullf); end
    U = double(U);
end

function applyUnderlayMeta(meta, U)
    if isfield(state,'underlayRevision'),state.underlayRevision=state.underlayRevision+1;end
    state.renderedAtlasCache={};
    ensureUnderlayStateFields();
    state.atlasDisplay3D=[];
    if isstruct(meta) && isfield(meta,'displayProvider'),state.atlasDisplay3D=meta.displayProvider;end
    if ~(isstruct(meta)&&isfield(meta,'registrationBundle3D')&&meta.registrationBundle3D)
        setappdata(popAtlasChoice,'AtlasUnderlayEntries2D',{});
        state.atlasRegionSearch=[];
        if exist('popAtlasChoice','var')&&isgraphics(popAtlasChoice),set(popAtlasChoice,'Enable','off');end
    end
    if uState.mode == 5
        % Saved-appearance scaling belongs to the loaded processed image.
        applyRecommendedUnderlayDisplayForModeLocal('normal');
    end
    state.isColorUnderlay = false; state.regionLabelUnderlay = []; state.regionColorLUT = []; state.regionInfo = struct();
    explicitRegionMode = false;
    if nargin >= 1 && isstruct(meta)
        if isfield(meta,'regionLabels') && ~isempty(meta.regionLabels)
            state.regionLabelUnderlay = double(meta.regionLabels); state.isColorUnderlay = true; explicitRegionMode = true;
        end
        if isfield(meta,'regionInfo') && ~isempty(meta.regionInfo), state.regionInfo = meta.regionInfo; end
        if isfield(meta,'atlasMode') && ~isempty(meta.atlasMode)
            try
                if strcmpi(char(meta.atlasMode),'regions'), explicitRegionMode = true; state.isColorUnderlay = true; end
            catch
            end
        end
        if isfield(meta,'isColor') && meta.isColor, state.isColorUnderlay = true; end
    end
    if nargin < 2 || isempty(U), return; end
    if isstruct(meta) && isfield(meta,'registrationBundle3D') && meta.registrationBundle3D
        state.isColorUnderlay=logical(meta.isColor);return;
    end
    if isstruct(meta) && isfield(meta,'registrationBundle2D') && meta.registrationBundle2D
        % Three motor planes are a grayscale stack, not an RGB image.
        state.isColorUnderlay=logical(meta.isColor);return;
    end
    U = squeeze(U);
    ambiguousThreeSliceStack = ndims(U) == 3 && size(U,3) == 3 && nZ > 1 && size(U,1) == nY && size(U,2) == nX;
    if explicitRegionMode, state.isColorUnderlay = true; return; end
    if ndims(U) == 3 && size(U,3) == 3
        state.isColorUnderlay = ~ambiguousThreeSliceStack;
    end
end

function ensureUnderlayStateFields()
    if ~isfield(state,'isColorUnderlay') || isempty(state.isColorUnderlay), state.isColorUnderlay = false; end
    if ~isfield(state,'regionLabelUnderlay') || isempty(state.regionLabelUnderlay), state.regionLabelUnderlay = []; end
    if ~isfield(state,'regionColorLUT') || isempty(state.regionColorLUT), state.regionColorLUT = []; end
    if ~isfield(state,'regionInfo') || isempty(state.regionInfo), state.regionInfo = struct(); end
end

function B = readScmBundleFile(fullf)
    if ~exist(fullf,'file'), error('File not found: %s', fullf); end
    S = load(fullf);
    B = scmReadMaskEditorBundle(S);
    if ~isempty(B), return; end
    if isfield(S,'maskBundle') && isstruct(S.maskBundle) && ~isempty(S.maskBundle), R = S.maskBundle; else, R = S; end
    B = struct('brainImage',[],'overlayMask',[],'brainMask',[],'overlayMaskIsInclude',true,'brainMaskIsInclude',true,'loadedField','','source',fullf);
    overlayFields = {'loadedMask','overlayMask','signalMask','overlay','overlay_mask','signal_mask','mask','activeMask'};
    for k = 1:numel(overlayFields)
        fn = overlayFields{k};
        if isfield(R,fn) && ~isempty(R.(fn)) && (isnumeric(R.(fn)) || islogical(R.(fn)))
            B.overlayMask = logical(R.(fn)); B.loadedField = fn; break;
        elseif isfield(S,fn) && ~isempty(S.(fn)) && (isnumeric(S.(fn)) || islogical(S.(fn)))
            B.overlayMask = logical(S.(fn)); B.loadedField = fn; break;
        end
    end
    brainFields = {'brainMask','underlayMask','brain_mask','underlay_mask'};
    for k = 1:numel(brainFields)
        fn = brainFields{k};
        if isfield(R,fn) && ~isempty(R.(fn)) && (isnumeric(R.(fn)) || islogical(R.(fn)))
            B.brainMask = logical(R.(fn)); break;
        elseif isfield(S,fn) && ~isempty(S.(fn)) && (isnumeric(S.(fn)) || islogical(S.(fn)))
            B.brainMask = logical(S.(fn)); break;
        end
    end
    % Prefer full saved underlay stacks from Mask Editor.
% brainImage can be masked or accidentally 2D, so use it only after
% anatomical_reference / anatomical_reference_raw.
underlayFields = { ...
    'anatomical_reference', ...
    'anatomical_reference_raw', ...
    'brainImage', ...
    'underlay', ...
    'bg', ...
    'brain_image'};

for k = 1:numel(underlayFields)
    fn = underlayFields{k};

    if isfield(R,fn) && ~isempty(R.(fn)) && (isnumeric(R.(fn)) || islogical(R.(fn)))
        B.brainImage = double(R.(fn));
        break;

    elseif isfield(S,fn) && ~isempty(S.(fn)) && (isnumeric(S.(fn)) || islogical(S.(fn)))
        B.brainImage = double(S.(fn));
        break;
    end
end
    if isfield(R,'overlayMaskIsInclude') && ~isempty(R.overlayMaskIsInclude), B.overlayMaskIsInclude = logical(R.overlayMaskIsInclude);
    elseif isfield(S,'overlayMaskIsInclude') && ~isempty(S.overlayMaskIsInclude), B.overlayMaskIsInclude = logical(S.overlayMaskIsInclude);
    elseif isfield(R,'loadedMaskIsInclude') && ~isempty(R.loadedMaskIsInclude), B.overlayMaskIsInclude = logical(R.loadedMaskIsInclude);
    elseif isfield(S,'loadedMaskIsInclude') && ~isempty(S.loadedMaskIsInclude), B.overlayMaskIsInclude = logical(S.loadedMaskIsInclude);
    elseif isfield(R,'maskIsInclude') && ~isempty(R.maskIsInclude), B.overlayMaskIsInclude = logical(R.maskIsInclude);
    elseif isfield(S,'maskIsInclude') && ~isempty(S.maskIsInclude), B.overlayMaskIsInclude = logical(S.maskIsInclude); end
    if isfield(R,'brainMaskIsInclude') && ~isempty(R.brainMaskIsInclude), B.brainMaskIsInclude = logical(R.brainMaskIsInclude);
    elseif isfield(S,'brainMaskIsInclude') && ~isempty(S.brainMaskIsInclude), B.brainMaskIsInclude = logical(S.brainMaskIsInclude); end
end









function [M, maskIsInclude, pickedField] = readMask(f, mode)
    if nargin < 2 || isempty(mode), mode = 'overlayPreferred'; end %#ok<NASGU>
    if ~exist(f,'file'), error('Mask file not found: %s', f); end
    maskIsInclude = true; pickedField = '';
    isNiiGz = (numel(f) >= 7 && strcmpi(f(end-6:end), '.nii.gz'));
    if isNiiGz
        tmpDir = tempname; mkdir(tmpDir); gunzip(f,tmpDir); ddd = dir(fullfile(tmpDir,'*.nii'));
        if isempty(ddd), error('Failed to gunzip .nii.gz mask.'); end
        M = logical(niftiread(fullfile(tmpDir,ddd(1).name))); pickedField = 'nifti';
        try, rmdir(tmpDir,'s'); catch, end
        return;
    end
    [~,~,e] = fileparts(f);
    if strcmpi(e,'.mat')
        S = load(f); if isfield(S,'maskBundle') && isstruct(S.maskBundle) && ~isempty(S.maskBundle), B = S.maskBundle; else, B = S; end
        searchFields = {'loadedMask','overlayMask','signalMask','mask','activeMask','brainMask','underlayMask','M'};
        M = [];
        for k = 1:numel(searchFields)
            fn = searchFields{k};
            if isfield(B,fn) && ~isempty(B.(fn)) && (isnumeric(B.(fn)) || islogical(B.(fn)))
                M = logical(B.(fn)); pickedField = fn; break;
            end
        end
        if isempty(M) && isfield(B,'brainImage') && ~isempty(B.brainImage), M = logical(B.brainImage > 0); pickedField = 'brainImage>0'; end
        if isempty(M), error('MAT mask file has no usable mask variable.'); end
        if isfield(B,'loadedMaskIsInclude') && ~isempty(B.loadedMaskIsInclude), maskIsInclude = logical(B.loadedMaskIsInclude);
        elseif isfield(B,'overlayMaskIsInclude') && ~isempty(B.overlayMaskIsInclude), maskIsInclude = logical(B.overlayMaskIsInclude);
        elseif isfield(B,'maskIsInclude') && ~isempty(B.maskIsInclude), maskIsInclude = logical(B.maskIsInclude); end
        return;
    end
    M = logical(niftiread(f)); pickedField = 'nifti';
end

    function T = force2DOutputSizeFromTargetUnderlay(T, Utarget)
    try
        if isempty(T) || ~isfield(T,'warpA') || isempty(T.warpA)
            return;
        end

        if ~isequal(size(double(T.warpA)), [3 3])
            return;
        end

        hasOut = isfield(T,'outSize') && ~isempty(T.outSize) && ...
            numel(T.outSize) >= 2 && all(isfinite(T.outSize(1:2))) && ...
            all(round(T.outSize(1:2)) > 0);

        if hasOut
            return;
        end

        if nargin >= 2 && ~isempty(Utarget)
            U = squeeze(Utarget);
            if ndims(U) >= 2
                T.outSize = [size(U,1) size(U,2)];
                T.outputSize = T.outSize;
            end
        end
    catch
    end
end


function T = askAndApply2DWarpDirection(T, dlgTitle)
    % Ask once whether to use saved affine matrix or its inverse.
    % For your current symptom, inverse is the first thing to test.

    try
                % Simple coronal 2D Reg2D files from registration_coronal_2d.m
        % are already saved as MATLAB affine2d source -> atlas matrices.
        % Do not ask saved/inverse and do not invert.
        if isfield(T,'type') && strcmpi(char(T.type), 'simple_coronal_2d')
            T.scmWarpDirection = 'as_saved';
            T.scmAffineChoice = 'row_saved';
            state.atlas2DWarpDirection = 'as_saved';
            return;
        end
        if isempty(T) || ~isfield(T,'warpA') || isempty(T.warpA)
            return;
        end

        A = double(T.warpA);

        if ~isequal(size(A), [3 3])
            return;
        end

        if nargin < 2 || isempty(dlgTitle)
            dlgTitle = '2D atlas transform direction';
        end

        if isfield(state,'atlas2DWarpDirection') && ...
                ~isempty(state.atlas2DWarpDirection) && ...
                ~strcmpi(state.atlas2DWarpDirection,'ask')

            T.scmWarpDirection = state.atlas2DWarpDirection;
            return;
        end

        msg = [ ...
            'Choose how SCM should apply the 2D affine transform.' newline newline ...
            'Use saved matrix:' newline ...
            '  Functional image is warped using T directly.' newline newline ...
            'Use inverse matrix:' newline ...
            '  Functional image is warped using inv(T).' newline ...
            '  Try this if histology appears in the right place but functional data does not align.' newline newline ...
            'Recommendation for your current problem: Use inverse matrix first.'];

        ch = questdlg(msg, dlgTitle, ...
            'Use saved matrix', 'Use inverse matrix', 'Cancel', ...
            'Use inverse matrix');

        if isempty(ch) || strcmpi(ch,'Cancel')
            error('Atlas warp cancelled.');
        end

        if strcmpi(ch,'Use inverse matrix')
            state.atlas2DWarpDirection = 'inverse';
        else
            state.atlas2DWarpDirection = 'as_saved';
        end

        T.scmWarpDirection = state.atlas2DWarpDirection;

    catch ME
        if strcmpi(ME.message,'Atlas warp cancelled.')
            rethrow(ME);
        end
        T.scmWarpDirection = 'as_saved';
    end
end


function regList = askAndApply2DWarpDirectionToRegList(regList, dlgTitle)
    if isempty(regList)
        return;
    end

    try
        T0 = regList(1).T;
        T0 = askAndApply2DWarpDirection(T0, dlgTitle);
        dirUse = T0.scmWarpDirection;

        for rr = 1:numel(regList)
            regList(rr).T.scmWarpDirection = dirUse;
        end
    catch ME
        rethrow(ME);
    end
end


    function Ause = apply2DWarpDirectionToMatrix(Araw, T)
    % Convert saved 2D transform to a MATLAB affine2d-compatible matrix.
    %
    % MATLAB affine2d requires translation in the LAST ROW:
    %   [a b 0
    %    c d 0
    %    tx ty 1]
    %
    % Many manual registration tools save column-vector matrices:
    %   [a b tx
    %    c d ty
    %    0 0 1]
    %
    % For those, MATLAB needs Araw'.

    Araw = double(Araw);
        % New Reg2D files save A directly in MATLAB affine2d row-vector format.
    % Use it directly.
    try
        if isfield(T,'scmAffineChoice') && strcmpi(char(T.scmAffineChoice), 'row_saved')
            if ~isValidMatlabAffine2D(Araw)
                error('Saved Reg2D.A is not a valid MATLAB affine2d row-vector matrix.');
            end
            Ause = Araw;
            return;
        end
    catch ME
        error(ME.message);
    end

    if ~isequal(size(Araw), [3 3])
        error('2D affine matrix must be 3x3.');
    end

    if any(~isfinite(Araw(:)))
        error('2D affine matrix contains NaN/Inf.');
    end

    cand = {};
    label = {};
    key = {};

    % Candidate 1: raw already valid for MATLAB affine2d.
    if isValidMatlabAffine2D(Araw)
        cand{end+1} = Araw; %#ok<AGROW>
        label{end+1} = 'saved matrix, MATLAB row-vector format'; %#ok<AGROW>
        key{end+1} = 'row_saved'; %#ok<AGROW>

        if abs(det(Araw(1:2,1:2))) > eps
            Ai = inv(Araw);
            if isValidMatlabAffine2D(Ai)
                cand{end+1} = Ai; %#ok<AGROW>
                label{end+1} = 'inverse saved matrix, MATLAB row-vector format'; %#ok<AGROW>
                key{end+1} = 'row_inverse'; %#ok<AGROW>
            end
        end
    end

    % Candidate 2: raw is column-vector style, transpose for affine2d.
    At = Araw.';
    if isValidMatlabAffine2D(At)
        cand{end+1} = At; %#ok<AGROW>
        label{end+1} = 'transpose saved matrix, column-vector source -> atlas'; %#ok<AGROW>
        key{end+1} = 'col_saved_transpose'; %#ok<AGROW>

        if abs(det(At(1:2,1:2))) > eps
            Ati = inv(At);
            if isValidMatlabAffine2D(Ati)
                cand{end+1} = Ati; %#ok<AGROW>
                label{end+1} = 'inverse transpose, column-vector atlas -> source'; %#ok<AGROW>
                key{end+1} = 'col_inverse_transpose'; %#ok<AGROW>
            end
        end
    end

    if isempty(cand)
        error(['No valid affine2d matrix could be made from saved A.' newline ...
               'This means A is not in a valid 2D affine format.']);
    end

    % Strong default:
    % If raw is invalid but transpose is valid, use transpose.
    useIdx = 1;
    if ~isValidMatlabAffine2D(Araw) && isValidMatlabAffine2D(At)
        hit = find(strcmp(key, 'col_saved_transpose'), 1);
        if ~isempty(hit), useIdx = hit; end
    end

    % Optional override stored in T.
    try
        if isfield(T,'scmAffineChoice') && ~isempty(T.scmAffineChoice)
            hit = find(strcmp(key, char(T.scmAffineChoice)), 1);
            if ~isempty(hit), useIdx = hit; end
        end
    catch
    end

    Ause = cand{useIdx};

    try
        fprintf('\n[SCM affine2d] Using %s\n', label{useIdx});
        fprintf('[SCM affine2d] Raw saved A:\n');
        disp(Araw);
        fprintf('[SCM affine2d] MATLAB affine2d Ause:\n');
        disp(Ause);
    catch
    end
end


function tf = isValidMatlabAffine2D(A)
    tf = false;
    try
        A = double(A);
        if ~isequal(size(A), [3 3]), return; end
        if any(~isfinite(A(:))), return; end

        % affine2d requires third column [0;0;1]
        tf = norm(A(:,3) - [0;0;1]) < 1e-8;
    catch
        tf = false;
    end
end
function T = extractAtlasWarpStruct(S)
    if isfield(S,'Transf') && isstruct(S.Transf)
        T = S.Transf;
    elseif isfield(S,'Reg2D') && isstruct(S.Reg2D)
        T = S.Reg2D;
    elseif isfield(S,'RegOut') && isstruct(S.RegOut)
        T = S.RegOut;
    elseif isfield(S,'Registration2D') && isstruct(S.Registration2D)
        T = S.Registration2D;
    else
        T = S;
    end
    if isfield(T,'A') && ~isempty(T.A), T.warpA = T.A;
    elseif isfield(T,'M') && ~isempty(T.M), T.warpA = T.M;
    elseif isfield(T,'T') && ~isempty(T.T), T.warpA = T.T;
    elseif isfield(T,'tform') && ~isempty(T.tform)
        try, T.warpA = T.tform.T; catch, error('Found tform field, but could not extract numeric matrix.'); end
    else
        error('Transform file has no usable matrix field. Expected A, M, T, or tform.T.');
    end
    if isfield(T,'outputSize') && ~isempty(T.outputSize), T.outSize = double(T.outputSize);
    elseif isfield(T,'size') && ~isempty(T.size), T.outSize = double(T.size);
    elseif isfield(T,'atlasSize') && ~isempty(T.atlasSize), T.outSize = double(T.atlasSize);
    elseif isfield(T,'outSize') && ~isempty(T.outSize), T.outSize = double(T.outSize);
    else, T.outSize = []; end
    if ~isfield(T,'type') || isempty(T.type), T.type = 'unknown'; end
    if ~isfield(T,'atlasSliceIndex') || isempty(T.atlasSliceIndex), T.atlasSliceIndex = NaN; end
    if ~isfield(T,'atlasMode') || isempty(T.atlasMode), T.atlasMode = ''; end
   % Do NOT rebuild simple_coronal_2d transforms here.
% registration_coronal_2d.m already saved a valid MATLAB affine2d matrix.
if isfield(T,'type') && strcmpi(char(T.type), 'simple_coronal_2d')
    if isfield(T,'A') && ~isempty(T.A)
        T.warpA = double(T.A);
    end

    if isfield(T,'outputSize') && ~isempty(T.outputSize)
        T.outSize = double(T.outputSize);
    end

    T.scmAffineChoice = 'row_saved';
end
end

function Y = warpFunctionalSeriesToAtlas(X, T)
    A = double(T.warpA);
    if ndims(X) == 4 && isequal(size(A), [4 4])
        if isempty(T.outSize) || numel(T.outSize) < 3, error('3D atlas warp requires output size.'); end
        outSize3 = round(T.outSize(1:3)); if any(outSize3 < 1), error('Invalid 3D output size.'); end
        Y=fusiWarpAtlasForDisplay(X,T);
        state.currentROIMapping=struct('kind','3DDirect','transform',T);
        return;
    end
    if isequal(size(A), [3 3])
    if isempty(T.outSize) || numel(T.outSize) < 2
        error('2D atlas warp requires output size.');
    end

    outSize2 = round(double(T.outSize(1:2)));
    if any(outSize2 < 1)
        error('Invalid 2D output size.');
    end

    Ause = apply2DWarpDirectionToMatrix(A, T);
    nativeShape=[size(X,1) size(X,2)];transposed=isfield(T,'sourceSize')&&isequal(nativeShape,fliplr(double(T.sourceSize(1:2))))&&~isequal(nativeShape,double(T.sourceSize(1:2)));
    sourceSlice=1;if ndims(X)==4
        sourceSlice=state.z;if isfield(T,'sourceSliceIndex'),sourceSlice=T.sourceSliceIndex;elseif isfield(T,'sourceSlice'),sourceSlice=T.sourceSlice;end
        sourceSlice=max(1,min(size(X,3),round(sourceSlice)));
    end
    state.currentROIMapping=struct('kind','2D','matrices',{{Ause}},'sourceSlices',sourceSlice,'transpose',transposed);
    tform2 = affine2d(Ause);
    Rout2 = imref2d(outSize2);

    if ndims(X) == 3
        X2 = X;
        zSel = 1;

        X2 = prepareFunctionalSliceForReg2D(X2, T, zSel);

        nTT = size(X2,3);
        Y = zeros([outSize2 nTT], 'single');

        for tt = 1:nTT
            Y(:,:,tt) = imwarp(single(X2(:,:,tt)), ...
                tform2, 'linear', 'OutputView', Rout2);
        end
        return;

    elseif ndims(X) == 4
        if isfield(T,'sourceSliceIndex') && ~isempty(T.sourceSliceIndex) && isfinite(T.sourceSliceIndex)
            zSel = round(T.sourceSliceIndex);
        elseif isfield(T,'sourceSlice') && ~isempty(T.sourceSlice) && isfinite(T.sourceSlice)
            zSel = round(T.sourceSlice);
        else
            zSel = state.z;
        end

        zSel = max(1,min(size(X,3),zSel));
        X2 = squeeze(X(:,:,zSel,:));

        X2 = prepareFunctionalSliceForReg2D(X2, T, zSel);

        nTT = size(X2,3);
        Y = zeros([outSize2 nTT], 'single');

        for tt = 1:nTT
            Y(:,:,tt) = imwarp(single(X2(:,:,tt)), ...
                tform2, 'linear', 'OutputView', Rout2);
        end

        try
            set(info1,'String',sprintf( ...
                'Applied 2D atlas warp: source slice %d -> atlas slice %d | output [%d %d]', ...
                zSel, round(T.atlasSliceIndex), outSize2(1), outSize2(2)));
        catch
        end

        return;
    else
        error('For 2D atlas warp, PSC must be [Y X T] or [Y X Z T].');
    end
end
    error('Unsupported transform matrix size: %dx%d', size(A,1), size(A,2));
end

function [Y, report] = warpFunctionalSeriesToAtlasStepMotor(X, regList)

    Y = [];

    report = struct();
    report.nUsed = 0;
    report.sourceIdx = [];
    report.atlasIdx = [];
    report.files = {};
    report.outSize = [];

    if isempty(regList)
        return;
    end

    if ndims(X) == 3
        nSrc = 1;
        nTT = size(X,3);
    elseif ndims(X) == 4
        nSrc = size(X,3);
        nTT = size(X,4);
    else
        error('Step Motor atlas warp requires PSC [Y X T] or [Y X Z T].');
    end

    srcIdxAll = [regList.sourceIdx];
    valid = find(isfinite(srcIdxAll) & srcIdxAll >= 1 & srcIdxAll <= nSrc);

    if isempty(valid)
        error('No transform source index matches the available functional slices.');
    end

    regList = regList(valid);
    srcIdxAll = [regList.sourceIdx];

    [~,ord] = sort(srcIdxAll);
    regList = regList(ord);

    % Remove duplicate source indices, keeping the first/best candidate.
    srcSorted = [regList.sourceIdx];
    [~,ia] = unique(srcSorted, 'stable');
    regList = regList(ia);

    % Validate first transform.
    T0 = regList(1).T;
    A0 = double(T0.warpA);

    if ~isequal(size(A0), [3 3])
        error('Step Motor folder warp currently expects 2D affine transforms with 3x3 matrices.');
    end

    if ~isfield(T0,'outSize') || isempty(T0.outSize) || numel(T0.outSize) < 2
        error('First Step Motor transform has no valid outputSize/outSize.');
    end

    outSize2 = round(double(T0.outSize(1:2)));

    if any(outSize2 < 1)
        error('Invalid atlas output size in first Step Motor transform.');
    end

    nUse = numel(regList);
    Y = zeros([outSize2 nUse nTT], 'single');

    for rr = 1:nUse

        T = regList(rr).T;
        A = double(T.warpA);

        if ~isequal(size(A), [3 3])
            error('Transform for source %d is not a 2D 3x3 transform.', regList(rr).sourceIdx);
        end

        if ~isfield(T,'outSize') || isempty(T.outSize) || numel(T.outSize) < 2
            error('Transform for source %d has no valid output size.', regList(rr).sourceIdx);
        end

        thisOut = round(double(T.outSize(1:2)));

        if any(thisOut ~= outSize2)
            error(['All Step Motor transforms must have the same atlas output size.' newline ...
                   'First output size: [%d %d]' newline ...
                   'Source %d output size: [%d %d]'], ...
                   outSize2(1), outSize2(2), regList(rr).sourceIdx, thisOut(1), thisOut(2));
        end

        zSrc = regList(rr).sourceIdx;
A = apply2DWarpDirectionToMatrix(A, T);
        tform2 = affine2d(A);
        Rout2 = imref2d(outSize2);

      if ndims(X) == 3
    X2 = X;
else
    X2 = squeeze(X(:,:,zSrc,:));
end

X2 = prepareFunctionalSliceForReg2D(X2, T, zSrc);

for tt = 1:nTT
    Y(:,:,rr,tt) = imwarp(single(X2(:,:,tt)), ...
        tform2, 'linear', 'OutputView', Rout2);
end
    end

    report.nUsed = nUse;
    report.outSize = outSize2;
    report.sourceIdx = [regList.sourceIdx];

    report.atlasIdx = nan(1,nUse);
    report.files = cell(1,nUse);

    for rr = 1:nUse
    report.files{rr} = regList(rr).file;

    try
        if isfield(regList(rr).T,'atlasSliceIndex') && ...
                ~isempty(regList(rr).T.atlasSliceIndex) && ...
                isfinite(regList(rr).T.atlasSliceIndex)
            report.atlasIdx(rr) = round(regList(rr).T.atlasSliceIndex);
        end
    catch
    end
end

report.usedRegList = regList;
matrices=cell(1,nUse);transposed=false(1,nUse);
for rr=1:nUse
 T=regList(rr).T;matrices{rr}=apply2DWarpDirectionToMatrix(double(T.warpA),T);
 if isfield(T,'sourceSize')&&numel(T.sourceSize)>=2
  nativeShape=size(X,[1 2]);sourceShape=double(T.sourceSize(1:2));
  transposed(rr)=isequal(nativeShape,fliplr(sourceShape))&&~isequal(nativeShape,sourceShape);
 end
end
state.currentROIMapping=struct('kind','2D','matrices',{matrices},'sourceSlices',report.sourceIdx,'transpose',transposed);
end


function regList = collectStepMotorRegistration2DTransforms(folderPath)

    regList = struct('sourceIdx',{},'file',{},'T',{},'score',{});

    if isempty(folderPath) || exist(folderPath,'dir') ~= 7
        return;
    end

    files = listMatFilesRecursive(folderPath, 4);

    if isempty(files)
        return;
    end

    cand = struct('sourceIdx',{},'file',{},'T',{},'score',{});

    for ii = 1:numel(files)

        f = files{ii};
        [~,nameOnly,extOnly] = fileparts(f);
        nameL = lower(nameOnly);

        if ~strcmpi(extOnly,'.mat')
            continue;
        end

        % The StepMotor session file is only an index.
        % It is NOT a transform file and must not be used by SCM.
        if ~isempty(strfind(nameL,'stepmotor_reg2d_session')) %#ok<STREMP>
            continue;
        end

        % For step-motor SCM, only use per-source-slice transform files.
        if isempty(strfind(nameL,'coronalregistration2d_source')) %#ok<STREMP>
            continue;
        end
        try
            S = load(f);
            T = extractAtlasWarpStruct(S);
        catch
            continue;
        end

        if ~isfield(T,'warpA') || isempty(T.warpA)
            continue;
        end

        A = double(T.warpA);

        % For this Step Motor workflow, keep 2D coronal transforms only.
        if ~isequal(size(A), [3 3])
            continue;
        end

        if ~isfield(T,'outSize') || isempty(T.outSize) || numel(T.outSize) < 2
            continue;
        end

        srcIdx = parseStepMotorSourceIndex(f, T);

        if ~isfinite(srcIdx) || srcIdx < 1
            continue;
        end

        srcIdx = round(srcIdx);

        score = scoreStepMotorTransformFile(f, T);

        c = struct();
        c.sourceIdx = srcIdx;
        c.file = f;
        c.T = T;
        c.score = score;

        cand(end+1) = c; %#ok<AGROW>
    end

    if isempty(cand)
        return;
    end

    srcAll = [cand.sourceIdx];
    srcUni = unique(srcAll);

    for ss = 1:numel(srcUni)
        idx = find(srcAll == srcUni(ss));

        scores = [cand(idx).score];
        [~,bestLocal] = max(scores);

        regList(end+1) = cand(idx(bestLocal)); %#ok<AGROW>
    end

    [~,ord] = sort([regList.sourceIdx]);
    regList = regList(ord);
end


function files = listMatFilesRecursive(rootDir, maxDepth)

    files = {};

    if nargin < 2 || isempty(maxDepth)
        maxDepth = 4;
    end

    walkDir(rootDir, 0);

    function walkDir(d, depth)

        if depth > maxDepth || exist(d,'dir') ~= 7
            return;
        end

        dd = dir(fullfile(d,'*.mat'));

        for kk = 1:numel(dd)
            if ~dd(kk).isdir
                files{end+1} = fullfile(dd(kk).folder, dd(kk).name); %#ok<AGROW>
            end
        end

        sub = dir(d);

        for kk = 1:numel(sub)

            if ~sub(kk).isdir
                continue;
            end

            nm = sub(kk).name;

            if strcmp(nm,'.') || strcmp(nm,'..')
                continue;
            end

            if strcmpi(nm,'private') || strcmpi(nm,'@')
                continue;
            end

            walkDir(fullfile(d,nm), depth + 1);
        end
    end
end


function idx = parseStepMotorSourceIndex(f, T)

    idx = NaN;

    try
        [~,nameOnly,~] = fileparts(f);
        s = lower(nameOnly);

        patterns = { ...
            'source[_\- ]*0*(\d+)', ...
            'src[_\- ]*0*(\d+)', ...
            'slice[_\- ]*0*(\d+)', ...
            'sl[_\- ]*0*(\d+)', ...
            'z[_\- ]*0*(\d+)'};

        for pp = 1:numel(patterns)
            tok = regexp(s, patterns{pp}, 'tokens', 'once');

            if ~isempty(tok)
                idx = str2double(tok{1});

                if isfinite(idx)
                    return;
                end
            end
        end
    catch
    end

    try
        if isfield(T,'sourceSliceIndex') && ~isempty(T.sourceSliceIndex) && isfinite(T.sourceSliceIndex)
            idx = double(T.sourceSliceIndex);
            return;
        end
    catch
    end

    try
        if isfield(T,'sourceSlice') && ~isempty(T.sourceSlice) && isfinite(T.sourceSlice)
            idx = double(T.sourceSlice);
            return;
        end
    catch
    end

    try
        if isfield(T,'sourceIndex') && ~isempty(T.sourceIndex) && isfinite(T.sourceIndex)
            idx = double(T.sourceIndex);
            return;
        end
    catch
    end
end


function score = scoreStepMotorTransformFile(f, T)

    score = 0;

    try
        [folder0,name0,~] = fileparts(f);
        s = lower([folder0 filesep name0]);

        if ~isempty(strfind(s,'coronalregistration2d')), score = score + 120; end
        if ~isempty(strfind(s,'registration2d')),        score = score + 100; end
        if ~isempty(strfind(s,'transformation')),         score = score + 70;  end
        if ~isempty(strfind(s,'source')),                 score = score + 50;  end
        if ~isempty(strfind(s,'slice')),                  score = score + 40;  end
        if ~isempty(strfind(s,'atlas')),                  score = score + 20;  end
        if ~isempty(strfind(s,'histology')),              score = score + 15;  end
        if ~isempty(strfind(s,'vascular')),               score = score + 15;  end
        if ~isempty(strfind(s,'regions')),                score = score + 15;  end
    catch
    end

    try
        if isfield(T,'atlasSliceIndex') && ~isempty(T.atlasSliceIndex) && isfinite(T.atlasSliceIndex)
            score = score + 20;
        end
    catch
    end

    try
        dd = dir(f);

        % Small files are often pure transform MAT files.
        if ~isempty(dd) && dd.bytes > 0 && dd.bytes < 300000
            score = score + 10;
        end
    catch
    end
end


function startPath = getStepMotorTransformStartPath()

    startPath = getTransformStartPath();

    % If Step Motor underlay files were passed from fusi_studio,
    % start close to those selected per-slice files.
    try
        if isstruct(par) && isfield(par,'scmPerSliceUnderlayFiles') && ...
                ~isempty(par.scmPerSliceUnderlayFiles)

            f0 = par.scmPerSliceUnderlayFiles{1};

            if exist(f0,'file') == 2
                startPath = fileparts(f0);
                return;
            elseif exist(f0,'dir') == 7
                startPath = f0;
                return;
            end
        end
    catch
    end

    % Otherwise use the normal Registration2D start path.
    try
        p0 = getTransformStartPath();

        if exist(p0,'dir') == 7
            startPath = p0;
        end
    catch
    end
end


function tf = underlayMatchesTargetDims(U, yy, xx, zz)

    tf = false;

    try
        if isempty(U)
            return;
        end

        U = squeeze(U);

        % ---------------------------------------------------------
        % 2D underlay can only match a single-slice display.
        % Do NOT allow one 2D atlas image to count as a full
        % Step Motor Z-stack.
        % ---------------------------------------------------------
        if ndims(U) == 2
            tf = (zz == 1 && size(U,1) == yy && size(U,2) == xx);
            return;
        end

        % ---------------------------------------------------------
        % 3D underlay ambiguity:
        %
        % [Y X 3] can mean either:
        %   A) RGB image
        %   B) 3 grayscale slices
        %
        % For Step Motor nZ == 3, this ambiguity is dangerous.
        % Use state.isColorUnderlay to decide.
        % ---------------------------------------------------------
        if ndims(U) == 3

            if size(U,1) ~= yy || size(U,2) ~= xx
                return;
            end

            if size(U,3) == 3
                if zz == 1 && state.isColorUnderlay
                    % true RGB single-slice underlay
                    tf = true;
                    return;
                elseif zz == 3 && ~state.isColorUnderlay
                    % true 3-slice grayscale stack
                    tf = true;
                    return;
                else
                    % Do not treat RGB as Step Motor stack.
                    tf = false;
                    return;
                end
            end

            % Normal grayscale multi-slice stack.
            tf = (size(U,3) == zz);
            return;
        end

        % ---------------------------------------------------------
        % 4D RGB stack: [Y X 3 Z]
        % This is a true color stack only if Z matches.
        % ---------------------------------------------------------
        if ndims(U) == 4
            tf = (size(U,1) == yy && ...
                  size(U,2) == xx && ...
                  size(U,3) == 3  && ...
                  size(U,4) == zz);
            return;
        end

    catch
        tf = false;
    end
end

function s = compactIndexList(v)

    if isempty(v)
        s = '<none>';
        return;
    end

    v = unique(sort(round(v(:).')));

    parts = {};
    i = 1;

    while i <= numel(v)
        j = i;

        while j < numel(v) && v(j+1) == v(j) + 1
            j = j + 1;
        end

        if i == j
            parts{end+1} = sprintf('%d', v(i)); %#ok<AGROW>
        else
            parts{end+1} = sprintf('%d-%d', v(i), v(j)); %#ok<AGROW>
        end

        i = j + 1;
    end

    s = strjoin(parts, ', ');
end


function setTitleAtlasStepMotor(report)

    try
        srcTxt = compactIndexList(report.sourceIdx);

        atlasTxt = '';

        if isfield(report,'atlasIdx') && ~isempty(report.atlasIdx)
            a = report.atlasIdx;
            a = a(isfinite(a));

            if ~isempty(a)
                atlasTxt = sprintf(' | atlas slices %s', compactIndexList(a));
            end
        end

        set(txtTitle, 'String', sprintf('%s | Step Motor atlas warp | source %s%s', ...
            fileLabel, srcTxt, atlasTxt));

    catch
        set(txtTitle, 'String', sprintf('%s | Step Motor atlas warp', fileLabel));
    end
end


   





function Uplane = acceptAtlasUnderlayCandidate(v, T, outSize2)

    Uplane = [];

    if isempty(v)
        return;
    end

    % Struct wrapper.
    if isstruct(v)
        subPref = {'Data','data','img','image','I','underlay','atlasUnderlay','brainImage','histology','vascular'};

        for ss = 1:numel(subPref)
            if isfield(v, subPref{ss})
                Uplane = acceptAtlasUnderlayCandidate(v.(subPref{ss}), T, outSize2);
                if ~isempty(Uplane)
                    return;
                end
            end
        end
        return;
    end

    if ~(isnumeric(v) || islogical(v))
        return;
    end

    U = squeeze(double(v));

    if isempty(U) || ndims(U) < 2
        return;
    end

    % Reject tiny transform matrices such as 3x3 or 4x4.
    if size(U,1) < 16 || size(U,2) < 16
        return;
    end

    % Atlas underlay must already match transform output size.
    % This prevents accidentally using native/source images here.
    if size(U,1) ~= outSize2(1) || size(U,2) ~= outSize2(2)
        return;
    end

    if ndims(U) == 2
        Uplane = U;
        return;
    end

    if ndims(U) == 3

        % RGB single atlas/histology plane.
        if size(U,3) == 3
            Uplane = rgbToGrayLocal(U);
            return;
        end

        % Atlas volume: choose atlasSliceIndex if available.
        zPick = round(size(U,3) / 2);

        try
            if isfield(T,'atlasSliceIndex') && ~isempty(T.atlasSliceIndex) && isfinite(T.atlasSliceIndex)
                zPick = round(T.atlasSliceIndex);
            end
        catch
        end

        zPick = max(1, min(size(U,3), zPick));
        Uplane = U(:,:,zPick);
        return;
    end

    if ndims(U) == 4

        % RGB stack: [Y X 3 Z]
        if size(U,3) == 3
            zPick = 1;

            try
                if isfield(T,'atlasSliceIndex') && ~isempty(T.atlasSliceIndex) && isfinite(T.atlasSliceIndex)
                    zPick = round(T.atlasSliceIndex);
                end
            catch
            end

            zPick = max(1, min(size(U,4), zPick));
            RGB = squeeze(U(:,:,:,zPick));
            Uplane = rgbToGrayLocal(RGB);
            return;
        end

        % RGB stack: [Y X Z 3]
        if size(U,4) == 3
            zPick = round(size(U,3) / 2);

            try
                if isfield(T,'atlasSliceIndex') && ~isempty(T.atlasSliceIndex) && isfinite(T.atlasSliceIndex)
                    zPick = round(T.atlasSliceIndex);
                end
            catch
            end

            zPick = max(1, min(size(U,3), zPick));
            RGB = squeeze(U(:,:,zPick,:));
            Uplane = rgbToGrayLocal(RGB);
            return;
        end
    end
end

function G = rgbToGrayLocal(RGB)

    RGB = double(RGB);

    if ndims(RGB) ~= 3 || size(RGB,3) ~= 3
        G = double(RGB);
        return;
    end

    G = 0.2989 .* RGB(:,:,1) + ...
        0.5870 .* RGB(:,:,2) + ...
        0.1140 .* RGB(:,:,3);
end


function U2 = fitPlaneToSizeLocal(U2, yy, xx)

    U2 = squeeze(double(U2));

    if ndims(U2) > 2
        U2 = U2(:,:,1);
    end

    if size(U2,1) == yy && size(U2,2) == xx
        return;
    end

    try
        U2 = imresize(U2, [yy xx], 'bilinear');
    catch
        tmp = zeros(yy, xx);
        y0 = min(yy, size(U2,1));
        x0 = min(xx, size(U2,2));
        tmp(1:y0,1:x0) = U2(1:y0,1:x0);
        U2 = tmp;
    end
end




function Uplane = acceptFixedAtlasCandidate(v, T, outSize2)
    Uplane = [];

    if isempty(v)
        return;
    end

    if isstruct(v)
        subPref = { ...
            'fixedImage', ...
            'targetImage', ...
            'atlasImage', ...
            'atlasUnderlay', ...
            'histologyImage', ...
            'vascularImage', ...
            'regionsImage', ...
            'Data', ...
            'image', ...
            'img'};

        for ss = 1:numel(subPref)
            if isfield(v, subPref{ss})
                Uplane = acceptFixedAtlasCandidate(v.(subPref{ss}), T, outSize2);
                if ~isempty(Uplane)
                    return;
                end
            end
        end
        return;
    end

    if ~(isnumeric(v) || islogical(v))
        return;
    end

    U = squeeze(double(v));

    if isempty(U) || ndims(U) < 2
        return;
    end

    if size(U,1) < 16 || size(U,2) < 16
        return;
    end

    % Fixed target must already match atlas output canvas.
    if size(U,1) ~= outSize2(1) || size(U,2) ~= outSize2(2)
        return;
    end

    if ndims(U) == 2
        Uplane = U;
        return;
    end

    if ndims(U) == 3
        if size(U,3) == 3
            Uplane = rgbToGrayLocal(U);
            return;
        end

        zPick = round(size(U,3) / 2);

        try
            if isfield(T,'atlasSliceIndex') && ~isempty(T.atlasSliceIndex) && isfinite(T.atlasSliceIndex)
                zPick = round(T.atlasSliceIndex);
            end
        catch
        end

        zPick = max(1, min(size(U,3), zPick));
        Uplane = U(:,:,zPick);
        return;
    end

    if ndims(U) == 4
        if size(U,3) == 3
            zPick = 1;

            try
                if isfield(T,'atlasSliceIndex') && ~isempty(T.atlasSliceIndex) && isfinite(T.atlasSliceIndex)
                    zPick = round(T.atlasSliceIndex);
                end
            catch
            end

            zPick = max(1, min(size(U,4), zPick));
            Uplane = rgbToGrayLocal(squeeze(U(:,:,:,zPick)));
            return;
        end
    end
end




function X2 = prepareFunctionalSliceForReg2D(X2, T, zSrc)
    % Ensure functional slice matches the source image used during registration.
    % Your metadata says sourceSize = [267 256].
    % If PSC slice is [256 267], SCM is using transposed orientation.

    if ndims(X2) == 2
        X2 = reshape(X2, size(X2,1), size(X2,2), 1);
    end

    if ~isfield(T,'sourceSize') || isempty(T.sourceSize) || numel(T.sourceSize) < 2
        return;
    end

    srcSize = round(double(T.sourceSize(1:2)));
    thisSize = [size(X2,1) size(X2,2)];

    if isequal(thisSize, srcSize)
        return;
    end

    if isequal(thisSize, fliplr(srcSize))
        choice = questdlg(sprintf([ ...
            'Functional source slice %d has size [%d %d], but the transform was made for [%d %d].\n\n' ...
            'This means X/Y are probably transposed between PSC and the registration source image.\n\n' ...
            'Transpose functional frames before warping?'], ...
            zSrc, thisSize(1), thisSize(2), srcSize(1), srcSize(2)), ...
            'SCM source-size mismatch', ...
            'Transpose frames', 'Cancel', 'Transpose frames');

        if isempty(choice) || strcmpi(choice,'Cancel')
            error('Atlas warp cancelled because PSC size does not match transform sourceSize.');
        end

        X2 = permute(X2, [2 1 3]);
        return;
    end

    error(['Functional source slice %d has size [%d %d], but transform sourceSize is [%d %d].' newline ...
           'Do not resize here. The registration was made on a different source image.' newline ...
           'Register the exact SCM/PSC native underlay or fix the MaskEditor source dimensions.'], ...
           zSrc, thisSize(1), thisSize(2), srcSize(1), srcSize(2));
end




function tf = hasUsableUnderlaySignal(U)

    tf = false;

    try
        if isempty(U)
            return;
        end

        v = double(U(:));
        v = v(isfinite(v));

        if isempty(v)
            return;
        end

        lo = prctile_fallback(v, 1);
        hi = prctile_fallback(v, 99);

        tf = isfinite(lo) && isfinite(hi) && hi > lo && abs(hi - lo) > eps;
    catch
        tf = false;
    end
end


function U = makeFunctionalContrastFallbackUnderlay(X)

    X = double(X);
    X(~isfinite(X)) = 0;

    if ndims(X) == 4
        % Y x X x Z x T -> use temporal variability as pseudo-underlay.
        U = std(X, 0, 4);

        if ~hasUsableUnderlaySignal(U)
            U = mean(abs(X), 4);
        end

    elseif ndims(X) == 3
        % Y x X x T -> use temporal variability.
        U = std(X, 0, 3);

        if ~hasUsableUnderlaySignal(U)
            U = mean(abs(X), 3);
        end

    else
        U = X;
    end

    U(~isfinite(U)) = 0;
end

function Uout = warpUnderlayForCurrentDisplay(Uin, T)
    A = double(T.warpA);
    if isequal(size(A), [3 3])
        if isempty(T.outSize) || numel(T.outSize) < 2, error('2D underlay warp requires output size.'); end
        outSize2 = round(T.outSize(1:2)); tform2 = affine2d(A); Rout2 = imref2d(outSize2);
        if ndims(Uin) == 2
            Uout = imwarp(single(Uin), tform2, 'linear', 'OutputView', Rout2);
        elseif ndims(Uin) == 3
            if size(Uin,3) == 3 && state.isColorUnderlay
                Uout = zeros([outSize2 3], 'single');
                for kk = 1:3, Uout(:,:,kk) = imwarp(single(Uin(:,:,kk)), tform2, 'linear', 'OutputView', Rout2); end
            else
                n3 = size(Uin,3); Uout = zeros([outSize2 n3], 'single');
                for kk = 1:n3, Uout(:,:,kk) = imwarp(single(Uin(:,:,kk)), tform2, 'linear', 'OutputView', Rout2); end
            end
        else
            error('Unsupported underlay dimensionality for 2D warp.');
        end
        return;
    end
    if isequal(size(A), [4 4])
        if isempty(T.outSize) || numel(T.outSize) < 3, error('3D underlay warp requires output size.'); end
        outSize3 = round(T.outSize(1:3)); tform3 = affine3d(A); Rout3 = imref3d(outSize3);
        if ndims(Uin) == 3
            Uout = imwarp(single(Uin), tform3, 'linear', 'OutputView', Rout3);
        elseif ndims(Uin) == 4
            n4 = size(Uin,4); Uout = zeros([outSize3 n4], 'single');
            for kk = 1:n4, Uout(:,:,:,kk) = imwarp(single(Uin(:,:,:,kk)), tform3, 'linear', 'OutputView', Rout3); end
        else
            error('Unsupported underlay dimensionality for 3D warp.');
        end
        return;
    end
    error('Unsupported transform matrix size for underlay warp: %dx%d', size(A,1), size(A,2));
end

function tf = doesUnderlayMatchCurrentDisplay(U)
    tf = false;
    try, U = squeeze(U); tf = (size(U,1) == nY && size(U,2) == nX); catch, tf = false; end
end

function tf = doesUnderlayMatchOriginalDisplay(U)
    tf = false;
    try, U = squeeze(U); tf = (size(U,1) == size(origPSC,1) && size(U,2) == size(origPSC,2)); catch, tf = false; end
end

function tf = doesUnderlayMatchTransformOutput(U, T)
    tf = false;
    try
        U = squeeze(U); if isempty(T) || ~isfield(T,'outSize') || isempty(T.outSize), return; end
        outSize = round(double(T.outSize)); if numel(outSize) < 2, return; end
        tf = (size(U,1) == outSize(1) && size(U,2) == outSize(2));
    catch, tf = false; end
end

function tfFile = getBestTransformForUnderlay(underlayFile, Ucandidate)
    if nargin < 2, Ucandidate = []; end
    tfFile = ''; candFiles = {}; candScore = []; candDirs = {};
    try, if isfield(state,'atlasTransformFile') && ~isempty(state.atlasTransformFile), addFileCandidate(char(state.atlasTransformFile),300); end, catch, end
    try, if isfield(state,'lastAtlasTransformFile') && ~isempty(state.lastAtlasTransformFile), addFileCandidate(char(state.lastAtlasTransformFile),250); end, catch, end
    try
        if nargin >= 1 && ~isempty(underlayFile)
            udir = fileparts(char(underlayFile)); p1 = fileparts(udir); p2 = fileparts(p1);
            addDirCandidate(udir); addDirCandidate(fullfile(udir,'Registration2D')); addDirCandidate(fullfile(udir,'Registration'));
            addDirCandidate(fullfile(p1,'Registration2D')); addDirCandidate(fullfile(p1,'Registration')); addDirCandidate(p1);
            addDirCandidate(fullfile(p2,'Registration2D')); addDirCandidate(fullfile(p2,'Registration')); addDirCandidate(p2);
        end
    catch
    end
    try
        ep = getDatasetRootForSelectors();
        addDirCandidate(fullfile(ep,'Registration2D')); addDirCandidate(fullfile(ep,'Registration')); addDirCandidate(ep);
        p1 = fileparts(ep); addDirCandidate(fullfile(p1,'Registration2D')); addDirCandidate(fullfile(p1,'Registration')); addDirCandidate(p1);
    catch
    end
    exactNames = {'CoronalRegistration2D.mat','Transformation.mat'};
    wildNames = {'CoronalRegistration2D*.mat','*CoronalRegistration2D*.mat','*Registration2D*.mat','Transformation*.mat','*Transformation*.mat','*source*_atlas*.mat','*histology*.mat','*atlas*.mat'};
    for ii = 1:numel(candDirs)
        d0 = candDirs{ii}; if isempty(d0) || exist(d0,'dir') ~= 7, continue; end
        for kk = 1:numel(exactNames), addFileCandidate(fullfile(d0, exactNames{kk}),120); end
        for kk = 1:numel(wildNames)
            dd = dir(fullfile(d0, wildNames{kk}));
            for jj = 1:numel(dd), if ~dd(jj).isdir, addFileCandidate(fullfile(dd(jj).folder,dd(jj).name),60); end, end
        end
    end
    if isempty(candFiles), return; end
    [candFiles, ia] = uniquePathList(candFiles); candScore = candScore(ia);
    bestScore = -Inf; bestFile = '';
    for ii = 1:numel(candFiles)
        [ok, extraScore] = scoreTransformCandidate(candFiles{ii}, Ucandidate);
        if ~ok, continue; end
        totalScore = candScore(ii) + extraScore;
        if totalScore > bestScore, bestScore = totalScore; bestFile = candFiles{ii}; end
    end
    if ~isempty(bestFile)
        tfFile = bestFile;
        try, set(info1,'String',['Auto-detected transform: ' shortenPath(tfFile,85)],'TooltipString',tfFile); catch, end
    end

    function addDirCandidate(d)
        try, if ~isempty(d) && exist(char(d),'dir') == 7, candDirs{end+1} = char(d); end, catch, end %#ok<AGROW>
    end
    function addFileCandidate(f, baseScore)
        try, if ~isempty(f) && exist(char(f),'file') == 2, candFiles{end+1} = char(f); candScore(end+1) = baseScore; end, catch, end %#ok<AGROW>
    end
    function [ok, score] = scoreTransformCandidate(f, Ucand)
        ok = false; score = -Inf;
        try, S = load(f); T = extractAtlasWarpStruct(S); catch, return; end
        if ~isfield(T,'warpA') || isempty(T.warpA), return; end
        A = double(T.warpA); if ~(isequal(size(A),[3 3]) || isequal(size(A),[4 4])), return; end
        ok = true; score = 0; [folder0,name0,~] = fileparts(f); nameL = lower(name0); folderL = lower(folder0);
        if ~isempty(strfind(nameL,'coronalregistration2d')), score = score + 100; end %#ok<STREMP>
        if ~isempty(strfind(nameL,'registration2d')), score = score + 80; end %#ok<STREMP>
        if ~isempty(strfind(nameL,'transformation')), score = score + 60; end %#ok<STREMP>
        if ~isempty(strfind(nameL,'source')), score = score + 20; end %#ok<STREMP>
        if ~isempty(strfind(nameL,'atlas')), score = score + 20; end %#ok<STREMP>
        if ~isempty(strfind(nameL,'histology')), score = score + 25; end %#ok<STREMP>
        if ~isempty(strfind(folderL,'registration2d')) && isequal(size(A),[3 3]), score = score + 80; end %#ok<STREMP>
        if ~isempty(Ucand)
            if doesUnderlayMatchTransformOutput(Ucand,T), score = score + 600; else, score = score - 200; end
        end
        try, dd = dir(f); if ~isempty(dd) && dd.bytes > 0 && dd.bytes < 200000, score = score + 10; end, catch, end
    end
    function [u, ia] = uniquePathList(c)
        keys = cell(size(c));
        for qq = 1:numel(c)
            try, keys{qq} = char(java.io.File(c{qq}).getCanonicalPath()); catch, keys{qq} = char(c{qq}); end
            keys{qq} = strrep(keys{qq}, '/', filesep); keys{qq} = strrep(keys{qq}, '\\', filesep);
            if ispc, keys{qq} = lower(keys{qq}); end
        end
        [~,ia] = unique(keys,'stable'); u = c(ia);
    end
end

%% ==========================================================
% GENERIC HELPERS
%% ==========================================================
function tf = isPointerOverImageAxis()
    tf = false;
    try
        h = hittest(fig); if isempty(h), return; end
        axHit = ancestor(h, 'axes'); tf = ~isempty(axHit) && axHit == ax;
    catch
        try, tf = isequal(gca, ax); catch, tf = false; end
    end
end

function analysedRoot = guessAnalysedRoot(p0)
    p0 = fusiAnalysisOutputPath(p0);
    if exist(p0,'dir') ~= 7
        try, p0 = fileparts(p0); catch, end
    end
    if containsCompat(p0,'AnalysedData'), analysedRoot = p0; return; end
    if containsCompat(p0,'RawData')
        analysedRoot = strrep(p0,'RawData','AnalysedData');
        if exist(analysedRoot,'dir') ~= 7, try, mkdir(analysedRoot); catch, end, end
        return;
    end
    parent = fileparts(p0); sib = fullfile(parent,'AnalysedData');
    if exist(sib,'dir') == 7, analysedRoot = sib; return; end
    analysedRoot = p0;
end

function tf = containsCompat(s, pat)
    try, tf = contains(s, pat); catch, tf = ~isempty(strfind(s, pat)); end %#ok<STREMP>
end

function P = getSimpleExportPaths()
    root = getDatasetRootForSelectors();
    root = guessAnalysedRoot(root);
    P = struct();
    P.root = root;
    P.roiDir = fullfile(root,'ROI');
    P.scmRootDir = fullfile(root,'SCM');
    P.scmImageDir = fullfile(P.scmRootDir,'Images');
    P.scmSeriesDir = fullfile(P.scmRootDir,'Series');
    P.scmTcDir = fullfile(P.scmRootDir,'Timecourse');
    P.fileStem = sanitizeName(getAnimalID(fileLabel)); if isempty(P.fileStem), P.fileStem = 'SCM'; end
end

function Pexp = getGroupBundleExportPathsLocal()
    % Clean SCM GroupAnalysis export location.
    % Important for step-motor data: do NOT save bundles deep inside the
    % current scan/split-motor folder. Instead, save centrally under:
    %   <Project>\AnalysedData\GroupAnalysis\Bundles\SCM\<subjectKey>
    base = getDatasetRootForSelectors();
    analysedRoot = getCentralAnalysedRootForGroupBundlesLocal(base);
    meta = deriveGroupBundleMetaLocal();

    % TARGETED_SCM_LOCAL_BUNDLE_COPY_20260622
    % In addition to the central GroupAnalysis bundle folder, also keep a copy
    % inside the currently loaded animal analysed folder:
    %   <animal>\GroupAnalysis\SCM Bundle
    loadedAnimalRoot = base;
    try
        loadedAnimalRoot = guessAnalysedRoot(loadedAnimalRoot);
        loadedAnimalRoot = normalizeSelectorRoot(loadedAnimalRoot);
    catch
    end
    localBundleDir = fullfile(loadedAnimalRoot, 'GroupAnalysis', 'SCM Bundle');

    bundleRoot = fullfile(analysedRoot, 'GroupAnalysis', 'Bundles', 'SCM');
    subjectKey = sanitizeName(sprintf('%s_%s_%s', meta.animalID, meta.session, meta.scanID));
    if isempty(subjectKey)
        subjectKey = ['SCM_Subject_' datestr(now,'yyyymmdd_HHMMSS')];
    end

    Pexp = struct();
    Pexp.root = analysedRoot;
    Pexp.bundleRoot = bundleRoot;
    Pexp.bundleDir = fullfile(bundleRoot, subjectKey);
    Pexp.localBundleDir = localBundleDir;
    Pexp.subjectKey = subjectKey;
    Pexp.animalID = meta.animalID;
    Pexp.session = meta.session;
    Pexp.scanID = meta.scanID;
end

function analysedRoot = getCentralAnalysedRootForGroupBundlesLocal(p0)
    analysedRoot = guessAnalysedRoot(p0);
    try
        s = char(analysedRoot);
        tok = regexp(s, '^(.*?[\\/]+AnalysedData)([\\/].*)?$', 'tokens', 'once');
        if ~isempty(tok)
            analysedRoot = tok{1};
            return;
        end
    catch
    end
end

function outFile = makeShortGroupBundleOutFileLocal(Pexp, stamp)
    % Short filename avoids Windows/MATLAB long-path save errors.
    try
        key = sanitizeName(Pexp.subjectKey);
    catch
        key = 'SCM_Subject';
    end
    if isempty(key)
        key = 'SCM_Subject';
    end
    outFile = fullfile(Pexp.bundleDir, sprintf('SCM_%s_%s.mat', key, stamp));
end

function meta = deriveGroupBundleMetaLocal()
    meta = struct('animalID','','session','','scanID','');
    txts = {fileLabel, safeParFieldLocal('loadedFile'), safeParFieldLocal('loadedPath'), ...
            safeParFieldLocal('exportPath'), safeParFieldLocal('activeDataset'), ...
            safeParFieldLocal('datasetName'), safeParFieldLocal('sourceFile'), ...
            safeParFieldLocal('rawFile'), safeParFieldLocal('file'), safeParFieldLocal('path')};
    try
        if isfield(par,'scmPerSliceUnderlayFiles') && ~isempty(par.scmPerSliceUnderlayFiles)
            for kk = 1:numel(par.scmPerSliceUnderlayFiles)
                txts{end+1} = char(par.scmPerSliceUnderlayFiles{kk}); %#ok<AGROW>
            end
        end
    catch
    end
    for ii = 1:numel(txts)
        s = txts{ii}; if isempty(s), continue; end
        tok = regexpi(s,'(?:^|[\\\/ _-])([A-Za-z]{1,16}\d{6}[A-Za-z]?|\d{3,6})[_\- ]+(S\d+).*?((?:FUS[_\-]?\d+)|(?:scan\d+(?:_[A-Za-z0-9]+)?))','tokens','once');
        if ~isempty(tok), meta.animalID=sanitizeName(tok{1}); meta.session=sanitizeName(tok{2}); meta.scanID=sanitizeName(tok{3}); return; end
    end
    for ii = 1:numel(txts)
        s = txts{ii}; if isempty(s), continue; end
        if isempty(meta.animalID)
            tokA = regexpi(s,'([A-Za-z]{1,16}\d{6}[A-Za-z]?)','tokens','once');
            if ~isempty(tokA), meta.animalID=sanitizeName(tokA{1}); end
        end
        if isempty(meta.animalID)
            % Numeric animal at the beginning of label/folder, e.g. 1160_S75_...
            tokA = regexpi(s,'(?:^|[\\\/])(\d{3,6})(?=[_\-\\\/\s]|$)','tokens','once');
            if ~isempty(tokA), meta.animalID=sanitizeName(tokA{1}); end
        end
        if isempty(meta.animalID)
            % PACAP/RGRO style: RGRO_260512_1024_MM_B6J_1005 -> 1005
            tokA = regexpi(s,'[A-Za-z]+[_\-]\d{6}[_\-]\d{3,6}[_\-][A-Za-z]+[_\-][A-Za-z0-9]+[_\-](\d{3,6})(?:[_\-.\\\/ ]|$)','tokens','once');
            if ~isempty(tokA), meta.animalID=sanitizeName(tokA{1}); end
        end
        if isempty(meta.animalID)
            % General strain marker style: MM_B6J_1005 or F_C57BL6J_1160
            tokA = regexpi(s,'(?:^|[_\\\/\-])(MM|M|F|MALE|FEMALE)?[_\\\/\-]*(B6J|C57BL6J|C57|BL6J)[_\\\/\-]+(\d{3,6})(?:[_\\\/\-. ]|$)','tokens','once');
            if ~isempty(tokA), meta.animalID=sanitizeName(tokA{end}); end
        end
        if isempty(meta.session), tokS = regexpi(s,'(S\d+)','tokens','once'); if ~isempty(tokS), meta.session=sanitizeName(tokS{1}); end, end
        if isempty(meta.scanID)
            tokF = regexpi(s,'(FUS[_\-]?\d+)','tokens','once');
            if ~isempty(tokF)
                tmpF = strrep(tokF{1},'-','_');
                tmpF = regexprep(tmpF,'^FUS(\d+)$','FUS_$1','ignorecase');
                meta.scanID=sanitizeName(upper(tmpF));
            end
        end
        if isempty(meta.scanID)
            tokF = regexpi(s,'(scan\d+(?:_[A-Za-z0-9]+)?)','tokens','once');
            if ~isempty(tokF), meta.scanID=sanitizeName(tokF{1}); end
        end
    end
    if isempty(meta.animalID), meta.animalID = 'Animal'; end
    if isempty(meta.session), meta.session = 'S1'; end
    if isempty(meta.scanID), meta.scanID = 'FUS_UNKNOWN'; end
end

function s = safeParFieldLocal(fn)
    s = '';
    try, if isstruct(par) && isfield(par,fn) && ~isempty(par.(fn)), s = char(par.(fn)); end, catch, s = ''; end
end

function s = getCurrentPopupStringLocal(hPop)
    s = '';
    try
        items = get(hPop,'String'); v = get(hPop,'Value');
        if iscell(items), v = max(1,min(numel(items),v)); s = char(items{v});
        else, v = max(1,min(size(items,1),v)); s = strtrim(char(items(v,:))); end
    catch, s = ''; end
end

function safeMkdirIfNeeded(pth)
    if isempty(pth), return; end
    if exist(pth,'dir') ~= 7
        ok = mkdir(pth); if ~ok, error('Could not create folder: %s', pth); end
    end
end

function titleStr = makeFullTitle(lbl)
    s = char(lbl); s = regexprep(s, '\|?\s*File:.*$', ''); titleStr = deConfUSIon_utils('shortenMiddle',s, 110);
end

function s = getAnimalID(lbl)
    s = '';
    cands = {lbl, safeParFieldLocal('loadedFile'), safeParFieldLocal('loadedPath'), ...
             safeParFieldLocal('exportPath'), safeParFieldLocal('activeDataset'), ...
             safeParFieldLocal('datasetName'), safeParFieldLocal('sourceFile'), ...
             safeParFieldLocal('rawFile'), safeParFieldLocal('file'), safeParFieldLocal('path')};
    for ii = 1:numel(cands)
        try, s0 = char(cands{ii}); catch, s0 = ''; end
        if isempty(s0), continue; end
        tok = regexp(s0,'(WT\d+[A-Za-z]?(?:_\w+)?_S\d+)','tokens','once'); if ~isempty(tok), s = sanitizeName(tok{1}); return; end
        tok = regexp(s0,'(WT\d+[A-Za-z]?)','tokens','once'); if ~isempty(tok), s = sanitizeName(tok{1}); return; end
        tok = regexp(s0,'([A-Za-z]{1,16}\d{6}[A-Za-z]?)','tokens','once'); if ~isempty(tok), s = sanitizeName(tok{1}); return; end
        tok = regexpi(s0,'(?:^|[\\\/])(\d{3,6})(?=[_\-\\\/\s]|$)','tokens','once'); if ~isempty(tok), s = sanitizeName(tok{1}); return; end
        tok = regexpi(s0,'[A-Za-z]+[_\-]\d{6}[_\-]\d{3,6}[_\-][A-Za-z]+[_\-][A-Za-z0-9]+[_\-](\d{3,6})(?:[_\-.\\\/ ]|$)','tokens','once'); if ~isempty(tok), s = sanitizeName(tok{1}); return; end
        tok = regexpi(s0,'(?:^|[_\\\/\-])(MM|M|F|MALE|FEMALE)?[_\\\/\-]*(B6J|C57BL6J|C57|BL6J)[_\\\/\-]+(\d{3,6})(?:[_\\\/\-. ]|$)','tokens','once'); if ~isempty(tok), s = sanitizeName(tok{end}); return; end
    end
    s = 'Animal';
end

function out = shortenMiddle(s, maxLen)
    s = char(s); if numel(s) <= maxLen, out = s; return; end
    keep = floor((maxLen-3)/2); out = [s(1:keep) '...' s(end-keep+1:end)];
end

function s = shortenPath(p, maxLen)
    p = char(p); if numel(p) <= maxLen, s = p; return; end
    keep = floor((maxLen-3)/2); s = [p(1:keep) '...' p(end-keep+1:end)];
end

function s = sanitizeName(s)
    if exist('isstring','builtin') && isstring(s), s = char(s); end
    s = char(s); s = strrep(s,filesep,'_'); s = regexprep(s,'[^\w\-]+','_'); s = regexprep(s,'_+','_'); s = regexprep(s,'^_+|_+$','');
    if numel(s) > 80, s = s(1:80); end
end

function tag = askExportLabel(defaultTag, dlgTitle)
    if nargin < 1 || isempty(defaultTag), defaultTag = 'Target'; end
    if nargin < 2 || isempty(dlgTitle), dlgTitle = 'Export label'; end
    defaultButton = 'Custom';
    if strcmpi(defaultTag, 'Target')
        defaultButton = 'Target';
    elseif strcmpi(defaultTag, 'Ctrl') || strcmpi(defaultTag, 'Control')
        defaultButton = 'Control';
    end
    choice = questdlg('How should this export be labeled?', dlgTitle, 'Target','Control','Custom', defaultButton);
    if isempty(choice), tag = ''; return; end
    switch lower(choice)
        case 'target', tag = 'Target';
        case 'control', tag = 'Ctrl';
        otherwise
            a = inputdlg({'Enter label (for example Target, Ctrl, Hipp, Cortex):'}, dlgTitle, 1, {defaultTag});
            if isempty(a), tag = ''; return; end
            tag = a{1};
    end
    tag = sanitizeExportTag(tag);
end

function tag = sanitizeExportTag(s)
    if exist('isstring','builtin') && isstring(s), s = char(s); end
    s = strtrim(char(s)); if isempty(s), s = 'Target'; end
    s = regexprep(s,'[^\w\-]+','_'); s = regexprep(s,'_+','_'); s = regexprep(s,'^_+|_+$','');
    if isempty(s), s = 'Target'; end
    tag = s;
end

function idx = findPopupIndexByName(hPop, targetName)
    idx = 1;
    try
        items = get(hPop,'String'); if ischar(items), items = cellstr(items); end
        for ii = 1:numel(items)
            if strcmpi(strtrim(items{ii}), strtrim(targetName)), idx = ii; return; end
        end
    catch
    end
end

function s = getStr(h)
    try, s = get(h,'String'); catch, s = ''; return; end
    if iscell(s), if isempty(s), s = ''; else, s = s{1}; end, end
    if exist('isstring','builtin') && isstring(s), if numel(s)>1, s=s(1); end, s=char(s); end
    if isnumeric(s), s = num2str(s); end
    s = char(s);
end

function [a,b] = parseRangeSafe(s, da, db)
    if nargin < 2, da = 0; end
    if nargin < 3, db = da; end
    s = char(s); s = strrep(s, char(8211), '-'); s = strrep(s, char(8212), '-'); s = strrep(s, ',', ' ');
    v = sscanf(s,'%f-%f');
    if numel(v) ~= 2, v = sscanf(s,'%f %f'); end
    if numel(v) ~= 2 || any(~isfinite(v)), a = da; b = db; else, a = v(1); b = v(2); end
end

function [a,b] = parseAxisPair(s, da, db)
    v = sscanf(strrep(char(s),',',' '),'%f');
    if numel(v) >= 2 && all(isfinite(v(1:2))), a = v(1); b = v(2); else, a = da; b = db; end
    if b < a, tmp=a; a=b; b=tmp; end
    if b == a, b = a + eps; end
end

function out = clamp(x, lo, hi)
    out = min(max(x, lo), hi);
end

function tf = isfiniteScalar(x)
    tf = isnumeric(x) && isscalar(x) && isfinite(x);
end

function rgb = toRGB(im01)
    im = double(im01); im(~isfinite(im)) = 0; im = min(max(im,0),1);
    idx = uint8(round(im*255)); rgb = ind2rgb(idx, gray(256));
end

function out = smooth2D_gauss(in, sigma)
    if sigma <= 0, out = in; return; end
    valid=isfinite(in);
    if ~all(valid(:))
        values=in; values(~valid)=0;
        weights=smooth2D_gauss(cast(valid,'like',in),sigma);
        out=smooth2D_gauss(values,sigma)./weights;
        out(~valid | weights<=0)=NaN;
        return;
    end
    try, out = imgaussfilt(in, sigma); return; catch, end
    r = max(1,ceil(3*sigma)); x = -r:r; g = exp(-(x.^2)/(2*sigma^2)); g = g/sum(g);
    out = conv2(conv2(in,g,'same'),g','same');
end

function U = mat2gray_safe(U)
    U = double(U); mn = min(U(:)); mx = max(U(:));
    if ~isfinite(mn) || ~isfinite(mx) || mx <= mn, U(:) = 0; return; end
    U = min(max((U-mn)/(mx-mn),0),1);
end

function U = clip01_percentile(A, pLow, pHigh)
    v = A(:); v = v(isfinite(v));
    if isempty(v), U = zeros(size(A)); return; end
    lo = prctile_fallback(v,pLow); hi = prctile_fallback(v,pHigh);
    if ~isfinite(lo) || ~isfinite(hi) || hi <= lo, U = mat2gray_safe(A); return; end
    U = A; U(U < lo) = lo; U(U > hi) = hi; U = min(max((U-lo)/max(eps,(hi-lo)),0),1);
end

function q = prctile_fallback(v, p)
    try, q = prctile(v,p); return; catch, end
    v = sort(v(:)); n = numel(v); if n == 0, q = 0; return; end
    k = 1 + (n-1)*(p/100); k1 = floor(k); k2 = ceil(k); k1 = max(1,min(n,k1)); k2 = max(1,min(n,k2));
    if k1 == k2, q = v(k1); else, q = v(k1) + (k-k1)*(v(k2)-v(k1)); end
end
function tf = isAtlasLikeUnderlayFile(f)
    tf = false;

    try
        s = lower(char(f));

        keys = { ...
            'coronalregistration2d', ...
            'registration2d', ...
            'atlas', ...
            'histology', ...
            'histo', ...
            'registered', ...
            'warped', ...
            'source'};

        for kk = 1:numel(keys)
            if ~isempty(strfind(s, keys{kk})) %#ok<STREMP>
                tf = true;
                return;
            end
        end
    catch
        tf = false;
    end
end
end


function G = SCM_normalizeGroupBundlePSC_PATCH_V4(G, fullf)
% Robustly normalize SCM GroupAnalysis bundles so SCM_gui can reopen them.
if nargin < 2, fullf = ''; end
if isempty(G) || ~isstruct(G), error('Invalid SCM group bundle struct.'); end

X = [];
if isfield(G,'pscAtlas4D') && ~isempty(G.pscAtlas4D) && isnumeric(G.pscAtlas4D)
    X = G.pscAtlas4D;
else
    flds = {'pscAtlasD','pscAtlas3D','psc4D','PSC4D','PSC','functionalPSC','Ipsc'};
    for k = 1:numel(flds)
        f = flds{k};
        if isfield(G,f) && ~isempty(G.(f)) && isnumeric(G.(f))
            X = G.(f);
            break;
        end
    end
end

if isempty(X)
    error(['The selected MAT file is not a full SCM bundle.' char(10) char(10) ...
           'SCM_gui needs G.pscAtlas4D with dimensions [Y X T] or [Y X Z T].' char(10) ...
           'You probably selected a static GroupAnalysis map/export file instead of an SCM_GroupExport bundle.' char(10) char(10) ...
           'Select the file created by SCM_gui -> EXPORT SCM BUNDLE.' char(10) ...
           'File: ' char(fullf)]);
end

X = double(X);
X(~isfinite(X)) = 0;

while ndims(X) > 4
    X = squeeze(X);
end

% Common valid single-slice storage: [Y X 1 T] -> [Y X T]
if ndims(X) == 4 && size(X,3) == 1 && size(X,4) >= 2
    X = squeeze(X);
end

if ndims(X) == 2
    error(['This bundle contains only a static 2D map, not the full PSC time series.' char(10) char(10) ...
           'SCM_gui cannot reopen a static group-map PNG/MAT as SCM data.' char(10) ...
           'Use SCM_gui -> EXPORT SCM BUNDLE to create SCM_GroupExport_*.mat.' char(10) ...
           'File: ' char(fullf)]);
end

if ndims(X) == 3
    if size(X,3) < 2
        error('PSC array has only one frame. Need [Y X T] with T >= 2.');
    end
elseif ndims(X) == 4
    if size(X,4) < 2
        error('PSC array has only one time frame. Need [Y X Z T] with T >= 2.');
    end
else
    error('G.pscAtlas4D must be [Y X T] or [Y X Z T] after normalization.');
end

G.pscAtlas4D = X;

% Repair TR if it was saved only as tsec/tmin.
badTR = true;
try
    badTR = isempty(G.TR) || ~isfinite(double(G.TR(1))) || double(G.TR(1)) <= 0;
catch
    badTR = true;
end
if badTR
    try
        if isfield(G,'tsec') && numel(G.tsec) >= 2
            G.TR = median(diff(double(G.tsec(:))));
        elseif isfield(G,'tmin') && numel(G.tmin) >= 2
            G.TR = 60 * median(diff(double(G.tmin(:))));
        end
    catch
    end
end
end
