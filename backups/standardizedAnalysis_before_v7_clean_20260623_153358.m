function standardizedAnalysis(studioFig)
% standardizedAnalysis.m - deConfUSIon standardized workflow manager
% V5: fixed-row dark workflow list. No MATLAB uitable. No dynamic empty-panel bug.

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
state.hArrow = [];
state.hRun = [];
state.hOrder = [];
state.hName = [];
state.hDesc = [];
state.dragSource = 0;

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
    'Tag','deconfusion_standardized_analysis_v5');

movegui(state.fig,'center');

uicontrol(state.fig,'Style','text', ...
    'String','STANDARDIZED ANALYSIS', ...
    'Units','normalized', ...
    'Position',[0.015 0.935 0.50 0.045], ...
    'BackgroundColor',[0.030 0.035 0.050], ...
    'ForegroundColor',[0.35 0.95 1.00], ...
    'FontSize',30, ...
    'FontWeight','bold', ...
    'HorizontalAlignment','left');

uicontrol(state.fig,'Style','text', ...
    'String','Click a row to select it. Green row = selected step. Use Move Up/Down or edit # to reorder.', ...
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

% Buttons
btnW = 0.118; btnH = 0.045; gap = 0.014;

uicontrol(state.fig,'Style','pushbutton','String','Recommended', ...
    'Units','normalized','Position',[0.735 0.900 btnW 0.040], ...
    'FontSize',13,'BackgroundColor',[0.18 0.20 0.25],'ForegroundColor',[1 1 1], ...
    'Callback',@onRecommended);

uicontrol(state.fig,'Style','pushbutton','String','Save / Load', ...
    'Units','normalized','Position',[0.735+btnW+gap 0.900 btnW 0.040], ...
    'FontSize',13,'BackgroundColor',[0.18 0.20 0.25],'ForegroundColor',[1 1 1], ...
    'Callback',@onSaveLoad);

uicontrol(state.fig,'Style','pushbutton','String','Run Workflow', ...
    'Units','normalized','Position',[0.735 0.145 btnW btnH], ...
    'FontSize',14,'FontWeight','bold','BackgroundColor',[0.08 0.45 0.26],'ForegroundColor',[1 1 1], ...
    'Callback',@onRunWorkflow);

uicontrol(state.fig,'Style','pushbutton','String','Run Step', ...
    'Units','normalized','Position',[0.735+btnW+gap 0.145 btnW btnH], ...
    'FontSize',14,'FontWeight','bold','BackgroundColor',[0.10 0.25 0.50],'ForegroundColor',[1 1 1], ...
    'Callback',@onRunSelectedStep);

uicontrol(state.fig,'Style','pushbutton','String','Move Up', ...
    'Units','normalized','Position',[0.735 0.090 btnW btnH], ...
    'FontSize',13,'BackgroundColor',[0.18 0.20 0.25],'ForegroundColor',[1 1 1], ...
    'Callback',@(src,evt) moveSelected(-1));

uicontrol(state.fig,'Style','pushbutton','String','Move Down', ...
    'Units','normalized','Position',[0.735+btnW+gap 0.090 btnW btnH], ...
    'FontSize',13,'BackgroundColor',[0.18 0.20 0.25],'ForegroundColor',[1 1 1], ...
    'Callback',@(src,evt) moveSelected(1));

uicontrol(state.fig,'Style','pushbutton','String','Top', ...
    'Units','normalized','Position',[0.735 0.035 btnW btnH], ...
    'FontSize',13,'BackgroundColor',[0.18 0.20 0.25],'ForegroundColor',[1 1 1], ...
    'Callback',@(src,evt) moveSelectedTo('top'));

uicontrol(state.fig,'Style','pushbutton','String','Bottom', ...
    'Units','normalized','Position',[0.735+btnW+gap 0.035 btnW btnH], ...
    'FontSize',13,'BackgroundColor',[0.18 0.20 0.25],'ForegroundColor',[1 1 1], ...
    'Callback',@(src,evt) moveSelectedTo('bottom'));

uicontrol(state.fig,'Style','pushbutton','String','Grab Row', ...
    'Units','normalized','Position',[0.735 0.000 2*btnW+gap 0.032], ...
    'FontSize',12,'FontWeight','bold','BackgroundColor',[0.10 0.32 0.20],'ForegroundColor',[1 1 1], ...
    'Callback',@startGrabRow);

createFixedRows();
refreshRows();
refreshSelectedPanel();

%% nested functions
function createFixedRows()
    n = numel(state.steps);
    state.hArrow = gobjects(n,1);
    state.hRun   = gobjects(n,1);
    state.hOrder = gobjects(n,1);
    state.hName  = gobjects(n,1);
    state.hDesc  = gobjects(n,1);

    headerY = 0.940;
    uicontrol(state.listPanel,'Style','text','String','Sel', ...
        'Units','normalized','Position',[0.010 headerY 0.045 0.040], ...
        'BackgroundColor',[0.045 0.052 0.070],'ForegroundColor',[0.35 0.95 1.00], ...
        'FontSize',12,'FontWeight','bold');
    uicontrol(state.listPanel,'Style','text','String','Run', ...
        'Units','normalized','Position',[0.060 headerY 0.050 0.040], ...
        'BackgroundColor',[0.045 0.052 0.070],'ForegroundColor',[0.35 0.95 1.00], ...
        'FontSize',12,'FontWeight','bold');
    uicontrol(state.listPanel,'Style','text','String','#', ...
        'Units','normalized','Position',[0.115 headerY 0.050 0.040], ...
        'BackgroundColor',[0.045 0.052 0.070],'ForegroundColor',[0.35 0.95 1.00], ...
        'FontSize',12,'FontWeight','bold');
    uicontrol(state.listPanel,'Style','text','String','Step', ...
        'Units','normalized','Position',[0.175 headerY 0.230 0.040], ...
        'BackgroundColor',[0.045 0.052 0.070],'ForegroundColor',[0.35 0.95 1.00], ...
        'FontSize',12,'FontWeight','bold','HorizontalAlignment','left');
    uicontrol(state.listPanel,'Style','text','String','Recommended preset', ...
        'Units','normalized','Position',[0.415 headerY 0.570 0.040], ...
        'BackgroundColor',[0.045 0.052 0.070],'ForegroundColor',[0.35 0.95 1.00], ...
        'FontSize',12,'FontWeight','bold','HorizontalAlignment','left');

    topY = 0.900;
    bottomY = 0.015;
    gapY = 0.006;
    rowH = (topY-bottomY-(n-1)*gapY)/n;

    for i = 1:n
        y = topY - i*rowH - (i-1)*gapY + rowH;
        y = topY - (i-1)*(rowH+gapY) - rowH;
        state.hArrow(i) = uicontrol(state.listPanel,'Style','pushbutton','String','', ...
            'Units','normalized','Position',[0.010 y 0.045 rowH], ...
            'FontSize',13,'FontWeight','bold','Callback',@(src,evt) selectRow(i));
        state.hRun(i) = uicontrol(state.listPanel,'Style','checkbox','Value',false, ...
            'Units','normalized','Position',[0.065 y+0.004 0.040 rowH-0.008], ...
            'FontSize',12,'Callback',@(src,evt) toggleRun(i,src));
        state.hOrder(i) = uicontrol(state.listPanel,'Style','edit','String',num2str(i), ...
            'Units','normalized','Position',[0.115 y+0.004 0.050 rowH-0.008], ...
            'FontSize',12,'FontWeight','bold','Callback',@(src,evt) editOrder(i,src));
        state.hName(i) = uicontrol(state.listPanel,'Style','pushbutton','String','', ...
            'Units','normalized','Position',[0.175 y 0.230 rowH], ...
            'FontSize',15,'FontWeight','bold','HorizontalAlignment','left', ...
            'Callback',@(src,evt) selectRow(i));
        state.hDesc(i) = uicontrol(state.listPanel,'Style','pushbutton','String','', ...
            'Units','normalized','Position',[0.415 y 0.570 rowH], ...
            'FontSize',13,'HorizontalAlignment','left', ...
            'Callback',@(src,evt) selectRow(i));
    end
end

function refreshRows()
    n = numel(state.steps);
    for i = 1:n
        s = state.steps(i);
        if i == state.selectedRow
            bg = [0.05 0.30 0.16];
            fg = [1 1 1];
            marker = '>';
            fw = 'bold';
        elseif mod(i,2)==0
            bg = [0.075 0.085 0.110];
            fg = [0.90 0.94 0.98];
            marker = '';
            fw = 'normal';
        else
            bg = [0.060 0.070 0.095];
            fg = [0.90 0.94 0.98];
            marker = '';
            fw = 'normal';
        end
        set(state.hArrow(i),'String',marker,'BackgroundColor',bg,'ForegroundColor',[0.55 1.00 0.62]);
        set(state.hRun(i),'Value',s.run,'BackgroundColor',bg,'ForegroundColor',fg);
        set(state.hOrder(i),'String',num2str(i),'BackgroundColor',[0.12 0.13 0.17],'ForegroundColor',[1 1 1]);
        set(state.hName(i),'String',s.name,'BackgroundColor',bg,'ForegroundColor',fg,'FontWeight','bold');
        set(state.hDesc(i),'String',s.desc,'BackgroundColor',bg,'ForegroundColor',fg,'FontWeight',fw);
    end
    drawnow;
end

function selectRow(r)
    if r < 1 || r > numel(state.steps), return; end
    if isfield(state,'dragSource') && state.dragSource > 0 && state.dragSource <= numel(state.steps)
        src = state.dragSource;
        if src ~= r
            item = state.steps(src);
            state.steps(src) = [];
            if src < r, r = r - 1; end
            state.steps = insertStepAt(state.steps,item,r);
            state = renumberSteps(state);
            state.selectedRow = r;
            state.dragSource = 0;
            refreshRows();
            refreshSelectedPanel();
            setStatus('Row moved. Grab Row / Drop complete.',[0.80 0.95 0.85]);
            return;
        else
            state.dragSource = 0;
        end
    end
    state.selectedRow = r;
    refreshRows();
    refreshSelectedPanel();
end

function toggleRun(r,src)
    if r < 1 || r > numel(state.steps), return; end
    state.selectedRow = r;
    state.steps(r).run = logical(get(src,'Value'));
    refreshRows();
    refreshSelectedPanel();
end

function editOrder(r,src)
    if r < 1 || r > numel(state.steps), return; end
    v = str2double(get(src,'String'));
    if ~isfinite(v)
        setStatus('Invalid order number.',[1.00 0.55 0.45]);
        refreshRows();
        return;
    end
    v = round(max(1,min(numel(state.steps),v)));
    item = state.steps(r);
    state.steps(r) = [];
    state.steps = insertStepAt(state.steps,item,v);
    state = renumberSteps(state);
    state.selectedRow = v;
    refreshRows();
    refreshSelectedPanel();
end

function moveSelected(delta)
    r = state.selectedRow;
    if isempty(r) || r < 1 || r > numel(state.steps), return; end
    newR = r + delta;
    if newR < 1 || newR > numel(state.steps), return; end
    tmp = state.steps(r);
    state.steps(r) = state.steps(newR);
    state.steps(newR) = tmp;
    state.selectedRow = newR;
    state = renumberSteps(state);
    refreshRows();
    refreshSelectedPanel();
end

function moveSelectedTo(whereTo)
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
    refreshRows();
    refreshSelectedPanel();
end

function startGrabRow(~,~)
    if state.selectedRow < 1 || state.selectedRow > numel(state.steps), return; end
    state.dragSource = state.selectedRow;
    setStatus(['Grabbed row #' num2str(state.selectedRow) '. Now click destination row.'],[0.80 0.95 0.85]);
end

function refreshSelectedPanel()
    old = get(state.paramPanel,'Children');
    if ~isempty(old), delete(old); end
    r = state.selectedRow;
    if r < 1 || r > numel(state.steps), r = 1; end
    s = state.steps(r);
    uicontrol(state.paramPanel,'Style','text','String',['#' num2str(r) '  ' s.name], ...
        'Units','normalized','Position',[0.04 0.88 0.92 0.085], ...
        'BackgroundColor',[0.055 0.065 0.085],'ForegroundColor',[0.55 1.00 0.62], ...
        'FontSize',17,'FontWeight','bold','HorizontalAlignment','left');
    uicontrol(state.paramPanel,'Style','checkbox','String','Run this step','Value',s.run, ...
        'Units','normalized','Position',[0.04 0.80 0.90 0.07], ...
        'BackgroundColor',[0.055 0.065 0.085],'ForegroundColor',[0.92 0.96 1.00], ...
        'FontSize',14,'Callback',@(src,evt) toggleRun(r,src));

    fields = relevantFields(s);
    labels = fieldLabels();
    y = 0.70; dy = 0.088;
    if isempty(fields)
        uicontrol(state.paramPanel,'Style','text','String','No editable numeric preset for this step yet.', ...
            'Units','normalized','Position',[0.04 y 0.92 0.08], ...
            'BackgroundColor',[0.055 0.065 0.085],'ForegroundColor',[0.78 0.86 0.92], ...
            'FontSize',13,'HorizontalAlignment','left');
    else
        for k = 1:numel(fields)
            f = fields{k};
            if y < 0.05, break; end
            uicontrol(state.paramPanel,'Style','text','String',labels.(f), ...
                'Units','normalized','Position',[0.04 y 0.55 0.062], ...
                'BackgroundColor',[0.055 0.065 0.085],'ForegroundColor',[0.92 0.96 1.00], ...
                'FontSize',13,'HorizontalAlignment','left');
            uicontrol(state.paramPanel,'Style','edit','String',num2str(s.(f)), ...
                'Units','normalized','Position',[0.61 y 0.33 0.067], ...
                'BackgroundColor',[0.12 0.13 0.17],'ForegroundColor',[1 1 1], ...
                'FontSize',13,'Callback',@(src,evt) editParam(src,f));
            y = y - dy;
        end
    end
    set(state.detailBox,'String',makeDetailText(s));
end

function editParam(src,fieldName)
    r = state.selectedRow;
    if r < 1 || r > numel(state.steps), return; end
    v = str2double(get(src,'String'));
    if ~isfinite(v)
        setStatus('Invalid number. Reverted.',[1.00 0.55 0.45]);
        set(src,'String',num2str(state.steps(r).(fieldName)));
        return;
    end
    state.steps(r).(fieldName) = sanitizeValue(fieldName,v);
    refreshSelectedPanel();
end

function onRunWorkflow(~,~)
    idx = find([state.steps.run]);
    if isempty(idx)
        setStatus('No workflow steps are ticked.',[1.00 0.55 0.45]);
        return;
    end
    for ii = 1:numel(idx)
        r = idx(ii);
        stepName = state.steps(r).name;
        setStatus(['Running step ' num2str(ii) '/' num2str(numel(idx)) ': ' stepName],[0.80 0.95 0.85]);
        drawnow;
        existChoice = askExistingOutputDecision(state.studioFig,stepName);
        if strcmpi(existChoice,'cancel')
            setStatus('Workflow cancelled by user.',[1.00 0.55 0.45]);
            setStudioReady(state.studioFig,true);
            return;
        elseif strcmpi(existChoice,'skip')
            setStatus(['Skipped existing step: ' stepName],[0.95 0.85 0.40]);
            continue;
        end
        setStudioReady(state.studioFig,false);
        figsBefore = findall(0,'Type','figure');
        ok = triggerStudioStep(state.studioFig,stepName,state.steps(r));
        if ~ok
            setStudioReady(state.studioFig,true);
            setStatus(['Stopped: could not launch ' stepName],[1.00 0.55 0.45]);
            return;
        end
        waitForInteractiveStep(stepName,figsBefore);
    end
        setStudioReady(state.studioFig,true);
    setStatus('Workflow launch finished.',[0.80 0.95 0.85]);
end

function onRunSelectedStep(~,~)
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
    answer = questdlg('Restore recommended workflow?','Recommended workflow','Restore','Cancel','Restore');
    if ~strcmp(answer,'Restore'), return; end
    state.steps = makeDefaultSteps();
    state.selectedRow = 1;
    refreshRows();
    refreshSelectedPanel();
    setStatus('Recommended workflow restored.',[0.80 0.95 0.85]);
end

function onSaveLoad(~,~)
    choice = questdlg('Preset action:','Save / Load workflow preset','Save','Load','Cancel','Save');
    if strcmp(choice,'Save')
        presetFile = fullfile(fileparts(which('standardizedAnalysis')),'standardizedAnalysis_preset.mat');
        steps = state.steps; %#ok<NASGU>
        try
            save(presetFile,'steps');
            setStatus(['Preset saved: ' presetFile],[0.80 0.95 0.85]);
        catch ME
            setStatus(['Could not save preset: ' ME.message],[1.00 0.55 0.45]);
        end
    elseif strcmp(choice,'Load')
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
                refreshRows();
                refreshSelectedPanel();
                setStatus(['Preset loaded: ' presetFile],[0.80 0.95 0.85]);
            end
        catch ME
            setStatus(['Could not load preset: ' ME.message],[1.00 0.55 0.45]);
        end
    end
end

function setStatus(msg,colorVal)
    if isempty(state.statusText) || ~ishandle(state.statusText)
        disp(msg);
    else
        set(state.statusText,'String',msg,'ForegroundColor',colorVal);
        drawnow;
    end
end

end

%% helper functions
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
% DECONF_STD_FILTER_DEFAULTS_V61
for kk = 1:numel(steps)
    if ~isfield(steps,'filterType') || isempty(steps(kk).filterType), steps(kk).filterType = NaN; end
    if ~isfield(steps,'fcLow') || isempty(steps(kk).fcLow), steps(kk).fcLow = NaN; end
    if ~isfield(steps,'fcHigh') || isempty(steps(kk).fcHigh), steps(kk).fcHigh = NaN; end
    if ~isfield(steps,'filterOrder') || isempty(steps(kk).filterOrder), steps(kk).filterOrder = NaN; end
end
steps(4).filterType = 1;     % 1=band-pass, 2=low-pass, 3=high-pass
steps(4).fcLow = 0.001;
steps(4).fcHigh = 0.20;
steps(4).filterOrder = 4;
end

function s = emptyStep()
s = struct('run',false,'order',0,'name','','desc','', ...
    'slices',NaN,'nsub',NaN,'base1',NaN,'base2',NaN, ...
    'cmin',NaN,'cmax',NaN,'amin',NaN,'amax',NaN, ...
    'filterType',NaN,'fcLow',NaN,'fcHigh',NaN,'filterOrder',NaN);
end

function s = makeStep(runFlag,orderVal,name,desc,slices,nsub,base1,base2,cmin,cmax,amin,amax)
s = emptyStep();
s.run = runFlag; s.order = orderVal; s.name = name; s.desc = desc;
s.slices = slices; s.nsub = nsub; s.base1 = base1; s.base2 = base2;
s.cmin = cmin; s.cmax = cmax; s.amin = amin; s.amax = amax;
end

function state = renumberSteps(state)
for i = 1:numel(state.steps)
    state.steps(i).order = i;
end
end

function steps = insertStepAt(steps,item,pos)
pos = max(1,min(numel(steps)+1,pos));
if isempty(steps)
    steps = item;
elseif pos == 1
    steps = [item steps];
elseif pos > numel(steps)
    steps = [steps item];
else
    steps = [steps(1:pos-1) item steps(pos:end)];
end
end

function fields = relevantFields(s)
fields = {};
switch lower(strtrim(s.name))
    case 'motor', fields = {'slices'};
    case 'filtering', fields = {'filterType','fcLow','fcHigh','filterOrder'};
    case 'imregdemons', fields = {'nsub'};
    case {'video gui','scm gui'}, fields = {'base1','base2','cmin','cmax','amin','amax'};
    case 'time-course viewer', fields = {'base1','base2','cmin','cmax'};
    case 'functional connectivity', fields = {'cmin','cmax'};
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
labels.filterType = 'Filter type 1=band 2=low 3=high';
labels.fcLow = 'Low cutoff Hz';
labels.fcHigh = 'High cutoff Hz';
labels.filterOrder = 'Filter order';
end

function v = sanitizeValue(fieldName,v)
switch fieldName
    case 'slices'
        v = round(max(1,min(12,v)));
    case 'nsub'
        v = round(max(1,min(1000,v)));
    case 'filterType'
        v = round(max(1,min(3,v)));
    case 'filterOrder'
        v = round(max(1,min(6,v)));
    otherwise
        if ~isfinite(v), v = NaN; end
end
end

function txt = makeDetailText(s)
fields = relevantFields(s); labels = fieldLabels();
txt = {['Step: ' s.name],'',['Recommended: ' s.desc],''};
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
txt{end+1} = 'Existing module dialogs still define final processing settings in V5.';
end

function steps = normalizeLoadedSteps(steps)
defaultSteps = makeDefaultSteps();
if ~isstruct(steps), steps = defaultSteps; return; end
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
    warndlg('Studio window was not found.','Standardized Analysis'); return;
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
            oldStdHas = false;
            oldStdVal = [];
            try
                oldStdHas = isappdata(studioFig,'deconf_std_workflow_step');
                if oldStdHas
                    oldStdVal = getappdata(studioFig,'deconf_std_workflow_step');
                end
                setappdata(studioFig,'deconf_std_workflow_step',stepStruct);
            catch
            end
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
                restoreStdWorkflowAppdata(studioFig,oldStdHas,oldStdVal);
                ok = true; return;
            catch ME
                restoreStdWorkflowAppdata(studioFig,oldStdHas,oldStdVal);
                warndlg(['Could not launch ' stepName ': ' ME.message],'Standardized Analysis');
                ok = false; return;
            end
        end
    end
end
warndlg(['Could not find a Studio button for: ' stepName],'Standardized Analysis');
end

function restoreStdWorkflowAppdata(studioFig,oldStdHas,oldStdVal)
try
    if oldStdHas
        setappdata(studioFig,'deconf_std_workflow_step',oldStdVal);
    elseif isappdata(studioFig,'deconf_std_workflow_step')
        rmappdata(studioFig,'deconf_std_workflow_step');
    end
catch
end
end

% DECONF_STD_HELPERS_V61

function setStudioReady(studioFig,isReady)
try
    if isempty(studioFig) || ~ishandle(studioFig), return; end
    S = guidata(studioFig);
    if isstruct(S) && isfield(S,'statusPanel') && ishghandle(S.statusPanel) && isfield(S,'statusText') && ishghandle(S.statusText)
        if isReady
            bg = [0.15 0.60 0.20]; label = 'PROGRAM READY';
        else
            bg = [0.85 0.20 0.20]; label = 'PROGRAM NOT READY';
        end
        set(S.statusPanel,'BackgroundColor',bg,'HighlightColor',bg,'ShadowColor',bg);
        set(S.statusText,'BackgroundColor',bg,'ForegroundColor',[1 1 1],'String',label);
        drawnow;
    end
catch
end
end

function waitForInteractiveStep(stepName,figsBefore)
try
    nm = lower(strtrim(stepName));
    mustWait = any(strcmp(nm,{'video gui','scm gui','registration to atlas'}));
    if ~mustWait, return; end
    pause(0.35); drawnow;
    figsAfter = findall(0,'Type','figure');
    newFigs = setdiff(figsAfter,figsBefore);
    if isempty(newFigs)
        if strcmp(nm,'video gui')
            newFigs = findobj(0,'Type','figure','-regexp','Name','Video');
        elseif strcmp(nm,'scm gui')
            newFigs = findobj(0,'Type','figure','-regexp','Name','SCM|Signal');
        elseif strcmp(nm,'registration to atlas')
            newFigs = findobj(0,'Type','figure','-regexp','Name','Registration|Atlas|Coreg');
        end
    end
    if ~isempty(newFigs) && ishghandle(newFigs(1))
        waitfor(newFigs(1));
    end
catch
end
end

function choice = askExistingOutputDecision(studioFig,stepName)
choice = 'run';
try
    nm = lower(strtrim(stepName));
    processSteps = {'motor','imregdemons','frame rejection','scrubbing','filtering','temporal smoothing','pca / ica','despike'};
    if ~any(strcmp(nm,processSteps)), return; end
    S = guidata(studioFig);
    if ~isstruct(S) || ~isfield(S,'exportPath') || isempty(S.exportPath), return; end
    preFolder = fullfile(S.exportPath,'Preprocessing');
    if ~exist(preFolder,'dir'), return; end
    tag = existingTagForStep(nm);
    files = dir(fullfile(preFolder,'**','*.mat'));
    hit = {};
    for ii = 1:numel(files)
        fp = fullfile(files(ii).folder,files(ii).name);
        if ~isempty(strfind(lower(fp),tag))
            hit{end+1} = fp; %#ok<AGROW>
        end
    end
    if isempty(hit), return; end
    latest = hit{end};
    msg = sprintf('%s output seems to already exist.\n\nLatest match:\n%s\n\nWhat should Standardized Analysis do?',stepName,latest);
    answ = questdlg(msg,'Existing analysis output','Skip','Redo','Cancel','Skip');
    if isempty(answ) || strcmpi(answ,'Cancel')
        choice = 'cancel';
    elseif strcmpi(answ,'Skip')
        choice = 'skip';
    else
        choice = 'run';
    end
catch
    choice = 'run';
end
end

function tag = existingTagForStep(nm)
switch nm
    case 'motor', tag = 'motor';
    case 'imregdemons', tag = 'imreg';
    case 'frame rejection', tag = 'framerej';
    case 'scrubbing', tag = 'scrub';
    case 'filtering', tag = 'filter';
    case 'temporal smoothing', tag = 'smooth';
    case 'pca / ica', tag = 'ica';
    case 'despike', tag = 'despike';
    otherwise, tag = nm;
end
end

function candidates = stepCandidates(stepName)
switch lower(strtrim(stepName))
    case 'motor', candidates = {'Motor','Step Motor','Step-Motor','Motor Correction'};
    case 'frame rejection', candidates = {'Frame Rejection','Frame rejection','Frame Reject'};
    case 'scrubbing', candidates = {'Scrubbing','Scrub'};
    case 'filtering', candidates = {'Filtering','Filter','Temporal Filtering'};
    case 'temporal smoothing', candidates = {'Temporal Smoothing','Smoothing/Subsampling','Temporal Smoothing/Subsampling','Subsampling'};
    case 'pca / ica', candidates = {'PCA / ICA','PCA/ICA','PCA ICA','ICA','PCA'};
    case 'despike', candidates = {'Despike','Despiking'};
    case 'imregdemons', candidates = {'Imregdemons','Imreg Demons','Imregdemons Preprocess','Registration Demons'};
    case 'full qc', candidates = {'Full QC','QC','Advanced QC','Quality Control'};
    case 'mask editor', candidates = {'Mask Editor','Video & SCM Mask','Mask'};
    case 'video gui', candidates = {'Video GUI','Video & SCM Mask','Video','Open Video GUI'};
    case 'time-course viewer', candidates = {'Time-Course Viewer','Time Course Viewer','Timecourse Viewer','Time Course'};
    case 'scm gui', candidates = {'SCM GUI','SCM','Signal Change Map','Signal Change Maps'};
    case 'registration to atlas', candidates = {'Registration to Atlas','Register to Atlas','Atlas Registration','Coregistration','Coreg'};
    case 'segmentation', candidates = {'Segmentation','Segment','Atlas Segmentation'};
    case 'functional connectivity', candidates = {'Functional Connectivity','FC','Connectivity'};
    case 'group analysis', candidates = {'Group Analysis','GroupAnalysis','Open Group Analysis'};
    otherwise, candidates = {stepName};
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
