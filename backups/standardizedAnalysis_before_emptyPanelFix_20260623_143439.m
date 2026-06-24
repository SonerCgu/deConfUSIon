function standardizedAnalysis(studioFig)
% standardizedAnalysis.m - deConfUSIon standardized workflow manager
% V4: custom dark workflow list, green selected row, no white uitable area.

if nargin < 1 || isempty(studioFig) || ~ishandle(studioFig)
    figs = findobj(0,'Type','figure','Name','fUSI Studio');
    if isempty(figs)
        studioFig = gcf;
    else
        studioFig = figs(1);
    end
end

state = struct();
state.studioFig = studioFig;
state.steps = makeDefaultSteps();
state.selectedRow = 1;
state.fig = [];
state.listPanel = [];
state.paramPanel = [];
state.detailBox = [];
state.statusText = [];

ss = get(0,'ScreenSize');
w = max(1250,round(ss(3)*0.97));
h = max(780,round(ss(4)*0.92));
x = max(1,round((ss(3)-w)/2));
y = max(1,round((ss(4)-h)/2));

state.fig = figure('Name','deConfUSIon - Standardized Analysis', ...
    'NumberTitle','off', ...
    'MenuBar','none', ...
    'ToolBar','none', ...
    'Color',[0.030 0.035 0.050], ...
    'Units','pixels', ...
    'Position',[x y w h], ...
    'Resize','on', ...
    'Tag','deconfusion_standardized_analysis_v4');

movegui(state.fig,'center');

uicontrol(state.fig,'Style','text', ...
    'String','STANDARDIZED ANALYSIS', ...
    'Units','normalized', ...
    'Position',[0.015 0.935 0.50 0.045], ...
    'BackgroundColor',[0.030 0.035 0.050], ...
    'ForegroundColor',[0.35 0.95 1.00], ...
    'FontSize',26, ...
    'FontWeight','bold', ...
    'HorizontalAlignment','left');

uicontrol(state.fig,'Style','text', ...
    'String','Click a workflow row to select it. Green row = selected step. Use Move controls or edit # to reorder.', ...
    'Units','normalized', ...
    'Position',[0.015 0.900 0.72 0.030], ...
    'BackgroundColor',[0.030 0.035 0.050], ...
    'ForegroundColor',[0.78 0.86 0.92], ...
    'FontSize',14, ...
    'HorizontalAlignment','left');

state.listPanel = uipanel(state.fig, ...
    'Title','Workflow order', ...
    'Units','normalized', ...
    'Position',[0.015 0.075 0.700 0.815], ...
    'BackgroundColor',[0.045 0.052 0.070], ...
    'ForegroundColor',[0.35 0.95 1.00], ...
    'HighlightColor',[0.15 0.28 0.35], ...
    'ShadowColor',[0.02 0.02 0.03], ...
    'FontSize',16, ...
    'FontWeight','bold');

state.paramPanel = uipanel(state.fig, ...
    'Title','Selected step', ...
    'Units','normalized', ...
    'Position',[0.735 0.405 0.250 0.485], ...
    'BackgroundColor',[0.055 0.065 0.085], ...
    'ForegroundColor',[0.35 0.95 1.00], ...
    'HighlightColor',[0.18 0.30 0.36], ...
    'ShadowColor',[0.02 0.02 0.03], ...
    'FontSize',16, ...
    'FontWeight','bold');

state.detailBox = uicontrol(state.fig,'Style','edit', ...
    'Units','normalized', ...
    'Position',[0.735 0.210 0.250 0.175], ...
    'Max',10, ...
    'Min',0, ...
    'Enable','inactive', ...
    'HorizontalAlignment','left', ...
    'BackgroundColor',[0.075 0.085 0.110], ...
    'ForegroundColor',[0.92 0.96 1.00], ...
    'FontSize',13);

