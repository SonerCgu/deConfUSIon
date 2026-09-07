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
% DECONF_OPTA_V1 : automatic / preselected component removal
if ~isfield(opts,'autoSelect'),       opts.autoSelect = []; end
if ~isfield(opts,'autoApply'),        opts.autoApply = false; end
if ~isfield(opts,'basisMethod'),      opts.basisMethod = 'auto'; end

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

% DECONF_OPTA_V1 : headless path - drop fixed components over all slices
autoSel = round(double(opts.autoSelect(:)'));
autoSel = autoSel(isfinite(autoSel) & autoSel >= 1);
if ~isempty(autoSel) && ~isempty(opts.autoApply) && any(logical(opts.autoApply))
    st = computePCA(struct('mode','all','zIndex',1,'nSlices',Z0,'sliceSpecific',false));
    selected = autoSel(autoSel <= st.K);
    applyFlag = ~isempty(selected);
    if ~isempty(opts.logFcn) && isa(opts.logFcn,'function_handle')
        try, opts.logFcn(sprintf('PCA auto-removal: PC%s over all slices.',sprintf(' %d',selected))); catch, end
    end
else
    [selected, applyFlag, st] = pca_v12_gui(I4orig, TR, opts, tag);
end

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
stats.decomposition=st.basisInfo;
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
        K = min([opts.nCompMax, V, T-1, 200]);
        if K < 1, error('Not enough time points for PCA.'); end
        [U,sing,W,totalEnergy,basisInfo] = deConfUSIon_signal('basis',Xc,K,struct('showProgress',~opts.autoApply,'method',opts.basisMethod));
        K=numel(sing); expl=sing.^2/max(eps,totalEnergy);
        st = struct('U',U,'W',W,'sing',sing,'expl',expl,'Xc',Xc,'mu',mu,'muVec',muVec, ...
            'Y',Y,'X',X,'Z',Z,'T',T,'K',K,'scopeInfo',scopeInfo,'basisInfo',basisInfo);
    end

    function [selected, applyFlag, st] = pca_v12_gui(I4orig_unused, TR, opts_unused, tag_unused) %#ok<INUSD>
        bgFig=[0.06 0.06 0.07]; bgAx=[0.09 0.09 0.10]; fg=[0.90 0.90 0.92]; fgDim=[0.70 0.70 0.74]; selRed=[1.00 0.25 0.25]; lineCol=[0.35 0.80 1];
        selected=[]; applyFlag=false;
        scopeInfo = struct('mode','all','zIndex',1,'nSlices',Z0,'sliceSpecific',false);
        st = computePCA(scopeInfo);
        K = st.K; T = st.T;
        % DECONF_OPTA_V1 : start with requested components already ticked
        try
            pre = round(double(opts.autoSelect(:)'));
            selected = pre(isfinite(pre) & pre >= 1 & pre <= K);
        catch
            selected = [];
        end
        maxPts = opts.maxDisplayPoints;
        idx = getIdx(T,maxPts);
        tmin = ((0:T-1)*TR)/60; tmin = tmin(idx); tmax = max(tmin);
        perPage=25; nPages=max(1,ceil(K/perPage)); page=1;
        fig=figure('Name','PCA Components — slice-aware V12', 'Color',bgFig,'MenuBar','none','ToolBar','none','NumberTitle','off', 'Position',[60 40 1800 980]);
        try, deConfUSIon_utils('deConfUSIon_force_fullscreen_fig',fig); catch, end
        deConfUSIon_ui('identity',fig,dataIn,tag,'PCA');
        gridX=0.03; gridY=0.08; gridW=0.66; gridH=0.81; rightX=0.71; rightY=0.08; rightW=0.27; rightH=0.83;
        hdr=uicontrol('Parent',fig,'Style','text','Units','normalized','Position',[gridX 0.905 gridW 0.03],'String','','BackgroundColor',bgFig,'ForegroundColor',fg,'FontSize',13,'FontWeight','bold','HorizontalAlignment','left');
        rightPanel=uipanel('Parent',fig,'Units','normalized','Position',[rightX rightY rightW rightH],'BackgroundColor',[0.08 0.08 0.09],'ForegroundColor',fg,'Title','Selection + Slice Scope','FontWeight','bold','FontSize',13);
        uicontrol('Parent',rightPanel,'Style','text','Units','normalized','Position',[0.06 0.915 0.88 0.055],'String','PCA INPUT SCOPE', 'BackgroundColor',get(rightPanel,'BackgroundColor'),'ForegroundColor',[0.85 0.95 1.00],'FontWeight','bold','FontSize',14);
        scopePopup=uicontrol('Parent',rightPanel,'Style','popupmenu','Units','normalized','Position',[0.06 0.855 0.88 0.055],'String',{'All slices together','Selected slice only'},'Value',1,'BackgroundColor',[0.16 0.16 0.18],'ForegroundColor',fg,'FontWeight','bold','FontSize',12,'Callback',@scopeChanged);
        scopeText=uicontrol('Parent',rightPanel,'Style','text','Units','normalized','Position',[0.06 0.805 0.88 0.050],'String',sprintf('All slices 1-%d',Z0),'BackgroundColor',get(rightPanel,'BackgroundColor'),'ForegroundColor',[1.00 0.95 0.55],'FontWeight','bold','FontSize',13);
        stepSmall=1/max(1,Z0-1);
        scopeSlider=uicontrol('Parent',rightPanel,'Style','slider','Units','normalized','Position',[0.06 0.755 0.88 0.045],'Min',1,'Max',max(2,Z0),'Value',1,'SliderStep',[stepSmall min(1,stepSmall*2)],'Enable','off','Callback',@scopeChanged);
        if Z0 <= 1, set(scopePopup,'Enable','off'); set(scopeSlider,'Enable','off'); set(scopeText,'String','2D / single-slice data'); end
        basisPopup=uicontrol(rightPanel,'Style','popupmenu','Units','normalized','Position',[.06 .705 .88 .04], ...
            'String',{'Automatic: fast approximation for long recordings','Exact PCA (slower; recomputes)'}, ...
            'Value',1+strcmp(opts.basisMethod,'exact'),'FontSize',10,'BackgroundColor',[.16 .16 .18],'ForegroundColor',fg,'Callback',@basisChanged);
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
        renderPage(); previewComponent(1); deConfUSIon_ui('style',fig); uiwait(fig);
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
            if st.basisInfo.approximate, set(hdr,'String',sprintf('PCs %d-%d of %d | Fast approximation | residual %.3g | %s',firstPC,lastPC,K,st.basisInfo.relativeResidual,scopeLabel())); end
            set(btnPrev,'Enable',onoff(page>1)); set(btnNext,'Enable',onoff(page<nPages));
            for jj=1:25
                k=(page-1)*perPage+jj; compIdx(jj)=k;
                if k<=K
                    tc=st.U(:,k); tc=tc(idx); set(lnGrid(jj),'XData',tmin,'YData',tc,'Visible','on'); set(axGrid(jj),'Visible','on','XLim',[0 max(tmin)]);
                    set(pcLabel(jj),'String',sprintf('PC%d %.2f%%',k,100*st.expl(k)),'Visible','on');
                    if any(selected==k), set(axGrid(jj),'XColor',selRed,'YColor',selRed,'LineWidth',2.2); set(pcLabel(jj),'Color',selRed); else, set(axGrid(jj),'XColor',fgDim,'YColor',fgDim,'LineWidth',1); set(pcLabel(jj),'Color',fg); end
                else
                    set(axGrid(jj),'Visible','off');
                    set(lnGrid(jj),'Visible','off');
                    set(pcLabel(jj),'Visible','off');
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
        function basisChanged(~,~)
            if get(basisPopup,'Value')==2, opts.basisMethod='exact'; else, opts.basisMethod='auto'; end
            scopeChanged([],[]);
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
        function showHelp(~,~), deConfUSIon_ui('help','PCA'); end
        function s=scopeLabel(), if st.scopeInfo.sliceSpecific, s=sprintf('slice %d/%d',st.scopeInfo.zIndex,st.scopeInfo.nSlices); else, s=sprintf('all slices 1-%d',Z0); end, end
    end

    function idx = getIdx(T,maxPts)
        if T > maxPts, idx = unique(round(linspace(1,T,maxPts))); else, idx = 1:T; end
    end

    function s = onoff(tf)
        if tf, s='on'; else, s='off'; end
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


function out = onoff(tf)
if tf, out = 'on'; else, out = 'off'; end
end

