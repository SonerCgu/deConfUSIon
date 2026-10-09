function out = fusi_studio_GUI(action)
% fusi_studio_GUI - GUI/source part 1 of the split Studio
%
% This is a valid MATLAB file that stores one source chunk for the split
% deConfUSIon / fUSI Studio. Run run_fusi_studio.m to assemble and launch.

if nargin == 0
    run_fusi_studio;
    if nargout > 0
        out = [];
    end
    return;
end

if ischar(action) && strcmpi(action,'source')
    out = localExtractSource(mfilename('fullpath'));
else
    error('HUMoR:SplitSource','Unknown action. Use run_fusi_studio.m to launch.');
end

end

function txt = localExtractSource(thisFile)
raw = fileread([thisFile '.m']);
startMarker = '%%%FUSI_STUDIO_SOURCE_BEGIN%%%';
endMarker   = '%%%FUSI_STUDIO_SOURCE_END%%%';
a = strfind(raw,startMarker);
b = strfind(raw,endMarker);
if isempty(a) || isempty(b) || b(1) <= a(1)
    error('HUMoR:SplitSource','Could not find embedded source markers in %s.m', thisFile);
end
a = a(end) + length(startMarker);
b = b(end) - 1;
txt = raw(a:b);
% Remove one leading newline after marker if present.
if ~isempty(txt) && (txt(1) == sprintf('\n') || txt(1) == sprintf('\r'))
    txt = regexprep(txt,'^\r?\n','', 'once');
end
end

