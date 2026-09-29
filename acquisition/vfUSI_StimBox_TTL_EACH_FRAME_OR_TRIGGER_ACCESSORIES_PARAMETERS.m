% V23: V22 stable acquisition + expanded users + UI title polish + journal defaults
% - Functional fUSI forces the lightweight processRF frame callback so the
%   top-right progress and measured Live dt update during the scan.
% - Progress shows frame/target, percent and elapsed seconds.
% - Callback UI refresh is automatically throttled to roughly once per second.
% UTF-8 safe, MATLAB 2017b compatible
%
% GUI ENTRY SCRIPT
% Keep this filename unchanged because the encrypted launcher may call it.

localLaunchMainGUI();

function localLaunchMainGUI()

    fig = figure( ...
        'Name', 'OpenfUS Trigger Controller', ...
        'NumberTitle', 'off', ...
        'MenuBar', 'none', ...
        'ToolBar', 'none', ...
        'Color', [0.07 0.08 0.10], ...
        'Position', [18 8 1760 1040], ...
        'Resize', 'on', ...
        'CloseRequestFcn', @(src, evt)localOnClose(src));

    C = localBuildColors();

    H = struct();
    H.fig = fig;
    H.C = C;

    % ------------------------------------------------------------------
    % Header
    % ------------------------------------------------------------------
H.hBanner = uipanel(fig, ...
    'Units', 'normalized', ...
    'Position', [0.012 0.936 0.976 0.050], ...
    'BorderType', 'line', ...
    'HighlightColor', C.banner, ...
    'ShadowColor', C.banner, ...
    'BackgroundColor', C.banner);

  H.hTitle = uicontrol(H.hBanner, 'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [0.014 0.22 0.178 0.64], ...
    'String', 'Trigger Controller', ...
    'FontSize', 19, ...
    'FontWeight', 'bold', ...
    'HorizontalAlignment', 'left', ...
    'ForegroundColor', [1 1 1], ...
    'BackgroundColor', C.banner);

H.hSubTitle = uicontrol(H.hBanner, 'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [0.198 0.23 0.252 0.58], ...
    'String', 'fUSI acquisition + synchronized StimBox / PulsePal / motor', ...
    'FontSize', 9.3, ...
    'FontWeight', 'bold', ...
    'HorizontalAlignment', 'left', ...
    'ForegroundColor', C.textSoft, ...
    'BackgroundColor', C.banner);

H.hStatus = uicontrol(H.hBanner, 'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [0.460 0.18 0.170 0.66], ...
    'String', 'Status: Idle', ...
    'FontSize', 10.5, ...
    'FontWeight', 'bold', ...
    'HorizontalAlignment', 'center', ...
    'ForegroundColor', [1 1 1], ...
    'BackgroundColor', C.idle);

H.hReady = uicontrol(H.hBanner, 'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [0.638 0.18 0.050 0.66], ...
    'String', 'READY', ...
    'FontSize', 9.3, ...
    'FontWeight', 'bold', ...
    'HorizontalAlignment', 'center', ...
    'ForegroundColor', [1 1 1], ...
    'BackgroundColor', C.ready);

% Live measured dt/TR display.
% This is based on wall-clock timing between frame callback updates.
H.pLiveDtBox = localMakeMiniInfoPanel(H.hBanner, [0.695 0.10 0.067 0.80], 'Live dt', C, C.edgePulse);
H.hLiveDt = localMakeMiniInfoText(H.pLiveDtBox, 'set --', C);
set(H.hLiveDt, 'FontSize', 10.8);     % bigger Live dt value

H.pFrameBox = localMakeMiniInfoPanel(H.hBanner, [0.770 0.10 0.060 0.80], 'Progress', C, C.edgeAcq);
H.hFrame = localMakeMiniInfoText(H.pFrameBox, '0', C);
set(H.hFrame, 'FontSize', 11.0);      % progress: frame/target + percent + seconds

set(H.pLiveDtBox, 'FontSize', 8.6);  % V23: clearer mini-panel title
set(H.pFrameBox, 'FontSize', 8.6);   % V23: clearer mini-panel title


H.pTrialBox = localMakeMiniInfoPanel(H.hBanner, [0.838 0.10 0.060 0.80], 'Scan', C, C.edgeStim);
H.hTrial = localMakeMiniInfoText(H.pTrialBox, '0/0', C);
set(H.pTrialBox, 'FontSize', 8.6);    % V23

H.pMotorBox = localMakeMiniInfoPanel(H.hBanner, [0.906 0.10 0.079 0.80], 'Motor', C, C.edgeMotor);
H.hMotor = localMakeMiniInfoText(H.pMotorBox, 'off', C);
set(H.pMotorBox, 'FontSize', 8.6);    % V23
% ------------------------------------------------------------------
% Main panels
% ------------------------------------------------------------------

% ===== Acquisition =====
pAcqWrap = uipanel(fig, ...
    'Units', 'normalized', ...
    'Position', [0.012 0.500 0.234 0.420], ...
    'Title', '', ...
    'BackgroundColor', C.edgeAcq, ...
    'BorderType', 'line', ...
    'HighlightColor', C.edgeAcq, ...
    'ShadowColor', C.edgeAcq);

uicontrol(pAcqWrap, 'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [0.02 0.946 0.96 0.044], ...
    'String', 'Acquisition', ...
    'FontSize', 11.0, ...
    'FontWeight', 'bold', ...
    'HorizontalAlignment', 'center', ...
    'ForegroundColor', [1 1 1], ...
    'BackgroundColor', C.edgeAcq);

pAcq = uipanel(pAcqWrap, ...
    'Units', 'normalized', ...
    'Position', [0.006 0.006 0.988 0.934], ...
    'BorderType', 'none', ...
    'BackgroundColor', C.panel);

% ===== StimBox =====
pStimBoxWrap = uipanel(fig, ...
    'Units', 'normalized', ...
    'Position', [0.249 0.500 0.234 0.420], ...
    'Title', '', ...
    'BackgroundColor', C.edgeStim, ...
    'BorderType', 'line', ...
    'HighlightColor', C.edgeStim, ...
    'ShadowColor', C.edgeStim);

uicontrol(pStimBoxWrap, 'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [0.02 0.946 0.96 0.044], ...
    'String', 'StimBox Triggering', ...
    'FontSize', 11.0, ...
    'FontWeight', 'bold', ...
    'HorizontalAlignment', 'center', ...
    'ForegroundColor', [1 1 1], ...
    'BackgroundColor', C.edgeStim);

pStimBox = uipanel(pStimBoxWrap, ...
    'Units', 'normalized', ...
    'Position', [0.006 0.006 0.988 0.934], ...
    'BorderType', 'none', ...
    'BackgroundColor', C.panel);

% ===== PulsePal =====
pPulsePalWrap = uipanel(fig, ...
    'Units', 'normalized', ...
    'Position', [0.486 0.500 0.237 0.420], ...
    'Title', '', ...
    'BackgroundColor', C.edgePulse, ...
    'BorderType', 'line', ...
    'HighlightColor', C.edgePulse, ...
    'ShadowColor', C.edgePulse);

uicontrol(pPulsePalWrap, 'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [0.02 0.946 0.96 0.044], ...
    'String', 'Electrical Stimulation', ...
    'FontSize', 11.0, ...
    'FontWeight', 'bold', ...
    'HorizontalAlignment', 'center', ...
    'ForegroundColor', [1 1 1], ...
    'BackgroundColor', C.edgePulse);

pPulsePal = uipanel(pPulsePalWrap, ...
    'Units', 'normalized', ...
    'Position', [0.006 0.006 0.988 0.934], ...
    'BorderType', 'none', ...
    'BackgroundColor', C.panel);

% ===== Motor =====
pMotorWrap = uipanel(fig, ...
    'Units', 'normalized', ...
    'Position', [0.726 0.500 0.262 0.420], ...
    'Title', '', ...
    'BackgroundColor', C.edgeMotor, ...
    'BorderType', 'line', ...
    'HighlightColor', C.edgeMotor, ...
    'ShadowColor', C.edgeMotor);

uicontrol(pMotorWrap, 'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [0.02 0.946 0.96 0.044], ...
    'String', 'Step Motor', ...
    'FontSize', 11.0, ...
    'FontWeight', 'bold', ...
    'HorizontalAlignment', 'center', ...
    'ForegroundColor', [1 1 1], ...
    'BackgroundColor', C.edgeMotor);

pMotor = uipanel(pMotorWrap, ...
    'Units', 'normalized', ...
    'Position', [0.006 0.006 0.988 0.934], ...
    'BorderType', 'none', ...
    'BackgroundColor', C.panel);

% ===== Embedded anatomy preview (V14) =====
% Compact three-zone layout: utility controls LEFT, anatomy image CENTER,
% display sliders RIGHT.  This avoids the V13 slider/grid overlap while
% leaving more width for the Live Log.
pPreviewWrap = uipanel(fig, ...
    'Units', 'normalized', ...
    'Position', [0.012 0.065 0.700 0.415], ...
    'Title', '', ...
    'BackgroundColor', C.edgeAcq, ...
    'BorderType', 'line', ...
    'HighlightColor', C.edgeAcq, ...
    'ShadowColor', C.edgeAcq);

uicontrol(pPreviewWrap, 'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [0.02 0.948 0.96 0.040], ...
    'String', 'ANATOMY PREVIEW  |  OpenfUS mirror', ...
    'FontSize', 10.2, ...
    'FontWeight', 'bold', ...
    'HorizontalAlignment', 'center', ...
    'ForegroundColor', [1 1 1], ...
    'BackgroundColor', C.edgeAcq);

pPreview = uipanel(pPreviewWrap, ...
    'Units', 'normalized', ...
    'Position', [0.006 0.008 0.988 0.934], ...
    'BorderType', 'none', ...
    'BackgroundColor', [0.035 0.04 0.05]);

% Left utility strip: status, color, grid and save/reset.
H.hPreviewInfo = uicontrol(pPreview, 'Style', 'text', ...
    'Units', 'normalized',  'Position', [0.015 0.805 0.155 0.125], ...
    'String', 'Waiting for anatomy', ...
    'HorizontalAlignment', 'left', 'FontSize', 8.2, 'FontWeight', 'bold', ...
    'ForegroundColor', C.textSoft, 'BackgroundColor', [0.035 0.04 0.05]);

uicontrol(pPreview,'Style','text','Units','normalized', ...
     'Position',[0.015 0.680 0.155 0.040],'String','Color', ...
    'HorizontalAlignment','left','FontSize',9,'FontWeight','bold', ...
    'ForegroundColor',C.text,'BackgroundColor',[0.035 0.04 0.05]);
H.pPreviewMap = uicontrol(pPreview, 'Style', 'popupmenu', ...
    'Units', 'normalized',  'Position', [0.015 0.610 0.155 0.060], ...
    'String', {'Gray','Hot'}, 'Value', 1, 'FontSize', 9.5, ...
    'BackgroundColor', C.editbg, 'ForegroundColor', [0 0 0]);

uicontrol(pPreview,'Style','text','Units','normalized', ...
     'Position',[0.015 0.530 0.155 0.040],'String','Grid layout', ...
    'HorizontalAlignment','left','FontSize',9,'FontWeight','bold', ...
    'ForegroundColor',C.text,'BackgroundColor',[0.035 0.04 0.05]);
uicontrol(pPreview,'Style','text','Units','normalized', ...
     'Position',[0.015 0.460 0.055 0.040],'String','Rows', ...
    'HorizontalAlignment','left','FontSize',8.7, ...
    'ForegroundColor',C.textSoft,'BackgroundColor',[0.035 0.04 0.05]);
H.pPreviewRows = uicontrol(pPreview,'Style','popupmenu','Units','normalized', ...
     'Position',[0.073 0.447 0.097 0.058], ...
    'String',{'Auto','1','2','3','4','5','6','7','8','9','10','12'}, ...
    'Value',1,'FontSize',9,'BackgroundColor',C.editbg,'ForegroundColor',[0 0 0]);
uicontrol(pPreview,'Style','text','Units','normalized', ...
     'Position',[0.015 0.380 0.055 0.040],'String','Cols', ...
    'HorizontalAlignment','left','FontSize',8.7, ...
    'ForegroundColor',C.textSoft,'BackgroundColor',[0.035 0.04 0.05]);
H.pPreviewCols = uicontrol(pPreview,'Style','popupmenu','Units','normalized', ...
     'Position',[0.073 0.367 0.097 0.058], ...
    'String',{'Auto','1','2','3','4','5','6','7','8','9','10','12'}, ...
    'Value',1,'FontSize',9,'BackgroundColor',C.editbg,'ForegroundColor',[0 0 0]);

H.bPreviewReset = uicontrol(pPreview, 'Style', 'pushbutton', ...
    'Units', 'normalized',  'Position', [0.015 0.235 0.155 0.070], ...
    'String', 'RESET VIEW', 'FontSize', 9.2, 'FontWeight', 'bold', ...
    'ForegroundColor', [1 1 1], 'BackgroundColor', C.btn, ...
    'Callback', @(src,evt)localResetPreviewDisplay(fig));

H.bSavePreview = uicontrol(pPreview, 'Style', 'pushbutton', ...
    'Units', 'normalized',  'Position', [0.015 0.145 0.155 0.070], ...
    'String', 'SAVE', 'FontSize', 9.2, 'FontWeight', 'bold', ...
    'ForegroundColor', [1 1 1], 'BackgroundColor', C.greenBtn, ...
    'Enable', 'off', ...
    'Callback', @(src,evt)localSaveCurrentPreview(fig));

% Central visualization area.
H.axPreview = axes('Parent', pPreview, ...
    'Units', 'normalized', ...
     'Position', [0.185 0.075 0.505 0.855], ...
    'Color', [0 0 0], ...
    'XColor', [0.68 0.70 0.74], ...
    'YColor', [0.68 0.70 0.74], ...
    'LineWidth', 1.0);
H.hPreviewImage = imagesc(H.axPreview, zeros(32,32), [0 1]);
axis(H.axPreview, 'image');
axis(H.axPreview, 'tight');
colormap(H.axPreview, gray(256));
H.hPreviewColorbar = colorbar('peer', H.axPreview);
title(H.axPreview, 'Waiting for Doppler / B-Mode', 'Color', [1 1 1], ...
    'FontSize', 9.5, 'FontWeight', 'bold', 'Interpreter', 'none');

% Right display sliders: one non-overlapping row per setting.
ctrlX = 0.715;
ctrlW = 0.270;
[H.hPreviewMinTxt,H.sPreviewMin] = localPreviewSlider(pPreview, 'Min', 0.00, 0.00, 0.95, ctrlX, 0.830, ctrlW, C);
[H.hPreviewMaxTxt,H.sPreviewMax] = localPreviewSlider(pPreview, 'Max', 1.00, 0.05, 1.00, ctrlX, 0.690, ctrlW, C);
[H.hPreviewGainTxt,H.sPreviewGain] = localPreviewSlider(pPreview, 'Gain', 1.00, 0.25, 4.00, ctrlX, 0.550, ctrlW, C);
[H.hPreviewGammaTxt,H.sPreviewGamma] = localPreviewSlider(pPreview, 'Gamma', 1.00, 0.25, 3.00, ctrlX, 0.410, ctrlW, C);
[H.hPreviewLogTxt,H.sPreviewLog] = localPreviewSlider(pPreview, 'Log', 0.00, 0.00, 1.00, ctrlX, 0.270, ctrlW, C);
[H.hPreviewSharpTxt,H.sPreviewSharp] = localPreviewSlider(pPreview, 'Sharp', 0.00, 0.00, 2.00, ctrlX, 0.130, ctrlW, C);

set(H.pPreviewMap,'Callback',@(src,evt)localUpdatePreviewDisplay(fig));
set(H.pPreviewRows,'Callback',@(src,evt)localUpdatePreviewDisplay(fig));
set(H.pPreviewCols,'Callback',@(src,evt)localUpdatePreviewDisplay(fig));
for hDisp = [H.sPreviewMin H.sPreviewMax H.sPreviewGain H.sPreviewGamma H.sPreviewLog H.sPreviewSharp]
    set(hDisp,'Callback',@(src,evt)localUpdatePreviewDisplay(fig));
end

% ===== Compact Live Log =====
pLogWrap = uipanel(fig, ...
    'Units', 'normalized', ...
    'Position', [0.720 0.065 0.268 0.415], ...
    'Title', '', ...
    'BackgroundColor', C.edgeHeader, ...
    'BorderType', 'line', ...
    'HighlightColor', C.edgeHeader, ...
    'ShadowColor', C.edgeHeader);

uicontrol(pLogWrap, 'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [0.02 0.948 0.96 0.040], ...
    'String', 'Live Log', ...
    'FontSize', 10.2, ...
    'FontWeight', 'bold', ...
    'HorizontalAlignment', 'center', ...
    'ForegroundColor', [1 1 1], ...
    'BackgroundColor', C.edgeHeader);

pLog = uipanel(pLogWrap, ...
    'Units', 'normalized', ...
    'Position', [0.010 0.010 0.980 0.934], ...
    'BorderType', 'none', ...
    'BackgroundColor', C.panel);
    % ------------------------------------------------------------------
% Acquisition / StimBox / PulsePal / Motor panels
% unified row grid
% ------------------------------------------------------------------
panelFs = 9.4;
smallFs = 8.1;

% Shared two-column grid for all upper panels.
% This makes Acquisition / StimBox / PulsePal / Motor rows line up better.
xLlbl = 0.05;
xLedt = 0.28;
wLedt = 0.17;

xRlbl = 0.50;
xRedt = 0.74;
wRedt = 0.16;

y1 = 0.78;
y2 = 0.66;
y3 = 0.54;
y4 = 0.42;
y5 = 0.30;
y6 = 0.18;
y7 = 0.06;

% ------------------------------------------------------------------
% Acquisition panel
% ------------------------------------------------------------------

% ------------------------------------------------------------------
% Save location selector (above folder warning)
% ------------------------------------------------------------------
uicontrol(pAcq, 'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [0.05 0.922 0.22 0.050], ...
    'String', 'Save under', ...
    'HorizontalAlignment', 'left', ...
    'FontSize', 10.5, ...
    'FontWeight', 'bold', ...
    'ForegroundColor', C.text, ...
    'BackgroundColor', C.panel);


% For adding other folder destination names change here
H.pSaveOwner = uicontrol(pAcq, 'Style', 'popupmenu', ...
    'Units', 'normalized', ...
    'Position', [0.28 0.920 0.55 0.050], ...
    'String', {'Soner','Yan','Kelly','Xuming','Pascal','Guest'}, ...
    'Value', 1, ...
    'FontSize', 10.5, ...
    'BackgroundColor', C.editbg, ...
    'ForegroundColor', [0 0 0]);

uicontrol(pAcq, 'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [0.05 0.86 0.78 0.05], ...
    'String', 'Care: Change Folder Name!', ...
    'HorizontalAlignment', 'left', ...
    'FontSize', 9.3, ...
    'FontWeight', 'bold', ...
    'ForegroundColor', [1 0.2 0.2], ...
    'BackgroundColor', C.panel);

H.eXpName = localMakeLabeledEdit(pAcq, ...
    'Exp. Name', [xLlbl y1 0.18 0.055], [xLedt y1-0.008 0.65 0.075], ...
    'RGRO_yymmdd_1024_MM_B6J_ID', C, panelFs, C.panel);

H.eNFrames = localMakeLabeledEdit(pAcq, ...
    'Frames/scan', [xLlbl y2 0.18 0.055], [xLedt y2-0.008 wLedt 0.075], ...
    '9000', C, panelFs, C.panel);

[H.eNTrials,H.hNTrialsLabel] = localMakeLabeledEdit(pAcq, ...
    'Scans', [xRlbl y2 0.16 0.055], [xRedt y2-0.008 wRedt 0.075], ...
    '1', C, panelFs, C.panel);

