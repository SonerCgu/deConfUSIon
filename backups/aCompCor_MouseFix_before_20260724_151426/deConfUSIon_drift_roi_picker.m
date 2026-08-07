function mask = deConfUSIon_drift_roi_picker(I, varargin)
% =========================================================================
% deConfUSIon - interactive aCompCor / reference ROI brush picker
% =========================================================================
% Display:
%   SCM/Video-style log-median Doppler underlay.
%
% Interaction:
%   Left click / drag   : add brush area
%   Right click / drag  : remove brush area
%   Mouse wheel         : change slice
%   ROI size slider/edit: change square brush size in pixels
%
% Uses base MATLAB only. No Image Processing Toolbox is required.
% =========================================================================

mask = [];
if nargin < 1 || isempty(I) || ~isnumeric(I)
    error('deConfUSIon_drift_roi_picker:BadInput', ...
        'Need a numeric [Y X T] or [Y X Z T] time series.');
end

ttl = 'aCompCor noise ROI';
brushSize = 15;
initialMask = [];

for k = 1:2:numel(varargin)-1
    key = lower(strtrim(char(varargin{k})));
    switch key
        case 'title'
            ttl = char(varargin{k+1});
        case 'brushsize'
            brushSize = double(varargin{k+1});
        case 'initialmask'
            initialMask = varargin{k+1};
    end
end

dims = size(I);
nd = ndims(I);

if nd == 3
    ny = dims(1);
    nx = dims(2);
    nz = 1;
    T = dims(3);

    idx = localSubsample(T,600);
    M3 = reshape(median(single(I(:,:,idx)),3),ny,nx,1);

elseif nd == 4
    ny = dims(1);
    nx = dims(2);
    nz = dims(3);
    T = dims(4);

    idx = localSubsample(T,600);
    M3 = median(single(I(:,:,:,idx)),4);

    if nz == 1
        M3 = reshape(M3,ny,nx,1);
    end
else
    error('deConfUSIon_drift_roi_picker:BadDims', ...
        'Need [Y X T] or [Y X Z T] data.');
end

% Create the same basic log-median presentation used by SCM/FC.
D3 = zeros(ny,nx,nz,'single');
for z = 1:nz
    D3(:,:,z) = single(localScmDisplay(M3(:,:,z)));
end

sel = false(ny,nx,nz);

if ~isempty(initialMask)
    if numel(initialMask) == numel(sel)
        sel = reshape(logical(initialMask),size(sel));
    elseif nz == 1 && isequal(size(initialMask),[ny nx])
        sel(:,:,1) = logical(initialMask);
    end
end

zc = max(1,ceil(nz/2));
applyAll = false;
painting = false;
paintMode = 1;
lastPaintXY = [-inf -inf];

maxBrush = max(3,min(220,max(nx,ny)));
brushSize = max(1,min(maxBrush,round(brushSize)));

FONT = 'Arial';
BG = [0.03 0.03 0.03];
PAN = [0.09 0.09 0.10];
WHT = [1 1 1];
DIM = [0.72 0.72 0.75];
ACC = [0.15 0.62 0.96];
MINT = [0.20 0.85 0.60];
RED = [0.95 0.35 0.32];
GOLD = [1.00 0.76 0.22];
CARD = [0.18 0.18 0.20];

f = figure( ...
    'Name',ttl, ...
    'NumberTitle','off', ...
    'MenuBar','none', ...
    'ToolBar','none', ...
    'Color',BG, ...
    'Units','normalized', ...
    'Position',[0.04 0.06 0.92 0.88], ...
    'WindowStyle','modal', ...
    'DefaultUicontrolFontName',FONT, ...
    'CloseRequestFcn',@onCancel, ...
    'WindowButtonMotionFcn',@onMouseMove, ...
    'WindowButtonDownFcn',@onMouseDown, ...
    'WindowButtonUpFcn',@onMouseUp, ...
    'WindowScrollWheelFcn',@onMouseWheel);

try
    set(f,'Renderer','opengl');
catch
end

