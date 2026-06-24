function standardizedAnalysis(studioFig)
% standardizedAnalysis.m - deConfUSIon standardized workflow manager
% V3: large dark UI, simple controls, numeric-only editable settings, order-column sorting.
%
% This function is intentionally external and conservative.
% It launches existing Studio buttons/callbacks without changing module internals.

if nargin < 1 || isempty(studioFig) || ~ishandle(studioFig)
    studioFig = findobj(0,'Type','figure','Name','fUSI Studio');
    if isempty(studioFig)
        studioFig = gcf;
    else
        studioFig = studioFig(1);
    end
end

state = struct();
state.studioFig = studioFig;
state.steps = makeDefaultSteps();
state.selectedRow = 1;
state.cutStep = [];
state.paramEditHandles = [];
state.statusText = [];
state.table = [];
state.detailBox = [];
state.paramPanel = [];
state.fig = [];

ss = get(0,'ScreenSize');
w = max(1200, round(ss(3)*0.96));
h = max(760,  round(ss(4)*0.90));
x = max(1, round((ss(3)-w)/2));
y = max(1, round((ss(4)-h)/2));

state.fig = figure('Name','deConfUSIon - Standardized Analysis', ...
    'NumberTitle','off', ...
    'MenuBar','none', ...
    'ToolBar','none', ...
    'Color',[0.035 0.040 0.055], ...
    'Units','pixels', ...
    'Position',[x y w h], ...
    'Resize','on', ...
    'Tag','deconfusion_standardized_analysis_v3');

movegui(state.fig,'center');

uicontrol(state.fig,'Style','text', ...
    'String','STANDARDIZED ANALYSIS', ...
    'Units','normalized', ...
    'Position',[0.015 0.935 0.55 0.045], ...
    'BackgroundColor',[0.035 0.040 0.055], ...
    'ForegroundColor',[0.45 0.90 1.00], ...
    'FontSize',24, ...
    'FontWeight','bold', ...
    'HorizontalAlignment','left');

uicontrol(state.fig,'Style','text', ...
    'String','Tick steps, edit # to reorder, click a row to edit its numbers on the right.', ...
    'Units','normalized', ...
    'Position',[0.015 0.900 0.75 0.032], ...
    'BackgroundColor',[0.035 0.040 0.055], ...
    'ForegroundColor',[0.78 0.86 0.92], ...
    'FontSize',14, ...
    'HorizontalAlignment','left');

state.statusText = uicontrol(state.fig,'Style','text', ...
    'String','Ready.', ...
    'Units','normalized', ...
    'Position',[0.015 0.015 0.72 0.035], ...
    'BackgroundColor',[0.035 0.040 0.055], ...
    'ForegroundColor',[0.80 0.95 0.85], ...
    'FontSize',13, ...
    'HorizontalAlignment','left');

colNames = {'Run','#','Step','Recommended action','Slices','N','Base 1','Base 2','% min','% max','Alpha min','Alpha max'};
colEditable = [true true false false true true true true true true true true];
colWidth = {55 50 185 470 70 70 80 80 80 80 90 90};

state.table = uitable(state.fig, ...
    'Units','normalized', ...
    'Position',[0.015 0.075 0.720 0.815], ...
    'Data',stepsToTable(state.steps), ...
    'ColumnName',colNames, ...
    'ColumnEditable',colEditable, ...
    'ColumnWidth',colWidth, ...
    'RowName',[], ...
    'FontSize',15, ...
    'CellSelectionCallback',@onSelectCell, ...
    'CellEditCallback',@onEditCell, ...
    'Tag','standardizedWorkflowTable');

try
    set(state.table,'BackgroundColor',[0.10 0.11 0.14; 0.13 0.14 0.18]);
catch
end
try
    set(state.table,'ForegroundColor',[0.92 0.96 1.00]);
catch
end

state.paramPanel = uipanel(state.fig, ...
    'Title','Selected step - editable numbers', ...
    'Units','normalized', ...
    'Position',[0.750 0.405 0.235 0.485], ...
    'BackgroundColor',[0.055 0.065 0.085], ...
    'ForegroundColor',[0.45 0.90 1.00], ...
    'HighlightColor',[0.18 0.30 0.36], ...
    'ShadowColor',[0.02 0.02 0.03], ...
    'FontSize',15, ...
    'FontWeight','bold');

