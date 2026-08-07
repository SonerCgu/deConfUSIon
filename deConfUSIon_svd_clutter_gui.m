function [Iout, statsOut, applied] = deConfUSIon_svd_clutter_gui(I, TR, datasetName, opts)
% deConfUSIon_svd_clutter_gui  Dark SVD/clutter filtering QC window.
%
% Left: controls. Right: singular spectrum, frequency diagnostic, retained
% and removed power, first kept component, and threshold-sweep QC.
%
% The exact Demene et al. method is intended for complex IQ cine data before
% Power-Doppler integration. Real Power-Doppler/fUSI input is allowed but is
% labelled experimental because global haemodynamic responses can be removed.

if nargin < 2 || isempty(TR), TR = 1; end
if nargin < 3 || isempty(datasetName), datasetName = 'active dataset'; end
if nargin < 4 || isempty(opts), opts = struct(); end
if ~isfield(opts,'exportPath'), opts.exportPath = ''; end
if ~isfield(opts,'mask'), opts.mask = []; end
if ~isfield(opts,'maskLabel'), opts.maskLabel = 'loaded mask'; end
if ~isfield(opts,'defaultPercent'), opts.defaultPercent = 20; end

Iout = [];
statsOut = struct();
applied = false;
model = [];
sweep = struct();
preview = struct();
recommendedPercent = max(1,min(40,double(opts.defaultPercent)));
modelSignature = '';
lastQcFile = '';

sz = size(I);
T = sz(end);
if ndims(I) == 3, Z = 1; else, Z = sz(3); end
TR = double(TR(1));
if ~isfinite(TR) || TR <= 0, TR = 1; end

C = struct();
C.bg = [0.055 0.060 0.070];
C.panel = [0.085 0.090 0.105];
C.panel2 = [0.105 0.110 0.125];
C.ax = [0.035 0.040 0.050];
C.fg = [0.94 0.95 0.97];
C.muted = [0.68 0.72 0.78];
C.blue = [0.20 0.62 0.95];
C.green = [0.25 0.78 0.52];
C.orange = [0.95 0.62 0.20];
C.red = [0.90 0.30 0.30];

scr = get(0,'ScreenSize');
fw = min(1580,max(1180,round(0.92*scr(3))));
fh = min(920,max(760,round(0.88*scr(4))));
fx = max(20,round((scr(3)-fw)/2));
fy = max(40,round((scr(4)-fh)/2));

fig = figure('Name','deConfUSIon | SVD / Clutter Filtering', ...
    'NumberTitle','off','MenuBar','none','ToolBar','none', ...
    'Color',C.bg,'Units','pixels','Position',[fx fy fw fh], ...
    'Resize','on','CloseRequestFcn',@onClose);

left = uipanel(fig,'Units','normalized','Position',[0.015 0.025 0.255 0.95], ...
    'BackgroundColor',C.panel,'ForegroundColor',C.fg,'BorderType','line', ...
    'HighlightColor',[0.35 0.38 0.44],'Title','SVD SETTINGS', ...
    'FontWeight','bold','FontSize',12);
right = uipanel(fig,'Units','normalized','Position',[0.285 0.025 0.70 0.95], ...
    'BackgroundColor',C.panel,'ForegroundColor',C.fg,'BorderType','line', ...
    'HighlightColor',[0.35 0.38 0.44],'Title','QUALITY CONTROL', ...
    'FontWeight','bold','FontSize',12);

uicontrol(left,'Style','text','Units','normalized','Position',[0.05 0.942 0.90 0.038], ...
    'String','SPATIOTEMPORAL SVD','BackgroundColor',C.panel,'ForegroundColor',C.fg, ...
    'FontSize',15,'FontWeight','bold','HorizontalAlignment','left');
uicontrol(left,'Style','text','Units','normalized','Position',[0.05 0.895 0.90 0.045], ...
    'String',shortText(datasetName,42),'BackgroundColor',C.panel,'ForegroundColor',C.muted, ...
    'FontSize',9.5,'HorizontalAlignment','left','TooltipString',datasetName);

if isreal(I)
    warningText = ['REAL fUSI/Power-Doppler input detected. SVD here is experimental: ' ...
        'inspect the REMOVED map and stop before vessels or expected global responses are removed.'];
