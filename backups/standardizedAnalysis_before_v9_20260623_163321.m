function standardizedAnalysis(studioFig)
% standardizedAnalysis.m - deConfUSIon standardized workflow manager
% V7 clean version: no duplicate helpers, clearer GUI, click-hold-drag reorder.

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
state.dragStartRow = 0;
state.dragIsActive = false;
state.fig = [];
state.listPanel = [];
state.paramPanel = [];
state.detailBox = [];
state.statusText = [];
state.hRow = [];
state.hArrow = [];
state.hRun = [];
state.hOrder = [];
state.hName = [];
state.hDesc = [];
state.rowLayout = [];

ss = get(0,'ScreenSize');
w = max(1300,round(ss(3)*0.97));
h = max(820,round(ss(4)*0.92));
x = max(1,round((ss(3)-w)/2));
y = max(1,round((ss(4)-h)/2));

state.fig = figure('Name','deConfUSIon - Standardized Analysis', ...
    'NumberTitle','off', ...
    'MenuBar','none', ...
    'ToolBar','none', ...
    'Color',[0.025 0.030 0.045], ...
    'Units','pixels', ...
    'Position',[x y w h], ...
    'Resize','on', ...
    'Tag','deconfusion_standardized_analysis_v7');
movegui(state.fig,'center');

uicontrol(state.fig,'Style','text', ...
    'String','STANDARDIZED ANALYSIS', ...
    'Units','normalized', ...
    'Position',[0.015 0.935 0.55 0.050], ...
    'BackgroundColor',[0.025 0.030 0.045], ...
    'ForegroundColor',[0.35 0.95 1.00], ...
    'FontSize',30, ...
    'FontWeight','bold', ...
    'HorizontalAlignment','left');

uicontrol(state.fig,'Style','text', ...
    'String','Click or hold on any row text/background to select. Hold left mouse and release on another row to move. Ticked rows run in shown order.', ...
    'Units','normalized', ...
    'Position',[0.015 0.900 0.75 0.030], ...
    'BackgroundColor',[0.025 0.030 0.045], ...
    'ForegroundColor',[0.85 0.92 0.98], ...
    'FontSize',15, ...
    'FontWeight','bold', ...
    'HorizontalAlignment','left');

state.listPanel = uipanel(state.fig, ...
    'Title','Workflow order', ...
    'Units','normalized', ...
    'Position',[0.015 0.075 0.700 0.815], ...
    'BackgroundColor',[0.040 0.048 0.068], ...
    'ForegroundColor',[0.35 0.95 1.00], ...
    'HighlightColor',[0.15 0.28 0.35], ...
    'ShadowColor',[0.02 0.02 0.03], ...
    'FontSize',17, ...
    'FontWeight','bold');

state.paramPanel = uipanel(state.fig, ...
    'Title','Selected step', ...
    'Units','normalized', ...
    'Position',[0.735 0.405 0.250 0.485], ...
    'BackgroundColor',[0.050 0.060 0.082], ...
    'ForegroundColor',[0.35 0.95 1.00], ...
    'HighlightColor',[0.18 0.30 0.36], ...
    'ShadowColor',[0.02 0.02 0.03], ...
    'FontSize',17, ...
    'FontWeight','bold');

state.detailBox = uicontrol(state.fig,'Style','edit', ...
    'Units','normalized', ...
    'Position',[0.735 0.210 0.250 0.175], ...
    'Max',10, ...
    'Min',0, ...
    'Enable','inactive', ...
    'HorizontalAlignment','left', ...
    'BackgroundColor',[0.070 0.080 0.108], ...
    'ForegroundColor',[1.00 1.00 1.00], ...
    'FontSize',13);

state.statusText = uicontrol(state.fig,'Style','text', ...
    'String','Ready.', ...
    'Units','normalized', ...
    'Position',[0.015 0.018 0.70 0.035], ...
    'BackgroundColor',[0.025 0.030 0.045], ...
    'ForegroundColor',[0.80 0.95 0.85], ...
    'FontSize',13, ...
    'FontWeight','bold', ...
    'HorizontalAlignment','left');

btnW = 0.118; btnH = 0.045; gap = 0.014;
uicontrol(state.fig,'Style','pushbutton','String','Recommended', ...
    'Units','normalized','Position',[0.735 0.900 btnW 0.040], ...
    'FontSize',13,'FontWeight','bold','BackgroundColor',[0.18 0.20 0.25],'ForegroundColor',[1 1 1], ...
    'Callback',@onRecommended);
uicontrol(state.fig,'Style','pushbutton','String','Save / Load', ...
    'Units','normalized','Position',[0.735+btnW+gap 0.900 btnW 0.040], ...
    'FontSize',13,'FontWeight','bold','BackgroundColor',[0.18 0.20 0.25],'ForegroundColor',[1 1 1], ...
    'Callback',@onSaveLoad);
