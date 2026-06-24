function standardizedAnalysis(varargin)
% standardizedAnalysis - deConfUSIon guided standardized workflow manager
% -------------------------------------------------------------------------
% NEW STANDALONE FILE. Keep this file in the main deConfUSIon folder.
%
% Purpose
%   Opens a dark workflow popup from fUSI Studio. The user can enable/disable
%   steps, move steps up/down, save/load presets, and run the selected steps.
%
% Design principle
%   This file DOES NOT modify Motor, Imregdemons, QC, Mask Editor, Video, SCM,
%   Registration, or Segmentation internals. It launches the already existing
%   Studio buttons by their labels. Therefore the old manual functionality is
%   preserved.
%
% Minimal Studio hook
%   In fusi_studio_GUI.m, replace one placeholder button with
%   'Standardized Analysis' and add one switch-case mapping that button to:
%
%       standardizedAnalysis(fig);
%
% Compatibility
%   MATLAB R2017b compatible. No App Designer / uifigure required.

% -------------------------------------------------------------------------
% Resolve Studio figure
% -------------------------------------------------------------------------
studioFig = [];
if nargin >= 1
    a = varargin{1};
    if ishghandle(a) && strcmpi(get(a,'Type'),'figure')
        studioFig = a;
    elseif ishghandle(a)
        try
            studioFig = ancestor(a,'figure');
        catch
            studioFig = [];
        end
    end
end

if isempty(studioFig) || ~ishghandle(studioFig)
    figs = findall(0,'Type','figure','Name','deConfUSIon');
    if isempty(figs)
        errordlg('Could not find the open deConfUSIon / fUSI Studio window. Start Studio first.', ...
            'Standardized Analysis');
        return;
    end
    studioFig = figs(1);
end

% Bring Studio path to MATLAB path, useful when called from assembled runtime.
try
    thisDir = fileparts(mfilename('fullpath'));
    if ~isempty(thisDir) && exist(thisDir,'dir')
        addpath(thisDir);
    end
catch
end

% Avoid opening many manager windows.
old = findall(0,'Type','figure','Tag','deconfusion_standardized_analysis_manager');
if ~isempty(old)
    try
        figure(old(1));
        return;
    catch
    end
end

% -------------------------------------------------------------------------
% State
% -------------------------------------------------------------------------
S = struct();
S.studioFig = studioFig;
S.steps = localDefaultSteps();
S.selectedRow = 1;
S.nextRunIndex = 1;
S.rootDir = localRootDir();
S.presetFile = fullfile(S.rootDir,'standardized_workflow_preset.mat');
S.autoPromptAfterManualSteps = true;
S.stopRequested = false;

% -------------------------------------------------------------------------
% UI
% -------------------------------------------------------------------------
bg = [0.035 0.035 0.045];
panelBg = [0.075 0.075 0.090];
fg = [0.92 0.92 0.92];
cyan = [0.35 0.85 1.00];
green = [0.25 0.95 0.45];
orange = [1.00 0.70 0.25];
red = [1.00 0.35 0.35];
blue = [0.20 0.45 0.95];

fig = figure('Name','Standardized Analysis - deConfUSIon', ...
    'Tag','deconfusion_standardized_analysis_manager', ...
    'Color',bg, ...
    'Units','normalized', ...
    'Position',[0.12 0.08 0.76 0.82], ...
    'MenuBar','none', ...
    'ToolBar','none', ...
    'NumberTitle','off', ...
    'Resize','on');

S.managerFig = fig;

guidata(fig,S);

uicontrol('Parent',fig,'Style','text', ...
    'Units','normalized', ...
    'Position',[0.025 0.940 0.630 0.045], ...
    'String','STANDARDIZED ANALYSIS', ...
    'FontSize',24, ...
    'FontWeight','bold', ...
    'HorizontalAlignment','left', ...
    'ForegroundColor',cyan, ...
    'BackgroundColor',bg);

uicontrol('Parent',fig,'Style','text', ...
    'Units','normalized', ...
    'Position',[0.660 0.946 0.315 0.030], ...
    'String','recommended workflow + editable presets', ...
    'FontSize',12, ...
    'FontWeight','bold', ...
    'HorizontalAlignment','right', ...
    'ForegroundColor',[0.75 0.75 0.75], ...
    'BackgroundColor',bg);

