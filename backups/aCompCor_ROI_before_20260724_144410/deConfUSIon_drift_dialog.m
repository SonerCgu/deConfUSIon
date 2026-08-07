function cfg = deConfUSIon_drift_dialog(defaults)
% =========================================================================
% deConfUSIon - Drift Compensation  (full-screen, master / detail)
% =========================================================================
% Left  : method list, ranked for pharmacological fUSI
% Right : explanation, caveat and ONLY the options that apply
% Bottom: baseline window, signal level, RUN / Cancel
%
% RETURNS cfg with .cancelled and every field the engine understands.
% MATLAB 2017b - 2023b, base MATLAB only.
% =========================================================================

if nargin < 1 || isempty(defaults), defaults = struct(); end

cfg = struct('cancelled',true);

FONT = 'Arial';

TR = 1;
if isfield(defaults,'TR') && ~isempty(defaults.TR) && isfinite(double(defaults.TR(end)))
    TR = double(defaults.TR(end));
end
nFrames = NaN;
if isfield(defaults,'nFrames') && ~isempty(defaults.nFrames)
    nFrames = double(defaults.nFrames);
end
runLen = NaN;
if isfinite(nFrames) && nFrames > 0, runLen = nFrames*TR; end

imgData = [];
if isfield(defaults,'I') && ~isempty(defaults.I), imgData = defaults.I; end

startRoot = pwd;
if isfield(defaults,'exportPath') && ~isempty(defaults.exportPath) && exist(defaults.exportPath,'dir')
    pp = fileparts(defaults.exportPath);
    if ~isempty(pp) && exist(pp,'dir'), startRoot = pp; else, startRoot = defaults.exportPath; end
end

% -------------------------------------------------------------- methods
mKey = {'glm','compcor','anchor','vehicle','spline','robust','baseline','poly','dct','reference'};
mName = { ...
 'GLM  -  modelled response', ...
 'COMPCOR  -  noise components', ...
 'ANCHOR  -  baseline + tail', ...
 'VEHICLE  -  subtract aCSF scan', ...
 'SPLINE  -  robust piecewise', ...
 'ROBUST  -  down-weighted fit', ...
 'BASELINE ONLY  -  extrapolated', ...
 'POLYNOMIAL  -  plain detrend', ...
 'DCT  -  high-pass', ...
 'REFERENCE  -  single ROI'};
mRank = [1 2 3 4 5 6 7 8 9 10];
mDesc = { ...
 ['Fits the drift basis AND an explicit model of the drug response in ONE design, then subtracts only the drift part. ' ...
  'The response is protected because it is modelled rather than avoided. Standard approach in pharmacological imaging.'], ...
 ['Takes the leading principal components of a region that should not respond and regresses them out. Separates drift ' ...
  'from response in SPACE rather than in time, so it fails differently from every time-based method - ideal as a cross-check.'], ...
 ['Fits the trend on the pre-injection window AND a late window, then interpolates between them. No extrapolation, ' ...
  'so it stays numerically stable over long runs.'], ...
 ['Subtracts a vehicle / aCSF scan of the SAME animal in fractional-change space. The only option that MEASURES drift, ' ...
  'injection artefact and handling instead of assuming a shape.'], ...
 ['Piecewise-linear drift with knots every N seconds, fitted with robust weights so response epochs are down-weighted. ' ...
  'Follows drift that is not polynomial at all (probe warm-up, coupling steps).'], ...
 ['Whole-run polynomial fit where frames that deviate strongly (the response) are automatically down-weighted by ' ...
  'iterative reweighting.'], ...
 ['Fits only on pre-injection frames and extrapolates across the run. Cannot absorb the response by construction.'], ...
 ['Classic whole-run polynomial detrend. Numerically the most stable option.'], ...
 ['Discrete-cosine high-pass, the classic SPM drift model. Removes everything slower than the cutoff period.'], ...
 ['Regresses out the mean time course of one non-responsive region.']};
