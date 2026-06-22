
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
S.fcRowFiles = cell(0,1);      % FC row-specific bundle paths
S.fcAtlasLabelFile = '';     % optional Allen/Waxholm label file
S.fcSeedRegion = '';         % optional seed/region name or label
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
S.tableColWidths = {38 126 56 96 94 78 78 62 72 112};

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
colNames = {'Use','Animal ID','Session','Scan ID','Group','Condition','ROI File','Bundle File','FC File','Status'};
colEdit  = [true true false false true true false false false false];
colFmt   = {'logical','char','char','char',S.groupList,S.condList,'char','char','char','char'};

S.hTable = uitable(pLeft, ...
    'Units','normalized', ...
    'Position',[0.03 0.42 0.70 0.55], ...
    'Data',makeUITableDisplayData(S.subj,S.tableMinRows,localGA_getFCRowFilesV12(S)), ...
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
    'FontName','Consolas','FontSize',11);

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
    'HorizontalAlignment','left','FontName','Consolas','FontSize',11);

%%% =====================================================================
%%% FC TAB
%%% =====================================================================
pFCBG = uipanel(S.tabFC,'Units','normalized','Position',[0 0 1 1], ...
    'BorderType','none','BackgroundColor',C.bg);

pFCTop = uipanel(pFCBG,'Units','normalized','Position',[0.02 0.695 0.96 0.300], ...
    'Title','Functional Connectivity group analysis', ...
    'BackgroundColor',bg2,'ForegroundColor','w','FontWeight','bold');

S.hFCLoad = mkBtn(pFCTop,'Load FC Bundles',[0.010 0.720 0.120 0.220],C.btnAction,@onLoadFCGroupBundles);
S.hFCScan = mkBtn(pFCTop,'Scan Folder',[0.140 0.720 0.090 0.220],C.btnSecondary,@onScanFCGroupFolder);
S.hFCLoadAtlas = mkBtn(pFCTop,'Atlas TXT/Auto',[0.240 0.720 0.120 0.220],C.btnSecondary,@onLoadFCAtlasLabels);

uicontrol(pFCTop,'Style','text','String','Grp A:', ...
    'Units','normalized','Position',[0.385 0.805 0.060 0.090], ...
    'BackgroundColor',bg2,'ForegroundColor','w', ...
    'HorizontalAlignment','left','FontWeight','bold','FontSize',11);
S.hFCGroupA = uicontrol(pFCTop,'Style','popupmenu','String',S.groupList, ...
    'Units','normalized','Position',[0.445 0.760 0.105 0.165], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w', ...
    'Callback',@updateFCTabPreview);

uicontrol(pFCTop,'Style','text','String','Grp B:', ...
    'Units','normalized','Position',[0.565 0.805 0.060 0.090], ...
    'BackgroundColor',bg2,'ForegroundColor','w', ...
    'HorizontalAlignment','left','FontWeight','bold','FontSize',11);
S.hFCGroupB = uicontrol(pFCTop,'Style','popupmenu','String',S.groupList, ...
    'Units','normalized','Position',[0.625 0.760 0.105 0.165], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w', ...
    'Callback',@updateFCTabPreview);

S.hFCCompute = mkBtn(pFCTop,'Compute FC',[0.755 0.720 0.105 0.220],C.btnPrimary,@onComputeGroupFC);
S.hFCExport  = mkBtn(pFCTop,'Export All FC',[0.875 0.720 0.110 0.220],C.btnAction,@onExportGroupFC);

uicontrol(pFCTop,'Style','text','String','View:', ...
    'Units','normalized','Position',[0.010 0.465 0.045 0.090], ...
    'BackgroundColor',bg2,'ForegroundColor','w', ...
    'HorizontalAlignment','left','FontWeight','bold','FontSize',11);
S.hFCView = uicontrol(pFCTop,'Style','popupmenu', ...
    'String',{'Matrix summary','Seed profile','Pair correlation','Max connections','ROI time course','Subject heatmap','Region graph'}, ...
    'Units','normalized','Position',[0.055 0.420 0.140 0.165], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w', ...
    'Callback',@updateFCTabPreview);

uicontrol(pFCTop,'Style','text','String','Show:', ...
    'Units','normalized','Position',[0.205 0.465 0.045 0.090], ...
    'BackgroundColor',bg2,'ForegroundColor','w', ...
    'HorizontalAlignment','left','FontWeight','bold','FontSize',11);
S.hFCActiveGroup = uicontrol(pFCTop,'Style','popupmenu','String',{'Group A'}, ...
    'Units','normalized','Position',[0.250 0.420 0.120 0.165], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w', ...
    'Callback',@updateFCTabPreview);

uicontrol(pFCTop,'Style','text','String','Hemi:', ...
    'Units','normalized','Position',[0.385 0.465 0.050 0.090], ...
    'BackgroundColor',bg2,'ForegroundColor','w', ...
    'HorizontalAlignment','left','FontWeight','bold','FontSize',11);
S.hFCHemiMode = uicontrol(pFCTop,'Style','popupmenu', ...
    'String',{'All / merged','Left only','Right only','Left vs Right'}, ...
    'Units','normalized','Position',[0.435 0.420 0.135 0.165], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w', ...
    'Callback',@updateFCTabPreview);

uicontrol(pFCTop,'Style','text','String','Units:', ...
    'Units','normalized','Position',[0.585 0.465 0.050 0.090], ...
    'BackgroundColor',bg2,'ForegroundColor','w', ...
    'HorizontalAlignment','left','FontWeight','bold','FontSize',11);
S.hFCDisplay = uicontrol(pFCTop,'Style','popupmenu','String',{'Pearson r','Fisher z'}, ...
    'Units','normalized','Position',[0.635 0.420 0.090 0.165], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w', ...
    'Callback',@updateFCTabPreview);

uicontrol(pFCTop,'Style','text','String','Hide |r|<', ...
    'Units','normalized','Position',[0.740 0.465 0.075 0.090], ...
    'BackgroundColor',bg2,'ForegroundColor','w', ...
    'HorizontalAlignment','left','FontWeight','bold','FontSize',11);
S.hFCThreshold = uicontrol(pFCTop,'Style','edit','String','0', ...
    'Units','normalized','Position',[0.815 0.420 0.055 0.165], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w', ...
    'Callback',@updateFCTabPreview);
S.hFCHelp = mkBtn(pFCTop,'Help',[0.890 0.405 0.095 0.190],C.btnSecondary,@onFCHelpV15);

uicontrol(pFCTop,'Style','text','String','ROI 1:', ...
    'Units','normalized','Position',[0.010 0.170 0.055 0.090], ...
    'BackgroundColor',bg2,'ForegroundColor','w', ...
    'HorizontalAlignment','left','FontWeight','bold','FontSize',11);
S.hFCRegion1 = uicontrol(pFCTop,'Style','popupmenu','String',{'Compute/load FC first'}, ...
    'Units','normalized','Position',[0.065 0.105 0.360 0.175], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w', ...
    'Callback',@onFCRegionChangedV15);

uicontrol(pFCTop,'Style','text','String','ROI 2:', ...
    'Units','normalized','Position',[0.445 0.170 0.055 0.090], ...
    'BackgroundColor',bg2,'ForegroundColor','w', ...
    'HorizontalAlignment','left','FontWeight','bold','FontSize',11);
S.hFCRegion2 = uicontrol(pFCTop,'Style','popupmenu','String',{'Compute/load FC first'}, ...
    'Units','normalized','Position',[0.500 0.105 0.360 0.175], ...
    'BackgroundColor',C.editBg,'ForegroundColor','w', ...
    'Callback',@updateFCTabPreview);
S.hFCRefreshRegions = mkBtn(pFCTop,'Refresh',[0.875 0.095 0.110 0.195],C.btnSecondary,@onRefreshFCRegionMenusV15);

% Hidden legacy seed edit.
S.hFCSeedRegion = uicontrol(pFCTop,'Style','edit','String','', ...
    'Units','normalized','Position',[0.001 0.001 0.001 0.001], ...
    'Visible','off');
try
    set(findall(pFCTop,'Style','text'),'FontSize',11,'FontWeight','bold');
catch
end









pFCAx = uipanel(pFCBG,'Units','normalized','Position',[0.02 0.095 0.96 0.570], ...
    'Title','FC matrices', ...
    'BackgroundColor',bg2,'ForegroundColor','w','FontWeight','bold');
S.hFCInfo = uicontrol(pFCBG,'Style','text', ...
    'String','FC status appears here. Select one table row before loading if you want row-specific FC assignment.', ...
    'Units','normalized','Position',[0.02 0.020 0.96 0.045], ...
    'BackgroundColor',bg2,'ForegroundColor',[0.75 0.80 0.90], ...
    'HorizontalAlignment','left','FontSize',11);









S.axFCA = axes('Parent',pFCAx,'Units','normalized','Position',[0.060 0.100 0.875 0.835]);
S.axFCB = axes('Parent',pFCAx,'Units','normalized','Position',[0.570 0.565 0.365 0.360],'Visible','off');
S.axFCD = axes('Parent',pFCAx,'Units','normalized','Position',[0.060 0.090 0.365 0.360],'Visible','off');
S.axFCP = axes('Parent',pFCAx,'Units','normalized','Position',[0.570 0.090 0.365 0.360],'Visible','off');