state.detailBox = uicontrol(state.fig,'Style','edit', ...
    'Units','normalized', ...
    'Position',[0.750 0.205 0.235 0.180], ...
    'Max',10, ...
    'Min',0, ...
    'Enable','inactive', ...
    'HorizontalAlignment','left', ...
    'BackgroundColor',[0.08 0.09 0.12], ...
    'ForegroundColor',[0.92 0.96 1.00], ...
    'FontSize',13);

btnY = 0.145;
btnH = 0.045;
btnW = 0.112;
gap = 0.011;

uicontrol(state.fig,'Style','pushbutton', ...
    'String','Run Workflow', ...
    'Units','normalized', ...
    'Position',[0.750 btnY btnW btnH], ...
    'FontSize',14, ...
    'FontWeight','bold', ...
    'BackgroundColor',[0.10 0.45 0.30], ...
    'ForegroundColor',[1 1 1], ...
    'Callback',@onRunWorkflow);

uicontrol(state.fig,'Style','pushbutton', ...
    'String','Run Step', ...
    'Units','normalized', ...
    'Position',[0.750+btnW+gap btnY btnW btnH], ...
    'FontSize',14, ...
    'FontWeight','bold', ...
    'BackgroundColor',[0.10 0.25 0.48], ...
    'ForegroundColor',[1 1 1], ...
    'Callback',@onRunSelectedStep);

btnY2 = 0.090;
uicontrol(state.fig,'Style','pushbutton', ...
    'String','Recommended', ...
    'Units','normalized', ...
    'Position',[0.750 btnY2 btnW btnH], ...
    'FontSize',13, ...
    'BackgroundColor',[0.20 0.20 0.25], ...
    'ForegroundColor',[1 1 1], ...
    'Callback',@onRecommended);

uicontrol(state.fig,'Style','pushbutton', ...
    'String','Save / Load', ...
    'Units','normalized', ...
    'Position',[0.750+btnW+gap btnY2 btnW btnH], ...
    'FontSize',13, ...
    'BackgroundColor',[0.20 0.20 0.25], ...
    'ForegroundColor',[1 1 1], ...
    'Callback',@onSaveLoad);

uicontrol(state.fig,'Style','pushbutton', ...
    'String','Close', ...
    'Units','normalized', ...
    'Position',[0.750 0.035 2*btnW+gap btnH], ...
    'FontSize',13, ...
    'BackgroundColor',[0.28 0.12 0.12], ...
    'ForegroundColor',[1 1 1], ...
    'Callback',@(s,e) close(state.fig));

guidata(state.fig,state);
refreshSelectedPanel();

% =====================================================================
% Nested callbacks
% =====================================================================

function onSelectCell(~,evt)
    state = guidata(gcbf);
    if isfield(evt,'Indices') && ~isempty(evt.Indices)
        r = evt.Indices(1,1);
        if r >= 1 && r <= numel(state.steps)
            state.selectedRow = r;
            guidata(state.fig,state);
            refreshSelectedPanel();
        end
    end
end

function onEditCell(~,evt)
    state = guidata(gcbf);
    if isempty(evt.Indices), return; end
    r = evt.Indices(1);
    c = evt.Indices(2);
    if r < 1 || r > numel(state.steps), return; end

    val = evt.NewData;
    if ischar(val)
        valNum = str2double(strtrim(val));
    elseif isnumeric(val)
        valNum = val;
    elseif islogical(val)
        valNum = double(val);
    else
        valNum = NaN;
    end

    switch c
        case 1
            state.steps(r).run = logical(val);
        case 2
            if isfinite(valNum)
                state.steps(r).order = valNum;
                state = sortAndRenumber(state);
                r = findSelectedByName(state,state.steps(min(r,numel(state.steps))).name); %#ok<FNDSB>
                if isempty(r), r = 1; end
                state.selectedRow = r;
            end
        otherwise
            field = columnToField(c);
            if isempty(field)
                % text columns are intentionally locked
            elseif isRelevant(state.steps(r),field) && isfinite(valNum)
                state.steps(r).(field) = sanitizeValue(field,valNum);
            else
                % Non-relevant numeric cell: revert silently.
            end
    end

    set(state.table,'Data',stepsToTable(state.steps));
    guidata(state.fig,state);
    refreshSelectedPanel();
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
    set(state.table,'Data',stepsToTable(state.steps));
    refreshSelectedPanel();
