function standardizedAnalysis(varargin)
% standardizedAnalysis - deConfUSIon guided standardized workflow manager
% -------------------------------------------------------------------------
% STANDALONE FILE. Keep this file in the main deConfUSIon folder.
%
% Purpose
%   Opens a large dark workflow popup from fUSI Studio. The user can
%   enable/disable steps, reorder them, edit recommended/preset details,
%   save/load presets, and launch the existing Studio modules.
%
% Important safety principle
%   This file DOES NOT modify Motor, Imregdemons, QC, Mask Editor, Video,
%   SCM, Registration, Segmentation, or any other processing module. It only
%   launches the already existing Studio buttons by their labels. Therefore
%   old manual functionality is preserved.
%
% Notes
%   - The editable preset text is saved and can document settings such as
%     motor.nSlices = 2..6, imregdemons.nsub = 25, video baseline = 30..35 s.
%   - V2 still does not inject these values into the downstream module
%     dialogs. That can be added later step-by-step as optional no-dialog
%     mode in each module.
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
S.clipboardStep = [];
S.nextRunIndex = 1;
S.rootDir = localRootDir();
S.presetFile = fullfile(S.rootDir,'standardized_workflow_preset.mat');
S.autoPromptAfterManualSteps = true;
S.stopRequested = false;

% -------------------------------------------------------------------------
% UI colors
% -------------------------------------------------------------------------
bg = [0.030 0.030 0.040];
panelBg = [0.070 0.070 0.090];
fieldBg = [0.020 0.020 0.026];
fg = [0.94 0.94 0.94]; %#ok<NASGU>
cyan = [0.35 0.85 1.00];
green = [0.25 0.95 0.45];
orange = [1.00 0.70 0.25];
red = [1.00 0.35 0.35];
blue = [0.20 0.45 0.95];

fig = figure('Name','Standardized Analysis - deConfUSIon', ...
    'Tag','deconfusion_standardized_analysis_manager', ...
    'Color',bg, ...
    'Units','normalized', ...
    'Position',[0.015 0.035 0.970 0.920], ...
    'MenuBar','none', ...
    'ToolBar','none', ...
    'NumberTitle','off', ...
    'Resize','on');

try, set(fig,'WindowState','maximized'); catch, end
S.managerFig = fig;
guidata(fig,S);

uicontrol('Parent',fig,'Style','text', ...
    'Units','normalized', ...
    'Position',[0.020 0.940 0.660 0.045], ...
    'String','STANDARDIZED ANALYSIS', ...
    'FontSize',28, ...
    'FontWeight','bold', ...
    'HorizontalAlignment','left', ...
    'ForegroundColor',cyan, ...
    'BackgroundColor',bg);

uicontrol('Parent',fig,'Style','text', ...
    'Units','normalized', ...
    'Position',[0.690 0.947 0.290 0.030], ...
    'String','large editable recipe + workflow presets', ...
    'FontSize',14, ...
    'FontWeight','bold', ...
    'HorizontalAlignment','right', ...
    'ForegroundColor',[0.78 0.78 0.82], ...
    'BackgroundColor',bg);

% -------------------------------------------------------------------------
% Left panel: large recipe table
% -------------------------------------------------------------------------
recipePanel = uipanel('Parent',fig, ...
    'Title','Workflow recipe: tick steps, edit presets, reorder steps', ...
    'Units','normalized', ...
    'Position',[0.020 0.115 0.700 0.815], ...
    'BackgroundColor',panelBg, ...
    'ForegroundColor','w', ...
    'FontSize',17, ...
    'FontWeight','bold', ...
    'BorderType','line', ...
    'HighlightColor',[0.45 0.45 0.50], ...
    'ShadowColor',[0.12 0.12 0.16]);

