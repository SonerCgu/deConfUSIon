function standardizedAnalysis(studioFig)
% standardizedAnalysis.m - deConfUSIon standardized workflow manager
% V11 clean stable version: no nested-function/end-style mix.
% Row click only selects. Run checkbox only changes when checkbox is clicked.

if nargin < 1 || isempty(studioFig) || ~ishghandle(studioFig)
    figs = findobj(0,'Type','figure','Name','fUSI Studio');
    if isempty(figs)
        studioFig = gcf;
    else
        studioFig = figs(1);
    end
end

old = findobj(0,'Type','figure','Tag','deconfusion_standardized_analysis_v11');
if ~isempty(old)
    try, delete(old); catch, end
end

ss = get(0,'ScreenSize');
w = max(1350,round(ss(3)*0.96));
h = max(830,round(ss(4)*0.90));
x = max(1,round((ss(3)-w)/2));
y = max(1,round((ss(4)-h)/2));

fig = figure('Name','deConfUSIon - Standardized Analysis', ...
    'NumberTitle','off', ...
    'MenuBar','none', ...
    'ToolBar','none', ...
    'Color',[0.020 0.025 0.040], ...
    'Units','pixels', ...
    'Position',[x y w h], ...
    'Resize','on', ...
    'Tag','deconfusion_standardized_analysis_v11');
movegui(fig,'center');

S = struct();
S.fig = fig;
S.studioFig = studioFig;
S.steps = makeDefaultSteps();
S.selectedRow = 1;
S.listPanel = [];
S.paramPanel = [];
S.detailBox = [];
S.statusText = [];
S.hRow = [];
S.hArrow = [];
S.hRun = [];
S.hOrder = [];
S.hName = [];
S.hDesc = [];

uicontrol(fig,'Style','text', ...
    'String','STANDARDIZED ANALYSIS', ...
    'Units','normalized', ...
    'Position',[0.015 0.935 0.55 0.050], ...
    'BackgroundColor',[0.020 0.025 0.040], ...
    'ForegroundColor',[1.00 0.68 0.22], ...
    'FontSize',32, ...
    'FontWeight','bold', ...
    'HorizontalAlignment','left');

uicontrol(fig,'Style','text', ...
    'String','Click a row to select it. Only the checkbox changes Run/Skip. Use Move Up/Down/Top/Bottom to reorder safely.', ...
    'Units','normalized', ...
    'Position',[0.015 0.900 0.74 0.032], ...
    'BackgroundColor',[0.020 0.025 0.040], ...
    'ForegroundColor',[0.92 0.94 0.98], ...
    'FontSize',16, ...
    'FontWeight','bold', ...
    'HorizontalAlignment','left');

S.listPanel = uipanel(fig,'Title','Workflow order', ...
    'Units','normalized', ...
    'Position',[0.015 0.075 0.700 0.815], ...
    'BackgroundColor',[0.055 0.060 0.085], ...
    'ForegroundColor',[1.00 0.68 0.22], ...
    'HighlightColor',[0.32 0.20 0.08], ...
    'ShadowColor',[0.02 0.02 0.03], ...
    'FontSize',18, ...
    'FontWeight','bold');

S.paramPanel = uipanel(fig,'Title','Selected step settings', ...
    'Units','normalized', ...
    'Position',[0.735 0.405 0.250 0.485], ...
    'BackgroundColor',[0.060 0.065 0.095], ...
    'ForegroundColor',[1.00 0.68 0.22], ...
    'HighlightColor',[0.32 0.20 0.08], ...
    'ShadowColor',[0.02 0.02 0.03], ...
    'FontSize',18, ...
    'FontWeight','bold');

S.detailBox = uicontrol(fig,'Style','edit', ...
    'Units','normalized', ...
    'Position',[0.735 0.210 0.250 0.175], ...
    'Max',10, ...
    'Min',0, ...
    'Enable','inactive', ...
    'HorizontalAlignment','left', ...
    'BackgroundColor',[0.075 0.080 0.115], ...
    'ForegroundColor',[1.00 1.00 1.00], ...
    'FontSize',14, ...
    'FontWeight','bold');

S.statusText = uicontrol(fig,'Style','text', ...
    'String','Ready.', ...
    'Units','normalized', ...
    'Position',[0.015 0.018 0.70 0.035], ...
    'BackgroundColor',[0.020 0.025 0.040], ...
    'ForegroundColor',[0.80 0.95 0.85], ...
    'FontSize',13, ...
    'FontWeight','bold', ...
    'HorizontalAlignment','left');

btnW = 0.118; btnH = 0.045; gap = 0.014;
uicontrol(fig,'Style','pushbutton','String','Recommended', ...
    'Units','normalized','Position',[0.735 0.900 btnW 0.040], ...
    'FontSize',14,'FontWeight','bold','BackgroundColor',[0.32 0.19 0.07],'ForegroundColor',[1 1 1], ...
    'Callback',@onRecommended);