%{
%%%FUSI_STUDIO_SOURCE_BEGIN%%%
function fusi_studio_runtime
% clc;  % disabled by cleanup - keeps Command Window log

%% =========================================================
%  SECTION A - INTERNAL STATE & GUI CONSTRUCTION - Update
% =========================================================
studio = struct();
studio.datasets = struct();
studio.activeDataset = '';
studio.meta = [];
studio.isLoaded = false;
studio.loadedFile = '';
studio.loadedPath = '';
studio.loadedName = '';
studio.exportPath = '';
studio.atlasTransform = [];
studio.atlasTransformFile = '';

studio.atlasReg2D = [];
studio.atlasReg2DFile = '';
studio.atlasRegistrationMode = '';
studio.allButtons = {};
studio.figure = [];
studio.publicationReady = [];
studio.publicationReadyNote = '';
studio.publicationReadyTime = '';

studio.mask = [];
studio.maskIsInclude = true;
studio.brainMask = [];
studio.brainImageFile = '';
studio.anatomicalReferenceRaw = [];
studio.anatomicalReference = [];
studio.anatomicalReferenceIsDisplayReady = false;
studio.anatomicalReferenceFile = '';

% FC / atlas / registration helper path
studio.registrationPath = '';
studio.registration2DPath = '';
studio.visualizationPath = '';
studio.maskStartPath = '';
studio.underlayStartPath = '';
studio.transformStartPath = '';
studio.lastScmUnderlayInfo = [];

studio.pipeline = struct( ...
    'loadDone', false, ...
    'qcDone', false, ...
    'preprocDone', false, ...
    'pscDone', false, ...
    'visualDone', false);

% =========================================================
%  deConfUSIon MODERN THEME (visual only; callbacks unchanged)
%  Inspired by the presentation GUI: navy canvas + cyan/blue/violet accents.
% =========================================================
theme = struct();
theme.bg            = [0.018 0.055 0.085];
theme.surface       = [0.030 0.085 0.125];
theme.card          = [0.045 0.110 0.155];
theme.cardSoft      = [0.060 0.135 0.185];
theme.button        = [0.075 0.145 0.190];
theme.buttonEnabled = [0.095 0.180 0.235];
theme.input         = [0.035 0.090 0.125];
theme.text          = [0.94 0.98 1.00];
theme.muted         = [0.56 0.68 0.76];
theme.cyan          = [0.00 0.78 0.78];
theme.blue          = [0.18 0.55 0.95];
theme.violet        = [0.52 0.34 0.94];
theme.teal          = [0.05 0.64 0.58];
theme.green         = [0.20 0.72 0.48];
theme.amber         = [0.95 0.62 0.16];
theme.yellow        = [0.95 0.78 0.20];
theme.red           = [0.82 0.28 0.34];
theme.sectionAccent = [ ...
    theme.cyan; ...      % 1 Dataset
    theme.violet; ...    % 2 QC
    theme.green; ...     % 3 Recommended processing
    theme.blue; ...      % 4 Advanced processing
    theme.teal; ...      % 5 Visualization
    [0.16 0.78 0.46]; ... % 6 Coregistration
    theme.amber; ...     % 7 Advanced analysis
    theme.red; ...        % 8 SVD
    theme.yellow; ...     % 9 Velocity
    [0.78 0.42 0.70]];   % 10 Community
studio.theme = theme;


% =========================================================
%  FIGURE WINDOW
% =========================================================
fig = figure( ...
    'Name','deConfUSIon', ...
    'Color',theme.bg, ...
    'Units','normalized', ...
    'Position',[0.18 0 0.64 1], ...
    'MenuBar','none', ...
    'ToolBar','none', ...
    'NumberTitle','off', ...
    'Resize','on', ...
    'CloseRequestFcn',@onCloseStudio);

try
    set(fig,'WindowState','maximized');
catch
end

studio.figure = fig;
setappdata(0,'deConfUSIonMainFigure',fig);
set(fig,'Name',sprintf('deConfUSIon | MATLAB %d',feature('getpid')));
guidata(fig, studio);

% =========================================================
%  TITLE
% =========================================================
uicontrol(fig,'Style','text', ...
    'String','deConfUSIon', ...
    'Units','normalized', ...
    'Position',[0.085 0.954 0.300 0.032], ...
    'FontName','Helvetica', ...
    'FontSize',25, ...
    'FontWeight','bold', ...
    'ForegroundColor',theme.cyan, ...
    'BackgroundColor',theme.bg, ...
    'HorizontalAlignment','left');

uicontrol(fig,'Style','text', ...
    'String','fUSI ANALYSIS STUDIO', ...
    'Units','normalized', ...
    'Position',[0.085 0.932 0.300 0.018], ...
    'FontName','Helvetica', ...
    'FontSize',9, ...
    'FontWeight','bold', ...
    'ForegroundColor',theme.muted, ...
    'BackgroundColor',theme.bg, ...
    'HorizontalAlignment','left');

uipanel('Parent',fig, ...
    'Units','normalized', ...
    'Position',[0.085 0.926 0.220 0.0016], ...
    'BorderType','none', ...
    'BackgroundColor',theme.cyan);

%% =========================================================
%  THREE-COLUMN MAIN LAYOUT
%  Column 1: boxes 1-5
%  Column 2: boxes 6-10
%  Column 3: Studio Log
%  All three columns share the same top and bottom span.
% =========================================================
guiMargin = 0.025;
uicontrol(fig,'Style','pushbutton','Units','normalized','Position',[.400 .946 .200 .028], ...
    'Tag','SaveQueueStatus','String','SAVE QUEUE  |  idle', ...
    'FontName','Arial','FontSize',9,'FontWeight','bold', ...
    'BackgroundColor',theme.card,'ForegroundColor',theme.muted, ...
    'HorizontalAlignment','right','Callback',@(~,~)DataIO('show'), ...
    'TooltipString','Analysis results are saved before completion. Inspect saves or retry a failed write.');
guiGap    = 0.012;
col1X = guiMargin;
col1W = 0.305;
col2X = col1X + col1W + guiGap;
col2W = 0.305;
logX  = col2X + col2W + guiGap;
logW  = 1.0 - logX - guiMargin;
mainY = 0.105;
mainH = 0.825;

col1Panel = uipanel(fig, ...
    'Units','normalized', ...
    'Position',[col1X mainY col1W mainH], ...
    'BackgroundColor',theme.bg, ...
    'BorderType','none');

col2Panel = uipanel(fig, ...
    'Units','normalized', ...
    'Position',[col2X mainY col2W mainH], ...
    'BackgroundColor',theme.bg, ...
    'BorderType','none');

%% =========================================================
%  LOG PANEL
% =========================================================
logPanel = uipanel(fig, ...
    'Title','STUDIO LOG', ...
    'Units','normalized', ...
    'Position',[logX mainY logW mainH], ...
    'BackgroundColor',theme.surface, ...
    'ForegroundColor',theme.cyan, ...
    'FontSize',14, ...
    'FontWeight','bold', ...
    'BorderType','line', ...
    'HighlightColor',theme.cyan, ...
    'ShadowColor',theme.cyan);

activeDatasetText = uicontrol(fig,'Style','text', ...
    'Units','normalized', ...
    'Position',[0.690 0.954 0.205 0.028], ...
    'FontName','Helvetica', ...
    'FontSize',10, ...
    'FontWeight','bold', ...
    'ForegroundColor',theme.green, ...
    'BackgroundColor',theme.bg, ...
    'HorizontalAlignment','right', ...
    'String','DATASET  /  none', ...
    'TooltipString','DATASET: none');

studio = guidata(fig);
studio.activeDatasetText = activeDatasetText;
guidata(fig, studio);

addTopLeftBrandIcon();
addStudioIcon();

jLog = [];
hLogContainer = [];

try
    useJavaLog = usejava('jvm') && exist('javaObjectEDT','file') && exist('javacomponent','file');
catch
    useJavaLog = false;
end

if useJavaLog
    try
        jLog = javaObjectEDT('javax.swing.JTextArea');
        jLog.setEditable(false);
        jLog.setLineWrap(true);
        jLog.setWrapStyleWord(true);
        jLog.setFont(java.awt.Font('Monospaced', java.awt.Font.PLAIN, 20));
        jLog.setBackground(studioJavaColor(theme.input(1),theme.input(2),theme.input(3)));
        jLog.setForeground(studioJavaColor(0.66,0.86,0.94));
        jLog.setText('');

        jScroll = javaObjectEDT('javax.swing.JScrollPane', jLog);
        warnState = warning('off','all');
        try
            [~, hLogContainer] = javacomponent(jScroll, [1 1 1 1], logPanel);
            warning(warnState);
        catch MEjavaComponent
            warning(warnState);
            rethrow(MEjavaComponent);
        end

        set(hLogContainer, 'Units','normalized', 'Position',[0.02 0.02 0.96 0.95]);
    catch
        jLog = [];
        hLogContainer = [];
    end
end

if isempty(hLogContainer) || ~ishghandle(hLogContainer)
    hLogContainer = uicontrol(logPanel, ...
        'Style','listbox', ...
        'Units','normalized', ...
        'Position',[0.02 0.02 0.96 0.95], ...
        'BackgroundColor',theme.input, ...
        'ForegroundColor',[0.66 0.86 0.94], ...
        'FontName','Monospaced', ...
        'FontSize',16, ...
        'String',{''}, ...
        'Max',2, ...
        'Min',0);
end

studio = guidata(fig);
studio.logBox = hLogContainer;
studio.logBoxJava = jLog;
guidata(fig, studio);

addLog('fUSI Studio initialized.');

%% =========================================================
%  SECTION DEFINITIONS
% =========================================================
sectionHeights = repmat(0.190, 1, 10);  % all boxes have the same height in both columns

sectionParents = { ...
    col1Panel, ...
    col1Panel, ...
    col1Panel, ...
    col1Panel, ...
    col1Panel, ...
    col2Panel, ...
    col2Panel, ...
    col2Panel, ...
    col2Panel, ...
    col2Panel};

titles = { ...
    '1. Dataset', ...
    '2. QC & Data Overview', ...
    '3. Recommended Processing', ...
    '4. Advanced Processing', ...
    '5. Visualization', ...
    '6. Coregistration', ...
    '7. Advanced Analysis', ...
    '8. SVD / Clutter Filtering', ...
    '9. Velocity Analysis', ...
    '10. Community Analysis'};

buttons = { ...
    {'Load fUSI Data'}, ...
    {'Full QC','Specific QC'}, ...
    {'Motion correction','Imregdemons','Chop data','Motor'}, ...
    {'Temporal Interpolation','Filtering','PCA / ICA','Drift Compensation'}, ...
    {'Time-Course Viewer','SCM GUI','Video GUI','Mask Editor'}, ...
    {'Registration to Atlas','Segmentation'}, ...
    {'Functional connectivity','Group analysis'}, ...
    {'SVD / Clutter Filtering'}, ...
    {'Velocity Maps','Flow / Velocity QC'}, ...
    {'Standardized Analysis','Placeholder Community B'}};

%% =========================================================
%  SECTION RENDERING LOOP
% =========================================================
gapBetweenSections = 0.007;
parentsForLayout = {col1Panel, col2Panel};

for pp = 1:numel(parentsForLayout)
    parentPanel = parentsForLayout{pp};
    y = 0.996;

    if pp == 1
        idxList = 1:5;
    else
        idxList = 6:10;
    end

    for jj = 1:numel(idxList)
        i = idxList(jj);
        h = sectionHeights(i);
        y = y - h;

        accent = theme.sectionAccent(i,:);
        panel = uipanel(parentPanel, ...
            'Title','', ...
            'Units','normalized', ...
            'Position',[0.015 y 0.970 h], ...
            'BackgroundColor',theme.bg, ...
            'ForegroundColor',accent, ...
            'FontName','Helvetica', ...
            'FontSize',16, ...
            'FontWeight','bold', ...
            'BorderType','none');

        addRoundedCard(panel, accent);
        drawSectionHeader(panel, titles{i}, i, accent);
        drawButtons(panel, buttons{i}, i);
        y = y - gapBetweenSections;
    end
end

%% =========================================================
%  STATUS BAR
% =========================================================
statusPanel = uipanel(fig, ...
    'Units','normalized', ...
    'Position',[col1X 0.04 (col2X + col2W - col1X) 0.055], ...
    'BackgroundColor',theme.card, ...
    'BorderType','line', ...
    'HighlightColor',theme.cyan, ...
    'ShadowColor',theme.cyan);

statusText = uicontrol(statusPanel,'Style','text', ...
    'Units','normalized', ...
    'Position',[0 0 1 1], ...
    'BackgroundColor',theme.card, ...
    'ForegroundColor',theme.text, ...
    'FontName','Helvetica', ...
    'FontWeight','bold', ...
    'FontSize',16, ...
    'HorizontalAlignment','center');

studio = guidata(fig);
studio.statusPanel = statusPanel;
studio.statusText = statusText;
guidata(fig, studio);

setProgramStatus(false);

% =========================================================
%  BOTTOM HELP/CLOSE/EXPORT SESSION BUTTONS
% =========================================================
btnY = 0.040;
btnH = 0.052;
btnGap = 0.007;
btnW = (logW - 3*btnGap) / 4;

bottomLabels = {'HELP', 'EXPORT LOG', 'PUB READY', 'CLOSE'};
bottomCallbacks = {@helpCallback, @exportSessionCallback, @markPublicationReadyCallback, @(s,e) close(fig)};
bottomColors = [ ...
    theme.blue; ...
    theme.teal; ...
    theme.violet; ...
    theme.red];

footerStyles = {'footerBlue','footerTeal','footerViolet','footerRed'};
for bb = 1:4
    createModernButton(fig, bottomLabels{bb}, ...
        [logX + (bb-1)*(btnW+btnGap) btnY btnW btnH], ...
        bottomCallbacks{bb}, true, footerStyles{bb});
end

%% =========================================================
%  FOOTER LABEL
% =========================================================
studio = guidata(fig);

footerText = uicontrol(fig,'Style','text', ...
    'Units','normalized', ...
    'Position',[logX 0.006 logW 0.024], ...
    'BackgroundColor',theme.bg, ...
    'ForegroundColor',theme.muted, ...
    'FontName','Helvetica', ...
    'FontSize',10, ...
    'FontWeight','normal', ...
    'HorizontalAlignment','right', ...
    'String', deConfUSIon_utils('buildFooterLabel'));

studio.footerText = footerText;
guidata(fig, studio);

% Apply the shared palette after all controls exist so the launcher and its
% child GUIs use one readable font, contrast system, and Help behavior.
setappdata(fig,'deConfUSIonOwned',true);
try, deConfUSIon_ui('style',fig); catch, end

%% =========================================================
%  SECTION HEADER / ICONS / MODERN ROUNDED UI
% =========================================================
function drawSectionHeader(parent, titleStr, sectionIndex, accent)

    iconNames = {'dataset','qc','recommended','advanced','visualization', ...
                 'coreg','analysis','svd','velocity','community'};

    % Header axis avoids rectangular text-label backgrounds.
    hAx = axes('Parent',parent, ...
        'Units','normalized', ...
        'Position',[0 0.705 1 0.285], ...
        'XLim',[0 1], 'YLim',[0 1], ...
        'Visible','off', ...
        'Color','none', ...
        'HitTest','off', ...
        'HandleVisibility','off');

    text(hAx,0.53,0.68,titleStr, ...
        'FontName','Helvetica', ...
        'FontSize',15, ...
        'FontWeight','bold', ...
        'Color',theme.text, ...
        'HorizontalAlignment','center', ...
        'VerticalAlignment','middle', ...
        'Interpreter','none', ...
        'HitTest','off');

    line(hAx,[0.13 0.93],[0.18 0.18], ...
        'Color',accent, ...
        'LineWidth',1.8, ...
        'HitTest','off');

    iconFile = '';
    if sectionIndex >= 1 && sectionIndex <= numel(iconNames)
        iconFile = localThemeIconPath(iconNames{sectionIndex});
    end

    if ~isempty(iconFile) && exist(iconFile,'file') == 2
        addPanelPng(parent, iconFile, [0.020 0.745 0.078 0.175], theme.surface, accent);
    end
end

function addRoundedCard(parent, accent)
    % Vector card: crisp at every screen resolution and no PNG scaling cost.
    ax = axes('Parent',parent, ...
        'Units','normalized', ...
        'Position',[0 0 1 1], ...
        'XLim',[0 1], 'YLim',[0 1], ...
        'Visible','off', ...
        'Color','none', ...
        'HitTest','off', ...
        'HandleVisibility','off');

    % Soft shadow.
    rectangle(ax,'Position',[0.016 0.010 0.968 0.952], ...
        'Curvature',[0.055 0.22], ...
        'FaceColor',[0.008 0.018 0.028], ...
        'EdgeColor','none', ...
        'HitTest','off');

    edge = 0.36*accent + 0.64*[0.16 0.24 0.32];
    rectangle(ax,'Position',[0.008 0.030 0.984 0.952], ...
        'Curvature',[0.055 0.22], ...
        'FaceColor',theme.surface, ...
        'EdgeColor',edge, ...
        'LineWidth',1.35, ...
        'HitTest','off');

    try, uistack(ax,'bottom'); catch, end
end

function hBtn = createModernButton(parent,label,pos,callback,isEnabled,styleKey)
    if nargin < 6 || isempty(styleKey), styleKey = 'regular'; end
    if nargin < 5 || isempty(isEnabled), isEnabled = true; end

    hBtn = axes('Parent',parent, ...
        'Units','normalized', ...
        'Position',pos, ...
        'XLim',[0 1], 'YLim',[0 1], ...
        'Visible','off', ...
        'Color','none', ...
        'Tag','dcModernButton', ...
        'HandleVisibility','callback');

    [fillC,edgeC,textC] = modernButtonColors(styleKey,isEnabled);

    hShadow = rectangle(hBtn,'Position',[0.025 0.035 0.95 0.84], ...
        'Curvature',[0.12 0.42], ...
        'FaceColor',[0.015 0.025 0.035], ...
        'EdgeColor','none');

    hRect = rectangle(hBtn,'Position',[0.012 0.085 0.976 0.84], ...
        'Curvature',[0.12 0.42], ...
        'FaceColor',fillC, ...
        'EdgeColor',edgeC, ...
        'LineWidth',1.35);

    % Thin highlight at the top gives a softer PPT-like button surface.
    hHi = line(hBtn,[0.09 0.91],[0.865 0.865], ...
        'Color',min(1,edgeC + 0.12), ...
        'LineWidth',0.8);

    fontSz = 12;
    if numel(label) > 24
        fontSz = 10;
    elseif numel(label) > 18
        fontSz = 11;
    end
    if strncmpi(styleKey,'footer',6)
        fontSz = 10;
    end

    hTxt = text(hBtn,0.5,0.505,label, ...
        'FontName','Helvetica', ...
        'FontSize',fontSz, ...
        'FontWeight','bold', ...
        'Color',textC, ...
        'HorizontalAlignment','center', ...
        'VerticalAlignment','middle', ...
        'Interpreter','none');

    ud = struct('callback',callback, ...
                'enabled',logical(isEnabled), ...
                'styleKey',styleKey, ...
                'rect',hRect, ...
                'shadow',hShadow, ...
                'highlight',hHi, ...
                'text',hTxt);
    set(hBtn,'UserData',ud);

    cb = @(~,~) modernButtonClick(hBtn);
    set(hBtn,'ButtonDownFcn',cb);
    set(hRect,'ButtonDownFcn',cb,'HitTest','on');
    set(hShadow,'ButtonDownFcn',cb,'HitTest','on');
    set(hHi,'ButtonDownFcn',cb,'HitTest','on');
    set(hTxt,'ButtonDownFcn',cb,'HitTest','on');
    set([hBtn hRect hShadow hHi hTxt],'BusyAction','cancel');
end

function modernButtonClick(hBtn)
    if isempty(hBtn) || ~ishghandle(hBtn), return; end
    ud = get(hBtn,'UserData');
    if isempty(ud) || ~isstruct(ud) || ~isfield(ud,'enabled') || ~ud.enabled
        return;
    end
    if isequal(getappdata(fig,'StudioActionBusy'),true), return; end
    setappdata(fig,'StudioActionBusy',true);
    dd=findobj(fig,'Tag','datasetDropdown');
    if ~isempty(dd), set(dd,'Enable','off','BusyAction','cancel'); end
    guard=onCleanup(@finishStudioAction); %#ok<NASGU>
    try
        feval(ud.callback,hBtn,[]);
    catch ME
        if isgraphics(fig)
            setappdata(fig,'StudioLastCallbackError',ME);
            state=guidata(fig); color=[0.36 0.12 0.38];
            if isstruct(state) && isfield(state,'statusPanel') && isgraphics(state.statusPanel)
                set(state.statusPanel,'BackgroundColor',color,'HighlightColor',color,'ShadowColor',color);
                set(state.statusText,'String','!!! ACTION CRASHED !!!','BackgroundColor',color, ...
                    'ForegroundColor',[1 1 1],'TooltipString',ME.message);
            end
            addLog(['ACTION ERROR: ' ME.message]);
            errordlg(sprintf('%s\n\nThe action stopped. Your session is still open; correct the settings and retry.',ME.message),'Action failed');
        end
        warning('deConfUSIon:CallbackFailed','%s',getReport(ME,'extended','hyperlinks','off'));
    end
end

function finishStudioAction()
    if ~isgraphics(fig), return; end
    % Consume pending clicks while the guard is still set, not after unlock.
    drawnow;
    if ~isgraphics(fig), return; end
    setappdata(fig,'StudioActionBusy',false);
    dd=findobj(fig,'Tag','datasetDropdown');
    if ~isempty(dd), set(dd,'Enable','on'); end
end

function setModernButtonEnabled(hBtn,tf)
    if isempty(hBtn) || ~ishghandle(hBtn), return; end
    ud = get(hBtn,'UserData');
    if isempty(ud) || ~isstruct(ud), return; end
    ud.enabled = logical(tf);
    [fillC,edgeC,textC] = modernButtonColors(ud.styleKey,ud.enabled);
    try, set(ud.rect,'FaceColor',fillC,'EdgeColor',edgeC); catch, end
    try, set(ud.text,'Color',textC); catch, end
    try, set(ud.highlight,'Color',min(1,edgeC + 0.12)); catch, end
    set(hBtn,'UserData',ud);
end

function [fillC,edgeC,textC] = modernButtonColors(styleKey,isEnabled)
    switch lower(styleKey)
        case 'primary'
            fillC = [0.040 0.47 0.48];
            edgeC = theme.cyan;
            textC = [0.96 1.00 1.00];
        case 'footerblue'
            fillC = [0.16 0.42 0.82]; edgeC = [0.35 0.60 1.00]; textC = [1 1 1];
        case 'footerteal'
            fillC = [0.04 0.55 0.50]; edgeC = [0.20 0.80 0.72]; textC = [1 1 1];
        case 'footerviolet'
            fillC = [0.43 0.28 0.78]; edgeC = [0.65 0.48 1.00]; textC = [1 1 1];
        case 'footerred'
            fillC = [0.66 0.22 0.25]; edgeC = [0.90 0.38 0.40]; textC = [1 1 1];
        otherwise
            if strncmpi(styleKey,'section',7)
                sectionNumber = str2double(styleKey(8:end));
                if isfinite(sectionNumber) && sectionNumber >= 1 && ...
                        sectionNumber <= size(theme.sectionAccent,1)
                    accent = theme.sectionAccent(sectionNumber,:);
                    fillC = 0.34*accent + 0.66*theme.button;
                    edgeC = min(1,0.72*accent + 0.28*[0.38 0.45 0.54]);
                    textC = [0.96 0.985 1.00];
                    if ~isEnabled
                        fillC = 0.55*fillC + 0.45*theme.bg;
                        edgeC = 0.55*edgeC + 0.45*[0.18 0.24 0.30];
                        textC = [0.54 0.63 0.70];
                    end
                    return;
                end
            end
            if isEnabled
                fillC = [0.105 0.165 0.225];
                edgeC = [0.34 0.43 0.53];
                textC = [0.94 0.97 1.00];
            else
                fillC = [0.070 0.105 0.140];
                edgeC = [0.20 0.27 0.34];
                textC = [0.50 0.58 0.65];
            end
    end
end

function addTopLeftBrandIcon()
    iconFile = localThemeIconPath('brand_left_ppt');
    if isempty(iconFile) || exist(iconFile,'file') ~= 2, return; end
    addPanelPng(fig, iconFile, [0.014 0.922 0.061 0.068], theme.bg);
end

function iconFile = localThemeIconPath(iconName)
    iconFile = '';
    try
        candRoots = {};
        w = which('run_fusi_studio');
        if ~isempty(w), candRoots{end+1} = fileparts(w); end
        w = which('fusi_studio_GUI');
        if ~isempty(w), candRoots{end+1} = fileparts(w); end
        candRoots{end+1} = pwd;
        for cc = 1:numel(candRoots)
            f2 = fullfile(candRoots{cc}, 'theme_icons', [iconName '.png']);
            if exist(f2,'file') == 2
                iconFile = f2;
                return;
            end
        end
    catch
    end
end

function addPanelPng(parent, pngFile, pos, bgColor, tint)
    try
        [img,map,alpha] = imread(pngFile);
        if ~isempty(map)
            img = im2uint8(ind2rgb(img,map));
        elseif ndims(img) == 2
            img = repmat(img,[1 1 3]);
        end
        if isempty(alpha)
            alpha = 255 * ones(size(img,1), size(img,2), 'uint8');
        end

        ax = axes('Parent', parent, ...
            'Units','normalized', ...
            'Position',pos, ...
            'Visible','off', ...
            'Color',bgColor, ...
            'XColor',bgColor, ...
            'YColor',bgColor, ...
            'HitTest','off', ...
            'HandleVisibility','off');

        if nargin>=5
            % Tint the glyph while retaining the original anti-aliased alpha.
            img=repmat(reshape(uint8(255*tint),1,1,3),size(img,1),size(img,2));
        end
        hImg = image('Parent',ax,'CData',img,'HitTest','off');
        set(ax,'YDir','reverse');
        xlim(ax,[0.5 size(img,2)+0.5]);
        ylim(ax,[0.5 size(img,1)+0.5]);
        axis(ax,'image');
        axis(ax,'off');

        alpha = double(alpha);
        if max(alpha(:)) > 1, alpha = alpha ./ 255; end
        set(hImg,'AlphaData',alpha);
    catch
    end
end

%% =========================================================
%  BUTTON DRAWING
% =========================================================
function drawButtons(parent, btns, sectionIndex)

    studio = guidata(fig);
    n = length(btns);

    if sectionIndex == 1 && n == 1 && strcmp(btns{1},'Load fUSI Data')
        loadBtn = createModernButton(parent,'Load fUSI Data', ...
            [0.045 0.20 0.340 0.36], @loadDataCallback, true, 'primary');
        studio.allButtons{end+1} = loadBtn;

        uicontrol(parent, ...
            'Style','popupmenu', ...
            'String',{'Select dataset'}, ...
            'Units','normalized', ...
            'Position',[0.420 0.215 0.535 0.33], ...
            'BackgroundColor',theme.input, ...
            'ForegroundColor',theme.text, ...
            'FontName','Helvetica', ...
            'FontSize',12, ...
            'FontWeight','bold', ...
            'Callback',@datasetDropdownCallback, ...
            'Tag','datasetDropdown', ...
            'UserData',{{}}, ...
            'TooltipString','Select active dataset');

        guidata(fig, studio);
        return;
    end

    if n == 2
        positions = [ ...
            0.08 0.205 0.38 0.34; ...
            0.54 0.205 0.38 0.34];
    elseif n == 4
        positions = [ ...
            0.08 0.43 0.38 0.20; ...
            0.54 0.43 0.38 0.20; ...
            0.08 0.15 0.38 0.20; ...
            0.54 0.15 0.38 0.20];
    elseif n == 5
        positions = [ ...
            0.08 0.49 0.38 0.17; ...
            0.54 0.49 0.38 0.17; ...
            0.08 0.285 0.38 0.17; ...
            0.54 0.285 0.38 0.17; ...
            0.08 0.08 0.84 0.17];
    elseif n == 6
        positions = [ ...
            0.08 0.49 0.38 0.17; ...
            0.54 0.49 0.38 0.17; ...
            0.08 0.285 0.38 0.17; ...
            0.54 0.285 0.38 0.17; ...
            0.08 0.08 0.38 0.17; ...
            0.54 0.08 0.38 0.17];
    else
        positions = zeros(n,4);
        for kk = 1:n
            positions(kk,:) = [0.14 0.20 0.72 0.32];
        end
    end

    for k = 1:n
        label = btns{k};
        callback = @dummyNotImplemented;
        labelKey = lower(regexprep(strtrim(label),'\s+',' '));

        switch labelKey
            case 'full qc'
                callback = @runFullQCCallback;
            case 'specific qc'
                callback = @runSpecificQCCallback;
            case 'motion correction'
                callback = @motionCorrectionCallback;
            case 'chop data'
                callback = @chopDataCallback;
            case 'frame rejection'
                callback = @frameRateCallback;
            case 'subsampling'
                callback = @imregdemonsCallback;
            case 'imregdemons'
                callback = @imregdemonsCallback;
            case 'scrubbing'
                callback = @scrubbingCallback;
            case 'motor'
                callback = @stepMotorCallback;
            case 'temporal interpolation'
                callback = @temporalSmoothingCallback;
            case 'temporal smoothing/subsampling'
                callback = @temporalSmoothingCallback;
            case 'temporal smoothing'
                callback = @temporalSmoothingCallback;
            case 'filtering'
                callback = @filteringCallback;
            case {'pca','pca / ica'}
                callback = @pcaCallback;
            case 'despike'
                callback = @despikeCallback;
            case {'drift compensation','driftcompensation','drift correction'}
                callback = @driftCompensationCallback;
            case 'time-course viewer'
                callback = @liveViewerCallback;
            case {'scm','scm gui'}
                callback = @scmCallback;
            case {'video & scm mask','video gui'}
                callback = @videoGUICallback;
            case 'mask editor'
                callback = @maskEditorCallback;
            case 'registration to atlas'
                callback = @coregCallback;
            case 'segmentation'
                callback = @segmentationCallback;
            case 'standardized analysis'
                callback = @(src,evt) standardizedAnalysis(fig);
            case 'functional connectivity'
                callback = @functionalConnectivityCallback;
            case 'group analysis'
                callback = @groupAnalysisCallback;
            case {'svd / clutter filtering','svd clutter filtering','svd / clutter filter'}
                callback = @svdClutterCallback;
        end

        % Tie each launcher button to the accent of its containing box. The
        % colors are deliberately darkened so the main Studio remains calm
        % while the section identity is still obvious at a glance.
        btnStyle = sprintf('section%d',sectionIndex);
        btn = createModernButton(parent,label,positions(k,:),callback,false,btnStyle);
        studio.allButtons{end+1} = btn;
        guidata(fig, studio);
    end
end

%% =========================================================
%  DUMMY PLACEHOLDER
% =========================================================
function dummyNotImplemented(~,~)
    addLog('This module is not implemented yet.');
end

function motionCorrectionCallback(~,~)
    studio=guidata(fig);
    if ~studio.isLoaded, errordlg('Load data first.'); return; end
    % These former toolbar actions now share the Motion correction button.
    % A workflow already selects the method; keep its original settings UI
    % where needed instead of asking the user to select a different method.
    if isappdata(fig,'deconf_std_workflow_step')
        step=getappdata(fig,'deconf_std_workflow_step');
        if isstruct(step) && isfield(step,'name')
            switch lower(strtrim(step.name))
                case 'frame rejection', frameRateCallback([],[]); return;
                case 'scrubbing', scrubbingCallback([],[]); return;
                case 'despike', despikeCallback([],[]); return;
            end
        end
    end
    cfg=Motion('choose',fig);
    if isempty(cfg), return; end
    setappdata(fig,'motionCorrectionConfig',cfg);
    cleanupCfg=onCleanup(@()clearMotionConfig()); %#ok<NASGU>
    switch cfg.method
        case 'Frame rejection', frameRateCallback([],[]);
        case 'Despiking', despikeCallback([],[]);
        case 'Scrubbing', scrubbingCallback([],[]);
    end
end

function clearMotionConfig()
    try, if isappdata(fig,'motionCorrectionConfig'), rmappdata(fig,'motionCorrectionConfig'); end, catch, end
end

function chopDataCallback(~,~)
    studio=guidata(fig);
    if ~studio.isLoaded, errordlg('Load data first.'); return; end
    cfg=Motion('chopdialog',fig); if isempty(cfg), return; end
    try
        data=getActiveData(); [newData,~]=Motion('chop',data,cfg(1),cfg(2));
        suffix=sprintf('_cut_%gs_start_%gs_end_%s',cfg(1),cfg(2),datestr(now,'yyyymmdd_HHMMSS'));
        suffix=strrep(suffix,'.','p');
        fullName=[getCurrentNamingStem(studio) suffix];
        keyName=makeSafeKey(fullName,studio.datasets);
        newData.displayNameFull=fullName; newData.preprocDisplayName=fullName;
        newData.HUMOR_fullDisplayName=fullName; newData.datasetSortTime=now;
        newData.sourceDatasetKey=studio.activeDataset; newData.isLazy=false;
        savePath=deConfUSIon_safe_preproc_save_path(fullfile(studio.exportPath,'Preprocessing'),fullName,keyName,'cut');
        newData.savedFile=savePath; newData.lazyFile=savePath;
        payload=struct('newData',newData,'displayNameFull',fullName,'preprocDisplayName',fullName,'datasetSortTime',newData.datasetSortTime);
        DataIO('save',savePath,payload);
        studio.datasets.(keyName)=newData; studio.activeDataset=keyName;
        studio.pipeline.preprocDone=true; guidata(fig,studio); refreshDatasetDropdown();
        addLog(['Cut dataset saved: ' fullName]);
    catch ME, errordlg(ME.message,'Chop data'); addLog(['Chop data failed: ' ME.message]); end
end

%% =========================================================
%  LOAD DATA CALLBACK
% =========================================================
function loadDataCallback(~,~)

    if isappdata(fig,'LoadInProgress')
        busy = false;
        try, busy = logical(getappdata(fig,'LoadInProgress')); catch, end
        if busy
            try, addLog('Load already in progress; please wait for the current import to finish.'); catch, end
            return;
        end
    end
    setappdata(fig,'LoadInProgress',true);
    previousStudio=fusiRebaseMovedStudioFiles(guidata(fig));
    setappdata(fig,'LoadTransaction',struct('previousStudio',previousStudio,'committed',false));
    % finishLoad is a sibling callback, not nested in this callback. MATLAB
    % destroys nested local variables before invoking some onCleanup paths.
    loadGuard=onCleanup(@finishLoad); %#ok<NASGU>
    studio = previousStudio;

    startPath = studio_default_load_start_path(studio);

    [file,path] = uigetfile( ...
        {'*.mat;*.nii;*.nii.gz','fUSI / fMRI data (*.mat, *.nii, *.nii.gz)'}, ...
        'Select fUSI / fMRI time-series dataset', startPath);

    if isequal(file,0)
        addLog('Load cancelled.');
        return;
    end

    % Load means Raw dataset import. Spatial summaries must not divert it to
    % a viewer or be interpreted as temporal samples.
    try
        selectedFile=studioRequireTimeSeriesFile(fullfile(path,file));
        if isempty(selectedFile), addLog('Load cancelled.'); return; end
        [path,stem,ext]=fileparts(selectedFile); path=[path filesep]; file=[stem ext];
    catch ME
        errordlg(ME.message,'Load dataset'); return;
    end

    % Finish saving the previous animal before its in-memory state is replaced.
    % If the drive is unavailable, leave that session intact for Save queue Retry.
    try
        DataIO('flushstudio',previousStudio);
    catch ME
        addLog(['Previous analysis is not saved: ' ME.message]);
        DataIO('show');
        errordlg(ME.message,'Finish saving before loading another animal');
        return;
    end

    addLog('Loading dataset...');
    setProgramStatus(false);
    drawnow;

    studio.datasets = struct();
    studio.activeDataset = '';
    studio.meta = [];
    studio.isLoaded = false;
    studio.loadedFile = '';
    studio.loadedPath = '';
    studio.loadedName = '';
    studio.exportPath = '';
    studio.publicationReady = [];
    studio.publicationReadyNote = '';
    studio.publicationReadyTime = '';
   studio.atlasTransform = [];
studio.atlasTransformFile = '';

studio.atlasReg2D = [];
studio.atlasReg2DFile = '';
studio.atlasRegistrationMode = '';

% Important: avoid stale mask-editor underlay/mask from previous animal
studio.mask = [];
studio.maskIsInclude = true;
studio.brainMask = [];
studio.underlayMask = [];
studio.overlayMask = [];
studio.signalMask = [];
studio.loadedMask = [];
studio.activeMask = [];
studio.loadedMaskIsInclude = true;
studio.overlayMaskIsInclude = true;
studio.maskEditorDraft = [];
studio.brainImageFile = '';
studio.anatomicalReferenceRaw = [];
studio.anatomicalReference = [];
studio.anatomicalReferenceIsDisplayReady = false;
studio.anatomicalReferenceFile = '';
studio.registrationPath = '';
studio.pipeline = struct( ...
        'loadDone', false, ...
        'qcDone', false, ...
        'preprocDone', false, ...
        'pscDone', false, ...
        'visualDone', false);

    % Publish the cleared in-progress state before reading the replacement
    % file. Otherwise the later refresh can retrieve the old guidata object
    % and re-add the previous animal's preprocessing entries to the new
    % dataset dropdown. finishLoad restores previousStudio on cancellation
    % or failure.
    guidata(fig,studio);
    refreshDatasetDropdown();

    try
    fullInputFile = fullfile(path,file);
    [data, meta] = loadFUSIData(fullInputFile, []);

    [probeType, defaultTR] = detectProbeTypeFromMeta(data, meta);
    defaultTR = studio_probe_default_tr_seconds(probeType, data);
    % Keep the probe-specific default as a fallback; the load-options dialog
    % starts in Custom TR mode so the user can confirm or replace it.
    chosenTR = defaultTR;
    [fileTRCandidate, fileTRSource] = studio_get_file_tr_candidate(data, meta);
    if isfield(meta,'rawMetadata') && isfield(meta.rawMetadata,'nifti') && ...
            ~isempty(fileTRCandidate) && isfinite(fileTRCandidate) && fileTRCandidate>0
        chosenTR=fileTRCandidate;
    end
    try
        if ~isfield(meta,'rawMetadata') || isempty(meta.rawMetadata)
            meta.rawMetadata = struct();
        end
        meta.rawMetadata.TRPreselectedSource = 'probe-specific default';
        if ~isempty(fileTRCandidate) && isfinite(fileTRCandidate) && fileTRCandidate > 0
            meta.rawMetadata.fileTRCandidateSec = fileTRCandidate;
            meta.rawMetadata.fileTRCandidateSource = fileTRSource;
        end
    catch
    end
    data.TR = chosenTR;
    data.nVols = size(data.I, ndims(data.I));
    data.TotalTimeSec = data.nVols * data.TR;
    data.TotalTimeMin = data.TotalTimeSec / 60;
    data.totalTime = data.TotalTimeSec;
    data.totalTimeMin = data.TotalTimeMin;

    if ~isfield(meta,'rawMetadata') || isempty(meta.rawMetadata)
        meta.rawMetadata = struct();
    end
    meta.rawMetadata.probeTypeUserConfirmed = probeType;
    meta.rawMetadata.defaultTRUserPromptSec = defaultTR;
    meta.rawMetadata.selectedTRUserSec = chosenTR;

        resolvedPaths=fusiResolveAnalysisFolder(fullInputFile);
        analysedRoot=resolvedPaths.analysedRoot;
        datasetName=resolvedPaths.datasetName;
        datasetFolder=resolvedPaths.datasetFolder;
        rawFileInfo=dir(fullInputFile);data.datasetSortTime=rawFileInfo.datenum;
        deConfUSIon_utils('studio_mkdir',analysedRoot);

        if ~exist('TR','var') || isempty(TR) || ~isnumeric(TR) || ~isfinite(TR) || TR <= 0
            TR = studio_get_last_tr_default();
        end
        [chosenTR, datasetFolder, outputWasCancelled, probeType, defaultTR] = studio_load_options_dark_dialog(chosenTR, datasetFolder, analysedRoot, datasetName, probeType, defaultTR, data, meta, fullInputFile);
        if outputWasCancelled
            addLog('Load cancelled in setup. Previous dataset preserved.');
            return;
        end

        % A user override changes the analysis grid, never acquired samples.
        if isfield(data,'tsec'), data.sourceTsec=data.tsec; end
        if isempty(fileTRCandidate) || abs(chosenTR-fileTRCandidate)>max(1e-9,fileTRCandidate*1e-6)
            data.tsec=(0:data.nVols-1)*chosenTR;
            data.timingUserOverride=true;
        end
        data.TR = chosenTR;
        data.sampleSpanSec=(data.nVols-1)*chosenTR;
        data.nVols = size(data.I, ndims(data.I));
        data.TotalTimeSec = data.nVols * data.TR;
        data.TotalTimeMin = data.TotalTimeSec / 60;
        data.totalTime = data.TotalTimeSec;
        data.totalTimeMin = data.TotalTimeMin;

        [data,~]=deConfUSIon_signal('timing',data);

        if ~isfield(meta,'rawMetadata') || isempty(meta.rawMetadata)
            meta.rawMetadata = struct();
        end
        meta.rawMetadata.probeTypeUserConfirmed = probeType;
        meta.rawMetadata.defaultTRUserPromptSec = defaultTR;
        meta.rawMetadata.selectedTRUserSec = chosenTR;

        deConfUSIon_utils('studio_mkdir',datasetFolder);

        parTmp = struct();
        parTmp.activeDataset = 'raw';
        parTmp.loadedName = datasetName;
        parTmp.loadedFile = fullInputFile;
        parTmp.loadedPath = path;
        parTmp.exportPath = datasetFolder;

        P = studio_resolve_paths(parTmp, datasetName, datasetFolder);

       qcFolder  = fullfile(datasetFolder,'QC');
preFolder = fullfile(datasetFolder,'Preprocessing');
visFolder = fullfile(datasetFolder,'Visualization');
regFolder = fullfile(datasetFolder,'Registration');
reg2DFolder = fullfile(datasetFolder,'Registration2D');
pscFolder = fullfile(datasetFolder,'PSC');

folders = {qcFolder, preFolder, visFolder, regFolder, reg2DFolder, pscFolder};
for kk = 1:numel(folders)
    if ~exist(folders{kk},'dir')
        mkdir(folders{kk});
    end
end

        studio = guidata(fig);

       data.displayNameFull = deConfUSIon_utils('deConfUSIon_make_loaded_display_name',datasetName, path, file);
        data.sourceFileName = file;
        data.sourcePath = path;

        studio.datasets.raw = data;
        studio.activeDataset = 'raw';
        studio.meta = meta;
        % Keep physical in-plane spacing available to every viewer/editor.
        % This is especially important for matrix probes, where pixel spacing
        % differs between the DV and LR axes.
        if isfield(data,'voxelSize') && ~isempty(data.voxelSize)
            studio.voxelSize = data.voxelSize;
        elseif isstruct(meta) && isfield(meta,'voxelSize') && ~isempty(meta.voxelSize)
            studio.voxelSize = meta.voxelSize;
        else
            studio.voxelSize = [];
        end
        studio.isLoaded = true;
        studio.loadedFile = file;
        studio.loadedPath = path;
        studio.loadedName = datasetName;
        studio.exportPath = datasetFolder;
        studio.pipeline.loadDone = true;
     studio.registrationPath = regFolder;
studio.registration2DPath = reg2DFolder;
studio.visualizationPath = visFolder;

% Preferred picker start folders
studio.maskStartPath = visFolder;
studio.underlayStartPath = reg2DFolder;
studio.transformStartPath = reg2DFolder;
if isempty(studio.meta) || ~isstruct(studio.meta)
    studio.meta = struct();
end

studio.meta.exportPath = datasetFolder;
studio.meta.savePath   = datasetFolder;
studio.meta.outPath    = datasetFolder;
studio.meta.loadedPath = path;
studio.meta.loadedFile = fullInputFile;
studio.meta.registrationPath = regFolder;
studio.meta.registration2DPath = reg2DFolder;
studio.meta.visualizationPath = visFolder;
studio.meta.preprocessingPath = preFolder;
studio.meta.pscPath = pscFolder;

        % A completed save interrupted during final publication can be
        % recovered before the picker scans this animal's result folders.
        DataIO('recover',{preFolder,fullfile(datasetFolder,'P'),pscFolder,fullfile(pscFolder,'P')});

        % Register preprocessing datasets from saved MAT metadata.
        % Do not use shortened physical filenames as dropdown names.
        studio = deConfUSIon_add_preproc_lazy_datasets(studio);

        guidata(fig, studio);
        transaction=getappdata(fig,'LoadTransaction'); transaction.committed=true;
        setappdata(fig,'LoadTransaction',transaction);

        unlockAllButtons();
        refreshDatasetDropdown();
dims = size(data.I);

addLog('---------------------------------------');
addLog('DATASET LOADED SUCCESSFULLY');
addLog(['Input file: ' fullInputFile]);
addLog(['Loaded name: ' datasetName]);
addLog(['Dataset folder: ' datasetFolder]);

if ndims(data.I) == 3
    addLog(sprintf('Dimensions: %d x %d | Volumes: %d', ...
        dims(1), dims(2), dims(3)));
elseif ndims(data.I) >= 4
    addLog(sprintf('Dimensions: %d x %d x %d | Volumes: %d', ...
        dims(1), dims(2), dims(3), dims(4)));
else
    addLog(['Dimensions: ' mat2str(dims)]);
    addLog(sprintf('Volumes: %d', data.nVols));
end

addLog(['Probe: ' probeType]);
addLog(sprintf('TR: %.0f ms (%.3f sec)', data.TR*1000, data.TR));
addLog(sprintf('Preset default TR for detected probe: %.0f ms', defaultTR*1000));

if isfield(data,'TotalTimeSec')
    addLog(sprintf('Total time: %.2f sec', data.TotalTimeSec));
end
addLog('---------------------------------------');

        setProgramStatus(true);

    catch ME
        addLog(['LOAD ERROR: ' ME.message]);
        setProgramStatus(true);
        errordlg(ME.message,'Load Failure');
    end
end

    function finishLoad()
        if ~isgraphics(fig), return; end
        transaction=getappdata(fig,'LoadTransaction');
        if isappdata(fig,'LoadInProgress'), rmappdata(fig,'LoadInProgress'); end
        if isappdata(fig,'LoadTransaction'), rmappdata(fig,'LoadTransaction'); end
        if isstruct(transaction) && ~transaction.committed
            % A cancelled or failed replacement load must leave the previous
            % dataset usable. Restore the complete state before refreshing
            % controls; otherwise the half-cleared state can look frozen and
            % the dropdown can remain empty.
            studio=transaction.previousStudio; guidata(fig,studio);
            try, refreshDatasetDropdown(); catch, end
        end
        try, unlockAllButtons(); catch, end
        current=guidata(fig);
        try, setProgramStatus(isfield(current,'isLoaded') && current.isLoaded); catch, end
        try, drawnow limitrate; catch, drawnow; end
    end

%% =========================================================
%  FULL QC
% =========================================================
function runFullQCCallback(~,~)

    studio = guidata(fig);
    if ~isfield(studio,'isLoaded') || ~studio.isLoaded
        errordlg('Load data first.');
        return;
    end

    addLog('Running FULL QC...');
    setProgramStatus(false);
    drawnow;

    opts = struct();
opts.frequency = true;
opts.spatial = true;
opts.temporal = true;
opts.motion = true;
opts.stability = true;
opts.framerate = true;
opts.pca = true;
opts.burst = true;
opts.cnr = true;
opts.commonmode = true;

% NEW QC modules
opts.outlierframes = true;
opts.reliability   = true;

% optional settings
opts.outlierReplace = false;
opts.saveOutlierCorrectedData = false;
opts.reliabilityThreshold = 0.60;

opts.datasetTag = studio.activeDataset;
opts.useTimestampSubfolder = false;

    data = getActiveData();

    try
        qc_fusi(data, studio.meta, studio.exportPath, opts);
        addLog(['FULL QC completed. Saved under: QC\' opts.datasetTag]);
        studio.pipeline.qcDone = true;
        guidata(fig, studio);
    catch ME
        addLog(['QC ERROR: ' ME.message]);
        errordlg(ME.message,'QC Failure');
    end

    setProgramStatus(true);
end

%% =========================================================
%  SPECIFIC QC + Helper
% =========================================================
    function runSpecificQCCallback(~,~)

    if isempty(fig) || ~ishghandle(fig)
        errordlg('Main Studio figure handle is invalid. Please restart fusi_studio.');
        return;
    end

    studio = guidata(fig);
    if isempty(studio) || ~isstruct(studio) || ~isfield(studio,'isLoaded') || ~studio.isLoaded
        errordlg('Load data first.');
        return;
    end

    [choice, choiceNames] = showSpecificQCDialog();

    if isempty(choice)
        addLog('QC selection cancelled.');
        return;
    end

opts = struct();
opts.frequency    = ismember(1, choice);
opts.spatial      = ismember(2, choice);
opts.temporal     = ismember(3, choice);
opts.motion       = ismember(4, choice);
opts.stability    = ismember(5, choice);
opts.framerate    = ismember(6, choice);
opts.pca          = ismember(7, choice);
opts.burst        = ismember(8, choice);
opts.cnr          = ismember(9, choice);
opts.commonmode   = ismember(10, choice);
opts.outlierframes = ismember(11, choice);
opts.reliability   = ismember(12, choice);

% optional settings
opts.outlierReplace = false;
opts.saveOutlierCorrectedData = false;
opts.reliabilityThreshold = 0.60;

opts.datasetTag = studio.activeDataset;
opts.useTimestampSubfolder = false;

    addLog('Running selected QC...');
    for ii = 1:numel(choiceNames)
        thisName = choiceNames{ii};
        addLog(['  - ' thisName]);
    end

    setProgramStatus(false);
    drawnow;

    data = getActiveData();

    try
        qc_fusi(data, studio.meta, studio.exportPath, opts);
        addLog(['Selected QC completed. Saved under: QC\' opts.datasetTag]);
        studio.pipeline.qcDone = true;
        guidata(fig, studio);
    catch ME
        addLog(['QC ERROR: ' ME.message]);
        errordlg(ME.message,'QC Failure');
    end

    setProgramStatus(true);
end
    function [choice, choiceNames] = showSpecificQCDialog()

    choice = [];
    choiceNames = {};

  modules = { ...
    'Frequency QC',        'Power spectrum: 0-2 Hz and 0-0.1 Hz',                          [0.20 0.75 1.00]; ...
    'Spatial QC',          'Mean image, temporal CV, tSNR map and histogram',              [0.20 0.90 0.55]; ...
    'Temporal QC',         'Global signal, rGS, DVARS, spike detection',                   [1.00 0.80 0.25]; ...
    'Motion QC',           'Center-of-mass drift over time',                                [1.00 0.50 0.30]; ...
    'Stability QC',        'Intensity distribution and rejected volumes',                   [0.95 0.35 0.75]; ...
    'Frame-rate QC',       'Global rejection and interpolation stability',                  [0.75 0.60 1.00]; ...
    'PCA QC',              'Explained variance and PCA component overview',                 [0.60 0.85 1.00]; ...
    'Burst Error QC',      'Burst ratio, noisy voxels, burst coverage over time',          [1.00 0.35 0.35]; ...
    'CNR QC',              'Contrast-to-noise ratio map and histogram',                     [0.35 0.90 0.90]; ...
    'Common-Mode QC',      'Block-correlation common-mode artifact detection',              [0.85 0.85 0.35]; ...
    'Outlier Line/Frame QC','Line-wise abnormal frame detection and optional interpolation', [1.00 0.60 0.20]; ...
    'Reliability QC',      'Finite/non-NaN voxel reliability map and region summary',       [0.45 0.75 1.00]  ...
};

    n = size(modules,1);

    bg    = [0.06 0.06 0.07];
    bg2   = [0.10 0.10 0.11];
    fg    = [0.96 0.96 0.96];
    fgDim = [0.72 0.72 0.75];

    dlg = figure( ...
        'Name','Select Specific QC Modules', ...
        'Color',bg, ...
        'MenuBar','none', ...
        'ToolBar','none', ...
        'NumberTitle','off', ...
        'Resize','off', ...
        'Units','pixels', ...
        'Position',[200 100 760 610], ...
        'WindowStyle','modal', ...
        'Visible','off', ...
        'CloseRequestFcn',@onCancel);

    try
        if ~isempty(fig) && ishghandle(fig)
            movegui(dlg,'center');
        end
    catch
        movegui(dlg,'center');
    end

    uicontrol('Parent',dlg,'Style','text', ...
        'Units','normalized', ...
        'Position',[0.04 0.93 0.92 0.05], ...
        'BackgroundColor',bg, ...
        'ForegroundColor',fg, ...
        'FontSize',18, ...
        'FontWeight','bold', ...
        'HorizontalAlignment','left', ...
        'String','Specific QC Selection');

    uicontrol('Parent',dlg,'Style','text', ...
        'Units','normalized', ...
        'Position',[0.04 0.885 0.92 0.035], ...
        'BackgroundColor',bg, ...
        'ForegroundColor',fgDim, ...
        'FontSize',11, ...
        'HorizontalAlignment','left', ...
        'String','Choose the QC modules you want to run.');

    mainPanel = uipanel('Parent',dlg, ...
        'Units','normalized', ...
        'Position',[0.04 0.18 0.92 0.68], ...
        'BackgroundColor',bg2, ...
        'ForegroundColor',[0.35 0.35 0.35], ...
        'BorderType','line', ...
        'Title','QC Modules', ...
        'FontSize',16, ...
        'FontWeight','bold');

    cb = zeros(1,n);

    y0 = 0.89;
    dy = 0.073;

    for ii = 1:n
        y = y0 - (ii-1)*dy;

        chip=uipanel('Parent',mainPanel, ...
            'Units','normalized', ...
            'Position',[0.03 y-0.005 0.025 0.045], ...
            'BackgroundColor',modules{ii,3}, ...
            'BorderType','line');
        setappdata(chip,'PreserveColors',true);

        cb(ii) = uicontrol('Parent',mainPanel, ...
            'Style','checkbox', ...
            'Units','normalized', ...
            'Position',[0.07 y 0.30 0.05], ...
            'BackgroundColor',bg2, ...
            'ForegroundColor',fg, ...
            'FontSize',16, ...
            'FontWeight','bold', ...
            'HorizontalAlignment','left', ...
            'String',modules{ii,1}, ...
            'Value',0);

        uicontrol('Parent',mainPanel,'Style','text', ...
            'Units','normalized', ...
            'Position',[0.39 y-0.003 0.57 0.05], ...
            'BackgroundColor',bg2, ...
            'ForegroundColor',fgDim, ...
            'FontSize',11, ...
            'HorizontalAlignment','left', ...
            'String',modules{ii,2});
    end

    uicontrol('Parent',dlg,'Style','pushbutton', ...
        'String','Select All', ...
        'Units','normalized', ...
        'Position',[0.04 0.09 0.14 0.055], ...
        'FontWeight','bold', ...
        'FontSize',11, ...
        'BackgroundColor',[0.22 0.52 0.95], ...
        'ForegroundColor','w', ...
        'Callback',@onSelectAll);

    uicontrol('Parent',dlg,'Style','pushbutton', ...
        'String','Clear All', ...
        'Units','normalized', ...
        'Position',[0.20 0.09 0.14 0.055], ...
        'FontWeight','bold', ...
        'FontSize',11, ...
        'BackgroundColor',[0.30 0.30 0.32], ...
        'ForegroundColor','w', ...
        'Callback',@onClearAll);

    uicontrol('Parent',dlg,'Style','pushbutton', ...
        'String','Core Set', ...
        'Units','normalized', ...
        'Position',[0.36 0.09 0.14 0.055], ...
        'FontWeight','bold', ...
        'FontSize',11, ...
        'BackgroundColor',[0.15 0.65 0.55], ...
        'ForegroundColor','w', ...
        'Callback',@onCoreSet);

    uicontrol('Parent',dlg,'Style','pushbutton', ...
        'String','Run Selected QC', ...
        'Units','normalized', ...
        'Position',[0.60 0.09 0.20 0.065], ...
        'FontWeight','bold', ...
        'FontSize',16, ...
        'BackgroundColor',[0.15 0.70 0.35], ...
        'ForegroundColor','w', ...
        'Callback',@onRun);

    uicontrol('Parent',dlg,'Style','pushbutton', ...
        'String','Cancel', ...
        'Units','normalized', ...
        'Position',[0.82 0.09 0.14 0.065], ...
        'FontWeight','bold', ...
        'FontSize',16, ...
        'BackgroundColor',[0.75 0.25 0.25], ...
        'ForegroundColor','w', ...
        'Callback',@onCancel);

    qcButtons=findall(dlg,'Style','pushbutton');
    for qcButton=reshape(qcButtons,1,[]), setappdata(qcButton,'PreserveColors',true); end
    set(dlg,'Visible','on');
    try, deConfUSIon_popup_autofit_apply(dlg); catch, end
try, deConfUSIon_fix_scm_video_dialog_fonts(dlg); catch, end % HUMOR_V27_SCM_VIDEO_FONT_FIX
waitfor(dlg);

    function onSelectAll(~,~)
        for kk = 1:n
            if ishandle(cb(kk))
                set(cb(kk),'Value',1);
            end
        end
    end

    function onClearAll(~,~)
        for kk = 1:n
            if ishandle(cb(kk))
                set(cb(kk),'Value',0);
            end
        end
    end

    function onCoreSet(~,~)
        coreIdx = [1 2 3 4 5 8 9 10 11 12];
        for kk = 1:n
            if ishandle(cb(kk))
                set(cb(kk),'Value',ismember(kk,coreIdx));
            end
        end
    end

    function onRun(~,~)
        idx = [];
        for kk = 1:n
            if ishandle(cb(kk))
                if get(cb(kk),'Value') == 1
                    idx(end+1) = kk; %#ok<AGROW>
                end
            end
        end

        if isempty(idx)
            errordlg('Please select at least one QC module.','Specific QC');
            return;
        end

        choice = idx;
        choiceNames = modules(idx,1);

        if ishandle(dlg)
            delete(dlg);
        end
    end

    function onCancel(~,~)
        choice = [];
        choiceNames = {};
        if ishandle(dlg)
            delete(dlg);
        end
    end
end


%% =========================================================
%  IMREGDEMONS PREPROCESSING
% =========================================================
function imregdemonsCallback(~,~)

    studio = guidata(fig);

    if isempty(studio) || ~isstruct(studio) || ...
            ~isfield(studio,'isLoaded') || ~studio.isLoaded
        errordlg('Load data first.','Imregdemons');
        return;
    end

    data = getActiveData();

    if ~isstruct(data) || ~isfield(data,'I') || isempty(data.I)
        errordlg('Active dataset has no data.I field.','Imregdemons');
        return;
    end

    if ~isfield(data,'TR') || isempty(data.TR) || ...
            ~isscalar(data.TR) || ~isfinite(data.TR) || data.TR <= 0
        errordlg('Active dataset has invalid TR.','Imregdemons');
        return;
    end

    % -----------------------------------------------------
    % One clean modern black setup popup
    % Default: MEDIAN, nsub = 100
    % -----------------------------------------------------
    % DECONF_STD_IMREG_CFG_V61
    stdStep = [];
    try
        if isappdata(fig,'deconf_std_workflow_step')
            tmpStd = getappdata(fig,'deconf_std_workflow_step');
            if isstruct(tmpStd) && isfield(tmpStd,'name') && strcmpi(strtrim(tmpStd.name),'Imregdemons')
                stdStep = tmpStd;
            end
        end
    catch
    end
    if ~isempty(stdStep)
        cfg = struct();
        cfg.cancelled = false;
        cfg.blockMethod = 'median';
        if isfield(stdStep,'nsub') && isfinite(double(stdStep.nsub))
            cfg.nsub = max(2,round(double(stdStep.nsub)));
        else
            cfg.nsub = 25;
        end
        cfg.regSmooth = 1.3;
        cfg.stepMotorMode = 'motor';
        cfg.saveQC = true;
        cfg.showQC = false;
        addLog(sprintf('[Standardized] Imregdemons: median | nsub=%d | step-motor per-slice',cfg.nsub));
    else
        % DECONF_STD_IMREG_CFG_V71
    stdStep = [];
    try
        if isappdata(0,'deconf_std_workflow_step'), stdStep = getappdata(0,'deconf_std_workflow_step'); end
        if isempty(stdStep) && exist('fig','var') && ishghandle(fig) && isappdata(fig,'deconf_std_workflow_step'), stdStep = getappdata(fig,'deconf_std_workflow_step'); end
    catch
    end
    if isstruct(stdStep) && isfield(stdStep,'name') && strcmpi(strtrim(stdStep.name),'Imregdemons')
        cfg = struct(); cfg.cancelled = false; cfg.blockMethod = 'median';
        if isfield(stdStep,'nsub') && isfinite(double(stdStep.nsub)), cfg.nsub = max(2,round(double(stdStep.nsub))); else, cfg.nsub = 25; end
        cfg.regSmooth = 1.3; cfg.stepMotorMode = 'motor'; cfg.saveQC = true; cfg.showQC = false;
        addLog(sprintf('[Standardized] Imregdemons no-dialog: median | nsub=%d',cfg.nsub));
    else
        cfg = showImregdemonsSetupDialog(data);
    end
    end

    if isempty(cfg) || ~isstruct(cfg) || ...
            ~isfield(cfg,'cancelled') || cfg.cancelled
        addLog('Imregdemons preprocessing cancelled.');
        return;
    end

    % True 3D awake preset registers volumes rather than independent motor slices.
    if isstruct(stdStep) && isfield(stdStep,'imregMode') && strcmp(stdStep.imregMode,'standard')
        cfg.stepMotorMode='standard';
    end
    blockMethod = lower(strtrim(cfg.blockMethod));
    nsub = round(cfg.nsub);

    % Cleanup old lingering QC / preprocessing windows first
    closeLingeringQCFigures();

    setProgramStatus(false);
    addLog(sprintf('Running Imregdemons preprocessing (%s, nsub = %d)...', ...
        upper(blockMethod), nsub));
    drawnow;

    % Track figure state so any figures created by imregdemons_preprocess
    % can be closed afterwards
    figsBefore = findall(0, 'Type', 'figure');

    ts = datestr(now,'yyyymmdd_HHMMSS');

    opts = struct();
    opts.nsub = nsub;
    opts.blockMethod = blockMethod;
    opts.regSmooth = cfg.regSmooth;
    opts.saveQC = cfg.saveQC;
    opts.showQC = cfg.showQC;
    opts.tag = ['imregdemons_' ts];
    opts.exportPath = studio.exportPath;
    opts.qcDir = fullfile(studio.exportPath, 'Preprocessing', ...
        sprintf('imregdemons_QC_%s_nsub%d', blockMethod, nsub));

    % Optional metadata for auto-detection inside imregdemons_preprocess
    try
        opts.meta = studio.meta;
    catch
    end

    % Registration mode control:
    %   auto     -> do not force opts.stepMotorMode
    %   standard -> force 3D demons for 4D data
    %   motor    -> force per-slice 2D demons for step-motor 4D data
    if strcmpi(cfg.stepMotorMode,'standard')
        opts.stepMotorMode = false;
    elseif strcmpi(cfg.stepMotorMode,'motor')
        opts.stepMotorMode = true;
    end

    % HUMOR_STUDIO_IMREG_FORCE_MOTOR_PATCH_V2
    try
        if studio_is_step_motor_dataset(data, studio)
            opts.stepMotorMode = true;
            opts.isStepMotor = true;
            opts.perSliceDemons = true;
            if isfield(data,'motorInfo')
                opts.motorInfo = data.motorInfo;
            end
            addLog('Step-motor dataset detected -> forcing per-slice 2D imregdemons.');
        end
    catch ME_motor_imreg
        warning('HUMoR:ImregMotorDetect','Could not auto-force motor imreg mode: %s', ME_motor_imreg.message);
    end

    try
        out = imregdemons_preprocess(data.I, data.TR, opts);

        % Close any new figures created during preprocessing
        drawnow;
        closeNewFigures(figsBefore);
        closeLingeringQCFigures();

        newData = data;
        newData.I = single(out.I);

        if isfield(out,'TR') && ~isempty(out.TR)
            newData.TR = out.TR;
        elseif isfield(out,'blockDur') && ~isempty(out.blockDur)
            newData.TR = out.blockDur;
        else
            newData.TR = data.TR * nsub;
        end

        if isfield(out,'nVols') && ~isempty(out.nVols)
            newData.nVols = out.nVols;
        else
            newData.nVols = size(newData.I, ndims(newData.I));
        end

        % Store both output duration and original acquisition duration
        newData.TotalTimeSec = newData.nVols * newData.TR;
        newData.TotalTimeMin = newData.TotalTimeSec / 60;
        newData.totalTime = newData.TotalTimeSec;
        newData.totalTimeMin = newData.TotalTimeMin;

        if isfield(out,'totalTime') && ~isempty(out.totalTime)
            newData.originalTotalTimeSec = out.totalTime;
        else
            newData.originalTotalTimeSec = size(data.I, ndims(data.I)) * data.TR;
        end

        if isfield(out,'method') && ~isempty(out.method)
            newData.preprocessing = out.method;
        else
            newData.preprocessing = sprintf('Imregdemons (%s, nsub=%d)', ...
                blockMethod, nsub);
        end

        % DECONF_OPTA_V2 : out.I is the same array as newData.I - storing both
        % doubled the size of every saved preprocessing MAT. Keep metadata only.
        try
            outMeta = out;
            if isfield(outMeta,'I'), outMeta = rmfield(outMeta,'I'); end
            newData.imregdemons = outMeta;
            clear outMeta;
        catch
            newData.imregdemons = out;
        end

        % Important: old PSC/bg are no longer valid after motion correction
        if isfield(newData,'PSC'), newData.PSC = []; end
        if isfield(newData,'bg'),  newData.bg  = []; end

        baseStem = getCurrentNamingStem(studio);

        fullName = sprintf('%s_imreg_%s_n%d_%s', ...
            baseStem, blockMethod, nsub, ts);

        keyName = makeSafeKey(fullName, studio.datasets);

        newData.displayNameFull = fullName;
        newData.preprocDisplayName = fullName;
        newData.HUMOR_fullDisplayName = fullName;
        try, newData.displayNameShort = deConfUSIon_display_short_name(fullName,newData,''); catch, newData.displayNameShort = fullName; end
        newData.datasetSortTime = now;
        newData.sourceDatasetKey = studio.activeDataset;

        studio.datasets.(keyName) = newData;
        studio.activeDataset = keyName;
        studio.pipeline.preprocDone = true;

        preFolder = fullfile(studio.exportPath,'Preprocessing');

                savePath = deConfUSIon_safe_preproc_save_path(preFolder, fullName, keyName, 'imreg');
        newData.savedFile = savePath;
        newData.lazyFile = savePath;
        displayNameFull = fullName;
                preprocDisplayName = fullName;
                try, datasetSortTime = newData.datasetSortTime; catch, datasetSortTime = now; end
                studio.datasets.(keyName) = newData;
        studio=studioSaveDataset(fig,studio,keyName);
        addLog(['Saved and verified -> ' savePath]);

        guidata(fig, studio);
        refreshDatasetDropdown();

        addLog(['Imregdemons preprocessing complete -> ' fullName]);

        if isfield(out,'registrationMode')
            addLog(['Registration mode: ' out.registrationMode]);
        end

        addLog(sprintf('Output TR: %.6g s | Output volumes: %d | Output duration: %.2f min', ...
            newData.TR, newData.nVols, newData.TotalTimeMin));

        if isfield(out.QC,'error')
            addLog(['Registration saved; QC export needs retry: ' out.QC.error]);
        elseif opts.saveQC
            addLog(['Imregdemons QC saved -> ' opts.qcDir]);
        end

    catch ME
        % Also cleanup figures on failure
        drawnow;
        closeNewFigures(figsBefore);
        closeLingeringQCFigures();

        refreshDatasetDropdown();
        addLog(['IMREGDEMONS ERROR: ' ME.message]);
        errordlg(ME.message,'Imregdemons Failure');
    end

    setProgramStatus(true);
end

%% =========================================================
%  MODERN IMREGDEMONS SETUP POPUP
% =========================================================
function cfg = showImregdemonsSetupDialog(data)

    cfg = struct();
    cfg.cancelled = true;

    TR = double(data.TR);
    I = data.I;
    nd = ndims(I);
    sz = size(I);
    T = sz(nd);

    if nd == 3
        dimTxt = sprintf('%d x %d x %d', sz(1), sz(2), sz(3));
        modeHint = '2D time-series: demons runs frame-by-frame.';
    elseif nd == 4
        dimTxt = sprintf('%d x %d x %d x %d', sz(1), sz(2), sz(3), sz(4));
        modeHint = '4D data: use Auto, or force Step-Motor per-slice mode if this came from motor reconstruction.';
    else
        dimTxt = mat2str(sz);
        modeHint = 'Unsupported dimensionality for Imregdemons.';
    end

    % ---------------- defaults requested ----------------
    defaultNsub = 100;
    defaultMethodIdx = 1;      % 1 = Median, 2 = Mean
    defaultRegSmooth = 1.3;
    defaultModeIdx = 1;        % 1 = Auto, 2 = Standard, 3 = Step-motor
    % HUMOR_STUDIO_IMREG_DIALOG_DEFAULT_PATCH_V2
    try
        if (isfield(data,'motorInfo') && ~isempty(data.motorInfo)) || ...
           (isfield(data,'isStepMotor') && ~isempty(data.isStepMotor) && logical(data.isStepMotor(1))) || ...
           (isfield(data,'stepMotorMode') && ~isempty(data.stepMotorMode) && logical(data.stepMotorMode(1)))
            defaultModeIdx = 3;
        end
    catch
    end
    defaultSaveQC = 1;
    defaultShowQC = 0;

    % ---------------- colors ----------------
    bg      = [0.045 0.045 0.050];
    panel   = [0.085 0.085 0.095];
    panel2  = [0.115 0.115 0.130];
    fg      = [0.96 0.96 0.96];
    fgDim   = [0.72 0.72 0.76];
    blue    = [0.20 0.48 0.95];
    green   = [0.15 0.68 0.35];
    orange  = [0.95 0.55 0.18];
    red     = [0.80 0.25 0.25];

    dlg = figure( ...
        'Name','Imregdemons Preprocessing', ...
        'Color',bg, ...
        'MenuBar','none', ...
        'ToolBar','none', ...
        'NumberTitle','off', ...
        'Resize','off', ...
        'Units','pixels', ...
       'Position',[300 100 880 690], ...
        'WindowStyle','modal', ...
        'Visible','off', ...
        'CloseRequestFcn',@onCancel, ...
        'KeyPressFcn',@onKey);

    try
        movegui(dlg,'center');
    catch
    end

    % ---------------- title ----------------
    uicontrol('Parent',dlg,'Style','text', ...
        'Units','normalized', ...
        'Position',[0.045 0.925 0.91 0.055], ...
        'String','Imregdemons / Motion Correction Setup', ...
        'BackgroundColor',bg, ...
        'ForegroundColor',fg, ...
        'FontName','Helvetica', ...
        'FontSize',20, ...
        'FontWeight','bold', ...
        'HorizontalAlignment','left');

    uicontrol('Parent',dlg,'Style','text', ...
        'Units','normalized', ...
        'Position',[0.047 0.875 0.91 0.04], ...
        'String','Median + nsub = 100 are pre-selected. Adjust only if needed.', ...
        'BackgroundColor',bg, ...
        'ForegroundColor',fgDim, ...
        'FontName','Helvetica', ...
        'FontSize',16, ...
        'HorizontalAlignment','left');

    % ---------------- dataset info ----------------
    infoPanel = uipanel('Parent',dlg, ...
        'Units','normalized', ...
        'Position',[0.045 0.755 0.91 0.105], ...
        'BackgroundColor',panel, ...
        'ForegroundColor',fg, ...
        'BorderType','line', ...
        'HighlightColor',[0.30 0.30 0.34], ...
        'ShadowColor',[0.02 0.02 0.02]);

    infoStr = sprintf('Input size: %s     TR: %.6g s     Volumes: %d     Duration: %.2f min', ...
        dimTxt, TR, T, (T*TR)/60);

    uicontrol('Parent',infoPanel,'Style','text', ...
        'Units','normalized', ...
        'Position',[0.035 0.48 0.93 0.38], ...
        'String',infoStr, ...
        'BackgroundColor',panel, ...
        'ForegroundColor',[0.75 0.88 1.00], ...
        'FontName','Helvetica', ...
        'FontSize',16, ...
        'FontWeight','bold', ...
        'HorizontalAlignment','left');

    uicontrol('Parent',infoPanel,'Style','text', ...
        'Units','normalized', ...
        'Position',[0.035 0.12 0.93 0.30], ...
        'String',modeHint, ...
        'BackgroundColor',panel, ...
        'ForegroundColor',[0.90 0.82 0.55], ...
        'FontName','Helvetica', ...
        'FontSize',11, ...
        'FontWeight','bold', ...
        'HorizontalAlignment','left');

    % ---------------- settings panel ----------------
    settingsPanel = uipanel('Parent',dlg, ...
        'Units','normalized', ...
        'Position',[0.045 0.205 0.91 0.525], ...
        'BackgroundColor',panel, ...
        'ForegroundColor',fg, ...
        'BorderType','line', ...
        'HighlightColor',[0.30 0.30 0.34], ...
        'ShadowColor',[0.02 0.02 0.02]);

    % Block method
    addLabel(settingsPanel,'Block averaging method',0.045,0.835);

    methodPopup = uicontrol('Parent',settingsPanel,'Style','popupmenu', ...
        'Units','normalized', ...
        'Position',[0.38 0.835 0.24 0.075], ...
        'String',{'Median','Mean'}, ...
        'Value',defaultMethodIdx, ...
        'BackgroundColor',panel2, ...
        'ForegroundColor',fg, ...
        'FontName','Helvetica', ...
        'FontSize',16, ...
        'FontWeight','bold', ...
        'Callback',@updateSummary);

 uicontrol('Parent',settingsPanel,'Style','text', ...
    'Units','normalized', ...
    'Position',[0.65 0.805 0.31 0.115], ...
    'String',{'Median is robust'; 'and recommended.'}, ...
    'BackgroundColor',panel, ...
    'ForegroundColor',fgDim, ...
    'FontName','Helvetica', ...
    'FontSize',10, ...
    'HorizontalAlignment','left');

    % nsub
    addLabel(settingsPanel,'Subsampling factor nsub',0.045,0.680);

    nsubEdit = uicontrol('Parent',settingsPanel,'Style','edit', ...
        'Units','normalized', ...
        'Position',[0.38 0.685 0.18 0.075], ...
        'String',num2str(defaultNsub), ...
        'BackgroundColor',[0.02 0.02 0.025], ...
        'ForegroundColor',fg, ...
        'FontName','Helvetica', ...
        'FontSize',13, ...
        'FontWeight','bold', ...
        'HorizontalAlignment','center', ...
        'Callback',@updateSummary);

uicontrol('Parent',settingsPanel,'Style','text', ...
    'Units','normalized', ...
    'Position',[0.59 0.660 0.37 0.105], ...
    'String',{'frames/block.'; 'Output TR = TR x nsub.'}, ...
    'BackgroundColor',panel, ...
    'ForegroundColor',fgDim, ...
    'FontName','Helvetica', ...
    'FontSize',10, ...
    'HorizontalAlignment','left');

    % reg smooth
    addLabel(settingsPanel,'Demons smoothing',0.045,0.525);

    regSmoothEdit = uicontrol('Parent',settingsPanel,'Style','edit', ...
        'Units','normalized', ...
        'Position',[0.38 0.530 0.18 0.075], ...
        'String',num2str(defaultRegSmooth), ...
        'BackgroundColor',[0.02 0.02 0.025], ...
        'ForegroundColor',fg, ...
        'FontName','Helvetica', ...
        'FontSize',13, ...
        'FontWeight','bold', ...
        'HorizontalAlignment','center', ...
        'Callback',@updateSummary);

uicontrol('Parent',settingsPanel,'Style','text', ...
    'Units','normalized', ...
    'Position',[0.59 0.505 0.37 0.115], ...
    'String',{'Default 1.3.'; 'Higher = smoother field.'}, ...
    'BackgroundColor',panel, ...
    'ForegroundColor',fgDim, ...
    'FontName','Helvetica', ...
    'FontSize',10, ...
    'HorizontalAlignment','left');

    % registration mode
    addLabel(settingsPanel,'Registration mode',0.045,0.370);

    modePopup = uicontrol('Parent',settingsPanel,'Style','popupmenu', ...
        'Units','normalized', ...
        'Position',[0.38 0.375 0.40 0.075], ...
       'String',{ ...
    'Auto-detect', ...
    'Standard 3D demons', ...
    'Step-motor per-slice 2D demons'}, ...
        'Value',defaultModeIdx, ...
        'BackgroundColor',panel2, ...
        'ForegroundColor',fg, ...
        'FontName','Helvetica', ...
        'FontSize',16, ...
        'FontWeight','bold', ...
        'Callback',@updateSummary);

    % QC options
    saveQcBox = uicontrol('Parent',settingsPanel,'Style','checkbox', ...
        'Units','normalized', ...
        'Position',[0.045 0.225 0.38 0.075], ...
        'String','Save QC PNGs', ...
        'Value',defaultSaveQC, ...
        'BackgroundColor',panel, ...
        'ForegroundColor',fg, ...
        'FontName','Helvetica', ...
        'FontSize',16, ...
        'FontWeight','bold', ...
        'Callback',@updateSummary);

    showQcBox = uicontrol('Parent',settingsPanel,'Style','checkbox', ...
        'Units','normalized', ...
        'Position',[0.45 0.225 0.38 0.075], ...
        'String','Show QC windows after run', ...
        'Value',defaultShowQC, ...
        'BackgroundColor',panel, ...
        'ForegroundColor',fg, ...
        'FontName','Helvetica', ...
        'FontSize',16, ...
        'FontWeight','bold', ...
        'Callback',@updateSummary);

    % preset buttons
    uicontrol('Parent',settingsPanel,'Style','pushbutton', ...
        'Units','normalized', ...
        'Position',[0.045 0.065 0.25 0.085], ...
        'String','Preset: Median n=100', ...
        'BackgroundColor',blue, ...
        'ForegroundColor','w', ...
        'FontName','Helvetica', ...
        'FontSize',11, ...
        'FontWeight','bold', ...
        'Callback',@presetRecommended);

    uicontrol('Parent',settingsPanel,'Style','pushbutton', ...
        'Units','normalized', ...
        'Position',[0.32 0.065 0.25 0.085], ...
        'String','Faster: Median n=50', ...
        'BackgroundColor',orange, ...
        'ForegroundColor','w', ...
        'FontName','Helvetica', ...
        'FontSize',11, ...
        'FontWeight','bold', ...
        'Callback',@presetFast);

    uicontrol('Parent',settingsPanel,'Style','pushbutton', ...
        'Units','normalized', ...
        'Position',[0.595 0.065 0.25 0.085], ...
        'String','Reset Defaults', ...
        'BackgroundColor',[0.30 0.30 0.34], ...
        'ForegroundColor','w', ...
        'FontName','Helvetica', ...
        'FontSize',11, ...
        'FontWeight','bold', ...
        'Callback',@presetRecommended);

    % ---------------- summary panel ----------------
   summaryPanel = uipanel('Parent',dlg, ...
    'Units','normalized', ...
    'Position',[0.045 0.105 0.91 0.08], ...
        'BackgroundColor',[0.035 0.035 0.040], ...
        'ForegroundColor',fg, ...
        'BorderType','line', ...
        'HighlightColor',[0.25 0.25 0.28], ...
        'ShadowColor',[0.01 0.01 0.01]);

    summaryText = uicontrol('Parent',summaryPanel,'Style','text', ...
        'Units','normalized', ...
        'Position',[0.025 0.10 0.95 0.80], ...
        'String','', ...
        'BackgroundColor',[0.035 0.035 0.040], ...
        'ForegroundColor',[0.70 1.00 0.80], ...
        'FontName','Helvetica', ...
        'FontSize',10, ...
        'FontWeight','bold', ...
        'HorizontalAlignment','left');

    % ---------------- bottom buttons ----------------
    uicontrol('Parent',dlg,'Style','pushbutton', ...
        'Units','normalized', ...
       'Position',[0.54 0.025 0.24 0.06], ...
        'String','RUN IMREGDEMONS', ...
        'BackgroundColor',green, ...
        'ForegroundColor','w', ...
        'FontName','Helvetica', ...
        'FontSize',13, ...
        'FontWeight','bold', ...
        'Callback',@onRun);

    uicontrol('Parent',dlg,'Style','pushbutton', ...
        'Units','normalized', ...
     'Position',[0.80 0.025 0.155 0.06], ...
        'String','CANCEL', ...
        'BackgroundColor',red, ...
        'ForegroundColor','w', ...
        'FontName','Helvetica', ...
        'FontSize',13, ...
        'FontWeight','bold', ...
        'Callback',@onCancel);

    updateSummary();

    set(dlg,'Visible','on');
    try, deConfUSIon_popup_autofit_apply(dlg); catch, end
try, deConfUSIon_fix_scm_video_dialog_fonts(dlg); catch, end % HUMOR_V27_SCM_VIDEO_FONT_FIX
waitfor(dlg);

    % =====================================================
    % Nested helper functions
    % =====================================================
    function addLabel(parent, str, x, y)
        uicontrol('Parent',parent,'Style','text', ...
            'Units','normalized', ...
            'Position',[x y 0.31 0.065], ...
            'String',str, ...
            'BackgroundColor',panel, ...
            'ForegroundColor',fg, ...
            'FontName','Helvetica', ...
            'FontSize',16, ...
            'FontWeight','bold', ...
            'HorizontalAlignment','left');
    end

    function updateSummary(~,~)

        nsub = str2double(get(nsubEdit,'String'));
        regSmooth = str2double(get(regSmoothEdit,'String'));

        if ~isfinite(nsub) || nsub < 2
            nsubTxt = 'invalid';
            outTR = NaN;
            outBlocks = NaN;
            discard = NaN;
        else
            nsub = round(nsub);
            outTR = TR * nsub;
            outBlocks = floor(T / nsub);
            discard = T - outBlocks * nsub;
            nsubTxt = sprintf('nsub=%d, block=%.6g s', nsub, outTR);
        end

        if ~isfinite(regSmooth) || regSmooth <= 0
            smoothTxt = 'invalid smoothing';
        else
            smoothTxt = sprintf('smooth=%.3g', regSmooth);
        end

        methodList = get(methodPopup,'String');
        methodName = methodList{get(methodPopup,'Value')};

        modeList = get(modePopup,'String');
        modeName = modeList{get(modePopup,'Value')};

        txt = sprintf(['%s block averaging | %s | %s | Output blocks: %d | ' ...
            'Discard tail: %d frames | Mode: %s'], ...
            upper(methodName), nsubTxt, smoothTxt, outBlocks, discard, modeName);

        if ishandle(summaryText)
            set(summaryText,'String',txt);
        end
    end

    function presetRecommended(~,~)
        set(methodPopup,'Value',1);          % Median
        set(nsubEdit,'String','100');
        set(regSmoothEdit,'String','1.3');
        set(modePopup,'Value',1);            % Auto
        set(saveQcBox,'Value',1);
        set(showQcBox,'Value',0);
        updateSummary();
    end

    function presetFast(~,~)
        set(methodPopup,'Value',1);          % Median
        set(nsubEdit,'String','50');
        set(regSmoothEdit,'String','1.3');
        set(modePopup,'Value',1);            % Auto
        set(saveQcBox,'Value',1);
        set(showQcBox,'Value',0);
        updateSummary();
    end

    function onRun(~,~)

        nsub = str2double(get(nsubEdit,'String'));
        regSmooth = str2double(get(regSmoothEdit,'String'));

        if ~isfinite(nsub) || nsub < 2
            uiwait(errordlg('nsub must be a number >= 2.', ...
                'Invalid Imregdemons setting','modal'));
            return;
        end

        nsub = round(nsub);

        if floor(T / nsub) < 1
            uiwait(errordlg(sprintf( ...
                'Not enough frames. Dataset has %d volumes, but nsub = %d.', ...
                T, nsub), ...
                'Invalid nsub','modal'));
            return;
        end

        if floor(T / nsub) < 3
            choice = questdlg(sprintf([ ...
                'Only %d output blocks will remain after nsub = %d.\n\n' ...
                'This is very little for motion correction.\nContinue anyway?'], ...
                floor(T/nsub), nsub), ...
                'Low output block count', ...
                'Continue','Cancel','Cancel');

            if isempty(choice) || strcmpi(choice,'Cancel')
                return;
            end
        end

        if ~isfinite(regSmooth) || regSmooth <= 0
            uiwait(errordlg('Demons smoothing must be a positive number.', ...
                'Invalid Imregdemons setting','modal'));
            return;
        end

        methodList = get(methodPopup,'String');
        methodName = lower(methodList{get(methodPopup,'Value')});

        modeVal = get(modePopup,'Value');
        if modeVal == 1
            stepMode = 'auto';
        elseif modeVal == 2
            stepMode = 'standard';
        else
            stepMode = 'motor';
        end

        cfg.cancelled = false;
        cfg.blockMethod = methodName;
        cfg.nsub = nsub;
        cfg.regSmooth = regSmooth;
        cfg.stepMotorMode = stepMode;
        cfg.saveQC = logical(get(saveQcBox,'Value'));
        cfg.showQC = logical(get(showQcBox,'Value'));

        if ishghandle(dlg)
            delete(dlg);
        end
    end

    function onCancel(~,~)
        cfg.cancelled = true;
        if ishghandle(dlg)
            delete(dlg);
        end
    end

    function onKey(~,ev)
        try
            if strcmpi(ev.Key,'escape')
                onCancel();
            elseif strcmpi(ev.Key,'return')
                onRun();
            end
        catch
        end
    end
end

%% =========================================================
%  FRAME-RATE REJECTION
% =========================================================
function frameRateCallback(~,~)

    studio = guidata(fig);

    if ~studio.isLoaded
        errordlg('Load data first.');
        return;
    end

    % Cleanup old lingering QC windows first
    closeLingeringQCFigures();

    data = getActiveData();
    frameCfg=[];
    try, if isappdata(fig,'motionCorrectionConfig'), frameCfg=getappdata(fig,'motionCorrectionConfig'); end, catch, end

    addLog('Running Frame-rate QC (ORIGINAL)...');
    setProgramStatus(false);
    drawnow;

    QC_before = struct();
    QC_after  = struct();

    try
        qcOpts=struct();
        if isstruct(frameCfg) && isfield(frameCfg,'frameSigma'), qcOpts.sigmaThreshold=frameCfg.frameSigma; end
        if isstruct(frameCfg) && isfield(frameCfg,'frameDirection'), qcOpts.direction=frameCfg.frameDirection; end
        QC_before = frameRateQC(data.I, data.TR, 'ORIGINAL', false, qcOpts);
        addLog(sprintf('Original rejected: %.2f %%', QC_before.rejPct));

        qcFolder = fullfile(studio.exportPath,'QC','FrameRate');
        if ~exist(qcFolder,'dir')
            mkdir(qcFolder);
        end

        ts = datestr(now,'yyyymmdd_HHMMSS');

        try
            if isfield(QC_before,'figIntensity') && ishghandle(QC_before.figIntensity)
                deConfUSIon_save_qc_png_white(QC_before.figIntensity, ...
                    fullfile(qcFolder,['FrameRate_ORIGINAL_Intensity_Rejection_' ts '.png']));
            end
            if isfield(QC_before,'figRejected') && ishghandle(QC_before.figRejected) && (~isfield(QC_before,'figIntensity') || ~isequal(QC_before.figRejected,QC_before.figIntensity))
                deConfUSIon_save_qc_png_white(QC_before.figRejected, ...
                    fullfile(qcFolder,['FrameRate_ORIGINAL_Rejected_' ts '.png']));
            end
        catch
        end

        safeCloseFigureHandle(QC_before, 'figIntensity');
        safeCloseFigureHandle(QC_before, 'figRejected');
        closeLingeringQCFigures();

        choice = 'Yes'; % Patch 24: frame rejection auto-confirmed

        if ~strcmp(choice,'Yes')
            addLog('Interpolation skipped.');
            setProgramStatus(true);
            return;
        end

        addLog('Interpolating rejected volumes...');
        Iclean = interpolateRejectedVolumes(data.I, QC_before.outliers);

        addLog('Running Frame-rate QC (INTERPOLATED)...');
        QC_after = frameRateQC(Iclean, data.TR, 'INTERPOLATED', false, qcOpts);
        addLog(sprintf('After interpolation rejected: %.2f %%', QC_after.rejPct));

        try
            if isfield(QC_after,'figIntensity') && ishghandle(QC_after.figIntensity)
                deConfUSIon_save_qc_png_white(QC_after.figIntensity, ...
                    fullfile(qcFolder,['FrameRate_INTERPOLATED_Intensity_Rejection_' ts '.png']));
            end
            if isfield(QC_after,'figRejected') && ishghandle(QC_after.figRejected) && (~isfield(QC_after,'figIntensity') || ~isequal(QC_after.figRejected,QC_after.figIntensity))
                deConfUSIon_save_qc_png_white(QC_after.figRejected, ...
                    fullfile(qcFolder,['FrameRate_INTERPOLATED_Rejected_' ts '.png']));
            end
        catch
        end

        safeCloseFigureHandle(QC_after, 'figIntensity');
        safeCloseFigureHandle(QC_after, 'figRejected');
        closeLingeringQCFigures();

        newData = data;
        newData.I = Iclean;
        newData.frameRateQC_before = QC_before;
        newData.frameRateQC_after = QC_after;
        newData.preprocessing = 'Frame-rate rejection (validated)';

        ts2 = datestr(now,'yyyymmdd_HHMMSS');
        baseStem = getCurrentNamingStem(studio);
        fullName = [baseStem '_frameRej_' ts2];

        keyName = makeSafeKey(fullName, studio.datasets);

        newData.displayNameFull = fullName;
        newData.preprocDisplayName = fullName;
        newData.HUMOR_fullDisplayName = fullName;
        try, newData.displayNameShort = deConfUSIon_display_short_name(fullName,newData,''); catch, newData.displayNameShort = fullName; end
        newData.datasetSortTime = now;
        newData.sourceDatasetKey = studio.activeDataset;

        studio.datasets.(keyName) = newData;
        studio.activeDataset = keyName;
        studio.pipeline.preprocDone = true;

                        preFolder = fullfile(studio.exportPath,'Preprocessing');
                savePath = deConfUSIon_safe_preproc_save_path(preFolder, fullName, keyName, 'framerej');
                newData.savedFile = savePath;
                newData.lazyFile = savePath;
                displayNameFull = fullName;
                preprocDisplayName = fullName;
                try, datasetSortTime = newData.datasetSortTime; catch, datasetSortTime = now; end
                studio.datasets.(keyName) = newData;
                DataIO('save',savePath,struct('newData',newData,'displayNameFull',displayNameFull,'preprocDisplayName',preprocDisplayName,'datasetSortTime',datasetSortTime));
                addLog(['Saved and verified -> ' savePath]);

        guidata(fig, studio);
        refreshDatasetDropdown();

        addLog(['Frame-rate rejection validated -> ' fullName]);

    catch ME
        safeCloseFigureHandle(QC_before, 'figIntensity');
        safeCloseFigureHandle(QC_before, 'figRejected');
        safeCloseFigureHandle(QC_after,  'figIntensity');
        safeCloseFigureHandle(QC_after,  'figRejected');
        closeLingeringQCFigures();

        addLog(['Frame-rate ERROR: ' ME.message]);
        errordlg(ME.message,'Frame-rate Failure');
    end

    setProgramStatus(true);
end

%% =========================================================
%  SCRUBBING
% =========================================================
function scrubbingCallback(~,~)

    studio = guidata(fig);
    if isempty(studio) || ~isstruct(studio) || ~isfield(studio,'isLoaded') || ~studio.isLoaded
        errordlg('Load data first.','Scrubbing');
        return;
    end

    data = getActiveData();
    motionCfg=[];
    try, if isappdata(fig,'motionCorrectionConfig'), motionCfg=getappdata(fig,'motionCorrectionConfig'); end, catch, end

    addLog('Running scrubbing...');
    setProgramStatus(false);
    drawnow;

    ts = datestr(now,'yyyymmdd_HHMMSS');
    tag = ['scrub_' ts];

    try
        [outI, stats] = scrubbing(data.I, data.TR, studio.exportPath, tag, motionCfg);
if isempty(outI) || ...
        (isstruct(stats) && isfield(stats,'cancelled') && stats.cancelled)
    addLog('Scrubbing cancelled.');
    setProgramStatus(true);
    return;
end
        method = 'Unknown';
        if isfield(stats,'method') && ~isempty(stats.method)
            method = stats.method;
        end

        interpMethod = 'linear';
        if isfield(stats,'interpMethod') && ~isempty(stats.interpMethod)
            interpMethod = stats.interpMethod;
        end

        methKey = regexprep(method, '\s+','');
        interpKey = lower(regexprep(interpMethod,'\s+',''));

        baseStem = getCurrentNamingStem(studio);
fullName = [baseStem '_scrub_' methKey '_' interpKey '_' ts];
        keyName = makeSafeKey(fullName, studio.datasets);

        newData = data;
        newData.I = single(outI);
        newData.preprocessing = sprintf('Scrubbing (%s, %s)', method, interpMethod);
        newData.scrubbingStats = stats;
        newData.displayNameFull = fullName;
        newData.preprocDisplayName = fullName;
        newData.HUMOR_fullDisplayName = fullName;
        try, newData.displayNameShort = deConfUSIon_display_short_name(fullName,newData,''); catch, newData.displayNameShort = fullName; end
        newData.datasetSortTime = now;
        newData.sourceDatasetKey = studio.activeDataset;

        studio.datasets.(keyName) = newData;
        studio.activeDataset = keyName;
        studio.pipeline.preprocDone = true;

                        preFolder = fullfile(studio.exportPath,'Preprocessing');
                savePath = deConfUSIon_safe_preproc_save_path(preFolder, fullName, keyName, 'scrub');
                newData.savedFile = savePath;
                newData.lazyFile = savePath;
                displayNameFull = fullName;
                preprocDisplayName = fullName;
                try, datasetSortTime = newData.datasetSortTime; catch, datasetSortTime = now; end
                studio.datasets.(keyName) = newData;
                DataIO('save',savePath,struct('newData',newData,'displayNameFull',displayNameFull,'preprocDisplayName',preprocDisplayName,'datasetSortTime',datasetSortTime));
                addLog(['Saved and verified -> ' savePath]);

        guidata(fig, studio);
        refreshDatasetDropdown();

        nFlag = NaN;
        pct = NaN;
        if isfield(stats,'removedVolumes')
            nFlag = stats.removedVolumes;
        end
        if isfield(stats,'percentRemoved')
            pct = stats.percentRemoved;
        end

        addLog(sprintf('Scrubbing done: %s + %s | flagged=%g (%.2f%%)', methKey, interpKey, nFlag, pct));
        addLog(['Saved dataset -> ' fullName]);

    catch ME
        addLog(['SCRUBBING ERROR: ' ME.message]);
        errordlg(ME.message,'Scrubbing Failure');
    end

    setProgramStatus(true);
end

%% =========================================================
%  MOTOR RECONSTRUCTION
% =========================================================
function stepMotorCallback(~,~)

    studio = guidata(fig);

    if isempty(studio) || ~studio.isLoaded
        errordlg('Load data first.');
        return;
    end

    data = getActiveData();

    % HUMOR_STUDIO_MOTOR_SPLIT_LOAD_PATCH_V2
    if ndims(data.I) == 4 && size(data.I,3) == 1
        data.I = squeeze(data.I(:,:,1,:));
    end

    if ndims(data.I) ~= 3
        errordlg(['Motor reconstruction should be run from one raw/split 2D MAT file first.' sprintf('\n\n') ...
            'If this is already an assembled [Y X Z T] motor dataset, do not run Motor again; run Imregdemons directly.'], ...
            'Motor Reconstruction');
        return;
    end

    addLog('Launching Motor Reconstruction...');
    setProgramStatus(false);
    drawnow;

    try
        qcFolder = fullfile(studio.exportPath,'Preprocessing','motor_QC');
        if ~exist(qcFolder,'dir')
            mkdir(qcFolder);
        end

        % HUMOR_STUDIO_MOTOR_PASS_FOLDER_PATCH_V2
        motorOpts = struct();
        try
            motorOpts.rawFolder = studio.loadedPath;
        catch
            motorOpts.rawFolder = '';
        end
        motorOpts.preferSplitIfFolderLooksSplit = true;

        % DECONF_STD_MOTOR_PRESET_20260623
        % If Motor is launched from Standardized Analysis, run it with
        % the selected standardized preset instead of opening the Motor dialog.
        try
            if isappdata(fig,'deconf_std_workflow_step')
                stdStep = getappdata(fig,'deconf_std_workflow_step');
                if isstruct(stdStep) && isfield(stdStep,'name') && strcmpi(strtrim(stdStep.name),'Motor')
                    motorOpts.standardizedWorkflow = true;
                    motorOpts.noDialog = true;
                    motorOpts.sourceMode = 2;                  % split MAT folder mode
                    motorOpts.correctionMode = 1;              % 1 = None/raw
                    motorOpts.doDespike = true;
                    motorOpts.spikeThr = 4;
                    motorOpts.trimFrames = 0;
                    motorOpts.splitBaselineBlocksPerSlice = 0;

                    if isfield(stdStep,'slices') && ~isempty(stdStep.slices) && isfinite(double(stdStep.slices))
                        motorOpts.nSlices = max(1,round(double(stdStep.slices)));
                    else
                        motorOpts.nSlices = 4;
                    end

                    try
                        if isfield(studio,'loadedPath') && ~isempty(studio.loadedPath) && exist(studio.loadedPath,'dir') == 7
                            motorOpts.rawFolder = studio.loadedPath;
                        end
                    catch
                    end

                    addLog(sprintf('[Standardized] Motor auto preset: split folder | slices=%d | correction=None/raw | residual despike=4', motorOpts.nSlices));
                end
            end
        catch ME_std_motor
            addLog(['[Standardized] Motor preset warning: ' ME_std_motor.message]);
        end

        % DECONF_STD_MOTOR_OPTS_FROM_WORKFLOW_V71
        try
            stdStep = [];
            if isappdata(0,'deconf_std_workflow_step'), stdStep = getappdata(0,'deconf_std_workflow_step'); end
            if isempty(stdStep) && exist('fig','var') && ishghandle(fig) && isappdata(fig,'deconf_std_workflow_step'), stdStep = getappdata(fig,'deconf_std_workflow_step'); end
            if isstruct(stdStep) && isfield(stdStep,'name') && strcmpi(strtrim(stdStep.name),'Motor')
                motorOpts.noDialog = true;
                motorOpts.sourceMode = 2;
                motorOpts.correctionMode = 1;
                motorOpts.doDespike = true;
                motorOpts.spikeThr = 4;
                motorOpts.trimFrames = 0;
                motorOpts.splitBaselineBlocksPerSlice = 0;
                if isfield(stdStep,'slices') && isfinite(double(stdStep.slices)), motorOpts.nSlices = max(1,round(double(stdStep.slices))); else, motorOpts.nSlices = 4; end
                if exist('studio','var') && isfield(studio,'loadedPath') && ~isempty(studio.loadedPath) && exist(studio.loadedPath,'dir') == 7, motorOpts.rawFolder = studio.loadedPath; end
                addLog(sprintf('[Standardized] Motor no-dialog: split folder | slices=%d | correction=None/raw | residual despike=4',motorOpts.nSlices));
            end
        catch ME_std_motor
            addLog(['[Standardized] Motor preset warning: ' ME_std_motor.message]);
        end
        [I3D, motorInfo] = motor(data.I, data.TR, qcFolder, motorOpts);

        newData = data;
        newData.I = I3D;

        if ndims(I3D) == 4
            newData.nVols = size(I3D,4);
        end

        newData.preprocessing = 'Motor slice reconstruction';
        newData.motorInfo = motorInfo;
        % Reconstruction creates a new time series, not a derivative with
        % the duration of the single split file used to open Studio.
        newData = deConfUSIon_signal('motortiming',newData);
        % HUMOR_STUDIO_MARK_MOTOR_PATCH_V2
        newData.isStepMotor = true;
        newData.stepMotorMode = true;

        ts = datestr(now,'yyyymmdd_HHMMSS');

        baseStem = getCurrentNamingStem(studio);

        fullName = [baseStem '_motor_' ts];

        keyName = makeSafeKey(fullName, studio.datasets);

        newData.displayNameFull = fullName;
        newData.preprocDisplayName = fullName;
        newData.HUMOR_fullDisplayName = fullName;
        try, newData.displayNameShort = deConfUSIon_display_short_name(fullName,newData,''); catch, newData.displayNameShort = fullName; end
        newData.datasetSortTime = now;
        newData.sourceDatasetKey = studio.activeDataset;

        studio.datasets.(keyName) = newData;
        studio.activeDataset = keyName;
        studio.pipeline.preprocDone = true;

                        preFolder = fullfile(studio.exportPath,'Preprocessing');
                savePath = deConfUSIon_safe_preproc_save_path(preFolder, fullName, keyName, 'motor');
                newData.savedFile = savePath;
                newData.lazyFile = savePath;
                displayNameFull = fullName;
                preprocDisplayName = fullName;
                try, datasetSortTime = newData.datasetSortTime; catch, datasetSortTime = now; end
                studio.datasets.(keyName) = newData;
                studio=studioSaveDataset(fig,studio,keyName);
                addLog(['Saved and verified -> ' savePath]);

        guidata(fig, studio);
        refreshDatasetDropdown();

        addLog(sprintf('Slices: %d | Volumes per slice: %d | Minutes per slice: %.2f', ...
            motorInfo.nSlices, motorInfo.volumesPerSlice, motorInfo.minutesPerSlice));
        addLog(['Motor reconstruction complete -> ' fullName]);

    catch ME
        refreshDatasetDropdown();
        addLog(['MOTOR ERROR: ' ME.message]);
        errordlg(ME.message,'Motor Failure');
    end

    setProgramStatus(true);
end

%% =========================================================
%  DESPIKE
% =========================================================
function despikeCallback(~,~)

    studio = guidata(fig);

    if ~studio.isLoaded
        errordlg('Load data first.');
        return;
    end

    data = getActiveData();

    zDefault='5';
    try, if isappdata(fig,'motionCorrectionConfig'), mc=getappdata(fig,'motionCorrectionConfig'); if isfield(mc,'despikeZ'), zDefault=num2str(mc.despikeZ); end, end, catch, end
    answer = inputdlg('Z-threshold (default = 5):', 'Despike', 1, {zDefault});

    if isempty(answer)
        addLog('Despiking cancelled.');
        return;
    end

    zthr = str2double(answer{1});
    if isnan(zthr) || zthr <= 0
        errordlg('Invalid Z-threshold.');
        return;
    end

    addLog(sprintf('Running voxel-wise despiking (Z = %.2f)...', zthr));
    setProgramStatus(false);
    drawnow;

    try
        ts = datestr(now,'yyyymmdd_HHMMSS');

        [outI, stats] = despike(data.I, zthr, studio.exportPath, ['despike_' ts]);

        if isfield(stats,'percentRemoved') && isfield(stats,'removedPoints')
            addLog(sprintf('Despiking removed %.4f%% of data points (%d spikes).', ...
                   stats.percentRemoved, stats.removedPoints));
        end

        if isfield(stats,'qcFile') && ~isempty(stats.qcFile)
            addLog(['Despike QC saved: ' stats.qcFile]);
        end

        newData = data;
        newData.I = single(outI);
        newData.preprocessing = sprintf('Voxel-wise MAD despiking (Z=%.3g)', zthr);
        newData.despikeStats = stats;
        newData.despikeZ = zthr;

        baseStem = getCurrentNamingStem(studio);
fullName = sprintf('%s_despike_z%s_%s', baseStem, numTag(zthr), ts);

        keyName = makeSafeKey(fullName, studio.datasets);

        newData.displayNameFull = fullName;
        newData.preprocDisplayName = fullName;
        newData.HUMOR_fullDisplayName = fullName;
        try, newData.displayNameShort = deConfUSIon_display_short_name(fullName,newData,''); catch, newData.displayNameShort = fullName; end
        newData.datasetSortTime = now;
        newData.sourceDatasetKey = studio.activeDataset;

        studio.datasets.(keyName) = newData;
        studio.activeDataset = keyName;
        studio.pipeline.preprocDone = true;

                        preFolder = fullfile(studio.exportPath,'Preprocessing');
                savePath = deConfUSIon_safe_preproc_save_path(preFolder, fullName, keyName, 'despike');
                newData.savedFile = savePath;
                newData.lazyFile = savePath;
                displayNameFull = fullName;
                preprocDisplayName = fullName;
                try, datasetSortTime = newData.datasetSortTime; catch, datasetSortTime = now; end
                studio.datasets.(keyName) = newData;
                DataIO('save',savePath,struct('newData',newData,'displayNameFull',displayNameFull,'preprocDisplayName',preprocDisplayName,'datasetSortTime',datasetSortTime));
                addLog(['Saved and verified -> ' savePath]);

        guidata(fig, studio);
        refreshDatasetDropdown();

        addLog(['Despiking complete -> ' fullName]);

    catch ME
        addLog(['DESPIKE ERROR: ' ME.message]);
        errordlg(ME.message,'Despike Failure');
    end

    setProgramStatus(true);
end

%% =========================================================
%  SVD / CLUTTER FILTERING
% =========================================================
function svdClutterCallback(~,~)

    studio = guidata(fig);

    if ~studio.isLoaded
        errordlg('Load data first.','SVD / Clutter Filtering');
        return;
    end

    data = getActiveData();
    if ~isstruct(data) || ~isfield(data,'I') || isempty(data.I)
        errordlg('Active dataset has no data.I field.','SVD / Clutter Filtering');
        return;
    end
    if ndims(data.I) < 3 || ndims(data.I) > 4
        errordlg('SVD needs [Y X T] or [Y X Z T] data with time last.', ...
            'SVD / Clutter Filtering');
        return;
    end

    guiOpts = struct();
    guiOpts.exportPath = studio.exportPath;
    guiOpts.defaultPercent = 20;
    guiOpts.mask = [];
    guiOpts.maskLabel = 'loaded brain mask';

    try
        if isfield(studio,'mask') && ~isempty(studio.mask)
            guiOpts.mask = logical(studio.mask);
            if isfield(studio,'maskIsInclude') && ~studio.maskIsInclude
                guiOpts.mask = ~guiOpts.mask;
                guiOpts.maskLabel = 'inverse loaded mask';
            end
        elseif isfield(data,'mask') && ~isempty(data.mask)
            guiOpts.mask = logical(data.mask);
            guiOpts.maskLabel = 'dataset mask';
        end
    catch
        guiOpts.mask = [];
    end

    datasetLabel = getDatasetDisplayName(studio,studio.activeDataset);
    addLog(['Opening SVD / Clutter Filtering QC (Dataset: ' datasetLabel ')']);
    setProgramStatus(false);
    drawnow;

    try
        [I_svd,svdStats,wasApplied] = deConfUSIon_svd_clutter_gui( ...
            data.I,data.TR,datasetLabel,guiOpts);

        if ~wasApplied
            addLog('SVD / Clutter Filtering closed without applying.');
            setProgramStatus(true);
            return;
        end

        newData = data;
        newData.I = single(I_svd);
        newData.svdClutter = svdStats;
        newData.preprocessing = sprintf( ...
            'SVD clutter filtering: rejected %d/%d components (%.1f%%), %s, centering=%s', ...
            svdStats.nRejected,svdStats.nFrames,svdStats.cutoffPercent, ...
            svdStats.scope,svdStats.centerMode);

        % PSC and background products from the parent dataset are invalid now.
        if isfield(newData,'PSC'), newData.PSC = []; end
        if isfield(newData,'bg'),  newData.bg  = []; end

        % Preserve the complete current processing-chain name.
        baseStem = getCurrentNamingStem(studio);
        baseStem = char(string(baseStem));
        baseStem = strtrim(baseStem);

        % Prevent repeated SVD suffixes when filtering an SVD dataset again.
        baseStem = regexprep(baseStem, ...
            '_SVD_p[0-9p]+_k[0-9]+_(perSlice|joint)(_[0-9]+)?$', ...
            '','ignorecase');

        pctTag = strrep(sprintf('%.1f',svdStats.cutoffPercent),'.','p');

        if strcmpi(svdStats.scope,'per-slice') || ...
                strcmpi(svdStats.scope,'perslice')
            scopeTag = 'perSlice';
        else
            scopeTag = 'joint';
        end

        fullName = sprintf('%s_SVD_p%s_k%d_%s', ...
            baseStem,pctTag,svdStats.nRejected,scopeTag);

        fullName = regexprep(fullName,'[^A-Za-z0-9_\-]+','_');
        fullName = regexprep(fullName,'_+','_');
        fullName = regexprep(fullName,'^_|_$','');

        % Keep the original dataset and create a unique new dropdown entry.
        keyName = makeSafeKey(fullName,studio.datasets);

        newData.displayNameFull = fullName;
        newData.preprocDisplayName = fullName;
        newData.HUMOR_fullDisplayName = fullName;
        try
            newData.displayNameShort = deConfUSIon_display_short_name(fullName,newData,'');
        catch
            newData.displayNameShort = fullName;
        end
        newData.datasetSortTime = now;
        newData.sourceDatasetKey = studio.activeDataset;

        preFolder = fullfile(studio.exportPath,'Preprocessing');
        savePath = deConfUSIon_safe_preproc_save_path(preFolder,fullName,keyName,'svd');
        newData.savedFile = savePath;
        newData.lazyFile = savePath;

        studio.datasets.(keyName) = newData;
        studio.activeDataset = keyName;
        studio.pipeline.preprocDone = true;

        displayNameFull = fullName; %#ok<NASGU>
        preprocDisplayName = fullName; %#ok<NASGU>
        datasetSortTime = newData.datasetSortTime; %#ok<NASGU>
        DataIO('save',savePath,struct('newData',newData,'displayNameFull',displayNameFull,'preprocDisplayName',preprocDisplayName,'datasetSortTime',datasetSortTime));

        guidata(fig,studio);
        refreshDatasetDropdown();

        addLog(sprintf('SVD applied: %.1f%% (%d/%d components), scope=%s, center=%s.', ...
            svdStats.cutoffPercent,svdStats.nRejected,svdStats.nFrames, ...
            svdStats.scope,svdStats.centerMode));
        addLog(['Saved and verified -> ' savePath]);
        if isfield(svdStats,'qcFile') && ~isempty(svdStats.qcFile)
            addLog(['SVD QC saved -> ' svdStats.qcFile]);
        end

    catch ME
        addLog(['SVD / CLUTTER FILTER ERROR: ' ME.message]);
        errordlg(ME.message,'SVD / Clutter Filtering Failure');
    end

    setProgramStatus(true);
end

%% =========================================================
%  DRIFT COMPENSATION
% =========================================================
function driftCompensationCallback(~,~)

    studio = guidata(fig);

    if ~studio.isLoaded
        errordlg('Load data first.');
        return;
    end

    data = getActiveData();

    if ~isfield(data,'I') || isempty(data.I)
        errordlg('Active dataset has no image data.','Drift Compensation');
        return;
    end

    ndI = ndims(data.I);
    if ndI < 3
        errordlg('Drift compensation needs a time series (3D or 4D dataset).','Drift Compensation');
        return;
    end
    nFrames = size(data.I, ndI);

    stdStep = [];
    try
        if isappdata(0,'deconf_std_workflow_step'), stdStep = getappdata(0,'deconf_std_workflow_step'); end
        if isempty(stdStep) && exist('fig','var') && ishghandle(fig) && isappdata(fig,'deconf_std_workflow_step')
            stdStep = getappdata(fig,'deconf_std_workflow_step');
        end
    catch
    end

    isAuto = isstruct(stdStep) && isfield(stdStep,'name') && ...
             strcmpi(strtrim(stdStep.name),'Drift Compensation');

    if isAuto
        cfg = struct();
        cfg.cancelled   = false;
        cfg.method      = 'anchor';
        cfg.polyOrder   = 1;
        if isfield(stdStep,'base2') && isfinite(double(stdStep.base2))
            cfg.tailSec = [];   % engine falls back to the last 25% of the run
        end
        cfg.vehicleFile = '';
        b1 = 0; b2 = 60;
        if isfield(stdStep,'base1') && isfinite(double(stdStep.base1)), b1 = double(stdStep.base1); end
        if isfield(stdStep,'base2') && isfinite(double(stdStep.base2)), b2 = double(stdStep.base2); end
        if b2 <= b1, b2 = b1 + 30; end
        cfg.baselineSec = [b1 b2];
        tr0 = double(data.TR(end));
        runSec = max(0,(nFrames-1)*tr0);
        availableSec = max(tr0,runSec-b2);
        cfg.injectionSec = b2;
        cfg.responseSec = min(availableSec, ...
            min(180,max(120,0.70*availableSec)));
        addLog(sprintf(['[Standardized] Drift GLM linear: baseline %.6g-%.6g s, ' ...
            'injection %.6g s, response %.6g s [default capped at 180 s]'], ...
            b1,b2,cfg.injectionSec,cfg.responseSec));
    else
        defs = struct();
        defs.exportPath = studio.exportPath;
        defs.TR         = data.TR;
        defs.nFrames    = nFrames;
        defs.I          = data.I;
        cfg = deConfUSIon_drift_dialog(defs);
    end

    if isempty(cfg) || ~isstruct(cfg) || ~isfield(cfg,'cancelled') || cfg.cancelled
        addLog('Drift compensation cancelled.');
        return;
    end

        addLog(sprintf('Running drift compensation (method = %s)...', cfg.method));
    setProgramStatus(false);
    drawnow;

    try
        ts = datestr(now,'yyyymmdd_HHMMSS');

        opts             = struct();
        opts.method      = cfg.method;
        opts.baselineSec = cfg.baselineSec;
        opts.polyOrder   = cfg.polyOrder;
        opts.tag         = ts;
        opts.verbose     = true;
        driftSkipFields = {'cancelled','method','baselineSec','polyOrder', ...
                           'vehicleFile','targetFile','rootFolder'};
        fnAllCfg = fieldnames(cfg);
        for iOpt = 1:numel(fnAllCfg)
            fnOpt = fnAllCfg{iOpt};
            if any(strcmp(fnOpt, driftSkipFields)), continue; end
            if ~isempty(cfg.(fnOpt))
                opts.(fnOpt) = cfg.(fnOpt);
            end
        end

        if strcmpi(cfg.method,'vehicle')
            if ~isfield(cfg,'vehicleFile') || isempty(cfg.vehicleFile) || exist(cfg.vehicleFile,'file') ~= 2
                error('No vehicle scan selected (or file not found).');
            end
            addLog(['Loading vehicle scan: ' cfg.vehicleFile]);
            Sveh = load(cfg.vehicleFile);
            vehData = [];
            if isfield(Sveh,'newData') && isstruct(Sveh.newData)
                vehData = Sveh.newData;
            else
                fnv = fieldnames(Sveh);
                for iv = 1:numel(fnv)
                    cand = Sveh.(fnv{iv});
                    if isstruct(cand) && isfield(cand,'I') && ~isempty(cand.I)
                        vehData = cand; break;
                    end
                end
            end
            if isempty(vehData) || ~isfield(vehData,'I') || isempty(vehData.I)
                error('Selected vehicle MAT contains no usable dataset (no .I field).');
            end
            opts.vehicleI = vehData.I;
            if isfield(vehData,'TR') && ~isempty(vehData.TR)
                opts.vehicleTR = vehData.TR;
            else
                opts.vehicleTR = data.TR;
            end
        end

        if strcmpi(cfg.method,'reference')
            if ~isfield(opts,'refMask') || isempty(opts.refMask)
                refM = [];
                if isfield(data,'mask') && ~isempty(data.mask), refM = data.mask; end
                if isempty(refM) && isfield(studio,'mask') && ~isempty(studio.mask), refM = studio.mask; end
                if ~isempty(refM), opts.refMask = refM; end
            end
            if ~isfield(opts,'refMask') || isempty(opts.refMask)
                error('Reference method needs a region. Pick one in the dialog, or load a mask first.');
            end
        elseif any(strcmpi(cfg.method,{'compcor','acompcor','glm','model'}))
            % For CompCor/GLM, the Mask Editor mask is treated as the brain/functional candidate mask.
            % It is not silently reused as the aCompCor noise ROI.
            if ~isfield(opts,'brainMask') || isempty(opts.brainMask)
                brainM = [];
                if isfield(data,'mask') && ~isempty(data.mask), brainM = data.mask; end
                if isempty(brainM) && isfield(studio,'mask') && ~isempty(studio.mask), brainM = studio.mask; end
                if ~isempty(brainM), opts.brainMask = brainM; end
            end
        end

        [outI, stats] = DriftCompensation('run', data.I, data.TR, studio.exportPath, opts);

        addLog(sprintf('Drift range %.4g -> %.4g (%.1f%% reduction).', ...
            stats.driftRangeBefore, stats.driftRangeAfter, stats.driftReductionPercent));

        if isfield(stats,'qcFile') && ~isempty(stats.qcFile)
            addLog(['Drift QC saved: ' stats.qcFile]);
        end

        newData = data;
        newData.I = single(outI);
        newData.preprocessing = sprintf('Drift compensation (%s, baseline %.6g-%.6g s)', ...
            stats.method, stats.baselineSec(1), stats.baselineSec(2));
        newData.driftStats  = stats;
        newData.driftMethod = stats.method;

        baseStem = getCurrentNamingStem(studio);

        driftMethod = lower(char(stats.method));
        po = round(double(stats.polyOrder));

        switch po
            case 0, orderLabel = 'constant';
            case 1, orderLabel = 'linear';
            case 2, orderLabel = 'quadratic';
            case 3, orderLabel = 'cubic';
            otherwise, orderLabel = ['order' num2str(po)];
        end

        driftParts = {['driftComp_' driftMethod]};

        if any(strcmp(driftMethod,{'glm','model','anchor','baseline','poly','robust','irls'}))
            driftParts{end+1} = orderLabel;
            driftParts{end+1} = ['o' num2str(po)];
        end

        driftParts{end+1} = ['b' numTag(stats.baselineSec(1)) '-' numTag(stats.baselineSec(2))];

        if any(strcmp(driftMethod,{'glm','model'}))
            if isfield(stats,'injectionSec') && ~isempty(stats.injectionSec)
                driftParts{end+1} = ['inj' numTag(stats.injectionSec(1))];
            end
            if isfield(stats,'responseSec') && ~isempty(stats.responseSec)
                driftParts{end+1} = ['resp' numTag(stats.responseSec(1))];
            end
        elseif strcmp(driftMethod,'anchor') && isfield(stats,'tailSec') && numel(stats.tailSec) == 2
            driftParts{end+1} = ['tail' numTag(stats.tailSec(1)) '-' numTag(stats.tailSec(2))];
        elseif any(strcmp(driftMethod,{'compcor','acompcor'})) && isfield(stats,'nComp')
            driftParts{end+1} = ['nC' num2str(round(double(stats.nComp)))];
        end

        if isfield(stats,'restoreMode') && ~isempty(stats.restoreMode)
            driftParts{end+1} = ['restore' lower(regexprep(char(stats.restoreMode),'[^A-Za-z0-9]',''))];
        end

        fullName = [baseStem '_' strjoin(driftParts,'_') '_' ts];
        fullName = regexprep(fullName,'_+','_');

        keyName = makeSafeKey(fullName, studio.datasets);

        newData.displayNameFull = fullName;
        newData.preprocDisplayName = fullName;
        newData.HUMOR_fullDisplayName = fullName;
        try, newData.displayNameShort = deConfUSIon_display_short_name(fullName,newData,''); catch, newData.displayNameShort = fullName; end
        newData.datasetSortTime = now;
        newData.sourceDatasetKey = studio.activeDataset;

        studio.datasets.(keyName) = newData;
        studio.activeDataset = keyName;
        studio.pipeline.preprocDone = true;

        preFolder = fullfile(studio.exportPath,'Preprocessing');
        savePath  = deConfUSIon_safe_preproc_save_path(preFolder, fullName, keyName, 'drift');
        newData.savedFile = savePath;
        newData.lazyFile  = savePath;
        displayNameFull    = fullName;
        preprocDisplayName = fullName;
        try, datasetSortTime = newData.datasetSortTime; catch, datasetSortTime = now; end
        studio.datasets.(keyName) = newData;
        DataIO('save',savePath,struct('newData',newData,'displayNameFull',displayNameFull,'preprocDisplayName',preprocDisplayName,'datasetSortTime',datasetSortTime));
        addLog(['Saved and verified -> ' savePath]);

        guidata(fig, studio);
        refreshDatasetDropdown();

        addLog(['Drift compensation complete -> ' fullName]);

    catch ME
        addLog(['DRIFT COMPENSATION ERROR: ' ME.message]);
        errordlg(ME.message,'Drift Compensation Failure');
    end

    setProgramStatus(true);
end

%% =========================================================
%  TEMPORAL SMOOTHING / SUBSAMPLING
% =========================================================
function temporalSmoothingCallback(~,~)

    studio = guidata(fig);

    if ~isfield(studio,'isLoaded') || ~studio.isLoaded
        errordlg('Load data first.','Temporal Interpolation');
        return;
    end

    data = getActiveData();

    if ~isstruct(data) || ~isfield(data,'I') || isempty(data.I)
        errordlg('Active dataset has no data.I to process.', ...
            'Temporal Interpolation');
        return;
    end

    if ~isfield(data,'TR') || isempty(data.TR) || ...
            ~isscalar(data.TR) || ~isfinite(data.TR) || data.TR <= 0
        errordlg('Active dataset has invalid TR.', ...
            'Temporal Interpolation');
        return;
    end

    % -----------------------------------------------------
    % Single modern black setup popup
    % -----------------------------------------------------
    % DECONF_STD_TEMPORAL_CFG_V71
    stdStep = [];
    try
        if isappdata(0,'deconf_std_workflow_step'), stdStep = getappdata(0,'deconf_std_workflow_step'); end
        if isempty(stdStep) && exist('fig','var') && ishghandle(fig) && isappdata(fig,'deconf_std_workflow_step'), stdStep = getappdata(fig,'deconf_std_workflow_step'); end
    catch
    end
    if isstruct(stdStep) && isfield(stdStep,'name') && strcmpi(strtrim(stdStep.name),'Temporal Smoothing')
        cfg = struct(); cfg.cancelled = false;
        tm = 1; if isfield(stdStep,'tempMode') && isfinite(double(stdStep.tempMode)), tm = round(double(stdStep.tempMode)); end
        if tm == 2
            cfg.mode = 'block';
            if isfield(stdStep,'tempNsub') && isfinite(double(stdStep.tempNsub)), cfg.nsub = max(1,round(double(stdStep.tempNsub))); else, cfg.nsub = 50; end
            if isfield(stdStep,'tempMethod') && round(double(stdStep.tempMethod)) == 2, cfg.blockMethod = 'median'; else, cfg.blockMethod = 'mean'; end
            cfg.winSec = cfg.nsub * double(data.TR);
        else
            cfg.mode = 'sliding';
            if isfield(stdStep,'tempWinSec') && isfinite(double(stdStep.tempWinSec)), cfg.winSec = double(stdStep.tempWinSec); else, cfg.winSec = 60; end
            cfg.nsub = []; cfg.blockMethod = 'mean';
        end
        cfg.chunkVoxels = 50000;
        addLog(sprintf('[Standardized] Temporal no-dialog: mode=%s | win=%.6g s',cfg.mode,cfg.winSec));
    else
        cfg = showTemporalSmoothSubsampleDialog(data);
    end

    if isempty(cfg) || ~isstruct(cfg) || ...
            ~isfield(cfg,'cancelled') || cfg.cancelled
        addLog('Temporal smoothing/subsampling cancelled.');
        return;
    end

    setProgramStatus(false);
    drawnow;

    try
        opts = struct();
        opts.chunkVoxels = cfg.chunkVoxels;
        opts.logFcn = [];

        newData = data;
        ts = datestr(now,'yyyymmdd_HHMMSS');
        baseStem = getCurrentNamingStem(studio);

        % =====================================================
        % MODE 1: SLIDING TEMPORAL SMOOTHING
        % =====================================================
        if strcmpi(cfg.mode,'sliding')

            winSec = cfg.winSec;

            opts.mode = 'sliding';
            opts.blockMethod = 'mean';

            addLog(sprintf(['Running temporal smoothing: sliding moving average | ' ...
                'window %.6g s | TR %.6g s'], winSec, data.TR));

            [Iout, stats] = temporalsmoothing(data.I, data.TR, winSec, opts);

            newData.I = single(Iout);
            newData.TR = stats.TRout;
            newData.nVols = stats.nVolsOut;
            newData.TotalTimeSec = stats.nVolsOut * stats.TRout;
            newData.TotalTimeMin = newData.TotalTimeSec / 60;
            newData.totalTime = newData.TotalTimeSec;
            newData.totalTimeMin = newData.TotalTimeMin;

            newData.temporalSmoothing = stats;
            newData.preprocessing = sprintf( ...
                'Temporal smoothing (sliding moving average, %.6g s)', ...
                stats.winSec);

            % avoid stale PSC/bg from older dataset version
            if isfield(newData,'PSC'), newData.PSC = []; end
            if isfield(newData,'bg'),  newData.bg  = []; end

            secTag = numTag(winSec);

            fullName = sprintf('%s_temporalSmooth_%ss_%s', ...
                baseStem, secTag, ts);

            addLog(sprintf(['Temporal smoothing complete: %.6g s window, ' ...
                '%d volumes/window, nVols %d -> %d, runtime %.2f s'], ...
                stats.winSec, stats.winVol, ...
                stats.nVolsIn, stats.nVolsOut, stats.runtimeSec));

        % =====================================================
        % MODE 2: BLOCK AVERAGING / SUBSAMPLING
        % =====================================================
        else

            nsub = cfg.nsub;
            winSec = nsub * data.TR;

            opts.mode = 'block';
            opts.blockMethod = lower(strtrim(cfg.blockMethod));

            addLog(sprintf(['Running subsampling: %s block averaging | ' ...
                'n = %d frames/block | block %.6g s | input TR %.6g s'], ...
                upper(opts.blockMethod), nsub, winSec, data.TR));

            [Iout, stats] = temporalsmoothing(data.I, data.TR, winSec, opts);

            % Correct output timing after discarded tail frames
            outTotalSec = stats.nVolsOut * stats.TRout;
            stats.totalTimeOutSec = outTotalSec;
            stats.totalTimeOutMin = outTotalSec / 60;

            newData.I = single(Iout);
            newData.TR = stats.TRout;
            newData.nVols = stats.nVolsOut;
            newData.TotalTimeSec = outTotalSec;
            newData.TotalTimeMin = outTotalSec / 60;
            newData.totalTime = newData.TotalTimeSec;
            newData.totalTimeMin = newData.TotalTimeMin;

            newData.temporalSmoothing = stats;
            newData.subsampling = stats;
            newData.preprocessing = sprintf('Subsampling (%s, n=%d)', ...
                upper(stats.blockMethod), stats.winVol);

            % avoid stale PSC/bg from older dataset version
            if isfield(newData,'PSC'), newData.PSC = []; end
            if isfield(newData,'bg'),  newData.bg  = []; end

            fullName = sprintf('%s_subsample_%s_nsub%d_%s', ...
                baseStem, lower(stats.blockMethod), stats.winVol, ts);

            addLog(sprintf(['Subsampling complete: %s, n=%d frames/block, ' ...
                'TR %.6g -> %.6g s, nVols %d -> %d, discarded tail = %d, ' ...
                'runtime %.2f s'], ...
                upper(stats.blockMethod), stats.winVol, ...
                stats.TR, stats.TRout, ...
                stats.nVolsIn, stats.nVolsOut, ...
                stats.nDiscardedTailVolumes, stats.runtimeSec));
        end

        % -----------------------------------------------------
        % Save as new active dataset
        % -----------------------------------------------------
        keyName = makeSafeKey(fullName, studio.datasets);

        newData.displayNameFull = fullName;
        newData.preprocDisplayName = fullName;
        newData.HUMOR_fullDisplayName = fullName;
        try, newData.displayNameShort = deConfUSIon_display_short_name(fullName,newData,''); catch, newData.displayNameShort = fullName; end
        newData.datasetSortTime = now;
        newData.sourceDatasetKey = studio.activeDataset;

        studio.datasets.(keyName) = newData;
        studio.activeDataset = keyName;
        studio.pipeline.preprocDone = true;

        preFolder = fullfile(studio.exportPath,'Preprocessing');

                savePath = deConfUSIon_safe_preproc_save_path(preFolder, fullName, keyName, 'tsmooth');
        newData.savedFile = savePath;
        newData.lazyFile = savePath;
        displayNameFull = fullName;
                preprocDisplayName = fullName;
                try, datasetSortTime = newData.datasetSortTime; catch, datasetSortTime = now; end
                studio.datasets.(keyName) = newData;
        DataIO('save',savePath,struct('newData',newData,'displayNameFull',displayNameFull,'preprocDisplayName',preprocDisplayName,'datasetSortTime',datasetSortTime));
        addLog(['Saved and verified -> ' savePath]);

        guidata(fig, studio);
        refreshDatasetDropdown();

        addLog(['Saved dataset -> ' fullName]);

    catch ME
        addLog(['TEMPORAL / SUBSAMPLING ERROR: ' ME.message]);
        errordlg(ME.message,'Temporal Interpolation failed');
    end

    setProgramStatus(true);
end
%% =========================================================
%  MODERN TEMPORAL SMOOTHING / SUBSAMPLING POPUP
% =========================================================
function cfg = showTemporalSmoothSubsampleDialog(data)

    cfg = struct();
    cfg.cancelled = true;

    TR = double(data.TR);
    T = size(data.I, ndims(data.I));

    % ---------------- defaults ----------------
    defaultMode = 1;          % 1 = sliding, 2 = block/subsample
    defaultWinSec = 60;       % temporal smoothing default
    defaultNsub = min(50, max(1, T));   % subsampling default, clamped for short scans
    defaultMethod = 1;        % 1 = mean, 2 = median
    defaultChunk = 50000;

    % ---------------- colors ----------------
    bg      = [0.045 0.045 0.050];
    panel   = [0.085 0.085 0.095];
    panel2  = [0.115 0.115 0.130];
    fg      = [0.96 0.96 0.96];
    fgDim   = [0.72 0.72 0.76];
    blue    = [0.20 0.48 0.95];
    green   = [0.15 0.68 0.35];
    orange  = [0.95 0.55 0.18];
    red     = [0.80 0.25 0.25];

    % ---------------- figure ----------------
    dlg = figure( ...
        'Name','Temporal Interpolation', ...
        'Color',bg, ...
        'MenuBar','none', ...
        'ToolBar','none', ...
        'NumberTitle','off', ...
        'Resize','off', ...
        'Units','pixels', ...
        'Position',[35 40 1600 940],   ...
        'WindowStyle','modal', ...
        'Visible','off', ...
        'CloseRequestFcn',@onCancel);
try, deConfUSIon_popup_polish_now(gcf); catch, end


    try
        movegui(dlg,'center');
    catch
    end

    % ---------------- title ----------------
    uicontrol('Parent',dlg,'Style','text', ...
        'Units','normalized', ...
        'Position',[0.045 0.915 0.91 0.06], ...
        'String','Temporal Interpolation', ...
        'BackgroundColor',bg, ...
        'ForegroundColor',fg, ...
        'FontName','Helvetica', ...
        'FontSize',20, ...
        'FontWeight','bold', ...
        'HorizontalAlignment','left');

    uicontrol('Parent',dlg,'Style','text', ...
        'Units','normalized', ...
        'Position',[0.047 0.865 0.91 0.04], ...
        'String','Choose one operation and confirm all settings in this single popup.', ...
        'BackgroundColor',bg, ...
        'ForegroundColor',fgDim, ...
        'FontName','Helvetica', ...
        'FontSize',16, ...
        'HorizontalAlignment','left');

    % ---------------- dataset info panel ----------------
    infoPanel = uipanel('Parent',dlg, ...
        'Units','normalized', ...
        'Position',[0.045 0.755 0.91 0.095], ...
        'BackgroundColor',panel, ...
        'ForegroundColor',fg, ...
        'BorderType','line', ...
        'HighlightColor',[0.30 0.30 0.34], ...
        'ShadowColor',[0.02 0.02 0.02]);

    infoStr = sprintf('Input: %d volumes     TR: %.6g s     Total time: %.2f min', ...
        T, TR, (T*TR)/60);

    uicontrol('Parent',infoPanel,'Style','text', ...
        'Units','normalized', ...
        'Position',[0.035 0.20 0.93 0.60], ...
        'String',infoStr, ...
        'BackgroundColor',panel, ...
        'ForegroundColor',[0.75 0.88 1.00], ...
        'FontName','Helvetica', ...
        'FontSize',13, ...
        'FontWeight','bold', ...
        'HorizontalAlignment','left');

    % ---------------- settings panel ----------------
    settingsPanel = uipanel('Parent',dlg, ...
        'Units','normalized', ...
        'Position',[0.045 0.235 0.91 0.50], ...
        'BackgroundColor',panel, ...
        'ForegroundColor',fg, ...
        'BorderType','line', ...
        'HighlightColor',[0.30 0.30 0.34], ...
        'ShadowColor',[0.02 0.02 0.02]);

    % operation
    uicontrol('Parent',settingsPanel,'Style','text', ...
        'Units','normalized', ...
        'Position',[0.045 0.835 0.28 0.07], ...
        'String','Operation', ...
        'BackgroundColor',panel, ...
        'ForegroundColor',fg, ...
        'FontName','Helvetica', ...
        'FontSize',16, ...
        'FontWeight','bold', ...
        'HorizontalAlignment','left');

    modePopup = uicontrol('Parent',settingsPanel,'Style','popupmenu', ...
        'Units','normalized', ...
        'Position',[0.35 0.83 0.58 0.08], ...
        'String',{ ...
            'Sliding temporal smoothing  -  same number of volumes', ...
            'Block averaging / subsampling  -  fewer volumes, larger TR'}, ...
        'Value',defaultMode, ...
        'BackgroundColor',panel2, ...
        'ForegroundColor',fg, ...
        'FontName','Helvetica', ...
        'FontSize',16, ...
        'Callback',@updateSummary);

    % smoothing window
    uicontrol('Parent',settingsPanel,'Style','text', ...
        'Units','normalized', ...
        'Position',[0.045 0.685 0.28 0.07], ...
        'String','Smoothing window', ...
        'BackgroundColor',panel, ...
        'ForegroundColor',fg, ...
        'FontName','Helvetica', ...
        'FontSize',16, ...
        'FontWeight','bold', ...
        'HorizontalAlignment','left');

    winSecEdit = uicontrol('Parent',settingsPanel,'Style','edit', ...
        'Units','normalized', ...
        'Position',[0.35 0.69 0.20 0.075], ...
        'String',num2str(defaultWinSec), ...
        'BackgroundColor',[0.02 0.02 0.025], ...
        'ForegroundColor',fg, ...
        'FontName','Helvetica', ...
        'FontSize',16, ...
        'FontWeight','bold', ...
        'HorizontalAlignment','center', ...
        'Callback',@updateSummary);

    uicontrol('Parent',settingsPanel,'Style','text', ...
        'Units','normalized', ...
        'Position',[0.57 0.685 0.30 0.07], ...
        'String','seconds  (sliding mode)', ...
        'BackgroundColor',panel, ...
        'ForegroundColor',fgDim, ...
        'FontName','Helvetica', ...
        'FontSize',11, ...
        'HorizontalAlignment','left');

    % subsampling n
    uicontrol('Parent',settingsPanel,'Style','text', ...
        'Units','normalized', ...
        'Position',[0.045 0.535 0.28 0.07], ...
        'String','Subsampling factor', ...
        'BackgroundColor',panel, ...
        'ForegroundColor',fg, ...
        'FontName','Helvetica', ...
        'FontSize',16, ...
        'FontWeight','bold', ...
        'HorizontalAlignment','left');

    nsubEdit = uicontrol('Parent',settingsPanel,'Style','edit', ...
        'Units','normalized', ...
        'Position',[0.35 0.54 0.20 0.075], ...
        'String',num2str(defaultNsub), ...
        'BackgroundColor',[0.02 0.02 0.025], ...
        'ForegroundColor',fg, ...
        'FontName','Helvetica', ...
        'FontSize',16, ...
        'FontWeight','bold', ...
        'HorizontalAlignment','center', ...
        'Callback',@updateSummary);

    uicontrol('Parent',settingsPanel,'Style','text', ...
        'Units','normalized', ...
        'Position',[0.57 0.535 0.34 0.07], ...
        'String','frames/block  (subsampling mode)', ...
        'BackgroundColor',panel, ...
        'ForegroundColor',fgDim, ...
        'FontName','Helvetica', ...
        'FontSize',11, ...
        'HorizontalAlignment','left');

    % block method
    uicontrol('Parent',settingsPanel,'Style','text', ...
        'Units','normalized', ...
        'Position',[0.045 0.385 0.28 0.07], ...
        'String','Block method', ...
        'BackgroundColor',panel, ...
        'ForegroundColor',fg, ...
        'FontName','Helvetica', ...
        'FontSize',16, ...
        'FontWeight','bold', ...
        'HorizontalAlignment','left');

    methodPopup = uicontrol('Parent',settingsPanel,'Style','popupmenu', ...
        'Units','normalized', ...
        'Position',[0.35 0.39 0.25 0.075], ...
        'String',{'Mean','Median'}, ...
        'Value',defaultMethod, ...
        'BackgroundColor',panel2, ...
        'ForegroundColor',fg, ...
        'FontName','Helvetica', ...
        'FontSize',16, ...
        'Callback',@updateSummary);

    uicontrol('Parent',settingsPanel,'Style','text', ...
        'Units','normalized', ...
        'Position',[0.62 0.385 0.30 0.07], ...
        'String','Mean is recommended default', ...
        'BackgroundColor',panel, ...
        'ForegroundColor',fgDim, ...
        'FontName','Helvetica', ...
        'FontSize',11, ...
        'HorizontalAlignment','left');

    % chunk voxels
    uicontrol('Parent',settingsPanel,'Style','text', ...
        'Units','normalized', ...
        'Position',[0.045 0.235 0.28 0.07], ...
        'String','Memory chunk', ...
        'BackgroundColor',panel, ...
        'ForegroundColor',fg, ...
        'FontName','Helvetica', ...
        'FontSize',16, ...
        'FontWeight','bold', ...
        'HorizontalAlignment','left');

    chunkEdit = uicontrol('Parent',settingsPanel,'Style','edit', ...
        'Units','normalized', ...
        'Position',[0.35 0.24 0.20 0.075], ...
        'String',num2str(defaultChunk), ...
        'BackgroundColor',[0.02 0.02 0.025], ...
        'ForegroundColor',fg, ...
        'FontName','Helvetica', ...
        'FontSize',16, ...
        'FontWeight','bold', ...
        'HorizontalAlignment','center', ...
        'Callback',@updateSummary);

    uicontrol('Parent',settingsPanel,'Style','text', ...
        'Units','normalized', ...
        'Position',[0.57 0.235 0.34 0.07], ...
        'String','voxels/chunk  (keep default unless RAM issue)', ...
        'BackgroundColor',panel, ...
        'ForegroundColor',fgDim, ...
        'FontName','Helvetica', ...
        'FontSize',11, ...
        'HorizontalAlignment','left');

    % preset buttons
    uicontrol('Parent',settingsPanel,'Style','pushbutton', ...
        'Units','normalized', ...
        'Position',[0.045 0.065 0.25 0.085], ...
        'String','Preset: Smooth 60 s', ...
        'BackgroundColor',blue, ...
        'ForegroundColor','w', ...
        'FontName','Helvetica', ...
        'FontSize',11, ...
        'FontWeight','bold', ...
        'Callback',@presetSmooth);

    uicontrol('Parent',settingsPanel,'Style','pushbutton', ...
        'Units','normalized', ...
        'Position',[0.32 0.065 0.25 0.085], ...
        'String','Preset: Subsample n=50', ...
        'BackgroundColor',orange, ...
        'ForegroundColor','w', ...
        'FontName','Helvetica', ...
        'FontSize',11, ...
        'FontWeight','bold', ...
        'Callback',@presetSubsample);

    uicontrol('Parent',settingsPanel,'Style','pushbutton', ...
        'Units','normalized', ...
        'Position',[0.595 0.065 0.25 0.085], ...
        'String','Reset Defaults', ...
        'BackgroundColor',[0.30 0.30 0.34], ...
        'ForegroundColor','w', ...
        'FontName','Helvetica', ...
        'FontSize',11, ...
        'FontWeight','bold', ...
        'Callback',@presetDefaults);

    % ---------------- summary panel ----------------
    summaryPanel = uipanel('Parent',dlg, ...
        'Units','normalized', ...
        'Position',[0.045 0.115 0.91 0.10], ...
        'BackgroundColor',[0.035 0.035 0.040], ...
        'ForegroundColor',fg, ...
        'BorderType','line', ...
        'HighlightColor',[0.25 0.25 0.28], ...
        'ShadowColor',[0.01 0.01 0.01]);

    summaryText = uicontrol('Parent',summaryPanel,'Style','text', ...
        'Units','normalized', ...
        'Position',[0.025 0.12 0.95 0.76], ...
        'String','', ...
        'BackgroundColor',[0.035 0.035 0.040], ...
        'ForegroundColor',[0.70 1.00 0.80], ...
        'FontName','Helvetica', ...
        'FontSize',16, ...
        'FontWeight','bold', ...
        'HorizontalAlignment','left');

    % ---------------- bottom buttons ----------------
    uicontrol('Parent',dlg,'Style','pushbutton', ...
        'Units','normalized', ...
        'Position',[0.56 0.035 0.22 0.06], ...
        'String','RUN PROCESSING', ...
        'BackgroundColor',green, ...
        'ForegroundColor','w', ...
        'FontName','Helvetica', ...
        'FontSize',13, ...
        'FontWeight','bold', ...
        'Callback',@onRun);

    uicontrol('Parent',dlg,'Style','pushbutton', ...
        'Units','normalized', ...
        'Position',[0.80 0.035 0.155 0.06], ...
        'String','CANCEL', ...
        'BackgroundColor',red, ...
        'ForegroundColor','w', ...
        'FontName','Helvetica', ...
        'FontSize',13, ...
        'FontWeight','bold', ...
        'Callback',@onCancel);

    updateSummary();

    set(dlg,'Visible','on');
    try, deConfUSIon_popup_autofit_apply(dlg); catch, end
try, deConfUSIon_fix_scm_video_dialog_fonts(dlg); catch, end % HUMOR_V27_SCM_VIDEO_FONT_FIX
waitfor(dlg);

    % =====================================================
    % Nested callbacks
    % =====================================================
    function updateSummary(~,~)

        modeVal = get(modePopup,'Value');

        winSec = str2double(get(winSecEdit,'String'));
        nsub = str2double(get(nsubEdit,'String'));
        chunkVox = str2double(get(chunkEdit,'String'));

        if ~isfinite(winSec) || winSec <= 0
            winSecTxt = 'invalid';
            winVol = NaN;
        else
            winVol = max(1, round(winSec / TR));
            winSecTxt = sprintf('%.6g s = %d frames', winSec, winVol);
        end

        if ~isfinite(nsub) || nsub < 1
            nsubTxt = 'invalid';
            outTR = NaN;
            outVols = NaN;
            discard = NaN;
        else
            nsub = min(round(nsub), max(1,T));
            outTR = nsub * TR;
            outVols = floor(T / nsub);
            discard = T - outVols * nsub;
            nsubTxt = sprintf('%d frames/block = %.6g s/block', nsub, outTR);
        end

        if ~isfinite(chunkVox) || chunkVox < 1
            chunkTxt = 'invalid';
        else
            chunkTxt = sprintf('%d voxels/chunk', round(chunkVox));
        end

        if modeVal == 1
            txt = sprintf(['SLIDING SMOOTHING selected | Window: %s | ' ...
                'Output: same TR %.6g s, same %d volumes | Chunk: %s'], ...
                winSecTxt, TR, T, chunkTxt);
        else
            methodList = get(methodPopup,'String');
            methodName = methodList{get(methodPopup,'Value')};
            txt = sprintf(['SUBSAMPLING selected | %s | Method: %s | ' ...
                'Output TR: %.6g s | Output volumes: %d | Discard tail: %d | Chunk: %s'], ...
                nsubTxt, upper(methodName), outTR, outVols, discard, chunkTxt);
        end

        if ishandle(summaryText)
            set(summaryText,'String',txt);
        end
    end

    function presetSmooth(~,~)
        set(modePopup,'Value',1);
        set(winSecEdit,'String','60');
        set(nsubEdit,'String',num2str(defaultNsub));
        set(methodPopup,'Value',1);
        set(chunkEdit,'String','50000');
        updateSummary();
    end

    function presetSubsample(~,~)
        set(modePopup,'Value',2);
        set(winSecEdit,'String','60');
        set(nsubEdit,'String',num2str(defaultNsub));
        set(methodPopup,'Value',1);
        set(chunkEdit,'String','50000');
        updateSummary();
    end

    function presetDefaults(~,~)
        set(modePopup,'Value',defaultMode);
        set(winSecEdit,'String',num2str(defaultWinSec));
        set(nsubEdit,'String',num2str(defaultNsub));
        set(methodPopup,'Value',defaultMethod);
        set(chunkEdit,'String',num2str(defaultChunk));
        updateSummary();
    end

    function onRun(~,~)

        modeVal = get(modePopup,'Value');

        winSec = str2double(get(winSecEdit,'String'));
        nsub = str2double(get(nsubEdit,'String'));
        chunkVox = str2double(get(chunkEdit,'String'));

        if ~isfinite(chunkVox) || chunkVox < 1
            uiwait(errordlg('Memory chunk must be a positive number.', ...
                'Invalid setting','modal'));
            return;
        end

        if modeVal == 1
            if ~isfinite(winSec) || winSec <= 0
                uiwait(errordlg('Smoothing window must be > 0 seconds.', ...
                    'Invalid smoothing window','modal'));
                return;
            end

            cfg.cancelled = false;
            cfg.mode = 'sliding';
            cfg.winSec = winSec;
            cfg.nsub = [];
            cfg.blockMethod = 'mean';
            cfg.chunkVoxels = round(chunkVox);

        else
            if ~isfinite(nsub) || nsub < 1
                uiwait(errordlg('Subsampling factor must be >= 1 frame.', ...
                    'Invalid subsampling factor','modal'));
                return;
            end

            nsub = min(round(nsub), max(1,T));
            set(nsubEdit,'String',num2str(nsub));
            updateSummary();

            methodList = get(methodPopup,'String');
            methodName = lower(methodList{get(methodPopup,'Value')});

            cfg.cancelled = false;
            cfg.mode = 'block';
            cfg.winSec = nsub * TR;
            cfg.nsub = nsub;
            cfg.blockMethod = methodName;
            cfg.chunkVoxels = round(chunkVox);
        end

        if ishghandle(dlg)
            delete(dlg);
        end
    end

    function onCancel(~,~)
        cfg.cancelled = true;
        if ishghandle(dlg)
            delete(dlg);
        end
    end
end
%% =========================================================
%  PCA / ICA
% =========================================================
function pcaCallback(~,~)

    studio = guidata(fig);
    if ~studio.isLoaded
        errordlg('Load data first.');
        return;
    end

    % DECONF_STD_PCAICA_METHOD_V71
    stdStep = [];
    try
        if isappdata(0,'deconf_std_workflow_step'), stdStep = getappdata(0,'deconf_std_workflow_step'); end
        if isempty(stdStep) && exist('fig','var') && ishghandle(fig) && isappdata(fig,'deconf_std_workflow_step'), stdStep = getappdata(fig,'deconf_std_workflow_step'); end
    catch
    end
    if isstruct(stdStep) && isfield(stdStep,'name') && strcmpi(strtrim(stdStep.name),'PCA / ICA')
        if isfield(stdStep,'pcaicaMethod') && round(double(stdStep.pcaicaMethod)) == 2
            methodChoice = 'ICA';
        else
            methodChoice = 'PCA';
        end
        addLog(['[Standardized] PCA/ICA method selected without method popup: ' methodChoice]);
    else
        methodChoice = showPcaIcaMethodDialog();
    end
    if isempty(methodChoice) || strcmpi(methodChoice,'Cancel')
        addLog('PCA / ICA cancelled.');
        return;
    end

    data = getActiveData();
    ts = datestr(now,'yyyymmdd_HHMMSS');
    setProgramStatus(false);
    drawnow;

    try
        switch upper(strtrim(methodChoice))
            case 'PCA'
                addLog('Running PCA denoising... (select PCs to remove)');
                opts = struct();
                opts.nCompMax = 50;
% DECONF_STD_PCA_NCOMP_V71
try
    if exist('stdStep','var') && isstruct(stdStep) && isfield(stdStep,'pcaNcomp') && isfinite(double(stdStep.pcaNcomp))
        opts.nCompMax = max(1,round(double(stdStep.pcaNcomp)));
    end
catch
end
                opts.maxDisplayPoints = 2000;
                opts.chunkT = 250;
                opts.centerMode = 'voxel';
% DECONF_OPTA_V1 : standardized Option A auto component removal
try
    if exist('stdStep','var') && isstruct(stdStep) && isfield(stdStep,'name') && strcmpi(strtrim(stdStep.name),'PCA / ICA')
        if isfield(stdStep,'pcaDropPC') && isfinite(double(stdStep.pcaDropPC))
            opts.autoSelect = max(1,round(double(stdStep.pcaDropPC)));
        end
        if isfield(stdStep,'pcaAutoApply') && isfinite(double(stdStep.pcaAutoApply))
            opts.autoApply = (round(double(stdStep.pcaAutoApply)) == 1);
        end
        opts.logFcn = @(msg) addLog(msg);
        if isfield(opts,'autoSelect') && ~isempty(opts.autoSelect) && isfield(opts,'autoApply') && opts.autoApply
            addLog(sprintf('[Standardized] PCA: removing PC%s over all slices, no manual selection.',sprintf(' %d',opts.autoSelect)));
        end
    end
catch
end
                opts.onApply = @(sel) decomp_onApply('PCA', sel);
                opts.onCancel = @() decomp_onCancel('PCA');
                [newData, stats] = pca_denoise(data, studio.exportPath, ['pca_' ts], opts);
                if ~isfield(stats,'applied') || ~stats.applied
                    setProgramStatus(true);
                    return;
                end
                baseStem = deConfUSIon_compact_chain_name(getCurrentNamingStem(studio));
                pcTag = 'dropPCunknown';
                if isfield(stats,'selectedComponents') && ~isempty(stats.selectedComponents)
                    pcTag = makePcDropTag(stats.selectedComponents);
                end
                scopeTag = '';
                if isfield(stats,'sliceScope')
                    scopeTag = deConfUSIon_utils('deConfUSIon_pcaica_scope_tag',stats.sliceScope);
                end
                if isempty(scopeTag)
                    fullName = sprintf('%s_pca_%s_%s', baseStem, pcTag, ts);
                else
                    fullName = sprintf('%s_%s_pca_%s_%s', baseStem, scopeTag, pcTag, ts);
                end
                keyName = makeSafeKey(fullName, studio.datasets);
                newData.preprocessing = 'PCA denoising';
                newData.displayNameFull = fullName;
                newData.preprocDisplayName = fullName;
                newData.HUMOR_fullDisplayName = fullName;
                try, newData.displayNameShort = deConfUSIon_display_short_name(fullName,newData,''); catch, newData.displayNameShort = fullName; end
        newData.preprocDisplayName = fullName;
        newData.HUMOR_fullDisplayName = fullName;
        try, newData.displayNameShort = deConfUSIon_display_short_name(fullName,newData,''); catch, newData.displayNameShort = fullName; end
        newData.datasetSortTime = now;
        newData.sourceDatasetKey = studio.activeDataset;
                newData.pcaStats = stats;
                datasetSortTime = now;
                newData.datasetSortTime = datasetSortTime;
                preFolder = fullfile(studio.exportPath,'Preprocessing');
                savePath = deConfUSIon_safe_preproc_save_path(preFolder, fullName, keyName, 'pca');
                newData.savedFile = savePath;
                newData.lazyFile = savePath;
                displayNameFull = fullName;
                preprocDisplayName = fullName;
                try, datasetSortTime = newData.datasetSortTime; catch, datasetSortTime = now; end
                studio.datasets.(keyName) = newData;
                studio.activeDataset = keyName;
                studio.pipeline.preprocDone = true;
                studio=studioSaveDataset(fig,studio,keyName);
                addLog(['Saved and verified -> ' savePath]);
                guidata(fig, studio);
                refreshDatasetDropdown();
                if isfield(stats,'percentExplainedRemoved'), addLog(sprintf('PCA removed %.2f%% variance proxy.', stats.percentExplainedRemoved)); end
                if isfield(stats,'selectedComponents') && ~isempty(stats.selectedComponents), addLog(['Dropped PCs: ' sprintf('%d ', stats.selectedComponents)]); end
                addLog(['PCA complete -> ' fullName]);

            case 'ICA'
                addLog('Running ICA denoising... (compute ICs, then select ICs to remove)');
                opts = struct();
                opts.nCompMax = 30;
% DECONF_STD_ICA_NCOMP_V71
try
    if exist('stdStep','var') && isstruct(stdStep) && isfield(stdStep,'icaNcomp') && isfinite(double(stdStep.icaNcomp))
        opts.nCompMax = max(1,round(double(stdStep.icaNcomp)));
    end
catch
end
                opts.maxDisplayPoints = 2000;
                opts.chunkT = 250;
                opts.centerMode = 'voxel';
                opts.icaMaxIter = 400;
                opts.icaTol = 1e-5;
                opts.verbose = true;
                opts.onApply = @(sel) decomp_onApply('ICA', sel);
                opts.onCancel = @() decomp_onCancel('ICA');
                [newData, stats] = ica_denoise(data, studio.exportPath, ['ica_' ts], opts);
                if ~isfield(stats,'applied') || ~stats.applied
                    setProgramStatus(true);
                    return;
                end
                baseStem = deConfUSIon_compact_chain_name(getCurrentNamingStem(studio));
                icTag = 'dropICunknown';
                if isfield(stats,'selectedComponents') && ~isempty(stats.selectedComponents)
                    icTag = makeIcDropTag(stats.selectedComponents);
                end
                scopeTag = '';
                if isfield(stats,'sliceScope')
                    scopeTag = deConfUSIon_utils('deConfUSIon_pcaica_scope_tag',stats.sliceScope);
                end
                if isempty(scopeTag)
                    fullName = sprintf('%s_ica_%s_%s', baseStem, icTag, ts);
                else
                    fullName = sprintf('%s_%s_ica_%s_%s', baseStem, scopeTag, icTag, ts);
                end
                keyName = makeSafeKey(fullName, studio.datasets);
                newData.preprocessing = 'ICA denoising';
                newData.displayNameFull = fullName;
                newData.preprocDisplayName = fullName;
                newData.HUMOR_fullDisplayName = fullName;
                try, newData.displayNameShort = deConfUSIon_display_short_name(fullName,newData,''); catch, newData.displayNameShort = fullName; end
        newData.preprocDisplayName = fullName;
        newData.HUMOR_fullDisplayName = fullName;
        try, newData.displayNameShort = deConfUSIon_display_short_name(fullName,newData,''); catch, newData.displayNameShort = fullName; end
        newData.datasetSortTime = now;
        newData.sourceDatasetKey = studio.activeDataset;
                newData.icaStats = stats;
                datasetSortTime = now;
                newData.datasetSortTime = datasetSortTime;
                preFolder = fullfile(studio.exportPath,'Preprocessing');
                savePath = deConfUSIon_safe_preproc_save_path(preFolder, fullName, keyName, 'ica');
                newData.savedFile = savePath;
                newData.lazyFile = savePath;
                displayNameFull = fullName;
                preprocDisplayName = fullName;
                try, datasetSortTime = newData.datasetSortTime; catch, datasetSortTime = now; end
                studio.datasets.(keyName) = newData;
                studio.activeDataset = keyName;
                studio.pipeline.preprocDone = true;
                studio=studioSaveDataset(fig,studio,keyName);
                addLog(['Saved and verified -> ' savePath]);
                guidata(fig, studio);
                refreshDatasetDropdown();
                if isfield(stats,'percentEnergyRemoved'), addLog(sprintf('ICA removed %.2f%% component-energy proxy.', stats.percentEnergyRemoved)); end
                if isfield(stats,'selectedComponents') && ~isempty(stats.selectedComponents), addLog(['Dropped ICs: ' sprintf('%d ', stats.selectedComponents)]); end
                if isfield(stats,'converged')
                    if stats.converged, addLog(sprintf('ICA converged in %d iterations.', stats.nIter)); else, addLog(sprintf('ICA warning: did not fully converge in %d iterations.', stats.nIter)); end
                end
                addLog(['ICA complete -> ' fullName]);

            otherwise
                addLog('PCA / ICA cancelled.');
                setProgramStatus(true);
                return;
        end
    catch ME
        refreshDatasetDropdown();
        addLog(['PCA / ICA ERROR: ' ME.message]);
        errordlg(ME.message,'PCA / ICA Failure');
    end
    setProgramStatus(true);

    function decomp_onApply(methodName, sel)
        if isempty(sel)
            addLog([methodName ' applied: no components selected. Please wait...']);
        else
            sel = unique(sel(:)');
            if strcmpi(methodName,'PCA'), compName = 'PCs'; else, compName = 'ICs'; end
            addLog([methodName ' applied, dropping ' compName ': ' sprintf('%d ', sel) ' - please wait...']);
        end
        drawnow;
    end

    function decomp_onCancel(methodName)
        addLog([methodName ' cancelled.']);
        setProgramStatus(true);
        drawnow;
    end
end

%% =========================================================
%  PSC COMPUTATION
% =========================================================
function computePSCCallback(~,~)

    studio = guidata(fig);

    if ~studio.isLoaded
        errordlg('Load data first.');
        return;
    end

    data = getActiveData();

    baseline.start = 0;
    baseline.end = min(5, data.nVols * data.TR);
    baseline.mode = 'sec';

    par = struct();
    par.interpol = 1;
    par.LPF = 0.15;
    par.HPF = 0;
    par.gaussSize = 3;
    par.gaussSig = 0.5;

    addLog('Computing PSC...');
    setProgramStatus(false);
    drawnow;

    try
        proc = computePSC(data.I, data.TR, par, baseline);

        newData = data;
        % This is an explicitly requested PSC analysis, not a viewer cache.
        % Drop cache ownership markers so durable saving retains its PSC.
        newData=rmfield(newData,intersect(fieldnames(newData),{'deconfPscKey','deconfPscDatasetKey','I1'}));
        newData.PSC = single(proc.PSC);
        newData.bg = single(proc.bg);
        if isfield(proc,'TR_eff')
            newData.TR_eff = proc.TR_eff;
        end
        if isfield(proc,'nFrames')
            newData.nFrames = proc.nFrames;
        end

        P = studio_resolve_paths(studio, studio.activeDataset, studio.exportPath);
        baseStem = P.fileStem;
        fullName = [baseStem '_psc_' datestr(now,'yyyymmdd_HHMMSS')];
        keyName = makeSafeKey(fullName, studio.datasets);

        newData.displayNameFull = fullName;
        newData.preprocDisplayName = fullName;
        newData.HUMOR_fullDisplayName = fullName;
        try, newData.displayNameShort = deConfUSIon_display_short_name(fullName,newData,''); catch, newData.displayNameShort = fullName; end
        newData.datasetSortTime = now;
        newData.sourceDatasetKey = studio.activeDataset;

        pscFolder = fullfile(studio.exportPath,'PSC');
        savePath=deConfUSIon_safe_preproc_save_path(pscFolder,fullName,keyName,'psc');
        newData.savedFile=savePath; newData.lazyFile=savePath;
        newData.isLazy=false;
        newData.pscParameters=struct('baseline',baseline,'filtering',par);
        DataIO('save',savePath,struct('newData',newData));
        studio.datasets.(keyName) = newData;
        studio.activeDataset = keyName;
        studio.pipeline.pscDone = true;

        guidata(fig, studio);
        refreshDatasetDropdown();

        addLog(['PSC saved and verified -> ' savePath]);

    catch ME
        addLog(['PSC ERROR: ' ME.message]);
        errordlg(ME.message,'PSC Failure');
    end

    setProgramStatus(true);
end

%% =========================================================
%  FILTERING
% =========================================================
function filteringCallback(~,~)

    studio = guidata(fig);

    if ~studio.isLoaded
        errordlg('Load data first.','Filtering');
        return;
    end

    data = getActiveData();

    if ~isstruct(data) || ~isfield(data,'I') || isempty(data.I)
        errordlg('Active dataset has no data.I field.','Filtering');
        return;
    end

    % One clean dark setup window.
    % DECONF_STD_FILTER_CFG_V61
    stdStep = [];
    try
        if isappdata(fig,'deconf_std_workflow_step')
            tmpStd = getappdata(fig,'deconf_std_workflow_step');
            if isstruct(tmpStd) && isfield(tmpStd,'name') && strcmpi(strtrim(tmpStd.name),'Filtering')
                stdStep = tmpStd;
            end
        end
    catch
    end
    if ~isempty(stdStep)
        opts = struct();
        ft = 1;
        if isfield(stdStep,'filterType') && isfinite(double(stdStep.filterType)), ft = round(double(stdStep.filterType)); end
        if ft == 2
            opts.type = 'low';
        elseif ft == 3
            opts.type = 'high';
        elseif ft == 4
            opts.type = 'stop';
        else
            opts.type = 'band';
        end
        opts.FcLow = 0.001; opts.FcHigh = 0.20; opts.order = 4;
        if isfield(stdStep,'fcLow') && isfinite(double(stdStep.fcLow)), opts.FcLow = double(stdStep.fcLow); end
        if isfield(stdStep,'fcHigh') && isfinite(double(stdStep.fcHigh)), opts.FcHigh = double(stdStep.fcHigh); end
        if isfield(stdStep,'filterOrder') && isfinite(double(stdStep.filterOrder)), opts.order = round(double(stdStep.filterOrder)); end
        opts.trimStart = 0; opts.trimEnd = 0; opts.useTaper = true; opts.saveQC = true; opts.chunkSize = 50000; opts.cancelled = false;
        if strcmpi(opts.type,'low'), opts.FcLow = 0; end
        if strcmpi(opts.type,'high'), opts.FcHigh = 0; end
        addLog(sprintf('[Standardized] Filtering: %s | low=%.6g | high=%.6g | order=%d',opts.type,opts.FcLow,opts.FcHigh,opts.order));
    else
        % DECONF_STD_FILTER_CFG_V71
    stdStep = [];
    try
        if isappdata(0,'deconf_std_workflow_step'), stdStep = getappdata(0,'deconf_std_workflow_step'); end
        if isempty(stdStep) && exist('fig','var') && ishghandle(fig) && isappdata(fig,'deconf_std_workflow_step'), stdStep = getappdata(fig,'deconf_std_workflow_step'); end
    catch
    end
    if isstruct(stdStep) && isfield(stdStep,'name') && strcmpi(strtrim(stdStep.name),'Filtering')
        opts = struct(); ft = 1;
        if isfield(stdStep,'filterType') && isfinite(double(stdStep.filterType)), ft = round(double(stdStep.filterType)); end
        if ft == 2, opts.type = 'low'; elseif ft == 3, opts.type = 'high'; elseif ft==4, opts.type='stop'; else, opts.type = 'band'; end
        opts.FcLow = 0.001; opts.FcHigh = 0.20; opts.order = 4;
        if isfield(stdStep,'fcLow') && isfinite(double(stdStep.fcLow)), opts.FcLow = double(stdStep.fcLow); end
        if isfield(stdStep,'fcHigh') && isfinite(double(stdStep.fcHigh)), opts.FcHigh = double(stdStep.fcHigh); end
        if isfield(stdStep,'filterOrder') && isfinite(double(stdStep.filterOrder)), opts.order = round(double(stdStep.filterOrder)); end
        opts.trimStart = 0; opts.trimEnd = 0; opts.useTaper = true; opts.saveQC = true; opts.chunkSize = 50000; opts.cancelled = false;
        if strcmpi(opts.type,'low'), opts.FcLow = 0; end
        if strcmpi(opts.type,'high'), opts.FcHigh = 0; end
        addLog(sprintf('[Standardized] Filtering no-dialog: %s | low=%.6g | high=%.6g | order=%d',opts.type,opts.FcLow,opts.FcHigh,opts.order));
    else
        opts = showFilteringSetupDialog(data);
    end
    end

    if isempty(opts) || ...
            (isstruct(opts) && isfield(opts,'cancelled') && opts.cancelled)
        addLog('Filtering cancelled.');
        return;
    end

    if isstruct(stdStep) && isfield(stdStep,'filterMethod') && isfinite(stdStep.filterMethod)
        families={'butter','cheby1','cheby2','ellip','fir','fft'};
        familyIndex=round(stdStep.filterMethod);
        if familyIndex<1||familyIndex>6, error('Filtering:Method','Workflow filter family must be 1-6.'); end
        opts.method=families{familyIndex};
    end
    if isstruct(stdStep)
        sourceFields={'filterRippleDb','filterAttenuationDb','filterPreserveMean'};
        targetFields={'passbandRippleDb','stopbandAttenuationDb','restoreMean'};
        for fi=1:numel(sourceFields)
            if isfield(stdStep,sourceFields{fi}) && isfinite(stdStep.(sourceFields{fi}))
                opts.(targetFields{fi})=stdStep.(sourceFields{fi});
            end
        end
    end
    if isfield(opts,'method')&&strcmp(opts.method,'fft'), opts.order=0; end
    ts = datestr(now,'yyyymmdd_HHMMSS');
    opts.tag = ['filter_' ts];

    filterTag = makeFilterTag(opts);

    if ~isfield(opts,'method'), opts.method='butter'; end
    addLog(['Running temporal filtering (' opts.method ')...']);
    addLog(sprintf('Type: %s | FcLow: %.6g Hz | FcHigh: %.6g Hz | Order: %d', ...
        upper(opts.type), opts.FcLow, opts.FcHigh, round(opts.order)));
    addLog(sprintf('Trim start: %.3g s | Trim end: %.3g s | Taper: %s', ...
        opts.trimStart, opts.trimEnd, iff(opts.useTaper,'ON','OFF')));

    setProgramStatus(false);
    drawnow;

    try
        [I_filt, stats] = filtering(data.I, data.TR, studio.exportPath, opts);
        filterTag=makeFilterTag(stats.optsResolved);

        newData = data;
        newData.I = single(I_filt);
        newData.filtering = stats;

        % Important: old PSC/bg are no longer valid after filtering.
        if isfield(newData,'PSC')
            newData.PSC = [];
        end
        if isfield(newData,'bg')
            newData.bg = [];
        end

        switch lower(stats.filterType)
            case 'low'
                newData.preprocessing = sprintf( ...
                    '%s low-pass filtering, Fc=%.6g Hz, order=%d', ...
                    stats.methodName, stats.FcHigh, stats.order);

            case 'high'
                newData.preprocessing = sprintf( ...
                    '%s high-pass filtering, Fc=%.6g Hz, order=%d', ...
                    stats.methodName, stats.FcLow, stats.order);

            case 'band'
                newData.preprocessing = sprintf( ...
                    '%s band-pass filtering, %.6g-%.6g Hz, order=%d', ...
                    stats.methodName, stats.FcLow, stats.FcHigh, stats.order);

            otherwise
                newData.preprocessing = [stats.methodName ' ' stats.filterType ' filtering'];
        end

        baseStem = getCurrentNamingStem(studio);
        fullName = sprintf('%s_%s_%s', baseStem, filterTag, ts);

        keyName = makeSafeKey(fullName, studio.datasets);

        newData.displayNameFull = fullName;
        newData.preprocDisplayName = fullName;
        newData.HUMOR_fullDisplayName = fullName;
        try, newData.displayNameShort = deConfUSIon_display_short_name(fullName,newData,''); catch, newData.displayNameShort = fullName; end
        newData.datasetSortTime = now;
        newData.sourceDatasetKey = studio.activeDataset;

        studio.datasets.(keyName) = newData;
        studio.activeDataset = keyName;
        studio.pipeline.preprocDone = true;

        preFolder = fullfile(studio.exportPath,'Preprocessing');

        savePath = deConfUSIon_safe_preproc_save_path(preFolder, fullName, keyName, 'filter');
        newData.savedFile = savePath;
        newData.lazyFile = savePath;
        studio.datasets.(keyName) = newData;
        displayNameFull = fullName;
        preprocDisplayName = fullName;
        if isfield(newData,'datasetSortTime') && ~isempty(newData.datasetSortTime)
            datasetSortTime = newData.datasetSortTime; %#ok<NASGU>
        else
            datasetSortTime = now; %#ok<NASGU>
            newData.datasetSortTime = datasetSortTime;
            studio.datasets.(keyName) = newData;
        end
        DataIO('save',savePath,struct('newData',newData,'displayNameFull',displayNameFull,'preprocDisplayName',preprocDisplayName,'datasetSortTime',datasetSortTime));
        addLog(['Saved and verified -> ' savePath]);

        guidata(fig, studio);
        refreshDatasetDropdown();

        addLog(['Filtering complete -> ' fullName]);

        if isfield(stats,'qcFolder') && ~isempty(stats.qcFolder)
            addLog(['Filtering QC saved -> ' stats.qcFolder]);
        end

        addLog(sprintf('Filtering runtime: %.2f sec', stats.processingTime));

    catch ME
        addLog(['FILTER ERROR: ' ME.message]);
        errordlg(ME.message,'Filtering Failure');
    end

    setProgramStatus(true);
end

function opts = showFilteringSetupDialog(data)
opts=filtering('setup',data);
end

%% =========================================================
%  ATLAS REGISTRATION
% =========================================================
function coregCallback(~,~)
    studio = guidata(fig);
    if ~isfield(studio,'isLoaded') || ~studio.isLoaded
        errordlg('Load data first.','Atlas Registration');
        return;
    end

    addLog('--- Atlas Registration ---');
    closeLingeringQCFigures();
    setProgramStatus(false);
    readyCleanup = onCleanup(@()setProgramStatus(true)); %#ok<NASGU>
    drawnow;

    try
        % Lazy selections still need their geometry available to the launcher.
        active = studio.datasets.(studio.activeDataset);
        if isfield(active,'isLazy') && active.isLazy
            getActiveData();
            studio = guidata(fig);
            setProgramStatus(false);
        end
        % Both registration launchers receive an analysed output directory.
        studio.exportPath = fusiModelAnalysisFolder(studio);
        if ~isfolder(studio.exportPath), mkdir(studio.exportPath); end
        RegOut = coreg(studio);
        if ~isgraphics(fig,'figure'), return; end
        if isempty(RegOut)
            addLog('Atlas registration cancelled; previous alignment retained.');
            return;
        end

        % Read back current Studio state after the registration window closes.
        studio = guidata(fig);
        if isstruct(RegOut) && ...
                ((isfield(RegOut,'type') && contains(lower(RegOut.type),'coronal_2d')) || ...
                 (isfield(RegOut,'A') && isfield(RegOut,'outputSize') && isfield(RegOut,'atlasSliceIndex')) || ...
                 isfield(RegOut,'Reg2DList'))
            studio.atlasReg2D = RegOut;
            studio.atlasRegistrationMode = '2D coronal';
            studio.atlasReg2DFile = '';
            if isfield(RegOut,'savedFile'), studio.atlasReg2DFile = RegOut.savedFile; end
            studio.atlasTransform = [];
            studio.atlasTransformFile = '';
            guidata(fig,studio);
            addLog('2D coronal atlas registration completed.');
            if ~isempty(studio.atlasReg2DFile)
                addLog(['Registration file: ' studio.atlasReg2DFile]);
            end
        elseif isstruct(RegOut) && isfield(RegOut,'M')
            studio.atlasTransform = RegOut;
            studio.atlasRegistrationMode = '3D';
            studio.atlasTransformFile = '';
            if isfield(RegOut,'atlasUnderlays') && isstruct(RegOut.atlasUnderlays) && ...
                    isfield(RegOut.atlasUnderlays,'transformFile')
                studio.atlasTransformFile = RegOut.atlasUnderlays.transformFile;
            elseif isfield(RegOut,'savedFile') && ~isempty(RegOut.savedFile)
                studio.atlasTransformFile = RegOut.savedFile;
            elseif isfield(studio,'exportPath') && ~isempty(studio.exportPath)
                candidate = fullfile(studio.exportPath,'Registration','Transformation.mat');
                if isfile(candidate), studio.atlasTransformFile = candidate; end
            end
            studio.atlasReg2D = [];
            studio.atlasReg2DFile = '';
            guidata(fig,studio);
            addLog('3D atlas registration completed.');
            if ~isempty(studio.atlasTransformFile)
                addLog(['Transformation file: ' studio.atlasTransformFile]);
            end
        else
            addLog('Atlas registration returned no recognized transformation; previous alignment retained.');
        end
    catch ME
        addLog(['COREG ERROR: ' ME.message]);
        if isgraphics(fig,'figure'), errordlg(ME.message,'Atlas Registration Failed'); end
    end
end

function segmentationCallback(~,~)

    studio = guidata(fig);
    addLog('--- Segmentation ---');

    if ~isfield(studio,'isLoaded') || ~studio.isLoaded
        errordlg('Load data first.');
        return;
    end

    setappdata(fig,'SegmentationRunning',true);
    readyGuard=onCleanup(@finishSegmentation); %#ok<NASGU>
    setProgramStatus(false);
    drawnow;

    try
        data = getActiveData();

        % Segmentation.m now contains a single modern setup GUI.
        % It supports:
        %   - active data.I / data.PSC
        %   - registered 3D atlas-space MAT files
        %   - manual atlas label maps from Registration2D
        %   - step-motor Reg2D files from Registration2D
        Seg = Segmentation(studio, data, @(m) addLog(m));

        if isempty(Seg)
            addLog('Segmentation cancelled or no output created.');
        else
            addLog('Segmentation completed.');

            if isfield(Seg,'files') && isfield(Seg.files,'mat')
                addLog(['Segmentation MAT: ' Seg.files.mat]);
            end

            if isfield(Seg,'files') && isfield(Seg.files,'csvBothZ')
                addLog(['Region x time CSV: ' Seg.files.csvBothZ]);
            end

            if isfield(Seg,'files') && isfield(Seg.files,'csvRegionTable')
                addLog(['Region table CSV: ' Seg.files.csvRegionTable]);
            end
        end

    catch ME
        if strcmp(ME.identifier,'deConfUSIon:ProcessingCancelled'),addLog('Segmentation cancelled.');return;end
        addLog(['SEGMENTATION ERROR: ' ME.message]);
        errordlg(ME.message,'Segmentation Failed');
    end

    setProgramStatus(true);
end

function finishSegmentation()
    if ~isgraphics(fig),return;end
    setappdata(fig,'SegmentationRunning',false);setProgramStatus(true);
end

%% =========================================================
%  GROUP ANALYSIS
% =========================================================
function groupAnalysisCallback(~,~)

    studio = guidata(fig);
    if ~isfield(studio,'isLoaded') || ~studio.isLoaded
        errordlg('Load data first.','Group Analysis');
        return;
    end

    addLog('Opening Group Analysis...');
    setProgramStatus(false);
    drawnow;

    onClose = @() groupAnalysisOnClose();

    try
        gaFig = GroupAnalysis(studio, onClose);

        if isempty(gaFig) || ~ishandle(gaFig)
            addLog('Group Analysis did not return a valid figure handle.');
            setProgramStatus(true);
            return;
        end

        addlistener(gaFig,'ObjectBeingDestroyed', @(~,~) onClose());

    catch ME
        addLog(['GROUP ANALYSIS ERROR: ' ME.message]);
        errordlg(ME.message,'Group Analysis');
        setProgramStatus(true);
    end

    function groupAnalysisOnClose()
        if ~isempty(fig) && ishandle(fig)
            setProgramStatus(true);
            addLog('Group Analysis closed.');
        end
    end
end

%% =========================================================
%  FUNCTIONAL CONNECTIVITY
% =========================================================
function functionalConnectivityCallback(~,~)

    studio = guidata(fig);
    addLog('Opening Functional Connectivity...');

    if ~isfield(studio,'isLoaded') || ~studio.isLoaded
        addLog('[FC] Load a dataset first.');
        errordlg('Load data first.','Functional Connectivity');
        return;
    end

    data = getActiveData();

    if ~isstruct(data) || ~isfield(data,'I') || isempty(data.I)
        addLog('[FC] Active dataset has no .I.');
        errordlg('Active dataset has no .I field.','Functional Connectivity');
        return;
    end

    if ~isfield(data,'TR') || isempty(data.TR) || ...
            ~isscalar(data.TR) || ~isfinite(data.TR) || data.TR <= 0
        addLog('[FC] Active dataset has invalid TR.');
        errordlg('Active dataset has invalid TR.','Functional Connectivity');
        return;
    end

    % -----------------------------------------------------
    % Single modern black setup popup
    % -----------------------------------------------------
    cfg = showFunctionalConnectivitySetupDialog(studio, data);

    if isempty(cfg) || ~isstruct(cfg) || ...
            ~isfield(cfg,'cancelled') || cfg.cancelled
        addLog('[FC] Functional Connectivity cancelled.');
        return;
    end

    saveRoot = studio.exportPath;
    if isempty(saveRoot) || ~exist(saveRoot,'dir')
        saveRoot = pwd;
    end

    tag = ['fc_' datestr(now,'yyyymmdd_HHMMSS')];

    % -----------------------------------------------------
    % Build data object for FunctionalConnectivity
    % -----------------------------------------------------
    dataFC = data;

    % Functional source
    if strcmpi(cfg.functionalSource,'psc')
        dataFC.I = single(data.PSC);
        dataFC.functionalSource = 'PSC';
    else
        dataFC.I = single(data.I);
        dataFC.functionalSource = 'I';
    end

    % Display / bookkeeping
    for key={'meta','metadata','md','voxelSizeUm','voxelSize','voxelSizeUnit'}
        if isfield(data,key{1}),dataFC.(key{1})=data.(key{1});end
    end
    if isfield(studio,'loadedFile'),dataFC.sourceFile=studio.loadedFile;end
    dataFC.name = getDatasetDisplayName(studio, studio.activeDataset);
    dataFC.analysisDir = saveRoot;
dataFC.exportPath = studio.exportPath;
dataFC.registrationPath = fcGetRegistrationStartDir(studio);
    if isfield(studio,'loadedPath') && ~isempty(studio.loadedPath)
        dataFC.loadedPath = studio.loadedPath;
    end

    % Mask
    switch lower(cfg.maskMode)
        case 'studio'
            dataFC.mask = logical(cfg.mask);

        case 'loaded'
            dataFC.mask = logical(cfg.mask);

        case 'none'
            if isfield(dataFC,'mask')
                dataFC.mask = [];
            end
            if isfield(dataFC,'brainMask')
                dataFC.brainMask = [];
            end

        otherwise
            % auto mask will be generated inside FunctionalConnectivity
            if isfield(dataFC,'mask')
                dataFC.mask = [];
            end
            if isfield(dataFC,'brainMask')
                dataFC.brainMask = [];
            end
    end

% Underlay / anatomical reference
dataFC.anatIsDisplayReady = false;

if ~isempty(cfg.anat)
    dataFC.anat = cfg.anat;
    dataFC.bg = cfg.anat;
    dataFC.underlay = cfg.anat;

    if isfield(cfg,'anatIsDisplayReady') && ~isempty(cfg.anatIsDisplayReady)
        dataFC.anatIsDisplayReady = logical(cfg.anatIsDisplayReady);
    end

elseif isfield(data,'bg') && ~isempty(data.bg)
    dataFC.anat = data.bg;
    dataFC.bg = data.bg;
    dataFC.underlay = data.bg;
    dataFC.anatIsDisplayReady = false;
end
    % ROI atlas / region atlas
    if ~isempty(cfg.roiAtlas)
        dataFC.roiAtlas = round(double(cfg.roiAtlas));
    end

    % -----------------------------------------------------
    % Options for FunctionalConnectivity
    % -----------------------------------------------------
    opts = struct();
    opts.datasetName = studio.activeDataset;
    opts.functionalField = 'I';

    opts.seedBoxSize = cfg.seedBoxSize;
    opts.roiMinVox = cfg.roiMinVox;
    opts.chunkVox = cfg.chunkVox;

    opts.askMaskAtStart = false;    % important: no extra popup
    opts.askAtlasAtStart = false;   % important: no extra popup
    opts.debugRethrow = false;
opts.defaultUnderlayMode = cfg.defaultUnderlayMode;
if isfield(cfg,'anatIsDisplayReady') && ~isempty(cfg.anatIsDisplayReady)
    opts.anatIsDisplayReady = logical(cfg.anatIsDisplayReady);
else
    opts.anatIsDisplayReady = false;
end
% -----------------------------------------------------
% FC underlay display style
% 3 = SCM / VideoGUI recommended display normalization
% -----------------------------------------------------
if isfield(cfg,'defaultUnderlayViewMode')
    opts.defaultUnderlayViewMode = cfg.defaultUnderlayViewMode;
else
    opts.defaultUnderlayViewMode = 5;   % 5 = SCM log/median underlay
end

if isfield(cfg,'underlayBrightness')
    opts.underlayBrightness = cfg.underlayBrightness;
else
    opts.underlayBrightness = -0.04;
end

if isfield(cfg,'underlayContrast')
    opts.underlayContrast = cfg.underlayContrast;
else
    opts.underlayContrast = 1.10;
end

if isfield(cfg,'underlayGamma')
    opts.underlayGamma = cfg.underlayGamma;
else
    opts.underlayGamma = 0.95;
end

    if ~isempty(cfg.roiNameTable)
        opts.roiNameTable = cfg.roiNameTable;
    else
        opts.roiNameTable = struct('labels',[],'names',{{}});
    end

    opts.statusFcn = @(isReady) setProgramStatus(isReady);
    opts.logFcn = @(m) addLog(['[FC] ' m]);
    opts.stepMotorFolder = '';
    opts.preloadSegmentationFile = '';
    if isfield(cfg,'stepMotorFolder') && ~isempty(cfg.stepMotorFolder)
        opts.stepMotorFolder = cfg.stepMotorFolder;
    end
    if isfield(cfg,'segmentationFile') && ~isempty(cfg.segmentationFile)
        opts.preloadSegmentationFile = cfg.segmentationFile;
    end

    % Useful paths for the FC GUI file pickers
 opts.saveRoot = saveRoot;
opts.loadedPath = studio.loadedPath;
opts.exportPath = studio.exportPath;

% Important for atlas / histology / region-name loading
opts.registrationPath = fcGetRegistrationStartDir(studio);
opts.startDirAtlas = opts.registrationPath;
opts.startDirNames = opts.registrationPath;
opts.startDirUnderlay = opts.registrationPath;

% New FC GUI behaviour
opts.showAtlasInSeedTab = false;
opts.seedOverlayAtlas = false;
opts.defaultUnderlayMode = cfg.defaultUnderlayMode;
opts.preferredUnderlayStyle = 'scm_log_median';

    addLog('[FC] Setup complete.');
    addLog(['[FC] Functional source: ' upper(cfg.functionalSource)]);
    addLog(['[FC] Mask mode: ' cfg.maskMode]);
  addLog(['[FC] Underlay mode: ' cfg.defaultUnderlayMode]);

if isfield(cfg,'defaultUnderlayViewMode') && cfg.defaultUnderlayViewMode == 3
    addLog('[FC] Underlay display: SCM/Video recommended normalization.');
end

    if ~isempty(cfg.roiAtlas)
        addLog('[FC] ROI atlas preloaded.');
    else
        addLog('[FC] ROI atlas not preloaded.');
    end

    if ~isempty(cfg.roiNameTable) && isfield(cfg.roiNameTable,'labels')
        addLog(sprintf('[FC] Region names preloaded: %d labels.', ...
            numel(cfg.roiNameTable.labels)));
    else
        addLog('[FC] Region names not preloaded.');
    end
    if isfield(cfg,'segmentationFile') && ~isempty(cfg.segmentationFile)
        addLog(['[FC] Step-motor Segmentation preload: ' cfg.segmentationFile]);
    end
    if false
    end

    setProgramStatus(false);
    drawnow;

    try
        fcFig = FunctionalConnectivity(dataFC, saveRoot, tag, opts);

        if ~isempty(fcFig) && ishandle(fcFig)
            addlistener(fcFig,'ObjectBeingDestroyed', @(~,~) fcOnClose());
        else
            setProgramStatus(true);
        end

        addLog('[FC] GUI launched.');

    catch ME
        setProgramStatus(true);
        addLog(['FC ERROR: ' ME.message]);
        errordlg(ME.message,'Functional Connectivity');
    end

    function fcOnClose()
        if ~isempty(fig) && ishandle(fig)
            setProgramStatus(true);
            addLog('[FC] Closed.');
        end
    end
end

%% =========================================================
%  MODERN FUNCTIONAL CONNECTIVITY SETUP POPUP
% =========================================================
function cfg = showFunctionalConnectivitySetupDialog(studio, data)

    cfg = struct();
    cfg.cancelled = true;

    I = data.I;
    nd = ndims(I);
    sz = size(I);

    if nd == 3
        Y = sz(1);
        X = sz(2);
        Z = 1;
        T = sz(3);
        dimTxt = sprintf('%d x %d x %d', Y, X, T);
    elseif nd == 4
        Y = sz(1);
        X = sz(2);
        Z = sz(3);
        T = sz(4);
        dimTxt = sprintf('%d x %d x %d x %d', Y, X, Z, T);
    else
        error('Functional Connectivity requires 3D [Y X T] or 4D [Y X Z T] data.');
    end

    TR = double(data.TR);

    hasPSC = isfield(data,'PSC') && ~isempty(data.PSC) && isnumeric(data.PSC);
    hasDataBg = isfield(data,'bg') && ~isempty(data.bg) && isnumeric(data.bg);

    hasStudioMask = isfield(studio,'mask') && ~isempty(studio.mask);
    hasStudioAnat = false;

    if isfield(studio,'anatomicalReference') && ~isempty(studio.anatomicalReference)
        hasStudioAnat = true;
    elseif isfield(studio,'anatomicalReferenceRaw') && ~isempty(studio.anatomicalReferenceRaw)
        hasStudioAnat = true;
    end

    loadedMask = [];
loadedAtlas = [];
loadedAnat = [];
loadedAnatDisplayReady = false;
loadedNames = struct('labels',[],'names',{{}});

    loadedMaskName = '';
    loadedAtlasName = '';
    loadedAnatName = '';
    loadedNamesName = '';
loadedStepFolder = '';
loadedSegmentationFile = '';
loadedStepInfo = [];  % HUMOR_FC_STEP_FOLDER_SETUP_PATCH_20260519

    % ---------------- colors ----------------
    bg      = [0.045 0.045 0.050];
    panel   = [0.085 0.085 0.095];
    panel2  = [0.115 0.115 0.130];
    fg      = [0.96 0.96 0.96];
    fgDim   = [0.72 0.72 0.76];
    blue    = [0.20 0.48 0.95];
    green   = [0.15 0.68 0.35];
    orange  = [0.95 0.55 0.18];
    red     = [0.80 0.25 0.25];

    dlg = figure( ...
        'Name','Functional Connectivity Setup', ...
        'Color',bg, ...
        'MenuBar','none', ...
        'ToolBar','none', ...
        'NumberTitle','off', ...
        'Resize','off', ...
        'Units','pixels', ...
       'Position',[35 35 1650 960],  ...
        'WindowStyle','modal', ...
        'Visible','off', ...
        'CloseRequestFcn',@onCancel, ...
        'KeyPressFcn',@onKey);
try, deConfUSIon_popup_polish_now(gcf); catch, end


    try
        movegui(dlg,'center');
    catch
    end

    % ---------------- title ----------------
    uicontrol('Parent',dlg,'Style','text', ...
        'Units','normalized', ...
        'Position',[0.045 0.93 0.91 0.05], ...
        'String','Functional Connectivity Setup', ...
        'BackgroundColor',bg, ...
        'ForegroundColor',fg, ...
        'FontName','Helvetica', ...
        'FontSize',21, ...
        'FontWeight','bold', ...
        'HorizontalAlignment','left');

    uicontrol('Parent',dlg,'Style','text', ...
        'Units','normalized', ...
        'Position',[0.047 0.885 0.91 0.035], ...
        'String','Preload functional data, mask, underlay, ROI atlas and region names before launching the FC GUI.', ...
        'BackgroundColor',bg, ...
        'ForegroundColor',fgDim, ...
        'FontName','Helvetica', ...
        'FontSize',16, ...
        'HorizontalAlignment','left');

    % ---------------- info panel ----------------
    infoPanel = uipanel('Parent',dlg, ...
        'Units','normalized', ...
        'Position',[0.045 0.785 0.91 0.085], ...
        'BackgroundColor',panel, ...
        'ForegroundColor',fg, ...
        'BorderType','line', ...
        'HighlightColor',[0.30 0.30 0.34], ...
        'ShadowColor',[0.02 0.02 0.02]);

    infoStr = sprintf('Input size: %s     TR: %.6g s     Volumes: %d     Duration: %.2f min', ...
        dimTxt, TR, T, (T*TR)/60);

    uicontrol('Parent',infoPanel,'Style','text', ...
        'Units','normalized', ...
        'Position',[0.035 0.22 0.93 0.58], ...
        'String',infoStr, ...
        'BackgroundColor',panel, ...
        'ForegroundColor',[0.75 0.88 1.00], ...
        'FontName','Helvetica', ...
        'FontSize',16, ...
        'FontWeight','bold', ...
        'HorizontalAlignment','left');

    % ---------------- settings panel ----------------
    settingsPanel = uipanel('Parent',dlg, ...
        'Units','normalized', ...
        'Position',[0.045 0.225 0.91 0.54], ...
        'BackgroundColor',panel, ...
        'ForegroundColor',fg, ...
        'BorderType','line', ...
        'HighlightColor',[0.30 0.30 0.34], ...
        'ShadowColor',[0.02 0.02 0.02]);

    % Functional source
    funcList = {'Active data.I'};
    if hasPSC
        funcList{end+1} = 'PSC field';
    end

    addLabel(settingsPanel,'Functional signal',0.045,0.865);
    ddFunc = uicontrol('Parent',settingsPanel,'Style','popupmenu', ...
        'Units','normalized', ...
        'Position',[0.31 0.865 0.30 0.07], ...
        'String',funcList, ...
        'Value',1, ...
        'BackgroundColor',panel2, ...
        'ForegroundColor',fg, ...
        'FontName','Helvetica', ...
        'FontSize',11, ...
        'FontWeight','bold', ...
        'Callback',@updateSummary);

    uicontrol('Parent',settingsPanel,'Style','text', ...
        'Units','normalized', ...
        'Position',[0.64 0.855 0.31 0.09], ...
        'String',{'Usually use active data.I.'; 'Use PSC only if already computed.'}, ...
        'BackgroundColor',panel, ...
        'ForegroundColor',fgDim, ...
        'FontName','Helvetica', ...
        'FontSize',10, ...
        'HorizontalAlignment','left');

    % Mask
    addLabel(settingsPanel,'Mask',0.045,0.720);
    ddMask = uicontrol('Parent',settingsPanel,'Style','popupmenu', ...
        'Units','normalized', ...
        'Position',[0.31 0.720 0.30 0.07], ...
        'String',{'Auto mask','Use Studio mask','Use loaded mask','No mask'}, ...
        'Value',fcDefaultMaskValue(), ...
        'BackgroundColor',panel2, ...
        'ForegroundColor',fg, ...
        'FontName','Helvetica', ...
        'FontSize',11, ...
        'FontWeight','bold', ...
        'Callback',@updateSummary);

    btnLoadMask = uicontrol('Parent',settingsPanel,'Style','pushbutton', ...
        'Units','normalized', ...
        'Position',[0.64 0.720 0.15 0.07], ...
        'String','Load mask', ...
        'BackgroundColor',blue, ...
        'ForegroundColor','w', ...
        'FontName','Helvetica', ...
        'FontSize',10, ...
        'FontWeight','bold', ...
        'Callback',@onLoadMask);

    txtMask = uicontrol('Parent',settingsPanel,'Style','text', ...
        'Units','normalized', ...
        'Position',[0.81 0.710 0.15 0.09], ...
        'String','', ...
        'BackgroundColor',panel, ...
        'ForegroundColor',fgDim, ...
        'FontName','Helvetica', ...
        'FontSize',9, ...
        'HorizontalAlignment','left');

    % Underlay
    addLabel(settingsPanel,'Underlay / anatomy',0.045,0.575);
    ddUnderlay = uicontrol('Parent',settingsPanel,'Style','popupmenu', ...
    'Units','normalized', ...
    'Position',[0.31 0.575 0.30 0.07], ...
    'String',{ ...
    'SCM log/median underlay [recommended]', ...
    'Mean functional', ...
    'Median functional', ...
    'data.bg / PSC bg', ...
    'Mask Editor anatomical underlay', ...
    'Loaded underlay / histology'}, ...
'Value',1, ...
    'BackgroundColor',panel2, ...
    'ForegroundColor',fg, ...
    'FontName','Helvetica', ...
    'FontSize',11, ...
    'FontWeight','bold', ...
    'Callback',@updateSummary);

    btnLoadUnderlay = uicontrol('Parent',settingsPanel,'Style','pushbutton', ...
        'Units','normalized', ...
        'Position',[0.64 0.575 0.15 0.07], ...
        'String','Load underlay', ...
        'BackgroundColor',blue, ...
        'ForegroundColor','w', ...
        'FontName','Helvetica', ...
        'FontSize',10, ...
        'FontWeight','bold', ...
        'Callback',@onLoadUnderlay);

    txtUnderlay = uicontrol('Parent',settingsPanel,'Style','text', ...
        'Units','normalized', ...
        'Position',[0.81 0.565 0.15 0.09], ...
        'String','', ...
        'BackgroundColor',panel, ...
        'ForegroundColor',fgDim, ...
        'FontName','Helvetica', ...
        'FontSize',9, ...
        'HorizontalAlignment','left');


    % ROI Atlas
    addLabel(settingsPanel,'ROI atlas / label map',0.045,0.430);
    ddAtlas = uicontrol('Parent',settingsPanel,'Style','popupmenu', ...
        'Units','normalized', ...
        'Position',[0.31 0.430 0.30 0.07], ...
        'String',{'No atlas','Use active dataset atlas','Use loaded atlas'}, ...
        'Value',fcDefaultAtlasValue(), ...
        'BackgroundColor',panel2, ...
        'ForegroundColor',fg, ...
        'FontName','Helvetica', ...
        'FontSize',11, ...
        'FontWeight','bold', ...
        'Callback',@updateSummary);

    btnLoadAtlas = uicontrol('Parent',settingsPanel,'Style','pushbutton', ...
        'Units','normalized', ...
        'Position',[0.64 0.430 0.15 0.07], ...
        'String','Load labels', ...
        'BackgroundColor',orange, ...
        'ForegroundColor','w', ...
        'FontName','Helvetica', ...
        'FontSize',10, ...
        'FontWeight','bold', ...
        'Callback',@onLoadAtlas);

    txtAtlas = uicontrol('Parent',settingsPanel,'Style','text', ...
        'Units','normalized', ...
        'Position',[0.81 0.420 0.15 0.09], ...
        'String','', ...
        'BackgroundColor',panel, ...
        'ForegroundColor',fgDim, ...
        'FontName','Helvetica', ...
        'FontSize',9, ...
        'HorizontalAlignment','left');

    % Region names
    addLabel(settingsPanel,'Region names',0.045,0.285);
    ddNames = uicontrol('Parent',settingsPanel,'Style','popupmenu', ...
        'Units','normalized', ...
        'Position',[0.31 0.285 0.30 0.07], ...
        'String',{'No region names','Use loaded names'}, ...
        'Value',1, ...
        'BackgroundColor',panel2, ...
        'ForegroundColor',fg, ...
        'FontName','Helvetica', ...
        'FontSize',11, ...
        'FontWeight','bold', ...
        'Callback',@updateSummary);

    btnLoadNames = uicontrol('Parent',settingsPanel,'Style','pushbutton', ...
        'Units','normalized', ...
        'Position',[0.64 0.285 0.15 0.07], ...
        'String','Load names', ...
        'BackgroundColor',orange, ...
        'ForegroundColor','w', ...
        'FontName','Helvetica', ...
        'FontSize',10, ...
        'FontWeight','bold', ...
        'Callback',@onLoadNames);

    txtNames = uicontrol('Parent',settingsPanel,'Style','text', ...
        'Units','normalized', ...
        'Position',[0.81 0.275 0.15 0.09], ...
        'String','', ...
        'BackgroundColor',panel, ...
        'ForegroundColor',fgDim, ...
        'FontName','Helvetica', ...
        'FontSize',9, ...
        'HorizontalAlignment','left');

    % Numeric settings
    addLabel(settingsPanel,'Seed box size',0.045,0.135);
    edSeedBox = uicontrol('Parent',settingsPanel,'Style','edit', ...
        'Units','normalized', ...
        'Position',[0.31 0.140 0.10 0.065], ...
        'String','3', ...
        'BackgroundColor',[0.02 0.02 0.025], ...
        'ForegroundColor',fg, ...
        'FontName','Helvetica', ...
        'FontSize',11, ...
        'FontWeight','bold', ...
        'HorizontalAlignment','center', ...
        'Callback',@updateSummary);

    uicontrol('Parent',settingsPanel,'Style','text', ...
        'Units','normalized', ...
        'Position',[0.43 0.125 0.12 0.09], ...
        'String','pixels', ...
        'BackgroundColor',panel, ...
        'ForegroundColor',fgDim, ...
        'FontName','Helvetica', ...
        'FontSize',10, ...
        'HorizontalAlignment','left');

    fcLabelSmall(settingsPanel,'ROI min vox',0.57,0.135);
    edMinVox = uicontrol('Parent',settingsPanel,'Style','edit', ...
        'Units','normalized', ...
        'Position',[0.70 0.140 0.09 0.065], ...
        'String','9', ...
        'BackgroundColor',[0.02 0.02 0.025], ...
        'ForegroundColor',fg, ...
        'FontName','Helvetica', ...
        'FontSize',11, ...
        'FontWeight','bold', ...
        'HorizontalAlignment','center', ...
        'Callback',@updateSummary);

    fcLabelSmall(settingsPanel,'Chunk',0.81,0.135);
    edChunk = uicontrol('Parent',settingsPanel,'Style','edit', ...
        'Units','normalized', ...
        'Position',[0.89 0.140 0.07 0.065], ...
        'String','6000', ...
        'BackgroundColor',[0.02 0.02 0.025], ...
        'ForegroundColor',fg, ...
        'FontName','Helvetica', ...
        'FontSize',11, ...
        'FontWeight','bold', ...
        'HorizontalAlignment','center', ...
        'Callback',@updateSummary);

    % Summary panel
    summaryPanel = uipanel('Parent',dlg, ...
        'Units','normalized', ...
        'Position',[0.045 0.115 0.91 0.085], ...
        'BackgroundColor',[0.035 0.035 0.040], ...
        'ForegroundColor',fg, ...
        'BorderType','line', ...
        'HighlightColor',[0.25 0.25 0.28], ...
        'ShadowColor',[0.01 0.01 0.01]);

    summaryText = uicontrol('Parent',summaryPanel,'Style','text', ...
        'Units','normalized', ...
        'Position',[0.025 0.10 0.95 0.80], ...
        'String','', ...
        'BackgroundColor',[0.035 0.035 0.040], ...
        'ForegroundColor',[0.70 1.00 0.80], ...
        'FontName','Helvetica', ...
        'FontSize',10, ...
        'FontWeight','bold', ...
        'HorizontalAlignment','left');

    % Bottom buttons
    uicontrol('Parent',dlg,'Style','pushbutton', ...
        'Units','normalized', ...
        'Position',[0.045 0.035 0.20 0.06], ...
        'String','AUTO SETUP', ...
        'BackgroundColor',blue, ...
        'ForegroundColor','w', ...
        'FontName','Helvetica', ...
        'FontSize',16, ...
        'FontWeight','bold', ...
        'Callback',@onAutoSetup);

    uicontrol('Parent',dlg,'Style','pushbutton', ...
        'Units','normalized', ...
        'Position',[0.275 0.035 0.225 0.060], ...
        'String','STEP-MOTOR FOLDER', ...
        'BackgroundColor',orange, ...
        'ForegroundColor','w', ...
        'FontName','Helvetica', ...
        'FontSize',16, ...
        'FontWeight','bold', ...
        'Callback',@onLoadStepMotorFolder);


    uicontrol('Parent',dlg,'Style','pushbutton', ...
        'Units','normalized', ...
        'Position',[0.54 0.035 0.24 0.06], ...
        'String','RUN CONNECTIVITY', ...
        'BackgroundColor',green, ...
        'ForegroundColor','w', ...
        'FontName','Helvetica', ...
        'FontSize',13, ...
        'FontWeight','bold', ...
        'Callback',@onRun);

    uicontrol('Parent',dlg,'Style','pushbutton', ...
        'Units','normalized', ...
        'Position',[0.80 0.035 0.155 0.06], ...
        'String','CANCEL', ...
        'BackgroundColor',red, ...
        'ForegroundColor','w', ...
        'FontName','Helvetica', ...
        'FontSize',13, ...
        'FontWeight','bold', ...
        'Callback',@onCancel);

  updateFileLabels();
updateSummary();

% Make this setup popup more readable
fcScaleFcSetupFonts(dlg);

set(dlg,'Visible','on');
try, deConfUSIon_popup_autofit_apply(dlg); catch, end
try, deConfUSIon_fix_scm_video_dialog_fonts(dlg); catch, end % HUMOR_V27_SCM_VIDEO_FONT_FIX
waitfor(dlg);

    % =====================================================
    % Nested UI helpers
    % =====================================================
    function addLabel(parent, str, x, y)
        uicontrol('Parent',parent,'Style','text', ...
            'Units','normalized', ...
            'Position',[x y 0.24 0.06], ...
            'String',str, ...
            'BackgroundColor',panel, ...
            'ForegroundColor',fg, ...
            'FontName','Helvetica', ...
            'FontSize',16, ...
            'FontWeight','bold', ...
            'HorizontalAlignment','left');
    end

    function fcLabelSmall(parent, str, x, y)
        uicontrol('Parent',parent,'Style','text', ...
            'Units','normalized', ...
            'Position',[x y 0.12 0.06], ...
            'String',str, ...
            'BackgroundColor',panel, ...
            'ForegroundColor',fg, ...
            'FontName','Helvetica', ...
            'FontSize',10, ...
            'FontWeight','bold', ...
            'HorizontalAlignment','left');
    end

    function v = fcDefaultMaskValue()
        if hasStudioMask
            v = 2;
        else
            v = 1;
        end
    end

   function v = fcDefaultUnderlayValue()
    % Always pre-select SCM/Video recommended underlay display.
    v = 1;
end

    function v = fcDefaultAtlasValue()
        if fcDataHasAtlas(data,Y,X,Z)
            v = 2;
        else
            v = 1;
        end
    end

    function updateFileLabels()
        if isempty(loadedMaskName)
            set(txtMask,'String','no file');
        else
            set(txtMask,'String',shortTxt(loadedMaskName,18));
        end

        if isempty(loadedAnatName)
            set(txtUnderlay,'String','no file');
        else
            set(txtUnderlay,'String',shortTxt(loadedAnatName,18));
        end

        if isempty(loadedAtlasName)
            set(txtAtlas,'String','no file');
        else
            set(txtAtlas,'String',shortTxt(loadedAtlasName,18));
        end

        if isempty(loadedNamesName)
            set(txtNames,'String','no file');
        else
            set(txtNames,'String',shortTxt(loadedNamesName,18));
        end
    end

    function updateSummary(~,~)

        funcStrings = get(ddFunc,'String');
        funcTxt = funcStrings{get(ddFunc,'Value')};

        maskStrings = get(ddMask,'String');
        maskTxt = maskStrings{get(ddMask,'Value')};

        underStrings = get(ddUnderlay,'String');
        underTxt = underStrings{get(ddUnderlay,'Value')};

        atlasStrings = get(ddAtlas,'String');
        atlasTxt = atlasStrings{get(ddAtlas,'Value')};

        namesStrings = get(ddNames,'String');
        namesTxt = namesStrings{get(ddNames,'Value')};

        seedBox = str2double(get(edSeedBox,'String'));
        roiMinVox = str2double(get(edMinVox,'String'));
        chunkVox = str2double(get(edChunk,'String'));

        txt = sprintf(['%s | Mask: %s | Underlay: %s | Atlas: %s | Names: %s | ' ...
            'Seed box: %g | ROI min vox: %g | Chunk: %g'], ...
            funcTxt, maskTxt, underTxt, atlasTxt, namesTxt, ...
            seedBox, roiMinVox, chunkVox);

        if ishandle(summaryText)
            set(summaryText,'String',txt);
        end
    end

    function onAutoSetup(~,~)
        if hasPSC
            set(ddFunc,'Value',1);
        end

        if hasStudioMask
            set(ddMask,'Value',2);
        else
            set(ddMask,'Value',1);
        end

       % Always use SCM/Video recommended display by default.
set(ddUnderlay,'Value',1);

        if fcDataHasAtlas(data,Y,X,Z)
            set(ddAtlas,'Value',2);
        else
            set(ddAtlas,'Value',1);
        end

        updateSummary();
    end

    function onLoadStepMotorFolder(~,~)
        startDir = fcGetRegistrationStartDir(studio);
        try
            if isfield(studio,'exportPath') && ~isempty(studio.exportPath) && exist(studio.exportPath,'dir')
                startDir = studio.exportPath;
            end
        catch
        end
        folder = uigetdir(startDir,'Select step-motor analysed/session folder');
        if isequal(folder,0), return; end
        loadedStepFolder = folder;
        loadedStepInfo = deConfUSIon_find_stepmotor_seg_fc_files(folder);

        if isfield(loadedStepInfo,'segmentationFile') && ~isempty(loadedStepInfo.segmentationFile)
            loadedSegmentationFile = loadedStepInfo.segmentationFile;
        end

        if isfield(loadedStepInfo,'nameFile') && ~isempty(loadedStepInfo.nameFile) && exist(loadedStepInfo.nameFile,'file') == 2
            try
                loadedNames = deConfUSIon_read_region_names_file(loadedStepInfo.nameFile);
                if ~isempty(loadedNames.labels)
                    loadedNamesName = localFileNameForFCSetup(loadedStepInfo.nameFile);
                    set(ddNames,'Value',2);
                end
            catch
            end
        end

        if isempty(loadedSegmentationFile) && isfield(loadedStepInfo,'labelFile') && ~isempty(loadedStepInfo.labelFile) && exist(loadedStepInfo.labelFile,'file') == 2
            try
                loadedAtlas = fcStudioReadAtlas(loadedStepInfo.labelFile,Y,X,Z);
                if ~isempty(loadedAtlas)
                    loadedAtlasName = localFileNameForFCSetup(loadedStepInfo.labelFile);
                    set(ddAtlas,'Value',3);
                end
            catch
            end
        end

        updateFileLabels();
        updateSummary();
        msg = 'Step-motor folder selected.';
        if ~isempty(loadedSegmentationFile)
            msg = ['Step-motor folder selected. Latest Segmentation MAT will be preloaded: ' localFileNameForFCSetup(loadedSegmentationFile)];
        elseif isstruct(loadedStepInfo)
            msg = ['Step-motor folder selected. ' loadedStepInfo.summary ' | Run Segmentation first if no Segmentation MAT was found.'];
        end
        set(summaryText,'String',msg);
    end

    function nm = localFileNameForFCSetup(f)
        [~,a,b] = fileparts(f);
        if strcmpi(b,'.gz')
            [~,a2,b2] = fileparts(a);
            nm = [a2 b2 b];
        else
            nm = [a b];
        end
    end

    function onLoadMask(~,~)
        startDir = fcSetupStartDir(studio);
        [f,p] = uigetfile({'*.mat','MAT files (*.mat)'}, ...
            'Load FC mask MAT', startDir);

        if isequal(f,0)
            return;
        end

        try
            S = load(fullfile(p,f));
            loadedMask = fcStudioPickVolume(S,Y,X,Z,true);
            if isempty(loadedMask)
                errordlg('No compatible mask found in selected MAT file.','FC mask');
                return;
            end
            loadedMaskName = f;
            set(ddMask,'Value',3);
            updateFileLabels();
            updateSummary();
        catch ME
            errordlg(ME.message,'FC mask load error');
        end
    end

   function onLoadUnderlay(~,~)
   startDir = fcGetRegistrationStartDir(studio);

[f,p] = fc_uigetfile_start( ...
        {'*.mat;*.png;*.jpg;*.jpeg;*.tif;*.tiff;*.bmp', ...
         'Underlay / histology files (*.mat,*.png,*.jpg,*.tif)'}, ...
        'Load FC underlay / histology / anatomy', startDir);

    if isequal(f,0)
        return;
    end

    try
        [loadedAnat, loadedAnatDisplayReady] = fcStudioReadUnderlay(fullfile(p,f),Y,X,Z);

        loadedAnatName = f;
        set(ddUnderlay,'Value',6);

        updateFileLabels();
        updateSummary();

    catch ME
        errordlg(ME.message,'FC underlay load error');
    end
end

 function onLoadAtlas(~,~)
    startDir = fcGetRegistrationStartDir(studio);

    [f,p] = fc_uigetfile_start( ...
        {'*.mat;*.nii;*.nii.gz;*.tif;*.tiff', ...
         'ROI label atlas files (*.mat,*.nii,*.nii.gz,*.tif)'}, ...
        'Load FC ROI atlas / integer region labels', startDir);

    if isequal(f,0)
        return;
    end

    try
        loadedAtlas = fcStudioReadAtlas(fullfile(p,f),Y,X,Z);

        if isempty(loadedAtlas)
            errordlg({ ...
                'No compatible ROI atlas label map found.', ...
                '', ...
                'Important:', ...
                '- Histology belongs under Load underlay.', ...
                '- Colored regions underlay is only a display image.', ...
                '- FC ROI heatmap needs an integer region-label volume.'}, ...
                'FC atlas');
            return;
        end

        loadedAtlas = round(double(loadedAtlas));
        loadedAtlasName = f;

        set(ddAtlas,'Value',3);

        updateFileLabels();
        updateSummary();

    catch ME
        errordlg(ME.message,'FC atlas load error');
    end
end

function onLoadNames(~,~)
    choiceNames = questdlg('Load FC region names from file or recursively from step-motor folder?', ...
        'FC region names', ...
        'Name/TXT file', 'Step-motor folder', 'Cancel', 'Step-motor folder');

    if isempty(choiceNames) || strcmpi(choiceNames,'Cancel')
        return;
    end

    if strcmpi(choiceNames,'Step-motor folder')
        startDir = fcGetRegistrationStartDir(studio);
        try
            if isfield(studio,'exportPath') && ~isempty(studio.exportPath) && exist(studio.exportPath,'dir') == 7
                startDir = studio.exportPath;
            end
        catch
        end

        folder = uigetdir(startDir,'Select Registration2D or step-motor analysed/session folder');
        if isequal(folder,0), return; end

        try
            R = deConfUSIon_FC_find_stepmotor_txt_names(folder);
            if isempty(R.names.labels)
                errordlg({'No readable region-name TXT/CSV/MAT files were found recursively.','','Selected folder:',folder,'','Expected example:','Registration2D\SourceSlice001_AtlasSlice111\AtlasRegions_slice111.txt','',R.summary},'FC step-motor names');
                return;
            end

            loadedNames = R.names;
            loadedNamesName = R.bestFile;
            set(ddNames,'Value',2);
            updateFileLabels();
            updateSummary();
            set(summaryText,'String',R.summary);

        catch ME
            errordlg(ME.message,'FC recursive step-motor names load error');
        end
        return;
    end

    startDir = fcGetRegistrationStartDir(studio);

    [f,p] = fc_uigetfile_start( ...
        {'*.txt;*.csv;*.tsv;*.mat', ...
        'Region names (*.txt,*.csv,*.tsv,*.mat)'}, ...
        'Load FC region names / AtlasRegions_slice TXT', startDir);

    if isequal(f,0)
        return;
    end

    try
        loadedNames = deConfUSIon_FC_read_region_names_file(fullfile(p,f));
        if isempty(loadedNames.labels)
            errordlg('Could not parse labels/names from selected file.','FC names');
            return;
        end
        loadedNamesName = f;
        set(ddNames,'Value',2);
        updateFileLabels();
        updateSummary();
    catch ME
        errordlg(ME.message,'FC region names load error');
    end
end

    function onRun(~,~)



        seedBox = str2double(get(edSeedBox,'String'));
        roiMinVox = str2double(get(edMinVox,'String'));
        chunkVox = str2double(get(edChunk,'String'));

        if ~isfinite(seedBox) || seedBox < 1
            uiwait(errordlg('Seed box size must be >= 1.','FC setup','modal'));
            return;
        end

        if ~isfinite(roiMinVox) || roiMinVox < 1
            uiwait(errordlg('ROI min vox must be >= 1.','FC setup','modal'));
            return;
        end

        if ~isfinite(chunkVox) || chunkVox < 100
            uiwait(errordlg('Chunk voxels should be at least 100.','FC setup','modal'));
            return;
        end

        % Functional source
        funcStrings = get(ddFunc,'String');
        funcChoice = funcStrings{get(ddFunc,'Value')};

        if ~isempty(strfind(lower(funcChoice),'psc')) %#ok<STREMP>
            if ~hasPSC
                uiwait(errordlg('PSC was selected but data.PSC is missing.','FC setup','modal'));
                return;
            end
            cfg.functionalSource = 'psc';
        else
            cfg.functionalSource = 'i';
        end

        % Mask
        cfg.mask = [];
        switch get(ddMask,'Value')
            case 1
                cfg.maskMode = 'auto';

            case 2
                if ~hasStudioMask
                    uiwait(errordlg('Studio mask selected but no studio.mask exists.','FC setup','modal'));
                    return;
                end
                cfg.maskMode = 'studio';
                cfg.mask = fcStudioFitVolume(studio.mask,Y,X,Z,true);

            case 3
                if isempty(loadedMask)
                    uiwait(errordlg('Loaded mask selected but no mask file was loaded.','FC setup','modal'));
                    return;
                end
                cfg.maskMode = 'loaded';
                cfg.mask = fcStudioFitVolume(loadedMask,Y,X,Z,true);

            otherwise
                cfg.maskMode = 'none';
        end

       % -----------------------------------------------------
% Underlay / anatomy
% -----------------------------------------------------
cfg.anat = [];
cfg.anatIsDisplayReady = false;


cfg.defaultUnderlayMode = 'scm_log_median';

% SCM / VideoGUI recommended display settings.
% These are only used for raw/linear underlays.
% If anatIsDisplayReady=true, FunctionalConnectivity.m should show it as-is.
cfg.defaultUnderlayViewMode = 3;
cfg.underlayBrightness = -0.04;
cfg.underlayContrast   = 1.10;
cfg.underlayGamma      = 0.95;

switch get(ddUnderlay,'Value')

        case 1
        % SCM log/median recommended underlay.
        % Priority:
        %   1) Mask Editor display-ready anatomical underlay
        %   2) Mask Editor raw anatomical underlay
        %   3) let FunctionalConnectivity recompute SCM log/median from data.I

        cfg.defaultUnderlayMode = 'scm_log_median';

        if hasStudioAnat && isfield(studio,'anatomicalReference') && ~isempty(studio.anatomicalReference)

            cfg.anat = fcStudioFitVolume(studio.anatomicalReference,Y,X,Z,false);

            if isfield(studio,'anatomicalReferenceIsDisplayReady') && ...
                    studio.anatomicalReferenceIsDisplayReady
                cfg.anatIsDisplayReady = true;
                cfg.defaultUnderlayMode = 'anat';
            else
                cfg.anatIsDisplayReady = false;
                cfg.defaultUnderlayMode = 'anat';
            end

        elseif hasStudioAnat && isfield(studio,'anatomicalReferenceRaw') && ~isempty(studio.anatomicalReferenceRaw)

            cfg.anat = fcStudioFitVolume(studio.anatomicalReferenceRaw,Y,X,Z,false);
            cfg.anatIsDisplayReady = false;
            cfg.defaultUnderlayMode = 'anat';

        else
            % No preloaded anatomical underlay.
            % FunctionalConnectivity.m will compute the SCM-style log/median underlay.
            cfg.anat = [];
            cfg.anatIsDisplayReady = false;
            cfg.defaultUnderlayMode = 'scm_log_median';
        end

    case 2
        cfg.defaultUnderlayMode = 'mean';

    case 3
        cfg.defaultUnderlayMode = 'median';

    case 4
        if hasDataBg
            cfg.anat = fcStudioFitVolume(data.bg,Y,X,Z,false);
            cfg.anatIsDisplayReady = false;
            cfg.defaultUnderlayMode = 'anat';
        else
            cfg.defaultUnderlayMode = 'mean';
        end

    case 5
        if hasStudioAnat && isfield(studio,'anatomicalReference') && ~isempty(studio.anatomicalReference)

            cfg.anat = fcStudioFitVolume(studio.anatomicalReference,Y,X,Z,false);
            cfg.anatIsDisplayReady = true;
            cfg.defaultUnderlayMode = 'anat';

        elseif hasStudioAnat && isfield(studio,'anatomicalReferenceRaw') && ~isempty(studio.anatomicalReferenceRaw)

            cfg.anat = fcStudioFitVolume(studio.anatomicalReferenceRaw,Y,X,Z,false);
            cfg.anatIsDisplayReady = false;
            cfg.defaultUnderlayMode = 'anat';

        else
            cfg.defaultUnderlayMode = 'mean';
        end

    case 6
        if isempty(loadedAnat)
            uiwait(errordlg('Loaded underlay selected but no underlay was loaded.','FC setup','modal'));
            return;
        end

        cfg.anat = fcStudioFitVolume(loadedAnat,Y,X,Z,false);
        cfg.anatIsDisplayReady = logical(loadedAnatDisplayReady);
        cfg.defaultUnderlayMode = 'anat';
end

        % ROI atlas
        cfg.roiAtlas = [];

        switch get(ddAtlas,'Value')
            case 1
                cfg.roiAtlas = [];

            case 2
                cfg.roiAtlas = fcGetAtlasFromData(data,Y,X,Z);

            case 3
                if isempty(loadedAtlas)
                    uiwait(errordlg('Loaded atlas selected but no atlas was loaded.','FC setup','modal'));
                    return;
                end
                cfg.roiAtlas = fcStudioFitVolume(loadedAtlas,Y,X,Z,false);
        end

        % Region names
        if get(ddNames,'Value') == 2
            cfg.roiNameTable = loadedNames;
        else
            cfg.roiNameTable = struct('labels',[],'names',{{}});
        end

        cfg.seedBoxSize = max(1,round(seedBox));
        cfg.roiMinVox = max(1,round(roiMinVox));
        cfg.chunkVox = max(100,round(chunkVox));
        cfg.stepMotorFolder = loadedStepFolder;
        cfg.segmentationFile = loadedSegmentationFile;
        cfg.stepMotorInfo = loadedStepInfo;

        cfg.cancelled = false;

        if ishghandle(dlg)
            delete(dlg);
        end
    end

    function onCancel(~,~)
        cfg.cancelled = true;
        if ishghandle(dlg)
            delete(dlg);
        end
    end

    function onKey(~,ev)
        try
            if strcmpi(ev.Key,'escape')
                onCancel();
            elseif strcmpi(ev.Key,'return')
                onRun();
            end
        catch
        end
    end

    function s = shortTxt(s,n)
        if nargin < 2
            n = 20;
        end
        s = char(s);
        if numel(s) > n
            s = [s(1:max(1,n-3)) '...'];
        end
    end
    function fcScaleFcSetupFonts(hFig)

    try
        allObj = findall(hFig);

        for ii = 1:numel(allObj)
            h = allObj(ii);

            if ~ishandle(h)
                continue;
            end

            if isprop(h,'FontName')
                try
                    set(h,'FontName','Helvetica');
                catch
                end
            end

            if ~isprop(h,'FontSize')
                continue;
            end

            try
                typ = get(h,'Type');
            catch
                typ = '';
            end

            if strcmpi(typ,'uicontrol')
                try
                    style = lower(get(h,'Style'));
                catch
                    style = '';
                end

                switch style
                    case 'text'
                        oldSize = get(h,'FontSize');
                        if oldSize >= 18
                            set(h,'FontSize',24,'FontWeight','bold');
                        elseif oldSize >= 12
                            set(h,'FontSize',14);
                        else
                            set(h,'FontSize',12);
                        end

                    case {'popupmenu','edit'}
                        set(h,'FontSize',13,'FontWeight','bold');

                    case 'pushbutton'
                        set(h,'FontSize',13,'FontWeight','bold');

                    case 'checkbox'
                        set(h,'FontSize',12,'FontWeight','bold');

                    otherwise
                        set(h,'FontSize',12);
                end

            elseif strcmpi(typ,'uipanel')
                set(h,'FontSize',13,'FontWeight','bold');

            elseif strcmpi(typ,'axes')
                set(h,'FontSize',11);
            end
        end
    catch
    end
end
end

%% =========================================================
%  FUNCTIONAL CONNECTIVITY SETUP HELPERS
% =========================================================
    function tf = fcDataHasAtlas(data,Y,X,Z)

tf = false;

try
    A = fcStudioPickAtlasVolume(data,Y,X,Z);
    tf = ~isempty(A);
catch
    tf = false;
end
    end

    function atlas = fcGetAtlasFromData(data,Y,X,Z)

atlas = [];

try
    atlas = fcStudioPickAtlasVolume(data,Y,X,Z);
    if ~isempty(atlas)
        atlas = round(double(atlas));
    end
catch
    atlas = [];
end
end
    function startDir = fcSetupStartDir(studio)
% Backward-compatible default start folder.
% For FC, prefer Registration because atlas, histology, region names,
% and transformed files usually live there.

    startDir = fcGetRegistrationStartDir(studio);
end


   function startDir = fcGetRegistrationStartDir(studio)
% FC atlas / labels / names picker start folder.
% Priority:
%   1) <exportPath>\Registration2D
%   2) studio.registration2DPath
%   3) <exportPath>\Registration
%   4) <exportPath>\Coregistration
%   5) <exportPath>
%   6) loaded raw path
%   7) pwd

    startDir = pwd;
    try
        active=getActiveData();
        if isfield(active,'I')&&ndims(active.I)==4&&size(active.I,3)>1
            subject=struct('I4',active.I,'analysisDir',studio.exportPath,'sourceFile','');
            if isfield(studio,'loadedFile'),subject.sourceFile=studio.loadedFile;end
            startDir=fusiFCStartDir(subject,studio);return;
        end
    catch ME
        addLog(['3D atlas folder lookup: ' ME.message]);
    end


    % -----------------------------------------------------
    % 1) Preferred: analysed dataset Registration2D folder
    % -----------------------------------------------------
    try
        if isfield(studio,'exportPath') && ~isempty(studio.exportPath) && exist(studio.exportPath,'dir')

            reg2DDir = fullfile(studio.exportPath,'Registration2D');

            % Create if missing, so uigetfile can start there.
            if ~exist(reg2DDir,'dir')
                try
                    mkdir(reg2DDir);
                catch
                end
            end

            if exist(reg2DDir,'dir')
                startDir = reg2DDir;
                return;
            end
        end
    catch
    end

    % -----------------------------------------------------
    % 2) Explicit studio.registration2DPath, if you store it
    % -----------------------------------------------------
    try
        if isfield(studio,'registration2DPath') && ~isempty(studio.registration2DPath) && ...
                exist(studio.registration2DPath,'dir')
            startDir = studio.registration2DPath;
            return;
        end
    catch
    end

    % -----------------------------------------------------
    % 3) Older fallback: studio.registrationPath
    % -----------------------------------------------------
    try
        if isfield(studio,'registrationPath') && ~isempty(studio.registrationPath) && ...
                exist(studio.registrationPath,'dir')
            startDir = studio.registrationPath;
            return;
        end
    catch
    end

    % -----------------------------------------------------
    % 4) Other analysed folders
    % -----------------------------------------------------
    try
        if isfield(studio,'exportPath') && ~isempty(studio.exportPath) && exist(studio.exportPath,'dir')

            regDir = fullfile(studio.exportPath,'Registration');
            if exist(regDir,'dir')
                startDir = regDir;
                return;
            end

            coregDir = fullfile(studio.exportPath,'Coregistration');
            if exist(coregDir,'dir')
                startDir = coregDir;
                return;
            end

            startDir = studio.exportPath;
            return;
        end
    catch
    end

    % -----------------------------------------------------
    % 5) Raw loaded path fallback
    % -----------------------------------------------------
    try
        if isfield(studio,'loadedPath') && ~isempty(studio.loadedPath) && exist(studio.loadedPath,'dir')
            startDir = studio.loadedPath;
        end
    catch
    end