ax = axes( ...
    'Parent',f, ...
    'Units','normalized', ...
    'Position',[0.035 0.075 0.705 0.865]);

hImg = imagesc(ax,D3(:,:,zc),[0 1]);
axis(ax,'image');
axis(ax,'off');
colormap(ax,'gray');
hold(ax,'on');

hOv = imagesc(ax,cat(3, ...
    0.20*ones(ny,nx), ...
    ones(ny,nx), ...
    0.35*ones(ny,nx)));

set(hOv, ...
    'AlphaData',0.42*double(sel(:,:,zc)), ...
    'HitTest','off');

hPreview = rectangle(ax, ...
    'Position',[1 1 brushSize brushSize], ...
    'EdgeColor',GOLD, ...
    'LineWidth',1.7, ...
    'LineStyle','-', ...
    'Visible','off', ...
    'HitTest','off');

hTitle = title(ax,'', ...
    'Color',WHT, ...
    'FontName',FONT, ...
    'FontSize',13, ...
    'FontWeight','bold');

hold(ax,'off');

p = uipanel( ...
    'Parent',f, ...
    'Units','normalized', ...
    'Position',[0.765 0.045 0.215 0.91], ...
    'BackgroundColor',PAN, ...
    'ForegroundColor',ACC, ...
    'Title','  aCompCor ROI  ', ...
    'FontName',FONT, ...
    'FontSize',14, ...
    'FontWeight','bold', ...
    'BorderType','line', ...
    'HighlightColor',[0.30 0.30 0.34]);

uicontrol(p, ...
    'Style','text', ...
    'Units','normalized', ...
    'Position',[0.06 0.875 0.88 0.095], ...
    'String',{ ...
        'LEFT click/drag: ADD'; ...
        'RIGHT click/drag: REMOVE'; ...
        'Mouse wheel: change slice'}, ...
    'BackgroundColor',PAN, ...
    'ForegroundColor',WHT, ...
    'FontName',FONT, ...
    'FontSize',11, ...
    'FontWeight','bold', ...
    'HorizontalAlignment','left');

uicontrol(p, ...
    'Style','text', ...
    'Units','normalized', ...
    'Position',[0.06 0.815 0.88 0.045], ...
    'String','ROI size (square pixels)', ...
    'BackgroundColor',PAN, ...
    'ForegroundColor',WHT, ...
    'FontName',FONT, ...
    'FontSize',11, ...
    'FontWeight','bold', ...
    'HorizontalAlignment','left');

hBrush = uicontrol(p, ...
    'Style','slider', ...
    'Units','normalized', ...
    'Position',[0.06 0.765 0.66 0.045], ...
    'Min',1, ...
    'Max',maxBrush, ...
    'Value',brushSize, ...
    'SliderStep',[ ...
        1/max(1,maxBrush-1) ...
        min(1,10/max(1,maxBrush-1))], ...
    'Callback',@onBrushSlider);

hBrushEdit = uicontrol(p, ...
    'Style','edit', ...
    'Units','normalized', ...
    'Position',[0.75 0.76 0.19 0.055], ...
    'String',num2str(brushSize), ...
    'BackgroundColor',CARD, ...
    'ForegroundColor',WHT, ...
    'FontName',FONT, ...
    'FontSize',11, ...
    'FontWeight','bold', ...
    'Callback',@onBrushEdit);

hAll = uicontrol(p, ...
    'Style','checkbox', ...
    'Units','normalized', ...
    'Position',[0.06 0.705 0.88 0.045], ...
    'String','Apply brush to all slices', ...
    'Value',0, ...
    'BackgroundColor',PAN, ...
    'ForegroundColor',WHT, ...
    'FontName',FONT, ...
    'FontSize',11, ...
    'FontWeight','bold', ...
    'Callback',@onApplyAll);

if nz < 2
    set(hAll,'Enable','off');
end

hSliceText = uicontrol(p, ...
    'Style','text', ...
    'Units','normalized', ...
    'Position',[0.06 0.645 0.88 0.045], ...
    'String','', ...
    'BackgroundColor',PAN, ...
    'ForegroundColor',WHT, ...
    'FontName',FONT, ...
    'FontSize',11, ...
    'FontWeight','bold', ...
    'HorizontalAlignment','left');

