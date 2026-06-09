function cfg = HUMOR_pcaica_slice_scope_dialog(data, methodName)
% Slice-scope selector for PCA/ICA.
% Allows all-slices decomposition or one selected Z-slice.

if nargin < 2 || isempty(methodName), methodName = 'PCA/ICA'; end

cfg = struct();
cfg.cancelled = true;
cfg.mode = 'all';
cfg.zIndex = 1;
cfg.nSlices = 1;
cfg.sliceSpecific = false;

if ~isstruct(data) || ~isfield(data,'I')
    cfg.cancelled = false;
    return;
end

I = data.I;
if ndims(I) == 4
    Z = size(I,3);
else
    Z = 1;
end
cfg.nSlices = Z;

if Z <= 1
    cfg.cancelled = false;
    cfg.mode = 'all';
    cfg.zIndex = 1;
    cfg.sliceSpecific = false;
    return;
end

bg = [0.06 0.06 0.07];
panelBg = [0.10 0.10 0.12];
fg = [0.92 0.92 0.94];
accent = [0.20 0.45 0.95];

dlg = figure('Name',[methodName ' slice scope'], ...
    'Color',bg,'MenuBar','none','ToolBar','none', ...
    'NumberTitle','off','Resize','off', ...
    'WindowStyle','modal', ...
    'Position',[300 170 780 500]);

uicontrol('Parent',dlg,'Style','text','Units','normalized', ...
    'Position',[0.06 0.82 0.88 0.12], ...
    'String',[methodName ' scope for multi-slice / step-motor data'], ...
    'BackgroundColor',bg,'ForegroundColor',fg, ...
    'FontName','Arial','FontSize',22,'FontWeight','bold', ...
    'HorizontalAlignment','center');

uicontrol('Parent',dlg,'Style','text','Units','normalized', ...
    'Position',[0.08 0.68 0.84 0.09], ...
    'String','Choose whether PCA/ICA should run across all slices, or only one selected slice.', ...
    'BackgroundColor',bg,'ForegroundColor',[0.78 0.86 0.95], ...
    'FontName','Arial','FontSize',15,'HorizontalAlignment','center');

panel = uipanel('Parent',dlg,'Units','normalized','Position',[0.08 0.24 0.84 0.40], ...
    'BackgroundColor',panelBg,'ForegroundColor',fg,'Title','Decomposition scope', ...
    'FontName','Arial','FontSize',16,'FontWeight','bold');

modePopup = uicontrol('Parent',panel,'Style','popupmenu','Units','normalized', ...
    'Position',[0.08 0.68 0.84 0.20], ...
    'String',{'All slices together','Single selected slice only'}, ...
    'Value',1,'BackgroundColor',[0.16 0.16 0.18],'ForegroundColor',fg, ...
    'FontName','Arial','FontSize',15,'Callback',@updateUI);

sliceText = uicontrol('Parent',panel,'Style','text','Units','normalized', ...
    'Position',[0.08 0.42 0.84 0.14], ...
    'String',sprintf('Selected slice: 1 of %d',Z), ...
    'BackgroundColor',panelBg,'ForegroundColor',fg, ...
    'FontName','Arial','FontSize',16,'FontWeight','bold', ...
    'HorizontalAlignment','center');

if Z > 1
    stepSmall = 1/(Z-1);
else
    stepSmall = 1;
end

sliceSlider = uicontrol('Parent',panel,'Style','slider','Units','normalized', ...
    'Position',[0.08 0.18 0.84 0.16], ...
    'Min',1,'Max',Z,'Value',1, ...
    'SliderStep',[stepSmall min(1,stepSmall*2)], ...
    'Enable','off','Callback',@updateSliceText);

uicontrol('Parent',dlg,'Style','pushbutton','Units','normalized', ...
    'Position',[0.14 0.060 0.34 0.125],'String','Run', ...
    'BackgroundColor',[0.20 0.48 0.25],'ForegroundColor','w', ...
    'FontName','Arial','FontSize',16,'FontWeight','bold', ...
    'Callback',@onRun);

uicontrol('Parent',dlg,'Style','pushbutton','Units','normalized', ...
    'Position',[0.52 0.060 0.34 0.125],'String','Cancel', ...
    'BackgroundColor',[0.62 0.18 0.18],'ForegroundColor','w', ...
    'FontName','Arial','FontSize',16,'FontWeight','bold', ...
    'Callback',@onCancel);

updateUI();
uiwait(dlg);

    function updateUI(~,~)
        if get(modePopup,'Value') == 1
            set(sliceSlider,'Enable','off');
        else
            set(sliceSlider,'Enable','on');
        end
        updateSliceText();
    end

    function updateSliceText(~,~)
        z = round(get(sliceSlider,'Value'));
        z = max(1,min(Z,z));
        set(sliceSlider,'Value',z);
        if get(modePopup,'Value') == 1
            set(sliceText,'String',sprintf('All slices: 1-%d',Z));
        else
            set(sliceText,'String',sprintf('Selected slice: %d of %d',z,Z));
        end
    end

    function onRun(~,~)
        cfg.cancelled = false;
        cfg.nSlices = Z;
        if get(modePopup,'Value') == 1
            cfg.mode = 'all';
            cfg.zIndex = 1;
            cfg.sliceSpecific = false;
        else
            z = round(get(sliceSlider,'Value'));
            cfg.mode = 'slice';
            cfg.zIndex = max(1,min(Z,z));
            cfg.sliceSpecific = true;
        end
        if ishghandle(dlg), delete(dlg); end
    end

    function onCancel(~,~)
        cfg.cancelled = true;
        if ishghandle(dlg), delete(dlg); end
    end

end