fcNoDataLocal(S.axFCA,'Group A mean FC',C);
fcNoDataLocal(S.axFCB,'Group B mean FC',C);
fcNoDataLocal(S.axFCD,'Difference: A - B',C);
fcNoDataLocal(S.axFCP,'p-value map',C);

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
        'Value',0,'BackgroundColor',bg2,'ForegroundColor','w','FontSize',11, ...
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
guidata(hFig,S);
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
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
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
        updateSelLabel();
    end

    function onCellEdit(~,~)
        syncSubjFromTable();
        S0 = guidata(hFig);
        S0 = sanitizeTableStruct(S0);
        guidata(hFig,S0);
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
        refreshTable();
    end

    function onApplyAllToggle(src,~)
        S0 = guidata(hFig);
        S0.applyAllIfNoneSelected = logical(get(src,'Value'));
        guidata(hFig,S0);
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
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
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
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
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
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
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
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
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
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
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
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
        try, startPath = localGA_forceLoadedDataBundleDirV39(S0,startPath); catch, end % ADDBUNDLES_FORCE_LOADED_DATA_DIR_V39
        [f,p] = uigetfile({'*.mat;*.txt','MAT or TXT (*.mat, *.txt)'}, ...
            'Select DATA / ROI / bundle files',startPath,'MultiSelect','on');
        if isequal(f,0), return; end
        if ischar(f), f = {f}; end
        for i = 1:numel(f)
            S0 = addFileSmartLight(S0,fullfile(p,f{i}));
        end
        S0.opt.startDir = p;
        guidata(hFig,S0);
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
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
        guidata(hFig,S0);
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
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
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
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
        S0.selectedRows = [];
        S0.lastROI = struct();
        S0.lastMAP = struct();
        S0.lastFC = struct();
        S0 = ensureRowPacapSideSize(S0);
        guidata(hFig,S0);
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
        refreshTable();
        clearPreview();
        refreshMapBundlePopup();
        setStatusText(sprintf('Removed %d row(s).',numel(sel)));
    end

    function onSaveList(~,~)
        syncSubjFromTable();
        S0 = guidata(hFig);
        S0 = ensureFCRowFilesSizeV13(S0);
        startPath = getSmartBrowseDir(S0);
        [f,p] = uiputfile({'*.mat','MAT list (*.mat)'}, ...
            'Save subject list',fullfile(startPath,'GroupSubjects.mat'));
        if isequal(f,0), return; end
        subj = S0.subj;
        groupList = S0.groupList;
        condList = S0.condList;
        rowPacapSide = S0.rowPacapSide;
        fcRowFiles = localGA_getFCRowFilesV13(S0);
        FC = struct(); lastFC = struct();
        fcAtlasLabelFile = ''; fcSeedRegion = '';
        try, FC = S0.FC; catch, end
        try, lastFC = S0.lastFC; catch, end
        try, fcAtlasLabelFile = S0.fcAtlasLabelFile; catch, end
        try
            if isfield(S0,'hFCSeedRegion') && ishghandle(S0.hFCSeedRegion)
                fcSeedRegion = strtrim(char(get(S0.hFCSeedRegion,'String')));
            else
                fcSeedRegion = S0.fcSeedRegion;
            end
        catch
        end
        save(fullfile(p,f),'subj','groupList','condList','rowPacapSide', ...
            'fcRowFiles','FC','lastFC','fcAtlasLabelFile','fcSeedRegion','-v7.3');
        S0.opt.startDir = p;
        guidata(hFig,S0);
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
        setStatusText('Saved list including FC files and FC data.');
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
        if isfield(L,'rowPacapSide'), S0.rowPacapSide = L.rowPacapSide; else, S0.rowPacapSide = cell(size(S0.subj,1),1); end
        if isfield(L,'fcRowFiles'), S0.fcRowFiles = L.fcRowFiles; else, S0.fcRowFiles = cell(size(S0.subj,1),1); end
        if isfield(L,'FC') && isstruct(L.FC), S0.FC = L.FC; else, S0.FC = struct('files',{{}},'subjects',struct([]),'loaded',false); end
        try, S0.FC.loaded = isfield(S0.FC,'subjects') && ~isempty(S0.FC.subjects); catch, end
        if isfield(L,'lastFC'), S0.lastFC = L.lastFC; else, S0.lastFC = struct(); end
        if isfield(L,'fcAtlasLabelFile'), S0.fcAtlasLabelFile = L.fcAtlasLabelFile; end
        if isfield(L,'fcSeedRegion'), S0.fcSeedRegion = L.fcSeedRegion; end
        try
            if isfield(S0,'hFCSeedRegion') && ishghandle(S0.hFCSeedRegion)
                set(S0.hFCSeedRegion,'String',S0.fcSeedRegion);
            end
        catch
        end
        S0.opt.startDir = p;
        S0.selectedRows = [];
        S0 = sanitizeTableStruct(S0);
        S0 = ensureRowPacapSideSize(S0);
        S0 = ensureFCRowFilesSizeV13(S0);
        S0 = localGA_autoFCAtlasFileV13(S0,false);
        guidata(hFig,S0);
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
        refreshTable(); refreshMapBundlePopup(); refreshFCGroupPopups(); clearPreview();
        try, updateFCTabPreview(); catch, end
        setStatusText('Loaded list including FC files and FC data.');
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
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
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
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
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
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
        updateManualTabs();
    end

    function onROIChanged(~,~)
        S0 = readROISettingsFromUI(guidata(hFig));
        guidata(hFig,S0);
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
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
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
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
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
        updatePreview();
    end

    function onSmoothChanged(~,~)
        S0 = guidata(hFig);
        try, S0.tc_previewSmooth = logical(get(S0.hSmoothEnable,'Value')); catch, end
        try, S0.tc_previewSmoothWinSec = safeNum(get(S0.hSmoothWin,'String'),S0.tc_previewSmoothWinSec); catch, end
        try, S0 = readPreviewAxisControlsLocal(S0); catch, end
        guidata(hFig,S0);
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
        updatePreview();
    end

    function onPlotScaleChanged(~,~)
        S0 = guidata(hFig);
        try, S0 = readPreviewAxisControlsLocal(S0); catch, end
        guidata(hFig,S0);
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
        updatePreview();
    end

    function onMapDisplayChanged(~,~)
        S0 = guidata(hFig);
        S0 = readMapSettingsFromUI(S0);
        guidata(hFig,S0);
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
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
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
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
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
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
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
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
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
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
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
        syncMapPreviewSideUI(r);
        previewBundleRow(r);
    end

    function onMapPreviewSideChanged(src,~)
        S0 = guidata(hFig);
        S0 = ensureRowPacapSideSize(S0);
        r = S0.mapPreviewRow;
        if isempty(r) || ~isfinite(r) || r < 1 || r > size(S0.subj,1)
            return;
        end
        items = get(src,'String');
        S0.rowPacapSide{r} = items{get(src,'Value')};
        guidata(hFig,S0);
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
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
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
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
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
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

    function onLoadFCAtlasLabels(~,~)
        S0 = guidata(hFig);
        startPath = getSmartBrowseDir(S0);
        [f,p] = uigetfile({'*.txt;*.label;*.csv','Atlas label/name files (*.txt, *.label, *.csv)'; '*.*','All files'}, ...
            'Select Allen/Waxholm label-name file',startPath);
        if isequal(f,0), return; end
        S0.fcAtlasLabelFile = fullfile(p,f);
        guidata(hFig,S0);
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
        try, set(S0.hFCInfo,'String',sprintf('FC atlas labels: %s',S0.fcAtlasLabelFile)); catch, end
        setStatusText(['Loaded FC atlas label file: ' S0.fcAtlasLabelFile]);
    end

    function onPickFCRegionV14(~,~)
        S0 = guidata(hFig);
        labels = []; names = {};
        try
            if isfield(S0,'lastFC') && isfield(S0.lastFC,'labels') && ~isempty(S0.lastFC.labels)
                labels = S0.lastFC.labels(:);
                names = S0.lastFC.names(:);
            elseif isfield(S0,'FC') && isfield(S0.FC,'subjects') && ~isempty(S0.FC.subjects)
                labels = S0.FC.subjects(1).labels(:);
                names = S0.FC.subjects(1).names(:);
            end
        catch
        end
        if isempty(labels)
            errordlg('Load/compute FC first so available regions are known.','Pick FC region');
            return;
        end
        choices = cell(numel(labels),1);
        for ii = 1:numel(labels)
            nm = '';
            try, nm = names{ii}; catch, nm = sprintf('ROI_%g',labels(ii)); end
            choices{ii} = sprintf('%g | %s',labels(ii),nm);
        end
        [sel,ok] = listdlg('PromptString','Choose seed / ROI region:', ...
            'SelectionMode','single', ...
            'ListString',choices, ...
            'ListSize',[520 520], ...
            'Name','FC seed / region');
        if ok && ~isempty(sel)
            set(S0.hFCSeedRegion,'String',num2str(labels(sel)));
            S0.fcSeedRegion = num2str(labels(sel));
            guidata(hFig,S0);
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
            updateFCTabPreview();
        end
    end

    function onFCHelpV14(~,~)
        msg = sprintf(['Seed/region box:\n' ...
            '  - enter an atlas label number, e.g. 105\n' ...
            '  - or type part of a region name, e.g. cortex, thalamus, hippocampus\n' ...
            '  - or click Pick Region to choose from the available ROI list.\n\n' ...
            'Views:\n' ...
            '  Matrix summary = one large FC matrix for selected group/difference.\n' ...
            '  Seed profile = strongest connections from selected seed/region.\n' ...
            '  Max connections = strongest ROI-to-ROI edges.\n' ...
            '  ROI time course = full stored ROI time course from the FC bundle, if meanTS exists.\n' ...
            '  Subject heatmap = subject-by-region seed connectivity.\n\n' ...
            'Hide |r| < is only a visual threshold. It does not recompute statistics.']);
        helpdlg(msg,'Functional Connectivity help');
    end

    function onFCRegionChangedV15(~,~)
        S0 = guidata(hFig);
        try
            reg = getSelectedPopupString(S0.hFCRegion1);
            lab = regexp(reg,'^\s*([+-]?\d+\.?\d*)','tokens','once');
            if ~isempty(lab)
                set(S0.hFCSeedRegion,'String',lab{1});
                S0.fcSeedRegion = lab{1};
            else
                set(S0.hFCSeedRegion,'String',reg);
                S0.fcSeedRegion = reg;
            end
            guidata(hFig,S0);
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
        catch
        end
        updateFCTabPreview();
    end

    function onRefreshFCRegionMenusV15(~,~)
        S0 = guidata(hFig);
        S0 = refreshFCRegionPopupsV15(S0);
        guidata(hFig,S0);
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
        updateFCTabPreview();
    end

    function onFCHelpV15(~,~)
        msg = sprintf(['Functional Connectivity Group Analysis\n\n' ...
            'Region 1 / seed:\n' ...
            '  Main seed region used for Seed profile, ROI time course, Subject heatmap, and Region graph.\n\n' ...
            'Region 2 / target:\n' ...
            '  Optional second region used for Pair correlation.\n\n' ...
            'Hemisphere mode:\n' ...
            '  All/Merged = use all available regions.\n' ...
            '  Left only / Right only = uses region names containing left/right markers if present.\n' ...
            '  Left vs Right = rows are left regions and columns are right regions.\n\n' ...
            'Hide |r| <:\n' ...
            '  Visual threshold only. It hides weak plotted edges but does not change statistics.\n\n' ...
            'Max connections:\n' ...
            '  Ranks strongest ROI-to-ROI edges. Useful QC and discovery view.\n\n' ...
            'Subject heatmap:\n' ...
            '  Rows = subjects, columns = target regions. With one subject, it is only a single-row QC view.\n\n' ...
            'Region graph:\n' ...
            '  Network-style FC visualization. If atlas coordinates are not stored in the bundle, it uses a circular layout instead of anatomical overlay.']);
        helpdlg(msg,'FC Group Analysis Help');
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
        syncSubjFromTable();
        S0 = guidata(hFig);
        S0 = ensureFCRowFilesSizeV13(S0);
        setStatus(false);
        setStatusText('Loading FC bundles...');
        drawnow;
        try
            fileList = fileList(:);
            selectedRows = [];
            try, selectedRows = S0.selectedRows(:); catch, selectedRows = []; end
            selectedRows = selectedRows(isfinite(selectedRows) & selectedRows >= 1 & selectedRows <= size(S0.subj,1));
            selectedRows = unique(selectedRows,'stable');
            if ~isempty(selectedRows)
                nAssign = min(numel(selectedRows),numel(fileList));
                for ii = 1:nAssign
                    r = selectedRows(ii);
                    fp = fileList{ii};
                    S0.fcRowFiles{r,1} = fp;
                    S0.subj{r,1} = true;
                    if isempty(strtrimSafe(S0.subj{r,2})) || strcmpi(strtrimSafe(S0.subj{r,2}),'N/A')
                        S0.subj{r,2} = guessSubjectID(fp);
                    end
                end
                S0 = localGA_buildFCFromTableRowsV13(S0);
                msg = sprintf('Assigned %d FC bundle(s) to selected row(s). Loaded %d FC subject(s).',nAssign,S0.FC.nSubjects);
            else
                [FC,cacheOut] = localGA_loadFCFilesV13(fileList,S0.cache);
                S0.cache = cacheOut;
                S0.FC = FC;
                S0.FC.loaded = true;
                S0 = localGA_autoAttachFCFilesToRowsV13(S0,FC);
                msg = sprintf('Loaded %d FC subject(s) from %d file(s). No row selected, auto-matched where possible.',FC.nSubjects,numel(fileList));
            end
            S0 = localGA_autoFCAtlasFileV13(S0,false);
            S0.lastFC = struct();
            S0.activeTab = 'FC';
            S0.mode = 'Functional Connectivity';
            S0 = ensureFCRowFilesSizeV13(S0);
            guidata(hFig,S0);
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
            refreshTable(); refreshFCGroupPopups(); updateManualTabs();
            try, set(S0.hFCInfo,'String',msg); catch, end
            setStatusText(msg);
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
                g = cell(numel(S0.FC.subjects),1);
                for ii = 1:numel(S0.FC.subjects)
                    g{ii} = strtrimSafe(S0.FC.subjects(ii).group);
                    if isempty(g{ii}), g{ii} = 'Unassigned'; end
                end
                groups = uniqueStable(g);
            end
        catch
        end
        if isempty(groups), groups = {'Unassigned'}; end
        try, set(S0.hFCGroupA,'String',groups,'Value',min(get(S0.hFCGroupA,'Value'),numel(groups))); catch, end
        try, set(S0.hFCGroupB,'String',groups,'Value',min(max(1,min(2,numel(groups))),numel(groups))); catch, end
        try
            activeChoices = groups(:);
            if numel(groups) >= 2
                activeChoices{end+1,1} = 'Difference A-B';
            end
            oldVal = 1;
            try, oldVal = get(S0.hFCActiveGroup,'Value'); catch, end
            set(S0.hFCActiveGroup,'String',activeChoices,'Value',min(oldVal,numel(activeChoices)));
        catch
        end
        S0 = refreshFCRegionPopupsV15(S0);
        guidata(hFig,S0);
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
    end
function onComputeGroupFC(varargin)
% FC_DATA_RECOVERY_COMPUTE_V32
try
    S0 = guidata(hFig);
    if ~isstruct(S0) || ~isfield(S0,'FC') || ~isstruct(S0.FC) || ~isfield(S0.FC,'subjects') || isempty(S0.FC.subjects)
        localGA_fcSetInfoV32(S0,'Load FC bundle(s) first.');
        return;
    end

    groupA = localGA_fcPopupV32(S0,'hFCGroupA','');
    groupB = localGA_fcPopupV32(S0,'hFCGroupB','');
    [R,FC2] = localGA_fcBuildResultV32(S0.FC,groupA,groupB);
    S0.FC = FC2;
    S0.lastFC = R;
    S0.activeTab = 'FC';
    S0.mode = 'Functional Connectivity';

    try
        if isfield(S0,'hFCActiveGroup') && isgraphics(S0.hFCActiveGroup)
            if R.singleGroup
                set(S0.hFCActiveGroup,'String',{R.groupA},'Value',1);
            else
                set(S0.hFCActiveGroup,'String',{R.groupA,R.groupB,'Difference A-B'},'Value',1);
            end
        end
    catch
    end

    guidata(hFig,S0);
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
    try, refreshFCRegionPopupsV15(S0); catch, end
    updateFCTabPreview();

    localGA_fcSetInfoV32(guidata(hFig),R.note);
catch ME
    try, localGA_fcSetInfoV32(guidata(hFig),['FC compute error: ' ME.message]); catch, end
    errordlg(ME.message,'FC compute error');
end
end
function updateFCTabPreview(varargin)
% FC_DATA_RECOVERY_PREVIEW_V32
try
    S0 = guidata(hFig);
    if ~isstruct(S0) || ~isfield(S0,'axFCA') || ~isgraphics(S0.axFCA)
        return;
    end
    ax = S0.axFCA;
    C = localGA_fcColorsV32();

    if ~isfield(S0,'lastFC') || ~isstruct(S0.lastFC) || ~isfield(S0.lastFC,'meanRA')
        if isfield(S0,'FC') && isstruct(S0.FC) && isfield(S0.FC,'subjects') && ~isempty(S0.FC.subjects)
            [R,FC2] = localGA_fcBuildResultV32(S0.FC,localGA_fcPopupV32(S0,'hFCGroupA',''),localGA_fcPopupV32(S0,'hFCGroupB',''));
            S0.FC = FC2;
            S0.lastFC = R;
            guidata(hFig,S0);
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
        else
            localGA_fcTextV32(ax,'Load FC bundle(s), then click Compute FC.',C);
            return;
        end
    end

    R = S0.lastFC;
    FC = S0.FC;
    viewMode = localGA_fcPopupV32(S0,'hFCView','Matrix summary');
    activeGroup = localGA_fcPopupV32(S0,'hFCActiveGroup','Group A');
    hemiMode = localGA_fcPopupV32(S0,'hFCHemiMode','All / merged');
    dispMode = localGA_fcPopupV32(S0,'hFCDisplay','Pearson r');
    reg1 = localGA_fcPopupV32(S0,'hFCRegion1','');
    reg2 = localGA_fcPopupV32(S0,'hFCRegion2','');
    thr = 0;
    try
        if isfield(S0,'hFCThreshold') && isgraphics(S0.hFCThreshold)
            thr = str2double(get(S0.hFCThreshold,'String'));
            if ~isfinite(thr), thr = 0; end
        end
    catch
    end

    localGA_fcPlotViewV32(ax,FC,R,viewMode,activeGroup,hemiMode,dispMode,reg1,reg2,thr,C);
catch ME
    try
        localGA_fcTextV32(guidata(hFig).axFCA,['FC preview error: ' ME.message],localGA_fcColorsV32());
        localGA_fcSetInfoV32(guidata(hFig),['FC preview error: ' ME.message]);
    catch
    end