else
    warningText = ['Complex input detected. Paper-style no-centering is appropriate for IQ cine data ' ...
        'before Power-Doppler integration.'];
end
uicontrol(left,'Style','text','Units','normalized','Position',[0.05 0.802 0.90 0.088], ...
    'String',warningText,'BackgroundColor',C.panel2,'ForegroundColor', ...
    ternary(isreal(I),C.orange,C.green),'FontSize',9.2,'FontWeight','bold', ...
    'HorizontalAlignment','left');

mkLabel(left,'SVD scope',0.755,C);
if Z > 1
    scopeStrings = {'Each slice independently (recommended)','All slices jointly'};
    scopeValue = 1;
else
    scopeStrings = {'All voxels jointly'};
    scopeValue = 1;
end
hScope = uicontrol(left,'Style','popupmenu','Units','normalized','Position',[0.05 0.712 0.90 0.043], ...
    'String',scopeStrings,'Value',scopeValue,'BackgroundColor',C.panel2,'ForegroundColor',C.fg, ...
    'FontSize',10,'Callback',@markRecompute);

mkLabel(left,'Centering / interpretation',0.665,C);
centerStrings = {'None - exact IQ/paper style','Subtract voxel mean, then restore'};
centerValue = 1 + double(isreal(I));
hCenter = uicontrol(left,'Style','popupmenu','Units','normalized','Position',[0.05 0.622 0.90 0.043], ...
    'String',centerStrings,'Value',centerValue,'BackgroundColor',C.panel2,'ForegroundColor',C.fg, ...
    'FontSize',10,'Callback',@markRecompute);

mkLabel(left,'QC slice',0.575,C);
sliceStrings = arrayfun(@(z)sprintf('Slice %d',z),1:Z,'UniformOutput',false);
hSlice = uicontrol(left,'Style','popupmenu','Units','normalized','Position',[0.05 0.532 0.90 0.043], ...
    'String',sliceStrings,'Value',max(1,round((Z+1)/2)),'BackgroundColor',C.panel2, ...
    'ForegroundColor',C.fg,'FontSize',10,'Callback',@onSliceChanged);
if Z == 1, set(hSlice,'Enable','off'); end

maskAvailable = ~isempty(opts.mask);
hMask = uicontrol(left,'Style','checkbox','Units','normalized','Position',[0.05 0.482 0.90 0.040], ...
    'String',['Estimate basis inside ' opts.maskLabel],'Value',double(maskAvailable), ...
    'Enable',ternary(maskAvailable,'on','off'),'BackgroundColor',C.panel, ...
    'ForegroundColor',C.fg,'FontSize',9.5,'Callback',@markRecompute);

mkLabel(left,'Reject leading components (%)',0.440,C);
hPct = uicontrol(left,'Style','edit','Units','normalized','Position',[0.70 0.432 0.25 0.043], ...
    'String',num2str(opts.defaultPercent,'%.1f'),'BackgroundColor',C.panel2,'ForegroundColor',C.fg, ...
    'FontSize',10.5,'Callback',@onPercentEdit);
hSlider = uicontrol(left,'Style','slider','Units','normalized','Position',[0.05 0.398 0.90 0.025], ...
    'Min',0,'Max',40,'Value',max(0,min(40,opts.defaultPercent)), ...
    'SliderStep',[1/40 5/40],'BackgroundColor',C.panel2,'Callback',@onSlider);

mkLabel(left,'Exact count (synchronised)',0.355,C);
hCount = uicontrol(left,'Style','edit','Units','normalized','Position',[0.70 0.347 0.25 0.043], ...
    'String',num2str(round(T*opts.defaultPercent/100)),'BackgroundColor',C.panel2, ...
    'ForegroundColor',C.fg,'FontSize',10.5,'Callback',@onCountEdit);

hStatus = uicontrol(left,'Style','text','Units','normalized','Position',[0.05 0.287 0.90 0.055], ...
    'String','Preparing SVD...','BackgroundColor',C.panel2,'ForegroundColor',C.muted, ...
    'FontSize',9.2,'FontWeight','bold','HorizontalAlignment','left');