mCav = { ...
 'Needs the injection time. If trend order and response length are too similar the split becomes ambiguous - the engine warns you.', ...
 'Quality depends entirely on the region. Pick it explicitly for real data.', ...
 'Assumes the response has largely returned by the tail window. If it has not, the tail eats part of it.', ...
 'Needs a matching vehicle scan on the same spatial grid, and it adds the vehicle noise.', ...
 'Too fine a knot spacing starts fitting the response. Keep knots long relative to the response.', ...
 'Works best when the response occupies a small fraction of the run.', ...
 'Slope error grows with the extrapolation distance. Unstable for long runs - prefer ANCHOR.', ...
 'Absorbs part of any sustained response. Keep the order at 1 and verify on a responsive ROI.', ...
 'Cannot tell a slow response from drift. Only safe when the response is clearly faster than the cutoff.', ...
 'A single time course cannot capture spatially uneven drift - CompCor is the better version of this.'};
mOpts = { ...
 {'order','inj','resp'}, {'ncomp','roi'}, {'order','tail'}, {'scans'}, {'knot'}, ...
 {'order'}, {'order'}, {'order'}, {'cutoff'}, {'roi'}};

sel = 1;
if isfield(defaults,'method') && ~isempty(defaults.method)
    ix = find(strcmpi(mKey, strtrim(defaults.method)),1);
    if ~isempty(ix), sel = ix; end
end

orderSel = 2; restoreSel = 1; fileList = {}; roiMask = []; % DRIFT_GLM_SAFE_DEFAULT: linear

% ---------------------------------------------------------------- theme
BG=[0.03 0.03 0.03]; PAN=[0.09 0.09 0.10]; CARD=[0.16 0.16 0.18];
FLD=[0.13 0.13 0.15]; WHT=[1 1 1]; DIM=[0.70 0.70 0.73];
ACC=[0.15 0.62 0.96]; GOLD=[1 0.76 0.22]; MINT=[0.20 0.85 0.60]; RED=[1 0.45 0.40];

f = figure('Name','Drift Compensation','NumberTitle','off','MenuBar','none', ...
    'ToolBar','none','Color',BG,'Units','normalized','WindowStyle','modal', ...
    'DefaultUicontrolFontName',FONT);
set(f,'Units','normalized','OuterPosition',[0 0 1 1]);

uicontrol(f,'Style','text','String','SIGNAL DRIFT COMPENSATION','Units','normalized', ...
    'Position',[0.02 0.945 0.5 0.04],'BackgroundColor',BG,'ForegroundColor',WHT, ...
    'FontName',FONT,'FontSize',24,'FontWeight','bold','HorizontalAlignment','left');
uicontrol(f,'Style','text','Units','normalized','Position',[0.021 0.915 0.62 0.028], ...
    'String','Pick a method on the left - the panel on the right explains it and shows only the settings it needs.', ...
    'BackgroundColor',BG,'ForegroundColor',DIM,'FontName',FONT,'FontSize',12, ...
    'HorizontalAlignment','left');

% ============================================================ LEFT: LIST
pL = uipanel(f,'Title','  METHOD  ','Units','normalized','Position',[0.02 0.20 0.26 0.70], ...
    'BackgroundColor',PAN,'ForegroundColor',ACC,'FontName',FONT,'FontSize',14, ...
    'FontWeight','bold','BorderType','line','HighlightColor',[0.30 0.30 0.34]);

hM = zeros(1,numel(mKey));
hgt = 0.088; gap = 0.007; y0 = 0.975 - hgt;
for i = 1:numel(mKey)
    if mRank(i) <= 3
        lbl = sprintf('%s\nRECOMMENDED  #%d', mName{i}, mRank(i));
    else
        lbl = mName{i};
    end
    hM(i) = uicontrol(pL,'Style','pushbutton','String',lbl,'Units','normalized', ...
        'Position',[0.04 y0-(i-1)*(hgt+gap) 0.92 hgt], ...
        'FontName',FONT,'FontSize',10.5,'Callback',@(a,b) setSel(i));
end

% ========================================================== RIGHT: DETAIL
pD = uipanel(f,'Title','  DETAILS  ','Units','normalized','Position',[0.30 0.20 0.68 0.70], ...
    'BackgroundColor',PAN,'ForegroundColor',ACC,'FontName',FONT,'FontSize',14, ...
    'FontWeight','bold','BorderType','line','HighlightColor',[0.30 0.30 0.34]);