H.eNBlocks = localMakeLabeledEdit(pAcq, ...
    'Blocks/image', [xLlbl y3 0.18 0.055], [xLedt y3-0.008 wLedt 0.075], ...
    '16', C, panelFs, C.panel);

uicontrol(pAcq, 'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [xRlbl y3 0.12 0.055], ...
    'String', 'TR', ...
    'HorizontalAlignment', 'left', ...
    'FontSize', panelFs, ...
    'FontWeight', 'bold', ...
    'ForegroundColor', C.text, ...
    'BackgroundColor', C.panel);

H.hTR = uicontrol(pAcq, 'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [xRedt y3-0.008 wRedt 0.075], ...
    'String', '0.320 s', ...
    'FontSize', panelFs, ...
    'FontWeight', 'bold', ...
    'HorizontalAlignment', 'center', ...
    'ForegroundColor', [1 1 1], ...
    'BackgroundColor', C.box);

H.ePause = localMakeLabeledEdit(pAcq, ...
    'Pause (s)', [xLlbl y4 0.18 0.055], [xLedt y4-0.008 wLedt 0.075], ...
    '1', C, panelFs, C.panel);

% ------------------------------------------------------------------
% Probe type selector
%
% 2D probe -> TR = nblocksImage x 0.02 s
% 3D probe -> TR = nblocksImage x 0.03 s
% ------------------------------------------------------------------
uicontrol(pAcq, 'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [xRlbl y4 0.16 0.055], ...
    'String', 'Probe', ...
    'HorizontalAlignment', 'left', ...
    'FontSize', panelFs, ...
    'FontWeight', 'bold', ...
    'ForegroundColor', C.titleAcq, ...
    'BackgroundColor', C.panel);

H.pProbeType = uicontrol(pAcq, 'Style', 'popupmenu', ...
    'Units', 'normalized', ...
    'Position', [xRedt y4-0.012 wRedt+0.06 0.075], ...
    'String', {'2D probe','3D probe'}, ...
    'Value', 1, ...
    'FontSize', panelFs, ...
    'BackgroundColor', C.editbg, ...
    'ForegroundColor', [0 0 0], ...
    'Callback', @(src,evt)localUpdateTRDisplay(fig));

H.hAcqModeTitle = uicontrol(pAcq, 'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [xLlbl y5 0.20 0.055], ...
    'String', 'Acq. mode', ...
    'HorizontalAlignment', 'left', ...
    'FontSize', panelFs, ...
    'FontWeight', 'bold', ...
    'ForegroundColor', C.titleAcq, ...
    'BackgroundColor', C.panel);

H.pAcqMode = uicontrol(pAcq, 'Style', 'popupmenu', ...
    'Units', 'normalized', ...
    'Position', [xLedt y5-0.012 0.62 0.075], ...
    'String', {'Doppler / Low-Res Anatomy','Functional fUSI / Time Series','B-Mode Live','High-Res 2D','High-Res 3D'}, ...
    'Value', 1, ...
    'FontSize', panelFs, ...
    'BackgroundColor', C.editbg, ...
    'ForegroundColor', [0 0 0], ...
    'Callback', @(src,evt)localOnAcqModeChanged(fig, true));

H.eCalcSec = localMakeLabeledEdit(pAcq, ...
    'Seconds', [xLlbl y6 0.15 0.055], [xLedt y6-0.008 wLedt 0.075], ...
    '10', C, panelFs, C.panel);

H.eCalcFrames = localMakeLabeledEdit(pAcq, ...
    'Frames', [xRlbl y6 0.15 0.055], [xRedt y6-0.008 wRedt 0.075], ...
    '31', C, panelFs, C.panel);

H.bSecToFrames = uicontrol(pAcq, 'Style', 'pushbutton', ...
    'Units', 'normalized', ...
    'Position', [0.05 y7 0.40 0.08], ...
    'String', 'sec -> frames', ...
    'FontSize', panelFs, ...
    'FontWeight', 'bold', ...
    'ForegroundColor', [1 1 1], ...
    'BackgroundColor', C.btn, ...
    'Callback', @(src,evt)localCalcSecToFrames(fig));

H.bFramesToSec = uicontrol(pAcq, 'Style', 'pushbutton', ...
    'Units', 'normalized', ...
    'Position', [0.50 y7 0.40 0.08], ...
    'String', 'frames -> sec', ...
    'FontSize', panelFs, ...
    'FontWeight', 'bold', ...
    'ForegroundColor', [1 1 1], ...
    'BackgroundColor', C.btn, ...
    'Callback', @(src,evt)localCalcFramesToSec(fig));

% ------------------------------------------------------------------
% StimBox panel
% ------------------------------------------------------------------
H.cStimEnable = uicontrol(pStimBox, 'Style', 'checkbox', ...
    'Units', 'normalized', ...
    'Position', [0.05 0.89 0.34 0.06], ...
    'String', 'Enable StimBox', ...
    'Value', 0, ...
    'FontSize', 10, ...
    'FontWeight', 'bold', ...
    'ForegroundColor', C.titleStim, ...
    'BackgroundColor', C.panel, ...
    'Callback', @(src,evt)localRefreshStimBoxPanel(fig));

H.eStimCom = localMakeLabeledEdit(pStimBox, ...
    'COM', [xLlbl y1 0.15 0.055], [xLedt y1-0.008 wLedt 0.075], ...
    'COM9', C, panelFs, C.panel);

H.eStimBaud = localMakeLabeledEdit(pStimBox, ...
    'Baud', [xRlbl y1 0.17 0.055], [xRedt y1-0.008 wRedt 0.075], ...
    '9600', C, panelFs, C.panel);

H.eStimStart = localMakeLabeledEdit(pStimBox, ...
    'Frame start', [xLlbl y2 0.18 0.055], [xLedt y2-0.008 wLedt 0.075], ...
    '20', C, panelFs, C.panel);

H.eStimDur = localMakeLabeledEdit(pStimBox, ...
    'Active frames', [xRlbl y2 0.20 0.055], [xRedt y2-0.008 wRedt 0.075], ...
    '10', C, panelFs, C.panel);

H.cD3 = uicontrol(pStimBox, 'Style', 'checkbox', ...
    'Units', 'normalized', ...
    'Position', [xLlbl y3 0.18 0.06], ...
    'String', 'D3 ON', ...
    'Value', 0, ...
    'FontSize', panelFs, ...
    'FontWeight', 'bold', ...
    'ForegroundColor', C.text, ...
    'BackgroundColor', C.panel);

H.cD5 = uicontrol(pStimBox, 'Style', 'checkbox', ...
    'Units', 'normalized', ...
    'Position', [xRlbl y3 0.18 0.06], ...
    'String', 'D5 ON', ...
    'Value', 1, ...
    'FontSize', panelFs, ...
    'FontWeight', 'bold', ...
    'ForegroundColor', C.text, ...
    'BackgroundColor', C.panel);

H.cD6 = uicontrol(pStimBox, 'Style', 'checkbox', ...
    'Units', 'normalized', ...
    'Position', [xLlbl y4 0.18 0.06], ...
    'String', 'D6 ON', ...
    'Value', 0, ...
    'FontSize', panelFs, ...
    'FontWeight', 'bold', ...
    'ForegroundColor', C.text, ...
    'BackgroundColor', C.panel);

H.cStimVerbose = uicontrol(pStimBox, 'Style', 'checkbox', ...
    'Units', 'normalized', ...
    'Position', [xRlbl y4 0.28 0.06], ...
    'String', 'Verbose log', ...
    'Value', 1, ...
    'FontSize', panelFs, ...
    'FontWeight', 'bold', ...
    'ForegroundColor', C.text, ...
    'BackgroundColor', C.panel);

H.cStimRepeat = uicontrol(pStimBox, 'Style', 'checkbox', ...
    'Units', 'normalized', ...
    'Position', [xLlbl y6 0.18 0.06], ...
    'String', 'Repeat', ...
    'Value', 1, ...
    'FontSize', panelFs, ...
    'FontWeight', 'bold', ...
    'ForegroundColor', C.titleStim, ...
    'BackgroundColor', C.repeatBg, ...
    'Callback', @(src,evt)localRefreshStimBoxPanel(fig));

H.eStimRepeatEvery = localMakeLabeledEdit(pStimBox, ...
    'Every', [xRlbl y6 0.12 0.055], [xRedt y6-0.008 wRedt 0.075], ...
    '50', C, panelFs, C.repeatBg);

H.hStimSummary = uicontrol(pStimBox, 'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [0.05 0.05 0.86 0.08], ...
    'String', 'StimBox disabled', ...
    'HorizontalAlignment', 'left', ...
    'FontSize', panelFs, ...
    'FontWeight', 'bold', ...
    'ForegroundColor', C.textSoft, ...
    'BackgroundColor', C.panel);

% ------------------------------------------------------------------
% PulsePal panel
% ------------------------------------------------------------------
CPP = C;
CPP.panel = C.panel;

H.cPPEnable = uicontrol(pPulsePal, 'Style', 'checkbox', ...
    'Units', 'normalized', ...
    'Position', [0.05 0.89 0.40 0.06], ...
    'String', 'Enable electrical stim', ...
    'Value', 0, ...
    'FontSize', 10, ...
    'FontWeight', 'bold', ...
    'ForegroundColor', C.titlePulse, ...
    'BackgroundColor', C.panel, ...
    'Callback', @(src,evt)localRefreshPulsePalPanel(fig));

H.ppStdBtn = uicontrol(pPulsePal, 'Style', 'pushbutton', ...
    'Units', 'normalized', ...
    'Position', [0.58 0.892 0.14 0.055], ...
    'String', 'Standard', ...
    'FontSize', panelFs, ...
    'FontWeight', 'bold', ...
    'ForegroundColor', [1 1 1], ...
    'BackgroundColor', C.blueBtn, ...
    'Callback', @(src,evt)localSwitchPulsePalTab(fig, 'std'));

H.ppAdvBtn = uicontrol(pPulsePal, 'Style', 'pushbutton', ...
    'Units', 'normalized', ...
    'Position', [0.75 0.892 0.14 0.055], ...
    'String', 'Advanced', ...
    'FontSize', panelFs, ...
    'FontWeight', 'bold', ...
    'ForegroundColor', [1 1 1], ...
    'BackgroundColor', C.btnDark, ...
    'Callback', @(src,evt)localSwitchPulsePalTab(fig, 'adv'));

H.ppStdPanel = uipanel(pPulsePal, ...
    'Units', 'normalized', ...
    'Position', [0.03 0.04 0.94 0.83], ...
    'BorderType', 'none', ...
    'BackgroundColor', CPP.panel);

H.ppAdvPanel = uipanel(pPulsePal, ...
    'Units', 'normalized', ...
    'Position', [0.03 0.04 0.94 0.83], ...
    'BorderType', 'none', ...
    'BackgroundColor', CPP.panel, ...
    'Visible', 'off');

% Standard tab
H.ePPCom = localMakeLabeledEdit(H.ppStdPanel, ...
    'COM', [xLlbl y1 0.15 0.055], [xLedt y1-0.008 wLedt 0.075], ...
    'COM14', CPP, panelFs, CPP.panel);

H.ePPChan = localMakeLabeledEdit(H.ppStdPanel, ...
    'Channel', [xRlbl y1 0.18 0.055], [xRedt y1-0.008 wRedt 0.075], ...
    '1', CPP, panelFs, CPP.panel);

H.ePPStart = localMakeLabeledEdit(H.ppStdPanel, ...
    'Frame start', [xLlbl y2 0.18 0.055], [xLedt y2-0.008 wLedt 0.075], ...
    '100', CPP, panelFs, CPP.panel);

H.ePPDurFrames = localMakeLabeledEdit(H.ppStdPanel, ...
    'Active frames', [xRlbl y2 0.20 0.055], [xRedt y2-0.008 wRedt 0.075], ...
    '1', CPP, panelFs, CPP.panel);

H.ePPVolt1 = localMakeLabeledEdit(H.ppStdPanel, ...
    'Phase1 V', [xLlbl y3 0.15 0.055], [xLedt y3-0.008 wLedt 0.075], ...
    '5', CPP, panelFs, CPP.panel);

H.ePPDur1 = localMakeLabeledEdit(H.ppStdPanel, ...
    'P1 width', [xRlbl y3 0.22 0.055], [xRedt y3-0.008 wRedt 0.075], ...
    '0.005', CPP, panelFs, CPP.panel);

H.ePPIPI = localMakeLabeledEdit(H.ppStdPanel, ...
    'IPI (s)', [xLlbl y4 0.18 0.055], [xLedt y4-0.008 wLedt 0.075], ...
    '0.050', CPP, panelFs, CPP.panel);

H.ePPTrainDur = localMakeLabeledEdit(H.ppStdPanel, ...
    'Train dur', [xRlbl y4 0.18 0.055], [xRedt y4-0.008 wRedt 0.075], ...
    '0.500', CPP, panelFs, CPP.panel);

H.ePPRest = localMakeLabeledEdit(H.ppStdPanel, ...
    'Rest V', [xLlbl y5 0.15 0.055], [xLedt y5-0.008 wLedt 0.075], ...
    '0', CPP, panelFs, CPP.panel);

H.cPPBiphasic = uicontrol(H.ppStdPanel, 'Style', 'checkbox', ...
    'Units', 'normalized', ...
    'Position', [xRlbl y5 0.22 0.06], ...
    'String', 'Biphasic', ...
    'Value', 0, ...
    'FontSize', panelFs, ...
    'FontWeight', 'bold', ...
    'ForegroundColor', C.text, ...
    'BackgroundColor', CPP.panel, ...
    'Callback', @(src,evt)localRefreshPulsePalPanel(fig));

H.cPPRepeat = uicontrol(H.ppStdPanel, 'Style', 'checkbox', ...
    'Units', 'normalized', ...
    'Position', [xLlbl y6 0.18 0.06], ...
    'String', 'Repeat', ...
    'Value', 0, ...
    'FontSize', panelFs, ...
    'FontWeight', 'bold', ...
    'ForegroundColor', C.titlePulse, ...
    'BackgroundColor', C.repeatBg, ...
    'Callback', @(src,evt)localRefreshPulsePalPanel(fig));

H.ePPRepeatEvery = localMakeLabeledEdit(H.ppStdPanel, ...
    'Every', [xRlbl y6 0.12 0.055], [xRedt y6-0.008 wRedt 0.075], ...
    '100', CPP, panelFs, C.repeatBg);

H.hPPFreqInfo = uicontrol(H.ppStdPanel, 'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [0.05 0.10 0.82 0.04], ...
    'String', 'IPI = 0.0500 s  (~20.00 Hz)', ...
    'HorizontalAlignment', 'left', ...
    'FontSize', smallFs, ...
    'FontWeight', 'bold', ...
    'ForegroundColor', C.textSoft, ...
    'BackgroundColor', CPP.panel);

H.tPPNote = uicontrol(H.ppStdPanel, 'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [0.05 0.03 0.82 0.04], ...
    'String', 'P1 width = pulse width; Train dur = total stimulation time.', ...
    'HorizontalAlignment', 'left', ...
    'FontSize', smallFs, ...
    'FontWeight', 'bold', ...
    'ForegroundColor', C.textSoft, ...
    'BackgroundColor', CPP.panel);

% Advanced tab
H.ePPInterPhase = localMakeLabeledEdit(H.ppAdvPanel, ...
    'Interphase', [xLlbl y1 0.18 0.055], [xLedt y1-0.008 wLedt 0.075], ...
    '0.0001', CPP, panelFs, CPP.panel);

H.ePPVolt2 = localMakeLabeledEdit(H.ppAdvPanel, ...
    'Phase2 V', [xRlbl y1 0.18 0.055], [xRedt y1-0.008 wRedt 0.075], ...
    '-5', CPP, panelFs, CPP.panel);

H.ePPDur2 = localMakeLabeledEdit(H.ppAdvPanel, ...
    'P2 width', [xLlbl y2 0.22 0.055], [xLedt y2-0.008 wLedt 0.075], ...
    '0.005', CPP, panelFs, CPP.panel);

H.ePPBurstDur = localMakeLabeledEdit(H.ppAdvPanel, ...
    'Burst dur', [xRlbl y2 0.18 0.055], [xRedt y2-0.008 wRedt 0.075], ...
    '0', CPP, panelFs, CPP.panel);

H.ePPInterBurst = localMakeLabeledEdit(H.ppAdvPanel, ...
    'Inter-burst', [xLlbl y3 0.20 0.055], [xLedt y3-0.008 wLedt 0.075], ...
    '0.100', CPP, panelFs, CPP.panel);

H.ePPTrainDelay = localMakeLabeledEdit(H.ppAdvPanel, ...
    'Train delay', [xRlbl y3 0.20 0.055], [xRedt y3-0.008 wRedt 0.075], ...
    '0', CPP, panelFs, CPP.panel);

H.pPPCustomID = localMakeLabeledPopup(H.ppAdvPanel, ...
    'Custom ID', [xLlbl y4 0.22 0.055], [xLedt y4-0.008 0.26 0.075], ...
    {'Parametric','Custom 1','Custom 2'}, 1, CPP, CPP.panel);

H.pPPCustomTarget = localMakeLabeledPopup(H.ppAdvPanel, ...
    'Custom target', [xRlbl y4 0.18 0.055], [xRedt y4-0.008 wRedt 0.075], ...
    {'Pulses','Bursts'}, 1, CPP, CPP.panel);

H.cPPCustomLoop = uicontrol(H.ppAdvPanel, 'Style', 'checkbox', ...
    'Units', 'normalized', ...
    'Position', [xLlbl y5 0.22 0.055], ...
    'String', 'Custom loop', ...
    'Value', 0, ...
    'FontSize', panelFs, ...
    'FontWeight', 'bold', ...
    'ForegroundColor', C.text, ...
    'BackgroundColor', CPP.panel);

H.cPPLink1 = uicontrol(H.ppAdvPanel, 'Style', 'checkbox', ...
    'Units', 'normalized', ...
    'Position', [0.33 y5 0.24 0.055], ...
    'String', 'Link Trig CH1', ...
    'Value', 0, ...
    'FontSize', panelFs, ...
    'FontWeight', 'bold', ...
    'ForegroundColor', C.text, ...
    'BackgroundColor', CPP.panel);

H.cPPLink2 = uicontrol(H.ppAdvPanel, 'Style', 'checkbox', ...
    'Units', 'normalized', ...
    'Position', [0.62 y5 0.24 0.055], ...
    'String', 'Link Trig CH2', ...
    'Value', 0, ...
    'FontSize', panelFs, ...
    'FontWeight', 'bold', ...
    'ForegroundColor', C.text, ...
    'BackgroundColor', CPP.panel);

H.pPPTrigMode1 = localMakeLabeledPopup(H.ppAdvPanel, ...
    'Trig CH1', [xLlbl y6 0.18 0.055], [xLedt y6-0.008 0.23 0.075], ...
    {'Normal','Toggle','Pulse gated'}, 1, CPP, CPP.panel);

H.pPPTrigMode2 = localMakeLabeledPopup(H.ppAdvPanel, ...
    'Trig CH2', [xRlbl y6 0.18 0.055], [xRedt y6-0.008 wRedt 0.075], ...
    {'Normal','Toggle','Pulse gated'}, 1, CPP, CPP.panel);

% ------------------------------------------------------------------
% Motor panel
% ------------------------------------------------------------------
H.cMotorEnable = uicontrol(pMotor, 'Style', 'checkbox', ...
    'Units', 'normalized', ...
    'Position', [0.05 0.89 0.22 0.06], ...
    'String', 'Enable motor', ...
    'Value', 0, ...
    'FontSize', 10, ...
    'FontWeight', 'bold', ...
    'ForegroundColor', C.titleMotor, ...
    'BackgroundColor', C.panel, ...
    'Callback', @(src,evt)localRefreshMotorPanel(fig));