uicontrol(state.fig,'Style','pushbutton','String','Run Workflow', ...
    'Units','normalized','Position',[0.735 0.145 btnW btnH], ...
    'FontSize',14,'FontWeight','bold','BackgroundColor',[0.08 0.48 0.26],'ForegroundColor',[1 1 1], ...
    'Callback',@onRunWorkflow);
uicontrol(state.fig,'Style','pushbutton','String','Run Step', ...
    'Units','normalized','Position',[0.735+btnW+gap 0.145 btnW btnH], ...
    'FontSize',14,'FontWeight','bold','BackgroundColor',[0.10 0.25 0.55],'ForegroundColor',[1 1 1], ...
    'Callback',@onRunSelectedStep);
uicontrol(state.fig,'Style','pushbutton','String','Move Up', ...
    'Units','normalized','Position',[0.735 0.090 btnW btnH], ...
    'FontSize',13,'FontWeight','bold','BackgroundColor',[0.18 0.20 0.25],'ForegroundColor',[1 1 1], ...
    'Callback',@(src,evt) moveSelected(-1));
uicontrol(state.fig,'Style','pushbutton','String','Move Down', ...
    'Units','normalized','Position',[0.735+btnW+gap 0.090 btnW btnH], ...
    'FontSize',13,'FontWeight','bold','BackgroundColor',[0.18 0.20 0.25],'ForegroundColor',[1 1 1], ...
    'Callback',@(src,evt) moveSelected(1));
uicontrol(state.fig,'Style','pushbutton','String','Top', ...
    'Units','normalized','Position',[0.735 0.035 btnW btnH], ...
    'FontSize',13,'FontWeight','bold','BackgroundColor',[0.18 0.20 0.25],'ForegroundColor',[1 1 1], ...
    'Callback',@(src,evt) moveSelectedTo('top'));
uicontrol(state.fig,'Style','pushbutton','String','Bottom', ...
    'Units','normalized','Position',[0.735+btnW+gap 0.035 btnW btnH], ...
    'FontSize',13,'FontWeight','bold','BackgroundColor',[0.18 0.20 0.25],'ForegroundColor',[1 1 1], ...
    'Callback',@(src,evt) moveSelectedTo('bottom'));

guidata(state.fig,state);
% DECONF_STD_FIGURE_MOUSEDOWN_V8
set(state.fig,'WindowButtonDownFcn',@figureMouseDown);
createRows();
refreshRows();
refreshSelectedPanel();

%% Nested GUI functions
function S = getState()
    S = guidata(state.fig);
end

function putState(S)
    guidata(S.fig,S);
    state = S;
end

function figureMouseDown(~,~)
    S = getState();
    try
        obj = hittest(S.fig);
        if ishghandle(obj)
            st = '';
            try, st = get(obj,'Style'); catch, st = ''; end
            if strcmpi(st,'edit') || strcmpi(st,'checkbox')
                return;
            end
        end
    catch
    end
    r = rowUnderMouse(S);
    if r >= 1 && r <= numel(S.steps)
        startDrag(r);
    end
end