mkButton(left,'COMPUTE / RECOMPUTE SVD',[0.05 0.230 0.90 0.047],C.blue,@onCompute,C);
mkButton(left,'USE QC RECOMMENDATION',[0.05 0.174 0.90 0.047],C.green,@onUseRecommendation,C);
mkButton(left,'PLAY RETAINED',[0.05 0.118 0.43 0.047],[0.24 0.48 0.72],@(src,evt)onPlay(false),C);
mkButton(left,'PLAY REMOVED',[0.52 0.118 0.43 0.047],[0.65 0.38 0.20],@(src,evt)onPlay(true),C);
mkButton(left,'EXPORT QC',[0.05 0.062 0.90 0.047],[0.45 0.35 0.70],@onExport,C);
mkButton(left,'APPLY & ADD DATASET',[0.05 0.008 0.62 0.045],C.green,@onApply,C);
mkButton(left,'CLOSE',[0.70 0.008 0.25 0.045],C.red,@onClose,C);

hRec = uicontrol(right,'Style','text','Units','normalized','Position',[0.025 0.895 0.95 0.085], ...
    'String','Computing recommendation...','BackgroundColor',C.panel2,'ForegroundColor',C.fg, ...
    'FontSize',10.2,'FontWeight','bold','HorizontalAlignment','left');

ax1 = makeAxis(right,[0.045 0.535 0.285 0.315],C);
ax2 = makeAxis(right,[0.360 0.535 0.285 0.315],C);
ax3 = makeAxis(right,[0.675 0.535 0.285 0.315],C);
ax4 = makeAxis(right,[0.045 0.105 0.285 0.315],C);
ax5 = makeAxis(right,[0.360 0.105 0.285 0.315],C);
ax6 = makeAxis(right,[0.675 0.105 0.285 0.315],C);

set(fig,'WindowButtonMotionFcn',[]);
drawnow;
onCompute([],[]);
uiwait(fig);
if ishghandle(fig), delete(fig); end

% =====================================================================
    function onCompute(~,~)
        setStatus('Computing temporal covariance and SVD... This can take a while.',C.orange);
        setControlsEnabled(false);
        drawnow;
        try
            eopts = collectOptions(true);
            [~,~,model] = deConfUSIon_svd_clutter(I,TR,eopts);
            modelSignature = currentSignature();
            updateSelectedSliceQC();
            setStatus(sprintf('SVD ready. %d frames; %s.',T,scopeLabel(eopts.scope)),C.green);
        catch ME
            model = [];
            setStatus(['SVD failed: ' ME.message],C.red);
            errordlg(ME.message,'SVD / Clutter Filtering');
        end
        setControlsEnabled(true);
    end

% =====================================================================
    function updateSelectedSliceQC()
        if isempty(model), return; end
        z = get(hSlice,'Value');
        pct = getPercent();
        B = getSelectedBlock(z);
        S = getSlice(I,z);
        centerMode = getCenterMode();
        preview = computePreview(S,B,pct,centerMode);
        sweep = computeSweep(S,B,centerMode);
        recommendedPercent = sweep.recommendedPercent;
        drawQC(B,pct,z);
        updateRecommendation(B,pct,z);
    end