hSlice = uicontrol(p, ...
    'Style','slider', ...
    'Units','normalized', ...
    'Position',[0.06 0.60 0.88 0.04], ...
    'Min',1, ...
    'Max',max(2,nz), ...
    'Value',zc, ...
    'SliderStep',[ ...
        1/max(1,nz-1) ...
        max(1/max(1,nz-1),0.1)], ...
    'Callback',@onSliceSlider);

if nz < 2
    set(hSlice,'Enable','off');
end

uicontrol(p, ...
    'Style','pushbutton', ...
    'Units','normalized', ...
    'Position',[0.06 0.525 0.88 0.055], ...
    'String','AUTO: LOWEST 25% SIGNAL', ...
    'BackgroundColor',ACC, ...
    'ForegroundColor',WHT, ...
    'FontName',FONT, ...
    'FontSize',10.5, ...
    'FontWeight','bold', ...
    'Callback',@onAutoLow);

uicontrol(p, ...
    'Style','pushbutton', ...
    'Units','normalized', ...
    'Position',[0.06 0.455 0.42 0.055], ...
    'String','CLEAR SLICE', ...
    'BackgroundColor',CARD, ...
    'ForegroundColor',WHT, ...
    'FontName',FONT, ...
    'FontSize',10.5, ...
    'FontWeight','bold', ...
    'Callback',@onClearSlice);

uicontrol(p, ...
    'Style','pushbutton', ...
    'Units','normalized', ...
    'Position',[0.52 0.455 0.42 0.055], ...
    'String','CLEAR ALL', ...
    'BackgroundColor',CARD, ...
    'ForegroundColor',WHT, ...
    'FontName',FONT, ...
    'FontSize',10.5, ...
    'FontWeight','bold', ...
    'Callback',@onClearAll);

uicontrol(p, ...
    'Style','pushbutton', ...
    'Units','normalized', ...
    'Position',[0.06 0.385 0.88 0.055], ...
    'String','INVERT CURRENT SLICE', ...
    'BackgroundColor',CARD, ...
    'ForegroundColor',WHT, ...
    'FontName',FONT, ...
    'FontSize',10.5, ...
    'FontWeight','bold', ...
    'Callback',@onInvertSlice);

hInfo = uicontrol(p, ...
    'Style','text', ...
    'Units','normalized', ...
    'Position',[0.06 0.245 0.88 0.115], ...
    'String','', ...
    'BackgroundColor',PAN, ...
    'ForegroundColor',MINT, ...
    'FontName',FONT, ...
    'FontSize',11, ...
    'FontWeight','bold', ...
    'HorizontalAlignment','left');

uicontrol(p, ...
    'Style','text', ...
    'Units','normalized', ...
    'Position',[0.06 0.165 0.88 0.07], ...
    'String','Select non-responsive tissue/noise. Avoid expected PACAP response regions.', ...
    'BackgroundColor',PAN, ...
    'ForegroundColor',DIM, ...
    'FontName',FONT, ...
    'FontSize',9.8, ...
    'HorizontalAlignment','left');

uicontrol(p, ...
    'Style','pushbutton', ...
    'Units','normalized', ...
    'Position',[0.06 0.085 0.88 0.065], ...
    'String','USE THIS REGION', ...
    'BackgroundColor',[0.13 0.62 0.38], ...
    'ForegroundColor',WHT, ...
    'FontName',FONT, ...
    'FontSize',12.5, ...
    'FontWeight','bold', ...
    'Callback',@onOK);

uicontrol(p, ...
    'Style','pushbutton', ...
    'Units','normalized', ...
    'Position',[0.06 0.015 0.88 0.055], ...
    'String','Cancel', ...
    'BackgroundColor',[0.52 0.16 0.18], ...
    'ForegroundColor',WHT, ...
    'FontName',FONT, ...
    'FontSize',11.5, ...
    'FontWeight','bold', ...
    'Callback',@onCancel);

