function cfg = deConfUSIon_drift_dialog(defaults)
% Drift Compensation dialog with inline CompCor / GLM artefact / CCA options.
% No second popup after Run.
if nargin < 1 || isempty(defaults), defaults = struct(); end
cfg = struct('cancelled',true);
FONT = 'Arial';
TR = 1;
if isfield(defaults,'TR') && ~isempty(defaults.TR)
    try, TR = double(defaults.TR(end)); catch, TR = 1; end
end
nFrames = NaN;
if isfield(defaults,'nFrames') && ~isempty(defaults.nFrames)
    try, nFrames = double(defaults.nFrames); catch, nFrames = NaN; end
end
runLen = NaN;
if isfinite(nFrames) && nFrames > 0 && isfinite(TR) && TR > 0, runLen = nFrames * TR; end
imgData = [];
if isfield(defaults,'I') && ~isempty(defaults.I), imgData = defaults.I; end
startRoot = pwd;
if isfield(defaults,'exportPath') && ~isempty(defaults.exportPath)
    try
        if exist(defaults.exportPath,'dir')==7
            pp = fileparts(defaults.exportPath);
            if ~isempty(pp) && exist(pp,'dir')==7, startRoot = pp; else, startRoot = defaults.exportPath; end
        end
    catch
    end
end

mKey = {'pacap_response','glm','compcor','anchor','vehicle','spline','robust','baseline','poly','dct','reference'};
mName = { ...
    'PACAP RESPONSE - early protected / delayed drift', ...
    'GLM - response + artefact / CCA', ...
    'COMPCOR - confound regression', ...
    'ANCHOR - baseline + tail', ...
    'VEHICLE - subtract aCSF scan', ...
    'SPLINE - robust piecewise', ...
    'ROBUST - down-weighted fit', ...
    'BASELINE ONLY - extrapolated', ...
    'POLYNOMIAL - plain detrend', ...
    'DCT - high-pass', ...
    'REFERENCE - single ROI'};
mRank = 1:numel(mKey);
mDesc = { ...
    'Estimates PACAP-specific response beta/amplitude maps while modelling drift and artefacts separately. Corrected movie is saved mainly for QC.', ...
    'Joint GLM: drift + protected response + optional injection artefact / ROI / custom / CCA nuisance regressors. Only nuisance is removed.', ...
    'Paper-style confound regression: Global signal, tCompCor, aCompCor, Random CompCor, or Low-variance CompCor.', ...
    'Fits trend on baseline and late tail, then interpolates drift between them.', ...
    'Subtracts matched vehicle/aCSF scan in fractional-change space.', ...
    'Robust piecewise-linear drift model with long knots.', ...
    'Whole-run robust polynomial with response outlier down-weighting.', ...
    'Fits only baseline and extrapolates across the run.', ...
    'Classic whole-run polynomial detrend.', ...
    'Discrete-cosine high-pass style drift model.', ...
    'Regresses out mean time course of one selected non-responsive region.'};
mCav = { ...
    'This is an estimator, not magic cleaning. If artefact and PACAP timing are inseparable, trust beta/QC plus vehicle control more than the corrected movie.', ...
    'Persistent artefacts and persistent drug responses can be hard to separate. Inspect QC.', ...
    'aCompCor requires a deliberately painted non-responsive / WM-CSF-like ROI. tCompCor and low-var are automatic.', ...
    'Assumes response has mostly returned in the tail window.', ...
    'Needs matching vehicle/aCSF scan on same spatial grid.', ...
    'Too fine knot spacing can fit real response.', ...
    'Works best when response occupies limited part of run.', ...
    'Extrapolation can be unstable for long runs.', ...
    'Can absorb sustained response.', ...
    'Cannot separate slow response from drift.', ...
    'Single ROI cannot capture spatially uneven artefacts.'};
mOpts = { ...
    {'order','inj','resp','artmode','artpulse','arttaus','artflags','artnpc','artroi','ccaroi'}, ...
    {'order','inj','resp','artmode','artpulse','arttaus','artflags','artnpc','artroi','ccaroi'}, ...
    {'ccmode','ncomp','ccfrac','ccprotect','ccseed','roi'}, ...
    {'order','tail'}, ...
    {'scans'}, ...
    {'knot'}, ...
    {'order'}, ...
    {'order'}, ...
    {'order'}, ...
    {'cutoff'}, ...
    {'roi'}};