end
end





    function onExportGroupFC(~,~)
        S0 = guidata(hFig);
        if ~isfield(S0,'lastFC') || isempty(fieldnames(S0.lastFC))
            errordlg('Compute FC first.','FC export');
            return;
        end
        try
            try, S0.fcRegion1 = getSelectedPopupString(S0.hFCRegion1); catch, end
            try, S0.fcRegion2 = getSelectedPopupString(S0.hFCRegion2); catch, end
            try, S0.fcHemiMode = getSelectedPopupString(S0.hFCHemiMode); catch, end
            try, S0.fcActiveGroup = getSelectedPopupString(S0.hFCActiveGroup); catch, end
            try, S0.fcDisplayMode = getSelectedPopupString(S0.hFCDisplay); catch, end
            try, S0.fcViewMode = getSelectedPopupString(S0.hFCView); catch, end
            try
                lab = regexp(S0.fcRegion1,'^\s*([+-]?\d+\.?\d*)','tokens','once');
                if ~isempty(lab), S0.fcSeedRegion = lab{1}; else, S0.fcSeedRegion = S0.fcRegion1; end
            catch
            end
            guidata(hFig,S0);
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
            callFC('exportGroupFCResults',S0);
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
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
        updatePreview();
    end

    function onDetectOutliers(~,~)
        S0 = guidata(hFig);
        try
            [keysOut,info] = callCommon('detectOutliers',double(S0.lastROI.metricVals(:)),S0.lastROI.subjTable,S0);
            S0.outlierKeys = keysOut;
            S0.outlierInfo = info;
            guidata(hFig,S0);
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
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
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
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
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
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
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37

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

        S0.groupList = mergeUniqueStable(S0.groupList,uniqueStable(colAsStr(S0.subj,3)));
        S0.condList  = mergeUniqueStable(S0.condList, uniqueStable(colAsStr(S0.subj,4)));

        colFmt = {'logical','char','char','char',S0.groupList,S0.condList,'char','char','char','char'};
        dispData = makeUITableDisplayData(S0.subj,S0.tableMinRows,localGA_getFCRowFilesV12(S0));

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
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
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
        guidata(hFig,S0);
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
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
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37

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
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
    end

    function syncMapPreviewSideUI(r)
        S0 = guidata(hFig);
        S0 = ensureRowPacapSideSize(S0);
        if r >= 1 && r <= numel(S0.rowPacapSide)
            setPopupToString(S0.hMapPreviewSide,S0.rowPacapSide{r});
        end
        guidata(hFig,S0);
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
    end

    function updateMapSideSummaryTable()
        S0 = guidata(hFig);
        if ~isfield(S0,'hMapSideTable') || ~ishghandle(S0.hMapSideTable)
            return;
        end
        S0 = ensureRowPacapSideSize(S0);
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
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
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
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
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
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
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
try, localGA_installTableSelectionMemoryV37(hFig); catch, end % TABLE_SELECTION_MEMORY_INSTALL_V37
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
% SANITIZE_TABLE_STRUCT_GUARD_V17
if ~isstruct(S)
    S = struct();
end
if ~isfield(S,'subj') || isempty(S.subj)
    S.subj = cell(0,9);
end
if ~isfield(S,'groupList') || isempty(S.groupList)
    S.groupList = {'PACAP','Vehicle','Control','Other'};
end
if ~isfield(S,'condList') || isempty(S.condList)
    S.condList = {'Condition 1','Condition 2','Other'};
end
if ~isfield(S,'rowPacapSide') || isempty(S.rowPacapSide)
    S.rowPacapSide = cell(size(S.subj,1),1);
end
if ~isfield(S,'fcRowFiles') || isempty(S.fcRowFiles)
    S.fcRowFiles = cell(size(S.subj,1),1);
end
if ~isfield(S,'selectedRows')
    S.selectedRows = [];
end
if ~isfield(S,'tableMinRows') || isempty(S.tableMinRows)
    S.tableMinRows = max(6,size(S.subj,1));
end

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
V = subjToUITable(subj,fcRowFiles);
n = size(V,1);
if minRows > 0 && n < minRows
    pad = cell(minRows-n,10);
    for i = 1:size(pad,1)
        pad{i,1} = false;
        for j = 2:10, pad{i,j} = ''; end
    end
    V = [V; pad];
end
end

function V = subjToUITable(subj,fcRowFiles)
if nargin < 2, fcRowFiles = cell(size(subj,1),1); end
n = size(subj,1);
if numel(fcRowFiles) < n, fcRowFiles(end+1:n,1) = {''}; end
V = cell(n,10);
for i = 1:n
    meta = extractMetaFromSources(subj{i,2},subj{i,6},subj{i,7},subj{i,8});
        V{i,1} = logicalCellValue(subj{i,1});
    if ~isfield(meta,'animalID') || isempty(meta.animalID), meta.animalID = 'Unknown'; end
    if ~isfield(meta,'session')  || isempty(meta.session),  meta.session  = ''; end
    if ~isfield(meta,'scanID')   || isempty(meta.scanID),   meta.scanID   = ''; end
    V{i,2} = meta.animalID;
    V{i,3} = meta.session;
    V{i,4} = displayScanID(meta.scanID);
    V{i,5} = strtrimSafe(subj{i,3});
    V{i,6} = strtrimSafe(subj{i,4});
    V{i,7} = simplifyFileLabel(strtrimSafe(subj{i,7}));
    V{i,8} = bundlePresenceLabel(strtrimSafe(subj{i,8}));
    V{i,9} = fcBundlePresenceLabelV13(fcRowFiles{i});
    V{i,10} = deriveRowStatusWithFCV13(subj(i,:),fcRowFiles{i});
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

function S = ensureFCRowFilesSizeV13(S)
n = size(S.subj,1);
if ~isfield(S,'fcRowFiles') || isempty(S.fcRowFiles), S.fcRowFiles = cell(n,1); end
S.fcRowFiles = S.fcRowFiles(:);
if numel(S.fcRowFiles) < n, S.fcRowFiles(end+1:n,1) = {''}; end
if numel(S.fcRowFiles) > n, S.fcRowFiles = S.fcRowFiles(1:n); end
for ii=1:n, S.fcRowFiles{ii,1} = strtrimSafe(S.fcRowFiles{ii,1}); end
end

function S = ensureFCRowFilesSizeV12(S), S = ensureFCRowFilesSizeV13(S); end

function fcRowFiles = localGA_getFCRowFilesV13(S)
try, S = ensureFCRowFilesSizeV13(S); fcRowFiles = S.fcRowFiles; catch, fcRowFiles = cell(size(S.subj,1),1); end
end

function fcRowFiles = localGA_getFCRowFilesV12(S), fcRowFiles = localGA_getFCRowFilesV13(S); end

function s = fcBundlePresenceLabelV13(fp)
fp = strtrimSafe(fp);
if isempty(fp), s = ''; elseif exist(fp,'file')==2, s = 'Exists'; else, s = 'Missing'; end
end

function s = fcBundlePresenceLabelV12(fp), s = fcBundlePresenceLabelV13(fp); end

% LOCAL_FC_COMPUTE_DISPLAY_HELPERS_V31

function R = localGA_fcBuildResultV31(FC,groupA,groupB)
if ~isstruct(FC) || ~isfield(FC,'subjects') || isempty(FC.subjects)
    error('No loaded FC subjects found.');
end
subs = FC.subjects;
baseIdx = [];
for ii = 1:numel(subs)
    if isfield(subs(ii),'R') && ~isempty(subs(ii).R) && isfield(subs(ii),'labels') && ~isempty(subs(ii).labels)
        baseIdx = ii;
        break;
    end
end
if isempty(baseIdx), error('Loaded FC bundle has no usable R matrices.'); end
labels = double(subs(baseIdx).labels(:));
nR = numel(labels);
names = localGA_fcNamesV31(subs(baseIdx),labels);
Zstack = []; groups = {}; subjectNames = {}; sourceFiles = {};
for ii = 1:numel(subs)
    if ~isfield(subs(ii),'R') || isempty(subs(ii).R), continue; end
    if ~isfield(subs(ii),'labels') || isempty(subs(ii).labels), continue; end
    labs = double(subs(ii).labels(:));
    [tf,ord] = ismember(labels,labs);
    if any(~tf), continue; end
    M = double(subs(ii).R);
    if size(M,1) ~= numel(labs) || size(M,2) ~= numel(labs), continue; end
    M = M(ord,ord);
    if isfield(subs(ii),'Z') && ~isempty(subs(ii).Z)
        Z = double(subs(ii).Z);
        if size(Z,1) == numel(labs) && size(Z,2) == numel(labs)
            Z = Z(ord,ord);
        else
            Z = atanh(max(-0.999999,min(0.999999,M)));
        end
    else
        Z = atanh(max(-0.999999,min(0.999999,M)));
    end
    Zstack(:,:,end+1) = Z;
    if isfield(subs(ii),'group'), g = localGA_fcStrV31(subs(ii).group); else, g = ''; end
    if isempty(g), g = 'Unassigned'; end
    groups{end+1,1} = g;
    if isfield(subs(ii),'name'), subjectNames{end+1,1} = localGA_fcStrV31(subs(ii).name); else, subjectNames{end+1,1} = sprintf('Subject_%02d',ii); end
    if isfield(subs(ii),'sourceFile'), sourceFiles{end+1,1} = localGA_fcStrV31(subs(ii).sourceFile); else, sourceFiles{end+1,1} = ''; end
end
if isempty(Zstack), error('Could not build FC stack from loaded bundle.'); end
u = localGA_fcUniqueV31(groups);
groupA = localGA_fcStrV31(groupA);
groupB = localGA_fcStrV31(groupB);
if isempty(groupA) || strcmpi(groupA,'Group A') || ~any(strcmpi(groups,groupA)), groupA = u{1}; end
idxA = strcmpi(groups,groupA);
if isempty(groupB) || strcmpi(groupB,'Group B') || strcmpi(groupB,groupA) || ~any(strcmpi(groups,groupB))
    groupB = 'None';
    for ii = 1:numel(u)
        if ~strcmpi(u{ii},groupA), groupB = u{ii}; break; end
    end
end
idxB = strcmpi(groups,groupB);
singleGroup = ~any(idxB);
meanZA = localGA_fcMean3V31(Zstack(:,:,idxA));
meanRA = tanh(meanZA);
if singleGroup
    meanZB = nan(nR,nR); meanRB = nan(nR,nR); diffZ = nan(nR,nR); diffR = nan(nR,nR);
else
    meanZB = localGA_fcMean3V31(Zstack(:,:,idxB));
    meanRB = tanh(meanZB);
    diffZ = meanZA - meanZB;
    diffR = meanRA - meanRB;
end
R = struct();
R.mode = 'Functional Connectivity';
R.singleGroup = singleGroup;
R.groupA = groupA; R.groupB = groupB; R.nA = sum(idxA); R.nB = sum(idxB);
R.labels = labels; R.names = names(:);
R.meanZA = meanZA; R.meanZB = meanZB; R.meanRA = meanRA; R.meanRB = meanRB;
R.diffZ = diffZ; R.diffR = diffR; R.pMat = nan(nR,nR); R.tMat = nan(nR,nR);
R.groups = groups; R.subjectNames = subjectNames; R.sourceFiles = sourceFiles;
end

function localGA_fcPlotViewV31(ax,FC,R,viewMode,activeGroup,hemiMode,dispMode,reg1,reg2,thr,C)
try, cla(ax); set(ax,'Visible','on','Color',C.axisBg,'XColor',C.muted,'YColor',C.muted); catch, end
v = lower(localGA_fcStrV31(viewMode));
try
    if ~isempty(strfind(v,'seed'))
        localGA_fcPlotSeedV31(ax,R,activeGroup,dispMode,reg1,thr,C);
    elseif ~isempty(strfind(v,'pair'))
        localGA_fcPlotPairV31(ax,R,activeGroup,dispMode,reg1,reg2,C);
    elseif ~isempty(strfind(v,'max'))
        localGA_fcPlotMaxV31(ax,R,activeGroup,hemiMode,dispMode,thr,C);
    elseif ~isempty(strfind(v,'time'))
        localGA_fcPlotTimeV31(ax,FC,R,activeGroup,reg1,C);
    elseif ~isempty(strfind(v,'heat'))
        localGA_fcPlotHeatV31(ax,FC,R,activeGroup,hemiMode,dispMode,reg1,thr,C);
    elseif ~isempty(strfind(v,'graph'))
        localGA_fcPlotGraphV31(ax,R,activeGroup,dispMode,reg1,thr,C);
    else
        localGA_fcPlotMatrixV31(ax,R,activeGroup,hemiMode,dispMode,thr,C);
    end
catch ME
    localGA_fcTextV31(ax,['FC view error: ' ME.message],C);
end
end

function localGA_fcPlotMatrixV31(ax,R,activeGroup,hemiMode,dispMode,thr,C)
[M,namesX,namesY,titleText,climVal,msg] = localGA_fcMatrixV31(R,activeGroup,hemiMode,dispMode);
if isempty(M), localGA_fcTextV31(ax,msg,C); return; end
if thr > 0, M(abs(M) < thr) = 0; end
imagesc(ax,M); colormap(ax,localGA_fcCmapV31(256)); caxis(ax,climVal);
cb = colorbar(ax); try, cb.Color = C.txt; catch, end
title(ax,[titleText ' | ' localGA_fcStrV31(hemiMode)],'Color',C.txt,'Interpreter','none','FontSize',14,'FontWeight','bold');
ix = localGA_fcTickV31(numel(namesX)); iy = localGA_fcTickV31(numel(namesY));
set(ax,'XTick',ix,'XTickLabel',localGA_fcAbbrevV31(namesX(ix),14),'YTick',iy,'YTickLabel',localGA_fcAbbrevV31(namesY(iy),14));
try, xtickangle(ax,90); catch, end
set(ax,'Color',C.axisBg,'XColor',C.muted,'YColor',C.muted,'FontSize',9);
end

function localGA_fcPlotSeedV31(ax,R,activeGroup,dispMode,reg1,thr,C)
[M,namesX,~,titleText,~,msg] = localGA_fcMatrixV31(R,activeGroup,'All / merged',dispMode);
if isempty(M), localGA_fcTextV31(ax,msg,C); return; end
idx = max(1,min(size(M,1),localGA_fcRegionIdxV31(R,reg1)));
vals = M(idx,:); vals(idx) = NaN;
if thr > 0, vals(abs(vals) < thr) = NaN; end
[~,ord] = sort(abs(vals),'descend'); ord = ord(isfinite(vals(ord))); ord = ord(1:min(35,numel(ord)));
if isempty(ord), localGA_fcTextV31(ax,'No seed connections pass the current filter.',C); return; end
barh(ax,flipud(vals(ord(:))));
set(ax,'YTick',1:numel(ord),'YTickLabel',flipud(localGA_fcAbbrevV31(namesX(ord),32)));
grid(ax,'on');
title(ax,sprintf('Seed profile: %g | %s | %s',R.labels(idx),R.names{idx},titleText),'Color',C.txt,'Interpreter','none','FontSize',14,'FontWeight','bold');
set(ax,'Color',C.axisBg,'XColor',C.muted,'YColor',C.muted,'FontSize',9);
end

function localGA_fcPlotPairV31(ax,R,activeGroup,dispMode,reg1,reg2,C)
[M,~,~,titleText,~,msg] = localGA_fcMatrixV31(R,activeGroup,'All / merged',dispMode);
if isempty(M), localGA_fcTextV31(ax,msg,C); return; end
i1 = max(1,min(size(M,1),localGA_fcRegionIdxV31(R,reg1)));
i2 = max(1,min(size(M,2),localGA_fcRegionIdxV31(R,reg2)));
s = sprintf('Pair correlation\n\nROI 1: %g | %s\nROI 2: %g | %s\n\n%s\nValue: %.4f',R.labels(i1),R.names{i1},R.labels(i2),R.names{i2},titleText,M(i1,i2));
localGA_fcTextV31(ax,s,C);
end