uicontrol(fig,'Style','pushbutton','String','Save / Load', ...
    'Units','normalized','Position',[0.735+btnW+gap 0.900 btnW 0.040], ...
    'FontSize',14,'FontWeight','bold','BackgroundColor',[0.20 0.22 0.30],'ForegroundColor',[1 1 1], ...
    'Callback',@onSaveLoad);
uicontrol(fig,'Style','pushbutton','String','Run Workflow', ...
    'Units','normalized','Position',[0.735 0.145 btnW btnH], ...
    'FontSize',15,'FontWeight','bold','BackgroundColor',[0.08 0.48 0.26],'ForegroundColor',[1 1 1], ...
    'Callback',@onRunWorkflow);
uicontrol(fig,'Style','pushbutton','String','Run Step', ...
    'Units','normalized','Position',[0.735+btnW+gap 0.145 btnW btnH], ...
    'FontSize',15,'FontWeight','bold','BackgroundColor',[0.10 0.25 0.55],'ForegroundColor',[1 1 1], ...
    'Callback',@onRunSelectedStep);
uicontrol(fig,'Style','pushbutton','String','Move Up', ...
    'Units','normalized','Position',[0.735 0.090 btnW btnH], ...
    'FontSize',14,'FontWeight','bold','BackgroundColor',[0.20 0.22 0.30],'ForegroundColor',[1 1 1], ...
    'Callback',@(src,evt) moveSelected(src,-1));
uicontrol(fig,'Style','pushbutton','String','Move Down', ...
    'Units','normalized','Position',[0.735+btnW+gap 0.090 btnW btnH], ...
    'FontSize',14,'FontWeight','bold','BackgroundColor',[0.20 0.22 0.30],'ForegroundColor',[1 1 1], ...
    'Callback',@(src,evt) moveSelected(src,1));
uicontrol(fig,'Style','pushbutton','String','Top', ...
    'Units','normalized','Position',[0.735 0.035 btnW btnH], ...
    'FontSize',14,'FontWeight','bold','BackgroundColor',[0.20 0.22 0.30],'ForegroundColor',[1 1 1], ...
    'Callback',@(src,evt) moveSelectedTo(src,'top'));
uicontrol(fig,'Style','pushbutton','String','Bottom', ...
    'Units','normalized','Position',[0.735+btnW+gap 0.035 btnW btnH], ...
    'FontSize',14,'FontWeight','bold','BackgroundColor',[0.20 0.22 0.30],'ForegroundColor',[1 1 1], ...
    'Callback',@(src,evt) moveSelectedTo(src,'bottom'));

guidata(fig,S);
buildRows(fig);
refreshRows(fig);
refreshSelectedPanel(fig);
end

function buildRows(fig)
S = guidata(fig);
n = numel(S.steps);
S.hRow = gobjects(n,1);
S.hArrow = gobjects(n,1);
S.hRun = gobjects(n,1);
S.hOrder = gobjects(n,1);
S.hName = gobjects(n,1);
S.hDesc = gobjects(n,1);

uicontrol(S.listPanel,'Style','text','String','SELECT', ...
    'Units','normalized','Position',[0.008 0.940 0.060 0.042], ...
    'BackgroundColor',[0.055 0.060 0.085],'ForegroundColor',[1.00 0.68 0.22], ...
    'FontSize',15,'FontWeight','bold');
uicontrol(S.listPanel,'Style','text','String','RUN', ...
    'Units','normalized','Position',[0.070 0.940 0.055 0.042], ...
    'BackgroundColor',[0.055 0.060 0.085],'ForegroundColor',[1.00 0.68 0.22], ...
    'FontSize',15,'FontWeight','bold');
uicontrol(S.listPanel,'Style','text','String','ORDER', ...
    'Units','normalized','Position',[0.130 0.940 0.070 0.042], ...
    'BackgroundColor',[0.055 0.060 0.085],'ForegroundColor',[1.00 0.68 0.22], ...
    'FontSize',15,'FontWeight','bold');
uicontrol(S.listPanel,'Style','text','String','STEP', ...
    'Units','normalized','Position',[0.210 0.940 0.205 0.042], ...
    'BackgroundColor',[0.055 0.060 0.085],'ForegroundColor',[1.00 0.68 0.22], ...
    'FontSize',15,'FontWeight','bold','HorizontalAlignment','left');
uicontrol(S.listPanel,'Style','text','String','RECOMMENDED PRESET / SETTINGS', ...
    'Units','normalized','Position',[0.420 0.940 0.565 0.042], ...
    'BackgroundColor',[0.055 0.060 0.085],'ForegroundColor',[1.00 0.68 0.22], ...
    'FontSize',15,'FontWeight','bold','HorizontalAlignment','left');