refreshScene();
uiwait(f);

    function onBrushSlider(~,~)
        brushSize = max(1,min(maxBrush,round(get(hBrush,'Value'))));
        set(hBrushEdit,'String',num2str(brushSize));
        updatePreview();
    end

    function onBrushEdit(~,~)
        v = str2double(strtrim(get(hBrushEdit,'String')));
        if ~isfinite(v)
            v = brushSize;
        end

        brushSize = max(1,min(maxBrush,round(v)));
        set(hBrush,'Value',brushSize);
        set(hBrushEdit,'String',num2str(brushSize));
        updatePreview();
    end

    function onApplyAll(~,~)
        applyAll = logical(get(hAll,'Value'));
        refreshInfo();
    end

    function onSliceSlider(~,~)
        setSlice(round(get(hSlice,'Value')));
    end

    function setSlice(z)
        zc = max(1,min(nz,z));
        set(hSlice,'Value',zc);
        refreshScene();
    end

    function onMouseWheel(~,evt)
        if nz <= 1 || ~pointerOnAxes()
            return;
        end

        dz = sign(evt.VerticalScrollCount);
        if dz == 0
            return;
        end

        setSlice(zc + dz);
    end

    function onMouseDown(~,~)
        if ~pointerOnAxes()
            return;
        end

        typ = get(f,'SelectionType');

        if strcmp(typ,'normal')
            paintMode = 1;
        elseif strcmp(typ,'alt')
            paintMode = -1;
        else
            return;
        end

        painting = true;
        lastPaintXY = [-inf -inf];
        paintAtPointer();
    end

    function onMouseUp(~,~)
        painting = false;
        lastPaintXY = [-inf -inf];
    end

    function onMouseMove(~,~)
        updatePreview();

        if painting
            paintAtPointer();
        end
    end

    function updatePreview()
        if ~pointerOnAxes()
            set(hPreview,'Visible','off');
            return;
        end

        [x,y,ok] = pointerXY();
        if ~ok
            set(hPreview,'Visible','off');
            return;
        end

        [x1,x2,y1,y2] = brushBounds(x,y);

        if painting && paintMode < 0
            col = RED;
        else
            col = GOLD;
        end

        set(hPreview, ...
            'Position',[x1 y1 x2-x1+1 y2-y1+1], ...
            'EdgeColor',col, ...
            'Visible','on');
    end

    function paintAtPointer()
        [x,y,ok] = pointerXY();
        if ~ok
            return;
        end

        if x == lastPaintXY(1) && y == lastPaintXY(2)
            return;
        end

        lastPaintXY = [x y];
        [x1,x2,y1,y2] = brushBounds(x,y);

        if applyAll
            zList = 1:nz;
        else
            zList = zc;
        end

        for zz = zList
            if paintMode > 0
                sel(y1:y2,x1:x2,zz) = true;
            else
                sel(y1:y2,x1:x2,zz) = false;
            end
        end

        set(hOv,'AlphaData',0.42*double(sel(:,:,zc)));
        refreshInfo();
        drawnow limitrate;
    end

    function [x1,x2,y1,y2] = brushBounds(x,y)
        leftHalf = floor((brushSize-1)/2);
        rightHalf = brushSize-1-leftHalf;

        x1 = max(1,x-leftHalf);
        x2 = min(nx,x+rightHalf);
        y1 = max(1,y-leftHalf);
        y2 = min(ny,y+rightHalf);
    end

    function [x,y,ok] = pointerXY()
        cp = get(ax,'CurrentPoint');
        x = round(cp(1,1));
        y = round(cp(1,2));

        ok = x >= 1 && x <= nx && y >= 1 && y <= ny;
    end

    function tf = pointerOnAxes()
        tf = false;

        try
            obj = hittest(f);

            if obj == ax
                tf = true;
            else
                a = ancestor(obj,'axes');
                tf = ~isempty(a) && a == ax;
            end
        catch
            [~,~,tf] = pointerXY();
        end
    end

    function onAutoLow(~,~)
        if applyAll
            zList = 1:nz;
        else
            zList = zc;
        end

        for zz = zList
            A = double(M3(:,:,zz));
            v = A(isfinite(A));

            if isempty(v)
                continue;
            end

            thr = localPercentile(v,25);
            sel(:,:,zz) = sel(:,:,zz) | (A <= thr);
        end

        refreshScene();
    end

    function onClearSlice(~,~)
        sel(:,:,zc) = false;
        refreshScene();
    end

    function onClearAll(~,~)
        sel(:) = false;
        refreshScene();
    end

    function onInvertSlice(~,~)
        sel(:,:,zc) = ~sel(:,:,zc);
        refreshScene();
    end

    function refreshScene()
        set(hImg,'CData',D3(:,:,zc));
        set(hOv,'AlphaData',0.42*double(sel(:,:,zc)));

        set(hTitle,'String',sprintf( ...
            'SCM log/median underlay - slice %d/%d', ...
            zc,nz));

        set(hSliceText,'String',sprintf( ...
            'Slice %d / %d',zc,nz));

        refreshInfo();
        updatePreview();
        drawnow limitrate;
    end

    function refreshInfo()
        set(hInfo,'String',sprintf([ ...
            'Selected: %d voxels total\n' ...
            'Current slice: %d voxels\n' ...
            'Brush: %d x %d px'], ...
            nnz(sel), ...
            nnz(sel(:,:,zc)), ...
            brushSize, ...
            brushSize));
    end

    function onOK(~,~)
        if nnz(sel) < 20
            errordlg( ...
                'Select at least 20 voxels.', ...
                'aCompCor ROI');
            return;
        end

        if nz == 1
            mask = sel(:,:,1);
        else
            mask = sel;
        end

        try
            uiresume(f);
        catch
        end

        delete(f);
    end

    function onCancel(~,~)
        mask = [];

        try
            uiresume(f);
        catch
        end

        if ishghandle(f)
            delete(f);
        end
    end