state.statusText = uicontrol(state.fig,'Style','text', ...
    'String','Ready.', ...
    'Units','normalized', ...
    'Position',[0.015 0.018 0.70 0.035], ...
    'BackgroundColor',[0.030 0.035 0.050], ...
    'ForegroundColor',[0.80 0.95 0.85], ...
    'FontSize',13, ...
    'HorizontalAlignment','left');

% Main action buttons
btnW = 0.118;
btnH = 0.045;
gap = 0.014;

uicontrol(state.fig,'Style','pushbutton', ...
    'String','Run Workflow', ...
    'Units','normalized', ...
    'Position',[0.735 0.145 btnW btnH], ...
    'FontSize',14, ...
    'FontWeight','bold', ...
    'BackgroundColor',[0.08 0.45 0.26], ...
    'ForegroundColor',[1 1 1], ...
    'Callback',@onRunWorkflow);

uicontrol(state.fig,'Style','pushbutton', ...
    'String','Run Step', ...
    'Units','normalized', ...
    'Position',[0.735+btnW+gap 0.145 btnW btnH], ...
    'FontSize',14, ...
    'FontWeight','bold', ...
    'BackgroundColor',[0.10 0.25 0.50], ...
    'ForegroundColor',[1 1 1], ...
    'Callback',@onRunSelectedStep);

% Reorder controls
uicontrol(state.fig,'Style','pushbutton', ...
    'String','Move Up', ...
    'Units','normalized', ...
    'Position',[0.735 0.090 btnW btnH], ...
    'FontSize',13, ...
    'BackgroundColor',[0.18 0.20 0.25], ...
    'ForegroundColor',[1 1 1], ...
    'Callback',@(s,e) moveSelected(-1));

uicontrol(state.fig,'Style','pushbutton', ...
    'String','Move Down', ...
    'Units','normalized', ...
    'Position',[0.735+btnW+gap 0.090 btnW btnH], ...
    'FontSize',13, ...
    'BackgroundColor',[0.18 0.20 0.25], ...
    'ForegroundColor',[1 1 1], ...
    'Callback',@(s,e) moveSelected(1));

uicontrol(state.fig,'Style','pushbutton', ...
    'String','Top', ...
    'Units','normalized', ...
    'Position',[0.735 0.035 btnW btnH], ...
    'FontSize',13, ...
    'BackgroundColor',[0.18 0.20 0.25], ...
    'ForegroundColor',[1 1 1], ...
    'Callback',@(s,e) moveSelectedTo('top'));

uicontrol(state.fig,'Style','pushbutton', ...
    'String','Bottom', ...
    'Units','normalized', ...
    'Position',[0.735+btnW+gap 0.035 btnW btnH], ...
    'FontSize',13, ...
    'BackgroundColor',[0.18 0.20 0.25], ...
    'ForegroundColor',[1 1 1], ...
    'Callback',@(s,e) moveSelectedTo('bottom'));

% Preset/close buttons in upper right
uicontrol(state.fig,'Style','pushbutton', ...
    'String','Recommended', ...
    'Units','normalized', ...
    'Position',[0.735 0.900 btnW 0.040], ...
    'FontSize',13, ...
    'BackgroundColor',[0.18 0.20 0.25], ...
    'ForegroundColor',[1 1 1], ...
    'Callback',@onRecommended);

uicontrol(state.fig,'Style','pushbutton', ...
    'String','Save / Load', ...
    'Units','normalized', ...
    'Position',[0.735+btnW+gap 0.900 btnW 0.040], ...
    'FontSize',13, ...
    'BackgroundColor',[0.18 0.20 0.25], ...
    'ForegroundColor',[1 1 1], ...
    'Callback',@onSaveLoad);

guidata(state.fig,state);
refreshWorkflowList();
refreshSelectedPanel();

% =====================================================================
% Nested callbacks
% =====================================================================