uicontrol(pMotor, 'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [0.30 0.89 0.14 0.055], ...
    'String', 'Acq mode', ...
    'HorizontalAlignment', 'left', ...
    'FontSize', panelFs, ...
    'FontWeight', 'bold', ...
    'ForegroundColor', C.text, ...
    'BackgroundColor', C.panel);

H.pMotorAcqMode = uicontrol(pMotor, 'Style', 'popupmenu', ...
    'Units', 'normalized', ...
   'Position', [0.44 0.882 0.31 0.075], ...
    'String', {'Continuous one MAT','Split per slice MAT'}, ...
    'Value', 2, ...
   'FontSize', panelFs, ...
    'BackgroundColor', C.editbg, ...
    'ForegroundColor', [0 0 0], ...
    'Callback', @(src,evt)localOnMotorAcqModeChanged(fig));

uicontrol(pMotor, 'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [0.77 0.89 0.06 0.055], ...
    'String', 'Pos', ...
    'HorizontalAlignment', 'left', ...
    'FontSize', panelFs, ...
    'FontWeight', 'bold', ...
    'ForegroundColor', C.text, ...
    'BackgroundColor', C.panel);

H.pMotorMode = uicontrol(pMotor, 'Style', 'popupmenu', ...
    'Units', 'normalized', ...
    'Position', [0.83 0.882 0.14 0.075], ...
    'String', {'Single','Stepped'}, ...
    'Value', 2, ...
    'FontSize', panelFs, ...
    'BackgroundColor', C.editbg, ...
    'Callback', @(src,evt)localRefreshMotorPanel(fig));

H.eMotorCom = localMakeLabeledEdit(pMotor, ...
    'COM', [xLlbl y1 0.15 0.055], [xLedt y1-0.008 wLedt 0.075], ...
    'COM8', C, panelFs, C.panel);

H.hCurrentPosLabel = uicontrol(pMotor, 'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [xRlbl y1 0.20 0.055], ...
    'String', 'Current pos', ...
    'HorizontalAlignment', 'left', ...
    'FontSize', panelFs, ...
    'FontWeight', 'bold', ...
    'ForegroundColor', C.text, ...
    'BackgroundColor', C.panel);

H.hCurrentPos = uicontrol(pMotor, 'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [xRedt y1-0.008 wRedt 0.075], ...
    'String', 'NA mm', ...
    'FontSize', panelFs, ...
    'FontWeight', 'bold', ...
    'HorizontalAlignment', 'center', ...
    'ForegroundColor', [1 1 1], ...
    'BackgroundColor', C.box);

H.eMotorFrameStart = localMakeLabeledEdit(pMotor, ...
    'Active from', [xLlbl y2 0.20 0.055], [xLedt y2-0.008 wLedt 0.075], ...
    '0', C, panelFs, C.panel);

H.eMotorFrameDur = localMakeLabeledEdit(pMotor, ...
    'Active for', [xRlbl y2 0.20 0.055], [xRedt y2-0.008 wRedt 0.075], ...
    '9000', C, panelFs, C.panel);

H.eMStart = localMakeLabeledEdit(pMotor, ...
    'Start (mm)', [xLlbl y3 0.18 0.055], [xLedt y3-0.008 wLedt 0.075], ...
    '10', C, panelFs, C.panel);

H.eMEnd = localMakeLabeledEdit(pMotor, ...
    'End (mm)', [xRlbl y3 0.18 0.055], [xRedt y3-0.008 wRedt 0.075], ...
    '30', C, panelFs, C.panel);

H.eMStep = localMakeLabeledEdit(pMotor, ...
    'Step (mm)', [xLlbl y4 0.18 0.055], [xLedt y4-0.008 wLedt 0.075], ...
    '0.5', C, panelFs, C.panel);

H.eMFrames = localMakeLabeledEdit(pMotor, ...
    'Frames/slice', [xRlbl y4 0.18 0.055], [xRedt y4-0.008 wRedt 0.075], ...
    '50', C, panelFs, C.panel);

% ------------------------------------------------------------------
% Slice timing controls (split mode)
%
% Fast pipeline: the move to the next slice is issued as soon as the
% current scan ends, so the stage travels while the file is written.
% ------------------------------------------------------------------
H.cMotorFastPipeline = uicontrol(pMotor, 'Style', 'checkbox', ...
    'Units', 'normalized', ...
    'Position', [xLlbl y5 0.42 0.06], ...
    'String', 'Fast pipeline', ...
    'Value', 1, ...
    'FontSize', panelFs, ...
    'FontWeight', 'bold', ...
    'ForegroundColor', C.titleMotor, ...
    'BackgroundColor', C.panel, ...
    'TooltipString', ...
    'Overlap the next motor move with the current file save to remove dead time between slices.');

H.eMotorSettle = localMakeLabeledEdit(pMotor, ...
    'Settle (s)', [xRlbl y5 0.18 0.055], [xRedt y5-0.008 wRedt 0.075], ...
    '0.02', C, panelFs, C.panel);

H.cMotorRepeat = uicontrol(pMotor, 'Style', 'checkbox', ...
    'Units', 'normalized', ...
    'Position', [xLlbl y6 0.16 0.06], ...
    'String', 'Repeat', ...
    'Value', 0, ...
    'FontSize', panelFs, ...
    'FontWeight', 'bold', ...
    'ForegroundColor', C.titleMotor, ...
    'BackgroundColor', C.repeatBg, ...
    'Callback', @(src,evt)localRefreshMotorPanel(fig));

H.eMotorRepeatEvery = localMakeLabeledEdit(pMotor, ...
    'Every', [xRlbl y6 0.12 0.055], [xRedt y6-0.008 wRedt 0.075], ...
    '100', C, panelFs, C.repeatBg);

H.cPeriodic = uicontrol(pMotor, 'Style', 'checkbox', ...
    'Units', 'normalized', ...
    'Position', [xLlbl 0.12 0.18 0.06], ...
    'String', 'Periodic', ...
    'Value', 0, ...
    'FontSize', panelFs, ...
    'FontWeight', 'bold', ...
    'ForegroundColor', C.text, ...
    'BackgroundColor', C.panel);

H.cReturnZero = uicontrol(pMotor, 'Style', 'checkbox', ...
    'Units', 'normalized', ...
    'Position', [0.28 0.12 0.24 0.06], ...
    'String', 'Return home', ...
    'Value', 1, ...
    'FontSize', panelFs, ...
    'FontWeight', 'bold', ...
    'ForegroundColor', C.text, ...
    'BackgroundColor', C.panel);

H.bReadMotor = uicontrol(pMotor, 'Style', 'pushbutton', ...
    'Units', 'normalized', ...
    'Position', [0.72 0.08 0.20 0.08], ...
    'String', 'READ POS', ...
    'FontSize', panelFs, ...
    'FontWeight', 'bold', ...
    'ForegroundColor', [1 1 1], ...
    'BackgroundColor', C.blueBtn, ...
    'Callback', @(src,evt)localTryReadMotorPos(fig, false));

H.hMotorSummary = uicontrol(pMotor, 'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [0.05 0.03 0.88 0.05], ...
    'String', 'Estimated positions: 1 | Used per scan: 1', ...
    'HorizontalAlignment', 'left', ...
    'FontSize', smallFs, ...
    'FontWeight', 'bold', ...
    'ForegroundColor', C.textSoft, ...
    'BackgroundColor', C.panel);

    % ------------------------------------------------------------------
    % Log
    % ------------------------------------------------------------------
H.logList = uicontrol(pLog, 'Style', 'listbox', ...
    'Units', 'normalized', ...
    'Position', [0.018 0.035 0.964 0.935], ...
    'Max', 2, ...
    'Min', 0, ...
    'FontName', 'Courier New', ...
    'FontSize', 9.1, ...
    'ForegroundColor', [0.96 0.96 0.96], ...
    'BackgroundColor', [0.06 0.07 0.09], ...
    'String', {'GUI ready.'});
    % ------------------------------------------------------------------
    % Buttons and footer
    % ------------------------------------------------------------------
    H.bStart = uicontrol(fig, 'Style', 'pushbutton', ...
        'Units', 'normalized', ...
        'Position', [0.012 0.012 0.12 0.042], ...
        'String', 'START', ...
        'FontSize', 11, ...
        'FontWeight', 'bold', ...
        'ForegroundColor', [1 1 1], ...
        'BackgroundColor', C.greenBtn, ...
        'Callback', @(src, evt)localOnStart(fig));

H.bStop = uicontrol(fig, 'Style', 'pushbutton', ...
    'Units', 'normalized', ...
    'Position', [0.142 0.012 0.12 0.042], ...
    'String', 'STOP', ...
    'FontSize', 11, ...
    'FontWeight', 'bold', ...
    'ForegroundColor', [1 1 1], ...
    'BackgroundColor', C.redBtn, ...
    'Enable', 'on', ...
    'Callback', @(src, evt)localOnStop(fig));

    H.bDefaults = uicontrol(fig, 'Style', 'pushbutton', ...
        'Units', 'normalized', ...
        'Position', [0.272 0.012 0.12 0.042], ...
        'String', 'DEFAULTS', ...
        'FontSize', 11, ...
        'FontWeight', 'bold', ...
        'ForegroundColor', [1 1 1], ...
        'BackgroundColor', C.btn, ...
        'Callback', @(src, evt)localLoadDefaults(fig));

    H.hFooter = uicontrol(fig, 'Style', 'text', ...
        'Units', 'normalized', ...
        'Position', [0.565 0.012 0.175 0.042], ...
        'String', 'Soner Caner Cagun  |  MPI-BC  |  2026', ...
        'FontSize', 10.2, ...
        'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center', ...
        'ForegroundColor', [0.86 0.88 0.92], ...
        'BackgroundColor', C.bg);

    H.bHelp = uicontrol(fig, 'Style', 'pushbutton', ...
        'Units', 'normalized', ...
        'Position', [0.755 0.012 0.11 0.042], ...
        'String', 'HELP', ...
        'FontSize', 11, ...
        'FontWeight', 'bold', ...
        'ForegroundColor', [1 1 1], ...
        'BackgroundColor', C.blueBtn, ...
        'Callback', @(src, evt)localShowHelpWindow());

    H.bClose = uicontrol(fig, 'Style', 'pushbutton', ...
        'Units', 'normalized', ...
        'Position', [0.875 0.012 0.11 0.042], ...
        'String', 'CLOSE', ...
        'FontSize', 11, ...
        'FontWeight', 'bold', ...
        'ForegroundColor', [1 1 1], ...
        'BackgroundColor', C.redBtn, ...
        'Callback', @(src, evt)localOnClose(fig));

    
    %Journal Button
H.bJournalNote = uicontrol(fig, 'Style', 'pushbutton', ...
    'Units', 'normalized', ...
    'Position', [0.402 0.012 0.150 0.042], ...
    'String', 'JOURNAL NOTE', ...
    'FontSize', 10.5, ...
    'FontWeight', 'bold', ...
    'ForegroundColor', [1 1 1], ...
    'BackgroundColor', [0.85 0.45 0.10], ...
    'Callback', @(src, evt)localEditJournalNote(fig));
    % ------------------------------------------------------------------
    % Input handles
    % ------------------------------------------------------------------
    H.inputHandles = [ ...
         H.bJournalNote ...
        H.pSaveOwner H.eXpName H.eNFrames H.eNTrials H.eNBlocks H.ePause H.pProbeType H.pAcqMode ...
        H.eCalcSec H.eCalcFrames H.bSecToFrames H.bFramesToSec ...
        H.cStimEnable H.eStimCom H.eStimBaud H.eStimStart H.eStimDur H.cStimRepeat H.eStimRepeatEvery H.cD3 H.cD5 H.cD6 H.cStimVerbose ...
        H.cPPEnable H.ppStdBtn H.ppAdvBtn H.ePPCom H.ePPChan H.ePPStart H.ePPDurFrames H.cPPRepeat H.ePPRepeatEvery ...
        H.ePPVolt1 H.ePPDur1 H.ePPIPI H.ePPTrainDur H.ePPRest H.cPPBiphasic ...
        H.ePPInterPhase H.ePPVolt2 H.ePPDur2 H.ePPBurstDur H.ePPInterBurst H.ePPTrainDelay ...
        H.pPPCustomID H.pPPCustomTarget H.cPPCustomLoop H.cPPLink1 H.cPPLink2 H.pPPTrigMode1 H.pPPTrigMode2 ...
        H.cMotorEnable H.pMotorAcqMode H.pMotorMode H.eMotorCom H.eMotorFrameStart H.eMotorFrameDur H.cMotorRepeat H.eMotorRepeatEvery ...
        H.eMStart H.eMEnd H.eMStep H.eMFrames H.cPeriodic H.cReturnZero H.bReadMotor ...
        ];

    % ------------------------------------------------------------------
    % Callbacks
    % ------------------------------------------------------------------
    set(H.eNBlocks, 'Callback', @(src,evt)localUpdateTRDisplay(fig));
    set(H.eNFrames, 'Callback', @(src,evt)localRefreshAllSummaries(fig));

    set(H.eStimStart, 'Callback', @(src,evt)localRefreshStimBoxPanel(fig));
    set(H.eStimDur, 'Callback', @(src,evt)localRefreshStimBoxPanel(fig));
    set(H.eStimRepeatEvery, 'Callback', @(src,evt)localRefreshStimBoxPanel(fig));

    set(H.ePPStart, 'Callback', @(src,evt)localRefreshPulsePalPanel(fig));
    set(H.ePPDurFrames, 'Callback', @(src,evt)localRefreshPulsePalPanel(fig));
    set(H.ePPRepeatEvery, 'Callback', @(src,evt)localRefreshPulsePalPanel(fig));
set(H.cPPBiphasic, 'Callback', @(src,evt)localRefreshPulsePalPanel(fig));
set(H.ePPIPI, 'Callback', @(src,evt)localRefreshPulsePalPanel(fig));
set(H.ePPTrainDur, 'Callback', @(src,evt)localRefreshPulsePalPanel(fig));
set(H.ePPDur1, 'Callback', @(src,evt)localRefreshPulsePalPanel(fig));
    set(H.eMotorCom, 'Callback', @(src,evt)localOnMotorFieldChanged(fig));
    set(H.eMotorFrameStart, 'Callback', @(src,evt)localRefreshMotorPanel(fig));
    set(H.eMotorFrameDur, 'Callback', @(src,evt)localRefreshMotorPanel(fig));
    set(H.eMotorRepeatEvery, 'Callback', @(src,evt)localRefreshMotorPanel(fig));
    set(H.eMStart, 'Callback', @(src,evt)localRefreshMotorPanel(fig));
    set(H.eMEnd, 'Callback', @(src,evt)localRefreshMotorPanel(fig));
    set(H.eMStep, 'Callback', @(src,evt)localRefreshMotorPanel(fig));
    set(H.eMFrames, 'Callback', @(src,evt)localRefreshMotorPanel(fig));

    guidata(fig, H);
setappdata(fig, 'stopRequested', false);
setappdata(fig, 'isRunning', false);
setappdata(fig, 'motorCurrentPosAbsMM', NaN);
setappdata(fig, 'PulsePalTab', 'std');
setappdata(fig, 'journalNote', '');
setappdata(fig, 'previewData', []);
setappdata(fig, 'previewMode', '');
setappdata(fig, 'previewMetadata', struct());
setappdata(fig, 'previewSaveCfg', struct());
% V19 company-UI synchronization state.
setappdata(fig, 'externalVendorBlocked', false);
setappdata(fig, 'externalVendorBusy', false);
setappdata(fig, 'externalVendorMode', '');
setappdata(fig, 'externalVendorWasAcquiring', false);
setappdata(fig, 'externalVendorIdleConfirm', 0);
setappdata(fig, 'externalVendorMirrorTried', false);
setappdata(fig, 'vendorMonitorTimer', []);

% Live measured dt/TR tracking.
setappdata(fig, 'liveTRStats', localInitLiveTRStats());
    localSetStatus(fig, 'Idle', 'idle');
    localSetReady(fig, true);
    localSetFrame(fig, 0);
    localSetTrial(fig, 0, 0);
    localSetMotor(fig, 0, 0, NaN, 0);
    localSetCurrentPos(fig, NaN);
        localUpdateJournalNoteButton(fig);
    localAppendLog(fig, 'GUI opened.');
localResetLiveTR(fig);

    localLoadDefaults(fig);
    localRestorePulsePalTab(fig);
    localTryReadMotorPos(fig, true);
    % Read-only synchronization with the company OpenfUS UI.
    localStartVendorMonitor(fig);
end

% =========================================================================
% UI builders
% =========================================================================
function C = localBuildColors()
    C.bg         = [0.07 0.08 0.10];
    C.banner     = [0.09 0.11 0.14];
    C.panel      = [0.12 0.14 0.18];
    C.text       = [0.96 0.97 0.98];
    C.textSoft   = [0.78 0.81 0.86];
    C.editbg     = [0.99 0.99 1.00];

    C.ready      = [0.15 0.58 0.22];
    C.notready   = [0.65 0.18 0.18];
    C.running    = [0.14 0.39 0.80];
   C.error      = [0.74 0.18 0.18];
C.warn       = [0.85 0.45 0.10];
C.good       = [0.15 0.58 0.22];
C.idle       = [0.25 0.28 0.33];

    C.btn        = [0.28 0.33 0.40];
    C.btnDark    = [0.20 0.23 0.28];
    C.greenBtn   = [0.16 0.62 0.24];
    C.redBtn     = [0.72 0.16 0.16];
    C.blueBtn    = [0.15 0.40 0.82];

    % IMPORTANT: keep this, your code still uses C.box
    C.box        = [0.18 0.21 0.26];

    % Top mini-box inner background
    C.miniBg     = [0.05 0.06 0.08];

    % Highlight background for Repeat/Every rows
    C.repeatBg   = [0.16 0.19 0.24];

    C.titleAcq   = [0.92 0.95 1.00];
    C.titleStim  = [0.50 0.95 0.66];
    C.titlePulse = [0.54 0.80 1.00];
    C.titleMotor = [0.95 0.35 0.35];

    C.edgeHeader = [0.30 0.36 0.44];
    C.edgeAcq    = [0.52 0.58 0.68];
    C.edgeStim   = [0.35 0.72 0.48];
    C.edgePulse  = [0.33 0.58 0.90];
    C.edgeMotor  = [0.82 0.22 0.22];
end


% =========================================================================
% Embedded anatomy preview / in-GUI save (V14)
% =========================================================================
function [hTxt,hSlider] = localPreviewSlider(parent,labelStr,val,mn,mx,x,y,w,C)
    % V16: generous label band above a thicker slider; tuned for Windows HiDPI.
    % This prevents labels from being clipped/overlapped on Windows HiDPI.
    hTxt = uicontrol(parent,'Style','text','Units','normalized', ...
        'Position',[x y+0.026 w 0.054], ...
        'String',sprintf('%s   %.2f',labelStr,val), ...
        'HorizontalAlignment','left','FontSize',10.2,'FontWeight','bold', ...
        'ForegroundColor',C.textSoft,'BackgroundColor',[0.035 0.04 0.05]);
    hSlider = uicontrol(parent,'Style','slider','Units','normalized', ...
        'Position',[x y-0.034 w 0.052], ...
        'Min',mn,'Max',mx,'Value',val);
end

function localSafeGuiPreview(fig,I,mode,md)
    try
        if ~ishandle(fig), return; end
        if nargin < 4 || isempty(md), md = struct(); end
        if nargin < 3 || isempty(mode), mode = 'anatomy'; end
        localSetPreview(fig,I,mode,md);
    catch ME
        try, localAppendLog(fig,['Preview update warning: ' ME.message]); catch, end
    end
end