end

function [f,p] = fc_uigetfile_start(filterSpec, titleStr, startDir)
% Robust uigetfile opener.
% MATLAB sometimes remembers the last folder. Temporarily cd() into startDir
% so the file picker really starts in Registration.

if nargin < 3 || isempty(startDir) || ~exist(startDir,'dir')
    startDir = pwd;
end

oldDir = pwd;
cleanupObj = onCleanup(@() cd(oldDir)); %#ok<NASGU>

try
    cd(startDir);
catch
end

[f,p] = uigetfile(filterSpec, titleStr);

end

function V = fcStudioPickVolume(S,Y,X,Z,makeLogical)

    V = [];

    preferred = { ...
        'roiAtlas', ...
        'atlas', ...
        'regions', ...
        'annotation', ...
        'labels', ...
        'mask', ...
        'brainMask', ...
        'loadedMask', ...
        'underlay', ...
        'anat', ...
        'bg', ...
        'Data', ...
        'I'};

    for i = 1:numel(preferred)
        fn = preferred{i};
        if isfield(S,fn)
            V = fcStudioVolumeFromAny(S.(fn),Y,X,Z,makeLogical);
            if ~isempty(V)
                return;
            end
        end
    end

    fns = fieldnames(S);
    for i = 1:numel(fns)
        V = fcStudioVolumeFromAny(S.(fns{i}),Y,X,Z,makeLogical);
        if ~isempty(V)
            return;
        end
    end