S.table = uitable('Parent',recipePanel, ...
    'Units','normalized', ...
    'Position',[0.015 0.080 0.970 0.895], ...
    'ColumnName',{'Run','Step','Recommended / editable preset','Studio button'}, ...
    'ColumnEditable',[true false true false], ...
    'ColumnFormat',{'logical','char','char','char'}, ...
    'ColumnWidth',{65 245 760 170}, ...
    'FontSize',13, ...
    'BackgroundColor',[0.10 0.10 0.12; 0.15 0.15 0.18], ...
    'ForegroundColor',[1 1 1], ...
    'CellSelectionCallback',@onTableSelect, ...
    'CellEditCallback',@onTableEdit);

uicontrol('Parent',recipePanel,'Style','text', ...
    'Units','normalized', ...
    'Position',[0.015 0.020 0.970 0.040], ...
    'String','Tip: select a row, edit the preset text directly in the table or in the right editor, then press Apply. Reorder using Move/Cut/Insert controls.', ...
    'FontSize',12, ...
    'FontWeight','bold', ...
    'HorizontalAlignment','left', ...
    'ForegroundColor',[0.84 0.84 0.86], ...
    'BackgroundColor',panelBg);

% -------------------------------------------------------------------------
% Right panel: selected step editor + controls
% -------------------------------------------------------------------------
ctrlPanel = uipanel('Parent',fig, ...
    'Title','Selected step editor / controls', ...
    'Units','normalized', ...
    'Position',[0.735 0.115 0.245 0.815], ...
    'BackgroundColor',panelBg, ...
    'ForegroundColor','w', ...
    'FontSize',17, ...
    'FontWeight','bold', ...
    'BorderType','line', ...
    'HighlightColor',[0.45 0.45 0.50], ...
    'ShadowColor',[0.12 0.12 0.16]);

uicontrol('Parent',ctrlPanel,'Style','text', ...
    'Units','normalized', ...
    'Position',[0.050 0.935 0.900 0.032], ...
    'String','Editable preset/details for selected step', ...
    'FontSize',13, ...
    'FontWeight','bold', ...
    'HorizontalAlignment','left', ...
    'ForegroundColor',cyan, ...
    'BackgroundColor',panelBg);

S.detailBox = uicontrol('Parent',ctrlPanel,'Style','edit', ...
    'Units','normalized', ...
    'Position',[0.050 0.625 0.900 0.305], ...
    'Max',20, ...
    'Min',0, ...
    'Enable','on', ...
    'HorizontalAlignment','left', ...
    'FontName','Consolas', ...
    'FontSize',12, ...
    'ForegroundColor',[0.92 0.97 1.00], ...
    'BackgroundColor',fieldBg, ...
    'String','');

uicontrol('Parent',ctrlPanel,'Style','pushbutton', ...
    'Units','normalized', ...
    'Position',[0.050 0.570 0.900 0.045], ...
    'String','Apply Edited Preset To Selected Step', ...
    'FontSize',12, ...
    'FontWeight','bold', ...
    'ForegroundColor','k', ...
    'BackgroundColor',cyan, ...
    'Callback',@onApplyDetailEdit);

S.statusText = uicontrol('Parent',ctrlPanel,'Style','text', ...
    'Units','normalized', ...
    'Position',[0.050 0.520 0.900 0.040], ...
    'String','Ready.', ...
    'FontSize',12, ...
    'FontWeight','bold', ...
    'HorizontalAlignment','left', ...
    'ForegroundColor',green, ...
    'BackgroundColor',panelBg);

S.autoPromptBox = uicontrol('Parent',ctrlPanel,'Style','checkbox', ...
    'Units','normalized', ...
    'Position',[0.050 0.480 0.900 0.032], ...
    'String','Pause/confirm after interactive steps', ...
    'Value',1, ...
    'FontSize',12, ...
    'FontWeight','bold', ...
    'ForegroundColor',[0.95 0.95 0.95], ...
    'BackgroundColor',panelBg, ...
    'Callback',@onAutoPromptToggle);

% Reorder controls
uicontrol('Parent',ctrlPanel,'Style','text', ...
    'Units','normalized', ...
    'Position',[0.050 0.438 0.900 0.030], ...
    'String','Reorder selected step', ...
    'FontSize',13, ...
    'FontWeight','bold', ...
    'HorizontalAlignment','left', ...
    'ForegroundColor',[1.00 0.86 0.45], ...
    'BackgroundColor',panelBg);