% Left panel: recipe table
recipePanel = uipanel('Parent',fig, ...
    'Title','Workflow recipe', ...
    'Units','normalized', ...
    'Position',[0.025 0.180 0.650 0.745], ...
    'BackgroundColor',panelBg, ...
    'ForegroundColor','w', ...
    'FontSize',14, ...
    'FontWeight','bold', ...
    'BorderType','line', ...
    'HighlightColor',[0.40 0.40 0.45], ...
    'ShadowColor',[0.15 0.15 0.18]);

S.table = uitable('Parent',recipePanel, ...
    'Units','normalized', ...
    'Position',[0.025 0.095 0.950 0.875], ...
    'ColumnName',{'Run','Step','Recommended / preset details'}, ...
    'ColumnEditable',[true false false], ...
    'ColumnFormat',{'logical','char','char'}, ...
    'ColumnWidth',{55 190 520}, ...
    'FontSize',11, ...
    'BackgroundColor',[0.10 0.10 0.12; 0.13 0.13 0.16], ...
    'ForegroundColor',[1 1 1], ...
    'CellSelectionCallback',@onTableSelect, ...
    'CellEditCallback',@onTableEdit);

uicontrol('Parent',recipePanel,'Style','text', ...
    'Units','normalized', ...
    'Position',[0.025 0.015 0.950 0.050], ...
    'String','Tip: enable/disable steps directly in the Run column. Select a row, then use Move Up / Move Down to reorder. For example, move Filtering before Imregdemons.', ...
    'FontSize',10, ...
    'FontWeight','bold', ...
    'HorizontalAlignment','left', ...
    'ForegroundColor',[0.82 0.82 0.82], ...
    'BackgroundColor',panelBg);

% Right panel: details and controls
ctrlPanel = uipanel('Parent',fig, ...
    'Title','Controls', ...
    'Units','normalized', ...
    'Position',[0.695 0.180 0.280 0.745], ...
    'BackgroundColor',panelBg, ...
    'ForegroundColor','w', ...
    'FontSize',14, ...
    'FontWeight','bold', ...
    'BorderType','line', ...
    'HighlightColor',[0.40 0.40 0.45], ...
    'ShadowColor',[0.15 0.15 0.18]);

S.detailBox = uicontrol('Parent',ctrlPanel,'Style','edit', ...
    'Units','normalized', ...
    'Position',[0.055 0.630 0.890 0.330], ...
    'Max',8, ...
    'Min',0, ...
    'Enable','inactive', ...
    'HorizontalAlignment','left', ...
    'FontName','Consolas', ...
    'FontSize',10, ...
    'ForegroundColor',[0.90 0.95 1.00], ...
    'BackgroundColor',[0.02 0.02 0.025], ...
    'String','');

S.statusText = uicontrol('Parent',ctrlPanel,'Style','text', ...
    'Units','normalized', ...
    'Position',[0.055 0.545 0.890 0.060], ...
    'String','Ready.', ...
    'FontSize',10, ...
    'FontWeight','bold', ...
    'HorizontalAlignment','left', ...
    'ForegroundColor',green, ...
    'BackgroundColor',panelBg);

S.autoPromptBox = uicontrol('Parent',ctrlPanel,'Style','checkbox', ...
    'Units','normalized', ...
    'Position',[0.055 0.500 0.890 0.035], ...
    'String','Pause/confirm after interactive steps', ...
    'Value',1, ...
    'FontSize',10, ...
    'FontWeight','bold', ...
    'ForegroundColor',[0.95 0.95 0.95], ...
    'BackgroundColor',panelBg, ...
    'Callback',@onAutoPromptToggle);

% Reorder buttons
uicontrol('Parent',ctrlPanel,'Style','pushbutton', ...
    'Units','normalized', ...
    'Position',[0.055 0.435 0.420 0.050], ...
    'String','Move Up', ...
    'FontSize',11, ...
    'FontWeight','bold', ...
    'ForegroundColor','w', ...
    'BackgroundColor',[0.20 0.20 0.22], ...
    'Callback',@onMoveUp);