end

function onRunWorkflow(~,~)
    state = guidata(gcbf);
    selected = find([state.steps.run]);
    if isempty(selected)
        setStatus('No workflow steps are ticked.',[1.00 0.55 0.45]);
        return;
    end

    selected = selected(:)';
    msg = sprintf('Run %d ticked workflow steps in the displayed order?',numel(selected));
    answer = questdlg(msg,'Run standardized workflow','Run','Cancel','Run');
    if ~strcmp(answer,'Run')
        setStatus('Cancelled.',[0.90 0.90 0.90]);
        return;
    end

    for ii = 1:numel(selected)
        state = guidata(state.fig);
        r = selected(ii);
        if r > numel(state.steps), continue; end
        stepName = state.steps(r).name;
        setStatus(['Running step ' num2str(ii) '/' num2str(numel(selected)) ': ' stepName],[0.80 0.95 0.85]);
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
    answer = questdlg('Restore recommended standardized workflow?','Recommended workflow','Restore','Cancel','Restore');
    if ~strcmp(answer,'Restore'), return; end
    state.steps = makeDefaultSteps();
    state.selectedRow = 1;
    set(state.table,'Data',stepsToTable(state.steps));
    guidata(state.fig,state);
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
            state = sortAndRenumber(state);
            state.selectedRow = 1;
            set(state.table,'Data',stepsToTable(state.steps));
            guidata(state.fig,state);
            refreshSelectedPanel();
            setStatus(['Preset loaded: ' presetFile],[0.80 0.95 0.85]);
        end
    catch ME
        setStatus(['Could not load preset: ' ME.message],[1.00 0.55 0.45]);
    end
end