end

function V = fcStudioVolumeFromAny(x,Y,X,Z,makeLogical)

    V = [];

    try
        if isstruct(x)
            if isfield(x,'Data') && isnumeric(x.Data)
                x = x.Data;
            elseif isfield(x,'I') && isnumeric(x.I)
                x = x.I;
            else
                return;
            end
        end

        if ~(isnumeric(x) || islogical(x))
            return;
        end

        V0 = squeeze(x);

        if ndims(V0) == 2
            if Z == 1 && size(V0,1) == Y && size(V0,2) == X
                V = reshape(V0,Y,X,1);
            elseif size(V0,1) == Y && size(V0,2) == X
                V = repmat(V0,[1 1 Z]);
            end

        elseif ndims(V0) == 3
            if all(size(V0) == [Y X Z])
                V = V0;
            elseif size(V0,1) == Y && size(V0,2) == X && size(V0,3) ~= Z
                zi = round(linspace(1,size(V0,3),Z));
                V = V0(:,:,zi);
            end

        elseif ndims(V0) == 4
            % If a functional 4D volume was accidentally selected as underlay,
            % reduce across time.
            if size(V0,1) == Y && size(V0,2) == X
                V0 = mean(V0,4);
                V = fcStudioVolumeFromAny(V0,Y,X,Z,makeLogical);
            end
        end

        if ~isempty(V) && makeLogical
            V = logical(V);
        end

    catch
        V = [];
    end
