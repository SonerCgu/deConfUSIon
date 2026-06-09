function HUMOR_fix_scm_video_dialog_fonts(figHandle)
% Final SCM/Video setup popup layout helper.
try
    if nargin < 1 || isempty(figHandle) || ~ishghandle(figHandle), return; end

    try
        oldUnits = get(figHandle,'Units');
        set(figHandle,'Units','pixels');
        p = get(figHandle,'Position');
        p(3) = max(p(3),1850);
        p(4) = max(p(4),1060);
        set(figHandle,'Position',p);
        set(figHandle,'Units',oldUnits);
        movegui(figHandle,'center');
    catch
    end

    % Align upper info box, baseline box, startup/manual sections.
    panels = findall(figHandle,'Type','uipanel');
    for i = 1:numel(panels)
        try
            ttl = char(get(panels(i),'Title'));
            set(panels(i),'FontUnits','points','FontSize',16,'FontWeight','bold');
            pos = get(panels(i),'Position');
            if isempty(strtrim(ttl)) && numel(pos) == 4 && pos(2) > 0.70
                set(panels(i),'Units','normalized','Position',[0.020 0.805 0.960 0.085]);
            elseif strcmpi(ttl,'Baseline window')
                set(panels(i),'Units','normalized','Position',[0.020 0.650 0.960 0.125]);
            elseif strcmpi(ttl,'Startup underlay source')
                set(panels(i),'Units','normalized','Position',[0.020 0.260 0.540 0.355]);
            elseif strcmpi(ttl,'Recommended Standard parameters')
                set(panels(i),'Units','normalized','Position',[0.575 0.260 0.405 0.355]);
            elseif strcmpi(ttl,'Manual file loading')
                set(panels(i),'Units','normalized','Position',[0.020 0.125 0.960 0.110]);
            end
        catch
        end
    end

    % Startup radio buttons + descriptions.
    radioLabels = { ...
        'Default current reference bg from PSC', ...
        'Step Motor Registration2D per-slice underlay', ...
        'Median of ACTIVE dataset', ...
        'Select external underlay / histology from Registration2D', ...
        'Recommended Standard - same logic as Mask Editor'};
    descLabels = { ...
        'Fast fallback. Uses the bg created during computePSC.', ...
        'For step-motor: choose histology / vascular / regions and load several source folders.', ...
        'Computes robust median from the current active dataset.', ...
        'Manual single underlay file selection. Good for one histology image.', ...
        'Mean(T) -> standardized Doppler equalized -> fixed window -> display FX.'};
    yMain = [0.820 0.625 0.430 0.235 0.040];
    yDesc = [0.755 0.560 0.365 0.170 0.000];
    for i = 1:numel(radioLabels)
        try
            h = findobj(figHandle,'Style','radiobutton','String',radioLabels{i});
            set(h,'FontUnits','points','FontSize',15,'FontWeight','bold', ...
                'Units','normalized','Position',[0.030 yMain(i) 0.945 0.095]);
        catch
        end
        try
            h = findobj(figHandle,'Style','text','String',descLabels{i});
            set(h,'FontUnits','points','FontSize',12.5,'FontWeight','normal', ...
                'Units','normalized','Position',[0.075 yDesc(i) 0.900 0.070]);
        catch
        end
    end

    % Recommended panel text/buttons.
    texts = findall(figHandle,'Style','text');
    for i = 1:numel(texts)
        try
            s = get(texts(i),'String');
            if iscell(s), flat = strjoin(s,' '); else, flat = char(s); end
            low = lower(flat);
            if ~isempty(strfind(low,'these match mask editor mode 7'))
                set(texts(i),'String',{'These match Mask Editor mode 7.','Change only if you want a different SCM/Video startup look.'}, ...
                    'FontUnits','points','FontSize',12.5,'FontWeight','bold', ...
                    'Units','normalized','Position',[0.040 0.850 0.920 0.095]);
            elseif ~isempty(strfind(low,'mask editor defaults')) || (~isempty(strfind(low,'stdlow 0.40')) && ~isempty(strfind(low,'sharpness')))
                set(texts(i),'String',{'Mask Editor defaults:','stdLow 0.40 | stdHigh 0.80 | gain 2.00','brightness 0.10 | contrast 0.50 | gamma 1.10','sharpness 75 | soft tone 0.40'}, ...
                    'FontUnits','points','FontSize',11,'FontWeight','bold', ...
                    'Units','normalized','Position',[0.045 0.200 0.900 0.170]);
            elseif ~isempty(strfind(low,'recommended standard selected'))
                set(texts(i),'FontUnits','points','FontSize',11.5,'FontWeight','bold', ...
                    'Units','normalized','Position',[0.025 0.070 0.950 0.040]);
            end
        catch
        end
    end

    try
        h = findobj(figHandle,'String','RESET MASK EDITOR DEFAULTS');
        set(h,'Units','normalized','Position',[0.045 0.105 0.410 0.115],'FontSize',11.5);
    catch
    end
    try
        h = findobj(figHandle,'String','USE RECOMMENDED');
        set(h,'Units','normalized','Position',[0.535 0.105 0.410 0.115],'FontSize',11.5);
    catch
    end

    % Manual file loading: larger and aligned.
    filePanel = [];
    panels = findall(figHandle,'Type','uipanel');
    for i = 1:numel(panels)
        try
            if strcmpi(char(get(panels(i),'Title')),'Manual file loading')
                filePanel = panels(i);
                break;
            end
        catch
        end
    end
    if ~isempty(filePanel)
        kids = findall(filePanel,'Type','uicontrol');
        for i = 1:numel(kids)
            try
                st = get(kids(i),'Style');
                if strcmpi(st,'pushbutton')
                    set(kids(i),'FontUnits','points','FontSize',15,'FontWeight','bold');
                elseif strcmpi(st,'popupmenu')
                    set(kids(i),'FontUnits','points','FontSize',14,'FontWeight','bold');
                else
                    set(kids(i),'FontUnits','points','FontSize',12.5,'FontWeight','bold');
                end
            catch
            end
        end
        try, set(findobj(filePanel,'String','Step kind'),'Units','normalized','Position',[0.490 0.650 0.120 0.260]); catch, end
        try, set(findobj(filePanel,'Style','popupmenu'),'Units','normalized','Position',[0.490 0.165 0.130 0.430]); catch, end
        try, set(findobj(filePanel,'String','LOAD / AUTO-FIND'),'Units','normalized','Position',[0.640 0.145 0.220 0.600]); catch, end
        try, set(findobj(filePanel,'String','Step mode: select parent folder, then subfolders.'),'Units','normalized','Position',[0.875 0.140 0.115 0.620]); catch, end
    end

    % Bottom buttons.
    try, set(findobj(figHandle,'String','OPEN SCM GUI'),'Units','normalized','Position',[0.495 0.015 0.280 0.050],'FontSize',14); catch, end
    try, set(findobj(figHandle,'String','OPEN VIDEO GUI'),'Units','normalized','Position',[0.495 0.015 0.280 0.050],'FontSize',14); catch, end
    try, set(findobj(figHandle,'String','CANCEL'),'Units','normalized','Position',[0.805 0.015 0.175 0.050],'FontSize',14); catch, end

    % General numeric fields.
    ctrls = findall(figHandle,'Type','uicontrol');
    for i = 1:numel(ctrls)
        try
            st = get(ctrls(i),'Style');
            if strcmpi(st,'edit')
                set(ctrls(i),'FontUnits','points','FontSize',17,'FontWeight','bold');
            elseif strcmpi(st,'pushbutton')
                set(ctrls(i),'FontUnits','points','FontSize',13.5,'FontWeight','bold');
            end
        catch
        end
    end
catch
end
end