sel = 1;
if isfield(defaults,'method') && ~isempty(defaults.method)
    ix = find(strcmpi(mKey,strtrim(defaults.method)),1);
    if ~isempty(ix), sel = ix; end
end

orderSel = 3;
restoreSel = 1;
fileList = {};
fileLabels = {};
roiMask = [];
artifactMask = [];
ccaNoiseMask = [];

BG=[0.03 0.03 0.03]; PAN=[0.09 0.09 0.10]; CARD=[0.16 0.16 0.18];
FLD=[0.13 0.13 0.15]; WHT=[1 1 1]; DIM=[0.70 0.70 0.73];
ACC=[0.15 0.62 0.96]; GOLD=[1 0.76 0.22]; MINT=[0.20 0.85 0.60]; RED=[1 0.45 0.40];

f = figure('Name','Drift Compensation','NumberTitle','off','MenuBar','none','ToolBar','none', ...
    'Color',BG,'Units','normalized','WindowStyle','modal','DefaultUicontrolFontName',FONT);
set(f,'Units','normalized','OuterPosition',[0 0 1 1]);

uicontrol(f,'Style','text','String','SIGNAL DRIFT COMPENSATION', ...
    'Units','normalized','Position',[0.02 0.945 0.55 0.04], ...
    'BackgroundColor',BG,'ForegroundColor',WHT,'FontName',FONT,'FontSize',24,'FontWeight','bold', ...
    'HorizontalAlignment','left');
uicontrol(f,'Style','text','String','Select a method on the left. CompCor, artefact and CCA settings stay visible on the right.', ...
    'Units','normalized','Position',[0.021 0.915 0.86 0.028], ...
    'BackgroundColor',BG,'ForegroundColor',DIM,'FontName',FONT,'FontSize',12,'HorizontalAlignment','left');

pL = uipanel(f,'Title','  METHOD  ','Units','normalized','Position',[0.02 0.20 0.26 0.70], ...
    'BackgroundColor',PAN,'ForegroundColor',ACC,'FontName',FONT,'FontSize',14,'FontWeight','bold');
hM = zeros(1,numel(mKey));
hgt = 0.088; gap = 0.007; y0 = 0.975-hgt;
for ii=1:numel(mKey)
    if mRank(ii)<=3
        lbl = sprintf('%s\nRECOMMENDED #%d',mName{ii},mRank(ii));
    else
        lbl = mName{ii};
    end
    hM(ii)=uicontrol(pL,'Style','pushbutton','String',lbl,'Units','normalized', ...
        'Position',[0.04 y0-(ii-1)*(hgt+gap) 0.92 hgt],'FontName',FONT,'FontSize',10.5, ...
        'Callback',@(a,b)setSel(ii));
end

pD = uipanel(f,'Title','  DETAILS  ','Units','normalized','Position',[0.30 0.20 0.68 0.70], ...
    'BackgroundColor',PAN,'ForegroundColor',ACC,'FontName',FONT,'FontSize',14,'FontWeight','bold');
hTitle = uicontrol(pD,'Style','text','Units','normalized','Position',[0.03 0.900 0.94 0.060], ...
    'BackgroundColor',PAN,'ForegroundColor',WHT,'FontName',FONT,'FontSize',18,'FontWeight','bold','HorizontalAlignment','left');
hDesc = uicontrol(pD,'Style','text','Units','normalized','Position',[0.03 0.760 0.94 0.130], ...
    'BackgroundColor',PAN,'ForegroundColor',WHT,'FontName',FONT,'FontSize',12,'HorizontalAlignment','left');
hCav = uicontrol(pD,'Style','text','Units','normalized','Position',[0.03 0.690 0.94 0.060], ...
    'BackgroundColor',PAN,'ForegroundColor',GOLD,'FontName',FONT,'FontSize',11,'FontWeight','bold','HorizontalAlignment','left');