function localSetPreview(fig,I,mode,md)
    if isempty(I) || ~ishandle(fig), return; end
    H = guidata(fig);
    try
        if isa(I,'gpuArray'), I = gather(I); end
    catch
    end
    if ~isnumeric(I), return; end
    I = squeeze(I);
    % UI bridge V10 already converts true-color company CData to scalar
    % display data before sending it here.  Therefore a third dimension of
    % size 3 means three anatomy slices, not RGB.
    oldMode = '';
    try, oldMode = getappdata(fig,'previewMode'); catch, end
    firstOfMode = isempty(oldMode) || ~strcmpi(oldMode,mode) || isempty(getappdata(fig,'previewData'));

    setappdata(fig,'previewData',I);
    setappdata(fig,'previewMode',mode);
    setappdata(fig,'previewMetadata',md);

    % Prefer the exact CLim captured from the company axes when available.
    base = [];
    try
        if isstruct(md) && isfield(md,'vendor_display_clim') && isnumeric(md.vendor_display_clim) && ...
                numel(md.vendor_display_clim)==2 && all(isfinite(md.vendor_display_clim)) && ...
                md.vendor_display_clim(2)>md.vendor_display_clim(1)
            base = double(md.vendor_display_clim(:)');
        end
    catch
    end
    if isempty(base)
        x = localPreviewPlane(I);
        v = double(x(:)); v = v(isfinite(v));
        if isempty(v)
            base = [0 1];
        else
            base = [min(v) max(v)];
            if base(2)<=base(1), base(2)=base(1)+1; end
        end
    end
    setappdata(fig,'previewDisplayBase',base);

    if firstOfMode
        localResetPreviewDisplay(fig);
    else
        localUpdatePreviewDisplay(fig);
    end

    if ~isempty(strfind(lower(mode),'bmode'))
        set(H.bSavePreview,'String','SAVE B-MODE','Enable','on');
    else
        set(H.bSavePreview,'String','SAVE LOW-RES','Enable','on');
    end
end

function img = localPreviewPlane(I)
    if ndims(I) <= 2,img=squeeze(I);return;end
    img=squeeze(I(:,:,1));
end

function [rows,cols]=localPreviewGridShape(H,md,n)
rows=1;cols=1;
if n<=1,return;end
% Manual override only when explicitly selected.
try
    rs=get(H.pPreviewRows,'String');rv=get(H.pPreviewRows,'Value');
    cs=get(H.pPreviewCols,'String');cv=get(H.pPreviewCols,'Value');
    if rv>1,rows=str2double(rs{rv});else,rows=NaN;end
    if cv>1,cols=str2double(cs{cv});else,cols=NaN;end
catch,rows=NaN;cols=NaN;end
if isnan(rows)
    try,rows=double(md.vendor_grid_rows);catch,rows=NaN;end
end
if isnan(cols)
    try,cols=double(md.vendor_grid_cols);catch,cols=NaN;end
end
if ~isfinite(rows)||rows<1,cols0=max(1,ceil(sqrt(1.5*n)));rows=ceil(n/cols0);end
if ~isfinite(cols)||cols<1,cols=ceil(n/rows);end
rows=max(1,round(rows));cols=max(1,round(cols));
if rows*cols<n
    cols=ceil(n/rows);
end
end

function [mosaic,rows,cols]=localPreviewMontage(I,md,H,mn,mx,gain,gamma,logS,sharp)
if ndims(I)<=2
    n=1;I3=reshape(I,size(I,1),size(I,2),1);
else
    I3=I;n=size(I3,3);
end
[rows,cols]=localPreviewGridShape(H,md,n);
clims=[];
try
    if isstruct(md)&&isfield(md,'vendor_display_clims')&&isnumeric(md.vendor_display_clims)&&size(md.vendor_display_clims,2)==2
        clims=double(md.vendor_display_clims);
    elseif isstruct(md)&&isfield(md,'vendor_display_clim')&&isnumeric(md.vendor_display_clim)&&numel(md.vendor_display_clim)==2
        clims=repmat(double(md.vendor_display_clim(:)'),n,1);
    end
catch
end
hh=size(I3,1);ww=size(I3,2);gap=max(1,round(min(hh,ww)*0.012));
mosaic=zeros(rows*hh+(rows-1)*gap,cols*ww+(cols-1)*gap);
for k=1:n
    x=double(I3(:,:,k));if ~isreal(x),x=abs(x);end;x(~isfinite(x))=0;
    if size(clims,1)>=k && all(isfinite(clims(k,:))) && clims(k,2)>clims(k,1)
        lo=clims(k,1);hi=clims(k,2);
    else
        v=x(:);v=v(isfinite(v));if isempty(v),lo=0;hi=1;else,lo=min(v);hi=max(v);if hi<=lo,hi=lo+1;end,end
    end
    z=(x-lo)/max(eps,hi-lo);z=max(0,min(1,z));
    z=(z-mn)/max(eps,mx-mn);z=max(0,min(1,z));
    z=max(0,min(1,z*gain));z=z.^(1/max(0.05,gamma));
    if logS>0.001,a=1+99*logS;z=log1p(a*z)/log1p(a);end
    if sharp>0.001
        ker=[1 2 1;2 4 2;1 2 1]/16;blur=conv2(z,ker,'same');z=max(0,min(1,z+sharp*(z-blur)));
    end
    r=floor((k-1)/cols)+1;c=mod(k-1,cols)+1;
    rr=(r-1)*(hh+gap)+(1:hh);cc=(c-1)*(ww+gap)+(1:ww);
    mosaic(rr,cc)=z;
end
end

function localResetPreviewDisplay(fig)
    if ~ishandle(fig), return; end
    H = guidata(fig);
    try, set(H.sPreviewMin,'Value',0); catch, end
    try, set(H.sPreviewMax,'Value',1); catch, end
    try, set(H.sPreviewGain,'Value',1); catch, end
    try, set(H.sPreviewGamma,'Value',1); catch, end
    try, set(H.sPreviewLog,'Value',0); catch, end
    try, set(H.sPreviewSharp,'Value',0); catch, end
    try, set(H.pPreviewMap,'Value',1); catch, end
    try, set(H.pPreviewRows,'Value',1); catch, end
    try, set(H.pPreviewCols,'Value',1); catch, end
    localUpdatePreviewDisplay(fig);
end

function localUpdatePreviewDisplay(fig)
    if ~ishandle(fig), return; end
    H = guidata(fig);I = getappdata(fig,'previewData');if isempty(I), return; end
    mode = getappdata(fig,'previewMode');md=getappdata(fig,'previewMetadata');
    mn=get(H.sPreviewMin,'Value');mx=get(H.sPreviewMax,'Value');
    if mx<=mn+0.01,mx=min(1,mn+0.01);set(H.sPreviewMax,'Value',mx);end
    gain=get(H.sPreviewGain,'Value');gamma=max(0.05,get(H.sPreviewGamma,'Value'));
    logS=get(H.sPreviewLog,'Value');sharp=get(H.sPreviewSharp,'Value');
    [z,rows,cols]=localPreviewMontage(I,md,H,mn,mx,gain,gamma,logS,sharp);
    set(H.hPreviewImage,'CData',z);set(H.axPreview,'CLim',[0 1]);
    maps=get(H.pPreviewMap,'String');mp=maps{get(H.pPreviewMap,'Value')};
    if strcmpi(mp,'Hot'),colormap(H.axPreview,hot(256));else,colormap(H.axPreview,gray(256));end
    axis(H.axPreview,'image');axis(H.axPreview,'tight');
    n=1;if ndims(I)>=3,n=size(I,3);end
    isRendered=false;try,isRendered=isstruct(md)&&isfield(md,'vendor_rendered_montage')&&logical(md.vendor_rendered_montage);catch,end
    if isRendered
        ttl=sprintf('%s  |  rendered native OpenfUS display  |  %dx%d px', ...
            localPreviewModeLabel(mode),size(I,2),size(I,1));
    else
        ttl=sprintf('%s  |  %d slice(s)  |  grid %dx%d  |  tile %dx%d', ...
            localPreviewModeLabel(mode),n,rows,cols,size(I,1),size(I,2));
    end
    title(H.axPreview,ttl,'Color',[1 1 1],'FontSize',9.5,'FontWeight','bold','Interpreter','none');
    set(H.hPreviewMinTxt,'String',sprintf('Min        %.0f %%',100*mn));
    set(H.hPreviewMaxTxt,'String',sprintf('Max        %.0f %%',100*mx));
    set(H.hPreviewGainTxt,'String',sprintf('Gain       %.2f x',gain));
    set(H.hPreviewGammaTxt,'String',sprintf('Gamma      %.2f',gamma));
    set(H.hPreviewLogTxt,'String',sprintf('Log        %.0f %%',100*logS));
    set(H.hPreviewSharpTxt,'String',sprintf('Sharpness  %.2f',sharp));
    if isRendered
        set(H.hPreviewInfo,'String',sprintf('%s | rendered vendor view',localPreviewModeLabel(mode)));
    else
        set(H.hPreviewInfo,'String',sprintf('%s | native display data',localPreviewModeLabel(mode)));
    end
    drawnow limitrate;
end

function s = localPreviewModeLabel(mode)
    if ~isempty(strfind(lower(mode),'bmode'))
        s='B-Mode Live';
    elseif ~isempty(strfind(lower(mode),'doppler'))
        s='Doppler / Low-Res Anatomy';
    else
        s='Anatomy';
    end
end

function localSaveCurrentPreview(fig)
    if ~ishandle(fig), return; end
    try
        if getappdata(fig,'isRunning')
            localAppendLog(fig,'SAVE is available after the active acquisition stops.');
            return;
        end
    catch
    end

    % Keep external-company acquisitions in exactly the same destination
    % convention as scans started by this controller.
    localRefreshPreviewSaveCfgFromGui(fig);

    I = getappdata(fig,'previewData');
    mode = getappdata(fig,'previewMode');
    if isempty(mode)
        mode = localGetAcquisitionMode(fig);
    end

    % If the acquisition was started from the native company GUI and the
    % automatic watcher did not catch it, SAVE performs one safe static
    % import of the current company visualization before saving.  Never do
    % this while the company software/hardware is busy.
    if isempty(I)
        if localVendorIsBlockedNow(fig)
            localAppendLog(fig,'SAVE unavailable while OpenfUS hardware/software is busy or not ready.');
            return;
        end
        try
            SCAN=[];
            try,SCAN=evalin('base','SCAN');catch,end
            [Iimp,mdimp]=vfUSI_OpenfUS_UIBridge('capture_current',SCAN,struct(),mode);
            if ~isempty(Iimp)
                localSafeGuiPreview(fig,Iimp,mode,mdimp);
                I=Iimp;
                localAppendLog(fig,'Imported current company OpenfUS anatomy into Trigger Controller for saving.');
            end
        catch MEimp
            localAppendLog(fig,['Could not import current company OpenfUS view: ' MEimp.message]);
        end
    end

    if isempty(I)
        localAppendLog(fig,'Nothing to save: no Doppler/B-Mode company view is available.');
        return;
    end

    metadata = getappdata(fig,'previewMetadata');
    cfg = getappdata(fig,'previewSaveCfg');
    if isempty(cfg) || ~isstruct(cfg), cfg=struct(); end
    try
        if ~isfield(cfg,'output_root')||isempty(cfg.output_root),cfg.output_root='C:\Data';end
        if ~isfield(cfg,'save_owner')||isempty(cfg.save_owner),cfg.save_owner='Soner';end
        if ~isfield(cfg,'xp_name')||isempty(cfg.xp_name),cfg.xp_name='Anatomy';end
        outDir=fullfile(cfg.output_root,cfg.save_owner,cfg.xp_name);
        if exist(outDir,'dir')~=7,mkdir(outDir);end

        if ~isstruct(metadata),metadata=struct();end
        metadata.saved_from_embedded_preview=true;
        metadata.preview_mode=mode;
        metadata.saved_at=datestr(now,'yyyy-mm-dd HH:MM:SS');
        events=struct();
        display_settings=localGetPreviewDisplaySettings(fig); %#ok<NASGU>

        if ~isempty(strfind(lower(mode),'bmode'))
            idx=localNextBModeIndex(outDir);
            name=sprintf('B-Mode_scan%d_%s.mat',idx,datestr(now,'yyyymmdd_HHMMSS'));
            metadata.imageType='bmode';
            metadata.image_role='bmode_anatomy';
        else
            idx=localNextPreviewIndex(outDir,'low_res_anatomy');
            name=sprintf('low_res_anatomy_%d.mat',idx);
            metadata.imageType='doppler';
            metadata.image_role='low_res_anatomy';
        end
        fullName=fullfile(outDir,name);
        save(fullName,'I','metadata','events','display_settings','-v7');
        localAppendLog(fig,['Saved anatomy from GUI: ' fullName]);
        H=guidata(fig);
        set(H.hPreviewInfo,'String',localPreviewSavedText(mode,name));
        try,set(H.hPreviewInfo,'TooltipString',fullName);catch,end
    catch ME
        localAppendLog(fig,['SAVE failed: ' ME.message]);
    end
end


function txt=localPreviewSavedText(mode,name)
% Multi-line filename display: avoids clipping long timestamped B-Mode names.
label=localPreviewModeLabel(mode);
tok=regexp(name,'^(B-Mode_scan\d+_)(.+)$','tokens','once');
if ~isempty(tok)
    txt=sprintf('%s\nSaved:\n%s\n%s',label,tok{1},tok{2});
else
    if numel(name)>26
        cut=min(26,numel(name));
        txt=sprintf('%s\nSaved:\n%s\n%s',label,name(1:cut),name(cut+1:end));
    else
        txt=sprintf('%s\nSaved:\n%s',label,name);
    end
end
end

function localRefreshPreviewSaveCfgFromGui(fig)
if ~ishandle(fig),return;end
try
    H=guidata(fig);
    owners=get(H.pSaveOwner,'String');
    oi=get(H.pSaveOwner,'Value');
    if ischar(owners),owners=cellstr(owners);end
    owner='Soner';
    if iscell(owners)&&oi>=1&&oi<=numel(owners),owner=strtrim(owners{oi});end
    xp=strtrim(get(H.eXpName,'String'));
    if isempty(xp),xp='Anatomy';end
    cfg=struct('output_root','C:\Data','save_owner',owner,'xp_name',xp);
    setappdata(fig,'previewSaveCfg',cfg);
catch
end
end

function tf=localVendorIsBlocked(fig)
tf=false;
try
    tf=logical(getappdata(fig,'externalVendorBlocked'));
catch
end
end

function tf=localVendorIsBlockedNow(fig)
% Immediate read-only safety check used when START/SAVE is clicked, so a
% company acquisition begun just before the next 0.75-s timer tick cannot be
% accidentally overlapped.
tf=localVendorIsBlocked(fig);
if tf,return;end
try
    st=vfUSI_OpenfUS_UIBridge('status',[],struct());
    tf=isstruct(st) && (logical(st.busy) || ~logical(st.ready));
    if tf
        setappdata(fig,'externalVendorBlocked',true);
        try,setappdata(fig,'externalVendorBusy',logical(st.busy));catch,end
        try,setappdata(fig,'externalVendorMode',char(st.mode));catch,end
    end
catch
end
end

function ds=localGetPreviewDisplaySettings(fig)
    H=guidata(fig);maps=get(H.pPreviewMap,'String');
    ds=struct('min',get(H.sPreviewMin,'Value'),'max',get(H.sPreviewMax,'Value'), ...
        'gain',get(H.sPreviewGain,'Value'),'gamma',get(H.sPreviewGamma,'Value'), ...
        'log',get(H.sPreviewLog,'Value'),'sharpness',get(H.sPreviewSharp,'Value'), ...
        'colormap',maps{get(H.pPreviewMap,'Value')}, ...
        'grid_rows_selection',get(H.pPreviewRows,'Value'),'grid_cols_selection',get(H.pPreviewCols,'Value'));
end

function idx=localNextBModeIndex(folderPath)
    idx=1;
    try
        d=dir(fullfile(folderPath,'B-Mode_scan*.mat'));nums=[];
        for k=1:numel(d)
            tok=regexp(d(k).name,'^B-Mode_scan(\d+)_','tokens','once');
            if ~isempty(tok),v=str2double(tok{1});if isfinite(v),nums(end+1)=v;end,end %#ok<AGROW>
        end
        if ~isempty(nums),idx=max(nums)+1;end
    catch
    end
end

function idx=localNextPreviewIndex(folderPath,prefix)
    idx=1;
    try
        d=dir(fullfile(folderPath,[prefix '_*.mat']));nums=[];
        expr=['^' regexptranslate('escape',prefix) '_(\d+)\.mat$'];
        for k=1:numel(d)
            tok=regexp(d(k).name,expr,'tokens','once');
            if ~isempty(tok),v=str2double(tok{1});if isfinite(v),nums(end+1)=v;end,end %#ok<AGROW>
        end
        if ~isempty(nums),idx=max(nums)+1;end
    catch
    end
end

function localUpdateScanTrialNaming(fig)
    if ~ishandle(fig),return;end
    H=guidata(fig);
    useTrial=false;
    try
        useTrial=logical(get(H.cMotorEnable,'Value')) && get(H.pMotorMode,'Value')==2;
    catch
    end
    try
        if useTrial
            set(H.hNTrialsLabel,'String','Trials');
            set(H.pTrialBox,'Title','Trial');
        else
            set(H.hNTrialsLabel,'String','Scans');
            set(H.pTrialBox,'Title','Scan');
        end
    catch
    end
end

function p = localMakeMiniInfoPanel(parent, pos, titleStr, C, edgeColor)
    p = uipanel(parent, ...
        'Units', 'normalized', ...
        'Position', pos, ...
        'Title', titleStr, ...
        'FontSize', 8.5, ...
        'FontWeight', 'bold', ...
        'BorderType', 'line', ...
        'ForegroundColor', C.text, ...
        'BackgroundColor', edgeColor, ...
        'HighlightColor', edgeColor, ...
        'ShadowColor', edgeColor);

    inner = uipanel(p, ...
        'Units', 'normalized', ...
        'Position', [0.05 0.08 0.90 0.66], ...
        'BorderType', 'none', ...
        'BackgroundColor', C.miniBg);

    setappdata(p, 'innerPanel', inner);
end

function h = localMakeMiniInfoText(parent, s, C)
    inner = getappdata(parent, 'innerPanel');
    if isempty(inner) || ~ishandle(inner)
        inner = parent;
    end

    h = uicontrol(inner, 'Style', 'text', ...
        'Units', 'normalized', ...
        'Position', [0.02 0.02 0.96 0.96], ...
        'String', s, ...
        'FontSize', 10.5, ...
        'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center', ...
        'ForegroundColor', [1 1 1], ...
        'BackgroundColor', C.miniBg);
end
function [hEdit,hLabel] = localMakeLabeledEdit(parent, labelStr, labelPos, editPos, defaultVal, C, fs, bgColor)
    if nargin < 7
        fs = 11;
    end
    if nargin < 8
        bgColor = C.panel;
    end

    hLabel = uicontrol(parent, 'Style', 'text', ...
        'Units', 'normalized', ...
        'Position', labelPos, ...
        'String', labelStr, ...
        'HorizontalAlignment', 'left', ...
        'FontSize', fs, ...
        'FontWeight', 'bold', ...
        'ForegroundColor', C.text, ...
        'BackgroundColor', bgColor);

    hEdit = uicontrol(parent, 'Style', 'edit', ...
        'Units', 'normalized', ...
        'Position', editPos, ...
        'String', defaultVal, ...
        'FontSize', fs, ...
        'BackgroundColor', C.editbg, ...
        'ForegroundColor', [0 0 0]);
end

function hPop = localMakeLabeledPopup(parent, labelStr, labelPos, popPos, items, defaultVal, C, bgColor)
    if nargin < 8
        bgColor = C.panel;
    end

    uicontrol(parent, 'Style', 'text', ...
        'Units', 'normalized', ...
        'Position', labelPos, ...
        'String', labelStr, ...
        'HorizontalAlignment', 'left', ...
        'FontSize', 10, ...
        'FontWeight', 'bold', ...
        'ForegroundColor', C.text, ...
        'BackgroundColor', bgColor);

    hPop = uicontrol(parent, 'Style', 'popupmenu', ...
        'Units', 'normalized', ...
        'Position', popPos, ...
        'String', items, ...
        'Value', defaultVal, ...
        'FontSize', 10, ...
        'BackgroundColor', C.editbg, ...
        'ForegroundColor', [0 0 0]);
end

% =========================================================================
% Panel refresh
% =========================================================================
function localRefreshAllSummaries(fig)
    if ~ishandle(fig)
        return;
    end
    localUpdateTRDisplay(fig);
    localRefreshStimBoxPanel(fig);
    localRefreshPulsePalPanel(fig);
    localRefreshMotorPanel(fig);
end

function localSwitchPulsePalTab(fig, tabName)
    if ~ishandle(fig)
        return;
    end

    H = guidata(fig);

    switch lower(tabName)
        case 'std'
            set(H.ppStdPanel, 'Visible', 'on');
            set(H.ppAdvPanel, 'Visible', 'off');
            set(H.ppStdBtn, 'BackgroundColor', H.C.blueBtn);
            set(H.ppAdvBtn, 'BackgroundColor', H.C.btnDark);
            setappdata(fig, 'PulsePalTab', 'std');

        case 'adv'
            set(H.ppStdPanel, 'Visible', 'off');
            set(H.ppAdvPanel, 'Visible', 'on');
            set(H.ppStdBtn, 'BackgroundColor', H.C.btnDark);
            set(H.ppAdvBtn, 'BackgroundColor', H.C.blueBtn);
            setappdata(fig, 'PulsePalTab', 'adv');
    end

    drawnow limitrate;
end

function localRestorePulsePalTab(fig)
    if ~ishandle(fig)
        return;
    end

    if isappdata(fig, 'PulsePalTab')
        tabName = getappdata(fig, 'PulsePalTab');
    else
        tabName = 'std';
    end

    localSwitchPulsePalTab(fig, tabName);
end

function localRefreshStimBoxPanel(fig)
    if ~ishandle(fig)
        return;
    end

    H = guidata(fig);

    stimOn = logical(get(H.cStimEnable, 'Value'));
    repOn = logical(get(H.cStimRepeat, 'Value'));

    handles = [H.eStimCom H.eStimBaud H.eStimStart H.eStimDur H.cStimRepeat H.eStimRepeatEvery H.cD3 H.cD5 H.cD6 H.cStimVerbose];
    localSetHandleGroup(handles, stimOn);
    localSetHandleGroup(H.eStimRepeatEvery, stimOn && repOn);

    if ~stimOn
        set(H.hStimSummary, 'String', 'StimBox disabled');
        return;
    end

    s0 = localParseNumericNoError(get(H.eStimStart, 'String'));
    dur = localParseNumericNoError(get(H.eStimDur, 'String'));
    repEvery = localParseNumericNoError(get(H.eStimRepeatEvery, 'String'));

    activeLines = {};
    if logical(get(H.cD3, 'Value')), activeLines{end+1} = 'D3'; end %#ok<AGROW>
    if logical(get(H.cD5, 'Value')), activeLines{end+1} = 'D5'; end %#ok<AGROW>
    if logical(get(H.cD6, 'Value')), activeLines{end+1} = 'D6'; end %#ok<AGROW>

    if isempty(activeLines)
        activeText = 'none';
    else
        activeText = strjoin(activeLines, ', ');
    end

    if repOn
        repText = sprintf('repeat every %s', localNum2Str(repEvery));
    else
        repText = 'no repeat';
    end

    set(H.hStimSummary, 'String', sprintf('Start %s | Active %s frames | %s | Lines: %s', ...
        localNum2Str(s0), localNum2Str(dur), repText, activeText));
end

function localRefreshPulsePalPanel(fig)
    if ~ishandle(fig)
        return;
    end

    H = guidata(fig);

    ppOn = logical(get(H.cPPEnable, 'Value'));
    repOn = logical(get(H.cPPRepeat, 'Value'));
    biphasicOn = logical(get(H.cPPBiphasic, 'Value'));

    pulsepalHandles = [ ...
        H.ppStdBtn H.ppAdvBtn ...
        H.ePPCom H.ePPChan H.ePPStart H.ePPDurFrames H.cPPRepeat H.ePPRepeatEvery ...
        H.ePPVolt1 H.ePPDur1 H.ePPIPI H.ePPTrainDur H.ePPRest H.cPPBiphasic ...
        H.ePPInterPhase H.ePPVolt2 H.ePPDur2 H.ePPBurstDur H.ePPInterBurst H.ePPTrainDelay ...
        H.pPPCustomID H.pPPCustomTarget H.cPPCustomLoop H.cPPLink1 H.cPPLink2 H.pPPTrigMode1 H.pPPTrigMode2 ...
        ];

    localSetHandleGroup(pulsepalHandles, ppOn);
    localSetHandleGroup(H.ePPRepeatEvery, ppOn && repOn);

    % Only true biphasic-only controls
    localSetHandleGroup([H.ePPInterPhase H.ePPVolt2 H.ePPDur2], ppOn && biphasicOn);

    % Still disabled in your present software-triggered workflow
    localSetHandleGroup([ ...
        H.pPPCustomID H.pPPCustomTarget H.cPPCustomLoop ...
        H.cPPLink1 H.cPPLink2 H.pPPTrigMode1 H.pPPTrigMode2 ...
        ], false);

    try
        ipi = str2double(get(H.ePPIPI, 'String'));
        if ~isnan(ipi) && isfinite(ipi) && ipi > 0
            hz = 1 / ipi;
            set(H.hPPFreqInfo, 'String', sprintf('IPI = %.4f s  (~%.2f Hz)', ipi, hz));
        else
            set(H.hPPFreqInfo, 'String', 'IPI = NA');
        end
    catch
        try
            set(H.hPPFreqInfo, 'String', 'IPI = NA');
        catch
        end
    end

    localRestorePulsePalTab(fig);
end
function localOnMotorAcqModeChanged(fig)
    if ~ishandle(fig)
        return;
    end

    H = guidata(fig);

    acqModeIdx = get(H.pMotorAcqMode, 'Value');
    isContinuous = (acqModeIdx == 1);

    if isContinuous
        % Continuous one-MAT mode should cycle through the slice list.
        set(H.cPeriodic, 'Value', 1);

        % Start at 0 = pre-position before scan.
        set(H.eMotorFrameStart, 'String', '0');

        % Use full trial length as motor active duration.
        try
            set(H.eMotorFrameDur, 'String', get(H.eNFrames, 'String'));
        catch
        end
    end

    localRefreshMotorPanel(fig);
end
function localRefreshMotorPanel(fig)
    if ~ishandle(fig)
        return;
    end

    H = guidata(fig);

    motorOn = logical(get(H.cMotorEnable, 'Value'));
    steppedMode = (get(H.pMotorMode, 'Value') == 2);

    acqModeIdx = get(H.pMotorAcqMode, 'Value');
    splitMode = (acqModeIdx == 2);

    motorHandlesAlways = [ ...
        H.pMotorAcqMode H.pMotorMode H.eMotorCom ...
        H.eMStart H.cReturnZero H.bReadMotor H.eMotorSettle];

    motorHandlesStepped = [H.eMEnd H.eMStep H.eMFrames];

    localSetHandleGroup([motorHandlesAlways motorHandlesStepped], motorOn);

    if motorOn
        localSetHandleGroup(motorHandlesStepped, steppedMode);
    end

    % The fast slice pipeline only applies to split mode, where the motor
    % moves between separate scans.
    localSetHandleGroup(H.cMotorFastPipeline, motorOn && splitMode);

    % Old continuous-only controls.
    % In split mode they are not used because each slice is its own scan.
    localSetHandleGroup([H.eMotorFrameStart H.eMotorFrameDur H.cMotorRepeat H.eMotorRepeatEvery H.cPeriodic], ...
        motorOn && ~splitMode);

    nPos = localEstimateMotorPositions(fig);
    framesPerSlice = str2double(get(H.eMFrames, 'String'));

    if isnan(framesPerSlice) || framesPerSlice < 1
        framesPerSlice = NaN;
    end

    if ~motorOn
        set(H.hMotorSummary, 'String', 'Motor OFF');
        localSetMotor(fig, 0, 0, NaN, 0);
        localSetCurrentPos(fig, NaN);

    elseif ~steppedMode
        if splitMode
            set(H.hMotorSummary, 'String', sprintf( ...
                'Split mode: 1 slice file/scan | %s frames/file | no acquisition during movement', ...
                localNum2Str(framesPerSlice)));
        else
            set(H.hMotorSummary, 'String', sprintf( ...
                'Continuous mode: single position | one MAT | %s frames/slice', ...
                localNum2Str(framesPerSlice)));
        end
        localSetMotor(fig, 0, 1, NaN, 0);

    else
        if splitMode
            set(H.hMotorSummary, 'String', sprintf( ...
                'Split mode: %d slice files/trial | %s frames/file | motor moves between files', ...
                nPos, localNum2Str(framesPerSlice)));
        else
            expectedFrames = nPos * framesPerSlice;
            set(H.hMotorSummary, 'String', sprintf( ...
                'Continuous mode: one MAT | %d slices x %s frames = ~%s frames', ...
                nPos, localNum2Str(framesPerSlice), localNum2Str(expectedFrames)));
        end

        localSetMotor(fig, 0, nPos, NaN, 0);
    end

    localUpdateScanTrialNaming(fig);
end

function localSetHandleGroup(handles, tfEnable)
    if tfEnable
        modeStr = 'on';
    else
        modeStr = 'off';
    end

    for k = 1:numel(handles)
        try
            set(handles(k), 'Enable', modeStr);
        catch
        end
    end
end

% =========================================================================
% TR / calculator
% =========================================================================
function localUpdateTRDisplay(fig)
    if ~ishandle(fig)
        return;
    end

    H = guidata(fig);

    imagingMode = localGetAcquisitionMode(fig);
    if strcmpi(imagingMode, 'bmode_live')
        set(H.hTR, 'String', 'LIVE');
        try
            if ~getappdata(fig, 'isRunning')
                localResetLiveTR(fig);
            end
        catch
        end
        return;
    end

    nblocks = str2double(get(H.eNBlocks, 'String'));
    trUnit = localGetTRUnit(fig);

    if isnan(nblocks) || nblocks <= 0
        tr = NaN;
        set(H.hTR, 'String', 'NA');
    else
        tr = nblocks * trUnit;
        set(H.hTR, 'String', sprintf('%.3f s', tr));
    end

    calcFrames = str2double(get(H.eCalcFrames, 'String'));
    if ~isnan(calcFrames) && ~isnan(tr)
        set(H.eCalcSec, 'String', sprintf('%.3f', calcFrames * tr));
    end

    % When not running, update the live-dt target display too.
    try
        if ~getappdata(fig, 'isRunning')
            localResetLiveTR(fig);
        end
    catch
    end
end

function localCalcSecToFrames(fig)
    if ~ishandle(fig)
        return;
    end

    H = guidata(fig);
    tr = localGetTR(fig);

    secVal = str2double(get(H.eCalcSec, 'String'));
    if isnan(secVal) || isnan(tr) || tr <= 0
        localAppendLog(fig, 'Calculator error: invalid seconds or TR.');
        return;
    end

    frames = secVal / tr;
    set(H.eCalcFrames, 'String', sprintf('%.2f', frames));
end

function localCalcFramesToSec(fig)
    if ~ishandle(fig)
        return;
    end

    H = guidata(fig);
    tr = localGetTR(fig);

    frameVal = str2double(get(H.eCalcFrames, 'String'));
    if isnan(frameVal) || isnan(tr) || tr <= 0
        localAppendLog(fig, 'Calculator error: invalid frames or TR.');
        return;
    end

    secVal = frameVal * tr;
    set(H.eCalcSec, 'String', sprintf('%.3f', secVal));
end

function tf = localIsZaberAvailableGUI()
    % Runtime check for the Zaber Motion toolbox.
    %
    % Deliberately does NOT use an import statement: MATLAB resolves
    % imports at parse time, which would prevent this GUI from opening
    % at all on a machine where the Zaber toolbox is not installed.

    persistent cachedTF

    if ~isempty(cachedTF)
        tf = cachedTF;
        return;
    end

    tf = false;

    try
        if exist('zaber.motion.Units', 'class') == 8
            tf = true;
        end
    catch
    end

    if ~tf
        try
            zaber.motion.Units.LENGTH_MILLIMETRES;
            tf = true;
        catch
            tf = false;
        end
    end

    cachedTF = tf;
end

function tr = localGetTR(fig)
    H = guidata(fig);

    if strcmpi(localGetAcquisitionMode(fig), 'bmode_live')
        tr = NaN;
        return;
    end

    nblocks = str2double(get(H.eNBlocks, 'String'));
    if isnan(nblocks) || nblocks <= 0
        tr = NaN;
    else
        tr = nblocks * localGetTRUnit(fig);
    end
end

function trUnit = localGetTRUnit(fig)
    % Seconds per nblocksImage unit.
    %   2D probe -> 0.02
    %   3D probe -> 0.03

    trUnit = 0.02;

    try
        H = guidata(fig);

        if ~isfield(H, 'pProbeType') || ~ishandle(H.pProbeType)
            return;
        end

        items = get(H.pProbeType, 'String');
        idx = get(H.pProbeType, 'Value');

        if iscell(items) && idx >= 1 && idx <= numel(items)
            if ~isempty(strfind(upper(items{idx}), '3D'))
                trUnit = 0.03;
            end
        end
    catch
    end
end

function probeStr = localGetProbeType(fig)
    % Returns '2D' or '3D'.

    probeStr = '2D';

    try
        H = guidata(fig);

        if ~isfield(H, 'pProbeType') || ~ishandle(H.pProbeType)
            return;
        end

        items = get(H.pProbeType, 'String');
        idx = get(H.pProbeType, 'Value');

        if iscell(items) && idx >= 1 && idx <= numel(items)
            if ~isempty(strfind(upper(items{idx}), '3D'))
                probeStr = '3D';
            end
        end
    catch
    end
end

function mode = localGetAcquisitionMode(fig)
    % Canonical values: doppler | functional | bmode_live | highres2d | highres3d
    mode = 'doppler';
    try
        H = guidata(fig);
        if ~isfield(H, 'pAcqMode') || ~ishandle(H.pAcqMode)
            return;
        end
        items = get(H.pAcqMode, 'String');
        idx = get(H.pAcqMode, 'Value');
        if ~iscell(items) || idx < 1 || idx > numel(items)
            return;
        end
        txt = lower(strtrim(items{idx}));
        if ~isempty(strfind(txt, 'functional')) || ~isempty(strfind(txt, 'time series')) || ...
                ~isempty(strfind(txt, 'timeseries'))
            mode = 'functional';
        elseif ~isempty(strfind(txt, 'b-mode')) || ~isempty(strfind(txt, 'bmode'))
            mode = 'bmode_live';
        elseif ~isempty(strfind(txt, 'high-res 2d')) || ~isempty(strfind(txt, 'highres 2d'))
            mode = 'highres2d';
        elseif ~isempty(strfind(txt, 'high-res 3d')) || ~isempty(strfind(txt, 'highres 3d'))
            mode = 'highres3d';
        else
            mode = 'doppler';
        end
    catch
        mode = 'doppler';
    end
end

function localPreparePreviewForMode(fig,mode)
try
    if ~ishandle(fig),return;end
    H=guidata(fig);
    setappdata(fig,'previewData',[]);
    setappdata(fig,'previewMode',mode);
    setappdata(fig,'previewMetadata',struct());
    try,set(H.hPreviewImage,'CData',zeros(32,32));set(H.axPreview,'CLim',[0 1]);catch,end
    try
        if strcmpi(mode,'bmode_live')
            set(H.bSavePreview,'String','SAVE B-MODE','Enable','on');
        elseif strcmpi(mode,'functional')
            set(H.bSavePreview,'String','FUNCTIONAL AUTO-SAVE','Enable','off');
        else
            set(H.bSavePreview,'String','SAVE LOW-RES','Enable','on');
        end
    catch
    end
    if strcmpi(mode,'bmode_live')
        ttl='Waiting for native B-Mode Live display...';info='B-Mode selected | waiting for live image';
    elseif strcmpi(mode,'functional')
        ttl='Functional fUSI time series | full movie auto-saves after scan';
        info='Functional mode | full Doppler time series saved automatically';
    else
        ttl='Waiting for native Doppler display...';info='Doppler selected | waiting for image';
    end
    try,title(H.axPreview,ttl,'Color',[1 1 1],'FontSize',9.5,'FontWeight','bold','Interpreter','none');catch,end
    try,set(H.hPreviewInfo,'String',info);catch,end
catch
end
end

function localOnAcqModeChanged(fig, doLog)
    if nargin < 2
        doLog = false;
    end
    if ~ishandle(fig)
        return;
    end

    H = guidata(fig);
    mode = localGetAcquisitionMode(fig);

    % V14: clear stale anatomy ONLY on a real user mode change (doLog=true).
    % localSetBusy(false) also calls this function after an acquisition merely
    % to refresh enabled/disabled controls.  V13 cleared the freshly mirrored
    % Doppler about two seconds after it appeared because of that refresh.
    if doLog && (strcmpi(mode,'doppler') || strcmpi(mode,'bmode_live') || strcmpi(mode,'functional'))
        localPreparePreviewForMode(fig,mode);
    end

    % SAVE remains available while idle even when no local preview exists:
    % pressing it can safely import the current static company view first.
    try
        if strcmpi(mode,'bmode_live')
            set(H.bSavePreview,'String','SAVE B-MODE');
            if ~localVendorIsBlocked(fig),set(H.bSavePreview,'Enable','on');end
        elseif strcmpi(mode,'doppler')
            set(H.bSavePreview,'String','SAVE LOW-RES');
            if ~localVendorIsBlocked(fig),set(H.bSavePreview,'Enable','on');end
        elseif strcmpi(mode,'functional')
            set(H.bSavePreview,'String','FUNCTIONAL AUTO-SAVE','Enable','off');
        else
            set(H.bSavePreview,'Enable','off');
        end
    catch
    end

    % Reset mode-controlled inputs first.
    try
        set(H.eNBlocks, 'Enable', 'on');
    catch
    end
    try
        set(H.pProbeType, 'Enable', 'on');
    catch
    end
    try
        set(H.eNFrames, 'Enable', 'on');
    catch
    end
    try
        set(H.eNTrials, 'Enable', 'on');
    catch
    end
    try
        set(H.ePause, 'Enable', 'on');
    catch
    end

    switch mode
        case 'doppler'
            % Company-style Doppler single-image preset.
            % Selecting Doppler immediately restores the requested quick
            % acquisition defaults: 5 Doppler images using 16 blocks/image.
            % The fields remain editable afterwards if a longer acquisition
            % is intentionally required.
            try
                set(H.eNFrames, 'String', '5');
            catch
            end
            try
                set(H.eNBlocks, 'String', '16');
            catch
            end

        case 'functional'
            % Standard functional fUSI Doppler time series. This restores the
            % original long-movie acquisition path instead of the 5-frame
            % quick-anatomy preset. 2500 frames x 16 blocks is the requested
            % 3D default (TR 0.480 s -> ~20 min); both fields remain editable.
            try
                set(H.eNFrames, 'String', '2500', 'Enable', 'on');
            catch
            end
            try
                set(H.eNBlocks, 'String', '16', 'Enable', 'on');
            catch
            end
            try
                set(H.eNTrials, 'String', '1', 'Enable', 'on');
            catch
            end

        case 'bmode_live'
            % B-mode uses the current scanner/probe configuration and runs
            % continuously until STOP is pressed in this Trigger Controller.
            % Frames/trials/blocks are not used for this preview path.
            try
                set(H.eNBlocks, 'Enable', 'off');
            catch
            end
            try
                set(H.eNFrames, 'Enable', 'off');
            catch
            end
            try
                set(H.eNTrials, 'Enable', 'off');
            catch
            end
            try
                set(H.ePause, 'Enable', 'off');
            catch
            end

        case 'highres2d'
            % V16 restores the known-working V13/V14 high-resolution default.
            % Keep 100 source frames exactly as in the working configuration.
            set(H.pProbeType, 'Value', 1, 'Enable', 'off');
            set(H.eNBlocks, 'String', '10', 'Enable', 'off');
            set(H.eNFrames, 'String', '100', 'Enable', 'on');

        case 'highres3d'
            % V16 restores the known-working V13/V14 high-resolution default.
            % Keep 100 source volumes exactly as in the working configuration.
            set(H.pProbeType, 'Value', 2, 'Enable', 'off');
            set(H.eNBlocks, 'String', '17', 'Enable', 'off');
            set(H.eNFrames, 'String', '100', 'Enable', 'on');
    end

    localUpdateTRDisplay(fig);
    localUpdateScanTrialNaming(fig);

    if doLog
        switch mode
            case 'doppler'
                localAppendLog(fig, ...
                    'Acquisition mode: Doppler / low-res anatomy preset (5 images, 16 blocks/image). Display in this GUI; use SAVE when wanted.');
            case 'functional'
                trNow = localGetTR(fig);
                if isfinite(trNow)
                    localAppendLog(fig, sprintf(['Acquisition mode: Functional fUSI / Time Series. Preset 2500 frames, 16 blocks/image ' ...
                        '(TR %.3f s; %.1f min for one scan). Full I movie auto-saves using the normal functional pipeline.'], ...
                        trNow, 2500*trNow/60));
                else
                    localAppendLog(fig, 'Acquisition mode: Functional fUSI / Time Series. Preset 2500 frames, 16 blocks/image. Full I movie auto-saves.');
                end
            case 'bmode_live'
                localAppendLog(fig, ['Acquisition mode: B-Mode Live. Uses the native company B-Mode LIVE control and stays on until STOP.']);
            case 'highres2d'
                localAppendLog(fig, 'Acquisition mode: High-Res 2D anatomy (10 blocks, 100 source frames; restored working V13/V14 path).');
            case 'highres3d'
                localAppendLog(fig, 'Acquisition mode: High-Res 3D anatomy (17 blocks, 100 source volumes; restored working V13/V14 path).');
        end
    end
end

% =========================================================================
% Motor estimation
% =========================================================================
function nPos = localEstimateMotorPositions(fig)
    H = guidata(fig);

    motorOn = logical(get(H.cMotorEnable, 'Value'));
    if ~motorOn
        nPos = 0;
        return;
    end

    modeVal = get(H.pMotorMode, 'Value');
    if modeVal == 1
        nPos = 1;
        return;
    end

    s0 = str2double(get(H.eMStart, 'String'));
    s1 = str2double(get(H.eMEnd, 'String'));
    st = str2double(get(H.eMStep, 'String'));

    if any(isnan([s0 s1 st])) || st <= 0
        nPos = 1;
        return;
    end

    vals = localBuildAbsolutePositionList(s0, s1, st);
    nPos = numel(vals);
end

function nUsed = localEstimateMotorVisitsPerTrial(fig)
    H = guidata(fig);

    motorOn = logical(get(H.cMotorEnable, 'Value'));
    if ~motorOn
        nUsed = 0;
        return;
    end

    modeVal = get(H.pMotorMode, 'Value');

    if modeVal == 1
        nUsed = 1;
    else
        nUsed = localEstimateMotorPositions(fig);
    end
end

function vals = localBuildAbsolutePositionList(startPos, endPos, stepVal)
    stepVal = abs(stepVal);

    if abs(endPos - startPos) < eps
        vals = startPos;
        return;
    end

    if endPos < startPos
        stepVal = -stepVal;
    end

    vals = startPos:stepVal:endPos;

    if isempty(vals)
        vals = [startPos endPos];
    else
        if abs(vals(end) - endPos) > 1e-12
            vals = [vals endPos];
        end
    end
end

function starts = localBuildCycleStarts(frameStart, repeatOn, repeatEvery, nFramesTotal)
    if isnan(frameStart) || frameStart < 1
        frameStart = 1;
    end

    frameStart = round(frameStart);

    if ~repeatOn || isnan(repeatEvery) || repeatEvery < 1
        starts = frameStart;
    else
        starts = frameStart:max(1, round(repeatEvery)):nFramesTotal;
    end
end

function localOnMotorFieldChanged(fig)
    if ~ishandle(fig)
        return;
    end
    localRefreshMotorPanel(fig);
    localTryReadMotorPos(fig, true);
end

% =========================================================================
% Motor position read
% =========================================================================
function localTryReadMotorPos(fig, quiet)
    if ~ishandle(fig)
        return;
    end

    H = guidata(fig);

    if ~logical(get(H.cMotorEnable, 'Value'))
        localSetCurrentPos(fig, NaN);
        return;
    end

    comName = strtrim(get(H.eMotorCom, 'String'));
    if isempty(comName)
        localSetCurrentPos(fig, NaN);
        return;
    end

    connection = [];
    try
        % IMPORTANT: no "import zaber.motion..." here.
        % MATLAB resolves imports at PARSE time, so a static import would
        % stop this entire GUI file from loading on a machine without the
        % Zaber Motion toolbox. Fully qualified names are used instead.

        if ~localIsZaberAvailableGUI()
            localSetCurrentPos(fig, NaN);
            if ~quiet
                localAppendLog(fig, ...
                    'Zaber Motion toolbox not found: motor position cannot be read.');
            end
            return;
        end

        connection = zaber.motion.ascii.Connection.openSerialPort(comName);
        deviceList = connection.detectDevices();

        if isempty(deviceList)
            localSetCurrentPos(fig, NaN);
            if ~quiet
                localAppendLog(fig, sprintf('No motor detected on %s.', comName));
            end
            try
                connection.close();
            catch
            end
            return;
        end

        deviceIdx = 1;
        axisIdx = 1;

        if numel(deviceList) < deviceIdx
            error('Requested device index %d not found on %s.', deviceIdx, comName);
        end

        device = deviceList(deviceIdx);

        try
            nAxes = device.getAxisCount();
        catch
            nAxes = 1;
        end

        if axisIdx > nAxes
            error('Requested axis index %d not found. Device has %d axes.', axisIdx, nAxes);
        end

        axis = device.getAxis(axisIdx);
        posMM = axis.getPosition(zaber.motion.Units.LENGTH_MILLIMETRES);

    setappdata(fig, 'motorCurrentPosAbsMM', posMM);
localSetCurrentPos(fig, posMM);

try
    set(H.eMStart, 'String', sprintf('%.3f', posMM));
catch
end

try
    localRefreshMotorPanel(fig);
catch
end

if ~quiet
    localAppendLog(fig, sprintf('Current motor position read from %s: %.3f mm', comName, posMM));
end
        try
            connection.close();
        catch
        end

    catch ME
        localSetCurrentPos(fig, NaN);
        if ~quiet
            localAppendLog(fig, sprintf('Could not read motor position: %s', ME.message));
        end
        try
            if ~isempty(connection)
                connection.close();
            end
        catch
        end
    end
end

% =========================================================================
% Start / stop / close
% =========================================================================
function localOnStart(fig)
    if ~ishandle(fig)
        return;
    end

    if getappdata(fig, 'isRunning')
        return;
    end

    if localVendorIsBlockedNow(fig)
        localSetStatus(fig,'OpenfUS hardware/software busy','notready');
        localSetReady(fig,false);
        localAppendLog(fig,'START blocked: native OpenfUS is currently busy/not ready.');
        return;
    end

    try
        cfg = localCollectCfg(fig);
    catch ME
        localSetStatus(fig, ['Invalid settings: ' ME.message], 'error');
        localSetReady(fig, false);
        localAppendLog(fig, ['Invalid settings: ' ME.message]);
        return;
    end

    % Target frame count used by the top-right live progress display.
    % Store this before acquisition starts so frame callbacks can show
    % frame/target, percentage and elapsed seconds.
    try
        setappdata(fig, 'liveTargetFrames', max(1, round(cfg.n_frames)));
    catch
        setappdata(fig, 'liveTargetFrames', NaN);
    end

    setappdata(fig, 'stopRequested', false);
    setappdata(fig, 'isRunning', true);

  localSetBusy(fig, true);
localSetFrame(fig, 0);
localResetLiveTR(fig);
localSetTrial(fig, 0, cfg.n_trials);
localSetMotor(fig, 0, localEstimateMotorVisitsPerTrial(fig), NaN, 0);
localSetStatus(fig, 'Starting experiment...', 'running');
    localSetReady(fig, false);
    localAppendLog(fig, 'Starting experiment...');

    cfg.gui = struct();
    cfg.gui.statusFcn = @(msg, state)localSafeGuiStatus(fig, msg, state);
    cfg.gui.logFcn = @(msg)localSafeGuiLog(fig, msg);
 cfg.gui.frameFcn = @(frameIdx)localSafeGuiFrame(fig, frameIdx);
cfg.gui.trialFcn = @(iTrial, nTrials)localSafeGuiTrial(fig, iTrial, nTrials);
cfg.gui.motorStepFcn = @(idx, total, absPosMM, frameIdx)localSafeGuiMotor(fig, idx, total, absPosMM, frameIdx);
cfg.gui.timingFcn = @(targetDt, meanDt, devPct, elapsedSec, nFrames)localSafeGuiTiming(fig, targetDt, meanDt, devPct, elapsedSec, nFrames);
cfg.gui.stopRequestedFcn = @()localSafeStopRequested(fig);
cfg.gui.previewFcn = @(I,mode,md)localSafeGuiPreview(fig,I,mode,md);

% Keep destination/settings for the embedded SAVE button.  The preview data
% themselves are stored in appdata by localSafeGuiPreview.
try
    saveCfg = rmfield(cfg,'gui');
catch
    saveCfg = cfg;
end
setappdata(fig,'previewSaveCfg',saveCfg);

% ---------------------------------------------------------------------
% Live frame/progress/TR monitoring
% ---------------------------------------------------------------------
% Functional fUSI is a long time-series acquisition.  In this mode the user
% needs live progress, elapsed seconds and measured TR even when no StimBox,
% PulsePal or continuous motor is enabled.  Therefore Functional fUSI forces
% the existing lightweight processRF callback.  The callback does NOT alter
% RF data; it is used for frame indexing/STOP/accessories and GUI telemetry.
%
% Other modes retain the stable V20 behaviour and do not force processRF just
% for the GUI.
if strcmpi(cfg.acquisition_mode, 'functional')
    cfg.gui.forceProcessRFForLiveFrames = true;

    % Aim for approximately one visible GUI refresh per second.  The callback
    % itself still runs at the scanner frame rate, but obj.onFrameFcn is only
    % invoked every N frames.  This keeps the UI responsive without asking
    % MATLAB to redraw hundreds/thousands of times.
    targetTR = double(cfg.nblocksImage) * double(cfg.tr_unit_s);
    if isempty(targetTR) || ~isfinite(targetTR) || targetTR <= 0
        cfg.gui.frameUpdateEvery = 2;
        monitorSec = NaN;
    else
        cfg.gui.frameUpdateEvery = max(1, round(1.0 / targetTR));
        monitorSec = cfg.gui.frameUpdateEvery * targetTR;
    end

    if isfinite(monitorSec)
        localAppendLog(fig, sprintf( ...
            'Functional fUSI live monitor enabled: progress + elapsed time + measured TR update about every %.2f s.', ...
            monitorSec));
    else
        localAppendLog(fig, ...
            'Functional fUSI live monitor enabled: progress + elapsed time + measured TR are active.');
    end
else
    cfg.gui.forceProcessRFForLiveFrames = false;
    cfg.gui.frameUpdateEvery = 10;
end
  try
    vfUSI_StimBox_TTL_EACH_FRAME_OR_TRIGGER_ACCESSORIES_COMMAND(cfg);

    if ishandle(fig)
        setappdata(fig, 'stopRequested', false);

        % Clear journal note after a completed run so next scan starts fresh
        setappdata(fig, 'journalNote', '');
        localUpdateJournalNoteButton(fig);

        localSetStatus(fig, 'Ready for next run', 'idle');
        localSetReady(fig, true);
        localAppendLog(fig, 'Journal note cleared after completed scan run.');
    end

catch ME
        if ishandle(fig)
            localSetStatus(fig, ['Error: ' ME.message], 'error');
            localSetReady(fig, false);
            localAppendLog(fig, ['ERROR: ' ME.message]);
        end
    end

    if ishandle(fig)
        setappdata(fig, 'isRunning', false);
        localSetBusy(fig, false);
        localTryReadMotorPos(fig, true);
    end
end

function localOnStop(fig)
    if ~ishandle(fig)
        return;
    end

    if ~getappdata(fig, 'isRunning')
        return;
    end

    setappdata(fig, 'stopRequested', true);
    localSetStatus(fig, 'Stop requested...', 'notready');
    localSetReady(fig, false);
    localAppendLog(fig, 'Stop requested by user.');
end

function localOnClose(fig)
    if ~ishandle(fig)
        return;
    end

    if getappdata(fig, 'isRunning')
        setappdata(fig, 'stopRequested', true);
        localSetStatus(fig, 'Stop requested before close...', 'notready');
        localSetReady(fig, false);
        localAppendLog(fig, 'Close requested while running. Stop requested first.');
        return;
    end

    localStopVendorMonitor(fig);
    delete(fig);
end


% =========================================================================
% V19 native OpenfUS monitor
% =========================================================================
function localStartVendorMonitor(fig)
if ~ishandle(fig),return;end
try
    old=getappdata(fig,'vendorMonitorTimer');
    if ~isempty(old) && isvalid(old),return;end
catch
end
try
    tm=timer('ExecutionMode','fixedSpacing','Period',0.75,'StartDelay',1.0, ...
        'BusyMode','drop','TimerFcn',@(src,evt)localVendorMonitorTick(fig,src));
    setappdata(fig,'vendorMonitorTimer',tm);
    start(tm);
catch ME
    try,localAppendLog(fig,['OpenfUS status monitor unavailable: ' ME.message]);catch,end
end
end

function localStopVendorMonitor(fig)
tm=[];
try,tm=getappdata(fig,'vendorMonitorTimer');catch,end
try
    if ~isempty(tm)&&isvalid(tm),stop(tm);delete(tm);end
catch
end
try,setappdata(fig,'vendorMonitorTimer',[]);catch,end
end

function localVendorMonitorTick(fig,tm)
% Read-only watcher. It NEVER invokes a company acquisition callback.
if ~ishandle(fig)
    try,stop(tm);delete(tm);catch,end
    return;
end
try
    if getappdata(fig,'isRunning')
        return;
    end
catch
end

try
    st=vfUSI_OpenfUS_UIBridge('status',[],struct());
catch
    return;
end
if ~isstruct(st),return;end

blocked=false;busy=false;mode='';
try,busy=logical(st.busy);catch,end
try,blocked=busy || ~logical(st.ready);catch,blocked=busy;end
try,mode=char(st.mode);catch,end
if isempty(mode),mode='unknown';end

prevBlocked=false;wasAcq=false;idleConfirm=0;
try,prevBlocked=logical(getappdata(fig,'externalVendorBlocked'));catch,end
try,wasAcq=logical(getappdata(fig,'externalVendorWasAcquiring'));catch,end
try,idleConfirm=getappdata(fig,'externalVendorIdleConfirm');catch,idleConfirm=0;end
if isempty(idleConfirm)||~isnumeric(idleConfirm),idleConfirm=0;end

H=guidata(fig);

if blocked
    setappdata(fig,'externalVendorBlocked',true);
    setappdata(fig,'externalVendorBusy',busy);
    setappdata(fig,'externalVendorIdleConfirm',0);
    try,set(H.bStart,'Enable','off');catch,end

    if busy
        setappdata(fig,'externalVendorWasAcquiring',true);
        setappdata(fig,'externalVendorMode',mode);

        if ~prevBlocked
            localRefreshPreviewSaveCfgFromGui(fig);
            localPreparePreviewForExternalRun(fig,mode);
            localSetReady(fig,false);
            localSetStatus(fig,['OpenfUS busy: ' localExternalModeLabel(mode)],'notready');
            localAppendLog(fig,['Native company OpenfUS acquisition detected: ' localExternalModeLabel(mode) ...
                '. Trigger Controller marked NOT READY.']);
            setappdata(fig,'externalVendorMirrorTried',false);
        end

        mirrorTried=false;
        try,mirrorTried=logical(getappdata(fig,'externalVendorMirrorTried'));catch,end
        if ~mirrorTried && ~isempty(strfind(lower(mode),'bmode'))
            setappdata(fig,'externalVendorMirrorTried',true);
            try
                SCAN=[];try,SCAN=evalin('base','SCAN');catch,end
                [Id,md]=vfUSI_OpenfUS_UIBridge('direct_preview',SCAN,struct(),mode);
                if ~isempty(Id)
                    localSafeGuiPreview(fig,Id,'bmode_live',md);
                    try,set(H.bSavePreview,'Enable','off');catch,end
                    localAppendLog(fig,'Mirroring externally started B-Mode through direct OpenfUS CData.');
                end
            catch
            end
        end
    else
        if ~prevBlocked
            localSetReady(fig,false);
            localSetStatus(fig,'OpenfUS hardware/software not ready','notready');
            try
                reason=char(st.reason);
                if ~isempty(reason),localAppendLog(fig,['Native OpenfUS NOT READY: ' reason]);end
            catch
            end
        end
    end
    return;
end

if prevBlocked && wasAcq
    idleConfirm=idleConfirm+1;
    setappdata(fig,'externalVendorIdleConfirm',idleConfirm);
    if idleConfirm<2
        localSetReady(fig,false);
        localSetStatus(fig,'OpenfUS finishing acquisition...','notready');
        try,set(H.bStart,'Enable','off');catch,end
        return;
    end

    prevMode='unknown';
    try,prevMode=char(getappdata(fig,'externalVendorMode'));catch,end
    localRefreshPreviewSaveCfgFromGui(fig);

    try
        SCAN=[];try,SCAN=evalin('base','SCAN');catch,end
        [I,md]=vfUSI_OpenfUS_UIBridge('capture_current',SCAN,struct(),prevMode);
        if ~isempty(I)
            localSafeGuiPreview(fig,I,localCanonicalPreviewMode(prevMode),md);
            localAppendLog(fig,['Imported completed company OpenfUS ' localExternalModeLabel(prevMode) ...
                ' into Trigger Controller. Use SAVE to keep it with the standard naming/folder convention.']);
        else
            localAppendLog(fig,['Company OpenfUS ' localExternalModeLabel(prevMode) ...
                ' finished, but no rendered anatomy view could be imported automatically. SAVE will retry once.']);
        end
    catch ME
        localAppendLog(fig,['Company-view import warning: ' ME.message]);
    end
end

if prevBlocked
    setappdata(fig,'externalVendorBlocked',false);
    setappdata(fig,'externalVendorBusy',false);
    setappdata(fig,'externalVendorWasAcquiring',false);
    setappdata(fig,'externalVendorIdleConfirm',0);
    setappdata(fig,'externalVendorMirrorTried',false);
    try,set(H.bStart,'Enable','on');catch,end
    localSetReady(fig,true);
    localSetStatus(fig,'Ready for next run','idle');
    localAppendLog(fig,'Native OpenfUS is ready again. Trigger Controller READY restored.');
end
end

function localPreparePreviewForExternalRun(fig,mode)
if ~ishandle(fig),return;end
try
    H=guidata(fig);
    pm=localCanonicalPreviewMode(mode);
    setappdata(fig,'previewData',[]);
    setappdata(fig,'previewMode',pm);
    setappdata(fig,'previewMetadata',struct());
    set(H.hPreviewImage,'CData',zeros(32,32));
    set(H.axPreview,'CLim',[0 1]);
    if strcmpi(pm,'bmode_live')
        ttl='Company B-Mode Live running...';
        info='Company B-Mode running | waiting for safe mirror/final frame';
        set(H.bSavePreview,'String','SAVE B-MODE','Enable','off');
    else
        ttl='Company Doppler acquisition running...';
        info='Company Doppler running | waiting for completed display';
        set(H.bSavePreview,'String','SAVE LOW-RES','Enable','off');
    end
    title(H.axPreview,ttl,'Color',[1 1 1],'FontSize',9.5,'FontWeight','bold','Interpreter','none');
    set(H.hPreviewInfo,'String',info);
catch
end
end

function mode=localCanonicalPreviewMode(mode)
m=lower(char(mode));
if ~isempty(strfind(m,'bmode')) || ~isempty(strfind(m,'b-mode'))
    mode='bmode_live';
else
    mode='doppler';
end
end

function s=localExternalModeLabel(mode)
if ~isempty(strfind(lower(char(mode)),'bmode'))
    s='B-Mode Live';
elseif ~isempty(strfind(lower(char(mode)),'doppler'))
    s='Doppler';
else
    s='acquisition';
end
end

% =========================================================================
% Defaults
% =========================================================================
% =========================================================================
function localLoadDefaults(fig)
    H = guidata(fig);

    
set(H.pSaveOwner, 'Value', 1);   % 1 Soner, 2 Yan, 3 Kelly, 4 Xuming, 5 Pascal, 6 Guest
    set(H.eXpName, 'String', 'RGRO_yymmdd_1024_MM_B6J_ID');
    set(H.eNFrames, 'String', '9000');
    set(H.eNTrials, 'String', '1');
    set(H.eNBlocks, 'String', '16');
    set(H.ePause, 'String', '1');
    set(H.pProbeType, 'Value', 1);   % 1 = 2D probe, 2 = 3D probe
    set(H.pAcqMode, 'Value', 1);     % 1 = Doppler

    % StimBox
    set(H.cStimEnable, 'Value', 0);
    set(H.eStimCom, 'String', 'COM9');
    set(H.eStimBaud, 'String', '9600');
    set(H.eStimStart, 'String', '20');
set(H.eStimDur, 'String', '10');
set(H.cStimRepeat, 'Value', 1);
set(H.eStimRepeatEvery, 'String', '50');
    set(H.cD3, 'Value', 0);
    set(H.cD5, 'Value', 1);
    set(H.cD6, 'Value', 0);
    set(H.cStimVerbose, 'Value', 1);

    % PulsePal
    % These defaults are a paper-like starter example:
    % pulse width = 0.5 ms, frequency = 4 Hz, low starting voltage
    set(H.cPPEnable, 'Value', 0);
    set(H.ePPCom, 'String', 'COM14');
    set(H.ePPChan, 'String', '1');
    set(H.ePPStart, 'String', '100');
    set(H.ePPDurFrames, 'String', '1');
    set(H.cPPRepeat, 'Value', 0);
    set(H.ePPRepeatEvery, 'String', '100');

    % Monophasic starter defaults
    set(H.ePPVolt1, 'String', '5.0');       % start low; actual current depends on load impedance
    set(H.ePPDur1, 'String', '0.0005');     % 0.5 ms pulse width
    set(H.ePPIPI, 'String', '0.25');        % 4 Hz = 0.25 s interpulse interval
    set(H.ePPTrainDur, 'String', '1.0');    % total train duration after one trigger
    set(H.ePPRest, 'String', '0');
    set(H.cPPBiphasic, 'Value', 0);

    % Biphasic-only / advanced defaults
    set(H.ePPInterPhase, 'String', '0.0001');
    set(H.ePPVolt2, 'String', '-5.0');
    set(H.ePPDur2, 'String', '0.0005');
    set(H.ePPBurstDur, 'String', '0');
    set(H.ePPInterBurst, 'String', '0.100');
    set(H.ePPTrainDelay, 'String', '0');

    % Currently unused in your software-triggered workflow
    set(H.pPPCustomID, 'Value', 1);
    set(H.pPPCustomTarget, 'Value', 1);
    set(H.cPPCustomLoop, 'Value', 0);
    set(H.cPPLink1, 'Value', 0);
    set(H.cPPLink2, 'Value', 0);
    set(H.pPPTrigMode1, 'Value', 1);
    set(H.pPPTrigMode2, 'Value', 1);

    % Motor
  set(H.cMotorEnable, 'Value', 0);
set(H.pMotorAcqMode, 'Value', 2);   % 1 = continuous, 2 = split per slice
set(H.pMotorMode, 'Value', 2);      % stepped positions
set(H.eMotorCom, 'String', 'COM8');

set(H.eMotorFrameStart, 'String', '0');
set(H.eMotorFrameDur, 'String', '9000');
set(H.cMotorRepeat, 'Value', 0);
set(H.eMotorRepeatEvery, 'String', '100');

set(H.eMStart, 'String', '0');
set(H.eMEnd, 'String', '30');
set(H.eMStep, 'String', '0.5');

set(H.eMFrames, 'String', '50');    % frames per slice
set(H.cPeriodic, 'Value', 0);
set(H.cReturnZero, 'Value', 1);

set(H.cMotorFastPipeline, 'Value', 1);
set(H.eMotorSettle, 'String', '0.02');
    % Calculator
    set(H.eCalcSec, 'String', '10');
    set(H.eCalcFrames, 'String', '31');

    localUpdateTRDisplay(fig);
    localRestorePulsePalTab(fig);
    localRefreshStimBoxPanel(fig);
    localRefreshPulsePalPanel(fig);
    localRefreshMotorPanel(fig);
    localOnAcqModeChanged(fig, false);
    localTryReadMotorPos(fig, true);

    localAppendLog(fig, 'Defaults loaded.');
    localSetReady(fig, true);
    localSetStatus(fig, 'Idle', 'idle');
end

% =========================================================================
% Config collection
% =========================================================================
function cfg = localCollectCfg(fig)
    H = guidata(fig);

    cfg = struct();
    
    if isappdata(fig, 'journalNote')
    cfg.journal_note = getappdata(fig, 'journalNote');
else
    cfg.journal_note = '';
end
% Acquisition
saveOwners = get(H.pSaveOwner, 'String');
saveOwnerIdx = get(H.pSaveOwner, 'Value');
cfg.save_owner = strtrim(saveOwners{saveOwnerIdx});
% HUMOR_OUTPUT_ROOT_CDATA_GUI_V1
cfg.output_root = 'C:\Data';

    cfg.xp_name      = strtrim(get(H.eXpName, 'String'));
    cfg.acquisition_mode = localGetAcquisitionMode(fig);
    cfg.n_frames     = localParseNumeric(get(H.eNFrames, 'String'), 'Frames/scan');
    cfg.n_trials     = localParseNumeric(get(H.eNTrials, 'String'), 'Scans / trials');
    cfg.nblocksImage = localParseNumeric(get(H.eNBlocks, 'String'), 'nblocksImage');
    cfg.time_pause   = localParseNumeric(get(H.ePause, 'String'), 'Pause');

    % Probe type drives the TR unit: 2D = 0.02 s, 3D = 0.03 s per block.
    cfg.probe_type = localGetProbeType(fig);
    cfg.tr_unit_s  = localGetTRUnit(fig);

    % The vendor HR demos use fixed acquisition blocks and probe families.
    if strcmpi(cfg.acquisition_mode, 'highres2d')
        cfg.probe_type = '2D';
        cfg.tr_unit_s = 0.02;
        cfg.nblocksImage = 10;
    elseif strcmpi(cfg.acquisition_mode, 'highres3d')
        cfg.probe_type = '3D';
        cfg.tr_unit_s = 0.03;
        cfg.nblocksImage = 17;
    end

    % StimBox
    cfg.stimbox = struct();
    cfg.stimbox.enable = logical(get(H.cStimEnable, 'Value'));
    cfg.stimbox.com = strtrim(get(H.eStimCom, 'String'));
    cfg.stimbox.baud = localParseNumeric(get(H.eStimBaud, 'String'), 'StimBox baud');
    cfg.stimbox.start_frame = localParseNumeric(get(H.eStimStart, 'String'), 'StimBox frame start');
    cfg.stimbox.frame_duration = localParseNumeric(get(H.eStimDur, 'String'), 'StimBox active frames');
    cfg.stimbox.repeat_enable = logical(get(H.cStimRepeat, 'Value'));
    cfg.stimbox.repeat_interval_frames = localParseNumeric(get(H.eStimRepeatEvery, 'String'), 'StimBox repeat after frames');
    cfg.stimbox.d3_enable = logical(get(H.cD3, 'Value'));
    cfg.stimbox.d5_enable = logical(get(H.cD5, 'Value'));
    cfg.stimbox.d6_enable = logical(get(H.cD6, 'Value'));
    cfg.stimbox.verbose = logical(get(H.cStimVerbose, 'Value'));

    % legacy fields retained
    cfg.stimbox.d3_trig = NaN;
    cfg.stimbox.d5_trig = NaN;
    cfg.stimbox.d6_trig = NaN;

    % PulsePal
    cfg.pulsepal = struct();
    cfg.pulsepal.enable = logical(get(H.cPPEnable, 'Value'));
    cfg.pulsepal.com = strtrim(get(H.ePPCom, 'String'));
    cfg.pulsepal.channel = localParseNumeric(get(H.ePPChan, 'String'), 'PulsePal channel');
    cfg.pulsepal.start_frame = localParseNumeric(get(H.ePPStart, 'String'), 'PulsePal frame start');
    cfg.pulsepal.frame_duration = localParseNumeric(get(H.ePPDurFrames, 'String'), 'PulsePal active frames');
    cfg.pulsepal.repeat_enable = logical(get(H.cPPRepeat, 'Value'));
    cfg.pulsepal.repeat_interval_frames = localParseNumeric(get(H.ePPRepeatEvery, 'String'), 'PulsePal repeat after frames');

    cfg.pulsepal.is_biphasic           = logical(get(H.cPPBiphasic, 'Value'));
    cfg.pulsepal.phase1_voltage        = localParseNumeric(get(H.ePPVolt1, 'String'), 'PulsePal phase1 voltage');
    cfg.pulsepal.phase1_duration_s     = localParseNumeric(get(H.ePPDur1, 'String'), 'PulsePal phase1 duration');
    cfg.pulsepal.interphase_interval_s = localParseNumeric(get(H.ePPInterPhase, 'String'), 'PulsePal interphase interval');
    cfg.pulsepal.phase2_voltage        = localParseNumeric(get(H.ePPVolt2, 'String'), 'PulsePal phase2 voltage');
    cfg.pulsepal.phase2_duration_s     = localParseNumeric(get(H.ePPDur2, 'String'), 'PulsePal phase2 duration');
    cfg.pulsepal.resting_voltage       = localParseNumeric(get(H.ePPRest, 'String'), 'PulsePal resting voltage');
    cfg.pulsepal.interpulse_interval_s = localParseNumeric(get(H.ePPIPI, 'String'), 'PulsePal inter-pulse interval');
    cfg.pulsepal.burst_duration_s      = localParseNumeric(get(H.ePPBurstDur, 'String'), 'PulsePal burst duration');
    cfg.pulsepal.interburst_interval_s = localParseNumeric(get(H.ePPInterBurst, 'String'), 'PulsePal inter-burst interval');
    cfg.pulsepal.train_delay_s         = localParseNumeric(get(H.ePPTrainDelay, 'String'), 'PulsePal train delay');
    cfg.pulsepal.train_duration_s      = localParseNumeric(get(H.ePPTrainDur, 'String'), 'PulsePal train duration');
     % -------------------------------------------------------------
    % Current controller mode:
    % PulsePal is SOFTWARE-triggered from the scan callback by
    % TriggerPulsePal(channel) at selected frame(s).
    %
    % Therefore we keep external trigger links OFF and custom train OFF
    % until a real external-trigger mode and custom-train upload UI exist.
    % -------------------------------------------------------------
    cfg.pulsepal.custom_train_id       = 0;
    cfg.pulsepal.custom_train_target   = 0;
    cfg.pulsepal.custom_train_loop     = false;
    cfg.pulsepal.link_trigger_ch1      = false;
    cfg.pulsepal.link_trigger_ch2      = false;
    cfg.pulsepal.trigger_mode1         = 0;
    cfg.pulsepal.trigger_mode2         = 0;

    % Motor
    cfg.motor = struct();
    cfg.motor.enable = logical(get(H.cMotorEnable, 'Value'));
motorAcqItems = get(H.pMotorAcqMode, 'String');
motorAcqIdx = get(H.pMotorAcqMode, 'Value');
motorAcqText = lower(strtrim(motorAcqItems{motorAcqIdx}));

if ~isempty(strfind(motorAcqText, 'continuous'))
    cfg.motor.acquisition_mode = 'continuous';
else
    cfg.motor.acquisition_mode = 'split';
end
    if get(H.pMotorMode, 'Value') == 1
        cfg.motor.mode = 'single';
    else
        cfg.motor.mode = 'stepped';
    end

    cfg.motor.com = strtrim(get(H.eMotorCom, 'String'));
    cfg.motor.frame_start = localParseNumeric(get(H.eMotorFrameStart, 'String'), 'Motor active from frame');
    cfg.motor.frame_duration = localParseNumeric(get(H.eMotorFrameDur, 'String'), 'Motor active for frames');
    cfg.motor.repeat_enable = logical(get(H.cMotorRepeat, 'Value'));
    cfg.motor.repeat_interval_frames = localParseNumeric(get(H.eMotorRepeatEvery, 'String'), 'Motor repeat after frames');

    % IMPORTANT: absolute positions
    cfg.motor.start_mm = localParseNumeric(get(H.eMStart, 'String'), 'Motor start position');
    cfg.motor.end_mm = localParseNumeric(get(H.eMEnd, 'String'), 'Motor end position');

    % compatibility fallback
    cfg.motor.start_offset_mm = cfg.motor.start_mm;
    cfg.motor.end_offset_mm = cfg.motor.end_mm;

    cfg.motor.step_mm = localParseNumeric(get(H.eMStep, 'String'), 'Motor step size');
 cfg.motor.frames_per_position = localParseNumeric(get(H.eMFrames, 'String'), 'Frames per slice');
    cfg.motor.periodic = logical(get(H.cPeriodic, 'Value'));
    cfg.motor.return_to_zero = logical(get(H.cReturnZero, 'Value'));

    % -------------------------------------------------------------
    % Slice timing
    %
    % settle_pause_s : pause after the stage reports idle, before the
    %                  next acquisition starts. Keep small.
    % fast_pipeline  : overlap the next motor move with the current
    %                  file save so there is no dead time between
    %                  slices.
    % -------------------------------------------------------------
    settleVal = localParseNumericNoError(get(H.eMotorSettle, 'String'));
    if isnan(settleVal) || settleVal < 0
        settleVal = 0.02;
    end
    cfg.motor.settle_pause_s = settleVal;

    cfg.motor.fast_pipeline = logical(get(H.cMotorFastPipeline, 'Value'));

    % In continuous mode, do not block the frame callback during travel.
    cfg.motor.wait_until_idle_in_scan = false;

    % Optional compatibility metadata
    if cfg.stimbox.enable
        cfg.stim_start = cfg.stimbox.start_frame;
        cfg.stim_duration = cfg.stimbox.frame_duration;
    elseif cfg.pulsepal.enable
        cfg.stim_start = cfg.pulsepal.start_frame;
        cfg.stim_duration = cfg.pulsepal.frame_duration;
    else
        cfg.stim_start = NaN;
        cfg.stim_duration = NaN;
    end

    % Legacy stim struct
    cfg.stim = struct();
    if cfg.stimbox.enable && ~cfg.pulsepal.enable
        cfg.stim.device = 'stimbox';
    elseif cfg.pulsepal.enable && ~cfg.stimbox.enable
        cfg.stim.device = 'pulsepal';
    elseif cfg.stimbox.enable && cfg.pulsepal.enable
        cfg.stim.device = 'hybrid';
    else
        cfg.stim.device = 'none';
    end
end

function v = localParseNumeric(s, labelStr)
    v = str2double(strtrim(s));
    if isnan(v)
        error('%s must be numeric.', labelStr);
    end
end

function v = localParseNumericNoError(s)
    v = str2double(strtrim(s));
    if isnan(v)
        v = NaN;
    end
end

% =========================================================================
% Busy state
% =========================================================================
function localSetBusy(fig, tf)
    if ~ishandle(fig)
        return;
    end

    H = guidata(fig);

 if tf
    localSetHandleGroup(H.inputHandles, false);
    set(H.bStart, 'Enable', 'off');
    set(H.bStop, 'Enable', 'on');
    set(H.bDefaults, 'Enable', 'off');
    set(H.bHelp, 'Enable', 'off');
else
    localSetHandleGroup(H.inputHandles, true);
    set(H.bStart, 'Enable', 'on');
    set(H.bStop, 'Enable', 'on');
    set(H.bDefaults, 'Enable', 'on');
    set(H.bHelp, 'Enable', 'on');

        localRefreshStimBoxPanel(fig);
        localRefreshPulsePalPanel(fig);
        localRefreshMotorPanel(fig);
        localOnAcqModeChanged(fig, false);
    end

    drawnow limitrate;
end

% =========================================================================
% Status widgets
% =========================================================================
function localSetStatus(fig, msg, state)
    if ~ishandle(fig)
        return;
    end

    H = guidata(fig);
    C = H.C;

    switch lower(state)
        case 'ready'
            bg = C.ready;
        case 'notready'
            bg = C.notready;
        case 'running'
            bg = C.running;
        case 'error'
            bg = C.error;
        otherwise
            bg = C.idle;
    end

    set(H.hStatus, 'String', ['Status: ' msg], 'BackgroundColor', bg);
    drawnow limitrate;
end

function localSetReady(fig, tfReady)
    if ~ishandle(fig)
        return;
    end

    H = guidata(fig);
    C = H.C;

    if tfReady
        set(H.hReady, 'String', 'READY', 'BackgroundColor', C.ready);
    else
        set(H.hReady, 'String', 'NOT READY', 'BackgroundColor', C.notready);
    end
    drawnow limitrate;
end

function localSetFrame(fig, frameIdx, elapsedSec)
    if ~ishandle(fig)
        return;
    end

    if nargin < 3 || isempty(elapsedSec) || isnan(elapsedSec)
        elapsedSec = NaN;

        try
            if isappdata(fig, 'liveTRStats')
                S = getappdata(fig, 'liveTRStats');
                if isstruct(S) && isfield(S, 'elapsedSec')
                    elapsedSec = S.elapsedSec;
                end
            end
        catch
        end
    end

    H = guidata(fig);

    % Target count for percentage/progress.
    targetFrames = NaN;
    try
        if isappdata(fig, 'liveTargetFrames')
            targetFrames = double(getappdata(fig, 'liveTargetFrames'));
        end
    catch
        targetFrames = NaN;
    end

    if isnan(elapsedSec)
        elapsedTxt = '--.-s';
    else
        elapsedTxt = sprintf('%.1fs', elapsedSec);
    end

    if isfinite(targetFrames) && targetFrames >= 1
        targetFrames = max(1, round(targetFrames));
        pct = 100 * double(frameIdx) / double(targetFrames);
        pct = max(0, min(100, pct));
        % Two compact lines fit the header box more reliably than the old
        % three-line layout and make percent completion immediately visible.
        txt = sprintf('%d/%d  %.1f%%\n%s', ...
            round(frameIdx), targetFrames, pct, elapsedTxt);
    else
        txt = sprintf('%d\n%s', round(frameIdx), elapsedTxt);
    end

    set(H.hFrame, 'String', txt);

    drawnow limitrate;
end

function localSetTrial(fig, iTrial, nTrials)
    if ~ishandle(fig)
        return;
    end

    H = guidata(fig);
    set(H.hTrial, 'String', sprintf('%d/%d', iTrial, nTrials));
    drawnow limitrate;
end

function localSetMotor(fig, idx, totalUsed, absPosMM, frameIdx)
    if ~ishandle(fig)
        return;
    end

    H = guidata(fig);

    if totalUsed <= 0
        txt = 'off';
    elseif idx <= 0
        txt = sprintf('0/%d', totalUsed);
    else
        txt = sprintf('%d/%d', idx, totalUsed);
    end

    set(H.hMotor, 'String', txt);

    if nargin >= 4 && ~isempty(absPosMM) && ~isnan(absPosMM)
        localSetCurrentPos(fig, absPosMM);
    end

    drawnow limitrate;
end

function localSetCurrentPos(fig, absPosMM)
    if ~ishandle(fig)
        return;
    end

    H = guidata(fig);

    if nargin < 2 || isempty(absPosMM) || isnan(absPosMM)
        set(H.hCurrentPos, 'String', 'NA mm');
    else
        set(H.hCurrentPos, 'String', sprintf('%.3f mm', absPosMM));
    end

    drawnow limitrate;
end

% =========================================================================
% Log
% =========================================================================
function localAppendLog(fig, msg)
    if ~ishandle(fig),return;end
    H=guidata(fig);old=get(H.logList,'String');if ischar(old),old=cellstr(old);end;if isempty(old),old={};end
    stamp=datestr(now,'HH:MM:SS');wrapped=localWrapLogText(char(msg),54);
    for k=1:numel(wrapped)
        if k==1,prefix=sprintf('[%s] ',stamp);else,prefix='           ';end
        old{end+1}=[prefix wrapped{k}]; %#ok<AGROW>
    end
    if numel(old)>700,old=old(end-699:end);end
    set(H.logList,'String',old,'Value',numel(old));drawnow limitrate;
end

function out=localWrapLogText(txt,maxChars)
% Pre-wrap log lines so the narrow right-side listbox never requires
% horizontal scrolling. Long unbroken tokens are hard-wrapped.
out={};if nargin<2,maxChars=48;end
parts=regexp(txt,'\r\n|\n|\r','split');
for p=1:numel(parts)
    line=strtrim(parts{p});if isempty(line),out{end+1}=' ';continue;end %#ok<AGROW>
    while numel(line)>maxChars
        cut=maxChars;sp=find(isspace(line(1:maxChars)),1,'last');if ~isempty(sp)&&sp>maxChars*0.55,cut=sp;end
        out{end+1}=strtrim(line(1:cut));line=strtrim(line(cut+1:end)); %#ok<AGROW>
    end
    if ~isempty(line),out{end+1}=line;end %#ok<AGROW>
end
if isempty(out),out={''};end
end

% =========================================================================
% Safe GUI bridge
% =========================================================================
function localSafeGuiStatus(fig, msg, state)
    if ~ishandle(fig)
        return;
    end

    localSetStatus(fig, msg, state);

    if strcmpi(state, 'ready') || strcmpi(state, 'idle')
        localSetReady(fig, true);
    else
        localSetReady(fig, false);
    end
end

function localSafeGuiLog(fig, msg)
    if ~ishandle(fig)
        return;
    end
    localAppendLog(fig, msg);
end

function localSafeGuiFrame(fig, frameIdx)
    if ~ishandle(fig)
        return;
    end

    frameIdx = round(frameIdx);

    % Backend sends frame 0 before every new acquisition.
    % Use that to reset live timing.
    if frameIdx <= 0
        localResetLiveTR(fig);
        localSetFrame(fig, 0, 0);
        return;
    end

    % This updates both:
    %   1) real frame index
    %   2) real elapsed wall-clock seconds
    %   3) live measured dt/TR box
    localUpdateLiveTRFromFrame(fig, frameIdx);