function localGA_fcPlotMaxV31(ax,R,activeGroup,hemiMode,dispMode,thr,C)
[M,namesX,~,titleText,~,msg] = localGA_fcMatrixV31(R,activeGroup,hemiMode,dispMode);
if isempty(M), localGA_fcTextV31(ax,msg,C); return; end
n = min(size(M,1),size(M,2)); vals = []; labs = {};
for i = 1:n
    for j = i+1:n
        vv = M(i,j);
        if isfinite(vv) && abs(vv) >= thr
            vals(end+1,1) = vv;
            labs{end+1,1} = [localGA_fcShortV31(namesX{i},18) ' <-> ' localGA_fcShortV31(namesX{j},18)];
        end
    end
end
if isempty(vals), localGA_fcTextV31(ax,'No connections pass threshold.',C); return; end
[~,ord] = sort(abs(vals),'descend'); ord = ord(1:min(35,numel(ord)));
barh(ax,flipud(vals(ord))); set(ax,'YTick',1:numel(ord),'YTickLabel',flipud(labs(ord))); grid(ax,'on');
title(ax,['Strongest connections | ' titleText],'Color',C.txt,'Interpreter','none','FontSize',14,'FontWeight','bold');
set(ax,'Color',C.axisBg,'XColor',C.muted,'YColor',C.muted,'FontSize',8);
end

function localGA_fcPlotTimeV31(ax,FC,R,activeGroup,reg1,C)
idx = localGA_fcRegionIdxV31(R,reg1); label = R.labels(idx);
[T,msg] = localGA_fcCollectTCV31(FC,R,label,activeGroup);
if isempty(T), localGA_fcTextV31(ax,msg,C); return; end
plot(ax,T,'Color',[0.55 0.55 0.55]); hold(ax,'on');
m = localGA_fcMean2V31(T); plot(ax,m,'LineWidth',3); hold(ax,'off'); grid(ax,'on');
title(ax,sprintf('ROI time course: %g | %s',label,R.names{idx}),'Color',C.txt,'Interpreter','none','FontSize',14,'FontWeight','bold');
xlabel(ax,'Frame stored in FC bundle'); ylabel(ax,'ROI signal');
set(ax,'Color',C.axisBg,'XColor',C.muted,'YColor',C.muted,'FontSize',10);
end

function localGA_fcPlotHeatV31(ax,FC,R,activeGroup,hemiMode,dispMode,reg1,thr,C)
idx = localGA_fcRegionIdxV31(R,reg1); label = R.labels(idx);
[H,namesUse,msg] = localGA_fcCollectHeatV31(FC,R,label,activeGroup,hemiMode,dispMode);
if isempty(H), localGA_fcTextV31(ax,msg,C); return; end
if thr > 0, H(abs(H) < thr) = 0; end
imagesc(ax,H); colormap(ax,localGA_fcCmapV31(256)); caxis(ax,[-1 1]);
cb = colorbar(ax); try, cb.Color = C.txt; catch, end
ix = localGA_fcTickV31(size(H,2));
set(ax,'XTick',ix,'XTickLabel',localGA_fcAbbrevV31(namesUse(ix),14),'YTick',1:size(H,1));
try, xtickangle(ax,90); catch, end
title(ax,sprintf('Subject heatmap: seed %g | %s',label,R.names{idx}),'Color',C.txt,'Interpreter','none','FontSize',14,'FontWeight','bold');
set(ax,'Color',C.axisBg,'XColor',C.muted,'YColor',C.muted,'FontSize',8);
end

function localGA_fcPlotGraphV31(ax,R,activeGroup,dispMode,reg1,thr,C)
[M,namesX,~,titleText,~,msg] = localGA_fcMatrixV31(R,activeGroup,'All / merged',dispMode);
if isempty(M), localGA_fcTextV31(ax,msg,C); return; end
idx = localGA_fcRegionIdxV31(R,reg1); vals = M(idx,:); vals(idx) = NaN;
if thr > 0, vals(abs(vals) < thr) = NaN; end
[~,ord] = sort(abs(vals),'descend'); ord = ord(isfinite(vals(ord))); ord = ord(1:min(20,numel(ord)));
if isempty(ord), localGA_fcTextV31(ax,'No graph edges pass threshold.',C); return; end
nodes = [idx transpose(ord(:))];
n = numel(nodes); th = linspace(0,2*pi,n+1); th(end) = []; x = cos(th); y = sin(th);
cla(ax); hold(ax,'on'); axis(ax,'equal'); axis(ax,'off'); set(ax,'Color',C.axisBg);
for k = 2:n
    j = nodes(k); vv = M(idx,j); lw = 0.5 + 4*min(1,abs(vv));
    if vv >= 0, col = [1 0.35 0.15]; else, col = [0.25 0.55 1]; end
    plot(ax,[x(1) x(k)],[y(1) y(k)],'Color',col,'LineWidth',lw);
end
scatter(ax,x,y,120,'filled','MarkerFaceColor',[0.9 0.9 0.9],'MarkerEdgeColor',[0 0 0]);
for k = 1:n
    text(ax,x(k)*1.15,y(k)*1.15,localGA_fcShortV31(namesX{nodes(k)},16),'Color',C.txt,'FontSize',8,'Interpreter','none');
end
title(ax,['Region graph | ' titleText],'Color',C.txt,'Interpreter','none','FontSize',14,'FontWeight','bold'); hold(ax,'off');
end

function [M,namesX,namesY,titleText,climVal,msg] = localGA_fcMatrixV31(R,activeGroup,hemiMode,dispMode)
M = []; namesX = {}; namesY = {}; titleText = ''; climVal = [-1 1]; msg = '';
g = localGA_fcResolveGroupV31(R,activeGroup); useZ = strcmpi(localGA_fcStrV31(dispMode),'Fisher z'); gl = lower(g);
if ~isempty(strfind(gl,'diff'))
    if isfield(R,'singleGroup') && R.singleGroup, msg = 'Difference unavailable: this is single-group FC summary.'; return; end
    if useZ, M = R.diffZ; else, M = R.diffR; end
    titleText = [R.groupA ' - ' R.groupB];
elseif strcmpi(g,R.groupB) && ~(isfield(R,'singleGroup') && R.singleGroup)
    if useZ, M = R.meanZB; climVal = [-2.5 2.5]; else, M = R.meanRB; climVal = [-1 1]; end
    titleText = [R.groupB ' mean FC'];
else
    if useZ, M = R.meanZA; climVal = [-2.5 2.5]; else, M = R.meanRA; climVal = [-1 1]; end
    titleText = [R.groupA ' mean FC'];
end
[M,namesX,namesY,msgH] = localGA_fcApplyHemiV31(M,R.names,hemiMode); if isempty(M), msg = msgH; end
end

function [M2,namesX,namesY,msg] = localGA_fcApplyHemiV31(M,names,hemiMode)
M2 = M; namesX = names(:); namesY = names(:); msg = ''; h = lower(localGA_fcStrV31(hemiMode));
if isempty(h) || ~isempty(strfind(h,'all')) || ~isempty(strfind(h,'merged')), return; end
L = localGA_fcHemiMaskV31(names,'left'); Rr = localGA_fcHemiMaskV31(names,'right');
if ~any(L) && ~any(Rr), return; end
if ~isempty(strfind(h,'left vs right'))
    if ~any(L) || ~any(Rr), M2=[]; namesX={}; namesY={}; msg='Left-vs-right requires both left and right labels.'; return; end
    M2 = M(L,Rr); namesY = names(L); namesX = names(Rr);
elseif ~isempty(strfind(h,'left'))
    if ~any(L), M2=[]; namesX={}; namesY={}; msg='No left ROI labels detected.'; return; end
    M2 = M(L,L); namesX = names(L); namesY = names(L);
elseif ~isempty(strfind(h,'right'))
    if ~any(Rr), M2=[]; namesX={}; namesY={}; msg='No right ROI labels detected.'; return; end
    M2 = M(Rr,Rr); namesX = names(Rr); namesY = names(Rr);
end
end

function mask = localGA_fcHemiMaskV31(names,side)
mask = false(numel(names),1);
for ii = 1:numel(names)
    s = lower(localGA_fcStrV31(names{ii}));
    if strcmpi(side,'left')
        mask(ii) = ~isempty(strfind(s,'left')) || ~isempty(strfind(s,'_l_')) || ~isempty(strfind(s,'-l-'));
    else
        mask(ii) = ~isempty(strfind(s,'right')) || ~isempty(strfind(s,'_r_')) || ~isempty(strfind(s,'-r-'));
    end
end
end

function g = localGA_fcResolveGroupV31(R,activeGroup)
g = localGA_fcStrV31(activeGroup);
if isempty(g) || strcmpi(g,'Group A'), g = R.groupA; return; end
if strcmpi(g,'Group B'), g = R.groupB; return; end
if ~isempty(strfind(lower(g),'diff')), g = 'Difference A-B'; return; end
end

function idx = localGA_fcRegionIdxV31(R,txt0)
idx = 1; s = localGA_fcStrV31(txt0); if isempty(s), return; end
tok = regexp(s,'^\s*([+-]?\d+\.?\d*)','tokens','once');
if ~isempty(tok), lab = str2double(tok{1}); else, lab = str2double(s); end
if isfinite(lab)
    hit = find(double(R.labels(:)) == lab,1,'first'); if ~isempty(hit), idx = hit; return; end
end
s2 = lower(regexprep(s,'^\s*[+-]?\d+\.?\d*\s*\|\s*',''));
for ii = 1:numel(R.names)
    if ~isempty(strfind(lower(localGA_fcStrV31(R.names{ii})),s2)), idx = ii; return; end
end
end

function [T,msg] = localGA_fcCollectTCV31(FC,R,label,activeGroup)
T = []; msg = 'No ROI time courses stored in this FC bundle.';
if ~isstruct(FC) || ~isfield(FC,'subjects'), return; end
g = localGA_fcResolveGroupV31(R,activeGroup);
for ii = 1:numel(FC.subjects)
    s = FC.subjects(ii); if isfield(s,'group') && ~strcmpi(localGA_fcStrV31(s.group),g), continue; end
    X = [];
    if isfield(s,'meanTS') && isnumeric(s.meanTS), X = s.meanTS; end
    if isempty(X) && isfield(s,'roiTS') && isnumeric(s.roiTS), X = s.roiTS; end
    if isempty(X) && isfield(s,'timeCourses') && isnumeric(s.timeCourses), X = s.timeCourses; end
    if isempty(X), continue; end
    labs = double(s.labels(:)); hit = find(labs == double(label),1,'first'); if isempty(hit), continue; end
    if size(X,2) == numel(labs), tc = X(:,hit); elseif size(X,1) == numel(labs), tc = transpose(X(hit,:)); else, continue; end
    if isempty(T), T = double(tc(:)); elseif numel(tc) == size(T,1), T(:,end+1) = double(tc(:)); end
end
end

function [H,namesUse,msg] = localGA_fcCollectHeatV31(FC,R,label,activeGroup,hemiMode,dispMode)
H = []; namesUse = R.names; msg = 'No subject FC matrices available for heatmap.';
if ~isstruct(FC) || ~isfield(FC,'subjects'), return; end
g = localGA_fcResolveGroupV31(R,activeGroup); keep = true(numel(R.labels),1); h = lower(localGA_fcStrV31(hemiMode));
if ~isempty(strfind(h,'left')) && isempty(strfind(h,'left vs right')), keep = localGA_fcHemiMaskV31(R.names,'left'); end
if ~isempty(strfind(h,'right')), keep = localGA_fcHemiMaskV31(R.names,'right'); end
if ~any(keep), keep = true(numel(R.labels),1); end
namesUse = R.names(keep);
for ii = 1:numel(FC.subjects)
    s = FC.subjects(ii); if isfield(s,'group') && ~strcmpi(localGA_fcStrV31(s.group),g), continue; end
    labs = double(s.labels(:)); hit = find(labs == double(label),1,'first'); if isempty(hit), continue; end
    if strcmpi(localGA_fcStrV31(dispMode),'Fisher z') && isfield(s,'Z'), M = s.Z; else, M = s.R; end
    [tf,ord] = ismember(double(R.labels(keep)),labs); if any(~tf), continue; end
    H(end+1,:) = double(M(hit,ord));
end
end

function m = localGA_fcMean2V31(X)
m = nan(size(X,1),1);
for ii = 1:size(X,1), v = X(ii,:); v = v(isfinite(v)); if ~isempty(v), m(ii) = mean(v); end; end
end

function M = localGA_fcMean3V31(X)
[a,b,~] = size(X); M = nan(a,b);
for i = 1:a
    for j = 1:b
        v = squeeze(X(i,j,:)); v = v(isfinite(v)); if ~isempty(v), M(i,j) = mean(v); end
    end
end
end

function names = localGA_fcNamesV31(subj,labels)
if isfield(subj,'names') && ~isempty(subj.names), names = subj.names(:); else, names = {}; end
if numel(names) < numel(labels)
    for ii = numel(names)+1:numel(labels), names{ii,1} = sprintf('ROI_%g',labels(ii)); end
end
names = names(1:numel(labels));
end

function u = localGA_fcUniqueV31(c)
u = {};
for ii = 1:numel(c), s = localGA_fcStrV31(c{ii}); if isempty(s), s = 'Unassigned'; end; if ~any(strcmpi(u,s)), u{end+1,1} = s; end; end
end

function val = localGA_fcPopupV31(S,fieldName,fb)
val = fb;
try
    if isfield(S,fieldName) && isgraphics(S.(fieldName))
        h = S.(fieldName); strs = get(h,'String'); vv = get(h,'Value');
        if iscell(strs), val = strs{max(1,min(numel(strs),vv))}; else, Cc = cellstr(strs); val = Cc{max(1,min(numel(Cc),vv))}; end
    end
catch, val = fb; end
end

function localGA_fcSetInfoV31(S,msg)
try, if isstruct(S) && isfield(S,'hFCInfo') && isgraphics(S.hFCInfo), set(S.hFCInfo,'String',msg); end; catch, end
end

function C = localGA_fcColorsV31()
C = struct(); C.bg = [0.04 0.04 0.04]; C.axisBg = [0.02 0.02 0.02]; C.txt = [1 1 1]; C.muted = [0.75 0.75 0.75];
end

function localGA_fcTextV31(ax,msg,C)
cla(ax); axis(ax,'off'); try, set(ax,'Color',C.axisBg); catch, end
text(ax,0.5,0.5,msg,'Units','normalized','HorizontalAlignment','center','VerticalAlignment','middle','Color',C.txt,'FontSize',12,'Interpreter','none');
end

function cmap = localGA_fcCmapV31(n)
if nargin < 1, n = 256; end
n = max(8,round(n)); h = floor(n/2);
b = [transpose(linspace(0,1,h)) transpose(linspace(0,1,h)) ones(h,1)];
r = [ones(n-h,1) transpose(linspace(1,0,n-h)) transpose(linspace(1,0,n-h))];
cmap = [b; r];
end