function createRows()
    S = getState();
    n = numel(S.steps);
    S.hRow = gobjects(n,1); S.hArrow = gobjects(n,1); S.hRun = gobjects(n,1);
    S.hOrder = gobjects(n,1); S.hName = gobjects(n,1); S.hDesc = gobjects(n,1);

    uicontrol(S.listPanel,'Style','text','String','Sel', ...
        'Units','normalized','Position',[0.010 0.940 0.045 0.040], ...
        'BackgroundColor',[0.040 0.048 0.068],'ForegroundColor',[0.35 0.95 1.00], ...
        'FontSize',13,'FontWeight','bold');
    uicontrol(S.listPanel,'Style','text','String','Run', ...
        'Units','normalized','Position',[0.060 0.940 0.050 0.040], ...
        'BackgroundColor',[0.040 0.048 0.068],'ForegroundColor',[0.35 0.95 1.00], ...
        'FontSize',13,'FontWeight','bold');
    uicontrol(S.listPanel,'Style','text','String','#', ...
        'Units','normalized','Position',[0.115 0.940 0.050 0.040], ...
        'BackgroundColor',[0.040 0.048 0.068],'ForegroundColor',[0.35 0.95 1.00], ...
        'FontSize',13,'FontWeight','bold');
    uicontrol(S.listPanel,'Style','text','String','Step', ...
        'Units','normalized','Position',[0.175 0.940 0.230 0.040], ...
        'BackgroundColor',[0.040 0.048 0.068],'ForegroundColor',[0.35 0.95 1.00], ...
        'FontSize',13,'FontWeight','bold','HorizontalAlignment','left');
    uicontrol(S.listPanel,'Style','text','String','Recommended preset', ...
        'Units','normalized','Position',[0.415 0.940 0.570 0.040], ...
        'BackgroundColor',[0.040 0.048 0.068],'ForegroundColor',[0.35 0.95 1.00], ...
        'FontSize',13,'FontWeight','bold','HorizontalAlignment','left');

    topY = 0.900; bottomY = 0.015; gapY = 0.006;
    rowH = (topY-bottomY-(n-1)*gapY)/n;
    S.rowLayout = [topY bottomY gapY rowH];

    for i = 1:n
        y = topY - (i-1)*(rowH+gapY) - rowH;
        S.hRow(i) = uipanel(S.listPanel,'Units','normalized','Position',[0.006 y 0.988 rowH], ...
            'BackgroundColor',[0.060 0.070 0.095],'BorderType','line', ...
            'HighlightColor',[0.12 0.35 0.22],'ShadowColor',[0.02 0.02 0.03], ...
            'ButtonDownFcn',@(src,evt) startDrag(i));
        S.hArrow(i) = uicontrol(S.hRow(i),'Style','text','String','', ...
            'Units','normalized','Position',[0.004 0.12 0.040 0.76], ...
            'FontSize',16,'FontWeight','bold','ButtonDownFcn',@(src,evt) startDrag(i));
        S.hRun(i) = uicontrol(S.hRow(i),'Style','checkbox','Value',false, ...
            'Units','normalized','Position',[0.053 0.15 0.040 0.70], ...
            'FontSize',12,'Callback',@(src,evt) toggleRun(i,src));
        S.hOrder(i) = uicontrol(S.hRow(i),'Style','edit','String',num2str(i), ...
            'Units','normalized','Position',[0.105 0.13 0.052 0.74], ...
            'FontSize',12,'FontWeight','bold','Callback',@(src,evt) editOrder(i,src));
        S.hName(i) = uicontrol(S.hRow(i),'Style','text','String','', ...
            'Units','normalized','Position',[0.170 0.10 0.235 0.80], ...
            'FontSize',17,'FontWeight','bold','HorizontalAlignment','left', ...
            'ButtonDownFcn',@(src,evt) startDrag(i));
        S.hDesc(i) = uicontrol(S.hRow(i),'Style','text','String','', ...
            'Units','normalized','Position',[0.415 0.10 0.570 0.80], ...
            'FontSize',15,'FontWeight','bold','HorizontalAlignment','left', ...
            'ButtonDownFcn',@(src,evt) startDrag(i));
    end
    putState(S);
end

function refreshRows()
    S = getState();
    for i = 1:numel(S.steps)
        s = S.steps(i);
        if i == S.selectedRow
            bg = [0.03 0.34 0.17]; fg = [1 1 1]; marker = '>';
        elseif S.dragIsActive && i == S.dragStartRow
            bg = [0.38 0.25 0.04]; fg = [1 1 1]; marker = 'DRAG';
        elseif mod(i,2)==0
            bg = [0.080 0.090 0.120]; fg = [0.92 0.96 1.00]; marker = '';
        else
            bg = [0.060 0.070 0.100]; fg = [0.92 0.96 1.00]; marker = '';
        end
        set(S.hRow(i),'BackgroundColor',bg,'HighlightColor',bg);
        set(S.hArrow(i),'String',marker,'BackgroundColor',bg,'ForegroundColor',[0.60 1.00 0.65]);
        set(S.hRun(i),'Value',s.run,'BackgroundColor',bg,'ForegroundColor',fg);
        set(S.hOrder(i),'String',num2str(i),'BackgroundColor',[0.12 0.13 0.17],'ForegroundColor',[1 1 1]);
        set(S.hName(i),'String',s.name,'BackgroundColor',bg,'ForegroundColor',fg);
        set(S.hDesc(i),'String',s.desc,'BackgroundColor',bg,'ForegroundColor',fg);
    end
    drawnow;
end

function startDrag(r)
    S = getState();
    if r < 1 || r > numel(S.steps), return; end
    S.selectedRow = r;
    S.dragStartRow = r;
    S.dragIsActive = true;
    putState(S);
    set(S.fig,'WindowButtonMotionFcn',@dragMotion);
    set(S.fig,'WindowButtonUpFcn',@endDrag);
    refreshRows();
    refreshSelectedPanel();
    setStatus(['Dragging row #' num2str(r) '. Release mouse on destination row. If dragging feels difficult, use Move Up/Down.'],[0.85 0.95 0.80]);
end

function dragMotion(~,~)
    S = getState();
    r = rowUnderMouse(S);
    if r >= 1 && r <= numel(S.steps)
        setStatus(['Release to move to row #' num2str(r) '.'],[0.85 0.95 0.80]);
    end
end