uicontrol('Parent',ctrlPanel,'Style','pushbutton', ...
    'Units','normalized', ...
    'Position',[0.525 0.435 0.420 0.050], ...
    'String','Move Down', ...
    'FontSize',11, ...
    'FontWeight','bold', ...
    'ForegroundColor','w', ...
    'BackgroundColor',[0.20 0.20 0.22], ...
    'Callback',@onMoveDown);

% Preset buttons
uicontrol('Parent',ctrlPanel,'Style','pushbutton', ...
    'Units','normalized', ...
    'Position',[0.055 0.365 0.420 0.050], ...
    'String','Save Preset', ...
    'FontSize',11, ...
    'FontWeight','bold', ...
    'ForegroundColor','w', ...
    'BackgroundColor',blue, ...
    'Callback',@onSavePreset);

uicontrol('Parent',ctrlPanel,'Style','pushbutton', ...
    'Units','normalized', ...
    'Position',[0.525 0.365 0.420 0.050], ...
    'String','Load Preset', ...
    'FontSize',11, ...
    'FontWeight','bold', ...
    'ForegroundColor','w', ...
    'BackgroundColor',blue, ...
    'Callback',@onLoadPreset);

uicontrol('Parent',ctrlPanel,'Style','pushbutton', ...
    'Units','normalized', ...
    'Position',[0.055 0.295 0.890 0.050], ...
    'String','Restore Recommended Workflow', ...
    'FontSize',11, ...
    'FontWeight','bold', ...
    'ForegroundColor','w', ...
    'BackgroundColor',[0.25 0.25 0.28], ...
    'Callback',@onRestoreRecommended);

% Run buttons
uicontrol('Parent',ctrlPanel,'Style','pushbutton', ...
    'Units','normalized', ...
    'Position',[0.055 0.205 0.890 0.065], ...
    'String','RUN SELECTED WORKFLOW', ...
    'FontSize',13, ...
    'FontWeight','bold', ...
    'ForegroundColor','k', ...
    'BackgroundColor',green, ...
    'Callback',@onRunSelectedWorkflow);

uicontrol('Parent',ctrlPanel,'Style','pushbutton', ...
    'Units','normalized', ...
    'Position',[0.055 0.130 0.420 0.055], ...
    'String','Run Next Step', ...
    'FontSize',11, ...
    'FontWeight','bold', ...
    'ForegroundColor','k', ...
    'BackgroundColor',orange, ...
    'Callback',@onRunNextStep);

uicontrol('Parent',ctrlPanel,'Style','pushbutton', ...
    'Units','normalized', ...
    'Position',[0.525 0.130 0.420 0.055], ...
    'String','Stop', ...
    'FontSize',11, ...
    'FontWeight','bold', ...
    'ForegroundColor','w', ...
    'BackgroundColor',red, ...
    'Callback',@onStopRequested);

uicontrol('Parent',ctrlPanel,'Style','pushbutton', ...
    'Units','normalized', ...
    'Position',[0.055 0.045 0.890 0.055], ...
    'String','Close Workflow Manager', ...
    'FontSize',11, ...
    'FontWeight','bold', ...
    'ForegroundColor','w', ...
    'BackgroundColor',[0.18 0.18 0.20], ...
    'Callback',@(s,e) close(fig));

% Bottom info strip
uicontrol('Parent',fig,'Style','text', ...
    'Units','normalized', ...
    'Position',[0.025 0.080 0.950 0.070], ...
    'String',localBottomHelpText(), ...
    'FontSize',10, ...
    'FontWeight','bold', ...
    'HorizontalAlignment','left', ...
    'ForegroundColor',[0.78 0.78 0.82], ...
    'BackgroundColor',bg);

uicontrol('Parent',fig,'Style','text', ...
    'Units','normalized', ...
    'Position',[0.025 0.030 0.950 0.035], ...
    'String','V1 safety mode: existing Studio modules are launched unchanged. Preset text documents recommended settings; true no-dialog parameter injection can be added later step-by-step.', ...
    'FontSize',10, ...
    'FontWeight','bold', ...
    'HorizontalAlignment','left', ...
    'ForegroundColor',[1.00 0.78 0.35], ...
    'BackgroundColor',bg);