topY = 0.900; bottomY = 0.015; gapY = 0.005;
rowH = (topY-bottomY-(n-1)*gapY)/n;

for i = 1:n
    y = topY - (i-1)*(rowH+gapY) - rowH;
    S.hRow(i) = uipanel(S.listPanel,'Units','normalized','Position',[0.006 y 0.988 rowH], ...
        'BackgroundColor',[0.075 0.085 0.125],'BorderType','line', ...
        'HighlightColor',[0.12 0.12 0.16],'ShadowColor',[0.02 0.02 0.03], ...
        'ButtonDownFcn',@(src,evt) selectRow(src,evt,i));
    S.hArrow(i) = uicontrol(S.hRow(i),'Style','pushbutton','String','', ...
        'Units','normalized','Position',[0.004 0.11 0.052 0.78], ...
        'FontSize',14,'FontWeight','bold', ...
        'Callback',@(src,evt) selectRow(src,evt,i));
    S.hRun(i) = uicontrol(S.hRow(i),'Style','checkbox','Value',false, ...
        'Units','normalized','Position',[0.065 0.17 0.050 0.66], ...
        'FontSize',12,'Callback',@(src,evt) toggleRun(src,evt,i));
    S.hOrder(i) = uicontrol(S.hRow(i),'Style','edit','String',num2str(i), ...
        'Units','normalized','Position',[0.125 0.13 0.060 0.74], ...
        'FontSize',12,'FontWeight','bold', ...
        'Callback',@(src,evt) editOrder(src,evt,i));
    S.hName(i) = uicontrol(S.hRow(i),'Style','pushbutton','String','', ...
        'Units','normalized','Position',[0.198 0.07 0.215 0.86], ...
        'FontSize',15,'FontWeight','bold','HorizontalAlignment','left', ...
        'Callback',@(src,evt) selectRow(src,evt,i));
    S.hDesc(i) = uicontrol(S.hRow(i),'Style','pushbutton','String','', ...
        'Units','normalized','Position',[0.420 0.07 0.565 0.86], ...
        'FontSize',13,'FontWeight','bold','HorizontalAlignment','left', ...
        'Callback',@(src,evt) selectRow(src,evt,i));
end

guidata(fig,S);
end

function refreshRows(fig)
if isempty(fig) || ~ishghandle(fig), return; end
S = guidata(fig);
if isempty(S), return; end
for i = 1:numel(S.steps)
    st = S.steps(i);
    if i == S.selectedRow
        bg = [0.03 0.42 0.22]; fg = [1 1 1]; marker = '>';
    elseif mod(i,2)==0
        bg = [0.095 0.105 0.145]; fg = [0.94 0.96 1.00]; marker = '';
    else
        bg = [0.075 0.085 0.125]; fg = [0.94 0.96 1.00]; marker = '';
    end
    set(S.hRow(i),'BackgroundColor',bg,'HighlightColor',bg);
    set(S.hArrow(i),'String',marker,'BackgroundColor',bg,'ForegroundColor',[1.00 0.86 0.28]);
    set(S.hRun(i),'Value',logical(st.run),'BackgroundColor',bg,'ForegroundColor',fg);
    set(S.hOrder(i),'String',num2str(i),'BackgroundColor',[0.12 0.13 0.17],'ForegroundColor',[1 1 1]);
    set(S.hName(i),'String',st.name,'BackgroundColor',bg,'ForegroundColor',fg);
    set(S.hDesc(i),'String',st.desc,'BackgroundColor',bg,'ForegroundColor',fg);
end
drawnow;
end

function selectRow(src,~,idx)
fig = ancestor(src,'figure');
if isempty(fig) || ~ishghandle(fig), return; end
S = guidata(fig);
if isempty(S) || idx < 1 || idx > numel(S.steps), return; end
S.selectedRow = idx;
guidata(fig,S);
refreshRows(fig);
refreshSelectedPanel(fig);
setStatus(fig,['Selected row #' num2str(idx) '. Checkbox controls Run/Skip.'],[0.80 0.95 0.85]);
end

function toggleRun(src,~,idx)
fig = ancestor(src,'figure');
S = guidata(fig);
if idx < 1 || idx > numel(S.steps), return; end
S.steps(idx).run = logical(get(src,'Value'));
S.selectedRow = idx;
guidata(fig,S);
refreshRows(fig);
refreshSelectedPanel(fig);
end