function endDrag(~,~)
    S = getState();
    set(S.fig,'WindowButtonMotionFcn','');
    set(S.fig,'WindowButtonUpFcn','');
    src = S.dragStartRow;
    dst = rowUnderMouse(S);
    S.dragIsActive = false;
    S.dragStartRow = 0;
    if src >= 1 && src <= numel(S.steps) && dst >= 1 && dst <= numel(S.steps) && src ~= dst
        item = S.steps(src);
        S.steps(src) = [];
        if src < dst, dst = dst - 1; end
        S.steps = insertStepAt(S.steps,item,dst);
        S = renumberSteps(S);
        S.selectedRow = dst;
        putState(S);
        refreshRows();
        refreshSelectedPanel();
        setStatus('Row moved by drag/drop.',[0.80 0.95 0.85]);
    else
        putState(S);
        refreshRows();
        refreshSelectedPanel();
        setStatus('Drag cancelled/no move.',[0.90 0.90 0.90]);
    end
end

function r = rowUnderMouse(S)
    r = 0;
    try
        mp = get(0,'PointerLocation');
        pp = getpixelposition(S.listPanel,true);
        relY = (mp(2)-pp(2))/pp(4);
        topY = S.rowLayout(1); gapY = S.rowLayout(3); rowH = S.rowLayout(4);
        for kk = 1:numel(S.steps)
            y1 = topY - (kk-1)*(rowH+gapY) - rowH;
            y2 = y1 + rowH;
            if relY >= y1 && relY <= y2
                r = kk; return;
            end
        end
    catch
        r = 0;
    end
end

function toggleRun(r,src)
    S = getState();
    if r < 1 || r > numel(S.steps), return; end
    S.selectedRow = r;
    S.steps(r).run = logical(get(src,'Value'));
    putState(S); refreshRows(); refreshSelectedPanel();
end

function editOrder(r,src)
    S = getState();
    v = str2double(get(src,'String'));
    if ~isfinite(v), refreshRows(); return; end
    v = round(max(1,min(numel(S.steps),v)));
    item = S.steps(r); S.steps(r) = [];
    S.steps = insertStepAt(S.steps,item,v);
    S = renumberSteps(S); S.selectedRow = v;
    putState(S); refreshRows(); refreshSelectedPanel();
end

function moveSelected(delta)
    S = getState(); r = S.selectedRow; newR = r + delta;
    if newR < 1 || newR > numel(S.steps), return; end
    tmp = S.steps(r); S.steps(r) = S.steps(newR); S.steps(newR) = tmp;
    S.selectedRow = newR; S = renumberSteps(S);
    putState(S); refreshRows(); refreshSelectedPanel();
end

function moveSelectedTo(whereTo)
    S = getState(); r = S.selectedRow;
    if r < 1 || r > numel(S.steps), return; end
    item = S.steps(r); S.steps(r) = [];
    if strcmpi(whereTo,'top'), S.steps = [item S.steps]; S.selectedRow = 1;
    else, S.steps = [S.steps item]; S.selectedRow = numel(S.steps); end
    S = renumberSteps(S); putState(S); refreshRows(); refreshSelectedPanel();
end

function refreshSelectedPanel()
    S = getState();
    old = get(S.paramPanel,'Children'); if ~isempty(old), delete(old); end
    r = S.selectedRow; if r < 1 || r > numel(S.steps), r = 1; end
    s = S.steps(r);
    uicontrol(S.paramPanel,'Style','text','String',['#' num2str(r) '  ' s.name], ...
        'Units','normalized','Position',[0.04 0.88 0.92 0.085], ...
        'BackgroundColor',[0.050 0.060 0.082],'ForegroundColor',[0.55 1.00 0.62], ...
        'FontSize',18,'FontWeight','bold','HorizontalAlignment','left');
    uicontrol(S.paramPanel,'Style','checkbox','String','Run this step','Value',s.run, ...
        'Units','normalized','Position',[0.04 0.80 0.90 0.07], ...
        'BackgroundColor',[0.050 0.060 0.082],'ForegroundColor',[0.92 0.96 1.00], ...
        'FontSize',14,'FontWeight','bold','Callback',@(src,evt) toggleRun(r,src));
    fields = relevantFields(s); labels = fieldLabels(); y = 0.70; dy = 0.086;
    if isempty(fields)
        uicontrol(S.paramPanel,'Style','text','String','No numeric preset for this step yet.', ...
            'Units','normalized','Position',[0.04 y 0.92 0.08], ...
            'BackgroundColor',[0.050 0.060 0.082],'ForegroundColor',[0.80 0.88 0.95], ...
            'FontSize',13,'FontWeight','bold','HorizontalAlignment','left');
    else
        for k = 1:numel(fields)
            f = fields{k}; if y < 0.05, break; end
            uicontrol(S.paramPanel,'Style','text','String',labels.(f), ...
                'Units','normalized','Position',[0.04 y 0.55 0.062], ...
                'BackgroundColor',[0.050 0.060 0.082],'ForegroundColor',[0.92 0.96 1.00], ...
                'FontSize',13,'FontWeight','bold','HorizontalAlignment','left');
            uicontrol(S.paramPanel,'Style','edit','String',num2str(s.(f)), ...
                'Units','normalized','Position',[0.61 y 0.33 0.067], ...
                'BackgroundColor',[0.12 0.13 0.17],'ForegroundColor',[1 1 1], ...
                'FontSize',13,'FontWeight','bold','Callback',@(src,evt) editParam(src,f));
            y = y - dy;
        end
    end
    set(S.detailBox,'String',makeDetailText(s));