function refreshWorkflowList()
    state = guidata(gcbf);
    if isempty(state) || ~isfield(state,'listPanel') || ~ishandle(state.listPanel), return; end
    old = get(state.listPanel,'Children');
    if ~isempty(old), delete(old); end

    n = numel(state.steps);
    topPad = 0.018;
    botPad = 0.018;
    gapY = 0.006;
    rowH = (1 - topPad - botPad - (n-1)*gapY) / n;

    for i = 1:n
        s = state.steps(i);
        y = 1 - topPad - i*rowH - (i-1)*gapY;
        selected = (i == state.selectedRow);

        if selected
            bg = [0.05 0.30 0.16];
            fg = [1.00 1.00 1.00];
            arrow = char(9658);
            fw = 'bold';
        elseif mod(i,2)==0
            bg = [0.075 0.085 0.110];
            fg = [0.90 0.94 0.98];
            arrow = '';
            fw = 'normal';
        else
            bg = [0.060 0.070 0.095];
            fg = [0.90 0.94 0.98];
            arrow = '';
            fw = 'normal';
        end

        rp = uipanel(state.listPanel, ...
            'Units','normalized', ...
            'Position',[0.010 y 0.980 rowH], ...
            'BackgroundColor',bg, ...
            'BorderType','line', ...
            'HighlightColor',[0.12 0.35 0.22], ...
            'ShadowColor',[0.02 0.02 0.03]);

        uicontrol(rp,'Style','pushbutton', ...
            'String',arrow, ...
            'Units','normalized', ...
            'Position',[0.005 0.13 0.040 0.74], ...
            'BackgroundColor',bg, ...
            'ForegroundColor',[0.55 1.00 0.62], ...
            'FontSize',17, ...
            'FontWeight','bold', ...
            'Callback',@(src,evt) onSelectRow(i));

        uicontrol(rp,'Style','checkbox', ...
            'Value',s.run, ...
            'Units','normalized', ...
            'Position',[0.052 0.18 0.045 0.64], ...
            'BackgroundColor',bg, ...
            'ForegroundColor',fg, ...
            'FontSize',13, ...
            'Callback',@(src,evt) onToggleRun(i,src));

        uicontrol(rp,'Style','edit', ...
            'String',num2str(i), ...
            'Units','normalized', ...
            'Position',[0.104 0.18 0.050 0.64], ...
            'BackgroundColor',[0.12 0.13 0.17], ...
            'ForegroundColor',[1 1 1], ...
            'FontSize',13, ...
            'FontWeight','bold', ...
            'Callback',@(src,evt) onOrderEdit(i,src));

        uicontrol(rp,'Style','pushbutton', ...
            'String',s.name, ...
            'Units','normalized', ...
            'Position',[0.165 0.13 0.245 0.74], ...
            'BackgroundColor',bg, ...
            'ForegroundColor',fg, ...
            'FontSize',14, ...
            'FontWeight',fw, ...
            'Callback',@(src,evt) onSelectRow(i));

        uicontrol(rp,'Style','pushbutton', ...
            'String',s.desc, ...
            'Units','normalized', ...
            'Position',[0.420 0.13 0.570 0.74], ...
            'BackgroundColor',bg, ...
            'ForegroundColor',fg, ...
            'FontSize',12, ...
            'FontWeight',fw, ...
            'Callback',@(src,evt) onSelectRow(i));
    end
    drawnow;
end

function onSelectRow(r)
    state = guidata(gcbf);
    if r < 1 || r > numel(state.steps), return; end
    state.selectedRow = r;
    guidata(state.fig,state);
    refreshWorkflowList();
    refreshSelectedPanel();
end

function onToggleRun(r,src)
    state = guidata(gcbf);
    if r < 1 || r > numel(state.steps), return; end
    state.steps(r).run = logical(get(src,'Value'));
    state.selectedRow = r;
    guidata(state.fig,state);
    refreshWorkflowList();
    refreshSelectedPanel();
end