G = struct();
G.order.lab=mkLab('Trend order');
G.order.b=[mkBtn('0 mean',@(a,b)setOrder(1)),mkBtn('1 linear',@(a,b)setOrder(2)),mkBtn('2 quad',@(a,b)setOrder(3)),mkBtn('3 cubic',@(a,b)setOrder(4))];
G.inj.lab=mkLab('Injection time [s]'); G.inj.e1=mkEd('60');
G.resp.lab=mkLab('Response length [s]'); G.resp.e1=mkEd(defStr(0.25*runLen));
G.tail.lab=mkLab('Tail window [s]'); G.tail.e1=mkEd(defStr(0.75*runLen)); G.tail.e2=mkEd(defStr(runLen));
G.ncomp.lab=mkLab('Components / PCs'); G.ncomp.e1=mkEd('5');
G.knot.lab=mkLab('Knot spacing [s]'); G.knot.e1=mkEd('120');
G.cutoff.lab=mkLab('Cutoff period [s]'); G.cutoff.e1=mkEd('240');

G.ccmode.lab=mkLab('CompCor mode');
G.ccmode.pop=uicontrol(pD,'Style','popupmenu', ...
    'String',{'Global brain signal','tCompCor - high temporal SD','aCompCor - painted non-responsive ROI','Random CompCor','Low-variance CompCor'}, ...
    'Units','normalized','BackgroundColor',FLD,'ForegroundColor',WHT,'FontName',FONT,'FontSize',11,'Visible','off');
G.ccfrac.lab=mkLab('Auto-mask voxel fraction'); G.ccfrac.e1=mkEd('0.05');
G.ccprotect.lab=mkLab('Response protection');
G.ccprotect.cb=uicontrol(pD,'Style','checkbox','String','exclude response-like noise voxels', ...
    'Units','normalized','Value',1,'BackgroundColor',PAN,'ForegroundColor',WHT,'FontName',FONT,'FontSize',10.5,'Visible','off');
G.ccseed.lab=mkLab('Random seed'); G.ccseed.e1=mkEd('1');

G.roi.lab=mkLab('ROI');
G.roi.b1=uicontrol(pD,'Style','pushbutton','String','Paint ROI', ...
    'Units','normalized','BackgroundColor',ACC,'ForegroundColor',WHT,'FontName',FONT,'FontSize',11,'FontWeight','bold','Visible','off','Callback',@(a,b)pickROI());
G.roi.t=uicontrol(pD,'Style','text','String','not selected', ...
    'Units','normalized','BackgroundColor',PAN,'ForegroundColor',DIM,'FontName',FONT,'FontSize',10.5,'HorizontalAlignment','left','Visible','off');

G.artmode.lab=mkLab('Artefact / CCA model');
G.artmode.pop=uicontrol(pD,'Style','popupmenu', ...
    'String',{'None','Automatic injection basis','Artifact ROI PCs','Auto + artifact ROI PCs','Custom regressors','Auto + custom regressors','Spatial CCA: brain vs noise ROI','Auto + spatial CCA'}, ...
    'Units','normalized','BackgroundColor',FLD,'ForegroundColor',WHT,'FontName',FONT,'FontSize',11,'Visible','off');
G.artpulse.lab=mkLab('Pulse duration [s]'); G.artpulse.e1=mkEd('5');
G.arttaus.lab=mkLab('Exp. taus [s]'); G.arttaus.e1=mkEd('5 20 60');
G.artnpc.lab=mkLab('ROI PCs / CCA threshold'); G.artnpc.e1=mkEd('3');
G.artflags.lab=mkLab('Extra shapes');
G.artflags.cb1=uicontrol(pD,'Style','checkbox','String','persistent step', ...
    'Units','normalized','Value',0,'BackgroundColor',PAN,'ForegroundColor',WHT,'FontName',FONT,'FontSize',10.5,'Visible','off');
G.artflags.cb2=uicontrol(pD,'Style','checkbox','String','slow plateau/ramp', ...
    'Units','normalized','Value',1,'BackgroundColor',PAN,'ForegroundColor',WHT,'FontName',FONT,'FontSize',10.5,'Visible','off');
G.artroi.lab=mkLab('Artefact ROI');
G.artroi.b1=uicontrol(pD,'Style','pushbutton','String','Paint injection / bubble ROI', ...
    'Units','normalized','BackgroundColor',ACC,'ForegroundColor',WHT,'FontName',FONT,'FontSize',10.5,'FontWeight','bold','Visible','off','Callback',@(a,b)pickArtifactROI());
G.artroi.t=uicontrol(pD,'Style','text','String','not selected', ...
    'Units','normalized','BackgroundColor',PAN,'ForegroundColor',DIM,'FontName',FONT,'FontSize',10.5,'HorizontalAlignment','left','Visible','off');