guidata(fig,S);
localRefreshTable(fig);
localRefreshDetail(fig);

% =========================================================================
% UI callbacks
% =========================================================================
    function onTableSelect(~,evt)
        S = guidata(fig);
        if isfield(evt,'Indices') && ~isempty(evt.Indices)
            S.selectedRow = evt.Indices(1,1);
            S.selectedRow = max(1,min(S.selectedRow,numel(S.steps)));
            guidata(fig,S);
            localRefreshDetail(fig);
        end
    end

    function onTableEdit(~,evt)
        S = guidata(fig);
        if isempty(evt.Indices), return; end
        row = evt.Indices(1);
        col = evt.Indices(2);
        if col == 1 && row >= 1 && row <= numel(S.steps)
            try
                S.steps(row).enabled = logical(evt.NewData);
                S.nextRunIndex = min(S.nextRunIndex,numel(S.steps));
            catch
            end
        end
        guidata(fig,S);
        localRefreshTable(fig);
        localRefreshDetail(fig);
    end

    function onAutoPromptToggle(src,~)
        S = guidata(fig);
        S.autoPromptAfterManualSteps = logical(get(src,'Value'));
        guidata(fig,S);
    end

    function onMoveUp(~,~)
        S = guidata(fig);
        i = S.selectedRow;
        if i <= 1, return; end
        tmp = S.steps(i-1);
        S.steps(i-1) = S.steps(i);
        S.steps(i) = tmp;
        S.selectedRow = i-1;
        S.nextRunIndex = min(S.nextRunIndex,numel(S.steps));
        guidata(fig,S);
        localRefreshTable(fig);
        localRefreshDetail(fig);
    end

    function onMoveDown(~,~)
        S = guidata(fig);
        i = S.selectedRow;
        if i >= numel(S.steps), return; end
        tmp = S.steps(i+1);
        S.steps(i+1) = S.steps(i);
        S.steps(i) = tmp;
        S.selectedRow = i+1;
        S.nextRunIndex = min(S.nextRunIndex,numel(S.steps));
        guidata(fig,S);
        localRefreshTable(fig);
        localRefreshDetail(fig);
    end

    function onSavePreset(~,~)
        S = guidata(fig);
        try
            steps = S.steps; %#ok<NASGU>
            autoPromptAfterManualSteps = S.autoPromptAfterManualSteps; %#ok<NASGU>
            save(S.presetFile,'steps','autoPromptAfterManualSteps');
            localSetStatus(fig,sprintf('Preset saved: %s',S.presetFile),[0.25 0.95 0.45]);
        catch ME
            localSetStatus(fig,['Could not save preset: ' ME.message],[1.00 0.35 0.35]);
        end
    end

    function onLoadPreset(~,~)
        S = guidata(fig);
        try
            if ~exist(S.presetFile,'file')
                [f,p] = uigetfile('*.mat','Load standardized workflow preset',S.rootDir);
                if isequal(f,0), return; end
                presetFile = fullfile(p,f);
            else
                presetFile = S.presetFile;
            end
            P = load(presetFile);
            if isfield(P,'steps')
                S.steps = localSanitizeLoadedSteps(P.steps,localDefaultSteps());
            else
                error('Preset does not contain variable steps.');
            end
            if isfield(P,'autoPromptAfterManualSteps')
                S.autoPromptAfterManualSteps = logical(P.autoPromptAfterManualSteps);
                try, set(S.autoPromptBox,'Value',double(S.autoPromptAfterManualSteps)); catch, end
            end
            S.selectedRow = 1;
            S.nextRunIndex = 1;
            guidata(fig,S);
            localRefreshTable(fig);
            localRefreshDetail(fig);
            localSetStatus(fig,sprintf('Preset loaded: %s',presetFile),[0.25 0.95 0.45]);
        catch ME
            localSetStatus(fig,['Could not load preset: ' ME.message],[1.00 0.35 0.35]);
        end
    end

    function onRestoreRecommended(~,~)
        S = guidata(fig);
        S.steps = localDefaultSteps();
        S.selectedRow = 1;
        S.nextRunIndex = 1;
        guidata(fig,S);
        localRefreshTable(fig);
        localRefreshDetail(fig);
        localSetStatus(fig,'Recommended workflow restored.',[0.25 0.95 0.45]);
    end

    function onStopRequested(~,~)
        S = guidata(fig);
        S.stopRequested = true;
        guidata(fig,S);
        localSetStatus(fig,'Stop requested. The current Studio module cannot be interrupted, but no next step will be launched.',[1.00 0.70 0.25]);
    end

    function onRunNextStep(~,~)
        S = guidata(fig);
        idx = localFindNextEnabled(S.steps,S.nextRunIndex);
        if isempty(idx)
            S.nextRunIndex = 1;
            guidata(fig,S);
            localSetStatus(fig,'No remaining enabled steps. Next-step pointer reset to first step.',[0.25 0.95 0.45]);
            return;
        end
        S.nextRunIndex = idx;
        S.stopRequested = false;
        guidata(fig,S);
        ok = localRunOneStep(fig,idx,true);
        S = guidata(fig);
        if ok
            S.nextRunIndex = idx + 1;
        end
        guidata(fig,S);
        localRefreshTable(fig);
    end

    function onRunSelectedWorkflow(~,~)
        S = guidata(fig);
        S.stopRequested = false;
        S.nextRunIndex = 1;
        guidata(fig,S);

        enabledIdx = find([S.steps.enabled]);
        if isempty(enabledIdx)
            localSetStatus(fig,'No workflow steps are enabled.',[1.00 0.35 0.35]);
            return;
        end

        choice = questdlg(sprintf(['Run %d enabled workflow steps now?\n\n' ...
            'This V1 launcher calls the existing Studio buttons unchanged.\n' ...
            'For interactive modules, finish/close the module and confirm to continue.']), ...
            numel(enabledIdx),'Run standardized workflow','Run','Cancel','Run');
        if ~strcmp(choice,'Run')
            localSetStatus(fig,'Workflow run cancelled.',[1.00 0.70 0.25]);
            return;
        end

        for ii = 1:numel(enabledIdx)
            S = guidata(fig);
            if S.stopRequested
                localSetStatus(fig,'Workflow stopped by user.',[1.00 0.70 0.25]);
                break;
            end
            idx = enabledIdx(ii);
            S.nextRunIndex = idx;
            S.selectedRow = idx;
            guidata(fig,S);
            localRefreshTable(fig);
            localRefreshDetail(fig);
            drawnow;
            ok = localRunOneStep(fig,idx,false);
            if ~ok
                S = guidata(fig);
                S.nextRunIndex = idx;
                guidata(fig,S);
                break;
            end
        end

        S = guidata(fig);
        if ~S.stopRequested
            S.nextRunIndex = 1;
            guidata(fig,S);
            localSetStatus(fig,'Selected workflow finished or handed off to the last opened module.',[0.25 0.95 0.45]);
        end
    end
