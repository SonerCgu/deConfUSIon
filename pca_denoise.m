function [newData, stats] = pca_denoise(dataIn, saveRoot, tag, opts)
% PCA_DENOISE V12 — integrated all-slice / slice-specific recompute GUI
% The first PCA/ICA popup only chooses method. This GUI handles slice scope.

if nargin < 2 || isempty(saveRoot), saveRoot = pwd; end
if nargin < 3 || isempty(tag), tag = datestr(now,'yyyymmdd_HHMMSS'); end
if nargin < 4, opts = struct(); end

if ~isfield(opts,'nCompMax'),         opts.nCompMax = 50; end
if ~isfield(opts,'maxDisplayPoints'), opts.maxDisplayPoints = 2000; end
if ~isfield(opts,'chunkT'),           opts.chunkT = 250; end
if ~isfield(opts,'centerMode'),       opts.centerMode = 'voxel'; end
if ~isfield(opts,'verbose'),          opts.verbose = true; end
if ~isfield(opts,'onApply'),          opts.onApply = []; end
if ~isfield(opts,'onCancel'),         opts.onCancel = []; end
if ~isfield(opts,'logFcn'),           opts.logFcn = []; end

isStruct = isstruct(dataIn);
if isStruct
    if ~isfield(dataIn,'I'), error('pca_denoise: input struct must contain .I'); end
    I = dataIn.I;
    TR = 1; if isfield(dataIn,'TR'), TR = double(dataIn.TR); end
    newData = dataIn;
else
    I = dataIn; TR = 1; newData = struct('I',I);
end
if ~isscalar(TR) || ~isfinite(TR) || TR <= 0, TR = 1; end

sz = size(I);
inputWas3D = false;
if ndims(I) == 3
    Y0 = sz(1); X0 = sz(2); T0 = sz(3); Z0 = 1;
    I4orig = reshape(I, Y0, X0, 1, T0);
    inputWas3D = true;
elseif ndims(I) == 4
    Y0 = sz(1); X0 = sz(2); Z0 = sz(3); T0 = sz(4);
    I4orig = I;
else
    error('Data must be 3D [Y X T] or 4D [Y X Z T].');
end

[selected, applyFlag, st] = pca_v12_gui(I4orig, TR, opts, tag);

stats = emptyStats(tag);
stats.nComponents = 0;
stats.explainedPerComponent = [];
stats.selectedComponents = [];
stats.percentExplainedRemoved = 0;
stats.applied = false;
stats.method = 'PCA (cancelled)';
stats.qcGridFiles = {};
stats.sliceScope = st.scopeInfo;

if ~applyFlag
    if ~isempty(opts.onCancel) && isa(opts.onCancel,'function_handle'), try, opts.onCancel(); catch, end, end
    newData.I = I;
    return;
end