end

function localSafeGuiTrial(fig, iTrial, nTrials)
    if ~ishandle(fig)
        return;
    end
    localSetTrial(fig, iTrial, nTrials);
end

function localSafeGuiMotor(fig, idx, totalFromBackend, absPosMM, frameIdx)
    if ~ishandle(fig)
        return;
    end

    if nargin < 3 || isempty(totalFromBackend) || totalFromBackend <= 0
        totalUsed = localEstimateMotorPositions(fig);
    else
        totalUsed = totalFromBackend;
    end

    localSetMotor(fig, idx, totalUsed, absPosMM, frameIdx);
end

function localSafeGuiTiming(fig, targetDt, meanDt, devPct, elapsedSec, nFrames)
    if ~ishandle(fig)
        return;
    end

    H = guidata(fig);

    warnNow = false;
    if ~isempty(targetDt) && ~isnan(targetDt) && targetDt > 0 && ...
            ~isempty(meanDt) && ~isnan(meanDt)

        if abs(devPct) > 15 || abs(meanDt - targetDt) > 0.050
            warnNow = true;
        end
    end

    % Final/periodic timing callback also refreshes progress.  This makes
    % sure a completed functional scan ends at the exact acquired frame count
    % and elapsed duration even if the last throttled frame callback happened
    % slightly earlier.
    try
        if ~isempty(nFrames) && isnumeric(nFrames) && isfinite(nFrames)
            localSetFrame(fig, nFrames, elapsedSec);
        end
    catch
    end

    if isfield(H, 'hLiveDt') && ishandle(H.hLiveDt)
        if isempty(meanDt) || isnan(meanDt)
            txt = 'dt --';
            bg = H.C.miniBg;
        else
            txt = sprintf('%.3fs %+0.0f%%', meanDt, devPct);

            if warnNow
                bg = H.C.error;
            else
                bg = H.C.good;
            end
        end

        set(H.hLiveDt, ...
            'String', txt, ...
            'BackgroundColor', bg, ...
            'ForegroundColor', [1 1 1]);
    end

    drawnow limitrate;
