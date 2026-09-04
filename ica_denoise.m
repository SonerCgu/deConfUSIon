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
        try, deConfUSIon_force_fullscreen_fig(fig); catch, end
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


function out = onoff(tf)
if tf, out = 'on'; else, out = 'off'; end
end