function idx = localGA_fcTickV31(n)
if n <= 12, idx = 1:n; else, idx = unique(round(linspace(1,n,12))); end
end

function out = localGA_fcAbbrevV31(names,maxLen)
out = cell(size(names)); for ii = 1:numel(names), out{ii} = localGA_fcShortV31(names{ii},maxLen); end
end

function s = localGA_fcShortV31(s,maxLen)
s = localGA_fcStrV31(s); if numel(s) > maxLen, s = [s(1:max(1,maxLen-3)) '...']; end
end

function s = localGA_fcStrV31(x)
s = '';
try
    if nargin < 1 || isempty(x), return; end
    if ischar(x), s = strtrim(x);
    elseif iscell(x), if ~isempty(x), s = localGA_fcStrV31(x{1}); end
    elseif isnumeric(x) || islogical(x), if isscalar(x), s = strtrim(num2str(x)); else, s = strtrim(mat2str(x)); end
    else, try, s = strtrim(char(x)); catch, s = ''; end
    end
catch, s = ''; end
end

% END_LOCAL_FC_COMPUTE_DISPLAY_HELPERS_V31

% LOCAL_FC_DATA_RECOVERY_HELPERS_V32

function [R,FC] = localGA_fcBuildResultV32(FC,groupA,groupB)
if ~isstruct(FC) || ~isfield(FC,'subjects') || isempty(FC.subjects)
    error('No loaded FC subjects found.');
end

subs = FC.subjects;
valid = [];
for ii = 1:numel(subs)
    [M,Z,labs,nms] = localGA_fcSubjectMatrixV32(subs(ii));
    if ~isempty(M) && ~isempty(labs)
        valid(end+1) = ii;
        FC.subjects(ii).R = M;
        FC.subjects(ii).Z = Z;
        FC.subjects(ii).labels = labs;
        FC.subjects(ii).names = nms;
    end
end

if isempty(valid)
    error('Loaded FC bundle contains subjects, but no usable FC matrix fields were found. Expected fields: R, Z, displayMatrix, displayZ, corrMatrix, fcMatrix, or matrix.');
end

base = valid(1);
labels = double(FC.subjects(base).labels(:));
names = FC.subjects(base).names(:);
nR = numel(labels);

Zstack = []; groups = {}; subjectNames = {}; sourceFiles = {};
for kk = 1:numel(valid)
    ii = valid(kk);
    labs = double(FC.subjects(ii).labels(:));
    [tf,ord] = ismember(labels,labs);
    if any(~tf), continue; end
    Z = double(FC.subjects(ii).Z);
    if size(Z,1) ~= numel(labs) || size(Z,2) ~= numel(labs), continue; end
    Zstack(:,:,end+1) = Z(ord,ord);

    g = '';
    try, g = localGA_fcStrV32(FC.subjects(ii).group); catch, end
    if isempty(g), g = localGA_fcInferGroupV32(FC.subjects(ii)); end
    if isempty(g), g = 'Unassigned'; end
    groups{end+1,1} = g;

    try, subjectNames{end+1,1} = localGA_fcStrV32(FC.subjects(ii).name); catch, subjectNames{end+1,1} = sprintf('Subject_%02d',ii); end
    try, sourceFiles{end+1,1} = localGA_fcStrV32(FC.subjects(ii).sourceFile); catch, sourceFiles{end+1,1} = ''; end
end

if isempty(Zstack)
    error('Could not align FC matrices across subjects.');
end

u = localGA_fcUniqueV32(groups);
groupA = localGA_fcStrV32(groupA);
groupB = localGA_fcStrV32(groupB);
if isempty(groupA) || strcmpi(groupA,'Group A') || ~any(strcmpi(groups,groupA)), groupA = u{1}; end
idxA = strcmpi(groups,groupA);
if isempty(groupB) || strcmpi(groupB,'Group B') || strcmpi(groupB,groupA) || ~any(strcmpi(groups,groupB))
    groupB = 'None';
    for ii = 1:numel(u)
        if ~strcmpi(u{ii},groupA), groupB = u{ii}; break; end
    end
end
idxB = strcmpi(groups,groupB);
singleGroup = ~any(idxB);

meanZA = localGA_fcMean3V32(Zstack(:,:,idxA));
meanRA = tanh(meanZA);
if singleGroup
    meanZB = nan(nR,nR); meanRB = nan(nR,nR); diffZ = nan(nR,nR); diffR = nan(nR,nR);
else
    meanZB = localGA_fcMean3V32(Zstack(:,:,idxB));
    meanRB = tanh(meanZB);
    diffZ = meanZA - meanZB;
    diffR = meanRA - meanRB;
end

R = struct();
R.mode = 'Functional Connectivity';
R.singleGroup = singleGroup;
R.groupA = groupA; R.groupB = groupB; R.nA = sum(idxA); R.nB = sum(idxB);
R.labels = labels; R.names = names(:);
R.meanZA = meanZA; R.meanZB = meanZB; R.meanRA = meanRA; R.meanRB = meanRB;
R.diffZ = diffZ; R.diffR = diffR; R.pMat = nan(nR,nR); R.tMat = nan(nR,nR);
R.groups = groups; R.subjectNames = subjectNames; R.sourceFiles = sourceFiles;
R.note = sprintf('FC data recovered: %d usable subject(s), %d ROI(s). Group A=%s n=%d, Group B=%s n=%d.',size(Zstack,3),nR,R.groupA,R.nA,R.groupB,R.nB);
end



function [M,Z,labels,names] = localGA_fcSubjectMatrixV32(subj)
% FC_MATRIX_RECOVERY_FROM_TC_V33
% Recover subject-level FC matrix from exported bundle.
% Priority: R/Z/displayMatrix fields -> nested matrix fields -> ROI time courses.

M = [];
Z = [];
labels = [];
names = {};

% Labels if exported.
try
    labels = localGA_fcGetNumericVectorV32(subj,{'labels','displayLabels','roiLabels','regionLabels','parcelLabels'});
catch
    labels = [];
end

% 1) Top-level matrix fields.
try
    M = localGA_fcGetNumericMatrixV32(subj,{'R','displayMatrix','corrMatrix','correlationMatrix','fcMatrix','FCmatrix','matrix','connMatrix','connectivityMatrix'});
catch
    M = [];
end

try
    Z = localGA_fcGetNumericMatrixV32(subj,{'Z','displayZ','zMatrix','fisherZ','fisherZMatrix','zFC'});
catch
    Z = [];
end

if isempty(M) && ~isempty(Z)
    M = tanh(Z);
end
if isempty(Z) && ~isempty(M)
    Z = atanh(max(-0.999999,min(0.999999,double(M))));
end

% 2) Nested matrix fields, e.g. subj.fcMeta.R or subj.heatmap.matrix.
if isempty(M)
    try
        [M,Z,labels2,names2] = localGA_fcSearchNestedV32(subj,0);
        if isempty(labels) && ~isempty(labels2), labels = labels2; end
        if isempty(names) && ~isempty(names2), names = names2; end
    catch
        M = []; Z = [];
    end
end

% 3) If no matrix exists, derive subject FC from exported ROI time courses.
if isempty(M)
    try
        [X,labsTC] = localGA_fcFindTimecourseV32(subj);
        if isempty(labels) && ~isempty(labsTC), labels = labsTC; end
        [Xtc,labelsTC2] = localGA_fcOrientTCV33(X,labels);
        if ~isempty(Xtc)
            M = localGA_fcCorrFromTCV33(Xtc);
            labels = labelsTC2;
            Z = atanh(max(-0.999999,min(0.999999,double(M))));
        end
    catch
        M = []; Z = [];
    end
end

if isempty(M)
    return;
end

if ndims(M) ~= 2 || size(M,1) ~= size(M,2) || size(M,1) < 2
    M = []; Z = []; labels = []; names = {};
    return;
end

M = double(M);
M(~isfinite(M)) = 0;

if isempty(labels) || numel(labels) ~= size(M,1)
    labels = transpose(1:size(M,1));
end
labels = double(labels(:));

if isempty(Z) || any(size(Z) ~= size(M))
    Z = atanh(max(-0.999999,min(0.999999,M)));
end
Z = double(Z);
Z(~isfinite(Z)) = 0;

try
    names = localGA_fcGetNamesV32(subj,labels,names);
catch
    names = cell(numel(labels),1);
    for ii = 1:numel(labels)
        names{ii,1} = sprintf('ROI_%g',labels(ii));
    end
end

if numel(names) < numel(labels)
    for ii = numel(names)+1:numel(labels)
        names{ii,1} = sprintf('ROI_%g',labels(ii));
    end
end
names = names(1:numel(labels));
end

function [M,Z,labels,names] = localGA_fcSearchNestedV32(S,depth)
% Search nested structs for FC matrices.
M = []; Z = []; labels = []; names = {};
if depth > 4 || ~isstruct(S)
    return;
end

f = fieldnames(S);
for ii = 1:numel(f)
    fn = f{ii};
    try
        x = S.(fn);
    catch
        continue;
    end

    if isnumeric(x) && ndims(x) == 2 && size(x,1) == size(x,2) && size(x,1) > 1
        nm = lower(fn);
        if strcmpi(fn,'R') || strcmpi(fn,'Z') || ~isempty(strfind(nm,'corr')) || ~isempty(strfind(nm,'matrix')) || ~isempty(strfind(nm,'connect')) || ~isempty(strfind(nm,'fc'))
            if strcmpi(fn,'Z') || ~isempty(strfind(nm,'zmatrix')) || ~isempty(strfind(nm,'fisher'))
                Z = double(x);
                M = tanh(Z);
            else
                M = double(x);
                Z = atanh(max(-0.999999,min(0.999999,M)));
            end
            labels = transpose(1:size(M,1));
            return;
        end
    elseif isstruct(x)
        [M,Z,labels,names] = localGA_fcSearchNestedV32(x,depth+1);
        if ~isempty(M)
            return;
        end
    elseif iscell(x)
        try
            for jj = 1:numel(x)
                if isstruct(x{jj})
                    [M,Z,labels,names] = localGA_fcSearchNestedV32(x{jj},depth+1);
                    if ~isempty(M), return; end
                end
            end
        catch
        end
    end
end
end

function [X,labs] = localGA_fcFindTimecourseV32(S)
% Find ROI time courses in top-level or nested FC bundle fields.
X = []; labs = [];
try
    if isfield(S,'labels') && isnumeric(S.labels)
        labs = double(S.labels(:));
    elseif isfield(S,'displayLabels') && isnumeric(S.displayLabels)
        labs = double(S.displayLabels(:));
    end
catch
    labs = [];
end

fields = {'meanTS','roiTS','timeCourses','roiTimeCourses','TS','tc','signal','signals','roiSignals','regionSignals','parcelTS'};
for ii = 1:numel(fields)
    f = fields{ii};
    try
        if isfield(S,f) && isnumeric(S.(f)) && ~isempty(S.(f))
            Y = double(S.(f));
            if ndims(Y) == 2 && size(Y,1) > 1 && size(Y,2) > 1
                if isempty(labs) || size(Y,1) == numel(labs) || size(Y,2) == numel(labs)
                    X = Y;
                    return;
                end
            end
        end
    catch
    end
end

try
    [X,labs2] = localGA_fcSearchTimecourseNestedV33(S,0,labs);
    if isempty(labs) && ~isempty(labs2), labs = labs2; end
catch
    X = [];
end
end

function [X,labs] = localGA_fcSearchTimecourseNestedV33(S,depth,labsIn)
X = []; labs = labsIn;
if depth > 4 || ~isstruct(S)
    return;
end

f = fieldnames(S);
for ii = 1:numel(f)
    fn = f{ii};
    try
        x = S.(fn);
    catch
        continue;
    end

    nm = lower(fn);
    if isnumeric(x) && ndims(x) == 2 && size(x,1) > 1 && size(x,2) > 1
        looksLikeTC = ~isempty(strfind(nm,'time')) || ~isempty(strfind(nm,'ts')) || ~isempty(strfind(nm,'course')) || ~isempty(strfind(nm,'signal')) || ~isempty(strfind(nm,'roi'));
        isSquare = size(x,1) == size(x,2);
        if looksLikeTC && ~isSquare
            X = double(x);
            return;
        end
    elseif isstruct(x)
        [X,labs] = localGA_fcSearchTimecourseNestedV33(x,depth+1,labs);
        if ~isempty(X), return; end
    elseif iscell(x)
        try
            for jj = 1:numel(x)
                if isstruct(x{jj})
                    [X,labs] = localGA_fcSearchTimecourseNestedV33(x{jj},depth+1,labs);
                    if ~isempty(X), return; end
                end
            end
        catch
        end
    end
end
end

function [Xtc,labelsOut] = localGA_fcOrientTCV33(X,labels)
% Return time x ROI matrix.
Xtc = [];
labelsOut = labels;
if isempty(X) || ~isnumeric(X) || ndims(X) ~= 2
    return;
end
X = double(X);

if isempty(labelsOut)
    if size(X,1) < size(X,2)
        Xtc = transpose(X);
    else
        Xtc = X;
    end
    labelsOut = transpose(1:size(Xtc,2));
    return;
end

labelsOut = double(labelsOut(:));
nLab = numel(labelsOut);

if size(X,2) == nLab
    Xtc = X;
elseif size(X,1) == nLab
    Xtc = transpose(X);
else
    if size(X,1) > size(X,2)
        Xtc = X;
        labelsOut = transpose(1:size(Xtc,2));
    else
        Xtc = transpose(X);
        labelsOut = transpose(1:size(Xtc,2));
    end
end

badRows = all(~isfinite(Xtc),2);
Xtc(badRows,:) = [];

if size(Xtc,1) < 3 || size(Xtc,2) < 2
    Xtc = [];
end
end

function R = localGA_fcCorrFromTCV33(X)
% Pairwise-complete Pearson correlation without Statistics Toolbox.
X = double(X);
n = size(X,2);
R = nan(n,n);

for i = 1:n
    xi0 = X(:,i);
    for j = i:n
        xj0 = X(:,j);
        ok = isfinite(xi0) & isfinite(xj0);
        xi = xi0(ok);
        xj = xj0(ok);
        if numel(xi) >= 3
            xi = xi - mean(xi);
            xj = xj - mean(xj);
            den = sqrt(sum(xi.^2) * sum(xj.^2));
            if den > 0 && isfinite(den)
                rv = sum(xi .* xj) / den;
            else
                rv = 0;
            end
        else
            rv = 0;
        end
        rv = max(-1,min(1,rv));
        R(i,j) = rv;
        R(j,i) = rv;
    end
end

for i = 1:n
    R(i,i) = 1;
end
R(~isfinite(R)) = 0;
end