end

function editParam(src,fieldName)
    S = getState(); r = S.selectedRow;
    v = str2double(get(src,'String'));
    if ~isfinite(v), set(src,'String',num2str(S.steps(r).(fieldName))); return; end
    S.steps(r).(fieldName) = sanitizeValue(fieldName,v);
    putState(S); refreshSelectedPanel();
end

function onRunWorkflow(~,~)
    S = getState();
    idx = find([S.steps.run]);
    if isempty(idx), setStatus('No workflow steps are ticked.',[1.0 0.55 0.45]); return; end
    for ii = 1:numel(idx)
        S = getState(); r = idx(ii); stepName = S.steps(r).name;
        choice = askExistingOutputDecision(S.studioFig,stepName);
        if strcmpi(choice,'cancel'), setStudioReady(S.studioFig,true); setStatus('Workflow cancelled.',[1 0.55 0.45]); return; end
        if strcmpi(choice,'skip'), setStatus(['Skipped existing step: ' stepName],[0.95 0.85 0.40]); continue; end
        setStudioReady(S.studioFig,false);
        figsBefore = findall(0,'Type','figure');
        setStatus(['Running ' num2str(ii) '/' num2str(numel(idx)) ': ' stepName],[0.80 0.95 0.85]);
        ok = triggerStudioStep(S.studioFig,stepName,S.steps(r));
        if ~ok, setStudioReady(S.studioFig,true); clearStdStepAppdata(); return; end
        waitForInteractiveStep(stepName,figsBefore);
        clearStdStepAppdata();
    end
    setStudioReady(S.studioFig,true);
    setStatus('Workflow finished.',[0.80 0.95 0.85]);
end

function onRunSelectedStep(~,~)
    S = getState(); r = S.selectedRow; stepName = S.steps(r).name;
    setStudioReady(S.studioFig,false);
    figsBefore = findall(0,'Type','figure');
    ok = triggerStudioStep(S.studioFig,stepName,S.steps(r));
    if ok, waitForInteractiveStep(stepName,figsBefore); end
    clearStdStepAppdata();
    setStudioReady(S.studioFig,true);
end

function onRecommended(~,~)
    S = getState(); S.steps = makeDefaultSteps(); S.selectedRow = 1;
    putState(S); refreshRows(); refreshSelectedPanel();
end

function onSaveLoad(~,~)
    S = getState();
    choice = questdlg('Preset action:','Save / Load workflow preset','Save','Load','Cancel','Save');
    presetFile = fullfile(fileparts(which('standardizedAnalysis')),'standardizedAnalysis_preset.mat');
    if strcmp(choice,'Save')
        steps = S.steps; %#ok<NASGU>
        save(presetFile,'steps'); setStatus(['Preset saved: ' presetFile],[0.80 0.95 0.85]);
    elseif strcmp(choice,'Load')
        if exist(presetFile,'file')
            X = load(presetFile,'steps');
            if isfield(X,'steps'), S.steps = normalizeLoadedSteps(X.steps); S = renumberSteps(S); S.selectedRow = 1; putState(S); refreshRows(); refreshSelectedPanel(); end
        end
    end
end

function setStatus(msg,colorVal)
    S = getState();
    if isfield(S,'statusText') && ishghandle(S.statusText)
        set(S.statusText,'String',msg,'ForegroundColor',colorVal); drawnow;
    else
        disp(msg);
    end
end

end