end

function V = fcStudioFitVolume(V0,Y,X,Z,makeLogical)

    V = fcStudioVolumeFromAny(V0,Y,X,Z,makeLogical);

    if isempty(V)
        error('Volume cannot be fitted to functional dimensions [%d x %d x %d].',Y,X,Z);
    end
end

function atlas = fcStudioReadAtlas(fullFile,Y,X,Z)

atlas = [];

if ~exist(fullFile,'file')
    error('Atlas file does not exist: %s',fullFile);
end

if numel(fullFile) >= 7 && strcmpi(fullFile(end-6:end),'.nii.gz')
    tmpDir = tempname;
    mkdir(tmpDir);

    try
        gunzip(fullFile,tmpDir);
        d = dir(fullfile(tmpDir,'*.nii'));
        if isempty(d)
            error('Could not unzip NIfTI atlas.');
        end

        A = double(niftiread(fullfile(tmpDir,d(1).name)));
        atlas = fcStudioAtlasVolumeFromAny(A,Y,X,Z);

        try
            rmdir(tmpDir,'s');
        catch
        end

    catch ME
        try
            rmdir(tmpDir,'s');
        catch
        end
        rethrow(ME);
    end

elseif strcmpi(lower(fileparts_ext(fullFile)),'.nii')
    A = double(niftiread(fullFile));
    atlas = fcStudioAtlasVolumeFromAny(A,Y,X,Z);