makeBtn(ctrlPanel,[0.050 0.393 0.420 0.040],'Move Up',[0.20 0.20 0.22],'w',@onMoveUp);
makeBtn(ctrlPanel,[0.530 0.393 0.420 0.040],'Move Down',[0.20 0.20 0.22],'w',@onMoveDown);
makeBtn(ctrlPanel,[0.050 0.347 0.420 0.040],'To Top',[0.20 0.20 0.22],'w',@onMoveTop);
makeBtn(ctrlPanel,[0.530 0.347 0.420 0.040],'To Bottom',[0.20 0.20 0.22],'w',@onMoveBottom);
makeBtn(ctrlPanel,[0.050 0.301 0.420 0.040],'Cut Step',[0.35 0.22 0.08],'w',@onCutStep);
makeBtn(ctrlPanel,[0.530 0.301 0.420 0.040],'Insert Above',[0.35 0.22 0.08],'w',@onInsertAbove);
makeBtn(ctrlPanel,[0.050 0.255 0.900 0.040],'Insert Cut Step Below Selected Row',[0.35 0.22 0.08],'w',@onInsertBelow);

% Preset buttons
makeBtn(ctrlPanel,[0.050 0.197 0.420 0.045],'Save Preset',blue,'w',@onSavePreset);
makeBtn(ctrlPanel,[0.530 0.197 0.420 0.045],'Load Preset',blue,'w',@onLoadPreset);
makeBtn(ctrlPanel,[0.050 0.146 0.900 0.045],'Restore Recommended Workflow',[0.25 0.25 0.28],'w',@onRestoreRecommended);

% Run buttons
makeBtn(ctrlPanel,[0.050 0.082 0.900 0.052],'RUN SELECTED WORKFLOW',green,'k',@onRunSelectedWorkflow);
makeBtn(ctrlPanel,[0.050 0.029 0.420 0.042],'Run Next Step',orange,'k',@onRunNextStep);
makeBtn(ctrlPanel,[0.530 0.029 0.420 0.042],'Stop',red,'w',@onStopRequested);

% Bottom info strips
uicontrol('Parent',fig,'Style','text', ...
    'Units','normalized', ...
    'Position',[0.020 0.060 0.960 0.038], ...
    'String',localBottomHelpText(), ...
    'FontSize',12, ...
    'FontWeight','bold', ...
    'HorizontalAlignment','left', ...
    'ForegroundColor',[0.80 0.80 0.84], ...
    'BackgroundColor',bg);

