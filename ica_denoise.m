function [newData, stats] = ica_denoise(dataIn, saveRoot, tag, opts)
% ICA_DENOISE V12 — integrated all-slice / slice-specific recompute GUI

if nargin < 2 || isempty(saveRoot), saveRoot = pwd; end
if nargin < 3 || isempty(tag), tag = datestr(now,'yyyymmdd_HHMMSS'); end
if nargin < 4, opts = struct(); end

if ~isfield(opts,'nCompMax'), opts.nCompMax = 30; end
if ~isfield(opts,'maxDisplayPoints'), opts.maxDisplayPoints = 2000; end
if ~isfield(opts,'chunkT'), opts.chunkT = 250; end
if ~isfield(opts,'centerMode'), opts.centerMode = 'voxel'; end
if ~isfield(opts,'verbose'), opts.verbose = true; end
if ~isfield(opts,'icaMaxIter'), opts.icaMaxIter = 400; end
if ~isfield(opts,'icaTol'), opts.icaTol = 1e-5; end
if ~isfield(opts,'onApply'), opts.onApply = []; end
if ~isfield(opts,'onCancel'), opts.onCancel = []; end
if ~isfield(opts,'logFcn'), opts.logFcn = []; end

isStruct = isstruct(dataIn);
if isStruct
    if ~isfield(dataIn,'I'), error('ica_denoise: input struct must contain .I'); end
    I = dataIn.I; TR = 1; if isfield(dataIn,'TR'), TR = double(dataIn.TR); end
    newData = dataIn;
else
    I = dataIn; TR = 1; newData = struct('I',I);
end
if ~isscalar(TR) || ~isfinite(TR) || TR <= 0, TR = 1; end

sz = size(I); inputWas3D = false;
if ndims(I) == 3
    Y0 = sz(1); X0 = sz(2); T0 = sz(3); Z0 = 1; I4orig = reshape(I,Y0,X0,1,T0); inputWas3D = true;
elseif ndims(I) == 4
    Y0 = sz(1); X0 = sz(2); Z0 = sz(3); T0 = sz(4); I4orig = I;
else
    error('Data must be 3D [Y X T] or 4D [Y X Z T].');
end

[selected, applyFlag, st] = ica_v12_gui();

stats = emptyStats(tag);
stats.nComponents = 0;
stats.energyProxyPerComponent = [];
stats.selectedComponents = [];
stats.percentEnergyRemoved = 0;
stats.applied = false;
stats.method = 'ICA (cancelled)';
stats.qcGridFiles = {};
stats.sliceScope = st.scopeInfo;
stats.nIter = st.nIter;
stats.converged = st.converged;

if ~applyFlag
    if ~isempty(opts.onCancel) && isa(opts.onCancel,'function_handle'), try, opts.onCancel(); catch, end, end
    newData.I = I;
    return;
end