end

% =========================================================================
% Defaults and data helpers
% =========================================================================
function steps = localDefaultSteps()
steps = repmat(localEmptyStep(),1,13);

steps(1) = localStep('motor','Motor','Motor',true,true, ...
    ['Recommended motor settings:' sprintf('\n') ...
     '- 4 slices / split MAT files' sprintf('\n') ...
     '- folder selector should start in loaded data folder' sprintf('\n') ...
     '- residual despiking threshold = 4' sprintf('\n') ...
     '- correction mode = none / mode 1' sprintf('\n') ...
     'V1 opens existing Motor dialog unchanged.']);

steps(2) = localStep('filtering','Filtering','Filtering',false,true, ...
    ['Optional preprocessing step.' sprintf('\n') ...
     '- Can be moved before Imregdemons' sprintf('\n') ...
     '- Keep disabled for the current recommended workflow unless needed.' sprintf('\n') ...
     'V1 opens existing Filtering dialog unchanged.']);

steps(3) = localStep('temporal','Temporal Smoothing/Subsampling','Temporal Smoothing/Subsampling',false,true, ...
    ['Optional preprocessing step.' sprintf('\n') ...
     '- Can be moved before or after Imregdemons' sprintf('\n') ...
     '- Keep disabled for current recommended workflow unless needed.']);