uicontrol('Parent',fig,'Style','text', ...
    'Units','normalized', ...
    'Position',[0.020 0.020 0.960 0.030], ...
    'String','V2 safety mode: this manager stores editable recommended settings and launches existing Studio modules. It does not yet inject parameters into module dialogs.', ...
    'FontSize',12, ...
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
        if row < 1 || row > numel(S.steps), return; end
        if col == 1
            try
                S.steps(row).enabled = logical(evt.NewData);
                S.nextRunIndex = min(S.nextRunIndex,numel(S.steps));
            catch
            end
        elseif col == 3
            try
                S.steps(row).detail = char(evt.NewData);
                S.selectedRow = row;
            catch
            end
        end
        guidata(fig,S);
        localRefreshTable(fig);
        localRefreshDetail(fig);
    end

    function onApplyDetailEdit(~,~)
        S = guidata(fig);
        if isempty(S.steps), return; end
        i = max(1,min(S.selectedRow,numel(S.steps)));
        try
            val = get(S.detailBox,'String');
            if iscell(val)
                val = sprintf('%s\n',val{:});
                if ~isempty(val), val = val(1:end-1); end
            end
            S.steps(i).detail = char(val);
            guidata(fig,S);
            localRefreshTable(fig);
            localRefreshDetail(fig);
            localSetStatus(fig,sprintf('Updated preset/details for: %s',S.steps(i).name),[0.25 0.95 0.45]);
        catch ME
            localSetStatus(fig,['Could not apply edited preset: ' ME.message],[1.00 0.35 0.35]);
        end
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

    function onMoveTop(~,~)
        S = guidata(fig);
        i = S.selectedRow;
        if i <= 1, return; end
        st = S.steps(i);
        S.steps(i) = [];
        S.steps = [st S.steps];
        S.selectedRow = 1;
        S.nextRunIndex = min(S.nextRunIndex,numel(S.steps));
        guidata(fig,S);
        localRefreshTable(fig);
        localRefreshDetail(fig);
    end

    function onMoveBottom(~,~)
        S = guidata(fig);
        i = S.selectedRow;
        if i >= numel(S.steps), return; end
        st = S.steps(i);
        S.steps(i) = [];
        S.steps = [S.steps st];
        S.selectedRow = numel(S.steps);
        S.nextRunIndex = min(S.nextRunIndex,numel(S.steps));
        guidata(fig,S);
        localRefreshTable(fig);
        localRefreshDetail(fig);
    end

    function onCutStep(~,~)
        S = guidata(fig);
        if isempty(S.steps), return; end
        i = max(1,min(S.selectedRow,numel(S.steps)));
        S.clipboardStep = S.steps(i);
        S.steps(i) = [];
        if isempty(S.steps)
            S.steps = localDefaultSteps();
            S.selectedRow = 1;
            localSetStatus(fig,'Cannot remove all steps. Restored default workflow.',[1.00 0.70 0.25]);
        else
            S.selectedRow = max(1,min(i,numel(S.steps)));
            localSetStatus(fig,sprintf('Cut step: %s. Select target row and insert above/below.',S.clipboardStep.name),[1.00 0.70 0.25]);
        end
        S.nextRunIndex = min(S.nextRunIndex,numel(S.steps));
        guidata(fig,S);
        localRefreshTable(fig);
        localRefreshDetail(fig);
    end

    function onInsertAbove(~,~)
        S = guidata(fig);
        if isempty(S.clipboardStep)
            localSetStatus(fig,'No cut step in clipboard.',[1.00 0.70 0.25]);
            return;
        end
        i = max(1,min(S.selectedRow,numel(S.steps)));
        S.steps = [S.steps(1:i-1) S.clipboardStep S.steps(i:end)];
        S.selectedRow = i;
        S.clipboardStep = [];
        S.nextRunIndex = min(S.nextRunIndex,numel(S.steps));
        guidata(fig,S);
        localRefreshTable(fig);
        localRefreshDetail(fig);
        localSetStatus(fig,'Inserted cut step above selected row.',[0.25 0.95 0.45]);
    end

    function onInsertBelow(~,~)
        S = guidata(fig);
        if isempty(S.clipboardStep)
            localSetStatus(fig,'No cut step in clipboard.',[1.00 0.70 0.25]);
            return;
        end
        i = max(1,min(S.selectedRow,numel(S.steps)));
        S.steps = [S.steps(1:i) S.clipboardStep S.steps(i+1:end)];
        S.selectedRow = i+1;
        S.clipboardStep = [];
        S.nextRunIndex = min(S.nextRunIndex,numel(S.steps));
        guidata(fig,S);
        localRefreshTable(fig);
        localRefreshDetail(fig);
        localSetStatus(fig,'Inserted cut step below selected row.',[0.25 0.95 0.45]);
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
        S.clipboardStep = [];
        guidata(fig,S);
        localRefreshTable(fig);
        localRefreshDetail(fig);
        localSetStatus(fig,'Recommended workflow restored.',[0.25 0.95 0.45]);
    end

    function onStopRequested(~,~)
        S = guidata(fig);
        S.stopRequested = true;
        guidata(fig,S);
        localSetStatus(fig,'Stop requested. Current Studio module cannot be interrupted, but no next step will be launched.',[1.00 0.70 0.25]);
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
            'This V2 launcher calls the existing Studio buttons unchanged.\n' ...
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
% Small UI factory
% =========================================================================
function h = makeBtn(parent,pos,str,bg,fg,cb)
h = uicontrol('Parent',parent,'Style','pushbutton', ...
    'Units','normalized', ...
    'Position',pos, ...
    'String',str, ...
    'FontSize',12, ...
    'FontWeight','bold', ...
    'ForegroundColor',fg, ...
    'BackgroundColor',bg, ...
    'Callback',cb);
end

% =========================================================================
% Defaults and data helpers
% =========================================================================
function steps = localDefaultSteps()
steps = repmat(localEmptyStep(),1,17);

steps(1) = localStep('frame_rejection','Frame Rejection','Frame Rejection',false,true, ...
    ['Optional early QC/preprocessing.\n' ...
     'Recommended preset: disabled for current motor-first workflow unless raw frame rejection is needed.\n' ...
     'Purpose: identify unstable / rejected frames and create validated interpolated dataset.\n' ...
     'User-editable notes: rejection threshold, interpolation mode, whether to run before Motor.']);

steps(2) = localStep('motor','Motor','Motor',true,true, ...
    ['Recommended motor settings:\n' ...
     'motor.sourceMode = split MAT folder\n' ...
     'motor.rawFolder = folder of loaded data / current run folder\n' ...
     'motor.nSlices = 4    allowed editable range: 2-6 slices\n' ...
     'motor.residualDespikeThreshold = 4\n' ...
     'motor.correctionMode = none / mode 1\n' ...
     'motor.output = assembled 4D step-motor dataset [Y X Z T]\n' ...
     'V2 opens existing Motor dialog unchanged; this preset text is saved for reproducibility.']);

steps(3) = localStep('filtering','Filtering','Filtering',false,true, ...
    ['Optional preprocessing step.\n' ...
     'Can be moved before Imregdemons if desired.\n' ...
     'Example editable preset: bandpass 0.01-0.10 Hz or low-pass 0.10 Hz.\n' ...
     'Recommended current workflow: disabled unless explicitly needed.']);

steps(4) = localStep('temporal','Temporal Smoothing/Subsampling','Temporal Smoothing/Subsampling',false,true, ...
    ['Optional temporal preprocessing.\n' ...
     'Editable preset: smoothing window / subsampling factor / target frame rate.\n' ...
     'Recommended current workflow: disabled unless needed for a specific analysis.']);

steps(5) = localStep('scrubbing','Scrubbing','Scrubbing',false,true, ...
    ['Optional artifact scrubbing.\n' ...
     'Can be placed before or after Imregdemons depending on your experimental logic.\n' ...
     'Editable preset: method, threshold, interpolation method.\n' ...
     'Recommended current workflow: disabled unless outlier frames remain problematic.']);

steps(6) = localStep('pca_ica','PCA / ICA','PCA / ICA',false,true, ...
    ['Optional denoising.\n' ...
     'Use PCA for variance/component inspection or ICA for component-based denoising.\n' ...
     'Editable preset: method = PCA or ICA, component count, selected components to remove.\n' ...
     'Recommended current workflow: disabled by default.']);

steps(7) = localStep('despike','Despike','Despike',false,true, ...
    ['Optional standalone despiking step.\n' ...
     'Note: requested residual despiking threshold = 4 is intended inside Motor.\n' ...
     'Enable only if you want extra standalone despiking after another step.']);

steps(8) = localStep('imreg','Imregdemons','Imregdemons',true,true, ...
    ['Recommended Imregdemons settings:\n' ...
     'imregdemons.nsub = 25\n' ...
     'imregdemons.blockMethod = median\n' ...
     'imregdemons.mode = step-motor / per-slice 2D for 4-slice motor data\n' ...
     'imregdemons.output = newest active motion-corrected dataset\n' ...
     'V2 opens existing Imregdemons dialog unchanged; this preset text is saved.']);

steps(9) = localStep('qc','Full QC','Full QC',true,true, ...
    ['Recommended QC after Imregdemons:\n' ...
     'qc.mode = full\n' ...
     'qc.source = newest active processed dataset\n' ...
     'qc.outputs = frequency/spatial/temporal/tSNR/SNR-CNR/stability/rejection plots where available.']);

steps(10) = localStep('mask','Mask Editor','Mask Editor',true,true, ...
    ['Interactive masking step.\n' ...
     'Open Mask Editor, create/save underlay brain mask and/or overlay mask.\n' ...
     'Close Mask Editor when finished. Workflow then continues after confirmation.\n' ...
     'Recommended: save underlay/brain mask before Video GUI and SCM GUI.']);

steps(11) = localStep('timecourse','Time-Course Viewer','Time-Course Viewer',false,true, ...
    ['Optional visualization / inspection step.\n' ...
     'Use to inspect ROI/global time courses before Video/SCM or after masking.\n' ...
     'Recommended current workflow: disabled by default but available.']);

steps(12) = localStep('video','Video GUI','Video & SCM Mask',true,true, ...
    ['Recommended Video GUI settings:\n' ...
     'video.baselineSec = [30 35]\n' ...
     'video.underlayMode = standardized / recommended SCM-log-median underlay\n' ...
     'video.signMode = positive + negative signal change\n' ...
     'video.signalCaxisPct = [-100 100]\n' ...
     'video.alphaAbsPct = [20 100]\n' ...
     'video.alphaMaxPct = 100\n' ...
     'V2 opens existing Video GUI unchanged; this preset text is saved.']);

steps(13) = localStep('scm','SCM GUI','SCM',true,true, ...
    ['Recommended SCM GUI settings:\n' ...
     'scm.baselineSec = [30 35]\n' ...
     'scm.signMode = positive + negative signal change\n' ...
     'scm.signalCaxisPct = [-100 100]\n' ...
     'scm.alphaAbsPct = [20 100]\n' ...
     'scm.alphaMaxPct = 100\n' ...
     'V2 opens existing SCM GUI unchanged; this preset text is saved.']);

steps(14) = localStep('registration','Registration to Atlas','Registration to Atlas',true,true, ...
    ['Interactive registration step.\n' ...
     'Recommended for 4-slice step-motor data: use 2D/slice registration if offered.\n' ...
     'Close registration when finished. Workflow then continues after confirmation.']);

steps(15) = localStep('segmentation','Segmentation','Segmentation',true,true, ...
    ['Recommended next step after registration.\n' ...
     'Open segmentation popup and generate/load atlas/ROI segmentation.\n' ...
     'Use existing segmentation settings.']);

steps(16) = localStep('fc','Functional Connectivity','Functional connectivity',false,true, ...
    ['Optional advanced analysis after segmentation.\n' ...
     'Editable preset: seed ROI, ROI set, hemisphere mode, windows, Fisher/Pearson output.\n' ...
     'Recommended current workflow: disabled until single-subject preprocessing is complete.']);

steps(17) = localStep('ga','Group Analysis','Group analysis',false,true, ...
    ['Optional group-level analysis.\n' ...
     'Use after single-subject outputs or FC bundles are ready.\n' ...
     'Recommended current workflow: disabled by default.']);
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
str = ['Safe workflow manager: this window stores a reproducible recipe and launches existing Studio modules. ' ...
       'Because MATLAB R2017b uitable drag/drop is not officially supported, reorder uses Move/Cut/Insert controls instead of fragile Java drag hacks.'];
end

% =========================================================================
% UI refresh helpers
% =========================================================================
function localRefreshTable(fig)
S = guidata(fig);
N = numel(S.steps);
data = cell(N,4);
for i = 1:N
    step = S.steps(i);
    data{i,1} = logical(step.enabled);
    data{i,2} = sprintf('%02d. %s',i,step.name);
    data{i,3} = localOneLine(step.detail);
    data{i,4} = step.buttonLabel;
end
try
    set(S.table,'Data',data);
catch
end
end

function txt = localOneLine(txt)
try
    txt = char(txt);
    txt = strrep(txt,sprintf('\r'),' ');
    txt = strrep(txt,sprintf('\n'),' | ');
    txt = regexprep(txt,'\s+',' ');
catch
    txt = '';
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