% =====================================================================
    function drawQC(B,pct,z)
        k = percentToK(pct,T);
        sv = B.singularValues(:);
        db = 20*log10(sv/max(eps,sv(1)) + eps);

        resetAxis(ax1,C); hold(ax1,'on');
        plot(ax1,1:numel(db),db,'LineWidth',1.35,'Color',C.blue);
        yl = [-max(80,min(140,abs(min(db(isfinite(db))))+5)) 2];
        if ~all(isfinite(yl)), yl = [-100 2]; end
        plot(ax1,[max(1,k) max(1,k)],yl,'--','LineWidth',1.25,'Color',C.orange);
        plot(ax1,[B.elbowK B.elbowK],yl,':','LineWidth',1.2,'Color',C.green);
        ylim(ax1,yl); xlim(ax1,[1 numel(db)]); grid(ax1,'on');
        title(ax1,'Singular-value spectrum','Color',C.fg,'FontWeight','bold');
        xlabel(ax1,'Component'); ylabel(ax1,'Relative magnitude (dB)');
        darkLegend(ax1,{'Spectrum','Current cutoff','Elbow'},'southwest',C);

        resetAxis(ax2,C); hold(ax2,'on');
        fpc = 100*B.frequency.centralFractionNyquist(:);
        plot(ax2,1:numel(fpc),fpc,'LineWidth',1.2,'Color',C.blue);
        plot(ax2,[max(1,k) max(1,k)],[0 100],'--','LineWidth',1.2,'Color',C.orange);
        plot(ax2,[1 numel(fpc)],[5 5],':','LineWidth',1.0,'Color',C.green);
        finiteF = fpc(isfinite(fpc));
        if isempty(finiteF), fMax = 20; else, fMax = min(100,max(20,ceil(max(finiteF)/10)*10)); end
        xlim(ax2,[1 numel(fpc)]); ylim(ax2,[0 fMax]);
        grid(ax2,'on');
        title(ax2,'Temporal frequency diagnostic','Color',C.fg,'FontWeight','bold');
        xlabel(ax2,'Component'); ylabel(ax2,'Central frequency (% Nyquist)');

        showMap(ax3,preview.retainedDb,sprintf('Retained power | slice %d',z),C);
        showMap(ax4,preview.removedDb,'Removed power: should be broad tissue',C);
        showMap(ax5,preview.firstKeptDb,sprintf('First kept component #%d',min(T,k+1)),C);

        resetAxis(ax6,C); hold(ax6,'on');
        plot(ax6,sweep.percent,sweep.coherenceNormalized,'-o','LineWidth',1.3, ...
            'MarkerSize',5,'Color',C.orange,'MarkerFaceColor',C.orange);
        plot(ax6,sweep.percent,sweep.retainedEnergy,'-s','LineWidth',1.3, ...
            'MarkerSize',5,'Color',C.blue,'MarkerFaceColor',C.blue);
        plot(ax6,[recommendedPercent recommendedPercent],[0 1.05],':','LineWidth',1.4,'Color',C.green);
        xlim(ax6,[0 32]); ylim(ax6,[0 1.05]); grid(ax6,'on');
        title(ax6,'Threshold sweep (heuristic)','Color',C.fg,'FontWeight','bold');
        xlabel(ax6,'Rejected components (%)'); ylabel(ax6,'Normalised metric');
        darkLegend(ax6,{'Residual global coherence','Retained dynamic energy','QC start'},'southwest',C);
    end

% =====================================================================
    function updateRecommendation(B,pct,z)
        k = percentToK(pct,T);
        if isreal(I)
            inputLine = 'Input: REAL fUSI/Power-Doppler -> experimental SVD; protect expected global biology.';
        else
            inputLine = 'Input: COMPLEX IQ -> compatible with paper-style SVD before Power-Doppler integration.';
        end
        txt = sprintf(['%s\n' ...
            'QC slice %d | current %.1f%% (%d/%d) | elbow %.1f%% | QC heuristic %.1f%% | paper rat-IQ start ~20%%.\n' ...
            'Decision rule: choose the LOWEST cutoff where broad coherent tissue disappears; stop if vessels enter the removed map.'], ...
            inputLine,z,pct,k,T,B.elbowPercent,recommendedPercent);
        set(hRec,'String',txt,'ForegroundColor',ternary(isreal(I),C.orange,C.fg));
    end

% =====================================================================
    function onUseRecommendation(~,~)
        if isempty(model)
            setStatus('Compute SVD first.',C.orange); return;
        end
        setPercent(recommendedPercent);
        updateSelectedSliceQC();
        setStatus(sprintf('Applied QC starting recommendation: %.1f%%. Inspect maps before final apply.',recommendedPercent),C.green);
    end