steps(4) = localStep('despike','Despike','Despike',false,true, ...
    ['Optional standalone despiking step.' sprintf('\n') ...
     '- Current requested residual despiking = 4 is intended inside Motor.' sprintf('\n') ...
     '- Enable only if you want extra standalone despiking.']);

steps(5) = localStep('imreg','Imregdemons','Imregdemons',true,true, ...
    ['Recommended Imregdemons settings:' sprintf('\n') ...
     '- nsub / n = 25' sprintf('\n') ...
     '- median block mode' sprintf('\n') ...
     '- step-motor / per-slice mode for 4-slice motor data' sprintf('\n') ...
     'V1 opens existing Imregdemons dialog unchanged.']);

steps(6) = localStep('qc','Full QC','Full QC',true,true, ...
    ['Recommended QC:' sprintf('\n') ...
     '- Full QC after Imregdemons' sprintf('\n') ...
     '- Use newest active processed dataset.']);

steps(7) = localStep('mask','Mask Editor','Mask Editor',true,true, ...
    ['Interactive step:' sprintf('\n') ...
     '- Opens Mask Editor' sprintf('\n') ...
     '- Save underlay / brain mask' sprintf('\n') ...
     '- Close Mask Editor when finished' sprintf('\n') ...
     '- Workflow then continues after confirmation.']);

steps(8) = localStep('video','Video GUI','Video & SCM Mask',true,true, ...
    ['Recommended Video GUI settings:' sprintf('\n') ...
     '- baseline = 30-35 s' sprintf('\n') ...
     '- standardized/recommended underlay mode' sprintf('\n') ...
     '- signed positive + negative signal change' sprintf('\n') ...
     '- caxis/signal range = -100 to +100 %' sprintf('\n') ...
     '- alpha modulation: abs 20 to 100 %, alpha 100 %' sprintf('\n') ...
     'V1 opens existing Video GUI unchanged.']);

steps(9) = localStep('scm','SCM GUI','SCM',true,true, ...
    ['Recommended SCM settings:' sprintf('\n') ...
     '- baseline = 30-35 s' sprintf('\n') ...
     '- signed positive + negative signal change' sprintf('\n') ...
     '- caxis/signal range = -100 to +100 %' sprintf('\n') ...
     '- alpha modulation: abs 20 to 100 %, alpha 100 %' sprintf('\n') ...
     'V1 opens existing SCM GUI unchanged.']);

steps(10) = localStep('registration','Registration to Atlas','Registration to Atlas',true,true, ...
    ['Interactive step:' sprintf('\n') ...
     '- Opens existing Registration to Atlas workflow' sprintf('\n') ...
     '- For 4-slice step-motor data, use 2D/slice registration if offered' sprintf('\n') ...
     '- Close registration when finished.']);

steps(11) = localStep('segmentation','Segmentation','Segmentation',true,true, ...
    ['Recommended next step after registration:' sprintf('\n') ...
     '- Opens segmentation popup' sprintf('\n') ...
     '- Use existing segmentation settings.']);

steps(12) = localStep('fc','Functional Connectivity','Functional connectivity',false,true, ...
    ['Optional advanced analysis.' sprintf('\n') ...
     '- Disabled in current recommended workflow' sprintf('\n') ...
     '- Enable when you want to continue into FC.']);

steps(13) = localStep('ga','Group Analysis','Group analysis',false,true, ...
    ['Optional group-level analysis.' sprintf('\n') ...
     '- Disabled in current recommended workflow' sprintf('\n') ...
     '- Enable after single-subject outputs are ready.']);
end

function s = localEmptyStep()
s = struct('id','','name','','buttonLabel','','enabled',false,'manual',true,'detail','');
end

function s = localStep(id,name,buttonLabel,enabled,manual,detail)
s = localEmptyStep();
s.id = id;
s.name = name;
s.buttonLabel = buttonLabel;
s.enabled = enabled;
s.manual = manual;
s.detail = detail;
end

function rootDir = localRootDir()
try
    rootDir = fileparts(mfilename('fullpath'));
    if isempty(rootDir) || ~exist(rootDir,'dir')
        rootDir = pwd;
    end
catch
    rootDir = pwd;
end
end