G.ccaroi.lab=mkLab('CCA noise ROI');
G.ccaroi.b1=uicontrol(pD,'Style','pushbutton','String','Paint noise / non-functional ROI', ...
    'Units','normalized','BackgroundColor',ACC,'ForegroundColor',WHT,'FontName',FONT,'FontSize',10.5,'FontWeight','bold','Visible','off','Callback',@(a,b)pickCCANoiseROI());
G.ccaroi.t=uicontrol(pD,'Style','text','String','not selected', ...
    'Units','normalized','BackgroundColor',PAN,'ForegroundColor',DIM,'FontName',FONT,'FontSize',10.5,'HorizontalAlignment','left','Visible','off');

G.scans.lab=mkLab('Animal / analysed folder'); G.scans.e1=mkEd(startRoot);
G.scans.b1=uicontrol(pD,'Style','pushbutton','String','Browse','Units','normalized','BackgroundColor',[0.24 0.24 0.28],'ForegroundColor',WHT,'FontName',FONT,'FontSize',11,'FontWeight','bold','Visible','off','Callback',@(a,b)onBrowse());
G.scans.b2=uicontrol(pD,'Style','pushbutton','String','Rescan','Units','normalized','BackgroundColor',[0.20 0.20 0.24],'ForegroundColor',WHT,'FontName',FONT,'FontSize',11,'FontWeight','bold','Visible','off','Callback',@(a,b)refreshLists());
G.scans.t1=uicontrol(pD,'Style','text','String','SCAN 1 DRUG / TARGET','Units','normalized','BackgroundColor',PAN,'ForegroundColor',GOLD,'FontName',FONT,'FontSize',10.5,'FontWeight','bold','HorizontalAlignment','left','Visible','off');
G.scans.t2=uicontrol(pD,'Style','text','String','SCAN 2 VEHICLE / aCSF','Units','normalized','BackgroundColor',PAN,'ForegroundColor',MINT,'FontName',FONT,'FontSize',10.5,'FontWeight','bold','HorizontalAlignment','left','Visible','off');
G.scans.l1=uicontrol(pD,'Style','listbox','String',{''},'Units','normalized','BackgroundColor',FLD,'ForegroundColor',WHT,'FontName',FONT,'FontSize',10,'Visible','off');
G.scans.l2=uicontrol(pD,'Style','listbox','String',{''},'Units','normalized','BackgroundColor',FLD,'ForegroundColor',WHT,'FontName',FONT,'FontSize',10,'Visible','off');

pB=uipanel(f,'Title','  ALWAYS APPLIED  ','Units','normalized','Position',[0.02 0.045 0.96 0.14], ...
    'BackgroundColor',PAN,'ForegroundColor',MINT,'FontName',FONT,'FontSize',13,'FontWeight','bold');
uicontrol(pB,'Style','text','String','Baseline [s]','Units','normalized','Position',[0.015 0.52 0.13 0.30], ...
    'BackgroundColor',PAN,'ForegroundColor',WHT,'FontName',FONT,'FontSize',12,'FontWeight','bold','HorizontalAlignment','left');
hB1=uicontrol(pB,'Style','edit','String','0','Units','normalized','Position',[0.145 0.50 0.055 0.34], ...
    'BackgroundColor',FLD,'ForegroundColor',WHT,'FontName',FONT,'FontSize',12,'FontWeight','bold');
hB2=uicontrol(pB,'Style','edit','String','60','Units','normalized','Position',[0.210 0.50 0.055 0.34], ...
    'BackgroundColor',FLD,'ForegroundColor',WHT,'FontName',FONT,'FontSize',12,'FontWeight','bold');
uicontrol(pB,'Style','text','String','Signal level','Units','normalized','Position',[0.015 0.12 0.13 0.30], ...
    'BackgroundColor',PAN,'ForegroundColor',WHT,'FontName',FONT,'FontSize',12,'FontWeight','bold','HorizontalAlignment','left');
rL={'Pre-injection level','Whole-run mean','Centred at zero'}; hRes=zeros(1,3);
for ii=1:3
    hRes(ii)=uicontrol(pB,'Style','pushbutton','String',rL{ii},'Units','normalized', ...
        'Position',[0.145+(ii-1)*0.155 0.10 0.15 0.34],'FontName',FONT,'FontSize',11,'Callback',@(a,b)setRestore(ii));
