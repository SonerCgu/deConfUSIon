function mask = deConfUSIon_drift_roi_picker(I, varargin)
% =========================================================================
% deConfUSIon - interactive noise / reference ROI picker
% =========================================================================
% Shows the MEAN image of a time series and lets the user define a region
% for the 'reference' and 'compcor' drift-compensation methods.
%
%   mask = deConfUSIon_drift_roi_picker(I)
%   mask = deConfUSIon_drift_roi_picker(I, 'title', 'Pick noise region')
%
% INPUT
%   I     [Y X T] or [Y X Z T] time series (the mean over time is displayed)
%
% OUTPUT
%   mask  logical [Y X] or [Y X Z]; empty if the user cancels
%
% TOOLS
%   Polygon     click corners, press Enter (or right-click) to close
%   Rectangle   click-drag once
%   Threshold   percentile slider on the mean image (low = non-tissue)
%   Add / Remove modes, Invert, Clear
%
% Uses only base MATLAB (ginput / rbbox / inpolygon) - no Image Processing
% Toolbox required, so it runs on any deConfUSIon installation.
% =========================================================================

mask = [];
if nargin < 1 || isempty(I) || ~isnumeric(I)
    error('deConfUSIon_drift_roi_picker:BadInput','Need a numeric time series.');
end

ttl = 'Select region';
for k = 1:2:numel(varargin)-1
    if strcmpi(varargin{k},'title'), ttl = varargin{k+1}; end
end

dims = size(I);
nd   = ndims(I);
if nd == 3
    ny = dims(1); nx = dims(2); nz = 1;
    M3 = reshape(mean(single(I),3), ny, nx, 1);
elseif nd == 4
    ny = dims(1); nx = dims(2); nz = dims(3);
    M3 = squeeze(mean(single(I),4));
    if nz == 1, M3 = reshape(M3, ny, nx, 1); end
else
    error('deConfUSIon_drift_roi_picker:BadDims','Need a 3D or 4D array.');
end

sel   = false(ny, nx, nz);
zc    = max(1, ceil(nz/2));
mode  = 1;      % 1 = add, 2 = remove
applyAll = (nz > 1);

FONT = 'Arial';
BG   = [0.03 0.03 0.03];
PAN  = [0.10 0.10 0.11];
WHT  = [1 1 1];
DIM  = [0.70 0.70 0.72];
ACC  = [0.15 0.62 0.96];
MINT = [0.20 0.85 0.60];
CARD = [0.17 0.17 0.18];

f = figure('Name',ttl,'NumberTitle','off','MenuBar','none','ToolBar','none', ...
    'Color',BG,'Units','normalized','WindowStyle','modal', ...
    'DefaultUicontrolFontName',FONT);
set(f,'Units','normalized','OuterPosition',[0.06 0.08 0.88 0.84]);

ax = axes('Parent',f,'Units','normalized','Position',[0.05 0.10 0.62 0.82]);
pnl = uipanel('Parent',f,'Units','normalized','Position',[0.70 0.06 0.28 0.88], ...
    'BackgroundColor',PAN,'ForegroundColor',WHT,'Title','  ROI TOOLS  ', ...
    'FontName',FONT,'FontSize',13,'FontWeight','bold','BorderType','line', ...
    'HighlightColor',[0.30 0.30 0.34]);

hImg = []; hOv = [];
drawScene();

% ------------------------------------------------------------- controls
yy = 0.93;
function y = nextY(h), y = yy - h; yy = y - 0.015; end

mkBtn('Polygon',      @(a,b) doPolygon(),   ACC);
mkBtn('Rectangle',    @(a,b) doRect(),      ACC);
mkBtn('Threshold',    @(a,b) doThreshold(), ACC);
mkLabel('');
hModeAdd = mkBtn('Mode: ADD',  @(a,b) setMode(1), CARD);
hModeRem = mkBtn('Mode: REMOVE',@(a,b) setMode(2), CARD);
mkLabel('');
mkBtn('Invert',       @(a,b) doInvert(),  CARD);
mkBtn('Clear',        @(a,b) doClear(),   CARD);
mkLabel('');