function editOrder(src,~,idx)
fig = ancestor(src,'figure');
S = guidata(fig);
v = str2double(get(src,'String'));
if ~isfinite(v), refreshRows(fig); return; end
v = round(max(1,min(numel(S.steps),v)));
item = S.steps(idx);
S.steps(idx) = [];
S.steps = insertStepAt(S.steps,item,v);
S = renumberSteps(S);
S.selectedRow = v;
guidata(fig,S);
refreshRows(fig);
refreshSelectedPanel(fig);
end

function moveSelected(src,delta)
fig = ancestor(src,'figure');
S = guidata(fig);
r = S.selectedRow;
newR = r + delta;
if newR < 1 || newR > numel(S.steps), return; end
tmp = S.steps(r);
S.steps(r) = S.steps(newR);
S.steps(newR) = tmp;
S.selectedRow = newR;
S = renumberSteps(S);
guidata(fig,S);
refreshRows(fig);
refreshSelectedPanel(fig);
end

function moveSelectedTo(src,whereTo)
fig = ancestor(src,'figure');
S = guidata(fig);
r = S.selectedRow;
if r < 1 || r > numel(S.steps), return; end
item = S.steps(r);
S.steps(r) = [];
if strcmpi(whereTo,'top')
    S.steps = [item S.steps];
    S.selectedRow = 1;
else
    S.steps = [S.steps item];
    S.selectedRow = numel(S.steps);
end
S = renumberSteps(S);
guidata(fig,S);
refreshRows(fig);
refreshSelectedPanel(fig);
end

function refreshSelectedPanel(fig)
if isempty(fig) || ~ishghandle(fig), return; end
S = guidata(fig);
if isempty(S), return; end
old = get(S.paramPanel,'Children');
if ~isempty(old), delete(old); end
r = S.selectedRow;
if r < 1 || r > numel(S.steps), r = 1; end
st = S.steps(r);
uicontrol(S.paramPanel,'Style','text','String',['#' num2str(r) '  ' st.name], ...
    'Units','normalized','Position',[0.04 0.88 0.92 0.085], ...
    'BackgroundColor',[0.060 0.065 0.095],'ForegroundColor',[1.00 0.86 0.28], ...
    'FontSize',18,'FontWeight','bold','HorizontalAlignment','left');
uicontrol(S.paramPanel,'Style','checkbox','String','Run this step','Value',st.run, ...
    'Units','normalized','Position',[0.04 0.80 0.90 0.07], ...
    'BackgroundColor',[0.060 0.065 0.095],'ForegroundColor',[0.95 0.98 1.00], ...
    'FontSize',14,'FontWeight','bold', ...
    'Callback',@(src,evt) toggleRun(src,evt,r));

fields = relevantFields(st);
labels = fieldLabels();
y = 0.70; dy = 0.086;
if isempty(fields)
    uicontrol(S.paramPanel,'Style','text','String','No numeric preset for this step.', ...
        'Units','normalized','Position',[0.04 y 0.92 0.08], ...
        'BackgroundColor',[0.060 0.065 0.095],'ForegroundColor',[0.85 0.90 0.96], ...
        'FontSize',13,'FontWeight','bold','HorizontalAlignment','left');
else
    for k = 1:numel(fields)
        f = fields{k};
        if y < 0.05, break; end
        uicontrol(S.paramPanel,'Style','text','String',labels.(f), ...
            'Units','normalized','Position',[0.04 y 0.55 0.062], ...
            'BackgroundColor',[0.060 0.065 0.095],'ForegroundColor',[0.95 0.98 1.00], ...
            'FontSize',13,'FontWeight','bold','HorizontalAlignment','left');
        uicontrol(S.paramPanel,'Style','edit','String',num2str(st.(f)), ...
            'Units','normalized','Position',[0.61 y 0.33 0.067], ...
            'BackgroundColor',[0.12 0.13 0.17],'ForegroundColor',[1 1 1], ...
            'FontSize',13,'FontWeight','bold', ...
            'Callback',@(src,evt) editParam(src,evt,f));
        y = y - dy;
    end
end
set(S.detailBox,'String',makeDetailText(st));
end

function editParam(src,~,fieldName)
fig = ancestor(src,'figure');
S = guidata(fig);
r = S.selectedRow;
v = str2double(get(src,'String'));
if ~isfinite(v)
    set(src,'String',num2str(S.steps(r).(fieldName)));
    return;
end
S.steps(r).(fieldName) = sanitizeValue(fieldName,v);
guidata(fig,S);
refreshSelectedPanel(fig);
refreshRows(fig);
end

function onRunWorkflow(src,~)
fig = ancestor(src,'figure');
if isempty(fig) || ~ishghandle(fig), return; end
S = guidata(fig);
idx = find([S.steps.run]);
if isempty(idx)
    setStatus(fig,'No workflow steps are ticked.',[1.00 0.55 0.45]);
    return;
end