function fcNoDataLocal(varargin)
% Robust fallback display helper for FC/GA views.
% Accepts: fcNoDataLocal(ax,msg,C), fcNoDataLocal(ax,msg), or fcNoDataLocal(msg).
ax = [];
msg = 'No data available for this view.';
C = struct();
C.axisBg = [0.02 0.02 0.02];
C.txt = [1 1 1];

try
    if nargin >= 1
        if isgraphics(varargin{1})
            ax = varargin{1};
            if nargin >= 2
                msg = fcNoDataLocal_str(varargin{2});
            end
            if nargin >= 3 && isstruct(varargin{3})
                C = varargin{3};
                if ~isfield(C,'axisBg'), C.axisBg = [0.02 0.02 0.02]; end
                if ~isfield(C,'txt'), C.txt = [1 1 1]; end
            end
        else
            msg = fcNoDataLocal_str(varargin{1});
        end
    end

    if isempty(ax) || ~isgraphics(ax)
        try
            ax = gca;
        catch
            return;
        end
    end

    try, cla(ax); catch, end
    try, axis(ax,'off'); catch, end
    try, set(ax,'Color',C.axisBg); catch, end

    text(ax,0.5,0.5,msg, ...
        'Units','normalized', ...
        'HorizontalAlignment','center', ...
        'VerticalAlignment','middle', ...
        'Color',C.txt, ...
        'FontSize',12, ...
        'FontWeight','bold', ...
        'Interpreter','none');
catch
    % Never allow a no-data display helper to crash the GUI.
end
end

function s = fcNoDataLocal_str(x)
s = '';
try
    if nargin < 1 || isempty(x)
        s = '';
    elseif ischar(x)
        s = strtrim(x);
    elseif iscell(x)
        if ~isempty(x), s = fcNoDataLocal_str(x{1}); end
    elseif isnumeric(x) || islogical(x)
        if isscalar(x), s = strtrim(num2str(x)); else, s = strtrim(mat2str(x)); end
    else
        try, s = strtrim(char(x)); catch, s = ''; end
    end
catch
    s = '';
end
if isempty(s)
    s = 'No data available for this view.';
end
end




function rows = findBundleDisplayRowsLocal(S)
% Restored helper: returns table rows that have a bundle/FC file path.
% Works with the main GA table where column 8 is Bundle File.
rows = [];
try
    if nargin < 1 || ~isstruct(S) || ~isfield(S,'subj') || isempty(S.subj)
        return;
    end

    tbl = S.subj;
    if ~iscell(tbl)
        return;
    end

    nRows = size(tbl,1);
    nCols = size(tbl,2);

    % Prefer column 8, because original GroupAnalysis used column 8 = Bundle File.
    candidateCols = [];
    if nCols >= 8
        candidateCols = 8;
    end

    % Also search nearby/file columns as fallback, because patched tables can vary.
    for cc = 1:nCols
        if cc ~= 8
            candidateCols(end+1) = cc;
        end
    end

    for r = 1:nRows
        hasBundle = false;

        for kk = 1:numel(candidateCols)
            c = candidateCols(kk);
            if c < 1 || c > nCols
                continue;
            end

            fp = findBundleDisplayRowsLocal_str(tbl{r,c});
            if isempty(fp)
                continue;
            end

            [~,nm,ext] = fileparts(fp);
            low = lower([nm ext]);

            % Accept actual existing bundle files first.
            if exist(fp,'file') == 2
                if strcmpi(ext,'.mat') || ~isempty(strfind(low,'bundle')) || ~isempty(strfind(low,'fc'))
                    hasBundle = true;
                    break;
                end
            end

            % Also accept stored paths even if drive is currently disconnected.
            if ~isempty(strfind(low,'bundle')) || ~isempty(strfind(low,'groupbundle')) || ~isempty(strfind(low,'fc_group')) || ~isempty(strfind(low,'fc'))
                if strcmpi(ext,'.mat') || ~isempty(ext)
                    hasBundle = true;
                    break;
                end
            end
        end

        if hasBundle
            rows(end+1) = r;
        end
    end
catch
    rows = [];
end
end

function s = findBundleDisplayRowsLocal_str(x)
s = '';
try
    if nargin < 1 || isempty(x)
        return;
    elseif ischar(x)
        s = strtrim(x);
    elseif iscell(x)
        if ~isempty(x)
            s = findBundleDisplayRowsLocal_str(x{1});
        end
    elseif isnumeric(x) || islogical(x)
        if isscalar(x)
            s = strtrim(num2str(x));
        else
            s = strtrim(mat2str(x));
        end
    else
        try
            s = strtrim(char(x));
        catch
            s = '';
        end
    end
catch
    s = '';
end
end











function startPath = getSmartBrowseDir(S)
% Restored smart Add Bundles start folder.
% Finds the current fUSI Studio loaded data / analysed folder instead of toolbox GitHub folder.
startPath = localGA_forceLoadedDataBundleDirV39(S,'');
if isempty(startPath)
    try, startPath = pwd; catch, startPath = '.'; end
end
end

function startPath = localGA_forceLoadedDataBundleDirV39(S,fallbackPath)
% Pick best Add Bundles start folder from loaded fUSI data context.
startPath = '';
try
    paths = localGA_contextPathsV39(S);
    dirs = {};

    % First: selected table row paths, if available.
    try
        rowDirs = localGA_getTableRowPathDirsV39(S);
        dirs = [dirs; rowDirs(:)];
    catch
    end

    % Then: all context paths from S / studio / open figures / base workspace.
    for ii = 1:numel(paths)
        cdirs = localGA_candidateDirsFromPathV39(paths{ii});
        dirs = [dirs; cdirs(:)]; %#ok<AGROW>
    end

    % Fallback path only after loaded-data candidates.
    if nargin >= 2 && ~isempty(fallbackPath)
        cdirs = localGA_candidateDirsFromPathV39(fallbackPath);
        dirs = [dirs; cdirs(:)];
    end

    startPath = localGA_bestBundleDirV39(dirs);

    if isempty(startPath)
        try, startPath = pwd; catch, startPath = '.'; end
    end

    try
        if ~isempty(startPath)
            fprintf('Add Bundles start folder: %s\n',startPath);
        end
    catch
    end
catch
    if nargin >= 2 && exist(fallbackPath,'dir') == 7
        startPath = fallbackPath;
    else
        try, startPath = pwd; catch, startPath = '.'; end
    end
end
end

function paths = localGA_contextPathsV39(S)
% Collect path-like strings from GA state, fUSI Studio, open figures, and base workspace.
paths = {};
try
    paths = [paths; localGA_collectPathsV39(S,0)];
catch
end

% Common base workspace variable names used by fUSI Studio sessions.
baseVars = {'studio','S','handles','app','data'};
for ii = 1:numel(baseVars)
    try
        existsVar = evalin('base',sprintf('exist(''%s'',''var'')',baseVars{ii}));
        if existsVar
            X = evalin('base',baseVars{ii});
            paths = [paths; localGA_collectPathsV39(X,0)]; %#ok<AGROW>
        end
    catch
    end
end

% Open GUI figures may hold fUSI Studio state in guidata/appdata.
try
    figs = findall(0,'Type','figure');
    for ff = 1:numel(figs)
        try
            G = guidata(figs(ff));
            paths = [paths; localGA_collectPathsV39(G,0)]; %#ok<AGROW>
        catch
        end
        try
            appNames = getappdata(figs(ff));
            if isstruct(appNames)
                f = fieldnames(appNames);
                for jj = 1:numel(f)
                    paths = [paths; localGA_collectPathsV39(appNames.(f{jj}),0)]; %#ok<AGROW>
                end
            end
        catch
        end
    end
catch
end

% De-duplicate.
clean = {};
for ii = 1:numel(paths)
    p = localGA_strV39(paths{ii});
    if isempty(p), continue; end
    if ~localGA_isPathLikeV39(p), continue; end
    if ~any(strcmp(clean,p))
        clean{end+1,1} = p; %#ok<AGROW>
    end
end
paths = clean;
end

function paths = localGA_collectPathsV39(X,depth)
paths = {};
if depth > 5
    return;
end
try
    if ischar(X)
        s = localGA_strV39(X);
        if localGA_isPathLikeV39(s)
            paths = {s};
        end
        return;
    elseif iscell(X)
        for ii = 1:min(numel(X),300)
            paths = [paths; localGA_collectPathsV39(X{ii},depth+1)]; %#ok<AGROW>
        end
    elseif isstruct(X)
        f = fieldnames(X);
        for ii = 1:numel(f)
            fn = f{ii};
            % Prioritize fields that usually contain loaded data paths.
            try
                val = X.(fn);
            catch
                continue;
            end
            paths = [paths; localGA_collectPathsV39(val,depth+1)]; %#ok<AGROW>
        end
    end
catch
end
end

function dirs = localGA_candidateDirsFromPathV39(p)
% Convert any path/file into candidate folders, including analysed/GroupAnalysis subfolders.
dirs = {};
try
    p = localGA_strV39(p);
    if isempty(p), return; end
    if ~localGA_isPathLikeV39(p), return; end

    baseDir = localGA_existingDirV39(p);
    if isempty(baseDir), return; end

    pref = localGA_preferredAnalysisDirsV39(baseDir);
    dirs = [dirs; pref(:)];
    dirs{end+1,1} = baseDir;

    % Also check parent because raw data file may sit next to analysed folder.
    try
        parentDir = fileparts(baseDir);
        if ~isempty(parentDir) && exist(parentDir,'dir') == 7
            pref2 = localGA_preferredAnalysisDirsV39(parentDir);
            dirs = [dirs; pref2(:)];
        end
    catch
    end
catch
end
end

function dirs = localGA_preferredAnalysisDirsV39(baseDir)
% Existing nearby folders where GroupAnalysis/FC bundles usually live.
dirs = {};
try
    baseDir = localGA_strV39(baseDir);
    if isempty(baseDir) || exist(baseDir,'dir') ~= 7, return; end

    fixed = { ...
        fullfile(baseDir,'GroupAnalysis','FunctionalConnectivity'), ...
        fullfile(baseDir,'GroupAnalysis','Bundles','FC'), ...
        fullfile(baseDir,'GroupAnalysis','Bundles'), ...
        fullfile(baseDir,'GroupAnalysis'), ...
        fullfile(baseDir,'FunctionalConnectivity'), ...
        fullfile(baseDir,'FC'), ...
        fullfile(baseDir,'analysis','GroupAnalysis'), ...
        fullfile(baseDir,'Analysis','GroupAnalysis'), ...
        fullfile(baseDir,'analysed','GroupAnalysis'), ...
        fullfile(baseDir,'Analyzed','GroupAnalysis'), ...
        fullfile(baseDir,'processed','GroupAnalysis'), ...
        fullfile(baseDir,'Processed','GroupAnalysis')};

    for ii = 1:numel(fixed)
        if exist(fixed{ii},'dir') == 7
            dirs{end+1,1} = fixed{ii}; %#ok<AGROW>
        end
    end

    % One-level scan for analysed/analysis folders and GroupAnalysis folders.
    dd = dir(baseDir);
    for ii = 1:numel(dd)
        if ~dd(ii).isdir || strcmp(dd(ii).name,'.') || strcmp(dd(ii).name,'..')
            continue;
        end
        nm = lower(dd(ii).name);
        child = fullfile(baseDir,dd(ii).name);
        if ~isempty(strfind(nm,'analysis')) || ~isempty(strfind(nm,'analys')) || ~isempty(strfind(nm,'processed')) || ~isempty(strfind(nm,'result')) || ~isempty(strfind(nm,'groupanalysis')) || ~isempty(strfind(nm,'functionalconnectivity'))
            dirs{end+1,1} = child; %#ok<AGROW>
            more = {fullfile(child,'GroupAnalysis'), fullfile(child,'GroupAnalysis','FunctionalConnectivity'), fullfile(child,'FunctionalConnectivity'), fullfile(child,'FC')};
            for jj = 1:numel(more)
                if exist(more{jj},'dir') == 7
                    dirs{end+1,1} = more{jj}; %#ok<AGROW>
                end
            end
        end
    end
catch
end
end

function bestDir = localGA_bestBundleDirV39(dirs)
bestDir = '';
bestScore = -Inf;
try
    for ii = 1:numel(dirs)
        d = localGA_strV39(dirs{ii});
        if isempty(d) || exist(d,'dir') ~= 7
            continue;
        end
        sc = localGA_scoreBundleDirV39(d);
        if sc > bestScore
            bestScore = sc;
            bestDir = d;
        end
    end
catch
end
end

function sc = localGA_scoreBundleDirV39(d)
sc = 0;
try
    low = lower(localGA_strV39(d));

    % Avoid toolbox/code folder unless nothing else exists.
    if ~isempty(strfind(low,'github')) || ~isempty(strfind(low,'deconfusion')) || ~isempty(strfind(low,'humor-analysis-tool'))
        sc = sc - 10000;
    end

    if ~isempty(strfind(low,'groupanalysis')), sc = sc + 500; end
    if ~isempty(strfind(low,'functionalconnectivity')), sc = sc + 400; end
    if ~isempty(strfind(low,'bundle')), sc = sc + 200; end
    if ~isempty(strfind(low,'analysis')) || ~isempty(strfind(low,'analys')), sc = sc + 150; end
    if ~isempty(strfind(low,'processed')) || ~isempty(strfind(low,'result')), sc = sc + 80; end
    if ~isempty(strfind(low,'fc')), sc = sc + 40; end

    try
        m1 = dir(fullfile(d,'FC_GroupBundle*.mat'));
        m2 = dir(fullfile(d,'*GroupBundle*.mat'));
        m3 = dir(fullfile(d,'*FC*.mat'));
        m4 = dir(fullfile(d,'*.mat'));
        if ~isempty(m1), sc = sc + 1000; end
        if ~isempty(m2), sc = sc + 700; end
        if ~isempty(m3), sc = sc + 300; end
        if ~isempty(m4), sc = sc + 100; end
    catch
    end
catch
    sc = -Inf;
end
end

function d = localGA_existingDirV39(p)
d = '';
try
    p = localGA_strV39(p);
    if isempty(p), return; end

    if exist(p,'dir') == 7
        d = p;
        return;
    end

    if exist(p,'file') == 2
        [d0,~,~] = fileparts(p);
        if exist(d0,'dir') == 7
            d = d0;
            return;
        end
    end

    % For stored paths that no longer exist exactly, walk upward.
    q = p;
    for kk = 1:12
        [q2,~,~] = fileparts(q);
        if isempty(q2) || strcmp(q2,q)
            break;
        end
        if exist(q2,'dir') == 7
            d = q2;
            return;
        end
        q = q2;
    end
catch
    d = '';
end
end