K = st.K;
selected = unique(selected(:)');
selected = selected(selected >= 1 & selected <= K);

if ~isempty(opts.onApply) && isa(opts.onApply,'function_handle'), try, opts.onApply(selected); catch, end, end

stats.nComponents = K;
stats.energyProxyPerComponent = st.proxy(:)';
stats.selectedComponents = selected;
stats.percentEnergyRemoved = 100 * sum(st.proxy(selected));
stats.applied = true;
stats.method = 'ICA denoise (V12 slice-aware)';
stats.sliceScope = st.scopeInfo;
stats.nIter = st.nIter;
stats.converged = st.converged;

if isempty(selected)
    newData.I = I;
    return;
end

AvoxSel = st.Avox(:,selected);
TCsel = st.TC(selected,:);
Xclean = st.Xc;
chunkT = max(50, round(opts.chunkT));
for t0 = 1:chunkT:st.T
    t1 = min(st.T, t0 + chunkT - 1);
    recon = AvoxSel * TCsel(:,t0:t1);
    Xclean(:,t0:t1) = Xclean(:,t0:t1) - single(recon);
end

switch lower(opts.centerMode)
    case 'global', Xout = Xclean + single(st.mu);
    otherwise, Xout = bsxfun(@plus, Xclean, st.muVec);
end

IworkOut4 = reshape(Xout, [st.Y st.X st.Z st.T]);
if st.scopeInfo.sliceSpecific && Z0 > 1
    Iout4 = I4orig;
    zUse = st.scopeInfo.zIndex;
    Iout4(:,:,zUse,:) = reshape(IworkOut4(:,:,1,:), [Y0 X0 1 T0]);
else
    Iout4 = IworkOut4;
end

if inputWas3D, newData.I = reshape(Iout4,[Y0 X0 T0]); else, newData.I = Iout4; end
newData.preprocessing = 'ICA denoise (V12 slice-aware)';
newData.pcaicaSliceScope = st.scopeInfo;
stats.qcFile = ''; stats.qcGlobalMeanFile = ''; stats.qcMeanImageFile = '';

    function st = computeICA(scopeInfo)
        if scopeInfo.sliceSpecific && Z0 > 1
            zUse = max(1,min(Z0,round(scopeInfo.zIndex)));
            I4 = reshape(I4orig(:,:,zUse,:), [Y0 X0 1 T0]);
            Y = Y0; X = X0; Z = 1; T = T0;
        else
            I4 = I4orig; Y = Y0; X = X0; Z = Z0; T = T0;
        end
        V = Y*X*Z;
        Xvt = reshape(single(I4), [V T]);
        switch lower(opts.centerMode)
            case 'global', mu = mean(Xvt(:)); Xc = Xvt - single(mu); muVec = [];
            otherwise, muVec = mean(Xvt,2); Xc = bsxfun(@minus,Xvt,muVec); mu = [];
        end
        K = min([opts.nCompMax, T-1, 100]);
        if K < 2, error('Not enough time points for ICA.'); end
        Xtv = double(Xc'); useFallback = false;
        try, [U,S,W] = svds(Xtv,K); catch, useFallback = true; end
        if useFallback
            Ct = Xtv*Xtv'; Ct = (Ct+Ct')*0.5; [U,L] = eigs(Ct,K,'largestreal');
            s = sqrt(max(diag(L),0)); S = diag(s); W = Xtv'*U;
            for ii=1:K, if s(ii)>0, W(:,ii)=W(:,ii)./s(ii); end, end
        end
        sing = diag(S); [sing,ord] = sort(sing(:),'descend'); U = U(:,ord); W = W(:,ord);
        Zwhite = U';
        [B,Sica,fastStats] = fastica_symm(Zwhite, opts.icaMaxIter, opts.icaTol);
        Ared = B';
        Avox = double(W) * diag(double(sing)) * Ared;
        TC = double(Sica);
        proxy = zeros(1,K);
        for kk=1:K, proxy(kk) = sum(Avox(:,kk).^2) * sum(TC(kk,:).^2); end
        if sum(proxy)>0, proxy = proxy./sum(proxy); else, proxy(:)=1/K; end
        [proxy,ord2] = sort(proxy(:)','descend'); TC = TC(ord2,:); Avox = Avox(:,ord2);
        st = struct('TC',TC,'Avox',Avox,'proxy',proxy,'Xc',Xc,'mu',mu,'muVec',muVec, ...
            'Y',Y,'X',X,'Z',Z,'T',T,'K',K,'scopeInfo',scopeInfo,'nIter',fastStats.nIter,'converged',fastStats.converged);
    end

    function [selected, applyFlag, st] = ica_v12_gui()
        bgFig=[0.06 0.06 0.07]; bgAx=[0.09 0.09 0.10]; fg=[0.90 0.90 0.92]; fgDim=[0.70 0.70 0.74]; selRed=[1.00 0.25 0.25]; lineCol=[0.20 0.95 0.35];
        selected=[]; applyFlag=false;
        scopeInfo = struct('mode','all','zIndex',1,'nSlices',Z0,'sliceSpecific',false);
        st = computeICA(scopeInfo);
        K=st.K; T=st.T; maxPts=opts.maxDisplayPoints; idx=getIdx(T,maxPts); tmin=((0:T-1)*TR)/60; tmin=tmin(idx);
        perPage=25; nPages=max(1,ceil(K/perPage)); page=1;
        fig=figure('Name','ICA Components — slice-aware V12', 'Color',bgFig,'MenuBar','none','ToolBar','none','NumberTitle','off', 'Position',[60 40 1800 980]);
        try, HUMoR_force_fullscreen_fig(fig); catch, end
        gridX=0.03; gridY=0.08; gridW=0.66; gridH=0.86; rightX=0.71; rightY=0.08; rightW=0.27; rightH=0.90;
        hdr=uicontrol('Parent',fig,'Style','text','Units','normalized','Position',[gridX 0.965 gridW 0.03],'String','','BackgroundColor',bgFig,'ForegroundColor',fg,'FontSize',13,'FontWeight','bold','HorizontalAlignment','left');
        rightPanel=uipanel('Parent',fig,'Units','normalized','Position',[rightX rightY rightW rightH],'BackgroundColor',[0.08 0.08 0.09],'ForegroundColor',fg,'Title','Selection + Slice Scope','FontWeight','bold','FontSize',13);
        uicontrol('Parent',rightPanel,'Style','text','Units','normalized','Position',[0.06 0.915 0.88 0.055],'String','ICA INPUT SCOPE', 'BackgroundColor',get(rightPanel,'BackgroundColor'),'ForegroundColor',[0.85 0.95 1.00],'FontWeight','bold','FontSize',14);
        scopePopup=uicontrol('Parent',rightPanel,'Style','popupmenu','Units','normalized','Position',[0.06 0.902 0.88 0.043],'String',{'All slices together','Selected slice only'},'Value',1,'BackgroundColor',[0.16 0.16 0.18],'ForegroundColor',fg,'FontWeight','bold','FontSize',12,'Callback',@scopeChanged);
        scopeText=uicontrol('Parent',rightPanel,'Style','text','Units','normalized','Position',[0.06 0.856 0.88 0.041],'String',sprintf('All slices 1-%d',Z0),'BackgroundColor',get(rightPanel,'BackgroundColor'),'ForegroundColor',[1.00 0.95 0.55],'FontWeight','bold','FontSize',13);
        stepSmall=1/max(1,Z0-1);
        scopeSlider=uicontrol('Parent',rightPanel,'Style','slider','Units','normalized','Position',[0.06 0.825 0.88 0.027],'Min',1,'Max',max(1,Z0),'Value',1,'SliderStep',[stepSmall min(1,stepSmall*2)],'Enable','off','Callback',@scopeChanged);
        if Z0 <= 1, set(scopePopup,'Enable','off'); set(scopeSlider,'Enable','off'); set(scopeText,'String','2D / single-slice data'); end
        axPrev=axes('Parent',rightPanel,'Units','normalized','Position',[0.13 0.365 0.75 0.110],'Color',bgAx,'XColor',fg,'YColor',fg); title(axPrev,'IC timecourse','Color',fg);
        axMap=axes('Parent',rightPanel,'Units','normalized','Position',[0.08 0.525 0.75 0.255],'Color',bgAx,'XColor',fg,'YColor',fg); title(axMap,'Spatial weighted map','Color',fg);
        % HUMOR_ICA_ROI_ONLY_CONTROLS_V17
        mapContrast = 1.32;
        mapGamma    = 0.72;
        mapSharp    = 0.32;
        roiRadius   = 5;
        roiShape    = 'Circle';
        roiOverlayH = [];
        roiHoverH   = [];
        currentPreviewK = 1;
        currentMapZ = 1;
        roiTitle = uicontrol('Parent',rightPanel,'Style','text','Units','normalized','Position',[0.855 0.755 0.12 0.030],'String','ROI','BackgroundColor',get(rightPanel,'BackgroundColor'),'ForegroundColor',[0.85 0.95 1.00],'FontWeight','bold','FontSize',10);
        roiShapePopup = uicontrol('Parent',rightPanel,'Style','popupmenu','Units','normalized','Position',[0.845 0.720 0.14 0.032],'String',{'Circle','Square'},'Value',1,'BackgroundColor',[0.16 0.16 0.18],'ForegroundColor',fg,'FontSize',9,'Callback',@updateRoiControls);
        roiSlider = uicontrol('Parent',rightPanel,'Style','slider','Units','normalized','Position',[0.915 0.545 0.038 0.165],'Min',2,'Max',20,'Value',roiRadius,'SliderStep',[1/18 3/18],'Callback',@updateRoiControls);
        roiSizeText = uicontrol('Parent',rightPanel,'Style','text','Units','normalized','Position',[0.855 0.515 0.12 0.030],'String',sprintf('r=%d',roiRadius),'BackgroundColor',get(rightPanel,'BackgroundColor'),'ForegroundColor',[1.00 0.95 0.55],'FontWeight','bold','FontSize',9);
        txtInfo=uicontrol('Parent',rightPanel,'Style','text','Units','normalized','Position',[0.08 0.315 0.84 0.040],'String','Selected: 0 ICs', 'BackgroundColor',get(rightPanel,'BackgroundColor'),'ForegroundColor',[0.85 0.95 1.00],'FontWeight','bold','FontSize',13);
        lb=uicontrol('Parent',rightPanel,'Style','listbox','Units','normalized','Position',[0.08 0.225 0.84 0.080],'String',{'<none>'},'BackgroundColor',[0.16 0.16 0.18],'ForegroundColor',fg,'FontName','Courier New','FontSize',13);
        uicontrol('Parent',rightPanel,'Style','pushbutton','Units','normalized','Position',[0.08 0.135 0.40 0.070],'String','Apply & Close','FontWeight','bold','FontSize',11,'BackgroundColor',[0.20 0.45 0.25],'ForegroundColor','w','Callback',@applyAndClose);
        uicontrol('Parent',rightPanel,'Style','pushbutton','Units','normalized','Position',[0.52 0.135 0.40 0.070],'String','Cancel','FontWeight','bold','FontSize',11,'BackgroundColor',[0.65 0.20 0.20],'ForegroundColor','w','Callback',@cancelAndClose);
        btnPrev=uicontrol('Parent',rightPanel,'Style','pushbutton','Units','normalized','Position',[0.08 0.040 0.25 0.070],'String','< Prev','FontWeight','bold','FontSize',11,'BackgroundColor',[0.12 0.34 0.95],'ForegroundColor','w','Callback',@prevPage);
        btnNext=uicontrol('Parent',rightPanel,'Style','pushbutton','Units','normalized','Position',[0.38 0.040 0.25 0.070],'String','Next >','FontWeight','bold','FontSize',11,'BackgroundColor',[0.12 0.34 0.95],'ForegroundColor','w','Callback',@nextPage);
        uicontrol('Parent',rightPanel,'Style','pushbutton','Units','normalized','Position',[0.68 0.040 0.24 0.070],'String','HELP','FontWeight','bold','FontSize',11,'BackgroundColor',[0.12 0.34 0.95],'ForegroundColor','w','Callback',@showHelp);
        nRow=5; nCol=5; axGrid=gobjects(25,1); lnGrid=gobjects(25,1); pcLabel=gobjects(25,1); compIdx=nan(25,1); pad=0.014; cellW=gridW/nCol; cellH=gridH/nRow;
        for ii=1:25
            r=floor((ii-1)/nCol); c=mod((ii-1),nCol);
            axGrid(ii)=axes('Parent',fig,'Units','normalized','Position',[gridX+c*cellW+pad gridY+(nRow-1-r)*cellH+pad cellW-2*pad cellH-2*pad],'Color',bgAx);
            set(axGrid(ii),'Box','on','LineWidth',1,'XColor',fgDim*0.35,'YColor',fgDim*0.35,'YTick',[]); hold(axGrid(ii),'on');
            lnGrid(ii)=plot(axGrid(ii),tmin,zeros(size(tmin)),'Color',lineCol,'LineWidth',1);
            pcLabel(ii)=text(axGrid(ii),0.02,0.92,'','Units','normalized','Color',fg,'FontSize',10,'FontWeight','bold'); hold(axGrid(ii),'off');
            set(axGrid(ii),'ButtonDownFcn',@(h,~)onCellClick(h)); set(lnGrid(ii),'ButtonDownFcn',@(h,~)onCellClick(h));
        end
        set(fig,'WindowKeyPressFcn',@onKey,'WindowScrollWheelFcn',@onScrollWheel,'WindowButtonMotionFcn',@onMapHover,'CloseRequestFcn',@cancelAndClose); renderPage(); previewComponent(1); uiwait(fig);
        function scopeChanged(~,~)
            if Z0 > 1 && get(scopePopup,'Value') == 2
                z=round(get(scopeSlider,'Value')); z=max(1,min(Z0,z)); set(scopeSlider,'Value',z,'Enable','on');
                scopeInfo=struct('mode','slice','zIndex',z,'nSlices',Z0,'sliceSpecific',true); set(scopeText,'String',sprintf('Selected slice %d of %d — recomputing ICA...',z,Z0));
            else
                set(scopeSlider,'Enable','off'); scopeInfo=struct('mode','all','zIndex',1,'nSlices',Z0,'sliceSpecific',false); set(scopeText,'String',sprintf('All slices 1-%d — recomputing ICA...',Z0));
            end
            drawnow; st=computeICA(scopeInfo); K=st.K; T=st.T; idx=getIdx(T,maxPts); tmin=((0:T-1)*TR)/60; tmin=tmin(idx); selected=[]; page=1; nPages=max(1,ceil(K/perPage)); renderPage(); previewComponent(1);
            if scopeInfo.sliceSpecific, set(scopeText,'String',sprintf('Selected slice %d of %d',scopeInfo.zIndex,Z0)); else, set(scopeText,'String',sprintf('All slices 1-%d',Z0)); end
        end
        function renderPage()
            firstPC=(page-1)*perPage+1; lastPC=min(K,page*perPage); set(hdr,'String',sprintf('ICs %d-%d of %d | %s',firstPC,lastPC,K,scopeLabel()));
            set(btnPrev,'Enable',onoff(page>1)); set(btnNext,'Enable',onoff(page<nPages));
            for jj=1:25
                k=(page-1)*perPage+jj; compIdx(jj)=k;
                if k<=K
                    tc=st.TC(k,:); tc=tc(idx); set(lnGrid(jj),'XData',tmin,'YData',tc,'Visible','on'); set(axGrid(jj),'Visible','on','XLim',[0 max(tmin)],'TickDir','out','FontSize',8); yl = [min(tc) max(tc)]; if isfinite(yl(1)) && isfinite(yl(2)) && yl(2)>yl(1), padY=0.12*(yl(2)-yl(1)); set(axGrid(jj),'YLim',[yl(1)-padY yl(2)+padY]); end; if jj>20, xlabel(axGrid(jj),'Time (min)','Color',[0.85 0.85 0.88],'FontSize',8,'FontWeight','bold'); end; if mod(jj-1,5)==0, ylabel(axGrid(jj),'IC amp','Color',[0.85 0.85 0.88],'FontSize',8,'FontWeight','bold'); end;
                    set(pcLabel(jj),'String',sprintf('IC%d %.2f%%',k,100*st.proxy(k)));
                    if any(selected==k), set(axGrid(jj),'XColor',selRed,'YColor',selRed,'LineWidth',2.2); set(pcLabel(jj),'Color',selRed); else, set(axGrid(jj),'XColor',fgDim*0.35,'YColor',fgDim*0.35,'LineWidth',1); set(pcLabel(jj),'Color',fg); end
                else
                    set(axGrid(jj),'Visible','off');
                end
            end
            refreshSelectionUI(); drawnow;
        end
        function onCellClick(hObj)
            axh=ancestor(hObj,'axes'); if isempty(axh)&&strcmp(get(hObj,'Type'),'axes'), axh=hObj; end
            ii=find(axGrid==axh,1); if isempty(ii), return; end
            k=compIdx(ii); if ~isfinite(k)||k<1||k>K, return; end
            if strcmp(get(fig,'SelectionType'),'alt'), selected(selected==k)=[]; else, if any(selected==k), selected(selected==k)=[]; else, selected(end+1)=k; end, end
            selected=sort(unique(selected)); renderPage(); previewComponent(k);
        end
        function previewComponent(k)
            if k<1 || k>K, return; end
            currentPreviewK = k;

            cla(axPrev);
            plot(axPrev,tmin,st.TC(k,idx),'Color',lineCol,'LineWidth',2.1);
            grid(axPrev,'on');
            set(axPrev,'Color',bgAx,'XColor',fg,'YColor',fg,'FontSize',10,'TickDir','out');
            xlabel(axPrev,'Time (min)','Color',fg,'FontSize',11,'FontWeight','bold');
            ylabel(axPrev,'IC amplitude','Color',fg,'FontSize',10,'FontWeight','bold');
            tcNow = st.TC(k,idx);
            yl = [min(tcNow) max(tcNow)];
            if isfinite(yl(1)) && isfinite(yl(2)) && yl(2)>yl(1)
                padY = 0.20*(yl(2)-yl(1));
                set(axPrev,'YLim',[yl(1)-padY yl(2)+padY]);
            end
            title(axPrev,sprintf('IC%d timecourse | %s',k,scopeLabel()),'Color',fg,'FontWeight','bold');

            cla(axMap,'reset');
            clearHoverRoi();
            try
                mapVec = double(st.Avox(:,k));
                map3 = reshape(mapVec,[st.Y st.X st.Z]);

                if st.Z > 1
                    sliceScore = zeros(1,st.Z);
                    for zz = 1:st.Z
                        tmp = abs(map3(:,:,zz));
                        sliceScore(zz) = max(tmp(:));
                    end
                    [~,zShow] = max(sliceScore);
                else
                    zShow = 1;
                end
                currentMapZ = zShow;

                mapRaw = abs(map3(:,:,zShow));
                mapDisp = enhanceIcaMapClean(mapRaw);

                imgH = imagesc(axMap,mapDisp,[0 1]);
                axis(axMap,'image'); axis(axMap,'off');
                colormap(axMap,hot(256));
                set(imgH,'ButtonDownFcn',@onMapClick,'HitTest','on','PickableParts','all');
                set(axMap,'ButtonDownFcn',@onMapClick,'HitTest','on','PickableParts','all');
                try
                    cb = colorbar(axMap,'eastoutside');
                    set(cb,'Color',fg,'FontSize',8);
                catch
                end

                if st.scopeInfo.sliceSpecific
                    title(axMap,sprintf('Spatial weights | selected slice %d/%d',st.scopeInfo.zIndex,st.scopeInfo.nSlices),'Color',fg,'FontWeight','bold');
                else
                    title(axMap,sprintf('Spatial weights | auto Z=%d',zShow),'Color',fg,'FontWeight','bold');
                end
            catch ME_map
                text(axMap,0.5,0.5,['Map preview error: ' ME_map.message],'Units','normalized','Color',fg,'HorizontalAlignment','center');
                axis(axMap,'off');
            end
        end

        function mapDisp = enhanceIcaMapClean(mapRaw)
            mapRaw = double(mapRaw);
            good = mapRaw(isfinite(mapRaw));
            if isempty(good)
                mapDisp = zeros(size(mapRaw));
                return;
            end
            lo = local_prctile(good,3);
            hi = local_prctile(good,99.2);
            if ~isfinite(hi) || hi <= lo
                hi = max(good(:));
                lo = min(good(:));
            end
            mapDisp = (mapRaw - lo) ./ max(eps,hi-lo);
            mapDisp(mapDisp<0)=0; mapDisp(mapDisp>1)=1;
            ker = [1 2 1; 2 4 2; 1 2 1] / 16;
            smoothMap = conv2(mapDisp,ker,'same');
            mapDisp = 0.58*smoothMap + 0.42*mapDisp;
            mapDisp = mapDisp .* mapContrast;
            mapDisp(mapDisp>1)=1;
            mapDisp = mapDisp .^ mapGamma;
            blur = conv2(mapDisp,ker,'same');
            mapDisp = mapDisp + mapSharp*(mapDisp-blur);
            mapDisp(mapDisp<0)=0; mapDisp(mapDisp>1)=1;
        end

        function updateRoiControls(~,~)
            try
                roiRadius = round(get(roiSlider,'Value'));
                set(roiSizeText,'String',sprintf('r=%d',roiRadius));
                shList = get(roiShapePopup,'String');
                roiShape = shList{get(roiShapePopup,'Value')};
            catch
            end
        end

        function onMapHover(~,~)
            try
                obj = hittest(fig);
                axh = ancestor(obj,'axes');
                if isempty(axh) || axh ~= axMap
                    clearHoverRoi();
                    return;
                end
                pt = get(axMap,'CurrentPoint');
                x = round(pt(1,1));
                y = round(pt(1,2));
                if x < 1 || x > st.X || y < 1 || y > st.Y
                    clearHoverRoi();
                    return;
                end
                updateRoiControls([],[]);
                drawRoiOverlay(x,y,roiRadius,false);
            catch
            end
        end

        function onMapClick(~,~)
            try
                updateRoiControls([],[]);
                pt = get(axMap,'CurrentPoint');
                x = round(pt(1,1));
                y = round(pt(1,2));
                x = max(1,min(st.X,x));
                y = max(1,min(st.Y,y));
                z = max(1,min(st.Z,currentMapZ));

                rr = max(1,round(roiRadius));
                yy = max(1,y-rr):min(st.Y,y+rr);
                xx = max(1,x-rr):min(st.X,x+rr);
                [YY,XX] = ndgrid(yy,xx);
                if strcmpi(roiShape,'Circle')
                    mask = ((XX-x).^2 + (YY-y).^2) <= rr^2;
                else
                    mask = true(size(XX));
                end
                YY = YY(mask); XX = XX(mask);
                ZZ = z * ones(numel(YY),1);
                rows = sub2ind([st.Y st.X st.Z],YY(:),XX(:),ZZ(:));

                roiScores = max(abs(st.Avox(rows,:)),[],1);
                if isempty(roiScores) || max(roiScores) <= 0, return; end
                [scoreSort,ord] = sort(roiScores,'descend');
                keep = ord(scoreSort >= 0.45*scoreSort(1));
                keep = keep(1:min(numel(keep),5));

                if strcmp(get(fig,'SelectionType'),'alt')
                    selected = setdiff(selected,keep);
                    clearFixedRoi();
                    actionTxt = 'removed';
                else
                    selected = sort(unique([selected keep]));
                    drawRoiOverlay(x,y,rr,true);
                    actionTxt = 'selected';
                end

                renderPage();
                previewComponent(currentPreviewK);
                if strcmp(actionTxt,'selected')
                    drawRoiOverlay(x,y,rr,true);
                end
                set(txtInfo,'String',sprintf('ROI %s r=%d %s ICs: %s',roiShape,rr,actionTxt,sprintf('%d ',keep)));
            catch ME_click
                set(txtInfo,'String',['ROI click failed: ' ME_click.message]);
            end
        end

        function drawRoiOverlay(x,y,rr,isFixed)
            axes(axMap); %#ok<LAXES>
            hold(axMap,'on');
            if isFixed
                clearFixedRoi();
                col = [0.00 1.00 1.00];
                lw = 2.2;
                ls = '-';
            else
                clearHoverRoi();
                col = [1.00 1.00 0.10];
                lw = 1.6;
                ls = '--';
            end
            if strcmpi(roiShape,'Circle')
                th = linspace(0,2*pi,120);
                h = plot(axMap,x + rr*cos(th), y + rr*sin(th),'Color',col,'LineWidth',lw,'LineStyle',ls);
            else
                xs = [x-rr x+rr x+rr x-rr x-rr];
                ys = [y-rr y-rr y+rr y+rr y-rr];
                h = plot(axMap,xs,ys,'Color',col,'LineWidth',lw,'LineStyle',ls);
            end
            if isFixed
                roiOverlayH = h;
            else
                roiHoverH = h;
            end
            hold(axMap,'off');
        end

        function clearHoverRoi()
            try, if ~isempty(roiHoverH) && ishghandle(roiHoverH), delete(roiHoverH); end, catch, end
            roiHoverH = [];
        end

        function clearFixedRoi()
            try, if ~isempty(roiOverlayH) && ishghandle(roiOverlayH), delete(roiOverlayH); end, catch, end
            roiOverlayH = [];
        end

        function p = local_prctile(v,prc)
            v = sort(v(:));
            if isempty(v), p = NaN; return; end
            q = 1 + (numel(v)-1) * prc/100;
            lo = floor(q); hi = ceil(q);
            lo = max(1,min(numel(v),lo));
            hi = max(1,min(numel(v),hi));
            if lo == hi
                p = v(lo);
            else
                p = v(lo) + (q-lo) * (v(hi)-v(lo));
            end
        end

        function refreshSelectionUI()



            if isempty(selected), set(lb,'String',{'<none>'}); else, set(lb,'String',arrayfun(@(x)sprintf('IC%-3d  (%.2f%%)',x,100*st.proxy(x)),selected,'UniformOutput',false)); end
            set(txtInfo,'String',sprintf('Selected: %d ICs | Removed %.2f%%',numel(selected),100*sum(st.proxy(selected))));
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
        function showHelp(~,~), msgbox(sprintf('Use scope control at top-right to switch All slices vs Selected slice. Mouse wheel changes slices and recomputes ICA. Click an IC to preview its spatial map. Hover over the spatial map to preview the ROI circle/square. Left-click selects ICs in that ROI; right-click removes them. ROI size/shape are beside the colorbar.'),'ICA help','modal'); end
        function s=scopeLabel(), if st.scopeInfo.sliceSpecific, s=sprintf('slice %d/%d',st.scopeInfo.zIndex,st.scopeInfo.nSlices); else, s=sprintf('all slices 1-%d',Z0); end, end
    end

    function idx = getIdx(T,maxPts)
        if T > maxPts, idx = unique(round(linspace(1,T,maxPts))); else, idx = 1:T; end
    end

    function s = onoff(tf)
        if tf, s='on'; else, s='off'; end
    end
end


function [selected, applyFlag] = ica_selector_gui_grid(TC, proxy, Avox, volSize, TR, maxPts)

T = size(TC,1);
K = size(TC,2);

if T > maxPts
    idx = unique(round(linspace(1, T, maxPts)));
else
    idx = 1:T;
end

tmin_full = ((0:T-1) * TR) / 60;
tmin = tmin_full(idx);
tmax = tmin_full(end);
xticks = niceMinuteTicks(tmax);

selected = [];
applyFlag = false;
% HUMOR_ICA_SCOPE_GUI_V8
if nargin < 4 || isempty(volSize), volSize = [1 1 1]; end
if numel(volSize) < 3, volSize(3) = 1; end
Zscope = max(1, round(volSize(3)));
scopeInfo = struct('mode','all','zIndex',1,'nSlices',Zscope,'sliceSpecific',false);

perPage = 25;
nPages = max(1, ceil(K / perPage));
page = 1;
currentPreviewK = 1;
currentMap2D = [];
currentMapRaw2D = [];
currentMapZ = 1;
currentMapTitle = '';
% HUMOR_ICA_ROI_QUERY_PATCH_V1
roiCenterXY = [];
roiRadiusPix = 8;
roiRankedICs = [];
roiPatchH = [];
roiMarkerH = [];
roiListMax = 12;

% theme
bgFig     = [0.06 0.06 0.07];
bgAx      = [0.09 0.09 0.10];
bgPanel   = [0.08 0.08 0.09];
fg        = [0.90 0.90 0.92];
fgDim     = [0.70 0.70 0.74];
selRed    = [1.00 0.25 0.25];
lineCol   = [0.35 0.80 1.00];

fig = figure('Name','ICA Components - left click select, right click deselect', ...
    'Color',bgFig,'MenuBar','none','ToolBar','none','NumberTitle','off', ...
    'Position',[160 90 1580 900]);
% HUMoR_FORCE_FULLSCREEN_PATCH31
try, HUMoR_force_fullscreen_fig(fig); catch, end


try, set(fig,'Renderer','opengl'); catch, end

gridX = 0.03; gridY = 0.08; gridW = 0.66; gridH = 0.90;
rightX = 0.705; rightY = 0.035; rightW = 0.285; rightH = 0.93;

hdr = uicontrol('Parent',fig,'Style','text','Units','normalized', ...
    'Position',[gridX 0.97 gridW 0.03], ...
    'String','', ...
    'BackgroundColor',bgFig,'ForegroundColor',fg,'FontSize',13,'FontWeight','bold', ...
    'HorizontalAlignment','left');

uicontrol('Parent',fig,'Style','text','Units','normalized', ...
    'Position',[gridX gridY-0.05 gridW 0.03], ...
    'String','Time (min)', ...
    'BackgroundColor',bgFig,'ForegroundColor',fgDim, ...
    'FontSize',11,'FontWeight','bold','HorizontalAlignment','center');

rightPanel = uipanel('Parent',fig,'Units','normalized','Position',[rightX rightY rightW rightH], ...
    'BackgroundColor',bgPanel,'ForegroundColor',fg,'Title','Selection', ...
    'FontWeight','bold','FontSize',12);

% ----------------------------------------------------------
% Timecourse preview (top)
% ----------------------------------------------------------
axPrev = axes('Parent',rightPanel,'Units','normalized','Position',[0.10 0.67 0.82 0.19], ...
    'Color',bgAx,'XColor',fgDim,'YColor',fgDim, ...
    'Box','on','LineWidth',1.0);
title(axPrev,'Preview','Color',fg,'FontWeight','bold');
grid(axPrev,'on');

% ----------------------------------------------------------
% Bigger spatial map preview + separate title text
% ----------------------------------------------------------
mapTitleText = uicontrol('Parent',rightPanel,'Style','text','Units','normalized', ...
    'Position',[0.07 0.605 0.50 0.03], ...
    'String','Spatial weight preview', ...
    'BackgroundColor',bgPanel, ...
    'ForegroundColor',fg, ...
    'HorizontalAlignment','center', ...
    'FontWeight','bold','FontSize',12);

axMap = axes('Parent',rightPanel,'Units','normalized','Position',[0.07 0.36 0.50 0.25], ...
    'Color',bgAx,'XColor',fgDim,'YColor',fgDim, ...
    'Box','on','LineWidth',1.0);

% ----------------------------------------------------------
% Display controls (bigger fonts, tighter layout)
% ----------------------------------------------------------
uicontrol('Parent',rightPanel,'Style','text','Units','normalized', ...
    'Position',[0.58 0.61 0.24 0.03], ...
    'String','Map Display', ...
    'BackgroundColor',bgPanel, ...
    'ForegroundColor',fg, ...
    'HorizontalAlignment','left', ...
    'FontWeight','bold','FontSize',12);

uicontrol('Parent',rightPanel,'Style','text','Units','normalized', ...
    'Position',[0.58 0.545 0.16 0.03], ...
    'String','Contrast', ...
    'BackgroundColor',bgPanel, ...
    'ForegroundColor',fgDim, ...
    'HorizontalAlignment','left', ...
    'FontWeight','bold','FontSize',11);

contrastSlider = uicontrol('Parent',rightPanel,'Style','slider', ...
    'Units','normalized','Position',[0.58 0.512 0.20 0.032], ...
    'Min',0.5,'Max',3.0,'Value',2.0, ...
    'BackgroundColor',[0.18 0.18 0.19], ...
    'Callback',@updateSpatialControls);

contrastValueText = uicontrol('Parent',rightPanel,'Style','text','Units','normalized', ...
    'Position',[0.80 0.510 0.10 0.032], ...
    'String','2.00', ...
    'BackgroundColor',bgPanel, ...
    'ForegroundColor',[0.70 0.90 1.00], ...
    'HorizontalAlignment','left', ...
    'FontWeight','bold','FontSize',10);

uicontrol('Parent',rightPanel,'Style','text','Units','normalized', ...
    'Position',[0.58 0.465 0.16 0.03], ...
    'String','Gamma', ...
    'BackgroundColor',bgPanel, ...
    'ForegroundColor',fgDim, ...
    'HorizontalAlignment','left', ...
    'FontWeight','bold','FontSize',11);

gammaSlider = uicontrol('Parent',rightPanel,'Style','slider', ...
    'Units','normalized','Position',[0.58 0.432 0.20 0.032], ...
    'Min',0.30,'Max',1.50,'Value',0.75, ...
    'BackgroundColor',[0.18 0.18 0.19], ...
    'Callback',@updateSpatialControls);

gammaValueText = uicontrol('Parent',rightPanel,'Style','text','Units','normalized', ...
    'Position',[0.80 0.430 0.10 0.032], ...
    'String','0.75', ...
    'BackgroundColor',bgPanel, ...
    'ForegroundColor',[0.70 0.90 1.00], ...
    'HorizontalAlignment','left', ...
    'FontWeight','bold','FontSize',10);

uicontrol('Parent',rightPanel,'Style','text','Units','normalized', ...
    'Position',[0.58 0.385 0.18 0.03], ...
    'String','Colormap', ...
    'BackgroundColor',bgPanel, ...
    'ForegroundColor',fgDim, ...
    'HorizontalAlignment','left', ...
    'FontWeight','bold','FontSize',11);

mapDropdown = uicontrol('Parent',rightPanel,'Style','popupmenu', ...
    'Units','normalized','Position',[0.58 0.350 0.28 0.038], ...
    'String',{'gray','hot','parula','jet','winter'}, ...
    'Value',2, ...
    'BackgroundColor',[0.18 0.18 0.19], ...
    'ForegroundColor',fg, ...
    'FontSize',11, ...
    'FontWeight','bold', ...
    'Callback',@updateSpatialControls);

% HUMOR_ICA_ROI_QUERY_PATCH_V1: click spatial map, rank ICs by ROI spatial weights
uicontrol('Parent',rightPanel,'Style','text','Units','normalized', ...
    'Position',[0.58 0.305 0.17 0.03], ...
    'String','ROI size', ...
    'BackgroundColor',bgPanel, ...
    'ForegroundColor',fgDim, ...
    'HorizontalAlignment','left', ...
    'FontWeight','bold','FontSize',11);

roiRadiusSlider = uicontrol('Parent',rightPanel,'Style','slider', ...
    'Units','normalized','Position',[0.70 0.305 0.16 0.03], ...
    'Min',2,'Max',40,'Value',roiRadiusPix, ...
    'BackgroundColor',[0.18 0.18 0.19], ...
    'Callback',@updateRoiRadius);

roiRadiusValueText = uicontrol('Parent',rightPanel,'Style','text','Units','normalized', ...
    'Position',[0.87 0.302 0.07 0.032], ...
    'String',sprintf('%d px', roiRadiusPix), ...
    'BackgroundColor',bgPanel, ...
    'ForegroundColor',[0.70 0.90 1.00], ...
    'HorizontalAlignment','left', ...
    'FontWeight','bold','FontSize',10);

uicontrol('Parent',rightPanel,'Style','text','Units','normalized', ...
    'Position',[0.58 0.252 0.34 0.03], ...
    'String','ROI-ranked ICs: click row to preview', ...
    'BackgroundColor',bgPanel, ...
    'ForegroundColor',fg, ...
    'HorizontalAlignment','left', ...
    'FontWeight','bold','FontSize',10);

roiResultList = uicontrol('Parent',rightPanel,'Style','listbox','Units','normalized', ...
    'Position',[0.58 0.165 0.34 0.075], ...
    'String',{'Click spatial map to rank ICs'}, ...
    'BackgroundColor',[0.16 0.16 0.18], ...
    'ForegroundColor',fg, ...
    'FontName','Courier New', ...
    'FontSize',9, ...
    'Callback',@onRoiListClick);

txtInfo = uicontrol('Parent',rightPanel,'Style','text','Units','normalized', ...
    'Position',[0.10 0.295 0.45 0.04], ...
    'String','Selected: 0 ICs | Removed: 0.00%', ...
    'BackgroundColor',bgPanel, ...
    'ForegroundColor',[0.70 0.90 1.00], ...
    'FontSize',11,'FontWeight','bold', ...
    'HorizontalAlignment','left');

uicontrol('Parent',rightPanel,'Style','text','Units','normalized', ...
    'Position',[0.10 0.252 0.45 0.03], ...
    'String','Selected for removal:', ...
    'BackgroundColor',bgPanel, ...
    'ForegroundColor',fg, ...
    'HorizontalAlignment','left', ...
    'FontWeight','bold','FontSize',11);

lb = uicontrol('Parent',rightPanel,'Style','listbox','Units','normalized', ...
    'Position',[0.10 0.165 0.45 0.075], ...
    'String',{'<none>'}, ...
    'BackgroundColor',[0.16 0.16 0.18], ...
    'ForegroundColor',fg, ...
    'FontName','Courier New', ...
    'FontSize',11);

uicontrol('Parent',rightPanel,'Style','pushbutton','Units','normalized', ...
    'Position',[0.10 0.082 0.38 0.075], 'String','Apply & Close', ...
    'FontWeight','bold','FontSize',12, ...
    'BackgroundColor',[0.20 0.45 0.25], 'ForegroundColor','w', ...
    'Callback',@applyAndClose);

uicontrol('Parent',rightPanel,'Style','pushbutton','Units','normalized', ...
    'Position',[0.54 0.082 0.38 0.075], 'String','Cancel', ...
    'FontWeight','bold','FontSize',12, ...
    'BackgroundColor',[0.65 0.20 0.20], 'ForegroundColor','w', ...
    'Callback',@cancelAndClose);

btnPrev = uicontrol('Parent',rightPanel,'Style','pushbutton','Units','normalized', ...
    'Position',[0.10 0.012 0.24 0.062], 'String','Prev', ...
    'FontWeight','bold','FontSize',11, ...
    'BackgroundColor',[0.22 0.22 0.25], 'ForegroundColor','w', ...
    'Callback',@prevPage);

btnNext = uicontrol('Parent',rightPanel,'Style','pushbutton','Units','normalized', ...
    'Position',[0.38 0.012 0.24 0.062], 'String','Next', ...
    'FontWeight','bold','FontSize',11, ...
    'BackgroundColor',[0.22 0.22 0.25], 'ForegroundColor','w', ...
    'Callback',@nextPage);

uicontrol('Parent',rightPanel,'Style','pushbutton','Units','normalized', ...
    'Position',[0.66 0.012 0.26 0.062], 'String','HELP', ...
    'FontWeight','bold','FontSize',11, ...
    'BackgroundColor',[0.10 0.35 0.95], 'ForegroundColor','w', ...
    'Callback',@showHelp);



% Build 5x5 axes like PCA
nRow = 5; nCol = 5;
axGrid = gobjects(25,1);
lnGrid = gobjects(25,1);
icLabel = gobjects(25,1);
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

    icLabel(i) = text(axGrid(i), 0.02, 0.92, '', ...
        'Units','normalized', 'Color',fg, 'FontSize',11, ...
        'FontWeight','bold', 'Interpreter','none');

    hold(axGrid(i),'off');

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
        firstIC = (page-1)*perPage + 1;
        lastIC  = min(K, page*perPage);
        set(hdr,'String',sprintf('ICs %d-%d of %d   (Page %d/%d)', firstIC, lastIC, K, page, nPages));

        set(btnPrev,'Enable', onoff(page>1));
        set(btnNext,'Enable', onoff(page<nPages));

        for i2 = 1:25
            k = (page-1)*perPage + i2;
            compIdx(i2) = k;

            if k <= K
                tc = TC(:,k);
                tc = tc(idx);

                set(lnGrid(i2),'XData',tmin,'YData',tc,'Visible','on');
                set(axGrid(i2),'XLim',[0 tmax]);

                rr = floor((i2-1)/nCol);
                if rr == (nRow-1)
                    set(axGrid(i2),'XTick',xticks, ...
                        'XTickLabel',arrayfun(@(x)sprintf('%d',round(x)),xticks,'uni',0), ...
                        'XColor',fgDim);
                else
                    set(axGrid(i2),'XTick',[], 'XTickLabel',{}, 'XColor',fgDim*0.35);
                end

                s = sprintf('IC%d  %.2f%%', k, 100*proxy(k));
                set(icLabel(i2),'String',s);

                if any(selected == k)
                    set(axGrid(i2),'XColor',selRed,'YColor',selRed,'LineWidth',2.2);
                    set(icLabel(i2),'Color',selRed);
                else
                    set(axGrid(i2),'XColor',fgDim*0.35,'YColor',fgDim*0.35,'LineWidth',1.0);
                    set(icLabel(i2),'Color',fg);
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
        currentPreviewK = k; %#ok<NASGU>

        cla(axPrev);
        tc = TC(:,k);
        tc = tc(idx);

        plot(axPrev, tmin, tc, 'LineWidth', 1.6, 'Color', lineCol);
        grid(axPrev,'on');
        set(axPrev,'XColor',fgDim,'YColor',fgDim,'Color',bgAx);
        title(axPrev, sprintf('IC%d | %.2f%%', k, 100*proxy(k)), 'Color',fg, 'FontWeight','bold');
        xlabel(axPrev,'Time (min)','Color',fgDim);
        ylabel(axPrev,'Amplitude (a.u.)','Color',fgDim);
        set(axPrev,'XLim',[0 tmax], 'XTick',xticks);

        mapk = reshape(Avox(:,k), volSize);

        if volSize(3) > 1
            if exist('scopePopup','var') && ishghandle(scopePopup) && get(scopePopup,'Value') == 2
                zShow = round(get(scopeSlider,'Value'));
                zShow = max(1,min(volSize(3),zShow));
            else
                sliceScore = zeros(1, volSize(3));
                for zz = 1:volSize(3)
                    tmp = abs(mapk(:,:,zz));
                    sliceScore(zz) = max(tmp(:));
                end
                [~, zShow] = max(sliceScore);
            end
            currentMapZ = zShow;
            currentMapRaw2D = double(mapk(:,:,zShow));
            currentMap2D = abs(currentMapRaw2D);
            currentMapTitle = sprintf('Spatial weight preview (Z=%d)', zShow);
        else
            currentMapZ = 1;
            currentMapRaw2D = double(mapk(:,:,1));
            currentMap2D = abs(currentMapRaw2D);
            currentMapTitle = 'Spatial weight preview';
        end

        refreshSpatialPreview();
        safeDrawnow();
    end

    function refreshSpatialPreview()
        cla(axMap);

        if isempty(currentMap2D)
            return;
        end

        map2 = double(currentMap2D);

        lo = prctile(map2(:), 5);
        hi = prctile(map2(:), 99);

        if ~isfinite(lo), lo = min(map2(:)); end
        if ~isfinite(hi), hi = max(map2(:)); end
        if hi <= lo
            hi = lo + eps;
        end

        map2 = (map2 - lo) / (hi - lo);
        map2 = max(0, min(1, map2));

        previewContrast = get(contrastSlider,'Value');
        previewGamma    = get(gammaSlider,'Value');

        map2 = map2 * previewContrast;
        map2 = max(0, min(1, map2));
        map2 = map2 .^ previewGamma;

        hImg = imagesc(axMap, map2, [0 1]);
        try, set(hImg,'ButtonDownFcn',@onMapClick,'HitTest','on'); catch, end
        try, set(axMap,'ButtonDownFcn',@onMapClick,'HitTest','on'); catch, end
        try, set(axMap,'PickableParts','all'); catch, end
        axis(axMap,'image');
        axis(axMap,'off');

        set(mapTitleText,'String',currentMapTitle);

        maps = get(mapDropdown,'String');
        cmapName = maps{get(mapDropdown,'Value')};
        colormap(axMap, cmapName);
        drawRoiOverlay();
    end

    function onMapClick(~,~)
        if isempty(currentMapRaw2D)
            return;
        end
        cp = get(axMap,'CurrentPoint');
        x = round(cp(1,1));
        y = round(cp(1,2));
        if x < 1 || x > volSize(2) || y < 1 || y > volSize(1)
            return;
        end
        roiCenterXY = [x y];
        rankIcsAtRoi();
        refreshSpatialPreview();
        safeDrawnow();
    end

    function updateRoiRadius(~,~)
        roiRadiusPix = round(get(roiRadiusSlider,'Value'));
        if roiRadiusPix < 2, roiRadiusPix = 2; end
        set(roiRadiusSlider,'Value',roiRadiusPix);
        set(roiRadiusValueText,'String',sprintf('%d px', roiRadiusPix));
        if ~isempty(roiCenterXY)
            rankIcsAtRoi();
            refreshSpatialPreview();
        end
        safeDrawnow();
    end

    function rankIcsAtRoi()
        if isempty(roiCenterXY)
            return;
        end
        yDim = volSize(1);
        xDim = volSize(2);
        zDim = volSize(3);
        zUse = max(1, min(zDim, currentMapZ));

        [xx, yy] = meshgrid(1:xDim, 1:yDim);
        roiMask = ((xx - roiCenterXY(1)).^2 + (yy - roiCenterXY(2)).^2) <= roiRadiusPix.^2;
        if ~any(roiMask(:))
            roiRankedICs = [];
            set(roiResultList,'String',{'ROI outside map'},'Value',1);
            return;
        end

        roiScore = zeros(1,K);
        roiSigned = zeros(1,K);
        roiLocal = zeros(1,K);
        for kk = 1:K
            mk = reshape(Avox(:,kk), volSize);
            m2 = double(mk(:,:,zUse));
            vals = m2(roiMask);
            roiScore(kk) = mean(abs(vals(:)));
            roiSigned(kk) = mean(vals(:));
            denom = prctile(abs(m2(:)),99);
            if ~isfinite(denom) || denom <= eps
                denom = max(abs(m2(:)));
            end
            if isfinite(denom) && denom > eps
                roiLocal(kk) = 100 * roiScore(kk) / denom;
            else
                roiLocal(kk) = 0;
            end
        end

        totalScore = sum(roiScore);
        if totalScore > eps
            roiPct = 100 * roiScore ./ totalScore;
        else
            roiPct = zeros(size(roiScore));
        end

        [~, ord] = sort(roiScore, 'descend');
        nShow = min(roiListMax, numel(ord));
        roiRankedICs = ord(1:nShow);

        out = cell(nShow+1,1);
        out{1} = sprintf('ROI x=%d y=%d z=%d r=%dpx', roiCenterXY(1), roiCenterXY(2), zUse, roiRadiusPix);
        for rr = 1:nShow
            kk = roiRankedICs(rr);
            if roiSigned(kk) >= 0
                sg = '+';
            else
                sg = '-';
            end
            out{rr+1} = sprintf('%02d) IC%-3d ROI %5.1f%% loc %5.1f%% %s E %4.1f%%', rr, kk, roiPct(kk), roiLocal(kk), sg, 100*proxy(kk));
        end
        set(roiResultList,'String',out,'Value',1);
    end

    function drawRoiOverlay()
        if isempty(roiCenterXY) || isempty(currentMap2D)
            return;
        end
        hold(axMap,'on');
        th = linspace(0, 2*pi, 120);
        x = roiCenterXY(1) + roiRadiusPix * cos(th);
        y = roiCenterXY(2) + roiRadiusPix * sin(th);
        roiPatchH = plot(axMap, x, y, 'w-', 'LineWidth', 1.5); %#ok<NASGU>
        roiMarkerH = plot(axMap, roiCenterXY(1), roiCenterXY(2), 'wo', 'MarkerSize', 5, 'LineWidth', 1.3); %#ok<NASGU>
        try, set(roiPatchH,'ButtonDownFcn',@onMapClick,'HitTest','on'); catch, end
        try, set(roiMarkerH,'ButtonDownFcn',@onMapClick,'HitTest','on'); catch, end
        hold(axMap,'off');
    end

    function onRoiListClick(~,~)
        if isempty(roiRankedICs)
            return;
        end
        val = get(roiResultList,'Value');
        if val <= 1
            return;
        end
        rr = val - 1;
        if rr < 1 || rr > numel(roiRankedICs)
            return;
        end
        k = roiRankedICs(rr);
        page = max(1, min(nPages, ceil(k / perPage)));
        renderPage();
        previewComponent(k);
    end

    function updateSpatialControls(~,~)
        set(contrastValueText,'String',sprintf('%.2f', get(contrastSlider,'Value')));
        set(gammaValueText,'String',sprintf('%.2f', get(gammaSlider,'Value')));
        refreshSpatialPreview();
        safeDrawnow();
    end

    function refreshSelectionUI()
        if isempty(selected)
            set(lb,'String',{'<none>'},'Value',1);
        else
            s = arrayfun(@(x)sprintf('IC%-3d  (%.2f%%)', x, 100*proxy(x)), selected, 'uni',0);
            set(lb,'String',s,'Value',1);
        end
        pct = 100 * sum(proxy(selected));
        set(txtInfo,'String',sprintf('Selected: %d ICs | Removed: %.2f%%', numel(selected), pct));
        safeDrawnow();
    end

    function prevPage(~,~)
        if page > 1
            page = page - 1;
            renderPage();
            previewComponent((page-1)*perPage + 1);
        end
    end

    function nextPage(~,~)
        if page < nPages
            page = page + 1;
            renderPage();
            previewComponent((page-1)*perPage + 1);
        end
    end

    function showHelp(~,~)
        msg = {
            'What ICA does'
            ''
            'ICA first whitens the data using PCA, then finds statistically independent components.'
            'Each IC has a timecourse and a spatial weight map.'
            ''
            'Spatial weight preview'
            'This shows where that IC contributes strongly across voxels.'
            'Click the spatial map to define an ROI and rank ICs by local spatial weight.'
            'Use ROI size to scale the circular query region.'
            'Click a row in ROI-ranked ICs to preview that component.'
            'Use the small Contrast/Gamma/Colormap controls only for display.'
            ''
            'Display hints'
            '  Lower gamma (< 1) brightens weak structures.'
            '  Higher contrast makes strong IC weights more visible.'
            '  Gray is often easiest for anatomical-style inspection.'
            ''
            'How to use it'
            '  - Remove ICs that look like drift, edge artifact, stripes, motion bursts, or non-biological patterns.'
            '  - Keep ICs that look anatomically plausible or stimulus-related.'
            ''
            'Controls'
            '  Left click  : toggle select'
            '  Right click : deselect'
            '  Prev/Next   : page through ICs'
            '  Apply       : apply removal and close'
            '  Cancel      : close with no changes'
            ''
            'Important'
            'ICA is more powerful than PCA for source separation, but easier to misuse.'
            'Always review both timecourse and spatial map before removing an IC.'
            };
        helpdlg(msg,'ICA Help');
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
% Symmetric FastICA
% ======================================================================
function [B, Sica, out] = fastica_symm(Z, maxIter, tol)

K = size(Z,1);
T = size(Z,2);

rng('default');

B = randn(K,K);
[uu,~,vv] = svd(B, 'econ');
B = uu * vv';

converged = false;
nIter = 0;

for it = 1:maxIter
    nIter = it;

    Y = B * Z;
    G = tanh(Y);
    Gp = 1 - G.^2;

    Bnew = (G * Z') / T - diag(mean(Gp,2)) * B;

    [u2,~,v2] = svd(Bnew, 'econ');
    Bnew = u2 * v2';

    lim = max(abs(abs(diag(Bnew * B')) - 1));
    B = Bnew;

    if lim < tol
        converged = true;
        break;
    end
end

Sica = B * Z;

out = struct();
out.nIter = nIter;
out.converged = converged;
end

% ======================================================================
% QC plots
% ======================================================================
function make_qc_plot_selected_ica(proxy, selected, outFile)

qcBlue = [0.00 0.15 0.55];
qcSel  = [0.15 0.15 0.15];
qcEdge = [0.85 0.10 0.10];

fig = figure('Visible','off','Color','w','Position',[100 100 1100 380]);
ax = axes('Parent',fig);

bar(ax, 100*proxy(:), 'FaceColor', qcBlue, 'EdgeColor', 'none');
hold(ax,'on');

if ~isempty(selected)
    bar(ax, selected, 100*proxy(selected), 'FaceColor', qcSel, 'EdgeColor', qcEdge, 'LineWidth', 1.2);
end

xlabel(ax,'IC index');
ylabel(ax,'Energy proxy (%)');
title(ax,'ICA component energy proxy (dark bars = removed ICs)');
grid(ax,'on');
set(ax,'LineWidth',1.2,'FontSize',11,'GridAlpha',0.25);

saveas(fig, outFile);
close(fig);
end

function make_qc_globalmean_plot_ica(gb, ga, TR, outFile)

T = numel(gb);
tmin = ((0:T-1)*TR)/60;

qcBlue  = [0.00 0.15 0.55];
qcAfter = [0.20 0.20 0.20];

fig = figure('Visible','off','Color','w','Position',[120 120 1100 380]);
ax = axes('Parent',fig);

plot(ax, tmin, double(gb), 'LineWidth', 1.9, 'Color', qcBlue); hold(ax,'on');
plot(ax, tmin, double(ga), 'LineWidth', 1.9, 'Color', qcAfter);

grid(ax,'on');
xlabel(ax,'Time (min)');
ylabel(ax,'Global mean intensity');
legend(ax, {'Before','After'}, 'Location','best');
title(ax,'Global mean intensity: before vs after ICA removal');

set(ax,'LineWidth',1.2,'FontSize',11,'GridAlpha',0.25);

saveas(fig, outFile);
close(fig);
end

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

function files = make_qc_grid_dark_exact_ica(TC, proxy, TR, selected, qcDir, tag)

files = {};
K = size(TC,2);
T = size(TC,1);

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

savePages = false(1,nPages);
savePages(1) = true;
for s = selected(:)'
    p = ceil(s/perPage);
    if p >= 1 && p <= nPages
        savePages(p) = true;
    end
end

bgFig   = [0.06 0.06 0.07];
bgAx    = [0.09 0.09 0.10];
fg      = [0.90 0.90 0.92];
fgDim   = [0.70 0.70 0.74];
selRed  = [1.00 0.25 0.25];
lineCol = [0.35 0.80 1];
lineW   = 1.35;

for p = 1:nPages
    if ~savePages(p), continue; end

    fig = figure('Visible','off','Color',bgFig,'Position',[80 60 1500 860]);

    annotation(fig,'textbox',[0.03 0.965 0.66 0.03], ...
        'String',sprintf('ICA grid (exact look) - Page %d/%d - tag=%s', p, nPages, tag), ...
        'Color',fg,'FontSize',13,'FontWeight','bold','EdgeColor','none', ...
        'Interpreter','none','HorizontalAlignment','left');

    annotation(fig,'textbox',[0.03 0.03 0.66 0.03], ...
        'String','Time (min)', ...
        'Color',fgDim,'FontSize',11,'FontWeight','bold','EdgeColor','none', ...
        'Interpreter','none','HorizontalAlignment','center');

    gridX=0.03; gridY=0.08; gridW=0.66; gridH=0.90;
    nRow=5; nCol=5;
    pad=0.014; cellW=gridW/nCol; cellH=gridH/nRow;

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
            tc = TC(:,k); tc = tc(idx);
            plot(ax, tmin, tc, 'LineWidth', lineW, 'Color', lineCol);
            grid(ax,'on');

            rr = floor((i-1)/nCol);
            if rr == (nRow-1)
                set(ax,'XTick',xticks,'XTickLabel',arrayfun(@(x)sprintf('%d',round(x)),xticks,'uni',0), ...
                    'XColor',fgDim);
            else
                set(ax,'XTick',[],'XTickLabel',{}, 'XColor',fgDim*0.35);
            end

            isSel = any(selected == k);
            labCol = fg; boxCol = fgDim*0.35; lw = 1.0;

            if isSel
                boxCol = selRed; lw = 2.2; labCol = selRed;
                text(ax,0.02,0.78,'REMOVED', 'Units','normalized', ...
                    'Color',selRed,'FontWeight','bold','FontSize',10,'Interpreter','none');
            end

            text(ax,0.02,0.92,sprintf('IC%d  %.2f%%',k,100*proxy(k)), 'Units','normalized', ...
                'Color',labCol,'FontWeight','bold','FontSize',10,'Interpreter','none');

            set(ax,'XColor',boxCol,'YColor',boxCol,'LineWidth',lw);
        else
            axis(ax,'off');
        end
    end

    outFile = fullfile(qcDir, sprintf('ICA_grid_dark_page%02d_%s.png', p, tag));
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
s.percentEnergyRemoved = 0;
s.energyProxyPerComponent = [];
s.qcFile = '';
s.qcGlobalMeanFile = '';
s.qcMeanImageFile = '';
s.qcGridFiles = {};
s.nComponents = 0;
s.method = '';
s.applied = false;
s.nIter = 0;
s.converged = false;
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