end


function tf = localSafeStopRequested(fig)
    tf = false;
    if ~ishandle(fig)
        return;
    end

    try
        tf = logical(getappdata(fig, 'stopRequested'));
    catch
        tf = false;
    end
end

% =========================================================================
% Live measured dt / TR monitor
% =========================================================================
function S = localInitLiveTRStats()
    S.targetDtSec = NaN;

    S.firstWallSec = NaN;
    S.lastFrame = NaN;
    S.lastWallSec = NaN;

    S.elapsedSec = 0;
    S.meanDtSec = NaN;
    S.nIntervals = 0;

    % Warning rule:
    % Warn if measured dt differs from expected TR by >15 percent
    % OR by more than 50 ms.
    S.warnFrac = 0.15;
    S.warnAbsSec = 0.050;

    % Avoid log spam
    S.lastWarnFrame = -Inf;
    S.warnEveryFrames = 200;
end

function localResetLiveTR(fig)
    if ~ishandle(fig)
        return;
    end

    S = localInitLiveTRStats();
    S.targetDtSec = localGetTR(fig);
    setappdata(fig, 'liveTRStats', S);

    localSetFrame(fig, 0, 0);

    H = guidata(fig);
    if isfield(H, 'hLiveDt') && ishandle(H.hLiveDt)
        if isnan(S.targetDtSec)
            set(H.hLiveDt, 'String', 'set --', ...
                'BackgroundColor', H.C.miniBg, ...
                'ForegroundColor', [1 1 1]);
        else
            set(H.hLiveDt, 'String', sprintf('set %.3fs', S.targetDtSec), ...
                'BackgroundColor', H.C.miniBg, ...
                'ForegroundColor', [1 1 1]);
        end
    end