K = st.K;
selected = unique(selected(:)');
selected = selected(selected >= 1 & selected <= K);

if ~isempty(opts.onApply) && isa(opts.onApply,'function_handle')
    try, opts.onApply(selected); catch, end
end

stats.nComponents = K;
stats.explainedPerComponent = st.expl(:)';
stats.selectedComponents = selected;
stats.percentExplainedRemoved = 100 * sum(st.expl(selected));
stats.applied = true;
stats.method = 'PCA denoise (V12 slice-aware)';
stats.sliceScope = st.scopeInfo;

if isempty(selected)
    newData.I = I;
    return;
end

Xclean = st.Xc;
Wsel = double(st.W(:,selected));
Ssel = diag(double(st.sing(selected)));
chunkT = max(50, round(opts.chunkT));

for t0 = 1:chunkT:st.T
    t1 = min(st.T, t0 + chunkT - 1);
    Ut = double(st.U(t0:t1, selected));
    recon = Wsel * (Ssel * Ut');
    Xclean(:,t0:t1) = Xclean(:,t0:t1) - single(recon);
end

switch lower(opts.centerMode)
    case 'global'
        Xout = Xclean + single(st.mu);
    otherwise
        Xout = bsxfun(@plus, Xclean, st.muVec);
end

IworkOut4 = reshape(Xout, [st.Y st.X st.Z st.T]);
if st.scopeInfo.sliceSpecific && Z0 > 1
    Iout4 = I4orig;
    zUse = st.scopeInfo.zIndex;
    Iout4(:,:,zUse,:) = reshape(IworkOut4(:,:,1,:), [Y0 X0 1 T0]);
else
    Iout4 = IworkOut4;
end

if inputWas3D
    newData.I = reshape(Iout4, [Y0 X0 T0]);
else
    newData.I = Iout4;
end
newData.preprocessing = 'PCA denoise (V12 slice-aware)';
newData.pcaicaSliceScope = st.scopeInfo;

stats.qcFile = '';
stats.qcGlobalMeanFile = '';
stats.qcMeanImageFile = '';

    function st = computePCA(scopeInfo)
        if scopeInfo.sliceSpecific && Z0 > 1
            zUse = max(1,min(Z0,round(scopeInfo.zIndex)));
            I4 = reshape(I4orig(:,:,zUse,:), [Y0 X0 1 T0]);
            Y = Y0; X = X0; Z = 1; T = T0;
        else
            I4 = I4orig;
            Y = Y0; X = X0; Z = Z0; T = T0;
        end
        V = Y*X*Z;
        Xvt = reshape(single(I4), [V T]);
        switch lower(opts.centerMode)
            case 'global'
                mu = mean(Xvt(:));
                Xc = Xvt - single(mu);
                muVec = [];
            otherwise
                muVec = mean(Xvt,2);
                Xc = bsxfun(@minus, Xvt, muVec);
                mu = [];
        end
        K = min([opts.nCompMax, T-1, 200]);
        if K < 1, error('Not enough time points for PCA.'); end
        Xtv = double(Xc');
        useFallback = false;
        try
            [U,S,W] = svds(Xtv,K);
        catch
            useFallback = true;
        end
        if useFallback
            Ct = Xtv * Xtv';
            Ct = (Ct + Ct') * 0.5;
            [U,L] = eigs(Ct,K,'largestreal');
            s = sqrt(max(diag(L),0));
            S = diag(s);
            W = Xtv' * U;
            for ii = 1:K
                if s(ii) > 0, W(:,ii) = W(:,ii) ./ s(ii); end
            end
        end
        sing = diag(S);
        [sing,ord] = sort(sing(:),'descend');
        U = U(:,ord); W = W(:,ord);
        expl = sing.^2;
        expl = expl ./ max(eps,sum(expl));
        st = struct('U',U,'W',W,'sing',sing,'expl',expl,'Xc',Xc,'mu',mu,'muVec',muVec, ...
            'Y',Y,'X',X,'Z',Z,'T',T,'K',K,'scopeInfo',scopeInfo);
    end

    function [selected, applyFlag, st] = pca_v12_gui(I4orig_unused, TR, opts_unused, tag_unused) %#ok<INUSD>
        bgFig=[0.06 0.06 0.07]; bgAx=[0.09 0.09 0.10]; fg=[0.90 0.90 0.92]; fgDim=[0.70 0.70 0.74]; selRed=[1.00 0.25 0.25]; lineCol=[0.35 0.80 1];
        selected=[]; applyFlag=false;
        scopeInfo = struct('mode','all','zIndex',1,'nSlices',Z0,'sliceSpecific',false);
        st = computePCA(scopeInfo);
        K = st.K; T = st.T;
        maxPts = opts.maxDisplayPoints;
        idx = getIdx(T,maxPts);
        tmin = ((0:T-1)*TR)/60; tmin = tmin(idx); tmax = max(tmin);
        perPage=25; nPages=max(1,ceil(K/perPage)); page=1;
        fig=figure('Name','PCA Components — slice-aware V12', 'Color',bgFig,'MenuBar','none','ToolBar','none','NumberTitle','off', 'Position',[60 40 1800 980]);
        try, deConfUSIon_force_fullscreen_fig(fig); catch, end
        gridX=0.03; gridY=0.08; gridW=0.66; gridH=0.86; rightX=0.71; rightY=0.08; rightW=0.27; rightH=0.90;
        hdr=uicontrol('Parent',fig,'Style','text','Units','normalized','Position',[gridX 0.965 gridW 0.03],'String','','BackgroundColor',bgFig,'ForegroundColor',fg,'FontSize',13,'FontWeight','bold','HorizontalAlignment','left');
        rightPanel=uipanel('Parent',fig,'Units','normalized','Position',[rightX rightY rightW rightH],'BackgroundColor',[0.08 0.08 0.09],'ForegroundColor',fg,'Title','Selection + Slice Scope','FontWeight','bold','FontSize',13);
        uicontrol('Parent',rightPanel,'Style','text','Units','normalized','Position',[0.06 0.915 0.88 0.055],'String','PCA INPUT SCOPE', 'BackgroundColor',get(rightPanel,'BackgroundColor'),'ForegroundColor',[0.85 0.95 1.00],'FontWeight','bold','FontSize',14);
        scopePopup=uicontrol('Parent',rightPanel,'Style','popupmenu','Units','normalized','Position',[0.06 0.855 0.88 0.055],'String',{'All slices together','Selected slice only'},'Value',1,'BackgroundColor',[0.16 0.16 0.18],'ForegroundColor',fg,'FontWeight','bold','FontSize',12,'Callback',@scopeChanged);
        scopeText=uicontrol('Parent',rightPanel,'Style','text','Units','normalized','Position',[0.06 0.805 0.88 0.050],'String',sprintf('All slices 1-%d',Z0),'BackgroundColor',get(rightPanel,'BackgroundColor'),'ForegroundColor',[1.00 0.95 0.55],'FontWeight','bold','FontSize',13);
        stepSmall=1/max(1,Z0-1);
        scopeSlider=uicontrol('Parent',rightPanel,'Style','slider','Units','normalized','Position',[0.06 0.755 0.88 0.045],'Min',1,'Max',max(1,Z0),'Value',1,'SliderStep',[stepSmall min(1,stepSmall*2)],'Enable','off','Callback',@scopeChanged);
        if Z0 <= 1, set(scopePopup,'Enable','off'); set(scopeSlider,'Enable','off'); set(scopeText,'String','2D / single-slice data'); end
        axPrev=axes('Parent',rightPanel,'Units','normalized','Position',[0.10 0.535 0.84 0.165],'Color',bgAx,'XColor',fg,'YColor',fg); title(axPrev,'PC timecourse preview','Color',fg);
        txtInfo=uicontrol('Parent',rightPanel,'Style','text','Units','normalized','Position',[0.08 0.470 0.84 0.045],'String','Selected: 0 PCs', 'BackgroundColor',get(rightPanel,'BackgroundColor'),'ForegroundColor',[0.85 0.95 1.00],'FontWeight','bold','FontSize',13);
        lb=uicontrol('Parent',rightPanel,'Style','listbox','Units','normalized','Position',[0.08 0.225 0.84 0.225],'String',{'<none>'},'BackgroundColor',[0.16 0.16 0.18],'ForegroundColor',fg,'FontName','Courier New','FontSize',13);
        uicontrol('Parent',rightPanel,'Style','pushbutton','Units','normalized','Position',[0.08 0.135 0.40 0.070],'String','Apply & Close','FontWeight','bold','FontSize',11,'BackgroundColor',[0.20 0.45 0.25],'ForegroundColor','w','Callback',@applyAndClose);
        uicontrol('Parent',rightPanel,'Style','pushbutton','Units','normalized','Position',[0.52 0.135 0.40 0.070],'String','Cancel','FontWeight','bold','FontSize',11,'BackgroundColor',[0.65 0.20 0.20],'ForegroundColor','w','Callback',@cancelAndClose);
        btnPrev=uicontrol('Parent',rightPanel,'Style','pushbutton','Units','normalized','Position',[0.08 0.040 0.25 0.070],'String','< Prev','FontWeight','bold','FontSize',11,'BackgroundColor',[0.12 0.34 0.95],'ForegroundColor','w','Callback',@prevPage);
        btnNext=uicontrol('Parent',rightPanel,'Style','pushbutton','Units','normalized','Position',[0.38 0.040 0.25 0.070],'String','Next >','FontWeight','bold','FontSize',11,'BackgroundColor',[0.12 0.34 0.95],'ForegroundColor','w','Callback',@nextPage);
        uicontrol('Parent',rightPanel,'Style','pushbutton','Units','normalized','Position',[0.68 0.040 0.24 0.070],'String','HELP','FontWeight','bold','FontSize',11,'BackgroundColor',[0.12 0.34 0.95],'ForegroundColor','w','Callback',@showHelp);
        nRow=5; nCol=5; axGrid=gobjects(25,1); lnGrid=gobjects(25,1); pcLabel=gobjects(25,1); compIdx=nan(25,1); pad=0.008; cellW=gridW/nCol; cellH=gridH/nRow;
        for ii=1:25
            r=floor((ii-1)/nCol); c=mod((ii-1),nCol);
            axGrid(ii)=axes('Parent',fig,'Units','normalized','Position',[gridX+c*cellW+pad gridY+(nRow-1-r)*cellH+pad cellW-2*pad cellH-2*pad],'Color',bgAx);
            set(axGrid(ii),'Box','on','LineWidth',1,'XColor',fgDim*0.35,'YColor',fgDim*0.35,'YTick',[]); hold(axGrid(ii),'on');
            lnGrid(ii)=plot(axGrid(ii),tmin,zeros(size(tmin)),'Color',lineCol,'LineWidth',1);
            pcLabel(ii)=text(axGrid(ii),0.02,0.92,'','Units','normalized','Color',fg,'FontSize',10,'FontWeight','bold'); hold(axGrid(ii),'off');
            set(axGrid(ii),'ButtonDownFcn',@(h,~)onCellClick(h)); set(lnGrid(ii),'ButtonDownFcn',@(h,~)onCellClick(h));
        end
        set(fig,'WindowKeyPressFcn',@onKey,'WindowScrollWheelFcn',@onScrollWheel,'CloseRequestFcn',@cancelAndClose);
        renderPage(); previewComponent(1); uiwait(fig);
        function scopeChanged(~,~)
            if Z0 > 1 && get(scopePopup,'Value') == 2
                z=round(get(scopeSlider,'Value')); z=max(1,min(Z0,z)); set(scopeSlider,'Value',z,'Enable','on');
                scopeInfo=struct('mode','slice','zIndex',z,'nSlices',Z0,'sliceSpecific',true);
                set(scopeText,'String',sprintf('Selected slice %d of %d — recomputing PCA...',z,Z0));
            else
                set(scopeSlider,'Enable','off'); scopeInfo=struct('mode','all','zIndex',1,'nSlices',Z0,'sliceSpecific',false);
                set(scopeText,'String',sprintf('All slices 1-%d — recomputing PCA...',Z0));
            end
            drawnow; st=computePCA(scopeInfo); K=st.K; T=st.T; idx=getIdx(T,maxPts); tmin=((0:T-1)*TR)/60; tmin=tmin(idx); tmax=max(tmin); selected=[]; page=1; nPages=max(1,ceil(K/perPage)); renderPage(); previewComponent(1);
            if scopeInfo.sliceSpecific, set(scopeText,'String',sprintf('Selected slice %d of %d',scopeInfo.zIndex,Z0)); else, set(scopeText,'String',sprintf('All slices 1-%d',Z0)); end
        end
        function renderPage()
            firstPC=(page-1)*perPage+1; lastPC=min(K,page*perPage); set(hdr,'String',sprintf('PCs %d-%d of %d | %s',firstPC,lastPC,K,scopeLabel()));
            set(btnPrev,'Enable',onoff(page>1)); set(btnNext,'Enable',onoff(page<nPages));
            for jj=1:25
                k=(page-1)*perPage+jj; compIdx(jj)=k;
                if k<=K
                    tc=st.U(:,k); tc=tc(idx); set(lnGrid(jj),'XData',tmin,'YData',tc,'Visible','on'); set(axGrid(jj),'Visible','on','XLim',[0 max(tmin)]);
                    set(pcLabel(jj),'String',sprintf('PC%d %.2f%%',k,100*st.expl(k)));
                    if any(selected==k), set(axGrid(jj),'XColor',selRed,'YColor',selRed,'LineWidth',2.2); set(pcLabel(jj),'Color',selRed); else, set(axGrid(jj),'XColor',fgDim*0.35,'YColor',fgDim*0.35,'LineWidth',1); set(pcLabel(jj),'Color',fg); end
                else
                    set(axGrid(jj),'Visible','off');
                end
            end
            refreshSelectionUI(); drawnow;
        end
        function onCellClick(hObj)
            axh=ancestor(hObj,'axes'); if isempty(axh) && strcmp(get(hObj,'Type'),'axes'), axh=hObj; end
            ii=find(axGrid==axh,1); if isempty(ii), return; end
            k=compIdx(ii); if ~isfinite(k)||k<1||k>K, return; end
            if strcmp(get(fig,'SelectionType'),'alt'), selected(selected==k)=[]; else, if any(selected==k), selected(selected==k)=[]; else, selected(end+1)=k; end, end
            selected=sort(unique(selected)); renderPage(); previewComponent(k);
        end
        function previewComponent(k)
            if k<1||k>K, return; end; cla(axPrev); plot(axPrev,tmin,st.U(idx,k),'Color',lineCol,'LineWidth',1.4); grid(axPrev,'on'); set(axPrev,'Color',bgAx,'XColor',fg,'YColor',fg); title(axPrev,sprintf('PC%d | %s',k,scopeLabel()),'Color',fg);
        end
        function refreshSelectionUI()
            if isempty(selected), set(lb,'String',{'<none>'}); else, set(lb,'String',arrayfun(@(x)sprintf('PC%-3d  (%.2f%%)',x,100*st.expl(x)),selected,'UniformOutput',false)); end
            set(txtInfo,'String',sprintf('Selected: %d PCs | Removed %.2f%%',numel(selected),100*sum(st.expl(selected))));
        end
        function prevPage(~,~), if page>1, page=page-1; renderPage(); end, end
        function nextPage(~,~), if page<nPages, page=page+1; renderPage(); end, end
        function applyAndClose(~,~), applyFlag=true; if ishghandle(fig), uiresume(fig); delete(fig); end, end
        function cancelAndClose(~,~), applyFlag=false; if ishghandle(fig), uiresume(fig); delete(fig); end, end
        function onKey(~,evt)
            if strcmp(evt.Key,'rightarrow'), nextPage();
            elseif strcmp(evt.Key,'leftarrow'), prevPage();
            elseif strcmp(evt.Key,'escape'), cancelAndClose();
            end
        end
        function onScrollWheel(~,evt)
            if Z0 <= 1, return; end
            set(scopePopup,'Value',2);
            z = round(get(scopeSlider,'Value'));
            if evt.VerticalScrollCount > 0
                z = z + 1;
            else
                z = z - 1;
            end
            z = max(1,min(Z0,z));
            set(scopeSlider,'Value',z);
            scopeChanged([],[]);
        end
        function showHelp(~,~), msgbox(sprintf('Use scope control at top-right to switch All slices vs Selected slice. Mouse wheel also changes slices and recomputes PCA for the selected slice.'),'PCA help','modal'); end
        function s=scopeLabel(), if st.scopeInfo.sliceSpecific, s=sprintf('slice %d/%d',st.scopeInfo.zIndex,st.scopeInfo.nSlices); else, s=sprintf('all slices 1-%d',Z0); end, end
    end

    function idx = getIdx(T,maxPts)
        if T > maxPts, idx = unique(round(linspace(1,T,maxPts))); else, idx = 1:T; end
    end

    function s = onoff(tf)
        if tf, s='on'; else, s='off'; end
    end
end


function [selected, applyFlag] = pca_selector_gui_grid(U, expl, TR, maxPts)

T = size(U,1);
K = size(U,2);

% downsample for speed
if T > maxPts
    idx = unique(round(linspace(1, T, maxPts)));
else
    idx = 1:T;
end

tmin_full = ((0:T-1) * TR) / 60;
tmin = tmin_full(idx);
tmax = tmin_full(end);

% nice ticks in minutes (shared)
xticks = niceMinuteTicks(tmax);

selected = [];
applyFlag = false;
% HUMOR_PCA_SCOPE_GUI_V8
if nargin < 5 || isempty(volSize), volSize = [1 1 1]; end
if numel(volSize) < 3, volSize(3) = 1; end
Zscope = max(1, round(volSize(3)));
scopeInfo = struct('mode','all','zIndex',1,'nSlices',Zscope,'sliceSpecific',false);

perPage = 25;
nPages = max(1, ceil(K / perPage));
page = 1;

% theme
bgFig   = [0.06 0.06 0.07];
bgAx    = [0.09 0.09 0.10];
fg      = [0.90 0.90 0.92];
fgDim   = [0.70 0.70 0.74];
selRed  = [1.00 0.25 0.25];

% STRONGER (less washed) blue for UI
lineCol = [0.35 0.80 1];   % lightblue (more visible than light blue)

fig = figure('Name','PCA Components — left click select, right click deselect', ...
    'Color',bgFig,'MenuBar','none','ToolBar','none','NumberTitle','off', ...
    'Position',[60 40 1800 980]);
% HUMoR_FORCE_FULLSCREEN_PATCH31
try, deConfUSIon_force_fullscreen_fig(fig); catch, end


try, set(fig,'Renderer','opengl'); catch, end

gridX = 0.03; gridY = 0.08; gridW = 0.66; gridH = 0.90;
rightX = 0.71; rightY = 0.08; rightW = 0.27; rightH = 0.90;

hdr = uicontrol('Parent',fig,'Style','text','Units','normalized', ...
    'Position',[gridX 0.97 gridW 0.03], ...
    'String','', ...
    'BackgroundColor',bgFig,'ForegroundColor',fg,'FontSize',13,'FontWeight','bold', ...
    'HorizontalAlignment','left');

% single shared x-axis label for grid
uicontrol('Parent',fig,'Style','text','Units','normalized', ...
    'Position',[gridX gridY-0.055 gridW 0.04], ...
    'String','Time (min)', ...
    'BackgroundColor',bgFig, ...
    'ForegroundColor',fg, ...
    'FontName','Arial', ...
    'FontSize',15, ...
    'FontWeight','bold', ...
    'HorizontalAlignment','center');

rightPanel = uipanel('Parent',fig,'Units','normalized','Position',[rightX rightY rightW rightH], ...
    'BackgroundColor',[0.08 0.08 0.09], ...
    'ForegroundColor',fg, ...
    'Title','Selection', ...
    'FontName','Arial', ...
    'FontWeight','bold', ...
    'FontSize',14);

axPrev = axes('Parent',rightPanel,'Units','normalized','Position',[0.15 0.66 0.77 0.28], ...
    'Color',bgAx,'XColor',fg,'YColor',fg);
title(axPrev,'Preview','Color',fg,'FontWeight','bold','FontSize',13);
grid(axPrev,'on');

txtInfo = uicontrol('Parent',rightPanel,'Style','text','Units','normalized', ...
    'Position',[0.10 0.55 0.82 0.075], ...
    'String','Selected: 0 PCs | Removed: 0.00%', ...
    'BackgroundColor',get(rightPanel,'BackgroundColor'), ...
    'ForegroundColor',[0.85 0.95 1.00], ...
    'FontName','Arial', ...
    'FontSize',14,'FontWeight','bold', ...
    'HorizontalAlignment','left');

uicontrol('Parent',rightPanel,'Style','text','Units','normalized', ...
    'Position',[0.10 0.49 0.82 0.045], ...
    'String','Selected for removal:', ...
    'BackgroundColor',get(rightPanel,'BackgroundColor'), ...
    'ForegroundColor',fg, ...
    'HorizontalAlignment','left', ...
    'FontName','Arial', ...
    'FontWeight','bold', ...
    'FontSize',13);

lb = uicontrol('Parent',rightPanel,'Style','listbox','Units','normalized', ...
    'Position',[0.10 0.22 0.82 0.26], ...
    'String',{'<none>'}, ...
    'BackgroundColor',[0.16 0.16 0.18], ...
    'ForegroundColor',fg, ...
    'FontName','Courier New', ...
    'FontSize',13);

uicontrol('Parent',rightPanel,'Style','pushbutton','Units','normalized', ...
    'Position',[0.10 0.12 0.38 0.08], 'String','Apply & Close', ...
    'FontWeight','bold','FontSize',13, 'BackgroundColor',[0.20 0.45 0.25], 'ForegroundColor','w', ...
    'Callback',@applyAndClose);

uicontrol('Parent',rightPanel,'Style','pushbutton','Units','normalized', ...
    'Position',[0.54 0.12 0.38 0.08], 'String','Cancel', ...
    'FontWeight','bold','FontSize',13, 'BackgroundColor',[0.65 0.20 0.20], 'ForegroundColor','w', ...
    'Callback',@cancelAndClose);

btnPrev = uicontrol('Parent',rightPanel,'Style','pushbutton','Units','normalized', ...
    'Position',[0.10 0.03 0.24 0.07], 'String','Prev', ...
    'FontWeight','bold','FontSize',12, 'BackgroundColor',[0.22 0.22 0.25], 'ForegroundColor','w', ...
    'Callback',@prevPage);

btnNext = uicontrol('Parent',rightPanel,'Style','pushbutton','Units','normalized', ...
    'Position',[0.38 0.03 0.24 0.07], 'String','Next', ...
    'FontWeight','bold','FontSize',12, 'BackgroundColor',[0.22 0.22 0.25], 'ForegroundColor','w', ...
    'Callback',@nextPage);

uicontrol('Parent',rightPanel,'Style','pushbutton','Units','normalized', ...
    'Position',[0.66 0.03 0.26 0.07], 'String','HELP', ...
    'FontWeight','bold','FontSize',12, 'BackgroundColor',[0.10 0.35 0.95], 'ForegroundColor','w', ...
    'Callback',@showHelp);



% Build 5x5 axes
nRow = 5; nCol = 5;
axGrid = gobjects(25,1);
lnGrid = gobjects(25,1);
pcLabel = gobjects(25,1);
compIdx = nan(25,1);

pad = 0.008;
cellW = gridW / nCol;
cellH = gridH / nRow;

for i = 1:25
    r = floor((i-1)/nCol);
    c = mod((i-1), nCol);

    x0 = gridX + c*cellW + pad;
    y0 = gridY + (nRow-1-r)*cellH + pad;
    w0 = cellW - 2*pad;
    h0 = cellH - 2*pad;

    axGrid(i) = axes('Parent',fig,'Units','normalized','Position',[x0 y0 w0 h0], ...
        'Color',bgAx);

    set(axGrid(i),'Box','on','LineWidth',1.0, ...
        'XColor',fgDim*0.35,'YColor',fgDim*0.35);

    set(axGrid(i),'YTick',[]);
    set(axGrid(i),'XLim',[0 tmax]);

    hold(axGrid(i),'on');
    lnGrid(i) = plot(axGrid(i), tmin, zeros(size(tmin)), 'LineWidth', 1.0);
    set(lnGrid(i),'Color',lineCol);

    % label INSIDE axis so it never disappears
    pcLabel(i) = text(axGrid(i), 0.02, 0.92, '', ...
        'Units','normalized', 'Color',fg, 'FontSize',11, ...
        'FontWeight','bold', 'Interpreter','none', 'Tag','PCLABEL');

    hold(axGrid(i),'off');

    % clickable
    set(axGrid(i), 'ButtonDownFcn', @(h,~)onCellClick(h));
    set(lnGrid(i), 'ButtonDownFcn', @(h,~)onCellClick(h));
    try, set(axGrid(i),'PickableParts','all'); catch, end
    try, set(lnGrid(i),'PickableParts','all'); catch, end
    set(axGrid(i),'HitTest','on');
    set(lnGrid(i),'HitTest','on');
end

set(fig,'WindowKeyPressFcn',@onKey);
set(fig,'CloseRequestFcn',@onCloseCancel);

renderPage();
previewComponent(1);

uiwait(fig);

    function renderPage()
        firstPC = (page-1)*perPage + 1;
        lastPC  = min(K, page*perPage);
        set(hdr,'String',sprintf('PCs %d–%d of %d   (Page %d/%d)', firstPC, lastPC, K, page, nPages));

        set(btnPrev,'Enable', onoff(page>1));
        set(btnNext,'Enable', onoff(page<nPages));

        for i2 = 1:25
            k = (page-1)*perPage + i2;
            compIdx(i2) = k;

            if k <= K
                tc = U(:,k);
                tc = tc(idx);

                set(lnGrid(i2),'XData',tmin,'YData',tc,'Visible','on');

                % consistent x-limits/ticks
                set(axGrid(i2),'XLim',[0 tmax]);

                % bottom row gets ticks/labels, others none (clean)
                rr = floor((i2-1)/nCol); % 0..4 top->bottom
        if rr == (nRow-1)
    set(axGrid(i2), ...
        'XTick',xticks, ...
        'XTickLabel',arrayfun(@(x)sprintf('%d',round(x)),xticks,'uni',0), ...
        'XColor',fg, ...
        'FontName','Arial', ...
        'FontSize',10, ...
        'FontWeight','bold');
else
    set(axGrid(i2), ...
        'XTick',[], ...
        'XTickLabel',{}, ...
        'XColor',fgDim*0.35);
end

                % label inside axis
                s = sprintf('PC%d  %.2f%%', k, 100*expl(k));
                set(pcLabel(i2),'String',s);

                % selection styling
                if any(selected == k)
                    set(axGrid(i2),'XColor',selRed,'YColor',selRed,'LineWidth',2.2);
                    set(pcLabel(i2),'Color',selRed);
                else
                    set(axGrid(i2),'XColor',fgDim*0.35,'YColor',fgDim*0.35,'LineWidth',1.0);
                    set(pcLabel(i2),'Color',fg);
                end

                set(axGrid(i2),'Visible','on');
            else
                set(axGrid(i2),'Visible','off');
            end
        end

        safeDrawnow();
    end

    function onCellClick(hObj)
        axh = [];
        if strcmp(get(hObj,'Type'),'axes')
            axh = hObj;
        else
            axh = ancestor(hObj,'axes');
        end
        if isempty(axh), return; end

        iCell = find(axGrid == axh, 1);
        if isempty(iCell), return; end

        k = compIdx(iCell);
        if ~isfinite(k) || k < 1 || k > K, return; end

        typ = get(fig,'SelectionType');
        if strcmp(typ,'alt')
            selected(selected == k) = [];
        else
            if any(selected == k)
                selected(selected == k) = [];
            else
                selected(end+1) = k; %#ok<AGROW>
            end
        end

        selected = sort(unique(selected));
        refreshSelectionUI();
        previewComponent(k);
        renderPage();
    end

    function previewComponent(k)
        if k < 1 || k > K, return; end
        cla(axPrev);

        tc = U(:,k);
        tc = tc(idx);

        plot(axPrev, tmin, tc, 'LineWidth', 1.6, 'Color', lineCol);
        grid(axPrev,'on');
        set(axPrev, ...
    'XColor',fg, ...
    'YColor',fg, ...
    'Color',bgAx, ...
    'FontName','Arial', ...
    'FontSize',12, ...
    'FontWeight','bold');

title(axPrev, sprintf('PC%d | %.2f%%', k, 100*expl(k)), ...
    'Color',fg, ...
    'FontName','Arial', ...
    'FontWeight','bold', ...
    'FontSize',13);

xlabel(axPrev,'Time (min)', ...
    'Color',fg, ...
    'FontName','Arial', ...
    'FontWeight','bold', ...
    'FontSize',13);

ylabel(axPrev,'Amplitude (a.u.)', ...
    'Color',fg, ...
    'FontName','Arial', ...
    'FontWeight','bold', ...
    'FontSize',12);

set(axPrev,'XLim',[0 tmax], 'XTick',xticks);

        safeDrawnow();
    end

    function refreshSelectionUI()
        if isempty(selected)
            set(lb,'String',{'<none>'},'Value',1);
        else
            s = arrayfun(@(x)sprintf('PC%-3d  (%.2f%%)', x, 100*expl(x)), selected, 'uni',0);
            set(lb,'String',s,'Value',1);
        end
        pct = 100 * sum(expl(selected));
        set(txtInfo,'String',sprintf('Selected: %d PCs | Removed: %.2f%%', numel(selected), pct));
        safeDrawnow();
    end

    function prevPage(~,~)
        if page > 1
            page = page - 1;
            renderPage();
        end
    end

    function nextPage(~,~)
        if page < nPages
            page = page + 1;
            renderPage();
        end
    end

   function showHelp(~,~)

    helpFig = figure( ...
        'Name','PCA Help', ...
        'Color',[0.03 0.03 0.04], ...
        'MenuBar','none', ...
        'ToolBar','none', ...
        'NumberTitle','off', ...
        'Resize','off', ...
        'Position',[260 140 900 650], ...
        'InvertHardcopy','off');

    uicontrol('Parent',helpFig, ...
        'Style','text', ...
        'Units','normalized', ...
        'Position',[0.04 0.91 0.92 0.06], ...
        'String','PCA Denoising - Quick Guide', ...
        'BackgroundColor',[0.03 0.03 0.04], ...
        'ForegroundColor',[1 1 1], ...
        'FontName','Arial', ...
        'FontSize',18, ...
        'FontWeight','bold', ...
        'HorizontalAlignment','center');

    helpLines = { ...
        'What PCA does:', ...
        'PCA decomposes the fUSI time-series into temporal components ranked by variance.', ...
        'Each PC contains a time-course and a spatial contribution across voxels.', ...
        'When you remove a PC, the code reconstructs that component and subtracts it from the data.', ...
        '', ...
        'What you should remove:', ...
        '- Slow global drift affecting most voxels.', ...
        '- Motion-like fluctuations visible in many PCs.', ...
        '- Stripe-like, scanner-like, or periodic artifacts.', ...
        '- Components with abrupt jumps or non-physiological patterns.', ...
        '', ...
        'What you should usually keep:', ...
        '- Components that look like plausible biological responses.', ...
        '- Components with localized or stimulus-related temporal structure.', ...
        '- Components that explain very little variance unless clearly artifact-like.', ...
        '', ...
        'How to use this GUI:', ...
        'Left click on a PC panel: select or deselect it.', ...
        'Right click on a PC panel: deselect it.', ...
        'Red border means the PC is selected for removal.', ...
        'The preview panel shows the selected PC time-course in more detail.', ...
        'The Selected/Removed value shows how many PCs and how much variance proxy will be removed.', ...
        '', ...
        'Important interpretation:', ...
        'High variance PCs are not automatically bad.', ...
        'PC1 can contain real global physiology, anesthesia drift, motion, or scanner drift.', ...
        'Always inspect the shape of the time-course before removing PCs.', ...
        '', ...
        'Buttons:', ...
        'Apply & Close: remove selected PCs and save QC plots.', ...
        'Cancel: close without changing the dataset.', ...
        'Prev / Next: move through pages of 25 PCs.', ...
        '', ...
        'Recommended workflow:', ...
        '1. Inspect PC1-PC10 carefully.', ...
        '2. Remove only obvious artifacts first.', ...
        '3. Check the global mean before/after QC plot.', ...
        '4. Avoid aggressive removal unless artifacts are severe.'};

    uicontrol('Parent',helpFig, ...
        'Style','edit', ...
        'Units','normalized', ...
        'Position',[0.05 0.12 0.90 0.76], ...
        'String',helpLines, ...
        'Max',50, ...
        'Min',0, ...
        'Enable','inactive', ...
        'BackgroundColor',[0.06 0.06 0.07], ...
        'ForegroundColor',[1 1 1], ...
        'FontName','Arial', ...
        'FontSize',14, ...
        'HorizontalAlignment','left');

    uicontrol('Parent',helpFig, ...
        'Style','pushbutton', ...
        'Units','normalized', ...
        'Position',[0.36 0.035 0.28 0.06], ...
        'String','Close Help', ...
        'BackgroundColor',[0.10 0.35 0.95], ...
        'ForegroundColor',[1 1 1], ...
        'FontName','Arial', ...
        'FontSize',13, ...
        'FontWeight','bold', ...
        'Callback',@(src,evt) delete(helpFig));
end
    function onKey(~,evt)
        switch evt.Key
            case {'return','enter'}
                applyAndClose();
            case {'escape'}
                cancelAndClose();
            case {'rightarrow'}
                nextPage();
            case {'leftarrow'}
                prevPage();
        end
    end

    function applyAndClose(~,~)

        applyFlag = true;
        try, uiresume(fig); catch, end
        try, delete(fig); catch, end
    end

    function cancelAndClose(~,~)
        applyFlag = false;
        selected = [];
        try, uiresume(fig); catch, end
        try, delete(fig); catch, end
    end

    function onCloseCancel(~,~)
        cancelAndClose();
    end

end

% ======================================================================
% QC: variance proxy bar plot (UPGRADED COLORS)
% ======================================================================
function make_qc_plot_selected(expl, selected, outFile)

% Strong QC palette
qcBlue = [0.00 0.15 0.55];   % dark blue
qcSel  = [0.15 0.15 0.15];   % dark charcoal (selected/removed)
qcEdge = [0.85 0.10 0.10];   % red edge for removed bars (keeps clarity)

fig = figure('Visible','off','Color','w','Position',[100 100 1100 380]);
ax = axes('Parent',fig);

hb = bar(ax, 100*expl(:), 'FaceColor', qcBlue, 'EdgeColor', 'none'); %#ok<NASGU>
hold(ax,'on');

if ~isempty(selected)
    hs = bar(ax, selected, 100*expl(selected), 'FaceColor', qcSel, 'EdgeColor', qcEdge, 'LineWidth', 1.2); %#ok<NASGU>
end

xlabel(ax,'PC index');
ylabel(ax,'Variance proxy (%)');
title(ax,'PCA variance proxy (dark bars = removed PCs)');
grid(ax,'on');

% Make grid/axes a bit stronger
set(ax,'LineWidth',1.2,'FontSize',11);
set(ax,'GridAlpha',0.25);

saveas(fig, outFile);
close(fig);
end

% ======================================================================
% QC: global mean timecourse before/after (minutes) (UPGRADED COLORS)
% ======================================================================
function make_qc_globalmean_plot(gb, ga, TR, outFile)

T = numel(gb);
tmin = ((0:T-1)*TR)/60;

% Strong QC palette
qcBlue  = [0.00 0.15 0.55];   % dark blue (Before)
qcAfter = [0.20 0.20 0.20];   % dark gray (After)

fig = figure('Visible','off','Color','w','Position',[120 120 1100 380]);
ax = axes('Parent',fig);

plot(ax, tmin, double(gb), 'LineWidth', 1.9, 'Color', qcBlue); hold(ax,'on');
plot(ax, tmin, double(ga), 'LineWidth', 1.9, 'Color', qcAfter);

grid(ax,'on');
xlabel(ax,'Time (min)');
ylabel(ax,'Global mean intensity');
legend(ax, {'Before','After'}, 'Location','best');
title(ax,'Global mean intensity: before vs after PCA removal');

set(ax,'LineWidth',1.2,'FontSize',11);
set(ax,'GridAlpha',0.25);

saveas(fig, outFile);
close(fig);
end

% ======================================================================
% QC: mean image before/after (middle Z)
% ======================================================================
function make_qc_meanimage_plot(I4_before, I4_after, outFile)

mBefore = mean(single(I4_before), 4);
mAfter  = mean(single(I4_after), 4);

Z = size(mBefore,3);
zMid = max(1, round(Z/2));

im1 = mBefore(:,:,zMid);
im2 = mAfter(:,:,zMid);

mn = min([im1(:); im2(:)]);
mx = max([im1(:); im2(:)]);
if ~isfinite(mn) || ~isfinite(mx) || mx <= mn
    mn = 0; mx = 1;
end

fig = figure('Visible','off','Color','w','Position',[140 140 1100 420]);

ax1 = subplot(1,2,1);
imagesc(ax1, im1); axis(ax1,'image'); axis(ax1,'off');
colormap(ax1, gray(256)); caxis(ax1, [mn mx]);
title(ax1, sprintf('Mean BEFORE (Z=%d)', zMid));

ax2 = subplot(1,2,2);
imagesc(ax2, im2); axis(ax2,'image'); axis(ax2,'off');
colormap(ax2, gray(256)); caxis(ax2, [mn mx]);
title(ax2, sprintf('Mean AFTER (Z=%d)', zMid));

saveas(fig, outFile);
close(fig);
end

% ======================================================================
% QC: exact-look dark grid pages (UPGRADED COLORS)
% ======================================================================
function files = make_qc_grid_dark_exact(U, expl, TR, selected, qcDir, tag)

files = {};
K = size(U,2);
T = size(U,1);

% downsample like GUI
maxPts = 2000;
if T > maxPts
    idx = unique(round(linspace(1, T, maxPts)));
else
    idx = 1:T;
end
tmin_full = ((0:T-1)*TR)/60;
tmin = tmin_full(idx);
tmax = tmin_full(end);
xticks = niceMinuteTicks(tmax);

perPage = 25;
nPages = max(1, ceil(K/perPage));

% determine which pages to save
savePages = false(1,nPages);
savePages(1) = true;
for s = selected(:)'
    p = ceil(s/perPage);
    if p >= 1 && p <= nPages
        savePages(p) = true;
    end
end

% theme
bgFig   = [0.06 0.06 0.07];
bgAx    = [0.09 0.09 0.10];
fg      = [0.90 0.90 0.92];
fgDim   = [0.70 0.70 0.74];
selRed  = [1.00 0.25 0.25];

% STRONGER blue for QC grid lines
lineCol = [0.35 0.80 1];  % light blue
lineW   = 1.35;              % slightly thicker for visibility

for p = 1:nPages
    if ~savePages(p), continue; end

    fig = figure('Visible','off','Color',bgFig,'Position',[80 60 1500 860]);

    % header (sgtitle not in 2017b)
    annotation(fig,'textbox',[0.03 0.965 0.66 0.03], ...
        'String',sprintf('PCA grid (exact look) — Page %d/%d — tag=%s', p, nPages, tag), ...
        'Color',fg,'FontSize',13,'FontWeight','bold','EdgeColor','none', ...
        'Interpreter','none','HorizontalAlignment','left');

annotation(fig,'textbox',[0.03 0.025 0.66 0.04], ...
    'String','Time (min)', ...
    'Color',fg, ...
    'FontName','Arial', ...
    'FontSize',15, ...
    'FontWeight','bold', ...
    'EdgeColor','none', ...
    'Interpreter','none', ...
    'HorizontalAlignment','center');

    gridX=0.03; gridY=0.08; gridW=0.66; gridH=0.90;

    nRow=5; nCol=5;
    pad=0.008; cellW=gridW/nCol; cellH=gridH/nRow;

    for i = 1:25
        r = floor((i-1)/nCol);
        c = mod((i-1), nCol);

        x0 = gridX + c*cellW + pad;
        y0 = gridY + (nRow-1-r)*cellH + pad;
        w0 = cellW - 2*pad;
        h0 = cellH - 2*pad;

        ax = axes('Parent',fig,'Units','normalized','Position',[x0 y0 w0 h0], 'Color',bgAx);
        set(ax,'Box','on','YTick',[],'XLim',[0 tmax]);

        k = (p-1)*perPage + i;
        if k <= K
            tc = U(:,k); tc = tc(idx);
            plot(ax, tmin, tc, 'LineWidth', lineW, 'Color', lineCol);
            grid(ax,'on');

            rr = floor((i-1)/nCol);
          if rr == (nRow-1)
    set(ax, ...
        'XTick',xticks, ...
        'XTickLabel',arrayfun(@(x)sprintf('%d',round(x)),xticks,'uni',0), ...
        'XColor',fg, ...
        'FontName','Arial', ...
        'FontSize',10, ...
        'FontWeight','bold');
else
                set(ax,'XTick',[],'XTickLabel',{}, 'XColor',fgDim*0.35);
            end

            % label inside axis
            isSel = any(selected == k);
            labCol = fg; boxCol = fgDim*0.35; lw = 1.0;

            if isSel
                boxCol = selRed; lw = 2.2; labCol = selRed;
                text(ax,0.02,0.78,sprintf('REMOVED'), 'Units','normalized', ...
                    'Color',selRed,'FontWeight','bold','FontSize',10,'Interpreter','none');
            end

            text(ax,0.02,0.92,sprintf('PC%d  %.2f%%',k,100*expl(k)), 'Units','normalized', ...
                'Color',labCol,'FontWeight','bold','FontSize',10,'Interpreter','none');

            set(ax,'XColor',boxCol,'YColor',boxCol,'LineWidth',lw);

        else
            axis(ax,'off');
        end
    end

    outFile = fullfile(qcDir, sprintf('PCA_grid_dark_page%02d_%s.png', p, tag));
    saveas(fig, outFile);
    close(fig);

    files{end+1} = outFile; %#ok<AGROW>
end

end

% ======================================================================
% Helpers
% ======================================================================
function s = emptyStats(tag)
s = struct();
s.tag = tag;
s.selectedComponents = [];
s.percentExplainedRemoved = 0;
s.explainedPerComponent = [];
s.qcFile = '';
s.qcGlobalMeanFile = '';
s.qcMeanImageFile = '';
s.qcGridFiles = {};
s.nComponents = 0;
s.method = '';
s.applied = false;
end

function safeDrawnow()
try
    drawnow limitrate;
catch
    drawnow;
end
end

function out = onoff(tf)
if tf, out = 'on'; else, out = 'off'; end
end

function ticks = niceMinuteTicks(tmax)
% choose a step so we get ~5-7 ticks
if ~isfinite(tmax) || tmax <= 0
    ticks = [0 1];
    return;
end

candidates = [0.5 1 2 5 10 15 20 30 60 120];
best = candidates(end);

for i = 1:numel(candidates)
    dt = candidates(i);
    n = floor(tmax/dt) + 1;
    if n <= 7
        best = dt;
        break;
    end
end

ticks = 0:best:tmax;
if ticks(end) < tmax
    ticks(end+1) = tmax;
end
ticks = unique(ticks);
end