for ii = 1:numel(idx)
    if isempty(fig) || ~ishghandle(fig), return; end
    S = guidata(fig);
    r = idx(ii);
    if r > numel(S.steps), continue; end
    stepName = S.steps(r).name;

    setStudioReady(S.studioFig,false);
    figsBefore = findall(0,'Type','figure');

    if strcmpi(strtrim(stepName),'Full QC')
        setStatus(fig,['Running Full QC ' num2str(ii) '/' num2str(numel(idx)) '. Please let QC finish; workflow continues afterwards.'],[1.00 0.86 0.28]);
    else
        setStatus(fig,['Running ' num2str(ii) '/' num2str(numel(idx)) ': ' stepName],[0.80 0.95 0.85]);
    end
    drawnow;

    try
        [ok,errMsg] = triggerStudioStep(S.studioFig,stepName,S.steps(r));
    catch ME_run
        ok = false;
        errMsg = ME_run.message;
    end

    if ~ok
        setStudioReady(S.studioFig,true);
        if isempty(errMsg), errMsg = 'Unknown error.'; end
        msgLow = lower(errMsg);
        wasAbort = ~isempty(strfind(msgLow,'operation terminated by user')) || ...
                   ~isempty(strfind(msgLow,'interrupt')) || ...
                   ~isempty(strfind(msgLow,'terminated by user'));

        if strcmpi(strtrim(stepName),'Full QC') && wasAbort
            choice = questdlg(['Full QC was interrupted/cancelled.' char(10) char(10) ...
                'Continue with the next workflow step or stop?'], ...
                'Full QC interrupted','Continue','Stop','Continue');
        else
            choice = questdlg(['Step failed or was interrupted:' char(10) char(10) stepName char(10) char(10) ...
                errMsg char(10) char(10) 'Continue with next step or stop workflow?'], ...
                'Standardized Analysis step issue','Continue','Stop','Stop');
        end

        if isempty(choice) || strcmpi(choice,'Stop')
            setStatus(fig,['Workflow stopped at step: ' stepName],[1.00 0.55 0.45]);
            setStudioReady(S.studioFig,true);
            return;
        else
            setStatus(fig,['Skipped failed/interrupted step and continuing: ' stepName],[0.95 0.85 0.40]);
            drawnow;
            continue;
        end
    end

    waitForInteractiveStep(stepName,figsBefore);
    if isempty(fig) || ~ishghandle(fig), return; end
    setStatus(fig,['Finished step: ' stepName],[0.80 0.95 0.85]);
    drawnow;
end

if ~isempty(fig) && ishghandle(fig)
    S = guidata(fig);
    setStudioReady(S.studioFig,true);
    setStatus(fig,'Workflow finished.',[0.80 0.95 0.85]);
end
end
function onRunSelectedStep(src,~)
fig = ancestor(src,'figure');
if isempty(fig) || ~ishghandle(fig), return; end
S = guidata(fig);
r = S.selectedRow;
if r < 1 || r > numel(S.steps), return; end
stepName = S.steps(r).name;
setStudioReady(S.studioFig,false);
figsBefore = findall(0,'Type','figure');
setStatus(fig,['Running selected step: ' stepName],[0.80 0.95 0.85]);
drawnow;

try
    [ok,errMsg] = triggerStudioStep(S.studioFig,stepName,S.steps(r));
catch ME_run
    ok = false;
    errMsg = ME_run.message;
end

if ok
    waitForInteractiveStep(stepName,figsBefore);
    if ~isempty(fig) && ishghandle(fig)
        setStatus(fig,['Finished selected step: ' stepName],[0.80 0.95 0.85]);
    end
else
    if isempty(errMsg), errMsg = 'Unknown error.'; end
    if ~isempty(fig) && ishghandle(fig)
        warndlg(['Selected step failed/interrupted: ' stepName char(10) char(10) errMsg],'Standardized Analysis');
        setStatus(fig,['Selected step failed/interrupted: ' stepName],[1.00 0.55 0.45]);
    end
end

if ~isempty(fig) && ishghandle(fig)
    S = guidata(fig);
    setStudioReady(S.studioFig,true);
end
end
function onRecommended(src,~)
fig = ancestor(src,'figure');
S = guidata(fig);
S.steps = makeDefaultSteps();
S.selectedRow = 1;
guidata(fig,S);
refreshRows(fig);
refreshSelectedPanel(fig);
setStatus(fig,'Recommended workflow restored.',[0.80 0.95 0.85]);
end

function onSaveLoad(src,~)
fig = ancestor(src,'figure');
S = guidata(fig);
choice = questdlg('Preset action:','Save / Load workflow preset','Save','Load','Cancel','Save');
presetFile = fullfile(fileparts(which('standardizedAnalysis')),'standardizedAnalysis_preset.mat');
if strcmp(choice,'Save')
    steps = S.steps; %#ok<NASGU>
    save(presetFile,'steps');
    setStatus(fig,['Preset saved: ' presetFile],[0.80 0.95 0.85]);