else
    [~,~,ext] = fileparts(fullFile);
    ext = lower(ext);

    if strcmpi(ext,'.mat')
        S = load(fullFile);
        atlas = fcStudioPickAtlasVolume(S,Y,X,Z);
    else
        A = double(imread(fullFile));
        atlas = fcStudioAtlasVolumeFromAny(A,Y,X,Z);
    end
end

if isempty(atlas)
    error(['No ROI label atlas found. Load histology as underlay. ' ...
           'For ROI FC, choose a regions/labels/annotation file with integer region IDs.']);
end

atlas = round(double(atlas));
end


function ext = fileparts_ext(f)
[~,~,ext] = fileparts(f);
end


function atlas = fcStudioPickAtlasVolume(S,Y,X,Z)

atlas = [];
candidates = struct('name',{},'score',{},'value',{});

candidates = fcStudioCollectAtlasCandidates(S,'root',0,candidates,Y,X,Z);

if isempty(candidates)
    return;
end

scores = zeros(numel(candidates),1);
for ii = 1:numel(candidates)
    scores(ii) = candidates(ii).score;
end

[~,idx] = max(scores);
atlas = candidates(idx).value;
end


function candidates = fcStudioCollectAtlasCandidates(v,pathStr,depth,candidates,Y,X,Z)