hTitle = uicontrol(pD,'Style','text','Units','normalized','Position',[0.03 0.885 0.94 0.075], ...
    'BackgroundColor',PAN,'ForegroundColor',WHT,'FontName',FONT,'FontSize',18, ...
    'FontWeight','bold','HorizontalAlignment','left');
hDesc = uicontrol(pD,'Style','text','Units','normalized','Position',[0.03 0.71 0.94 0.17], ...
    'BackgroundColor',PAN,'ForegroundColor',WHT,'FontName',FONT,'FontSize',12.5, ...
    'HorizontalAlignment','left');
hCav = uicontrol(pD,'Style','text','Units','normalized','Position',[0.03 0.60 0.94 0.10], ...
    'BackgroundColor',PAN,'ForegroundColor',GOLD,'FontName',FONT,'FontSize',12, ...
    'FontWeight','bold','HorizontalAlignment','left');

G = struct();
G.order.lab  = mkLab('Drift trend order   (1 linear recommended)');
G.order.b    = [mkBtn('0  mean',@(a,b) setOrder(1)), mkBtn('1  linear',@(a,b) setOrder(2)), ...
                mkBtn('2  quadratic',@(a,b) setOrder(3)), mkBtn('3  cubic',@(a,b) setOrder(4))];
G.tail.lab   = mkLab('Tail window  [s]');
G.tail.e1    = mkEd(defStr(0.75*runLen));
G.tail.e2    = mkEd(defStr(runLen));
G.inj.lab    = mkLab('Injection onset  [s]');
G.inj.e1     = mkEd('60');
G.resp.lab   = mkLab('Expected response duration from injection onset  [s]');
G.resp.e1    = mkEd(defStr(min(max(TR,runLen-60), min(180,max(120,0.70*max(0,runLen-60)))))); % DRIFT_GLM_SAFE_RESPONSE_DEFAULT
G.ncomp.lab  = mkLab('CompCor components');
G.ncomp.e1   = mkEd('3'); % DRIFT_COMPCOR_SAFE_DEFAULT
G.knot.lab   = mkLab('Knot spacing  [s]');
G.knot.e1    = mkEd('120');
G.cutoff.lab = mkLab('Cutoff period  [s]');
G.cutoff.e1  = mkEd('240');
G.roi.lab    = mkLab('Reference region');
G.roi.b1     = uicontrol(pD,'Style','pushbutton','String','Pick region on mean image ...', ...
    'Units','normalized','BackgroundColor',ACC,'ForegroundColor',WHT,'FontName',FONT, ...
    'FontSize',11,'FontWeight','bold','Callback',@(a,b) pickROI());
G.roi.t      = uicontrol(pD,'Style','text','String','no region  -  falls back to low-signal voxels', ...
    'Units','normalized','BackgroundColor',PAN,'ForegroundColor',DIM,'FontName',FONT, ...
    'FontSize',11,'HorizontalAlignment','left');
G.scans.lab  = mkLab('Animal / analysed folder');
G.scans.e1   = mkEd(startRoot);
G.scans.b1   = uicontrol(pD,'Style','pushbutton','String','Browse','Units','normalized', ...
    'BackgroundColor',[0.24 0.24 0.28],'ForegroundColor',WHT,'FontName',FONT, ...
    'FontSize',11,'FontWeight','bold','Callback',@(a,b) onBrowse());
G.scans.b2   = uicontrol(pD,'Style','pushbutton','String','Rescan','Units','normalized', ...
    'BackgroundColor',[0.20 0.20 0.24],'ForegroundColor',WHT,'FontName',FONT, ...
    'FontSize',11,'FontWeight','bold','Callback',@(a,b) refreshLists());
G.scans.t1   = uicontrol(pD,'Style','text','String','TARGET = CURRENT ACTIVE DATASET','Units','normalized', ...
    'BackgroundColor',PAN,'ForegroundColor',GOLD,'FontName',FONT,'FontSize',11, ...
    'FontWeight','bold','HorizontalAlignment','left');