function onOrderEdit(r,src)
    state = guidata(gcbf);
    if r < 1 || r > numel(state.steps), return; end
    v = str2double(get(src,'String'));
    if ~isfinite(v)
        setStatus('Invalid order number.',[1.00 0.55 0.45]);
        refreshWorkflowList();
        return;
    end
    selectedName = state.steps(r).name;
    v = round(max(1,min(numel(state.steps),v)));
    item = state.steps(r);
    state.steps(r) = [];
    state.steps = insertStepAt(state.steps,item,v);
    state = renumberSteps(state);
    state.selectedRow = findStepByName(state,selectedName);
    if isempty(state.selectedRow), state.selectedRow = min(v,numel(state.steps)); end
    guidata(state.fig,state);
    refreshWorkflowList();
    refreshSelectedPanel();
end

function moveSelected(delta)
    state = guidata(gcbf);
    r = state.selectedRow;
    if isempty(r) || r < 1 || r > numel(state.steps), return; end
    newR = r + delta;
    if newR < 1 || newR > numel(state.steps), return; end
    tmp = state.steps(r);
    state.steps(r) = state.steps(newR);
    state.steps(newR) = tmp;
    state.selectedRow = newR;
    state = renumberSteps(state);
    guidata(state.fig,state);
    refreshWorkflowList();
    refreshSelectedPanel();
end

function moveSelectedTo(whereTo)
    state = guidata(gcbf);
    r = state.selectedRow;
    if isempty(r) || r < 1 || r > numel(state.steps), return; end
    item = state.steps(r);
    state.steps(r) = [];
    if strcmpi(whereTo,'top')
        state.steps = [item state.steps];
        state.selectedRow = 1;
    else
        state.steps = [state.steps item];
        state.selectedRow = numel(state.steps);
    end
    state = renumberSteps(state);
    guidata(state.fig,state);
    refreshWorkflowList();
    refreshSelectedPanel();
end

function refreshSelectedPanel()
    state = guidata(gcbf);
    if isempty(state) || ~isfield(state,'paramPanel') || ~ishandle(state.paramPanel), return; end
    old = get(state.paramPanel,'Children');
    if ~isempty(old), delete(old); end

    r = state.selectedRow;
    if isempty(r) || r < 1 || r > numel(state.steps), r = 1; end
    s = state.steps(r);

    uicontrol(state.paramPanel,'Style','text', ...
        'String',['#' num2str(r) '  ' s.name], ...
        'Units','normalized', ...
        'Position',[0.04 0.88 0.92 0.085], ...
        'BackgroundColor',[0.055 0.065 0.085], ...
        'ForegroundColor',[0.55 1.00 0.62], ...
        'FontSize',17, ...
        'FontWeight','bold', ...
        'HorizontalAlignment','left');

    uicontrol(state.paramPanel,'Style','checkbox', ...
        'String','Run this step', ...
        'Value',s.run, ...
        'Units','normalized', ...
        'Position',[0.04 0.80 0.90 0.07], ...
        'BackgroundColor',[0.055 0.065 0.085], ...
        'ForegroundColor',[0.92 0.96 1.00], ...
        'FontSize',14, ...
        'Callback',@onSelectedRunToggle);

    fields = relevantFields(s);
    labels = fieldLabels();
    y = 0.70;
    dy = 0.088;
    if isempty(fields)
        uicontrol(state.paramPanel,'Style','text', ...
            'String','No editable numeric preset for this step yet.', ...
            'Units','normalized', ...
            'Position',[0.04 y 0.92 0.08], ...
            'BackgroundColor',[0.055 0.065 0.085], ...
            'ForegroundColor',[0.78 0.86 0.92], ...
            'FontSize',13, ...
            'HorizontalAlignment','left');
    else
        for k = 1:numel(fields)
            f = fields{k};
            if y < 0.05, break; end
            uicontrol(state.paramPanel,'Style','text', ...
                'String',labels.(f), ...
                'Units','normalized', ...
                'Position',[0.04 y 0.55 0.062], ...
                'BackgroundColor',[0.055 0.065 0.085], ...
                'ForegroundColor',[0.92 0.96 1.00], ...
                'FontSize',13, ...
                'HorizontalAlignment','left');
            uicontrol(state.paramPanel,'Style','edit', ...
                'String',num2str(s.(f)), ...
                'Units','normalized', ...
                'Position',[0.61 y 0.33 0.067], ...
                'BackgroundColor',[0.12 0.13 0.17], ...
                'ForegroundColor',[1 1 1], ...
                'FontSize',13, ...
                'Callback',@(src,evt) onParamEdit(src,evt,f));
            y = y - dy;
        end
    end

    set(state.detailBox,'String',makeDetailText(s));