elseif strcmp(choice,'Load')
    if exist(presetFile,'file')
        X = load(presetFile,'steps');
        if isfield(X,'steps')
            S.steps = normalizeLoadedSteps(X.steps);
            S = renumberSteps(S);
            S.selectedRow = 1;
            guidata(fig,S);
            refreshRows(fig);
            refreshSelectedPanel(fig);
        end
    end
end
end

function setStatus(fig,msg,colorVal)
try
    S = guidata(fig);
    set(S.statusText,'String',msg,'ForegroundColor',colorVal);
    drawnow;
catch
    disp(msg);
end
end

function steps = makeDefaultSteps()
steps = repmat(emptyStep(),1,18);
steps(1)  = makeStep(true,  1,'Motor',                 '4 slices, split MAT folder, residual despike 4, correction none',4,NaN,NaN,NaN,NaN,NaN,NaN,NaN);
steps(2)  = makeStep(true,  2,'Full QC',               'QC immediately after Motor, before further preprocessing',NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN);
steps(3)  = makeStep(false, 3,'Frame Rejection',       'optional frame rejection',NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN);
steps(4)  = makeStep(false, 4,'Scrubbing',             'optional scrubbing',NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN);
steps(5)  = makeStep(true,  5,'Filtering',             'filterType 1=band, low=0.001 Hz, high=0.20 Hz, order=4',NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN);
steps(6)  = makeStep(false, 6,'Temporal Smoothing',    'mode 1=smooth 2=subsample, win=60 s, nsub=50, method 1=mean 2=median',NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN);
steps(7)  = makeStep(false, 7,'PCA / ICA',             'method 1=PCA 2=ICA; component GUI still opens for selection',NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN);
steps(8)  = makeStep(false, 8,'Despike',               'optional additional despiking',NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN);
steps(9)  = makeStep(true,  9,'Imregdemons',           'median mode, nsub 25, step-motor per-slice',NaN,25,NaN,NaN,NaN,NaN,NaN,NaN);
steps(10) = makeStep(true, 10,'Full QC',               'QC after preprocessing / Imregdemons',NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN);
steps(11) = makeStep(true, 11,'Mask Editor',           'save underlay/mask, then close',NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN);
steps(12) = makeStep(true, 12,'Video GUI',             'baseline 30-35 s, signed PSC, caxis -100..100, alpha mod -20..20',NaN,NaN,30,35,-100,100,-20,20);
steps(13) = makeStep(false,13,'Time-Course Viewer',    'optional inspect ROI/time-course; workflow waits until closed',NaN,NaN,30,35,-100,100,NaN,NaN);
steps(14) = makeStep(true, 14,'SCM GUI',               'baseline 30-35 s, signed PSC, caxis -100..100, alpha mod -20..20',NaN,NaN,30,35,-100,100,-20,20);
steps(15) = makeStep(true, 15,'Segmentation',          'segmentation immediately after SCM GUI',NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN);
steps(16) = makeStep(true, 16,'Functional Connectivity','Functional Connectivity after Segmentation',NaN,NaN,NaN,NaN,-1,1,NaN,NaN);
steps(17) = makeStep(true, 17,'Registration to Atlas', 'atlas/coregistration workflow after segmentation/FC',NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN);
steps(18) = makeStep(false,18,'Group Analysis',        'optional group-level analysis',NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN);
for kk = 1:numel(steps)
    steps(kk).filterType = NaN; steps(kk).fcLow = NaN; steps(kk).fcHigh = NaN; steps(kk).filterOrder = NaN;
    steps(kk).tempMode = NaN; steps(kk).tempWinSec = NaN; steps(kk).tempNsub = NaN; steps(kk).tempMethod = NaN;
    steps(kk).pcaicaMethod = NaN; steps(kk).pcaNcomp = NaN; steps(kk).icaNcomp = NaN;
end
steps(5).filterType = 1; steps(5).fcLow = 0.001; steps(5).fcHigh = 0.20; steps(5).filterOrder = 4;
steps(6).tempMode = 1; steps(6).tempWinSec = 60; steps(6).tempNsub = 50; steps(6).tempMethod = 1;
steps(7).pcaicaMethod = 1; steps(7).pcaNcomp = 50; steps(7).icaNcomp = 30;
end