%% Helper functions
function steps = makeDefaultSteps()
steps = repmat(emptyStep(),1,17);
steps(1)  = makeStep(true,  1,'Motor',                 '4 slices, split MAT folder, residual despike 4, correction none',4,NaN,NaN,NaN,NaN,NaN,NaN,NaN);
steps(2)  = makeStep(false, 2,'Frame Rejection',       'optional frame rejection before correction',NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN);
steps(3)  = makeStep(false, 3,'Scrubbing',             'optional scrubbing after correction',NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN);
steps(4)  = makeStep(true, 4,'Filtering',             'filterType 1=band, low=0.001 Hz, high=0.20 Hz, order=4',NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN);
steps(5)  = makeStep(false, 5,'Temporal Smoothing',    'mode 1=smooth 2=subsample, win=60 s, nsub=50, method 1=mean 2=median',NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN);
steps(6)  = makeStep(false, 6,'PCA / ICA',             'method 1=PCA 2=ICA; component GUI still opens for selection',NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN);
steps(7)  = makeStep(false, 7,'Despike',               'optional additional despiking',NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN);
steps(8)  = makeStep(true,  8,'Imregdemons',           'median mode, nsub 25, step-motor per-slice',NaN,25,NaN,NaN,NaN,NaN,NaN,NaN);
steps(9)  = makeStep(true,  9,'Full QC',               'full advanced QC on newest dataset',NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN);
steps(10) = makeStep(true, 10,'Mask Editor',           'save underlay/mask, then close',NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN);
steps(11) = makeStep(true, 11,'Video GUI',             'baseline 30-35 s, signed PSC, caxis -100..100, alpha -20..20',NaN,NaN,30,35,-100,100,-20,20);
steps(12) = makeStep(false,12,'Time-Course Viewer',    'optional inspect ROI/time-course',NaN,NaN,30,35,-100,100,NaN,NaN);
steps(13) = makeStep(true, 13,'SCM GUI',               'baseline 30-35 s, signed PSC, caxis -100..100, alpha -20..20',NaN,NaN,30,35,-100,100,-20,20);
steps(14) = makeStep(true, 14,'Registration to Atlas', 'atlas/coregistration workflow',NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN);
steps(15) = makeStep(true, 15,'Segmentation',          'open segmentation popup',NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN);
steps(16) = makeStep(true, 16,'Functional Connectivity','optional FC after segmentation',NaN,NaN,NaN,NaN,-1,1,NaN,NaN);
steps(17) = makeStep(false,17,'Group Analysis',        'optional group-level analysis',NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN);
for kk=1:numel(steps), steps(kk).filterType=NaN; steps(kk).fcLow=NaN; steps(kk).fcHigh=NaN; steps(kk).filterOrder=NaN; end
steps(4).filterType = 1; steps(4).fcLow = 0.001; steps(4).fcHigh = 0.20; steps(4).filterOrder = 4;
% DECONF_STD_DEFAULT_RUNS_ALPHA_V8
steps(4).run = true;     % Filtering included by default
steps(16).run = true;    % Functional Connectivity after Segmentation by default
steps(11).amin = -20; steps(11).amax = 20;
steps(13).amin = -20; steps(13).amax = 20;
steps(5).tempMode = 1; steps(5).tempWinSec = 60; steps(5).tempNsub = 50; steps(5).tempMethod = 1;
steps(6).pcaicaMethod = 1; steps(6).pcaNcomp = 50; steps(6).icaNcomp = 30;
end

function s = emptyStep()
s = struct('run',false,'order',0,'name','','desc','', ...
    'slices',NaN,'nsub',NaN,'base1',NaN,'base2',NaN, ...
    'cmin',NaN,'cmax',NaN,'amin',NaN,'amax',NaN, ...
    'filterType',NaN,'fcLow',NaN,'fcHigh',NaN,'filterOrder',NaN, ...
    'tempMode',NaN,'tempWinSec',NaN,'tempNsub',NaN,'tempMethod',NaN, ...
    'pcaicaMethod',NaN,'pcaNcomp',NaN,'icaNcomp',NaN);
end

function s = makeStep(runFlag,orderVal,name,desc,slices,nsub,base1,base2,cmin,cmax,amin,amax)
s = emptyStep();
s.run = runFlag; s.order = orderVal; s.name = name; s.desc = desc;
s.slices = slices; s.nsub = nsub; s.base1 = base1; s.base2 = base2;
s.cmin = cmin; s.cmax = cmax; s.amin = amin; s.amax = amax;
end

function S = renumberSteps(S)
for i=1:numel(S.steps), S.steps(i).order = i; end
end

function steps = insertStepAt(steps,item,pos)
pos = max(1,min(numel(steps)+1,pos));
if isempty(steps), steps = item;
elseif pos == 1, steps = [item steps];
elseif pos > numel(steps), steps = [steps item];
else, steps = [steps(1:pos-1) item steps(pos:end)]; end
end

function fields = relevantFields(s)
fields = {};
switch lower(strtrim(s.name))
    case 'motor', fields = {'slices'};
    case 'imregdemons', fields = {'nsub'};
    case 'filtering', fields = {'filterType','fcLow','fcHigh','filterOrder'};
    case 'temporal smoothing', fields = {'tempMode','tempWinSec','tempNsub','tempMethod'};
    case 'pca / ica', fields = {'pcaicaMethod','pcaNcomp','icaNcomp'};
    case {'video gui','scm gui'}, fields = {'base1','base2','cmin','cmax','amin','amax'};
    case 'time-course viewer', fields = {'base1','base2','cmin','cmax'};
    case 'functional connectivity', fields = {'cmin','cmax'};
end
end