end

function onSelectedRunToggle(src,~)
    state = guidata(gcbf);
    r = state.selectedRow;
    if r >= 1 && r <= numel(state.steps)
        state.steps(r).run = logical(get(src,'Value'));
        guidata(state.fig,state);
        refreshWorkflowList();
        refreshSelectedPanel();
    end
end

function onParamEdit(src,~,fieldName)
    state = guidata(gcbf);
    r = state.selectedRow;
    if r < 1 || r > numel(state.steps), return; end
    v = str2double(get(src,'String'));
    if ~isfinite(v)
        setStatus('Invalid number. Reverted.',[1.00 0.55 0.45]);
        set(src,'String',num2str(state.steps(r).(fieldName)));
        return;
    end
    state.steps(r).(fieldName) = sanitizeValue(fieldName,v);
    guidata(state.fig,state);
    refreshSelectedPanel();
end

function onRunWorkflow(~,~)
    state = guidata(gcbf);
    idx = find([state.steps.run]);
    if isempty(idx)
        setStatus('No workflow steps are ticked.',[1.00 0.55 0.45]);
        return;
    end
    msg = sprintf('Run %d ticked workflow steps in the displayed order?',numel(idx));
    answer = questdlg(msg,'Run standardized workflow','Run','Cancel','Run');
    if ~strcmp(answer,'Run')
        setStatus('Cancelled.',[0.90 0.90 0.90]);
        return;
    end
    for ii = 1:numel(idx)
        state = guidata(state.fig);
        r = idx(ii);
        if r > numel(state.steps), continue; end
        stepName = state.steps(r).name;
        setStatus(['Running step ' num2str(ii) '/' num2str(numel(idx)) ': ' stepName],[0.80 0.95 0.85]);
        drawnow;
        ok = triggerStudioStep(state.studioFig,stepName,state.steps(r));
        if ~ok
            setStatus(['Stopped: could not launch ' stepName],[1.00 0.55 0.45]);
            return;
        end
        drawnow;
    end
    setStatus('Workflow launch finished.',[0.80 0.95 0.85]);
end

function onRunSelectedStep(~,~)
    state = guidata(gcbf);
    r = state.selectedRow;
    if r < 1 || r > numel(state.steps), return; end
    stepName = state.steps(r).name;
    setStatus(['Launching selected step: ' stepName],[0.80 0.95 0.85]);
    ok = triggerStudioStep(state.studioFig,stepName,state.steps(r));
    if ok
        setStatus(['Launched: ' stepName],[0.80 0.95 0.85]);
    else
        setStatus(['Could not launch: ' stepName],[1.00 0.55 0.45]);
    end
end

function onRecommended(~,~)
    state = guidata(gcbf);
    answer = questdlg('Restore recommended workflow?','Recommended workflow','Restore','Cancel','Restore');
    if ~strcmp(answer,'Restore'), return; end
    state.steps = makeDefaultSteps();
    state.selectedRow = 1;
    guidata(state.fig,state);
    refreshWorkflowList();
    refreshSelectedPanel();
    setStatus('Recommended workflow restored.',[0.80 0.95 0.85]);
end