function st = emptyStep()
st = struct('run',false,'order',0,'name','','desc','', ...
    'slices',NaN,'nsub',NaN,'base1',NaN,'base2',NaN, ...
    'cmin',NaN,'cmax',NaN,'amin',NaN,'amax',NaN, ...
    'filterType',NaN,'fcLow',NaN,'fcHigh',NaN,'filterOrder',NaN, ...
    'tempMode',NaN,'tempWinSec',NaN,'tempNsub',NaN,'tempMethod',NaN, ...
    'pcaicaMethod',NaN,'pcaNcomp',NaN,'icaNcomp',NaN);
end

function st = makeStep(runFlag,orderVal,name,desc,slices,nsub,base1,base2,cmin,cmax,amin,amax)
st = emptyStep();
st.run = runFlag;
st.order = orderVal;
st.name = name;
st.desc = desc;
st.slices = slices;
st.nsub = nsub;
st.base1 = base1;
st.base2 = base2;
st.cmin = cmin;
st.cmax = cmax;
st.amin = amin;
st.amax = amax;
end

function S = renumberSteps(S)
for ii = 1:numel(S.steps)
    S.steps(ii).order = ii;
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

function fields = relevantFields(st)
fields = {};
switch lower(strtrim(st.name))
    case 'motor'
        fields = {'slices'};
    case 'imregdemons'
        fields = {'nsub'};
    case 'filtering'
        fields = {'filterType','fcLow','fcHigh','filterOrder'};
    case 'temporal smoothing'
        fields = {'tempMode','tempWinSec','tempNsub','tempMethod'};
    case 'pca / ica'
        fields = {'pcaicaMethod','pcaNcomp','icaNcomp'};
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
labels.nsub = 'Imreg n / nsub';
labels.base1 = 'Baseline start (s)';
labels.base2 = 'Baseline end (s)';
labels.cmin = 'Display min (%)';
labels.cmax = 'Display max (%)';
labels.amin = 'Alpha mod min (%)';
labels.amax = 'Alpha mod max (%)';
labels.filterType = 'Filter type 1=band 2=low 3=high';
labels.fcLow = 'Low cutoff Hz';
labels.fcHigh = 'High cutoff Hz';
labels.filterOrder = 'Filter order';
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
    case 'slices'
        v = round(max(1,min(12,v)));
    case 'nsub'
        v = round(max(1,min(1000,v)));
    case 'filterType'
        v = round(max(1,min(3,v)));
    case 'filterOrder'
        v = round(max(1,min(6,v)));
    case 'tempMode'
        v = round(max(1,min(2,v)));
    case 'tempMethod'
        v = round(max(1,min(2,v)));
    case 'pcaicaMethod'
        v = round(max(1,min(2,v)));
    case 'pcaNcomp'
        v = round(max(1,min(200,v)));
    case 'icaNcomp'
        v = round(max(1,min(100,v)));
    otherwise
        if ~isfinite(v), v = NaN; end
end
end

function txt = makeDetailText(st)
fields = relevantFields(st);
labels = fieldLabels();
txt = {['Step: ' st.name],'',['Recommended: ' st.desc],''};
if isempty(fields)
    txt{end+1} = 'Editable numbers: none for this step.';
else
    txt{end+1} = 'Editable numbers:';
    for ii = 1:numel(fields)
        f = fields{ii};
        txt{end+1} = ['  ' labels.(f) ' = ' num2str(st.(f))]; %#ok<AGROW>
    end
end
txt{end+1} = '';
txt{end+1} = 'Clicking rows only selects them. Checkbox controls Run/Skip.';
end

function steps = normalizeLoadedSteps(steps)
defaultSteps = makeDefaultSteps();
if ~isstruct(steps)
    steps = defaultSteps;
    return;
end
needFields = fieldnames(emptyStep());
for ii = 1:numel(steps)
    for ff = 1:numel(needFields)
        if ~isfield(steps,needFields{ff})
            steps(ii).(needFields{ff}) = defaultSteps(min(ii,numel(defaultSteps))).(needFields{ff});
        end
    end
end
end

function [ok,errMsg] = triggerStudioStep(studioFig,stepName,stepStruct)
ok = false;
errMsg = '';
try
    setStdStepAppdata(studioFig,stepStruct);
    candidates = stepCandidates(stepName);
    allBtns = findall(studioFig,'Type','uicontrol');
    for cc = 1:numel(candidates)
        target = cleanLabel(candidates{cc});
        for ii = 1:numel(allBtns)
            try
                style = get(allBtns(ii),'Style');
                label = get(allBtns(ii),'String');
            catch
                continue;
            end
            if ~ischar(label) || isempty(label), continue; end
            if ~(strcmpi(style,'pushbutton') || strcmpi(style,'togglebutton')), continue; end
            if strcmp(cleanLabel(label),target)
                cb = get(allBtns(ii),'Callback');
                try
                    if isa(cb,'function_handle')
                        feval(cb,allBtns(ii),[]);
                    elseif iscell(cb) && ~isempty(cb) && isa(cb{1},'function_handle')
                        feval(cb{1},allBtns(ii),[],cb{2:end});
                    elseif ischar(cb)
                        eval(cb);
                    else
                        errMsg = 'Button callback is empty or unsupported.';
                        return;
                    end
                    ok = true;
                    return;
                catch ME_step
                    ok = false;
                    errMsg = ME_step.message;
                    return;
                end
            end
        end
    end
    errMsg = ['Could not find Studio button for: ' stepName];