% =====================================================================
    function onApply(~,~)
        if isempty(model) || ~strcmp(modelSignature,currentSignature())
            setStatus('Settings changed. Recompute SVD before applying.',C.orange);
            return;
        end
        pct = getPercent();
        answer = 'Yes';
        if isreal(I)
            answer = questdlg(sprintf(['This is real fUSI/Power-Doppler data. Removing coherent SVD modes may remove true global responses.\n\n' ...
                'Apply %.1f%% (%d/%d components) after inspecting the removed map?'], ...
                pct,percentToK(pct,T),T),'Experimental SVD confirmation','Yes','No','No');
        end
        if ~strcmp(answer,'Yes'), return; end

        setStatus('Applying SVD to the full dataset...',C.orange);
        setControlsEnabled(false); drawnow;
        try
            eopts = collectOptions(false);
            eopts.model = model;
            [Iout,statsOut] = deConfUSIon_svd_clutter(I,TR,eopts);
            statsOut.qcSweep = sweep;
            statsOut.qcPreview = previewSummary(preview);
            statsOut.qcSlice = get(hSlice,'Value');
            statsOut.qcRecommendationPercent = recommendedPercent;
            statsOut.userSelectedPercent = pct;
            lastQcFile = exportQcInternal(statsOut);
            if ~isempty(lastQcFile), statsOut.qcFile = lastQcFile; end
            applied = true;
            setStatus('SVD applied successfully.',C.green);
            uiresume(fig);
            delete(fig);
        catch ME
            setStatus(['Apply failed: ' ME.message],C.red);
            errordlg(ME.message,'SVD Apply Failed');
            setControlsEnabled(true);
        end
    end

% =====================================================================
    function onExport(~,~)
        if isempty(model), setStatus('Compute SVD first.',C.orange); return; end
        s = struct();
        s.method = 'SVD QC only';
        s.cutoffPercent = getPercent();
        s.nRejected = percentToK(s.cutoffPercent,T);
        s.qcSlice = get(hSlice,'Value');
        s.qcSweep = sweep;
        s.qcPreview = previewSummary(preview);
        s.scope = getScope();
        s.centerMode = getCenterMode();
        s.isComplexInput = ~isreal(I);
        try
            lastQcFile = exportQcInternal(s);
            if isempty(lastQcFile)
                setStatus('QC export cancelled or no export path available.',C.orange);
            else
                setStatus(['QC exported: ' lastQcFile],C.green);
            end
        catch ME
            setStatus(['QC export failed: ' ME.message],C.red);
        end
    end

% =====================================================================
    function qcFile = exportQcInternal(summary)
        qcFile = '';
        outRoot = opts.exportPath;
        if isempty(outRoot) || exist(outRoot,'dir') ~= 7
            outRoot = uigetdir(pwd,'Choose folder for SVD QC');
            if isequal(outRoot,0), return; end
        end
        outDir = fullfile(outRoot,'SVD_QC');
        if exist(outDir,'dir') ~= 7, mkdir(outDir); end
        ts = datestr(now,'yyyymmdd_HHMMSS');
        stem = ['SVD_QC_' safeName(datasetName) '_' ts];
        qcFile = fullfile(outDir,[stem '.png']);
        oldInvert = get(fig,'InvertHardcopy');
        set(fig,'InvertHardcopy','off');
        drawnow;
        print(fig,qcFile,'-dpng','-r180');
        set(fig,'InvertHardcopy',oldInvert);
        matFile = fullfile(outDir,[stem '.mat']);
        save(matFile,'summary');
    end

% =====================================================================
    function onPlay(showRemoved)
        if isempty(model), setStatus('Compute SVD first.',C.orange); return; end
        try
            z = get(hSlice,'Value');
            S = getSlice(I,z);
            B = getSelectedBlock(z);
            pct = getPercent();
            M = buildSmallMovie(S,B,pct,getCenterMode(),showRemoved);
            titleText = ternary(showRemoved,'SVD removed signal','SVD retained signal');
            playMovie(M,titleText,C);
        catch ME
            errordlg(ME.message,'SVD Movie Preview');
        end
    end

% =====================================================================
    function onSliceChanged(~,~)
        if ~isempty(model) && strcmp(modelSignature,currentSignature())
            setStatus('Updating QC slice...',C.muted); drawnow;
            updateSelectedSliceQC();
            setStatus('QC slice updated.',C.green);
        end
    end

% =====================================================================
    function markRecompute(~,~)
        setStatus('Settings changed: click COMPUTE / RECOMPUTE SVD.',C.orange);
    end