end

function idx = localSubsample(T,maxFrames)
if T <= maxFrames
    idx = 1:T;
else
    idx = unique(round(linspace(1,T,maxFrames)));
end
end

function U01 = localScmDisplay(U)
% Match FunctionalConnectivity SCM-log/median defaults:
% logGain=2, percentile 0.5-99.7, sharpness=0.35,
% contrast=1.10, brightness=-0.04 and gamma=0.95.

U = double(U);
U(~isfinite(U)) = 0;
U = U - min(U(:));

pos = U(isfinite(U) & U > 0);
if isempty(pos)
    med = 1;
else
    med = median(pos);
end

if ~isfinite(med) || med <= 0
    med = max(eps,localPercentile(U(:),50));
end

Ulog = log1p(max(0,U) ./ max(eps,med) * 2.0);

lo = localPercentile(Ulog(:),0.5);
hi = localPercentile(Ulog(:),99.7);

if ~isfinite(lo) || ~isfinite(hi) || hi <= lo
    lo = min(Ulog(:));
    hi = max(Ulog(:));
end

if ~isfinite(lo) || ~isfinite(hi) || hi <= lo
    U01 = zeros(size(Ulog));
else
    U01 = (Ulog-lo) ./ max(eps,hi-lo);
end

U01 = min(max(U01,0),1);

blur = conv2(U01,ones(3,3)/9,'same');
U01 = U01 + 0.35*(U01-blur);
U01 = min(max(U01,0),1);

U01 = U01*1.10 - 0.04;
U01 = min(max(U01,0),1);

U01 = U01.^0.95;
U01 = min(max(U01,0),1);
end

function q = localPercentile(v,p)
v = double(v(:));
v = sort(v(isfinite(v)));

if isempty(v)
    q = NaN;
    return;
end

p = max(0,min(100,double(p)));

if numel(v) == 1
    q = v(1);
    return;
end

r = 1 + (numel(v)-1)*p/100;
i0 = floor(r);
i1 = ceil(r);

if i0 == i1
    q = v(i0);
else
    q = v(i0) + (r-i0)*(v(i1)-v(i0));
end
end