function refreshSelectedPanel()
    state = guidata(gcbf);
    if isempty(state) || ~isfield(state,'paramPanel') || ~ishandle(state.paramPanel), return; end

    old = get(state.paramPanel,'Children');
    if ~isempty(old), delete(old); end

    r = state.selectedRow;
    if r < 1 || r > numel(state.steps), r = 1; end
    s = state.steps(r);

    uicontrol(state.paramPanel,'Style','text', ...
        'String',['#' num2str(s.order) '  ' s.name], ...
        'Units','normalized', ...
        'Position',[0.04 0.88 0.92 0.085], ...
        'BackgroundColor',[0.055 0.065 0.085], ...
        'ForegroundColor',[0.45 0.90 1.00], ...
        'FontSize',16, ...
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
    dy = 0.085;
    if isempty(fields)
        uicontrol(state.paramPanel,'Style','text', ...
            'String','No numeric preset for this step yet.', ...
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
                'Position',[0.04 y 0.52 0.06], ...
                'BackgroundColor',[0.055 0.065 0.085], ...
                'ForegroundColor',[0.92 0.96 1.00], ...
                'FontSize',13, ...
                'HorizontalAlignment','left');
            uicontrol(state.paramPanel,'Style','edit', ...
                'String',num2str(s.(f)), ...
                'Units','normalized', ...
                'Position',[0.58 y 0.36 0.065], ...
                'BackgroundColor',[0.12 0.13 0.17], ...
                'ForegroundColor',[1 1 1], ...
                'FontSize',13, ...
                'Callback',@(src,evt) onParamEdit(src,evt,f));
            y = y - dy;
        end
    end

    set(state.detailBox,'String',makeDetailText(s));
    guidata(state.fig,state);
end

function onSelectedRunToggle(src,~)
    state = guidata(gcbf);
    r = state.selectedRow;
    if r >= 1 && r <= numel(state.steps)
        state.steps(r).run = logical(get(src,'Value'));
        set(state.table,'Data',stepsToTable(state.steps));
        guidata(state.fig,state);
        refreshSelectedPanel();
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
steps(2)  = makeStep(false, 2,'Frame Rejection',       'optional manual/automatic frame rejection before motion correction',NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN);
steps(3)  = makeStep(false, 3,'Scrubbing',             'optional scrubbing after motion/motor correction',NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN);
steps(4)  = makeStep(false, 4,'Filtering',             'optional temporal filtering; set inside existing module dialog',NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN);
steps(5)  = makeStep(false, 5,'Temporal Smoothing',    'optional temporal smoothing/subsampling',NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN);
steps(6)  = makeStep(false, 6,'PCA / ICA',             'optional PCA/ICA denoising or component review',NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN);
steps(7)  = makeStep(false, 7,'Despike',               'optional additional despiking; set threshold in module',NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN);
steps(8)  = makeStep(true,  8,'Imregdemons',           'median mode, nsub 25, step-motor compatible registration',NaN,25,NaN,NaN,NaN,NaN,NaN,NaN);
steps(9)  = makeStep(true,  9,'Full QC',               'full advanced QC on newest processed dataset',NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN);
steps(10) = makeStep(true, 10,'Mask Editor',           'save underlay/mask, then close editor to continue',NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN);
steps(11) = makeStep(true, 11,'Video GUI',             'baseline 30-35 s, signed PSC, display -100..100, alpha 20..100',NaN,NaN,30,35,-100,100,20,100);
steps(12) = makeStep(false,12,'Time-Course Viewer',    'optional inspect ROI/time-course before SCM',NaN,NaN,30,35,-100,100,NaN,NaN);
steps(13) = makeStep(true, 13,'SCM GUI',               'baseline 30-35 s, positive/negative signal, alpha 20..100',NaN,NaN,30,35,-100,100,20,100);
steps(14) = makeStep(true, 14,'Registration to Atlas', 'open atlas registration/coregistration workflow',NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN);
steps(15) = makeStep(true, 15,'Segmentation',          'open segmentation popup after atlas registration',NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN);
steps(16) = makeStep(false,16,'Functional Connectivity','optional FC after segmentation/atlas assignment',NaN,NaN,NaN,NaN,-1,1,NaN,NaN);
steps(17) = makeStep(false,17,'Group Analysis',        'optional group-level analysis after subject bundles exist',NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN);
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

function data = stepsToTable(steps)
n = numel(steps);
data = cell(n,12);
for i = 1:n
    s = steps(i);
    data{i,1} = logical(s.run);
    data{i,2} = s.order;
    data{i,3} = s.name;
    data{i,4} = s.desc;
    data{i,5} = showNum(s.slices);
    data{i,6} = showNum(s.nsub);
    data{i,7} = showNum(s.base1);
    data{i,8} = showNum(s.base2);
    data{i,9} = showNum(s.cmin);
    data{i,10} = showNum(s.cmax);
    data{i,11} = showNum(s.amin);
    data{i,12} = showNum(s.amax);
end
end

function out = showNum(v)
if isnumeric(v) && isscalar(v) && isfinite(v)
    out = v;
else
    out = '';
end
end

function state = sortAndRenumber(state)
[~,idx] = sort([state.steps.order]);
state.steps = state.steps(idx);
for i = 1:numel(state.steps)
    state.steps(i).order = i;
end
end

function idx = findSelectedByName(state,name)
idx = [];
for i = 1:numel(state.steps)
    if strcmp(state.steps(i).name,name)
        idx = i;
        return;
    end
end
end

function f = columnToField(c)
f = '';
switch c
    case 5, f = 'slices';
    case 6, f = 'nsub';
    case 7, f = 'base1';
    case 8, f = 'base2';
    case 9, f = 'cmin';
    case 10, f = 'cmax';
    case 11, f = 'amin';
    case 12, f = 'amax';
end
end

function tf = isRelevant(s,fieldName)
tf = false;
fields = relevantFields(s);
for i = 1:numel(fields)
    if strcmp(fields{i},fieldName)
        tf = true;
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
    txt{end+1} = 'Editable numbers: none for this step in V3.';
else
    txt{end+1} = 'Editable numbers:';
    for i = 1:numel(fields)
        f = fields{i};
        txt{end+1} = ['  ' labels.(f) ' = ' num2str(s.(f))]; %#ok<AGROW>
    end
end
txt{end+1} = '';
txt{end+1} = 'Note: V3 stores/organizes presets and launches existing Studio modules.';
txt{end+1} = 'The existing module dialogs still define the final processing parameters.';
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