end

function localUpdateLiveTRFromFrame(fig, frameIdx)
    if ~ishandle(fig)
        return;
    end

    frameIdx = round(frameIdx);
    if frameIdx < 1
        return;
    end

    H = guidata(fig);

    if ~isappdata(fig, 'liveTRStats')
        setappdata(fig, 'liveTRStats', localInitLiveTRStats());
    end

    S = getappdata(fig, 'liveTRStats');

    if isempty(S) || ~isstruct(S)
        S = localInitLiveTRStats();
    end

    if isempty(S.targetDtSec) || isnan(S.targetDtSec)
        S.targetDtSec = localGetTR(fig);
    end

    nowSec = now * 86400;

    % First received real frame callback.
    if isnan(S.firstWallSec)
        S.firstWallSec = nowSec;
        S.lastFrame = frameIdx;
        S.lastWallSec = nowSec;
        S.elapsedSec = 0;

        setappdata(fig, 'liveTRStats', S);

        localSetFrame(fig, frameIdx, 0);
        return;
    end

    frameDelta = frameIdx - S.lastFrame;
    timeDeltaSec = nowSec - S.lastWallSec;

    S.elapsedSec = max(0, nowSec - S.firstWallSec);

    if frameDelta <= 0 || timeDeltaSec <= 0
        setappdata(fig, 'liveTRStats', S);
        localSetFrame(fig, frameIdx, S.elapsedSec);
        return;
    end

    blockDtSec = timeDeltaSec / frameDelta;

    if isnan(S.meanDtSec)
        S.meanDtSec = blockDtSec;
        S.nIntervals = frameDelta;
    else
        S.meanDtSec = ((S.meanDtSec * S.nIntervals) + (blockDtSec * frameDelta)) / ...
            max(1, S.nIntervals + frameDelta);
        S.nIntervals = S.nIntervals + frameDelta;
    end

    S.lastFrame = frameIdx;
    S.lastWallSec = nowSec;

    target = S.targetDtSec;
    warnNow = false;
    devPct = NaN;

    if ~isnan(target) && target > 0 && ~isnan(S.meanDtSec)
        devFrac = abs(S.meanDtSec - target) / target;
        devPct = 100 * (S.meanDtSec - target) / target;

        if devFrac > S.warnFrac || abs(S.meanDtSec - target) > S.warnAbsSec
            warnNow = true;
        end
    end

    % Update Frame / seconds box.
    localSetFrame(fig, frameIdx, S.elapsedSec);

    % Update live dt/TR box.
    if isfield(H, 'hLiveDt') && ishandle(H.hLiveDt)
        if isnan(S.meanDtSec)
            txt = 'dt --';
            bg = H.C.miniBg;
        else
            if isnan(devPct)
                txt = sprintf('%.3fs', S.meanDtSec);
            else
                txt = sprintf('%.3fs %+0.f%%', S.meanDtSec, devPct);
            end

            if warnNow
                bg = H.C.error;
            else
                bg = H.C.good;
            end
        end

        set(H.hLiveDt, 'String', txt, ...
            'BackgroundColor', bg, ...
            'ForegroundColor', [1 1 1]);
    end

    if warnNow && frameIdx - S.lastWarnFrame >= S.warnEveryFrames
        localAppendLog(fig, sprintf( ...
            'TR WARNING: expected %.3f s, measured mean %.3f s (%+.1f%%) at frame %d.', ...
            target, S.meanDtSec, devPct, frameIdx));

        S.lastWarnFrame = frameIdx;
    end

    setappdata(fig, 'liveTRStats', S);