% =====================================================================
    function onSlider(~,~)
        setPercent(get(hSlider,'Value'));
        if ~isempty(model) && strcmp(modelSignature,currentSignature())
            updateSelectedSliceQC();
        end
    end

    function onPercentEdit(~,~)
        p = str2double(get(hPct,'String'));
        if ~isfinite(p), p = get(hSlider,'Value'); end
        setPercent(p);
        if ~isempty(model) && strcmp(modelSignature,currentSignature()), updateSelectedSliceQC(); end
    end

    function onCountEdit(~,~)
        k = str2double(get(hCount,'String'));
        if ~isfinite(k), k = percentToK(getPercent(),T); end
        k = max(0,min(T-1,round(k)));
        setPercent(100*k/T);
        if ~isempty(model) && strcmp(modelSignature,currentSignature()), updateSelectedSliceQC(); end
    end

% =====================================================================
    function p = getPercent()
        p = str2double(get(hPct,'String'));
        if ~isfinite(p), p = get(hSlider,'Value'); end
        p = max(0,min(40,p));
    end

    function setPercent(p)
        p = max(0,min(40,double(p)));
        set(hPct,'String',num2str(p,'%.1f'));
        set(hSlider,'Value',p);
        set(hCount,'String',num2str(percentToK(p,T)));
    end

% =====================================================================
    function eopts = collectOptions(computeOnly)
        eopts = struct();
        eopts.cutoffPercent = getPercent();
        eopts.scope = getScope();
        eopts.centerMode = getCenterMode();
        eopts.chunkVoxels = 20000;
        eopts.computeOnly = computeOnly;
        eopts.verbose = false;
        if get(hMask,'Value') && ~isempty(opts.mask), eopts.mask = opts.mask; else, eopts.mask = []; end
    end

    function s = getScope()
        if Z > 1 && get(hScope,'Value') == 1, s = 'per-slice'; else, s = 'joint'; end
    end

    function s = getCenterMode()
        if get(hCenter,'Value') == 1, s = 'none'; else, s = 'voxelmean'; end
    end

    function sig = currentSignature()
        sig = sprintf('%s|%s|mask%d',getScope(),getCenterMode(),get(hMask,'Value'));
    end

    function B = getSelectedBlock(z)
        if strcmp(model.scope,'per-slice'), B = model.blocks{z}; else, B = model.blocks{1}; end
    end

% =====================================================================
    function setControlsEnabled(tf)
        state = ternary(tf,'on','off');
        set([hScope hCenter hSlice hMask hPct hSlider hCount],'Enable',state);
        if Z == 1, set(hSlice,'Enable','off'); end
        if ~maskAvailable, set(hMask,'Enable','off'); end
        drawnow;
    end

    function setStatus(txt,col)
        if ishghandle(hStatus), set(hStatus,'String',txt,'ForegroundColor',col); drawnow; end
    end

% =====================================================================
    function onClose(~,~)
        applied = false;
        Iout = [];
        statsOut = struct();
        if ishghandle(fig)
            try, uiresume(fig); catch, end
            delete(fig);
        end
    end
end

% =========================================================================
function P = computePreview(S,B,pct,centerMode)
[Y,X,T] = size(S);
Xmat = reshape(S,[],T);
k = percentToK(pct,T);
Vrej = B.V(:,1:k);
kp = min(T,k+1);
Vkeep = B.V(:,kp);
retPow = zeros(Y*X,1);
remPow = zeros(Y*X,1);
firstKept = zeros(Y*X,1);
chunk = 15000;
for a = 1:chunk:size(Xmat,1)
    rr = a:min(size(Xmat,1),a+chunk-1);
    Xi = double(Xmat(rr,:)); Xi(~isfinite(Xi)) = 0;
    if strcmp(centerMode,'voxelmean'), Xc = Xi-mean(Xi,2); else, Xc = Xi; end
    if k > 0, R = (Xc*Vrej)*Vrej'; else, R = zeros(size(Xc)); end
    F = Xc-R;
    retPow(rr) = mean(abs(F).^2,2);
    remPow(rr) = mean(abs(R).^2,2);
    firstKept(rr) = abs(Xc*Vkeep);