if depth > 5
    return;
end

% Numeric candidate.
if isnumeric(v) || islogical(v)
    [A,ok] = fcStudioAtlasVolumeFromAny(v,Y,X,Z);

    if ok && ~isempty(A)
        score = fcStudioScoreAtlasCandidate(A,pathStr);

        if isfinite(score)
            c = struct();
            c.name = pathStr;
            c.score = score;
            c.value = A;
            candidates(end+1) = c; %#ok<AGROW>
        end
    end

    return;
end

% Cell wrapper.
if iscell(v) && numel(v) == 1
    candidates = fcStudioCollectAtlasCandidates(v{1},[pathStr '{1}'],depth+1,candidates,Y,X,Z);
    return;
end

% Struct recursion.
if isstruct(v)
    if numel(v) > 1
        % Region-name structs are not image volumes.
        return;
    end

    fns = fieldnames(v);

    for ii = 1:numel(fns)
        fn = fns{ii};

        if isempty(pathStr)
            p2 = fn;
        else
            p2 = [pathStr '.' fn];
        end

        candidates = fcStudioCollectAtlasCandidates(v.(fn),p2,depth+1,candidates,Y,X,Z);
    end
end
end


function [A,ok] = fcStudioAtlasVolumeFromAny(v,Y,X,Z)