function steps = localSanitizeLoadedSteps(stepsIn,defaults)
steps = defaults;
try
    if ~isstruct(stepsIn) || isempty(stepsIn)
        return;
    end
    required = {'id','name','buttonLabel','enabled','manual','detail'};
    for i = 1:numel(stepsIn)
        for r = 1:numel(required)
            if ~isfield(stepsIn,required{r})
                error('Missing field.');
            end
        end
    end
    steps = stepsIn(:).';
catch
    steps = defaults;
end
end

function str = localBottomHelpText()
str = ['Safe workflow manager: this window only stores the recipe and launches your existing Studio modules. ' ...
       'It intentionally does not inject parameters into Motor/Imregdemons/Video/SCM yet, so old behavior remains unchanged. ' ...
       'After this V1 is stable, individual modules can be upgraded to accept standardized no-dialog options.'];
end

% =========================================================================
% UI refresh helpers
% =========================================================================
function localRefreshTable(fig)
S = guidata(fig);
N = numel(S.steps);
data = cell(N,3);
for i = 1:N
    step = S.steps(i);
    data{i,1} = logical(step.enabled);
    prefix = sprintf('%02d. ',i);
    data{i,2} = [prefix step.name];
    d = step.detail;
    d = strrep(d,sprintf('\r'),' ');
    d = strrep(d,sprintf('\n'),' | ');
    d = regexprep(d,'\s+',' ');
    data{i,3} = d;
end
try
    set(S.table,'Data',data);
catch
end
end

function localRefreshDetail(fig)
S = guidata(fig);
if isempty(S.steps), return; end
i = max(1,min(S.selectedRow,numel(S.steps)));
step = S.steps(i);
runTxt = 'OFF';
if step.enabled, runTxt = 'ON'; end
manualTxt = 'interactive/manual';
if ~step.manual, manualTxt = 'automatic'; end
msg = sprintf('%02d. %s\nRun: %s\nLaunches Studio button: %s\nMode: %s\n\n%s', ...
    i,step.name,runTxt,step.buttonLabel,manualTxt,step.detail);
try
    set(S.detailBox,'String',msg);
catch
end
end

function localSetStatus(fig,msg,color)
if nargin < 3 || isempty(color), color = [0.25 0.95 0.45]; end
try
    S = guidata(fig);
    set(S.statusText,'String',msg,'ForegroundColor',color);
    drawnow;
catch
end
try
    fprintf('[Standardized Analysis] %s\n',msg);
catch
end
end

function idx = localFindNextEnabled(steps,startIdx)
idx = [];
if isempty(steps), return; end
startIdx = max(1,startIdx);
for i = startIdx:numel(steps)
    if steps(i).enabled
        idx = i;
        return;
    end
end
end

% =========================================================================
% Runner helpers
% =========================================================================
function ok = localRunOneStep(managerFig,idx,singleStepMode)
ok = false;
S = guidata(managerFig);
if idx < 1 || idx > numel(S.steps)
    localSetStatus(managerFig,'Invalid workflow step index.',[1.00 0.35 0.35]);
    return;
end
step = S.steps(idx);
if ~step.enabled
    localSetStatus(managerFig,sprintf('Skipped disabled step: %s',step.name),[1.00 0.70 0.25]);
    ok = true;
    return;
end

if ~ishghandle(S.studioFig)
    localSetStatus(managerFig,'Studio window is no longer available.',[1.00 0.35 0.35]);
    return;
end

localSetStatus(managerFig,sprintf('Launching %02d/%02d: %s',idx,numel(S.steps),step.name),[0.35 0.85 1.00]);
drawnow;

try
    localStudioLog(S.studioFig,sprintf('Standardized workflow launching: %s',step.name));
catch
end