end
% =========================================================================
% Help
% =========================================================================
function localShowHelpWindow()
    hf = figure( ...
        'Name', 'Trigger Controller Help', ...
        'NumberTitle', 'off', ...
        'MenuBar', 'none', ...
        'ToolBar', 'none', ...
        'Color', [0.09 0.09 0.10], ...
        'Position', [180 120 940 690], ...
        'Resize', 'on');

    txt = sprintf([ ...
        'OpenfUS Trigger Controller - Help\n\n' ...
        '1) Acquisition\n' ...
        '   - Mode: Doppler / Low-Res Anatomy, Functional fUSI / Time Series, B-Mode Live, High-Res 2D or High-Res 3D.\n' ...
        '   - Doppler: selecting this mode presets Frames / scan = 5 and nblocksImage = 16.\n' ...
        '     With the untouched 5/16 preset and accessories OFF, the final Doppler image/volume\n' ...
        '     is mirrored into this GUI; press SAVE LOW-RES only when you want to keep it.\n' ...
        '     Saved files are numbered low_res_anatomy_1.mat, low_res_anatomy_2.mat, ...\n' ...
        '     If you change the preset or enable accessories, normal Doppler time-series saving is kept.\n' ...
        '   - Functional fUSI: full Doppler movie; default 2500 frames x 16 blocks/image; auto-saved.\n' ...
        '     During Functional fUSI, Progress shows frame/target, percent and elapsed seconds; Live dt shows measured TR.\n' ...
        '   - B-Mode Live: START uses the company LIVE control (not repeated snapshots) until STOP.\n' ...
        '     Press STOP in this Trigger Controller to end it. Frames/Scans/nblocksImage are ignored.\n' ...
        '     Frame-synchronized StimBox/PulsePal/motor remains disabled for B-mode.\n' ...
        '   - High-Res 2D: Frames / scan = source frames used to reconstruct one HR image;\n' ...
        '     fixed nblocksImage = 10. Review in the HR viewer and press SAVE ANATOMY there.\n' ...
        '   - High-Res 3D: Frames / scan = source volumes used to reconstruct one HR volume;\n' ...
        '     fixed nblocksImage = 17. Review in the HR viewer and press SAVE ANATOMY there.\n' ...
        '     Saved HR files are numbered high_res_anatomy_1.mat, high_res_anatomy_2.mat, ...\n' ...
        '     Viewer: sliders for black/white, gain, gamma, log compression and sharpness;\n' ...
        '     Gray/Hot, adjustable grid rows/cols and RESET COMPANY DEFAULT.\n' ...
        '   - Probe: select 2D or 3D for Doppler. HR modes set it automatically.\n' ...
        '   - nblocksImage: TR = nblocksImage x 0.02 s for a 2D probe,\n' ...
        '     and TR = nblocksImage x 0.03 s for a 3D probe.\n' ...
        '   - Scans: repeated acquisitions when the step motor is off; shown as Trials when stepped motor is active.\n' ...
        '   - Pause (s): pause between trials.\n\n' ...
        '2) StimBox\n' ...
        '   - Enable StimBox independently from all other devices.\n' ...
        '   - Frame start = first frame where the active trigger block begins.\n' ...
        '   - Frames active = how many consecutive frames the trigger block lasts.\n' ...
        '   - Repeat after frames = start a new trigger block again after that many frames.\n' ...
        '   - D3 / D5 / D6 can be enabled individually.\n\n' ...
        '3) Electrical stimulation / PulsePal\n' ...
        '   - Enable PulsePal independently from StimBox and Motor.\n' ...
        '   - Frame start = first trigger frame.\n' ...
        '   - Frames active = metadata window for scheduling block logic.\n' ...
        '   - Repeat after = trigger again after this many frames.\n' ...
        '   - Standard tab contains common stimulation parameters.\n' ...
        '   - Advanced tab contains phase 2, burst, train, custom train and trigger settings.\n\n' ...
        '4) Step Motor\n' ...
        '   - Start pos and End pos are ABSOLUTE positions in mm.\n' ...
        '   - Active from frame = first frame where the motor becomes active.\n' ...
        '   - Active for frames = size of the active motor window.\n' ...
        '   - Move every N frames = how often the motor advances to the next position.\n' ...
        '   - Example: Active from frame 10, active for 150 frames, move every 100 frames\n' ...
        '     means the motor moves at frame 10 and again at frame 110.\n' ...
        '   - Periodic repeats the position list inside one active window.\n' ...
        '   - Return home moves back to the initial read motor position when finished.\n\n' ...
        '5) Notes\n' ...
        '   - The live log is intentionally less noisy now.\n' ...
        '   - StimBox does not print every single active frame trigger by default.\n' ...
        '   - Key events, motor moves, saved files and errors are still shown.\n' ...
        ]);

    uicontrol(hf, 'Style', 'edit', ...
        'Units', 'normalized', ...
        'Position', [0.03 0.04 0.94 0.92], ...
        'Max', 2, ...
        'Min', 0, ...
        'Enable', 'inactive', ...
        'HorizontalAlignment', 'left', ...
        'FontName', 'Helvetica', ...
        'FontSize', 11, ...
        'ForegroundColor', [1 1 1], ...
        'BackgroundColor', [0.12 0.12 0.13], ...
        'String', txt);
end

% =========================================================================
% Small helpers
% =========================================================================
function sessionFolder = getNextSplitMotorSessionFolder(expFolder)
% Creates next available split-motor session folder:
% Session_001_SplitMotor, Session_002_SplitMotor, ...

if nargin < 1 || isempty(expFolder) || ~exist(expFolder, 'dir')
    error('Experiment folder does not exist.');
end

d = dir(fullfile(expFolder, 'Session_*_SplitMotor'));
existingNames = {d([d.isdir]).name};

maxIdx = 0;
for i = 1:numel(existingNames)
    tok = regexp(existingNames{i}, '^Session_(\d+)_SplitMotor$', 'tokens', 'once');
    if ~isempty(tok)
        v = str2double(tok{1});
        if isfinite(v)
            maxIdx = max(maxIdx, v);
        end
    end
end

nextIdx = maxIdx + 1;
sessionFolder = fullfile(expFolder, sprintf('Session_%03d_SplitMotor', nextIdx));

if ~exist(sessionFolder, 'dir')
    mkdir(sessionFolder);
end
end

function localEditJournalNote(fig)
    if ~ishandle(fig)
        return;
    end

    prevNote = '';
    if isappdata(fig, 'journalNote')
        prevNote = getappdata(fig, 'journalNote');
    end

    defaultTemplate = sprintf([ ...
        'Experimental Scheme: Baseline 2 min, Injection 1 min, PI 13 min\n' ...
        'Left: (uM, 1 µL, 1 µL/min)\n' ...
        'Right: (uM, 1 µL, 1 µL/min)\n' ...
        'Notes: ']);

    if isempty(strtrim(prevNote))
        startNote = defaultTemplate;
    else
        startNote = prevNote;
    end

    answer = inputdlg( ...
        {'Journal note for per-scan txt file (set before scan):'}, ...
        'Journal Note', ...
        [10 90], ...
        {startNote});

    if isempty(answer)
        return;
    end

    noteTxt = answer{1};

    if ischar(noteTxt) && size(noteTxt, 1) > 1
        noteTxt = strjoin(cellstr(noteTxt), sprintf('\n'));
    end

    noteTxt = strtrim(noteTxt);

    setappdata(fig, 'journalNote', noteTxt);
    localUpdateJournalNoteButton(fig);

    if isempty(noteTxt)
        localAppendLog(fig, 'Journal note cleared.');
    else
        localAppendLog(fig, 'Journal note updated.');
    end
end

function localUpdateJournalNoteButton(fig)
    if ~ishandle(fig)
        return;
    end

    H = guidata(fig);
    if isempty(H) || ~isfield(H, 'bJournalNote') || ~ishandle(H.bJournalNote)
        return;
    end

    noteTxt = '';
    if isappdata(fig, 'journalNote')
        noteTxt = getappdata(fig, 'journalNote');
    end

    if isempty(strtrim(noteTxt))
        set(H.bJournalNote, ...
            'String', 'JOURNAL NOTE', ...
            'BackgroundColor', [0.85 0.45 0.10], ...
            'ForegroundColor', [1 1 1]);
    else
        set(H.bJournalNote, ...
            'String', 'JOURNAL SET', ...
            'BackgroundColor', [0.15 0.40 0.82], ...
            'ForegroundColor', [1 1 1]);
    end
end


function s = localNum2Str(v)
    if isempty(v) || ~isnumeric(v) || isnan(v)
        s = 'NA';
    else
        if abs(v - round(v)) < 1e-12
            s = sprintf('%d', round(v));
        else
            s = sprintf('%.3f', v);
        end
    end
end