function onSaveLoad(~,~)
    choice = questdlg('Preset action:','Save / Load workflow preset','Save','Load','Cancel','Save');
    if strcmp(choice,'Save')
        savePreset();
    elseif strcmp(choice,'Load')
        loadPreset();
    end
end

function savePreset()
    state = guidata(gcbf);
    presetFile = fullfile(fileparts(which('standardizedAnalysis')),'standardizedAnalysis_preset.mat');
    steps = state.steps; %#ok<NASGU>
    try
        save(presetFile,'steps');
        setStatus(['Preset saved: ' presetFile],[0.80 0.95 0.85]);
    catch ME
        setStatus(['Could not save preset: ' ME.message],[1.00 0.55 0.45]);
    end
end

function loadPreset()
    state = guidata(gcbf);
    presetFile = fullfile(fileparts(which('standardizedAnalysis')),'standardizedAnalysis_preset.mat');
    if ~exist(presetFile,'file')
        setStatus('No saved preset found yet.',[1.00 0.55 0.45]);
        return;
    end
    try
        S = load(presetFile,'steps');
        if isfield(S,'steps')
            state.steps = normalizeLoadedSteps(S.steps);
            state = renumberSteps(state);
            state.selectedRow = 1;
            guidata(state.fig,state);
            refreshWorkflowList();
            refreshSelectedPanel();
            setStatus(['Preset loaded: ' presetFile],[0.80 0.95 0.85]);
        end
    catch ME
        setStatus(['Could not load preset: ' ME.message],[1.00 0.55 0.45]);
    end
end

function setStatus(msg,colorVal)
    state = guidata(gcbf);
    if isempty(state) || ~isfield(state,'statusText') || ~ishandle(state.statusText)
        disp(msg);
        return;
    end
    set(state.statusText,'String',msg,'ForegroundColor',colorVal);
    drawnow;
end

end % main function

% =====================================================================
% Helper functions
% =====================================================================

function steps = makeDefaultSteps()
steps = repmat(emptyStep(),1,17);
steps(1)  = makeStep(true,  1,'Motor',                 '4 slices, split MAT folder, residual despike 4, correction none',4,NaN,NaN,NaN,NaN,NaN,NaN,NaN);
steps(2)  = makeStep(false, 2,'Frame Rejection',       'optional frame rejection before correction',NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN);
steps(3)  = makeStep(false, 3,'Scrubbing',             'optional scrubbing after correction',NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN);
steps(4)  = makeStep(false, 4,'Filtering',             'optional temporal filtering',NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN);
steps(5)  = makeStep(false, 5,'Temporal Smoothing',    'optional smoothing/subsampling',NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN);
steps(6)  = makeStep(false, 6,'PCA / ICA',             'optional PCA/ICA denoising/review',NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN);
steps(7)  = makeStep(false, 7,'Despike',               'optional additional despiking',NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN);
steps(8)  = makeStep(true,  8,'Imregdemons',           'median mode, nsub 25',NaN,25,NaN,NaN,NaN,NaN,NaN,NaN);
steps(9)  = makeStep(true,  9,'Full QC',               'full advanced QC on newest dataset',NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN);
steps(10) = makeStep(true, 10,'Mask Editor',           'save underlay/mask, then close',NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN);
steps(11) = makeStep(true, 11,'Video GUI',             'baseline 30-35 s, signed PSC, alpha 20-100',NaN,NaN,30,35,-100,100,20,100);
steps(12) = makeStep(false,12,'Time-Course Viewer',    'optional inspect ROI/time-course',NaN,NaN,30,35,-100,100,NaN,NaN);
steps(13) = makeStep(true, 13,'SCM GUI',               'baseline 30-35 s, signed PSC, alpha 20-100',NaN,NaN,30,35,-100,100,20,100);
steps(14) = makeStep(true, 14,'Registration to Atlas', 'atlas/coregistration workflow',NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN);
steps(15) = makeStep(true, 15,'Segmentation',          'open segmentation popup',NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN);
steps(16) = makeStep(false,16,'Functional Connectivity','optional FC after segmentation',NaN,NaN,NaN,NaN,-1,1,NaN,NaN);
steps(17) = makeStep(false,17,'Group Analysis',        'optional group-level analysis',NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN);
end