function labels = fieldLabels()
labels = struct();
labels.slices = 'Slices'; labels.nsub = 'Imreg n / nsub';
labels.base1 = 'Baseline start (s)'; labels.base2 = 'Baseline end (s)';
labels.cmin = 'Display min (%)'; labels.cmax = 'Display max (%)';
labels.amin = 'Alpha mod min (%)'; labels.amax = 'Alpha mod max (%)';
labels.filterType = 'Filter type 1=band 2=low 3=high';
labels.fcLow = 'Low cutoff Hz'; labels.fcHigh = 'High cutoff Hz'; labels.filterOrder = 'Filter order';
labels.tempMode = 'Temporal mode 1=smooth 2=subsample';
labels.tempWinSec = 'Smoothing window (s)';
labels.tempNsub = 'Subsample n frames';
labels.tempMethod = 'Block method 1=mean 2=median';
labels.pcaicaMethod = 'Method 1=PCA 2=ICA';
labels.pcaNcomp = 'PCA max components';
labels.icaNcomp = 'ICA max components';
end

function v = sanitizeValue(fieldName,v)
switch fieldName
    case 'slices', v = round(max(1,min(12,v)));
    case 'nsub', v = round(max(1,min(1000,v)));
    case 'filterType', v = round(max(1,min(3,v)));
    case 'filterOrder', v = round(max(1,min(6,v)));
    case 'tempMode', v = round(max(1,min(2,v)));
    case 'tempMethod', v = round(max(1,min(2,v)));
    case 'pcaicaMethod', v = round(max(1,min(2,v)));
    case 'pcaNcomp', v = round(max(1,min(200,v)));
    case 'icaNcomp', v = round(max(1,min(100,v)));
    otherwise, if ~isfinite(v), v = NaN; end
end
end

function txt = makeDetailText(s)
fields = relevantFields(s); labels = fieldLabels();
txt = {['Step: ' s.name],'',['Recommended: ' s.desc],''};
if isempty(fields)
    txt{end+1} = 'Editable numbers: none for this step yet.';
else
    txt{end+1} = 'Editable numbers:';
    for i=1:numel(fields), f=fields{i}; txt{end+1} = ['  ' labels.(f) ' = ' num2str(s.(f))]; end
end
txt{end+1}='';
txt{end+1}='Standardized Analysis passes these numbers to patched module callbacks.';
end

function steps = normalizeLoadedSteps(steps)
defaultSteps = makeDefaultSteps();
if ~isstruct(steps), steps = defaultSteps; return; end
needFields = fieldnames(emptyStep());
for i=1:numel(steps)
    for f=1:numel(needFields)
        if ~isfield(steps,needFields{f}), steps(i).(needFields{f}) = defaultSteps(min(i,numel(defaultSteps))).(needFields{f}); end
    end
end
end

function ok = triggerStudioStep(studioFig,stepName,stepStruct)
ok = false;
try
    setStdStepAppdata(studioFig,stepStruct);
    candidates = stepCandidates(stepName);
    allBtns = findall(studioFig,'Type','uicontrol');
    for c=1:numel(candidates)
        target = cleanLabel(candidates{c});
        for i=1:numel(allBtns)
            try, style=get(allBtns(i),'Style'); label=get(allBtns(i),'String'); catch, continue; end
            if ~ischar(label) || isempty(label), continue; end
            if ~(strcmpi(style,'pushbutton') || strcmpi(style,'togglebutton')), continue; end
            if strcmp(cleanLabel(label),target)
                cb = get(allBtns(i),'Callback');
                if isa(cb,'function_handle'), feval(cb,allBtns(i),[]);
                elseif iscell(cb) && ~isempty(cb) && isa(cb{1},'function_handle'), feval(cb{1},allBtns(i),[],cb{2:end});
                elseif ischar(cb), eval(cb);
                else, return; end
                ok = true; return;
            end
        end
    end
    warndlg(['Could not find Studio button for: ' stepName],'Standardized Analysis');
catch ME
    warndlg(['Could not launch ' stepName ': ' ME.message],'Standardized Analysis');
end
end

function setStdStepAppdata(studioFig,stepStruct)
try, setappdata(0,'deconf_std_workflow_step',stepStruct); end
try, if ishghandle(studioFig), setappdata(studioFig,'deconf_std_workflow_step',stepStruct); end, end
try
    figs = findall(0,'Type','figure');
    for ii=1:numel(figs), setappdata(figs(ii),'deconf_std_workflow_step',stepStruct); end
end
end

function clearStdStepAppdata()
try, if isappdata(0,'deconf_std_workflow_step'), rmappdata(0,'deconf_std_workflow_step'); end, end
% Do not aggressively remove from all figures while callbacks may still inspect it.
end