catch ME
    ok = false;
    errMsg = ME.message;
end
end
function setStdStepAppdata(studioFig,stepStruct)
try, setappdata(0,'deconf_std_workflow_step',stepStruct); catch, end
try
    if ishghandle(studioFig)
        setappdata(studioFig,'deconf_std_workflow_step',stepStruct);
    end
catch
end
try
    figs = findall(0,'Type','figure');
    for ii = 1:numel(figs)
        setappdata(figs(ii),'deconf_std_workflow_step',stepStruct);
    end
catch
end
end

function candidates = stepCandidates(stepName)
switch lower(strtrim(stepName))
    case 'motor'
        candidates = {'Motor','Step Motor','Step-Motor','Motor Correction'};
    case 'frame rejection'
        candidates = {'Frame Rejection','Frame Reject'};
    case 'scrubbing'
        candidates = {'Scrubbing','Scrub'};
    case 'filtering'
        candidates = {'Filtering','Filter','Temporal Filtering'};
    case 'temporal smoothing'
        candidates = {'Temporal Smoothing','Smoothing/Subsampling','Temporal Smoothing/Subsampling','Subsampling'};
    case 'pca / ica'
        candidates = {'PCA / ICA','PCA/ICA','ICA','PCA'};
    case 'despike'
        candidates = {'Despike','Despiking'};
    case 'imregdemons'
        candidates = {'Imregdemons','Imreg Demons','Imregdemons Preprocess'};
    case 'full qc'
        candidates = {'Full QC','QC','Advanced QC','Quality Control'};
    case 'mask editor'
        candidates = {'Mask Editor','Video & SCM Mask','Mask'};
    case 'video gui'
        candidates = {'Video GUI','Video & SCM Mask','Video','Open Video GUI'};
    case 'time-course viewer'
        candidates = {'Time-Course Viewer','Time Course Viewer','Time Course'};
    case 'scm gui'
        candidates = {'SCM GUI','SCM','Signal Change Map','Signal Change Maps'};
    case 'segmentation'
        candidates = {'Segmentation','Segment','Atlas Segmentation'};
    case 'functional connectivity'
        candidates = {'Functional Connectivity','FC','Connectivity'};
    case 'registration to atlas'
        candidates = {'Registration to Atlas','Register to Atlas','Atlas Registration','Coregistration','Coreg'};
    case 'group analysis'
        candidates = {'Group Analysis','GroupAnalysis'};
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
s = regexprep(s,'\s+',' ');
end

function setStudioReady(studioFig,isReady)
try
    if isempty(studioFig) || ~ishghandle(studioFig), return; end
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
    mustWait = any(strcmp(nm,{'video gui','scm gui','registration to atlas','time-course viewer','mask editor','segmentation','functional connectivity','pca / ica'}));
    if ~mustWait, return; end
    pause(0.5); drawnow;
    figsAfter = findall(0,'Type','figure');
    newFigs = setdiff(figsAfter,figsBefore);
    if isempty(newFigs)
        if strcmp(nm,'video gui'), newFigs = findobj(0,'Type','figure','-regexp','Name','Video'); end
        if strcmp(nm,'scm gui'), newFigs = findobj(0,'Type','figure','-regexp','Name','SCM|Signal'); end
        if strcmp(nm,'registration to atlas'), newFigs = findobj(0,'Type','figure','-regexp','Name','Registration|Atlas|Coreg'); end
        if strcmp(nm,'time-course viewer'), newFigs = findobj(0,'Type','figure','-regexp','Name','Time|Course|Viewer'); end
        if strcmp(nm,'mask editor'), newFigs = findobj(0,'Type','figure','-regexp','Name','Mask'); end
        if strcmp(nm,'segmentation'), newFigs = findobj(0,'Type','figure','-regexp','Name','Segmentation|Segment'); end
        if strcmp(nm,'functional connectivity'), newFigs = findobj(0,'Type','figure','-regexp','Name','Connectivity|Functional'); end
        if strcmp(nm,'pca / ica'), newFigs = findobj(0,'Type','figure','-regexp','Name','PCA|ICA'); end
    end
    if ~isempty(newFigs) && ishghandle(newFigs(1))
        waitfor(newFigs(1));
    end
catch
end
end