function tf = localGA_isPathLikeV39(p)
tf = false;
try
    p = localGA_strV39(p);
    if isempty(p), return; end
    low = lower(p);
    if any(strcmpi(low,{'exists','missing','none','nan','true','false'}))
        return;
    end
    if ~isempty(strfind(p,':\')) || ~isempty(strfind(p,'\\')) || ~isempty(strfind(p,'/'))
        tf = true;
        return;
    end
    [~,~,ext] = fileparts(p);
    if ~isempty(ext) && any(strcmpi(ext,{'.mat','.nii','.gz','.csv','.txt','.xlsx'}))
        tf = true;
    end
catch
    tf = false;
end
end

function rows = localGA_getSelectedRowsV39(S)
rows = [];
try
    fields = {'selectedRows','lastSelectedRows','selectedRow','lastSelectedRow','activeRow','currentRow','selectedTableRows'};
    for ii = 1:numel(fields)
        if isstruct(S) && isfield(S,fields{ii}) && ~isempty(S.(fields{ii})) && isnumeric(S.(fields{ii}))
            rows = [rows; double(S.(fields{ii})(:))]; %#ok<AGROW>
        end
    end
catch
end
rows = rows(isfinite(rows) & rows >= 1);
rows = unique(round(rows));
end

function dirs = localGA_getTableRowPathDirsV39(S)
dirs = {};
try
    if ~isstruct(S) || ~isfield(S,'subj') || ~iscell(S.subj), return; end
    rows = localGA_getSelectedRowsV39(S);
    if isempty(rows)
        rows = 1:size(S.subj,1);
    end
    rows = rows(rows >= 1 & rows <= size(S.subj,1));
    priorityCols = [6 7 8 5 4 3 2 1];
    priorityCols = priorityCols(priorityCols <= size(S.subj,2));

    for rr = 1:numel(rows)
        r = rows(rr);
        for cc = priorityCols
            p = localGA_strV39(S.subj{r,cc});
            cdirs = localGA_candidateDirsFromPathV39(p);
            dirs = [dirs; cdirs(:)]; %#ok<AGROW>
        end
    end
catch
end
end

function S = addBundleAsNewRow(S,bundleFile)
% GA_MIN_FIX: corrected table layout. Column 1 is logical Use, column 8 is SCM bundle.
try
    fp = localGA_strV39(bundleFile);
    if isempty(fp), return; end

    if ~isstruct(S), S = struct(); end
    if ~isfield(S,'subj') || isempty(S.subj) || ~iscell(S.subj)
        S.subj = cell(0,9);
    end
    if size(S.subj,2) < 9
        S.subj(:,end+1:9) = {''};
    elseif size(S.subj,2) > 9
        S.subj = S.subj(:,1:9);
    end

    animalName = localGA_inferBundleAnimalV39(fp);
    g = 'PACAP';
    c = 'CondA';
    try, if isfield(S,'defaultGroup') && ~isempty(S.defaultGroup), g = S.defaultGroup; end, catch, end
    try, if isfield(S,'defaultCond')  && ~isempty(S.defaultCond),  c = S.defaultCond;  end, catch, end

    row = {true, animalName, g, c, animalName, '', '', '', ''};

    isFC  = localGA_isFCMatFile_MIN(fp);
    isSCM = localGA_isSCMMatFile_MIN(fp);
    if isFC && ~isSCM
        row{8} = '';
    else
        row{8} = fp;
    end

    S.subj(end+1,1:9) = row;
    S = ensureFCRowFilesSizeV13(S);
    newRow = size(S.subj,1);
    if isFC && ~isSCM
        S.fcRowFiles{newRow,1} = fp;
    else
        S.fcRowFiles{newRow,1} = '';
    end

    try
        [d,~,~] = fileparts(fp);
        if exist(d,'dir') == 7
            S.lastBundleDir = d;
            S.lastFCBundleDir = d;
            S.lastBrowseDir = d;
        end
    catch
    end
catch ME
    warning('addBundleAsNewRow failed: %s',ME.message);
end
end


function animalName = localGA_inferBundleAnimalV39(fp)
animalName = 'FC Bundle';
try
    fp = localGA_strV39(fp);
    [d,nm,~] = fileparts(fp);
    animalName = nm;
    parts = regexp(d,'[\\/]+','split');
    for ii = numel(parts):-1:1
        p = strtrim(parts{ii});
        if isempty(p), continue; end
        low = lower(p);
        if isempty(strfind(low,'groupanalysis')) && isempty(strfind(low,'functionalconnectivity')) && isempty(strfind(low,'bundle')) && isempty(strfind(low,'fc'))
            animalName = p;
            return;
        end
    end
catch
end
end

function s = localGA_strV39(x)
s = '';
try
    if nargin < 1 || isempty(x)
        return;
    elseif ischar(x)
        s = strtrim(x);
    elseif iscell(x)
        if ~isempty(x), s = localGA_strV39(x{1}); end
    elseif isnumeric(x) || islogical(x)
        if isscalar(x), s = strtrim(num2str(x)); else, s = strtrim(mat2str(x)); end
    else
        try, s = strtrim(char(x)); catch, s = ''; end
    end
catch
    s = '';
end
end




function meta = extractMetaFromSources(varargin)
% Restored helper used by sanitizeTableStruct.
% Input usually: row animal/name, data file, ROI file, bundle file.
% Output is intentionally rich/compatible so older GA code can use different field names.

meta = struct();
meta.animal = '';
meta.animalID = '';
meta.animalId = '';
meta.subject = '';
meta.subjectID = '';
meta.name = '';
meta.group = '';
meta.session = '';
meta.sessionID = '';
meta.sessionId = '';
meta.scan = '';
meta.scanID = '';
meta.scanId = '';
meta.dataFile = '';
meta.roiFile = '';
meta.bundleFile = '';
meta.folder = '';
meta.rootDir = '';
meta.sourceFile = '';
meta.valid = false;

try
    src = cell(nargin,1);
    for ii = 1:nargin
        src{ii} = extractMetaFromSources_str(varargin{ii});
    end

    if numel(src) >= 1, meta.name = src{1}; end
    if numel(src) >= 2, meta.dataFile = src{2}; end
    if numel(src) >= 3, meta.roiFile = src{3}; end
    if numel(src) >= 4, meta.bundleFile = src{4}; end

    % Pick best source file: bundle > data > roi > name/path.
    candidates = {meta.bundleFile, meta.dataFile, meta.roiFile, meta.name};
    for ii = 1:numel(candidates)
        p = extractMetaFromSources_str(candidates{ii});
        if ~isempty(p)
            meta.sourceFile = p;
            break;
        end
    end

    meta.folder = extractMetaFromSources_firstExistingDir(candidates);
    meta.rootDir = meta.folder;

    animal = extractMetaFromSources_guessAnimal(candidates);
    if isempty(animal)
        animal = meta.name;
    end
    if isempty(animal)
        animal = 'Unknown';
    end

    meta.animal = animal;
    meta.animalID = animal;
    meta.animalId = animal;
    meta.subject = animal;
    meta.subjectID = animal;

    meta.group = extractMetaFromSources_guessGroup(candidates);

    % Scan/session guess from path/file name.
    joined = strjoin(candidates,' ');
    tok = regexp(joined,'scan[_ -]?([A-Za-z0-9]+)','tokens','once');
    if ~isempty(tok)
        meta.scan = tok{1};
        meta.scanID = tok{1};
        meta.scanId = tok{1};
    end

    % GA_MIN_SESSION_PARSE_20260616
    try
        tokS = regexp(joined,'(?i)(Session[_ -]?0*\d+|Session\d+|S\d+)','match','once');
        if ~isempty(tokS)
            meta.session = tokS;
            meta.sessionID = tokS;
            meta.sessionId = tokS;
        end
    catch
        meta.session = '';
        meta.sessionID = '';
        meta.sessionId = '';
    end

    meta.valid = ~isempty(meta.sourceFile) || ~isempty(meta.name);
catch
    % Never let metadata extraction crash table sanitizing.
end
end

function s = extractMetaFromSources_str(x)
s = '';
try
    if nargin < 1 || isempty(x)
        return;
    elseif ischar(x)
        s = strtrim(x);
    elseif iscell(x)
        if ~isempty(x)
            s = extractMetaFromSources_str(x{1});
        end
    elseif isnumeric(x) || islogical(x)
        if isscalar(x)
            s = strtrim(num2str(x));
        else
            s = strtrim(mat2str(x));
        end
    else
        try
            s = strtrim(char(x));
        catch
            s = '';
        end
    end
catch
    s = '';
end
end

function d = extractMetaFromSources_firstExistingDir(candidates)
d = '';
try
    for ii = 1:numel(candidates)
        p = extractMetaFromSources_str(candidates{ii});
        if isempty(p), continue; end
        if exist(p,'dir') == 7
            d = p;
            return;
        end
        if exist(p,'file') == 2
            [d0,~,~] = fileparts(p);
            if exist(d0,'dir') == 7
                d = d0;
                return;
            end
        end
        q = p;
        for kk = 1:10
            [q2,~,~] = fileparts(q);
            if isempty(q2) || strcmp(q2,q), break; end
            if exist(q2,'dir') == 7
                d = q2;
                return;
            end
            q = q2;
        end
    end
catch
    d = '';
end
end

function animal = extractMetaFromSources_guessAnimal(candidates)
animal = '';
try
    for ii = 1:numel(candidates)
        p = extractMetaFromSources_str(candidates{ii});
        if isempty(p), continue; end

        % Prefer folder names above GroupAnalysis/FunctionalConnectivity folders.
        parts = regexp(p,'[\\/]+','split');
        for jj = numel(parts):-1:1
            nm = strtrim(parts{jj});
            if isempty(nm), continue; end
            low = lower(nm);
            if ~isempty(strfind(low,'groupanalysis')) || ~isempty(strfind(low,'functionalconnectivity')) || ~isempty(strfind(low,'bundle')) || strcmpi(low,'fc')
                continue;
            end
            if ~isempty(strfind(low,'github')) || ~isempty(strfind(low,'deconfusion'))
                continue;
            end
            animal = nm;
            return;
        end

        [~,nm,~] = fileparts(p);
        if ~isempty(nm)
            animal = nm;
            return;
        end
    end
catch
    animal = '';
end
end

function group = extractMetaFromSources_guessGroup(candidates)
group = '';
try
    joined = lower(strjoin(candidates,' '));
    if ~isempty(strfind(joined,'vehicle')) || ~isempty(strfind(joined,'veh')) || ~isempty(strfind(joined,'pbs')) || ~isempty(strfind(joined,'acsf'))
        group = 'Vehicle';
    elseif ~isempty(strfind(joined,'pacap'))
        group = 'PACAP';
    elseif ~isempty(strfind(joined,'control')) || ~isempty(strfind(joined,'ctrl'))
        group = 'Control';
    elseif ~isempty(strfind(joined,'treat'))
        group = 'Treatment';
    else
        group = '';
    end
catch
    group = '';
end
end


% GA_MIN_FIX_20260616_START
function S = assignBundleToRow(S,r,fp)
try
    fp = strtrimSafe(fp);
    if isempty(fp), return; end
    if r < 1 || r > size(S.subj,1), return; end
    if size(S.subj,2) < 9, S.subj(:,end+1:9) = {''}; end
    S.subj{r,1} = true;
    if isempty(strtrimSafe(S.subj{r,2})), S.subj{r,2} = localGA_inferBundleAnimalV39(fp); end
    if isempty(strtrimSafe(S.subj{r,3})), S.subj{r,3} = S.defaultGroup; end
    if isempty(strtrimSafe(S.subj{r,4})), S.subj{r,4} = S.defaultCond; end
    if isempty(strtrimSafe(S.subj{r,5})), S.subj{r,5} = S.subj{r,2}; end
    S = ensureFCRowFilesSizeV13(S);
    if localGA_isFCMatFile_MIN(fp) && ~localGA_isSCMMatFile_MIN(fp)
        S.fcRowFiles{r,1} = fp;
        S.subj{r,8} = '';
    else
        S.subj{r,8} = fp;
        S.fcRowFiles{r,1} = '';
    end
catch ME
    warning('assignBundleToRow failed: %s',ME.message);
end
end

function S = addFileSmartLight(S,fp)
try
    fp = strtrimSafe(fp);
    if isempty(fp), return; end
    if ~isfield(S,'subj') || isempty(S.subj) || ~iscell(S.subj), S.subj = cell(0,9); end
    if size(S.subj,2) < 9, S.subj(:,end+1:9) = {''}; elseif size(S.subj,2) > 9, S.subj = S.subj(:,1:9); end
    animalName = localGA_inferBundleAnimalV39(fp);
    g = S.defaultGroup;
    c = S.defaultCond;
    row = {true,animalName,g,c,animalName,'','','',''};
    [~,~,ext] = fileparts(fp);
    isFC = localGA_isFCMatFile_MIN(fp);
    isSCM = localGA_isSCMMatFile_MIN(fp);
    if strcmpi(ext,'.txt')
        row{7} = fp;
    elseif isFC && ~isSCM
        row{8} = '';
    elseif isSCM
        row{8} = fp;
    else
        row{6} = fp;
    end
    S.subj(end+1,1:9) = row;
    S = ensureFCRowFilesSizeV13(S);
    newRow = size(S.subj,1);
    if isFC && ~isSCM, S.fcRowFiles{newRow,1} = fp; end
catch ME
    warning('addFileSmartLight failed: %s',ME.message);
end
end

function tf = localGA_isFCMatFile_MIN(fp)
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
        tf = any(strcmp({info.name},'fcBundle'));
    end
catch
    tf = false;
end
end

function tf = localGA_isSCMMatFile_MIN(fp)
tf = false;
try
    fp = strtrimSafe(fp);
    if isempty(fp), return; end
    [~,nm,ext] = fileparts(fp);
    if strcmpi(ext,'.mat') && ~isempty(regexpi(nm,'SCM|GroupExport|SCM_Group|MapBundle','once'))
        tf = true;
        return;
    end
    if exist(fp,'file') == 2
        info = whos('-file',fp);
        names = {info.name};
        tf = any(strcmp(names,'G')) || any(strcmp(names,'groupBundle'));
    end
catch
    tf = false;
end
end

function s = displayScanID(scanID)
s = strtrimSafe(scanID);
if isempty(s) || strcmpi(s,'N/A')
    s = '';
    return;
end
s = regexprep(s,'(?i)^FUS_?','');
s = regexprep(s,'(?i)^SCAN','scan');
end

function s = simplifyFileLabel(fp)
fp = strtrimSafe(fp);
if isempty(fp), s = ''; return; end
try
    [~,bn,ext] = fileparts(fp);
    s = [bn ext];
catch
    s = fp;
end
if numel(s) > 38
    s = [s(1:35) '...'];
end
end

function s = simplifyROIFileLabel(fp)
s = simplifyFileLabel(fp);
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

function s = deriveRowStatusWithFCV13(row,fcFile)
roi = ''; bundle = ''; st = ''; use = true;
if nargin < 2, fcFile = ''; end
fcFile = strtrimSafe(fcFile);
try, roi = strtrimSafe(row{7}); catch, end
try, bundle = strtrimSafe(row{8}); catch, end
try, st = lower(strtrimSafe(row{9})); catch, end
try, use = logicalCellValue(row{1}); catch, end
if ~isempty(strfind(st,'excluded'))
    s = 'Excluded';
elseif ~use
    s = 'Not used';
elseif ~isempty(roi) || ~isempty(bundle) || ~isempty(fcFile)
    s = 'OK';
else
    s = 'Not set';
end
end

function s = deriveRowStatus(row)
s = deriveRowStatusWithFCV13(row,'');
end
% GA_MIN_FIX_20260616_END


% GA_RESTORE_MISSING_HELPERS_20260616_START
function info = extractRowMetaLight(row)
% Lightweight row metadata helper for GroupAnalysis map side table.
% IMPORTANT: does not load large data mats.
info = struct();

info.subject    = GA_restore_getrowstr_20260616(row,2);
info.group      = GA_restore_getrowstr_20260616(row,3);
info.condition  = GA_restore_getrowstr_20260616(row,4);
info.pairID     = GA_restore_getrowstr_20260616(row,5);
info.dataFile   = GA_restore_getrowstr_20260616(row,6);
info.roiFile    = GA_restore_getrowstr_20260616(row,7);
info.bundleFile = GA_restore_getrowstr_20260616(row,8);
info.status     = GA_restore_getrowstr_20260616(row,9);

meta = struct();
try
    meta = extractMetaFromSources(info.subject, info.dataFile, info.roiFile, info.bundleFile);
catch
    meta = struct();
end

if isfield(meta,'animalID') && ~isempty(meta.animalID)
    info.animalID = GA_restore_str_20260616(meta.animalID);
else
    info.animalID = info.subject;
end

if isempty(info.animalID)
    info.animalID = GA_restore_guess_subject_20260616(info.bundleFile, info.roiFile, info.dataFile);
end
if isempty(info.animalID)
    info.animalID = 'Unknown';
end

if isfield(meta,'session') && ~isempty(meta.session)
    info.session = GA_restore_str_20260616(meta.session);
elseif isfield(meta,'sessionID') && ~isempty(meta.sessionID)
    info.session = GA_restore_str_20260616(meta.sessionID);
elseif isfield(meta,'sessionId') && ~isempty(meta.sessionId)
    info.session = GA_restore_str_20260616(meta.sessionId);
else
    info.session = GA_restore_parse_session_20260616({info.bundleFile,info.roiFile,info.dataFile,info.subject});
end

if isfield(meta,'scanID') && ~isempty(meta.scanID)
    info.scanID = GA_restore_str_20260616(meta.scanID);
elseif isfield(meta,'scanId') && ~isempty(meta.scanId)
    info.scanID = GA_restore_str_20260616(meta.scanId);
else
    info.scanID = GA_restore_parse_scan_20260616({info.bundleFile,info.roiFile,info.dataFile,info.subject});
end

info.notes             = '';
info.useForPublication = '';
info.animalStatus      = '';
info.TR_sec            = NaN;
info.NVols             = NaN;
end

function [FC, cache] = localGA_loadFCfilesv13(fileList, cache)
% Case-compatibility wrapper. Some current code calls localGA_loadFCfilesv13.
[FC, cache] = localGA_loadFCFilesV13(fileList, cache);
end

function [FC, cache] = localGA_loadFCFilesV13(fileList, cache)
% Robust FC bundle loader wrapper for GroupAnalysis.m.
if nargin < 2 || isempty(cache)
    cache = struct();
end
if nargin < 1 || isempty(fileList)
    fileList = {};
end
if ischar(fileList)
    fileList = {fileList};
end
fileList = fileList(:);

% Preferred path: use the modular FC backend.
try
    [FC, cache] = GroupAnalysis_FC('loadFCGroupBundlesFromFiles', fileList, cache);
    if ~isfield(FC,'loaded'), FC.loaded = true; end
    return;
catch ME_backend
    try
        fprintf(2,'GroupAnalysis_FC loader fallback activated: %s\n',ME_backend.message);
    catch
    end
end

% Fallback path: directly read fcBundle.subjects from MAT files.
FC = struct();
FC.files = fileList;
FC.subjects = struct([]);
FC.nSubjects = 0;
FC.loaded = false;

idx = 0;
for ii = 1:numel(fileList)
    fp = GA_restore_str_20260616(fileList{ii});
    if isempty(fp) || exist(fp,'file') ~= 2
        continue;
    end
    try
        L = load(fp);
        B = [];
        if isfield(L,'fcBundle') && isstruct(L.fcBundle)
            B = L.fcBundle;
        elseif isfield(L,'FC') && isstruct(L.FC)
            B = L.FC;
        elseif isfield(L,'G') && isstruct(L.G)
            B = L.G;
        end
        if isempty(B) || ~isstruct(B) || ~isfield(B,'subjects')
            continue;
        end
        Slist = B.subjects;
        for jj = 1:numel(Slist)
            subj0 = Slist(jj);
            [R,Z,labels,names] = GA_restore_fc_matrix_20260616(subj0);
            if isempty(R) || isempty(labels)
                continue;
            end
            idx = idx + 1;
            FC.subjects(idx).sourceFile = fp;
            if isfield(subj0,'name') && ~isempty(subj0.name)
                FC.subjects(idx).name = GA_restore_str_20260616(subj0.name);
            else
                FC.subjects(idx).name = GA_restore_guess_subject_20260616(fp,'','');
            end
            if isfield(subj0,'group') && ~isempty(subj0.group)
                FC.subjects(idx).group = GA_restore_str_20260616(subj0.group);
            else
                FC.subjects(idx).group = GA_restore_infer_fc_group_20260616([FC.subjects(idx).name ' ' fp]);
            end
            FC.subjects(idx).labels = double(labels(:));
            FC.subjects(idx).names  = names(:);
            FC.subjects(idx).R = double(R);
            FC.subjects(idx).Z = double(Z);
            FC.subjects(idx).displayMatrix = FC.subjects(idx).R;
            FC.subjects(idx).displayZ      = FC.subjects(idx).Z;
            FC.subjects(idx).displayNames  = FC.subjects(idx).names;
            FC.subjects(idx).displayLabels = FC.subjects(idx).labels;
            try, FC.subjects(idx).TR = double(subj0.TR); catch, FC.subjects(idx).TR = []; end
            try, FC.subjects(idx).analysisDir = subj0.analysisDir; catch, FC.subjects(idx).analysisDir = ''; end
            try, FC.subjects(idx).isStepMotor3D = logical(subj0.isStepMotor3D); catch, FC.subjects(idx).isStepMotor3D = false; end
            try, FC.subjects(idx).nSlices = double(subj0.nSlices); catch, FC.subjects(idx).nSlices = []; end
            try, FC.subjects(idx).sliceResults = subj0.sliceResults; catch, FC.subjects(idx).sliceResults = struct([]); end
        end
    catch ME_file
        try
            fprintf(2,'Skipping FC file: %s | %s\n',fp,ME_file.message);
        catch
        end
    end
end

FC.nSubjects = idx;
FC.loaded = idx > 0;
end

function S = localGA_buildFCFromTableRowsV13(S)
% Build S.FC from S.fcRowFiles / table rows.
try
    S = ensureFCRowFilesSizeV13(S);
catch
    if ~isfield(S,'fcRowFiles') || numel(S.fcRowFiles) ~= size(S.subj,1)
        S.fcRowFiles = cell(size(S.subj,1),1);
    end
end
files = {};
try
    files = S.fcRowFiles(:);
    files = files(~cellfun(@isempty,files));
catch
    files = {};
end
[FC, cacheOut] = localGA_loadFCFilesV13(files, S.cache);
S.cache = cacheOut;
S.FC = FC;
end

function S = localGA_autoAttachFCFilesToRowsV13(S, FC)
% Attach loaded FC file paths to matching/new table rows.
try
    S = ensureFCRowFilesSizeV13(S);
catch
    if ~isfield(S,'fcRowFiles') || numel(S.fcRowFiles) ~= size(S.subj,1)
        S.fcRowFiles = cell(size(S.subj,1),1);
    end
end
if nargin < 2 || ~isfield(FC,'subjects') || isempty(FC.subjects)
    return;
end
for ii = 1:numel(FC.subjects)
    fp = ''; nm = ''; grp = 'Unassigned';
    try, fp = GA_restore_str_20260616(FC.subjects(ii).sourceFile); catch, end
    try, nm = GA_restore_str_20260616(FC.subjects(ii).name); catch, end
    try, grp = GA_restore_str_20260616(FC.subjects(ii).group); catch, end
    if isempty(nm), nm = GA_restore_guess_subject_20260616(fp,'',''); end
    hit = [];
    for r = 1:size(S.subj,1)
        if strcmpi(GA_restore_getrowstr_20260616(S.subj(r,:),2), nm)
            hit = r;
            break;
        end
    end
    if isempty(hit)
        c = 'CondA';
        if ~isempty(strfind(upper(grp),'VEH')) || ~isempty(strfind(upper(grp),'CONTROL')) || ~isempty(strfind(upper(grp),'GROUPB'))
            c = 'CondB';
        end
        if ~isfield(S,'subj') || isempty(S.subj), S.subj = cell(0,9); end
        if size(S.subj,2) < 9, S.subj(:,end+1:9) = {''}; end
        S.subj(end+1,1:9) = {true,nm,grp,c,nm,'','','','OK'};
        S = ensureFCRowFilesSizeV13(S);
        hit = size(S.subj,1);
    end
    S.fcRowFiles{hit,1} = fp;
end
end

function s = GA_restore_getrowstr_20260616(row, col)
s = '';
try
    if iscell(row) && numel(row) >= col
        s = GA_restore_str_20260616(row{col});
    end
catch
    s = '';
end
end

function s = GA_restore_str_20260616(x)
try
    if isempty(x)
        s = '';
    elseif isstring(x)
        s = strtrim(char(x));
    elseif ischar(x)
        s = strtrim(x);
    elseif isnumeric(x) || islogical(x)
        if isscalar(x)
            s = strtrim(num2str(x));
        else
            s = strtrim(mat2str(x));
        end
    else
        s = strtrim(char(x));
    end
catch
    s = '';
end
end

function subj = GA_restore_guess_subject_20260616(varargin)
subj = '';
for ii = 1:nargin
    txt = GA_restore_str_20260616(varargin{ii});
    if isempty(txt), continue; end
    try
        [~,bn,~] = fileparts(txt);
        bn = GA_restore_str_20260616(bn);
        if isempty(bn), continue; end
        bnLow = lower(bn);
        if ~isempty(strfind(bnLow,'groupbundle')) || ~isempty(strfind(bnLow,'fc_groupbundle')) || ~isempty(strfind(bnLow,'scm'))
            % Try parent folder instead for bundle files.
            p = fileparts(txt);
            [~,bn2,~] = fileparts(p);
            if ~isempty(bn2)
                subj = GA_restore_str_20260616(bn2);
                return;
            end
        else
            subj = bn;
            return;
        end
    catch
    end
end
if isempty(subj), subj = 'Unknown'; end
end

function sess = GA_restore_parse_session_20260616(txts)
sess = '';
try
    for ii = 1:numel(txts)
        txt = GA_restore_str_20260616(txts{ii});
        if isempty(txt), continue; end
        tok = regexp(txt,'(?i)(Session[_ -]?0*\d+|Session\d+|S\d+)','match','once');
        if ~isempty(tok)
            sess = tok;
            return;
        end
    end
catch
    sess = '';
end
end

function scan = GA_restore_parse_scan_20260616(txts)
scan = '';
try
    for ii = 1:numel(txts)
        txt = GA_restore_str_20260616(txts{ii});
        if isempty(txt), continue; end
        tok = regexp(txt,'(?i)(scan[_ -]?\d+[A-Za-z0-9_]*|FUS[_ -]?\d+[A-Za-z0-9_]*)','match','once');
        if ~isempty(tok)
            scan = tok;
            return;
        end
    end
catch
    scan = '';
end
end

function [R,Z,labels,names] = GA_restore_fc_matrix_20260616(subj0)
R = []; Z = []; labels = []; names = {};
try
    if isfield(subj0,'labels') && ~isempty(subj0.labels)
        labels = double(subj0.labels(:));
    elseif isfield(subj0,'displayLabels') && ~isempty(subj0.displayLabels)
        labels = double(subj0.displayLabels(:));
    end
catch
end
try
    if isfield(subj0,'R') && ~isempty(subj0.R)
        R = double(subj0.R);
    elseif isfield(subj0,'displayMatrix') && ~isempty(subj0.displayMatrix)
        R = double(subj0.displayMatrix);
    elseif isfield(subj0,'corrMatrix') && ~isempty(subj0.corrMatrix)
        R = double(subj0.corrMatrix);
    elseif isfield(subj0,'matrix') && ~isempty(subj0.matrix)
        R = double(subj0.matrix);
    end
catch
end
try
    if isfield(subj0,'Z') && ~isempty(subj0.Z)
        Z = double(subj0.Z);
    elseif isfield(subj0,'displayZ') && ~isempty(subj0.displayZ)
        Z = double(subj0.displayZ);
    end
catch
end
if isempty(R) && ~isempty(Z)
    R = tanh(Z);
end
if isempty(Z) && ~isempty(R)
    Rclip = max(-0.999999,min(0.999999,double(R)));
    Z = atanh(Rclip);
    try, Z(1:size(Z,1)+1:end) = 0; catch, end
end
if isempty(labels) && ~isempty(R)
    labels = (1:size(R,1))';
end
try
    if isfield(subj0,'names') && ~isempty(subj0.names)
        names = subj0.names(:);
    elseif isfield(subj0,'displayNames') && ~isempty(subj0.displayNames)
        names = subj0.displayNames(:);
    end
catch
    names = {};
end
if isempty(names) && ~isempty(labels)
    names = cell(numel(labels),1);
    for kk = 1:numel(labels)
        names{kk} = sprintf('ROI_%g',labels(kk));
    end
end
end

function g = GA_restore_infer_fc_group_20260616(txt)
g = 'Unassigned';
u = upper(GA_restore_str_20260616(txt));
if ~isempty(strfind(u,'PACAP')) || ~isempty(strfind(u,'GROUPA')) || ~isempty(strfind(u,'CONDA'))
    g = 'PACAP';
elseif ~isempty(strfind(u,'VEH')) || ~isempty(strfind(u,'VEHICLE')) || ~isempty(strfind(u,'CONTROL')) || ~isempty(strfind(u,'PBS')) || ~isempty(strfind(u,'ACSF')) || ~isempty(strfind(u,'GROUPB')) || ~isempty(strfind(u,'CONDB'))
    g = 'Vehicle';
end
end
% GA_RESTORE_MISSING_HELPERS_20260616_END