function candidates = stepCandidates(stepName)
switch lower(strtrim(stepName))
    case 'motor', candidates = {'Motor','Step Motor','Step-Motor','Motor Correction'};
    case 'frame rejection', candidates = {'Frame Rejection','Frame Reject'};
    case 'scrubbing', candidates = {'Scrubbing','Scrub'};
    case 'filtering', candidates = {'Filtering','Filter','Temporal Filtering'};
    case 'temporal smoothing', candidates = {'Temporal Smoothing','Smoothing/Subsampling','Temporal Smoothing/Subsampling','Subsampling'};
    case 'pca / ica', candidates = {'PCA / ICA','PCA/ICA','ICA','PCA'};
    case 'despike', candidates = {'Despike','Despiking'};
    case 'imregdemons', candidates = {'Imregdemons','Imreg Demons','Imregdemons Preprocess'};
    case 'full qc', candidates = {'Full QC','QC','Advanced QC','Quality Control'};
    case 'mask editor', candidates = {'Mask Editor','Video & SCM Mask','Mask'};
    case 'video gui', candidates = {'Video GUI','Video & SCM Mask','Video','Open Video GUI'};
    case 'time-course viewer', candidates = {'Time-Course Viewer','Time Course Viewer','Time Course'};
    case 'scm gui', candidates = {'SCM GUI','SCM','Signal Change Map','Signal Change Maps'};
    case 'registration to atlas', candidates = {'Registration to Atlas','Register to Atlas','Atlas Registration','Coregistration','Coreg'};
    case 'segmentation', candidates = {'Segmentation','Segment','Atlas Segmentation'};
    case 'functional connectivity', candidates = {'Functional Connectivity','FC','Connectivity'};
    case 'group analysis', candidates = {'Group Analysis','GroupAnalysis'};
    otherwise, candidates = {stepName};
end
end

function s = cleanLabel(s)
if iscell(s), s=s{1}; end
if ~ischar(s), s=''; return; end
s = lower(strtrim(s)); s = strrep(s,char(10),' '); s = strrep(s,char(13),' '); s = regexprep(s,'\s+',' ');
end

function setStudioReady(studioFig,isReady)
try
    if isempty(studioFig) || ~ishghandle(studioFig), return; end
    S = guidata(studioFig);
    if isstruct(S) && isfield(S,'statusPanel') && ishghandle(S.statusPanel) && isfield(S,'statusText') && ishghandle(S.statusText)
        if isReady, bg=[0.15 0.60 0.20]; label='PROGRAM READY'; else, bg=[0.85 0.20 0.20]; label='PROGRAM NOT READY'; end
        set(S.statusPanel,'BackgroundColor',bg,'HighlightColor',bg,'ShadowColor',bg);
        set(S.statusText,'BackgroundColor',bg,'ForegroundColor',[1 1 1],'String',label); drawnow;
    end
catch
end
end

function waitForInteractiveStep(stepName,figsBefore)
try
    nm = lower(strtrim(stepName));
    mustWait = any(strcmp(nm,{'video gui','scm gui','registration to atlas'}));
    if ~mustWait, return; end
    pause(0.5); drawnow;
    figsAfter = findall(0,'Type','figure');
    newFigs = setdiff(figsAfter,figsBefore);
    if isempty(newFigs)
        if strcmp(nm,'video gui'), newFigs = findobj(0,'Type','figure','-regexp','Name','Video'); end
        if strcmp(nm,'scm gui'), newFigs = findobj(0,'Type','figure','-regexp','Name','SCM|Signal'); end
        if strcmp(nm,'registration to atlas'), newFigs = findobj(0,'Type','figure','-regexp','Name','Registration|Atlas|Coreg'); end
    end
    if ~isempty(newFigs) && ishghandle(newFigs(1)), waitfor(newFigs(1)); end
catch
end
end

function choice = askExistingOutputDecision(studioFig,stepName)
choice = 'run';
try
    nm = lower(strtrim(stepName));
    processSteps = {'motor','imregdemons','frame rejection','scrubbing','filtering','temporal smoothing','pca / ica','despike'};
    if ~any(strcmp(nm,processSteps)), return; end
    S = guidata(studioFig); if ~isstruct(S) || ~isfield(S,'exportPath') || isempty(S.exportPath), return; end
    preFolder = fullfile(S.exportPath,'Preprocessing'); if ~exist(preFolder,'dir'), return; end
    tag = existingTagForStep(nm); files = dir(fullfile(preFolder,'**','*.mat')); hit = {};
    for ii=1:numel(files), fp=fullfile(files(ii).folder,files(ii).name); if ~isempty(strfind(lower(fp),tag)), hit{end+1}=fp; end, end
    if isempty(hit), return; end
    answ = questdlg(sprintf('%s output seems to exist.\n\nLatest match:\n%s\n\nWhat should Standardized Analysis do?',stepName,hit{end}), ...
        'Existing output','Skip','Redo','Cancel','Skip');
    if isempty(answ) || strcmpi(answ,'Cancel'), choice='cancel'; elseif strcmpi(answ,'Skip'), choice='skip'; else, choice='run'; end
catch
    choice = 'run';
end
end

function tag = existingTagForStep(nm)
switch nm
    case 'motor', tag='motor'; case 'imregdemons', tag='imreg'; case 'frame rejection', tag='framerej';
    case 'scrubbing', tag='scrub'; case 'filtering', tag='filter'; case 'temporal smoothing', tag='smooth';
    case 'pca / ica', tag='ica'; case 'despike', tag='despike'; otherwise, tag=nm;
end
end