hSliceLab = mkLabel(sprintf('Slice  %d / %d', zc, nz));
hSlice = uicontrol(pnl,'Style','slider','Units','normalized', ...
    'Position',[0.08 nextY(0.05) 0.84 0.05], ...
    'Min',1,'Max',max(2,nz),'Value',zc, ...
    'SliderStep',[1/max(1,nz-1) max(1/max(1,nz-1),0.1)], ...
    'Callback',@(a,b) setSlice(round(get(a,'Value'))));
if nz < 2, set(hSlice,'Enable','off'); end

hAll = uicontrol(pnl,'Style','checkbox','String','Apply to all slices', ...
    'Units','normalized','Position',[0.08 nextY(0.05) 0.84 0.05], ...
    'BackgroundColor',PAN,'ForegroundColor',WHT,'FontName',FONT, ...
    'FontSize',11,'FontWeight','bold','Value',double(applyAll), ...
    'Callback',@(a,b) setApplyAll(get(a,'Value')));
if nz < 2, set(hAll,'Enable','off'); end

hInfo = uicontrol(pnl,'Style','text','String','','Units','normalized', ...
    'Position',[0.06 nextY(0.10) 0.88 0.10],'BackgroundColor',PAN, ...
    'ForegroundColor',MINT,'FontName',FONT,'FontSize',11,'FontWeight','bold', ...
    'HorizontalAlignment','left');

uicontrol(pnl,'Style','text', ...
    'String',['Tip: for CompCor pick tissue that should NOT respond ' ...
              '(or use Threshold to grab low-signal background).'], ...
    'Units','normalized','Position',[0.06 nextY(0.12) 0.88 0.12], ...
    'BackgroundColor',PAN,'ForegroundColor',DIM,'FontName',FONT, ...
    'FontSize',10,'HorizontalAlignment','left');

uicontrol(pnl,'Style','pushbutton','String','USE THIS REGION', ...
    'Units','normalized','Position',[0.08 0.09 0.84 0.07], ...
    'BackgroundColor',[0.13 0.62 0.38],'ForegroundColor',WHT, ...
    'FontName',FONT,'FontSize',13,'FontWeight','bold','Callback',@(a,b) onOK());
uicontrol(pnl,'Style','pushbutton','String','Cancel', ...
    'Units','normalized','Position',[0.08 0.015 0.84 0.06], ...
    'BackgroundColor',[0.52 0.16 0.18],'ForegroundColor',WHT, ...
    'FontName',FONT,'FontSize',12,'FontWeight','bold','Callback',@(a,b) close(f));

setMode(1);
updateInfo();
uiwait(f);

