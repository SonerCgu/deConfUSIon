classdef registration_ccf < handle
% =========================================================
% Atlas registration GUI
%
% ASCII only
% MATLAB 2017b compatible
%
% Main goals:
%   - Use your nice mask-editor brainImage / MIP / anatomy as overlay
%   - Better contrast controls for overlay
%   - Keep atlas fixed, move overlay
%   - Save Transformation.mat
%   - Preview/register functional files to atlas space
%
% Constructor supports:
%   R = registration_ccf(atlas, scananatomy)
%   R = registration_ccf(atlas, scananatomy, initialTransf)
%   R = registration_ccf(atlas, scananatomy, initialTransf, logFcn)
%   R = registration_ccf(atlas, scananatomy, initialTransf, logFcn, saveDir)
%   R = registration_ccf(atlas, scananatomy, initialTransf, logFcn, saveDir, funcCandidates)
% =========================================================

    properties
        H
        atlas

        ms1
        ms2
        DataNoScale
        RegistrationData

        scale
        Trot
        TF
        T0

        r1
        r2
        r3

        mapRegions
        mapHistology
        mapVascular
        linmap

        hlinesS
        hlinesC
        hlinesT

        logFcn = []
        saveDir = ''

        funcFiles = {}
        funcLabels = {}

        overlayOpacity = 0.85
        overlayCmapName = 'hot'
        overlayInvert = false
        overlayWinMin = 0.00
        overlayWinMax = 1.00
        overlayGain = 1
        overlayGamma = 1
        showAtlasLines = true
        showAtlasUnderlay = true

        overlayCoronalOnly = false
        atlasStepCor = 1

        lastScrollT = -inf
        scrollMinDt = 0.03
        autoBusy = false
        autoSetupBusy = false
        autoReport = []
        autoUndo = []
        scanGeometry = []
        reviewBusy = false
        reviewBundle = []
        reviewMatrix = []
        reviewTarget = ''
        snapReference = 'vascular'
        lastDragPreview = -inf
        lastLinesKey = []
        displayPreset = 'Mask Editor standard'
        regionMode = 'Detailed'
        groupedRegions = []
        groupedRegionInfo = []
        savedDisplayData = []
        anchorDraft = []
        previewTimer = []
        cutCache = []
        previewSampler = []
        atlasCutCache = []
        livePreview = false
    end

    properties (Access=protected)
        im1
        im2
        im3

        im4Under
        im5Under
        im6Under

        im4
        im5
        im6

        line1x
        line1y
        line2x
        line2y
        line3x
        line3y
        line4x
        line4y
        line5x
        line5y
        line6x
        line6y

        uiEditCor
        uiEditSag
        uiEditAxi
        uiSliceInfo

        uiOpacity
        uiWinMin
        uiWinMax
        uiOverlayGain
        uiOverlayGamma
        uiInvert
        uiCmapPopup
        uiOverlayStatus

        uiScaleCorX
        uiScaleSagY
        uiScaleAxiZ
        uiScaleStep
        uiLivePreview
        uiAuto
        uiUndoAuto
        uiApply
        uiSave
        uiSaveStatus

        uiAtlasGroup
        uiAtlasVasc
        uiAtlasHist
        uiAtlasReg
        uiShowLines

        uiHelp
        uiClose

        uiFuncPopup
        uiFuncPreview
        uiFuncRegister
        uiFuncStatus
    end

    methods
        function R = registration_ccf(atlas, scananatomy, varargin)
            deConfUSIon_setup();
            initialTransf = [];
            logFcn = [];
            saveDir = '';
            funcCandidates = struct('files',{{}},'labels',{{}});

            if numel(varargin) >= 1
                initialTransf = varargin{1};
            end
            if numel(varargin) >= 2
                logFcn = varargin{2};
            end
            if numel(varargin) >= 3
                saveDir = varargin{3};
            end
            if numel(varargin) >= 4
                funcCandidates = varargin{4};
            end

            if ~isempty(initialTransf) && isstruct(initialTransf) && isfield(initialTransf,'M')
                R.T0 = initialTransf.M;
                if isfield(initialTransf,'autoRegistration'), R.autoReport=initialTransf.autoRegistration; end
                if isfield(initialTransf,'regionGrouping'),R.regionMode=initialTransf.regionGrouping;end
            else
                R.T0 = eye(4);
            end

            if ~isempty(logFcn) && isa(logFcn,'function_handle')
                R.logFcn = logFcn;
            end

            if ~isempty(saveDir) && (ischar(saveDir)||isstring(saveDir))
                R.saveDir = fusiAnalysisOutputPath(saveDir);
            else
                R.saveDir = fusiAnalysisOutputPath(pwd);
            end

            if ~isempty(funcCandidates) && isstruct(funcCandidates)
                if isfield(funcCandidates,'files') && iscell(funcCandidates.files)
                    R.funcFiles = funcCandidates.files;
                end
                if isfield(funcCandidates,'labels') && iscell(funcCandidates.labels)
                    R.funcLabels = funcCandidates.labels;
                end
            end
            if isempty(R.funcLabels)
                R.funcLabels = R.funcFiles;
            end

            atlas=deConfUSIon_apply_rgb2acr(atlas);
            R.atlas = atlas;
            if isfield(scananatomy,'Geometry'), R.scanGeometry=scananatomy.Geometry; end
            R.log(sprintf('[Atlas GUI] Save directory: %s', R.saveDir));
            % deConfUSIon 3D registration patch START: voxel-aware coronal scrolling
            atlasStepUm = 50;
            scanStepUm  = 80;

            try
                if isfield(atlas,'VoxelSize') && numel(atlas.VoxelSize) >= 1
                    atlasStepUm = double(atlas.VoxelSize(1));
                end
            catch
            end

            try
                if isfield(scananatomy,'VoxelSize') && numel(scananatomy.VoxelSize) >= 1
                    scanStepUm = double(scananatomy.VoxelSize(1));
                end
            catch
            end

            if ~isfinite(atlasStepUm) || atlasStepUm <= 0, atlasStepUm = 50; end
            if ~isfinite(scanStepUm)  || scanStepUm  <= 0, scanStepUm  = 80; end

            R.atlasStepCor = max(1, round(scanStepUm / atlasStepUm));
            R.scrollMinDt  = 0.08;
            % deConfUSIon 3D registration patch END



            % Normalize anatomy overlay and bring it into atlas voxel/orientation space
            tmp = AtlasRegistration('prepare',scananatomy,atlas);
            R.RegistrationData=single(tmp.Data);
            if isfield(scananatomy,'DisplayData') && ~isempty(scananatomy.DisplayData)
                shown=scananatomy;shown.Data=shown.DisplayData;shown=AtlasRegistration('prepare',shown,atlas);
                R.savedDisplayData=min(1,max(0,single(shown.Data)));R.displayPreset='Saved Mask Editor';
            end
            R.ms2 = mapscan(fusiRegistrationDisplayVolume(tmp.Data,R.displayPreset), gray(256), 'fix');
            if ~isempty(R.savedDisplayData),R.ms2.setData(R.savedDisplayData);end
            R.ms2.caxis = [0 1];

            R.mapHistology = mapscan(atlas.Histology, gray(256), 'index');
            R.mapVascular  = mapscan(atlas.Vascular,  gray(256), 'auto');
            R.mapRegions   = mapscan(atlas.Regions,   atlas.infoRegions.rgb, 'index');

            R.ms1 = R.mapVascular;
            R.linmap = atlas.Lines;

            R.scale = [1 1 1];
            R.Trot  = eye(4);
            R.TF    = eye(4);

            R.buildGUI();

            R.DataNoScale = R.ms2.D;R.previewSampler=griddedInterpolant(single(R.DataNoScale),'linear','none');

            R.restartMove();
            R.apply();
            if ~strcmp(R.regionMode,'Detailed')
                selector=findobj(R.H.figure1,'Tag','AtlasRegionGrouping');selector.Value=2;R.onRegionGrouping(selector);
            end
            R.refresh();
        end

        function buildGUI(R)

            scr = get(0,'ScreenSize');
            W = min(1460, scr(3)-80);
            Hh = min(940, scr(4)-80);
            x0 = max(40, floor((scr(3)-W)/2));
            y0 = max(40, floor((scr(4)-Hh)/2));

            bg = [0.06 0.06 0.06];
            fg = [0.95 0.95 0.95];
            panelBG  = [0.10 0.10 0.10];
            panelBG2 = [0.12 0.12 0.12];

            f = figure( ...
                'Name','Atlas GUI', ...
                'Color',bg, ...
                'MenuBar','none', ...
                'ToolBar','none', ...
                'NumberTitle','off', ...
                'Position',[x0 y0 W Hh]);

            R.H.figure1 = f;
            setappdata(f,'AtlasRegistrationController',R);
            set(f,'CloseRequestFcn',@(src,evt)R.onClose());
            set(f,'DeleteFcn',@(~,~)R.cancelPreview());
            set(f,'WindowScrollWheelFcn',@(src,evt)R.onScroll(evt));

            % open maximised: the six axes are unusable in a small window
            try
                set(f,'WindowState','maximized');
            catch
                % pre-R2018a has no WindowState: fill the screen manually
                try
                    set(f,'Units','pixels','OuterPosition',get(0,'ScreenSize'));
                catch ME_fs
                    warning('deConfUSIon:Maximize','Could not maximise: %s', ME_fs.message);
                end
            end

            leftX = 0.03;
            midX  = 0.35;
            ctrlX = 0.68;
            axW   = 0.28;
            axH   = 0.18;
            gapY  = 0.04;

            yTop = 0.51;
            yMid = 0.27;
            yBot = 0.04;

            uicontrol(f,'Style','text', ...
                'Units','normalized', ...
                'Position',[0.03 0.94 0.63 0.045], ...
                'String','3D Atlas Registration - automatic alignment and manual review', ...
                'BackgroundColor',bg, ...
                'ForegroundColor',fg, ...
                'FontSize',16, ...
                'FontWeight','bold', ...
                'HorizontalAlignment','left');

            R.uiSliceInfo = uicontrol(f,'Style','text', ...
                'Units','normalized', ...
                'Position',[0.68 0.94 0.29 0.045], ...
                'String','Coronal: -/-   Sagittal: -/-   Axial: -/-', ...
                'BackgroundColor',bg, ...
                'ForegroundColor',[0.7 0.95 0.7], ...
                'FontSize',12, ...
                'FontWeight','bold', ...
                'HorizontalAlignment','right');

            R.H.axes1 = axes('Parent',f,'Units','normalized','Position',[leftX yTop axW 0.38], 'Color','k');
            R.H.axes2 = axes('Parent',f,'Units','normalized','Position',[leftX yMid axW axH], 'Color','k');
            R.H.axes3 = axes('Parent',f,'Units','normalized','Position',[leftX yBot axW axH], 'Color','k');

            R.H.axes4 = axes('Parent',f,'Units','normalized','Position',[midX yTop axW 0.38], 'Color','k');
            R.H.axes5 = axes('Parent',f,'Units','normalized','Position',[midX yMid axW axH], 'Color','k');
            R.H.axes6 = axes('Parent',f,'Units','normalized','Position',[midX yBot axW axH], 'Color','k');

            axAll = [R.H.axes1 R.H.axes2 R.H.axes3 R.H.axes4 R.H.axes5 R.H.axes6];
            for k = 1:numel(axAll)
                axis(axAll(k),'image');
                axis(axAll(k),'off');
                set(axAll(k),'Box','off');
            end

            uicontrol(f,'Style','text','Units','normalized', ...
                'Position',[leftX yTop+0.38+0.005 axW 0.02], ...
                'String','Atlas - Coronal', ...
                'BackgroundColor',bg,'ForegroundColor',fg, ...
                'FontSize',11,'FontWeight','bold','HorizontalAlignment','center');

            uicontrol(f,'Style','text','Units','normalized', ...
                'Position',[leftX yMid+axH+0.005 axW 0.02], ...
                'String','Atlas - Axial (sanity check)', ...
                'BackgroundColor',bg,'ForegroundColor',fg, ...
                'FontSize',11,'FontWeight','bold','HorizontalAlignment','center');

            uicontrol(f,'Style','text','Units','normalized', ...
                'Position',[leftX yBot+axH+0.005 axW 0.02], ...
                'String','Atlas - Sagittal (sanity check)', ...
                'BackgroundColor',bg,'ForegroundColor',fg, ...
                'FontSize',11,'FontWeight','bold','HorizontalAlignment','center');

            uicontrol(f,'Style','text','Units','normalized', ...
                'Position',[midX yTop+0.38+0.005 axW 0.02], ...
                'String','Acquired coronal anatomy on fixed atlas', ...
                'BackgroundColor',bg,'ForegroundColor',fg, ...
                'FontSize',11,'FontWeight','bold','HorizontalAlignment','center');

            uicontrol(f,'Style','text','Units','normalized', ...
                'Position',[midX yMid+axH+0.005 axW 0.02], ...
                'String','Anatomy on atlas - Axial (sanity check)', ...
                'BackgroundColor',bg,'ForegroundColor',fg, ...
                'FontSize',11,'FontWeight','bold','HorizontalAlignment','center');

            uicontrol(f,'Style','text','Units','normalized', ...
                'Position',[midX yBot+axH+0.005 axW 0.02], ...
                'String','Anatomy on atlas - Sagittal (sanity check)', ...
                'BackgroundColor',bg,'ForegroundColor',fg, ...
                'FontSize',11,'FontWeight','bold','HorizontalAlignment','center');

            ctrlPanel = uipanel(f, ...
                'Units','normalized', ...
                'Position',[ctrlX 0.06 0.29 0.87], ...
                'BackgroundColor',panelBG, ...
                'ForegroundColor',fg, ...
                'Title','Controls', ...
                'FontSize',12, ...
                'FontWeight','bold');

            % Overlay display panel
            R.uiAuto = uicontrol(ctrlPanel,'Style','pushbutton','Units','normalized', ...
                'Position',[0.05 0.91 0.57 0.065], ...
                'String','1. Auto: fit anatomy', ...
                'Tag','Automatic3DRegistration', ...
                'BackgroundColor',[0.16 0.60 0.34],'ForegroundColor','w', ...
                'FontName','Arial','FontSize',13,'FontWeight','bold', ...
                'Callback',@(src,evt)R.onAutoRegister());
            uicontrol(ctrlPanel,'Style','pushbutton','Units','normalized', ...
                'Position',[.65 .91 .30 .065],'String','ITK-SNAP review', ...
                'Tag','ReviewInITKSNAP','BackgroundColor',[.16 .42 .75],'ForegroundColor','w', ...
                'FontWeight','bold','Callback',@(~,~)R.onReviewSnap());
            ovPanel = uipanel(ctrlPanel, ...
                'Units','normalized', ...
                'Position',[0.05 0.675 0.90 0.215], ...
                'BackgroundColor',panelBG2, ...
                'ForegroundColor',fg, ...
                'Title','Overlay display', ...
                'FontSize',11, ...
                'FontWeight','bold');

            uicontrol(ovPanel,'Style','text','Units','normalized', ...
                'Position',[0.06 0.83 0.26 0.12], ...
                'String','Anatomy opacity', ...
                'BackgroundColor',panelBG2,'ForegroundColor',fg, ...
                'HorizontalAlignment','left','FontSize',10,'FontWeight','bold');

            R.uiOpacity = uicontrol(ovPanel,'Style','slider','Units','normalized', ...
                'Tag','AnatomyOpacity', ...
                'Position',[0.36 0.85 0.58 0.10], ...
                'Min',0,'Max',1,'Value',R.overlayOpacity, ...
                'BackgroundColor',panelBG2, ...
                'Callback',@(src,evt)R.onOverlayChanged());

            uicontrol(ovPanel,'Style','text','Units','normalized', ...
                'Position',[0.06 0.64 0.26 0.12], ...
                'String','Win min', ...
                'BackgroundColor',panelBG2,'ForegroundColor',fg, ...
                'HorizontalAlignment','left','FontSize',10,'FontWeight','bold');

            R.uiWinMin = uicontrol(ovPanel,'Style','edit','Units','normalized', ...
                'Tag','AnatomyWindowMin','Position',[0.36 0.65 0.20 0.12], ...
                'String',num2str(R.overlayWinMin), ...
                'BackgroundColor',[0.12 0.12 0.12], ...
                'ForegroundColor',fg, ...
                'Callback',@(src,evt)R.onOverlayChanged());

            uicontrol(ovPanel,'Style','text','Units','normalized', ...
                'Position',[0.60 0.64 0.20 0.12], ...
                'String','Win max', ...
                'BackgroundColor',panelBG2,'ForegroundColor',fg, ...
                'HorizontalAlignment','left','FontSize',10,'FontWeight','bold');

            R.uiWinMax = uicontrol(ovPanel,'Style','edit','Units','normalized', ...
                'Tag','AnatomyWindowMax','Position',[0.80 0.65 0.14 0.12], ...
                'String',num2str(R.overlayWinMax), ...
                'BackgroundColor',[0.12 0.12 0.12], ...
                'ForegroundColor',fg, ...
                'Callback',@(src,evt)R.onOverlayChanged());

            uicontrol(ovPanel,'Style','text','Units','normalized', ...
                'Position',[0.06 0.26 0.26 0.12], ...
                'String','Colormap', ...
                'BackgroundColor',panelBG2,'ForegroundColor',fg, ...
                'HorizontalAlignment','left','FontSize',10,'FontWeight','bold');

            cmapList = {'cyan','red','gray','bone','hot','copper','parula','jet'};
            defaultIdx = find(strcmpi(cmapList, R.overlayCmapName), 1);
            if isempty(defaultIdx), defaultIdx = 1; end

            R.uiCmapPopup = uicontrol(ovPanel,'Style','popupmenu','Units','normalized', ...
                'Position',[0.36 0.27 0.32 0.14], ...
                'String',cmapList, ...
                'Value',defaultIdx, ...
                'BackgroundColor',[0.15 0.15 0.15], ...
                'ForegroundColor',fg, ...
                'Callback',@(src,evt)R.onOverlayChanged());

            R.uiInvert = uicontrol(ovPanel,'Style','checkbox','Units','normalized', ...
                'Position',[0.72 0.26 0.22 0.14], ...
                'String','Invert', ...
                'Value',0, ...
                'BackgroundColor',panelBG2,'ForegroundColor',fg, ...
                'Callback',@(src,evt)R.onOverlayChanged());

            R.uiOverlayStatus = uicontrol(ovPanel,'Style','text','Units','normalized', ...
                'Position',[0.06 0.08 0.88 0.14], ...
                'String','', ...
                'BackgroundColor',panelBG2,'ForegroundColor',[0.7 0.95 0.7], ...
                'HorizontalAlignment','left','FontSize',9);
            set(R.uiOverlayStatus,'Visible','off');
            uicontrol(ovPanel,'Style','text','Units','normalized','Position',[.06 .45 .26 .12], ...
                'String','Vessel gain','BackgroundColor',panelBG2,'ForegroundColor',fg, ...
                'HorizontalAlignment','left','FontSize',10,'FontWeight','bold');
            R.uiOverlayGain=uicontrol(ovPanel,'Style','edit','Units','normalized','Position',[.36 .46 .20 .12], ...
                'String','1','Tag','AnatomyVesselGain','BackgroundColor',[.12 .12 .12],'ForegroundColor',fg, ...
                'FontSize',11,'TooltipString','Display only. 1 = Mask Editor appearance; try 2-5 for stronger vessels. Any positive gain is allowed.', ...
                'Callback',@(~,~)R.onOverlayChanged());
            uicontrol(ovPanel,'Style','text','Units','normalized','Position',[.60 .45 .20 .12], ...
                'String','Gamma','BackgroundColor',panelBG2,'ForegroundColor',fg, ...
                'HorizontalAlignment','left','FontSize',10,'FontWeight','bold');
            R.uiOverlayGamma=uicontrol(ovPanel,'Style','edit','Units','normalized','Position',[.80 .46 .14 .12], ...
                'String','1','Tag','AnatomyGamma','BackgroundColor',[.12 .12 .12],'ForegroundColor',fg, ...
                'FontSize',11,'TooltipString','Display only. Greater than 1 reveals faint vessels; below 1 suppresses faint background.', ...
                'Callback',@(~,~)R.onOverlayChanged());
            uicontrol(ovPanel,'Style','popupmenu','Units','normalized','Position',[.06 .04 .88 .16], ...
                'String',{'Saved Mask Editor','Mask Editor standard','Vessel detail','Linear power','Log Doppler'}, ...
                'Value',find(strcmp({'Saved Mask Editor','Mask Editor standard','Vessel detail','Linear power','Log Doppler'},R.displayPreset)), ...
                'Tag','AtlasDisplayPreset','BackgroundColor',[.12 .12 .12],'ForegroundColor','w', ...
                'FontSize',12,'TooltipString','Display contrast only. Vessel detail enhances coronal anatomy; linear power preserves intensity relationships.', ...
                'Callback',@(src,~)R.onDisplayPreset(src));

            % Transform panel
            trPanel = uipanel(ctrlPanel, ...
                'Units','normalized', ...
                'Position',[0.05 0.44 0.90 0.19], ...
                'BackgroundColor',panelBG2, ...
                'ForegroundColor',fg, ...
                'Title','Resize anatomy (1 = unchanged)', ...
                'FontSize',11, ...
                'FontWeight','bold');

            uicontrol(trPanel,'Style','text','Units','normalized', ...
                'Position',[0.05 0.59 0.30 0.16], ...
                'String','DV / depth (Y)', ...
                'BackgroundColor',panelBG2,'ForegroundColor',fg, ...
                'HorizontalAlignment','left','FontSize',10,'FontWeight','bold');

            R.uiScaleCorX = uicontrol(trPanel,'Style','edit','Units','normalized', ...
                'Position',[0.37 0.59 0.19 0.16], ...
                'String','1', ...
                'BackgroundColor',[0.12 0.12 0.12], ...
                'ForegroundColor',fg,'FontSize',12,'Tag','AtlasScaleDV', ...
                'TooltipString','Resize the anatomy along depth (DV). 1 = unchanged; 1.1 = 10% larger. Applied immediately.', ...
                'Callback',@(src,evt)R.onApply());

            uicontrol(trPanel,'Style','text','Units','normalized', ...
                'Position',[0.05 0.39 0.30 0.16], ...
                'String','AP / length (Z)', ...
                'BackgroundColor',panelBG2,'ForegroundColor',fg, ...
                'HorizontalAlignment','left','FontSize',10,'FontWeight','bold');

            R.uiScaleSagY = uicontrol(trPanel,'Style','edit','Units','normalized', ...
                'Position',[0.37 0.39 0.19 0.16], ...
                'String','1', ...
                'BackgroundColor',[0.12 0.12 0.12], ...
                'ForegroundColor',fg,'FontSize',12,'Tag','AtlasScaleAP', ...
                'TooltipString','Resize anterior/posterior length. 1 = unchanged; applied immediately.', ...
                'Callback',@(src,evt)R.onApply());

            uicontrol(trPanel,'Style','text','Units','normalized', ...
                'Position',[0.05 0.19 0.30 0.16], ...
                'String','LR / width (X)', ...
                'BackgroundColor',panelBG2,'ForegroundColor',fg, ...
                'HorizontalAlignment','left','FontSize',10,'FontWeight','bold');

            R.uiScaleAxiZ = uicontrol(trPanel,'Style','edit','Units','normalized', ...
                'Position',[0.37 0.19 0.19 0.16], ...
                'String','1', ...
                'BackgroundColor',[0.12 0.12 0.12], ...
                'ForegroundColor',fg,'FontSize',12,'Tag','AtlasScaleLR', ...
                'TooltipString','Resize left/right width. 1 = unchanged; applied immediately.', ...
                'Callback',@(src,evt)R.onApply());

            uicontrol(trPanel,'Style','text','Units','normalized','Position',[.05 .80 .30 .14], ...
                'String','Button step','BackgroundColor',panelBG2,'ForegroundColor',fg, ...
                'HorizontalAlignment','left','FontSize',12);
            R.uiScaleStep=uicontrol(trPanel,'Style','popupmenu','Units','normalized', ...
                'Position',[.37 .80 .55 .15],'String',{'0.01 (1%)','0.05 (5%)','0.10 (10%)'}, ...
                'Value',1,'Tag','AtlasScaleStep','BackgroundColor',[.12 .12 .12], ...
                'ForegroundColor',fg,'FontSize',12, ...
                'TooltipString','Added to or subtracted from the size factor by each -/+ click.');
            axesNames={'DV','AP','LR'};rowY=[.59 .39 .19];
            for axisIndex=1:3
                for direction=[-1 1]
                    x=.60;if direction>0,x=.78;end
                    symbol='-';suffix='Minus';if direction>0,symbol='+';suffix='Plus';end
                    uicontrol(trPanel,'Style','pushbutton','Units','normalized', ...
                        'Position',[x rowY(axisIndex) .14 .16],'String',symbol, ...
                        'Tag',['AtlasScale' axesNames{axisIndex} suffix], ...
                        'BackgroundColor',[.18 .35 .25],'ForegroundColor','w','FontSize',14, ...
                        'FontWeight','bold','TooltipString','Resize this direction and preview immediately.', ...
                        'Callback',@(~,~)R.onScaleNudge(axisIndex,direction));
                end
            end

            R.uiUndoAuto = uicontrol(trPanel,'Style','pushbutton','Units','normalized', ...
                'Position',[0.05 0.01 0.27 0.14], ...
                'String','Undo auto','Enable','off', ...
                'BackgroundColor',[0.82 0.60 0.18], ...
                'ForegroundColor','w', ...
                'FontWeight','bold', ...
                'Callback',@(src,evt)R.onUndoAuto());

            R.uiApply = uicontrol(trPanel,'Style','pushbutton','Units','normalized', ...
                'Position',[0.36 0.01 0.20 0.14], ...
                'String','Apply', ...
                'BackgroundColor',[0.20 0.45 0.95], ...
                'ForegroundColor','w', ...
                'FontWeight','bold', ...
                'Callback',@(src,evt)R.onApply());

            R.uiSave = uicontrol(trPanel,'Style','pushbutton','Units','normalized', ...
                'Position',[0.60 0.01 0.35 0.14], ...
                'String','Save transform', ...
                'BackgroundColor',[0.15 0.70 0.55], ...
                'ForegroundColor','w', ...
                'FontWeight','bold', ...
                'Callback',@(src,evt)R.onSave());

            R.uiSaveStatus = uicontrol(f,'Style','text','Units','normalized', ...
                'Position',[0.03 0.008 0.94 0.035], ...
                'String','', ...
                'BackgroundColor',panelBG2, ...
                'ForegroundColor',[0.7 0.95 0.7], ...
                'HorizontalAlignment','left', ...
                'FontSize',11);

            % Functional panel
            funcPanel = uipanel(ctrlPanel, ...
                'Units','normalized', ...
                'Position',[0.05 0.25 0.90 0.12], ...
                'BackgroundColor',panelBG2, ...
                'ForegroundColor',fg, ...
                'Title','Functional preview/register', ...
                'FontSize',11, ...
                'FontWeight','bold');

            popupStrings = {'No functional candidates found'};
            popupEnable = 'off';
            btnEnable = 'off';

            if ~isempty(R.funcLabels)
                popupStrings = R.funcLabels;
                popupEnable = 'on';
                btnEnable = 'on';
            end

            R.uiFuncPopup = uicontrol(funcPanel,'Style','popupmenu','Units','normalized', ...
                'Position',[0.05 0.56 0.90 0.22], ...
                'String',popupStrings, ...
                'Value',1, ...
                'Enable',popupEnable, ...
                'BackgroundColor',[0.15 0.15 0.15], ...
                'ForegroundColor',fg);

            R.uiFuncPreview = uicontrol(funcPanel,'Style','pushbutton','Units','normalized', ...
                'Position',[0.05 0.24 0.42 0.20], ...
                'String','Preview selected', ...
                'Enable',btnEnable, ...
                'BackgroundColor',[0.32 0.48 0.86], ...
                'ForegroundColor','w', ...
                'FontWeight','bold', ...
                'Callback',@(src,evt)R.onPreviewFunctional());

            R.uiFuncRegister = uicontrol(funcPanel,'Style','pushbutton','Units','normalized', ...
                'Position',[0.53 0.24 0.42 0.20], ...
                'String','Register selected', ...
                'Enable',btnEnable, ...
                'BackgroundColor',[0.64 0.42 0.20], ...
                'ForegroundColor','w', ...
                'FontWeight','bold', ...
                'Callback',@(src,evt)R.onRegisterFunctional());

            R.uiFuncStatus = uicontrol(funcPanel,'Style','text','Units','normalized', ...
                'Position',[0.05 0.03 0.90 0.12], ...
                'String','', ...
                'BackgroundColor',panelBG2, ...
                'ForegroundColor',[0.7 0.95 0.7], ...
                'HorizontalAlignment','left', ...
                'FontSize',9);
            if isempty(R.funcFiles),set(funcPanel,'Visible','off');end

            % Plane and atlas panel
            miscPanel = uipanel(ctrlPanel, ...
                'Units','normalized', ...
                'Position',[0.05 0.10 0.90 0.14], ...
                'BackgroundColor',panelBG2, ...
                'ForegroundColor',fg, ...
                'Title','Atlas display', ...
                'FontSize',11, ...
                'FontWeight','bold');

            uicontrol(miscPanel,'Style','text','Units','normalized', ...
                'Position',[0.03 0.58 0.16 0.18], ...
                'String','', ...
                'BackgroundColor',panelBG2,'ForegroundColor',fg, ...
                'HorizontalAlignment','left','FontSize',10,'FontWeight','bold');

            R.uiEditCor = uicontrol(miscPanel,'Style','edit','Units','normalized', ...
                'Position',[0.14 0.58 0.12 0.20], ...
                'String','1', ...
                'BackgroundColor',[0.12 0.12 0.12],'ForegroundColor',fg, ...
                'Callback',@(src,evt)R.onPlaneEdited());

            uicontrol(miscPanel,'Style','text','Units','normalized', ...
                'Position',[0.30 0.58 0.16 0.18], ...
                'String','', ...
                'BackgroundColor',panelBG2,'ForegroundColor',fg, ...
                'HorizontalAlignment','left','FontSize',10,'FontWeight','bold');

            R.uiEditSag = uicontrol(miscPanel,'Style','edit','Units','normalized', ...
                'Position',[0.40 0.58 0.12 0.20], ...
                'String','1', ...
                'BackgroundColor',[0.12 0.12 0.12],'ForegroundColor',fg, ...
                'Callback',@(src,evt)R.onPlaneEdited());

            uicontrol(miscPanel,'Style','text','Units','normalized', ...
                'Position',[0.56 0.58 0.16 0.18], ...
                'String','', ...
                'BackgroundColor',panelBG2,'ForegroundColor',fg, ...
                'HorizontalAlignment','left','FontSize',10,'FontWeight','bold');

            R.uiEditAxi = uicontrol(miscPanel,'Style','edit','Units','normalized', ...
                'Position',[0.66 0.58 0.12 0.20], ...
                'String','1', ...
                'BackgroundColor',[0.12 0.12 0.12],'ForegroundColor',fg, ...
                'Callback',@(src,evt)R.onPlaneEdited());

            slicePanel=uipanel(f,'Units','normalized','Position',[.03 .895 .63 .035], ...
                'BackgroundColor',panelBG2,'ForegroundColor',fg,'BorderType','none','Tag','AtlasSliceControls');
            editors=[R.uiEditCor R.uiEditAxi R.uiEditSag];
            names={'Coronal / AP','Axial / depth','Sagittal / LR'};
            for sliceControl=1:3
                x=(sliceControl-1)/3;
                uicontrol(slicePanel,'Style','text','Units','normalized','Position',[x .05 .22 .8], ...
                    'String',names{sliceControl},'BackgroundColor',panelBG2,'ForegroundColor',fg,'FontSize',12);
                set(editors(sliceControl),'Parent',slicePanel,'Position',[x+.22 .08 .10 .84], ...
                    'FontSize',13,'Tag',['AtlasSlice' num2str(sliceControl)], ...
                    'TooltipString','Enter atlas slice index; scroll over the corresponding image to browse.');
            end
            R.uiShowLines = uicontrol(miscPanel,'Style','checkbox','Units','normalized', ...
                'Position',[0.03 0.28 0.30 0.18], ...
                'String','Atlas lines', ...
                'Value',1, ...
                'BackgroundColor',panelBG2,'ForegroundColor',fg, ...
                'Callback',@(src,evt)R.onShowLines());

            uicontrol(miscPanel,'Style','checkbox','Units','normalized', ...
                'Position',[.03 .04 .33 .18],'String','Atlas underlay','Value',1, ...
                'Tag','AtlasShowUnderlay','BackgroundColor',panelBG2,'ForegroundColor',fg,'FontSize',11, ...
                'TooltipString','Show atlas anatomy beneath the moving overlay. Off: inspect the overlay alone on black; the fixed reference images and transform are unchanged.', ...
                'Callback',@(src,~)R.onShowAtlasUnderlay(src));

            uicontrol(miscPanel,'Style','popupmenu','Units','normalized','Position',[.03 .63 .92 .25], ...
                'String',{'Detailed regions','Parent regions (merge CPu / layers)'},'Value',1, ...
                'Tag','AtlasRegionGrouping','BackgroundColor',panelBG2,'ForegroundColor',fg, ...
                'FontSize',12,'Callback',@(src,~)R.onRegionGrouping(src));
            atlasModeStrings = {'vascular','histology','regions'};
            R.uiAtlasGroup = uibuttongroup(miscPanel, ...
                'Units','normalized', ...
                'Position',[0.38 0.10 0.57 0.35], ...
                'BackgroundColor',panelBG2, ...
                'ForegroundColor',fg, ...
                'SelectionChangedFcn',@(src,evt)R.onAtlasMode(evt.NewValue.Tag));

            R.uiAtlasVasc = uicontrol(R.uiAtlasGroup,'Style','radiobutton', ...
                'Units','normalized', ...
                'Position',[0.02 0.10 0.30 0.80], ...
                'String',atlasModeStrings{1}, ...
                'Tag','vascular', ...
                'Value',1, ...
                'BackgroundColor',panelBG2,'ForegroundColor',fg);

            R.uiAtlasHist = uicontrol(R.uiAtlasGroup,'Style','radiobutton', ...
                'Units','normalized', ...
                'Position',[0.34 0.10 0.30 0.80], ...
                'String',atlasModeStrings{2}, ...
                'Tag','histology', ...
                'BackgroundColor',panelBG2,'ForegroundColor',fg);

            R.uiAtlasReg = uicontrol(R.uiAtlasGroup,'Style','radiobutton', ...
                'Units','normalized', ...
                'Position',[0.66 0.10 0.30 0.80], ...
                'String',atlasModeStrings{3}, ...
                'Tag','regions', ...
                'BackgroundColor',panelBG2,'ForegroundColor',fg);

            R.uiHelp = uicontrol(ctrlPanel,'Style','pushbutton','Units','normalized', ...
                'Position',[0.05 0.02 0.42 0.05], ...
                'String','HELP', ...
                'BackgroundColor',[0.25 0.45 0.95], ...
                'ForegroundColor','w', ...
                'FontWeight','bold', ...
                'Callback',@(src,evt)R.onHelp());

            R.uiClose = uicontrol(ctrlPanel,'Style','pushbutton','Units','normalized', ...
                'Position',[0.53 0.02 0.42 0.05], ...
                'String','CLOSE', ...
                'BackgroundColor',[0.85 0.25 0.25], ...
                'ForegroundColor','w', ...
                'FontWeight','bold', ...
                'Callback',@(src,evt)R.onClose());

            semi=uicontrol(ctrlPanel,'Style','pushbutton','Units','normalized', ...
                'Position',[.05 .865 .58 .045],'String','2. Match three reference slices', ...
                'Tag','AtlasSemiAutomatic','BackgroundColor',[.16 .6 .34],'ForegroundColor','w', ...
                'FontSize',12,'FontWeight','bold','Callback',@(~,~)R.onSemiAutomatic());
            uicontrol(ctrlPanel,'Style','popupmenu','Units','normalized','Position',[.65 .865 .30 .045], ...
                'String',{'SNAP: Vascular','SNAP: Histology'},'Tag','AtlasSnapReference','Value',1, ...
                'BackgroundColor',[.15 .15 .15],'ForegroundColor','w','FontSize',12, ...
                'TooltipString','Fixed atlas underlay in ITK-SNAP review. This does not change your transform.', ...
                'Callback',@(src,~)R.onSnapReference(src));
            % Top actions have their own space above the overlay panel.
            set(R.uiAuto,'Position',[.05 .925 .60 .06]);
            snapButton=findobj(ctrlPanel,'Style','pushbutton','String','ITK-SNAP review');
            set(snapButton,'Position',[.69 .925 .26 .06]);
            set(ovPanel,'Position',[.05 .655 .90 .205]);
            uicontrol(ctrlPanel,'Style','pushbutton','Units','normalized','Position',[.05 .805 .58 .05], ...
                'String','SAVE TRANSFORM NOW','Tag','AtlasSaveTransformAs', ...
                'BackgroundColor',[.15 .70 .35],'ForegroundColor','w','FontWeight','bold','FontSize',13, ...
                'Callback',@(~,~)R.onSave());
            menu=uicontextmenu(R.H.figure1);uimenu(menu,'Label','Save as...','Callback',@(~,~)R.onSaveAs());
            set(findobj(ctrlPanel,'Tag','AtlasSaveTransformAs'),'UIContextMenu',menu,'TooltipString','Save a timestamped reviewed transform immediately. Right-click for Save as.');
            uicontrol(ctrlPanel,'Style','pushbutton','Units','normalized','Position',[.65 .805 .30 .05], ...
                'String','Import SNAP edit','Tag','AtlasImportSnap','BackgroundColor',[.16 .42 .75], ...
                'ForegroundColor','w','FontWeight','bold','Callback',@(~,~)R.onImportSnap());
            set(ovPanel,'Position',[.05 .635 .90 .165]);
            set([R.uiApply R.uiSave],'Visible','off'); % Size edits apply immediately; one clear Save button above.
            R.uiLivePreview=uicontrol(trPanel,'Style','checkbox','Units','normalized', ...
                'Position',[.36 .01 .60 .14],'String','Live 3D preview','Value',0,'Tag','AtlasLive3DPreview', ...
                'BackgroundColor',panelBG2,'ForegroundColor','w','FontSize',12, ...
                'TooltipString','Optional companion-model updates after manual edits. Leave off for responsive alignment; saving or closing updates the final model.', ...
                'Callback',@(src,~)R.onLivePreview(src));
            uicontrol(ctrlPanel,'Style','pushbutton','Units','normalized','Position',[.05 .38 .90 .05], ...
                'String','3. Refine matched alignment','Tag','AtlasRefineCurrent', ...
                'BackgroundColor',[.16 .60 .34],'ForegroundColor','w','FontWeight','bold', ...
                'TooltipString','Keep your position and manual sizing as the starting point; refine the full 3D fit within acquired coverage.', ...
                'Callback',@(~,~)R.onAutoRegister([],true));
                        % Create images
            R.im1 = image(zeros(R.ms1.ny, R.ms1.nz, 3), 'Parent', R.H.axes1);
            R.im2 = image(zeros(R.ms1.nx, R.ms1.nz, 3), 'Parent', R.H.axes2);
            R.im3 = image(zeros(R.ms1.ny, R.ms1.nx, 3), 'Parent', R.H.axes3);

            cla(R.H.axes4);
            R.im4Under = image(zeros(R.ms1.ny, R.ms1.nz, 3), 'Parent', R.H.axes4);
            set(R.im4Under,'HitTest','off','Tag','FixedAtlas');
            hold(R.H.axes4,'on');
            R.im4 = imagesc(zeros(R.ms1.ny, R.ms1.nz), 'Parent', R.H.axes4);
            set(R.im4,'AlphaData',R.overlayOpacity,'HitTest','on','Tag','MovingAnatomy');
            hold(R.H.axes4,'off');
            uistack(R.im4,'top');

            cla(R.H.axes5);
            R.im5Under = image(zeros(R.ms1.nx, R.ms1.nz, 3), 'Parent', R.H.axes5);
            set(R.im5Under,'HitTest','off');
            hold(R.H.axes5,'on');
            R.im5 = imagesc(zeros(R.ms1.nx, R.ms1.nz), 'Parent', R.H.axes5);
            set(R.im5,'AlphaData',R.overlayOpacity,'HitTest','on');
            hold(R.H.axes5,'off');
            uistack(R.im5,'top');

            cla(R.H.axes6);
            R.im6Under = image(zeros(R.ms1.ny, R.ms1.nx, 3), 'Parent', R.H.axes6);
            set(R.im6Under,'HitTest','off');
            hold(R.H.axes6,'on');
            R.im6 = imagesc(zeros(R.ms1.ny, R.ms1.nx), 'Parent', R.H.axes6);
            set(R.im6,'AlphaData',R.overlayOpacity,'HitTest','on');
            hold(R.H.axes6,'off');
            uistack(R.im6,'top');

            R.applyOverlayColormap();

            % Crosshairs
            R.line1x = line(R.H.axes1, [1 R.ms1.nz], [R.ms1.y0 R.ms1.y0], 'Color',[1 1 1], 'HitTest','off');
            R.line1y = line(R.H.axes1, [R.ms1.z0 R.ms1.z0], [1 R.ms1.ny], 'Color',[1 1 1], 'HitTest','off');

            R.line2x = line(R.H.axes2, [1 R.ms1.nz], [R.ms1.x0 R.ms1.x0], 'Color',[1 1 1], 'HitTest','off');
            R.line2y = line(R.H.axes2, [R.ms1.z0 R.ms1.z0], [1 R.ms1.nx], 'Color',[1 1 1], 'HitTest','off');

            R.line3x = line(R.H.axes3, [1 R.ms1.nx], [R.ms1.y0 R.ms1.y0], 'Color',[1 1 1], 'HitTest','off');
            R.line3y = line(R.H.axes3, [R.ms1.x0 R.ms1.x0], [1 R.ms1.ny], 'Color',[1 1 1], 'HitTest','off');

            R.line4x = line(R.H.axes4, [1 R.ms1.nz], [R.ms1.y0 R.ms1.y0], 'Color',[1 1 1], 'HitTest','off');
            R.line4y = line(R.H.axes4, [R.ms1.z0 R.ms1.z0], [1 R.ms1.ny], 'Color',[1 1 1], 'HitTest','off');

            R.line5x = line(R.H.axes5, [1 R.ms1.nz], [R.ms1.x0 R.ms1.x0], 'Color',[1 1 1], 'HitTest','off');
            R.line5y = line(R.H.axes5, [R.ms1.z0 R.ms1.z0], [1 R.ms1.nx], 'Color',[1 1 1], 'HitTest','off');

            R.line6x = line(R.H.axes6, [1 R.ms1.nx], [R.ms1.y0 R.ms1.y0], 'Color',[1 1 1], 'HitTest','off');
            R.line6y = line(R.H.axes6, [R.ms1.x0 R.ms1.x0], [1 R.ms1.ny], 'Color',[1 1 1], 'HitTest','off');

            R.hlinesS = gobjects(0);
            R.hlinesC = gobjects(0);
            R.hlinesT = gobjects(0);

            set(R.uiEditCor,'String',num2str(R.ms1.x0));
            set(R.uiEditSag,'String',num2str(R.ms1.z0));
            set(R.uiEditAxi,'String',num2str(R.ms1.y0));

            for k=1:numel(axAll), axis(axAll(k),'image'); axis(axAll(k),'off'); end
            R.bumpControlFonts(ctrlPanel, 12);
        end


        function bumpControlFonts(R, parentObj, minFS)
            h = findall(parentObj);
            for k = 1:numel(h)
                try
                    if isprop(h(k),'FontSize')
                        fs = get(h(k),'FontSize');
                        if isnumeric(fs) && isfinite(fs) && fs < minFS
                            set(h(k),'FontSize',minFS);
                        end
                    end
                catch
                end
            end
        end

        function restartMove(R)
            R.r1 = moveimage(R.H.axes4, R.im4);
            R.r1.onCommit=@()R.onApply();
            R.r1.onPreview=@()R.previewAlignment();

            if R.overlayCoronalOnly
                R.r2 = [];
                R.r3 = [];
            else
                R.r2 = moveimage(R.H.axes5, R.im5);
                R.r3 = moveimage(R.H.axes6, R.im6);
                R.r2.onCommit=@()R.onApply(); R.r3.onCommit=@()R.onApply();
                R.r2.onPreview=@()R.previewAlignment(); R.r3.onPreview=@()R.previewAlignment();
            end
        end

        function tf = anyDragging(R)
            tf = safeIsDragging(R.r1) || safeIsDragging(R.r2) || safeIsDragging(R.r3);
        end

        function TransfNow = getCurrentTransform(R)
            center=[(size(R.DataNoScale,[2 1 3])+1)/2 1]*R.T0;
            TS=fusiAtlasSizeMatrix(R.scale,center(1:3));

            tot = build3DrotationMatrix(R);

            TransfNow = struct();
            TransfNow.M = R.T0 * TS * R.Trot * tot;
            TransfNow.size = size(R.ms1.D);
            TransfNow.scanGeometry = R.scanGeometry;
            TransfNow.regionGrouping=R.regionMode;
            if ~isempty(TransfNow.scanGeometry)
                TransfNow.scanGeometry.atlasVoxelSizeUm=double(R.atlas.VoxelSize(:)');
            end
            TransfNow.autoRegistration = R.autoReport;
            if isfield(R.atlas,'deConfUSIon') && isfield(R.atlas.deConfUSIon,'source_atlas_path')
                TransfNow.atlasSource=R.atlas.deConfUSIon.source_atlas_path;
            end
            TransfNow.atlasVoxelSizeUm=double(R.atlas.VoxelSize(:)');
            TransfNow.atlasArrayOrder='AP-DV-LR';
        end

        function apply(R)
            tot = build3DrotationMatrix(R);
            R.Trot = R.Trot * tot;

            center=[(size(R.DataNoScale,[2 1 3])+1)/2 1]*R.T0;
            TS=fusiAtlasSizeMatrix(R.scale,center(1:3));

            R.TF = R.T0 * TS * R.Trot;

            % Interactive review only needs three planes. Full-volume
            % resampling belongs to functional export / the 3D model.
            R.cutCache=[];

            safeResetMove(R.r1);
            safeResetMove(R.r2);
            safeResetMove(R.r3);
        end

        function refresh(R)

            R.clampIndices();

            x0 = R.ms1.x0;
            y0 = R.ms1.y0;
            z0 = R.ms1.z0;

            set(R.uiSliceInfo,'String',sprintf('Coronal: %d/%d   Sagittal: %d/%d   Axial: %d/%d', ...
                x0, R.ms1.nx, z0, R.ms1.nz, y0, R.ms1.ny));

            set(R.uiEditCor,'String',num2str(x0));
            set(R.uiEditSag,'String',num2str(z0));
            set(R.uiEditAxi,'String',num2str(y0));

            atlasChanged=isempty(R.atlasCutCache)||~isequal(R.atlasCutCache.map,R.ms1)|| ...
                ~isequal(R.atlasCutCache.indices,[x0 y0 z0]);
            if atlasChanged
            [aCor, aSag, aAxi] = R.ms1.cuts();

            set(R.im1,'CData',aCor);
            set(R.im2,'CData',aSag);
            set(R.im3,'CData',permute(aAxi,[2 1 3]));

            set(R.im4Under,'CData',aCor);
            set(R.im5Under,'CData',aSag);
            set(R.im6Under,'CData',permute(aAxi,[2 1 3]));

                R.atlasCutCache=struct('map',R.ms1,'indices',[x0 y0 z0]);
            end

            indices=[x0 y0 z0];
            if isempty(R.cutCache)
                [cor,axi,sag]=AtlasRegistration('previewcuts',R.previewSampler,R.TF,size(R.ms1.D),indices);
                R.cutCache=struct('indices',indices,'planes',{{cor,axi,sag}});
            elseif ~isequal(R.cutCache.indices,indices)
                requested=indices~=R.cutCache.indices;
                [cor,axi,sag]=AtlasRegistration('previewcuts',R.previewSampler,R.TF,size(R.ms1.D),indices,requested);
                newPlanes={cor,axi,sag};
                for plane=find(requested),R.cutCache.planes{plane}=newPlanes{plane};end
                R.cutCache.indices=indices;
            end
            raw=R.cutCache.planes;

            wmin = R.overlayWinMin;
            wmax = R.overlayWinMax;
            if wmax <= wmin
                wmax = wmin + 0.01;
            end

            [oCor,aCorOverlay]=fusiRegistrationOverlayAppearance(raw{1},[wmin wmax],R.overlayGain,R.overlayGamma,R.overlayOpacity,R.overlayInvert);
            [oSag,aSagOverlay]=fusiRegistrationOverlayAppearance(raw{2},[wmin wmax],R.overlayGain,R.overlayGamma,R.overlayOpacity,R.overlayInvert);
            [oAxi,aAxiOverlay]=fusiRegistrationOverlayAppearance(raw{3},[wmin wmax],R.overlayGain,R.overlayGamma,R.overlayOpacity,R.overlayInvert);
            set([R.H.axes4 R.H.axes5 R.H.axes6],'CLim',[0 1]);

            if isempty(R.r1) || ~isvalidHandleObj(R.r1)
                set(R.im4,'CData',oCor);
            else
                R.r1.setImageData(oCor);
            end

            if isempty(R.r2) || ~isvalidHandleObj(R.r2)
                set(R.im5,'CData',oSag);
            else
                R.r2.setImageData(oSag);
            end

            if isempty(R.r3) || ~isvalidHandleObj(R.r3)
                set(R.im6,'CData',oAxi);
            else
                R.r3.setImageData(oAxi);
            end

            set(R.im4,'Visible','on','AlphaData',aCorOverlay);

            if R.overlayCoronalOnly
                set(R.im5,'Visible','off','AlphaData',0);
                set(R.im6,'Visible','off','AlphaData',0);
            else
                set(R.im5,'Visible','on','AlphaData',aSagOverlay);
                set(R.im6,'Visible','on','AlphaData',aAxiOverlay);
            end

            set([R.im4Under R.im5Under R.im6Under],'AlphaData',double(R.showAtlasUnderlay),'Tag','AtlasReferenceUnderlayImage');
            for imageHandle=[R.im4 R.im5 R.im6], uistack(imageHandle,'top'); end
            if atlasChanged
            set(R.line1x,'XData',[1 R.ms1.nz],'YData',[y0 y0]);
            set(R.line1y,'XData',[z0 z0],'YData',[1 R.ms1.ny]);

            set(R.line2x,'XData',[1 R.ms1.nz],'YData',[x0 x0]);
            set(R.line2y,'XData',[z0 z0],'YData',[1 R.ms1.nx]);

            set(R.line3x,'XData',[1 R.ms1.nx],'YData',[y0 y0]);
            set(R.line3y,'XData',[x0 x0],'YData',[1 R.ms1.ny]);

            set(R.line4x,'XData',[1 R.ms1.nz],'YData',[y0 y0]);
            set(R.line4y,'XData',[z0 z0],'YData',[1 R.ms1.ny]);

            set(R.line5x,'XData',[1 R.ms1.nz],'YData',[x0 x0]);
            set(R.line5y,'XData',[z0 z0],'YData',[1 R.ms1.nx]);

            set(R.line6x,'XData',[1 R.ms1.nx],'YData',[y0 y0]);
            set(R.line6y,'XData',[x0 x0],'YData',[1 R.ms1.ny]);

            end

            lineIndices=[x0 y0 z0];lineAxes=[R.H.axes4 R.H.axes5 R.H.axes6];
            lineFields={'hlinesC','hlinesT','hlinesS'};lineMaps={R.linmap.Cor,R.linmap.Tra,R.linmap.Sag};
            if ~iscell(R.lastLinesKey),R.lastLinesKey=cell(1,3);end
            for plane=1:3
                linesKey={lineIndices(plane),R.showAtlasLines,R.regionMode,R.showAtlasUnderlay};
                if isequal(linesKey,R.lastLinesKey{plane}),continue;end
                safeDeleteGraphics(R.(lineFields{plane}));R.(lineFields{plane})=gobjects(0);
                if R.showAtlasLines && R.showAtlasUnderlay
                    if strcmp(R.regionMode,'Detailed')
                        R.(lineFields{plane})=addLines(lineAxes(plane),lineMaps{plane},clampToNumel(lineMaps{plane},lineIndices(plane)));
                    else
                        switch plane
                            case 1,L=squeeze(R.groupedRegions(x0,:,:));
                            case 2,L=squeeze(R.groupedRegions(:,y0,:));
                            case 3,L=squeeze(R.groupedRegions(:,:,z0))';
                        end
                        R.(lineFields{plane})=fusiDrawRegionBoundaries(lineAxes(plane),L);
                    end
                end
                R.lastLinesKey{plane}=linesKey;
            end

            drawnow limitrate nocallbacks;
        end
        function onShowAtlasUnderlay(R,src)
            R.showAtlasUnderlay=logical(get(src,'Value'));
            set([R.H.axes4 R.H.axes5 R.H.axes6],'Color','k');
            R.refresh();
        end

        function onOverlayChanged(R)

            if ~isempty(R.uiOpacity) && isgraphics(R.uiOpacity)
                R.overlayOpacity = get(R.uiOpacity,'Value');
            end

            wmin = str2double(get(R.uiWinMin,'String'));
            wmax = str2double(get(R.uiWinMax,'String'));
            if ~isfinite(wmin)
                wmin = R.overlayWinMin;
            end
            if ~isfinite(wmax)
                wmax = R.overlayWinMax;
            end

            wmin = max(0, min(.99, wmin));
            wmax = max(0, min(1, wmax));
            if wmax <= wmin
                wmax = min(1, wmin + 0.01);
            end

            R.overlayWinMin = wmin;
            R.overlayWinMax = wmax;
            set(R.uiWinMin,'String',num2str(R.overlayWinMin));
            set(R.uiWinMax,'String',num2str(R.overlayWinMax));
            gain=str2double(get(R.uiOverlayGain,'String'));gamma=str2double(get(R.uiOverlayGamma,'String'));
            if isfinite(gain)&&gain>0,R.overlayGain=gain;end
            if isfinite(gamma)&&gamma>0,R.overlayGamma=gamma;end
            set(R.uiOverlayGain,'String',num2str(R.overlayGain));
            set(R.uiOverlayGamma,'String',num2str(R.overlayGamma));

            R.overlayInvert = logical(get(R.uiInvert,'Value'));

            cmapList = get(R.uiCmapPopup,'String');
            idx = get(R.uiCmapPopup,'Value');
            if iscell(cmapList)
                R.overlayCmapName = cmapList{idx};
            else
                R.overlayCmapName = deblank(cmapList(idx,:));
            end

            R.applyOverlayColormap();
            R.refresh();

            set(R.uiOverlayStatus,'String',sprintf( ...
                'Opacity %.2f | Win [%.2f %.2f] | Gain %.2f | Gamma %.2f | %s', ...
                R.overlayOpacity, R.overlayWinMin, R.overlayWinMax,R.overlayGain,R.overlayGamma,R.overlayCmapName));
        end

        function onDisplayPreset(R,src)
            choices=get(src,'String');R.displayPreset=choices{get(src,'Value')};
            if strcmp(R.displayPreset,'Saved Mask Editor')
                if isempty(R.savedDisplayData),R.DataNoScale=fusiRegistrationDisplayVolume(R.RegistrationData,'Mask Editor standard');
                else,R.DataNoScale=R.savedDisplayData;end
            else
                R.DataNoScale=fusiRegistrationDisplayVolume(R.RegistrationData,R.displayPreset);
            end
            R.previewSampler=griddedInterpolant(single(R.DataNoScale),'linear','none');
            R.apply();R.refresh();
        end

        function applyOverlayColormap(R)

            switch lower(R.overlayCmapName)
                case 'cyan'
                    cmap = [zeros(256,1) linspace(.25,1,256)' linspace(.4,1,256)'];
                case 'red'
                    cmap = [linspace(0,1,256)' zeros(256,1) zeros(256,1)];
                otherwise
                    try
                        cmap = feval(R.overlayCmapName, 256);
                    catch
                        cmap = gray(256);
                        R.overlayCmapName = 'gray';
                    end
            end

            colormap(R.H.axes4, cmap);
            colormap(R.H.axes5, cmap);
            colormap(R.H.axes6, cmap);
        end

        function onPlaneEdited(R)
            cor = round(str2double(get(R.uiEditCor,'String')));
            sag = round(str2double(get(R.uiEditSag,'String')));
            axi = round(str2double(get(R.uiEditAxi,'String')));

            if isnan(cor), cor = R.ms1.x0; end
            if isnan(sag), sag = R.ms1.z0; end
            if isnan(axi), axi = R.ms1.y0; end

            R.ms1.x0 = cor;
            R.ms1.y0 = axi;
            R.ms1.z0 = sag;

            R.ms2.x0 = R.ms1.x0;
            R.ms2.y0 = R.ms1.y0;
            R.ms2.z0 = R.ms1.z0;

            R.refresh();
        end

        function onRegionGrouping(R,src)
            wasRegions=isequal(R.ms1,R.mapRegions);
            R.regionMode='Detailed';if get(src,'Value')==2,R.regionMode='Parent';end
            [R.groupedRegions,R.groupedRegionInfo]=fusiAtlasRegionGrouping(R.atlas,R.regionMode);
            R.mapRegions=mapscan(R.groupedRegions,R.groupedRegionInfo.rgb,'index');
            if wasRegions,R.ms1=R.mapRegions;R.ms1.x0=R.ms2.x0;R.ms1.y0=R.ms2.y0;R.ms1.z0=R.ms2.z0;end
            R.lastLinesKey=[];R.refresh();
        end

        function onAtlasMode(R, tag)
            switch lower(tag)
                case 'vascular'
                    R.ms1 = R.mapVascular;
                case 'histology'
                    R.ms1 = R.mapHistology;
                case 'regions'
                    R.ms1 = R.mapRegions;
                otherwise
                    R.ms1 = R.mapVascular;
            end

            R.ms1.x0 = R.ms2.x0;
            R.ms1.y0 = R.ms2.y0;
            R.ms1.z0 = R.ms2.z0;

            if any(strcmpi(tag,{'histology','vascular'})),R.setSnapReference(tag);end

            R.refresh();
        end

        function onShowLines(R)
            R.showAtlasLines = logical(get(R.uiShowLines,'Value'));
            R.refresh();
        end

        function onApply(R)

            sx = str2double(get(R.uiScaleCorX,'String'));
            sy = str2double(get(R.uiScaleSagY,'String'));
            sz = str2double(get(R.uiScaleAxiZ,'String'));

            if any(~isfinite([sx sy sz])|[sx sy sz]<=0)
                set(R.uiSaveStatus,'String','Size factors must be finite and positive (1 = unchanged). Previous alignment preserved.');return;
            end

            R.scale = [sx sy sz];

            R.cancelPreview();
            R.apply();
            R.refresh();
            R.queuePreview();

            message='Alignment updated. Save or close to update the 3D model.';
            if R.livePreview,message='Alignment updated. The 3D preview follows after adjustments pause.';end
            set(R.uiSaveStatus,'String',message);
            R.log('[Atlas GUI] Apply executed.');
        end

        function onAutoRegister(R,cfg,refineCurrent)
            if nargin<3,refineCurrent=false;end
            if R.autoBusy
                setappdata(R.H.figure1,'AtlasAutoCancel',true); return;
            end
            if R.autoSetupBusy, return; end
            if nargin<2 || (isempty(cfg) && refineCurrent)
                R.autoSetupBusy=true; setupGuard=onCleanup(@()R.finishAutoSetup());
                current=R.getCurrentTransform();
                spec=struct('sourceSliceCount',size(R.RegistrationData,1),'useCurrent',refineCurrent || norm(current.M-eye(4),'fro')>1e-8);
                if ~isempty(R.scanGeometry),spec.sourceSliceCount=R.scanGeometry.originalSize(R.scanGeometry.permutation(1));end
                if isstruct(R.autoReport) && isfield(R.autoReport,'sliceSelection')
                    spec.sourceSliceRange=R.autoReport.sliceSelection.sourceSliceRange;
                elseif isstruct(R.autoReport) && isfield(R.autoReport,'anchors')
                    sourceSlices=[R.autoReport.anchors.sourceSlice];spec.sourceSliceRange=[min(sourceSlices) max(sourceSlices)];
                end
                cfg=AtlasRegistration('settings',R.H.figure1,spec);
                clear setupGuard;
            end
            if isempty(cfg), return; end
            if refineCurrent,cfg.useCurrent=true;cfg.searchInitialization=false;end
            R.cancelPreview();
            previous=R.getCurrentTransform();
            controls=findall(R.H.figure1,'Type','uicontrol');
            enabled=get(controls,'Enable');
            R.autoBusy=true; setappdata(R.H.figure1,'AtlasAutoCancel',false);
            setappdata(R.H.figure1,'AtlasAutoBusy',true);
            guard=onCleanup(@()R.finishAuto(controls,enabled)); %#ok<NASGU>
            set(controls,'Enable','off');
            set(R.uiAuto,'Enable','on','String','Cancel registration','BackgroundColor',[.65 .2 .24]);
            cfg.cancelFcn=@()getappdata(R.H.figure1,'AtlasAutoCancel');
            cfg.progressFcn=@(msg)set(R.uiSaveStatus,'String',msg);
            cfg.voxelSizeUm=double(R.atlas.VoxelSize(:)');
            try
                if strcmpi(cfg.target,'histology'), fixed=R.mapHistology.D;
                else, fixed=R.mapVascular.D; end
                [cfg,seed]=fusiRegistrationConfigureSlices(cfg,R.scanGeometry,size(R.RegistrationData),previous.M,size(fixed));
                [M,report]=AtlasRegistration('register',fixed,R.RegistrationData,cfg,seed);
                R.autoUndo=previous;
                R.installMatrix(M); R.autoReport=report;
                R.overlayOpacity=.85; set(R.uiOpacity,'Value',.85);
                R.onAtlasMode(cfg.target); R.refresh();
                msg=sprintf('Unsaved automatic alignment ready (%s): NMI %.3f -> %.3f. Review all planes, then SAVE TRANSFORM NOW, or Undo auto.', ...
                    report.engine,report.nmiBefore,report.nmiAfter);
                if ~report.refinementAccepted, msg=[msg ' ' report.refinementNote]; end
                R.publishPreview();msg=[msg ' Unsaved preview; use SAVE TRANSFORM to keep it.'];
                set(R.uiSaveStatus,'String',sprintf('Automatic alignment ready (%s). Review all planes, then match reference slices or SAVE TRANSFORM NOW.',report.engine), ...
                    'TooltipString',msg); R.log(['[Atlas GUI] ' msg]);
                if (isfield(cfg,'openReview') && cfg.openReview) || ...
                        (any(strcmpi(cfg.engine,{'greedy','compare'})) && ~isfield(cfg,'openReview'))
                    reference=cfg.target;
                    if isfield(cfg,'snapReference') && ~strcmpi(cfg.snapReference,'target'),reference=cfg.snapReference;end
                    R.onReviewSnap(reference);
                end
            catch ME
                R.installMatrix(previous.M); R.autoReport=previous.autoRegistration;
                set(R.uiSaveStatus,'String',ME.message); R.log(['[Atlas GUI] ' ME.message]);
            end
        end

        function onSemiAutomatic(R,slices,apSeed,reverseAP)
            if nargin<3,apSeed=[];end
            if nargin<4,reverseAP=[];end % Empty asks; logical input is explicit API confirmation.
            if R.autoBusy || R.autoSetupBusy,return;end
            R.cancelPreview();
            n=size(R.RegistrationData,1);ratio=1;flipAP=false;
            if ~isempty(R.scanGeometry) && isfield(R.scanGeometry,'originalSize')
                g=R.scanGeometry;axis=g.permutation(1);n=g.originalSize(axis);
                ratio=g.originalSpacingUm(axis)/R.atlas.VoxelSize(1);
                flipAP=isfield(g,'flipAxes') && ismember(1,g.flipAxes);
            end
            if nargin<2
                sliceDefaults=R.referenceSliceDefaults();
                answer=inputdlg({'Choose three scan slices to match manually: first, middle and last usable slices. Each matched scan/atlas pair guides the 3D fit (an anchor). Previous matches reopen if unchanged:', ...
                    'Optional first/last AP (mm from bregma; anterior +, posterior -), e.g. 2 -3:', ...
                    'Atlas AP index at bregma (required only for AP seed; this atlas has no saved bregma metadata):'}, ...
                    'Semi-automatic 3D alignment',1,{strtrim(sprintf('%d ',sliceDefaults)),'',getpref('deConfUSIon','atlasBregmaIndexText','')});
                if isempty(answer),return;end;slices=sscanf(answer{1},'%f')';
                if ~isempty(strtrim(answer{2}))
                    try
                        apSeed=fusiBregmaAnchors(slices,sscanf(answer{2},'%f')',str2double(answer{3}),R.atlas.VoxelSize(1),size(R.atlas.Histology,1));
                        setpref('deConfUSIon','atlasBregmaIndexText',answer{3});
                    catch ME,set(R.uiSaveStatus,'String',ME.message);return;end
                end
            end
            if numel(slices)~=3 || any(~isfinite(slices)) || any(slices~=round(slices)) || ...
                    slices(1)<1 || slices(3)>n || any(diff(slices)<=0)
                set(R.uiSaveStatus,'String','Enter three increasing source slices inside the recording.');return;
            end
            controls=findall(R.H.figure1,'Type','uicontrol');enabled=get(controls,'Enable');
            R.autoSetupBusy=true;set(controls,'Enable','off');
            guard=onCleanup(@()R.finishSemi(controls,enabled)); %#ok<NASGU>
            previous=R.getCurrentTransform();anchors=struct([]);apReversed=false;previousGeometry=R.scanGeometry;retainedDraft=R.anchorDraft;
            preparedPositions=1+(slices-1)*ratio;
            if flipAP,preparedPositions=1+(n-slices)*ratio;end
            preparedPositions=min(size(R.DataNoScale,1),max(1,preparedPositions));
            try
            for k=1:3
                q=preparedPositions(k);
                % Actual native AP position is retained even if fractional on the atlas grid.
                % INTERPN scalar/vector query conventions vary; explicit grid is clearer.
                [dv,lr]=ndgrid(1:size(R.DataNoScale,2),1:size(R.DataNoScale,3));
                plane=squeeze(interpn(R.DataNoScale,q*ones(size(dv)),dv,lr,'linear',0));
                point=[(size(plane,1)+1)/2 q (size(plane,2)+1)/2 1]*previous.M;
                if ~isempty(anchors),point(2)=anchors(1).atlasSliceIndex+q-preparedPositions(1);end
                if ~isempty(apSeed),point(2)=apSeed.atlasIndices(k);end
                init=struct('atlasMode','histology','atlasSliceIndex',min(size(R.atlas.Histology,1),max(1,round(point(2)))), ...
                    'opacity',.85,'winMin',0,'winMax',1,'cmapName','hot', ...
                    'tx',point(3)-(size(plane,2)+1)/2,'ty',point(1)-(size(plane,1)+1)/2, ...
                    'sx',norm(previous.M(3,1:3)),'sy',norm(previous.M(1,1:3)), ...
                    'rotDeg',atan2d(previous.M(3,1),previous.M(3,3)));
                if ~isempty(retainedDraft)
                    index=find([retainedDraft.sourceSlice]==slices(k),1);
                    if ~isempty(index)
                        retained=retainedDraft(index);A=retained.M;c=[(size(plane,2)+1)/2 (size(plane,1)+1)/2];t=A(3,1:2)+c*A(1:2,1:2)-c;
                        init.tx=t(1);init.ty=t(2);init.sx=norm(A(1,1:2));init.sy=norm(A(2,1:2));init.rotDeg=atan2d(A(1,2),A(1,1));
                        if isempty(apSeed),init.atlasSliceIndex=retained.atlasSliceIndex;end
                    end
                end
                info=struct('anchorOnly',true,'displayIsProcessed',true,'preparedAP',q, ...
                    'originalSlice',slices(k),'label',sprintf('Reference slice %d of 3 | scan slice %d: choose matching atlas plane',k,slices(k)));
                reference=init.atlasSliceIndex;if ~isempty(anchors),reference=anchors(1).atlasSliceIndex;end
                info.sliceGuide=struct('sourceSlices',slices,'preparedPositions',preparedPositions,'current',k, ...
                    'referenceAtlasIndex',reference,'atlasCount',size(R.atlas.Histology,1), ...
                    'scanSpacingUm',ratio*R.atlas.VoxelSize(1),'atlasSpacingUm',R.atlas.VoxelSize(1));
                info.acceptedAnchors=anchors;info.atlasVoxelSize=R.atlas.VoxelSize;
                anchor=registration_coronal_2d(R.atlas,plane,info,init,R.saveDir);
                if isempty(anchor),set(R.uiSaveStatus,'String','Anchor alignment cancelled; previous 3D transform preserved.');return;end
                if isempty(anchors),anchors=anchor;else,anchors(end+1)=anchor;end %#ok<AGROW>
                R.anchorDraft=anchors;
            end
                R.anchorDraft=anchors;
                [~,order]=sort([anchors.preparedAP]);positions=[anchors.atlasSliceIndex];
                if all(diff(positions(order))<0) && ~isempty(R.scanGeometry)
                    if isempty(reverseAP)
                        choice=questdlg(sprintf('Source slices %s map to atlas AP %s. Their direction is reversed. Is this acquisition ordered posterior to anterior relative to the current geometry? Reverse AP keeps your accepted anchors and does not change left/right.',mat2str([anchors.sourceSlice]),mat2str(positions)), ...
                            'Confirm acquisition AP direction','Reverse source AP','Recheck anchors','Recheck anchors');
                    elseif isequal(reverseAP,true),choice='Reverse source AP';else,choice='Recheck anchors';end
                    if strcmp(choice,'Reverse source AP')
                        R.RegistrationData=flip(R.RegistrationData,1);R.DataNoScale=flip(R.DataNoScale,1);R.previewSampler=griddedInterpolant(single(R.DataNoScale),'linear','none');
                        if ~isempty(R.savedDisplayData),R.savedDisplayData=flip(R.savedDisplayData,1);end
                        if ~isfield(R.scanGeometry,'flipAxes'),R.scanGeometry.flipAxes=[];end
                        R.scanGeometry.flipAxes=setxor(R.scanGeometry.flipAxes,1);
                        apReversed=true;
                        for j=1:numel(anchors),anchors(j).preparedAP=size(R.DataNoScale,1)+1-anchors(j).preparedAP;end
                        R.anchorDraft=anchors;
                    end
                end
                [M,report]=fusiFitCoronalAnchors(anchors,[size(R.DataNoScale,2) size(R.DataNoScale,3)],R.atlas.VoxelSize);
                if ~isempty(apSeed),report.bregmaSeed=apSeed;end
                R.autoUndo=previous;R.installMatrix(M);R.autoReport=report;R.refresh();
                R.publishPreview();
                R.anchorDraft=[];
                set(R.uiUndoAuto,'Enable','on');
                set(R.uiSaveStatus,'String','Three reference slices applied. Review all planes; refine if needed, then SAVE TRANSFORM NOW.', ...
                    'TooltipString',sprintf('Reference slice fitting errors: %.3f / %.3f / %.3f mm. This preview is not saved yet.',report.anchorRMSErrorMm));
            catch ME
                if apReversed
                    R.RegistrationData=flip(R.RegistrationData,1);R.DataNoScale=flip(R.DataNoScale,1);R.previewSampler=griddedInterpolant(single(R.DataNoScale),'linear','none');R.scanGeometry=previousGeometry;
                    if ~isempty(R.savedDisplayData),R.savedDisplayData=flip(R.savedDisplayData,1);end
                    for j=1:numel(R.anchorDraft),R.anchorDraft(j).preparedAP=size(R.DataNoScale,1)+1-R.anchorDraft(j).preparedAP;end
                end
                R.installMatrix(previous.M);R.autoReport=previous.autoRegistration;
                if isgraphics(R.H.figure1),set(R.uiSaveStatus,'String',ME.message);end
                R.log(['[Atlas anchors] ' ME.message]);
            end
        end

        function finishSemi(R,controls,enabled)
            R.autoSetupBusy=false;
            for k=1:numel(controls)
                if isgraphics(controls(k)),set(controls(k),'Enable',enabled{k});end
            end
            if isgraphics(R.H.figure1) && ~isempty(R.autoUndo),set(R.uiUndoAuto,'Enable','on');end
        end

        function finishAutoSetup(R)
            drawnow; R.autoSetupBusy=false;
        end

        function finishAuto(R,controls,enabled)
            R.autoBusy=false;
            for k=1:numel(controls)
                if isgraphics(controls(k)), set(controls(k),'Enable',enabled{k}); end
            end
            if ~isgraphics(R.H.figure1), return; end
            setappdata(R.H.figure1,'AtlasAutoBusy',false);
            set(R.uiAuto,'String','1. Auto: fit anatomy','BackgroundColor',[.16 .60 .34]);
            if ~isempty(R.autoUndo), set(R.uiUndoAuto,'Enable','on'); end
            set(R.H.figure1,'Pointer','arrow');
        end

        function onSnapReference(R,src)
            names={'vascular','histology'};R.setSnapReference(names{get(src,'Value')});
        end

        function slices=referenceSliceDefaults(R)
            % Carry the automatic fit's usable range into manual matching.
            % A scan fitted on 15-45 should offer 15/30/45, not its bad ends.
            n=size(R.RegistrationData,1);ratio=1;flipAP=false;
            if ~isempty(R.scanGeometry) && isfield(R.scanGeometry,'originalSize')
                g=R.scanGeometry;axis=g.permutation(1);n=g.originalSize(axis);
                ratio=g.originalSpacingUm(axis)/R.atlas.VoxelSize(1);
                flipAP=isfield(g,'flipAxes') && ismember(1,g.flipAxes);
            end
            cfg=struct('trimEmptySlices',true);
            if isstruct(R.autoReport) && isfield(R.autoReport,'sliceSelection')
                cfg.preparedSliceRange=R.autoReport.sliceSelection.preparedSliceRange;
            end
            [~,quality]=fusiRegistrationSliceSupport(R.RegistrationData,cfg);
            usable=1+(quality.preparedSliceRange-1)/ratio;
            if flipAP,usable=n+1-usable;end
            usable=sort(usable);first=max(1,ceil(usable(1)));last=min(n,floor(usable(2)));
            slices=[first round((first+last)/2) last];
            if isstruct(R.autoReport) && isfield(R.autoReport,'anchors') && numel(R.autoReport.anchors)==3
                slices=sort([R.autoReport.anchors.sourceSlice]);
            end
            if ~isempty(R.anchorDraft),slices=[R.anchorDraft.sourceSlice];end
        end

        function onScaleNudge(R,axisIndex,direction)
            if R.autoBusy,return;end
            fields=[R.uiScaleCorX R.uiScaleSagY R.uiScaleAxiZ];
            value=str2double(get(fields(axisIndex),'String'));
            step=[.01 .05 .10];step=step(get(R.uiScaleStep,'Value'));
            next=round((value+direction*step)*1e6)/1e6;
            if ~isfinite(value) || value<=0 || next<=0
                set(R.uiSaveStatus,'String','Size factors must stay finite and positive. Previous alignment preserved.');
                return;
            end
            set(fields(axisIndex),'String',sprintf('%.6g',next));
            R.onApply();
        end

        function setSnapReference(R,target)
            assert(any(strcmpi(target,{'histology','vascular'})),'Choose Histology or Vascular for SNAP review.');
            R.snapReference=lower(target);
            control=findobj(R.H.figure1,'Tag','AtlasSnapReference');
            if ~isempty(control),set(control,'Value',1+strcmpi(target,'histology'));end
        end

        function onReviewSnap(R,target,launch)
            if nargin<2,target=R.snapReference;end
            if nargin<3,launch=true;end
            R.setSnapReference(target);
            if R.reviewBusy, return; end
            R.reviewBusy=true;
            guard=onCleanup(@()R.finishReview()); %#ok<NASGU>
            try
                proposal=R.getCurrentTransform();
                fixed=R.mapVascular.D;
                if strcmpi(target,'histology'),fixed=R.mapHistology.D;end
                if ~isempty(R.reviewBundle) && isequal(proposal.M,R.reviewMatrix) && strcmp(target,R.reviewTarget)
                    if launch,R.reviewBundle.process=fusiOpenSnapWorkspace(R.reviewBundle.executable,R.reviewBundle.workspace);end
                    if launch,set(R.uiSaveStatus,'String',['Verified ITK-SNAP window opened with ' target ' underlay. Use Tools > Registration > Manual.']);end
                    return;
                end
                regions=R.atlas.Regions;regionInfo=R.atlas.infoRegions;
                if ~strcmp(R.regionMode,'Detailed'),regions=R.groupedRegions;regionInfo=R.groupedRegionInfo;end
                bundle=AtlasRegistration('review',fixed,R.DataNoScale,regions, ...
                    regionInfo,proposal.M,R.atlas.VoxelSize,R.saveDir,launch);
                R.reviewBundle=bundle; R.reviewMatrix=proposal.M; R.reviewTarget=target;
                message=['SNAP review files created with ' target ' underlay.'];
                if launch,message=['Verified ITK-SNAP window opened with ' target ' underlay. Tools > Registration > Manual; select aligned_anatomy. Save its transform, then Import SNAP edit here.'];end
                set(R.uiSaveStatus,'String',[message ' Files: ' bundle.folder]);
                R.log(['[Atlas GUI] Review bundle: ' bundle.folder]);
            catch ME
                set(R.uiSaveStatus,'String',['ITK-SNAP review: ' ME.message]); R.log(ME.message);
            end
        end

        function finishReview(R)
            % Drain repeated clicks while the review guard is still active.
            drawnow; R.reviewBusy=false;
        end

        function previewAlignment(R)
            t=now*86400;
            if R.autoBusy || t-R.lastDragPreview<.12, return; end
            R.lastDragPreview=t;
            proposal=R.getCurrentTransform();
            [cor,axi,sag]=AtlasRegistration('previewcuts',R.previewSampler,proposal.M,size(R.ms1.D), ...
                [R.ms1.x0 R.ms1.y0 R.ms1.z0]);
            views={cor,axi,sag}; movers={R.r1,R.r2,R.r3}; handles=[R.im4 R.im5 R.im6];
            for k=1:3
                [D,alpha]=fusiRegistrationOverlayAppearance(views{k},[R.overlayWinMin R.overlayWinMax], ...
                    R.overlayGain,R.overlayGamma,R.overlayOpacity,R.overlayInvert);
                if safeIsDragging(movers{k})
                    set(handles(k),'AlphaData',alpha); continue;
                end
                set(handles(k),'CData',D,'AlphaData',alpha);
            end
        end

        function installMatrix(R,M)
            % Clear uncommitted mouse drags before applying a replacement
            % matrix, otherwise the old drag would be applied a second time.
            safeResetMove(R.r1); safeResetMove(R.r2); safeResetMove(R.r3);
            R.T0=M; R.Trot=eye(4); R.scale=[1 1 1];
            set([R.uiScaleCorX R.uiScaleSagY R.uiScaleAxiZ],'String','1');
            R.apply(); R.refresh();
        end

        function onUndoAuto(R)
            if isempty(R.autoUndo) || R.autoBusy, return; end
            previous=R.autoUndo; R.installMatrix(previous.M);
            R.autoReport=previous.autoRegistration; R.autoUndo=[];
            R.publishPreview();
            set(R.uiUndoAuto,'Enable','off');
            set(R.uiSaveStatus,'String','Automatic proposal discarded. Previous alignment restored.');
        end

        function onSaveAs(R,outFile)
            if nargin<2
                [file,folder]=uiputfile('*.mat','Save current animal atlas transform',fullfile(R.saveDir,'Transformation.mat'));
                if isequal(file,0),return;end
                outFile=fullfile(folder,file);
            end
            R.onSave(outFile);
        end

        function onImportSnap(R,file,proposalFile)
            try
                if nargin<3
                    if isempty(R.reviewBundle),error('Open ITK-SNAP review from this editor first.');end
                    proposalFile=R.reviewBundle.session;
                end
                if nargin<2
                    if isstruct(proposalFile),startFolder=R.reviewBundle.folder;else,startFolder=fileparts(proposalFile);end
                    [name,folder]=uigetfile({'*.txt;*.tfm;*.mat','ITK affine text / Convert3D RAS matrix'}, ...
                        'Import manually saved ITK-SNAP transform',startFolder);
                    if isequal(name,0),return;end;file=fullfile(folder,name);
                end
                previous=R.getCurrentTransform();
                [M,report]=fusiImportSnapAdjustment(file,proposalFile,previous.M);
                R.installMatrix(M);R.autoUndo=previous;R.autoReport=report;R.refresh();
                R.publishPreview();
                set(R.uiUndoAuto,'Enable','on');
                set(R.uiSaveStatus,'String','SNAP adjustment imported. Review all planes, then SAVE TRANSFORM NOW to update the 3D model.');
            catch ME
                set(R.uiSaveStatus,'String',['SNAP import: ' ME.message]);R.log(ME.message);
            end
        end

        function outFile=onSaveProposal(R)
            % Legacy explicit export API; never called by automatic fitting
            % or GUI buttons. Automatic computation is not anatomical review.
            Transf=R.getCurrentTransform();
            if ~isstruct(Transf.autoRegistration)||isempty(Transf.autoRegistration),Transf.autoRegistration=struct();end
            Transf.autoRegistration.reviewRequired=true;
            Transf.autoRegistration.proposalSavedAt=datestr(now,30);
            if ~isfolder(R.saveDir),mkdir(R.saveDir);end
            outFile=fullfile(R.saveDir,['Transformation_proposal_' char(datetime('now','Format','yyyy-MM-dd_HH-mm-ss-SSS')) '.mat']);
            save(outFile,'Transf');
            callback=getappdata(R.H.figure1,'AtlasSavedCallback');
            if isa(callback,'function_handle')
                try,callback(outFile);catch ME,R.log(['Proposal saved; companion refresh failed: ' ME.message]);end
            end
        end

        function onSave(R,outFile)
            R.cancelPreview();
            Transf = R.getCurrentTransform();
            if ~isstruct(Transf.autoRegistration)||isempty(Transf.autoRegistration),Transf.autoRegistration=struct('engine','manual');end
            Transf.autoRegistration.reviewRequired=false;
            Transf.autoRegistration.reviewedSavedAt=datestr(now,30);
            Transf.autoRegistration.savedMatrix=Transf.M;
            quickSave=nargin<2;
            if quickSave
                root=R.saveDir;[parent,leaf]=fileparts(root);
                if startsWith(leaf,'AtlasRegistration_'),root=parent;end
                folder=fusiUniqueOutputFolder(root,['AtlasRegistration_' char(datetime('now','Format','yyyy-MM-dd_HH-mm-ss-SSS'))]);
                outFile=fullfile(folder,'Transformation.mat');
            end
            outFile=fusiAnalysisOutputPath(outFile);
            if isfile(outFile)
                [folder,stem,ext]=fileparts(outFile);
                folder=fusiUniqueOutputFolder(folder,['AtlasRegistration_' char(datetime('now','Format','yyyy-MM-dd_HH-mm-ss-SSS'))]);
                outFile=fullfile(folder,[stem ext]);
            end

            try
                folder=fileparts(outFile);if ~isfolder(folder),mkdir(folder);end
                Transf.atlasUnderlays=fusiSaveAtlasUnderlays3D(R.atlas,Transf,outFile);
                save(outFile,'Transf');
                % Existing Studio/coregistration readers use this canonical
                % reviewed file. Retain it alongside the timestamped record.
                % Only the root compatibility alias follows the latest save.
                % Dated folders and their self-contained underlays are immutable.
                if quickSave,save(fullfile(root,'Transformation.mat'),'Transf');end
                setappdata(R.H.figure1,'AtlasLastSavedFile',outFile);
                set(R.uiSaveStatus,'String',sprintf('Saved transform: %s | Histology, Vascular, Regions_All and Regions_Merged: %s',outFile,Transf.atlasUnderlays.folder));
                R.log(sprintf('[Atlas GUI] Saved new registration -> %s', outFile));
            catch ME
                set(R.uiSaveStatus,'String',['Save failed: ' ME.message]);
                R.log(['[Atlas GUI] Save failed: ' ME.message]);
                return;
            end
            callback=getappdata(R.H.figure1,'AtlasSavedCallback');
            if isa(callback,'function_handle')
                try,callback(outFile);
                catch ME,R.log(['[Atlas GUI] Transform saved; companion refresh failed: ' ME.message]);end
            end
        end

        function onPreviewFunctional(R)

            if isempty(R.funcFiles)
                set(R.uiFuncStatus,'String','No functional candidates.');
                return;
            end

            idx = get(R.uiFuncPopup,'Value');
            idx = max(1, min(numel(R.funcFiles), idx));
            f = R.funcFiles{idx};

            try
                [scan, desc0] = loadFunctionalCandidateFile(f);
                [scanPrev, desc1] = makePreviewScan(scan);

                TransfNow = R.getCurrentTransform();
                regVol = register_data(R.atlas, scanPrev, TransfNow);

                R.showPreviewFigure(regVol, f, [desc0 ' | ' desc1]);
                set(R.uiFuncStatus,'String','Preview opened.');
            catch ME
                set(R.uiFuncStatus,'String',['Preview failed: ' ME.message]);
                R.log(['[Atlas GUI] Preview failed: ' ME.message]);
            end
        end

        function onRegisterFunctional(R)

            if isempty(R.funcFiles)
                set(R.uiFuncStatus,'String','No functional candidates.');
                return;
            end

            idx = get(R.uiFuncPopup,'Value');
            idx = max(1, min(numel(R.funcFiles), idx));
            f = R.funcFiles{idx};

            try
                set(R.H.figure1,'Pointer','watch');
                drawnow limitrate;

                [scan, desc0] = loadFunctionalCandidateFile(f);
                TransfNow = R.getCurrentTransform();

                [registered, desc1] = registerFullOrStaticScan(R.atlas, scan, TransfNow);

                [~,nm,~] = fileparts(stripNiiGzExt(f));
                ts = datestr(now,'yyyymmdd_HHMMSS');
                outFile = fullfile(R.saveDir, sprintf('%s_registered_to_atlas_%s.mat', safeFileStem(nm), ts));

                meta = struct();
                meta.source_file = f;
                meta.source_description = desc0;
                meta.registration_description = desc1;
                meta.transformation_file = getappdata(R.H.figure1,'AtlasLastSavedFile');
                if isempty(meta.transformation_file),meta.transformation_file=fullfile(R.saveDir,'Transformation.mat');end
                meta.timestamp = ts;meta.region_grouping=R.regionMode;

                atlasRegionLabels=R.atlas.Regions;atlasInfoRegions=R.atlas.infoRegions;
                if ~strcmp(R.regionMode,'Detailed'),atlasRegionLabels=R.groupedRegions;atlasInfoRegions=R.groupedRegionInfo;end
                save(outFile,'registered','meta','TransfNow','atlasRegionLabels','atlasInfoRegions','-v7.3');

                set(R.uiFuncStatus,'String',['Registered saved: ' outFile]);
                R.log(sprintf('[Atlas GUI] Registered scan saved -> %s', outFile));
                set(R.H.figure1,'Pointer','arrow');

            catch ME
                set(R.H.figure1,'Pointer','arrow');
                set(R.uiFuncStatus,'String',['Register failed: ' ME.message]);
                R.log(['[Atlas GUI] Register failed: ' ME.message]);
            end
        end

        function showPreviewFigure(R, regVol, srcFile, descText)

            x0 = R.ms1.x0;
            y0 = R.ms1.y0;
            z0 = R.ms1.z0;

            [aCor, aSag, aAxi] = R.ms1.cuts();

            oCor = squeeze(regVol(x0,:,:));
            oSag = squeeze(regVol(:,y0,:));
            oAxi = squeeze(regVol(:,:,z0))';

            if R.overlayInvert
                oCor = 1 - rescaleSafe(oCor);
                oSag = 1 - rescaleSafe(oSag);
                oAxi = 1 - rescaleSafe(oAxi);
            end

            win = estimateDisplayRange01(regVol);
            cmap = getOverlayCmap(R.overlayCmapName);

            hf = figure( ...
                'Name','Preview registered functional', ...
                'Color',[0 0 0], ...
                'MenuBar','none', ...
                'ToolBar','none', ...
                'NumberTitle','off', ...
                'Position',[100 100 1380 520]);

            ax1 = axes('Parent',hf,'Units','normalized','Position',[0.03 0.12 0.29 0.76], 'Color','k');
            ax2 = axes('Parent',hf,'Units','normalized','Position',[0.355 0.12 0.29 0.76], 'Color','k');
            ax3 = axes('Parent',hf,'Units','normalized','Position',[0.68 0.12 0.29 0.76], 'Color','k');

            drawOverlayPreview(ax1, aCor, rescaleSafe(oCor), [R.overlayWinMin R.overlayWinMax], cmap, R.overlayOpacity, sprintf('Coronal x = %d', x0));
            drawOverlayPreview(ax2, aSag, rescaleSafe(oSag), [R.overlayWinMin R.overlayWinMax], cmap, R.overlayOpacity, sprintf('Axial depth = %d', y0));
            drawOverlayPreview(ax3, permute(aAxi,[2 1 3]), rescaleSafe(oAxi), [R.overlayWinMin R.overlayWinMax], cmap, R.overlayOpacity, sprintf('Sagittal left/right = %d', z0));

            uicontrol('Style','text','Parent',hf,'Units','normalized', ...
                'Position',[0.02 0.93 0.96 0.05], ...
                'BackgroundColor',[0 0 0], ...
                'ForegroundColor',[1 1 1], ...
                'HorizontalAlignment','left', ...
                'FontSize',11, ...
                'String',sprintf('Source: %s | %s | display range estimate [%.3f %.3f]', srcFile, descText, win(1), win(2)));
        end

        function onHelp(R)
            deConfUSIon_ui('help','Registration'); return;
            bg = [0.06 0.06 0.06];
            fg = [0.95 0.95 0.95];

            hf = figure('Name','Atlas GUI - Help', ...
                'Color',bg,'MenuBar','none','ToolBar','none','NumberTitle','off', ...
                'Position',[200 120 900 650]);

            txt = {
                'Atlas GUI - Help'
                ' '
                'Recommended workflow:'
                '1) Select your nice BrainOnly / brainImage / MIP-like anatomy in coreg.'
                '2) In this GUI, mainly align coronal first.'
                '3) Then verify and refine with sagittal and axial.'
                '4) Use Apply, then Save.'
                '5) Use Preview selected or Register selected for functional outputs.'
                ' '
                'Automatic alignment:'
                'Greedy is the registration calculation engine bundled with ITK-SNAP.'
                'ITK-SNAP review is a separate viewer; it does not accept the transform for you.'
                'Refine current manual alignment: use after your rough placement is close.'
                'Leave it off to search new starting positions when the placement is wrong.'
                'Review multiple coronal, axial and sagittal slices before SAVE TRANSFORM NOW.'
                ' '
                'Visibility and browsing:'
                'Vessel detail / Linear power / Log Doppler affect display only.'
                'Hot is the default, matching the 2D anatomy appearance; reduce opacity to see the atlas.'
                'Slice numbers are in the top bar; the wheel browses the hovered plane.'
                'In ITK-SNAP use Alt-I for contrast, Q/E for opacity, W to toggle the overlay.'
                'Separate image tiles? Right-click aligned_anatomy and choose Display as Overlay.'
                'Tools > Registration > Manual: select aligned_anatomy, then enable Interactive Tool.'
                'Drag away from the wheel to translate; turn the wheel to rotate.'
                'Save Transform as ITK affine text or Convert3D RAS text; return here and Import SNAP edit.'
                'Review the imported adjustment, then SAVE TRANSFORM NOW to update the 3D model.'
                ' '
                'Mouse interaction on right panels:'
                '  - Left drag  = translate overlay'
                '  - Right drag = rotate overlay'
                ' '
                'Important:'
                'A reliable 3D transform should not be based on coronal only.'
                'Use coronal as primary view, but confirm sagittal and axial too.'
                ' '
                'The overlay display controls are only for contrast/visibility.'
                'They do not change the data used for the saved transformation.'
                };

            uicontrol(hf,'Style','edit','Max',2,'Min',0, ...
                'Units','normalized','Position',[0.03 0.03 0.94 0.94], ...
                'BackgroundColor',bg,'ForegroundColor',fg, ...
                'FontName','Consolas','FontSize',12, ...
                'HorizontalAlignment','left', ...
                'String',strjoin(txt, sprintf('\n')));
        end

        function publishPreview(R)
            R.cancelPreview();
            if ~isgraphics(R.H.figure1),return;end
            callback=getappdata(R.H.figure1,'AtlasPreviewCallback');
            if isa(callback,'function_handle')
                try,callback(R.getCurrentTransform());
                catch ME,R.log(['[Atlas preview] ' ME.message]);end
            end
        end

        function queuePreview(R)
            % Coalesce rapid nudges. Never rebuild an atlas model inside a
            % mouse-release or size-edit callback.
            R.cancelPreview();
            if ~R.livePreview,return;end
            if ~isgraphics(R.H.figure1) || ~isa(getappdata(R.H.figure1,'AtlasPreviewCallback'),'function_handle'),return;end
            R.previewTimer=timer('ExecutionMode','singleShot','StartDelay',.75, ...
                'Name','deConfUSIon_atlas_preview','TimerFcn',@(~,~)R.flushPreview());
            start(R.previewTimer);
        end

        function onLivePreview(R,src)
            R.livePreview=logical(get(src,'Value'));R.queuePreview();
        end

        function flushPreview(R)
            if ~isgraphics(R.H.figure1),R.cancelPreview();return;end
            if R.anyDragging() || R.autoBusy || R.autoSetupBusy,R.queuePreview();return;end
            R.publishPreview();
        end

        function cancelPreview(R)
            pending=R.previewTimer;R.previewTimer=[];
            if ~isempty(pending) && isvalid(pending),stop(pending);delete(pending);end
        end

        function onClose(R)
            if R.autoBusy
                setappdata(R.H.figure1,'AtlasAutoCancel',true);
                return;
            end
            R.publishPreview();
            try
                delete(R.H.figure1);
            catch
            end
        end

        function onScroll(R, evt)
            if R.autoBusy, return; end
            if R.anyDragging()
                return;
            end

            t = now * 24 * 3600;
            if (t - R.lastScrollT) < R.scrollMinDt
                return;
            end
            R.lastScrollT = t;

            ax = R.getAxesUnderPointer();
            if isempty(ax) || ~isgraphics(ax)
                return;
            end

            step = -sign(evt.VerticalScrollCount);
            if step == 0
                return;
            end

            if ax == R.H.axes1 || ax == R.H.axes4
                R.ms1.x0 = R.ms1.x0 + step * R.atlasStepCor;
            elseif ax == R.H.axes2 || ax == R.H.axes5
                R.ms1.y0 = R.ms1.y0 + step;
            elseif ax == R.H.axes3 || ax == R.H.axes6
                R.ms1.z0 = R.ms1.z0 + step;
            else
                return;
            end

            R.ms2.x0 = R.ms1.x0;
            R.ms2.y0 = R.ms1.y0;
            R.ms2.z0 = R.ms1.z0;

            R.refresh();
        end

        function ax = getAxesUnderPointer(R)

            fig = R.H.figure1;
            cp = get(fig,'CurrentPoint');
            axList = [R.H.axes1 R.H.axes2 R.H.axes3 R.H.axes4 R.H.axes5 R.H.axes6];

            ax = [];
            for k = 1:numel(axList)
                a = axList(k);
                if ~isgraphics(a)
                    continue;
                end
                p = getpixelposition(a, true);
                if cp(1) >= p(1) && cp(1) <= p(1)+p(3) && cp(2) >= p(2) && cp(2) <= p(2)+p(4)
                    ax = a;
                    return;
                end
            end
        end

        function clampIndices(R)

            nx = size(R.ms1.D,1);
            ny = size(R.ms1.D,2);
            nz = size(R.ms1.D,3);

            R.ms1.nx = nx;
            R.ms1.ny = ny;
            R.ms1.nz = nz;

            R.ms2.nx = nx;
            R.ms2.ny = ny;
            R.ms2.nz = nz;

            R.ms1.x0 = max(1, min(nx, R.ms1.x0));
            R.ms1.y0 = max(1, min(ny, R.ms1.y0));
            R.ms1.z0 = max(1, min(nz, R.ms1.z0));

            R.ms2.x0 = R.ms1.x0;
            R.ms2.y0 = R.ms1.y0;
            R.ms2.z0 = R.ms1.z0;
        end

        function log(R, msg)
            if isempty(msg)
                return;
            end
            try
                if ~isempty(R.logFcn) && isa(R.logFcn,'function_handle')
                    R.logFcn(msg);
                end
            catch
            end
        end
    end
end


function DataNorm = equalizeImages(Data)

DataNorm = Data - min(Data(:));
mx = max(DataNorm(:));
if mx > 0
    DataNorm = DataNorm ./ mx;
end

m = median(DataNorm(:));
if m <= 0
    m = 0.5;
end

comp = -2 / log2(m);
DataNorm = DataNorm .^ comp;

DataNorm = DataNorm - min(DataNorm(:));
mx = max(DataNorm(:));
if mx > 0
    DataNorm = DataNorm ./ mx;
end

end


function tot = build3DrotationMatrix(R)

tot = eye(4);
movers={R.r1,R.r2,R.r3}; planes={'coronal','axial','sagittal'};
for k=1:3
    if isempty(movers{k}), continue; end
    tot=tot*AtlasRegistration('planematrix',movers{k}.pendingTransform(),planes{k});
end
end


function idx = clampToNumel(LL, idx)
n = numel(LL);
if n < 1
    idx = 1;
    return;
end
idx = max(1, min(n, idx));
end


function h = addLines(ax, LL, ip)

if isempty(LL) || ip < 1 || ip > numel(LL)
    h = gobjects(0);
    return;
end

L = LL{ip};coords=cell(1,numel(L));
for ib=1:numel(L),coords{ib}=[L{ib};NaN NaN];end
xy=[];if ~isempty(coords),xy=vertcat(coords{:});end;h=gobjects(0);
if ~isempty(xy),h=line(ax,xy(:,2),xy(:,1),'Color','w','LineStyle',':','LineWidth',1,'HitTest','off');end

end


function safeDeleteGraphics(h)
try
    if isempty(h)
        return;
    end
    for k = 1:numel(h)
        if isgraphics(h(k))
            delete(h(k));
        end
    end
catch
end
end


function tf = safeIsDragging(r)
tf = false;
try
    if ~isempty(r) && ismethod(r,'isDragging')
        tf = r.isDragging();
    end
catch
    tf = false;
end
end


function tf = isvalidHandleObj(obj)
tf = false;
try
    tf = ~isempty(obj) && isvalid(obj);
catch
    tf = false;
end
end


function safeResetMove(r)
try
    if ~isempty(r) && ismethod(r,'resetTransform')
        r.resetTransform();
    end
catch
end
end


function [scan, descText] = loadFunctionalCandidateFile(f)

if endsWithLowerLocal(f,'.mat')
    S = load(f);
    [scan, descText] = detectBestFunctionalFromMat(S);

elseif endsWithLowerLocal(f,'.nii') || endsWithLowerLocal(f,'.nii.gz')
    [D, vox] = loadNiftiMaybeGzLocal(f);
    scan = struct();
    scan.Data = double(D);
    if isempty(vox)
        vox = [1 1 1];
    end
    scan.VoxelSize = vox;
    descText = sprintf('NIfTI [%s]', joinDimsLocal(size(scan.Data)));

else
    error('Unsupported functional candidate: %s', f);
end

if ~isfield(scan,'Data') || isempty(scan.Data)
    error('Loaded functional candidate has empty Data.');
end

if ~isfield(scan,'VoxelSize') || isempty(scan.VoxelSize)
    scan.VoxelSize = [1 1 1];
end

end


function [scanBest, descText] = detectBestFunctionalFromMat(S)

fields = fieldnames(S);

voxHint = [];
try
    if isfield(S,'VoxelSize')
        voxHint = S.VoxelSize;
    end
    if isempty(voxHint) && isfield(S,'meta') && isstruct(S.meta) && isfield(S.meta,'VoxelSize')
        voxHint = S.meta.VoxelSize;
    end
catch
end
if isempty(voxHint)
    voxHint = [1 1 1];
end

scanBest = [];
descText = '';

preferredNumeric = { ...
    'brainImage', ...
    'I', ...
    'PSC', ...
    'Data', ...
    'anatomical_reference', ...
    'anatomical_reference_raw' ...
    };

for i = 1:numel(preferredNumeric)
    nm = preferredNumeric{i};
    if isfield(S, nm)
        v = S.(nm);
        if (isnumeric(v) || islogical(v)) && ~isempty(v)
            if ndims(v) >= 2 && ndims(v) <= 4
                scanBest = struct();
                scanBest.Data = double(v);
                scanBest.VoxelSize = voxHint;
                descText = sprintf('MAT numeric %s [%s]', nm, joinDimsLocal(size(v)));
                return;
            end
        end
    end
end

preferredStruct = { ...
    'registered', ...
    'scan', ...
    'scanfus', ...
    'anatomic', ...
    'proc', ...
    'out' ...
    };

for i = 1:numel(preferredStruct)
    nm = preferredStruct{i};
    if isfield(S, nm)
        v = S.(nm);
        if isstruct(v) && isfield(v,'Data') && isnumeric(v.Data) && ~isempty(v.Data)
            scanBest = struct();
            scanBest.Data = double(v.Data);
            if isfield(v,'VoxelSize') && ~isempty(v.VoxelSize)
                scanBest.VoxelSize = v.VoxelSize;
            else
                scanBest.VoxelSize = voxHint;
            end
            descText = sprintf('MAT struct %s.Data [%s]', nm, joinDimsLocal(size(v.Data)));
            return;
        end
    end
end

for i = 1:numel(fields)
    v = S.(fields{i});
    if isstruct(v) && isscalar(v) && isfield(v,'I') && isnumeric(v.I) && ~isempty(v.I)
        v.Data=v.I;
    end
    if isstruct(v) && isfield(v,'Data') && isnumeric(v.Data) && ~isempty(v.Data)
        if ndims(v.Data) >= 2 && ndims(v.Data) <= 4
            scanBest = struct();
            scanBest.Data = double(v.Data);
            if isfield(v,'VoxelSize') && ~isempty(v.VoxelSize)
                scanBest.VoxelSize = v.VoxelSize;
            else
                scanBest.VoxelSize = voxHint;
            end
            descText = sprintf('MAT struct %s.Data [%s]', fields{i}, joinDimsLocal(size(v.Data)));
            return;
        end
    end
end

bestScore = -inf;

for i = 1:numel(fields)
    v = S.(fields{i});

    if (isnumeric(v) || islogical(v)) && ~isempty(v)
        if ndims(v) >= 2 && ndims(v) <= 4
            sc = 1000 * ndims(v) + log(double(numel(v)) + 1);
            if sc > bestScore
                bestScore = sc;
                scanBest = struct();
                scanBest.Data = double(v);
                scanBest.VoxelSize = voxHint;
                descText = sprintf('MAT numeric %s [%s]', fields{i}, joinDimsLocal(size(v)));
            end
        end
    end
end

if isempty(scanBest)
    error('No suitable functional candidate found. No numeric 2D/3D/4D variable or struct.Data field was found.');
end

end


function [scanPrev, descText] = makePreviewScan(scanIn)

scanPrev = scanIn;
D = double(scanIn.Data);

if ndims(D) == 4
    scanPrev.Data = mean(D,4);
    descText = sprintf('Preview = mean over time of 4D [%s]', joinDimsLocal(size(D)));

elseif ndims(D) == 3
    % Slice count does not identify a time axis: a 54-slice anatomy is 3D.
    scanPrev.Data = D;
    descText = sprintf('Preview = static 3D volume [%s]', joinDimsLocal(size(D)));

elseif ndims(D) == 2
    scanPrev.Data = reshape(D, [size(D,1) size(D,2) 1]);
    descText = sprintf('Preview = single 2D image [%s]', joinDimsLocal(size(D)));

else
    error('Unsupported preview dimensionality.');
end

if ~isfield(scanPrev,'VoxelSize') || isempty(scanPrev.VoxelSize)
    scanPrev.VoxelSize = [1 1 1];
end

end


function [registered, descText] = registerFullOrStaticScan(atlas, scanIn, TransfNow)

registered = struct();
registered.VoxelSize = atlas.VoxelSize;

D = double(scanIn.Data);

if ndims(D) == 4
    T = size(D,4);

    tmpFirst = struct();
    tmpFirst.Data = squeeze(D(:,:,:,1));
    tmpFirst.VoxelSize = scanIn.VoxelSize;
    reg1 = register_data(atlas, tmpFirst, TransfNow);

    regAll = zeros([size(reg1) T], 'single');
    regAll(:,:,:,1) = single(reg1);

    for t = 2:T
        tmp = struct();
        tmp.Data = squeeze(D(:,:,:,t));
        tmp.VoxelSize = scanIn.VoxelSize;
        regAll(:,:,:,t) = single(register_data(atlas, tmp, TransfNow));
    end

    registered.Data = regAll;
    descText = sprintf('Full 4D scan registered [%s]', joinDimsLocal(size(D)));

elseif ndims(D) == 3
    tmp=struct('Data',D,'VoxelSize',scanIn.VoxelSize);
    registered.Data = single(register_data(atlas, tmp, TransfNow));
    descText = sprintf('Static 3D volume registered [%s]', joinDimsLocal(size(D)));

elseif ndims(D) == 2
    tmp = struct();
    tmp.Data = reshape(D, [size(D,1) size(D,2) 1]);
    tmp.VoxelSize = scanIn.VoxelSize;
    registered.Data = single(register_data(atlas, tmp, TransfNow));
    descText = sprintf('2D image registered as single plane [%s]', joinDimsLocal(size(D)));

else
    error('Unsupported scan dimensionality for registration.');
end

end


function drawOverlayPreview(ax, underRGB, overData01, win, cmap, alphaVal, ttl)

axes(ax); %#ok<LAXES>
cla(ax);
image(underRGB, 'Parent', ax);
axis(ax,'image');
axis(ax,'off');
hold(ax,'on');
h = imagesc(overData01, 'Parent', ax);
set(h,'AlphaData',fusiRegistrationOverlayAlpha(overData01,win,alphaVal));
set(ax,'CLim',win);
colormap(ax, cmap);
title(ax, ttl, 'Color','w', 'FontWeight','bold');
hold(ax,'off');

end


function cmap = getOverlayCmap(nameIn)
switch lower(nameIn)
    case 'cyan'
        cmap=[zeros(256,1) linspace(.25,1,256)' linspace(.4,1,256)'];
    case 'red'
        cmap = [linspace(0,1,256)' zeros(256,1) zeros(256,1)];
    otherwise
        try
            cmap = feval(nameIn, 256);
        catch
            cmap = gray(256);
        end
end
end


function win = estimateDisplayRange01(V)
v = double(V(:));
v = v(isfinite(v));
if isempty(v)
    win = [0 1];
    return;
end

v = rescaleSafe(v);
lo = prctile(v, 2);
hi = prctile(v, 98);

if ~isfinite(lo) || ~isfinite(hi) || hi <= lo
    lo = min(v);
    hi = max(v);
end
if hi <= lo
    hi = lo + 0.01;
end

win = [lo hi];
end


function x = rescaleSafe(x)
x = double(x);
mn = min(x(:));
mx = max(x(:));
if ~isfinite(mn), mn = 0; end
if ~isfinite(mx), mx = 1; end
if mx <= mn
    x = zeros(size(x));
else
    x = (x - mn) ./ (mx - mn);
end
x = min(max(x,0),1);
end


function tf = endsWithLowerLocal(str, suffix)
str = lower(str);
suffix = lower(suffix);
if numel(str) < numel(suffix)
    tf = false;
    return;
end
tf = strcmp(str(end-numel(suffix)+1:end), suffix);
end


function [D, vox] = loadNiftiMaybeGzLocal(f)

vox = [];
isGz = (numel(f) >= 7 && strcmpi(f(end-6:end),'.nii.gz'));

if isGz
    tmpDir = tempname;
    mkdir(tmpDir);
    gunzip(f, tmpDir);
    d = dir(fullfile(tmpDir,'*.nii'));
    if isempty(d)
        error('Failed to gunzip: %s', f);
    end
    niiFile = fullfile(tmpDir, d(1).name);

    info = niftiinfo(niiFile);
    D = niftiread(info);

    try
        if isfield(info,'PixelDimensions') && numel(info.PixelDimensions) >= 3
            vox = double(info.PixelDimensions(1:3));
        end
    catch
    end

    try
        rmdir(tmpDir,'s');
    catch
    end

else
    info = niftiinfo(f);
    D = niftiread(info);
    try
        if isfield(info,'PixelDimensions') && numel(info.PixelDimensions) >= 3
            vox = double(info.PixelDimensions(1:3));
        end
    catch
    end
end

end


function s = joinDimsLocal(sz)
if isempty(sz)
    s = '';
    return;
end
s = num2str(sz(1));
for k = 2:numel(sz)
    s = [s 'x' num2str(sz(k))]; %#ok<AGROW>
end
end


function stem = safeFileStem(s)
if isempty(s)
    stem = 'scan';
    return;
end
stem = regexprep(s,'[^A-Za-z0-9_]+','_');
stem = regexprep(stem,'_+','_');
stem = regexprep(stem,'^_','');
stem = regexprep(stem,'_$','');
if isempty(stem)
    stem = 'scan';
end
if numel(stem) > 60
    stem = stem(1:60);
end
end


function out = stripNiiGzExt(f)
out = f;
if numel(out) >= 7 && strcmpi(out(end-6:end), '.nii.gz')
    out = out(1:end-7);
    return;
end
[p,n,~] = fileparts(out);
out = fullfile(p,n);
end

%% ------------------------------------------------------------------------
%% Integrated helper from register_data.m on 09-Jun-2026 16:52:21
%% Original file archived in backups/deConfUSIon_phase6_fast_cleanup_*/integrated_helpers
%% ------------------------------------------------------------------------

% Urban Lab - NERF empowered by imec, KU Leuven and VIB
% Mace Lab  - Max Planck institute of Neurobiology
% Authors:  G. MONTALDO, E. MACE
% Review & test: C.BRUNNER, M. GRILLET
% September 2020
%
% Interpolates and registers a volumetric data with the Allen Mouse Common Coordinate Framework using an affine transformation
%
% xreg=register_data(atlas, x, Transf)
%   atlas, Allen Mouse Common Coordinate Framework provided in the allen_brain_atlas.mat file,
%   x, fus-structure of type volume,
%   Transf, transformation structure obtained with the registering function.
%   xreg, a fus-structure of type volume with the registered data.
%
% Example: example03_correlation.m
%%
function ras=register_data(atlas,x,Transf)
if isfield(Transf,'scanGeometry') && ~isempty(Transf.scanGeometry)
    Transf.scanGeometry.atlasVoxelSizeUm=double(atlas.VoxelSize(:)');
    ras=AtlasRegistration('warp',x.Data,Transf);
    return;
end
Dint=interpolate3D(atlas,x);
T=affine3d(Transf.M);
ref=imref3d(Transf.size);
ras=imwarp(Dint.Data,T,'OutputView',ref);
end







%% ------------------------------------------------------------------------
%% Integrated tiny helper from interpolate3D.m on 09-Jun-2026 16:59:39
%% ------------------------------------------------------------------------

function scanInt = interpolate3D(atlas, scan)
% interpolate3D (ROBUST)
% ------------------------------------------------------------
% Paper-faithful intent:
%   - Resample scan.Data to atlas.VoxelSize
%   - Then flip/permute axes to match atlas orientation (same as paper code)
%
% Fixes:
%   - Avoids meshgrid/meshgridvectors issues by using ndgrid + interpn
%   - Sanitizes VoxelSize (handles NaN/Inf/<=0)
%   - Guards empty/invalid target sizes
%
% MATLAB 2017b compatible
% ------------------------------------------------------------

% Basic checks
if ~isstruct(scan) || ~isfield(scan,'Data') || isempty(scan.Data)
    error('interpolate3D: scan must be a struct with non-empty field .Data');
end
if ~isstruct(atlas) || ~isfield(atlas,'VoxelSize') || isempty(atlas.VoxelSize)
    error('interpolate3D: atlas must contain field .VoxelSize');
end

D = double(scan.Data);
if ndims(D) == 2
    D = reshape(D, size(D,1), size(D,2), 1);
end

% Ensure scan voxel size exists and is sane
if ~isfield(scan,'VoxelSize') || isempty(scan.VoxelSize)
    scan.VoxelSize = [1 1 1];
end

sv = sanitizeVoxelSize(scan.VoxelSize);
av = sanitizeVoxelSize(atlas.VoxelSize);

dz    = sv(1); dx    = sv(2); dy    = sv(3);
dzint = av(1); dxint = av(2); dyint = av(3);

[nz, nx, ny] = size(D);

% Target sizes (guarded)
n1x = round((nx-1) * dx / dxint) + 1;
n1y = round((ny-1) * dy / dyint) + 1;
n1z = round((nz-1) * dz / dzint) + 1;

if ~isfinite(n1x) || n1x < 1, n1x = 1; end
if ~isfinite(n1y) || n1y < 1, n1y = 1; end
if ~isfinite(n1z) || n1z < 1, n1z = 1; end

% Query coordinates in scan-index space (1-based)
sx = dxint / dx; if ~isfinite(sx) || sx <= 0, sx = 1; end
sy = dyint / dy; if ~isfinite(sy) || sy <= 0, sy = 1; end
sz = dzint / dz; if ~isfinite(sz) || sz <= 0, sz = 1; end

xq = (0:n1x-1) * sx + 1;   % corresponds to dim 2 (x)
yq = (0:n1y-1) * sy + 1;   % corresponds to dim 3 (y)
zq = (0:n1z-1) * sz + 1;   % corresponds to dim 1 (z)

% Use ndgrid in (z,x,y) order to match D = [nz nx ny]
[Zq, Xq, Yq] = ndgrid(zq, xq, yq);

% Interpolate (outside -> 0)
ai = interpn(D, Zq, Xq, Yq, 'linear', 0);

% Paper axis manipulation: flip + permute
ai = flip(ai,3);
ai = flip(ai,2);
ai = permute(ai,[3,1,2]);

scanInt.Data = ai;
scanInt.VoxelSize = av;

end

% ------------------------------------------------------------
% Local helper: sanitize voxel size to [z x y] positive finite
% ------------------------------------------------------------
function v = sanitizeVoxelSize(vin)
v = vin(:)';
if numel(v) < 3
    v = [v, ones(1, 3-numel(v))];
end
v = v(1:3);
for k = 1:3
    if ~isfinite(v(k)) || v(k) <= 0
        v(k) = 1;
    end
end
end