end
P = struct();
P.retainedDb = powerDb(reshape(retPow,Y,X));
P.removedDb = powerDb(reshape(remPow,Y,X));
P.firstKeptDb = powerDb(reshape(firstKept.^2,Y,X));
P.retainedMedian = median(retPow(isfinite(retPow)));
P.removedMedian = median(remPow(isfinite(remPow)));
P.cutoffPercent = pct;
P.nRejected = k;
end

% =========================================================================
function S = computeSweep(sliceData,B,centerMode)
[Y,X,T] = size(sliceData); %#ok<ASGLU>
Xmat = reshape(sliceData,[],T);
energy = sum(abs(double(Xmat)).^2,2);
valid = find(isfinite(energy) & energy > eps);
if isempty(valid), valid = (1:size(Xmat,1))'; end
maxN = 2500;
if numel(valid) > maxN
    valid = valid(round(linspace(1,numel(valid),maxN)));
end
Xs = double(Xmat(valid,:)); Xs(~isfinite(Xs)) = 0;
if strcmp(centerMode,'voxelmean'), Xs = Xs-mean(Xs,2); end
E0 = sum(abs(Xs(:)).^2)+eps;
c0 = globalCoherence(Xs);
perc = [0 5 10 15 20 25 30];
coh = zeros(size(perc)); ret = zeros(size(perc)); score = zeros(size(perc));
for i = 1:numel(perc)
    k = percentToK(perc(i),T);
    F = Xs;
    if k > 0, V = B.V(:,1:k); F = F-(F*V)*V'; end
    coh(i) = globalCoherence(F);
    ret(i) = sum(abs(F(:)).^2)/E0;
end
cohNorm = coh/max(eps,c0);
suppression = max(0,1-cohNorm);
score = suppression .* sqrt(max(0,ret));
score(1) = 0;
[best,~] = max(score);
if best <= 0.01 || ~isfinite(best)
    rec = max(5,min(30,5*round(B.elbowPercent/5)));
else
    idx = find(score >= 0.97*best & perc >= 5,1,'first');
    rec = perc(idx);
end
S = struct('percent',perc,'coherence',coh, ...
    'coherenceNormalized',min(1.25,cohNorm), ...
    'retainedEnergy',min(1.25,ret),'score',score, ...
    'recommendedPercent',rec,'baselineCoherence',c0);
end

% =========================================================================
function c = globalCoherence(X)
if isempty(X), c = 0; return; end
g = mean(X,1);
g = g-mean(g);
Xc = X-mean(X,2);
num = abs(Xc*conj(g(:)));
den = sqrt(sum(abs(Xc).^2,2))*sqrt(sum(abs(g).^2)+eps);
r = num./max(eps,den);
r = r(isfinite(r));
if isempty(r), c = 0; else, c = median(r); end
end

% =========================================================================
function M = buildSmallMovie(S,B,pct,centerMode,showRemoved)
[Y,X,T] = size(S);
maxY = 128; maxX = 128; maxT = 500;
yi = unique(round(linspace(1,Y,min(Y,maxY))));
xi = unique(round(linspace(1,X,min(X,maxX))));
St = S(yi,xi,:);
Xm = reshape(St,[],T);
Xm = double(Xm); Xm(~isfinite(Xm)) = 0;
if strcmp(centerMode,'voxelmean'), mu = mean(Xm,2); Xc = Xm-mu; else, mu = zeros(size(Xm,1),1); Xc = Xm; end
k = percentToK(pct,T);
if k > 0, V = B.V(:,1:k); R = (Xc*V)*V'; else, R = zeros(size(Xc)); end
if showRemoved
    Ymat = R;
else
    Ymat = Xc-R;
    if strcmp(centerMode,'voxelmean'), Ymat = Ymat+mu; end
end
ti = unique(round(linspace(1,T,min(T,maxT))));
Ymat = Ymat(:,ti);
M = reshape(abs(Ymat),numel(yi),numel(xi),numel(ti));
lo = localPercentile(M(:),1); hi = localPercentile(M(:),99.5);
M = (M-lo)/max(eps,hi-lo); M = min(max(M,0),1);
end

% =========================================================================
function playMovie(M,titleText,C)
if exist('implay','file') == 2
    implay(M);
    return;