function s = emptyStep()
s = struct('run',false,'order',0,'name','','desc','', ...
    'slices',NaN,'nsub',NaN,'base1',NaN,'base2',NaN, ...
    'cmin',NaN,'cmax',NaN,'amin',NaN,'amax',NaN);
end

function s = makeStep(runFlag,orderVal,name,desc,slices,nsub,base1,base2,cmin,cmax,amin,amax)
s = emptyStep();
s.run = runFlag;
s.order = orderVal;
s.name = name;
s.desc = desc;
s.slices = slices;
s.nsub = nsub;
s.base1 = base1;
s.base2 = base2;
s.cmin = cmin;
s.cmax = cmax;
s.amin = amin;
s.amax = amax;
end

function state = renumberSteps(state)
for i = 1:numel(state.steps)
    state.steps(i).order = i;
end
end

function steps = insertStepAt(steps,item,pos)
if isempty(steps)
    steps = item;
    return;
end
pos = max(1,min(numel(steps)+1,pos));
if pos == 1
    steps = [item steps];
elseif pos > numel(steps)
    steps = [steps item];
else
    steps = [steps(1:pos-1) item steps(pos:end)];
end
end

function idx = findStepByName(state,name)
idx = [];
for i = 1:numel(state.steps)
    if strcmp(state.steps(i).name,name)
        idx = i;
        return;
    end
end
end

function fields = relevantFields(s)
fields = {};
switch lower(strtrim(s.name))
    case 'motor'
        fields = {'slices'};
    case 'imregdemons'
        fields = {'nsub'};
    case {'video gui','scm gui'}
        fields = {'base1','base2','cmin','cmax','amin','amax'};
    case 'time-course viewer'
        fields = {'base1','base2','cmin','cmax'};
    case 'functional connectivity'
        fields = {'cmin','cmax'};
end
end

function labels = fieldLabels()
labels = struct();
labels.slices = 'Slices';
labels.nsub   = 'Imreg n / nsub';
labels.base1  = 'Baseline start (s)';
labels.base2  = 'Baseline end (s)';
labels.cmin   = 'Display min (%)';
labels.cmax   = 'Display max (%)';
labels.amin   = 'Alpha min abs (%)';
labels.amax   = 'Alpha max abs (%)';
end

function v = sanitizeValue(fieldName,v)
switch fieldName
    case 'slices'
        v = round(v);
        v = max(1,min(12,v));
    case 'nsub'
        v = round(v);
        v = max(1,min(1000,v));
    otherwise
        if ~isfinite(v), v = NaN; end
end
end

function txt = makeDetailText(s)
fields = relevantFields(s);
labels = fieldLabels();
txt = {['Step: ' s.name],'', ['Recommended: ' s.desc], ''};
if isempty(fields)
    txt{end+1} = 'Editable numbers: none for this step yet.';
else
    txt{end+1} = 'Editable numbers:';
    for i = 1:numel(fields)
        f = fields{i};
        txt{end+1} = ['  ' labels.(f) ' = ' num2str(s.(f))]; %#ok<AGROW>
    end
end
txt{end+1} = '';
txt{end+1} = 'This manager controls workflow order and presets.';
txt{end+1} = 'Existing module dialogs still define final processing settings in V4.';
end

function steps = normalizeLoadedSteps(steps)
defaultSteps = makeDefaultSteps();
if ~isstruct(steps)
    steps = defaultSteps;
    return;
end
needFields = fieldnames(emptyStep());
for i = 1:numel(steps)
    for f = 1:numel(needFields)
        if ~isfield(steps,needFields{f})
            steps(i).(needFields{f}) = defaultSteps(min(i,numel(defaultSteps))).(needFields{f});
        end
    end