G.scans.t2   = uicontrol(pD,'Style','text','String','SCAN 2    VEHICLE / aCSF','Units','normalized', ...
    'BackgroundColor',PAN,'ForegroundColor',MINT,'FontName',FONT,'FontSize',11, ...
    'FontWeight','bold','HorizontalAlignment','left');
G.scans.l1   = uicontrol(pD,'Style','listbox','String',{''},'Units','normalized', ...
    'BackgroundColor',FLD,'ForegroundColor',WHT,'FontName',FONT,'FontSize',10);
G.scans.l2   = uicontrol(pD,'Style','listbox','String',{''},'Units','normalized', ...
    'BackgroundColor',FLD,'ForegroundColor',WHT,'FontName',FONT,'FontSize',10);

% =============================================================== BOTTOM
pB = uipanel(f,'Title','  ALWAYS APPLIED  ','Units','normalized','Position',[0.02 0.045 0.96 0.14], ...
    'BackgroundColor',PAN,'ForegroundColor',MINT,'FontName',FONT,'FontSize',13, ...
    'FontWeight','bold','BorderType','line','HighlightColor',[0.30 0.30 0.34]);

uicontrol(pB,'Style','text','String','Baseline (pre-injection)  [s]','Units','normalized', ...
    'Position',[0.015 0.52 0.155 0.30],'BackgroundColor',PAN,'ForegroundColor',WHT, ...
    'FontName',FONT,'FontSize',12,'FontWeight','bold','HorizontalAlignment','left');
hB1 = uicontrol(pB,'Style','edit','String','0','Units','normalized', ...
    'Position',[0.175 0.50 0.055 0.34],'BackgroundColor',FLD,'ForegroundColor',WHT, ...
    'FontName',FONT,'FontSize',12,'FontWeight','bold','Callback',@(a,b) paintAll());
hB2 = uicontrol(pB,'Style','edit','String','60','Units','normalized', ...
    'Position',[0.240 0.50 0.055 0.34],'BackgroundColor',FLD,'ForegroundColor',WHT, ...
    'FontName',FONT,'FontSize',12,'FontWeight','bold','Callback',@(a,b) paintAll());

uicontrol(pB,'Style','text','String','Signal level after correction','Units','normalized', ...
    'Position',[0.015 0.12 0.155 0.30],'BackgroundColor',PAN,'ForegroundColor',WHT, ...
    'FontName',FONT,'FontSize',12,'FontWeight','bold','HorizontalAlignment','left');
rL = {'Pre-injection level (PSC-safe)','Whole-run mean','Centred at zero'};
hRes = zeros(1,3);
for i = 1:3
    hRes(i) = uicontrol(pB,'Style','pushbutton','String',rL{i},'Units','normalized', ...
        'Position',[0.175+(i-1)*0.155 0.10 0.15 0.34],'FontName',FONT,'FontSize',11, ...
        'Callback',@(a,b) setRestore(i));
end

hHint = uicontrol(pB,'Style','text','Units','normalized','Position',[0.66 0.52 0.325 0.30], ...
    'BackgroundColor',PAN,'ForegroundColor',DIM,'FontName',FONT,'FontSize',11, ...
    'HorizontalAlignment','left','String',hintStr());
hWarn = uicontrol(pB,'Style','text','Units','normalized','Position',[0.66 0.08 0.325 0.38], ...
    'BackgroundColor',PAN,'ForegroundColor',MINT,'FontName',FONT,'FontSize',11, ...
    'FontWeight','bold','HorizontalAlignment','left','String','');

uicontrol(f,'Style','pushbutton','String','RUN','Units','normalized', ...
    'Position',[0.80 0.005 0.085 0.034],'BackgroundColor',[0.13 0.62 0.38], ...
    'ForegroundColor',WHT,'FontName',FONT,'FontSize',15,'FontWeight','bold','Callback',@(a,b) onOK());
uicontrol(f,'Style','pushbutton','String','Cancel','Units','normalized', ...
    'Position',[0.895 0.005 0.085 0.034],'BackgroundColor',[0.52 0.16 0.18], ...
    'ForegroundColor',WHT,'FontName',FONT,'FontSize',15,'FontWeight','bold','Callback',@(a,b) close(f));

refreshLists();
paintAll();
uiwait(f);