end
f = figure('Name',titleText,'NumberTitle','off','Color',C.bg,'MenuBar','none','ToolBar','none');
a = axes('Parent',f,'Position',[0.06 0.08 0.90 0.86],'Color',C.ax);
h = imagesc(a,M(:,:,1),[0 1]); axis(a,'image'); axis(a,'off'); colormap(f,'gray');
title(a,titleText,'Color',C.fg);
for t = 1:size(M,3)
    if ~ishghandle(f), break; end
    set(h,'CData',M(:,:,t)); title(a,sprintf('%s | frame %d/%d',titleText,t,size(M,3)),'Color',C.fg);
    drawnow;
end
end

% =========================================================================
function showMap(ax,A,t,C)
resetAxis(ax,C);
imagesc(ax,A,[-40 0]); axis(ax,'image'); axis(ax,'off');
title(ax,t,'Color',C.fg,'FontWeight','bold','FontSize',10);
end

function resetAxis(ax,C)
cla(ax); set(ax,'Color',C.ax,'XColor',C.muted,'YColor',C.muted, ...
    'GridColor',[0.35 0.38 0.42],'FontSize',8.5,'Box','on');
end

function ax = makeAxis(parent,pos,C)
ax = axes('Parent',parent,'Units','normalized','Position',pos,'Color',C.ax, ...
    'XColor',C.muted,'YColor',C.muted,'FontSize',8.5,'Box','on');
end

function h = darkLegend(ax,labels,location,C)
try
    h = legend(ax,labels,'Location',location);
    set(h,'TextColor',C.fg,'Color',C.ax,'EdgeColor',[0.3 0.3 0.3]);
catch
    h = legend(ax,labels,'Location',location);
end
end

function mkLabel(parent,str,y,C)
uicontrol(parent,'Style','text','Units','normalized','Position',[0.05 y 0.62 0.032], ...
    'String',str,'BackgroundColor',C.panel,'ForegroundColor',C.fg, ...
    'HorizontalAlignment','left','FontSize',9.5,'FontWeight','bold');
end

function h = mkButton(parent,str,pos,bg,cb,C)
h = uicontrol(parent,'Style','pushbutton','Units','normalized','Position',pos, ...
    'String',str,'BackgroundColor',bg,'ForegroundColor',C.fg, ...
    'FontSize',9.5,'FontWeight','bold','Callback',cb);
end

function S = getSlice(I,z)
if ndims(I) == 3
    S = I;
else
    S = squeeze(I(:,:,z,:));
end
if ndims(S) == 2, S = reshape(S,size(S,1),size(S,2),1); end
end

function k = percentToK(p,T)
k = max(0,min(T-1,round(double(p)*T/100)));
end

function A = powerDb(P)
P = double(P); P(~isfinite(P)) = 0;
mx = max(P(:));
if mx <= 0, A = -40*ones(size(P)); else, A = 10*log10(P/mx+eps); end
A = max(-40,min(0,A));
end

function s = previewSummary(P)
s = P;
if isfield(s,'retainedDb'), s = rmfield(s,'retainedDb'); end
if isfield(s,'removedDb'), s = rmfield(s,'removedDb'); end
if isfield(s,'firstKeptDb'), s = rmfield(s,'firstKeptDb'); end
end

function p = localPercentile(v,q)
v = sort(double(v(isfinite(v))));
if isempty(v), p = 0; return; end
pos = 1+(numel(v)-1)*q/100;
i0 = floor(pos); i1 = ceil(pos);
i0 = max(1,min(numel(v),i0)); i1 = max(1,min(numel(v),i1));
if i0 == i1, p = v(i0); else, p = v(i0)+(pos-i0)*(v(i1)-v(i0)); end
end

function out = scopeLabel(s)
if strcmp(s,'per-slice'), out = 'per-slice basis'; else, out = 'joint basis'; end
end

function s = shortText(s,n)
s = char(s);
if numel(s) > n, s = [s(1:round(n/2)-2) '...' s(end-round(n/2)+2:end)]; end
end

function s = safeName(s)
s = regexprep(char(s),'[^A-Za-z0-9_-]+','_');
if isempty(s), s = 'dataset'; end
if numel(s) > 70, s = s(1:70); end
end

function v = ternary(tf,a,b)
if tf, v = a; else, v = b; end
end