end
end

function ok = triggerStudioStep(studioFig,stepName,stepStruct)
ok = false;
if nargin < 3, stepStruct = []; end %#ok<NASGU>
if isempty(studioFig) || ~ishandle(studioFig)
    warndlg('Studio window was not found.','Standardized Analysis');
    return;
end

candidates = stepCandidates(stepName);
allBtns = findall(studioFig,'Type','uicontrol');

for c = 1:numel(candidates)
    target = cleanLabel(candidates{c});
    for i = 1:numel(allBtns)
        try
            style = get(allBtns(i),'Style');
            label = get(allBtns(i),'String');
        catch
            continue;
        end
        if ~ischar(label) || isempty(label), continue; end
        if ~(strcmpi(style,'pushbutton') || strcmpi(style,'togglebutton')), continue; end
        if strcmp(cleanLabel(label),target)
            cb = get(allBtns(i),'Callback');
            if isempty(cb), return; end
            try
                if isa(cb,'function_handle')
                    feval(cb,allBtns(i),[]);
                elseif iscell(cb) && ~isempty(cb) && isa(cb{1},'function_handle')
                    feval(cb{1},allBtns(i),[],cb{2:end});
                elseif ischar(cb)
                    eval(cb);
                else
                    return;
                end
                ok = true;
                return;
            catch ME
                warndlg(['Could not launch ' stepName ': ' ME.message],'Standardized Analysis');
                ok = false;
                return;
            end
        end
    end
end

warndlg(['Could not find a Studio button for: ' stepName],'Standardized Analysis');
end

function candidates = stepCandidates(stepName)
switch lower(strtrim(stepName))
    case 'motor'
        candidates = {'Motor','Step Motor','Step-Motor','Motor Correction'};
    case 'frame rejection'
        candidates = {'Frame Rejection','Frame rejection','Frame Reject'};
    case 'scrubbing'
        candidates = {'Scrubbing','Scrub'};
    case 'filtering'
        candidates = {'Filtering','Filter','Temporal Filtering'};
    case 'temporal smoothing'
        candidates = {'Temporal Smoothing','Smoothing/Subsampling','Temporal Smoothing/Subsampling','Subsampling'};
    case 'pca / ica'
        candidates = {'PCA / ICA','PCA/ICA','PCA ICA','ICA','PCA'};
    case 'despike'
        candidates = {'Despike','Despiking'};
    case 'imregdemons'
        candidates = {'Imregdemons','Imreg Demons','Imregdemons Preprocess','Registration Demons'};
    case 'full qc'
        candidates = {'Full QC','QC','Advanced QC','Quality Control'};
    case 'mask editor'
        candidates = {'Mask Editor','Video & SCM Mask','Mask'};
    case 'video gui'
        candidates = {'Video GUI','Video','Open Video GUI'};
    case 'time-course viewer'
        candidates = {'Time-Course Viewer','Time Course Viewer','Timecourse Viewer','Time Course'};
    case 'scm gui'
        candidates = {'SCM GUI','SCM','Signal Change Map','Signal Change Maps'};
    case 'registration to atlas'
        candidates = {'Registration to Atlas','Register to Atlas','Atlas Registration','Coregistration','Coreg'};
    case 'segmentation'
        candidates = {'Segmentation','Segment','Atlas Segmentation'};
    case 'functional connectivity'
        candidates = {'Functional Connectivity','FC','Connectivity'};
    case 'group analysis'
        candidates = {'Group Analysis','GroupAnalysis','Open Group Analysis'};
    otherwise
        candidates = {stepName};
end
end

function s = cleanLabel(s)
if iscell(s), s = s{1}; end
if ~ischar(s), s = ''; return; end
s = lower(strtrim(s));
s = strrep(s,char(10),' ');
s = strrep(s,char(13),' ');
s = strrep(s,'&','and');
s = regexprep(s,'\s+',' ');
end