A = [];
ok = false;

try
    v = squeeze(v);

    if isempty(v) || isvector(v)
        return;
    end

    % RGB / colored region underlay is not a label atlas.
    if ndims(v) == 3 && size(v,3) == 3 && Z == 1
        return;
    end

    % 2D label image.
    if ndims(v) == 2

        v2 = double(v);

        % Exact.
        if size(v2,1) == Y && size(v2,2) == X
            A2 = v2;

        % Transposed exact.
        elseif size(v2,1) == X && size(v2,2) == Y
            A2 = v2';

        % Co-registered export with slightly different pixel size.
        else
            A2 = fcStudioResizeLabel2D(v2,Y,X);
        end

        if ~fcStudioLooksLikeRoiLabelMap(A2)
            return;
        end

        if Z == 1
            A = reshape(round(A2),Y,X,1);
        else
            A = repmat(round(A2),[1 1 Z]);
        end

        ok = true;
        return;
    end

    % 3D label volume.
    if ndims(v) == 3

        v3 = double(v);

        % Avoid accidentally resizing the full Allen atlas or huge raw atlases.
        if numel(v3) > 2e7 && ~(size(v3,1)==Y && size(v3,2)==X)
            return;
        end

        if size(v3,1) == Y && size(v3,2) == X
            A3 = v3;

        elseif size(v3,1) == X && size(v3,2) == Y
            A3 = permute(v3,[2 1 3]);

        else
            A3 = zeros(Y,X,size(v3,3));

            for zz = 1:size(v3,3)
                A3(:,:,zz) = fcStudioResizeLabel2D(v3(:,:,zz),Y,X);
            end
        end

        if size(A3,3) ~= Z
            zi = round(linspace(1,size(A3,3),Z));
            zi = max(1,min(size(A3,3),zi));
            A3 = A3(:,:,zi);
        end

        if ~fcStudioLooksLikeRoiLabelMap(A3)
            return;
        end

        A = round(A3);
        ok = true;
        return;
    end

catch
    A = [];
    ok = false;
end
end


function A = fcStudioResizeLabel2D(A,Y,X)

A = double(A);

if size(A,1) == Y && size(A,2) == X
    return;
end

if exist('imresize','file') == 2
    A = imresize(A,[Y X],'nearest');
else
    yy = round(linspace(1,size(A,1),Y));
    xx = round(linspace(1,size(A,2),X));
    A = A(yy,xx);
end

A = round(A);
end


function tf = fcStudioLooksLikeRoiLabelMap(A)

tf = false;

try
    A = double(A);
    A = A(isfinite(A));

    if isempty(A)
        return;
    end

    % Subsample for speed.
    if numel(A) > 200000
        idx = round(linspace(1,numel(A),200000));
        A = A(idx);
    end

    % Must be mostly integer-valued.
    fracInt = mean(abs(A - round(A)) < 1e-6);

    if fracInt < 0.98
        return;
    end

    U = unique(round(A(:)));
    U = U(isfinite(U));
    U = U(U ~= 0);

    % Binary mask is not an atlas.
    if numel(U) < 2
        return;
    end

    % Too many labels usually means colored/intensity image, not atlas IDs.
    if numel(U) > 5000
        return;
    end

    tf = true;

catch
    tf = false;
end
end


function score = fcStudioScoreAtlasCandidate(A,nameStr)

score = -Inf;

if isempty(A)
    return;
end

if ~fcStudioLooksLikeRoiLabelMap(A)
    return;
end

score = 100;

lname = lower(nameStr);

goodKeys = { ...
    'roiatlas','roi_atlas','region','regions','label','labels', ...
    'annotation','atlas','registered','warped','area'};

badKeys = { ...
    'histology','histo','anat','anatomical','underlay','display', ...
    'raw','brainimage','mask','overlay','signal','rgb','image','img'};

for ii = 1:numel(goodKeys)
    if ~isempty(strfind(lname,goodKeys{ii})) %#ok<STREMP>
        score = score + 20;
    end
end

for ii = 1:numel(badKeys)
    if ~isempty(strfind(lname,badKeys{ii})) %#ok<STREMP>
        score = score - 25;
    end
end

try
    U = unique(round(double(A(:))));
    U = U(U ~= 0);
    score = score + min(50,numel(U));
catch
end
end

    function [U,isDisplayReady] = fcStudioReadUnderlay(fullFile,Y,X,Z)

U = [];
isDisplayReady = false;

if ~exist(fullFile,'file')
    error('File does not exist: %s',fullFile);
end

[~,~,ext] = fileparts(fullFile);
ext = lower(ext);

if strcmpi(ext,'.mat')
    S = load(fullFile);

    [U,isDisplayReady] = fcStudioPickUnderlay(S,Y,X,Z);

    if isempty(U)
        error('No compatible underlay variable found in MAT file.');
    end

    U = double(U);
    return;
end

A = imread(fullFile);

if ndims(A) == 3 && size(A,3) == 3
    A = double(A);
    U2 = 0.2989*A(:,:,1) + 0.5870*A(:,:,2) + 0.1140*A(:,:,3);
else
    U2 = double(A);
end

if size(U2,1) ~= Y || size(U2,2) ~= X
    U2 = fcStudioResize2D(U2,Y,X);
end

if Z == 1
    U = reshape(U2,Y,X,1);
else
    U = repmat(U2,[1 1 Z]);
end

isDisplayReady = true;
    end

function [U,isDisplayReady] = fcStudioPickUnderlay(S,Y,X,Z)

U = [];
isDisplayReady = false;

% Prefer Mask Editor bundle first.
if isfield(S,'maskBundle') && isstruct(S.maskBundle)
    [U,isDisplayReady] = fcStudioPickUnderlayFromStruct(S.maskBundle,Y,X,Z);
    if ~isempty(U)
        return;
    end
end

[U,isDisplayReady] = fcStudioPickUnderlayFromStruct(S,Y,X,Z);
end


function [U,isDisplayReady] = fcStudioPickUnderlayFromStruct(S,Y,X,Z)

U = [];
isDisplayReady = false;

% These are already tuned/display-ready.
displayFields = { ...
    'savedUnderlayDisplay', ...
    'savedUnderlayForReload', ...
    'anatomical_reference', ...
    'anatomicalReference', ...
    'brainImage'};

for ii = 1:numel(displayFields)
    fn = displayFields{ii};
    if ~isfield(S,fn)
        continue;
    end

    Ucand = fcStudioUnderlayCandidate(S.(fn),Y,X,Z);

    if isempty(Ucand)
        continue;
    end

    if fcStudioLooksLikeAtlasOrMask(Ucand)
        continue;
    end

    U = Ucand;
    isDisplayReady = true;
    return;
end

% These are raw/base images and should be normalized inside FC.
rawFields = { ...
    'anatomical_reference_raw', ...
    'anatomicalReferenceRaw', ...
    'underlay', ...
    'bg', ...
    'DP', ...
    'dp', ...
    'histology', ...
    'Histology', ...
    'image', ...
    'img', ...
    'I', ...
    'Data'};

for ii = 1:numel(rawFields)
    fn = rawFields{ii};
    if ~isfield(S,fn)
        continue;
    end

    Ucand = fcStudioUnderlayCandidate(S.(fn),Y,X,Z);

    if isempty(Ucand)
        continue;
    end

    if fcStudioLooksLikeAtlasOrMask(Ucand)
        continue;
    end

    U = Ucand;
    isDisplayReady = false;
    return;
end

% Fallback: any numeric non-mask, non-atlas field.
skip = { ...
    'mask','loadedMask','activeMask','brainMask','underlayMask', ...
    'overlayMask','signalMask','roiAtlas','atlas','regions', ...
    'annotation','labels','labelVolume', ...
    'maskIsInclude','loadedMaskIsInclude','overlayMaskIsInclude'};

fns = fieldnames(S);

for ii = 1:numel(fns)
    fn = fns{ii};

    if any(strcmpi(fn,skip))
        continue;
    end

    Ucand = fcStudioUnderlayCandidate(S.(fn),Y,X,Z);

    if isempty(Ucand)
        continue;
    end

    if fcStudioLooksLikeAtlasOrMask(Ucand)
        continue;
    end

    U = Ucand;
    isDisplayReady = false;
    return;
end
end
%%%FUSI_STUDIO_SOURCE_END%%%
%}