try
    btn = localFindStudioButton(S.studioFig,step.buttonLabel);
    if isempty(btn) || ~ishghandle(btn)
        error('Could not find enabled Studio button named "%s".',step.buttonLabel);
    end
    if strcmpi(get(btn,'Enable'),'off')
        choice = questdlg(sprintf(['The Studio button "%s" is currently disabled.\n\n' ...
            'This usually means no dataset is loaded or the step is not available yet.\n\n' ...
            'Skip this step or stop workflow?'],step.buttonLabel), ...
            'Step not available','Skip','Stop','Skip');
        if strcmp(choice,'Skip')
            localSetStatus(managerFig,sprintf('Skipped unavailable step: %s',step.name),[1.00 0.70 0.25]);
            ok = true;
        else
            localSetStatus(managerFig,sprintf('Stopped before unavailable step: %s',step.name),[1.00 0.35 0.35]);
        end
        return;
    end

    cb = get(btn,'Callback');
    if isempty(cb)
        error('The Studio button "%s" has no callback.',step.buttonLabel);
    end

    % Bring Studio to front, then execute its existing callback.
    try, figure(S.studioFig); catch, end
    drawnow;
    localExecuteCallback(cb,btn,[]);

    ok = true;
    localSetStatus(managerFig,sprintf('Step launched/finished: %s',step.name),[0.25 0.95 0.45]);

    S = guidata(managerFig);
    if step.manual && S.autoPromptAfterManualSteps
        try, figure(managerFig); catch, end
        drawnow;
        if singleStepMode
            msg = sprintf(['Step launched: %s\n\n' ...
                'Finish/close the opened Studio module if it is still open.\n' ...
                'Use "Run Next Step" when you want to continue.'],step.name);
            helpdlg(msg,'Standardized Analysis');
        else
            choice = questdlg(sprintf(['Step launched: %s\n\n' ...
                'Finish/close the opened Studio module if needed.\n\n' ...
                'Continue with the next enabled workflow step?'],step.name), ...
                'Continue standardized workflow','Continue','Stop','Continue');
            if strcmp(choice,'Stop')
                S = guidata(managerFig);
                S.stopRequested = true;
                guidata(managerFig,S);
                localSetStatus(managerFig,'Workflow stopped after interactive step.',[1.00 0.70 0.25]);
            end
        end
    end
catch ME
    localSetStatus(managerFig,['Workflow step failed: ' ME.message],[1.00 0.35 0.35]);
    try
        errordlg(sprintf('Step failed:\n\n%s\n\n%s',step.name,ME.message),'Standardized Analysis');
    catch
    end
end
end

function btn = localFindStudioButton(studioFig,label)
btn = [];
try
    hs = findall(studioFig,'Style','pushbutton');
catch
    hs = [];
end
if isempty(hs), return; end

% Prefer exact visible string match.
for i = 1:numel(hs)
    try
        s = get(hs(i),'String');
        if iscell(s), s = s{1}; end
        if ischar(s) && strcmpi(strtrim(s),strtrim(label))
            btn = hs(i);
            return;
        end
    catch
    end
end

% Fallback normalized whitespace.
labelKey = lower(regexprep(strtrim(label),'\s+',' '));
for i = 1:numel(hs)
    try
        s = get(hs(i),'String');
        if iscell(s), s = s{1}; end
        sKey = lower(regexprep(strtrim(char(s)),'\s+',' '));
        if strcmp(sKey,labelKey)
            btn = hs(i);
            return;
        end
    catch
    end
end
end

function localExecuteCallback(cb,src,evt)
if isa(cb,'function_handle')
    feval(cb,src,evt);
elseif iscell(cb) && ~isempty(cb)
    f = cb{1};
    args = cb(2:end);
    if isa(f,'function_handle')
        feval(f,src,evt,args{:});
    elseif ischar(f)
        feval(f,src,evt,args{:});
    else
        error('Unsupported callback cell format.');
    end
elseif ischar(cb)
    evalin('base',cb);
else
    error('Unsupported callback type.');
end
end

function localStudioLog(studioFig,msg)
% Best-effort log injection without depending on nested addLog.
try
    S = guidata(studioFig);
    if isfield(S,'logBoxJava') && ~isempty(S.logBoxJava)
        try
            old = char(S.logBoxJava.getText());
            S.logBoxJava.setText(sprintf('%s\n%s',old,msg));
            return;
        catch
        end
    end
    if isfield(S,'logBox') && ishghandle(S.logBox)
        old = get(S.logBox,'String');
        if ischar(old), old = cellstr(old); end
        old{end+1} = msg;
        set(S.logBox,'String',old,'Value',numel(old));
    end
catch
end
end
