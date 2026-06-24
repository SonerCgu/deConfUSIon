
% GA_FISHERZ_STATS_PATCH_20260512
% FC group matrices are averaged/statistically compared in Fisher z space.
% Convert back with tanh(Z) only for Pearson-r display if needed.
%% GA_ALPHA_MOD_SCM_STYLE_20260504_START
% AlphaData set-lines are wrapped with GA_alphaModFixFromCData_20260504.
% This keeps blackbody 0-percent pixels transparent below Mod Min.
%% GA_ALPHA_MOD_SCM_STYLE_20260504_END

function hFig = GroupAnalysis(varargin)
% GroupAnalysis.m
% Reduced modular main GUI for fUSI Studio Group Analysis
% MATLAB 2017b + 2023b compatible
%
% This file is intentionally smaller.
%
% Backend functions are delegated to:
%   GroupAnalysis_Map.m
%   GroupAnalysis_FC.m
%   GroupAnalysis_Common.m
%

%%% =====================================================================
%%% INPUT PARSING
%%% =====================================================================
posStudio = [];
posOnClose = [];
args = varargin;

if ~isempty(args) && isstruct(args{1}) && ~ischar(args{1})
    posStudio = args{1};
    args = args(2:end);
end

if ~isempty(args) && isa(args{1},'function_handle')
    posOnClose = args{1};
    args = args(2:end);
end

%%% GA_INPUTPARSER_POSITIONAL_STARTDIR_FIX_V2_20260504_START
% Accept old caller style: GroupAnalysis(studio,onClose,startDir)
% or accidental positional folder paths from fUSI Studio.
posStartDir = '';
try
    gaKnownInputNames = {'studio','logFcn','statusFcn','startDir','onClose'};
    gaCleanArgs = {};
    iiGA = 1;
    while iiGA <= numel(args)
        aGA = args{iiGA};
        try
            if exist('isstring','builtin') && isstring(aGA) && isscalar(aGA)
                aGA = char(aGA);
            end
        catch
        end

        if isa(aGA,'function_handle')
            posOnClose = aGA;
            iiGA = iiGA + 1;
            continue;
        end

        if ischar(aGA)
            aTxt = strtrim(aGA);
            isKnownName = any(strcmpi(aTxt,gaKnownInputNames));

            if isKnownName
                gaCleanArgs{end+1} = aTxt; %#ok<AGROW>
                if iiGA < numel(args)
                    gaCleanArgs{end+1} = args{iiGA+1}; %#ok<AGROW>
                    iiGA = iiGA + 2;
                else
                    iiGA = iiGA + 1;
                end
                continue;
            else
                % Any unknown positional char/string is treated as startDir.
                posStartDir = aTxt;
                iiGA = iiGA + 1;
                continue;
            end
        end

        gaCleanArgs{end+1} = args{iiGA}; %#ok<AGROW>
        iiGA = iiGA + 1;
    end
    args = gaCleanArgs;
catch ME_ga_parse_clean
    try, disp(['GroupAnalysis input cleanup warning: ' ME_ga_parse_clean.message]); catch, end
end
%%% GA_INPUTPARSER_POSITIONAL_STARTDIR_FIX_V2_20260504_END

P = inputParser;
P.addParameter('studio', struct(), @(x) isstruct(x));
P.addParameter('logFcn', [], @(x) isempty(x) || isa(x,'function_handle'));
P.addParameter('statusFcn', [], @(x) isempty(x) || isa(x,'function_handle'));
P.addParameter('startDir', '', @(x) ischar(x) || (exist('isstring','builtin') && isstring(x) && isscalar(x)));
P.addParameter('onClose', [], @(x) isempty(x) || isa(x,'function_handle'));
P.parse(args{:});
opt = P.Results;
%%% GA_APPLY_POSITIONAL_STARTDIR_V2_20260504_START
try
    if exist('isstring','builtin') && isstring(opt.startDir) && isscalar(opt.startDir)
        opt.startDir = char(opt.startDir);
    end
catch
end
try
    if exist('posStartDir','var') && ~isempty(posStartDir)
        opt.startDir = posStartDir;
    end
catch
end
%%% GA_APPLY_POSITIONAL_STARTDIR_V2_20260504_END

if ~isempty(posStudio)
    opt.studio = posStudio;
end

if ~isempty(posOnClose)
    opt.onClose = posOnClose;
end

if isempty(opt.startDir)
    opt.startDir = pwd;
end

try
    if isfield(opt.studio,'exportPath') && ~isempty(opt.studio.exportPath) && exist(opt.studio.exportPath,'dir') == 7
        opt.startDir = opt.studio.exportPath;
    end
catch
end

%%% =====================================================================
%%% THEME
%%% =====================================================================
C.bg     = [0.06 0.06 0.06];
C.panel  = [0.10 0.10 0.10];
C.panel2 = [0.08 0.08 0.08];
C.txt    = [0.95 0.95 0.95];
C.muted  = [0.70 0.80 0.90];
C.axisBg = [0.00 0.00 0.00];
C.editBg = [0.14 0.14 0.14];

C.btnSecondary = [0.18 0.18 0.18];
C.btnPrimary   = [0.22 0.70 0.52];
C.btnAction    = [0.25 0.55 0.95];
C.btnDanger    = [0.90 0.25 0.25];
C.btnHelp      = [0.20 0.60 0.95];

F.name  = 'Arial';
F.base  = 13;
F.small = 12;
F.big   = 16;
F.table = 12;
F.tab   = 15;

%%% =====================================================================
%%% FIGURE
%%% =====================================================================
hFig = figure( ...
    'Name','fUSI Studio - Group Analysis', ...
    'Color',C.bg, ...
    'MenuBar','none', ...
    'ToolBar','none', ...
    'NumberTitle','off', ...
    'Position',[120 60 1860 980], ...
    'CloseRequestFcn',@closeMe);
% HUMoR_FORCE_FULLSCREEN_PATCH32
try, deConfUSIon_force_fullscreen_fig(hFig); catch, end


set(hFig, ...
    'DefaultUicontrolFontName',F.name, ...
    'DefaultUicontrolFontSize',F.base, ...
    'DefaultUipanelFontName',F.name, ...
    'DefaultUipanelFontSize',F.base, ...
    'DefaultAxesFontName',F.name, ...
    'DefaultAxesFontSize',F.base);

%%% =====================================================================
%%% STATE
%%% =====================================================================
S = struct();
S.opt = opt;
S.C = C;
S.F = F;

S.subj = cell(0,9);
S.selectedRows = [];
S.isClosing = false;

S.lastROI = struct();
S.lastMAP = struct();
S.lastFC  = struct();
S.lastMapDisplay = struct();

S.activeTab = 'ROI';
S.mode = 'ROI Timecourse';

S.groupList = {'PACAP','Vehicle','Control','GroupA','GroupB'};
S.condList  = {'CondA','CondB','Baseline','Post'};
S.defaultGroup = 'PACAP';
S.defaultCond  = 'CondA';
S.tableMinRows = 2;
S.tableColWidths = {36 118 54 88 88 74 72 62 62 92};

S.applyAllIfNoneSelected = true;

try
    S.groupToCondMap = containers.Map('KeyType','char','ValueType','char');
    S.groupToCondMap('PACAP')   = 'CondA';
    S.groupToCondMap('VEHICLE') = 'CondB';
    S.groupToCondMap('CONTROL') = 'CondB';
    S.groupToCondMap('GROUPA')  = 'CondA';
    S.groupToCondMap('GROUPB')  = 'CondB';
catch
    S.groupToCondMap = [];
end

try
    S.cache.roiTC       = containers.Map('KeyType','char','ValueType','any');
    S.cache.pscMap      = containers.Map('KeyType','char','ValueType','any');
    S.cache.groupBundle = containers.Map('KeyType','char','ValueType','any');
    S.cache.fcBundle    = containers.Map('KeyType','char','ValueType','any');
catch
    S.cache = struct();
end

%%% ROI defaults
S.tc_computePSC      = false;
S.tc_baseMin0        = 0;
S.tc_baseMin1        = 10;
S.tc_injMin0         = 5;
S.tc_injMin1         = 15;
S.tc_plateauMin0     = 30;
S.tc_plateauMin1     = 40;
S.tc_peakSearchMin0  = 15;
S.tc_peakSearchMin1  = 25;
S.tc_peakWinMin      = 3;
S.tc_trimPct         = 10;
S.tc_metric          = 'Robust Peak';
S.tc_showSEM         = true;
S.tc_showInjectionBox = true;
S.displaySemAlpha    = 0.35;
S.exportSemAlpha     = 0.20;

%%% Group map defaults
S.mapSummary          = 'Mean';
S.mapUseGlobalWindows = true;
S.mapGlobalBaseSec    = [30 240];
S.mapGlobalSigSec     = [840 900];
S.mapSource           = 'Recompute from exported PSC';
S.mapUseBundleWindows = true;
S.mapSigma            = 1;
S.mapUnderlayMode     = 'Bundle underlay';
S.mapCustomUnderlayFile = '';
S.mapLoadedUnderlay   = [];
S.mapLoadedOverlayMask = [];
S.rowPacapSide        = cell(0,1);
S.mapRefPacapSide     = 'Left';
S.mapPreviewRow       = NaN;
S.mapCurrentSlice     = NaN;   % GA_STEPMOTOR_GROUPMAP_SCROLL_PATCH_V1
S.mapCurrentSliceMax  = NaN;
S.mapPolarity         = 'Positive only';

S.mapThreshold       = 0;
S.mapCaxis           = [0 100];
S.mapAlphaModOn      = true;
S.mapModMin          = 10;
S.mapModMax          = 20;
S.mapBlackBody       = true;
S.mapFlipMode        = 'Off';
S.mapColormap        = 'blackbdy_iso';

%%% FC state
S.FC = struct();
S.FC.files = {};
S.FC.subjects = struct([]);
S.FC.loaded = false;

% Separate per-row FC-GA bundle paths. Do not store these in S.subj,
% so old SCM / step-motor Group Maps table logic stays intact.
S.fcRowFiles = cell(0,1);

S.fcDisplayValue = 'Pearson r';
S.fcThreshold = 0;
S.fcGroupA = 'PACAP';
S.fcGroupB = 'Vehicle';

%%% style
S.colorMode     = 'Scheme';
S.colorScheme   = 'PACAP/Vehicle';
S.manualGroupA  = 'PACAP';
S.manualGroupB  = 'Vehicle';
S.manualColorA  = 1;
S.manualColorB  = 2;

S.plotTop = struct('auto',true,'forceZero',false,'ymin',0,'ymax',300,'step',0);
S.plotBot = struct('auto',true,'forceZero',false,'ymin',0,'ymax',300,'step',0);

S.previewStyle    = 'Dark';
S.previewShowGrid = false;
S.tc_previewSmooth = false;
S.tc_previewSmoothWinSec = 60;

S.testType  = 'Two-sample t-test (Student, equal var)';
S.alpha     = 0.05;
S.annotMode = 'Bottom only';
S.showPText = true;

S.outlierMethod = 'None';
S.outMADthr     = 3.5;
S.outIQRk       = 1.5;
S.outlierKeys   = {};
S.outlierInfo   = {};

S.outDir = defaultOutDir(opt);

%%% =====================================================================
%%% LAYOUT
%%% =====================================================================
leftW = 0.46;

pLeft = uipanel(hFig, ...
    'Units','normalized', ...
    'Position',[0.02 0.05 leftW 0.93], ...
    'Title','Subjects / Groups', ...
    'BackgroundColor',C.panel, ...
    'ForegroundColor','w', ...
    'FontSize',F.big, ...
    'FontWeight','bold');

pRight = uipanel(hFig, ...
    'Units','normalized', ...
    'Position',[0.02+leftW+0.02 0.05 0.96-(0.02+leftW+0.02) 0.93], ...
    'Title','', ...
    'BackgroundColor',C.panel, ...
    'ForegroundColor','w', ...
    'FontSize',F.big, ...
    'FontWeight','bold');

%%% =====================================================================
%%% LEFT TABLE
%%% =====================================================================
colNames = {'Use','Animal ID','Session','Scan ID','Group','Condition','ROI File','Bundle File','FC GA','Status'};
colEdit  = [true true false false true true false false false false];
colFmt   = {'logical','char','char','char',S.groupList,S.condList,'char','char','char','char'};

S.hTable = uitable(pLeft, ...
    'Units','normalized', ...
    'Position',[0.03 0.42 0.70 0.55], ...
    'Data',makeUITableDisplayData(S.subj,S.tableMinRows,S.fcRowFiles), ...
    'ColumnName',colNames, ...
    'ColumnEditable',colEdit, ...
    'ColumnFormat',colFmt, ...
    'RowName','numbered', ...
    'ColumnWidth',S.tableColWidths, ...
    'BackgroundColor',buildTableRowColorsDisplay(S.subj,S.tableMinRows), ...
    'ForegroundColor',[1 1 1], ...
    'FontName','Consolas', ...
    'FontSize',F.table, ...
    'CellSelectionCallback',@onCellSelect, ...
    'CellEditCallback',@onCellEdit);

%%% =====================================================================
%%% QUICK ASSIGN
%%% =====================================================================
pQuick = uipanel(pLeft, ...
    'Units','normalized', ...
    'Position',[0.75 0.42 0.22 0.55], ...
    'Title','Quick Assign', ...
    'BackgroundColor',C.panel2, ...
    'ForegroundColor','w', ...
    'FontSize',F.base, ...
    'FontWeight','bold');

S.hSelInfo = uicontrol(pQuick,'Style','text','String','Selected: none', ...
    'Units','normalized','Position',[0.05 0.93 0.90 0.05], ...
    'BackgroundColor',C.panel2,'ForegroundColor',C.muted, ...
    'HorizontalAlignment','left','FontWeight','bold');

S.hApplyAllIfNone = uicontrol(pQuick,'Style','checkbox', ...
    'String','If none selected -> active USE rows', ...
    'Units','normalized','Position',[0.05 0.87 0.90 0.05], ...
    'Value',double(S.applyAllIfNoneSelected), ...
    'BackgroundColor',C.panel2,'ForegroundColor','w', ...
    'Callback',@onApplyAllToggle);

uicontrol(pQuick,'Style','text','String','Group', ...
    'Units','normalized','Position',[0.05 0.79 0.90 0.045], ...
    'BackgroundColor',C.panel2,'ForegroundColor','w', ...
    'HorizontalAlignment','left','FontWeight','bold');

S.hQuickGroup = uicontrol(pQuick,'Style','popupmenu','String',S.groupList, ...
    'Units','normalized','Position',[0.05 0.735 0.90 0.055], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w', ...
    'Callback',@onQuickGroupChanged);

uicontrol(pQuick,'Style','text','String','Condition', ...
    'Units','normalized','Position',[0.05 0.655 0.90 0.045], ...
    'BackgroundColor',C.panel2,'ForegroundColor','w', ...
    'HorizontalAlignment','left','FontWeight','bold');

S.hQuickCond = uicontrol(pQuick,'Style','popupmenu','String',S.condList, ...
    'Units','normalized','Position',[0.05 0.60 0.90 0.055], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w');

S.hApplyGroup = mkBtn(pQuick,'Apply Group',[0.05 0.50 0.43 0.075],C.btnAction,@onApplyGroup);
S.hApplyCond  = mkBtn(pQuick,'Apply Cond',[0.52 0.50 0.43 0.075],C.btnAction,@onApplyCond);
S.hApplyBoth  = mkBtn(pQuick,'Apply Both',[0.05 0.405 0.90 0.075],C.btnPrimary,@onApplyBoth);

S.hAddGroup = mkBtn(pQuick,'Add Group',[0.05 0.305 0.43 0.070],C.btnSecondary,@onAddGroup);
S.hAddCond  = mkBtn(pQuick,'Add Cond',[0.52 0.305 0.43 0.070],C.btnSecondary,@onAddCond);
S.hRevertExcluded = mkBtn(pQuick,'Revert Excluded',[0.05 0.145 0.90 0.075],C.btnSecondary,@onRevertExcluded);

S.hAutoPair = uicontrol(pQuick,'Style','checkbox','String','Auto PairID = Subject', ...
    'Units','normalized','Position',[0.01 0.01 0.01 0.01], ...
    'Value',1,'Visible','off');

%%% =====================================================================
%%% LEFT ACTIONS
%%% =====================================================================
S.hAddBundles = mkBtn(pLeft,'Add Bundles',[0.03 0.285 0.22 0.060],C.btnAction,@onAddBundles);
S.hAddFiles   = mkBtn(pLeft,'Add ROI / DATA',[0.27 0.285 0.22 0.060],C.btnSecondary,@onAddFiles);
S.hAddFolder  = mkBtn(pLeft,'Add Folder',[0.51 0.285 0.14 0.060],C.btnSecondary,@onAddFolder);
S.hRemove     = mkBtn(pLeft,'Remove Selected / USE',[0.67 0.285 0.30 0.060],C.btnDanger,@onRemoveSelected);

S.hSaveList = mkBtn(pLeft,'Save List',[0.03 0.210 0.45 0.055],C.btnSecondary,@onSaveList);
S.hLoadList = mkBtn(pLeft,'Load List',[0.52 0.210 0.45 0.055],C.btnSecondary,@onLoadList);

S.hHelp  = mkBtn(pLeft,'Help',[0.47 0.060 0.24 0.050],C.btnHelp,@onHelp);
S.hClose = mkBtn(pLeft,'Close',[0.73 0.060 0.24 0.050],C.btnDanger,@(~,~) closeMe(hFig,[]));

%%% =====================================================================
%%% RIGHT MANUAL TABS
%%% =====================================================================
S.hAnalysisTitle = uicontrol(pRight,'Style','text','String','Analysis', ...
    'Units','normalized','Position',[0.02 0.965 0.18 0.025], ...
    'BackgroundColor',C.panel,'ForegroundColor','w', ...
    'HorizontalAlignment','left','FontSize',F.big,'FontWeight','bold');

S.hTabBar = uipanel(pRight,'Units','normalized','Position',[0.02 0.935 0.96 0.035], ...
    'BorderType','none','BackgroundColor',C.panel);

S.hTabROI   = mkTabBtn(S.hTabBar,'ROI Timecourse',      [0.000 0.05 0.175 0.90],@(s,e) onTabClicked('ROI'));
S.hTabMAP   = mkTabBtn(S.hTabBar,'Group Maps',          [0.185 0.05 0.135 0.90],@(s,e) onTabClicked('MAP'));
S.hTabFC    = mkTabBtn(S.hTabBar,'Functional Conn.',    [0.330 0.05 0.185 0.90],@(s,e) onTabClicked('FC'));
S.hTabSTATS = mkTabBtn(S.hTabBar,'Statistics / Export', [0.525 0.05 0.225 0.90],@(s,e) onTabClicked('STATS'));
S.hTabPREV  = mkTabBtn(S.hTabBar,'ROI Preview',         [0.760 0.05 0.130 0.90],@(s,e) onTabClicked('PREV'));

S.tabROI   = uipanel(pRight,'Units','normalized','Position',[0.02 0.02 0.96 0.90], ...
    'BorderType','none','BackgroundColor',C.bg);
S.tabMAP   = uipanel(pRight,'Units','normalized','Position',[0.02 0.02 0.96 0.90], ...
    'BorderType','none','BackgroundColor',C.bg,'Visible','off');
S.tabFC    = uipanel(pRight,'Units','normalized','Position',[0.02 0.02 0.96 0.90], ...
    'BorderType','none','BackgroundColor',C.bg,'Visible','off');
S.tabSTATS = uipanel(pRight,'Units','normalized','Position',[0.02 0.02 0.96 0.90], ...
    'BorderType','none','BackgroundColor',C.bg,'Visible','off');
S.tabPREV  = uipanel(pRight,'Units','normalized','Position',[0.02 0.02 0.96 0.90], ...
    'BorderType','none','BackgroundColor',C.bg,'Visible','off');

bg2 = C.panel2;

%%% =====================================================================
%%% ROI TAB
%%% =====================================================================
pROIBG = uipanel(S.tabROI,'Units','normalized','Position',[0 0 1 1], ...
    'BorderType','none','BackgroundColor',C.bg);

pROItop = uipanel(pROIBG,'Units','normalized','Position',[0.02 0.92 0.96 0.07], ...
    'BorderType','none','BackgroundColor',bg2);

uicontrol(pROItop,'Style','text','String','Active mode:', ...
    'Units','normalized','Position',[0.02 0.15 0.18 0.70], ...
    'BackgroundColor',bg2,'ForegroundColor','w', ...
    'HorizontalAlignment','left','FontWeight','bold');

S.hMode = uicontrol(pROItop,'Style','popupmenu', ...
    'String',{'ROI Timecourse','Group Maps'}, ...
    'Units','normalized','Position',[0.20 0.18 0.25 0.70], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w', ...
    'Callback',@onModeChanged);

pROI = uipanel(pROIBG,'Units','normalized','Position',[0.02 0.60 0.96 0.30], ...
    'Title','ROI settings','BackgroundColor',bg2,'ForegroundColor','w','FontWeight','bold');

S.hTC_ComputePSC = uicontrol(pROI,'Style','checkbox', ...
    'String','Compute %SC from raw using baseline', ...
    'Units','normalized','Position',[0.02 0.82 0.58 0.15], ...
    'Value',double(S.tc_computePSC), ...
    'BackgroundColor',bg2,'ForegroundColor','w', ...
    'Callback',@onROIChanged);

uicontrol(pROI,'Style','text','String','Injection (min):', ...
    'Units','normalized','Position',[0.62 0.84 0.16 0.10], ...
    'BackgroundColor',bg2,'ForegroundColor','w', ...
    'HorizontalAlignment','left','FontWeight','bold');

S.hInj0 = uicontrol(pROI,'Style','edit','String',num2str(S.tc_injMin0), ...
    'Units','normalized','Position',[0.79 0.84 0.08 0.10], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w','Callback',@onROIChanged);

S.hInj1 = uicontrol(pROI,'Style','edit','String',num2str(S.tc_injMin1), ...
    'Units','normalized','Position',[0.88 0.84 0.08 0.10], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w','Callback',@onROIChanged);

[S.hBase0,S.hBase1] = addPairEditsDark(pROI,0.62,'Baseline (min):',S.tc_baseMin0,S.tc_baseMin1,C,@onROIChanged);
[S.hPkS0,S.hPkS1]   = addPairEditsDark(pROI,0.42,'Peak search (min):',S.tc_peakSearchMin0,S.tc_peakSearchMin1,C,@onROIChanged);
[S.hPlat0,S.hPlat1] = addPairEditsDark(pROI,0.22,'Plateau (min):',S.tc_plateauMin0,S.tc_plateauMin1,C,@onROIChanged);

uicontrol(pROI,'Style','text','String','Peak win (min):', ...
    'Units','normalized','Position',[0.66 0.62 0.18 0.12], ...
    'BackgroundColor',bg2,'ForegroundColor','w','HorizontalAlignment','left','FontWeight','bold');

S.hTC_PeakWin = uicontrol(pROI,'Style','edit','String',num2str(S.tc_peakWinMin), ...
    'Units','normalized','Position',[0.84 0.62 0.12 0.12], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w','Callback',@onROIChanged);

uicontrol(pROI,'Style','text','String','Trim %:', ...
    'Units','normalized','Position',[0.66 0.42 0.18 0.12], ...
    'BackgroundColor',bg2,'ForegroundColor','w','HorizontalAlignment','left','FontWeight','bold');

S.hTC_Trim = uicontrol(pROI,'Style','edit','String',num2str(S.tc_trimPct), ...
    'Units','normalized','Position',[0.84 0.42 0.12 0.12], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w','Callback',@onROIChanged);

uicontrol(pROI,'Style','text','String','Metric:', ...
    'Units','normalized','Position',[0.66 0.22 0.18 0.12], ...
    'BackgroundColor',bg2,'ForegroundColor','w','HorizontalAlignment','left','FontWeight','bold');

S.hTC_Metric = uicontrol(pROI,'Style','popupmenu','String',{'Plateau','Robust Peak'}, ...
    'Value',2, ...
    'Units','normalized','Position',[0.84 0.22 0.12 0.12], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w','Callback',@onROIChanged);
% GA_FORCE_ROBUST_PEAK_POPUP_START
try, set(S.hTC_Metric,'Value',2); catch, end
% GA_FORCE_ROBUST_PEAK_POPUP_END

pStyle = uipanel(pROIBG,'Units','normalized','Position',[0.02 0.36 0.96 0.22], ...
    'Title','Display style','BackgroundColor',bg2,'ForegroundColor','w','FontWeight','bold');

uicontrol(pStyle,'Style','text','String','Color scheme:', ...
    'Units','normalized','Position',[0.02 0.64 0.18 0.22], ...
    'BackgroundColor',bg2,'ForegroundColor','w','HorizontalAlignment','left','FontWeight','bold');

S.hColorScheme = uicontrol(pStyle,'Style','popupmenu', ...
    'String',{'PACAP/Vehicle','Blue/Red','Green/Magenta','A/B green-magenta','Cyan/Orange','Purple/Green','Gray/Orange','Red/Blue','Distinct','Tableau 10','Bright 12'}, ...
    'Units','normalized','Position',[0.20 0.66 0.22 0.22], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w','Callback',@onStyleChanged);

S.hShowSEM = uicontrol(pStyle,'Style','checkbox','String','Show SEM', ...
    'Units','normalized','Position',[0.45 0.66 0.16 0.22], ...
    'Value',double(S.tc_showSEM), ...
    'BackgroundColor',bg2,'ForegroundColor','w','Callback',@onStyleChanged);

S.hShowInjBox = uicontrol(pStyle,'Style','checkbox','String','Injection box', ...
    'Units','normalized','Position',[0.62 0.66 0.18 0.22], ...
    'Value',double(S.tc_showInjectionBox), ...
    'BackgroundColor',bg2,'ForegroundColor','w','Callback',@onStyleChanged);

pY = uipanel(pROIBG,'Units','normalized','Position',[0.02 0.02 0.96 0.32], ...
    'Title','Y-Axis Scaling','BackgroundColor',bg2,'ForegroundColor','w','FontWeight','bold');

[S.hTopAuto,S.hTopZero,S.hTopStep,S.hTopYmin,S.hTopYmax] = mkYControlsSimple(pY,0.62,'Top',S.plotTop,C,@onPlotScaleChanged);
[S.hBotAuto,S.hBotZero,S.hBotStep,S.hBotYmin,S.hBotYmax] = mkYControlsSimple(pY,0.20,'Bottom',S.plotBot,C,@onPlotScaleChanged);

%%% =====================================================================
%%% MAP TAB
%%% =====================================================================
pMAPBG = uipanel(S.tabMAP,'Units','normalized','Position',[0 0 1 1], ...
    'BorderType','none','BackgroundColor',C.bg);

pMapDisp = uipanel(pMAPBG,'Units','normalized','Position',[0.02 0.855 0.96 0.140], ...
    'Title','Render style','BackgroundColor',bg2,'ForegroundColor','w','FontWeight','bold');

uicontrol(pMapDisp,'Style','text','String','Summary:', ...
    'Units','normalized','Position',[0.02 0.66 0.09 0.18], ...
    'BackgroundColor',bg2,'ForegroundColor','w','HorizontalAlignment','left','FontWeight','bold');

S.hMapSummary = uicontrol(pMapDisp,'Style','popupmenu','String',{'Mean','Median'}, ...
    'Units','normalized','Position',[0.12 0.64 0.12 0.20], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w','Callback',@onMapDisplayChanged);

uicontrol(pMapDisp,'Style','text','String','Source:', ...
    'Units','normalized','Position',[0.30 0.66 0.08 0.18], ...
    'BackgroundColor',bg2,'ForegroundColor','w','HorizontalAlignment','left','FontWeight','bold');

S.hMapSource = uicontrol(pMapDisp,'Style','popupmenu', ...
    'String',{'Use exported SCM map','Recompute from exported PSC'}, ...
    'Units','normalized','Position',[0.39 0.64 0.30 0.20], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w','Callback',@onMapDisplayChanged, ...
    'Value',2);

uicontrol(pMapDisp,'Style','text','String','Colormap:', ...
    'Units','normalized','Position',[0.02 0.36 0.09 0.18], ...
    'BackgroundColor',bg2,'ForegroundColor','w','HorizontalAlignment','left','FontWeight','bold');

S.hMapColormap = uicontrol(pMapDisp,'Style','popupmenu', ...
    'String',{'blackbdy_iso','hot','parula','turbo','jet','gray'}, ...
    'Units','normalized','Position',[0.12 0.34 0.16 0.20], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w','Callback',@onMapDisplayChanged);

S.hMapBlackBody = uicontrol(pMapDisp,'Style','checkbox','String','Black body', ...
    'Units','normalized','Position',[0.31 0.34 0.12 0.20], ...
    'Value',double(S.mapBlackBody), ...
    'BackgroundColor',bg2,'ForegroundColor','w','Callback',@onMapDisplayChanged);

uicontrol(pMapDisp,'Style','text','String','Flip mode:', ...
    'Units','normalized','Position',[0.46 0.36 0.09 0.18], ...
    'BackgroundColor',bg2,'ForegroundColor','w','HorizontalAlignment','left','FontWeight','bold');

S.hMapFlipMode = uicontrol(pMapDisp,'Style','popupmenu', ...
    'String',{'Off','Flip right-injected animals','Flip left-injected animals','Align to Reference Hemisphere'}, ...
    'Units','normalized','Position',[0.56 0.34 0.40 0.20], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w','Callback',@onMapDisplayChanged);

uicontrol(pMapDisp,'Style','text','String','Alpha min:', ...
    'Units','normalized','Position',[0.02 0.08 0.08 0.16], ...
    'BackgroundColor',bg2,'ForegroundColor','w','HorizontalAlignment','left','FontWeight','bold');

S.hMapModMin = uicontrol(pMapDisp,'Style','edit','String',num2str(S.mapModMin), ...
    'Units','normalized','Position',[0.11 0.06 0.09 0.18], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w','Callback',@onMapDisplayChanged);

uicontrol(pMapDisp,'Style','text','String','Alpha max:', ...
    'Units','normalized','Position',[0.23 0.08 0.08 0.16], ...
    'BackgroundColor',bg2,'ForegroundColor','w','HorizontalAlignment','left','FontWeight','bold');

S.hMapModMax = uicontrol(pMapDisp,'Style','edit','String',num2str(S.mapModMax), ...
    'Units','normalized','Position',[0.32 0.06 0.09 0.18], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w','Callback',@onMapDisplayChanged);

uicontrol(pMapDisp,'Style','text','String','Sigma:', ...
    'Units','normalized','Position',[0.45 0.08 0.06 0.16], ...
    'BackgroundColor',bg2,'ForegroundColor','w','HorizontalAlignment','left','FontWeight','bold');

S.hMapSigma = uicontrol(pMapDisp,'Style','edit','String',num2str(S.mapSigma), ...
    'Units','normalized','Position',[0.52 0.06 0.08 0.18], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w','Callback',@onMapDisplayChanged);

uicontrol(pMapDisp,'Style','text','String','Caxis:', ...
    'Units','normalized','Position',[0.64 0.08 0.06 0.16], ...
    'BackgroundColor',bg2,'ForegroundColor','w','HorizontalAlignment','left','FontWeight','bold');

S.hMapCaxis = uicontrol(pMapDisp,'Style','edit','String',sprintf('%g %g',S.mapCaxis(1),S.mapCaxis(2)), ...
    'Units','normalized','Position',[0.71 0.06 0.14 0.18], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w','Callback',@onMapDisplayChanged);

S.hMapPolarity = uicontrol(pMapDisp,'Style','popupmenu', ...
    'String',{'Positive only','Negative only','Positive + Negative'}, ...
    'Units','normalized','Position',[0.865 0.06 0.12 0.18], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w', ...
    'TooltipString','SCM sign display: positive blackbody, negative winter', ...
    'Callback',@onMapDisplayChanged);

pMapPrev = uipanel(pMAPBG,'Units','normalized','Position',[0.02 0.115 0.96 0.725], ...
    'Title','Preview','BackgroundColor',bg2,'ForegroundColor','w','FontWeight','bold');

S.hMapPreviewPopup = uicontrol(pMapPrev,'Style','popupmenu', ...
    'String',{'No bundle rows'}, ...
    'Units','normalized','Position',[0.03 0.938 0.37 0.050], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w', ...
    'Callback',@onMapPreviewPopup, ...
    'UserData',[]);

uicontrol(pMapPrev,'Style','text','String','Inj side:', ...
    'Units','normalized','Position',[0.43 0.945 0.08 0.040], ...
    'BackgroundColor',bg2,'ForegroundColor','w', ...
    'HorizontalAlignment','left','FontWeight','bold');

S.hMapPreviewSide = uicontrol(pMapPrev,'Style','popupmenu', ...
    'String',{'Unknown','Left','Right'}, ...
    'Units','normalized','Position',[0.52 0.938 0.10 0.050], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w', ...
    'Callback',@onMapPreviewSideChanged);

uicontrol(pMapPrev,'Style','text','String','Ref hemi:', ...
    'Units','normalized','Position',[0.65 0.945 0.09 0.040], ...
    'BackgroundColor',bg2,'ForegroundColor','w', ...
    'HorizontalAlignment','left','FontWeight','bold');

S.hMapRefSide = uicontrol(pMapPrev,'Style','popupmenu', ...
    'String',{'Left','Right'}, ...
    'Units','normalized','Position',[0.75 0.938 0.11 0.050], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w', ...
    'Callback',@onMapDisplayChanged);

uicontrol(pMapPrev,'Style','text','String','Slice:', ...
    'Units','normalized','Position',[0.875 0.945 0.055 0.040], ...
    'BackgroundColor',bg2,'ForegroundColor','w', ...
    'HorizontalAlignment','left','FontWeight','bold');

S.hMapSliceText = uicontrol(pMapPrev,'Style','edit','String','-', ...
    'Units','normalized','Position',[0.930 0.938 0.055 0.050], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w', ...
    'TooltipString','Current step-motor slice. You can also use mouse wheel on Group Maps preview.', ...
    'Callback',@onMapSliceEdit);

S.axMap1 = axes('Parent',pMapPrev,'Units','normalized','Position',[0.03 0.13 0.58 0.78]);
axis(S.axMap1,'off');

S.hMapSideBox = uipanel(pMapPrev, ...
    'Units','normalized','Position',[0.62 0.07 0.36 0.82], ...
    'Title','Side assignment / Map options', ...
    'BackgroundColor',bg2,'ForegroundColor','w','FontWeight','bold');

S.hMapSideTable = uitable(S.hMapSideBox, ...
    'Units','normalized','Position',[0.04 0.55 0.92 0.38], ...
    'Data',cell(0,4), ...
    'ColumnName',{'Animal','Sess','Scan','Inj Side'}, ...
    'ColumnEditable',[false false false false], ...
    'RowName',[], ...
    'BackgroundColor',[0.12 0.12 0.12; 0.10 0.10 0.10], ...
    'ForegroundColor',[1 1 1], ...
    'FontName','Consolas','FontSize',10);

S.hMapUseGlobalWin = uicontrol(S.hMapSideBox,'Style','checkbox', ...
    'String','Use custom global baseline / signal windows', ...
    'Units','normalized','Position',[0.05 0.45 0.90 0.06], ...
    'Value',double(S.mapUseGlobalWindows), ...
    'BackgroundColor',bg2,'ForegroundColor','w', ...
    'Callback',@onMapDisplayChanged);

uicontrol(S.hMapSideBox,'Style','text','String','Base (s):', ...
    'Units','normalized','Position',[0.05 0.34 0.28 0.055], ...
    'BackgroundColor',bg2,'ForegroundColor','w','HorizontalAlignment','left','FontWeight','bold');

S.hMapBase0 = uicontrol(S.hMapSideBox,'Style','edit','String',num2str(S.mapGlobalBaseSec(1)), ...
    'Units','normalized','Position',[0.40 0.33 0.15 0.08], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w','Callback',@onMapDisplayChanged);

S.hMapBase1 = uicontrol(S.hMapSideBox,'Style','edit','String',num2str(S.mapGlobalBaseSec(2)), ...
    'Units','normalized','Position',[0.59 0.33 0.15 0.08], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w','Callback',@onMapDisplayChanged);

uicontrol(S.hMapSideBox,'Style','text','String','Signal (s):', ...
    'Units','normalized','Position',[0.05 0.23 0.28 0.055], ...
    'BackgroundColor',bg2,'ForegroundColor','w','HorizontalAlignment','left','FontWeight','bold');

S.hMapSig0 = uicontrol(S.hMapSideBox,'Style','edit','String',num2str(S.mapGlobalSigSec(1)), ...
    'Units','normalized','Position',[0.40 0.22 0.15 0.08], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w','Callback',@onMapDisplayChanged);

S.hMapSig1 = uicontrol(S.hMapSideBox,'Style','edit','String',num2str(S.mapGlobalSigSec(2)), ...
    'Units','normalized','Position',[0.59 0.22 0.15 0.08], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w','Callback',@onMapDisplayChanged);

S.hMapUnderlayMode = uicontrol(S.hMapSideBox,'Style','popupmenu', ...
    'String',{'Bundle underlay','Bundle normal','Bundle histology','Bundle vascular','Bundle regions','Loaded custom underlay'}, ...
    'Units','normalized','Position',[0.12 0.11 0.76 0.07], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w', ...
    'Callback',@onMapDisplayChanged);

S.hMapLoadUnderlay = mkBtn(S.hMapSideBox,'Load Underlay',[0.22 0.02 0.56 0.07],C.btnAction,@onLoadCustomUnderlay);

pMapBottom = uipanel(pMAPBG,'Units','normalized','Position',[0.02 0.015 0.96 0.085], ...
    'BorderType','none','BackgroundColor',bg2);

S.hMapPreviewSel  = mkBtn(pMapBottom,'Preview Only',       [0.02 0.48 0.13 0.42],C.btnSecondary,@onPreviewSelectedBundle);
S.hMapCompute     = mkBtn(pMapBottom,'Compute Group Maps', [0.16 0.48 0.20 0.42],C.btnPrimary,@onComputeGroupMaps);
S.hMapExportData  = mkBtn(pMapBottom,'Export Data Video',  [0.38 0.48 0.16 0.42],C.btnAction,@onExportGroupMapData);
S.hMapExportSCM   = mkBtn(pMapBottom,'Export Data SCM',    [0.55 0.48 0.15 0.42],C.btnAction,@onExportGroupMapDataSCM);
S.hMapExportPNG   = mkBtn(pMapBottom,'Export PNG',         [0.71 0.50 0.12 0.40],C.btnAction,@onExportGroupMapPNG);
S.hMapExportPPT   = mkBtn(pMapBottom,'Export PPT',         [0.84 0.50 0.12 0.40],C.btnAction,@onExportGroupMapPPT);

S.hMapExportStatus = uicontrol(pMapBottom,'Style','text','String','Ready.', ...
    'Units','normalized','Position',[0.02 0.06 0.96 0.18], ...
    'BackgroundColor',bg2,'ForegroundColor',C.muted, ...
    'HorizontalAlignment','left','FontName','Consolas','FontSize',10);

%%% =====================================================================
%%% FC TAB
%%% =====================================================================
pFCBG = uipanel(S.tabFC,'Units','normalized','Position',[0 0 1 1], ...
    'BorderType','none','BackgroundColor',C.bg);

pFCTop = uipanel(pFCBG,'Units','normalized','Position',[0.02 0.735 0.96 0.255], ...
    'Title','Functional Connectivity Group Analysis', ...
    'BackgroundColor',bg2,'ForegroundColor','w','FontWeight','bold');

S.hFCLoad = mkBtn(pFCTop,'Load FC Bundles',[0.015 0.52 0.145 0.34],C.btnAction,@onLoadFCGroupBundles);
S.hFCScan = mkBtn(pFCTop,'Scan Folder',[0.175 0.52 0.125 0.34],C.btnSecondary,@onScanFCGroupFolder);

uicontrol(pFCTop,'Style','text','String','Group A:', ...
    'Units','normalized','Position',[0.325 0.60 0.075 0.25], ...
    'BackgroundColor',bg2,'ForegroundColor','w','HorizontalAlignment','left','FontWeight','bold');

S.hFCGroupA = uicontrol(pFCTop,'Style','popupmenu','String',S.groupList, ...
    'Units','normalized','Position',[0.405 0.59 0.125 0.27], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w');

uicontrol(pFCTop,'Style','text','String','Group B:', ...
    'Units','normalized','Position',[0.545 0.60 0.075 0.25], ...
    'BackgroundColor',bg2,'ForegroundColor','w','HorizontalAlignment','left','FontWeight','bold');

S.hFCGroupB = uicontrol(pFCTop,'Style','popupmenu','String',S.groupList, ...
    'Units','normalized','Position',[0.625 0.59 0.125 0.27], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w');

uicontrol(pFCTop,'Style','text','String','Display:', ...
    'Units','normalized','Position',[0.765 0.60 0.065 0.25], ...
    'BackgroundColor',bg2,'ForegroundColor','w','HorizontalAlignment','left','FontWeight','bold');

S.hFCDisplay = uicontrol(pFCTop,'Style','popupmenu','String',{'Pearson r','Fisher z'}, ...
    'Units','normalized','Position',[0.835 0.59 0.145 0.27], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w', ...
    'Callback',@updateFCTabPreview);

uicontrol(pFCTop,'Style','text','String','Abs threshold:', ...
    'Units','normalized','Position',[0.325 0.16 0.120 0.25], ...
    'BackgroundColor',bg2,'ForegroundColor','w','HorizontalAlignment','left','FontWeight','bold');

S.hFCThreshold = uicontrol(pFCTop,'Style','edit','String','0', ...
    'Units','normalized','Position',[0.450 0.14 0.080 0.28], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w', ...
    'Callback',@updateFCTabPreview);

S.hFCCompute = mkBtn(pFCTop,'Compute Group FC',[0.560 0.10 0.170 0.36],C.btnPrimary,@onComputeGroupFC);
S.hFCExport  = mkBtn(pFCTop,'Export FC Results',[0.750 0.10 0.170 0.36],C.btnAction,@onExportGroupFC);
%%% GA_FC_SINGLE_CLEAN_UI_20260616_START
% Clean single-group FC-GA layout. No forced Group A vs Group B comparison.
try
    set(S.hFCLoad,   'String','Load FC Bundles', 'Position',[0.015 0.58 0.135 0.30]);
    set(S.hFCScan,   'String','Scan Folder',     'Position',[0.160 0.58 0.105 0.30]);
    set(S.hFCCompute,'String','Compute FC',      'Position',[0.735 0.20 0.120 0.30]);
    set(S.hFCExport, 'String','Export',          'Position',[0.865 0.20 0.105 0.30]);
catch
end

% Reuse Group A popup as the single selected FC group. Hide Group B.
try, set(S.hFCGroupA,'Position',[0.360 0.61 0.130 0.24]); catch, end
try, set(S.hFCGroupB,'Visible','off'); catch, end
try, set(findall(pFCTop,'Style','text','String','Group A:'),'String','Group:','Position',[0.295 0.62 0.060 0.20]); catch, end
try, set(findall(pFCTop,'Style','text','String','Group B:'),'Visible','off'); catch, end

% Reuse existing Display dropdown and threshold edit, but move them cleanly.
try, set(findall(pFCTop,'Style','text','String','Display:'),'Position',[0.505 0.62 0.070 0.20]); catch, end
try, set(S.hFCDisplay,'Position',[0.575 0.61 0.120 0.24]); catch, end
try, set(findall(pFCTop,'Style','text','String','Abs threshold:'),'String','Threshold:','Position',[0.710 0.62 0.080 0.20]); catch, end
try, set(S.hFCThreshold,'Position',[0.790 0.61 0.070 0.24]); catch, end

uicontrol(pFCTop,'Style','text','String','View:', ...
    'Units','normalized','Position',[0.015 0.18 0.050 0.20], ...
    'BackgroundColor',bg2,'ForegroundColor','w','HorizontalAlignment','left','FontWeight','bold');
S.hFCView = uicontrol(pFCTop,'Style','popupmenu', ...
    'String',{'Heatmap','Seed profile','ROI trace','ROI pair','Subject matrix'}, ...
    'Units','normalized','Position',[0.070 0.17 0.145 0.24], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w', ...
    'Callback',@updateFCTabPreview);

uicontrol(pFCTop,'Style','text','String','Seed:', ...
    'Units','normalized','Position',[0.235 0.18 0.050 0.20], ...
    'BackgroundColor',bg2,'ForegroundColor','w','HorizontalAlignment','left','FontWeight','bold');
S.hFCRegion1 = uicontrol(pFCTop,'Style','popupmenu', ...
    'String',{'Load FC first'}, ...
    'Units','normalized','Position',[0.285 0.17 0.175 0.24], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w', ...
    'Callback',@updateFCTabPreview);

uicontrol(pFCTop,'Style','text','String','ROI 2:', ...
    'Units','normalized','Position',[0.475 0.18 0.055 0.20], ...
    'BackgroundColor',bg2,'ForegroundColor','w','HorizontalAlignment','left','FontWeight','bold');
S.hFCRegion2 = uicontrol(pFCTop,'Style','popupmenu', ...
    'String',{'Load FC first'}, ...
    'Units','normalized','Position',[0.535 0.17 0.175 0.24], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w', ...
    'Callback',@updateFCTabPreview);

uicontrol(pFCTop,'Style','text','String','Subject:', ...
    'Units','normalized','Position',[0.015 0.39 0.065 0.18], ...
    'BackgroundColor',bg2,'ForegroundColor','w','HorizontalAlignment','left','FontWeight','bold');
S.hFCSubject = uicontrol(pFCTop,'Style','popupmenu', ...
    'String',{'Group mean'}, ...
    'Units','normalized','Position',[0.085 0.38 0.180 0.22], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w', ...
    'Callback',@updateFCTabPreview);

% Hide stale controls from previous attempts if they exist.
try, if isfield(S,'hFCMatrixMode'), set(S.hFCMatrixMode,'Visible','off'); end, catch, end
try, if isfield(S,'hFCActiveGroup'), set(S.hFCActiveGroup,'Visible','off'); end, catch, end
%%% GA_FC_SINGLE_CLEAN_UI_20260616_END
%%% GA_FC_LAYOUT_TIDY_20260617_START
% Clean up spacing and make every FC control auto-refresh/auto-compute.
try
    set(S.hFCLoad,   'Position',[0.020 0.66 0.140 0.25],'FontSize',11);
    set(S.hFCScan,   'Position',[0.175 0.66 0.115 0.25],'FontSize',11);
    set(findall(pFCTop,'Style','text','String','Group:'),'Position',[0.325 0.69 0.060 0.18]);
    set(S.hFCGroupA, 'Position',[0.385 0.675 0.135 0.22],'Callback',@updateFCTabPreview);
    set(findall(pFCTop,'Style','text','String','Display:'),'Position',[0.545 0.69 0.070 0.18]);
    set(S.hFCDisplay,'Position',[0.615 0.675 0.120 0.22],'Callback',@updateFCTabPreview);
    set(findall(pFCTop,'Style','text','String','Threshold:'),'Position',[0.760 0.69 0.080 0.18]);
    set(S.hFCThreshold,'Position',[0.845 0.675 0.070 0.22],'Callback',@updateFCTabPreview);

    set(findall(pFCTop,'Style','text','String','Subject:'),'Position',[0.020 0.38 0.065 0.17]);
    set(S.hFCSubject,'Position',[0.090 0.365 0.185 0.22],'Callback',@updateFCTabPreview);
    set(findall(pFCTop,'Style','text','String','View:'),'Position',[0.305 0.38 0.050 0.17]);
    set(S.hFCView,'Position',[0.355 0.365 0.150 0.22],'Callback',@updateFCTabPreview);
    set(findall(pFCTop,'Style','text','String','Seed:'),'Position',[0.535 0.38 0.050 0.17]);
    set(S.hFCRegion1,'Position',[0.585 0.365 0.180 0.22],'Callback',@updateFCTabPreview);
    set(findall(pFCTop,'Style','text','String','ROI 2:'),'Position',[0.790 0.38 0.055 0.17]);
    set(S.hFCRegion2,'Position',[0.845 0.365 0.140 0.22],'Callback',@updateFCTabPreview);

    set(S.hFCCompute,'Position',[0.735 0.080 0.120 0.24],'String','Recompute');
    set(S.hFCExport, 'Position',[0.865 0.080 0.105 0.24],'String','Export');
catch ME_fc_layout_tidy
    try, disp(['FC layout tidy warning: ' ME_fc_layout_tidy.message]); catch, end
end
%%% GA_FC_LAYOUT_TIDY_20260617_END
%%% GA_FC_ADVANCED_DISPLAY_UI_20260617_START
% Advanced FC-GA display controls: hemisphere, slices, animals, labels, color, export.
try
    % Row 1
    set(S.hFCLoad,   'Position',[0.020 0.720 0.135 0.200],'FontSize',11);
    set(S.hFCScan,   'Position',[0.165 0.720 0.105 0.200],'FontSize',11);
    set(findall(pFCTop,'Style','text','String','Group:'),'Position',[0.295 0.745 0.055 0.140]);
    set(S.hFCGroupA, 'Position',[0.350 0.725 0.125 0.185],'Callback',@updateFCTabPreview);
    set(findall(pFCTop,'Style','text','String','Display:'),'Position',[0.500 0.745 0.070 0.140]);
    set(S.hFCDisplay,'Position',[0.570 0.725 0.110 0.185],'Callback',@updateFCTabPreview);
    set(findall(pFCTop,'Style','text','String','Threshold:'),'Position',[0.705 0.745 0.080 0.140]);
    set(S.hFCThreshold,'Position',[0.785 0.725 0.065 0.185],'Callback',@updateFCTabPreview);
    set(S.hFCCompute,'Position',[0.865 0.705 0.060 0.215],'String','Recompute','FontSize',10);
    set(S.hFCExport, 'Position',[0.930 0.705 0.055 0.215],'String','Export CSV','FontSize',10);

    % Row 2
    set(findall(pFCTop,'Style','text','String','Subject:'),'Position',[0.020 0.455 0.065 0.130]);
    set(S.hFCSubject,'Position',[0.085 0.440 0.150 0.175],'Callback',@updateFCTabPreview);
    set(findall(pFCTop,'Style','text','String','View:'),'Position',[0.255 0.455 0.045 0.130]);
    set(S.hFCView,'Position',[0.300 0.440 0.145 0.175],'Callback',@updateFCTabPreview);
    set(S.hFCView,'String',{'Heatmap','Seed profile ± SD','Animal pair values','ROI pair summary','Subject matrix','ROI overlay map'});

    uicontrol(pFCTop,'Style','text','String','Hemi:', ...
        'Units','normalized','Position',[0.465 0.455 0.050 0.130], ...
        'BackgroundColor',bg2,'ForegroundColor','w','HorizontalAlignment','left','FontWeight','bold');
    S.hFCHemi = uicontrol(pFCTop,'Style','popupmenu', ...
        'String',{'All','Merged L+R','Left only','Right only','Left vs Right'}, ...
        'Units','normalized','Position',[0.515 0.440 0.120 0.175], ...
        'BackgroundColor',C.editBg,'ForegroundColor','w', ...
        'Callback',@updateFCTabPreview);

    uicontrol(pFCTop,'Style','text','String','Color:', ...
        'Units','normalized','Position',[0.650 0.455 0.055 0.130], ...
        'BackgroundColor',bg2,'ForegroundColor','w','HorizontalAlignment','left','FontWeight','bold');
    S.hFCColorMap = uicontrol(pFCTop,'Style','popupmenu', ...
        'String',{'Blue-White-Red','Blue-White','Red-White-Blue','parula','hot','jet','gray','blackbody'}, ...
        'Units','normalized','Position',[0.705 0.440 0.105 0.175], ...
        'BackgroundColor',C.editBg,'ForegroundColor','w', ...
        'Callback',@updateFCTabPreview);

    % TARGETED_FCGA_DEFAULT_BWR_20260622
    try, set(S.hFCColorMap,'Value',1); catch, end

    uicontrol(pFCTop,'Style','text','String','Labels:', ...
        'Units','normalized','Position',[0.825 0.455 0.055 0.130], ...
        'BackgroundColor',bg2,'ForegroundColor','w','HorizontalAlignment','left','FontWeight','bold');
    S.hFCLabelMode = uicontrol(pFCTop,'Style','popupmenu', ...
        'String',{'Abbrev','Full'}, ...
        'Units','normalized','Position',[0.880 0.440 0.080 0.175], ...
        'BackgroundColor',C.editBg,'ForegroundColor','w', ...
        'Callback',@updateFCTabPreview);

    % Row 3
    set(findall(pFCTop,'Style','text','String','Seed:'),'Position',[0.020 0.185 0.045 0.130]);
    set(S.hFCRegion1,'Position',[0.065 0.170 0.210 0.175],'Callback',@updateFCTabPreview);
    set(findall(pFCTop,'Style','text','String','ROI 2:'),'Position',[0.295 0.185 0.050 0.130]);
    set(S.hFCRegion2,'Position',[0.345 0.170 0.210 0.175],'Callback',@updateFCTabPreview);

    uicontrol(pFCTop,'Style','text','String','Slice:', ...
        'Units','normalized','Position',[0.575 0.185 0.050 0.130], ...
        'BackgroundColor',bg2,'ForegroundColor','w','HorizontalAlignment','left','FontWeight','bold');
    S.hFCSlice = uicontrol(pFCTop,'Style','popupmenu', ...
        'String',{'All slices'}, ...
        'Units','normalized','Position',[0.625 0.170 0.095 0.175], ...
        'BackgroundColor',C.editBg,'ForegroundColor','w', ...
        'Callback',@updateFCTabPreview);

    S.hFCAnimals = mkBtn(pFCTop,'Animals...',[0.735 0.155 0.080 0.205],C.btnSecondary,@(~,~) selectFCAnimals_SAFE_20260617(hFig));
    S.hFCNames   = mkBtn(pFCTop,'Names',[0.825 0.155 0.065 0.205],C.btnSecondary,@(~,~) showFCRegionNames_SAFE_20260617(hFig));
    S.hFCExportPNG = mkBtn(pFCTop,'PNG',[0.900 0.155 0.065 0.205],C.btnAction,@(~,~) exportFCHighResPNG_ADV_20260617(hFig));
    % TARGETED_FCGA_ZOOM_BUTTON_20260622
    try
        S.hFCZoom = mkBtn(pFCTop,'Large',[0.895 0.020 0.070 0.105],C.btnAction,@(~,~) showFCLargeView_GA_20260622(hFig));
        set(S.hFCZoom,'TooltipString','Open current FC-GA view in a large exportable window');
    catch
        try, S.hFCZoom = mkBtn(pFCTop,'Large',[0.895 0.020 0.070 0.105],C.btnAction,@(~,~) showFCLargeView_GA_20260622(hFig)); catch, end
    end
    % TARGETED_FCGA_STYLE_UI_20260622: y-axis and plot-color controls for FC-GA pair plots.
    try
        uicontrol(pFCTop,'Style','text','String','Y:','Units','normalized','Position',[0.020 0.020 0.025 0.100],'BackgroundColor',bg2,'ForegroundColor','w','HorizontalAlignment','left','FontWeight','bold');
        S.hFCYAuto = uicontrol(pFCTop,'Style','checkbox','String','Auto','Value',1,'Units','normalized','Position',[0.045 0.015 0.060 0.120],'BackgroundColor',bg2,'ForegroundColor','w','Callback',@updateFCTabPreview);
        S.hFCYMin = uicontrol(pFCTop,'Style','edit','String','0','Units','normalized','Position',[0.110 0.020 0.050 0.105],'BackgroundColor',C.editBg,'ForegroundColor','w','Callback',@updateFCTabPreview);
        S.hFCYMax = uicontrol(pFCTop,'Style','edit','String','1.5','Units','normalized','Position',[0.165 0.020 0.050 0.105],'BackgroundColor',C.editBg,'ForegroundColor','w','Callback',@updateFCTabPreview);
        S.hFCYStep = uicontrol(pFCTop,'Style','edit','String','0.5','Units','normalized','Position',[0.220 0.020 0.050 0.105],'BackgroundColor',C.editBg,'ForegroundColor','w','Callback',@updateFCTabPreview);
        uicontrol(pFCTop,'Style','text','String','Plot:','Units','normalized','Position',[0.285 0.020 0.045 0.100],'BackgroundColor',bg2,'ForegroundColor','w','HorizontalAlignment','left','FontWeight','bold');
        S.hFCPlotColor = uicontrol(pFCTop,'Style','popupmenu','String',{'Auto','Blue','Red','Green','Orange','Purple','Black','White','Gray'},'Units','normalized','Position',[0.330 0.020 0.085 0.105],'BackgroundColor',C.editBg,'ForegroundColor','w','Callback',@updateFCTabPreview);
    catch ME_fc_style_ui
        try, disp(['FC style UI warning: ' ME_fc_style_ui.message]); catch, end
    end
catch ME_fcadv_ui
    try, disp(['FC advanced UI warning: ' ME_fcadv_ui.message]); catch, end
end
%%% GA_FC_ADVANCED_DISPLAY_UI_20260617_END
S.hFCInfo = uicontrol(pFCBG,'Style','text', ...
    'String','Load FC_GroupBundle_*.mat files exported from FunctionalConnectivity.m.', ...
    'Units','normalized','Position',[0.02 0.018 0.96 0.035], ...
    'BackgroundColor',C.bg,'ForegroundColor',C.muted, ...
    'HorizontalAlignment','left','FontName','Consolas','FontSize',10);

pFCAx = uipanel(pFCBG,'Units','normalized','Position',[0.02 0.065 0.96 0.650], ...
    'Title','FC matrices', ...
    'BackgroundColor',bg2,'ForegroundColor','w','FontWeight','bold');

S.axFCA = axes('Parent',pFCAx,'Units','normalized','Position',[0.060 0.565 0.365 0.360]);
S.axFCB = axes('Parent',pFCAx,'Units','normalized','Position',[0.570 0.565 0.365 0.360]);
S.axFCD = axes('Parent',pFCAx,'Units','normalized','Position',[0.060 0.090 0.365 0.360]);
S.axFCP = axes('Parent',pFCAx,'Units','normalized','Position',[0.570 0.090 0.365 0.360]);

fcNoDataLocal(S.axFCA,'Group A mean FC',C);
fcNoDataLocal(S.axFCB,'Group B mean FC',C);
fcNoDataLocal(S.axFCD,'Difference: A - B',C);
fcNoDataLocal(S.axFCP,'p-value map',C);
% GA_FC_SINGLE_DEFAULT_AXIS_20260616
try, set(S.axFCA,'Position',[0.070 0.110 0.840 0.800]); catch, end
try, set(S.axFCB,'Visible','off'); catch, end
try, set(S.axFCD,'Visible','off'); catch, end
try, set(S.axFCP,'Visible','off'); catch, end

%%% =====================================================================
%%% STATS / EXPORT TAB
%%% =====================================================================
pSTATSBG = uipanel(S.tabSTATS,'Units','normalized','Position',[0 0 1 1], ...
    'BorderType','none','BackgroundColor',C.bg);

pStats = uipanel(pSTATSBG,'Units','normalized','Position',[0.02 0.54 0.96 0.44], ...
    'Title','Metric statistics','BackgroundColor',bg2,'ForegroundColor','w','FontWeight','bold');

uicontrol(pStats,'Style','text','String','Test:', ...
    'Units','normalized','Position',[0.02 0.72 0.12 0.20], ...
    'BackgroundColor',bg2,'ForegroundColor','w','HorizontalAlignment','left','FontWeight','bold');

S.hTest = uicontrol(pStats,'Style','popupmenu', ...
    'String',{'None','One-sample t-test (vs 0)','Two-sample t-test (Student, equal var)','Two-sample t-test (Welch)','One-way ANOVA (groups)'}, ...
    'Units','normalized','Position',[0.14 0.74 0.50 0.20], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w','Callback',@onStatsChanged, ...
    'Value',3);

uicontrol(pStats,'Style','text','String','Alpha:', ...
    'Units','normalized','Position',[0.66 0.72 0.10 0.20], ...
    'BackgroundColor',bg2,'ForegroundColor','w','HorizontalAlignment','left','FontWeight','bold');

S.hAlpha = uicontrol(pStats,'Style','edit','String',num2str(S.alpha), ...
    'Units','normalized','Position',[0.75 0.74 0.10 0.20], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w','Callback',@onStatsChanged);

uicontrol(pStats,'Style','text','String','Annotate:', ...
    'Units','normalized','Position',[0.02 0.52 0.12 0.14], ...
    'BackgroundColor',bg2,'ForegroundColor','w','HorizontalAlignment','left','FontWeight','bold');

S.hAnnotMode = uicontrol(pStats,'Style','popupmenu', ...
    'String',{'None','Bottom only','Both'}, ...
    'Units','normalized','Position',[0.14 0.54 0.25 0.16], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w','Callback',@onStatsChanged, ...
    'Value',2);

S.hShowPText = uicontrol(pStats,'Style','checkbox','String','Show p-value text', ...
    'Units','normalized','Position',[0.42 0.54 0.25 0.16], ...
    'Value',double(S.showPText), ...
    'BackgroundColor',bg2,'ForegroundColor','w','Callback',@onStatsChanged);

pOut = uipanel(pStats,'Units','normalized','Position',[0.02 0.02 0.96 0.46], ...
    'Title','Outlier detection','BackgroundColor',bg2,'ForegroundColor','w','FontWeight','bold');

S.hOutMethod = uicontrol(pOut,'Style','popupmenu','String',{'None','MAD robust z-score','IQR rule'}, ...
    'Units','normalized','Position',[0.02 0.79 0.22 0.16], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w');

S.hOutParam = uicontrol(pOut,'Style','edit','String',num2str(S.outMADthr), ...
    'Units','normalized','Position',[0.26 0.79 0.08 0.16], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w');

S.hDetectOut  = mkBtn(pOut,'Detect',[0.38 0.79 0.11 0.16],C.btnAction,@onDetectOutliers);
S.hExcludeOut = mkBtn(pOut,'Exclude',[0.51 0.79 0.11 0.16],C.btnDanger,@onExcludeOutliers);
S.hRevertOut  = mkBtn(pOut,'Revert',[0.64 0.79 0.11 0.16],C.btnSecondary,@onRevertExcluded);

S.hOutInfo = uicontrol(pOut,'Style','listbox', ...
    'Units','normalized','Position',[0.02 0.06 0.96 0.60], ...
    'String',{'No outliers detected yet.'}, ...
    'BackgroundColor',C.axisBg,'ForegroundColor','w', ...
    'FontName','Consolas','FontSize',11);

pRun = uipanel(pSTATSBG,'Units','normalized','Position',[0.02 0.02 0.96 0.48], ...
    'Title','Run / Export','BackgroundColor',bg2,'ForegroundColor','w','FontWeight','bold');

S.hRun         = mkBtn(pRun,'Run Analysis',[0.14 0.62 0.22 0.24],C.btnPrimary,@onRun);
S.hExport      = mkBtn(pRun,'Export Results',[0.39 0.62 0.22 0.24],C.btnSecondary,@onExport);
S.hExportExcel = mkBtn(pRun,'Export Excel',[0.64 0.62 0.22 0.24],C.btnAction,@onExportExcel);

S.hStatus = uicontrol(pRun,'Style','text','String','Ready.', ...
    'Units','normalized','Position',[0.04 0.10 0.92 0.36], ...
    'BackgroundColor',bg2,'ForegroundColor',C.muted, ...
    'HorizontalAlignment','center','FontSize',F.small);

%%% =====================================================================
%%% PREVIEW TAB
%%% =====================================================================
S.hPrevBG = uipanel(S.tabPREV,'Units','normalized','Position',[0 0 1 1], ...
    'BorderType','none','BackgroundColor',C.bg);

S.hPrevTop = uipanel(S.hPrevBG,'Units','normalized','Position',[0.02 0.895 0.96 0.095], ...
    'BackgroundColor',bg2,'ForegroundColor','w','FontWeight','bold');

S.hPrevExportTop  = mkBtn(S.hPrevTop,'Export Top PNG',    [0.015 0.16 0.140 0.68],C.btnSecondary,@(~,~) onExportPreviewPNG(1));
S.hPrevExportBot  = mkBtn(S.hPrevTop,'Export Bottom PNG', [0.165 0.16 0.155 0.68],C.btnSecondary,@(~,~) onExportPreviewPNG(2));
S.hPrevExportBoth = mkBtn(S.hPrevTop,'Export Both PNGs',  [0.330 0.16 0.155 0.68],C.btnSecondary,@(~,~) onExportPreviewPNG(3));

S.hPrevLblView = uicontrol(S.hPrevTop,'Style','text','String','View:','Units','normalized','Position',[0.510 0.18 0.055 0.64],'BackgroundColor',bg2,'ForegroundColor','w','HorizontalAlignment','left','FontWeight','bold','FontSize',12);
S.hPrevStyle = uicontrol(S.hPrevTop,'Style','popupmenu','String',{'Dark','Light'},'Units','normalized','Position',[0.565 0.18 0.090 0.64],'BackgroundColor',C.editBg,'ForegroundColor','w','FontSize',12,'Callback',@onPreviewStyleChanged);
S.hPrevGrid = uicontrol(S.hPrevTop,'Style','checkbox','String','Grid','Units','normalized','Position',[0.665 0.15 0.065 0.70],'Value',double(S.previewShowGrid),'BackgroundColor',bg2,'ForegroundColor','w','FontSize',12,'Callback',@onPreviewStyleChanged);
S.hSmoothEnable = uicontrol(S.hPrevTop,'Style','checkbox','String','Smoothing','Units','normalized','Position',[0.740 0.15 0.120 0.70],'Value',double(S.tc_previewSmooth),'BackgroundColor',bg2,'ForegroundColor','w','FontSize',12,'Callback',@onSmoothChanged);
S.hPrevLblWin = uicontrol(S.hPrevTop,'Style','text','String','Win (s):','Units','normalized','Position',[0.865 0.18 0.070 0.64],'BackgroundColor',bg2,'ForegroundColor','w','HorizontalAlignment','left','FontWeight','bold','FontSize',12);
S.hSmoothWin = uicontrol(S.hPrevTop,'Style','edit','String',num2str(S.tc_previewSmoothWinSec),'Units','normalized','Position',[0.935 0.18 0.055 0.64],'BackgroundColor',C.editBg,'ForegroundColor','w','FontSize',12,'Callback',@onSmoothChanged);

S.ax1 = axes('Parent',S.hPrevBG,'Units','normalized','Position',[0.095 0.540 0.850 0.285]);
S.ax2 = axes('Parent',S.hPrevBG,'Units','normalized','Position',[0.095 0.120 0.850 0.285]);
try
    set(S.hPrevTop,'Position',[0.02 0.735 0.96 0.255]);
    set(S.ax1,'Position',[0.095 0.455 0.850 0.245]);
    set(S.ax2,'Position',[0.095 0.060 0.850 0.245]);

    try, set(S.hPrevExportTop, 'Position',[0.015 0.650 0.120 0.270],'FontSize',11); catch, end
    try, set(S.hPrevExportBot, 'Position',[0.145 0.650 0.130 0.270],'FontSize',11); catch, end
    try, set(S.hPrevExportBoth,'Position',[0.285 0.650 0.140 0.270],'FontSize',11); catch, end

    try, set(S.hPrevLblView,'Position',[0.465 0.735 0.050 0.120],'HorizontalAlignment','right','FontSize',12); catch, end
    try, set(S.hPrevStyle,  'Position',[0.525 0.710 0.090 0.180],'FontSize',11); catch, end
    try, set(S.hPrevGrid,   'Position',[0.635 0.700 0.060 0.190],'FontSize',11); catch, end
    try, set(S.hSmoothEnable,'Position',[0.710 0.700 0.110 0.190],'FontSize',11); catch, end
    try, set(S.hPrevLblWin,'Position',[0.815 0.735 0.065 0.120],'HorizontalAlignment','right','FontSize',12); catch, end
    try, set(S.hSmoothWin,'Position',[0.895 0.650 0.055 0.270],'FontSize',11); catch, end

    uicontrol(S.hPrevTop,'Style','text','String','Line width','Units','normalized', ...
        'Position',[0.020 0.470 0.095 0.120],'BackgroundColor',bg2,'ForegroundColor','w', ...
        'HorizontalAlignment','left','FontWeight','bold','FontSize',11,'Tag','GA_RPV_DYNAMIC');
    S.hPrevLineWidth = uicontrol(S.hPrevTop,'Style','slider','Min',1,'Max',6,'Value',2.8, ...
        'Units','normalized','Position',[0.125 0.465 0.140 0.110],'BackgroundColor',C.editBg, ...
        'Callback',@onSmoothChanged,'Tag','GA_RPV_LINE_WIDTH');

    uicontrol(S.hPrevTop,'Style','text','String','Shade alpha','Units','normalized', ...
        'Position',[0.285 0.470 0.100 0.120],'BackgroundColor',bg2,'ForegroundColor','w', ...
        'HorizontalAlignment','left','FontWeight','bold','FontSize',11,'Tag','GA_RPV_DYNAMIC');
    S.hPrevShadeAlpha = uicontrol(S.hPrevTop,'Style','slider','Min',0,'Max',0.70,'Value',0.22, ...
        'Units','normalized','Position',[0.395 0.465 0.140 0.110],'BackgroundColor',C.editBg, ...
        'Callback',@onSmoothChanged,'Tag','GA_RPV_SHADE_ALPHA');

    uicontrol(S.hPrevTop,'Style','text','String','A color','Units','normalized', ...
        'Position',[0.560 0.470 0.065 0.120],'BackgroundColor',bg2,'ForegroundColor','w', ...
        'HorizontalAlignment','left','FontWeight','bold','FontSize',11,'Tag','GA_RPV_DYNAMIC');
    S.hPrevColorA = uicontrol(S.hPrevTop,'Style','popupmenu','String',{'PACAP blue','Vehicle gray','Teal','Dark blue','Orange','Red','Green','Purple','Cyan','Magenta','Yellow','Dark green','Dark red','Black'}, ...
        'Value',1,'Units','normalized','Position',[0.630 0.445 0.125 0.180], ...
        'BackgroundColor',C.editBg,'ForegroundColor','w','FontSize',11,'Callback',@onSmoothChanged,'Tag','GA_RPV_COLOR_A');

    uicontrol(S.hPrevTop,'Style','text','String','B color','Units','normalized', ...
        'Position',[0.775 0.470 0.065 0.120],'BackgroundColor',bg2,'ForegroundColor','w', ...
        'HorizontalAlignment','left','FontWeight','bold','FontSize',11,'Tag','GA_RPV_DYNAMIC');
    S.hPrevColorB = uicontrol(S.hPrevTop,'Style','popupmenu','String',{'PACAP blue','Vehicle gray','Teal','Dark blue','Orange','Red','Green','Purple','Cyan','Magenta','Yellow','Dark green','Dark red','Black'}, ...
        'Value',2,'Units','normalized','Position',[0.845 0.445 0.125 0.180], ...
        'BackgroundColor',C.editBg,'ForegroundColor','w','FontSize',11,'Callback',@onSmoothChanged,'Tag','GA_RPV_COLOR_B');

    S.hPrevAnimalLabels = uicontrol(S.hPrevTop,'Style','checkbox','String','Animal labels', ...
        'Units','normalized','Position',[0.845 0.330 0.130 0.110], ...
        'Value',0,'BackgroundColor',bg2,'ForegroundColor','w','FontSize',10, ...
        'Callback',@onSmoothChanged,'Tag','GA_RPV_ANIMAL_LABELS');

    uicontrol(S.hPrevTop,'Style','text','String','X min / max','Units','normalized', ...
        'Position',[0.020 0.155 0.095 0.120],'BackgroundColor',bg2,'ForegroundColor','w', ...
        'HorizontalAlignment','left','FontWeight','bold','FontSize',11,'Tag','GA_RPV_DYNAMIC');
    S.hPrevXMin = uicontrol(S.hPrevTop,'Style','edit','String','0','Units','normalized', ...
        'Position',[0.125 0.080 0.055 0.250],'BackgroundColor',C.editBg,'ForegroundColor','w', ...
        'FontSize',11,'Callback',@onSmoothChanged,'Tag','GA_RPV_XMIN');
    S.hPrevXMax = uicontrol(S.hPrevTop,'Style','edit','String','45','Units','normalized', ...
        'Position',[0.190 0.080 0.055 0.250],'BackgroundColor',C.editBg,'ForegroundColor','w', ...
        'FontSize',11,'Callback',@onSmoothChanged,'Tag','GA_RPV_XMAX');

    uicontrol(S.hPrevTop,'Style','text','String','Top Ymax','Units','normalized', ...
        'Position',[0.295 0.155 0.075 0.120],'BackgroundColor',bg2,'ForegroundColor','w', ...
        'HorizontalAlignment','left','FontWeight','bold','FontSize',11,'Tag','GA_RPV_DYNAMIC');
    S.hPrevTopYmax = uicontrol(S.hPrevTop,'Style','edit','String','50','Units','normalized', ...
        'Position',[0.375 0.080 0.055 0.250],'BackgroundColor',C.editBg,'ForegroundColor','w', ...
        'FontSize',11,'Callback',@onSmoothChanged,'Tag','GA_RPV_TOP_YMAX');

    uicontrol(S.hPrevTop,'Style','text','String','Top step','Units','normalized', ...
        'Position',[0.465 0.155 0.070 0.120],'BackgroundColor',bg2,'ForegroundColor','w', ...
        'HorizontalAlignment','left','FontWeight','bold','FontSize',11,'Tag','GA_RPV_DYNAMIC');
    S.hPrevTopStep = uicontrol(S.hPrevTop,'Style','edit','String','10','Units','normalized', ...
        'Position',[0.540 0.080 0.055 0.250],'BackgroundColor',C.editBg,'ForegroundColor','w', ...
        'FontSize',11,'Callback',@onSmoothChanged,'Tag','GA_RPV_TOP_STEP');

    uicontrol(S.hPrevTop,'Style','text','String','Bottom Ymax','Units','normalized', ...
        'Position',[0.635 0.155 0.095 0.120],'BackgroundColor',bg2,'ForegroundColor','w', ...
        'HorizontalAlignment','left','FontWeight','bold','FontSize',11,'Tag','GA_RPV_DYNAMIC');
    S.hPrevBotYmax = uicontrol(S.hPrevTop,'Style','edit','String','50','Units','normalized', ...
        'Position',[0.735 0.080 0.055 0.250],'BackgroundColor',C.editBg,'ForegroundColor','w', ...
        'FontSize',11,'Callback',@onSmoothChanged,'Tag','GA_RPV_BOT_YMAX');

    uicontrol(S.hPrevTop,'Style','text','String','Bottom step','Units','normalized', ...
        'Position',[0.825 0.155 0.100 0.120],'BackgroundColor',bg2,'ForegroundColor','w', ...
        'HorizontalAlignment','left','FontWeight','bold','FontSize',11,'Tag','GA_RPV_DYNAMIC');
    S.hPrevBotStep = uicontrol(S.hPrevTop,'Style','edit','String','10','Units','normalized', ...
        'Position',[0.930 0.080 0.055 0.250],'BackgroundColor',C.editBg,'ForegroundColor','w', ...
        'FontSize',11,'Callback',@onSmoothChanged,'Tag','GA_RPV_BOT_STEP');

catch ME_ga_roi_visual_ui
    disp('ROI preview visual UI patch failed:');
    disp(ME_ga_roi_visual_ui.message);
end


%%% =====================================================================
%%% INITIALIZE
%%% =====================================================================
try, fcGACleanFinalLayout_20260624(S); fcGAFixRow2Overlap_FORCE_20260624(S); catch, end%INIT_FCGA_LAYOUT
guidata(hFig,S);
try, set(hFig,'WindowScrollWheelFcn',@onMapScrollWheel); catch, end
updateManualTabs();
refreshTable();
clearPreview();
refreshMapBundlePopup();
updateMapSideSummaryTable();
setStatusText('Ready. Modular main loaded.');

try, GA_force_scm_alpha_20260504(gcf,10,20); catch, end; % AUTO_FORCE_SCM_ALPHA_20260504
drawnow;

%%% =====================================================================
%%% CALLBACKS
%%% =====================================================================

    function closeMe(src,~)
        S0 = guidata(src);
        if isempty(S0)
            delete(src);
            return;
        end
        if isfield(S0,'isClosing') && S0.isClosing
            delete(src);
            return;
        end
        S0.isClosing = true;
        guidata(src,S0);
        try
            setStatus(true);
        catch
        end
        try
            if isfield(S0.opt,'onClose') && ~isempty(S0.opt.onClose)
                S0.opt.onClose();
            end
        catch
        end
        delete(src);
    end

    function onCellSelect(~,evt)
        S0 = guidata(hFig);
        if isempty(evt) || ~isfield(evt,'Indices') || isempty(evt.Indices)
            S0.selectedRows = [];
        else
            S0.selectedRows = unique(evt.Indices(:,1));
        end
        guidata(hFig,S0);
        updateSelLabel();
    end

    function onCellEdit(~,~)
        syncSubjFromTable();
        S0 = guidata(hFig);
        S0 = sanitizeTableStruct(S0);
        S0 = ensureFCRowFilesSizeGA_TARGETED(S0);
        guidata(hFig,S0);
        refreshTable();
    end

    function onApplyAllToggle(src,~)
        S0 = guidata(hFig);
        S0.applyAllIfNoneSelected = logical(get(src,'Value'));
        guidata(hFig,S0);
    end

    function onQuickGroupChanged(src,~)
        S0 = guidata(hFig);
        g = getSelectedPopupString(src);
        c = mapConditionFromGroup(S0,g);
        if ~isempty(c)
            setPopupToString(S0.hQuickCond,c);
        end
    end

    function onApplyGroup(~,~)
        syncSubjFromTable();
        S0 = guidata(hFig);
        rows = getTargetRows(S0);
        if isempty(rows)
            setStatusText('No rows selected.');
            return;
        end
        g = getSelectedPopupString(S0.hQuickGroup);
        cAuto = mapConditionFromGroup(S0,g);
        for r = rows(:)'
            S0.subj{r,3} = g;
            if ~isempty(cAuto)
                S0.subj{r,4} = cAuto;
            end
        end
        guidata(hFig,S0);
        refreshTable();
        setStatusText(['Applied group: ' g]);
    end

    function onApplyCond(~,~)
        syncSubjFromTable();
        S0 = guidata(hFig);
        rows = getTargetRows(S0);
        if isempty(rows)
            setStatusText('No rows selected.');
            return;
        end
        c = getSelectedPopupString(S0.hQuickCond);
        for r = rows(:)'
            S0.subj{r,4} = c;
        end
        guidata(hFig,S0);
        refreshTable();
        setStatusText(['Applied condition: ' c]);
    end

    function onApplyBoth(~,~)
        syncSubjFromTable();
        S0 = guidata(hFig);
        rows = getTargetRows(S0);
        if isempty(rows)
            setStatusText('No rows selected.');
            return;
        end
        g = getSelectedPopupString(S0.hQuickGroup);
        c = getSelectedPopupString(S0.hQuickCond);
        for r = rows(:)'
            S0.subj{r,3} = g;
            S0.subj{r,4} = c;
        end
        guidata(hFig,S0);
        refreshTable();
        setStatusText(['Applied group/condition: ' g ' / ' c]);
    end

    function onAddGroup(~,~)
        S0 = guidata(hFig);
        answ = inputdlg({'New group name:'},'Add group',1,{''});
        if isempty(answ), return; end
        nm = strtrimSafe(answ{1});
        if isempty(nm), return; end
        S0.groupList = mergeUniqueStable(S0.groupList,{nm});
        guidata(hFig,S0);
        refreshTable();
    end

    function onAddCond(~,~)
        S0 = guidata(hFig);
        answ = inputdlg({'New condition name:'},'Add condition',1,{''});
        if isempty(answ), return; end
        nm = strtrimSafe(answ{1});
        if isempty(nm), return; end
        S0.condList = mergeUniqueStable(S0.condList,{nm});
        guidata(hFig,S0);
        refreshTable();
    end

    function onHelp(~,~)
        msg = sprintf([ ...
            'GROUP ANALYSIS MODULAR MAIN\n\n' ...
            'This reduced GroupAnalysis.m only manages the GUI and state.\n\n' ...
            'Backends are delegated to:\n' ...
            '  GroupAnalysis_Map.m\n' ...
            '  GroupAnalysis_FC.m\n' ...
            '  GroupAnalysis_Common.m\n\n' ...
            'If a button gives "module action failed", the action name is missing from the corresponding module dispatcher.\n\n' ...
            'Recommended test order:\n' ...
            '1. Start GUI.\n' ...
            '2. Add Bundles.\n' ...
            '3. Open Group Maps tab.\n' ...
            '4. Preview Only.\n' ...
            '5. Compute Group Maps.\n' ...
            '6. Test Export PNG, then PPT.\n']);
        helpdlg(msg,'GroupAnalysis Help');
    end

    function onAddFiles(~,~)
        syncSubjFromTable();
        S0 = guidata(hFig);
        startPath = getSmartBrowseDir(S0);
        [f,p] = uigetfile({'*.mat;*.txt','MAT or TXT (*.mat, *.txt)'}, ...
            'Select DATA / ROI / bundle files',startPath,'MultiSelect','on');
        if isequal(f,0), return; end
        if ischar(f), f = {f}; end
        for i = 1:numel(f)
            S0 = addFileSmartLight(S0,fullfile(p,f{i}));
        end
        S0.opt.startDir = p;
        guidata(hFig,S0);
        refreshTable();
        setStatusText(sprintf('Added %d file(s).',numel(f)));
    end

    function onAddBundles(~,~)
        syncSubjFromTable();
        S0 = guidata(hFig);
        startPath = getSmartBrowseDir(S0);
        [f,p] = uigetfile({'*.mat','SCM Group bundle MAT (*.mat)'}, ...
            'Select SCM Group bundle MAT files',startPath,'MultiSelect','on');
        if isequal(f,0), return; end
        if ischar(f), f = {f}; end

        sel = clampSelRows(S0.selectedRows,size(S0.subj,1));
        if ~isempty(sel)
            nDirect = min(numel(sel),numel(f));
            for ii = 1:nDirect
                S0 = assignBundleToRow(S0,sel(ii),fullfile(p,f{ii}));
            end
            for ii = nDirect+1:numel(f)
                S0 = addBundleAsNewRow(S0,fullfile(p,f{ii}));
            end
        else
            for ii = 1:numel(f)
                S0 = addBundleAsNewRow(S0,fullfile(p,f{ii}));
            end
        end

        S0.opt.startDir = p;
        S0 = sanitizeTableStruct(S0);
        S0 = ensureRowPacapSideSize(S0);
        S0 = ensureFCRowFilesSizeGA_TARGETED(S0);
        S0 = ensureFCRowFilesSizeGA_TARGETED(S0);
        guidata(hFig,S0);
        refreshTable();
        refreshMapBundlePopup();
        setStatusText(sprintf('Added %d bundle file(s).',numel(f)));
    end

    function onAddFolder(~,~)
        syncSubjFromTable();
        S0 = guidata(hFig);
        startPath = getSmartBrowseDir(S0);
        folder = uigetdir(startPath,'Select a folder to scan');
        if isequal(folder,0), return; end
        dm = dir(fullfile(folder,'*.mat'));
        dt = dir(fullfile(folder,'*.txt'));
        for i = 1:numel(dm)
            S0 = addFileSmartLight(S0,fullfile(dm(i).folder,dm(i).name));
        end
        for i = 1:numel(dt)
            S0 = addFileSmartLight(S0,fullfile(dt(i).folder,dt(i).name));
        end
        S0.opt.startDir = folder;
        guidata(hFig,S0);
        refreshTable();
        refreshMapBundlePopup();
        setStatusText(sprintf('Scanned folder. Added %d file(s).',numel(dm)+numel(dt)));
    end

    function onRemoveSelected(~,~)
        syncSubjFromTable();
        S0 = guidata(hFig);
        sel = clampSelRows(S0.selectedRows,size(S0.subj,1));
        if isempty(sel)
            sel = find(logicalCol(S0.subj,1));
        end
        if isempty(sel)
            setStatusText('No rows selected.');
            return;
        end
        S0.subj(sel,:) = [];
        if isfield(S0,'rowPacapSide') && numel(S0.rowPacapSide) >= max(sel)
            keep = true(numel(S0.rowPacapSide),1);
            keep(sel) = false;
            S0.rowPacapSide = S0.rowPacapSide(keep);
        end
        if isfield(S0,'fcRowFiles') && numel(S0.fcRowFiles) >= max(sel)
            keepFC = true(numel(S0.fcRowFiles),1);
            keepFC(sel) = false;
            S0.fcRowFiles = S0.fcRowFiles(keepFC);
        end
        S0.selectedRows = [];
        S0.lastROI = struct();
        S0.lastMAP = struct();
        S0.lastFC = struct();
        S0 = ensureRowPacapSideSize(S0);
        S0 = ensureFCRowFilesSizeGA_TARGETED(S0);
        guidata(hFig,S0);
        refreshTable();
        clearPreview();
        refreshMapBundlePopup();
        setStatusText(sprintf('Removed %d row(s).',numel(sel)));
    end

    function onSaveList(~,~)
        syncSubjFromTable();
        S0 = guidata(hFig);
        startPath = getSmartBrowseDir(S0);
        [f,p] = uiputfile({'*.mat','MAT list (*.mat)'}, ...
            'Save subject list',fullfile(startPath,'GroupSubjects.mat'));
        if isequal(f,0), return; end
        subj = S0.subj;
        groupList = S0.groupList;
        condList = S0.condList;
        rowPacapSide = S0.rowPacapSide;
        save(fullfile(p,f),'subj','groupList','condList','rowPacapSide','-v7');
        S0.opt.startDir = p;
        guidata(hFig,S0);
        setStatusText('Saved list.');
    end

    function onLoadList(~,~)
        S0 = guidata(hFig);
        startPath = getSmartBrowseDir(S0);
        [f,p] = uigetfile({'*.mat','MAT list (*.mat)'},'Load subject list',startPath);
        if isequal(f,0), return; end
        L = load(fullfile(p,f));
        if isfield(L,'subj'), S0.subj = L.subj; end
        if isfield(L,'groupList'), S0.groupList = L.groupList; end
        if isfield(L,'condList'), S0.condList = L.condList; end
        if isfield(L,'rowPacapSide')
            S0.rowPacapSide = L.rowPacapSide;
        else
            S0.rowPacapSide = cell(size(S0.subj,1),1);
        end
        if isfield(L,'fcRowFiles')
            S0.fcRowFiles = L.fcRowFiles;
        else
            S0.fcRowFiles = cell(size(S0.subj,1),1);
        end
        S0.opt.startDir = p;
        S0.lastROI = struct();
        S0.lastMAP = struct();
        S0.lastFC = struct();
        S0.selectedRows = [];
        S0 = sanitizeTableStruct(S0);
        S0 = ensureRowPacapSideSize(S0);
        S0 = ensureFCRowFilesSizeGA_TARGETED(S0);
        S0 = ensureFCRowFilesSizeGA_TARGETED(S0);
        guidata(hFig,S0);
        refreshTable();
        refreshMapBundlePopup();
        clearPreview();
        setStatusText('Loaded list.');
    end

    function onRevertExcluded(~,~)
        syncSubjFromTable();
        S0 = guidata(hFig);
        for r = 1:size(S0.subj,1)
            st = lower(strtrimSafe(S0.subj{r,9}));
            if contains(st,'excluded') || contains(st,'not used')
                S0.subj{r,1} = true;
                S0.subj{r,9} = '';
            end
        end
        S0.outlierKeys = {};
        S0.outlierInfo = {};
        S0.lastROI = struct();
        S0.lastMAP = struct();
        guidata(hFig,S0);
        refreshTable();
        setStatusText('Reverted excluded rows.');
    end

    function onTabClicked(tabName)
        S0 = guidata(hFig);
        S0.activeTab = upper(strtrimSafe(tabName));
        switch S0.activeTab
            case 'ROI'
                S0.mode = 'ROI Timecourse';
                try, set(S0.hMode,'Value',1); catch, end
            case 'MAP'
                S0.mode = 'Group Maps';
                try, set(S0.hMode,'Value',2); catch, end
            case 'FC'
                S0.mode = 'Functional Connectivity';
            case 'STATS'
                S0.mode = 'ROI Timecourse';
                try, set(S0.hMode,'Value',1); catch, end
            case 'PREV'
                S0.mode = 'ROI Timecourse';
                try, set(S0.hMode,'Value',1); catch, end
        end
        guidata(hFig,S0);
        updateManualTabs();
        if strcmpi(S0.activeTab,'MAP')
            refreshMapBundlePopup();
            updateMapSideSummaryTable();
            updateMapTabPreview();
        elseif strcmpi(S0.activeTab,'FC')
            updateFCTabPreview();
        elseif strcmpi(S0.activeTab,'PREV')
            updatePreview();
        end
    end

    function onModeChanged(src,~)
        S0 = guidata(hFig);
        items = get(src,'String');
        S0.mode = items{get(src,'Value')};
        if strcmpi(S0.mode,'Group Maps')
            S0.activeTab = 'MAP';
        else
            S0.activeTab = 'ROI';
        end
        guidata(hFig,S0);
        updateManualTabs();
    end

    function onROIChanged(~,~)
        S0 = readROISettingsFromUI(guidata(hFig));
        guidata(hFig,S0);
        updatePreview();
    end

    function onStyleChanged(~,~)
        S0 = guidata(hFig);
        try
            items = get(S0.hColorScheme,'String');
            S0.colorScheme = items{get(S0.hColorScheme,'Value')};
        catch
        end
        try, S0.tc_showSEM = logical(get(S0.hShowSEM,'Value')); catch, end
        try, S0.tc_showInjectionBox = logical(get(S0.hShowInjBox,'Value')); catch, end
        guidata(hFig,S0);
        updatePreview();
    end

    function onPreviewStyleChanged(~,~)
        S0 = guidata(hFig);
        try
            items = get(S0.hPrevStyle,'String');
            S0.previewStyle = items{get(S0.hPrevStyle,'Value')};
        catch
        end
        try, S0.previewShowGrid = logical(get(S0.hPrevGrid,'Value')); catch, end
        guidata(hFig,S0);
        updatePreview();
    end

    function onSmoothChanged(~,~)
        S0 = guidata(hFig);
        try, S0.tc_previewSmooth = logical(get(S0.hSmoothEnable,'Value')); catch, end
        try, S0.tc_previewSmoothWinSec = safeNum(get(S0.hSmoothWin,'String'),S0.tc_previewSmoothWinSec); catch, end
        try, S0 = readPreviewAxisControlsLocal(S0); catch, end
        guidata(hFig,S0);
        updatePreview();
    end

    function onPlotScaleChanged(~,~)
        S0 = guidata(hFig);
        try, S0 = readPreviewAxisControlsLocal(S0); catch, end
        guidata(hFig,S0);
        updatePreview();
    end

    function onMapDisplayChanged(~,~)
        S0 = guidata(hFig);
        S0 = readMapSettingsFromUI(S0);
        guidata(hFig,S0);
        if isfield(S0,'lastMAP') && isstruct(S0.lastMAP) && ~isempty(fieldnames(S0.lastMAP))
            updateMapTabPreview();
        elseif isfield(S0,'mapPreviewRow') && isfinite(S0.mapPreviewRow)
            previewBundleRow(S0.mapPreviewRow);
        end
    end

    function onLoadCustomUnderlay(~,~)
        S0 = guidata(hFig);
        startPath = getSmartBrowseDir(S0);
        [f,p] = uigetfile({'*.mat;*.png;*.jpg;*.jpeg;*.tif;*.tiff;*.bmp','Underlay / MaskEditor files'}, ...
            'Select custom underlay or MaskEditor mask bundle',startPath);
        if isequal(f,0), return; end

        fpOriginal = fullfile(p,f);
        fpUsed = fpOriginal;
        overlayMask = [];

        try
            [U,overlayMask,infoTxt] = GA_loadUnderlayAndOverlayMask_20260504(fpOriginal);
        catch ME_direct
            try
                % Fallback only. Do NOT rely on corrupt cache files.
                U = callMap('loadGroupUnderlayFile',fpOriginal);
                overlayMask = [];
                infoTxt = ['fallback raw load: ' shortPathForTable(fpOriginal,60)];
            catch ME_fallback
                msg = sprintf('Could not load underlay/mask bundle.\n\nDirect extraction:\n%s\n\nFallback:\n%s', ...
                    ME_direct.message, ME_fallback.message);
                errordlg(msg,'Load custom underlay');
                return;
            end
        end

        S0.mapLoadedUnderlay = U;
        S0.mapLoadedOverlayMask = overlayMask;
        S0.mapCustomUnderlayFile = fpOriginal;
        S0.mapUnderlayMode = 'Loaded custom underlay';

        try, setPopupToString(S0.hMapUnderlayMode,'Loaded custom underlay'); catch, end

        guidata(hFig,S0);
        updateMapTabPreview();

        if ~isempty(overlayMask)
            setStatusText(['Loaded true underlay + overlay mask: ' infoTxt]);
        else
            setStatusText(['Loaded true underlay only: ' infoTxt]);
        end
    end

    function onMapSliceEdit(src,~)
        S0 = guidata(hFig);
        s = '';
        try, s = get(src,'String'); catch, end
        v = sscanf(strrep(s,'/',' '),'%f');
        if isempty(v) || ~isfinite(v(1)), return; end
        S0.mapCurrentSlice = round(v(1));
        if ~isfield(S0,'mapCurrentSliceMax') || ~isfinite(S0.mapCurrentSliceMax)
            S0.mapCurrentSliceMax = max(1,S0.mapCurrentSlice);
        end
        S0.mapCurrentSlice = max(1,min(S0.mapCurrentSliceMax,S0.mapCurrentSlice));
        guidata(hFig,S0);
        redrawMapAfterSliceChangeLocal();
    end

    function onMapScrollWheel(~,evt)
        S0 = guidata(hFig);
        try
            if ~isfield(S0,'activeTab') || ~strcmpi(S0.activeTab,'MAP')
                if ~isfield(S0,'mode') || isempty(strfind(lower(S0.mode),'map'))
                    return;
                end
            end
        catch
            return;
        end

        r = [];
        try
            if isfield(S0,'mapPreviewRow') && isfinite(S0.mapPreviewRow)
                r = S0.mapPreviewRow;
            end
        catch
            r = [];
        end
        if isempty(r)
            try
                rows = findBundleDisplayRowsLocal(S0);
                if ~isempty(rows), r = rows(1); end
            catch
            end
        end
        if isempty(r), return; end

        S0 = ensureMapSliceStateForRowLocal(S0,r);
        nZ = 1;
        try, nZ = max(1,round(S0.mapCurrentSliceMax)); catch, end
        if nZ <= 1
            updateMapSliceTextLocal(S0);
            guidata(hFig,S0);
            return;
        end

        step = 1;
        try
            if evt.VerticalScrollCount < 0, step = -1; else, step = 1; end
        catch
            step = 1;
        end
        S0.mapCurrentSlice = max(1,min(nZ,round(S0.mapCurrentSlice + step)));
        updateMapSliceTextLocal(S0);
        guidata(hFig,S0);
        redrawMapAfterSliceChangeLocal();
    end

    function redrawMapAfterSliceChangeLocal()
        S0 = guidata(hFig);
        updateMapSliceTextLocal(S0);
        try
            if isfield(S0,'lastMAP') && isstruct(S0.lastMAP) && ~isempty(fieldnames(S0.lastMAP))
                onComputeGroupMaps([],[]);
            elseif isfield(S0,'mapPreviewRow') && isfinite(S0.mapPreviewRow)
                previewBundleRow(S0.mapPreviewRow);
            end
        catch ME_scroll
            try, GA_printErrorLocal(ME_scroll,'GroupAnalysis map slice scroll'); catch, end
            setStatusText(['Slice redraw failed: ' ME_scroll.message]);
        end
    end

    function S0 = ensureMapSliceStateForRowLocal(S0,r)
        if isempty(r) || r < 1 || r > size(S0.subj,1), return; end
        bf = '';
        try, bf = strtrimSafe(S0.subj{r,8}); catch, end
        if isempty(bf) || exist(bf,'file') ~= 2, return; end
        try
            [G,cacheOut] = callMap('getCachedGroupBundle',S0.cache,bf);
            S0.cache = cacheOut;
            nZ = inferMapSliceCountFromBundleLocal(G);
            if ~isfinite(nZ) || nZ < 1, nZ = 1; end
            S0.mapCurrentSliceMax = nZ;
            if ~isfield(S0,'mapCurrentSlice') || ~isfinite(S0.mapCurrentSlice) || S0.mapCurrentSlice < 1 || S0.mapCurrentSlice > nZ
                S0.mapCurrentSlice = defaultMapSliceFromBundleLocal(G,nZ);
            end
            S0.mapCurrentSlice = max(1,min(nZ,round(S0.mapCurrentSlice)));
            updateMapSliceTextLocal(S0);
        catch
        end
    end

    function updateMapSliceTextLocal(S0)
        try
            if isfield(S0,'hMapSliceText') && ishghandle(S0.hMapSliceText)
                if isfield(S0,'mapCurrentSliceMax') && isfinite(S0.mapCurrentSliceMax) && S0.mapCurrentSliceMax > 1
                    set(S0.hMapSliceText,'String',sprintf('%d/%d',round(S0.mapCurrentSlice),round(S0.mapCurrentSliceMax)));
                elseif isfield(S0,'mapCurrentSlice') && isfinite(S0.mapCurrentSlice)
                    set(S0.hMapSliceText,'String',sprintf('%d/1',round(S0.mapCurrentSlice)));
                else
                    set(S0.hMapSliceText,'String','-');
                end
            end
        catch
        end
    end
    function onPreviewSelectedBundle(~,~)
        S0 = guidata(hFig);
        r = [];
        sel = clampSelRows(S0.selectedRows,size(S0.subj,1));
        if ~isempty(sel)
            r = sel(1);
        elseif isfinite(S0.mapPreviewRow)
            r = S0.mapPreviewRow;
        end
        if isempty(r) || r < 1 || r > size(S0.subj,1)
            errordlg('Select one bundle row first.','Preview');
            return;
        end
        previewBundleRow(r);
    end

    function onMapPreviewPopup(src,~)
        rows = get(src,'UserData');
        if isempty(rows) || ~all(isfinite(rows)), return; end
        v = get(src,'Value');
        v = max(1,min(numel(rows),v));
        r = rows(v);
        S0 = guidata(hFig);
        S0.mapPreviewRow = r;
        guidata(hFig,S0);
        syncMapPreviewSideUI(r);
        previewBundleRow(r);
    end

    function onMapPreviewSideChanged(src,~)
        S0 = guidata(hFig);
        S0 = ensureRowPacapSideSize(S0);
        S0 = ensureFCRowFilesSizeGA_TARGETED(S0);
        r = S0.mapPreviewRow;
        if isempty(r) || ~isfinite(r) || r < 1 || r > size(S0.subj,1)
            return;
        end
        items = get(src,'String');
        S0.rowPacapSide{r} = items{get(src,'Value')};
        guidata(hFig,S0);
        updateMapSideSummaryTable();
        setStatusText(sprintf('Injection side set for row %d: %s',r,S0.rowPacapSide{r}));
    end

    function onComputeGroupMaps(~,~)
        syncSubjFromTable();
        S0 = guidata(hFig);
        S0 = readMapSettingsFromUI(S0);
        [mapIdx,missingIdx] = findActiveBundleRowsLocal(S0);
        if ~isempty(mapIdx)
            S0 = ensureMapSliceStateForRowLocal(S0,mapIdx(1));
            guidata(hFig,S0);
        end
        if isempty(mapIdx)
            errordlg('No valid bundle rows found. Use Add Bundles first.','Group Maps');
            return;
        end
        setStatus(false);
        setStatusText(sprintf('Computing group maps from %d bundle row(s)...',numel(mapIdx)));
        try, GA_force_scm_alpha_20260504(gcf,10,20); catch, end; % AUTO_FORCE_SCM_ALPHA_20260504
drawnow;
        try
            subjActive = S0.subj(mapIdx,:);
            [R,cacheOut] = callMap('runPSCMapAnalysis',S0,subjActive,mapIdx,S0.cache);
            S0 = guidata(hFig);
            S0.cache = cacheOut;
            S0.lastMAP = R;
            
            S0.previewForceMode = 'MAP';
S0.activeTab = 'MAP';
            S0.mode = 'Group Maps';
            guidata(hFig,S0);
            updateManualTabs();
            updateMapTabPreview();
            if ~isempty(missingIdx)
                setStatusText(sprintf('Group map complete. Skipped %d active row(s) without valid bundle.',numel(missingIdx)));
            else
                setStatusText('Group map analysis complete.');
            end
        catch ME
            try, GA_printErrorLocal(ME,'caught error in GroupAnalysis.m'); catch, end
            setStatusText(['Group map failed: ' ME.message]);
            errordlg(ME.message,'Group Maps');
        end
        setStatus(true);
    end

    function onExportGroupMapData(~,~)
        try
            setStatusText('Exporting multi-slice GA video bundle...');
            outFile = localGA_motorExportIntegratedV6('video',hFig);
            if isempty(outFile)
                setStatusText('Group video export cancelled.');
            else
                setStatusText(['Group video bundle saved: ' outFile]);
            end
        catch ME
            try, GA_printErrorLocal(ME,'onExportGroupMapData integrated V6'); catch, end
            setStatusText(['Group video export failed: ' ME.message]);
            errordlg(ME.message,'Export Group Data for Video');
        end
    end

    function onExportGroupMapDataSCM(~,~)
        try
            setStatusText('Exporting multi-slice SCM data bundle...');
            outFile = localGA_motorExportIntegratedV6('scm',hFig);
            if isempty(outFile)
                setStatusText('Export Data SCM cancelled.');
            else
                setStatusText(['SCM data export saved: ' outFile]);
            end
        catch ME
            try, GA_scm_print_error(ME,'onExportGroupMapDataSCM integrated V6'); catch, disp(ME.message); end
            setStatusText(['Export Data SCM failed: ' ME.message]);
            errordlg(ME.message,'Export Data SCM failed');
        end
    end

    function onExportGroupMapPNG(~,~)
        S0 = guidata(hFig);
        if ~isfield(S0,'lastMAP') || isempty(fieldnames(S0.lastMAP))
            errordlg('Compute a group map first.','Export PNG');
            return;
        end
        startDir = getSmartBrowseDir(S0);
        [f,p] = uiputfile({'*.png','PNG (*.png)'}, ...
            'Save Group Map PNG',fullfile(startDir,['GroupMap_' datestr(now,'yyyymmdd_HHMMSS') '.png']));
        if isequal(f,0), return; end
        outFile = fullfile(p,f);
        try
            D = buildCurrentMapDisplayLocal(S0);
            callMap('exportMapDisplayPNG',outFile,D,'Dark');
            setStatusText(['Group map PNG saved: ' outFile]);
        catch ME
            try, GA_printErrorLocal(ME,'caught error in GroupAnalysis.m'); catch, end
            errordlg(ME.message,'Export PNG');
        end
    end

    function onExportGroupMapPPT(~,~)
        try
            setStatusText('Exporting multi-slice SCM PowerPoint...');
            outFile = localGA_motorExportIntegratedV6('ppt',hFig);
            if isempty(outFile)
                setStatusText('Export PPT cancelled.');
            else
                setStatusText(['Group SCM PPT saved: ' outFile]);
            end
        catch ME
            try, GA_scm_print_error(ME,'onExportGroupMapPPT integrated V6'); catch, disp(ME.message); end
            setStatusText(['Export PPT failed: ' ME.message]);
            errordlg(ME.message,'Export Group Map PPT failed');
        end
    end

    function onLoadFCGroupBundles(~,~)
        S0 = guidata(hFig);
        startPath = getSmartBrowseDir(S0);
        [f,p] = uigetfile({'FC_GroupBundle_*.mat;*.mat','FC group bundles (*.mat)'}, ...
            'Select FC_GroupBundle MAT files',startPath,'MultiSelect','on');
        if isequal(f,0), return; end
        if ischar(f), f = {f}; end
        fileList = cell(numel(f),1);
        for ii = 1:numel(f)
            fileList{ii} = fullfile(p,f{ii});
        end
        loadFCFileListIntoState(fileList);
    end

    function onScanFCGroupFolder(~,~)
        S0 = guidata(hFig);
        startPath = getSmartBrowseDir(S0);
        rootDir = uigetdir(startPath,'Select folder to scan for FC_GroupBundle_*.mat');
        if isequal(rootDir,0), return; end
        try
            fileList = callFC('findFCBundlesRecursive',rootDir);
        catch ME
            try, GA_printErrorLocal(ME,'caught error in GroupAnalysis.m'); catch, end
            errordlg(ME.message,'Scan FC folder');
            return;
        end
        if isempty(fileList)
            errordlg('No FC_GroupBundle_*.mat files found.','Functional Connectivity');
            return;
        end
        loadFCFileListIntoState(fileList);
    end

    function loadFCFileListIntoState(fileList)
        S0 = guidata(hFig);
        try, prevFCRowFiles_20260624 = S0.fcRowFiles; catch, prevFCRowFiles_20260624 = {}; end
        try, prevFCState_20260624 = S0.FC; catch, prevFCState_20260624 = struct(); end
        setStatus(false);
        setStatusText('Loading FC bundles...');
        try, GA_force_scm_alpha_20260504(gcf,10,20); catch, end; % AUTO_FORCE_SCM_ALPHA_20260504
drawnow;
        try
            [FC,cacheOut] = callFC('loadFCGroupBundlesFromFiles',fileList,S0.cache);
            S0.cache = cacheOut;
            S0.FC = fcga_merge_fc_state_keep_previous_20260624(prevFCState_20260624,FC);
            S0.FC.loaded = true;
            S0 = attachFCGABundlesToTable_USE_ROW_20260624(S0,fileList,FC);
            S0 = fcga_restore_previous_fc_rows_20260624(S0,prevFCRowFiles_20260624);
            S0 = sanitizeTableStruct(S0);
            S0 = ensureRowPacapSideSize(S0);
            S0 = ensureFCRowFilesSizeGA_TARGETED(S0);
            S0.groupList = mergeUniqueStable(S0.groupList,uniqueStable(colAsStr(S0.subj,3)));
            S0.condList  = mergeUniqueStable(S0.condList, uniqueStable(colAsStr(S0.subj,4)));
            S0.lastFC = struct();
            S0.activeTab = 'FC';
            S0.mode = 'Functional Connectivity';
            guidata(hFig,S0);
            refreshFCGroupPopups();
            try, refreshFCRegionPopups_SAFE_20260617(hFig); catch, end
            try, refreshFCSubjectPopup_ADV_20260617(hFig); catch, end
                try, refreshFCSlicePopup_CLEAN_20260617(hFig); catch, end
            try, refreshFCRegionPopups_TARGETED(hFig); catch, end
            updateManualTabs();
            refreshTable();
            S0 = guidata(hFig);
            set(S0.hFCInfo,'String',sprintf('Loaded %d FC subject(s) from %d file(s). %s',FC.nSubjects,numel(fileList),fcGroupCountsText_TARGETED(FC)));
            setStatusText('FC bundles loaded.');
        catch ME
            try, GA_printErrorLocal(ME,'caught error in GroupAnalysis.m'); catch, end
            errordlg(ME.message,'Load FC bundles');
            setStatusText(['FC loading failed: ' ME.message]);
        end
        setStatus(true);
    end

    function refreshFCGroupPopups()
        S0 = guidata(hFig);
        groups = S0.groupList;
        try
            if isfield(S0,'FC') && isfield(S0.FC,'subjects') && ~isempty(S0.FC.subjects)
                g2 = cell(numel(S0.FC.subjects),1);
                for ii = 1:numel(S0.FC.subjects)
                    g2{ii} = strtrimSafe(S0.FC.subjects(ii).group);
                    if isempty(g2{ii}), g2{ii} = 'Unassigned'; end
                end
                groups = mergeUniqueStable(groups,uniqueStable(g2));
            end
        catch
        end
        set(S0.hFCGroupA,'String',groups);
        set(S0.hFCGroupB,'String',groups);
        setPopupToString(S0.hFCGroupA,'PACAP');
        setPopupToString(S0.hFCGroupB,'Vehicle');
    end

    function onComputeGroupFC(~,~)
        S0 = guidata(hFig);
        try
            if ~isfield(S0,'FC') || ~isfield(S0.FC,'subjects') || isempty(S0.FC.subjects)
                set(S0.hFCInfo,'String','Load FC bundles first.');
                return;
            end
            S0 = syncFCGroupsFromTable_TARGETED(S0);
            R = computeSingleGroupFC_SINGLE_20260616(S0);
            S0.lastFC = R;
            guidata(hFig,S0);
            try, refreshFCRegionPopups_SAFE_20260617(hFig); catch, end
            updateFCTabPreview();
            S0 = guidata(hFig);
            set(S0.hFCInfo,'String',sprintf('Loaded %d FC subject(s). Showing %s, n=%d. No A-vs-B comparison.',numel(S0.FC.subjects),R.groupName,R.n));
        catch ME
            try, GA_printErrorLocal(ME,'caught error in single-group FC compute'); catch, end
            try, set(S0.hFCInfo,'String',['FC ERROR: ' ME.message]); catch, end
            setStatusText(['FC ERROR: ' ME.message]);
        end
    end

    function updateFCTabPreview(~,~)
        S0 = guidata(hFig);
        try
            hasFC = isfield(S0,'FC') && isfield(S0.FC,'subjects') && ~isempty(S0.FC.subjects);
            if ~hasFC
                try
                    setSingleFCAxis_SINGLE_20260616(S0);
                    fcNoDataLocal(S0.axFCA,'Load FC bundles first',S0.C);
                catch
                end
                return;
            end

            currentGroup = 'All loaded';
            try, currentGroup = popupString_SINGLE_20260616(S0,'hFCGroupA','All loaded'); catch, end

            needCompute = false;
            if ~isfield(S0,'lastFC') || isempty(fieldnames(S0.lastFC))
                needCompute = true;
            elseif ~isfield(S0.lastFC,'groupName')
                needCompute = true;
            elseif ~strcmpi(strtrimSafe(S0.lastFC.groupName),strtrimSafe(currentGroup)) && ~strcmpi(strtrimSafe(S0.lastFC.groupName),'All loaded')
                needCompute = true;
            end

            if needCompute
                try, S0 = syncFCGroupsFromTable_TARGETED(S0); catch, end
                S0.lastFC = computeSingleGroupFC_ADV_20260617(S0);
                guidata(hFig,S0);
                try, refreshFCRegionPopups_SAFE_20260617(hFig); catch, end
                try, refreshFCSubjectPopup_ADV_20260617(hFig); catch, end
                try, refreshFCSlicePopup_CLEAN_20260617(hFig); catch, end
                S0 = guidata(hFig);
            end

            updateFCTabPreview_ADV_20260617(S0);
        catch ME
            try, GA_printErrorLocal(ME,'caught error in FC auto-compute/preview'); catch, end
            try, set(S0.hFCInfo,'String',['FC ERROR: ' ME.message]); catch, end
        end
    end

    function onExportGroupFC(~,~)
        S0 = guidata(hFig);
        if ~isfield(S0,'lastFC') || isempty(fieldnames(S0.lastFC))
            errordlg('Compute group FC first.','FC export');
            return;
        end
        try
            exportGroupFCResults_TARGETED(S0);
            setStatusText('FC export complete.');
        catch ME
            try, GA_printErrorLocal(ME,'caught error in GroupAnalysis.m'); catch, end
            errordlg(ME.message,'FC export');
        end
    end

    function onStatsChanged(~,~)
        S0 = guidata(hFig);
        try
            items = get(S0.hTest,'String');
            S0.testType = items{get(S0.hTest,'Value')};
        catch
        end
        try
            S0.alpha = safeNum(get(S0.hAlpha,'String'),S0.alpha);
        catch
        end
        try
            items = get(S0.hAnnotMode,'String');
            S0.annotMode = items{get(S0.hAnnotMode,'Value')};
        catch
        end
        try, S0.showPText = logical(get(S0.hShowPText,'Value')); catch, end
        guidata(hFig,S0);
        updatePreview();
    end

    function onDetectOutliers(~,~)
        S0 = guidata(hFig);
        try
            [keysOut,info] = callCommon('detectOutliers',double(S0.lastROI.metricVals(:)),S0.lastROI.subjTable,S0);
            S0.outlierKeys = keysOut;
            S0.outlierInfo = info;
            guidata(hFig,S0);
            updateOutlierBox();
            updatePreview();
        catch ME
            try, GA_printErrorLocal(ME,'caught error in GroupAnalysis.m'); catch, end
            errordlg(ME.message,'Outliers');
        end
    end

    function onExcludeOutliers(~,~)
        syncSubjFromTable();
        S0 = guidata(hFig);
        if isempty(S0.outlierKeys)
            errordlg('No outliers detected.','Exclude outliers');
            return;
        end
        keysAll = makeRowKeysLocal(S0.subj);
        for i = 1:numel(S0.outlierKeys)
            hit = find(strcmp(keysAll,S0.outlierKeys{i}),1,'first');
            if ~isempty(hit)
                S0.subj{hit,1} = false;
                S0.subj{hit,9} = 'EXCLUDED (outlier)';
            end
        end
        S0.lastROI = struct();
        S0.lastMAP = struct();
        guidata(hFig,S0);
        refreshTable();
        clearPreview();
        setStatusText('Outliers excluded. Run analysis again.');
    end

    function onRun(~,~)
        syncSubjFromTable();
        S0 = guidata(hFig);
        if strcmpi(S0.activeTab,'FC')
            onComputeGroupFC([],[]);
            return;
        end
        if strcmpi(S0.activeTab,'MAP') || strcmpi(S0.mode,'Group Maps')
            onComputeGroupMaps([],[]);
            return;
        end

        roiIdx = findActiveROIRowsLocal(S0.subj);
        if isempty(roiIdx)
            errordlg('No valid ROI rows found.','ROI Analysis');
            return;
        end

        S0 = readROISettingsFromUI(S0);
        S0 = readStatsSettingsFromUI(S0);
        S0 = readPlotScaleSettingsFromUI(S0);
        subjActive = S0.subj(roiIdx,:);

        setStatus(false);
        setStatusText(sprintf('Running ROI analysis for %d row(s)...',numel(roiIdx)));
        try, GA_force_scm_alpha_20260504(gcf,10,20); catch, end; % AUTO_FORCE_SCM_ALPHA_20260504
drawnow;
        try
            [R,cacheOut] = callCommon('runROITimecourseAnalysis',S0,subjActive,S0.cache);
            S0 = guidata(hFig);
            S0.cache = cacheOut;
            S0.lastROI = R;
            
            S0.previewForceMode = 'ROI';
            S0.activeTab = 'PREV';
S0.activeTab = 'PREV';
            S0.mode = 'ROI Timecourse';
            guidata(hFig,S0);
            updateManualTabs();
            updatePreview();
            setStatusText('ROI analysis complete.');
        catch ME
            try, GA_printErrorLocal(ME,'caught error in GroupAnalysis.m'); catch, end
            errordlg(ME.message,'ROI Analysis');
            setStatusText(['ROI analysis failed: ' ME.message]);
        end
        setStatus(true);
    end

    function onExport(~,~)
        S0 = guidata(hFig);
        if strcmpi(S0.activeTab,'FC')
            onExportGroupFC([],[]);
            return;
        end
        R = struct();
        if strcmpi(S0.mode,'Group Maps')
            if isfield(S0,'lastMAP'), R = S0.lastMAP; end
        else
            if isfield(S0,'lastROI'), R = S0.lastROI; end
        end
        if isempty(fieldnames(R))
            errordlg('Run analysis first.','Export');
            return;
        end
        outParent = uigetdir(getSmartBrowseDir(S0),'Choose export folder');
        if isequal(outParent,0), return; end
        outFolder = fullfile(outParent,['GroupAnalysis_' datestr(now,'yyyymmdd_HHMMSS')]);
        if exist(outFolder,'dir') ~= 7, mkdir(outFolder); end
        save(fullfile(outFolder,'Results.mat'),'R','-v7.3');
        setStatusText(['Exported: ' outFolder]);
    end

    function onExportExcel(~,~)
        S0 = guidata(hFig);
        startPath = getSmartBrowseDir(S0);
        [f,p] = uiputfile({'*.xlsx','Excel workbook (*.xlsx)'}, ...
            'Save Group Analysis Excel',fullfile(startPath,['GroupAnalysisExport_' datestr(now,'yyyymmdd_HHMMSS') '.xlsx']));
        if isequal(f,0), return; end
        try
            callCommon('exportGroupAnalysisExcelWorkbook',fullfile(p,f),S0);
            setStatusText(['Excel exported: ' fullfile(p,f)]);
        catch ME
            try, GA_printErrorLocal(ME,'caught error in GroupAnalysis.m'); catch, end
            errordlg(ME.message,'Excel export');
        end
    end
    function onExportPreviewPNG(which)
        S0 = guidata(hFig);
        S0 = readPlotScaleSettingsFromUI(S0);
        guidata(hFig,S0);

        outDir = uigetdir(getSmartBrowseDir(S0),'Choose folder to save preview PNG(s)');
        if isequal(outDir,0)
            return;
        end

        try
            ts = datestr(now,'yyyymmdd_HHMMSS');

            if which == 1 || which == 3
                outTop = fullfile(outDir,['ROIPreview_Top_' ts '.png']);
                savePreviewPNGLocal(outTop, 1, S0);
            end

            if which == 2 || which == 3
                outBot = fullfile(outDir,['ROIPreview_Bottom_' ts '.png']);
                savePreviewPNGLocal(outBot, 2, S0);
            end

            setStatusText(['Preview PNG saved to: ' outDir]);

        catch ME
            try
                GA_printErrorLocal(ME,'caught error in GroupAnalysis.m');
            catch
                disp(getReport(ME,'extended'));
            end
            errordlg(ME.message,'Preview export');
        end
    end

%%% =====================================================================
%%% GUI UPDATE HELPERS
%%% =====================================================================

    function updateManualTabs()
        S0 = guidata(hFig);

        set(S0.tabROI,'Visible','off');
        set(S0.tabMAP,'Visible','off');
        set(S0.tabFC,'Visible','off');
        set(S0.tabSTATS,'Visible','off');
        set(S0.tabPREV,'Visible','off');

        tabOff = [0.18 0.18 0.18];
        tabOn  = [0.34 0.34 0.34];

        set(S0.hTabROI,'BackgroundColor',tabOff);
        set(S0.hTabMAP,'BackgroundColor',tabOff);
        set(S0.hTabFC,'BackgroundColor',tabOff);
        set(S0.hTabSTATS,'BackgroundColor',tabOff);
        set(S0.hTabPREV,'BackgroundColor',tabOff);

        switch upper(S0.activeTab)
            case 'ROI'
                set(S0.tabROI,'Visible','on');
                set(S0.hTabROI,'BackgroundColor',tabOn);
            case 'MAP'
                set(S0.tabMAP,'Visible','on');
                set(S0.hTabMAP,'BackgroundColor',tabOn);
            case 'FC'
                set(S0.tabFC,'Visible','on');
                set(S0.hTabFC,'BackgroundColor',tabOn);
            case 'STATS'
                set(S0.tabSTATS,'Visible','on');
                set(S0.hTabSTATS,'BackgroundColor',tabOn);
            case 'PREV'
                set(S0.tabPREV,'Visible','on');
                set(S0.hTabPREV,'BackgroundColor',tabOn);
        end
    end

    function refreshTable()
        S0 = guidata(hFig);
        S0 = sanitizeTableStruct(S0);
        S0 = ensureRowPacapSideSize(S0);
        S0 = ensureFCRowFilesSizeGA_TARGETED(S0);
        S0 = ensureFCRowFilesSizeGA_TARGETED(S0);

        S0.groupList = mergeUniqueStable(S0.groupList,uniqueStable(colAsStr(S0.subj,3)));
        S0.condList  = mergeUniqueStable(S0.condList, uniqueStable(colAsStr(S0.subj,4)));

        colFmt = {'logical','char','char','char',S0.groupList,S0.condList,'char','char','char','char'};
        dispData = makeUITableDisplayData(S0.subj,S0.tableMinRows,S0.fcRowFiles);

        try
            set(S0.hTable,'Data',dispData);
            set(S0.hTable,'ColumnFormat',colFmt);
            set(S0.hTable,'BackgroundColor',buildTableRowColorsDisplay(S0.subj,S0.tableMinRows));
            set(S0.hTable,'ColumnWidth',S0.tableColWidths);
        catch
        end

        try
            set(S0.hQuickGroup,'String',S0.groupList);
            set(S0.hQuickCond,'String',S0.condList);
            set(S0.hFCGroupA,'String',S0.groupList);
            set(S0.hFCGroupB,'String',S0.groupList);
        catch
        end

        guidata(hFig,S0);
        updateSelLabel();
        updateMapSideSummaryTable();
    end

    function syncSubjFromTable()
        S0 = guidata(hFig);
        try
            dt = get(S0.hTable,'Data');
            if iscell(dt)
                dt = stripUITablePlaceholders(dt);
                S0.subj = applyUITableToSubj(S0.subj,dt);
            end
        catch
        end
        S0 = sanitizeTableStruct(S0);
        S0 = ensureFCRowFilesSizeGA_TARGETED(S0);
        guidata(hFig,S0);
    end

    function updateSelLabel()
        S0 = guidata(hFig);
        sel = clampSelRows(S0.selectedRows,size(S0.subj,1));
        if isempty(sel)
            set(S0.hSelInfo,'String','Selected: none');
        else
            set(S0.hSelInfo,'String',sprintf('Selected: %d row(s)',numel(sel)));
        end
    end

    function updateOutlierBox()
        S0 = guidata(hFig);
        if isempty(S0.outlierInfo)
            msg = {'No outliers detected yet.'};
        else
            msg = S0.outlierInfo(:);
        end
        try
            set(S0.hOutInfo,'String',msg,'Value',1);
        catch
        end
    end

    function clearPreview()
        S0 = guidata(hFig);

        try, deleteAllColorbars(hFig); catch, end

        try
            if isfield(S0,'ax1') && ishghandle(S0.ax1)
                hardClearAx(S0.ax1, S0.previewStyle, S0.previewShowGrid, 'Top plot');
            end
        catch
            try, cla(S0.ax1); catch, end
        end

        try
            if isfield(S0,'ax2') && ishghandle(S0.ax2)
                hardClearAx(S0.ax2, S0.previewStyle, S0.previewShowGrid, 'Bottom plot');
            end
        catch
            try, cla(S0.ax2); catch, end
        end

        try, GA_force_scm_alpha_20260504(gcf,10,20); catch, end; % AUTO_FORCE_SCM_ALPHA_20260504
drawnow limitrate;
    end
    function updatePreview()
        S0 = guidata(hFig);

        try
            % Always refresh UI settings first
            try
                S0 = readROISettingsFromUI(S0);
            catch
            end

            try
                S0 = readStatsSettingsFromUI(S0);
            catch
            end

            try
                items = get(S0.hPrevStyle,'String');
                S0.previewStyle = items{get(S0.hPrevStyle,'Value')};
            catch
                if ~isfield(S0,'previewStyle') || isempty(S0.previewStyle)
                    S0.previewStyle = 'Dark';
                end
            end

            try
                S0.previewShowGrid = logical(get(S0.hPrevGrid,'Value'));
            catch
                if ~isfield(S0,'previewShowGrid')
                    S0.previewShowGrid = false;
                end
            end

            try
                S0.tc_previewSmooth = logical(get(S0.hSmoothEnable,'Value'));
            catch
            end

            try
                S0.tc_previewSmoothWinSec = safeNum(get(S0.hSmoothWin,'String'),S0.tc_previewSmoothWinSec);
            catch
            end

            
            try, S0 = readPreviewAxisControlsLocal(S0); catch, end
try, S0 = readPlotScaleSettingsFromUI(S0); catch, end
            try, applyPreviewLightDarkToUI(S0); catch, end

            guidata(hFig,S0);

            % IMPORTANT: actually redraw both ROI preview axes.
            if isfield(S0,'ax1') && ishghandle(S0.ax1)
                exportOnePreview(S0.ax1,1,S0,S0.previewStyle);
            end

            if isfield(S0,'ax2') && ishghandle(S0.ax2)
                exportOnePreview(S0.ax2,2,S0,S0.previewStyle);
            end

            try
                setStatusText('ROI preview plotted.');
            catch
            end

        catch ME_prev
            try
                GA_printErrorLocal(ME_prev,'updatePreview / ROI preview');
            catch
                disp(getReport(ME_prev,'extended'));
            end

            try
                setStatusText(['ROI preview failed: ' ME_prev.message]);
            catch
            end

            try
                clearPreview();
            catch
            end
        end
    end


    function refreshMapBundlePopup()
        S0 = guidata(hFig);
        rows = findBundleDisplayRowsLocal(S0);
        labels = {};
        if isempty(rows)
            labels = {'No bundle rows'};
            rows = NaN;
        else
            for i = 1:numel(rows)
                r = rows(i);
                info = extractRowMetaLight(S0.subj(r,:));
                labels{end+1} = sprintf('Row %d | %s | %s | %s', ...
                    r,info.animalID,info.session,displayScanID(info.scanID)); %#ok<AGROW>
            end
        end
        try
            set(S0.hMapPreviewPopup,'String',labels,'UserData',rows,'Value',1);
        catch
        end
        if all(isfinite(rows))
            S0.mapPreviewRow = rows(1);
        else
            S0.mapPreviewRow = NaN;
        end
        guidata(hFig,S0);
    end

    function syncMapPreviewSideUI(r)
        S0 = guidata(hFig);
        S0 = ensureRowPacapSideSize(S0);
        S0 = ensureFCRowFilesSizeGA_TARGETED(S0);
        if r >= 1 && r <= numel(S0.rowPacapSide)
            setPopupToString(S0.hMapPreviewSide,S0.rowPacapSide{r});
        end
        guidata(hFig,S0);
    end

    function updateMapSideSummaryTable()
        S0 = guidata(hFig);
        if ~isfield(S0,'hMapSideTable') || ~ishghandle(S0.hMapSideTable)
            return;
        end
        S0 = ensureRowPacapSideSize(S0);
        S0 = ensureFCRowFilesSizeGA_TARGETED(S0);
        rows = findBundleDisplayRowsLocal(S0);
        if isempty(rows)
            data = {'-','-','-','-'};
        else
            data = cell(numel(rows),4);
            for i = 1:numel(rows)
                r = rows(i);
                info = extractRowMetaLight(S0.subj(r,:));
                side = 'Unknown';
                if r <= numel(S0.rowPacapSide)
                    side = strtrimSafe(S0.rowPacapSide{r});
                end
                data{i,1} = info.animalID;
                data{i,2} = info.session;
                data{i,3} = displayScanID(info.scanID);
                data{i,4} = side;
            end
        end
        try
            set(S0.hMapSideTable,'Data',data);
        catch
        end
        guidata(hFig,S0);
    end

    function previewBundleRow(r)
        S0 = guidata(hFig);
        if isempty(r) || r < 1 || r > size(S0.subj,1)
            return;
        end
        bf = strtrimSafe(S0.subj{r,8});
        if isempty(bf) || exist(bf,'file') ~= 2
            errordlg('Selected row has no valid bundle file.','Preview');
            return;
        end
        S0 = readMapSettingsFromUI(S0);
        setStatusText(sprintf('Previewing bundle row %d...',r));
        try, GA_force_scm_alpha_20260504(gcf,10,20); catch, end; % AUTO_FORCE_SCM_ALPHA_20260504
drawnow;
        try
            [G,cacheOut] = callMap('getCachedGroupBundle',S0.cache,bf);
            S0.cache = cacheOut;
            S0 = ensureMapSliceStateForRowLocal(S0,r);
            guidata(hFig,S0);
            [mapNow,~] = callMap('buildPreviewMapFromBundle',S0,G);
            underlayNow = callMap('resolvePreviewUnderlay',S0,G,mapNow);
            D = struct();
            D.map = mapNow;
            D.underlay = underlayNow;
            D.title = sprintf('Row %d preview',r);
            D.render = makeMapRenderStructLocal(S0);

            cla(S0.axMap1);
            callMap('renderPSCOverlay',S0.axMap1,D.underlay,D.map,D.render,'Dark',true);
            title(S0.axMap1,D.title,'Color','w','FontWeight','bold');

            S0.lastMapDisplay = D;
            S0.mapPreviewRow = r;
            guidata(hFig,S0);
            setStatusText('Bundle preview updated.');
        catch ME
            try, GA_printErrorLocal(ME,'caught error in GroupAnalysis.m'); catch, end
            errordlg(ME.message,'Bundle preview');
            setStatusText(['Preview failed: ' ME.message]);
        end
    end

    function updateMapTabPreview()
        S0 = guidata(hFig);
        if ~isfield(S0,'lastMAP') || isempty(fieldnames(S0.lastMAP))
            return;
        end
        try
            D = buildCurrentMapDisplayLocal(S0);
            cla(S0.axMap1);
            callMap('renderPSCOverlay',S0.axMap1,D.underlay,D.map,D.render,'Dark',true);
            title(S0.axMap1,D.title,'Color','w','FontWeight','bold');
            S0.lastMapDisplay = D;
            guidata(hFig,S0);
        catch ME
            try, GA_printErrorLocal(ME,'caught error in GroupAnalysis.m'); catch, end
            setStatusText(['Map preview failed: ' ME.message]);
        end
    end

%%% =====================================================================
%%% MODULE CALL WRAPPERS
%%% =====================================================================

    function varargout = callMap(action,varargin)
        try
            [varargout{1:nargout}] = GroupAnalysis_Map(action,varargin{:});
        catch ME
            try, GA_printErrorLocal(ME,'caught error in GroupAnalysis.m'); catch, end
            error('GroupAnalysis_Map action "%s" failed: %s',action,ME.message);
        end
    end

    function varargout = callFC(action,varargin)
        % GA_FC_PARAMETER_NAME_FIX_20260504
        % Adaptive wrapper for GroupAnalysis_FC.
        % Some GroupAnalysis_FC versions expect positional inputs, others expect
        % name-value inputs. This wrapper supports both and prevents folder paths
        % like Z:...dataset from being interpreted as parameter names.
        
        try
            [varargout{1:nargout}] = GroupAnalysis_FC(action,varargin{:});
            return;
        catch ME1
            msg1 = lower(ME1.message);
            shouldRetry = false;
            if ~isempty(strfind(msg1,'unmatched parameter name')) || ...
               ~isempty(strfind(msg1,'parameter name')) || ...
               ~isempty(strfind(msg1,'field name')) || ...
               ~isempty(strfind(msg1,'name-value'))
                shouldRetry = true;
            end
            
            if shouldRetry
                try
                    act = lower(strtrimSafe(action));
                    switch act
                        case 'findfcbundlesrecursive'
                            if numel(varargin) < 1
                                error('Missing root folder for findFCBundlesRecursive.');
                            end
                            rootDir = varargin{1};
                            try
                                [varargout{1:nargout}] = GroupAnalysis_FC(action,'rootDir',rootDir);
                                return;
                            catch
                            end
                            try
                                [varargout{1:nargout}] = GroupAnalysis_FC(action,'folder',rootDir);
                                return;
                            catch
                            end
                            [varargout{1:nargout}] = GroupAnalysis_FC(action,'rootFolder',rootDir);
                            return;
                            
                        case 'loadfcgroupbundlesfromfiles'
                            fileList = {};
                            cacheIn = struct();
                            if numel(varargin) >= 1, fileList = varargin{1}; end
                            if numel(varargin) >= 2, cacheIn = varargin{2}; end
                            try
                                [varargout{1:nargout}] = GroupAnalysis_FC(action,'fileList',fileList,'cache',cacheIn);
                                return;
                            catch
                            end
                            try
                                [varargout{1:nargout}] = GroupAnalysis_FC(action,'files',fileList,'cache',cacheIn);
                                return;
                            catch
                            end
                            [varargout{1:nargout}] = GroupAnalysis_FC(action,'files',fileList,'cacheIn',cacheIn);
                            return;
                            
                        case 'alignfcsubjectstocommonrois'
                            if numel(varargin) < 1
                                error('Missing FC struct for alignFCSubjectsToCommonROIs.');
                            end
                            try
                                [varargout{1:nargout}] = GroupAnalysis_FC(action,'FC',varargin{1});
                                return;
                            catch
                            end
                            [varargout{1:nargout}] = GroupAnalysis_FC(action,'fc',varargin{1});
                            return;
                            
                        case 'computegroupfcstats'
                            if numel(varargin) < 3
                                error('Missing G/groupA/groupB for computeGroupFCStats.');
                            end
                            try
                                [varargout{1:nargout}] = GroupAnalysis_FC(action,'G',varargin{1},'groupA',varargin{2},'groupB',varargin{3});
                                return;
                            catch
                            end
                            [varargout{1:nargout}] = GroupAnalysis_FC(action,'aligned',varargin{1},'groupA',varargin{2},'groupB',varargin{3});
                            return;
                            
                        case 'fcplotmatrix'
                            if numel(varargin) < 6
                                error('Missing inputs for fcPlotMatrix.');
                            end
                            try
                                [varargout{1:nargout}] = GroupAnalysis_FC(action,'ax',varargin{1},'M',varargin{2},'clim',varargin{3},'titleStr',varargin{4},'names',varargin{5},'C',varargin{6});
                                return;
                            catch
                            end
                            [varargout{1:nargout}] = GroupAnalysis_FC(action,'ax',varargin{1},'matrix',varargin{2},'clim',varargin{3},'titleStr',varargin{4},'names',varargin{5},'C',varargin{6});
                            return;
                            
                        case 'fcplotpmatrix'
                            if numel(varargin) < 5
                                error('Missing inputs for fcPlotPMatrix.');
                            end
                            try
                                [varargout{1:nargout}] = GroupAnalysis_FC(action,'ax',varargin{1},'P',varargin{2},'titleStr',varargin{3},'names',varargin{4},'C',varargin{5});
                                return;
                            catch
                            end
                            [varargout{1:nargout}] = GroupAnalysis_FC(action,'ax',varargin{1},'pMat',varargin{2},'titleStr',varargin{3},'names',varargin{4},'C',varargin{5});
                            return;
                            
                        case 'exportgroupfcresults'
                            if numel(varargin) < 1
                                error('Missing S struct for exportGroupFCResults.');
                            end
                            try
                                [varargout{1:nargout}] = GroupAnalysis_FC(action,'S',varargin{1});
                                return;
                            catch
                            end
                            [varargout{1:nargout}] = GroupAnalysis_FC(action,'state',varargin{1});
                            return;
                    end
                catch ME2
                    try, GA_printErrorLocal(ME2,'GroupAnalysis_FC adaptive retry failed'); catch, end
                    error('GroupAnalysis_FC action "%s" failed. Original: %s | Retry: %s',action,ME1.message,ME2.message);
                end
            end
            
            try, GA_printErrorLocal(ME1,'caught error in GroupAnalysis.m'); catch, end
            error('GroupAnalysis_FC action "%s" failed: %s',action,ME1.message);
        end
    end

    function varargout = callCommon(action,varargin)
        try
            [varargout{1:nargout}] = GroupAnalysis_Common(action,varargin{:});
        catch ME
            try, GA_printErrorLocal(ME,'caught error in GroupAnalysis.m'); catch, end
            error('GroupAnalysis_Common action "%s" failed: %s',action,ME.message);
        end
    end

%%% =====================================================================
%%% LOCAL CORE HELPERS
%%% =====================================================================

    function setStatusText(txt)
        S0 = guidata(hFig);
        try
            set(S0.hStatus,'String',txt);
        catch
        end
        try
            set(S0.hMapExportStatus,'String',txt);
        catch
        end
        try, GA_force_scm_alpha_20260504(gcf,10,20); catch, end; % AUTO_FORCE_SCM_ALPHA_20260504
drawnow limitrate;
    end

    function setStatus(isReady)
        try
            if ~isempty(opt.statusFcn)
                opt.statusFcn(logical(isReady));
            end
        catch
        end
    end

end

%%% =====================================================================
%%% FILE-LEVEL LOCAL FUNCTIONS
%%% =====================================================================

function h = mkBtn(parent,txt,pos,bg,cb)
h = uicontrol(parent,'Style','pushbutton','String',txt, ...
    'Units','normalized','Position',pos, ...
    'BackgroundColor',bg,'ForegroundColor','w', ...
    'FontWeight','bold','FontSize',12,'Callback',cb);
end

function h = mkTabBtn(parent,txt,pos,cb)
h = uicontrol(parent,'Style','pushbutton','String',txt, ...
    'Units','normalized','Position',pos, ...
    'BackgroundColor',[0.18 0.18 0.18], ...
    'ForegroundColor','w', ...
    'FontWeight','bold','FontSize',11,'Callback',cb);
end

function d = defaultOutDir(opt)
d = pwd;
try
    if isfield(opt,'studio') && isstruct(opt.studio)
        if isfield(opt.studio,'exportPath') && exist(opt.studio.exportPath,'dir') == 7
            d = fullfile(opt.studio.exportPath,'GroupAnalysis');
        end
    end
catch
end
try
    if exist(d,'dir') ~= 7
        mkdir(d);
    end
catch
    d = pwd;
end
end

function [hAuto,hZero,hStep,hYmin,hYmax] = mkYControlsSimple(parent,y0,label,cfg,C,cb)
bg = get(parent,'BackgroundColor');
rowH = 0.18;

uicontrol(parent,'Style','text','String',[label ':'], ...
    'Units','normalized','Position',[0.02 y0 0.08 rowH], ...
    'BackgroundColor',bg,'ForegroundColor','w','HorizontalAlignment','left','FontWeight','bold');

hAuto = uicontrol(parent,'Style','checkbox','String','Auto', ...
    'Units','normalized','Position',[0.11 y0 0.12 rowH], ...
    'Value',double(cfg.auto),'BackgroundColor',bg,'ForegroundColor','w','Callback',cb);

hZero = uicontrol(parent,'Style','checkbox','String','Force 0', ...
    'Units','normalized','Position',[0.24 y0 0.14 rowH], ...
    'Value',double(cfg.forceZero),'BackgroundColor',bg,'ForegroundColor','w','Callback',cb);

uicontrol(parent,'Style','text','String','Step:', ...
    'Units','normalized','Position',[0.40 y0 0.06 rowH], ...
    'BackgroundColor',bg,'ForegroundColor','w','HorizontalAlignment','left','FontWeight','bold');

hStep = uicontrol(parent,'Style','edit','String',num2str(cfg.step), ...
    'Units','normalized','Position',[0.46 y0+0.01 0.06 rowH], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w','Callback',cb);

uicontrol(parent,'Style','text','String','Ymin:', ...
    'Units','normalized','Position',[0.54 y0 0.06 rowH], ...
    'BackgroundColor',bg,'ForegroundColor','w','HorizontalAlignment','left','FontWeight','bold');

hYmin = uicontrol(parent,'Style','edit','String',num2str(cfg.ymin), ...
    'Units','normalized','Position',[0.60 y0+0.01 0.08 rowH], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w','Callback',cb);

uicontrol(parent,'Style','text','String','Ymax:', ...
    'Units','normalized','Position',[0.70 y0 0.06 rowH], ...
    'BackgroundColor',bg,'ForegroundColor','w','HorizontalAlignment','left','FontWeight','bold');

hYmax = uicontrol(parent,'Style','edit','String',num2str(cfg.ymax), ...
    'Units','normalized','Position',[0.76 y0+0.01 0.08 rowH], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w','Callback',cb);
end

function [h0,h1] = addPairEditsDark(parent,y,label,v0,v1,C,cb)
bg = get(parent,'BackgroundColor');

uicontrol(parent,'Style','text','String',label, ...
    'Units','normalized','Position',[0.02 y 0.35 0.12], ...
    'BackgroundColor',bg,'ForegroundColor','w', ...
    'HorizontalAlignment','left','FontWeight','bold');

h0 = uicontrol(parent,'Style','edit','String',num2str(v0), ...
    'Units','normalized','Position',[0.38 y 0.12 0.12], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w','Callback',cb);

h1 = uicontrol(parent,'Style','edit','String',num2str(v1), ...
    'Units','normalized','Position',[0.52 y 0.12 0.12], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w','Callback',cb);
end

function s = strtrimSafe(x)
try
    if isempty(x)
        s = '';
    else
        s = strtrim(char(x));
    end
catch
    s = '';
end
end

function v = safeNum(str,fallback)
v = str2double(str);
if isnan(v) || ~isfinite(v)
    v = fallback;
end
end

function v = logicalCellValue(x)
try
    if islogical(x)
        v = x;
    elseif isnumeric(x)
        v = x ~= 0;
    elseif ischar(x)
        s = lower(strtrim(x));
        v = any(strcmp(s,{'1','true','yes','y','on'}));
    else
        v = logical(x);
    end
catch
    v = false;
end
end

function sel = clampSelRows(sel,nRows)
if isempty(sel)
    sel = [];
    return;
end
sel = unique(sel(:)');
sel = sel(sel >= 1 & sel <= nRows);
end

function tf = logicalCol(tbl,col)
tf = false(size(tbl,1),1);
for i = 1:size(tbl,1)
    tf(i) = logicalCellValue(tbl{i,col});
end
end

function col = colAsStr(C,j)
col = cell(size(C,1),1);
for i = 1:size(C,1)
    col{i} = strtrimSafe(C{i,j});
end
end

function u = uniqueStable(C)
C = C(:);
C = C(~cellfun(@isempty,C));
u = {};
for i = 1:numel(C)
    if ~any(strcmpi(u,C{i}))
        u{end+1,1} = C{i}; %#ok<AGROW>
    end
end
end

function out = mergeUniqueStable(a,b)
if isempty(a), a = {}; end
if isempty(b), b = {}; end
out = a(:).';
for i = 1:numel(b)
    if isempty(b{i}), continue; end
    if ~any(strcmpi(out,b{i}))
        out{end+1} = b{i}; %#ok<AGROW>
    end
end
end

function setPopupToString(h,desired)
try
    items = get(h,'String');
    v = 1;
    for k = 1:numel(items)
        if strcmpi(items{k},desired)
            v = k;
            break;
        end
    end
    set(h,'Value',v);
catch
end
end

function s = getSelectedPopupString(h)
s = '';
try
    items = get(h,'String');
    val = get(h,'Value');
    if iscell(items)
        val = max(1,min(numel(items),val));
        s = strtrimSafe(items{val});
    else
        s = strtrimSafe(items(val,:));
    end
catch
end
end

function S = sanitizeTableStruct(S)
if isempty(S.subj)
    return;
end

if size(S.subj,2) < 9
    S.subj(:,end+1:9) = {''};
elseif size(S.subj,2) > 9
    S.subj = S.subj(:,1:9);
end

for r = 1:size(S.subj,1)
    S.subj{r,1} = logicalCellValue(S.subj{r,1});

    meta = extractMetaFromSources(S.subj{r,2},S.subj{r,6},S.subj{r,7},S.subj{r,8});
    if ~isempty(meta.animalID) && ~strcmpi(meta.animalID,'N/A')
        S.subj{r,2} = meta.animalID;
    elseif isempty(strtrimSafe(S.subj{r,2}))
        S.subj{r,2} = ['S' num2str(r)];
    end

    if isempty(strtrimSafe(S.subj{r,3}))
        S.subj{r,3} = S.defaultGroup;
    end
    if isempty(strtrimSafe(S.subj{r,4}))
        S.subj{r,4} = S.defaultCond;
    end
    if isempty(strtrimSafe(S.subj{r,5})) && logicalCellValue(S.subj{r,1})
        S.subj{r,5} = S.subj{r,2};
    end
end
end

function S = ensureRowPacapSideSize(S)
n = size(S.subj,1);
if ~isfield(S,'rowPacapSide') || isempty(S.rowPacapSide)
    S.rowPacapSide = repmat({'Unknown'},n,1);
end
if numel(S.rowPacapSide) < n
    S.rowPacapSide(end+1:n,1) = {'Unknown'};
elseif numel(S.rowPacapSide) > n
    S.rowPacapSide = S.rowPacapSide(1:n);
end
for i = 1:n
    s = strtrimSafe(S.rowPacapSide{i});
    if strcmpi(s,'L'), s = 'Left'; end
    if strcmpi(s,'R'), s = 'Right'; end
    if ~any(strcmpi(s,{'Unknown','Left','Right'}))
        s = 'Unknown';
    end
    S.rowPacapSide{i} = s;
end
end

function V = makeUITableDisplayData(subj,minRows,fcRowFiles)
if nargin < 2, minRows = 0; end
if nargin < 3, fcRowFiles = cell(size(subj,1),1); end
fcRowFiles = fcRowFilesForN_TARGETED(fcRowFiles,size(subj,1));
V = subjToUITable(subj,fcRowFiles);
n = size(V,1);
nCols = size(V,2);
if minRows > 0 && n < minRows
    pad = cell(minRows-n,nCols);
    for i = 1:size(pad,1)
        pad{i,1} = false;
        for j = 2:nCols
            pad{i,j} = '';
        end
    end
    V = [V; pad];
end
end

function V = subjToUITable(subj,fcRowFiles)
n = size(subj,1);
if nargin < 2, fcRowFiles = cell(n,1); end
fcRowFiles = fcRowFilesForN_TARGETED(fcRowFiles,n);
V = cell(n,10);
for i = 1:n
    meta = extractMetaFromSources(subj{i,2},subj{i,6},subj{i,7},subj{i,8});
    if ~isfield(meta,'animalID') || isempty(meta.animalID), meta.animalID = strtrimSafe(subj{i,2}); end
    if ~isfield(meta,'session')  || isempty(meta.session),  meta.session  = ''; end
    if ~isfield(meta,'scanID')   || isempty(meta.scanID),   meta.scanID   = ''; end
    V{i,1}  = logicalCellValue(subj{i,1});
    V{i,2}  = meta.animalID;
    V{i,3}  = meta.session;
    V{i,4}  = displayScanID(meta.scanID);
    V{i,5}  = strtrimSafe(subj{i,3});
    V{i,6}  = strtrimSafe(subj{i,4});
    V{i,7}  = simplifyFileLabel(strtrimSafe(subj{i,7}));
    V{i,8}  = bundlePresenceLabel(strtrimSafe(subj{i,8}));
    V{i,9}  = bundlePresenceLabel(strtrimSafe(fcRowFiles{i}));
    V{i,10} = deriveRowStatusWithFC_TARGETED(subj(i,:),fcRowFiles{i});
end
end


function subj = applyUITableToSubj(subj,V)
n = size(V,1);
if isempty(subj)
    subj = cell(n,9);
end
if size(subj,1) < n
    subj(end+1:n,1:9) = {''};
elseif size(subj,1) > n
    subj = subj(1:n,:);
end
for i = 1:n
    subj{i,1} = logicalCellValue(V{i,1});
    subj{i,2} = strtrimSafe(V{i,2});
    subj{i,3} = strtrimSafe(V{i,5});
    subj{i,4} = strtrimSafe(V{i,6});
end
end

function V = stripUITablePlaceholders(V)
if isempty(V), return; end
keep = false(size(V,1),1);
for i = 1:size(V,1)
    useVal = logicalCellValue(V{i,1});
    hasContent = false;
    for j = 2:size(V,2)
        if ~isempty(strtrimSafe(V{i,j}))
            hasContent = true;
            break;
        end
    end
    keep(i) = useVal || hasContent;
end
V = V(keep,:);
end

function colors = buildTableRowColorsDisplay(subj,minRows)
if nargin < 2, minRows = 0; end
neutral = [0.12 0.12 0.12];
excluded = [0.30 0.12 0.12];
n = size(subj,1);
nOut = max(max(n,2),minRows);
colors = repmat(neutral,nOut,1);
for i = 1:n
    use = logicalCellValue(subj{i,1});
    st = lower(strtrimSafe(subj{i,9}));
    grp = upper(strtrimSafe(subj{i,3}));
    cond = upper(strtrimSafe(subj{i,4}));
    if contains(st,'excluded') || ~use
        colors(i,:) = excluded;
    elseif contains(grp,'PACAP') || contains(cond,'CONDA') || contains(grp,'GROUPA')
        colors(i,:) = [0.22 0.42 0.22];
    elseif contains(grp,'VEH') || contains(grp,'CONTROL') || contains(cond,'CONDB') || contains(grp,'GROUPB')
        colors(i,:) = [0.08 0.22 0.10];
    else
        colors(i,:) = [0.12 0.30 0.16];
    end
end
end

function s = deriveRowStatus(row)
roi = strtrimSafe(row{7});
bundle = strtrimSafe(row{8});
st = lower(strtrimSafe(row{9}));
use = logicalCellValue(row{1});
if contains(st,'excluded')
    s = 'Excluded';
elseif ~use
    s = 'Not used';
elseif ~isempty(roi) || ~isempty(bundle)
    s = 'OK';
else
    s = 'Not set';
end
end

function s = simplifyFileLabel(fp)
fp = strtrimSafe(fp);
if isempty(fp)
    s = '';
else
    [~,name,ext] = fileparts(fp);
    s = [name ext];
end
end

function s = bundlePresenceLabel(fp)
fp = strtrimSafe(fp);
if isempty(fp)
    s = '';
elseif exist(fp,'file') == 2
    s = 'Exists';
else
    s = 'Missing';
end
end

function rows = getTargetRows(S)
sel = clampSelRows(S.selectedRows,size(S.subj,1));
if ~isempty(sel)
    rows = sel;
elseif S.applyAllIfNoneSelected
    rows = find(logicalCol(S.subj,1));
else
    rows = [];
end
end

function c = mapConditionFromGroup(S,g)
c = '';
g0 = upper(strtrimSafe(g));
try
    if isa(S.groupToCondMap,'containers.Map') && isKey(S.groupToCondMap,g0)
        c = S.groupToCondMap(g0);
        return;
    end
catch
end
if contains(g0,'PACAP') || contains(g0,'GROUPA') || strcmp(g0,'A')
    c = 'CondA';
elseif contains(g0,'VEH') || contains(g0,'CONTROL') || contains(g0,'GROUPB') || strcmp(g0,'B')
    c = 'CondB';
end
end

function d = getSmartBrowseDir(S)
d = '';
try
    sel = clampSelRows(S.selectedRows,size(S.subj,1));
    rows = [sel(:).' setdiff(1:size(S.subj,1),sel(:).','stable')];
    for k = 1:numel(rows)
        r = rows(k);
        fpList = {S.subj{r,8},S.subj{r,7},S.subj{r,6}};
        for j = 1:numel(fpList)
            fp = strtrimSafe(fpList{j});
            if exist(fp,'file') == 2
                d0 = fileparts(fp);
                if exist(d0,'dir') == 7
                    d = d0;
                    return;
                end
            end
        end
    end
catch
end
try
    if isempty(d) && isfield(S.opt,'startDir') && exist(S.opt.startDir,'dir') == 7
        d = S.opt.startDir;
    end
catch
end
if isempty(d) || exist(d,'dir') ~= 7
    d = pwd;
end
end

function S = addFileSmartLight(S,fp)
[~,~,ext] = fileparts(fp);
ext = lower(ext);

subj = guessSubjectID(fp);
gdef = getDefaultGroupLocal(S);
cdef = getDefaultCondLocal(S);

if strcmp(ext,'.txt')
    row = {true,subj,gdef,cdef,subj,'',fp,'',''};
    S.subj(end+1,:) = row;
elseif strcmp(ext,'.mat')
    if isFCGABundleFile_TARGETED(fp)
        row = {true,subj,gdef,cdef,subj,'','','','OK'};
        S.subj(end+1,:) = row;
        S = ensureFCRowFilesSizeGA_TARGETED(S);
        S.fcRowFiles{size(S.subj,1),1} = fp;
    elseif isLikelyBundleFile(fp)
        row = {true,subj,gdef,cdef,subj,'','',fp,''};
        S.subj(end+1,:) = row;
    else
        row = {true,subj,gdef,cdef,subj,fp,'','',''};
        S.subj(end+1,:) = row;
    end
else
    row = {true,subj,gdef,cdef,subj,fp,'','',''};
    S.subj(end+1,:) = row;
end

S = sanitizeTableStruct(S);
S = ensureFCRowFilesSizeGA_TARGETED(S);
end


function S = addBundleAsNewRow(S,fp)
subj = guessSubjectID(fp);
gdef = getDefaultGroupLocal(S);
cdef = getDefaultCondLocal(S);
if isFCGABundleFile_TARGETED(fp)
    row = {true,subj,gdef,cdef,subj,'','','','OK'};
    S.subj(end+1,:) = row;
    S = ensureFCRowFilesSizeGA_TARGETED(S);
    S.fcRowFiles{size(S.subj,1),1} = fp;
else
    row = {true,subj,gdef,cdef,subj,'','',fp,''};
    S.subj(end+1,:) = row;
    S = ensureFCRowFilesSizeGA_TARGETED(S);
    S.fcRowFiles{size(S.subj,1),1} = '';
end
S = sanitizeTableStruct(S);
S = ensureFCRowFilesSizeGA_TARGETED(S);
end


function S = assignBundleToRow(S,r,fp)
if r < 1 || r > size(S.subj,1), return; end
S = ensureFCRowFilesSizeGA_TARGETED(S);
S.subj{r,1} = true;
if isFCGABundleFile_TARGETED(fp)
    S.fcRowFiles{r,1} = fp;
    S.subj{r,8} = '';
else
    S.subj{r,8} = fp;
    S.fcRowFiles{r,1} = '';
end
if isempty(strtrimSafe(S.subj{r,2}))
    S.subj{r,2} = guessSubjectID(fp);
end
if isempty(strtrimSafe(S.subj{r,5}))
    S.subj{r,5} = S.subj{r,2};
end
end


function g = getDefaultGroupLocal(S)
g = S.defaultGroup;
try
    g2 = getSelectedPopupString(S.hQuickGroup);
    if ~isempty(g2), g = g2; end
catch
end
end

function c = getDefaultCondLocal(S)
c = S.defaultCond;
try
    c2 = getSelectedPopupString(S.hQuickCond);
    if ~isempty(c2), c = c2; end
catch
end
end

function tf = isLikelyBundleFile(fp)
tf = false;
[~,nm,ext] = fileparts(fp);
if ~strcmpi(ext,'.mat'), return; end
if ~isempty(regexpi(nm,'SCM_GroupExport|GroupBundle|GroupExport','once'))
    tf = true;
    return;
end
try
    info = whos('-file',fp);
    vars = {info.name};
    tf = any(strcmp(vars,'G')) || any(strcmp(vars,'fcBundle'));
catch
    tf = false;
end
end

function idx = findActiveROIRowsLocal(subj)
idx = [];
for i = 1:size(subj,1)
    if ~logicalCellValue(subj{i,1}), continue; end
    roi = strtrimSafe(subj{i,7});
    if ~isempty(roi) && exist(roi,'file') == 2
        idx(end+1) = i; %#ok<AGROW>
    end
end
end

function [idx,missingIdx] = findActiveBundleRowsLocal(S)
idx = [];
missingIdx = [];
rows = findBundleDisplayRowsLocal(S);
for i = 1:numel(rows)
    r = rows(i);
    if ~logicalCellValue(S.subj{r,1})
        continue;
    end
    bf = strtrimSafe(S.subj{r,8});
    if ~isempty(bf) && exist(bf,'file') == 2
        idx(end+1) = r; %#ok<AGROW>
    else
        missingIdx(end+1) = r; %#ok<AGROW>
    end
end
end

function rows = findBundleDisplayRowsLocal(S)
rows = [];
for r = 1:size(S.subj,1)
    bf = strtrimSafe(S.subj{r,8});
    if ~isempty(bf)
        rows(end+1) = r; %#ok<AGROW>
    end
end
end

function S = readPreviewAxisControlsLocal(S)
% Reads ROI-tab Y controls first, then optional compact Preview-tab overrides.
try, S.plotTop.auto      = logical(get(S.hTopAuto,'Value')); catch, end
try, S.plotTop.forceZero = logical(get(S.hTopZero,'Value')); catch, end
try, S.plotTop.step      = safeNum(get(S.hTopStep,'String'),S.plotTop.step); catch, end
try, S.plotTop.ymin      = safeNum(get(S.hTopYmin,'String'),S.plotTop.ymin); catch, end
try, S.plotTop.ymax      = safeNum(get(S.hTopYmax,'String'),S.plotTop.ymax); catch, end

try, S.plotBot.auto      = logical(get(S.hBotAuto,'Value')); catch, end
try, S.plotBot.forceZero = logical(get(S.hBotZero,'Value')); catch, end
try, S.plotBot.step      = safeNum(get(S.hBotStep,'String'),S.plotBot.step); catch, end
try, S.plotBot.ymin      = safeNum(get(S.hBotYmin,'String'),S.plotBot.ymin); catch, end
try, S.plotBot.ymax      = safeNum(get(S.hBotYmax,'String'),S.plotBot.ymax); catch, end

if ~isfield(S,'plotX') || ~isstruct(S.plotX)
    S.plotX = struct('auto',true,'xmin',NaN,'xmax',NaN);
end

% Preview compact controls override only when numeric. auto/blank leaves ROI-tab settings.
v = previewAxisNumLocal(S,'hPrevTopYmax');
if isfinite(v)
    S.plotTop.auto = false;
    S.plotTop.ymax = v;
    try, set(S.hTopAuto,'Value',0); catch, end
    try, set(S.hTopYmax,'String',num2str(v)); catch, end
end

v = previewAxisNumLocal(S,'hPrevTopStep');
if isfinite(v) && v >= 0
    S.plotTop.step = v;
    try, set(S.hTopStep,'String',num2str(v)); catch, end
end

v = previewAxisNumLocal(S,'hPrevBotYmax');
if isfinite(v)
    S.plotBot.auto = false;
    S.plotBot.ymax = v;
    try, set(S.hBotAuto,'Value',0); catch, end
    try, set(S.hBotYmax,'String',num2str(v)); catch, end
end

v = previewAxisNumLocal(S,'hPrevBotStep');
if isfinite(v) && v >= 0
    S.plotBot.step = v;
    try, set(S.hBotStep,'String',num2str(v)); catch, end
end

x0 = previewAxisNumLocal(S,'hPrevXMin');
x1 = previewAxisNumLocal(S,'hPrevXMax');
if isfinite(x0) || isfinite(x1)
    S.plotX.auto = false;
    S.plotX.xmin = x0;
    S.plotX.xmax = x1;
else
    S.plotX.auto = true;
    S.plotX.xmin = NaN;
    S.plotX.xmax = NaN;
end

if ~isfield(S,'plotTop') || ~isstruct(S.plotTop)
    S.plotTop = struct('auto',true,'forceZero',false,'ymin',0,'ymax',300,'step',0);
end
if ~isfield(S,'plotBot') || ~isstruct(S.plotBot)
    S.plotBot = struct('auto',true,'forceZero',false,'ymin',0,'ymax',300,'step',0);
end
end

function v = previewAxisNumLocal(S,fieldName)
v = NaN;
try
    if ~isfield(S,fieldName) || ~ishghandle(S.(fieldName))
        return;
    end
    s = strtrim(char(get(S.(fieldName),'String')));
    if isempty(s) || strcmpi(s,'auto')
        return;
    end
    v = str2double(s);
    if ~isfinite(v)
        v = NaN;
    end
catch
    v = NaN;
end
end

function S = readROISettingsFromUI(S)
try, S.tc_computePSC = logical(get(S.hTC_ComputePSC,'Value')); catch, end
try, S.tc_baseMin0 = safeNum(get(S.hBase0,'String'),S.tc_baseMin0); catch, end
try, S.tc_baseMin1 = safeNum(get(S.hBase1,'String'),S.tc_baseMin1); catch, end
try, S.tc_injMin0 = safeNum(get(S.hInj0,'String'),S.tc_injMin0); catch, end
try, S.tc_injMin1 = safeNum(get(S.hInj1,'String'),S.tc_injMin1); catch, end
try, S.tc_peakSearchMin0 = safeNum(get(S.hPkS0,'String'),S.tc_peakSearchMin0); catch, end
try, S.tc_peakSearchMin1 = safeNum(get(S.hPkS1,'String'),S.tc_peakSearchMin1); catch, end
try, S.tc_plateauMin0 = safeNum(get(S.hPlat0,'String'),S.tc_plateauMin0); catch, end
try, S.tc_plateauMin1 = safeNum(get(S.hPlat1,'String'),S.tc_plateauMin1); catch, end
try, S.tc_peakWinMin = safeNum(get(S.hTC_PeakWin,'String'),S.tc_peakWinMin); catch, end
try, S.tc_trimPct = safeNum(get(S.hTC_Trim,'String'),S.tc_trimPct); catch, end
try
    items = get(S.hTC_Metric,'String');
    S.tc_metric = items{get(S.hTC_Metric,'Value')};
catch
end
end

function S = readStatsSettingsFromUI(S)
try
    items = get(S.hTest,'String');
    S.testType = items{get(S.hTest,'Value')};
catch
end
try, S.alpha = safeNum(get(S.hAlpha,'String'),S.alpha); catch, end
try
    items = get(S.hAnnotMode,'String');
    S.annotMode = items{get(S.hAnnotMode,'Value')};
catch
end
try, S.showPText = logical(get(S.hShowPText,'Value')); catch, end
end

function S = readPlotScaleSettingsFromUI(S)
% Read ROI Preview Y-axis controls directly from the GUI.
try, S.plotTop.auto      = logical(get(S.hTopAuto,'Value')); catch, end
try, S.plotTop.forceZero = logical(get(S.hTopZero,'Value')); catch, end
try, S.plotTop.step      = max(0, safeNum(get(S.hTopStep,'String'), S.plotTop.step)); catch, end
try, S.plotTop.ymin      = safeNum(get(S.hTopYmin,'String'), S.plotTop.ymin); catch, end
try, S.plotTop.ymax      = safeNum(get(S.hTopYmax,'String'), S.plotTop.ymax); catch, end

try, S.plotBot.auto      = logical(get(S.hBotAuto,'Value')); catch, end
try, S.plotBot.forceZero = logical(get(S.hBotZero,'Value')); catch, end
try, S.plotBot.step      = max(0, safeNum(get(S.hBotStep,'String'), S.plotBot.step)); catch, end
try, S.plotBot.ymin      = safeNum(get(S.hBotYmin,'String'), S.plotBot.ymin); catch, end
try, S.plotBot.ymax      = safeNum(get(S.hBotYmax,'String'), S.plotBot.ymax); catch, end

if ~isfield(S,'plotTop') || ~isstruct(S.plotTop)
    S.plotTop = struct('auto',true,'forceZero',false,'ymin',0,'ymax',300,'step',0);
end
if ~isfield(S,'plotBot') || ~isstruct(S.plotBot)
    S.plotBot = struct('auto',true,'forceZero',false,'ymin',0,'ymax',300,'step',0);
end

if ~isfinite(S.plotTop.step), S.plotTop.step = 0; end
if ~isfinite(S.plotBot.step), S.plotBot.step = 0; end

if ~isfinite(S.plotTop.ymin), S.plotTop.ymin = 0; end
if ~isfinite(S.plotTop.ymax), S.plotTop.ymax = S.plotTop.ymin + max(1,S.plotTop.step); end
if S.plotTop.ymax <= S.plotTop.ymin
    S.plotTop.ymax = S.plotTop.ymin + max(1,S.plotTop.step);
end

if ~isfinite(S.plotBot.ymin), S.plotBot.ymin = 0; end
if ~isfinite(S.plotBot.ymax), S.plotBot.ymax = S.plotBot.ymin + max(1,S.plotBot.step); end
if S.plotBot.ymax <= S.plotBot.ymin
    S.plotBot.ymax = S.plotBot.ymin + max(1,S.plotBot.step);
end

try, set(S.hTopStep,'String',num2str(S.plotTop.step)); catch, end
try, set(S.hTopYmin,'String',num2str(S.plotTop.ymin)); catch, end
try, set(S.hTopYmax,'String',num2str(S.plotTop.ymax)); catch, end
try, set(S.hBotStep,'String',num2str(S.plotBot.step)); catch, end
try, set(S.hBotYmin,'String',num2str(S.plotBot.ymin)); catch, end
try, set(S.hBotYmax,'String',num2str(S.plotBot.ymax)); catch, end
end

function applyPreviewLightDarkToUI(S)
% Apply Light/Dark preview mode to the actual ROI Preview tab widgets.
styleName = 'Dark';
try, styleName = char(S.previewStyle); catch, end

if strcmpi(styleName,'Light')
    bgMain = [1 1 1];
    bgTop  = [0.96 0.96 0.96];
    fg     = [0 0 0];
    editBg = [1 1 1];
    btnBg  = [0.86 0.86 0.86];
else
    bgMain = S.C.bg;
    bgTop  = S.C.panel2;
    fg     = [1 1 1];
    editBg = S.C.editBg;
    btnBg  = S.C.btnSecondary;
end

try, set(S.hPrevBG,'BackgroundColor',bgMain); catch, end
try, set(S.hPrevTop,'BackgroundColor',bgTop,'ForegroundColor',fg); catch, end
try, set(S.ax1,'Color',bgMain,'XColor',fg,'YColor',fg); catch, end
try, set(S.ax2,'Color',bgMain,'XColor',fg,'YColor',fg); catch, end

btns = {'hPrevExportTop','hPrevExportBot','hPrevExportBoth'};
for kk = 1:numel(btns)
    try
        h = S.(btns{kk});
        if ishghandle(h)
            set(h,'BackgroundColor',btnBg,'ForegroundColor',fg,'FontWeight','bold');
        end
    catch
    end
end

texts = {'hPrevLblView','hPrevLblWin'};
for kk = 1:numel(texts)
    try
        h = S.(texts{kk});
        if ishghandle(h)
            set(h,'BackgroundColor',bgTop,'ForegroundColor',fg);
        end
    catch
    end
end

edits = {'hPrevStyle','hSmoothWin','hPrevColorA','hPrevColorB'};
for kk = 1:numel(edits)
    try
        h = S.(edits{kk});
        if ishghandle(h)
            set(h,'BackgroundColor',editBg,'ForegroundColor',fg);
        end
    catch
    end
end

checks = {'hPrevGrid','hSmoothEnable','hPrevAnimalLabels'};
for kk = 1:numel(checks)
    try
        h = S.(checks{kk});
        if ishghandle(h)
            set(h,'BackgroundColor',bgTop,'ForegroundColor',fg);
        end
    catch
    end
end
end

function S = readMapSettingsFromUI(S)
try
    items = get(S.hMapSummary,'String');
    S.mapSummary = items{get(S.hMapSummary,'Value')};
catch
end
try
    items = get(S.hMapSource,'String');
    S.mapSource = items{get(S.hMapSource,'Value')};
catch
end
try
    items = get(S.hMapColormap,'String');
    S.mapColormap = items{get(S.hMapColormap,'Value')};
catch
end
try, S.mapBlackBody = logical(get(S.hMapBlackBody,'Value')); catch, end
try
    items = get(S.hMapFlipMode,'String');
    S.mapFlipMode = items{get(S.hMapFlipMode,'Value')};
catch
end
try
    items = get(S.hMapPolarity,'String');
    S.mapPolarity = items{get(S.hMapPolarity,'Value')};
catch
end
try, S.mapModMin = safeNum(get(S.hMapModMin,'String'),S.mapModMin); catch, end
try, S.mapModMax = safeNum(get(S.hMapModMax,'String'),S.mapModMax); catch, end
try, S.mapSigma = safeNum(get(S.hMapSigma,'String'),S.mapSigma); catch, end
try
    caxv = sscanf(get(S.hMapCaxis,'String'),'%f');
    if numel(caxv) >= 2
        S.mapCaxis = caxv(1:2).';
    end
catch
end
try, S.mapUseGlobalWindows = logical(get(S.hMapUseGlobalWin,'Value')); catch, end
try, S.mapGlobalBaseSec(1) = safeNum(get(S.hMapBase0,'String'),S.mapGlobalBaseSec(1)); catch, end
try, S.mapGlobalBaseSec(2) = safeNum(get(S.hMapBase1,'String'),S.mapGlobalBaseSec(2)); catch, end
try, S.mapGlobalSigSec(1) = safeNum(get(S.hMapSig0,'String'),S.mapGlobalSigSec(1)); catch, end
try, S.mapGlobalSigSec(2) = safeNum(get(S.hMapSig1,'String'),S.mapGlobalSigSec(2)); catch, end
try
    items = get(S.hMapUnderlayMode,'String');
    S.mapUnderlayMode = items{get(S.hMapUnderlayMode,'Value')};
catch
end
try
    items = get(S.hMapRefSide,'String');
    S.mapRefPacapSide = items{get(S.hMapRefSide,'Value')};
catch
end
try
    if isfield(S,'hMapAlphaMod') && ishghandle(S.hMapAlphaMod)
        S.mapAlphaModOn = logical(get(S.hMapAlphaMod,'Value'));
    else
        S.mapAlphaModOn = true;
    end
catch
    S.mapAlphaModOn = true;
end
S.mapThreshold = 0;
end

function nZ = inferMapSliceCountFromBundleLocal(G)
nZ = 1;
try
    if isfield(G,'pscAtlas4D') && ~isempty(G.pscAtlas4D) && isnumeric(G.pscAtlas4D)
        X = G.pscAtlas4D;
        if ndims(X) == 4
            nZ = max(nZ,size(X,3));
        end
    end
catch
end
try
    flds = {'underlayAtlas','underlay2D','scmMapSignedAtlas','scmMapDisplayAtlas'};
    for ii = 1:numel(flds)
        if isfield(G,flds{ii}) && ~isempty(G.(flds{ii})) && isnumeric(G.(flds{ii}))
            A = G.(flds{ii});
            if ndims(A) == 3 && size(A,3) ~= 3
                nZ = max(nZ,size(A,3));
            elseif ndims(A) == 4
                nZ = max(nZ,size(A,3));
            end
        end
    end
catch
end
try
    if isfield(G,'underlays') && isstruct(G.underlays)
        fn = fieldnames(G.underlays);
        for ii = 1:numel(fn)
            E = G.underlays.(fn{ii});
            if isstruct(E) && isfield(E,'data'), A = E.data; else, A = E; end
            if isnumeric(A) || islogical(A)
                if ndims(A) == 3 && size(A,3) ~= 3
                    nZ = max(nZ,size(A,3));
                elseif ndims(A) == 4
                    nZ = max(nZ,size(A,3));
                end
            end
        end
    end
catch
end
try
    if isfield(G,'nSlices') && isfinite(double(G.nSlices(1)))
        nZ = max(nZ,round(double(G.nSlices(1))));
    end
catch
end
nZ = max(1,round(nZ));
end

function z = defaultMapSliceFromBundleLocal(G,nZ)
z = round(max(1,nZ)/2);
try
    names = {'currentSlice','sliceIdx','zIndex','atlasSliceIndex'};
    for ii = 1:numel(names)
        if isfield(G,names{ii}) && ~isempty(G.(names{ii}))
            zz = round(double(G.(names{ii})(1)));
            if isfinite(zz) && zz >= 1 && zz <= nZ
                z = zz;
                return;
            end
        end
    end
catch
end
z = max(1,min(nZ,round(z)));
end

function D = buildCurrentMapDisplayLocal(S)
R = S.lastMAP;
D = struct();
D.map = R.groupMap;
D.underlay = R.commonUnderlay;
D.render = makeMapRenderStructLocal(S);
if strcmpi(strtrimSafe(R.mapSummary),'Median')
    D.title = sprintf('Group median map (n=%d)',R.n);
else
    D.title = sprintf('Group mean map (n=%d)',R.n);
end
if strcmpi(S.mapUnderlayMode,'Loaded custom underlay') && ~isempty(S.mapLoadedUnderlay)
    D.underlay = S.mapLoadedUnderlay;
end
end

function Rm = makeMapRenderStructLocal(S)
Rm = struct();
Rm.threshold = 0;
Rm.caxis = S.mapCaxis;
try, Rm.negCaxis = S.mapNegCaxis; catch, Rm.negCaxis = [-max(abs(Rm.caxis)) 0]; end
try, Rm.alphaModOn = logical(S.mapAlphaModOn); catch, Rm.alphaModOn = true; end
Rm.modMin = S.mapModMin;
Rm.modMax = S.mapModMax;
Rm.blackBody = S.mapBlackBody;
Rm.colormapName = S.mapColormap;
try, Rm.polarity = S.mapPolarity; catch, Rm.polarity = 'Positive only'; end
Rm.flipUDPreview = false; % GA orientation fix: do not force upside-down flip
try, Rm.alphaPercent = double(S.mapAlphaPercent); catch, Rm.alphaPercent = 100; end
Rm.overlayMask = [];
try
    if isfield(S,'mapLoadedOverlayMask') && ~isempty(S.mapLoadedOverlayMask)
        Rm.overlayMask = S.mapLoadedOverlayMask;
    end
catch
end
end

function hardClearAxLocal(ax,styleName,showGrid,ttl)
try
    cla(ax,'reset');
catch
    cla(ax);
end
[bg,fg] = previewColorsLocal(styleName);
set(ax,'Color',bg,'XColor',fg,'YColor',fg);
if showGrid
    grid(ax,'on');
else
    grid(ax,'off');
end
title(ax,ttl,'Color',fg,'FontWeight','bold');
end

function [bg,fg] = previewColorsLocal(styleName)
if strcmpi(styleName,'Light')
    bg = [1 1 1];
    fg = [0 0 0];
else
    bg = [0 0 0];
    fg = [1 1 1];
end
end

function fcNoDataLocal(ax,titleStr,C)
cla(ax);
text(ax,0.5,0.5,'No data', ...
    'HorizontalAlignment','center','VerticalAlignment','middle', ...
    'Color',C.txt,'FontName','Arial','FontSize',12,'FontWeight','bold');
set(ax,'Color',C.axisBg,'XColor',C.muted,'YColor',C.muted,'XTick',[],'YTick',[]);
title(ax,titleStr,'Color',C.txt,'FontWeight','bold','Interpreter','none');
end

function keys = makeRowKeysLocal(tbl)
n = size(tbl,1);
keys = cell(n,1);
for i = 1:n
    keys{i} = [strtrimSafe(tbl{i,2}) '|' strtrimSafe(tbl{i,3}) '|' strtrimSafe(tbl{i,4}) '|' strtrimSafe(tbl{i,5})];
end
end

function s = shortPathForTable(fp,maxLen)
if nargin < 2, maxLen = 40; end
s = strtrimSafe(fp);
[~,name,ext] = fileparts(s);
s = [name ext];
if numel(s) > maxLen
    s = [s(1:maxLen-3) '...'];
end
end

function subj = guessSubjectID(txt)
subj = '';
try
    m = parseMetaSingleText(txt);
    if ~strcmpi(m.animalID,'N/A')
        subj = m.animalID;
        return;
    end
catch
end
try
    [~,bn,~] = fileparts(txt);
    subj = bn;
catch
end
if isempty(subj)
    subj = ['S' datestr(now,'HHMMSS')];
end
end

function meta = extractMetaFromSources(subjectTxt,dataFile,roiFile,bundleFile)
if nargin < 4, bundleFile = ''; end
meta = struct('animalID','N/A','session','N/A','scanID','N/A');
cands = {bundleFile,roiFile,dataFile,subjectTxt};
for i = 1:numel(cands)
    txt = strtrimSafe(cands{i});
    if isempty(txt), continue; end
    m = parseMetaSingleText(txt);
    if strcmpi(meta.animalID,'N/A') && ~strcmpi(m.animalID,'N/A')
        meta.animalID = m.animalID;
    end
    if strcmpi(meta.session,'N/A') && ~strcmpi(m.session,'N/A')
        meta.session = m.session;
    end
    if strcmpi(meta.scanID,'N/A') && ~strcmpi(m.scanID,'N/A')
        meta.scanID = m.scanID;
    end
end
end

function meta = parseMetaSingleText(txt)
meta = struct('animalID','N/A','session','N/A','scanID','N/A');
txt = strrep(strtrimSafe(txt),'\','/');
txtU = upper(txt);

% Classic animal/session/scan pattern.
tok = regexpi(txtU,'([A-Z]{1,8}\d{6}[A-Z]?)_(S\d+)_(FUS_\d+)','tokens','once');
if ~isempty(tok)
    meta.animalID = tok{1};
    meta.session = tok{2};
    meta.scanID = tok{3};
    return;
end

tok = regexpi(txtU,'([A-Z]{1,8}\d{6}[A-Z]?)_(S\d+)','tokens','once');
if ~isempty(tok)
    meta.animalID = tok{1};
    meta.session = tok{2};
end

% Session_003 / Sess_003 / Session003 from folders or file names.
tok = regexpi(txtU,'(?:SESSION|SESS)[_\- ]*0*(\d+)','tokens','once');
if ~isempty(tok)
    nSess = str2double(tok{1});
    if isfinite(nSess)
        meta.session = sprintf('Session_%03d', round(nSess));
    else
        meta.session = ['Session_' tok{1}];
    end
end

% Scan / FUS id.
tok = regexpi(txtU,'(FUS_\d+)','tokens','once');
if ~isempty(tok), meta.scanID = tok{1}; end
if strcmpi(meta.scanID,'N/A')
    tok = regexpi(txt,'(scan\d+(?:_[A-Za-z0-9]+)?)','tokens','once');
    if ~isempty(tok), meta.scanID = tok{1}; end
end

% PACAP/RGRO pattern: RGRO_260512_1024_MM_B6J_1005 -> animalID = 1005.
tok = regexpi(txtU,'[A-Z]+[_\-]\d{6}[_\-]\d{3,6}[_\-][A-Z]+[_\-][A-Z0-9]+[_\-](\d{3,6})(?:[_\-. /]|$)','tokens','once');
if ~isempty(tok), meta.animalID = tok{1}; end

% General sex/strain/ID pattern: MM_B6J_1005.
if strcmpi(meta.animalID,'N/A')
    tok = regexpi(txtU,'(?:^|[_/\-])(MM|M|F|MALE|FEMALE)[_/\-]+[A-Z0-9]+[_/\-]+(\d{3,6})(?:[_/\-. ]|$)','tokens','once');
    if ~isempty(tok), meta.animalID = tok{2}; end
end

txtTok = regexprep(txt,'[^A-Za-z0-9/_\-]','_');
parts = regexp(txtTok,'[/_\-]+','split');
parts = parts(~cellfun(@isempty,parts));

% Session fallback from split parts.
if strcmpi(meta.session,'N/A')
    for k = 1:numel(parts)
        pk = parts{k};
        if ~isempty(regexpi(pk,'^S\d+$','once'))
            meta.session = pk;
            break;
        end
        tokS = regexpi(pk,'^Session0*(\d+)$','tokens','once');
        if ~isempty(tokS)
            meta.session = sprintf('Session_%03d', round(str2double(tokS{1})));
            break;
        end
        if strcmpi(pk,'Session') && k < numel(parts) && ~isempty(regexpi(parts{k+1},'^\d+$','once'))
            meta.session = sprintf('Session_%03d', round(str2double(parts{k+1})));
            break;
        end
    end
end

% Scan fallback from split parts.
scanIdx = [];
for k = 1:numel(parts)
    if ~isempty(regexpi(parts{k},'^scan\d+$','once'))
        scanIdx = k;
        scanID = parts{k};
        if k < numel(parts)
            nxt = parts{k+1};
            if ~isempty(regexpi(nxt,'^[A-Za-z]{1,6}[A-Za-z0-9]*$','once')) && isempty(regexpi(nxt,'^S\d+$','once')) && isempty(regexpi(nxt,'^\d+$','once'))
                scanID = [scanID '_' nxt];
            end
        end
        meta.scanID = scanID;
        break;
    end
end

% Strain marker fallback: B6J / C57BL6J followed by numeric animal ID.
if strcmpi(meta.animalID,'N/A')
    for k = 1:numel(parts)-1
        if ~isempty(regexpi(parts{k},'^(B6J|C57BL6J|C57|BL6J)$','once')) && ~isempty(regexpi(parts{k+1},'^\d{3,6}$','once'))
            meta.animalID = parts{k+1};
            break;
        end
    end
end

% Old fallback: number shortly before scan token.
if strcmpi(meta.animalID,'N/A') && ~isempty(scanIdx)
    for k = scanIdx-1:-1:max(1,scanIdx-3)
        if ~isempty(regexpi(parts{k},'^\d{3,6}$','once'))
            meta.animalID = parts{k};
            break;
        end
    end
end
end

function info = extractRowMetaLight(row)
info = struct();
info.subject = strtrimSafe(row{2});
info.group = strtrimSafe(row{3});
info.condition = strtrimSafe(row{4});
info.pairID = strtrimSafe(row{5});
info.dataFile = strtrimSafe(row{6});
info.roiFile = strtrimSafe(row{7});
info.bundleFile = strtrimSafe(row{8});
info.status = strtrimSafe(row{9});
meta = extractMetaFromSources(info.subject,info.dataFile,info.roiFile,info.bundleFile);
info.animalID = meta.animalID;
info.session = meta.session;
info.scanID = meta.scanID;
end


function s = displayScanID(scanID)
s = strtrimSafe(scanID);
s = regexprep(s,'(?i)^FUS_?','');
s = regexprep(s,'(?i)^SCAN','scan');
end


function key = makeAuditMatchKey(row)
% Stable matching key for Excel audit export.
key = '';

try
    if isempty(row)
        return;
    end

    if iscell(row) && size(row,1) > 1
        row = row(1,:);
    end

    vals = cell(1,9);
    for ii = 1:9
        if iscell(row) && numel(row) >= ii
            vals{ii} = row{ii};
        else
            vals{ii} = '';
        end
    end

    animal = strtrimSafe(vals{2});
    grp    = strtrimSafe(vals{3});
    cond   = strtrimSafe(vals{4});
    pairid = strtrimSafe(vals{5});
    dataf  = strtrimSafe(vals{6});
    roif   = strtrimSafe(vals{7});
    bunf   = strtrimSafe(vals{8});

    try
        meta = extractMetaFromSources(animal, dataf, roif, bunf);
        if ~isempty(strtrimSafe(meta.animalID)) && ~strcmpi(strtrimSafe(meta.animalID),'N/A')
            animal = strtrimSafe(meta.animalID);
        end
        sess = strtrimSafe(meta.session);
        scan = strtrimSafe(meta.scanID);
    catch
        sess = '';
        scan = '';
    end

    [~,roiName,roiExt] = fileparts(roif);
    roiLeaf = [roiName roiExt];

    key = lower(strjoin({animal,sess,scan,grp,cond,pairid,roiLeaf}, '|'));
catch
    key = '';
end
end


function [mapNow, winInfoTxt] = GA_buildPreviewMapFromBundle_STANDALONE(S0, G)
% Standalone fallback helper for GroupAnalysis map preview.
winInfoTxt = '';
mapNow = [];

if nargin < 2 || ~isstruct(G)
    error('Invalid group bundle struct.');
end

useGlobal = false;
try
    useGlobal = isfield(S0,'mapUseGlobalWindows') && logical(S0.mapUseGlobalWindows);
catch
    useGlobal = false;
end

src = 'Recompute from exported PSC';
try
    if isfield(S0,'mapSource') && ~isempty(S0.mapSource)
        src = GA_strtrimSafe_STANDALONE(S0.mapSource);
    end
catch
end

sigma = 0;
try, sigma = double(S0.mapSigma); catch, end
if ~isfinite(sigma), sigma = 0; end

hasPSC = isfield(G,'pscAtlas4D') && ~isempty(G.pscAtlas4D);
hasMap = isfield(G,'scmMapAtlas') && ~isempty(G.scmMapAtlas);

if useGlobal
    if hasPSC
        bw = double(S0.mapGlobalBaseSec(:)');
        sw = double(S0.mapGlobalSigSec(:)');
        mapNow = GA_recomputeScmFromPSC_STANDALONE(G, bw, sw, sigma);
        winInfoTxt = sprintf('base %.0f-%.0fs | sig %.0f-%.0fs', bw(1), bw(2), sw(1), sw(2));
    elseif hasMap
        mapNow = GA_squeezeMap2D_STANDALONE(G.scmMapAtlas);
        winInfoTxt = 'exported SCM fallback; no PSC series';
    else
        error('Bundle has neither pscAtlas4D nor scmMapAtlas.');
    end
elseif strcmpi(src,'Use exported SCM map')
    if hasMap
        mapNow = GA_squeezeMap2D_STANDALONE(G.scmMapAtlas);
        winInfoTxt = 'exported SCM map';
    elseif hasPSC
        [bw, sw] = GA_defaultBundleWindows_STANDALONE(G, S0);
        mapNow = GA_recomputeScmFromPSC_STANDALONE(G, bw, sw, sigma);
        winInfoTxt = sprintf('PSC fallback base %.0f-%.0fs | sig %.0f-%.0fs', bw(1), bw(2), sw(1), sw(2));
    else
        error('Bundle has neither exported map nor PSC series.');
    end
else
    if hasPSC
        [bw, sw] = GA_defaultBundleWindows_STANDALONE(G, S0);
        mapNow = GA_recomputeScmFromPSC_STANDALONE(G, bw, sw, sigma);
        winInfoTxt = sprintf('base %.0f-%.0fs | sig %.0f-%.0fs', bw(1), bw(2), sw(1), sw(2));
    elseif hasMap
        mapNow = GA_squeezeMap2D_STANDALONE(G.scmMapAtlas);
        winInfoTxt = 'exported SCM fallback; no PSC series';
    else
        error('Bundle has neither pscAtlas4D nor scmMapAtlas.');
    end
end

mapNow = double(mapNow);
mapNow(~isfinite(mapNow)) = 0;
end

function [bw, sw] = GA_defaultBundleWindows_STANDALONE(G, S0)
bw = [30 240];
sw = [840 900];
try
    if isfield(G,'baseWindowSec') && numel(G.baseWindowSec) >= 2
        bw = double(G.baseWindowSec(1:2));
    elseif isfield(S0,'mapGlobalBaseSec') && numel(S0.mapGlobalBaseSec) >= 2
        bw = double(S0.mapGlobalBaseSec(1:2));
    end
catch
end
try
    if isfield(G,'sigWindowSec') && numel(G.sigWindowSec) >= 2
        sw = double(G.sigWindowSec(1:2));
    elseif isfield(S0,'mapGlobalSigSec') && numel(S0.mapGlobalSigSec) >= 2
        sw = double(S0.mapGlobalSigSec(1:2));
    end
catch
end
if numel(bw) < 2 || any(~isfinite(bw)), bw = [30 240]; end
if numel(sw) < 2 || any(~isfinite(sw)), sw = [840 900]; end
if bw(2) <= bw(1), bw(2) = bw(1) + 1; end
if sw(2) <= sw(1), sw(2) = sw(1) + 1; end
end

function map2 = GA_recomputeScmFromPSC_STANDALONE(G, baseWinSec, sigWinSec, sigma)
if ~isfield(G,'pscAtlas4D') || isempty(G.pscAtlas4D)
    error('Bundle has no pscAtlas4D.');
end
if ~isfield(G,'TR') || isempty(G.TR) || ~isfinite(G.TR) || G.TR <= 0
    error('Bundle has no valid TR.');
end

PSC = double(G.pscAtlas4D);
TR = double(G.TR);

if ndims(PSC) == 3
    PSCz = PSC;
elseif ndims(PSC) == 4
    zSel = round(size(PSC,3)/2);
    try
        if isfield(G,'atlasSliceIndex') && ~isempty(G.atlasSliceIndex) && isfinite(G.atlasSliceIndex)
            zSel = round(G.atlasSliceIndex);
        elseif isfield(G,'currentSlice') && ~isempty(G.currentSlice) && isfinite(G.currentSlice)
            zSel = round(G.currentSlice);
        end
    catch
    end
    zSel = max(1, min(size(PSC,3), zSel));
    PSCz = squeeze(PSC(:,:,zSel,:));
else
    error('pscAtlas4D must be [Y X T] or [Y X Z T].');
end

if ndims(PSCz) ~= 3
    error('Selected PSC slice is not [Y X T].');
end

nT = size(PSCz,3);
b0 = max(1, min(nT, round(baseWinSec(1)/TR) + 1));
b1 = max(1, min(nT, round(baseWinSec(2)/TR) + 1));
s0 = max(1, min(nT, round(sigWinSec(1)/TR) + 1));
s1 = max(1, min(nT, round(sigWinSec(2)/TR) + 1));
if b1 < b0, tmp = b0; b0 = b1; b1 = tmp; end
if s1 < s0, tmp = s0; s0 = s1; s1 = tmp; end

baseMap = mean(PSCz(:,:,b0:b1),3);
sigMap  = mean(PSCz(:,:,s0:s1),3);
map2 = sigMap - baseMap;

if isfinite(sigma) && sigma > 0
    map2 = GA_smooth2D_STANDALONE(map2, sigma);
end

mask2D = GA_extractMask2D_STANDALONE(G, size(map2));
if ~isempty(mask2D)
    try, map2(~mask2D) = 0; catch, end
end

map2(~isfinite(map2)) = 0;
end

function M2 = GA_squeezeMap2D_STANDALONE(M)
M = double(M);
if isempty(M), M2 = []; return; end
if ndims(M) == 2
    M2 = M;
elseif ndims(M) == 3
    if size(M,3) == 1
        M2 = M(:,:,1);
    else
        z = max(1, round(size(M,3)/2));
        M2 = M(:,:,z);
    end
else
    error('Unsupported SCM map dimensionality.');
end
M2(~isfinite(M2)) = 0;
end

function mask2D = GA_extractMask2D_STANDALONE(G, szMap)
mask2D = [];
try
    if isfield(G,'mask2DCurrentSlice') && ~isempty(G.mask2DCurrentSlice)
        M = logical(G.mask2DCurrentSlice);
        if isequal(size(M), szMap)
            mask2D = M;
            return;
        end
    end
catch
end
try
    if isfield(G,'maskAtlas') && ~isempty(G.maskAtlas)
        M = logical(G.maskAtlas);
        if ismatrix(M) && isequal(size(M), szMap)
            mask2D = M;
            return;
        elseif ndims(M) == 3
            zSel = round(size(M,3)/2);
            try
                if isfield(G,'atlasSliceIndex') && ~isempty(G.atlasSliceIndex) && isfinite(G.atlasSliceIndex)
                    zSel = round(G.atlasSliceIndex);
                elseif isfield(G,'currentSlice') && ~isempty(G.currentSlice) && isfinite(G.currentSlice)
                    zSel = round(G.currentSlice);
                end
            catch
            end
            zSel = max(1, min(size(M,3), zSel));
            M2 = M(:,:,zSel);
            if isequal(size(M2), szMap)
                mask2D = M2;
                return;
            end
        end
    end
catch
end
end

function B = GA_smooth2D_STANDALONE(A, sigma)
try
    B = imgaussfilt(A, sigma);
    return;
catch
end
if sigma <= 0
    B = A;
    return;
end
r = max(1, ceil(3*sigma));
x = -r:r;
g = exp(-(x.^2)/(2*sigma^2));
g = g / sum(g);
B = conv2(conv2(double(A), g, 'same'), g', 'same');
end

function s = GA_strtrimSafe_STANDALONE(x)
try
    if isempty(x)
        s = '';
    else
        s = strtrim(char(x));
    end
catch
    s = '';
end
end


% GA_ROI_PREVIEW_STANDALONE_START
function exportOnePreview(ax, whichPlot, S, styleName)
% Repaired fail-safe ROI preview plotter.
% - Replots from S.lastROI when available.
% - Falls back to reading active ROI TXT files from S.subj(:,7).
% - Fixes light/dark axis colors.
% - Uses PSC (%) labels.
% - Removes lower-plot errorbars/legend.
% - Supports line/shade/color/animal-label controls when visible.

if nargin < 4 || isempty(styleName)
    styleName = 'Dark';
end
try
    if isfield(S,'previewStyle') && ~isempty(S.previewStyle)
        styleName = char(S.previewStyle);
    end
catch
end

if isempty(ax) || ~ishandle(ax)
    return;
end

figH = ancestor(ax,'figure');
[lineW, shadeA, colA, colB, showAnimalLabels] = ga_preview_style_from_gui(figH);

cla(ax,'reset');
hold(ax,'on');

if strcmpi(styleName,'Light')
    bgCol = [1 1 1];
    fgCol = [0 0 0];
else
    bgCol = [0 0 0];
    fgCol = [1 1 1];
end

set(ax,'Color',bgCol,'XColor',fgCol,'YColor',fgCol, ...
    'FontName','Arial','FontSize',11,'LineWidth',1.2,'Layer','top','Box','off');
try, set(get(ax,'Title'),'Color',fgCol,'FontName','Arial','FontWeight','bold'); catch, end
try, set(get(ax,'XLabel'),'Color',fgCol,'FontName','Arial','FontWeight','bold'); catch, end
try, set(get(ax,'YLabel'),'Color',fgCol,'FontName','Arial','FontWeight','bold'); catch, end

R = ga_get_roi_preview_data(S);

if isempty(R) || ~isstruct(R)
    text(ax,0.5,0.5,{'No ROI data found.','Check that active rows have ROI TXT files in the ROI File column.'}, ...
        'Units','normalized','HorizontalAlignment','center','VerticalAlignment','middle', ...
        'Color',fgCol,'FontName','Arial','FontSize',12,'FontWeight','bold');
    xlim(ax,[0 1]); ylim(ax,[0 1]);
    return;
end

if whichPlot == 1
    ga_plot_roi_top(ax,R,S,fgCol,bgCol,lineW,shadeA,colA,colB);
else
    ga_plot_roi_bottom(ax,R,S,fgCol,bgCol,colA,colB,showAnimalLabels);
end

try, try, GA_force_scm_alpha_20260504(gcf,10,20); catch, end; % AUTO_FORCE_SCM_ALPHA_20260504
drawnow limitrate; catch, end
end

function R = ga_get_roi_preview_data(S)
R = [];
try
    if isfield(S,'lastROI') && isstruct(S.lastROI) && ~isempty(fieldnames(S.lastROI))
        LR = S.lastROI;
        if isfield(LR,'tMin') && isfield(LR,'group') && ~isempty(LR.group)
            R = LR;
            return;
        end
    end
catch
end

R = ga_build_roi_preview_from_txt(S);
end

function R = ga_build_roi_preview_from_txt(S)
R = [];
if ~isfield(S,'subj') || isempty(S.subj)
    return;
end
subj = S.subj;
if ~iscell(subj) || size(subj,2) < 7
    return;
end

rows = [];
for r = 1:size(subj,1)
    useRow = true;
    try, useRow = ga_bool(subj{r,1}); catch, useRow = true; end
    roiFile = '';
    try, roiFile = strtrim(char(subj{r,7})); catch, roiFile = ''; end
    if useRow && ~isempty(roiFile) && exist(roiFile,'file') == 2
        rows(end+1) = r; %#ok<AGROW>
    end
end

if isempty(rows)
    return;
end

n = numel(rows);
tCell = cell(n,1);
yCell = cell(n,1);
grp = cell(n,1);
subjName = cell(n,1);

for i = 1:n
    r = rows(i);
    roiFile = strtrim(char(subj{r,7}));
    [ok,tMin,psc] = ga_read_roi_txt(roiFile);
    if ~ok
        tCell{i} = [];
        yCell{i} = [];
    else
        tCell{i} = tMin(:)';
        yCell{i} = psc(:)';
    end

    try, grp{i} = strtrim(char(subj{r,3})); catch, grp{i} = ''; end
    if isempty(grp{i}), grp{i} = 'GroupA'; end

    try, subjName{i} = strtrim(char(subj{r,2})); catch, subjName{i} = ''; end
    if isempty(subjName{i}), subjName{i} = sprintf('S%d',i); end
end

okTrace = false(n,1);
for i = 1:n
    okTrace(i) = numel(tCell{i}) >= 3 && numel(yCell{i}) == numel(tCell{i});
end

if ~any(okTrace)
    return;
end

rows = rows(okTrace);
tCell = tCell(okTrace);
yCell = yCell(okTrace);
grp = grp(okTrace);
subjName = subjName(okTrace);
n = numel(tCell);

t0 = -inf;
t1 = inf;
dtList = [];
for i = 1:n
    t = tCell{i};
    t0 = max(t0,min(t));
    t1 = min(t1,max(t));
    d = diff(t);
    d = d(isfinite(d) & d > 0);
    dtList = [dtList d(:)']; %#ok<AGROW>
end

if ~isfinite(t0) || ~isfinite(t1) || t1 <= t0
    tCommon = tCell{1};
else
    dt = median(dtList);
    if ~isfinite(dt) || dt <= 0
        dt = 0.1;
    end
    tCommon = t0:dt:t1;
end

X = nan(n,numel(tCommon));
for i = 1:n
    try
        X(i,:) = interp1(tCell{i},yCell{i},tCommon,'linear',NaN);
    catch
    end
end

gNames = ga_unique_stable(grp);
gNames = ga_sort_groups(gNames);

G = struct([]);
for g = 1:numel(gNames)
    idx = strcmpi(grp,gNames{g});
    mu = ga_nanmean(X(idx,:),1);
    sd = ga_nanstd(X(idx,:),0,1);
    nn = sum(isfinite(X(idx,:)),1);
    se = sd ./ sqrt(max(1,nn));
    G(g).name = gNames{g};
    G(g).mean = mu;
    G(g).sem = se;
    G(g).n = sum(idx);
end

m0 = NaN; m1 = NaN;
try, if isfield(S,'tc_plateauMin0'), m0 = double(S.tc_plateauMin0); end, catch, end
try, if isfield(S,'tc_plateauMin1'), m1 = double(S.tc_plateauMin1); end, catch, end
if ~isfinite(m0) || ~isfinite(m1) || m1 <= m0
    ttMax = max(tCommon);
    if ttMax >= 40
        m0 = 30; m1 = 40;
    else
        m0 = 0.65*ttMax; m1 = ttMax;
    end
end

w = tCommon >= m0 & tCommon <= m1;
if ~any(w)
    w = true(size(tCommon));
end
metricVals = ga_nanmean(X(:,w),2);

stats = struct('p',NaN,'alpha',0.05,'type','Welch fallback');
if numel(gNames) >= 2
    a = metricVals(strcmpi(grp,gNames{1}));
    b = metricVals(strcmpi(grp,gNames{2}));
    stats.p = ga_welch_p(a,b);
end

R = struct();
R.mode = 'ROI Timecourse';
R.tMin = tCommon;
R.group = G;
R.groupNames = gNames;
R.groupDisplayNames = ga_display_group_names(gNames);
R.metricVals = metricVals;
R.metricName = sprintf('Mean PSC %.1f-%.1f min',m0,m1);
R.stats = stats;
R.subjTable = subj(rows,:);
R.subjectNames = subjName;
R.rawX = X;
R.rawGroups = grp;
end

function ga_plot_roi_top(ax,R,S,fgCol,bgCol,lineW,shadeA,colA,colB)
t = double(R.tMin(:)');
if isempty(t) || ~isfield(R,'group') || isempty(R.group)
    text(ax,0.5,0.5,'No top-plot ROI data','Units','normalized','HorizontalAlignment','center','Color',fgCol);
    return;
end

allY = [];
lineHs = [];
leg = {};

for g = 1:numel(R.group)
    if g == 1, cc = colA; else, cc = colB; end
    try
        nm = lower(char(R.group(g).name));
        if ~isempty(strfind(nm,'veh')) || ~isempty(strfind(nm,'control')), cc = colB; end
        if ~isempty(strfind(nm,'pacap')), cc = colA; end
    catch
    end

    y = double(R.group(g).mean(:)');
    e = double(R.group(g).sem(:)');
    if isempty(y) || numel(y) ~= numel(t)
        continue;
    end

    if gaPrevField(S,'tc_previewSmooth',false)
        try
            dtSec = median(diff(t))*60;
            y = gaPrevSmooth(y,dtSec,gaPrevField(S,'tc_previewSmoothWinSec',60));
            e = gaPrevSmooth(e,dtSec,gaPrevField(S,'tc_previewSmoothWinSec',60));
        catch
        end
    end

    if gaPrevField(S,'tc_showSEM',true) && ~isempty(e) && numel(e) == numel(y)
        up = y + e;
        dn = y - e;
        patch(ax,[t fliplr(t)],[up fliplr(dn)],cc, ...
            'FaceAlpha',shadeA,'EdgeColor','none','HandleVisibility','off');
        allY = [allY up(:)' dn(:)']; %#ok<AGROW>
    end

    dispName = R.group(g).name;
    try
        if isfield(R,'groupDisplayNames') && numel(R.groupDisplayNames) >= g
            dispName = R.groupDisplayNames{g};
        end
    catch
    end

    hLine = plot(ax,t,y,'Color',cc,'LineWidth',lineW,'DisplayName',dispName);
    lineHs = [lineHs hLine]; %#ok<AGROW>
    leg{end+1} = sprintf('%s (n=%d)',dispName,R.group(g).n); %#ok<AGROW>
    allY = [allY y(:)']; %#ok<AGROW>
end

xlabel(ax,'Time (min)','Color',fgCol,'FontWeight','bold');
ylabel(ax,'PSC (%)','Color',fgCol,'FontWeight','bold');
title(ax,'Group ROI timecourse','Color',fgCol,'FontWeight','bold');

ga_apply_preview_x(ax,t,S);
gaPrevApplyY(ax,allY,gaPrevField(S,'plotTop',struct('auto',true,'forceZero',false,'ymin',0,'ymax',1,'step',0)));
ga_draw_injection_box_final(ax,S,fgCol,bgCol);

try
    if ~isempty(lineHs)
        lg = legend(ax,lineHs,leg,'Location','northeast','Box','off');
        set(lg,'TextColor',fgCol,'Color',bgCol,'EdgeColor','none');
    end
catch
end

ga_apply_preview_grid(ax,S,fgCol);
end

function ga_plot_roi_bottom(ax,R,S,fgCol,bgCol,colA,colB,showAnimalLabels)
if ~isfield(R,'metricVals') || isempty(R.metricVals)
    text(ax,0.5,0.5,'No lower-plot metric data','Units','normalized','HorizontalAlignment','center','Color',fgCol);
    return;
end

metricVals = double(R.metricVals(:));
if isfield(R,'subjTable') && ~isempty(R.subjTable)
    T = R.subjTable;
else
    T = {};
end

if isfield(R,'groupNames') && ~isempty(R.groupNames)
    gNames = R.groupNames;
else
    gNames = {'GroupA'};
end

dispNames = ga_display_group_names(gNames);
if isfield(R,'groupDisplayNames') && ~isempty(R.groupDisplayNames)
    try, dispNames = R.groupDisplayNames; catch, end
end

grp = cell(numel(metricVals),1);
for i = 1:numel(metricVals)
    grp{i} = '';
    if ~isempty(T) && size(T,2) >= 3
        try, grp{i} = strtrim(char(T{i,3})); catch, grp{i} = ''; end
    end
    if isempty(grp{i})
        grp{i} = gNames{1};
    end
end

allY = [];
for g = 1:numel(gNames)
    idxRows = find(strcmpi(grp,gNames{g}) & isfinite(metricVals));
    vals = metricVals(idxRows);
    if isempty(vals)
        continue;
    end

    if g == 1, cc = colA; else, cc = colB; end
    try
        nm = lower(char(gNames{g}));
        if ~isempty(strfind(nm,'veh')) || ~isempty(strfind(nm,'control')), cc = colB; end
        if ~isempty(strfind(nm,'pacap')), cc = colA; end
    catch
    end

    for k = 1:numel(idxRows)
        ii = idxRows(k);
        y = metricVals(ii);
        x = g + ga_jitter(ii,0.22);
        scatter(ax,x,y,145, ...
            'MarkerFaceColor',cc, ...
            'MarkerEdgeColor',cc, ...
            'LineWidth',1.3, ...
            'HandleVisibility','off');
        allY(end+1) = y; %#ok<AGROW>

        if showAnimalLabels
            label = sprintf('S%d',ii);
            try
                if ~isempty(T) && size(T,2) >= 2
                    label = char(T{ii,2});
                end
            catch
            end
            text(ax,x+0.04,y,label, ...
                'Color',fgCol, ...
                'FontName','Arial', ...
                'FontSize',9, ...
                'FontWeight','bold', ...
                'Interpreter','none', ...
                'Clipping','on');
        end
    end

    mu = mean(vals);
    plot(ax,[g-0.28 g+0.28],[mu mu], ...
        '-', ...
        'Color',cc, ...
        'LineWidth',3.8, ...
        'HandleVisibility','off');
    allY(end+1) = mu; %#ok<AGROW>
end

set(ax,'XTick',1:numel(gNames),'XTickLabel',dispNames,'FontSize',11);
try, xtickangle(ax,20); catch, end
xlabel(ax,'','Color',fgCol);
ylabel(ax,'PSC (%)','Color',fgCol,'FontWeight','bold');
title(ax,'Per-animal ROI metric','Color',fgCol,'FontWeight','bold');
xlim(ax,[0.4 numel(gNames)+0.6]);

gaPrevApplyY(ax,allY,gaPrevField(S,'plotBot',struct('auto',true,'forceZero',false,'ymin',0,'ymax',1,'step',0)));

try, legend(ax,'off'); catch, end
try, delete(findall(ax,'Type','errorbar')); catch, end

try
    if isfield(R,'stats') && isfield(R.stats,'p') && isfinite(R.stats.p) && numel(gNames) >= 2
        yl = ylim(ax);
        y = yl(2) - 0.08*(yl(2)-yl(1));
        p = R.stats.p;
        stars = ga_stars(p);
        text(ax,mean([1 2]),y,sprintf('%s   p = %.3g',stars,p), ...
            'Color',fgCol,'FontName','Arial','FontSize',12,'FontWeight','bold', ...
            'HorizontalAlignment','center','VerticalAlignment','top');
    end
catch
end

try
    ga_draw_sig_bar_lower_plot(ax,R,S,fgCol,numel(gNames));
catch ME_sigbar
    try, disp(['ROI preview significance bar skipped: ' ME_sigbar.message]); catch, end
end
ga_apply_preview_grid(ax,S,fgCol);
end

function s = ga_preview_popup_string_local(h)
s = '';
try
    lst = get(h,'String');
    val = get(h,'Value');
    if iscell(lst)
        val = max(1,min(numel(lst),val));
        s = lst{val};
    else
        s = char(lst);
    end
catch
end
if isempty(s), s = 'PACAP blue'; end
end

function c = ga_preview_named_color_local(name, cDefault)
if nargin < 2 || isempty(cDefault), cDefault = [0.5 0.5 0.5]; end
c = cDefault;
if isempty(name), return; end
s = lower(strtrim(name));
switch s
    case {'pacap blue','blue'}
        c = [0.20 0.65 0.96];
    case 'orange'
        c = [0.95 0.58 0.20];
    case 'red'
        c = [0.87 0.24 0.24];
    case 'green'
        c = [0.20 0.72 0.28];
    case 'purple'
        c = [0.58 0.36 0.78];
    case 'magenta'
        c = [0.90 0.20 0.70];
    case 'cyan'
        c = [0.10 0.80 0.85];
    case 'yellow'
        c = [0.95 0.85 0.20];
    case 'teal'
        c = [0.10 0.65 0.60];
    case 'dark blue'
        c = [0.05 0.25 0.60];
    case 'dark green'
        c = [0.05 0.45 0.12];
    case 'dark red'
        c = [0.55 0.10 0.10];
    case 'gray'
        c = [0.60 0.60 0.60];
    case 'black'
        c = [0.10 0.10 0.10];
end
end

function c = ga_color_name(s,fallback)
c = fallback;
try
    s = lower(char(s));
    if ~isempty(strfind(s,'pacap')) || ~isempty(strfind(s,'blue'))
        c = [0.20 0.65 0.90];
    elseif ~isempty(strfind(s,'vehicle')) || ~isempty(strfind(s,'veh')) || ~isempty(strfind(s,'gray')) || ~isempty(strfind(s,'grey'))
        c = [0.60 0.60 0.60];
    elseif ~isempty(strfind(s,'red'))
        c = [0.90 0.25 0.25];
    elseif ~isempty(strfind(s,'green'))
        c = [0.25 0.75 0.45];
    elseif ~isempty(strfind(s,'purple'))
        c = [0.60 0.35 0.90];
    elseif ~isempty(strfind(s,'orange'))
        c = [0.95 0.55 0.20];
    elseif ~isempty(strfind(s,'black'))
        c = [0 0 0];
    end
catch
end
end

function [ok,tMin,psc] = ga_read_roi_txt(fname)
ok = false;
tMin = [];
psc = [];
fid = fopen(fname,'r');
if fid < 0, return; end
cleanupObj = onCleanup(@()fclose(fid)); %#ok<NASGU>
while true
    ln = fgetl(fid);
    if ~ischar(ln), break; end
    ln = strtrim(ln);
    if isempty(ln), continue; end
    if ln(1) == '#' || ln(1) == '%' || ln(1) == ';'
        continue;
    end
    vals = sscanf(ln,'%f');
    if numel(vals) >= 3
        tMin(end+1,1) = vals(2); %#ok<AGROW>
        psc(end+1,1) = vals(3); %#ok<AGROW>
    elseif numel(vals) == 2
        tMin(end+1,1) = vals(1); %#ok<AGROW>
        psc(end+1,1) = vals(2); %#ok<AGROW>
    end
end
ok = numel(tMin) >= 3 && numel(psc) == numel(tMin);
end

function ga_draw_optional_window(ax,S)
try
    if isfield(S,'tc_peakSearchMin0') && isfield(S,'tc_peakSearchMin1')
        x0 = double(S.tc_peakSearchMin0);
        x1 = double(S.tc_peakSearchMin1);
        if isfinite(x0) && isfinite(x1) && x1 > x0
            yl = ylim(ax);
            patch(ax,[x0 x1 x1 x0],[yl(1) yl(1) yl(2) yl(2)],[1 0.9 0.2], ...
                'FaceAlpha',0.12,'EdgeColor','none','HandleVisibility','off');
        end
    end
catch
end
end

function ga_apply_preview_x(ax,t,S)
try
    t = double(t(:));
    t = t(isfinite(t));
    if isempty(t), return; end
    xmin = min(t);
    xmax = max(t);
    if isfield(S,'plotX') && isstruct(S.plotX) && ~gaPrevField(S.plotX,'auto',true)
        x0 = gaPrevField(S.plotX,'xmin',NaN);
        x1 = gaPrevField(S.plotX,'xmax',NaN);
        if isfinite(x0), xmin = x0; end
        if isfinite(x1), xmax = x1; end
    end
    if isfinite(xmin) && isfinite(xmax) && xmax > xmin
        xlim(ax,[xmin xmax]);
    end
catch
end
end

function ga_apply_preview_grid(ax,S,fgCol)
try
    showGrid = false;
    if isfield(S,'previewShowGrid'), showGrid = logical(S.previewShowGrid); end
    if showGrid
        grid(ax,'on');
        try, set(ax,'XGrid','on','YGrid','on'); catch, end
        try, set(ax,'GridAlpha',0.22); catch, end
        try, set(ax,'MinorGridAlpha',0.10); catch, end
        try
            if all(fgCol > 0.5)
                set(ax,'GridColor',[0.70 0.70 0.70]);
            else
                set(ax,'GridColor',[0.25 0.25 0.25]);
            end
        catch
        end
    else
        grid(ax,'off');
        try, set(ax,'XGrid','off','YGrid','off'); catch, end
    end
catch
end
end

function ga_draw_injection_box_final(ax,S,fgCol,bgCol)
try
    if ~gaPrevField(S,'tc_showInjectionBox',true), return; end
    x0 = gaPrevField(S,'tc_injMin0',NaN);
    x1 = gaPrevField(S,'tc_injMin1',NaN);
    if ~isfinite(x0) || ~isfinite(x1) || x1 <= x0, return; end
    xl = xlim(ax);
    yl = ylim(ax);
    x0 = max(x0,xl(1));
    x1 = min(x1,xl(2));
    if x1 <= x0, return; end
    if all(bgCol > 0.9)
        faceCol = [0.92 0.86 0.55];
        edgeCol = [0.78 0.66 0.20];
        aVal = 0.26;
    else
        faceCol = [0.60 0.60 0.60];
        edgeCol = [0.90 0.90 0.90];
        aVal = 0.30;
    end
    h = patch(ax,[x0 x1 x1 x0],[yl(1) yl(1) yl(2) yl(2)],faceCol, ...
        'FaceAlpha',aVal,'EdgeColor',edgeCol,'LineWidth',0.8, ...
        'HandleVisibility','off','HitTest','off','Tag','GA_InjectionPatch');
    try
        ann = get(h,'Annotation');
        leg = get(ann,'LegendInformation');
        set(leg,'IconDisplayStyle','off');
    catch
    end
    try, uistack(h,'bottom'); catch, end
    text(ax,(x0+x1)/2,yl(2)-0.035*(yl(2)-yl(1)),'Injection', ...
        'Color',fgCol,'FontName','Arial','FontSize',8,'FontWeight','bold', ...
        'HorizontalAlignment','center','VerticalAlignment','top', ...
        'Clipping','on','HandleVisibility','off');
catch
end
end

function ga_auto_limits(ax)
try
    ch = get(ax,'Children');
    xx = [];
    yy = [];
    for i = 1:numel(ch)
        try
            x = get(ch(i),'XData');
            y = get(ch(i),'YData');
            xx = [xx x(:)']; %#ok<AGROW>
            yy = [yy y(:)']; %#ok<AGROW>
        catch
        end
    end
    xx = xx(isfinite(xx));
    yy = yy(isfinite(yy));
    if ~isempty(xx)
        xlim(ax,[min(xx) max(xx)]);
    end
    if ~isempty(yy)
        lo = min(yy); hi = max(yy);
        if hi <= lo, hi = lo + 1; end
        pad = 0.12*(hi-lo);
        ylim(ax,[lo-pad hi+pad]);
    end
catch
end
end

function tf = ga_bool(x)
tf = true;
try
    if islogical(x)
        tf = x;
    elseif isnumeric(x)
        tf = x ~= 0;
    else
        s = lower(strtrim(char(x)));
        tf = any(strcmp(s,{'1','true','yes','y','on'}));
    end
catch
    tf = true;
end
end

function u = ga_unique_stable(C)
u = {};
for i = 1:numel(C)
    s = strtrim(char(C{i}));
    if isempty(s), continue; end
    hit = false;
    for j = 1:numel(u)
        if strcmpi(u{j},s), hit = true; break; end
    end
    if ~hit, u{end+1,1} = s; end %#ok<AGROW>
end
end

function g = ga_sort_groups(g)
if numel(g) < 2, return; end
rank = 100 + (1:numel(g));
for i = 1:numel(g)
    s = upper(g{i});
    if ~isempty(strfind(s,'PACAP')) || ~isempty(strfind(s,'GROUPA')) || strcmp(s,'A')
        rank(i) = 1;
    elseif ~isempty(strfind(s,'VEH')) || ~isempty(strfind(s,'CONTROL')) || ~isempty(strfind(s,'GROUPB')) || strcmp(s,'B')
        rank(i) = 2;
    end
end
[~,ord] = sort(rank);
g = g(ord);
end

function d = ga_display_group_names(g)
d = g;
for i = 1:numel(g)
    s = upper(g{i});
    if ~isempty(strfind(s,'PACAP'))
        d{i} = 'PACAP';
    elseif ~isempty(strfind(s,'VEH')) || ~isempty(strfind(s,'CONTROL'))
        d{i} = 'Vehicle';
    end
end
end

function m = ga_nanmean(X,dim)
if nargin < 2, dim = 1; end
try
    m = mean(X,dim,'omitnan');
catch
    n = sum(isfinite(X),dim);
    X2 = X; X2(~isfinite(X2)) = 0;
    m = sum(X2,dim) ./ max(1,n);
    m(n==0) = NaN;
end
end

function s = ga_nanstd(X,flag,dim)
if nargin < 2, flag = 0; end
if nargin < 3, dim = 1; end
try
    s = std(X,flag,dim,'omitnan');
catch
    mu = ga_nanmean(X,dim);
    rep = ones(1,ndims(X));
    rep(dim) = size(X,dim);
    MU = repmat(mu,rep);
    D = X - MU;
    D(~isfinite(D)) = 0;
    n = sum(isfinite(X),dim);
    if flag == 0
        den = max(1,n-1);
    else
        den = max(1,n);
    end
    s = sqrt(sum(D.^2,dim)./den);
    s(n==0) = NaN;
end
end

function p = ga_welch_p(a,b)
p = NaN;
a = a(isfinite(a));
b = b(isfinite(b));
n1 = numel(a); n2 = numel(b);
if n1 < 2 || n2 < 2, return; end
m1 = mean(a); m2 = mean(b);
v1 = var(a,0); v2 = var(b,0);
den = sqrt(v1/n1 + v2/n2);
if den <= 0 || ~isfinite(den), return; end
t = (m1-m2)/den;
df = (v1/n1 + v2/n2)^2 / ((v1^2)/(n1^2*max(1,n1-1)) + (v2^2)/(n2^2*max(1,n2-1)));
df = max(1,df);
p = 2*ga_tcdf(-abs(t),df);
end

function p = ga_tcdf(x,v)
try
    p = tcdf(x,v);
    return;
catch
end
z = v ./ (v + x.^2);
ib = betainc(z,v/2,0.5);
p = zeros(size(x));
p(x >= 0) = 1 - 0.5*ib(x >= 0);
p(x < 0) = 0.5*ib(x < 0);
end

function s = ga_stars(p)
if ~isfinite(p)
    s = 'p=?';
elseif p < 0.001
    s = '***';
elseif p < 0.01
    s = '**';
elseif p < 0.05
    s = '*';
else
    s = 'n.s.';
end
end

function j = ga_jitter(k,amp)
if nargin < 2, amp = 0.16; end
j = amp * (mod(double(k)*37,100)/100 - 0.5);
end

function s = ga_join(C,sep)
s = '';
for i = 1:numel(C)
    if i > 1, s = [s sep]; end %#ok<AGROW>
    s = [s char(C{i})]; %#ok<AGROW>
end
end


function gaPrevTop(ax,R,S,styleName)
[~,fg] = gaPrevColors(styleName);
hold(ax,'on');
t = double(R.tMin(:)');
allY = [];
for g = 1:numel(R.group)
    y = double(R.group(g).mean(:)');
    e = double(R.group(g).sem(:)');
    if gaPrevField(S,'tc_previewSmooth',false)
        dtSec = median(diff(t))*60;
        y = gaPrevSmooth(y,dtSec,gaPrevField(S,'tc_previewSmoothWinSec',60));
        e = gaPrevSmooth(e,dtSec,gaPrevField(S,'tc_previewSmoothWinSec',60));
    end
    col = gaPrevGroupColor(R,R.group(g).name,g);
    if gaPrevField(S,'tc_showSEM',true) && numel(e)==numel(y)
        patch(ax,[t fliplr(t)],[y+e fliplr(y-e)],col,'FaceAlpha',gaPrevField(S,'displaySemAlpha',0.25),'EdgeColor','none','HandleVisibility','off');
    end
    plot(ax,t,y,'Color',col,'LineWidth',2.4,'DisplayName',gaPrevDisplayName(R,g));
    allY = [allY y(:)'];
end
xlabel(ax,'Time (min)','Color',fg,'FontWeight','bold');
if isfield(R,'unitsPercent') && R.unitsPercent, ylabel(ax,'% signal change','Color',fg,'FontWeight','bold'); else, ylabel(ax,'Signal','Color',fg,'FontWeight','bold'); end
title(ax,'Group ROI timecourse','Color',fg,'FontWeight','bold');
gaPrevApplyY(ax,allY,gaPrevField(S,'plotTop',struct('auto',true,'forceZero',false,'ymin',0,'ymax',1,'step',0)));
if gaPrevField(S,'tc_showInjectionBox',true)
    yl = ylim(ax);
    x0 = gaPrevField(S,'tc_injMin0',NaN); x1 = gaPrevField(S,'tc_injMin1',NaN);
    if isfinite(x0) && isfinite(x1) && x1 > x0
        hp = patch(ax,[x0 x1 x1 x0],[yl(1) yl(1) yl(2) yl(2)],[1 1 0],'FaceAlpha',0.10,'EdgeColor','none','HandleVisibility','off');
        try, uistack(hp,'bottom'); catch, end
    end
end
try, legend(ax,'Location','best','TextColor',fg,'Color','none','Box','off'); catch, end
hold(ax,'off');
end

function gaPrevBottom(ax,R,S,styleName)
[~,fg] = gaPrevColors(styleName);
hold(ax,'on');
vals = double(R.metricVals(:));
grp = R.subjTable(:,3);
gNames = R.groupNames;
allY = vals(:)';
for g = 1:numel(gNames)
    idx = strcmpi(grp,gNames{g});
    v = vals(idx); v = v(isfinite(v));
    if isempty(v), continue; end
    mu = mean(v);
    se = std(v,0)./sqrt(max(1,numel(v)));
    col = gaPrevGroupColor(R,gNames{g},g);
    bar(ax,g,mu,0.55,'FaceColor',col,'EdgeColor','none');
xj = g + linspace(-0.12,0.12,numel(v));
    scatter(ax,xj,v,55,'MarkerFaceColor',col,'MarkerEdgeColor',fg,'LineWidth',0.8);
end
set(ax,'XTick',1:numel(gNames),'XTickLabel',gaPrevDisplayNames(R));
try, xtickangle(ax,20); catch, end
ylabel(ax,gaPrevField(R,'metricName','Metric'),'Color',fg,'FontWeight','bold','Interpreter','none');
title(ax,'Per-animal ROI metric','Color',fg,'FontWeight','bold');
gaPrevApplyY(ax,allY,gaPrevField(S,'plotBot',struct('auto',true,'forceZero',false,'ymin',0,'ymax',1,'step',0)));
gaPrevStatsText(ax,R,S,styleName);
hold(ax,'off');
end

function gaPrevStatsText(ax,R,S,styleName)
[~,fg] = gaPrevColors(styleName);
if ~isfield(R,'stats') || ~isfield(R.stats,'p'), return; end
p = R.stats.p;
if ~isfinite(p), return; end
yl = ylim(ax); dy = yl(2)-yl(1); if ~isfinite(dy) || dy<=0, dy=1; end
stars = gaPrevStars(p);
x = mean(xlim(ax));
text(ax,x,yl(2)-0.06*dy,sprintf('%s   p = %.3g',stars,p),'Color',fg,'FontWeight','bold','FontSize',12,'HorizontalAlignment','center','VerticalAlignment','top');
end

function gaPrevClear(ax,styleName,showGrid)
try, cla(ax,'reset'); catch, cla(ax); end
[bg,fg] = gaPrevColors(styleName);
set(ax,'Color',bg,'XColor',fg,'YColor',fg,'FontName','Arial','FontSize',12,'Box','off');
if showGrid, grid(ax,'on'); else, grid(ax,'off'); end
end

function [bg,fg] = gaPrevColors(styleName)
if strcmpi(styleName,'Light'), bg=[1 1 1]; fg=[0 0 0]; else, bg=[0 0 0]; fg=[1 1 1]; end
end

function val = gaPrevField(S,name,fb)
val = fb;
try, if isstruct(S) && isfield(S,name) && ~isempty(S.(name)), val = S.(name); end; catch, end
end

function y2 = gaPrevSmooth(y,dtSec,winSec)
y = double(y(:)'); y2 = y;
if ~isfinite(dtSec) || dtSec<=0 || ~isfinite(winSec) || winSec<=0, return; end
w = max(1,round(winSec/dtSec));
if w <= 1, return; end
if any(~isfinite(y))
    ii = find(isfinite(y));
    if numel(ii) >= 2, y = interp1(ii,y(ii),1:numel(y),'linear','extrap'); end
end
k = ones(1,w)./w;
padL = repmat(y(1),1,floor(w/2));
padR = repmat(y(end),1,w-1-floor(w/2));
y2 = conv([padL y padR],k,'valid');
end

function col = gaPrevGroupColor(R,name,idx)
col = lines(max(2,idx)); col = col(idx,:);
try
    f = gaPrevMakeField(name);
    if isfield(R,'groupColors') && isfield(R.groupColors,f), col = R.groupColors.(f); end
catch
end
end

function f = gaPrevMakeField(s)
try, f = matlab.lang.makeValidName(char(s)); catch, f = regexprep(char(s),'[^A-Za-z0-9_]','_'); end
if isempty(f), f = 'Group'; end
end

function names = gaPrevDisplayNames(R)
if isfield(R,'groupDisplayNames') && numel(R.groupDisplayNames)==numel(R.groupNames)
    names = R.groupDisplayNames;
else
    names = R.groupNames;
end
end

function s = gaPrevDisplayName(R,g)
names = gaPrevDisplayNames(R);
try, s = names{g}; catch, s = R.group(g).name; end
end

function gaPrevApplyY(ax,dataVec,cfg)
dataVec = dataVec(isfinite(dataVec));
if isempty(dataVec), dataVec = 0; end
auto = gaPrevField(cfg,'auto',true);
forceZero = gaPrevField(cfg,'forceZero',false);
if auto
    lo = min(dataVec);
    hi = max(dataVec);
    if lo == hi, lo = lo - 1; hi = hi + 1; end
    pad = 0.08*(hi-lo);
    lo = lo - pad;
    hi = hi + pad;
    if forceZero, lo = 0; end
else
    lo = gaPrevField(cfg,'ymin',min(dataVec));
    hi = gaPrevField(cfg,'ymax',max(dataVec));
    if forceZero, lo = 0; end
end
if ~isfinite(lo), lo = min(dataVec); end
if ~isfinite(hi), hi = max(dataVec); end
if hi <= lo, hi = lo + 1; end
ylim(ax,[lo hi]);

step = gaPrevField(cfg,'step',0);
if isfinite(step) && step > 0
    yl = ylim(ax);
    t0 = ceil(yl(1)/step)*step;
    t1 = floor(yl(2)/step)*step;
    ticks = t0:step:t1;
    if isempty(ticks) || ticks(1) > yl(1)+1e-9
        ticks = [yl(1) ticks];
    end
    if ticks(end) < yl(2)-1e-9
        ticks = [ticks yl(2)];
    end
    ticks = unique(ticks);
    if numel(ticks) >= 2 && numel(ticks) < 80
        set(ax,'YTick',ticks);
    end
else
    try, set(ax,'YTickMode','auto'); catch, end
end
end

function s = gaPrevStars(p)
if p < 0.001, s='***'; elseif p < 0.01, s='**'; elseif p < 0.05, s='*'; else, s='n.s.'; end
end
% GA_ROI_PREVIEW_STANDALONE_END


function savePreviewPNGLocal(outFile, whichPlot, S)
% Save ROI preview as PNG using the same renderer as the GUI preview.

if nargin < 3 || isempty(S)
    error('Missing GroupAnalysis state.');
end

styleName = 'Dark';
try
    if isfield(S,'previewStyle') && ~isempty(S.previewStyle)
        styleName = S.previewStyle;
    end
catch
end

if strcmpi(styleName,'Light')
    figBg = [1 1 1];
else
    figBg = [0 0 0];
end

f = figure( ...
    'Visible','off', ...
    'Color',figBg, ...
    'InvertHardcopy','off', ...
    'MenuBar','none', ...
    'ToolBar','none', ...
    'NumberTitle','off');

if whichPlot == 1
    set(f,'Position',[100 100 1400 650]);
    ax = axes('Parent',f,'Units','normalized','Position',[0.09 0.16 0.86 0.74]);
else
    set(f,'Position',[100 100 950 700]);
    ax = axes('Parent',f,'Units','normalized','Position',[0.14 0.16 0.78 0.74]);
end

exportOnePreview(ax,whichPlot,S,styleName);

set(f,'PaperPositionMode','auto');
print(f, outFile, '-dpng', '-r300');
close(f);
end


function groupColors = assignGroupColorsWithMode(gNames, varargin)
% Robust group color assignment for ROI preview and exports.
% Accepts old and new call styles.

if nargin < 1 || isempty(gNames)
    groupColors = zeros(0,3);
    return;
end

if ischar(gNames)
    gNames = cellstr(gNames);
end

nG = numel(gNames);
palette = [ ...
    0.20 0.63 0.86; ... % blue / PACAP
    0.25 0.75 0.45; ... % green / Vehicle
    0.90 0.35 0.25; ... % red
    0.70 0.45 0.90; ... % purple
    0.95 0.70 0.25; ... % yellow
    0.20 0.75 0.75];    % cyan

groupColors = zeros(nG,3);
for i = 1:nG
    groupColors(i,:) = palette(1+mod(i-1,size(palette,1)),:);
end

S = struct();
for q = 1:numel(varargin)
    if isstruct(varargin{q})
        S = varargin{q};
    end
end

aGroup = gaText_cleanfix(gaFieldAny_cleanfix(S,{'tc_groupA','groupA','groupAName','plotGroupA','roiGroupA','selectedGroupA','selectedA','previewGroupA','statGroupA','metricGroupA','group1'}));
bGroup = gaText_cleanfix(gaFieldAny_cleanfix(S,{'tc_groupB','groupB','groupBName','plotGroupB','roiGroupB','selectedGroupB','selectedB','previewGroupB','statGroupB','metricGroupB','group2'}));
aColTxt = gaFieldAny_cleanfix(S,{'tc_colorA','tcColorA','colorA','groupColorA','plotColorA','lineColorA','roiColorA','groupAColor','colorNameA','lineColorAName'});
bColTxt = gaFieldAny_cleanfix(S,{'tc_colorB','tcColorB','colorB','groupColorB','plotColorB','lineColorB','roiColorB','groupBColor','colorNameB','lineColorBName'});

% Also support direct call style: assignGroupColorsWithMode(gNames,A,B,colorA,colorB)
colorCandidates = {};
for q = 1:numel(varargin)
    v = varargin{q};
    if isstruct(v)
        continue;
    end
    s = gaText_cleanfix(v);
    if isempty(s)
        if isnumeric(v) && numel(v)==3
            colorCandidates{end+1} = v;
        end
        continue;
    end

    isGroupName = false;
    for gg = 1:nG
        if strcmpi(s,gaText_cleanfix(gNames{gg}))
            isGroupName = true;
            break;
        end
    end

    if isGroupName && isempty(aGroup)
        aGroup = s;
    elseif isGroupName && isempty(bGroup) && ~strcmpi(s,aGroup)
        bGroup = s;
    else
        cTry = gaColor_cleanfix(v);
        if ~any(isnan(cTry))
            colorCandidates{end+1} = v;
        end
    end
end

if isempty(aGroup) && nG >= 1, aGroup = gaText_cleanfix(gNames{1}); end
if isempty(bGroup) && nG >= 2, bGroup = gaText_cleanfix(gNames{2}); end

aRGB = gaColor_cleanfix(aColTxt);
bRGB = gaColor_cleanfix(bColTxt);

if any(isnan(aRGB)) && numel(colorCandidates) >= 1
    aRGB = gaColor_cleanfix(colorCandidates{1});
end
if any(isnan(bRGB)) && numel(colorCandidates) >= 2
    bRGB = gaColor_cleanfix(colorCandidates{2});
end

if any(isnan(aRGB)), aRGB = gaColor_cleanfix(aGroup); end
if any(isnan(bRGB)), bRGB = gaColor_cleanfix(bGroup); end

if any(isnan(aRGB)), aRGB = palette(1,:); end
if any(isnan(bRGB)), bRGB = palette(2,:); end

for i = 1:nG
    gi = gaText_cleanfix(gNames{i});
    if ~isempty(aGroup) && strcmpi(gi,aGroup)
        groupColors(i,:) = aRGB;
    elseif ~isempty(bGroup) && strcmpi(gi,bGroup)
        groupColors(i,:) = bRGB;
    else
        guess = gaColor_cleanfix(gi);
        if ~any(isnan(guess))
            groupColors(i,:) = guess;
        end
    end
end

groupColors = max(0,min(1,groupColors));
end

function v = gaFieldAny_cleanfix(S, fields)
v = [];
if ~isstruct(S), return; end
for k = 1:numel(fields)
    f = fields{k};
    if isfield(S,f) && ~isempty(S.(f))
        v = S.(f);
        if iscell(v) && ~isempty(v)
            v = v{1};
        end
        return;
    end
end
end

function s = gaText_cleanfix(v)
s = '';
if isempty(v), return; end
if iscell(v) && ~isempty(v), v = v{1}; end
if isnumeric(v), return; end
try
    s = strtrim(char(v));
catch
    s = '';
end
end

function rgb = gaColor_cleanfix(v)
rgb = [NaN NaN NaN];
if isempty(v), return; end

if isnumeric(v) && numel(v) == 3
    rgb = double(v(:)');
    if max(rgb) > 1, rgb = rgb ./ 255; end
    return;
end

s = lower(gaText_cleanfix(v));
if isempty(s), return; end
s = strrep(s,'_',' ');
s = strrep(s,'-',' ');
s = strtrim(s);

if ~isempty(strfind(s,'pacap')) || ~isempty(strfind(s,'blue')) || strcmp(s,'conda') || strcmp(s,'condition a') || strcmp(s,'a')
    rgb = [0.20 0.63 0.86]; return;
end
if ~isempty(strfind(s,'vehicle')) || ~isempty(strfind(s,'green')) || strcmp(s,'condb') || strcmp(s,'condition b') || strcmp(s,'b')
    rgb = [0.25 0.75 0.45]; return;
end
if ~isempty(strfind(s,'red')) || ~isempty(strfind(s,'orange')) || ~isempty(strfind(s,'salmon'))
    rgb = [0.90 0.35 0.25]; return;
end
if ~isempty(strfind(s,'purple')) || ~isempty(strfind(s,'violet'))
    rgb = [0.70 0.45 0.90]; return;
end
if ~isempty(strfind(s,'yellow')) || ~isempty(strfind(s,'gold'))
    rgb = [0.95 0.70 0.25]; return;
end
if ~isempty(strfind(s,'cyan')) || ~isempty(strfind(s,'turquoise'))
    rgb = [0.20 0.75 0.75]; return;
end
if ~isempty(strfind(s,'black'))
    rgb = [0 0 0]; return;
end
if ~isempty(strfind(s,'white'))
    rgb = [1 1 1]; return;
end
if ~isempty(strfind(s,'gray')) || ~isempty(strfind(s,'grey'))
    rgb = [0.5 0.5 0.5]; return;
end
end


function gaApplyROIPreviewAxisCleanfix(hFig,R)
% Applies final visual cleanup to ROI preview axes.
if nargin < 1 || isempty(hFig) || ~ishandle(hFig)
    try
        hFig = gcf;
    catch
        return;
    end
end
if nargin < 2
    R = [];
end

axs = findall(hFig,'Type','axes');
for k = 1:numel(axs)
    ax = axs(k);
    ttl = lower(gaGetAxesTitleCleanfix(ax));

    if ~isempty(strfind(ttl,'group roi timecourse'))
        gaFixOneROIAxisCleanfix(ax,true,R);
    elseif ~isempty(strfind(ttl,'per-animal roi metric'))
        gaFixOneROIAxisCleanfix(ax,false,R);
    end
end
end

function gaFixOneROIAxisCleanfix(ax,isTop,R)
if isempty(ax) || ~ishandle(ax), return; end

bg = get(ax,'Color');
if ischar(bg)
    try
        bg = get(ancestor(ax,'figure'),'Color');
    catch
        bg = [1 1 1];
    end
end
if ischar(bg) || isempty(bg) || numel(bg) ~= 3
    bg = [1 1 1];
end
bg = double(bg(:)');

if mean(bg) > 0.5
    fg = [0 0 0];
else
    fg = [1 1 1];
end

try
    set(ax,'XColor',fg,'YColor',fg,'FontName','Arial','FontSize',10,'LineWidth',1.1,'Box','off');
end

try, set(get(ax,'Title'), 'Color',fg,'FontName','Arial','FontWeight','bold'); end
try, set(get(ax,'XLabel'),'Color',fg,'FontName','Arial','FontWeight','bold'); end
try, set(get(ax,'YLabel'),'Color',fg,'FontName','Arial','FontWeight','bold'); end

try
    txt = findall(ax,'Type','text');
    for t = 1:numel(txt)
        set(txt(t),'Color',fg,'FontName','Arial');
    end
end

try
    hFig = ancestor(ax,'figure');
    legs = findall(hFig,'Type','legend');
    for l = 1:numel(legs)
        try, set(legs(l),'TextColor',fg); end
        try, set(legs(l),'Color',bg); end
    end
end

if isTop
    x = gaCollectTimeFromRCleanfix(R);
    if isempty(x)
        x = gaCollectAxisDataCleanfix(ax,'XData');
    end
    x = x(isfinite(x));
    if numel(x) >= 2
        xmin = min(x(:));
        xmax = max(x(:));
        if xmax > xmin
            xlim(ax,[xmin xmax]);
        end
    end

    y = gaCollectAxisDataCleanfix(ax,'YData');
    y = y(isfinite(y));
    if ~isempty(y)
        lo = min(y(:));
        hi = max(y(:));
        if hi <= lo, hi = lo + 1; end
        pad = 0.10 * (hi-lo);
        ylim(ax,[lo-pad hi+pad]);
    end

    try, xlabel(ax,'Time (min)'); end
    try, ylabel(ax,'PSC (%)'); end
else
    y = gaCollectAxisDataCleanfix(ax,'YData');
    y = y(isfinite(y));
    if ~isempty(y)
        lo = min([0; y(:)]);
        hi = max([0; y(:)]);
        if hi <= lo, hi = lo + 1; end
        pad = 0.20 * (hi-lo);
        ylim(ax,[lo-pad hi+pad]);
        yl = ylim(ax);
        set(ax,'YTick',linspace(yl(1),yl(2),5));
    end

    x = gaCollectAxisDataCleanfix(ax,'XData');
    x = x(isfinite(x));
    if ~isempty(x)
        xmin = min(x(:));
        xmax = max(x(:));
        if xmax > xmin
            xlim(ax,[xmin-0.75 xmax+0.75]);
        end
    end

    try, ylabel(ax,'PSC (%)'); end
end
end

function ttl = gaGetAxesTitleCleanfix(ax)
ttl = '';
try
    h = get(ax,'Title');
    s = get(h,'String');
    if iscell(s)
        tmp = '';
        for i = 1:numel(s)
            tmp = [tmp ' ' char(s{i})];
        end
        s = tmp;
    end
    ttl = char(s);
catch
    ttl = '';
end
end

function vals = gaCollectAxisDataCleanfix(ax,propName)
vals = [];
try
    hs = findall(ax,'-property',propName);
catch
    return;
end

for i = 1:numel(hs)
    try
        d = get(hs(i),propName);
    catch
        continue;
    end

    if iscell(d)
        for j = 1:numel(d)
            if isnumeric(d{j})
                vals = [vals; double(d{j}(:))];
            end
        end
    elseif isnumeric(d)
        vals = [vals; double(d(:))];
    end
end
end

function x = gaCollectTimeFromRCleanfix(R)
x = [];
if ~isstruct(R), return; end

fields = {'tMin','timeMin','time_min','timeAxis','time','t','commonTimeMin','commonTime','plotTimeMin'};
for k = 1:numel(fields)
    f = fields{k};
    if isfield(R,f) && isnumeric(R.(f)) && numel(R.(f)) >= 2
        tmp = double(R.(f)(:));
        tmp = tmp(isfinite(tmp));
        if numel(tmp) >= 2
            x = tmp;
            return;
        end
    end
end
end


function [lineW, shadeA, colA, colB, showLabels] = ga_preview_style_from_gui(figH)
lineW = 2.8;
shadeA = 0.22;
colA = [0.20 0.65 0.90];
colB = [0.60 0.60 0.60];
showLabels = false;

if isempty(figH) || ~ishandle(figH)
    return;
end

% Line width slider
try
    h = findall(figH,'Tag','GA_RPV_LINE_WIDTH');
    if ~isempty(h)
        v = get(h(1),'Value');
        if isfinite(v), lineW = v; end
    end
catch
end

% Shade alpha slider
try
    h = findall(figH,'Tag','GA_RPV_SHADE_ALPHA');
    if ~isempty(h)
        v = get(h(1),'Value');
        if isfinite(v), shadeA = v; end
    end
catch
end

% A color popup
try
    h = findall(figH,'Tag','GA_RPV_COLOR_A');
    if ~isempty(h)
        items = get(h(1),'String');
        if ischar(items), items = cellstr(items); end
        v = get(h(1),'Value');
        v = max(1,min(numel(items),round(v)));
        s = lower(char(items{v}));
        if ~isempty(strfind(s,'vehicle')) || ~isempty(strfind(s,'gray')) || ~isempty(strfind(s,'grey'))
            colA = [0.60 0.60 0.60];
        elseif ~isempty(strfind(s,'dark blue'))
            colA = [0.05 0.25 0.65];
        elseif ~isempty(strfind(s,'dark green'))
            colA = [0.00 0.35 0.20];
        elseif ~isempty(strfind(s,'dark red'))
            colA = [0.55 0.05 0.05];
        elseif ~isempty(strfind(s,'teal'))
            colA = [0.10 0.70 0.65];
        elseif ~isempty(strfind(s,'purple'))
            colA = [0.60 0.35 0.90];
        elseif ~isempty(strfind(s,'orange'))
            colA = [0.95 0.55 0.20];
        elseif ~isempty(strfind(s,'red'))
            colA = [0.90 0.25 0.25];
        elseif ~isempty(strfind(s,'green'))
            colA = [0.25 0.75 0.45];
        elseif ~isempty(strfind(s,'cyan'))
            colA = [0.20 0.85 0.85];
        elseif ~isempty(strfind(s,'magenta'))
            colA = [0.90 0.35 0.80];
        elseif ~isempty(strfind(s,'yellow'))
            colA = [0.95 0.85 0.20];
        elseif ~isempty(strfind(s,'black'))
            colA = [0 0 0];
        else
            colA = [0.20 0.65 0.90];
        end
    end
catch
end

% B color popup
try
    h = findall(figH,'Tag','GA_RPV_COLOR_B');
    if ~isempty(h)
        items = get(h(1),'String');
        if ischar(items), items = cellstr(items); end
        v = get(h(1),'Value');
        v = max(1,min(numel(items),round(v)));
        s = lower(char(items{v}));
        if ~isempty(strfind(s,'vehicle')) || ~isempty(strfind(s,'gray')) || ~isempty(strfind(s,'grey'))
            colB = [0.60 0.60 0.60];
        elseif ~isempty(strfind(s,'dark blue'))
            colB = [0.05 0.25 0.65];
        elseif ~isempty(strfind(s,'dark green'))
            colB = [0.00 0.35 0.20];
        elseif ~isempty(strfind(s,'dark red'))
            colB = [0.55 0.05 0.05];
        elseif ~isempty(strfind(s,'teal'))
            colB = [0.10 0.70 0.65];
        elseif ~isempty(strfind(s,'purple'))
            colB = [0.60 0.35 0.90];
        elseif ~isempty(strfind(s,'orange'))
            colB = [0.95 0.55 0.20];
        elseif ~isempty(strfind(s,'red'))
            colB = [0.90 0.25 0.25];
        elseif ~isempty(strfind(s,'green'))
            colB = [0.25 0.75 0.45];
        elseif ~isempty(strfind(s,'cyan'))
            colB = [0.20 0.85 0.85];
        elseif ~isempty(strfind(s,'magenta'))
            colB = [0.90 0.35 0.80];
        elseif ~isempty(strfind(s,'yellow'))
            colB = [0.95 0.85 0.20];
        elseif ~isempty(strfind(s,'black'))
            colB = [0 0 0];
        else
            colB = [0.60 0.60 0.60];
        end
    end
catch
end

% Animal labels checkbox
try
    h = findall(figH,'Tag','GA_RPV_ANIMAL_LABELS');
    if ~isempty(h)
        showLabels = logical(get(h(1),'Value'));
    end
catch
end

lineW = max(0.5,min(9,lineW));
shadeA = max(0,min(0.75,shadeA));
end


function GA_exportGroupAnalysisPPTBundleFix_20260511(hFig, makePPT)
% Compatibility wrapper for older Group Maps Export Data SCM / PPT callbacks.
% Keeps old button callbacks working after the exporter was renamed.
if nargin < 2 || isempty(makePPT), makePPT = false; end
GA_exportGroupMeanSCMBundle_Interactive(hFig, makePPT);
end

function GA_exportGroupMeanSCMBundle_Interactive(hFig, makePPT)
% Export Group Maps result either as an SCM-compatible MAT bundle or as PPT.
if nargin < 2 || isempty(makePPT), makePPT = false; end
if nargin < 1 || isempty(hFig) || ~ishghandle(hFig)
    try, hFig = gcf; catch, hFig = []; end
end
if isempty(hFig) || ~ishghandle(hFig)
    error('Invalid GroupAnalysis figure handle.');
end
S = guidata(hFig);
if isempty(S) || ~isstruct(S)
    error('Could not read GroupAnalysis GUI state.');
end
[D,G] = GA_export_get_map_bundle_local(S);
startDir = pwd;
try
    if isfield(S,'outDir') && ~isempty(S.outDir) && exist(S.outDir,'dir') == 7
        startDir = S.outDir;
    elseif isfield(S,'opt') && isfield(S.opt,'startDir') && ~isempty(S.opt.startDir) && exist(S.opt.startDir,'dir') == 7
        startDir = S.opt.startDir;
    end
catch
end
if makePPT
    defName = ['GA_GroupMap_PPT_' datestr(now,'yyyymmdd_HHMMSS') '.pptx'];
    [f,p] = uiputfile({'*.pptx','PowerPoint (*.pptx)'}, 'Save Group Map PPT', fullfile(startDir,defName));
    if isequal(f,0), return; end
    outFile = fullfile(p,f);
    [~,baseName] = fileparts(outFile);
    pngFile = fullfile(p,[baseName '_preview.png']);
    matFile = fullfile(p,[baseName '_SCM_bundle.mat']);
    GA_export_capture_map_png_local(S,pngFile,D);
    GA = G; %#ok<NASGU>
    save(matFile,'G','GA','D','-v7.3');
    GA_export_write_ppt_local(outFile,pngFile,G,D);
    fprintf('[saved PPT] %s\n', outFile);
    fprintf('[saved preview PNG] %s\n', pngFile);
    fprintf('[saved SCM bundle] %s\n', matFile);
else
    defName = ['GA_GroupMean_SCMBundle_' datestr(now,'yyyymmdd_HHMMSS') '.mat'];
    [f,p] = uiputfile({'*.mat','MAT-file (*.mat)'}, 'Save SCM-compatible Group Map Bundle', fullfile(startDir,defName));
    if isequal(f,0), return; end
    outFile = fullfile(p,f);
    GA = G;
    underlay2D = G.underlay2D;
    brainImage = G.brainImage;
    overlay2D = G.overlay2D;
    groupMap2D = G.groupMap2D;
    scmMapAtlas = G.scmMapAtlas;
    commonUnderlay = G.commonUnderlay;
    render = G.render;
    created = G.created;
    save(outFile,'G','GA','underlay2D','brainImage','overlay2D','groupMap2D','scmMapAtlas','commonUnderlay','render','created','-v7.3');
    fprintf('[saved SCM bundle] %s\n', outFile);
end
end

function [D,G] = GA_export_get_map_bundle_local(S)
M = [];
U = [];
R = struct();
hasLastMAP = false;
try
    hasLastMAP = isfield(S,'lastMAP') && isstruct(S.lastMAP) && ~isempty(fieldnames(S.lastMAP)) && isfield(S.lastMAP,'groupMap') && ~isempty(S.lastMAP.groupMap);
catch
    hasLastMAP = false;
end
if hasLastMAP
    R = S.lastMAP;
    M = double(R.groupMap);
    if isfield(R,'commonUnderlay') && ~isempty(R.commonUnderlay)
        U = R.commonUnderlay;
    end
elseif isfield(S,'lastMapDisplay') && isstruct(S.lastMapDisplay) && isfield(S.lastMapDisplay,'map') && ~isempty(S.lastMapDisplay.map)
    M = double(S.lastMapDisplay.map);
    if isfield(S.lastMapDisplay,'underlay')
        U = S.lastMapDisplay.underlay;
    end
else
    error('No group map is available. Click "Compute Group Maps" or "Preview Only" first.');
end
if ndims(M) > 2, M = squeeze(M); end
if ndims(M) > 2, M = M(:,:,1); end
M(~isfinite(M)) = 0;
if isempty(U), U = zeros(size(M)); end
U = GA_export_resize2d_local(U,size(M));
D = struct();
D.map = M;
D.underlay = U;
D.title = 'Group mean map';
try
    if hasLastMAP && isfield(R,'n'), D.title = sprintf('Group mean map (n=%d)',R.n); end
catch
end
D.render = struct();
D.render.caxis = [0 100];
D.render.modMin = 10;
D.render.modMax = 20;
D.render.threshold = 0;
D.render.colormapName = 'blackbdy_iso';
D.render.polarity = 'Positive only';
try, if isfield(S,'mapCaxis'), D.render.caxis = S.mapCaxis; end, catch, end
try, if isfield(S,'mapModMin'), D.render.modMin = S.mapModMin; end, catch, end
try, if isfield(S,'mapModMax'), D.render.modMax = S.mapModMax; end, catch, end
try, if isfield(S,'mapThreshold'), D.render.threshold = S.mapThreshold; end, catch, end
try, if isfield(S,'mapColormap'), D.render.colormapName = S.mapColormap; end, catch, end
try, if isfield(S,'mapPolarity'), D.render.polarity = S.mapPolarity; end, catch, end
G = struct();
G.created = datestr(now);
G.source = 'GroupAnalysis group mean SCM bundle';
G.isGroupMean = true;
G.note = 'Exported from GroupAnalysis Group Maps tab; compatible with SCM/Video loaders.';
G.scmMapAtlas = M;
G.mapAtlas = M;
G.pscMapAtlas = M;
G.groupMap2D = M;
G.overlay2D = M;
G.map = M;
G.underlay2D = U;
G.underlayAtlas2D = U;
G.commonUnderlay = U;
G.brainImage = U;
G.bg = U;
G.TR = 1;
G.tMin = 0;
G.atlasSliceIndex = 1;
try, if isfield(S,'mapCurrentSlice') && isfinite(S.mapCurrentSlice), G.atlasSliceIndex = round(S.mapCurrentSlice); end, catch, end
try, if isfield(S,'mapCurrentSlice') && isfinite(S.mapCurrentSlice), G.currentSlice = round(S.mapCurrentSlice); end, catch, end
try, if isfield(S,'mapCurrentSliceMax') && isfinite(S.mapCurrentSliceMax), G.nSlices = round(S.mapCurrentSliceMax); end, catch, end
G.pscAtlas4D = reshape(M,[size(M,1) size(M,2) 1 1]);
G.functional4D = reshape(U(:,:,1),[size(U,1) size(U,2) 1 1]);
G.render = D.render;
try, if hasLastMAP && isfield(R,'n'), G.n = R.n; end, catch, end
try, if hasLastMAP && isfield(R,'subjects'), G.subjects = R.subjects; end, catch, end
try, if hasLastMAP && isfield(R,'maps'), G.subjectMaps = R.maps; end, catch, end
end

function GA_export_capture_map_png_local(S,pngFile,D)
ok = false;
try
    if isfield(S,'axMap1') && ishghandle(S.axMap1)
        fr = getframe(S.axMap1);
        imwrite(fr.cdata,pngFile);
        ok = true;
    end
catch
    ok = false;
end
if ~ok
    GA_export_make_preview_png_local(pngFile,D);
end
end

function GA_export_make_preview_png_local(pngFile,D)
f = figure('Visible','off','Color',[0 0 0],'InvertHardcopy','off','MenuBar','none','ToolBar','none','NumberTitle','off');
set(f,'Position',[100 100 1100 800]);
ax = axes('Parent',f,'Units','normalized','Position',[0.06 0.08 0.84 0.84]);
U = D.underlay;
M = D.map;
if ndims(U) == 3 && size(U,3) == 3
    image(ax,min(max(double(U),0),1));
else
    image(ax,repmat(GA_export_mat2gray_local(U),[1 1 3]));
end
axis(ax,'image'); axis(ax,'off'); hold(ax,'on');
h = imagesc(ax,M);
cax = [0 100];
try, cax = D.render.caxis; catch, end
modMin = cax(1); modMax = cax(2);
try, modMin = D.render.modMin; modMax = D.render.modMax; catch, end
A = abs(M);
if modMax <= modMin, modMax = modMin + eps; end
alp = (A - modMin) ./ (modMax - modMin);
alp = min(max(alp,0),1);
alp(~isfinite(M)) = 0;
set(h,'AlphaData',GA_alphaModFixFromCData_20260504(h,alp)); try, set(h,'AlphaDataMapping','none'); catch, end
try, caxis(ax,cax); catch, end
try, colormap(ax,hot(256)); catch, end
try, colorbar(ax,'Color',[1 1 1]); catch, end
try, title(ax,D.title,'Color',[1 1 1],'FontWeight','bold','Interpreter','none'); catch, end
set(f,'PaperPositionMode','auto');
print(f,pngFile,'-dpng','-r300');
close(f);
end

function GA_export_write_ppt_local(outFile,pngFile,G,D)
% GA_export_write_ppt_local
% Robust SCM-style PPT writer for GroupAnalysis.
% Primary path: mlreportgen.ppt, same safe style as SCM_gui.
% Fallback path: ActiveX using invoke(), not pres.Slides.Add().

    if nargin < 1 || isempty(outFile)
        error('No output PPTX file was provided.');
    end
    if nargin < 2 || isempty(pngFile) || exist(pngFile,'file') ~= 2
        error('Slide PNG not found: %s', pngFile);
    end

    outDir = fileparts(outFile);
    if ~isempty(outDir) && exist(outDir,'dir') ~= 7
        mkdir(outDir);
    end

    if exist(outFile,'file') == 2
        try
            delete(outFile);
        catch
            error('Could not overwrite existing PPTX file: %s', outFile);
        end
    end

    % ---------------------------------------------------------
    % Preferred method: MATLAB Report Generator PPT API.
    % This is the same stable style used in SCM_gui.
    % ---------------------------------------------------------
    if ~isempty(which('mlreportgen.ppt.Presentation'))
        try
            import mlreportgen.ppt.*
            ppt = Presentation(outFile);
            open(ppt);

            try
                slide = add(ppt,'Blank');
            catch
                slide = add(ppt);
            end

            pic = Picture(pngFile);
            pic.X = '0in';
            pic.Y = '0in';
            pic.Width = '13.333in';
            pic.Height = '7.5in';
            add(slide,pic);

            close(ppt);
            pause(0.25);

            if exist(outFile,'file') ~= 2
                error('PPTX file was not created.');
            end
            dd = dir(outFile);
            if isempty(dd) || dd.bytes <= 0
                error('PPTX file exists but is empty.');
            end
            return;
        catch MEppt
            warning('GroupAnalysis PPT export via mlreportgen failed, trying ActiveX fallback: %s', MEppt.message);
        end
    end

    % ---------------------------------------------------------
    % Fallback method: PowerPoint COM / ActiveX.
    % Important: use invoke(...,'Add',...) instead of .Add().
    % ---------------------------------------------------------
    pptApp = [];
    pres = [];
    try
        pptApp = actxserver('PowerPoint.Application');
        pptApp.Visible = 1;

        pres = invoke(pptApp.Presentations,'Add');
        slide = invoke(pres.Slides,'Add',1,12);  % 12 = ppLayoutBlank

        slideW = pres.PageSetup.SlideWidth;
        slideH = pres.PageSetup.SlideHeight;

        invoke(slide.Shapes,'AddPicture',pngFile,0,1,0,0,slideW,slideH);

        invoke(pres,'SaveAs',outFile);
        invoke(pres,'Close');
        invoke(pptApp,'Quit');

        pause(0.25);
        if exist(outFile,'file') ~= 2
            error('PPTX file was not created by ActiveX.');
        end
    catch MEax
        try, if ~isempty(pres), invoke(pres,'Close'); end, catch, end
        try, if ~isempty(pptApp), invoke(pptApp,'Quit'); end, catch, end
        error('PowerPoint export failed: %s', MEax.message);
    end
end
function B = GA_export_resize2d_local(A,sz)
if numel(sz) > 2, sz = sz(1:2); end
A = double(A);
if ndims(A) == 3 && size(A,3) == 3
    B = zeros(sz(1),sz(2),3);
    for c = 1:3
        B(:,:,c) = GA_export_resize2d_local(A(:,:,c),sz);
    end
    mx = max(B(:));
    if isfinite(mx) && mx > 1, B = B ./ 255; end
    B = min(max(B,0),1);
    return;
end
if ndims(A) > 2
    A = squeeze(A);
    if ndims(A) > 2, A = A(:,:,1); end
end
if isequal(size(A),sz)
    B = A;
    return;
end
try
    B = imresize(A,sz,'bilinear');
catch
    [Y,X] = size(A);
    [xq,yq] = meshgrid(linspace(1,X,sz(2)),linspace(1,Y,sz(1)));
    B = interp2(double(A),xq,yq,'linear',0);
end
end

function G = GA_export_mat2gray_local(A)
A = double(A);
if ndims(A) == 3 && size(A,3) == 3
    A = 0.2989*A(:,:,1) + 0.5870*A(:,:,2) + 0.1140*A(:,:,3);
end
A(~isfinite(A)) = 0;
mn = min(A(:));
mx = max(A(:));
if isfinite(mn) && isfinite(mx) && mx > mn
    G = (A - mn) ./ (mx - mn);
else
    G = zeros(size(A));
end
G = min(max(G,0),1);
end

function GA_scm_print_error(ME, whereTxt)
if nargin < 2 || isempty(whereTxt), whereTxt = 'GroupAnalysis export'; end
try
    fprintf(2,'\n================ GROUP ANALYSIS ERROR ================\n');
    fprintf(2,'%s\n', whereTxt);
    fprintf(2,'Message: %s\n', ME.message);
    try
        fprintf(2,'%s\n', getReport(ME,'extended','hyperlinks','on'));
    catch
        for kk = 1:numel(ME.stack)
            fprintf(2,'  %s | line %d | %s\n',ME.stack(kk).name,ME.stack(kk).line,ME.stack(kk).file);
        end
    end
    fprintf(2,'======================================================\n\n');
catch
end
end

function ga_draw_sig_bar_lower_plot(ax,R,S,fgCol,nGroups)
% Replace old lower-plot "* p=..." text with a normal bracket between group A and B.
if nargin < 5 || isempty(nGroups), nGroups = 2; end
if isempty(ax) || ~ishandle(ax) || nGroups < 2, return; end
if ~isstruct(R) || ~isfield(R,'stats') || ~isfield(R.stats,'p'), return; end
p = double(R.stats.p);
if ~isfinite(p), return; end
txts = findall(ax,'Type','text');
for ii = 1:numel(txts)
    try
        s = get(txts(ii),'String');
        if iscell(s), s = strjoin(s,' '); end
        s = strtrim(char(s));
        sl = lower(s);
        if ~isempty(strfind(sl,'p =')) || ~isempty(strfind(sl,'p=')) || strcmp(s,'*') || strcmp(s,'**') || strcmp(s,'***') || strcmpi(s,'n.s.')
            delete(txts(ii));
        end
    catch
    end
end
holdState = ishold(ax);
hold(ax,'on');
yl = ylim(ax);
dy = yl(2) - yl(1);
if ~isfinite(dy) || dy <= 0, dy = 1; end
x1 = 1;
x2 = 2;
yBar = yl(2) - 0.16*dy;
tickH = 0.035*dy;
plot(ax,[x1 x1 x2 x2],[yBar-tickH yBar yBar yBar-tickH],'-','Color',fgCol,'LineWidth',1.8,'HandleVisibility','off');
stars = ga_sig_stars_local(p);
text(ax,(x1+x2)/2,yBar+0.060*dy,stars, ...
    'Color',fgCol,'FontName','Arial','FontSize',15,'FontWeight','bold', ...
    'HorizontalAlignment','center','VerticalAlignment','middle','HandleVisibility','off');
showP = true;
try, if isfield(S,'showPText'), showP = logical(S.showPText); end, catch, end
if showP
    text(ax,(x1+x2)/2,yBar+0.028*dy,sprintf('p = %.3g',p), ...
        'Color',fgCol,'FontName','Arial','FontSize',10,'FontWeight','bold', ...
        'HorizontalAlignment','center','VerticalAlignment','middle','HandleVisibility','off');
end
if ~holdState, hold(ax,'off'); end
end

function s = ga_sig_stars_local(p)
if ~isfinite(p)
    s = 'p=?';
elseif p < 0.001
    s = '***';
elseif p < 0.01
    s = '**';
elseif p < 0.05
    s = '*';
else
    s = 'n.s.';
end
end
function G = GA_fixGroupBundleForScmOpen_local(G,D)
% Make GroupAnalysis SCM bundle readable by SCM_gui.
% SCM_gui expects G.pscAtlas4D as [Y X T] or [Y X Z T].

    if nargin < 1 || isempty(G) || ~isstruct(G)
        G = struct();
    end
    if nargin < 2
        D = struct();
    end

    X = [];

    % Preferred existing field.
    if isfield(G,'pscAtlas4D') && ~isempty(G.pscAtlas4D) && isnumeric(G.pscAtlas4D)
        X = G.pscAtlas4D;
    end

    % Other possible GroupAnalysis field names.
    if isempty(X)
        candG = {'pscGroupMeanAtlas4D','meanPSCAtlas4D','groupMeanPSCAtlas4D','groupPSCAtlas4D','PSCAtlas4D','PSC','psc','meanPSC','groupMeanPSC','scmSeriesAtlas','scmMapSignedAtlas','scmMapDisplayAtlas'};
        for ii = 1:numel(candG)
            fn = candG{ii};
            if isfield(G,fn) && ~isempty(G.(fn)) && isnumeric(G.(fn))
                X = G.(fn);
                break;
            end
        end
    end

    % Try D/appdata struct if needed.
    if isempty(X) && isstruct(D)
        candD = {'pscAtlas4D','PSCAtlas4D','PSC','psc','meanPSC','groupMeanPSC','scmMapSignedAtlas','scmMapDisplayAtlas'};
        for ii = 1:numel(candD)
            fn = candD{ii};
            if isfield(D,fn) && ~isempty(D.(fn)) && isnumeric(D.(fn))
                X = D.(fn);
                break;
            end
        end
    end

    if isempty(X)
        % Last fallback: make tiny dummy image instead of crashing save.
        X = zeros(2,2,2,'single');
    end

    X = double(squeeze(X));
    X(~isfinite(X)) = 0;

    % If first dimension looks like subjects/groups and the next two are image-like,
    % average the first dimension. This prevents [N Y X T] from reaching SCM_gui.
    if ndims(X) == 4 && size(X,1) <= 50 && size(X,2) > 16 && size(X,3) > 16
        X = squeeze(mean(X,1));
    end

    % If first dimension is group/subject in [N Y X Z T], average it.
    if ndims(X) == 5 && size(X,1) <= 50 && size(X,2) > 16 && size(X,3) > 16
        X = squeeze(mean(X,1));
    end

    % Use underlay/mask dimensions to decide whether 3rd dim is Z or T.
    nZhint = NaN;
    if isfield(G,'nZ') && ~isempty(G.nZ) && isnumeric(G.nZ) && isfinite(G.nZ)
        nZhint = double(G.nZ);
    elseif isfield(G,'underlayAtlas') && isnumeric(G.underlayAtlas) && ndims(G.underlayAtlas) == 3
        nZhint = size(G.underlayAtlas,3);
    end

    nThint = NaN;
    if isfield(G,'nT') && ~isempty(G.nT) && isnumeric(G.nT) && isfinite(G.nT)
        nThint = double(G.nT);
    elseif isfield(G,'tsec') && isnumeric(G.tsec) && numel(G.tsec) > 1
        nThint = numel(G.tsec);
    elseif isfield(G,'tmin') && isnumeric(G.tmin) && numel(G.tmin) > 1
        nThint = numel(G.tmin);
    end

    if ndims(X) == 2
        % Static 2D map -> duplicate as 2 timepoints.
        X = cat(3, X, X);
    elseif ndims(X) == 3
        % Ambiguous [Y X K]. If K looks like Z, create [Y X Z 2].
        K = size(X,3);
        if isfinite(nZhint) && nZhint > 1 && K == round(nZhint) && ~(isfinite(nThint) && K == round(nThint))
            X = cat(4, X, X);
        else
            % Keep as [Y X T].
        end
    elseif ndims(X) == 4
        % Already [Y X Z T].
    else
        % Collapse unsupported dimensions into time.
        sz = size(X);
        if numel(sz) >= 2
            X = reshape(X, sz(1), sz(2), []);
        else
            X = reshape(X, 1, 1, []);
        end
        if size(X,3) == 1
            X = cat(3,X,X);
        end
    end

    % Guarantee at least 2 timepoints for static maps.
    if ndims(X) == 3 && size(X,3) == 1
        X = cat(3,X,X);
    end
    if ndims(X) == 4 && size(X,4) == 1
        X = cat(4,X,X);
    end

    G.pscAtlas4D = single(X);

    if ndims(G.pscAtlas4D) == 3
        G.nY = size(G.pscAtlas4D,1);
        G.nX = size(G.pscAtlas4D,2);
        G.nZ = 1;
        G.nT = size(G.pscAtlas4D,3);
    else
        G.nY = size(G.pscAtlas4D,1);
        G.nX = size(G.pscAtlas4D,2);
        G.nZ = size(G.pscAtlas4D,3);
        G.nT = size(G.pscAtlas4D,4);
    end

    if ~isfield(G,'TR') || isempty(G.TR) || ~isnumeric(G.TR) || ~isscalar(G.TR) || ~isfinite(G.TR) || G.TR <= 0
        G.TR = 1;
    end
    G.tsec = (0:G.nT-1) .* double(G.TR);
    G.tmin = G.tsec ./ 60;

    if ~isfield(G,'kind') || isempty(G.kind)
        G.kind = 'SCM_GROUP_EXPORT';
    end
    G.version = '1.1_GroupAnalysis_fixed_for_SCM_gui';
end

% BEGIN_GA_SCM_TIMESERIES_EXPORT_HELPERS_V2
function GA_export_write_scm_timeseries_ppt_local(outFile,G,D,pngFile,hFig)
% Full SCM-style time-series PPT export for GroupAnalysis.
% Exports 60 s SCM windows across the complete group mean PSC series.

    if nargin < 2 || isempty(G), G = struct(); end
    if nargin < 3 || isempty(D), D = struct(); end
    if nargin < 4, pngFile = ''; end
    if nargin < 5, hFig = []; end

    outDir0 = fileparts(outFile);
    if isempty(outDir0), outDir0 = pwd; end
    if exist(outDir0,'dir') ~= 7, mkdir(outDir0); end

    % Try to find the real full time-series first.
    [X,srcName] = GA_find_best_timeseries_local(G,D,hFig);

    if isempty(X)
        error(['Could not find a full PSC time series for GroupAnalysis PPT export.' newline newline ...
               'The current export contains only one static group-map PNG. ' ...
               'The PPT exporter needs a numeric array shaped [Y X T] or [Y X Z T].']);
    end

    X = double(squeeze(X));
    X(~isfinite(X)) = 0;

    if ndims(X) == 3
        [nY,nX,nT] = size(X);
        nZ = 1;
    elseif ndims(X) == 4
        [nY,nX,nZ,nT] = size(X);
    else
        error('Time-series PSC must be [Y X T] or [Y X Z T]. Found: %s', mat2str(size(X)));
    end

    if nT < 4
        error(['Only %d time points were found in the exported group data.' newline newline ...
               'This means GroupAnalysis is still passing a static SCM map, not the full time series. ' ...
               'The full time series must be stored in the GroupAnalysis data/bundle before PPT export.'], nT);
    end

    TR = GA_get_TR_local(G,D);
    tsec = (0:nT-1) .* TR;
    totalSec = tsec(end);

    [base0,base1] = GA_get_base_window_local(G,D,totalSec);
    defMaxMin = '';
    if totalSec > 0
        defMaxMin = sprintf('%.2f', totalSec/60);
    end

    a = inputdlg({ ...
        'Injection start (sec). Empty if unknown:', ...
        'Window length (sec) (SCM default = 60):', ...
        'Max minutes to export (empty = all):', ...
        'Baseline window start-end sec:'}, ...
        'Export full Group SCM time series', 1, {'','60',defMaxMin,sprintf('%g-%g',base0,base1)});

    if isempty(a), return; end

    injSec = str2double(strtrim(a{1}));
    if ~isfinite(injSec), injSec = NaN; end

    winLen = str2double(strtrim(a{2}));
    if ~isfinite(winLen) || winLen <= 0, winLen = 60; end

    maxMin = str2double(strtrim(a{3}));
    if ~isfinite(maxMin) || maxMin <= 0, maxMin = NaN; end

    [base0,base1] = GA_parse_range_local(a{4},base0,base1);
    b0i = max(1,min(nT,round(base0/TR)+1));
    b1i = max(1,min(nT,round(base1/TR)+1));
    if b1i < b0i, tmp=b0i; b0i=b1i; b1i=tmp; end

    stamp = datestr(now,'yyyymmdd_HHMMSS');
    seriesDir = fullfile(outDir0, ['Group_SCM_timeseries_' stamp]);
    tileDir = fullfile(seriesDir,'tiles_png');
    slideDir = fullfile(seriesDir,'slide_pngs');
    if exist(seriesDir,'dir') ~= 7, mkdir(seriesDir); end
    if exist(tileDir,'dir') ~= 7, mkdir(tileDir); end
    if exist(slideDir,'dir') ~= 7, mkdir(slideDir); end

    cm = GA_get_export_cmap_local(G);
    caxV = GA_get_export_caxis_local(G,X);
    sigma = GA_get_export_sigma_local(G);
    thr = GA_get_export_threshold_local(G);
    alphaPct = GA_get_export_alpha_local(G);
    [alphaModOn,modMin,modMax] = GA_get_export_alpha_mod_local(G);
    signMode = GA_get_export_signmode_local(G);

    U = GA_get_underlay_local(G,X);
    M = GA_get_mask_local(G,nY,nX,nZ);

    starts = 0:winLen:(floor(totalSec/winLen)*winLen);
    if isempty(starts), starts = 0; end
    if isfinite(maxMin)
        starts = starts(starts < maxMin*60);
    end
    if isempty(starts), starts = 0; end

    slidePNGs = {};
    nSaved = 0;

    for zSel = 1:nZ
        if ndims(X) == 3
            Xz = X;
        else
            Xz = squeeze(X(:,:,zSel,:));
        end

        baseMap = mean(Xz(:,:,b0i:b1i),3);
        mask2 = M(:,:,min(zSel,size(M,3)));
        bg2 = GA_get_underlay_slice_local(U,zSel,nY,nX,nZ);

        tilePNG = {};
        tileLBL = {};

        for wi = 1:numel(starts)
            s0 = starts(wi);
            s1 = min(s0 + winLen, totalSec + TR);
            idx = find(tsec >= s0 & tsec < s1);
            if isempty(idx), continue; end

            sigMap = mean(Xz(:,:,idx),3);
            map = sigMap - baseMap;
            if sigma > 0, map = GA_smooth2_local(map,sigma); end
            map(~mask2) = 0;

            [dispMap,alpha] = GA_build_overlay_local(map,mask2,thr,alphaPct,alphaModOn,modMin,modMax,signMode);

            phase = '';
            if isfinite(injSec)
                if s1 <= injSec
                    phase = 'Baseline';
                elseif s0 < injSec && s1 > injSec
                    phase = 'Injection';
                else
                    piMin = floor((s0-injSec)/winLen) + 1;
                    if piMin < 1, piMin = 1; end
                    phase = sprintf('%d min PI',piMin);
                end
            end

            if isempty(phase)
                lbl = sprintf('z=%d/%d | %.0f-%.0fs',zSel,nZ,s0,s1);
            else
                lbl = sprintf('z=%d/%d | %.0f-%.0fs | %s',zSel,nZ,s0,s1,phase);
            end

            outPng = fullfile(tileDir,sprintf('GroupSCM_z%02d_w%03d_%0.0f_%0.0fs.png',zSel,wi,s0,s1));
            GA_render_scm_tile_local(outPng,bg2,dispMap,alpha,cm,caxV,lbl,200);

            if exist(outPng,'file') == 2
                tilePNG{end+1} = outPng; %#ok<AGROW>
                tileLBL{end+1} = lbl; %#ok<AGROW>
                nSaved = nSaved + 1;
            end
        end

        if isempty(tilePNG), continue; end

        perSlide = 6;
        nSlides = ceil(numel(tilePNG)/perSlide);
        for si = 1:nSlides
            i0 = (si-1)*perSlide + 1;
            i1 = min(si*perSlide,numel(tilePNG));
            idx = i0:i1;

            ttl = GA_get_export_title_local(G,srcName,zSel,nZ);
            footer = sprintf('TR=%.4g s | Base=%g-%g s | Win=%g s | Thr=%g | CAX=[%g %g] | Alpha=%g%% | AlphaMod=%d [%g..%g]', ...
                TR,base0,base1,winLen,thr,caxV(1),caxV(2),alphaPct,double(alphaModOn),modMin,modMax);

            outSlide = fullfile(slideDir,sprintf('slide_z%02d_%02d.png',zSel,si));
            GA_render_scm_montage_slide_local(outSlide,tilePNG(idx),tileLBL(idx),cm,caxV,ttl,footer,200);
            slidePNGs{end+1} = outSlide; %#ok<AGROW>
        end
    end

    if isempty(slidePNGs)
        error('No SCM time windows were rendered.');
    end

    GA_write_ppt_from_slide_pngs_local(outFile,slidePNGs);

    fprintf('\n[GroupAnalysis SCM PPT] Full time-series PPT saved:\n%s\n', outFile);
    fprintf('[GroupAnalysis SCM PPT] Tile folder:\n%s\n', tileDir);
    fprintf('[GroupAnalysis SCM PPT] Rendered %d SCM window tiles.\n\n', nSaved);
end

function [bestX,bestSrc] = GA_find_best_timeseries_local(G,D,hFig)
    bestX = [];
    bestSrc = '';
    bestScore = -Inf;

    roots = {};
    names = {};
    roots{end+1} = G; names{end+1} = 'G';
    roots{end+1} = D; names{end+1} = 'D';

    try
        if ~isempty(hFig) && ishghandle(hFig)
            GD = guidata(hFig);
            if ~isempty(GD), roots{end+1} = GD; names{end+1} = 'guidata'; end
            AD = getappdata(hFig);
            if ~isempty(AD), roots{end+1} = AD; names{end+1} = 'appdata'; end
        end
    catch
    end

    for rr = 1:numel(roots)
        scan_value(roots{rr},names{rr},0);
    end

    function scan_value(v,path,depth)
        if depth > 3, return; end

        if isnumeric(v) || islogical(v)
            [Xcand,nT,ok] = GA_normalize_timeseries_candidate_local(v);
            if ok && nT >= 4
                sc = GA_score_timeseries_candidate_local(path,Xcand,nT);
                if sc > bestScore
                    bestScore = sc;
                    bestX = Xcand;
                    bestSrc = path;
                end
            end
            return;
        end

        if isstruct(v)
            fn = fieldnames(v);
            for ii = 1:numel(fn)
                try
                    scan_value(v.(fn{ii}),[path '.' fn{ii}],depth+1);
                catch
                end
            end
            return;
        end

        if iscell(v) && numel(v) <= 50
            for ii = 1:numel(v)
                try
                    scan_value(v{ii},sprintf('%s{%d}',path,ii),depth+1);
                catch
                end
            end
        end
    end
end

function [X,nT,ok] = GA_normalize_timeseries_candidate_local(A)
    X = [];
    nT = 0;
    ok = false;

    try
        A = squeeze(double(A));
        A(~isfinite(A)) = 0;
        sz = size(A);
        nd = ndims(A);

        if nd == 3
            if sz(1) > 16 && sz(2) > 16 && sz(3) >= 4
                X = A;
                nT = sz(3);
                ok = true;
            end
            return;
        end

        if nd == 4
            % [Y X Z T]
            if sz(1) > 16 && sz(2) > 16 && sz(4) >= 4
                X = A;
                nT = sz(4);
                ok = true;
                return;
            end

            % [N Y X T] animals/groups first
            if sz(1) <= 50 && sz(2) > 16 && sz(3) > 16 && sz(4) >= 4
                X = squeeze(mean(A,1));
                nT = size(X,3);
                ok = true;
                return;
            end

            % [Y X T N] animals/groups last
            if sz(1) > 16 && sz(2) > 16 && sz(3) >= 4 && sz(4) <= 50
                X = squeeze(mean(A,4));
                nT = size(X,3);
                ok = true;
                return;
            end
        end

        if nd == 5
            % [N Y X Z T]
            if sz(1) <= 50 && sz(2) > 16 && sz(3) > 16 && sz(5) >= 4
                X = squeeze(mean(A,1));
                nT = size(X,4);
                ok = true;
                return;
            end

            % [Y X Z T N]
            if sz(1) > 16 && sz(2) > 16 && sz(4) >= 4 && sz(5) <= 50
                X = squeeze(mean(A,5));
                nT = size(X,4);
                ok = true;
                return;
            end
        end
    catch
        X = [];
        nT = 0;
        ok = false;
    end
end

function sc = GA_score_timeseries_candidate_local(path,X,nT)
    p = lower(path);
    sc = 0;
    if ~isempty(strfind(p,'psc')), sc = sc + 200; end
    if ~isempty(strfind(p,'atlas')), sc = sc + 60; end
    if ~isempty(strfind(p,'group')), sc = sc + 40; end
    if ~isempty(strfind(p,'mean')), sc = sc + 35; end
    if ~isempty(strfind(p,'series')), sc = sc + 35; end
    if ~isempty(strfind(p,'time')), sc = sc + 25; end
    if ~isempty(strfind(p,'4d')), sc = sc + 20; end
    if ~isempty(strfind(p,'map')), sc = sc - 80; end
    if ~isempty(strfind(p,'underlay')), sc = sc - 300; end
    if ~isempty(strfind(p,'mask')), sc = sc - 300; end
    if ~isempty(strfind(p,'alpha')), sc = sc - 300; end
    if ~isempty(strfind(p,'display')), sc = sc - 120; end
    if ndims(X) == 4, sc = sc + 30; end
    sc = sc + min(nT,1000)/10;
end

function TR = GA_get_TR_local(G,D)
    TR = NaN;
    try, if isfield(G,'TR') && isfinite(G.TR) && G.TR > 0, TR = double(G.TR); end, catch, end
    try, if ~isfinite(TR) && isfield(D,'TR') && isfinite(D.TR) && D.TR > 0, TR = double(D.TR); end, catch, end
    try, if ~isfinite(TR) && isfield(G,'tsec') && numel(G.tsec) > 1, TR = median(diff(double(G.tsec(:)))); end, catch, end
    if ~isfinite(TR) || TR <= 0, TR = 1; end
end

function [b0,b1] = GA_get_base_window_local(G,D,totalSec)
    b0 = 30; b1 = 240;
    try, if isfield(G,'baseWindowSec') && numel(G.baseWindowSec) >= 2, b0 = G.baseWindowSec(1); b1 = G.baseWindowSec(2); end, catch, end
    try, if isfield(G,'baseWindowStr') && ~isempty(G.baseWindowStr), [b0,b1] = GA_parse_range_local(G.baseWindowStr,b0,b1); end, catch, end
    if b0 >= totalSec || b1 > totalSec || b1 <= b0
        b0 = 0;
        b1 = max(1,min(totalSec,0.20*totalSec));
    end
end

function [a,b] = GA_parse_range_local(s,da,db)
    a = da; b = db;
    try
        s = char(s);
        s = strrep(s,char(8211),'-');
        s = strrep(s,char(8212),'-');
        s = strrep(s,',',' ');
        v = sscanf(s,'%f-%f');
        if numel(v) ~= 2, v = sscanf(s,'%f %f'); end
        if numel(v) >= 2 && all(isfinite(v(1:2)))
            a = v(1); b = v(2);
        end
    catch
    end
    if b < a, tmp=a; a=b; b=tmp; end
end

function cm = GA_get_export_cmap_local(G)
    cm = [];
    try, if isfield(G,'display') && isfield(G.display,'cmapMatrix') && size(G.display.cmapMatrix,2) == 3, cm = double(G.display.cmapMatrix); end, catch, end
    if isempty(cm)
        try
            if isfield(G,'display') && isfield(G.display,'colormapName')
                nm = lower(char(G.display.colormapName));
                if ~isempty(strfind(nm,'winter')), cm = winter(256);
                elseif ~isempty(strfind(nm,'gray')), cm = gray(256);
                elseif ~isempty(strfind(nm,'jet')), cm = jet(256);
                else, cm = hot(256); end
            end
        catch
        end
    end
    if isempty(cm), cm = hot(256); end
end

function caxV = GA_get_export_caxis_local(G,X)
    caxV = [0 100];
    try, if isfield(G,'display') && isfield(G.display,'caxis') && numel(G.display.caxis) >= 2, caxV = double(G.display.caxis(1:2)); end, catch, end
    if ~all(isfinite(caxV)) || caxV(2) <= caxV(1)
        v = abs(double(X(:))); v = v(isfinite(v));
        if isempty(v), caxV = [0 1]; else, caxV = [0 max(1,GA_prctile_local(v,99))]; end
    end
end

function sigma = GA_get_export_sigma_local(G)
    sigma = 1;
    try, if isfield(G,'sigma') && isfinite(G.sigma), sigma = double(G.sigma); end, catch, end
end

function thr = GA_get_export_threshold_local(G)
    thr = 0;
    try, if isfield(G,'display') && isfield(G.display,'threshold') && isfinite(G.display.threshold), thr = double(G.display.threshold); end, catch, end
end

function a = GA_get_export_alpha_local(G)
    a = 100;
    try, if isfield(G,'display') && isfield(G.display,'alphaPercent') && isfinite(G.display.alphaPercent), a = double(G.display.alphaPercent); end, catch, end
    a = max(0,min(100,a));
end

function [tf,lo,hi] = GA_get_export_alpha_mod_local(G)
    tf = true; lo = 10; hi = 20;
    try, if isfield(G,'display') && isfield(G.display,'alphaModOn'), tf = logical(G.display.alphaModOn); end, catch, end
    try, if isfield(G,'display') && isfield(G.display,'modMin') && isfinite(G.display.modMin), lo = double(G.display.modMin); end, catch, end
    try, if isfield(G,'display') && isfield(G.display,'modMax') && isfinite(G.display.modMax), hi = double(G.display.modMax); end, catch, end
    if hi < lo, tmp=lo; lo=hi; hi=tmp; end
end

function sm = GA_get_export_signmode_local(G)
    sm = 1;
    try, if isfield(G,'display') && isfield(G.display,'signMode') && isfinite(G.display.signMode), sm = round(double(G.display.signMode)); end, catch, end
    sm = max(1,min(3,sm));
end

function U = GA_get_underlay_local(G,X)
    U = [];
    try, if isfield(G,'underlayAtlas') && ~isempty(G.underlayAtlas), U = double(G.underlayAtlas); end, catch, end
    if isempty(U)
        if ndims(X) == 3, U = std(double(X),0,3); else, U = std(double(X),0,4); end
    end
    U = squeeze(double(U)); U(~isfinite(U)) = 0;
end

function M = GA_get_mask_local(G,nY,nX,nZ)
    M = true(nY,nX,nZ);
    try
        if isfield(G,'maskAtlas') && ~isempty(G.maskAtlas)
            M0 = logical(G.maskAtlas);
        elseif isfield(G,'mask2DCurrentSlice') && ~isempty(G.mask2DCurrentSlice)
            M0 = logical(G.mask2DCurrentSlice);
        else
            return;
        end
        if ndims(M0) == 2
            M(:,:,1) = GA_resize_mask_local(M0,nY,nX);
            for z=2:nZ, M(:,:,z) = M(:,:,1); end
        elseif ndims(M0) == 3
            for z=1:nZ
                zz = min(z,size(M0,3));
                M(:,:,z) = GA_resize_mask_local(M0(:,:,zz),nY,nX);
            end
        end
    catch
        M = true(nY,nX,nZ);
    end
end

function M2 = GA_resize_mask_local(M0,nY,nX)
    if size(M0,1) == nY && size(M0,2) == nX
        M2 = logical(M0); return;
    end
    try, M2 = imresize(double(M0),[nY nX],'nearest') > 0.5;
    catch, M2 = true(nY,nX); end
end

function bg2 = GA_get_underlay_slice_local(U,z,nY,nX,nZ)
    U = squeeze(U);
    if ndims(U) == 2
        bg2 = U;
    elseif ndims(U) == 3
        if size(U,3) == 3 && nZ == 1
            bg2 = U;
        else
            bg2 = U(:,:,min(z,size(U,3)));
        end
    elseif ndims(U) == 4
        if size(U,3) == 3
            bg2 = squeeze(U(:,:,:,min(z,size(U,4))));
        else
            tmp = mean(U,4); bg2 = tmp(:,:,min(z,size(tmp,3)));
        end
    else
        bg2 = zeros(nY,nX);
    end
    bg2 = GA_fit_image_local(bg2,nY,nX);
end

function I = GA_fit_image_local(I,nY,nX)
    I = squeeze(double(I));
    if ndims(I) == 2
        if size(I,1) ~= nY || size(I,2) ~= nX
            try, I = imresize(I,[nY nX],'bilinear'); catch, I = zeros(nY,nX); end
        end
    elseif ndims(I) == 3 && size(I,3) == 3
        if size(I,1) ~= nY || size(I,2) ~= nX
            try, I = imresize(I,[nY nX],'bilinear'); catch, I = zeros(nY,nX,3); end
        end
    else
        I = I(:,:,1);
        I = GA_fit_image_local(I,nY,nX);
    end
end

function [dispMap,alpha] = GA_build_overlay_local(rawMap,mask2,thr,alphaPct,alphaModOn,modMin,modMax,signMode)
% SCM-style overlay and alpha builder for GroupAnalysis exports.
rawMap = double(rawMap);
rawMap(~isfinite(rawMap)) = 0;

if nargin < 2 || isempty(mask2)
    mask2 = true(size(rawMap));
end
mask2 = logical(mask2);
if ~isequal(size(mask2),size(rawMap))
    try
        mask2 = imresize(double(mask2),size(rawMap),'nearest') > 0.5;
    catch
        tmp = false(size(rawMap));
        yy = min(size(tmp,1),size(mask2,1));
        xx = min(size(tmp,2),size(mask2,2));
        tmp(1:yy,1:xx) = mask2(1:yy,1:xx);
        mask2 = tmp;
    end
end

if nargin < 3 || isempty(thr) || ~isfinite(thr), thr = 0; end
if nargin < 4 || isempty(alphaPct) || ~isfinite(alphaPct), alphaPct = 100; end
if nargin < 5 || isempty(alphaModOn), alphaModOn = true; end
if nargin < 6 || isempty(modMin) || ~isfinite(modMin), modMin = 10; end
if nargin < 7 || isempty(modMax) || ~isfinite(modMax), modMax = 20; end
if nargin < 8 || isempty(signMode) || ~isfinite(signMode), signMode = 1; end

thr = abs(double(thr));
alphaPct = max(0,min(100,double(alphaPct)));
modMin = double(modMin);
modMax = double(modMax);
if modMax < modMin
    tmp = modMin; modMin = modMax; modMax = tmp;
end
if modMax <= modMin
    modMax = modMin + eps;
end

signMode = round(double(signMode));
switch signMode
    case 2
        showMask = rawMap < 0;
        dispMap = abs(min(rawMap,0));
    case 3
        showMask = rawMap ~= 0;
        dispMap = rawMap;
    otherwise
        showMask = rawMap > 0;
        dispMap = rawMap;
end

mag = abs(rawMap);
showMask = showMask & mask2 & isfinite(rawMap) & (mag >= thr);

if ~logical(alphaModOn)
    alpha = (alphaPct/100) .* double(showMask);
else
    effLo = max(modMin,thr);
    effHi = modMax;
    if effHi <= effLo, effHi = effLo + eps; end
    ramp = (mag - effLo) ./ max(eps,(effHi - effLo));
    ramp(~isfinite(ramp)) = 0;
    ramp = min(max(ramp,0),1);
    ramp(mag <= effLo) = 0;
    alpha = (alphaPct/100) .* ramp .* double(showMask);
end

alpha(~isfinite(alpha)) = 0;
alpha = min(max(alpha,0),1);
alpha(abs(rawMap) <= max(modMin,thr)) = 0;
dispMap(~isfinite(dispMap)) = 0;
dispMap(alpha <= 0) = 0;
end

function GA_render_scm_tile_local(outPng,bg2,map,alpha,cm,caxV,lbl,dpiVal)
    figT = figure('Visible','off','Color',[0 0 0],'InvertHardcopy','off','Units','pixels','Position',[80 80 1000 850]);
    ax = axes('Parent',figT,'Units','normalized','Position',[0.02 0.02 0.96 0.96]);
    axis(ax,'image'); axis(ax,'off'); set(ax,'YDir','reverse'); hold(ax,'on');
    image(ax,GA_underlay_rgb_local(bg2));
    h = imagesc(ax,map); set(h,'AlphaData',GA_alphaModFixFromCData_20260504(h,alpha)); try, set(h,'AlphaDataMapping','none'); catch, end
    colormap(ax,cm); caxis(ax,caxV);
    text(ax,0.02,0.98,lbl,'Units','normalized','Color','w','FontName','Arial','FontWeight','bold','FontSize',16, ...
        'HorizontalAlignment','left','VerticalAlignment','top','Interpreter','none','BackgroundColor',[0 0 0],'Margin',2);
    set(figT,'PaperPositionMode','auto');
    print(figT,outPng,'-dpng',sprintf('-r%d',dpiVal),'-opengl');
    close(figT);
end

function rgb = GA_underlay_rgb_local(U)
    U = squeeze(double(U));
    if ndims(U) == 3 && size(U,3) == 3
        rgb = U;
        if max(rgb(:)) > 1, rgb = rgb ./ 255; end
        rgb = min(max(rgb,0),1);
        return;
    end
    U(~isfinite(U)) = 0;
    lo = GA_prctile_local(U(:),0.5); hi = GA_prctile_local(U(:),99.5);
    if ~isfinite(lo) || ~isfinite(hi) || hi <= lo
        lo = min(U(:)); hi = max(U(:));
    end
    if hi <= lo, U01 = zeros(size(U)); else, U01 = min(max((U-lo)./(hi-lo),0),1); end
    rgb = repmat(U01,[1 1 3]);
end

function GA_render_scm_montage_slide_local(outFile,pngList,lblList,cm,caxV,titleStr,footerStr,dpiVal)
    figS = figure('Visible','off','Color',[0 0 0],'InvertHardcopy','off');
    set(figS,'Units','inches','Position',[0.5 0.5 13.333 7.5]);
    set(figS,'PaperPositionMode','auto');

    annotation(figS,'textbox',[0.02 0.89 0.96 0.09],'String',titleStr,'Color','w','EdgeColor','none', ...
        'FontName','Arial','FontSize',15,'FontWeight','bold','HorizontalAlignment','center','Interpreter','none');
    annotation(figS,'textbox',[0.25 0.01 0.73 0.06],'String',footerStr,'Color','w','EdgeColor','none', ...
        'FontName','Arial','FontSize',9,'FontWeight','bold','HorizontalAlignment','right','Interpreter','none');

    axCB = axes('Parent',figS,'Position',[0.01 0.14 0.001 0.72],'Visible','off');
    imagesc(axCB,[0 1;0 1]); colormap(axCB,cm); caxis(axCB,caxV);
    cb = colorbar(axCB,'Position',[0.018 0.14 0.015 0.72]);
    cb.Color = 'w'; cb.FontName = 'Arial'; cb.FontSize = 9;
    cb.Label.String = 'Signal change (%)'; cb.Label.Color = 'w';

    x0 = 0.085; x1 = 0.98; yBot = 0.11; yTop = 0.86;
    rowGap = 0.06; colGap = 0.02;
    cellH = (yTop-yBot-rowGap)/2;
    cellW = (x1-x0-2*colGap)/3;

    for k = 1:min(6,numel(pngList))
        if k <= 3
            cc = k-1; y = yBot + cellH + rowGap;
        else
            cc = k-4; y = yBot;
        end
        x = x0 + cc*(cellW+colGap);
        img = imread(pngList{k});
        axI = axes('Parent',figS,'Position',[x y cellW cellH]);
        image(axI,img); axis(axI,'image'); axis(axI,'off');
        annotation(figS,'textbox',[x y+cellH+0.003 cellW 0.035],'String',lblList{k},'Color','w','EdgeColor','none', ...
            'FontName','Arial','FontSize',11,'FontWeight','bold','HorizontalAlignment','center','Interpreter','none');
    end

    print(figS,outFile,'-dpng',sprintf('-r%d',dpiVal),'-opengl');
    close(figS);
end

function GA_write_ppt_from_slide_pngs_local(outFile,slidePNGs)
    if exist(outFile,'file') == 2
        try, delete(outFile); catch, error('Could not overwrite PPTX: %s',outFile); end
    end

    if ~isempty(which('mlreportgen.ppt.Presentation'))
        try
            import mlreportgen.ppt.*
            ppt = Presentation(outFile); open(ppt);
            for i=1:numel(slidePNGs)
                try, slide = add(ppt,'Blank'); catch, slide = add(ppt); end
                pic = Picture(slidePNGs{i});
                pic.X = '0in'; pic.Y = '0in'; pic.Width = '13.333in'; pic.Height = '7.5in';
                add(slide,pic);
            end
            close(ppt); pause(0.25);
            if exist(outFile,'file') == 2, return; end
        catch ME
            warning('mlreportgen PPT failed, trying ActiveX: %s',ME.message);
        end
    end

    pptApp = []; pres = [];
    try
        pptApp = actxserver('PowerPoint.Application'); pptApp.Visible = 1;
        pres = invoke(pptApp.Presentations,'Add');
        for i=1:numel(slidePNGs)
            slide = invoke(pres.Slides,'Add',i,12);
            sw = pres.PageSetup.SlideWidth; sh = pres.PageSetup.SlideHeight;
            invoke(slide.Shapes,'AddPicture',slidePNGs{i},0,1,0,0,sw,sh);
        end
        invoke(pres,'SaveAs',outFile);
        invoke(pres,'Close'); invoke(pptApp,'Quit');
    catch ME
        try, if ~isempty(pres), invoke(pres,'Close'); end, catch, end
        try, if ~isempty(pptApp), invoke(pptApp,'Quit'); end, catch, end
        error('PowerPoint export failed: %s',ME.message);
    end
end

function titleStr = GA_get_export_title_local(G,srcName,zSel,nZ)
    titleStr = 'GroupAnalysis SCM time series';
    try, if isfield(G,'fileLabel') && ~isempty(G.fileLabel), titleStr = char(G.fileLabel); end, catch, end
    if isempty(titleStr), titleStr = 'GroupAnalysis SCM time series'; end
    titleStr = sprintf('%s | z=%d/%d | source: %s',titleStr,zSel,nZ,srcName);
end

function out = GA_smooth2_local(in,sigma)
    try, out = imgaussfilt(in,sigma); return; catch, end
    if sigma <= 0, out = in; return; end
    r = max(1,ceil(3*sigma)); x = -r:r; g = exp(-(x.^2)/(2*sigma^2)); g = g/sum(g);
    out = conv2(conv2(in,g,'same'),g','same');
end

function q = GA_prctile_local(v,p)
    v = double(v(:)); v = v(isfinite(v));
    if isempty(v), q = 0; return; end
    try, q = prctile(v,p); return; catch, end
    v = sort(v); n = numel(v);
    k = 1 + (n-1)*(p/100); k1 = floor(k); k2 = ceil(k);
    k1 = max(1,min(n,k1)); k2 = max(1,min(n,k2));
    if k1 == k2, q = v(k1); else, q = v(k1) + (k-k1)*(v(k2)-v(k1)); end
end
% END_GA_SCM_TIMESERIES_EXPORT_HELPERS_V2


function [rows,bundles] = GA_collectSCMBundlesFromRows_PATCH_V4(S,cand)
rows = []; bundles = {}; seen = {};
for ii = 1:numel(cand)
    r = cand(ii);
    useRow = true;
    try, useRow = GA_toLogical_PATCH_V4(S.subj{r,1}); catch, end
    if ~useRow, continue; end
    bf = '';
    try, bf = strtrim(char(S.subj{r,8})); catch, end
    if isempty(bf) || exist(bf,'file') ~= 2, continue; end
    if ~GA_isLikelySCMBundle_PATCH_V4(bf), continue; end
    key = lower(strrep(bf,'/','\'));
    if any(strcmp(seen,key)), continue; end
    seen{end+1} = key; %#ok<AGROW>
    rows(end+1) = r; %#ok<AGROW>
    bundles{end+1} = bf; %#ok<AGROW>
end
end

function tf = GA_isLikelySCMBundle_PATCH_V4(bf)
tf = false;
try
    W = whos('-file',bf); names = {W.name};
    if any(strcmp(names,'G'))
        tf = true; return;
    end
catch
end
try
    [~,nm,~] = fileparts(bf); nm = lower(nm);
    tf = ~isempty(strfind(nm,'scm_groupexport')) || ~isempty(strfind(nm,'scm_group'));
catch
end
end

function G = GA_loadSCMBundle_PATCH_V4(bf)
L = load(bf); G = [];
if isfield(L,'G') && isstruct(L.G)
    G = L.G;
else
    fn = fieldnames(L);
    for k = 1:numel(fn)
        v = L.(fn{k});
        if isstruct(v) && (isfield(v,'pscAtlas4D') || isfield(v,'pscAtlasD') || isfield(v,'psc4D') || isfield(v,'PSC'))
            G = v; break;
        end
    end
end
if isempty(G) || ~isstruct(G), error('MAT file does not contain an SCM bundle struct G.'); end
G = GA_normalizeBundlePSC_PATCH_V4(G,bf);
end

function G = GA_normalizeBundlePSC_PATCH_V4(G,bf)
if isfield(G,'pscAtlas4D') && ~isempty(G.pscAtlas4D)
    X = G.pscAtlas4D;
else
    X = [];
    flds = {'pscAtlasD','pscAtlas3D','psc4D','PSC4D','PSC','functionalPSC','Ipsc'};
    for k = 1:numel(flds)
        f = flds{k};
        if isfield(G,f) && ~isempty(G.(f)) && isnumeric(G.(f))
            X = G.(f); break;
        end
    end
end
if isempty(X)
    error(['Could not find a full PSC time series in this bundle.' char(10) ...
           'Expected G.pscAtlas4D [Y X T] or [Y X Z T].' char(10) ...
           'File: ' bf]);
end
X = double(X);
X(~isfinite(X)) = 0;
while ndims(X) > 4
    X = squeeze(X);
end
if ndims(X) == 4 && size(X,3) == 1
    X = squeeze(X);
end
if ndims(X) == 2
    error(['This file contains only a static 2D map, not a full SCM time series.' char(10) ...
           'Open/export the individual SCM_GroupExport bundle from SCM_gui instead.' char(10) ...
           'File: ' bf]);
end
if ndims(X) == 3
    if size(X,3) < 2, error('3D PSC array has only one frame.'); end
elseif ndims(X) == 4
    if size(X,4) < 2, error('4D PSC array has only one time frame.'); end
else
    error('PSC array must be [Y X T] or [Y X Z T].');
end
G.pscAtlas4D = X;
if ~isfield(G,'TR') || isempty(G.TR) || ~isfinite(double(G.TR(1)))
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

function [TR,nT] = GA_getTRnT_PATCH_V4(G)
TR = NaN; nT = NaN;
try, TR = double(G.TR(1)); catch, end
X = G.pscAtlas4D;
if ndims(X) == 3, nT = size(X,3); elseif ndims(X) == 4, nT = size(X,4); end
if (~isfinite(TR) || TR <= 0) && isfield(G,'tsec') && numel(G.tsec) >= 2
    TR = median(diff(double(G.tsec(:))));
end
if (~isfinite(TR) || TR <= 0) && isfield(G,'tmin') && numel(G.tmin) >= 2
    TR = 60 * median(diff(double(G.tmin(:))));
end
end

function M = GA_computeSCMWindowMap_PATCH_V4(G,zSel,baseWin,sigWin,TR)
X = double(G.pscAtlas4D);
if ndims(X) == 3
    P = X;
else
    zSel = max(1,min(size(X,3),round(zSel)));
    P = squeeze(X(:,:,zSel,:));
end
T = size(P,3);
b0 = max(1,min(T,floor(baseWin(1)/TR)+1));
b1 = max(1,min(T,floor(baseWin(2)/TR)+1));
s0 = max(1,min(T,floor(sigWin(1)/TR)+1));
s1 = max(1,min(T,floor(sigWin(2)/TR)+1));
if b1 < b0, tmp=b0; b0=b1; b1=tmp; end
if s1 < s0, tmp=s0; s0=s1; s1=tmp; end
baseMap = mean(P(:,:,b0:b1),3);
sigMap  = mean(P(:,:,s0:s1),3);
M = sigMap - baseMap;
sigma = 1;
try, if isfield(G,'sigma') && ~isempty(G.sigma) && isfinite(G.sigma(1)), sigma = double(G.sigma(1)); end, catch, end
if sigma > 0, M = GA_smooth2_PATCH_V4(M,sigma); end
M(~isfinite(M)) = 0;
end

function U = GA_getUnderlayForBundle_PATCH_V4(G,zSel,sz)
U = [];
flds = {'underlayAtlas','underlay2D','underlayAtlas2D','underlayAtlas','brainImage','bg','commonUnderlay'};
for k = 1:numel(flds)
    f = flds{k};
    if isfield(G,f) && ~isempty(G.(f)) && isnumeric(G.(f))
        U = G.(f); break;
    end
end
if isempty(U), U = zeros(sz(1),sz(2)); end
U = squeeze(double(U));
if ndims(U) == 3
    if size(U,3) == 3 && ~(isfield(G,'nZ') && G.nZ == 3)
        % RGB image, keep as RGB.
    else
        zSel = max(1,min(size(U,3),round(zSel)));
        U = U(:,:,zSel);
    end
elseif ndims(U) == 4
    if size(U,3) == 3
        zSel = max(1,min(size(U,4),round(zSel)));
        U = squeeze(U(:,:,:,zSel));
    else
        zSel = max(1,min(size(U,3),round(zSel)));
        U = squeeze(U(:,:,zSel,1));
    end
end
U = GA_resizeLike_PATCH_V4(U,sz);
end

function mask2 = GA_getMaskForBundle_PATCH_V4(G,zSel,sz)
mask2 = true(sz(1),sz(2));
M = [];
if isfield(G,'maskAtlas') && ~isempty(G.maskAtlas), M = G.maskAtlas;
elseif isfield(G,'mask2DCurrentSlice') && ~isempty(G.mask2DCurrentSlice), M = G.mask2DCurrentSlice;
end
if isempty(M), return; end
M = logical(M);
if ndims(M) == 3
    zSel = max(1,min(size(M,3),round(zSel)));
    M = M(:,:,zSel);
elseif ndims(M) > 3
    M = squeeze(M);
    if ndims(M) > 2, M = M(:,:,1); end
end
mask2 = GA_resizeMask_PATCH_V4(M,sz);
try
    if isfield(G,'maskIsInclude') && ~isempty(G.maskIsInclude) && ~logical(G.maskIsInclude)
        mask2 = ~mask2;
    end
catch
end
end

function R = GA_displayStruct_PATCH_V4(S,G)
R.threshold = GA_numField_PATCH_V4(S,'mapThreshold',0);
R.caxis = GA_vecField_PATCH_V4(S,'mapCaxis',[0 100]);
R.alphaPercent = 100;
R.alphaModOn = GA_logField_PATCH_V4(S,'mapAlphaModOn',true);
R.modMin = GA_numField_PATCH_V4(S,'mapModMin',15);
R.modMax = GA_numField_PATCH_V4(S,'mapModMax',30);
R.colormapName = GA_charField_PATCH_V4(S,'mapColormap','blackbdy_iso');
R.signMode = 1;
try
    if isfield(G,'display') && isstruct(G.display)
        D = G.display;
        if isfield(D,'threshold') && ~isempty(D.threshold), R.threshold = double(D.threshold(1)); end
        if isfield(D,'caxis') && numel(D.caxis)>=2, R.caxis = double(D.caxis(1:2)); end
        if isfield(D,'alphaPercent') && ~isempty(D.alphaPercent), R.alphaPercent = double(D.alphaPercent(1)); end
        if isfield(D,'alphaModOn') && ~isempty(D.alphaModOn), R.alphaModOn = logical(D.alphaModOn(1)); end
        if isfield(D,'modMin') && ~isempty(D.modMin), R.modMin = double(D.modMin(1)); end
        if isfield(D,'modMax') && ~isempty(D.modMax), R.modMax = double(D.modMax(1)); end
        if isfield(D,'colormapName') && ~isempty(D.colormapName), R.colormapName = char(D.colormapName); end
        if isfield(D,'signMode') && ~isempty(D.signMode), R.signMode = round(double(D.signMode(1))); end
        if isfield(D,'cmapMatrix') && ~isempty(D.cmapMatrix) && size(D.cmapMatrix,2)==3, R.cmapMatrix = double(D.cmapMatrix); end
    end
catch
end
if numel(R.caxis)<2 || any(~isfinite(R.caxis(1:2))) || R.caxis(2)==R.caxis(1), R.caxis = [0 100]; end
if R.caxis(2)<R.caxis(1), R.caxis = fliplr(R.caxis); end
if R.modMax < R.modMin, tmp=R.modMin; R.modMin=R.modMax; R.modMax=tmp; end
R.signMode = max(1,min(3,R.signMode));
end

function GA_exportTile_PATCH_V4(outFile,U,M,R,titleStr)
f = figure('Visible','off','Color',[0 0 0],'InvertHardcopy','off','MenuBar','none','ToolBar','none','NumberTitle','off');
set(f,'Position',[100 100 1100 900]);
ax = axes('Parent',f,'Units','normalized','Position',[0.06 0.08 0.80 0.84]);
Urgb = GA_toRGB_PATCH_V4(U);
image(ax,Urgb); axis(ax,'image'); axis(ax,'off'); hold(ax,'on');
[dispMap,alpha] = GA_displayMapAlpha_PATCH_V4(M,R);
h = imagesc(ax,dispMap); set(h,'AlphaData',GA_alphaModFixFromCData_20260504(h,alpha)); try, set(h,'AlphaDataMapping','none'); catch, end
colormap(ax,GA_colormap_PATCH_V4(R)); caxis(ax,R.caxis);
cb = colorbar(ax);
try, cb.Color = 'w'; cb.Label.String = 'Signal change (%)'; cb.Label.Color = 'w'; cb.FontSize = 11; catch, end
title(ax,titleStr,'Color','w','FontWeight','bold','Interpreter','none');
set(f,'PaperPositionMode','auto');
print(f,outFile,'-dpng','-r200','-opengl');
close(f);
end

function [D,A] = GA_displayMapAlpha_PATCH_V4(M,R)
% SCM-style display map and alpha for GroupAnalysis preview.
M = double(M);
M(~isfinite(M)) = 0;

if nargin < 2 || isempty(R) || ~isstruct(R)
    R = struct();
end

thr = 0;
if isfield(R,'thr') && ~isempty(R.thr) && isfinite(R.thr), thr = double(R.thr(1)); end
if isfield(R,'threshold') && ~isempty(R.threshold) && isfinite(R.threshold), thr = double(R.threshold(1)); end
thr = abs(thr);

alphaPct = 100;
if isfield(R,'alpha') && ~isempty(R.alpha) && isfinite(R.alpha), alphaPct = double(R.alpha(1)); end
if isfield(R,'alphaPct') && ~isempty(R.alphaPct) && isfinite(R.alphaPct), alphaPct = double(R.alphaPct(1)); end
if isfield(R,'alphaPercent') && ~isempty(R.alphaPercent) && isfinite(R.alphaPercent), alphaPct = double(R.alphaPercent(1)); end
alphaPct = max(0,min(100,alphaPct));

alphaModOn = true;
if isfield(R,'alphaModOn') && ~isempty(R.alphaModOn), alphaModOn = logical(R.alphaModOn); end
if isfield(R,'mapAlphaModOn') && ~isempty(R.mapAlphaModOn), alphaModOn = logical(R.mapAlphaModOn); end

modMin = 10;
modMax = 20;
if isfield(R,'modMin') && ~isempty(R.modMin) && isfinite(R.modMin), modMin = double(R.modMin(1)); end
if isfield(R,'modMax') && ~isempty(R.modMax) && isfinite(R.modMax), modMax = double(R.modMax(1)); end
if modMax < modMin
    tmp = modMin; modMin = modMax; modMax = tmp;
end
if modMax <= modMin
    modMax = modMin + eps;
end

signMode = 1;
if isfield(R,'signMode') && ~isempty(R.signMode) && isfinite(R.signMode), signMode = round(double(R.signMode(1))); end

switch signMode
    case 2
        showMask = M < 0;
        D = abs(min(M,0));
    case 3
        showMask = M ~= 0;
        D = M;
    otherwise
        showMask = M > 0;
        D = M;
end

mag = abs(M);
showMask = showMask & isfinite(M) & (mag >= thr);

if ~alphaModOn
    A = (alphaPct/100) .* double(showMask);
else
    effLo = max(modMin,thr);
    effHi = modMax;
    if effHi <= effLo, effHi = effLo + eps; end
    ramp = (mag - effLo) ./ max(eps,(effHi - effLo));
    ramp(~isfinite(ramp)) = 0;
    ramp = min(max(ramp,0),1);
    ramp(mag <= effLo) = 0;
    A = (alphaPct/100) .* ramp .* double(showMask);
end

A(~isfinite(A)) = 0;
A = min(max(A,0),1);
A(abs(M) <= max(modMin,thr)) = 0;
D(~isfinite(D)) = 0;
D(A <= 0) = 0;
end

function GA_renderMontageSlide_PATCH_V4(outFile,pngList,lblList,cm,caxV,titleStr,footerStr)
figS = figure('Visible','off','Color',[0 0 0],'InvertHardcopy','off','MenuBar','none','ToolBar','none','NumberTitle','off');
set(figS,'Units','inches','Position',[0.5 0.5 13.333 7.5]);
set(figS,'PaperPositionMode','auto');
annotation(figS,'textbox',[0.02 0.89 0.96 0.10],'String',titleStr,'Color','w','EdgeColor','none','FontName','Arial','FontSize',14,'FontWeight','bold','HorizontalAlignment','center','Interpreter','none');
annotation(figS,'textbox',[0.28 0.01 0.70 0.06],'String',footerStr,'Color','w','EdgeColor','none','FontName','Arial','FontSize',9,'FontWeight','bold','HorizontalAlignment','right','Interpreter','none');
axCB = axes('Parent',figS,'Position',[0.012 0.14 0.001 0.74],'Visible','off','XTick',[],'YTick',[],'XColor','none','YColor','none','Box','off');
imagesc(axCB,[0 1; 0 1]); colormap(axCB,cm); caxis(axCB,caxV);
cbx = colorbar(axCB,'Position',[0.020 0.14 0.015 0.74]);
try, cbx.Color='w'; cbx.FontName='Arial'; cbx.FontSize=10; cbx.Label.String='Signal change (%)'; cbx.Label.Color='w'; cbx.TickDirection='out'; cbx.Box='off'; catch, end
x0 = 0.095; x1 = 0.98; yBot = 0.12; yTop = 0.86; rowGap = 0.06; colGap = 0.02;
cellH = (yTop-yBot-rowGap)/2; cellW = (x1-x0-2*colGap)/3;
for k = 1:min(6,numel(pngList))
    if k <= 3, cc = k-1; y = yBot + cellH + rowGap; else, cc = k-4; y = yBot; end
    x = x0 + cc*(cellW+colGap);
    axI = axes('Parent',figS,'Position',[x y cellW cellH]);
    image(axI,imread(pngList{k})); axis(axI,'image'); axis(axI,'off');
    annotation(figS,'textbox',[x y+cellH+0.005 cellW 0.035],'String',lblList{k},'Color','w','EdgeColor','none','FontName','Arial','FontSize',12,'FontWeight','bold','HorizontalAlignment','center','Interpreter','none');
end
print(figS,outFile,'-dpng','-r200','-opengl');
close(figS);
end

function GA_writePPT_PATCH_V4(pptFile,slidePNGs)
if exist(pptFile,'file')==2
    try, delete(pptFile); catch, error('Could not overwrite PPT: %s',pptFile); end
end
if ~isempty(which('mlreportgen.ppt.Presentation'))
    import mlreportgen.ppt.*
    ppt = [];
    try
        ppt = Presentation(pptFile); open(ppt);
        for i = 1:numel(slidePNGs)
            try, slide = add(ppt,'Blank'); catch, slide = add(ppt); end
            pic = Picture(slidePNGs{i});
            pic.X = '0in'; pic.Y = '0in'; pic.Width = '13.333in'; pic.Height = '7.5in';
            add(slide,pic);
        end
        close(ppt);
    catch ME
        try, if ~isempty(ppt), close(ppt); end, catch, end
        error('mlreportgen PPT export failed: %s',ME.message);
    end
elseif ispc && exist('actxserver','file')==2
    ppt = []; pres = [];
    try
        ppt = actxserver('PowerPoint.Application'); ppt.Visible = 1;
        pres = ppt.Presentations.Add;
        sw = pres.PageSetup.SlideWidth; sh = pres.PageSetup.SlideHeight;
        for i = 1:numel(slidePNGs)
            slide = pres.Slides.Add(i,12);
            slide.Shapes.AddPicture(slidePNGs{i},0,1,0,0,sw,sh);
        end
        pres.SaveAs(pptFile); pres.Close; ppt.Quit;
    catch ME
        try, if ~isempty(pres), pres.Close; end, catch, end
        try, if ~isempty(ppt), ppt.Quit; end, catch, end
        error('PowerPoint COM export failed: %s',ME.message);
    end
else
    error('No PowerPoint writer found. Slide PNGs were saved but PPTX could not be created.');
end
pause(0.3);
if exist(pptFile,'file')~=2, error('PPT file was not created: %s',pptFile); end
end

function cm = GA_colormap_PATCH_V4(R)
if isfield(R,'cmapMatrix') && ~isempty(R.cmapMatrix) && size(R.cmapMatrix,2)==3
    cm = double(R.cmapMatrix); cm = max(0,min(1,cm)); return;
end
name = lower(strtrim(char(R.colormapName)));
n = 256;
switch name
    case 'hot', cm = hot(n);
    case 'parula', cm = parula(n);
    case 'jet', cm = jet(n);
    case 'gray', cm = gray(n);
    case 'bone', cm = bone(n);
    case 'copper', cm = copper(n);
    case 'winter_brain_fsl', cm = winter(n);
    case 'signed_blackbdy_winter'
        nNeg = floor(n/2); nPos = n-nNeg;
        neg = winter(max(nNeg,2)); neg = neg(1:nNeg,:); neg = neg .* repmat(linspace(1,0,nNeg)',1,3);
        if ~isempty(neg), neg(end,:) = [0 0 0]; end
        pos = hot(max(nPos,2)); pos = pos(1:nPos,:); if ~isempty(pos), pos(1,:) = [0 0 0]; end
        cm = [neg; pos];
    otherwise
        if strcmp(name,'turbo') && exist('turbo','file')==2, cm = turbo(n); else, cm = hot(n); end
end
end

function RGB = GA_toRGB_PATCH_V4(U)
U = double(U); U(~isfinite(U)) = 0;
if ndims(U) == 3 && size(U,3) == 3
    RGB = U; mx = max(RGB(:)); if isfinite(mx) && mx > 1, RGB = RGB/255; end; RGB = max(0,min(1,RGB)); return;
end
mn = min(U(:)); mx = max(U(:));
if isfinite(mn) && isfinite(mx) && mx > mn, G = (U-mn)/(mx-mn); else, G = zeros(size(U)); end
RGB = repmat(G,[1 1 3]);
end

function B = GA_resizeLike_PATCH_V4(A,sz)
if numel(sz)>2, sz = sz(1:2); end
if ndims(A)==3 && size(A,3)==3
    B = zeros(sz(1),sz(2),3);
    for c=1:3, B(:,:,c) = GA_resizeLike_PATCH_V4(A(:,:,c),sz); end
    return;
end
if isequal(size(A),sz), B=A; return; end
try
    B = imresize(A,sz,'bilinear');
catch
    [Y,X] = size(A); [xq,yq] = meshgrid(linspace(1,X,sz(2)),linspace(1,Y,sz(1)));
    B = interp2(double(A),xq,yq,'linear',0);
end
end

function M = GA_resizeMask_PATCH_V4(M,sz)
if isequal(size(M),sz), M = logical(M); return; end
try, M = imresize(double(M),sz,'nearest') > 0.5;
catch, M = GA_resizeLike_PATCH_V4(double(M),sz) > 0.5;
end
end

function B = GA_smooth2_PATCH_V4(A,sigma)
try, B = imgaussfilt(A,sigma); return; catch, end
if sigma <= 0, B = A; return; end
r = max(1,ceil(3*sigma)); x = -r:r; g = exp(-(x.^2)/(2*sigma^2)); g = g/sum(g);
B = conv2(conv2(double(A),g,'same'),g','same');
end

function tf = GA_toLogical_PATCH_V4(x)
tf = false;
try
    if islogical(x), tf = logical(x(1));
    elseif isnumeric(x), tf = isfinite(x(1)) && x(1) ~= 0;
    else, s = lower(strtrim(char(x))); tf = any(strcmp(s,{'1','true','yes','y','on'}));
    end
catch
end
end

function bw = GA_defaultBaseWindow_PATCH_V4(S,bf)
bw = [30 240];
try
    if isfield(S,'mapGlobalBaseSec') && numel(S.mapGlobalBaseSec)>=2
        v = double(S.mapGlobalBaseSec(1:2)); if all(isfinite(v)) && v(2)>v(1), bw = v(:)'; return; end
    end
catch
end
try
    G = GA_loadSCMBundle_PATCH_V4(bf);
    if isfield(G,'baseWindowSec') && numel(G.baseWindowSec)>=2
        v = double(G.baseWindowSec(1:2)); if all(isfinite(v)) && v(2)>v(1), bw = v(:)'; return; end
    end
catch
end
end

function d = GA_exportStartDir_PATCH_V4(S)
d = pwd;
try, if isfield(S,'outDir') && ~isempty(S.outDir) && exist(S.outDir,'dir')==7, d = char(S.outDir); return; end, catch, end
try, if isfield(S,'opt') && isfield(S.opt,'startDir') && exist(S.opt.startDir,'dir')==7, d = char(S.opt.startDir); return; end, catch, end
end

function subj = GA_subjectName_PATCH_V4(S,row,bf,G)
subj = '';
try, subj = strtrim(char(S.subj{row,2})); catch, end
if isempty(subj) && isfield(G,'animalID') && ~isempty(G.animalID), try, subj = strtrim(char(G.animalID)); catch, end, end
if isempty(subj), [~,subj] = fileparts(bf); end
end

function s = GA_phaseLabel_PATCH_V4(s0,s1,injSec,winLen)
if ~isfinite(injSec)
    s = sprintf('%d min',floor(s0/winLen)+1);
elseif s1 <= injSec
    s = 'Pre-inj';
elseif s0 < injSec && s1 > injSec
    s = 'Injection';
else
    m = floor((s0-injSec)/winLen)+1; if m < 1, m = 1; end
    s = sprintf('%d min PI',m);
end
end

function v = GA_numField_PATCH_V4(S,f,fb)
v = fb; try, if isfield(S,f) && ~isempty(S.(f)), v = double(S.(f)(1)); end, catch, end; if ~isfinite(v), v = fb; end
end
function v = GA_vecField_PATCH_V4(S,f,fb)
v = fb; try, if isfield(S,f) && numel(S.(f))>=2, vv = double(S.(f)(1:2)); if all(isfinite(vv)), v = vv(:)'; end, end, catch, end
end
function v = GA_logField_PATCH_V4(S,f,fb)
v = fb; try, if isfield(S,f) && ~isempty(S.(f)), v = logical(S.(f)(1)); end, catch, end
end
function s = GA_charField_PATCH_V4(S,f,fb)
s = fb; try, if isfield(S,f) && ~isempty(S.(f)), s = strtrim(char(S.(f))); end, catch, end
end
function s = GA_safeName_PATCH_V4(s)
try, s = char(s); catch, s = 'export'; end
s = regexprep(s,'[<>:"/\\|?*]','_'); s = regexprep(s,'[^A-Za-z0-9_\-]','_'); s = regexprep(s,'_+','_'); s = regexprep(s,'^_+|_+$','');
if isempty(s), s = 'export'; end; if numel(s)>60, s = s(1:60); end
end
function GA_mkdir_PATCH_V4(d)
if exist(d,'dir')~=7, ok = mkdir(d); if ~ok, error('Could not create folder: %s',d); end, end
end


function Aout = GA_alphaModFixFromCData_20260504(h, Ain)
% Strict SCM-style alpha safety wrapper.
% Keeps AlphaData numeric in [0,1] and removes black zero-valued overlay pixels.
Aout = Ain;
try
    Aout = double(Aout);
catch
    Aout = 0;
end

Aout(~isfinite(Aout)) = 0;
Aout = min(max(Aout,0),1);

try
    C = get(h,'CData');
    if isnumeric(C) && ndims(C) == 2
        C = double(C);
        if isscalar(Aout)
            Aout = Aout .* ones(size(C));
        end
        if isequal(size(Aout),size(C))
            Aout(~isfinite(C)) = 0;
            Aout(abs(C) <= eps) = 0;
        end
    end
catch
end

try
    set(h,'AlphaDataMapping','none');
catch
end
end


% ============================================================
% GA_loadUnderlayAndOverlayMask_20260504
% Robust extractor for MaskEditor UnderlayAndOverlayMasks MAT files.
% ============================================================
function [U,OM,infoTxt] = GA_loadUnderlayAndOverlayMask_20260504(fp)
U = [];
OM = [];
infoTxt = '';

fp = strtrimSafe(fp);
if isempty(fp) || exist(fp,'file') ~= 2
    error('File not found: %s',fp);
end

[~,~,ext] = fileparts(fp);
ext = lower(ext);

if ~strcmp(ext,'.mat')
    U = imread(fp);
    infoTxt = shortFileOnly_20260504(fp);
    return;
end

L = load(fp);

cands = struct('path',{},'value',{},'scoreU',{},'scoreM',{});
walkStruct(L,'',0);

if isempty(cands)
    error('No numeric image-like fields found in MAT file: %s',fp);
end

% Pick true underlay.
scoresU = [cands.scoreU];
[bestU,idxU] = max(scoresU);
if isempty(idxU) || bestU <= -Inf
    error('Could not identify a true underlay field in MAT file.');
end
U = cands(idxU).value;
U = squeeze(U);
U = double(U);
U(~isfinite(U)) = 0;

% Pick overlay/signal mask.
scoresM = [cands.scoreM];
[bestM,idxM] = max(scoresM);
if ~isempty(idxM) && isfinite(bestM) && bestM > 0
    OM = cands(idxM).value;
    OM = squeeze(OM);
    if ndims(OM) > 2
        if size(OM,3) == 1
            OM = OM(:,:,1);
        elseif size(OM,3) == 3
            OM = OM(:,:,1);
        else
            OM = OM(:,:,round(size(OM,3)/2));
        end
    end
    OM = double(OM);
    OM(~isfinite(OM)) = 0;
    if max(OM(:)) > min(OM(:))
        OM = OM > 0.5 * max(OM(:));
    else
        OM = logical(OM);
    end
else
    OM = [];
end

infoTxt = sprintf('%s | underlay=%s', shortFileOnly_20260504(fp), cands(idxU).path);
if ~isempty(OM)
    infoTxt = sprintf('%s | overlayMask=%s', infoTxt, cands(idxM).path);
end

fprintf('[GA mask loader] %s\n', infoTxt);

    function walkStruct(S,path0,depth)
        if depth > 5
            return;
        end
        if isstruct(S)
            fn = fieldnames(S);
            for ii = 1:numel(fn)
                f = fn{ii};
                if isempty(path0)
                    pth = f;
                else
                    pth = [path0 '.' f];
                end
                try
                    walkStruct(S.(f),pth,depth+1);
                catch
                end
            end
        elseif isnumeric(S) || islogical(S)
            A = squeeze(S);
            if isempty(A) || numel(A) < 100
                return;
            end
            if ndims(A) > 3
                return;
            end
            sz = size(A);
            if numel(sz) < 2 || sz(1) < 8 || sz(2) < 8
                return;
            end
            scU = scoreUnderlay(path0,A);
            scM = scoreMask(path0,A);
            cands(end+1).path = path0;
            cands(end).value = A;
            cands(end).scoreU = scU;
            cands(end).scoreM = scM;
        elseif iscell(S) && numel(S) <= 20
            for jj = 1:numel(S)
                try
                    walkStruct(S{jj},sprintf('%s{%d}',path0,jj),depth+1);
                catch
                end
            end
        end
    end

    function sc = scoreUnderlay(pathName,A)
        p = lower(pathName);
        sc = 0;
        if contains(p,'sliceunderlayraw'), sc = sc + 1200; end
        if contains(p,'underlayraw'),      sc = sc + 1000; end
        if contains(p,'sliceunderlay'),    sc = sc + 900;  end
        if contains(p,'underlay2d'),       sc = sc + 800;  end
        if contains(p,'underlay'),         sc = sc + 650;  end
        if contains(p,'brainimage'),       sc = sc + 500;  end
        if contains(p,'anatomy'),          sc = sc + 450;  end
        if contains(p,'bg'),               sc = sc + 300;  end
        if contains(p,'mask'),             sc = sc - 500;  end
        if contains(p,'overlay'),          sc = sc - 400;  end
        if isBinaryish(A),                   sc = sc - 350;  end
        if ndims(A) == 3 && size(A,3) == 3, sc = sc + 100;  end
    end

    function sc = scoreMask(pathName,A)
        p = lower(pathName);
        sc = -Inf;
        if contains(p,'overlaymask'), sc = 1200; end
        if contains(p,'signalmask'),  sc = max(sc,1100); end
        if contains(p,'overlay') && contains(p,'mask'), sc = max(sc,1000); end
        if contains(p,'loadedmask'),  sc = max(sc,500); end
        if contains(p,'mask') && ~contains(p,'underlaymask'), sc = max(sc,250); end
        if isfinite(sc)
            if isBinaryish(A), sc = sc + 150; else, sc = sc - 150; end
        end
    end

    function tf = isBinaryish(A)
        try
            if islogical(A)
                tf = true;
                return;
            end
            v = double(A(:));
            v = v(isfinite(v));
            if isempty(v)
                tf = true;
                return;
            end
            if numel(v) > 10000
                idx = round(linspace(1,numel(v),10000));
                v = v(idx);
            end
            v = round(v(:) * 1000) / 1000;
            u = unique(v);
            tf = numel(u) <= 4;
        catch
            tf = false;
        end
    end
end

function s = shortFileOnly_20260504(fp)
try
    [~,a,b] = fileparts(fp);
    s = [a b];
catch
    s = fp;
end
end



function M = ga_fc_prefer_fisher_z_matrix(subj)
% GA helper: use Fisher z for FC averaging/statistics.
% Priority: displayStatMatrix/displayZ/statMatrix/Z, fallback atanh(displayR/R).
M = [];
try
    if isstruct(subj)
        if isfield(subj,'displayStatMatrix') && ~isempty(subj.displayStatMatrix)
            M = double(subj.displayStatMatrix); return;
        end
        if isfield(subj,'displayZ') && ~isempty(subj.displayZ)
            M = double(subj.displayZ); return;
        end
        if isfield(subj,'statMatrix') && ~isempty(subj.statMatrix)
            M = double(subj.statMatrix); return;
        end
        if isfield(subj,'Z') && ~isempty(subj.Z)
            M = double(subj.Z); return;
        end
        if isfield(subj,'displayR') && ~isempty(subj.displayR)
            R = max(-0.999999,min(0.999999,double(subj.displayR)));
            M = atanh(R);
            M(1:size(M,1)+1:end) = 0;
            return;
        end
        if isfield(subj,'R') && ~isempty(subj.R)
            R = max(-0.999999,min(0.999999,double(subj.R)));
            M = atanh(R);
            M(1:size(M,1)+1:end) = 0;
            return;
        end
    end
catch
end
end

function R = ga_fc_prefer_pearson_r_matrix(subj)
% GA helper: use Pearson r for visual display.
R = [];
try
    if isstruct(subj)
        if isfield(subj,'displayMatrix') && ~isempty(subj.displayMatrix)
            R = double(subj.displayMatrix); return;
        end
        if isfield(subj,'displayR') && ~isempty(subj.displayR)
            R = double(subj.displayR); return;
        end
        if isfield(subj,'R') && ~isempty(subj.R)
            R = double(subj.R); return;
        end
        if isfield(subj,'displayZ') && ~isempty(subj.displayZ)
            R = tanh(double(subj.displayZ)); return;
        end
        if isfield(subj,'Z') && ~isempty(subj.Z)
            R = tanh(double(subj.Z)); return;
        end
    end
catch
end
end



%% LOCAL_GA_MOTOR_EXPORT_INTEGRATED_V6
function outFile = localGA_motorExportIntegratedV6(action,hFig,varargin)
% Integrated multi-slice step-motor GroupAnalysis exporter.
% No external helper files required.
if nargin < 1 || isempty(action), action = 'scm'; end
if nargin < 2 || isempty(hFig) || ~ishghandle(hFig)
    try, hFig = gcf; catch, hFig = []; end
end
if isempty(hFig) || ~ishghandle(hFig)
    error('Invalid GroupAnalysis figure handle.');
end
switch lower(strtrim(char(action)))
    case {'video','exportvideo'}
        outFile = localGA_exportVideoBundleV6(hFig);
    case {'scm','data','exportscm'}
        outFile = localGA_exportSCMBundleV6(hFig,false);
    case {'ppt','powerpoint','exportppt'}
        outFile = localGA_exportSCMBundleV6(hFig,true);
    otherwise
        error('Unsupported export action: %s', action);
end
end

function outFile = localGA_exportVideoBundleV6(hFig)
S = guidata(hFig);
[rows,bfs] = localGA_collectBundlesV6(S);
if isempty(bfs)
    error('No active SCM bundle rows found. Add SCM bundles and keep rows enabled.');
end
startDir = localGA_smartStartDirV6(S,bfs{1});
defName = ['GA_MotorVideo_AllSlices_' datestr(now,'yyyymmdd_HHMMSS') '.mat'];
[f,p] = uiputfile({'*.mat','MAT-file (*.mat)'}, 'Save multi-slice GroupAnalysis video bundle', fullfile(startDir,defName));
if isequal(f,0), outFile = ''; return; end
outFile = fullfile(p,f);
opts = localGA_readDisplayOptsV6(S);
opts.underlayMode = 'selected';
[G,E] = localGA_buildGroupBundleV6(S,rows,bfs,opts,[]);
E.kind = 'GA_GROUP_VIDEO_EXPORT';
E.exportPurpose = 'multi-slice video';
E.note = 'Open in Video GUI using LOAD GA VIDEO BUNDLE. Contains all step-motor slices as [Y X Z T].';
GA = E; %#ok<NASGU>
psc4D = E.psc4D; %#ok<NASGU>
functional4D = E.functional4D; %#ok<NASGU>
underlay2D = E.underlay2D; %#ok<NASGU>
brainImage = E.brainImage; %#ok<NASGU>
groupMap2D = E.groupMap2D; %#ok<NASGU>
overlay2D = E.overlay2D; %#ok<NASGU>
save(outFile,'E','GA','G','psc4D','functional4D','underlay2D','brainImage','groupMap2D','overlay2D','-v7.3');
msgbox(sprintf('Saved multi-slice GA video bundle:\n\n%s\n\nSlices: %d\nFrames: %d\nSubjects: %d',outFile,E.nSlices,E.nFrames,numel(rows)), 'Group video export');
fprintf('\n[GA motor video export] Saved:\n%s\n',outFile);
end

function outFile = localGA_exportSCMBundleV6(hFig,makePPT)
S = guidata(hFig);
[rows,bfs] = localGA_collectBundlesV6(S);
if isempty(bfs)
    error('No active SCM bundle rows found. Add SCM bundles and keep rows enabled.');
end
startDir = localGA_smartStartDirV6(S,bfs{1});
opts = localGA_readDisplayOptsV6(S);
if makePPT
    opts = localGA_askPPTOptionsV6(S,bfs{1},opts);
    try, opts.hFig = hFig; catch, end
    if isempty(opts), outFile = ''; return; end
    defName = ['GA_MotorSCM_AllSlices_' datestr(now,'yyyymmdd_HHMMSS') '.pptx'];
    [f,p] = uiputfile({'*.pptx','PowerPoint (*.pptx)'}, 'Save multi-slice SCM PowerPoint', fullfile(startDir,defName));
    if isequal(f,0), outFile = ''; return; end
    outFile = fullfile(p,f);
    [G,E] = localGA_buildGroupBundleV6(S,rows,bfs,opts,opts.slices);
    [pngDir,nSlides,nTiles] = localGA_writeMotorPPTV6(outFile,G,E,opts);
    matFile = fullfile(fileparts(outFile), [localGA_stripExtV6(localGA_localNameV6(outFile)) '_SCM_bundle.mat']);
    GA = E; %#ok<NASGU>
    save(matFile,'G','E','GA','opts','-v7.3');
    msgbox(sprintf('Saved multi-slice SCM PPT:\n\n%s\n\nSaved source PNGs in:\n%s\n\nSlides: %d\nBrain PNG tiles: %d\nSCM bundle:\n%s',outFile,pngDir,nSlides,nTiles,matFile), 'Group PPT export');
    fprintf('\n[GA motor PPT export] Saved PPT:\n%s\nPNG folder:\n%s\nMAT bundle:\n%s\n',outFile,pngDir,matFile);
else
    defName = ['GA_MotorSCM_AllSlices_' datestr(now,'yyyymmdd_HHMMSS') '.mat'];
    [f,p] = uiputfile({'*.mat','MAT-file (*.mat)'}, 'Save multi-slice SCM-compatible group bundle', fullfile(startDir,defName));
    if isequal(f,0), outFile = ''; return; end
    outFile = fullfile(p,f);
    [G,E] = localGA_buildGroupBundleV6(S,rows,bfs,opts,[]);
    GA = E; %#ok<NASGU>
    pscAtlas4D = G.pscAtlas4D; %#ok<NASGU>
    functional4D = E.functional4D; %#ok<NASGU>
    underlayAtlas = G.underlayAtlas; %#ok<NASGU>
    underlay2D = E.underlay2D; %#ok<NASGU>
    brainImage = E.brainImage; %#ok<NASGU>
    scmMapSignedAtlas = G.scmMapSignedAtlas; %#ok<NASGU>
    groupMap2D = E.groupMap2D; %#ok<NASGU>
    overlay2D = E.overlay2D; %#ok<NASGU>
    save(outFile,'G','E','GA','pscAtlas4D','functional4D','underlayAtlas','underlay2D','brainImage','scmMapSignedAtlas','groupMap2D','overlay2D','-v7.3');
    msgbox(sprintf('Saved multi-slice SCM group bundle:\n\n%s\n\nSlices: %d\nFrames: %d\nSubjects: %d',outFile,G.nSlices,G.nFrames,numel(rows)), 'Export Data SCM');
    fprintf('\n[GA motor SCM data export] Saved:\n%s\n',outFile);
end
end

function opts = localGA_askPPTOptionsV6(S,firstBundle,opts)
% SCM-style motor PPT options for GroupAnalysis.
% Uses GroupAnalysis GUI settings for caxis/alpha/modulation/polarity.
try
    G0 = localGA_loadBundleV6(firstBundle);
    X0 = localGA_normalizePSCV6(localGA_getPSCFieldV6(G0));
    nZ = size(X0,3);
    nT = size(X0,4);
    TR = localGA_getTRV6(G0);
    totalSec = max(0,(nT-1)*TR);
catch
    nZ = 1; nT = 1; TR = 1; totalSec = 0;
end

curZ = 1;
try
    if isfield(S,'mapCurrentSlice') && isfinite(S.mapCurrentSlice)
        curZ = round(S.mapCurrentSlice);
    end
catch
end
curZ = max(1,min(nZ,curZ));

choice = questdlg('Which step-motor slices should be exported to PPT?', ...
    'SCM-style motor PPT export', ...
    'All slices', 'Current slice only', 'Custom list', 'All slices');
if isempty(choice), opts = []; return; end

switch choice
    case 'All slices'
        slices = 1:nZ;
    case 'Current slice only'
        slices = curZ;
    otherwise
        a0 = inputdlg({'Slice list, e.g. 1:4 or 1 3 4:'}, ...
            'Custom slice list', 1, {sprintf('1:%d',nZ)});
        if isempty(a0), opts = []; return; end
        slices = localGA_parseNumListV6(a0{1},1:nZ);
end
slices = unique(max(1,min(nZ,round(slices))),'stable');
if isempty(slices), slices = 1:nZ; end

uModes = {'selected','normal','histology','vascular','regions'};
[um,ok] = listdlg('PromptString',{ ...
        'Underlay for exported PPT:', ...
        'selected = bundle-selected underlay; otherwise force one atlas underlay'}, ...
    'SelectionMode','single', ...
    'ListString',uModes, ...
    'InitialValue',1, ...
    'ListSize',[420 180], ...
    'Name','PPT underlay mode');
if ~ok || isempty(um), opts = []; return; end

% Read GUI settings AFTER underlay choice, then force only the export-specific values.
opts = localGA_readDisplayOptsV6(S);
opts.underlayMode = uModes{um};
opts.baseWin = [20 40];

answers = inputdlg({ ...
    'Injection start (sec). Default = 60 s because motor baseline is 1 min per slice:', ...
    'Window length (sec). Default = 28 s:', ...
    'Specific time point sec to export (empty = every 28-s window):'}, ...
    'Motor SCM PPT timing', 1, {'60', '28', ''});
if isempty(answers), opts = []; return; end

opts.slices = slices;
opts.injSec = str2double(strtrim(answers{1}));
if ~isfinite(opts.injSec), opts.injSec = 60; end
opts.winLen = str2double(strtrim(answers{2}));
if ~isfinite(opts.winLen) || opts.winLen <= 0, opts.winLen = 28; end
tp = str2double(strtrim(answers{3}));
if isfinite(tp), opts.singleTimePointSec = tp; else, opts.singleTimePointSec = NaN; end
opts.TRHint = TR;
opts.totalSecHint = totalSec;
opts.nFramesHint = nT;

fprintf('\n[GA motor PPT] GUI settings used: polarity=%s, pos caxis=[%g %g], neg caxis=[%g %g], alpha=%g%%, mod=[%g %g], baseline=[20 40] s\n', ...
    opts.polarity, opts.caxis(1), opts.caxis(2), opts.negCaxis(1), opts.negCaxis(2), opts.alphaPercent, opts.modMin, opts.modMax);
end

function [G,E] = localGA_buildGroupBundleV6(S,rows,bfs,opts,slicesWanted)
Gs = cell(1,numel(bfs)); Xs = cell(1,numel(bfs)); TRs = nan(1,numel(bfs));
for i=1:numel(bfs)
    Gs{i} = localGA_loadBundleV6(bfs{i});
    Xs{i} = localGA_normalizePSCV6(localGA_getPSCFieldV6(Gs{i}));
    TRs(i) = localGA_getTRV6(Gs{i});
end
nY = size(Xs{1},1); nX = size(Xs{1},2); nZ = size(Xs{1},3); nT = size(Xs{1},4);
for i=2:numel(Xs)
    nZ = min(nZ,size(Xs{i},3)); nT = min(nT,size(Xs{i},4));
end
if isempty(slicesWanted), slicesWanted = 1:nZ; end
slicesWanted = unique(max(1,min(nZ,round(slicesWanted))),'stable');
nZout = numel(slicesWanted);
SUM = zeros(nY,nX,nZout,nT,'double'); CNT = zeros(nY,nX,nZout,nT,'double');
Usum = zeros(nY,nX,nZout,'double'); Ucnt = zeros(nY,nX,nZout,'double');
subjects = struct('row',{},'animal',{},'condition',{},'group',{},'bundleFile',{});
for i=1:numel(Xs)
    Xi = localGA_fitPSCToTargetV6(Xs{i},nY,nX,nZ,nT);
    Xi = Xi(:,:,slicesWanted,1:nT);
    ok = isfinite(Xi); Xi(~ok) = 0; SUM = SUM + Xi; CNT = CNT + double(ok);
    Ui = localGA_getUnderlayStackV6(Gs{i},opts.underlayMode,nY,nX,nZ);
    Ui = Ui(:,:,slicesWanted);
    oku = isfinite(Ui); Ui(~oku) = 0; Usum = Usum + Ui; Ucnt = Ucnt + double(oku);
    subjects(end+1) = localGA_rowInfoV6(S,rows(i),bfs{i},Gs{i}); %#ok<AGROW>
end
Xg = SUM ./ max(1,CNT); Xg(CNT==0) = 0;
Ug = Usum ./ max(1,Ucnt); Ug(Ucnt==0) = 0;
TR = median(TRs(isfinite(TRs) & TRs>0)); if ~isfinite(TR), TR = 1; end
baseWin = [0 60]; try, if isfield(opts,'baseWin'), baseWin = opts.baseWin; end, catch, end
sigWin = [60 88]; try, sigWin = [opts.injSec opts.injSec + opts.winLen]; catch, end
maps = localGA_computeWindowMapsV6(Xg,TR,baseWin,sigWin,opts);
G = struct();
G.kind = 'SCM_GROUP_EXPORT';
G.version = 'GA_MOTOR_EXPORT_INTEGRATED_V6';
G.source = 'GroupAnalysis multi-slice motor export';
G.created = datestr(now);
G.pscAtlas4D = single(Xg);
G.functional4D = single(repmat(Ug,[1 1 1 nT]));
G.underlayAtlas = single(Ug);
G.underlay2D = single(Ug);
G.brainImage = single(Ug);
G.commonUnderlay = single(Ug);
G.scmMapSignedAtlas = single(maps);
G.scmMapAtlas = single(maps);
G.mapAtlas = single(maps);
G.groupMap2D = single(maps);
G.overlay2D = single(maps);
G.TR = TR; G.tsec = (0:nT-1)*TR; G.tMin = G.tsec/60;
G.nSlices = nZout; G.nFrames = nT; G.selectedSlices = slicesWanted;
G.baseWindowSec = baseWin; G.signalWindowSec = sigWin;
G.display = opts; G.render = opts; G.subjects = subjects;
G.note = 'Multi-slice group mean PSC: [Y X Z T]. Suitable for step-motor GroupAnalysis, SCM, PPT, and Video GUI.';
E = struct();
E.kind = 'GA_GROUP_VIDEO_EXPORT';
E.version = 'GA_MOTOR_EXPORT_INTEGRATED_V6';
E.psc4D = single(Xg);
E.functional4D = single(repmat(Ug,[1 1 1 nT]));
E.underlay2D = single(Ug);
E.brainImage = single(Ug);
E.groupMap2D = single(maps);
E.overlay2D = single(maps);
E.TR = TR; E.tsec = G.tsec; E.tMin = G.tMin;
E.nSlices = nZout; E.nFrames = nT; E.selectedSlices = slicesWanted;
E.baseWindowSec = baseWin; E.signalWindowSec = sigWin;
E.mapCaxis = opts.caxis; E.mapSigma = opts.sigma; E.mapModMin = opts.modMin; E.mapModMax = opts.modMax;
E.render = opts; E.subjects = subjects; E.sourceG = G;
end

function maps = localGA_computeWindowMapsV6(X,TR,baseWin,sigWin,opts)
[nY,nX,nZ,nT] = size(X); maps = zeros(nY,nX,nZ);
b = localGA_secToIdxV6(baseWin,TR,nT); s = localGA_secToIdxV6(sigWin,TR,nT);
for z=1:nZ
    P = squeeze(X(:,:,z,:));
    M = mean(P(:,:,s(1):s(2)),3) - mean(P(:,:,b(1):b(2)),3);
    if opts.sigma > 0, M = localGA_smooth2V6(M,opts.sigma); end
    M(~isfinite(M)) = 0; maps(:,:,z) = M;
end
end

function [pngDir,nSlides,nTiles] = localGA_writeMotorPPTV6(outFile,G,E,opts)
% SCM_gui-like motor PPT export for GroupAnalysis group mean maps.
% Slide order: info slide, then slice 1 windows, slice 2 windows, etc.
% Each slide contains up to 6 brain images.
outDir = fileparts(outFile);
if isempty(outDir), outDir = pwd; end
[~,base] = fileparts(outFile);
pngDir = fullfile(outDir,[base '_PNGs']);
localGA_mkdirV6(pngDir);
tileDir = fullfile(pngDir,'brain_tiles_png');
slideDir = fullfile(pngDir,'fallback_slide_png');
localGA_mkdirV6(tileDir);
localGA_mkdirV6(slideDir);

X = double(G.pscAtlas4D);
U = double(G.underlayAtlas);
TR = double(G.TR);
[~,~,nZ,nT] = size(X);
tsec = (0:nT-1)*TR;
totalSec = max(tsec);
baseIdx = localGA_secToIdxV6(opts.baseWin,TR,nT);

if isfinite(opts.singleTimePointSec)
    starts = max(0,floor(opts.singleTimePointSec/opts.winLen)*opts.winLen);
else
    starts = 0:opts.winLen:totalSec;
end
if isempty(starts), starts = 0; end

perSlide = 6;
estSlides = 1 + nZ * ceil(numel(starts)/perSlide);
nTiles = 0;

cbarFile = fullfile(pngDir,'colorbar_signal_change.png');
localGA_makeColorbarPNGV6(cbarFile,opts);

info = localGA_makeInfoTextV6(G,E,opts);
infoPNG = fullfile(slideDir,'slide_000_info_table.png');
localGA_makeInfoPNGV6(infoPNG,info);

slides = struct('title',{},'subtitle',{},'tiles',{},'labels',{},'cbar',{});
slides(1).title = 'GroupAnalysis motor SCM export';
slides(1).subtitle = '';
slides(1).tiles = {infoPNG};
slides(1).labels = {'Export information'};
slides(1).cbar = '';

wb = [];
try
    wb = waitbar(0, sprintf('Preparing slide 1/%d...',estSlides), 'Name','Exporting motor SCM PPT');
catch
    wb = [];
end
localGA_setStatusBestEffortV6(opts,'PPT export: preparing info slide 1/%d',estSlides);

slideCounter = 1;
for z=1:nZ
    tileFiles = {};
    tileLabels = {};
    for wi=1:numel(starts)
        s0 = starts(wi);
        s1 = min(s0 + opts.winLen, totalSec + TR);
        idx = find(tsec >= s0 & tsec < s1);
        if isempty(idx), continue; end

        P = squeeze(X(:,:,z,:));
        M = mean(P(:,:,idx),3) - mean(P(:,:,baseIdx(1):baseIdx(2)),3);
        if opts.sigma > 0
            M = localGA_smooth2V6(M,opts.sigma);
        end
        M(~isfinite(M)) = 0;

        bg = U(:,:,min(z,size(U,3)));
        phase = localGA_phaseLabelV6(s0,s1,opts.injSec);
        lbl = sprintf('Slice %d/%d | %.0f-%.0f s | %s',z,nZ,s0,s1,phase);
        tileFile = fullfile(tileDir,sprintf('slice%02d_window%03d_%0.0f_%0.0fs.png',z,wi,s0,s1));
        localGA_renderTilePNGV6(tileFile,bg,M,opts,lbl);
        tileFiles{end+1} = tileFile; %#ok<AGROW>
        tileLabels{end+1} = lbl; %#ok<AGROW>
        nTiles = nTiles + 1;

        localGA_setStatusBestEffortV6(opts,'PPT export: rendered tile %d, slice %d/%d',nTiles,z,nZ);
        drawnow;
    end

    if isempty(tileFiles), continue; end
    nSlideZ = ceil(numel(tileFiles)/perSlide);
    for si=1:nSlideZ
        i0 = (si-1)*perSlide + 1;
        i1 = min(si*perSlide,numel(tileFiles));
        idx2 = i0:i1;
        slideCounter = slideCounter + 1;
        slides(end+1).title = sprintf('Slice %d/%d  |  windows %d-%d',z,nZ,i0,i1); %#ok<AGROW>
        slides(end).subtitle = sprintf('Base %g-%g s | Injection %.0f s | TR %.4g s | alpha %.0f%%%% | AlphaMod %d [%g %g] | %s', ...
            opts.baseWin(1),opts.baseWin(2),opts.injSec,TR,opts.alphaPercent,double(opts.alphaModOn),opts.modMin,opts.modMax,opts.polarity);
        slides(end).tiles = tileFiles(idx2);
        slides(end).labels = tileLabels(idx2);
        slides(end).cbar = cbarFile;

        try
            if ~isempty(wb) && ishghandle(wb)
                waitbar(min(0.95,slideCounter/max(1,estSlides)), wb, sprintf('Prepared slide %d/%d',slideCounter,estSlides));
            end
        catch
        end
        localGA_setStatusBestEffortV6(opts,'PPT export: prepared slide %d/%d',slideCounter,estSlides);
        drawnow;
    end
end

if numel(slides) <= 1
    try, if ~isempty(wb) && ishghandle(wb), close(wb); end, catch, end
    error('No PPT tiles were rendered.');
end

try
    if ~isempty(wb) && ishghandle(wb)
        waitbar(0.98, wb, 'Writing PowerPoint file...');
    end
catch
end
localGA_setStatusBestEffortV6(opts,'PPT export: writing PowerPoint file with %d slides...',numel(slides));
localGA_writePPTObjectsV6(outFile,slides,slideDir,opts);
try, if ~isempty(wb) && ishghandle(wb), close(wb); end, catch, end

nSlides = numel(slides);
localGA_setStatusBestEffortV6(opts,'PPT export saved: %s',outFile);
end

function localGA_writePPTObjectsV6(outFile,slides,slideDir,opts)
if exist(outFile,'file')==2
    try
        delete(outFile);
    catch
        error('Could not overwrite PPTX: %s',outFile);
    end
end

if ispc && exist('actxserver','file') == 2
    ppt = []; pres = [];
    try
        ppt = actxserver('PowerPoint.Application');
        ppt.Visible = 1;
        pres = invoke(ppt.Presentations,'Add');
        sw = pres.PageSetup.SlideWidth;
        sh = pres.PageSetup.SlideHeight;

        for i=1:numel(slides)
            slide = invoke(pres.Slides,'Add',i,12);
            localGA_setSlideBlackV6(slide);
            localGA_addTextV6(slide,slides(i).title,20,12,sw-40,34,20,true);

            if i == 1
                localGA_addPictureFitV6(slide,slides(i).tiles{1},45,70,sw-90,sh-100);
            else
                localGA_addTextV6(slide,slides(i).subtitle,20,45,sw-40,24,10,false);

                % Bigger readable left colorbar.
                if ~isempty(slides(i).cbar)
                    localGA_addPictureFitV6(slide,slides(i).cbar,10,92,95,500);
                end

                % 6-panel grid, image aspect preserved.
                n = numel(slides(i).tiles);
                cols = 3;
                rows = 2;
                left0 = 112;
                top0 = 82;
                gapX = 12;
                gapY = 18;
                cellW = (sw-left0-24-(cols-1)*gapX)/cols;
                cellH = (sh-top0-28-(rows-1)*gapY)/rows;
                for k=1:n
                    rr = floor((k-1)/cols);
                    cc = mod(k-1,cols);
                    x = left0 + cc*(cellW+gapX);
                    y = top0 + rr*(cellH+gapY);
                    localGA_addPictureFitV6(slide,slides(i).tiles{k},x,y,cellW,cellH);
                end
            end

            localGA_setStatusBestEffortV6(opts,'PPT export: writing slide %d/%d',i,numel(slides));
            drawnow;
        end

        invoke(pres,'SaveAs',outFile);
        invoke(pres,'Close');
        invoke(ppt,'Quit');
        pause(0.3);
        if exist(outFile,'file')==2
            return;
        end
    catch ME
        try, if ~isempty(pres), invoke(pres,'Close'); end, catch, end
        try, if ~isempty(ppt), invoke(ppt,'Quit'); end, catch, end
        warning('ActiveX PPT failed, using fallback slide PNGs: %s',ME.message);
    end
end

% Fallback: one slide PNG per PPT slide.
slidePNGs = cell(1,numel(slides));
for i=1:numel(slides)
    slidePNGs{i} = fullfile(slideDir,sprintf('fallback_slide_%03d.png',i));
    localGA_renderFallbackSlideV6(slidePNGs{i},slides(i),opts);
    localGA_setStatusBestEffortV6(opts,'PPT fallback export: rendered slide %d/%d',i,numel(slides));
    drawnow;
end
localGA_writePPTSlidePNGs_V6(outFile,slidePNGs);
end

function localGA_addPictureV6(slide,file,x,y,w,h)
invoke(slide.Shapes,'AddPicture',file,0,1,x,y,w,h);
end

function localGA_addPictureFitV6(slide,file,x,y,w,h)
% Insert image while preserving aspect ratio. Prevents stretched brain panels.
try
    info = imfinfo(file);
    iw = double(info.Width);
    ih = double(info.Height);
    if iw > 0 && ih > 0
        scale = min(w/iw,h/ih);
        ww = iw*scale;
        hh = ih*scale;
        xx = x + (w-ww)/2;
        yy = y + (h-hh)/2;
        invoke(slide.Shapes,'AddPicture',file,0,1,xx,yy,ww,hh);
        return;
    end
catch
end
invoke(slide.Shapes,'AddPicture',file,0,1,x,y,w,h);
end

function localGA_setSlideBlackV6(slide)
try
    slide.FollowMasterBackground = 0;
    slide.Background.Fill.Visible = 1;
    slide.Background.Fill.Solid;
    slide.Background.Fill.ForeColor.RGB = 0;
catch
end
end

function localGA_addTextV6(slide,txt,x,y,w,h,fs,boldFlag)
sh = invoke(slide.Shapes,'AddTextbox',1,x,y,w,h);
try
    sh.TextFrame.TextRange.Text = txt;
    sh.TextFrame.TextRange.Font.Size = fs;
    sh.TextFrame.TextRange.Font.Name = 'Arial';
    sh.TextFrame.TextRange.Font.Color.RGB = 16777215;
    if boldFlag, sh.TextFrame.TextRange.Font.Bold = 1; end
catch
end
end

function localGA_writePPTSlidePNGs_V6(outFile,slidePNGs)
if ~isempty(which('mlreportgen.ppt.Presentation'))
    import mlreportgen.ppt.*
    ppt = Presentation(outFile); open(ppt);
    for i=1:numel(slidePNGs)
        try, slide = add(ppt,'Blank'); catch, slide = add(ppt); end
        pic = Picture(slidePNGs{i}); pic.X='0in'; pic.Y='0in'; pic.Width='13.333in'; pic.Height='7.5in'; add(slide,pic);
    end
    close(ppt); pause(0.3); if exist(outFile,'file')==2, return; end
end
error('Could not create PowerPoint. Fallback slide PNGs were saved.');
end

function localGA_renderFallbackSlideV6(outFile,SL,opts)
f = figure('Visible','off', ...
    'Color',[0 0 0], ...
    'InvertHardcopy','off', ...
    'Units','inches', ...
    'Position',[0.5 0.5 13.333 7.5]);
annotation(f,'textbox',[0.02 0.91 0.96 0.07], ...
    'String',SL.title, ...
    'Color','w', ...
    'EdgeColor','none', ...
    'HorizontalAlignment','center', ...
    'FontSize',16, ...
    'FontWeight','bold', ...
    'Interpreter','none');

if numel(SL.tiles)==1 && isempty(SL.cbar)
    ax = axes('Parent',f,'Position',[0.05 0.08 0.90 0.78]);
    image(ax,imread(SL.tiles{1}));
    axis(ax,'image'); axis(ax,'off');
else
    annotation(f,'textbox',[0.08 0.86 0.90 0.035], ...
        'String',SL.subtitle, ...
        'Color','w', ...
        'EdgeColor','none', ...
        'HorizontalAlignment','left', ...
        'FontSize',8.5, ...
        'Interpreter','none');
    if ~isempty(SL.cbar)
        axc = axes('Parent',f,'Position',[0.010 0.12 0.075 0.74]);
        image(axc,imread(SL.cbar));
        axis(axc,'image'); axis(axc,'off');
    end
    n = numel(SL.tiles);
    cols = 3; rows = 2;
    left0 = 0.095; top0 = 0.84; W = 0.885; H = 0.73; gapX = 0.016; gapY = 0.035;
    cw = (W-(cols-1)*gapX)/cols;
    ch = (H-(rows-1)*gapY)/rows;
    for k=1:n
        rr = floor((k-1)/cols);
        cc = mod(k-1,cols);
        x = left0 + cc*(cw+gapX);
        y = top0 - (rr+1)*ch - rr*gapY;
        ax = axes('Parent',f,'Position',[x y cw ch]);
        image(ax,imread(SL.tiles{k}));
        axis(ax,'image'); axis(ax,'off');
    end
end
print(f,outFile,'-dpng','-r180','-opengl');
close(f);
end

function localGA_makeInfoPNGV6(outFile,txt)
f = figure('Visible','off', ...
    'Color',[0 0 0], ...
    'InvertHardcopy','off', ...
    'Units','pixels', ...
    'Position',[100 100 1800 1000]);
ax = axes('Parent',f,'Position',[0 0 1 1]);
axis(ax,'off'); hold(ax,'on');
text(ax,0.04,0.94,'GroupAnalysis multi-slice motor SCM export', ...
    'Units','normalized', ...
    'Color',[1 1 1], ...
    'FontName','Arial', ...
    'FontSize',28, ...
    'FontWeight','bold', ...
    'Interpreter','none', ...
    'VerticalAlignment','top');
lines0 = regexp(txt,sprintf('\n'),'split');
lines0 = lines0(~cellfun(@isempty,lines0));
y = 0.86; dy = 0.038;
for i=1:numel(lines0)
    L = lines0{i};
    if isempty(strtrim(L)), y = y - dy; continue; end
    if ~isempty(strfind(L,'|'))
        rectangle('Parent',ax,'Position',[0.035 y-0.026 0.93 0.034], ...
            'EdgeColor',[0.28 0.28 0.28], ...
            'FaceColor',[0.055 0.055 0.055]);
    end
    text(ax,0.05,y,L, ...
        'Units','normalized', ...
        'Color',[0.95 0.95 0.95], ...
        'FontName','Consolas', ...
        'FontSize',16, ...
        'Interpreter','none', ...
        'VerticalAlignment','middle');
    y = y - dy;
    if y < 0.05, break; end
end
print(f,outFile,'-dpng','-r150','-opengl');
close(f);
end

function txtOut = localGA_makeInfoTextV6(G,E,opts)
subs = {};
try
    for i=1:numel(G.subjects)
        animal = G.subjects(i).animal;
        groupName = G.subjects(i).group;
        condName = G.subjects(i).condition;
        fileName = localGA_localNameV6(G.subjects(i).bundleFile);
        subs{end+1} = sprintf('%s | %s | %s | %s', animal, groupName, condName, fileName); %#ok<AGROW>
    end
catch
end
if isempty(subs), subs = {'unknown | unknown | unknown | unknown'}; end
txtOut = sprintf('Animal / subject | Group | Condition | Bundle file\n');
txtOut = [txtOut sprintf('%s\n', subs{:})];
txtOut = [txtOut sprintf('\nExport settings\n')];
txtOut = [txtOut sprintf('Slices exported | %s | Frames | %d\n', mat2str(G.selectedSlices), E.nFrames)];
txtOut = [txtOut sprintf('TR / total duration | %.4g s | %.2f min\n', G.TR, max(G.tsec)/60)];
txtOut = [txtOut sprintf('Baseline / injection | %g-%g s | injection %.0f s | window %.0f s\n', opts.baseWin(1),opts.baseWin(2),opts.injSec,opts.winLen)];
txtOut = [txtOut sprintf('Polarity / underlay | %s | %s\n', opts.polarity, opts.underlayMode)];
txtOut = [txtOut sprintf('Positive caxis | [%g %g] | Negative caxis | [%g %g]\n', opts.caxis(1),opts.caxis(2),opts.negCaxis(1),opts.negCaxis(2))];
txtOut = [txtOut sprintf('Alpha / alpha modulation | %.0f%%%% | ON=%d | [%g %g]\n', opts.alphaPercent,double(opts.alphaModOn),opts.modMin,opts.modMax)];
txtOut = [txtOut sprintf('Threshold / sigma | %g | %g\n', opts.threshold,opts.sigma)];
txtOut = [txtOut sprintf('\nPNG note\nEach brain tile is saved separately in *_PNGs/brain_tiles_png.\nPPT slides contain up to 6 brain PNGs per slide, slice-by-slice like SCM_gui motor export.\n')];
end

function localGA_makeColorbarPNGV6(outFile,opts)
f = figure('Visible','off', ...
    'Color',[0 0 0], ...
    'InvertHardcopy','off', ...
    'Units','pixels', ...
    'Position',[100 100 340 980]);
ax = axes('Parent',f,'Position',[0.12 0.07 0.10 0.86]);
imagesc(ax,[0 1;0 1]);
set(ax,'Visible','off');
[cm,cax] = localGA_cmapForOptsV6(opts);
colormap(ax,cm);
caxis(ax,cax);
cb = colorbar(ax,'Position',[0.34 0.07 0.30 0.86]);
try
    cb.Color = 'w';
    cb.FontSize = 16;
    cb.LineWidth = 1.5;
    mode = localGA_polarityModeV11(opts);
    if mode == 2
        cb.Label.String = 'Negative |signal change| (%)';
    else
        cb.Label.String = 'Signal change (%)';
    end
    cb.Label.Color = 'w';
    cb.Label.FontSize = 16;
    cb.Label.FontWeight = 'bold';
catch
end
print(f,outFile,'-dpng','-r180','-opengl');
close(f);
end

function localGA_renderTilePNGV6(outFile,bg,M,opts,lbl)
[RGB,A,cmap,cax] = localGA_overlayRGBV6(bg,M,opts);
f = figure('Visible','off', ...
    'Color',[0 0 0], ...
    'InvertHardcopy','off', ...
    'Units','pixels', ...
    'Position',[100 100 1200 820]);

% Big centered title area above the brain image.
annotation(f,'textbox',[0.02 0.925 0.96 0.060], ...
    'String',lbl, ...
    'Color','w', ...
    'EdgeColor','none', ...
    'HorizontalAlignment','center', ...
    'VerticalAlignment','middle', ...
    'FontName','Arial', ...
    'FontSize',24, ...
    'FontWeight','bold', ...
    'Interpreter','none');

ax = axes('Parent',f,'Position',[0.025 0.040 0.950 0.875]);
image(ax,localGA_underlayRGBV6(bg));
axis(ax,'image');
axis(ax,'off');
hold(ax,'on');
h = image(ax,RGB);
set(h,'AlphaData',A);
try, set(h,'AlphaDataMapping','none'); catch, end
colormap(ax,cmap);
caxis(ax,cax);
print(f,outFile,'-dpng','-r180','-opengl');
close(f);
end

function mode = localGA_polarityModeV11(opts)
% SCM_gui signMode equivalent: 1 positive, 2 negative, 3 signed positive+negative.
mode = 1;
try
    pol = lower(strtrim(char(opts.polarity)));
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

function [posLo,posHi,negHi] = localGA_colorLimitsV11(opts)
posLo = 0; posHi = 100; negHi = 100;
try
    ca = double(opts.caxis(:)');
    if numel(ca) >= 2 && all(isfinite(ca(1:2)))
        posLo = ca(1);
        posHi = ca(2);
    end
catch
end
try
    nca = double(opts.negCaxis(:)');
    if numel(nca) >= 2 && all(isfinite(nca(1:2)))
        negHi = max(abs(nca(1:2)));
    end
catch
end
if ~isfinite(posLo), posLo = 0; end
if ~isfinite(posHi) || posHi <= posLo
    tmp = max(abs([posLo posHi 100]));
    if ~isfinite(tmp) || tmp <= 0, tmp = 100; end
    posLo = 0;
    posHi = tmp;
end
if ~isfinite(negHi) || negHi <= 0
    negHi = max(abs([posLo posHi 100]));
end
if ~isfinite(negHi) || negHi <= 0
    negHi = 100;
end
end

function [posCM,negMagCM,signedCM] = localGA_scmColormapsV11(n)
% Exact SCM_gui-style colormap selection.
% positive: blackbdy_iso if available, else hot.
% negative-only magnitude: black at 0, winter at high magnitude.
% signed: winter -> black at zero -> blackbody.
if nargin < 1 || isempty(n), n = 256; end
n = max(2,round(n));

if exist('blackbdy_iso','file') == 2
    posCM = blackbdy_iso(n);
else
    posCM = hot(n);
end
posCM = min(max(posCM,0),1);
if ~isempty(posCM), posCM(1,:) = [0 0 0]; end

if exist('winter_brain_fsl','file') == 2
    winterCM = winter_brain_fsl(n);
else
    winterCM = winter(n);
end
winterCM = min(max(winterCM,0),1);

% Signed SCM negative half: strongest negative is winter, zero is black.
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

% Negative-only uses magnitude map abs(negative): 0 should be black, high magnitude winter.
negMagCM = flipud(negSigned);
if isempty(negMagCM)
    negMagCM = winterCM;
end
negMagCM = min(max(negMagCM,0),1);
if ~isempty(negMagCM), negMagCM(1,:) = [0 0 0]; end
end

function [RGB,A,cm,cax] = localGA_overlayRGBV6(bg,M,opts)
% V11: exact SCM_gui-style sign handling and alpha modulation for PPT export.
M = double(M);
M(~isfinite(M)) = 0;
sz = size(M);

if ~isfield(opts,'alphaModOn'), opts.alphaModOn = true; end
if ~isfield(opts,'threshold'), opts.threshold = 0; end
if ~isfield(opts,'alphaPercent'), opts.alphaPercent = 100; end
if ~isfield(opts,'modMin'), opts.modMin = 15; end
if ~isfield(opts,'modMax'), opts.modMax = 30; end
if ~isfield(opts,'caxis'), opts.caxis = [0 100]; end
if ~isfield(opts,'negCaxis'), opts.negCaxis = [-100 0]; end

[posLo,posHi,negHi] = localGA_colorLimitsV11(opts);
mode = localGA_polarityModeV11(opts);
[posCM,negMagCM,signedCM] = localGA_scmColormapsV11(256);

% SCM_gui buildDisplayedOverlay equivalent.
switch mode
    case 1
        showMask = M > 0;
        dispMap = M;
        cm = posCM;
        cax = [posLo posHi];
        RGB = localGA_colorizeV6(dispMap,posLo,posHi,posCM);
    case 2
        showMask = M < 0;
        dispMap = abs(min(M,0));
        cm = negMagCM;
        cax = [0 negHi];
        RGB = localGA_colorizeV6(dispMap,0,negHi,negMagCM);
    otherwise
        showMask = isfinite(M) & M ~= 0;
        dispMap = M;
        cm = signedCM;
        cax = [-negHi posHi];
        RGB = localGA_colorizeV6(dispMap,-negHi,posHi,signedCM);
end

brain = localGA_brainMaskFromUnderlayV11(bg,sz);
thr = abs(double(opts.threshold));
thrMask = double((abs(M) >= thr) & showMask) .* double(brain);

a = max(0,min(100,double(opts.alphaPercent))) / 100;
mMin = double(opts.modMin);
mMax = double(opts.modMax);
if ~isfinite(mMin), mMin = 15; end
if ~isfinite(mMax), mMax = 30; end
if mMax < mMin, tmp=mMin; mMin=mMax; mMax=tmp; end

if ~logical(opts.alphaModOn)
    A = a .* thrMask;
else
    effLo = max(mMin,thr);
    effHi = mMax;
    mag = abs(M);
    mag(~showMask) = NaN;
    if ~isfinite(effHi) || effHi <= effLo
        tmpv = mag(isfinite(mag));
        if isempty(tmpv)
            effHi = effLo + eps;
        else
            effHi = max(tmpv);
        end
    end
    if ~isfinite(effHi) || effHi <= effLo
        effHi = effLo + eps;
    end
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
end

function brain = localGA_brainMaskFromUnderlayV11(bg,sz)
try
    G = localGA_underlayRGBV6(bg);
    G = mean(G,3);
    mx = max(G(:));
    if ~isfinite(mx) || mx <= 0
        brain = true(sz);
        return;
    end
    brain = G > max(0.02,0.15*mx);
    if nnz(brain) < 10, brain = true(sz); end
catch
    brain = true(sz);
end
end

function RGB=localGA_colorizeV6(V,lo,hi,cm)
if hi<=lo, hi=lo+eps; end
t=(double(V)-lo)./(hi-lo); t=min(max(t,0),1); t(~isfinite(t))=0; idx=1+round(t*(size(cm,1)-1));
RGB=zeros([size(V) 3]); for c=1:3, C=cm(:,c); RGB(:,:,c)=reshape(C(idx(:)),size(V)); end
end

function cm=localGA_blackbodyV6(n)
% Shared blackbody-like positive map: black -> red -> orange/yellow -> white.
if nargin < 1 || isempty(n), n = 256; end
n = max(2,round(n));
x = linspace(0,1,n)';
anchorX = [0.00 0.18 0.40 0.68 1.00]';
anchorC = [ ...
    0.00 0.00 0.00;  ...
    0.35 0.00 0.00;  ...
    0.85 0.05 0.00;  ...
    1.00 0.75 0.00;  ...
    1.00 1.00 1.00];
cm = zeros(n,3);
for cc=1:3
    cm(:,cc) = interp1(anchorX,anchorC(:,cc),x,'linear','extrap');
end
cm = max(0,min(1,cm));
end

function RGB=localGA_underlayRGBV6(U)
U=double(U); U=squeeze(U); if ndims(U)==3 && size(U,3)==3, RGB=U; if max(RGB(:))>1, RGB=RGB/255; end; RGB=max(0,min(1,RGB)); return; end
U(~isfinite(U))=0; v=U(:); v=v(isfinite(v)); if isempty(v), U01=zeros(size(U)); else, lo=localGA_prctileV6(v,1); hi=localGA_prctileV6(v,99); if hi<=lo, U01=zeros(size(U)); else, U01=min(max((U-lo)/(hi-lo),0),1); end, end
RGB=repmat(U01,[1 1 3]);
end

function m=localGA_brainMaskFromUnderlayV6(U,sz)
G=localGA_underlayRGBV6(U); G=mean(G,3); thr=max(0.02,0.15*max(G(:))); m=G>thr; if nnz(m)<10, m=true(sz); end
end

function [cm,cax]=localGA_cmapForOptsV6(opts)
% V11: colorbar matches exact SCM-style overlay rendering.
[posLo,posHi,negHi] = localGA_colorLimitsV11(opts);
mode = localGA_polarityModeV11(opts);
[posCM,negMagCM,signedCM] = localGA_scmColormapsV11(256);
switch mode
    case 1
        cm = posCM;
        cax = [posLo posHi];
    case 2
        cm = negMagCM;
        cax = [0 negHi];
    otherwise
        cm = signedCM;
        cax = [-negHi posHi];
end
end

function G=localGA_loadBundleV6(bf)
L=load(bf); G=[];
if isfield(L,'G') && isstruct(L.G), G=L.G; return; end
if isfield(L,'E') && isstruct(L.E), G=L.E; return; end
if isfield(L,'GA') && isstruct(L.GA), G=L.GA; return; end
fn=fieldnames(L); for i=1:numel(fn), v=L.(fn{i}); if isstruct(v) && (isfield(v,'pscAtlas4D')||isfield(v,'psc4D')||isfield(v,'functional4D')), G=v; return; end, end
error('Could not find bundle struct G/E/GA in: %s',bf);
end

function X=localGA_getPSCFieldV6(G)
flds={'pscAtlas4D','psc4D','PSC','functionalPSC','Ipsc'}; X=[]; for i=1:numel(flds), if isfield(G,flds{i}) && ~isempty(G.(flds{i})), X=G.(flds{i}); return; end, end
error('Bundle has no PSC time series field.');
end

function X=localGA_normalizePSCV6(X)
X=double(X); X(~isfinite(X))=0;
if ndims(X)==2, error('PSC is only 2D static map, not a time series.'); end
if ndims(X)==3, X=reshape(X,[size(X,1) size(X,2) 1 size(X,3)]); return; end
if ndims(X)==4, return; end
while ndims(X)>4, X=squeeze(mean(X,1)); end
if ndims(X)==3, X=reshape(X,[size(X,1) size(X,2) 1 size(X,3)]); end
if ndims(X)~=4, error('PSC must normalize to [Y X Z T].'); end
end

function TR=localGA_getTRV6(G)
TR=NaN; try, if isfield(G,'TR') && ~isempty(G.TR), TR=double(G.TR(1)); end, catch, end
try, if (~isfinite(TR)||TR<=0) && isfield(G,'tsec') && numel(G.tsec)>1, TR=median(diff(double(G.tsec(:)))); end, catch, end
try, if (~isfinite(TR)||TR<=0) && isfield(G,'tMin') && numel(G.tMin)>1, TR=60*median(diff(double(G.tMin(:)))); end, catch, end
if ~isfinite(TR)||TR<=0, TR=1; end
end

function U=localGA_getUnderlayStackV6(G,mode,nY,nX,nZ)
U=[]; mode=lower(strtrim(mode));
try
    if isfield(G,'underlays') && isstruct(G.underlays)
        if strcmp(mode,'selected') && isfield(G,'underlaySelectedMode'), mode=lower(strtrim(char(G.underlaySelectedMode))); end
        order={mode,'normal','histology','vascular','regions'};
        for k=1:numel(order)
            fn=order{k}; if isempty(fn), continue; end
            if isfield(G.underlays,fn)
                E=G.underlays.(fn); if isstruct(E) && isfield(E,'data'), U=E.data; else, U=E; end
                if ~isempty(U), break; end
            end
        end
    end
catch, U=[]; end
if isempty(U)
    flds={'underlayAtlas','underlay2D','underlayAtlas2D','brainImage','commonUnderlay','bg','functional4D'};
    for i=1:numel(flds), if isfield(G,flds{i}) && ~isempty(G.(flds{i})), U=G.(flds{i}); break; end, end
end
if isempty(U), U=zeros(nY,nX,nZ); end
U=localGA_fitUnderlayV6(U,nY,nX,nZ);
end

function U=localGA_fitUnderlayV6(U,nY,nX,nZ)
U=squeeze(double(U)); U(~isfinite(U))=0;
if ndims(U)==2
    U2=localGA_resize2V6(U,nY,nX); U=repmat(U2,[1 1 nZ]); return;
end
if ndims(U)==3
    if size(U,3)==3 && nZ==1, U=mean(U,3); U=localGA_resize2V6(U,nY,nX); U=reshape(U,[nY nX 1]); return; end
    V=zeros(nY,nX,size(U,3)); for z=1:size(U,3), V(:,:,z)=localGA_resize2V6(U(:,:,z),nY,nX); end
    if size(V,3)==nZ, U=V; else, idx=round(linspace(1,size(V,3),nZ)); U=V(:,:,idx); end
    return;
end
if ndims(U)==4
    V=mean(U,4); U=localGA_fitUnderlayV6(V,nY,nX,nZ); return;
end
U=zeros(nY,nX,nZ);
end

function Xo=localGA_fitPSCToTargetV6(X,nY,nX,nZ,nT)
Xo=zeros(nY,nX,nZ,nT);
for z=1:nZ
    zz=min(z,size(X,3));
    for t=1:nT
        tt=min(t,size(X,4)); Xo(:,:,z,t)=localGA_resize2V6(X(:,:,zz,tt),nY,nX);
    end
end
end

function B=localGA_resize2V6(A,nY,nX)
A=double(A); if size(A,1)==nY && size(A,2)==nX, B=A; return; end
try, B=imresize(A,[nY nX],'bilinear'); catch, [Y,X]=size(A); [xq,yq]=meshgrid(linspace(1,X,nX),linspace(1,Y,nY)); B=interp2(A,xq,yq,'linear',0); end
end

function opts=localGA_readDisplayOptsV6(S)
opts = struct();
opts.caxis = [0 100];
opts.negCaxis = [-100 0];
opts.threshold = 0;
opts.alphaPercent = 100;
opts.alphaModOn = true;
opts.modMin = 10;
opts.modMax = 20;
opts.sigma = 0;
opts.polarity = 'Positive only';
opts.underlayMode = 'selected';
opts.baseWin = [20 40];

% Positive caxis from GroupAnalysis GUI.
try, if isfield(S,'mapCaxis') && numel(S.mapCaxis)>=2, opts.caxis=double(S.mapCaxis(1:2)); end, catch, end
try
    if isfield(S,'hMapCaxis') && ishghandle(S.hMapCaxis)
        opts.caxis = localGA_parseRangeV6(get(S.hMapCaxis,'String'),opts.caxis);
    end
catch
end

% Negative caxis if present; otherwise mirror positive range.
negFound = false;
try, if isfield(S,'mapNegCaxis') && numel(S.mapNegCaxis)>=2, opts.negCaxis=double(S.mapNegCaxis(1:2)); negFound=true; end, catch, end
try, if ~negFound && isfield(S,'mapNegativeCaxis') && numel(S.mapNegativeCaxis)>=2, opts.negCaxis=double(S.mapNegativeCaxis(1:2)); negFound=true; end, catch, end
try
    if ~negFound && isfield(S,'hMapNegCaxis') && ishghandle(S.hMapNegCaxis)
        opts.negCaxis = localGA_parseRangeV6(get(S.hMapNegCaxis,'String'),opts.negCaxis);
        negFound = true;
    end
catch
end
if ~negFound
    mx = max(abs(opts.caxis));
    if ~isfinite(mx) || mx <= 0, mx = 100; end
    opts.negCaxis = [-mx 0];
end
if opts.negCaxis(1) > opts.negCaxis(2), opts.negCaxis = fliplr(opts.negCaxis); end
if opts.negCaxis(2) > 0 && opts.negCaxis(1) >= 0
    opts.negCaxis = [-max(abs(opts.negCaxis)) 0];
end

try, if isfield(S,'mapThreshold'), opts.threshold=double(S.mapThreshold(1)); end, catch, end
try, if isfield(S,'mapModMin'), opts.modMin=double(S.mapModMin(1)); end, catch, end
try, if isfield(S,'mapModMax'), opts.modMax=double(S.mapModMax(1)); end, catch, end
try, if isfield(S,'hMapModMin') && ishghandle(S.hMapModMin), opts.modMin=str2double(get(S.hMapModMin,'String')); end, catch, end
try, if isfield(S,'hMapModMax') && ishghandle(S.hMapModMax), opts.modMax=str2double(get(S.hMapModMax,'String')); end, catch, end
try, if isfield(S,'mapSigma'), opts.sigma=double(S.mapSigma(1)); end, catch, end

% Alpha modulation ON/OFF, compatible with current and future GUI fields.
try, if isfield(S,'mapAlphaModOn'), opts.alphaModOn=logical(S.mapAlphaModOn); end, catch, end
try, if isfield(S,'alphaModOn'), opts.alphaModOn=logical(S.alphaModOn); end, catch, end
try, if isfield(S,'hMapAlphaMod') && ishghandle(S.hMapAlphaMod), opts.alphaModOn=logical(get(S.hMapAlphaMod,'Value')); end, catch, end
try, if isfield(S,'hAlphaMod') && ishghandle(S.hAlphaMod), opts.alphaModOn=logical(get(S.hAlphaMod,'Value')); end, catch, end

% Polarity from GUI.
try, if isfield(S,'mapPolarity') && ~isempty(S.mapPolarity), opts.polarity=char(S.mapPolarity); end, catch, end
try
    if isfield(S,'hMapPolarity') && ishghandle(S.hMapPolarity)
        items = get(S.hMapPolarity,'String');
        val = get(S.hMapPolarity,'Value');
        if iscell(items), opts.polarity = items{val}; else, opts.polarity = strtrim(items(val,:)); end
    end
catch
end

% Alpha percent.
try, if isfield(S,'mapAlphaPercent'), opts.alphaPercent=double(S.mapAlphaPercent(1)); end, catch, end
try, if isfield(S,'mapAlphaPct'), opts.alphaPercent=double(S.mapAlphaPct(1)); end, catch, end
try, if isfield(S,'alphaPercent'), opts.alphaPercent=double(S.alphaPercent(1)); end, catch, end
try, if isfield(S,'mapAlpha') && S.mapAlpha <= 1, opts.alphaPercent=100*double(S.mapAlpha(1)); end, catch, end

if ~isfinite(opts.alphaPercent), opts.alphaPercent=100; end
opts.alphaPercent=max(0,min(100,opts.alphaPercent));
if ~isfinite(opts.modMin), opts.modMin=10; end
if ~isfinite(opts.modMax), opts.modMax=20; end
if opts.modMax<opts.modMin, tmp=opts.modMin; opts.modMin=opts.modMax; opts.modMax=tmp; end
if ~isfinite(opts.sigma), opts.sigma = 0; end
end

function [rows,bfs]=localGA_collectBundlesV6(S)
rows=[]; bfs={}; seen={};
if ~isfield(S,'subj') || isempty(S.subj), return; end
for r=1:size(S.subj,1)
    use=true; try, use=localGA_toLogicalV6(S.subj{r,1}); catch, end
    if ~use, continue; end
    bf=''; try, bf=strtrim(char(S.subj{r,8})); catch, end
    if isempty(bf) || exist(bf,'file')~=2, continue; end
    key=lower(strrep(bf,'/','\'));
    if any(strcmp(seen,key)), continue; end
    seen{end+1}=key; rows(end+1)=r; bfs{end+1}=bf; %#ok<AGROW>
end
end

function ri=localGA_rowInfoV6(S,row,bf,G)
ri=struct('row',row,'animal','','condition','','group','','bundleFile',bf);
try, ri.animal=strtrim(char(S.subj{row,2})); catch, end
try, ri.group=strtrim(char(S.subj{row,5})); catch, end
try, ri.condition=strtrim(char(S.subj{row,6})); catch, end
try, if isempty(ri.animal) && isfield(G,'animalID'), ri.animal=char(G.animalID); end, catch, end
if isempty(ri.animal), [~,ri.animal]=fileparts(bf); end
end

function tf=localGA_toLogicalV6(x)
if islogical(x), tf=logical(x(1)); elseif isnumeric(x), tf=isfinite(x(1)) && x(1)~=0; else, s=lower(strtrim(char(x))); tf=any(strcmp(s,{'1','true','yes','y','on'})); end
end

function idx=localGA_secToIdxV6(win,TR,nT)
idx=[max(1,min(nT,floor(win(1)/TR)+1)) max(1,min(nT,floor(win(2)/TR)+1))]; if idx(2)<idx(1), idx=fliplr(idx); end
end

function r=localGA_parseRangeV6(s,fb)
r = fb;
try
    s = strtrim(char(s));
    s = regexprep(s,'(?<=\d)\s*-\s*(?=\d)',' ');
    tok = regexp(s,'[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?','match');
    if numel(tok) >= 2
        v1 = str2double(tok{1});
        v2 = str2double(tok{2});
        if isfinite(v1) && isfinite(v2)
            r = [v1 v2];
        end
    end
catch
    r = fb;
end
if numel(r) < 2 || any(~isfinite(r(1:2)))
    r = fb;
end
if r(2)<r(1), r=fliplr(r); end
end

function vals=localGA_parseNumListV6(s,fb)
try, vals=eval(['[' char(s) ']']); vals=vals(:)'; vals=vals(isfinite(vals)); catch, vals=fb; end
end

function d=localGA_smartStartDirV6(S,bf)
d=pwd; try, [p,~,~]=fileparts(bf); if exist(p,'dir')==7, d=p; end, catch, end
try, if isfield(S,'outDir') && exist(S.outDir,'dir')==7, d=S.outDir; end, catch, end
end

function s=localGA_phaseLabelV6(s0,s1,inj)
if ~isfinite(inj), s=sprintf('%.1f min',s0/60); elseif s1<=inj, s='Baseline'; elseif s0<inj && s1>inj, s='Injection'; else, s=sprintf('PI %.2f-%.2f min',(s0-inj)/60,(s1-inj)/60); end
end

function q=localGA_prctileV6(v,p)
v=sort(double(v(:))); v=v(isfinite(v)); if isempty(v), q=0; return; end; n=numel(v); k=1+(n-1)*(p/100); k1=max(1,min(n,floor(k))); k2=max(1,min(n,ceil(k))); if k1==k2, q=v(k1); else, q=v(k1)+(k-k1)*(v(k2)-v(k1)); end
end

function tf=localGA_containsV6(s,pat)
tf=~isempty(strfind(lower(char(s)),lower(char(pat))));
end

function B=localGA_smooth2V6(A,sigma)
try, B=imgaussfilt(A,sigma); return; catch, end
if sigma<=0, B=A; return; end; r=max(1,ceil(3*sigma)); x=-r:r; g=exp(-(x.^2)/(2*sigma^2)); g=g/sum(g); B=conv2(conv2(double(A),g,'same'),g','same');
end

function localGA_mkdirV6(d), if exist(d,'dir')~=7, mkdir(d); end, end
function n=localGA_localNameV6(f), [~,n,e]=fileparts(f); n=[n e]; end
function s=localGA_stripExtV6(s), [~,s]=fileparts(s); end
function localGA_setStatusBestEffortV6(opts,varargin)
try
    msg = sprintf(varargin{:});
catch
    try, msg = char(varargin{1}); catch, msg = ''; end
end
if isempty(msg), return; end
try, fprintf('\n[GA PPT] %s\n',msg); catch, end
try
    if isfield(opts,'hFig') && ishghandle(opts.hFig)
        hFig0 = opts.hFig;
        hs = findall(hFig0,'Style','text');
        for ii=1:numel(hs)
            try
                tag = get(hs(ii),'Tag');
                str = get(hs(ii),'String');
                if ~isempty(strfind(lower(tag),'status')) || ~isempty(strfind(lower(str),'ready')) || ~isempty(strfind(lower(str),'export'))
                    set(hs(ii),'String',msg);
                    break;
                end
            catch
            end
        end
    end
catch
end
drawnow;
end

%% END_LOCAL_GA_MOTOR_EXPORT_INTEGRATED_V6
% GA_TARGETED_FCGA_20260616_START
function S = ensureFCRowFilesSizeGA_TARGETED(S)
if ~isfield(S,'subj') || isempty(S.subj)
    n = 0;
else
    n = size(S.subj,1);
end
if ~isfield(S,'fcRowFiles') || isempty(S.fcRowFiles)
    S.fcRowFiles = cell(n,1);
else
    S.fcRowFiles = S.fcRowFiles(:);
    if numel(S.fcRowFiles) < n
        S.fcRowFiles(end+1:n,1) = {''};
    elseif numel(S.fcRowFiles) > n
        S.fcRowFiles = S.fcRowFiles(1:n);
    end
end
end

function fcRowFiles = fcRowFilesForN_TARGETED(fcRowFiles,n)
if nargin < 1 || isempty(fcRowFiles)
    fcRowFiles = cell(n,1);
else
    fcRowFiles = fcRowFiles(:);
    if numel(fcRowFiles) < n
        fcRowFiles(end+1:n,1) = {''};
    elseif numel(fcRowFiles) > n
        fcRowFiles = fcRowFiles(1:n);
    end
end
end

function tf = isFCGABundleFile_TARGETED(fp)
tf = false;
try
    fp = strtrimSafe(fp);
    if isempty(fp), return; end
    [~,nm,ext] = fileparts(fp);
    if strcmpi(ext,'.mat') && ~isempty(regexpi(nm,'^FC_GroupBundle_|FC.*GroupBundle|GroupBundle.*FC','once'))
        tf = true;
        return;
    end
    if exist(fp,'file') == 2
        info = whos('-file',fp);
        vars = {info.name};
        tf = any(strcmp(vars,'fcBundle'));
    end
catch
    tf = false;
end
end

function s = deriveRowStatusWithFC_TARGETED(row,fcFile)
roi = ''; bundle = ''; st = ''; use = true;
if nargin < 2, fcFile = ''; end
try, roi = strtrimSafe(row{7}); catch, end
try, bundle = strtrimSafe(row{8}); catch, end
try, st = lower(strtrimSafe(row{9})); catch, end
try, use = logicalCellValue(row{1}); catch, end
fcFile = strtrimSafe(fcFile);
if contains(st,'excluded')
    s = 'Excluded';
elseif ~use
    s = 'Not used';
elseif ~isempty(roi) || ~isempty(bundle) || ~isempty(fcFile)
    s = 'OK';
else
    s = 'Not set';
end
end

function S = attachFCGABundlesToTable_TARGETED(S,fileList,FC)
% Attach FC-GA bundles to existing rows only. Never create subject rows here.
S = ensureFCRowFilesSizeGA_TARGETED(S);
if nargin < 2 || isempty(fileList), fileList = {}; end
if ischar(fileList), fileList = {fileList}; end
fileList = fileList(:);

% 1) If user selected rows before loading FC, attach files in order.
sel = [];
try
    if isfield(S,'selectedRows') && ~isempty(S.selectedRows)
        sel = unique(round(double(S.selectedRows(:)')).');
        sel = sel(sel >= 1 & sel <= size(S.subj,1));
    end
catch
    sel = [];
end
if ~isempty(sel) && ~isempty(fileList)
    nDirect = min(numel(sel),numel(fileList));
    for kk = 1:nDirect
        S.fcRowFiles{sel(kk),1} = fileList{kk};
    end
end

% 2) Match FC subjects to already existing rows by animal / subject name.
if nargin >= 3 && isfield(FC,'subjects') && ~isempty(FC.subjects)
    for ii = 1:numel(FC.subjects)
        fp = ''; nm = '';
        try, fp = strtrimSafe(FC.subjects(ii).sourceFile); catch, end
        try, nm = strtrimSafe(FC.subjects(ii).name); catch, end
        if isempty(fp) && ~isempty(fileList)
            try, fp = fileList{min(ii,numel(fileList))}; catch, end
        end
        r = findExistingFCGARow_TARGETED(S,nm,fp);
        if ~isempty(r)
            S.fcRowFiles{r,1} = fp;
            try
                if isfield(FC.subjects(ii),'group') && ~isempty(FC.subjects(ii).group)
                    % Keep table group as source of truth if user already set it.
                    if isempty(strtrimSafe(S.subj{r,3})) || strcmpi(strtrimSafe(S.subj{r,3}),'Unassigned')
                        S.subj{r,3} = strtrimSafe(FC.subjects(ii).group);
                    end
                end
            catch
            end
        end
    end
end

% 3) Do not append unmatched FC subjects. They remain loaded in S.FC only.
try
    nAttached = sum(~cellfun(@isempty,S.fcRowFiles));
    S.fcAttachNote = sprintf('FC bundles attached to %d existing table row(s). No new subject rows created.',nAttached);
catch
end
end


function hit = findFCGARow_TARGETED(S,nm,fp)
hit = [];
nm = lower(strtrimSafe(nm));
fp = strtrimSafe(fp);
S = ensureFCRowFilesSizeGA_TARGETED(S);
for r = 1:size(S.subj,1)
    try
        if ~isempty(fp) && strcmpi(strtrimSafe(S.fcRowFiles{r}),fp)
            hit = r;
            return;
        end
    catch
    end
end
if isempty(nm), return; end
for r = 1:size(S.subj,1)
    try
        if strcmpi(strtrimSafe(S.subj{r,2}),nm)
            hit = r;
            return;
        end
    catch
    end
end
end

function g = inferGroupFromText_TARGETED(txt)
g = 'Unassigned';
u = upper(strtrimSafe(txt));
if contains(u,'PACAP') || contains(u,'GROUPA') || contains(u,'CONDA')
    g = 'PACAP';
elseif contains(u,'VEH') || contains(u,'VEHICLE') || contains(u,'CONTROL') || contains(u,'PBS') || contains(u,'ACSF') || contains(u,'GROUPB') || contains(u,'CONDB')
    g = 'Vehicle';
end
end

function S = syncFCGroupsFromTable_TARGETED(S)
S = ensureFCRowFilesSizeGA_TARGETED(S);
if ~isfield(S,'FC') || ~isfield(S.FC,'subjects') || isempty(S.FC.subjects)
    return;
end
for ii = 1:numel(S.FC.subjects)
    fp = ''; nm = '';
    try, fp = strtrimSafe(S.FC.subjects(ii).sourceFile); catch, end
    try, nm = strtrimSafe(S.FC.subjects(ii).name); catch, end
    r = findFCGARow_TARGETED(S,nm,fp);
    if ~isempty(r)
        try, S.FC.subjects(ii).group = strtrimSafe(S.subj{r,3}); catch, end
        try, S.FC.subjects(ii).condition = strtrimSafe(S.subj{r,4}); catch, end
        try, S.FC.subjects(ii).name = strtrimSafe(S.subj{r,2}); catch, end
    end
end
end

function txt = fcGroupCountsText_TARGETED(FC)
txt = '';
try
    if ~isfield(FC,'subjects') || isempty(FC.subjects), return; end
    gs = cell(numel(FC.subjects),1);
    for ii = 1:numel(FC.subjects)
        gs{ii} = strtrimSafe(FC.subjects(ii).group);
        if isempty(gs{ii}), gs{ii} = 'Unassigned'; end
    end
    u = uniqueStable(gs);
    parts = cell(numel(u),1);
    for jj = 1:numel(u)
        parts{jj} = sprintf('%s=%d',u{jj},sum(strcmpi(gs,u{jj})));
    end
    txt = ['Groups: ' strjoin(parts,', ') '.'];
catch
    txt = '';
end
end

function exportGroupFCResults_TARGETED(S)
if ~isfield(S,'lastFC') || isempty(fieldnames(S.lastFC))
    error('Compute group FC first.');
end
R = S.lastFC;
outDir = '';
try, outDir = S.outDir; catch, end
if isempty(outDir) || exist(outDir,'dir') ~= 7
    try, outDir = defaultOutDir(S.opt); catch, outDir = pwd; end
end
outDir = fullfile(outDir,'FunctionalConnectivity_GroupAnalysis');
if exist(outDir,'dir') ~= 7, mkdir(outDir); end
tag = datestr(now,'yyyymmdd_HHMMSS');
base = sprintf('FC_Group_%s_vs_%s_%s',sanitizeFilename(R.groupA),sanitizeFilename(R.groupB),tag);
try, writeFCMatrixCSV(fullfile(outDir,[base '_mean_' sanitizeFilename(R.groupA) '_PearsonR.csv']),R.meanRA,R.names); catch, end
try, writeFCMatrixCSV(fullfile(outDir,[base '_mean_' sanitizeFilename(R.groupB) '_PearsonR.csv']),R.meanRB,R.names); catch, end
try, writeFCMatrixCSV(fullfile(outDir,[base '_diff_PearsonR.csv']),R.diffR,R.names); catch, end
try, writeFCMatrixCSV(fullfile(outDir,[base '_p_values.csv']),R.pMat,R.names); catch, end
try, writeFCMatrixCSV(fullfile(outDir,[base '_mean_' sanitizeFilename(R.groupA) '_FisherZ.csv']),R.meanZA,R.names); catch, end
try, writeFCMatrixCSV(fullfile(outDir,[base '_mean_' sanitizeFilename(R.groupB) '_FisherZ.csv']),R.meanZB,R.names); catch, end
try
    R_export = R; %#ok<NASGU>
    save(fullfile(outDir,[base '.mat']),'R_export','-v7');
catch
end
try, saveFCAxisPNG(S.axFCA,fullfile(outDir,[base '_A.png']),S.C); catch, end
try, saveFCAxisPNG(S.axFCB,fullfile(outDir,[base '_B.png']),S.C); catch, end
try, saveFCAxisPNG(S.axFCD,fullfile(outDir,[base '_Diff.png']),S.C); catch, end
try, saveFCAxisPNG(S.axFCP,fullfile(outDir,[base '_Pvalues.png']),S.C); catch, end
fprintf('FC Group Analysis exported to:\n%s\n',outDir);
end
% GA_TARGETED_FCGA_20260616_END


% GA_FC_SINGLE_CLEAN_HELPERS_20260616_START
function S = attachFCGABundlesToTable_NOROW_SINGLE_20260616(S,fileList,FC)
% Attach FC-GA bundles only to selected or matched existing rows. Never create new rows.
S = ensureFCRowFilesSizeGA_TARGETED(S);
if nargin < 2 || isempty(fileList), fileList = {}; end
if ischar(fileList), fileList = {fileList}; end
fileList = fileList(:);

% Direct attach to selected rows.
sel = [];
try
    if isfield(S,'selectedRows') && ~isempty(S.selectedRows)
        sel = unique(round(double(S.selectedRows(:)')));
        sel = sel(sel >= 1 & sel <= size(S.subj,1));
    end
catch
    sel = [];
end
if ~isempty(sel) && ~isempty(fileList)
    nDirect = min(numel(sel),numel(fileList));
    for kk = 1:nDirect
        S.fcRowFiles{sel(kk),1} = fileList{kk};
    end
end

% Match by existing animal / pair ID only.
if nargin >= 3 && isfield(FC,'subjects') && ~isempty(FC.subjects)
    for ii = 1:numel(FC.subjects)
        fp = ''; nm = '';
        try, fp = strtrimSafe(FC.subjects(ii).sourceFile); catch, end
        try, nm = strtrimSafe(FC.subjects(ii).name); catch, end
        if isempty(fp) && ~isempty(fileList)
            try, fp = fileList{min(ii,numel(fileList))}; catch, end
        end
        r = findExistingFCGARow_SINGLE_20260616(S,nm,fp);
        if ~isempty(r)
            S.fcRowFiles{r,1} = fp;
        end
    end
end
try
    S.fcAttachNote = sprintf('FC bundles attached to %d existing row(s). Unmatched bundles remain loaded but no table rows were created.',sum(~cellfun(@isempty,S.fcRowFiles)));
catch
end
end

function r = findExistingFCGARow_SINGLE_20260616(S,nm,fp)
r = [];
nm = lower(strtrimSafe(nm));
fp = strtrimSafe(fp);
try, S = ensureFCRowFilesSizeGA_TARGETED(S); catch, end
try
    for ii = 1:numel(S.fcRowFiles)
        if ~isempty(fp) && strcmpi(strtrimSafe(S.fcRowFiles{ii}),fp)
            r = ii; return;
        end
    end
catch
end
if isempty(nm), return; end
try
    for ii = 1:size(S.subj,1)
        a = lower(strtrimSafe(S.subj{ii,2}));
        p = lower(strtrimSafe(S.subj{ii,5}));
        if (~isempty(a) && (strcmp(a,nm) || contains(nm,a) || contains(a,nm))) || ...
           (~isempty(p) && (strcmp(p,nm) || contains(nm,p) || contains(p,nm)))
            r = ii; return;
        end
    end
catch
end
end

function R = computeSingleGroupFC_SINGLE_20260616(S)
G = alignFCSubjectsToCommonROIs_SINGLE_DIRECT_20260617(S.FC);
groupSel = 'All loaded';
try, groupSel = popupString_SINGLE_20260616(S,'hFCGroupA','All loaded'); catch, end

idx = true(numel(G.groups),1);
if ~isempty(groupSel) && ~strcmpi(groupSel,'All loaded') && ~strcmpi(groupSel,'All')
    idx = strcmpi(G.groups,groupSel);
    if ~any(idx)
        % Avoid old Group B style error. If selected group is empty, use all loaded FC subjects.
        idx = true(numel(G.groups),1);
        groupSel = 'All loaded';
    end
end

Z = G.Zstack(:,:,idx);
Rstack = G.Rstack(:,:,idx);
meanZ = mean3nan_SINGLE_20260616(Z);
meanR = tanh(meanZ);
pMat = pOneSampleApprox_SINGLE_20260616(Z);

R = struct();
R.mode = 'Functional Connectivity Single Group';
R.groupName = groupSel;
R.groupA = groupSel;
R.groupB = '';
R.n = sum(idx);
R.nA = sum(idx);
R.nB = 0;
R.labels = G.labels;
R.names = G.names;
R.meanZ = meanZ;
R.meanR = meanR;
R.meanZA = meanZ;
R.meanRA = meanR;
R.meanZB = nan(size(meanZ));
R.meanRB = nan(size(meanR));
R.diffZ = nan(size(meanZ));
R.diffR = nan(size(meanR));
R.pMat = pMat;
R.Zstack = Z;
R.Rstack = Rstack;
R.subjectNames = G.subjectNames(idx);
R.groups = G.groups(idx);
R.sourceFiles = G.sourceFiles(idx);
R.note = 'Single-group FC-GA: mean is computed in Fisher z space; Pearson r = tanh(mean z).';
end

function updateFCTabPreview_SINGLE_20260616(S)
R = S.lastFC;
setSingleFCAxis_SINGLE_20260616(S);
viewMode = popupString_SINGLE_20260616(S,'hFCView','Heatmap');
dispMode = popupString_SINGLE_20260616(S,'hFCDisplay','Pearson r');
thr = 0;
try, thr = safeNum(get(S.hFCThreshold,'String'),0); catch, end
if strcmpi(dispMode,'Fisher z')
    M = R.meanZ; stack = R.Zstack; clim = [-2.5 2.5]; valTxt = 'Fisher z';
else
    M = R.meanR; stack = R.Rstack; clim = [-1 1]; valTxt = 'Pearson r';
end
if thr > 0, M(abs(M) < thr) = 0; end
seedIdx = popupIndex_SINGLE_20260616(S,'hFCRegion1',1);
roi2Idx = popupIndex_SINGLE_20260616(S,'hFCRegion2',min(2,size(M,1)));
seedIdx = max(1,min(seedIdx,size(M,1)));
roi2Idx = max(1,min(roi2Idx,size(M,1)));
subjIdx = popupIndex_SINGLE_20260616(S,'hFCSubject',1);

switch lower(viewMode)
    case 'heatmap'
        plotFCMatrix_SINGLE_20260616(S.axFCA,M,clim,sprintf('%s mean FC heatmap | n=%d | %s',R.groupName,R.n,valTxt),R.names,S.C);
    case 'seed profile'
        plotSeedProfile_SINGLE_20260616(S.axFCA,M,seedIdx,R,valTxt,S.C);
    case 'roi trace'
        plotROITrace_SINGLE_20260616(S.axFCA,stack,seedIdx,roi2Idx,R,valTxt,S.C);
    case 'roi pair'
        plotROIPair_SINGLE_20260616(S.axFCA,stack,seedIdx,roi2Idx,R,valTxt,S.C);
    otherwise
        if subjIdx <= 1
            plotFCMatrix_SINGLE_20260616(S.axFCA,M,clim,sprintf('%s mean subject matrix | n=%d | %s',R.groupName,R.n,valTxt),R.names,S.C);
        else
            si = max(1,min(subjIdx-1,size(stack,3)));
            Ms = stack(:,:,si);
            if thr > 0, Ms(abs(Ms) < thr) = 0; end
            plotFCMatrix_SINGLE_20260616(S.axFCA,Ms,clim,sprintf('Subject matrix: %s | %s',strtrimSafe(R.subjectNames{si}),valTxt),R.names,S.C);
        end
end
try
    set(S.hFCInfo,'String',sprintf('Loaded %d FC subject(s). Showing %s, n=%d | View=%s | Seed=%s | ROI2=%s',numel(S.FC.subjects),R.groupName,R.n,viewMode,roiName_SINGLE_20260616(R,seedIdx),roiName_SINGLE_20260616(R,roi2Idx)));
catch
end
end

function setSingleFCAxis_SINGLE_20260616(S)
try, set(S.axFCA,'Visible','on','Position',[0.070 0.110 0.840 0.800]); catch, end
try, cla(S.axFCB); set(S.axFCB,'Visible','off'); catch, end
try, cla(S.axFCD); set(S.axFCD,'Visible','off'); catch, end
try, cla(S.axFCP); set(S.axFCP,'Visible','off'); catch, end
end

function plotFCMatrix_SINGLE_20260616(ax,M,clim,titleStr,names,C)
cla(ax);
if isempty(M), fcNoDataLocal(ax,titleStr,C); return; end
imagesc(ax,M); axis(ax,'image');
try, caxis(ax,clim); catch, end
colormap(ax,bwr_SINGLE_20260616(256));
cb = colorbar(ax); try, set(cb,'Color',[1 1 1]); catch, end
set(ax,'Color',C.axisBg,'XColor',C.muted,'YColor',C.muted,'FontName','Arial','FontSize',8,'TickLength',[0 0]);
title(ax,titleStr,'Color',C.txt,'FontWeight','bold','Interpreter','none');
nR = size(M,1); ticks = tickIdx_SINGLE_20260616(nR);
set(ax,'XTick',ticks,'YTick',ticks,'XTickLabel',abbrev_SINGLE_20260616(names(ticks),10),'YTickLabel',abbrev_SINGLE_20260616(names(ticks),10));
try, xtickangle(ax,90); catch, end
end

function plotSeedProfile_SINGLE_20260616(ax,M,seedIdx,R,valTxt,C)
cla(ax);
y = M(seedIdx,:); x = 1:numel(y);
plot(ax,x,y,'LineWidth',2.0);
set(ax,'Color',C.axisBg,'XColor',C.muted,'YColor',C.muted); grid(ax,'on');
title(ax,sprintf('Seed profile: %s | %s',roiName_SINGLE_20260616(R,seedIdx),valTxt),'Color',C.txt,'FontWeight','bold','Interpreter','none');
xlabel(ax,'ROI index','Color',C.txt); ylabel(ax,valTxt,'Color',C.txt);
end

function plotROITrace_SINGLE_20260616(ax,stack,seedIdx,roi2Idx,R,valTxt,C)
cla(ax);
vals = squeeze(stack(seedIdx,roi2Idx,:));
if isempty(vals), vals = NaN; end
plot(ax,1:numel(vals),vals,'-o','LineWidth',1.8,'MarkerSize',6);
set(ax,'Color',C.axisBg,'XColor',C.muted,'YColor',C.muted); grid(ax,'on');
title(ax,sprintf('ROI trace across subjects: %s ↔ %s',roiName_SINGLE_20260616(R,seedIdx),roiName_SINGLE_20260616(R,roi2Idx)),'Color',C.txt,'FontWeight','bold','Interpreter','none');
xlabel(ax,'Subject index','Color',C.txt); ylabel(ax,valTxt,'Color',C.txt);
end

function plotROIPair_SINGLE_20260616(ax,stack,seedIdx,roi2Idx,R,valTxt,C)
cla(ax);
vals = squeeze(stack(seedIdx,roi2Idx,:));
vals = vals(:);
bar(ax,1,mean(vals,'omitnan')); hold(ax,'on');
if numel(vals) > 1
    xj = 1 + linspace(-0.08,0.08,numel(vals));
    plot(ax,xj,vals,'o','MarkerSize',7,'LineWidth',1.5);
end
hold(ax,'off');
set(ax,'XTick',1,'XTickLabel',{'Mean + subjects'},'Color',C.axisBg,'XColor',C.muted,'YColor',C.muted); grid(ax,'on');
title(ax,sprintf('ROI pair: %s ↔ %s | n=%d',roiName_SINGLE_20260616(R,seedIdx),roiName_SINGLE_20260616(R,roi2Idx),numel(vals)),'Color',C.txt,'FontWeight','bold','Interpreter','none');
ylabel(ax,valTxt,'Color',C.txt);
end

function refreshFCRegionPopups_SINGLE_20260616(hFig)
try
    S = guidata(hFig);
    if isempty(S) || ~isfield(S,'FC') || ~isfield(S.FC,'subjects') || isempty(S.FC.subjects), return; end
    subj = S.FC.subjects(1);
    labels = []; names = {};
    try, labels = double(subj.labels(:)); catch, end
    try, names = subj.names(:); catch, end
    if isempty(labels), try, labels = (1:size(subj.R,1))'; catch, labels = []; end, end
    if isempty(names)
        names = cell(numel(labels),1);
        for ii = 1:numel(labels), names{ii} = sprintf('ROI_%g',labels(ii)); end
    end
    items = cell(numel(labels),1);
    for ii = 1:numel(labels)
        nm = strtrimSafe(names{ii}); if numel(nm)>44, nm=[nm(1:41) '...']; end
        items{ii} = sprintf('%g | %s',labels(ii),nm);
    end
    if isempty(items), items = {'No ROI labels'}; end
    if isfield(S,'hFCRegion1') && ishghandle(S.hFCRegion1), set(S.hFCRegion1,'String',items,'Value',min(get(S.hFCRegion1,'Value'),numel(items))); end
    if isfield(S,'hFCRegion2') && ishghandle(S.hFCRegion2), set(S.hFCRegion2,'String',items,'Value',min(max(get(S.hFCRegion2,'Value'),2),numel(items))); end
catch
end
end

function refreshFCSubjectPopup_SINGLE_20260616(hFig)
try
    S = guidata(hFig);
    if isempty(S) || ~isfield(S,'FC') || ~isfield(S.FC,'subjects') || isempty(S.FC.subjects), return; end
    items = cell(numel(S.FC.subjects)+1,1);
    items{1} = 'Group mean';
    for ii = 1:numel(S.FC.subjects)
        nm = sprintf('Subject %d',ii);
        try, nm = strtrimSafe(S.FC.subjects(ii).name); catch, end
        if isempty(nm), nm = sprintf('Subject %d',ii); end
        items{ii+1} = nm;
    end
    if isfield(S,'hFCSubject') && ishghandle(S.hFCSubject), set(S.hFCSubject,'String',items,'Value',1); end
catch
end
end

function M = mean3nan_SINGLE_20260616(X)
[n1,n2,~] = size(X); M = nan(n1,n2);
for r = 1:n1
    for c = 1:n2
        v = squeeze(X(r,c,:)); v = v(isfinite(v));
        if ~isempty(v), M(r,c) = mean(v); end
    end
end
end

function P = pOneSampleApprox_SINGLE_20260616(X)
[n1,n2,n] = size(X); P = nan(n1,n2);
for r = 1:n1
    for c = 1:n2
        v = squeeze(X(r,c,:)); v = v(isfinite(v));
        if numel(v) >= 2
            t = mean(v) ./ (std(v) ./ sqrt(numel(v)) + eps);
            P(r,c) = erfc(abs(t)./sqrt(2)); % normal approx, toolbox-free
        end
    end
end
end

function s = popupString_SINGLE_20260616(S,fieldName,fallback)
s = fallback;
try
    if ~isfield(S,fieldName) || ~ishghandle(S.(fieldName)), return; end
    items = get(S.(fieldName),'String'); val = get(S.(fieldName),'Value');
    if iscell(items), val=max(1,min(val,numel(items))); s=strtrimSafe(items{val});
    else, cc=cellstr(items); val=max(1,min(val,numel(cc))); s=strtrimSafe(cc{val}); end
catch
end
end

function idx = popupIndex_SINGLE_20260616(S,fieldName,fallback)
idx = fallback;
try, if isfield(S,fieldName) && ishghandle(S.(fieldName)), idx = get(S.(fieldName),'Value'); end, catch, end
end

function nm = roiName_SINGLE_20260616(R,idx)
nm = sprintf('ROI_%d',idx);
try
    if idx >= 1 && idx <= numel(R.names)
        nm = strtrimSafe(R.names{idx});
        if numel(nm) > 34, nm = [nm(1:31) '...']; end
    end
catch
end
end

function ticks = tickIdx_SINGLE_20260616(nR)
if nR <= 35, step = 1; elseif nR <= 70, step = 2; elseif nR <= 120, step = 4; elseif nR <= 200, step = 6; else, step = max(8,ceil(nR/30)); end
ticks = 1:step:nR;
end

function out = abbrev_SINGLE_20260616(names,n)
if nargin < 2, n = 10; end
out = names;
for ii = 1:numel(out)
    s = strtrimSafe(out{ii});
    s = regexprep(s,'\s*\[[^\]]*\]\s*$','');
    parts = regexp(s,'\s+','split'); if ~isempty(parts), s = parts{1}; end
    if numel(s) > n, s = [s(1:max(1,n-3)) '...']; end
    out{ii} = s;
end
end

function cmap = bwr_SINGLE_20260616(n)
if nargin < 1, n = 256; end
n1 = floor(n/2); n2 = n - n1;
b = [0.00 0.25 0.95]; w = [1.00 1.00 1.00]; r = [0.95 0.20 0.20];
c1 = [linspace(b(1),w(1),n1)' linspace(b(2),w(2),n1)' linspace(b(3),w(3),n1)'];
c2 = [linspace(w(1),r(1),n2)' linspace(w(2),r(2),n2)' linspace(w(3),r(3),n2)'];
cmap = [c1; c2];
end
% GA_FC_SINGLE_CLEAN_HELPERS_20260616_END

% GA_FC_CALLFC_AUTOCOMPUTE_20260617_START
function G = alignFCSubjectsToCommonROIs_SINGLE_DIRECT_20260617(FC)
% Local/direct equivalent of GroupAnalysis_FC('alignFCSubjectsToCommonROIs',FC).
% Needed because appended helper functions cannot see nested callFC().
if ~isfield(FC,'subjects') || isempty(FC.subjects)
    error('No FC subjects loaded.');
end

nSub = numel(FC.subjects);
labels0 = getFCLabels_SINGLE_DIRECT_20260617(FC.subjects(1));
commonLabels = labels0(:);

for ii = 2:nSub
    labs = getFCLabels_SINGLE_DIRECT_20260617(FC.subjects(ii));
    commonLabels = intersect(commonLabels,labs(:));
end
commonLabels = sort(commonLabels(:));
if isempty(commonLabels)
    error('No common ROI labels found across FC subjects.');
end

nR = numel(commonLabels);
Zstack = nan(nR,nR,nSub);
Rstack = nan(nR,nR,nSub);
names = cell(nR,1);

for ii = 1:nSub
    subj = FC.subjects(ii);
    labs = getFCLabels_SINGLE_DIRECT_20260617(subj);
    [Rmat,Zmat] = getFCMatrices_SINGLE_DIRECT_20260617(subj);
    idx = nan(nR,1);
    for kk = 1:nR
        hit = find(double(labs) == double(commonLabels(kk)),1,'first');
        if ~isempty(hit), idx(kk) = hit; end
    end
    if any(~isfinite(idx))
        error('Internal FC ROI alignment error.');
    end
    idx = double(idx(:));
    Rstack(:,:,ii) = Rmat(idx,idx);
    Zstack(:,:,ii) = Zmat(idx,idx);
    if ii == 1
        nms = getFCNames_SINGLE_DIRECT_20260617(subj,labs);
        for kk = 1:nR
            srcIdx = idx(kk);
            if srcIdx <= numel(nms)
                names{kk} = strtrimSafe(nms{srcIdx});
            else
                names{kk} = sprintf('ROI_%g',commonLabels(kk));
            end
        end
    end
end

G = struct();
G.labels = commonLabels;
G.names = names;
G.Zstack = Zstack;
G.Rstack = Rstack;
G.nSubjects = nSub;
G.subjectNames = cell(nSub,1);
G.groups = cell(nSub,1);
G.sourceFiles = cell(nSub,1);
for ii = 1:nSub
    try, G.subjectNames{ii} = strtrimSafe(FC.subjects(ii).name); catch, G.subjectNames{ii} = sprintf('Subject_%02d',ii); end
    try, G.groups{ii} = strtrimSafe(FC.subjects(ii).group); catch, G.groups{ii} = 'Unassigned'; end
    if isempty(G.groups{ii}), G.groups{ii} = 'Unassigned'; end
    try, G.sourceFiles{ii} = strtrimSafe(FC.subjects(ii).sourceFile); catch, G.sourceFiles{ii} = ''; end
end
end

function labs = getFCLabels_SINGLE_DIRECT_20260617(subj)
labs = [];
try, if isfield(subj,'labels') && ~isempty(subj.labels), labs = double(subj.labels(:)); end, catch, end
try, if isempty(labs) && isfield(subj,'displayLabels') && ~isempty(subj.displayLabels), labs = double(subj.displayLabels(:)); end, catch, end
if isempty(labs)
    try
        [Rmat,~] = getFCMatrices_SINGLE_DIRECT_20260617(subj);
        labs = (1:size(Rmat,1))';
    catch
        labs = [];
    end
end
end

function names = getFCNames_SINGLE_DIRECT_20260617(subj,labs)
names = {};
try, if isfield(subj,'names') && ~isempty(subj.names), names = subj.names(:); end, catch, end
try, if isempty(names) && isfield(subj,'displayNames') && ~isempty(subj.displayNames), names = subj.displayNames(:); end, catch, end
if isempty(names)
    names = cell(numel(labs),1);
    for ii = 1:numel(labs)
        names{ii} = sprintf('ROI_%g',labs(ii));
    end
end
try
    fn = {};
    if isfield(subj,'fullNames') && ~isempty(subj.fullNames), fn = subj.fullNames(:); end
    if ~isempty(fn)
        for ii = 1:min(numel(names),numel(fn))
            fni = strtrimSafe(fn{ii});
            if ~isempty(fni) && isempty(strfind(char(names{ii}),'||'))
                names{ii} = [strtrimSafe(names{ii}) ' || ' fni];
            end
        end
    end
catch
end
end

function [Rmat,Zmat] = getFCMatrices_SINGLE_DIRECT_20260617(subj)
Rmat = [];
Zmat = [];
try, if isfield(subj,'R') && ~isempty(subj.R), Rmat = double(subj.R); end, catch, end
try, if isempty(Rmat) && isfield(subj,'displayMatrix') && ~isempty(subj.displayMatrix), Rmat = double(subj.displayMatrix); end, catch, end
try, if isempty(Rmat) && isfield(subj,'corrMatrix') && ~isempty(subj.corrMatrix), Rmat = double(subj.corrMatrix); end, catch, end
try, if isempty(Rmat) && isfield(subj,'matrix') && ~isempty(subj.matrix), Rmat = double(subj.matrix); end, catch, end

try, if isfield(subj,'Z') && ~isempty(subj.Z), Zmat = double(subj.Z); end, catch, end
try, if isempty(Zmat) && isfield(subj,'displayZ') && ~isempty(subj.displayZ), Zmat = double(subj.displayZ); end, catch, end

if isempty(Rmat) && ~isempty(Zmat)
    Rmat = tanh(Zmat);
end
if isempty(Zmat) && ~isempty(Rmat)
    Rc = max(-0.999999,min(0.999999,Rmat));
    Zmat = atanh(Rc);
    try, Zmat(1:size(Zmat,1)+1:end) = 0; catch, end
end
if isempty(Rmat) || isempty(Zmat)
    error('FC subject does not contain a usable R/Z matrix.');
end
end
% GA_FC_CALLFC_AUTOCOMPUTE_20260617_END

% GA_FC_ADVANCED_DISPLAY_HELPERS_20260617_START
function R = computeSingleGroupFC_ADV_20260617(S)
% Single-group FC-GA with animal, group, slice filtering.
G = alignFCSubjectsWithOptions_ADV_20260617(S);
groupSel = popupString_SINGLE_20260616(S,'hFCGroupA','All loaded');
idx = true(numel(G.groups),1);
if ~isempty(groupSel) && ~strcmpi(groupSel,'All loaded') && ~strcmpi(groupSel,'All')
    idx = strcmpi(G.groups,groupSel);
    if ~any(idx)
        idx = true(numel(G.groups),1);
        groupSel = 'All loaded';
    end
end
try
    if isfield(S,'fcSelectedSubjectIdx') && ~isempty(S.fcSelectedSubjectIdx)
        keep = false(numel(idx),1);
        keep(S.fcSelectedSubjectIdx(S.fcSelectedSubjectIdx>=1 & S.fcSelectedSubjectIdx<=numel(idx))) = true;
        idx = idx & keep;
        if ~any(idx), idx = keep; end
    end
catch
end
if ~any(idx), error('No FC animals selected for the current group/slice.'); end
Z = G.Zstack(:,:,idx);
Rstack = G.Rstack(:,:,idx);
meanZ = mean3nan_SINGLE_20260616(Z);
meanR = tanh(meanZ);
pMat = pOneSampleApprox_SINGLE_20260616(Z);
R = struct();
R.mode = 'Functional Connectivity Single Group Advanced';
R.groupName = groupSel;
R.groupA = groupSel;
R.groupB = '';
R.n = sum(idx);
R.nA = sum(idx);
R.nB = 0;
R.labels = G.labels;
R.names = G.names;
R.meanZ = meanZ;
R.meanR = meanR;
R.meanZA = meanZ;
R.meanRA = meanR;
R.meanZB = nan(size(meanZ));
R.meanRB = nan(size(meanR));
R.diffZ = nan(size(meanZ));
R.diffR = nan(size(meanR));
R.pMat = pMat;
R.Zstack = Z;
R.Rstack = Rstack;
R.subjectNames = G.subjectNames(idx);
R.groups = G.groups(idx);
R.sourceFiles = G.sourceFiles(idx);
R.sliceMode = G.sliceMode;
R.note = 'Single-group FC-GA: mean is computed in Fisher z space; Pearson r = tanh(mean z).';
end

function G = alignFCSubjectsWithOptions_ADV_20260617(S)
FC = S.FC;
if ~isfield(FC,'subjects') || isempty(FC.subjects), error('No FC subjects loaded.'); end
sliceMode = popupString_SINGLE_20260616(S,'hFCSlice','All slices');
nSub = numel(FC.subjects);
labs0 = getFCLabels_SINGLE_DIRECT_20260617(FC.subjects(1));
commonLabels = labs0(:);
for ii = 2:nSub
    labs = getFCLabels_SINGLE_DIRECT_20260617(FC.subjects(ii));
    commonLabels = intersect(commonLabels,labs(:));
end
commonLabels = sort(commonLabels(:));
if isempty(commonLabels), error('No common ROI labels found across FC subjects.'); end
nR = numel(commonLabels);
Zstack = nan(nR,nR,nSub);
Rstack = nan(nR,nR,nSub);
names = cell(nR,1);
for ii = 1:nSub
    subj = FC.subjects(ii);
    labs = getFCLabels_SINGLE_DIRECT_20260617(subj);
    [Rmat,Zmat] = getFCMatricesForSlice_ADV_20260617(subj,sliceMode);
    idx = nan(nR,1);
    for kk = 1:nR
        hit = find(double(labs) == double(commonLabels(kk)),1,'first');
        if ~isempty(hit), idx(kk) = hit; end
    end
    if any(~isfinite(idx)), error('Internal FC ROI alignment error.'); end
    idx = double(idx(:));
    Rstack(:,:,ii) = Rmat(idx,idx);
    Zstack(:,:,ii) = Zmat(idx,idx);
    if ii == 1
        nms = getFCNames_SINGLE_DIRECT_20260617(subj,labs);
        for kk = 1:nR
            srcIdx = idx(kk);
            if srcIdx <= numel(nms), names{kk} = strtrimSafe(nms{srcIdx}); else, names{kk}=sprintf('ROI_%g',commonLabels(kk)); end
        end
    end
end
G = struct();
G.labels = commonLabels;
G.names = names;
G.Zstack = Zstack;
G.Rstack = Rstack;
G.nSubjects = nSub;
G.subjectNames = cell(nSub,1);
G.groups = cell(nSub,1);
G.sourceFiles = cell(nSub,1);
G.sliceMode = sliceMode;
for ii = 1:nSub
    try, G.subjectNames{ii}=strtrimSafe(FC.subjects(ii).name); catch, G.subjectNames{ii}=sprintf('Subject_%02d',ii); end
    try, G.groups{ii}=strtrimSafe(FC.subjects(ii).group); catch, G.groups{ii}='Unassigned'; end
    if isempty(G.groups{ii}), G.groups{ii}='Unassigned'; end
    try, G.sourceFiles{ii}=strtrimSafe(FC.subjects(ii).sourceFile); catch, G.sourceFiles{ii}=''; end
end
end

function [Rmat,Zmat] = getFCMatricesForSlice_ADV_20260617(subj,sliceMode)
% Uses subject-level R/Z by default; if sliceResults exist, can select/average slices.
if nargin < 2 || isempty(sliceMode), sliceMode = 'All slices'; end
useSlice = NaN;
tok = regexp(sliceMode,'(\d+)','tokens','once');
if ~isempty(tok), useSlice = str2double(tok{1}); end
hasSlices = isfield(subj,'sliceResults') && ~isempty(subj.sliceResults);
if hasSlices
    SR = subj.sliceResults;
    if isfinite(useSlice)
        z = max(1,min(round(useSlice),numel(SR)));
        [Rmat,Zmat] = getMatrixFromStruct_ADV_20260617(SR(z));
        if ~isempty(Rmat), return; end
    else
        Zs = {};
        Rs = {};
        for zz = 1:numel(SR)
            [Rz,Zz] = getMatrixFromStruct_ADV_20260617(SR(zz));
            if ~isempty(Rz) && ~isempty(Zz)
                Rs{end+1} = Rz; %#ok<AGROW>
                Zs{end+1} = Zz; %#ok<AGROW>
            end
        end
        if ~isempty(Zs)
            Zcat = cat(3,Zs{:});
            Zmat = mean3nan_SINGLE_20260616(Zcat);
            Rmat = tanh(Zmat);
            return;
        end
    end
end
[Rmat,Zmat] = getFCMatrices_SINGLE_DIRECT_20260617(subj);
end

function [Rmat,Zmat] = getMatrixFromStruct_ADV_20260617(X)
Rmat=[]; Zmat=[];
try, if isfield(X,'R') && ~isempty(X.R), Rmat=double(X.R); end, catch, end
try, if isempty(Rmat) && isfield(X,'displayMatrix') && ~isempty(X.displayMatrix), Rmat=double(X.displayMatrix); end, catch, end
try, if isempty(Rmat) && isfield(X,'corrMatrix') && ~isempty(X.corrMatrix), Rmat=double(X.corrMatrix); end, catch, end
try, if isempty(Rmat) && isfield(X,'matrix') && ~isempty(X.matrix), Rmat=double(X.matrix); end, catch, end
try, if isfield(X,'Z') && ~isempty(X.Z), Zmat=double(X.Z); end, catch, end
try, if isempty(Zmat) && isfield(X,'displayZ') && ~isempty(X.displayZ), Zmat=double(X.displayZ); end, catch, end
if isempty(Rmat) && ~isempty(Zmat), Rmat=tanh(Zmat); end
if isempty(Zmat) && ~isempty(Rmat)
    Rc=max(-0.999999,min(0.999999,Rmat)); Zmat=atanh(Rc); try, Zmat(1:size(Zmat,1)+1:end)=0; catch, end
end
end

function [M2,names2,labels2,rowIdx,colIdx,titleTxt] = applyHemisphereMode_ADV_20260617(M,names,labels,mode)
mode = lower(strtrimSafe(mode));
labels = double(labels(:));
L = labels < 0;
R = labels > 0;
if ~any(L), L = contains(lower(names),'l_') | contains(lower(names),'left'); end
if ~any(R), R = contains(lower(names),'r_') | contains(lower(names),'right'); end
if contains(mode,'left vs right')
    rowIdx=find(L); colIdx=find(R);
    if isempty(rowIdx) || isempty(colIdx), rowIdx=1:size(M,1); colIdx=1:size(M,2); end
    M2=M(rowIdx,colIdx); names2=names(colIdx); labels2=labels(colIdx); titleTxt='Left rows × Right columns';
elseif contains(mode,'left') && ~contains(mode,'right')
    rowIdx=find(L); colIdx=rowIdx; if isempty(rowIdx), rowIdx=1:size(M,1); colIdx=rowIdx; end
    M2=M(rowIdx,colIdx); names2=names(rowIdx); labels2=labels(rowIdx); titleTxt='Left only';
elseif contains(mode,'right') && ~contains(mode,'left')
    rowIdx=find(R); colIdx=rowIdx; if isempty(rowIdx), rowIdx=1:size(M,1); colIdx=rowIdx; end
    M2=M(rowIdx,colIdx); names2=names(rowIdx); labels2=labels(rowIdx); titleTxt='Right only';
elseif contains(mode,'merged')
    [M2,names2,labels2] = mergeLRMatrix_ADV_20260617(M,names,labels);
    rowIdx=1:numel(labels2); colIdx=rowIdx; titleTxt='Merged L+R homologs';
else
    rowIdx=1:size(M,1); colIdx=1:size(M,2); M2=M; names2=names; labels2=labels; titleTxt='All ROIs';
end
end

function [Mm,namesM,labelsM] = mergeLRMatrix_ADV_20260617(M,names,labels)
labels = double(labels(:));
if any(labels < 0) && any(labels > 0)
    ids = unique(abs(labels)); ids = ids(ids>0);
else
    ids = (1:numel(labels))';
end
n = numel(ids); Mm = nan(n,n); namesM = cell(n,1); labelsM = ids(:);
for i=1:n
    ii=find(abs(labels)==ids(i)); if isempty(ii), ii=i; end
    namesM{i}=cleanLRName_ADV_20260617(names{ii(1)});
    for j=1:n
        jj=find(abs(labels)==ids(j)); if isempty(jj), jj=j; end
        block=M(ii,jj); v=block(isfinite(block)); if ~isempty(v), Mm(i,j)=mean(v); end
    end
end
end

function s = cleanLRName_ADV_20260617(s)
s = strtrimSafe(s);
s = regexprep(s,'(?i)\b[LR]_','');
s = regexprep(s,'(?i)\b(left|right)\b','');
s = regexprep(s,'\[-?\d+\]','');
s = strtrim(regexprep(s,'\s+',' '));
end

function cm = cmapFC_ADV_20260617(name,n)
if nargin < 2, n = 256; end
name = lower(strtrimSafe(name));
switch name
    case {'blue-white','blue white','bluewhite','bw'}
        cm = fcCmapBlueWhite_20260622(n);
    case {'blue-white-red','blue white red','bwr'}
        cm = fcCmapBlueWhiteRed_20260622(n);
    case {'red-white-blue','red white blue','rwb'}
        cm = flipud(fcCmapBlueWhiteRed_20260622(n));
    case 'parula'
        try, cm = parula(n); catch, cm = jet(n); end
    case 'hot'
        cm = hot(n);
    case 'jet'
        cm = jet(n);
    case 'gray'
        cm = gray(n);
    case {'blackbody','blackbdy_iso'}
        if exist('blackbdy_iso','file')==2, cm=blackbdy_iso(n); else, cm=hot(n); end
    otherwise
        cm = fcCmapBlueWhite_20260622(n);
end
end

function cm = fcCmapBlueWhite_20260622(n)
t = linspace(0,1,n)';
cm = [t t ones(n,1)];
end

function cm = fcCmapBlueWhiteRed_20260622(n)
n1 = floor(n/2); n2 = n - n1;
t1 = linspace(0,1,n1)';
t2 = linspace(0,1,n2)';
blueToWhite = [t1 t1 ones(n1,1)];
whiteToRed  = [ones(n2,1) 1-t2 1-t2];
cm = [blueToWhite; whiteToRed];
end

function [map2,note] = findROIOverlayMap_ADV_20260617(S)
map2=[]; note='';
try
    if ~isfield(S,'FC') || ~isfield(S.FC,'subjects') || isempty(S.FC.subjects), return; end
    fns={'roiMap','labelMap','parcelMap','labelMask','roiLabelMask','roiAtlas','atlasLabels2D','maskLabels','segmentationMap','segMap','labels2D'};
    subj=S.FC.subjects(1);
    for ii=1:numel(fns)
        if isfield(subj,fns{ii}) && isnumeric(subj.(fns{ii})) && ~isempty(subj.(fns{ii}))
            map2=subj.(fns{ii}); note=fns{ii}; return;
        end
    end
    if isfield(subj,'sliceResults') && ~isempty(subj.sliceResults)
        SR=subj.sliceResults;
        for zz=1:numel(SR)
            for ii=1:numel(fns)
                if isfield(SR(zz),fns{ii}) && isnumeric(SR(zz).(fns{ii})) && ~isempty(SR(zz).(fns{ii}))
                    map2=SR(zz).(fns{ii}); note=sprintf('%s slice %d',fns{ii},zz); return;
                end
            end
        end
    end
catch
end
end

function refreshFCSlicePopup_CLEAN_20260617(hFig)
try
    S=guidata(hFig); if isempty(S)||~isfield(S,'FC')||~isfield(S.FC,'subjects')||isempty(S.FC.subjects), return; end
    nZ=1;
    for ii=1:numel(S.FC.subjects)
        subj=S.FC.subjects(ii);
        try, if isfield(subj,'nSlices') && ~isempty(subj.nSlices), nZ=max(nZ,double(subj.nSlices)); end, catch, end
        try, if isfield(subj,'sliceResults') && ~isempty(subj.sliceResults), nZ=max(nZ,numel(subj.sliceResults)); end, catch, end
    end
    items=cell(nZ+1,1); items{1}='All slices'; for z=1:nZ, items{z+1}=sprintf('Slice %d',z); end
    if isfield(S,'hFCSlice')&&ishghandle(S.hFCSlice), set(S.hFCSlice,'String',items,'Value',min(get(S.hFCSlice,'Value'),numel(items))); end
catch
end
end



function exportFCHighResPNG_ADV_20260617(hFig)
try
    S=guidata(hFig); outDir=''; try,outDir=fullfile(S.outDir,'FunctionalConnectivity_GroupAnalysis');catch,end; if isempty(outDir),outDir=fullfile(pwd,'FunctionalConnectivity_GroupAnalysis');end; if exist(outDir,'dir')~=7,mkdir(outDir);end
    viewMode=popupString_SINGLE_20260616(S,'hFCView','FC'); viewMode=sanitizeFilename(viewMode);
    outFile=fullfile(outDir,sprintf('FCGA_%s_%s.png',viewMode,datestr(now,'yyyymmdd_HHMMSS')));
    f=figure('Visible','off','Color',S.C.bg,'InvertHardcopy','off','MenuBar','none','ToolBar','none','NumberTitle','off','Position',[100 100 2200 1800]);
    ax2=copyobj(S.axFCA,f); set(ax2,'Units','normalized','Position',[0.08 0.10 0.78 0.80]);
    set(f,'PaperPositionMode','auto'); print(f,outFile,'-dpng','-r300'); close(f);
    try,set(S.hFCInfo,'String',['Exported high-res PNG: ' outFile]);catch,end
    fprintf('Exported FC-GA PNG:\n%s\n',outFile);
catch ME, try,errordlg(ME.message,'Export FC PNG');catch,end
end
end

function m=nanmean_local_ADV_20260617(X,dim)
if nargin<2,dim=1;end; X=double(X); ok=isfinite(X); X(~ok)=0; n=sum(ok,dim); m=sum(X,dim)./max(n,1); m(n==0)=NaN;
end
function s=nanstd_local_ADV_20260617(X,flag,dim)
if nargin<2,flag=0;end; if nargin<3,dim=1;end; mu=nanmean_local_ADV_20260617(X,dim); sz=ones(1,ndims(X)); sz(dim)=size(X,dim); muRep=repmat(mu,sz); D=(X-muRep).^2; D(~isfinite(D))=NaN; v=nanmean_local_ADV_20260617(D,dim); s=sqrt(v);
end
% GA_FC_ADVANCED_DISPLAY_HELPERS_20260617_END




% GA_FC_CLEAN_LABELS_20260617_START




% GA_FC_SAFE_VIEWER_20260617_START
function refreshFCRegionPopups_SAFE_20260617(hFig)
try
    S = guidata(hFig);
    if isempty(S) || ~isfield(S,'FC') || ~isfield(S.FC,'subjects') || isempty(S.FC.subjects), return; end
    subj = S.FC.subjects(1);
    labels = fcGetLabels_SAFE_20260617(subj);
    names  = fcGetNames_SAFE_20260617(subj,labels);
    items = cell(numel(labels),1);
    for kk = 1:numel(labels)
        items{kk} = fcNiceName_SAFE_20260617(names{kk},labels(kk),'Abbrev',false);
    end
    if isempty(items), items = {'No ROI labels'}; end
    if isfield(S,'hFCRegion1') && ishghandle(S.hFCRegion1)
        set(S.hFCRegion1,'String',items,'Value',min(get(S.hFCRegion1,'Value'),numel(items)));
    end
    if isfield(S,'hFCRegion2') && ishghandle(S.hFCRegion2)
        set(S.hFCRegion2,'String',items,'Value',min(max(get(S.hFCRegion2,'Value'),2),numel(items)));
    end
catch
end
end

function selectFCAnimals_SAFE_20260617(hFig)
try
    S = guidata(hFig);
    if isempty(S) || ~isfield(S,'FC') || ~isfield(S.FC,'subjects') || isempty(S.FC.subjects), return; end
    names = cell(numel(S.FC.subjects),1);
    for kk = 1:numel(S.FC.subjects)
        try, names{kk} = strtrimSafe(S.FC.subjects(kk).name); catch, names{kk} = sprintf('Subject %d',kk); end
        if isempty(names{kk}), names{kk} = sprintf('Subject %d',kk); end
    end
    init = 1:numel(names);
    try, if isfield(S,'fcSelectedSubjectIdx') && ~isempty(S.fcSelectedSubjectIdx), init = S.fcSelectedSubjectIdx; end, catch, end
    [sel,ok] = listdlg('PromptString','Select animals included in FC-GA:','SelectionMode','multiple','ListString',names,'InitialValue',init,'ListSize',[420 320]);
    if ok
        S.fcSelectedSubjectIdx = sel(:);
        S.lastFC = struct();
        guidata(hFig,S);
        fcTriggerPreview_SAFE_20260617(hFig);
    end
catch ME
    try, errordlg(ME.message,'FC animals'); catch, end
end
end

function selectFCRegions_SAFE_20260617(hFig)
try
    S = guidata(hFig);
    if isempty(S) || ~isfield(S,'FC') || ~isfield(S.FC,'subjects') || isempty(S.FC.subjects), return; end
    subj = S.FC.subjects(1);
    labels = fcGetLabels_SAFE_20260617(subj);
    names  = fcGetNames_SAFE_20260617(subj,labels);
    items = cell(numel(labels),1);
    for kk = 1:numel(labels)
        items{kk} = sprintf('%g | %s',labels(kk),fcNiceName_SAFE_20260617(names{kk},labels(kk),'Full',false));
    end
    init = 1:numel(items);
    try, if isfield(S,'fcSelectedROIIdx') && ~isempty(S.fcSelectedROIIdx), init = S.fcSelectedROIIdx; end, catch, end
    [sel,ok] = listdlg('PromptString','Select regions shown in FC-GA plots:','SelectionMode','multiple','ListString',items,'InitialValue',init,'ListSize',[540 420]);
    if ok
        S.fcSelectedROIIdx = sel(:);
        S.lastFC = struct();
        guidata(hFig,S);
        fcTriggerPreview_SAFE_20260617(hFig);
    end
catch ME
    try, errordlg(ME.message,'FC regions'); catch, end
end
end

function showFCRegionNames_SAFE_20260617(hFig)
try
    S = guidata(hFig);
    if isempty(S) || ~isfield(S,'FC') || ~isfield(S.FC,'subjects') || isempty(S.FC.subjects), return; end
    subj = S.FC.subjects(1);
    labels = fcGetLabels_SAFE_20260617(subj);
    names  = fcGetNames_SAFE_20260617(subj,labels);
    f = figure('Name','FC ROI names / select regions','Color',[0.08 0.08 0.08],'MenuBar','none','ToolBar','none','NumberTitle','off','Position',[160 80 1050 780]);
    setappdata(f,'hFigGA',hFig);
    setappdata(f,'fcLabels',labels(:));
    setappdata(f,'fcNames',names(:));
    uicontrol(f,'Style','text','String','Search:','Units','normalized','Position',[0.03 0.940 0.07 0.035],'BackgroundColor',[0.08 0.08 0.08],'ForegroundColor',[1 1 1],'FontWeight','bold','HorizontalAlignment','left');
    hSearch = uicontrol(f,'Style','edit','String','','Units','normalized','Position',[0.10 0.940 0.28 0.040],'BackgroundColor',[0.12 0.12 0.14],'ForegroundColor',[1 1 1]);
    uicontrol(f,'Style','text','String','Show:','Units','normalized','Position',[0.41 0.940 0.06 0.035],'BackgroundColor',[0.08 0.08 0.08],'ForegroundColor',[1 1 1],'FontWeight','bold','HorizontalAlignment','left');
    hHemi = uicontrol(f,'Style','popupmenu','String',{'Merged L/R','Left only','Right only','Both separate'},'Units','normalized','Position',[0.47 0.940 0.17 0.040],'BackgroundColor',[0.12 0.12 0.14],'ForegroundColor',[1 1 1]);
    hTable = uitable('Parent',f,'Units','normalized','Position',[0.03 0.095 0.94 0.825],'Data',{},'ColumnName',{'Include','Label','Abbrev','Full region name','Indices'},'ColumnEditable',[true false false false false],'RowName',[],'ColumnWidth',{70 90 180 560 110},'FontName','Arial','FontSize',12);
    set(hSearch,'Callback',@(src,evt)fcGARefreshNameTable_20260622(f));
    set(hHemi,'Callback',@(src,evt)fcGARefreshNameTable_20260622(f));
    setappdata(f,'hSearch',hSearch); setappdata(f,'hHemi',hHemi); setappdata(f,'hTable',hTable);
    uicontrol(f,'Style','pushbutton','String','Apply selection','Units','normalized','Position',[0.03 0.025 0.18 0.050],'BackgroundColor',[0.10 0.45 0.95],'ForegroundColor','w','FontWeight','bold','Callback',@(src,evt)fcGAApplyNameTableSelection_20260622(f));
    uicontrol(f,'Style','pushbutton','String','All shown','Units','normalized','Position',[0.23 0.025 0.10 0.050],'Callback',@(src,evt)fcGASetShownInclude_20260622(f,true));
    uicontrol(f,'Style','pushbutton','String','None shown','Units','normalized','Position',[0.35 0.025 0.12 0.050],'Callback',@(src,evt)fcGASetShownInclude_20260622(f,false));
    uicontrol(f,'Style','pushbutton','String','Close','Units','normalized','Position',[0.82 0.025 0.15 0.050],'BackgroundColor',[0.7 0.1 0.1],'ForegroundColor','w','FontWeight','bold','Callback',@(src,evt)delete(f));
    fcGARefreshNameTable_20260622(f);
catch ME
    try, errordlg(ME.message,'FC names'); catch, end
end
end

function fcTriggerPreview_SAFE_20260617(hFig)
try
    S = guidata(hFig);
    if isfield(S,'hFCView') && ishghandle(S.hFCView)
        cb = get(S.hFCView,'Callback');
        if isa(cb,'function_handle')
            feval(cb,S.hFCView,[]);
        end
    end
catch ME
    try, S = guidata(hFig); set(S.hFCInfo,'String',['FC refresh failed: ' ME.message]); catch, end
end
end

function labs = fcMakeLabels_SAFE_20260617(names,labels,labelMode,hemiTitle)
n = numel(names); labs = cell(n,1);
stripSide = fcStripSideForHemi_SAFE_20260617(hemiTitle);
for kk = 1:n
    labs{kk} = fcNiceName_SAFE_20260617(names{kk},labels(kk),labelMode,stripSide);
end
end

function s = fcSide_SAFE_20260617(raw,label)
s = ''; r = lower(strtrimSafe(raw));
if startsWith(r,'l_') || startsWith(r,'l-') || contains(r,'left'), s = 'L'; return; end
if startsWith(r,'r_') || startsWith(r,'r-') || contains(r,'right'), s = 'R'; return; end
try, if label < 0, s = 'L'; elseif label > 0, s = 'R'; end, catch, end
end

function tf = fcStripSideForHemi_SAFE_20260617(hemiTitle)
h = lower(strtrimSafe(hemiTitle));
tf = contains(h,'left only') || contains(h,'right only') || contains(h,'merged');
end

function [xl,yl] = fcHemiAxis_SAFE_20260617(hemiTitle)
h = lower(strtrimSafe(hemiTitle));
if contains(h,'left rows')
    xl = 'Right hemisphere regions'; yl = 'Left hemisphere regions';
elseif contains(h,'left only')
    xl = 'Left hemisphere regions'; yl = 'Left hemisphere regions';
elseif contains(h,'right only')
    xl = 'Right hemisphere regions'; yl = 'Right hemisphere regions';
elseif contains(h,'merged')
    xl = 'Merged bilateral regions'; yl = 'Merged bilateral regions';
else
    xl = 'Regions'; yl = 'Regions';
end
end

function full = fcFullName_SAFE_20260617(acr)
a = lower(regexprep(strtrimSafe(acr),'[^a-z0-9]',''));
switch a
    case 'cpu', full = 'caudate putamen';
    case 'alv', full = 'alveus';
    case 'cc', full = 'corpus callosum';
    case 'aca', full = 'anterior commissure anterior';
    case 'acp', full = 'anterior commissure posterior';
    case 'fi', full = 'fimbria';
    case 'hip', full = 'hippocampus';
    case 'ca1', full = 'cornu ammonis 1';
    case 'ca2', full = 'cornu ammonis 2';
    case 'ca3', full = 'cornu ammonis 3';
    case 'dg', full = 'dentate gyrus';
    case 'th', full = 'thalamus';
    case 'hyp', full = 'hypothalamus';
    case 'ctx', full = 'cortex';
    case 'str', full = 'striatum';
    case 'gp', full = 'globus pallidus';
    case 'ic', full = 'internal capsule';
    case 'ec', full = 'external capsule';
    case 'ot', full = 'optic tract';
    case 'amy', full = 'amygdala';
    case 'sn', full = 'substantia nigra';
    case 'pag', full = 'periaqueductal gray';
    otherwise, full = acr;
end
end

function idx = fcTickIdx_SAFE_20260617(n,maxTicks)
if n <= maxTicks, idx = 1:n; else, step = ceil(n/maxTicks); idx = 1:step:n; if idx(end) ~= n, idx = [idx n]; end, end
end

function labels = fcGetLabels_SAFE_20260617(subj)
labels = [];
try, if isfield(subj,'labels') && ~isempty(subj.labels), labels = double(subj.labels(:)); end, catch, end
try, if isempty(labels) && isfield(subj,'displayLabels') && ~isempty(subj.displayLabels), labels = double(subj.displayLabels(:)); end, catch, end
if isempty(labels)
    try, labels = (1:size(subj.R,1))'; catch, labels = []; end
end
end

function names = fcGetNames_SAFE_20260617(subj,labels)
names = {};
try, if isfield(subj,'names') && ~isempty(subj.names), names = subj.names(:); end, catch, end
try, if isempty(names) && isfield(subj,'displayNames') && ~isempty(subj.displayNames), names = subj.displayNames(:); end, catch, end
if isempty(names), names = arrayfun(@(x)sprintf('ROI_%g',x),labels(:),'UniformOutput',false); end
try
    fn = {};
    if isfield(subj,'fullNames') && ~isempty(subj.fullNames), fn = subj.fullNames(:); end
    if ~isempty(fn)
        for ii = 1:min(numel(names),numel(fn))
            fni = strtrimSafe(fn{ii});
            if ~isempty(fni) && isempty(strfind(char(names{ii}),'||'))
                names{ii} = [strtrimSafe(names{ii}) ' || ' fni];
            end
        end
    end
catch
end
end

function cm = cmapFC_SAFE_20260617(name,n)
cm = cmapFC_ADV_20260617(name,n);
end

function v = fcNanMean_SAFE_20260617(X,dim)
if nargin < 2, dim = 1; end
X = double(X); ok = isfinite(X); X(~ok)=0; n=sum(ok,dim); v=sum(X,dim)./max(n,1); v(n==0)=NaN;
end

function s = fcNanStd_SAFE_20260617(X,dim)
if nargin < 2, dim = 1; end
mu = fcNanMean_SAFE_20260617(X,dim); sz = ones(1,ndims(X)); sz(dim)=size(X,dim); D=(X-repmat(mu,sz)).^2; s=sqrt(fcNanMean_SAFE_20260617(D,dim));
end

function fcApplyY_SAFE_20260617(ax,S)
try
    autoY = true; try, autoY = logical(get(S.hFCYAuto,'Value')); catch, end
    y0 = NaN; y1 = NaN; ys = NaN;
    try, y0 = str2double(strrep(get(S.hFCYMin,'String'),',','.')); catch, end
    try, y1 = str2double(strrep(get(S.hFCYMax,'String'),',','.')); catch, end
    try, ys = str2double(strrep(get(S.hFCYStep,'String'),',','.')); catch, end
    if ~autoY && isfinite(y0) && isfinite(y1) && y1 > y0
        ylim(ax,[y0 y1]);
    end
    if isfinite(ys) && ys > 0
        yl = ylim(ax);
        yt = yl(1):ys:yl(2);
        if numel(yt) >= 2 && numel(yt) <= 40, set(ax,'YTick',yt); end
    end
catch
end
end

function col = fcGetPlotColor_SAFE_20260622(S,defaultCol)
col = defaultCol;
try
    if isfield(S,'hFCPlotColor') && ishghandle(S.hFCPlotColor)
        items = get(S.hFCPlotColor,'String'); v = get(S.hFCPlotColor,'Value');
        if iscell(items), nm = lower(strtrimSafe(items{max(1,min(v,numel(items)))})); else, cc = cellstr(items); nm = lower(strtrimSafe(cc{max(1,min(v,numel(cc)))})); end
        switch nm
            case 'blue',   col = [0.10 0.45 0.95];
            case 'red',    col = [0.90 0.15 0.12];
            case 'green',  col = [0.10 0.60 0.25];
            case 'orange', col = [0.95 0.48 0.10];
            case 'purple', col = [0.55 0.25 0.85];
            case 'black',  col = [0.02 0.02 0.02];
            case 'white',  col = [0.95 0.95 0.95];
            case 'gray',   col = [0.45 0.45 0.45];
        end
    end
catch
    col = defaultCol;
end
end

function s = popupStr_SAFE_20260617(S,field,fb)
s = fb;
try
    if isfield(S,field) && ishghandle(S.(field))
        items = get(S.(field),'String'); v = get(S.(field),'Value');
        if iscell(items), v=max(1,min(v,numel(items))); s=strtrimSafe(items{v}); else, c=cellstr(items); v=max(1,min(v,numel(c))); s=strtrimSafe(c{v}); end
    end
catch
end
end
% GA_FC_SAFE_VIEWER_20260617_END







function fcDrawHeatmapGrid_GA_20260622(ax,nR,nC)
try, for x=0.5:1:(nC+0.5), line(ax,[x x],[0.5 nR+0.5],'Color',[0 0 0],'LineWidth',0.55,'HitTest','off'); end; for y=0.5:1:(nR+0.5), line(ax,[0.5 nC+0.5],[y y],'Color',[0 0 0],'LineWidth',0.55,'HitTest','off'); end; for x=0.5:5:(nC+0.5), line(ax,[x x],[0.5 nR+0.5],'Color',[0 0 0],'LineWidth',1.50,'HitTest','off'); end; for y=0.5:5:(nR+0.5), line(ax,[0.5 nC+0.5],[y y],'Color',[0 0 0],'LineWidth',1.50,'HitTest','off'); end; catch, end
end



function [sel,note] = fcGASelectedOrTopROIIdx_20260622(S,R,M,seedIdx,roi2Idx,nTop)
sel=[]; note='';
try
    n=size(M,1); if nargin<6||isempty(nTop), nTop=20; end; nHalf=max(5,min(10,round(nTop/2)));
    if isfield(S,'fcSelectedROIIdx') && ~isempty(S.fcSelectedROIIdx)
        sel=fc_region_keep_indices_GA_20260622(S.fcSelectedROIIdx,n); note=sprintf('manual %d ROI(s)',numel(sel)); return;
    end
    row=double(M(seedIdx,:)); row(seedIdx)=NaN;
    [~,posOrd]=sort(row,'descend'); [~,negOrd]=sort(row,'ascend');
    posOrd=posOrd(isfinite(row(posOrd))); negOrd=negOrd(isfinite(row(negOrd)));
    posSel=posOrd(1:min(nHalf,numel(posOrd))); negSel=negOrd(1:min(nHalf,numel(negOrd)));
    sel=unique([seedIdx;roi2Idx;posSel(:);negSel(:)],'stable'); sel=sel(sel>=1&sel<=n);
    names = cell(numel(sel),1); for ii=1:numel(sel), names{ii}=fcNiceName_SAFE_20260617(R.names{sel(ii)},R.labels(sel(ii)),'Abbrev',true); end
    [~,ord]=sort(lower(names)); sel=sel(ord);
    note=sprintf('seed top +%d / -%d ROI(s), alphabetic',numel(posSel),numel(negSel));
catch, sel=[]; note='all ROIs'; end
end

function keep = fc_region_keep_indices_GA_20260622(sel,n)
keep=[]; try, if isempty(sel)||n<1, return; end; if islogical(sel), sel=find(sel(:)); end; sel=round(double(sel(:))); keep=unique(sel(sel>=1&sel<=n),'stable'); catch, keep=[]; end
end

function fcGARefreshNameTable_20260622(f)
try, hFig=getappdata(f,'hFigGA'); S=guidata(hFig); labels=getappdata(f,'fcLabels'); names=getappdata(f,'fcNames'); hSearch=getappdata(f,'hSearch'); hHemi=getappdata(f,'hHemi'); hTable=getappdata(f,'hTable'); q=lower(strtrim(get(hSearch,'String'))); hemiItems=get(hHemi,'String'); mode=hemiItems{get(hHemi,'Value')}; rows={}; usedAbs=[]; for ii=1:numel(labels), lab=double(labels(ii)); side='R'; if lab<0, side='L'; end; if strcmpi(mode,'Left only')&&lab>0, continue; end; if strcmpi(mode,'Right only')&&lab<0, continue; end; if strcmpi(mode,'Merged L/R'), if any(usedAbs==abs(lab)), continue; end; usedAbs(end+1)=abs(lab); idxGroup=find(abs(double(labels(:)))==abs(lab)); showLab=abs(lab); else, idxGroup=ii; showLab=lab; end; abbr=fcNiceName_SAFE_20260617(names{ii},lab,'Abbrev',true); full=fcNiceName_SAFE_20260617(names{ii},lab,'Full',true); txtRow=lower(sprintf('%g %s %s',showLab,abbr,full)); if ~isempty(q)&&isempty(strfind(txtRow,q)), continue; end; inc=false; try, if isfield(S,'fcSelectedROIIdx')&&~isempty(S.fcSelectedROIIdx), inc=any(ismember(idxGroup,S.fcSelectedROIIdx)); end, catch, end; idxStr=sprintf('%d,',idxGroup); idxStr=regexprep(idxStr,',$',''); if strcmpi(mode,'Both separate'), abbr=[side '_' abbr]; end; rows(end+1,:)={inc,showLab,abbr,full,idxStr}; end; if ~isempty(rows), [~,ord]=sort(lower(rows(:,3))); rows=rows(ord,:); end; set(hTable,'Data',rows); catch ME, try, disp(['Names table refresh failed: ' ME.message]); catch, end, end
end
function fcGASetShownInclude_20260622(f,val)
try, hTable=getappdata(f,'hTable'); D=get(hTable,'Data'); for ii=1:size(D,1), D{ii,1}=logical(val); end; set(hTable,'Data',D); catch, end
end
function fcGAApplyNameTableSelection_20260622(f)
try, hFig=getappdata(f,'hFigGA'); S=guidata(hFig); hTable=getappdata(f,'hTable'); D=get(hTable,'Data'); sel=[]; for ii=1:size(D,1), if logical(D{ii,1}), parts=regexp(char(D{ii,5}),'\d+','match'); for jj=1:numel(parts), sel(end+1,1)=str2double(parts{jj}); end, end, end; sel=unique(sel(isfinite(sel)&sel>=1),'stable'); if isempty(sel), warndlg('At least one region must be selected.','FC names'); return; end; S.fcSelectedROIIdx=sel(:); guidata(hFig,S); try, delete(f); catch, end; updateFCTabPreview_ADV_20260617(S); catch ME, errordlg(ME.message,'Apply FC region selection'); end
end


function fcGACompactLayout_20260623(S)
% Runtime layout cleanup for FC-GA top controls.
try
    if isfield(S,'hFCExportPNG') && ishghandle(S.hFCExportPNG), set(S.hFCExportPNG,'Units','normalized','Position',[0.820 0.020 0.065 0.105]); end
    if isfield(S,'hFCZoom') && ishghandle(S.hFCZoom), set(S.hFCZoom,'Units','normalized','Position',[0.895 0.020 0.070 0.105],'String','Large'); end
    if isfield(S,'hFCYAuto') && ishghandle(S.hFCYAuto), set(S.hFCYAuto,'Units','normalized','Position',[0.060 0.020 0.060 0.105]); end
    if isfield(S,'hFCYMin') && ishghandle(S.hFCYMin), set(S.hFCYMin,'Units','normalized','Position',[0.125 0.020 0.045 0.105]); end
    if isfield(S,'hFCYMax') && ishghandle(S.hFCYMax), set(S.hFCYMax,'Units','normalized','Position',[0.175 0.020 0.045 0.105]); end
    if isfield(S,'hFCYStep') && ishghandle(S.hFCYStep), set(S.hFCYStep,'Units','normalized','Position',[0.225 0.020 0.045 0.105]); end
    if isfield(S,'hFCPlotColor') && ishghandle(S.hFCPlotColor), set(S.hFCPlotColor,'Units','normalized','Position',[0.325 0.020 0.085 0.105]); end
catch
end
end

function nm = fcNiceName_SAFE_20260617(raw,label,labelMode,stripSide)
if nargin < 4, stripSide = false; end
[acr,full] = fcNameParts_SAFE_20260622(raw);
if strcmpi(labelMode,'Full')
    if isempty(full), base = acr; else, base = full; end
elseif strcmpi(labelMode,'Label ID')
    base = sprintf('%g',label);
else
    base = acr;
end
if ~strcmpi(labelMode,'Full'), base = upper(base); end
side = fcSide_SAFE_20260617(raw,label);
if ~stripSide && ~isempty(side)
    base = [upper(side) '_' base];
end
base = regexprep(base,'\s+',' ');
maxN = 12; if strcmpi(labelMode,'Full'), maxN = 34; end
if numel(base) > maxN, base = [base(1:max(1,maxN-3)) '...']; end
nm = base;
end

function acr = fcAcr_SAFE_20260617(raw)
[acr,~] = fcNameParts_SAFE_20260622(raw);
acr = upper(acr);
end

function [acr,full] = fcNameParts_SAFE_20260622(raw)
s = strtrimSafe(raw); full = '';
if isempty(s), acr = ''; return; end
if ~isempty(strfind(s,'||'))
    parts = regexp(s,'\|\|','split'); left = strtrimSafe(parts{1});
    if numel(parts) >= 2, full = strtrimSafe(parts{2}); end
else
    left = s;
end
left = regexprep(left,'\[[^\]]*\]','');
left = regexprep(left,'^\s*-?\d+\s*=?\s*','');
left = regexprep(left,'(?i)^(L|R)[_\-\s]+','');
left = regexprep(left,'(?i)\b(left|right)\b','');
left = strtrim(regexprep(left,'[_\s]+',' '));
tok = regexp(left,'^([A-Za-z][A-Za-z0-9\-]{0,12})\s+(.+)$','tokens','once');
if ~isempty(tok)
    acr = upper(strtrim(tok{1}));
    if isempty(full), full = strtrim(tok{2}); end
else
    acr = upper(strtrim(left));
end
full = regexprep(full,'\[[^\]]*\]','');
full = regexprep(full,'^\s*-?\d+\s*=?\s*','');
full = regexprep(full,'(?i)^(L|R)[_\-\s]+','');
full = regexprep(full,'(?i)\b(left|right)\b','');
full = regexprep(full,'\s+\d+(\s+\d+)*\s*$','');
full = strtrim(regexprep(full,'[_\s]+',' '));
if isempty(acr), acr = upper(strtrimSafe(raw)); end
end

function plotFCMatrix_CLEAN_20260617(ax,M,clim,titleStr,namesX,namesY,labelsX,labelsY,C,cmapName,labelMode,hemiTitle)
try, delete(findall(ancestor(ax,'figure'),'Type','ColorBar')); catch, end
cla(ax);
if isempty(M)
    try, fcNoDataLocal(ax,titleStr,C); catch, text(ax,0.5,0.5,titleStr); end
    return;
end
imagesc(ax,M);
try, set(ax,'CLim',clim); catch, try, caxis(ax,clim); catch, end, end
try, colormap(ax,cmapFC_ADV_20260617(cmapName,256)); catch, colormap(ax,jet(256)); end
cb = colorbar(ax);
try, set(cb,'Color',C.txt); ylabel(cb,'FC','Color',C.txt,'Interpreter','none'); catch, end
set(ax,'Color',C.axisBg,'XColor',C.txt,'YColor',C.txt,'FontName','Arial','FontSize',9,'TickLength',[0 0]);
try, set(ax,'TickLabelInterpreter','none'); catch, end
title(ax,titleStr,'Color',C.txt,'FontWeight','bold','Interpreter','none');
nR=size(M,1); nC=size(M,2);
forceAllTicks=false; try, forceAllTicks=isappdata(ax,'FCGA_FORCE_ALL_TICKS'); catch, end
maxTicks=32; if strcmpi(strtrimSafe(labelMode),'Full'), maxTicks=18; end; if forceAllTicks, maxTicks=max(size(M)); end
ticksY=fcTickIdx_SAFE_20260617(nR,maxTicks); ticksX=fcTickIdx_SAFE_20260617(nC,maxTicks);
xLabs=fcMakeLabels_SAFE_20260617(namesX,labelsX,labelMode,hemiTitle);
yLabs=fcMakeLabels_SAFE_20260617(namesY,labelsY,labelMode,hemiTitle);
set(ax,'YTick',ticksY,'YTickLabel',yLabs(ticksY),'XTick',ticksX,'XTickLabel',xLabs(ticksX));
try, xtickangle(ax,45); catch, end
axis(ax,'tight'); box(ax,'on'); hold(ax,'on');
try, fcDrawHeatmapGrid_GA_20260622(ax,nR,nC); catch, end
hold(ax,'off');
[xl,yl]=fcHemiAxis_SAFE_20260617(hemiTitle);
xlabel(ax,xl,'Color',C.txt,'Interpreter','none'); ylabel(ax,yl,'Color',C.txt,'Interpreter','none');
end

function [sel,note] = fcGASelectROIForLarge_20260623(S,R,M,seedIdx,roi2Idx,nTop)
sel = [];
note = '';
try
    n = size(M,1);
    if nargin < 6 || isempty(nTop), nTop = 20; end
    nHalf = max(5,min(10,round(nTop/2)));

    row = double(M(seedIdx,:));
    row(seedIdx) = NaN;
    [~,posOrd] = sort(row,'descend');
    [~,negOrd] = sort(row,'ascend');
    posOrd = posOrd(isfinite(row(posOrd)));
    negOrd = negOrd(isfinite(row(negOrd)));
    posSel = posOrd(1:min(nHalf,numel(posOrd)));
    negSel = negOrd(1:min(nHalf,numel(negOrd)));

    sel = unique([seedIdx; roi2Idx; posSel(:); negSel(:)],'stable');
    sel = sel(sel >= 1 & sel <= n);

    try
        nm = cell(numel(sel),1);
        for ii = 1:numel(sel)
            nm{ii} = fcNiceName_SAFE_20260617(R.names{sel(ii)},R.labels(sel(ii)),'Abbrev',true);
        end
        [~,ord] = sort(lower(nm));
        sel = sel(ord);
    catch
    end

    note = sprintf('seed top +%d / -%d ROI(s), alphabetic',numel(posSel),numel(negSel));
catch
    sel = [];
    note = 'all ROIs';
end
end

function plotROIOverlay_ADV_20260617(ax,S,R,cmapName)
cla(ax);
[map3,note] = findROIOverlayMap_ADV_20260617(S);
if isempty(map3)
    text(ax,0.5,0.55,'ROI overlay map not found', ...
        'Color',S.C.txt,'HorizontalAlignment','center', ...
        'FontWeight','bold','Interpreter','none');
    set(ax,'Color',S.C.axisBg,'XTick',[],'YTick',[]);
    title(ax,'ROI seed-correlation overlay','Color',S.C.txt,'Interpreter','none');
    return;
end

map3 = squeeze(map3);
z = 1;
if ndims(map3) > 2
    try
        sl = popupString_SINGLE_20260616(S,'hFCSlice','All slices');
        tok = regexp(sl,'(\d+)','tokens','once');
        if ~isempty(tok)
            z = str2double(tok{1});
        else
            z = round(size(map3,3)/2);
        end
    catch
        z = round(size(map3,3)/2);
    end
    z = max(1,min(round(z),size(map3,3)));
    labelSlice = double(map3(:,:,z));
    note = sprintf('%s | slice %d/%d',note,z,size(map3,3));
else
    labelSlice = double(map3);
end

seedIdx = popupIndex_SINGLE_20260616(S,'hFCRegion1',1);
seedIdx = max(1,min(seedIdx,numel(R.labels)));
M = R.meanR;
valMap = NaN(size(labelSlice));
for ii = 1:numel(R.labels)
    lab = double(R.labels(ii));
    v = NaN;
    try, v = double(M(seedIdx,ii)); catch, end
    if isfinite(v)
        mask = (labelSlice == lab);
        if ~any(mask(:)), mask = (abs(labelSlice) == abs(lab)); end
        valMap(mask) = v;
    end
end

hIm = imagesc(ax,valMap,[-1 1]);
set(hIm,'AlphaData',isfinite(valMap),'HitTest','on','PickableParts','all');
set(ax,'Color',S.C.axisBg,'ButtonDownFcn',@(src,evt)fcGAOverlayClickAny_20260623(src,evt));
axis(ax,'image'); axis(ax,'ij'); axis(ax,'off');
xlim(ax,[1 size(valMap,2)]); ylim(ax,[1 size(valMap,1)]);
try, colormap(ax,cmapFC_ADV_20260617('Blue-White-Red',256)); catch, colormap(ax,jet(256)); end
cb = colorbar(ax);
try, set(cb,'Color',S.C.txt); ylabel(cb,'Pearson r: selected seed → ROI','Color',S.C.txt,'Interpreter','none'); catch, end

setappdata(ax,'fcGAOverlayLabelSlice',labelSlice);
setappdata(ax,'fcGAOverlayLabels',double(R.labels(:)));
setappdata(ax,'fcGAOverlayMap3',map3);
setappdata(ax,'fcGAOverlayR',R);

title(ax,sprintf('ROI seed-correlation overlay | click ROI = seed | mouse wheel = slice | Seed: %s | %s', ...
    fcNiceName_SAFE_20260617(R.names{seedIdx},R.labels(seedIdx),'Full',false),note), ...
    'Color',S.C.txt,'FontWeight','bold','Interpreter','none');

try, set(hIm,'ButtonDownFcn',@(src,evt)fcGAOverlayClickAny_20260623(src,evt)); catch, end
try
    fig = ancestor(ax,'figure');
    set(fig,'WindowScrollWheelFcn',@(src,evt)fcGAOverlayScrollAny_20260623(src,evt));
catch
end
end

function fcGAOverlayClickAny_20260623(src,evt)
try
    ax = ancestor(src,'axes');
    fig = ancestor(ax,'figure');
    labelSlice = getappdata(ax,'fcGAOverlayLabelSlice');
    labs = getappdata(ax,'fcGAOverlayLabels');
    if isempty(labelSlice) || isempty(labs), return; end

    cp = get(ax,'CurrentPoint');
    x = round(cp(1,1));
    y = round(cp(1,2));
    if y < 1 || x < 1 || y > size(labelSlice,1) || x > size(labelSlice,2)
        return;
    end

    lab = double(labelSlice(y,x));
    if lab == 0 || ~isfinite(lab), return; end

    idx = find(labs == lab,1,'first');
    if isempty(idx), idx = find(abs(labs) == abs(lab),1,'first'); end
    if isempty(idx), return; end

    % Large window case.
    D = [];
    try, D = getappdata(fig,'D'); catch, end
    if isstruct(D) && isfield(D,'hSeed') && ~isempty(D.hSeed) && ishghandle(D.hSeed)
        set(D.hSeed,'Value',idx);
        try
            S = guidata(D.mainFig);
            if isfield(S,'hFCRegion1') && ishghandle(S.hFCRegion1)
                set(S.hFCRegion1,'Value',idx);
                guidata(D.mainFig,S);
            end
        catch
        end
        try, fcGALargeReplot_20260622(fig); catch, end
        return;
    end

    % Main GroupAnalysis window case.
    S = guidata(fig);
    if isempty(S)
        try
            mainFig = getappdata(fig,'mainFig');
            S = guidata(mainFig);
            fig = mainFig;
        catch
        end
    end
    if isempty(S), return; end

    if isfield(S,'hFCRegion1') && ~isempty(S.hFCRegion1) && ishghandle(S.hFCRegion1)
        set(S.hFCRegion1,'Value',idx);
        guidata(fig,S);
        updateFCTabPreview_ADV_20260617(S);
    end
catch ME
    try, fprintf('FC-GA ROI overlay click warning: %s\n',ME.message); catch, end
end
end

function fcGAOverlayScrollAny_20260623(fig,evt)
try
    % Large-window case first.
    D = [];
    try, D = getappdata(fig,'D'); catch, end
    if isstruct(D) && isfield(D,'hSlice') && ~isempty(D.hSlice) && ishghandle(D.hSlice)
        items = get(D.hSlice,'String');
        if ischar(items), items = cellstr(items); end
        if numel(items) < 2, return; end
        v = get(D.hSlice,'Value');
        step = sign(evt.VerticalScrollCount);
        if step == 0, step = 1; end
        v = max(1,min(numel(items),v + step));
        set(D.hSlice,'Value',v);
        try, fcGALargeReplot_20260622(fig); catch, end
        return;
    end

    % Main GroupAnalysis window case.
    S = guidata(fig);
    if isempty(S) || ~isfield(S,'hFCSlice') || isempty(S.hFCSlice) || ~ishghandle(S.hFCSlice)
        return;
    end

    viewMode = '';
    try, viewMode = popupString_SINGLE_20260616(S,'hFCView',''); catch, end
    if isempty(strfind(lower(viewMode),'overlay'))
        return;
    end

    items = get(S.hFCSlice,'String');
    if ischar(items), items = cellstr(items); end
    if numel(items) < 2, return; end

    v = get(S.hFCSlice,'Value');
    step = sign(evt.VerticalScrollCount);
    if step == 0, step = 1; end
    v = max(1,min(numel(items),v + step));
    set(S.hFCSlice,'Value',v);
    guidata(fig,S);
    drawnow limitrate;
    updateFCTabPreview_ADV_20260617(S);
catch ME
    try, fprintf('FC-GA ROI overlay scroll warning: %s\n',ME.message); catch, end
end
end

% Compatibility wrappers for older callbacks still present in the file.
function fcGAOverlayClick_20260622(src,evt)
fcGAOverlayClickAny_20260623(src,evt);
end

function fcGAScrollSlice_20260622(fig,evt)
fcGAOverlayScrollAny_20260623(fig,evt);
end

function fcGALargeOverlayClick_20260622(f,src,evt)
try, fcGAOverlayClickAny_20260623(src,evt); catch, end
end

function fcGALargeScrollSlice_20260622(f,evt)
fcGAOverlayScrollAny_20260623(f,evt);
end










function fcGACleanFinalLayout_20260624(S)
% Final polished FC-GA top layout with equal row spacing.
try
    if ~isfield(S,'axFCA') || isempty(S.axFCA) || ~ishghandle(S.axFCA)
        return;
    end

    pMat = get(S.axFCA,'Parent');
    if isempty(pMat) || ~ishghandle(pMat), return; end
    pFCBG = get(pMat,'Parent');
    if isempty(pFCBG) || ~ishghandle(pFCBG), return; end
    fig = ancestor(pFCBG,'figure');

    pTop = [];
    try, if isfield(S,'hFCView') && ishghandle(S.hFCView), pTop = get(S.hFCView,'Parent'); end, catch, end
    if isempty(pTop) || ~ishghandle(pTop)
        try, if isfield(S,'hFCDisplay') && ishghandle(S.hFCDisplay), pTop = get(S.hFCDisplay,'Parent'); end, catch, end
    end
    if isempty(pTop) || ~ishghandle(pTop), return; end

    try, set(pFCBG,'Units','normalized'); catch, end
    try, set(pTop,'Units','normalized'); catch, end
    try, set(pMat,'Units','normalized'); catch, end

    % Capitalized panel title.
    try, set(pTop,'Title','Functional Connectivity Group Analysis'); catch, end

    % Overall layout.
    set(pTop,'Position',[0.02 0.790 0.96 0.200]);
    set(pMat,'Position',[0.02 0.130 0.96 0.645]);

    % Matrix axes shifted right a little to avoid label-border overlap.
    try, set(S.axFCA,'Units','normalized','Position',[0.095 0.110 0.765 0.825]); catch, end

    % Status line below matrix.
    if isfield(S,'hFCInfo') && ~isempty(S.hFCInfo) && ishghandle(S.hFCInfo)
        try, set(S.hFCInfo,'Parent',pFCBG); catch, end
        set(S.hFCInfo,'Units','normalized', ...
            'Position',[0.02 0.085 0.96 0.035], ...
            'HorizontalAlignment','left', ...
            'FontName','Consolas', ...
            'FontSize',8.0, ...
            'ForegroundColor',[0.60 0.85 1.00]);
    end

    % Bottom strip.
    pStrip = findall(pFCBG,'Type','uipanel','Tag','FCGA_BOTTOM_CONTROL_STRIP_20260624_CLEAN');
    if isempty(pStrip) || ~ishghandle(pStrip(1))
        pStrip = uipanel('Parent',pFCBG, ...
            'Units','normalized', ...
            'Position',[0.02 0.005 0.96 0.070], ...
            'BorderType','line', ...
            'HighlightColor',[0.70 0.70 0.70], ...
            'ShadowColor',[0.25 0.25 0.25], ...
            'BackgroundColor',[0.07 0.07 0.075], ...
            'Tag','FCGA_BOTTOM_CONTROL_STRIP_20260624_CLEAN');
    else
        pStrip = pStrip(1);
        set(pStrip,'Units','normalized', ...
            'Position',[0.02 0.005 0.96 0.070], ...
            'BackgroundColor',[0.07 0.07 0.075]);
    end

    % Hide Threshold controls.
    hThrTxt1 = fcGAFindControlText_20260624(fig,'Threshold','text');
    hThrTxt2 = fcGAFindControlText_20260624(fig,'Abs threshold','text');
    try, if ~isempty(hThrTxt1) && ishghandle(hThrTxt1), set(hThrTxt1,'Visible','off'); end, catch, end
    try, if ~isempty(hThrTxt2) && ishghandle(hThrTxt2), set(hThrTxt2,'Visible','off'); end, catch, end
    try, if isfield(S,'hFCThreshold') && ishghandle(S.hFCThreshold), set(S.hFCThreshold,'Visible','off','String','0'); end, catch, end

    % Label dropdown wording.
    try
        if isfield(S,'hFCLabelMode') && ishghandle(S.hFCLabelMode)
            oldVal = get(S.hFCLabelMode,'Value');
            set(S.hFCLabelMode,'String',{'Abbreviation','Full name','Label ID'},'Value',max(1,min(3,oldVal)));
        end
    catch
    end

    fsLab = 11.0;
    fsCtl = 10.5;
    fsBtn = 12.0;

    % Slightly higher than previous version, with equal row gaps.
    row1 = 0.655;
    row2 = 0.265;
    row3 = 0.020;
    hCtl = 0.230;
    hLab = 0.230;

    % Row 1.
    try, if isfield(S,'hFCLoad') && ishghandle(S.hFCLoad), set(S.hFCLoad,'Parent',pTop,'Units','normalized','Position',[0.020 0.600 0.135 0.320],'FontSize',11.0,'FontWeight','bold'); end, catch, end
    try, if isfield(S,'hFCScan') && ishghandle(S.hFCScan), set(S.hFCScan,'Parent',pTop,'Units','normalized','Position',[0.165 0.600 0.110 0.320],'FontSize',11.0,'FontWeight','bold'); end, catch, end
    fcGASetLabelPos_20260624(pTop,'Group:',[0.305 row1 0.060 hLab],fsLab);
    try, if isfield(S,'hFCGroupA') && ishghandle(S.hFCGroupA), set(S.hFCGroupA,'Parent',pTop,'Units','normalized','Position',[0.370 row1+0.010 0.125 hCtl],'FontSize',fsCtl); end, catch, end
    fcGASetLabelPos_20260624(pTop,'Display:',[0.525 row1 0.075 hLab],fsLab);
    try, if isfield(S,'hFCDisplay') && ishghandle(S.hFCDisplay), set(S.hFCDisplay,'Parent',pTop,'Units','normalized','Position',[0.605 row1+0.010 0.135 hCtl],'FontSize',fsCtl); end, catch, end
    try, if isfield(S,'hFCCompute') && ishghandle(S.hFCCompute), set(S.hFCCompute,'Parent',pTop,'Units','normalized','Position',[0.765 0.565 0.110 0.370],'String','Recompute','FontSize',fsBtn,'FontWeight','bold'); end, catch, end
    try, if isfield(S,'hFCExport') && ishghandle(S.hFCExport), set(S.hFCExport,'Parent',pTop,'Units','normalized','Position',[0.885 0.565 0.100 0.370],'String','Export GA','FontSize',fsBtn,'FontWeight','bold'); end, catch, end

    % Row 2.
    fcGASetLabelPos_20260624(pTop,'Subject:',[0.005 row2 0.070 hLab],fsLab);
    try, if isfield(S,'hFCSubject') && ishghandle(S.hFCSubject), set(S.hFCSubject,'Parent',pTop,'Units','normalized','Position',[0.080 row2+0.006 0.185 hCtl],'FontSize',fsCtl); end, catch, end
    fcGASetLabelPos_20260624(pTop,'View:',[0.265 row2 0.050 hLab],fsLab);
    try, if isfield(S,'hFCView') && ishghandle(S.hFCView), set(S.hFCView,'Parent',pTop,'Units','normalized','Position',[0.320 row2+0.006 0.170 hCtl],'FontSize',fsCtl); end, catch, end
    fcGASetLabelPos_20260624(pTop,'Hemi:',[0.490 row2 0.055 hLab],fsLab);
    try, if isfield(S,'hFCHemi') && ishghandle(S.hFCHemi), set(S.hFCHemi,'Parent',pTop,'Units','normalized','Position',[0.545 row2+0.006 0.135 hCtl],'FontSize',fsCtl); end, catch, end
    fcGASetLabelPos_20260624(pTop,'Color:',[0.705 row2 0.055 hLab],fsLab);
    try, if isfield(S,'hFCColorMap') && ishghandle(S.hFCColorMap), set(S.hFCColorMap,'Parent',pTop,'Units','normalized','Position',[0.755 row2+0.006 0.110 hCtl],'FontSize',fsCtl); end, catch, end
    fcGASetLabelPos_20260624(pTop,'Labels:',[0.845 row2 0.060 hLab],fsLab);
    try, if isfield(S,'hFCLabelMode') && ishghandle(S.hFCLabelMode), set(S.hFCLabelMode,'Parent',pTop,'Units','normalized','Position',[0.905 row2+0.006 0.085 hCtl],'FontSize',fsCtl); end, catch, end

    % Row 3.
    fcGASetLabelPos_20260624(pTop,'Seed:',[0.020 row3 0.050 hLab],fsLab);
    try, if isfield(S,'hFCRegion1') && ishghandle(S.hFCRegion1), set(S.hFCRegion1,'Parent',pTop,'Units','normalized','Position',[0.075 row3+0.010 0.270 hCtl],'FontSize',fsCtl); end, catch, end
    fcGASetLabelPos_20260624(pTop,'ROI 2:',[0.365 row3 0.065 hLab],fsLab);
    try, if isfield(S,'hFCRegion2') && ishghandle(S.hFCRegion2), set(S.hFCRegion2,'Parent',pTop,'Units','normalized','Position',[0.435 row3+0.010 0.275 hCtl],'FontSize',fsCtl); end, catch, end
    fcGASetLabelPos_20260624(pTop,'Slice:',[0.735 row3 0.055 hLab],fsLab);
    try, if isfield(S,'hFCSlice') && ishghandle(S.hFCSlice), set(S.hFCSlice,'Parent',pTop,'Units','normalized','Position',[0.795 row3+0.010 0.125 hCtl],'FontSize',fsCtl); end, catch, end

    % Bottom strip controls.
    hYLab = fcGAFindControlText_20260624(fig,'Y:','text');
    fcGASetCtrlPos_20260624(hYLab,pStrip,[0.010 0.170 0.030 0.650]);
    if isfield(S,'hFCYAuto') && ~isempty(S.hFCYAuto) && ishghandle(S.hFCYAuto)
        fcGASetCtrlPos_20260624(S.hFCYAuto,pStrip,[0.045 0.140 0.070 0.700]);
    else
        hAuto = fcGAFindControlText_20260624(fig,'Auto','checkbox');
        fcGASetCtrlPos_20260624(hAuto,pStrip,[0.045 0.140 0.070 0.700]);
    end
    if isfield(S,'hFCYMin') && ~isempty(S.hFCYMin) && ishghandle(S.hFCYMin), fcGASetCtrlPos_20260624(S.hFCYMin,pStrip,[0.125 0.165 0.045 0.650]); end
    if isfield(S,'hFCYMax') && ~isempty(S.hFCYMax) && ishghandle(S.hFCYMax), fcGASetCtrlPos_20260624(S.hFCYMax,pStrip,[0.175 0.165 0.045 0.650]); end
    if isfield(S,'hFCYStep') && ~isempty(S.hFCYStep) && ishghandle(S.hFCYStep), fcGASetCtrlPos_20260624(S.hFCYStep,pStrip,[0.225 0.165 0.045 0.650]); end
    hPlotLab = fcGAFindControlText_20260624(fig,'Plot','text');
    fcGASetCtrlPos_20260624(hPlotLab,pStrip,[0.295 0.170 0.045 0.650]);
    if isfield(S,'hFCPlotColor') && ~isempty(S.hFCPlotColor) && ishghandle(S.hFCPlotColor), fcGASetCtrlPos_20260624(S.hFCPlotColor,pStrip,[0.345 0.165 0.090 0.650]); end
    hAnimals = []; try, if isfield(S,'hFCAnimals') && ishghandle(S.hFCAnimals), hAnimals = S.hFCAnimals; end, catch, end
    if isempty(hAnimals), hAnimals = fcGAFindButtonContains_20260624(fig,'Animals'); end
    fcGASetCtrlPos_20260624(hAnimals,pStrip,[0.610 0.120 0.090 0.760]);
    hNames = []; try, if isfield(S,'hFCNames') && ishghandle(S.hFCNames), hNames = S.hFCNames; end, catch, end
    if isempty(hNames), hNames = fcGAFindButtonExact_20260624(fig,'Names'); end
    fcGASetCtrlPos_20260624(hNames,pStrip,[0.705 0.120 0.075 0.760]);
    hPNG = []; try, if isfield(S,'hFCExportPNG') && ishghandle(S.hFCExportPNG), hPNG = S.hFCExportPNG; end, catch, end
    if isempty(hPNG), hPNG = fcGAFindButtonExact_20260624(fig,'PNG'); end
    fcGASetCtrlPos_20260624(hPNG,pStrip,[0.785 0.120 0.070 0.760]);
    hLarge = fcGAFindButtonExact_20260624(fig,'Large'); if isempty(hLarge), hLarge = fcGAFindButtonExact_20260624(fig,'⛶'); end
    if ~isempty(hLarge) && ishghandle(hLarge)
        fcGASetCtrlPos_20260624(hLarge,pStrip,[0.865 0.120 0.085 0.760]);
        try, set(hLarge,'String','Large','Callback',@(src,evt)showFCLargeView_GA_20260622(ancestor(src,'figure'))); catch, end
    end
    drawnow limitrate;
catch ME
    try, fprintf('FC-GA row-spacing/title polish warning: %s\n',ME.message); catch, end
end
end

function fcGASetLabelPos_20260624(parentHandle,labelText,pos,fontSize)
try
    if nargin < 4 || isempty(fontSize), fontSize = 10; end
    h = findall(parentHandle,'Type','uicontrol','Style','text','String',labelText);
    if ~isempty(h) && ishghandle(h(1))
        set(h(1),'Units','normalized','Position',pos,'Visible','on', ...
            'FontSize',fontSize,'FontWeight','bold', ...
            'HorizontalAlignment','right');
    end
catch
end
end

function h = fcGAFindControlText_20260624(parentHandle,pattern,styleWanted)
h = [];
try
    if isempty(parentHandle) || ~ishghandle(parentHandle), return; end
    hs = findall(parentHandle,'Type','uicontrol');
    pat = lower(pattern);
    for kk = 1:numel(hs)
        try
            if nargin >= 3 && ~isempty(styleWanted)
                st = get(hs(kk),'Style');
                if ~strcmpi(st,styleWanted), continue; end
            end
            s = get(hs(kk),'String');
            if iscell(s), s = strjoin(s,' '); end
            if isempty(s), continue; end
            if ~isempty(strfind(lower(char(s)),pat))
                h = hs(kk); return;
            end
        catch, end
    end
catch, h = []; end
end

function h = fcGAFindButtonExact_20260624(parentHandle,labelText)
h = [];
try
    hs = findall(parentHandle,'Type','uicontrol','Style','pushbutton');
    for kk = 1:numel(hs)
        try
            s = get(hs(kk),'String'); if iscell(s), s = strjoin(s,' '); end
            if strcmp(strtrim(char(s)),labelText), h = hs(kk); return; end
        catch, end
    end
catch, h = []; end
end

function h = fcGAFindButtonContains_20260624(parentHandle,pattern)
h = [];
try
    hs = findall(parentHandle,'Type','uicontrol','Style','pushbutton');
    pat = lower(pattern);
    for kk = 1:numel(hs)
        try
            s = get(hs(kk),'String'); if iscell(s), s = strjoin(s,' '); end
            if ~isempty(strfind(lower(char(s)),pat)), h = hs(kk); return; end
        catch, end
    end
catch, h = []; end
end

function fcGASetCtrlPos_20260624(h,newParent,pos)
try
    if ~isempty(h) && ishghandle(h) && ~isempty(newParent) && ishghandle(newParent)
        try, set(h,'Parent',newParent); catch, end
        set(h,'Units','normalized','Position',pos,'Visible','on');
    end
catch
end
end


function fcGAFixRow2Overlap_FORCE_20260624(S)
% Force-separate Subject/View/Hemi/Color/Labels row to remove black popup overlaps.
try
    pTop = [];
    try, if isfield(S,'hFCView') && ishghandle(S.hFCView), pTop = get(S.hFCView,'Parent'); end, catch, end
    if isempty(pTop) || ~ishghandle(pTop)
        try, if isfield(S,'hFCDisplay') && ishghandle(S.hFCDisplay), pTop = get(S.hFCDisplay,'Parent'); end, catch, end
    end
    if isempty(pTop) || ~ishghandle(pTop), return; end

    bg = [0.07 0.07 0.075];
    try, bg = get(pTop,'BackgroundColor'); catch, end

    % Compact label dropdown text so it does not need a wide black box.
    try
        if isfield(S,'hFCLabelMode') && ishghandle(S.hFCLabelMode)
            v = get(S.hFCLabelMode,'Value');
            set(S.hFCLabelMode,'String',{'Abbrev','Full','ID'},'Value',max(1,min(3,v)));
        end
    catch
    end

    % Row-2 fixed positions with real gaps between popup boxes.
    yLab = 0.265;
    yCtl = 0.282;
    hLab = 0.205;
    hCtl = 0.205;
    fsLab = 11.0;
    fsCtl = 10.5;

    % Subject
    hSubjectTxt = fcGAFindTextExact_FORCE_20260624(pTop,'Subject:');
    fcGASetText_FORCE_20260624(hSubjectTxt,[0.005 yLab 0.070 hLab],fsLab,bg);
    try, fcGASetPopup_FORCE_20260624(S.hFCSubject,[0.080 yCtl 0.175 hCtl],fsCtl); catch, end

    % View
    hViewTxt = fcGAFindTextExact_FORCE_20260624(pTop,'View:');
    fcGASetText_FORCE_20260624(hViewTxt,[0.280 yLab 0.055 hLab],fsLab,bg);
    try, fcGASetPopup_FORCE_20260624(S.hFCView,[0.340 yCtl 0.155 hCtl],fsCtl); catch, end

    % Hemi
    hHemiTxt = fcGAFindTextExact_FORCE_20260624(pTop,'Hemi:');
    fcGASetText_FORCE_20260624(hHemiTxt,[0.505 yLab 0.055 hLab],fsLab,bg);
    try, fcGASetPopup_FORCE_20260624(S.hFCHemi,[0.565 yCtl 0.110 hCtl],fsCtl); catch, end

    % Color
    hColorTxt = fcGAFindTextExact_FORCE_20260624(pTop,'Color:');
    fcGASetText_FORCE_20260624(hColorTxt,[0.695 yLab 0.055 hLab],fsLab,bg);
    try, fcGASetPopup_FORCE_20260624(S.hFCColorMap,[0.755 yCtl 0.110 hCtl],fsCtl); catch, end

    % Labels
    hLabelsTxt = fcGAFindTextExact_FORCE_20260624(pTop,'Labels:');
    fcGASetText_FORCE_20260624(hLabelsTxt,[0.885 yLab 0.055 hLab],fsLab,bg);
    try, fcGASetPopup_FORCE_20260624(S.hFCLabelMode,[0.945 yCtl 0.045 hCtl],fsCtl); catch, end

    % Put text labels above popup graphics.
    labs = [hSubjectTxt hViewTxt hHemiTxt hColorTxt hLabelsTxt];
    for ii = 1:numel(labs)
        try, if ishghandle(labs(ii)), uistack(labs(ii),'top'); end, catch, end
    end

    drawnow limitrate;
catch ME
    try, fprintf('FC-GA FORCE row2 overlap warning: %s\n',ME.message); catch, end
end
end

function h = fcGAFindTextExact_FORCE_20260624(parentHandle,labelText)
h = [];
try
    hs = findall(parentHandle,'Type','uicontrol','Style','text');
    for kk = 1:numel(hs)
        try
            s = get(hs(kk),'String');
            if iscell(s), s = strjoin(s,' '); end
            if strcmp(strtrim(char(s)),labelText)
                h = hs(kk);
                return;
            end
        catch
        end
    end
catch
    h = [];
end
end

function fcGASetText_FORCE_20260624(h,pos,fontSize,bg)
try
    if ~isempty(h) && ishghandle(h)
        set(h,'Units','normalized', ...
            'Position',pos, ...
            'Visible','on', ...
            'FontSize',fontSize, ...
            'FontWeight','bold', ...
            'HorizontalAlignment','right', ...
            'BackgroundColor',bg, ...
            'ForegroundColor',[1 1 1]);
    end
catch
end
end

function fcGASetPopup_FORCE_20260624(h,pos,fontSize)
try
    if ~isempty(h) && ishghandle(h)
        set(h,'Units','normalized', ...
            'Position',pos, ...
            'Visible','on', ...
            'FontSize',fontSize, ...
            'BackgroundColor',[0.12 0.12 0.13], ...
            'ForegroundColor',[1 1 1]);
    end
catch
end
end


function S = attachFCGABundlesToTable_USE_ROW_20260624(S,fileList,FC)
% Attach FC-GA bundles to the intended existing table row.
% Priority:
%   1) selected row(s)
%   2) checked Use row(s)
%   3) fallback name/file matching
% Never creates new rows.
try
    S = ensureFCRowFilesSizeGA_TARGETED(S);
catch
end

if nargin < 2 || isempty(fileList), fileList = {}; end
if ischar(fileList), fileList = {fileList}; end
fileList = fileList(:);

nRows = 0;
try, nRows = size(S.subj,1); catch, nRows = 0; end
if nRows < 1
    return;
end

targetRows = fcga_get_use_attach_rows_20260624(S);
assignedRows = [];
assignedFiles = {};

% ---------------------------------------------------------------------
% Direct attach to selected / Use rows first.
% ---------------------------------------------------------------------
if ~isempty(targetRows) && ~isempty(fileList)
    nDirect = min(numel(targetRows),numel(fileList));
    for kk = 1:nDirect
        r = targetRows(kk);
        fp = strtrimSafe(fileList{kk});
        if isempty(fp), continue; end

        % Clear this same FC bundle from any other row first.
        % FC-GA persistent mode: do not clear this file from other rows.

        S.fcRowFiles{r,1} = fp;
        assignedRows(end+1,1) = r; %#ok<AGROW>
        assignedFiles{end+1,1} = fp; %#ok<AGROW>

        % Fill group/condition from file only if table row is empty/unassigned.
        try
            if isempty(strtrimSafe(S.subj{r,3})) || strcmpi(strtrimSafe(S.subj{r,3}),'Unassigned')
                S.subj{r,3} = inferGroupFromText_TARGETED(fp);
            end
        catch
        end
    end
end

% ---------------------------------------------------------------------
% Fallback matching only for files that were not already direct-attached.
% This prevents the file from jumping back to row 1.
% ---------------------------------------------------------------------
if isempty(targetRows) && nargin >= 3 && isfield(FC,'subjects') && ~isempty(FC.subjects)
    for ii = 1:numel(FC.subjects)
        fp = ''; nm = '';
        try, fp = strtrimSafe(FC.subjects(ii).sourceFile); catch, end
        try, nm = strtrimSafe(FC.subjects(ii).name); catch, end
        if isempty(fp) && ~isempty(fileList)
            try, fp = strtrimSafe(fileList{min(ii,numel(fileList))}); catch, end
        end
        if isempty(fp), continue; end

        alreadyRow = fcga_find_row_with_fc_file_20260624(S,fp);
        if ~isempty(alreadyRow)
            r = alreadyRow;
        else
            r = [];
            try, r = findExistingFCGARow_SINGLE_20260616(S,nm,fp); catch, end
            if isempty(r)
                try, r = findExistingFCGARow_TARGETED(S,nm,fp); catch, end
            end
        end

        if ~isempty(r)
            % FC-GA persistent mode: do not clear this file from other rows.
            S.fcRowFiles{r,1} = fp;
            assignedRows(end+1,1) = r; %#ok<AGROW>
            assignedFiles{end+1,1} = fp; %#ok<AGROW>
        end
    end
end

% Sync S.FC subject metadata from the row where each FC file is attached.
try
    S = fcga_sync_loaded_fc_from_rows_20260624(S);
catch
end

% Store a useful note.
try
    assignedRows = unique(assignedRows(:)','stable');
    if ~isempty(assignedRows)
        S.fcAttachNote = sprintf('FC bundle(s) attached to table row(s): %s. Use-row priority was applied.',fcga_row_list_txt_20260624(assignedRows));
    else
        S.fcAttachNote = 'No FC bundle was attached to a table row. Check one Use row or select a row before loading.';
    end
catch
end
end

function rows = fcga_get_use_attach_rows_20260624(S)
% Get target rows for FC-GA loading.
rows = [];
nRows = 0;
try, nRows = size(S.subj,1); catch, return; end

% 1) selected rows first. If selected rows are also Use=true, prefer those.
sel = [];
try
    if isfield(S,'selectedRows') && ~isempty(S.selectedRows)
        sel = unique(round(double(S.selectedRows(:)')).','stable');
        sel = sel(sel >= 1 & sel <= nRows);
    end
catch
    sel = [];
end

useRows = [];
try
    for r = 1:nRows
        useNow = false;
        try, useNow = logicalCellValue(S.subj{r,1}); catch, useNow = false; end
        if useNow
            useRows(end+1,1) = r; %#ok<AGROW>
        end
    end
catch
    useRows = [];
end

if ~isempty(sel)
    selUse = intersect(sel(:),useRows(:),'stable');
    if ~isempty(selUse)
        rows = selUse(:);
    else
        rows = sel(:);
    end
    return;
end

% 2) if no selected row, use checked Use rows.
if ~isempty(useRows)
    try
        S = ensureFCRowFilesSizeGA_TARGETED(S);
        emptyUse = [];
        filledUse = [];
        for ii = 1:numel(useRows)
            r = useRows(ii);
            fp = '';
            try, fp = strtrimSafe(S.fcRowFiles{r}); catch, end
            if isempty(fp)
                emptyUse(end+1,1) = r; %#ok<AGROW>
            else
                filledUse(end+1,1) = r; %#ok<AGROW>
            end
        end
        rows = [emptyUse(:); filledUse(:)];
    catch
        rows = useRows(:);
    end
end
end

function S = fcga_clear_duplicate_fc_file_20260624(S,fp,keepRow)
% Remove this FC file from all rows except keepRow.
try
    fp = strtrimSafe(fp);
    if isempty(fp), return; end
    S = ensureFCRowFilesSizeGA_TARGETED(S);
    for r = 1:numel(S.fcRowFiles)
        if r == keepRow, continue; end
        try
            if strcmpi(strtrimSafe(S.fcRowFiles{r}),fp)
                S.fcRowFiles{r} = '';
            end
        catch
        end
    end
catch
end
end

function r = fcga_find_row_with_fc_file_20260624(S,fp)
r = [];
try
    fp = strtrimSafe(fp);
    if isempty(fp), return; end
    S = ensureFCRowFilesSizeGA_TARGETED(S);
    for ii = 1:numel(S.fcRowFiles)
        try
            if strcmpi(strtrimSafe(S.fcRowFiles{ii}),fp)
                r = ii;
                return;
            end
        catch
        end
    end
catch
    r = [];
end
end

function S = fcga_sync_loaded_fc_from_rows_20260624(S)
% Sync loaded FC subject metadata from the row where its FC file is attached.
try
    if ~isfield(S,'FC') || ~isfield(S.FC,'subjects') || isempty(S.FC.subjects)
        return;
    end
    S = ensureFCRowFilesSizeGA_TARGETED(S);
    for ii = 1:numel(S.FC.subjects)
        fp = ''; nm = '';
        try, fp = strtrimSafe(S.FC.subjects(ii).sourceFile); catch, end
        try, nm = strtrimSafe(S.FC.subjects(ii).name); catch, end

        r = [];
        if ~isempty(fp)
            r = fcga_find_row_with_fc_file_20260624(S,fp);
        end
        if isempty(r)
            try, r = findExistingFCGARow_SINGLE_20260616(S,nm,fp); catch, end
        end
        if isempty(r), continue; end

        try
            animal = strtrimSafe(S.subj{r,2});
            if ~isempty(animal), S.FC.subjects(ii).name = animal; end
        catch
        end
        try
            group = strtrimSafe(S.subj{r,3});
            if ~isempty(group), S.FC.subjects(ii).group = group; end
        catch
        end
        try
            cond = strtrimSafe(S.subj{r,4});
            if ~isempty(cond), S.FC.subjects(ii).condition = cond; end
        catch
        end
    end
catch
end
end

function s = fcga_row_list_txt_20260624(rows)
s = '';
try
    rows = rows(:)';
    parts = cell(numel(rows),1);
    for ii = 1:numel(rows)
        parts{ii} = sprintf('%d',rows(ii));
    end
    s = strjoin(parts,', ');
catch
    s = '?';
end
end


function FCout = fcga_merge_fc_state_keep_previous_20260624(FCold,FCnew)
% Merge newly loaded FC bundle(s) into existing loaded FC state.
% This prevents loading row 2 from deleting row 1 FC-GA information.
try
    if nargin < 1 || isempty(FCold) || ~isstruct(FCold)
        FCout = FCnew;
        try, FCout.loaded = true; catch, end
        return;
    end
    if nargin < 2 || isempty(FCnew) || ~isstruct(FCnew)
        FCout = FCold;
        try, FCout.loaded = true; catch, end
        return;
    end

    FCout = FCnew;

    oldSubs = struct([]);
    newSubs = struct([]);
    try, oldSubs = FCold.subjects; catch, oldSubs = struct([]); end
    try, newSubs = FCnew.subjects; catch, newSubs = struct([]); end

    if isempty(oldSubs)
        FCout.subjects = newSubs;
        FCout.loaded = true;
        return;
    end
    if isempty(newSubs)
        FCout.subjects = oldSubs;
        FCout.loaded = true;
        return;
    end

    merged = oldSubs;
    for ii = 1:numel(newSubs)
        keyNew = fcga_subject_key_20260624(newSubs(ii),ii);
        hit = [];
        for jj = 1:numel(merged)
            keyOld = fcga_subject_key_20260624(merged(jj),jj);
            if strcmpi(keyNew,keyOld)
                hit = jj;
                break;
            end
        end

        if isempty(hit)
            merged = fcga_struct_array_assign_union_20260624(merged,numel(merged)+1,newSubs(ii));
        else
            merged = fcga_struct_array_assign_union_20260624(merged,hit,newSubs(ii));
        end
    end

    FCout.subjects = merged;
    FCout.loaded = true;

    % Preserve old fields that may not exist in the new FC struct.
    try
        fOld = fieldnames(FCold);
        for kk = 1:numel(fOld)
            if ~isfield(FCout,fOld{kk})
                FCout.(fOld{kk}) = FCold.(fOld{kk});
            end
        end
    catch
    end
catch ME
    warning('FC-GA merge failed, using newly loaded FC only: %s',ME.message);
    FCout = FCnew;
    try, FCout.loaded = true; catch, end
end
end

function key = fcga_subject_key_20260624(subj,idx)
key = '';
try, key = strtrimSafe(subj.sourceFile); catch, end
if isempty(key)
    try, key = strtrimSafe(subj.bundleFile); catch, end
end
if isempty(key)
    try, key = strtrimSafe(subj.roiSourceFile); catch, end
end
if isempty(key)
    try, key = strtrimSafe(subj.name); catch, end
end
if isempty(key)
    key = sprintf('subject_%d',idx);
end
key = lower(strrep(key,'\','/'));
end

function S = fcga_restore_previous_fc_rows_20260624(S,prevFCRowFiles)
% Restore old per-row FC attachments if the new load accidentally cleared them.
try
    S = ensureFCRowFilesSizeGA_TARGETED(S);
    if nargin < 2 || isempty(prevFCRowFiles), return; end
    prevFCRowFiles = prevFCRowFiles(:);
    n = min(numel(prevFCRowFiles),numel(S.fcRowFiles));
    for r = 1:n
        oldFp = ''; newFp = '';
        try, oldFp = strtrimSafe(prevFCRowFiles{r}); catch, oldFp = ''; end
        try, newFp = strtrimSafe(S.fcRowFiles{r}); catch, newFp = ''; end
        if ~isempty(oldFp) && isempty(newFp)
            S.fcRowFiles{r,1} = oldFp;
        end
    end
catch ME
    try, fprintf('FC-GA restore previous row files warning: %s\n',ME.message); catch, end
end
end

function S = fcga_struct_array_assign_union_20260624(S,idx,rec)
% Assign rec into struct array S even if fields differ.
try
    if isempty(S)
        fields = fieldnames(rec);
        S = repmat(fcga_blank_struct_20260624(fields),idx,1);
        rec = fcga_add_missing_fields_20260624(rec,fields);
        S(idx) = orderfields(rec,S);
        return;
    end

    allF = fcga_struct_union_fields_20260624(fieldnames(S),fieldnames(rec));
    S = fcga_add_missing_fields_20260624(S,allF);
    rec = fcga_add_missing_fields_20260624(rec,allF);

    if numel(S) < idx
        blank = fcga_blank_struct_20260624(allF);
        S(numel(S)+1:idx,1) = repmat(blank,idx-numel(S),1);
    end

    try, rec = orderfields(rec,S); catch, end
    S(idx) = rec;
catch ME
    error('FC-GA struct union assignment failed: %s',ME.message);
end
end

function out = fcga_struct_union_fields_20260624(a,b)
out = {};
for ii = 1:numel(a)
    if ~any(strcmp(out,a{ii})), out{end+1,1} = a{ii}; end %#ok<AGROW>
end
for ii = 1:numel(b)
    if ~any(strcmp(out,b{ii})), out{end+1,1} = b{ii}; end %#ok<AGROW>
end
end

function S = fcga_add_missing_fields_20260624(S,fields)
if isempty(S), return; end
for ii = 1:numel(fields)
    if ~isfield(S,fields{ii})
        [S.(fields{ii})] = deal([]);
    end
end
end

function S = fcga_blank_struct_20260624(fields)
S = struct();
for ii = 1:numel(fields)
    S.(fields{ii}) = [];
end
end


function refreshFCSubjectPopup_ADV_20260617(hFig)
% Detailed subject dropdown: group mean + animal/group/scan/file info.
try
    S = guidata(hFig);
    if isempty(S) || ~isfield(S,'FC') || ~isfield(S.FC,'subjects') || isempty(S.FC.subjects), return; end
    if isfield(S,'lastFC') && ~isempty(S.lastFC) && isstruct(S.lastFC)
        fcGARefreshSubjectPopupDetailed_20260624(S,S.lastFC);
    else
        R = struct();
        R.subjectNames = cell(numel(S.FC.subjects),1);
        R.groups = cell(numel(S.FC.subjects),1);
        R.sourceFiles = cell(numel(S.FC.subjects),1);
        for ii=1:numel(S.FC.subjects)
            try, R.subjectNames{ii}=strtrimSafe(S.FC.subjects(ii).name); catch, R.subjectNames{ii}=sprintf('Subject_%02d',ii); end
            try, R.groups{ii}=strtrimSafe(S.FC.subjects(ii).group); catch, R.groups{ii}=''; end
            try, R.sourceFiles{ii}=strtrimSafe(S.FC.subjects(ii).sourceFile); catch, R.sourceFiles{ii}=''; end
        end
        fcGARefreshSubjectPopupDetailed_20260624(S,R);
    end
catch
end
end

function fcGARefreshSubjectPopupDetailed_20260624(S,R)
try
    if ~isfield(S,'hFCSubject') || ~ishghandle(S.hFCSubject), return; end
    oldVal = get(S.hFCSubject,'Value');
    n = 0;
    try, n = numel(R.subjectNames); catch, n = 0; end
    items = cell(n+1,1);
    items{1} = sprintf('Group mean (n=%d)',max(0,n));
    for ii = 1:n
        items{ii+1} = fcGASubjectDisplayName_20260624(R,ii);
    end
    set(S.hFCSubject,'String',items,'Value',max(1,min(oldVal,numel(items))));
catch ME
    try, fprintf('FC-GA subject popup warning: %s\n',ME.message); catch, end
end
end

function label = fcGASubjectDisplayName_20260624(R,ii)
label = sprintf('Subject %02d',ii);
try
    animal = ''; grp = ''; file = '';
    try, animal = strtrimSafe(R.subjectNames{ii}); catch, end
    try, grp = strtrimSafe(R.groups{ii}); catch, end
    try, file = strtrimSafe(R.sourceFiles{ii}); catch, end
    if isempty(animal), animal = sprintf('Subject_%02d',ii); end
    shortFile = fcGAShortFileName_20260624(file);
    if ~isempty(grp) && ~isempty(shortFile)
        label = sprintf('%02d | %s | %s | %s',ii,animal,grp,shortFile);
    elseif ~isempty(shortFile)
        label = sprintf('%02d | %s | %s',ii,animal,shortFile);
    elseif ~isempty(grp)
        label = sprintf('%02d | %s | %s',ii,animal,grp);
    else
        label = sprintf('%02d | %s',ii,animal);
    end
catch
end
end

function s = fcGAShortFileName_20260624(fp)
s = '';
try
    fp = strtrimSafe(fp);
    if isempty(fp), return; end
    [~,nm,ext] = fileparts(fp);
    s = [nm ext];
    s = regexprep(s,'(?i)_?fc_?group.*','');
    s = regexprep(s,'(?i)_?groupanalysis.*','');
    s = regexprep(s,'(?i)_?bundle.*','');
    s = regexprep(s,'[_\-]+','_');
    if numel(s) > 42, s = ['...' s(end-38:end)]; end
catch
    s = '';
end
end

function [Rplot,M0,stack0,subjectNote,subjectIdxReal,isIndividual] = fcGAUseSelectedSubject_20260624(Rfull,Mgroup,stackFull,subjPopupIdx,dispMode)
Rplot = Rfull;
M0 = Mgroup;
stack0 = stackFull;
subjectIdxReal = 0;
isIndividual = false;
subjectNote = 'Group mean';
try
    nSub = size(stackFull,3);
    if subjPopupIdx > 1 && nSub >= 1
        si = max(1,min(subjPopupIdx-1,nSub));
        subjectIdxReal = si;
        isIndividual = true;
        M0 = stackFull(:,:,si);
        stack0 = stackFull(:,:,si);
        Rplot.n = 1;
        try, Rplot.subjectNames = Rfull.subjectNames(si); catch, end
        try, Rplot.groups = Rfull.groups(si); catch, end
        try, Rplot.sourceFiles = Rfull.sourceFiles(si); catch, end
        if strcmpi(dispMode,'Fisher z')
            Rplot.meanZ = M0;
            try, Rplot.meanR = tanh(M0); catch, end
        else
            Rplot.meanR = M0;
            try, Rplot.meanZ = atanh(max(-0.999999,min(0.999999,M0))); catch, end
        end
        subjectNote = fcGASubjectDisplayName_20260624(Rfull,si);
    else
        try, subjectNote = sprintf('Group mean (n=%d)',size(stackFull,3)); catch, end
    end
catch
end
end

function plotSeedProfile_ADV_20260617(ax,stack,seedIdx,roiKeep,R,valTxt,C,S,isIndividual,subjectNote)
if nargin < 8, S = struct(); end
if nargin < 9, isIndividual = false; end
if nargin < 10, subjectNote = ''; end
fcGAResetPlotAxes_20260624(ax,C);
roiKeep = roiKeep(:)';
Y = squeeze(stack(seedIdx,roiKeep,:));
if isvector(Y), Y = reshape(Y,numel(roiKeep),[]); end
if size(Y,1) ~= numel(roiKeep) && size(Y,2) == numel(roiKeep), Y = Y'; end
mu = fcNanMean_SAFE_20260617(Y,2);
sd = fcNanStd_SAFE_20260617(Y,2);
nEff = sum(isfinite(Y),2);
sem = sd ./ sqrt(max(nEff,1));
x = 1:numel(mu);
lineCol = fcGAGetPlotColor_20260624(S,[0.10 0.45 0.95]);
shadeCol = fcGASelectLightShade_20260624(lineCol);
hold(ax,'on');
if ~isIndividual && size(Y,2) > 1
    patch(ax,[x fliplr(x)],[mu(:)'+sem(:)' fliplr(mu(:)'-sem(:)')],shadeCol, ...
        'FaceAlpha',0.35,'EdgeColor','none');
end
plot(ax,x,mu,'LineWidth',2.3,'Color',lineCol);
hold(ax,'off');
set(ax,'Color',C.axisBg,'XColor',C.txt,'YColor',C.txt,'FontSize',9);
grid(ax,'on'); box(ax,'on'); xlim(ax,[0.5 max(1,numel(mu)+0.5)]);
fcGAApplyValueAxis_20260624(ax,S,valTxt);
seedName = fcNiceName_SAFE_20260617(R.names{seedIdx},R.labels(seedIdx),'Abbrev',false);
if isIndividual
    ttl = sprintf('Seed profile: %s | %s',seedName,subjectNote);
else
    ttl = sprintf('Seed profile mean ± SEM: %s | %s',seedName,subjectNote);
end
title(ax,ttl,'Color',C.txt,'FontWeight','bold','Interpreter','none');
xlabel(ax,'Target ROI', 'Color',C.txt,'Interpreter','none');
ylabel(ax,fcGAValueLabel_20260624(valTxt),'Color',C.txt,'Interpreter','none');
labs = fcMakeLabels_SAFE_20260617(R.names(roiKeep),R.labels(roiKeep),'Abbrev','All ROIs');
if numel(roiKeep) <= 32
    set(ax,'XTick',x,'XTickLabel',labs);
else
    ticks = round(linspace(1,numel(roiKeep),32));
    set(ax,'XTick',ticks,'XTickLabel',labs(ticks));
end
try, xtickangle(ax,55); catch, end
try, legend(ax,'off'); catch, end
end

function fcGAResetPlotAxes_20260624(ax,C)
try, delete(findall(ancestor(ax,'figure'),'Type','ColorBar')); catch, end
try, cla(ax,'reset'); catch, cla(ax); end
try, set(ax,'Units','normalized','Position',[0.095 0.110 0.765 0.825]); catch, end
try
    set(ax,'Color',C.axisBg,'XColor',C.txt,'YColor',C.txt, ...
        'XTickMode','auto','YTickMode','auto', ...
        'XTickLabelMode','auto','YTickLabelMode','auto', ...
        'YDir','normal','TickLabelInterpreter','none');
catch
end
end

function fcGAApplyValueAxis_20260624(ax,S,valTxt)
try
    set(ax,'YTickMode','auto','YTickLabelMode','auto');
catch
end
try, fcApplyY_SAFE_20260617(ax,S); catch, end
try
    yl = ylim(ax);
    if numel(yl)==2 && yl(1)==yl(2)
        ylim(ax,yl + [-0.1 0.1]);
    end
catch
end
end

function s = fcGAValueLabel_20260624(valTxt)
s = valTxt;
try
    if isempty(strfind(lower(valTxt),'pearson')) && isempty(strfind(lower(valTxt),'fisher'))
        s = 'FC value';
    end
catch
    s = 'FC value';
end
end

function col = fcGAGetPlotColor_20260624(S,defaultCol)
col = defaultCol;
try
    if isfield(S,'hFCPlotColor') && ishghandle(S.hFCPlotColor)
        items = get(S.hFCPlotColor,'String');
        if ischar(items), items = cellstr(items); end
        v = get(S.hFCPlotColor,'Value');
        name = lower(strtrim(items{max(1,min(v,numel(items)))}));
        if ~isempty(strfind(name,'red')), col = [0.85 0.20 0.20]; end
        if ~isempty(strfind(name,'green')), col = [0.20 0.65 0.25]; end
        if ~isempty(strfind(name,'black')), col = [0.02 0.02 0.02]; end
        if ~isempty(strfind(name,'gray')) || ~isempty(strfind(name,'grey')), col = [0.45 0.45 0.45]; end
        if ~isempty(strfind(name,'blue')), col = [0.10 0.45 0.95]; end
    end
catch
end
end

function shade = fcGASelectLightShade_20260624(lineCol)
shade = 0.70 + 0.30*lineCol;
try
    if lineCol(3) >= max(lineCol(1),lineCol(2))
        shade = [0.65 0.82 1.00];
    end
catch
end
end


function updateFCTabPreview_ADV_20260617(S)
% FC-GA preview update with correct group mean / individual animal logic.
try, fcGADefaultDisplayFisher_20260624(S); catch, end
if ~isfield(S,'isLargeFCGA') || ~S.isLargeFCGA
    try, fcGACleanFinalLayout_20260624(S); catch, end
    try, fcGAFixRow2Overlap_FORCE_20260624(S); catch, end
end

Rfull = S.lastFC;
if isempty(Rfull) || ~isstruct(Rfull)
    try, fcNoDataLocal(S.axFCA,'No FC-GA result loaded/recomputed',S.C); catch, end
    return;
end

try, fcGARefreshSubjectPopupDetailed_20260624(S,Rfull); catch, end
if ~isfield(S,'isLargeFCGA') || ~S.isLargeFCGA
    try, setSingleFCAxis_SINGLE_20260616(S); catch, end
end

viewMode  = popupString_SINGLE_20260616(S,'hFCView','Heatmap');
dispMode  = popupString_SINGLE_20260616(S,'hFCDisplay','Fisher z');
hemiMode  = popupString_SINGLE_20260616(S,'hFCHemi','All');
labelMode = popupString_SINGLE_20260616(S,'hFCLabelMode','Abbrev');
cmapName  = popupString_SINGLE_20260616(S,'hFCColorMap','Blue-White-Red');

thr = 0;
try, thr = safeNum(get(S.hFCThreshold,'String'),0); catch, end

if ~isempty(strfind(lower(dispMode),'fisher'))
    Mgroup = Rfull.meanZ;
    stackFull = Rfull.Zstack;
    clim = [-2.5 2.5];
    valTxt = 'Fisher z';
else
    Mgroup = Rfull.meanR;
    stackFull = Rfull.Rstack;
    clim = [-1 1];
    valTxt = 'Pearson r';
end

subjPopupIdx = popupIndex_SINGLE_20260616(S,'hFCSubject',1);
[Rplot,M0,stack0,subjectNote,subjectIdxReal,isIndividual] = fcGAUseSelectedSubject_20260624(Rfull,Mgroup,stackFull,subjPopupIdx,dispMode);

if thr > 0
    M0(abs(M0) < thr) = 0;
end

seedIdx0 = popupIndex_SINGLE_20260616(S,'hFCRegion1',1);
roi2Idx0 = popupIndex_SINGLE_20260616(S,'hFCRegion2',min(2,size(M0,1)));
seedIdx0 = max(1,min(seedIdx0,size(M0,1)));
roi2Idx0 = max(1,min(roi2Idx0,size(M0,1)));

% Important fix: ROI subset is chosen from GROUP MEAN, not from the selected animal.
% Therefore animal 01 and animal 02 show the same regions; only values change.
selNote = 'all ROIs';
selIdx = 1:size(M0,1);
try
    [tmpSel,tmpNote] = fcGASelectedOrTopROIIdx_20260622(S,Rfull,Mgroup,seedIdx0,roi2Idx0,20);
    if ~isempty(tmpSel)
        selIdx = tmpSel(:)';
        selNote = tmpNote;
    end
catch
end

Rsmall = Rplot;
Msmall = M0;
stackSmall = stack0;
seedSmall = seedIdx0;
roi2Small = roi2Idx0;
if ~isempty(selIdx) && numel(selIdx) < size(M0,1)
    selIdx = selIdx(selIdx >= 1 & selIdx <= size(M0,1));
    Msmall = M0(selIdx,selIdx);
    stackSmall = stack0(selIdx,selIdx,:);
    Rsmall.names = Rplot.names(selIdx);
    Rsmall.labels = Rplot.labels(selIdx);
    try, Rsmall.meanR = Rplot.meanR(selIdx,selIdx); catch, end
    try, Rsmall.meanZ = Rplot.meanZ(selIdx,selIdx); catch, end
    seedSmall = find(selIdx == seedIdx0,1,'first'); if isempty(seedSmall), seedSmall = 1; end
    roi2Small = find(selIdx == roi2Idx0,1,'first'); if isempty(roi2Small), roi2Small = min(2,numel(selIdx)); end
end

[Mhemi,~,~,rowIdx,colIdx,hemiTitle] = applyHemisphereMode_ADV_20260617(Msmall,Rsmall.names,Rsmall.labels,hemiMode);
namesY = Rsmall.names(rowIdx); labelsY = Rsmall.labels(rowIdx);
namesX = Rsmall.names(colIdx); labelsX = Rsmall.labels(colIdx);

switch lower(viewMode)
    case 'heatmap'
        plotFCMatrix_CLEAN_20260617(S.axFCA,Mhemi,clim, ...
            sprintf('%s FC heatmap | %s | %s | %s | %s',Rfull.groupName,hemiTitle,valTxt,subjectNote,selNote), ...
            namesX,namesY,labelsX,labelsY,S.C,cmapName,labelMode,hemiTitle);

    case {'subject matrix'}
        plotFCMatrix_CLEAN_20260617(S.axFCA,Mhemi,clim, ...
            sprintf('Subject matrix | %s | %s | %s | %s',subjectNote,hemiTitle,valTxt,selNote), ...
            namesX,namesY,labelsX,labelsY,S.C,cmapName,labelMode,hemiTitle);

    case {'seed profile +/- sd','seed profile ± sd','seed profile'}
        plotSeedProfile_ADV_20260617(S.axFCA,stackSmall,seedSmall,1:size(stackSmall,2),Rsmall,valTxt,S.C,S,isIndividual,subjectNote);

    case {'animal pair values','roi trace'}
        plotAnimalPairValues_ADV_20260617(S.axFCA,stack0,seedIdx0,roi2Idx0,Rplot,valTxt,S.C,S,subjectIdxReal);

    case {'roi pair summary','roi pair'}
        plotROIPairSummary_ADV_20260617(S.axFCA,stack0,seedIdx0,roi2Idx0,Rplot,valTxt,S.C,S,isIndividual,subjectNote);

    otherwise
        plotROIOverlay_ADV_20260617(S.axFCA,S,Rplot,cmapName);
end

try, fcGAHeatmapFontSmall_20260624(S.axFCA,viewMode); catch, end

try
    set(S.hFCInfo,'String',sprintf('Loaded %d FC subject(s). Showing %s, n=%d | %s | %s | %s | Slice=%s | Seed=%s | ROI2=%s', ...
        numel(S.FC.subjects),Rfull.groupName,Rfull.n,viewMode,hemiMode,subjectNote,Rfull.sliceMode, ...
        roiName_SINGLE_20260616(Rfull,seedIdx0),roiName_SINGLE_20260616(Rfull,roi2Idx0)));
catch
end
end

function fcGADefaultDisplayFisher_20260624(S)
% Fisher z is the better default for group-level FC averaging.
% Applied once per GUI instance; user can still switch manually to Pearson r.
try
    if ~isfield(S,'hFCDisplay') || ~ishghandle(S.hFCDisplay), return; end
    fig = ancestor(S.hFCDisplay,'figure');
    if isempty(fig) || ~ishghandle(fig), return; end
    if isappdata(fig,'FCGA_FISHER_DEFAULT_DONE'), return; end
    items = get(S.hFCDisplay,'String');
    if ischar(items), items = cellstr(items); end
    hit = [];
    for ii = 1:numel(items)
        if ~isempty(strfind(lower(items{ii}),'fisher'))
            hit = ii; break;
        end
    end
    if ~isempty(hit), set(S.hFCDisplay,'Value',hit); end
    setappdata(fig,'FCGA_FISHER_DEFAULT_DONE',true);
catch
end
end

function fcGAHeatmapFontSmall_20260624(ax,viewMode)
try
    if isempty(ax) || ~ishghandle(ax), return; end
    vm = lower(strtrim(viewMode));
    if isempty(strfind(vm,'heatmap')) && isempty(strfind(vm,'matrix')), return; end
    nLab = max(numel(get(ax,'XTickLabel')),numel(get(ax,'YTickLabel')));
    if nLab > 90
        set(ax,'FontSize',4);
    elseif nLab > 60
        set(ax,'FontSize',5);
    elseif nLab > 35
        set(ax,'FontSize',6);
    else
        set(ax,'FontSize',8);
    end
    try, set(ax,'TickLabelInterpreter','none'); catch, end
catch
end
end

function plotAnimalPairValues_ADV_20260617(ax,stack,seedIdx,roi2Idx,R,valTxt,C,S,selectedSubjectIdx)
if nargin < 8, S = struct(); end
if nargin < 9, selectedSubjectIdx = 0; end
try, fcGAResetPlotAxes_20260624(ax,C); catch, cla(ax,'reset'); end
vals = squeeze(stack(seedIdx,roi2Idx,:)); vals = vals(:);
n = numel(vals); x = 1:n;
subjLabsFull = fcGASubjectLabelsFromR_20260624(R);
subjLabs = fcGATickLabelsCompact_20260624(subjLabsFull,18);
cols = lines(max(n,1));
meanCol = [1.00 0.55 0.05];
hold(ax,'on');
for ii = 1:n
    if ii == selectedSubjectIdx, ms = 13; lw = 2.6; else, ms = 11; lw = 1.8; end
    plot(ax,x(ii),vals(ii),'o','Color',cols(ii,:),'MarkerFaceColor',cols(ii,:), ...
        'MarkerSize',ms,'LineWidth',lw,'DisplayName',subjLabs{ii});
end
[mu,sem,nEff] = fcGAMeanSem_20260624(vals);
if isfinite(mu)
    errorbar(ax,n+0.65,mu,sem,'d','Color',meanCol,'MarkerFaceColor',meanCol, ...
        'MarkerEdgeColor',meanCol,'MarkerSize',12,'LineWidth',2.4,'CapSize',14, ...
        'DisplayName',sprintf('Mean +/- SEM, n=%d',nEff));
end
hold(ax,'off');
set(ax,'Color',C.axisBg,'XColor',C.txt,'YColor',C.txt,'FontSize',11);
grid(ax,'on'); box(ax,'on');
xlim(ax,[0.5 max(1,n+1.1)]);
fcGAAutoValueYLim_20260624(ax,vals,valTxt);
set(ax,'XTick',[x n+0.65],'XTickLabel',[subjLabs(:); {'Mean'}]);
try, xtickangle(ax,35); catch, end
seedName = fcNiceName_SAFE_20260617(R.names{seedIdx},R.labels(seedIdx),'Abbrev',false);
roiName  = fcNiceName_SAFE_20260617(R.names{roi2Idx},R.labels(roi2Idx),'Abbrev',false);
title(ax,sprintf('Animal pair values: %s <-> %s',seedName,roiName),'Color',C.txt,'FontWeight','bold','Interpreter','none');
ylabel(ax,valTxt,'Color',C.txt,'Interpreter','none');
xlabel(ax,'Animal / scan','Color',C.txt,'Interpreter','none');
try
    if n <= 10
        lg = legend(ax,'show','Location','eastoutside');
        set(lg,'Interpreter','none','TextColor',C.txt,'Color',[0.10 0.10 0.11]);
    end
catch
end
end

function plotROIPairSummary_ADV_20260617(ax,stack,seedIdx,roi2Idx,R,valTxt,C,S,isIndividual,subjectNote)
if nargin < 8, S = struct(); end
if nargin < 9, isIndividual = false; end
if nargin < 10, subjectNote = ''; end
try, fcGAResetPlotAxes_20260624(ax,C); catch, cla(ax,'reset'); end
vals = squeeze(stack(seedIdx,roi2Idx,:)); vals = vals(:);
lineCol = fcGAGetPlotColor_20260624(S,[0.10 0.45 0.95]);
meanCol = [1.00 0.55 0.05];
hold(ax,'on');
if isIndividual || numel(vals) == 1
    plot(ax,1,vals(1),'o','MarkerSize',13,'LineWidth',2.4,'Color',lineCol,'MarkerFaceColor',lineCol,'DisplayName',subjectNote);
    xlim(ax,[0.5 1.5]);
    tmpLab = fcGATickLabelsCompact_20260624({subjectNote},18);
    set(ax,'XTick',1,'XTickLabel',tmpLab);
    nTxt = 1;
else
    subjLabsFull = fcGASubjectLabelsFromR_20260624(R);
    subjLabs = fcGATickLabelsCompact_20260624(subjLabsFull,18);
    n = numel(vals); x = 1:n;
    cols = lines(max(n,1));
    for ii = 1:n
        plot(ax,x(ii),vals(ii),'o','Color',cols(ii,:),'MarkerFaceColor',cols(ii,:), ...
            'MarkerSize',11,'LineWidth',1.8,'DisplayName',subjLabs{ii});
    end
    [mu,sem,nEff] = fcGAMeanSem_20260624(vals);
    if isfinite(mu)
        errorbar(ax,n+0.65,mu,sem,'d','Color',meanCol,'MarkerFaceColor',meanCol, ...
            'MarkerEdgeColor',meanCol,'MarkerSize',12,'LineWidth',2.4,'CapSize',14, ...
            'DisplayName',sprintf('Mean +/- SEM, n=%d',nEff));
    end
    xlim(ax,[0.5 n+1.1]);
    set(ax,'XTick',[x n+0.65],'XTickLabel',[subjLabs(:); {'Mean'}]);
    nTxt = nEff;
end
hold(ax,'off');
set(ax,'Color',C.axisBg,'XColor',C.txt,'YColor',C.txt,'FontSize',11);
grid(ax,'on'); box(ax,'on');
try, xtickangle(ax,35); catch, end
fcGAAutoValueYLim_20260624(ax,vals,valTxt);
seedName = fcNiceName_SAFE_20260617(R.names{seedIdx},R.labels(seedIdx),'Abbrev',false);
roiName  = fcNiceName_SAFE_20260617(R.names{roi2Idx},R.labels(roi2Idx),'Abbrev',false);
title(ax,sprintf('ROI pair summary: %s <-> %s | %s | n=%d',seedName,roiName,subjectNote,nTxt),'Color',C.txt,'FontWeight','bold','Interpreter','none');
ylabel(ax,valTxt,'Color',C.txt,'Interpreter','none');
xlabel(ax,'Animal / scan','Color',C.txt,'Interpreter','none');
try
    if numel(vals) <= 10 && ~isIndividual
        lg = legend(ax,'show','Location','eastoutside');
        set(lg,'Interpreter','none','TextColor',C.txt,'Color',[0.10 0.10 0.11]);
    end
catch
end
end

function labs = fcGASubjectLabelsFromR_20260624(R)
n = 0;
try, n = numel(R.subjectNames); catch, n = 0; end
if n < 1, n = 1; end
labs = cell(n,1);
for ii = 1:n
    try, labs{ii} = fcGASubjectDisplayName_20260624(R,ii); catch, labs{ii} = sprintf('Animal %02d',ii); end
end
end

function labsOut = fcGATickLabelsCompact_20260624(labsIn,maxN)
if nargin < 2, maxN = 18; end
if ischar(labsIn), labsIn = {labsIn}; end
labsOut = labsIn(:);
animals = cell(numel(labsOut),1);
for ii = 1:numel(labsOut), animals{ii} = fcGAExtractAnimalFromLabel_20260624(labsOut{ii}); end
for ii = 1:numel(labsOut)
    animal = animals{ii};
    if isempty(animal), animal = 'Animal'; end
    same = find(strcmp(animals,animal));
    if numel(same) > 1
        occ = find(same == ii,1,'first');
        s = sprintf('%s %02d',animal,occ);
    else
        s = animal;
    end
    if numel(s) > maxN, s = [s(1:maxN-3) '...']; end
    labsOut{ii} = s;
end
end

function animal = fcGAExtractAnimalFromLabel_20260624(s)
animal = '';
try
    if iscell(s), s = s{1}; end
    s = strtrim(char(s));
    parts = regexp(s,'\s*\|\s*','split');
    if numel(parts) >= 2, animal = strtrim(parts{2}); else, animal = strtrim(s); end
    animal = regexprep(animal,'(?i)^subject[_\s-]*','');
    animal = regexprep(animal,'\s+',' ');
    tok = regexp(animal,'(\d{3,6})','tokens','once');
    if ~isempty(tok), animal = tok{1}; end
catch
    animal = '';
end
end

function [mu,sem,nEff] = fcGAMeanSem_20260624(vals)
vals = vals(:); vals = vals(isfinite(vals));
nEff = numel(vals);
if nEff < 1, mu = NaN; sem = NaN; return; end
mu = mean(vals);
if nEff > 1, sem = std(vals,0) ./ sqrt(nEff); else, sem = 0; end
end

function fcGAAutoValueYLim_20260624(ax,vals,valTxt)
try
    vals = vals(:); vals = vals(isfinite(vals));
    if isempty(vals), return; end
    lo = min(vals); hi = max(vals);
    if lo == hi, pad = 0.10; else, pad = 0.18 * (hi - lo); end
    lo = lo - pad; hi = hi + pad;
    if ~isempty(strfind(lower(valTxt),'pearson')), lo = max(-1,lo); hi = min(1,hi); end
    if lo == hi, lo = lo - 0.1; hi = hi + 0.1; end
    ylim(ax,[lo hi]);
    set(ax,'YTick',linspace(lo,hi,5));
    set(ax,'YTickLabelMode','auto');
catch
end
end

function showFCLargeView_GA_20260622(hFig)
try
    S = guidata(hFig);
    if isempty(S) || ~isfield(S,'lastFC') || isempty(S.lastFC)
        errordlg('No FC-GA result loaded/recomputed yet.','FC-GA large view'); return;
    end
    try, fcGARefreshSubjectPopupDetailed_20260624(S,S.lastFC); catch, end
    f = figure('Name','FC-GA Large View','Color',[0.05 0.05 0.055],'Units','pixels','Position',[80 60 1450 860],'NumberTitle','off','MenuBar','none','ToolBar','figure');
    ax = axes('Parent',f,'Units','normalized','Position',[0.060 0.110 0.705 0.820]);
    p = uipanel('Parent',f,'Units','normalized','Position',[0.790 0.060 0.195 0.880],'Title','Functional Connectivity Group Analysis','FontSize',12,'FontWeight','bold','ForegroundColor',[1 1 1],'BackgroundColor',[0.08 0.08 0.09]);
    y = 0.920; dy = 0.070;
    fcGALargeMakeText_20260624(p,'Subject',y); D.hSubject = fcGALargeMakePopup_20260624(p,fcGALargeCopyString_20260624(S,'hFCSubject',{'Group mean'}),fcGALargeValue_20260624(S,'hFCSubject',1),y-0.035); y = y-dy;
    fcGALargeMakeText_20260624(p,'View',y); D.hView = fcGALargeMakePopup_20260624(p,fcGALargeCopyString_20260624(S,'hFCView',{'Heatmap'}),fcGALargeValue_20260624(S,'hFCView',1),y-0.035); y = y-dy;
    fcGALargeMakeText_20260624(p,'Display',y); D.hDisplay = fcGALargeMakePopup_20260624(p,fcGALargeCopyString_20260624(S,'hFCDisplay',{'Fisher z','Pearson r'}),fcGALargeValue_20260624(S,'hFCDisplay',1),y-0.035); y = y-dy;
    fcGALargeMakeText_20260624(p,'Hemisphere',y); D.hHemi = fcGALargeMakePopup_20260624(p,fcGALargeCopyString_20260624(S,'hFCHemi',{'All'}),fcGALargeValue_20260624(S,'hFCHemi',1),y-0.035); y = y-dy;
    fcGALargeMakeText_20260624(p,'Labels',y); D.hLabel = fcGALargeMakePopup_20260624(p,fcGALargeCopyString_20260624(S,'hFCLabelMode',{'Abbrev','Full','ID'}),fcGALargeValue_20260624(S,'hFCLabelMode',1),y-0.035); y = y-dy;
    fcGALargeMakeText_20260624(p,'Color map',y); D.hColor = fcGALargeMakePopup_20260624(p,fcGALargeCopyString_20260624(S,'hFCColorMap',{'Blue-White-Red'}),fcGALargeValue_20260624(S,'hFCColorMap',1),y-0.035); y = y-dy;
    fcGALargeMakeText_20260624(p,'Seed',y); D.hSeed = fcGALargeMakePopup_20260624(p,fcGALargeCopyString_20260624(S,'hFCRegion1',{'1'}),fcGALargeValue_20260624(S,'hFCRegion1',1),y-0.035); y = y-dy;
    fcGALargeMakeText_20260624(p,'ROI 2',y); D.hROI2 = fcGALargeMakePopup_20260624(p,fcGALargeCopyString_20260624(S,'hFCRegion2',{'2'}),fcGALargeValue_20260624(S,'hFCRegion2',1),y-0.035); y = y-dy;
    fcGALargeMakeText_20260624(p,'Slice',y); D.hSlice = fcGALargeMakePopup_20260624(p,fcGALargeCopyString_20260624(S,'hFCSlice',{'All'}),fcGALargeValue_20260624(S,'hFCSlice',1),y-0.035);
    uicontrol('Parent',p,'Style','pushbutton','Units','normalized','Position',[0.08 0.080 0.38 0.060],'String','Update','FontSize',12,'FontWeight','bold','Callback',@(src,evt)fcGALargeReplot_20260622(f));
    uicontrol('Parent',p,'Style','pushbutton','Units','normalized','Position',[0.54 0.080 0.38 0.060],'String','Export PNG','FontSize',12,'FontWeight','bold','Callback',@(src,evt)fcExportLargeView_GA_20260622(f));
    D.hInfo = uicontrol('Parent',f,'Style','text','Units','normalized','Position',[0.060 0.020 0.705 0.040],'String','','HorizontalAlignment','left','BackgroundColor',[0.05 0.05 0.055],'ForegroundColor',[0.75 0.90 1.00],'FontSize',9);
    D.S = S; D.ax = ax; D.mainFig = hFig;
    D.hThr = uicontrol('Parent',p,'Style','edit','Visible','off','String','0');
    guidata(f,D);
    fcGALargeReplot_20260622(f);
catch ME
    errordlg(sprintf('Large FC-GA view failed:\n%s',ME.message),'FC-GA large view');
end
end

function fcGALargeReplot_20260622(f)
try
    D = guidata(f); S = D.S;
    S.axFCA = D.ax;
    S.isLargeFCGA = true;
    S.hFCSubject = D.hSubject;
    S.hFCView = D.hView;
    S.hFCDisplay = D.hDisplay;
    S.hFCHemi = D.hHemi;
    S.hFCLabelMode = D.hLabel;
    S.hFCColorMap = D.hColor;
    S.hFCRegion1 = D.hSeed;
    S.hFCRegion2 = D.hROI2;
    S.hFCSlice = D.hSlice;
    S.hFCThreshold = D.hThr;
    S.hFCInfo = D.hInfo;
    updateFCTabPreview_ADV_20260617(S);
catch ME
    try, fprintf('FC-GA large replot warning: %s\n',ME.message); catch, end
end
end

function fcExportLargeView_GA_20260622(f)
try
    [fn,fp] = uiputfile('FCGA_large_view.png','Export FC-GA large view PNG');
    if isequal(fn,0), return; end
    out = fullfile(fp,fn);
    try, exportgraphics(f,out,'Resolution',220); catch, print(f,out,'-dpng','-r220'); end
catch ME
    errordlg(sprintf('Export failed:\n%s',ME.message),'FC-GA export');
end
end

function items = fcGALargeCopyString_20260624(S,fieldName,fallback)
items = fallback;
try
    if isfield(S,fieldName) && ishghandle(S.(fieldName))
        items = get(S.(fieldName),'String');
        if ischar(items), items = cellstr(items); end
        if isempty(items), items = fallback; end
    end
catch, items = fallback; end
end

function v = fcGALargeValue_20260624(S,fieldName,defaultValue)
v = defaultValue;
try, if isfield(S,fieldName) && ishghandle(S.(fieldName)), v = get(S.(fieldName),'Value'); end, catch, end
end

function h = fcGALargeMakePopup_20260624(parentHandle,items,val,y)
if ischar(items), items = cellstr(items); end
val = max(1,min(val,numel(items)));
h = uicontrol('Parent',parentHandle,'Style','popupmenu','Units','normalized','Position',[0.08 y 0.84 0.045],'String',items,'Value',val,'FontSize',10.5,'BackgroundColor',[0.12 0.12 0.13],'ForegroundColor',[1 1 1]);
try, set(h,'Callback',@(src,evt)fcGALargeReplot_20260622(ancestor(src,'figure'))); catch, end
end

function fcGALargeMakeText_20260624(parentHandle,label,y)
uicontrol('Parent',parentHandle,'Style','text','Units','normalized','Position',[0.08 y 0.84 0.030],'String',label,'HorizontalAlignment','left','FontSize',10.5,'FontWeight','bold','BackgroundColor',[0.08 0.08 0.09],'ForegroundColor',[1 1 1]);
end