end
hHint=uicontrol(pB,'Style','text','Units','normalized','Position',[0.66 0.52 0.325 0.30], ...
    'BackgroundColor',PAN,'ForegroundColor',DIM,'FontName',FONT,'FontSize',11,'HorizontalAlignment','left','String',hintStr());
hWarn=uicontrol(pB,'Style','text','Units','normalized','Position',[0.66 0.08 0.325 0.38], ...
    'BackgroundColor',PAN,'ForegroundColor',MINT,'FontName',FONT,'FontSize',11,'FontWeight','bold','HorizontalAlignment','left','String','');
uicontrol(f,'Style','pushbutton','String','RUN','Units','normalized','Position',[0.80 0.005 0.085 0.034], ...
    'BackgroundColor',[0.13 0.62 0.38],'ForegroundColor',WHT,'FontName',FONT,'FontSize',15,'FontWeight','bold','Callback',@(a,b)onOK());
uicontrol(f,'Style','pushbutton','String','Cancel','Units','normalized','Position',[0.895 0.005 0.085 0.034], ...
    'BackgroundColor',[0.52 0.16 0.18],'ForegroundColor',WHT,'FontName',FONT,'FontSize',15,'FontWeight','bold','Callback',@(a,b)cancelClose());

refreshLists();
paintAll();
uiwait(f);

    function h=mkLab(s)
        h=uicontrol(pD,'Style','text','String',s,'Units','normalized', ...
            'BackgroundColor',PAN,'ForegroundColor',WHT,'FontName',FONT,'FontSize',11.5,'FontWeight','bold', ...
            'HorizontalAlignment','left','Visible','off');
    end
    function h=mkBtn(s,cb)
        h=uicontrol(pD,'Style','pushbutton','String',s,'Units','normalized', ...
            'FontName',FONT,'FontSize',10.5,'Callback',cb,'Visible','off');
    end
    function h=mkEd(s)
        if isempty(s), s=''; end
        h=uicontrol(pD,'Style','edit','String',s,'Units','normalized', ...
            'BackgroundColor',FLD,'ForegroundColor',WHT,'FontName',FONT,'FontSize',11.5,'FontWeight','bold','Visible','off');
    end
    function s=defStr(v)
        if isfinite(v), s=sprintf('%.0f',v); else, s=''; end
    end
    function s=hintStr()
        if isfinite(runLen)
            s=sprintf('Run: %d frames | TR %.3f s | %.1f s total',nFrames,TR,runLen);
        else
            s='Run length unknown.';
        end
    end
    function setSel(i), sel=i; paintAll(); end
    function setOrder(i), orderSel=i; paintAll(); end
    function setRestore(i), restoreSel=i; paintAll(); end
    function cancelClose()
        cfg=struct('cancelled',true);
        if ishghandle(f), uiresume(f); delete(f); end
    end
    function hideAll()
        fn=fieldnames(G);
        for a=1:numel(fn)
            g=G.(fn{a});
            sub=fieldnames(g);
            for b=1:numel(sub)
                hh=g.(sub{b});
                for c=1:numel(hh)
                    if ishghandle(hh(c)), set(hh(c),'Visible','off'); end
                end
            end
        end
    end
    function y=place(name,y)
        g=G.(name);
        set(g.lab,'Position',[0.03 y 0.29 0.042],'Visible','on');
        switch name
            case 'order'
                for q=1:4, set(g.b(q),'Position',[0.34+(q-1)*0.145 y 0.135 0.045],'Visible','on'); end
                y=y-0.055;
            case 'tail'
                set(g.e1,'Position',[0.34 y 0.11 0.045],'Visible','on');
                set(g.e2,'Position',[0.47 y 0.11 0.045],'Visible','on');
                y=y-0.055;
            case {'inj','resp','ncomp','knot','cutoff','ccfrac','ccseed','artpulse','arttaus','artnpc'}
                set(g.e1,'Position',[0.34 y 0.18 0.045],'Visible','on');
                y=y-0.055;
            case {'ccmode','artmode'}
                set(g.pop,'Position',[0.34 y 0.52 0.047],'Visible','on');
                y=y-0.055;
            case 'ccprotect'
                set(g.cb,'Position',[0.34 y 0.50 0.045],'Visible','on');
                y=y-0.055;
            case 'artflags'
                set(g.cb1,'Position',[0.34 y 0.22 0.045],'Visible','on');
                set(g.cb2,'Position',[0.58 y 0.22 0.045],'Visible','on');
                y=y-0.055;
            case {'roi','artroi','ccaroi'}
                set(g.b1,'Position',[0.34 y 0.30 0.050],'Visible','on');
                set(g.t,'Position',[0.66 y 0.28 0.060],'Visible','on');
                y=y-0.065;
            case 'scans'
                set(g.e1,'Position',[0.34 y 0.34 0.045],'Visible','on');
                set(g.b1,'Position',[0.70 y 0.12 0.048],'Visible','on');
                set(g.b2,'Position',[0.83 y 0.12 0.048],'Visible','on');
                y=y-0.060;
                set(g.t1,'Position',[0.03 y 0.45 0.040],'Visible','on');
                set(g.t2,'Position',[0.51 y 0.45 0.040],'Visible','on');
                y=y-0.280;
                set(g.l1,'Position',[0.03 y 0.45 0.260],'Visible','on');
                set(g.l2,'Position',[0.51 y 0.45 0.260],'Visible','on');
                y=y-0.030;
        end
    end
    function paintAll()
        for a=1:numel(mKey)
            if a==sel
                set(hM(a),'BackgroundColor',ACC,'ForegroundColor',WHT,'FontWeight','bold');
            elseif mRank(a)<=3
                set(hM(a),'BackgroundColor',[0.19 0.26 0.31],'ForegroundColor',WHT,'FontWeight','bold');
            else
                set(hM(a),'BackgroundColor',CARD,'ForegroundColor',WHT,'FontWeight','normal');
            end
        end
        for a=1:4
            if a==orderSel, set(G.order.b(a),'BackgroundColor',GOLD,'ForegroundColor',[0.05 0.05 0.05],'FontWeight','bold');
            else, set(G.order.b(a),'BackgroundColor',CARD,'ForegroundColor',WHT,'FontWeight','normal'); end
        end
        for a=1:3
            if a==restoreSel, set(hRes(a),'BackgroundColor',MINT,'ForegroundColor',[0.05 0.05 0.05],'FontWeight','bold');
            else, set(hRes(a),'BackgroundColor',CARD,'ForegroundColor',WHT,'FontWeight','normal'); end
        end
        if mRank(sel)<=3, set(hTitle,'String',sprintf('%s        recommended #%d',mName{sel},mRank(sel)));
        else, set(hTitle,'String',mName{sel}); end
        set(hDesc,'String',mDesc{sel});
        set(hCav,'String',['Caveat: ' mCav{sel}]);
        hideAll();
        y=0.635;
        op=mOpts{sel};
        for a=1:numel(op), y=place(op{a},y); end
        msg=''; col=MINT;
        if strcmp(mKey{sel},'vehicle') && isempty(fileList), msg='No pre-processed scans found in this folder.'; col=RED; end
        if restoreSel==3, msg=[msg ' Level centred at zero - computePSC will not work.']; col=RED; end
        set(hWarn,'String',msg,'ForegroundColor',col);
        set(hHint,'String',hintStr());
    end
    function mk=callPicker(ttl,bsz)
        mk=[];
        if isempty(imgData)
            errordlg('No image data was handed to the dialog.','ROI picker');
            return;
        end
        try
            mk=deConfUSIon_drift_roi_picker(imgData,'title',ttl,'brushSize',bsz);
        catch ME
            errordlg(ME.message,'ROI picker failed');
            mk=[];
        end
    end
    function pickROI()
        mk=callPicker('aCompCor / reference non-responsive ROI',15);
        if isempty(mk), return; end
        roiMask=mk;
        set(G.roi.t,'String',sprintf('selected: %d voxels',nnz(roiMask)),'ForegroundColor',MINT);
        figure(f);
    end
    function pickArtifactROI()
        mk=callPicker('Injection / bubble / coupling artefact ROI',15);
        if isempty(mk), return; end
        artifactMask=mk;
        set(G.artroi.t,'String',sprintf('selected: %d voxels',nnz(artifactMask)),'ForegroundColor',MINT);
        figure(f);
    end
    function pickCCANoiseROI()
        mk=callPicker('CCA noise / non-functional ROI',20);
        if isempty(mk), return; end
        ccaNoiseMask=mk;
        set(G.ccaroi.t,'String',sprintf('selected: %d voxels',nnz(ccaNoiseMask)),'ForegroundColor',MINT);
        figure(f);
    end
    function onBrowse()
        d=uigetdir(get(G.scans.e1,'String'),'Select the animal / analysed folder');
        if ischar(d) && ~isempty(d) && exist(d,'dir')==7
            set(G.scans.e1,'String',d);
            refreshLists();
            paintAll();
        end
    end
    function refreshLists()
        rr=strtrim(get(G.scans.e1,'String'));
        fileList={}; fileLabels={};
        if isempty(rr) || exist(rr,'dir')~=7
            set(G.scans.l1,'String',{'   (folder not found)'},'Value',1);
            set(G.scans.l2,'String',{'   (folder not found)'},'Value',1);
            return;
        end
        cand={rr};
        d=dir(rr);
        for a=1:numel(d)
            if d(a).isdir && ~strcmp(d(a).name,'.') && ~strcmp(d(a).name,'..')
                cand{end+1}=fullfile(rr,d(a).name);
            end
        end
        for a=1:numel(cand)
            pp2=fullfile(cand{a},'Preprocessing');
            if exist(pp2,'dir')~=7, continue; end
            mm=dir(fullfile(pp2,'*.mat'));
            for b=1:numel(mm)
                [~,sn]=fileparts(cand{a});
                fileList{end+1}=fullfile(pp2,mm(b).name);
                fileLabels{end+1}=sprintf('  %-24s   %s',sn,mm(b).name);
            end
        end
        if isempty(fileList)
            set(G.scans.l1,'String',{'   (no Preprocessing/*.mat found)'},'Value',1);
            set(G.scans.l2,'String',{'   (no Preprocessing/*.mat found)'},'Value',1);
        else
            set(G.scans.l1,'String',fileLabels,'Value',1);
            set(G.scans.l2,'String',fileLabels,'Value',min(2,numel(fileLabels)));
        end
    end
    function onOK()
        rN={'baseline','runmean','none'};
        k=mKey{sel};
        need=mOpts{sel};
        b1=str2double(get(hB1,'String'));
        b2=str2double(get(hB2,'String'));
        if ~isfinite(b1) || ~isfinite(b2) || b2<=b1 || b1<0
            errordlg('Baseline window invalid: need 0 <= start < end.','Drift Compensation'); return;
        end
        o=struct();
        o.cancelled=false;
        o.method=k;
        o.baselineSec=[b1 b2];
        o.polyOrder=orderSel-1;
        o.restoreMode=rN{restoreSel};
        o.rootFolder=strtrim(get(G.scans.e1,'String'));
        o.vehicleFile='';
        o.targetFile='';
        if any(strcmp(need,'tail'))
            t1=str2double(get(G.tail.e1,'String')); t2=str2double(get(G.tail.e2,'String'));
            if ~isfinite(t1) || ~isfinite(t2) || t2<=t1, errordlg('Tail window invalid.','Drift Compensation'); return; end
            if t1<=b2, errordlg('Tail window must start after baseline.','Drift Compensation'); return; end
            o.tailSec=[t1 t2];
        end
        if any(strcmp(need,'inj'))
            v=str2double(get(G.inj.e1,'String'));
            if ~isfinite(v) || v<0, errordlg('Injection time invalid.','Drift Compensation'); return; end
            o.injectionSec=v;
        end
        if any(strcmp(need,'resp'))
            v=str2double(get(G.resp.e1,'String'));
            if ~isfinite(v) || v<=0, errordlg('Response length must be > 0.','Drift Compensation'); return; end
            o.responseSec=v;
        end
        if any(strcmp(need,'ncomp'))
            v=str2double(get(G.ncomp.e1,'String'));
            if ~isfinite(v) || v<1, errordlg('Components must be >= 1.','Drift Compensation'); return; end
            o.nComp=round(v);
        end
        if any(strcmp(need,'knot'))
            v=str2double(get(G.knot.e1,'String'));
            if ~isfinite(v) || v<=0, errordlg('Knot spacing must be > 0.','Drift Compensation'); return; end
            o.knotSec=v;
        end
        if any(strcmp(need,'cutoff'))
            v=str2double(get(G.cutoff.e1,'String'));
            if ~isfinite(v) || v<=0, errordlg('Cutoff must be > 0.','Drift Compensation'); return; end
            o.cutoffSec=v;
        end
        if strcmp(k,'compcor')
            cmodes={'global','tcompcor','acompcor','random','lowvar'};
            cv=get(G.ccmode.pop,'Value'); cv=max(1,min(numel(cmodes),cv));
            o.compcorMode=cmodes{cv};
            v=str2double(get(G.ccfrac.e1,'String')); if ~isfinite(v) || v<=0, v=0.05; end
            if v>1, v=v/100; end
            o.compcorFrac=v;
            v=str2double(get(G.ccseed.e1,'String')); if ~isfinite(v), v=1; end
            o.randomSeed=round(v);
            o.protectResponse=logical(get(G.ccprotect.cb,'Value'));
            if ~isfield(o,'injectionSec') || isempty(o.injectionSec), o.injectionSec=b2; end
            if ~isfield(o,'responseSec') || isempty(o.responseSec), o.responseSec=180; end
            if strcmp(o.compcorMode,'acompcor') && isempty(roiMask)
                errordlg('aCompCor needs a painted non-responsive / WM-CSF-like ROI. Use Paint ROI first.','CompCor'); return;
            end
            if ~isempty(roiMask), o.refMask=roiMask; end
        end
        if strcmp(k,'glm') || strcmp(k,'pacap_response')
            amodes={'none','auto','roi','auto_roi','custom','auto_custom','spatial_cca','auto_spatial_cca'};
            av=get(G.artmode.pop,'Value'); av=max(1,min(numel(amodes),av));
            o.artifactMode=amodes{av};
            v=str2double(get(G.artpulse.e1,'String')); if ~isfinite(v) || v<=0, v=5; end
            o.artifactPulseSec=v;
            v=str2double(get(G.artnpc.e1,'String')); if ~isfinite(v) || v<1, v=3; end
            o.artifactNPC=round(v); o.ccaThreshold=o.artifactNPC;
            tau=str2num(get(G.arttaus.e1,'String')); %#ok<ST2NM>
            if isempty(tau), tau=[5 20 60]; end
            o.artifactExpTauSec=tau;
            o.artifactPersistent=logical(get(G.artflags.cb1,'Value'));
            o.artifactPlateau=logical(get(G.artflags.cb2,'Value'));
            needsArtifactROI=any(strcmp(o.artifactMode,{'roi','auto_roi'}));
            needsCCA=any(strcmp(o.artifactMode,{'spatial_cca','auto_spatial_cca'}));
            needsCustom=any(strcmp(o.artifactMode,{'custom','auto_custom'}));
            if needsArtifactROI
                if isempty(artifactMask), errordlg('This artefact mode needs a painted injection/bubble/coupling ROI.','GLM artefact ROI'); return; end
                o.artifactMask=artifactMask;
            end
            if needsCCA
                if isempty(ccaNoiseMask), errordlg('Spatial CCA needs a painted noise / non-functional ROI.','CCA noise ROI'); return; end
                o.ccaNoiseMask=ccaNoiseMask;
            end
            if needsCustom
                [fn,fp]=uigetfile({'*.mat;*.csv;*.txt','Regressor files (*.mat, *.csv, *.txt)'},'Select custom artefact regressors');
                if isequal(fn,0), return; end
                o.customArtifactFile=fullfile(fp,fn);
            end
        end
        if any(strcmp(need,'roi')) && ~strcmp(k,'compcor')
            if ~isempty(roiMask)
                o.refMask=roiMask;
            elseif strcmp(k,'reference')
                errordlg('Reference method needs a region.','Drift Compensation'); return;
            end
        end
        if any(strcmp(need,'scans'))
            if isempty(fileList), errordlg('No pre-processed scans found.','Drift Compensation'); return; end
            i1=get(G.scans.l1,'Value'); i2=get(G.scans.l2,'Value');
            if i1>numel(fileList) || i2>numel(fileList), errordlg('Select one scan in each list.','Drift Compensation'); return; end
            if i1==i2, errordlg('Drug scan and vehicle scan must be different.','Drift Compensation'); return; end
            o.targetFile=fileList{i1};
            o.vehicleFile=fileList{i2};
        end
        cfg=o;
        if ishghandle(f), uiresume(f); delete(f); end
    end
end