% =========================================================================
    function h = mkBtn(label, cb, col)
        h = uicontrol(pnl,'Style','pushbutton','String',label, ...
            'Units','normalized','Position',[0.08 nextY(0.062) 0.84 0.062], ...
            'BackgroundColor',col,'ForegroundColor',WHT,'FontName',FONT, ...
            'FontSize',12,'FontWeight','bold','Callback',cb);
    end

    function h = mkLabel(txt)
        h = uicontrol(pnl,'Style','text','String',txt,'Units','normalized', ...
            'Position',[0.06 nextY(0.035) 0.88 0.035],'BackgroundColor',PAN, ...
            'ForegroundColor',WHT,'FontName',FONT,'FontSize',11, ...
            'FontWeight','bold','HorizontalAlignment','left');
    end

    function setMode(m)
        mode = m;
        if m == 1
            set(hModeAdd,'BackgroundColor',MINT,'ForegroundColor',[0.05 0.05 0.05]);
            set(hModeRem,'BackgroundColor',CARD,'ForegroundColor',WHT);
        else
            set(hModeRem,'BackgroundColor',[0.95 0.45 0.40],'ForegroundColor',[0.05 0.05 0.05]);
            set(hModeAdd,'BackgroundColor',CARD,'ForegroundColor',WHT);
        end
    end

    function setApplyAll(v), applyAll = logical(v); end

    function setSlice(z)
        zc = max(1,min(nz,z));
        set(hSliceLab,'String',sprintf('Slice  %d / %d', zc, nz));
        drawScene(); updateInfo();
    end

    function drawScene()
        img = double(M3(:,:,zc));
        lo = min(img(isfinite(img))); hi = max(img(isfinite(img)));
        if isempty(lo) || ~isfinite(lo) || hi <= lo, lo = 0; hi = 1; end
        axes(ax); cla(ax);
        hImg = imagesc(img,[lo hi]); axis image off; colormap(ax,'gray'); hold(ax,'on');
        ov = double(sel(:,:,zc));
        hOv = imagesc(cat(3, ones(ny,nx), 0.35*ones(ny,nx), 0.25*ones(ny,nx)));
        set(hOv,'AlphaData', 0.42*ov);
        title(ax, sprintf('Mean image - slice %d/%d', zc, nz), ...
            'Color',[1 1 1],'FontName',FONT,'FontSize',13,'FontWeight','bold');
        hold(ax,'off');
    end

    function applySel(bw)
        if applyAll
            for z = 1:nz
                if mode == 1, sel(:,:,z) = sel(:,:,z) | bw;
                else,         sel(:,:,z) = sel(:,:,z) & ~bw;
                end
            end
        else
            if mode == 1, sel(:,:,zc) = sel(:,:,zc) | bw;
            else,         sel(:,:,zc) = sel(:,:,zc) & ~bw;
            end
        end
        drawScene(); updateInfo();
    end

    function doPolygon()
        set(hInfo,'String','Click corners, then press Enter.');
        axes(ax);
        try
            [xp, yp] = ginput_poly();
        catch
            set(hInfo,'String','Polygon cancelled.'); return;
        end
        if numel(xp) < 3, set(hInfo,'String','Need at least 3 points.'); return; end
        [XX, YY] = meshgrid(1:nx, 1:ny);
        bw = inpolygon(XX, YY, xp, yp);
        applySel(bw);
    end

    function [xp, yp] = ginput_poly()
        xp = []; yp = [];
        while true
            [x, y, btn] = ginput(1);
            if isempty(btn), break; end          % Enter
            if btn == 3, break; end              % right click
            if btn ~= 1, continue; end
            xp(end+1) = x; yp(end+1) = y; %#ok<AGROW>
            hold(ax,'on');
            plot(ax, xp, yp, '-o','Color',[1 0.75 0.2],'LineWidth',1.6,'MarkerSize',5);
            hold(ax,'off'); drawnow;
        end
    end

    function doRect()
        set(hInfo,'String','Drag a rectangle.');
        axes(ax);
        k = waitforbuttonpress; %#ok<NASGU>
        pt1 = get(ax,'CurrentPoint');
        rbbox;
        pt2 = get(ax,'CurrentPoint');
        x1 = round(min(pt1(1,1), pt2(1,1))); x2 = round(max(pt1(1,1), pt2(1,1)));
        y1 = round(min(pt1(1,2), pt2(1,2))); y2 = round(max(pt1(1,2), pt2(1,2)));
        x1 = max(1,x1); y1 = max(1,y1); x2 = min(nx,x2); y2 = min(ny,y2);
        if x2 <= x1 || y2 <= y1, set(hInfo,'String','Rectangle too small.'); return; end
        bw = false(ny,nx); bw(y1:y2, x1:x2) = true;
        applySel(bw);
    end

    function doThreshold()
        img = double(M3(:,:,zc));
        v = img(isfinite(img));
        if isempty(v), return; end
        answer = inputdlg({'Take voxels BELOW this percentile of the mean image (0-100):'}, ...
            'Threshold', 1, {'25'});
        if isempty(answer), return; end
        q = str2double(answer{1});
        if ~isfinite(q) || q <= 0 || q >= 100
            set(hInfo,'String','Percentile must be between 0 and 100.'); return;
        end
        sv = sort(v);
        thr = sv(max(1, min(numel(sv), round(numel(sv)*q/100))));
        bw = img <= thr;
        applySel(bw);
    end

    function doInvert()
        if applyAll, sel = ~sel; else, sel(:,:,zc) = ~sel(:,:,zc); end
        drawScene(); updateInfo();
    end

    function doClear()
        sel = false(ny,nx,nz);
        drawScene(); updateInfo();
    end

    function updateInfo()
        n = nnz(sel);
        set(hInfo,'String',sprintf('Selected: %d voxels\n(%d on this slice)', n, nnz(sel(:,:,zc))));
    end

    function onOK()
        if nnz(sel) < 20
            errordlg('Select at least 20 voxels.','ROI');
            return;
        end
        if nz == 1
            mask = sel(:,:,1);
        else
            mask = sel;
        end
        close(f);
    end
end