% =========================================================================
    function h = mkLab(txt)
        h = uicontrol(pD,'Style','text','String',txt,'Units','normalized', ...
            'BackgroundColor',PAN,'ForegroundColor',WHT,'FontName',FONT, ...
            'FontSize',12,'FontWeight','bold','HorizontalAlignment','left','Visible','off');
    end
    function h = mkBtn(txt, cb)
        h = uicontrol(pD,'Style','pushbutton','String',txt,'Units','normalized', ...
            'FontName',FONT,'FontSize',11,'Callback',cb,'Visible','off');
    end
    function h = mkEd(str)
        h = uicontrol(pD,'Style','edit','String',str,'Units','normalized', ...
            'BackgroundColor',FLD,'ForegroundColor',WHT,'FontName',FONT, ...
            'FontSize',12,'FontWeight','bold','Visible','off');
    end
    function s = defStr(v)
        if isfinite(v), s = sprintf('%.0f',v); else, s = ''; end
    end
    function s = hintStr()
        if isfinite(runLen)
            s = sprintf('Run: %d frames  |  TR %.3f s  |  %.1f s total', nFrames, TR, runLen);
        else
            s = 'Run length unknown.';
        end
    end

    function setSel(i),     sel = i;        paintAll(); end
    function setOrder(i),   orderSel = i;   paintAll(); end
    function setRestore(i), restoreSel = i; paintAll(); end

    function hideAll()
        fn = fieldnames(G);
        for i = 1:numel(fn)
            g = G.(fn{i}); sub = fieldnames(g);
            for j = 1:numel(sub)
                hh = g.(sub{j});
                for k = 1:numel(hh)
                    if ishghandle(hh(k)), set(hh(k),'Visible','off'); end
                end
            end
        end
    end

    function y = place(name, y)
        g = G.(name);
        set(g.lab,'Position',[0.03 y 0.30 0.045],'Visible','on');
        switch name
            case 'order'
                for i = 1:4
                    set(g.b(i),'Position',[0.34+(i-1)*0.145 y 0.135 0.048],'Visible','on');
                end
                y = y - 0.080;
            case 'tail'
                set(g.e1,'Position',[0.34 y 0.11 0.048],'Visible','on');
                set(g.e2,'Position',[0.47 y 0.11 0.048],'Visible','on');
                y = y - 0.080;
            case {'inj','resp','ncomp','knot','cutoff'}
                set(g.e1,'Position',[0.34 y 0.13 0.048],'Visible','on');
                y = y - 0.080;
            case 'roi'
                set(g.b1,'Position',[0.34 y 0.28 0.052],'Visible','on');
                set(g.t,'Position',[0.64 y 0.33 0.045],'Visible','on');
                y = y - 0.090;
            case 'scans'
                set(g.e1,'Position',[0.34 y 0.34 0.048],'Visible','on');
                set(g.b1,'Position',[0.70 y 0.12 0.050],'Visible','on');
                set(g.b2,'Position',[0.83 y 0.12 0.050],'Visible','on');
                y = y - 0.070;
                set(g.t1,'Position',[0.03 y 0.45 0.042],'Visible','on');
                set(g.t2,'Position',[0.51 y 0.45 0.042],'Visible','on');
                y = y - 0.300;
                set(g.l1,'Position',[0.03 y 0.45 0.290],'Visible','on');
                set(g.l2,'Position',[0.51 y 0.45 0.290],'Visible','on');
                y = y - 0.030;
        end
    end

    function paintAll()
        for i = 1:numel(mKey)
            if i == sel
                set(hM(i),'BackgroundColor',ACC,'ForegroundColor',WHT,'FontWeight','bold');
            elseif mRank(i) <= 3
                set(hM(i),'BackgroundColor',[0.19 0.26 0.31],'ForegroundColor',WHT,'FontWeight','bold');
            else
                set(hM(i),'BackgroundColor',CARD,'ForegroundColor',WHT,'FontWeight','normal');
            end
        end
        for i = 1:4
            if i == orderSel
                set(G.order.b(i),'BackgroundColor',GOLD,'ForegroundColor',[0.05 0.05 0.05],'FontWeight','bold');
            else
                set(G.order.b(i),'BackgroundColor',CARD,'ForegroundColor',WHT,'FontWeight','normal');
            end
        end
        for i = 1:3
            if i == restoreSel
                set(hRes(i),'BackgroundColor',MINT,'ForegroundColor',[0.05 0.05 0.05],'FontWeight','bold');
            else
                set(hRes(i),'BackgroundColor',CARD,'ForegroundColor',WHT,'FontWeight','normal');
            end
        end

        if mRank(sel) <= 3
            set(hTitle,'String',sprintf('%s        recommended #%d', mName{sel}, mRank(sel)));
        else
            set(hTitle,'String',mName{sel});
        end
        set(hDesc,'String',mDesc{sel});
        set(hCav,'String',['Caveat:   ' mCav{sel}]);

        hideAll();
        y = 0.50;
        op = mOpts{sel};
        for i = 1:numel(op)
            y = place(op{i}, y);
        end

        msg = ''; col = MINT;
        switch mKey{sel}
            case 'glm'
                if orderSel == 2
                    msg = ['Recommended default: linear drift. ' ...
                           'Use 180 s initially; compare 240/300 s only as sensitivity checks.'];
                    col = MINT;
                elseif orderSel > 2
                    msg = ['WARNING: quadratic/cubic drift can absorb a slow PACAP response. ' ...
                           'Use only as a sensitivity analysis.'];
                    col = RED;
                else
                    msg = 'Constant-only drift: no temporal slope will be removed.';
                    col = GOLD;
                end
            case 'baseline'
                b1 = str2double(get(hB1,'String')); b2 = str2double(get(hB2,'String'));
                if isfinite(runLen) && isfinite(b1) && isfinite(b2) && b2 > b1
                    ratio = (runLen-b2)/max(eps,(b2-b1));
                    if ratio > 5
                        msg = sprintf('WARNING: extrapolated over %.1fx the baseline span.', ratio); col = RED;
                    else
                        msg = sprintf('Extrapolation factor %.1fx.', ratio);
                    end
                end
            case 'dct'
                msg = 'Everything slower than the cutoff is removed.'; col = GOLD;
            case 'vehicle'
                if isempty(fileList)
                    msg = 'No pre-processed scans found in this folder.'; col = RED;
                end
        end
        if restoreSel == 3
            msg = [msg '  Level centred at zero - computePSC will not work.']; col = RED;
        end
        set(hWarn,'String',msg,'ForegroundColor',col);
        set(hHint,'String',hintStr());
    end

    function pickROI()
        if isempty(imgData)
            errordlg(['No image data was handed to the dialog, so the mean image cannot be shown. ' ...
                      'CompCor will fall back to low-signal voxels.'],'Region');
            return;
        end
        try
            mk2 = deConfUSIon_drift_roi_picker(imgData,'title','Select reference / noise region');
        catch ME
            errordlg(ME.message,'Region picker failed'); return;
        end
        if isempty(mk2), return; end
        roiMask = mk2;
        set(G.roi.t,'String',sprintf('region selected:  %d voxels', nnz(roiMask)),'ForegroundColor',MINT);
    end

    function onBrowse()
        d = uigetdir(get(G.scans.e1,'String'),'Select the animal / analysed folder');
        if ischar(d) && ~isempty(d) && exist(d,'dir')
            set(G.scans.e1,'String',d); refreshLists(); paintAll();
        end
    end

    function refreshLists()
        root = strtrim(get(G.scans.e1,'String'));
        fileList = {}; labels = {};
        if isempty(root) || exist(root,'dir') ~= 7
            set([G.scans.l1 G.scans.l2],'String',{'   (folder not found)'},'Value',1);
            return;
        end
        cand = {root};
        d = dir(root);
        for ii = 1:numel(d)
            if d(ii).isdir && ~strcmp(d(ii).name,'.') && ~strcmp(d(ii).name,'..')
                cand{end+1} = fullfile(root,d(ii).name); %#ok<AGROW>
            end
        end
        for ii = 1:numel(cand)
            pp2 = fullfile(cand{ii},'Preprocessing');
            if exist(pp2,'dir') ~= 7, continue; end
            mm = dir(fullfile(pp2,'*.mat'));
            for jj = 1:numel(mm)
                [~,sn] = fileparts(cand{ii});
                fileList{end+1} = fullfile(pp2,mm(jj).name); %#ok<AGROW>
                labels{end+1}   = sprintf('  %-24s   %s', sn, mm(jj).name); %#ok<AGROW>
            end
        end
        if isempty(fileList)
            set([G.scans.l1 G.scans.l2],'String',{'   (no Preprocessing/*.mat found)'},'Value',1);
        else
            set(G.scans.l1,'String',labels,'Value',1);
            set(G.scans.l2,'String',labels,'Value',min(2,numel(labels)));
        end
    end

    function onOK()
        rN = {'baseline','runmean','none'};
        k  = mKey{sel};
        need = mOpts{sel};

        b1 = str2double(get(hB1,'String'));
        b2 = str2double(get(hB2,'String'));
        if ~isfinite(b1) || ~isfinite(b2) || b2 <= b1 || b1 < 0
            errordlg('Baseline window invalid: need 0 <= start < end.','Drift Compensation'); return;
        end

        o = struct();
        o.cancelled   = false;
        o.method      = k;
        o.baselineSec = [b1 b2];
        o.polyOrder   = orderSel - 1;
        o.restoreMode = rN{restoreSel};
        o.rootFolder  = strtrim(get(G.scans.e1,'String'));
        o.vehicleFile = '';
        o.targetFile  = '';

        if any(strcmp(need,'tail'))
            t1 = str2double(get(G.tail.e1,'String'));
            t2 = str2double(get(G.tail.e2,'String'));
            if ~isfinite(t1) || ~isfinite(t2) || t2 <= t1
                errordlg('Tail window invalid.','Drift Compensation'); return;
            end
            if t1 <= b2
                errordlg('The tail window must start after the baseline ends.','Drift Compensation'); return;
            end
            o.tailSec = [t1 t2];
        end
        if any(strcmp(need,'inj'))
            v = str2double(get(G.inj.e1,'String'));
            if ~isfinite(v) || v < 0, errordlg('Injection time invalid.','Drift Compensation'); return; end
            o.injectionSec = v;
        end
        if any(strcmp(need,'resp'))
            v = str2double(get(G.resp.e1,'String'));
            if ~isfinite(v) || v <= 0, errordlg('Response length must be > 0.','Drift Compensation'); return; end
            o.responseSec = v;
        end
        if any(strcmp(need,'ncomp'))
            v = str2double(get(G.ncomp.e1,'String'));
            if ~isfinite(v) || v < 1, errordlg('Components must be >= 1.','Drift Compensation'); return; end
            o.nComp = round(v);
        end
        if any(strcmp(need,'knot'))
            v = str2double(get(G.knot.e1,'String'));
            if ~isfinite(v) || v <= 0, errordlg('Knot spacing must be > 0.','Drift Compensation'); return; end
            o.knotSec = v;
        end
        if any(strcmp(need,'cutoff'))
            v = str2double(get(G.cutoff.e1,'String'));
            if ~isfinite(v) || v <= 0, errordlg('Cutoff must be > 0.','Drift Compensation'); return; end
            o.cutoffSec = v;
        end
        if any(strcmp(need,'roi'))
            if ~isempty(roiMask)
                o.refMask = roiMask;
            elseif strcmp(k,'reference')
                errordlg('The reference method needs a region. Use "Pick region on mean image".', ...
                    'Drift Compensation'); return;
            end
        end
        if any(strcmp(need,'scans'))
            if isempty(fileList)
                errordlg('No pre-processed scans found in that folder.','Drift Compensation'); return;
            end
            i1 = get(G.scans.l1,'Value'); i2 = get(G.scans.l2,'Value');
            if i1 > numel(fileList) || i2 > numel(fileList)
                errordlg('Select one scan in each list.','Drift Compensation'); return;
            end
            if i1 == i2
                errordlg('Drug scan and vehicle scan must be different.','Drift Compensation'); return;
            end
            o.targetFile  = fileList{i1};
            o.vehicleFile = fileList{i2};
        end

        cfg = o;
        close(f);
    end
end
