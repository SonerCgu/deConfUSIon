function HUMOR_FC_remember_layout(fig,mode)
% Capture/restore the good FC GUI layout so Load Seg MAT does not shrink fonts.
try
    if nargin < 1 || isempty(fig) || ~ishghandle(fig), fig = gcf; end
    if nargin < 2 || isempty(mode), mode = 'restore'; end
    mode = lower(char(mode));

    switch mode
        case 'capture'
            S = localCapture(fig);
            setappdata(fig,'HUMOR_FC_GOOD_LAYOUT_SNAPSHOT',S);

        otherwise
            if ~isappdata(fig,'HUMOR_FC_GOOD_LAYOUT_SNAPSHOT')
                return;
            end
            S = getappdata(fig,'HUMOR_FC_GOOD_LAYOUT_SNAPSHOT');
            localRestore(S);
    end
catch ME
    try, fprintf('HUMOR_FC_remember_layout warning: %s\n',ME.message); catch, end
end
end

function S = localCapture(fig)
S = struct();
S.fig = fig;
S.items = {};

% Capture panels and controls that should never shrink/change after Load Seg.
targetPanels = {};
pSave = localFindPanelByTitle(fig,'4. Display / Save');
if ~isempty(pSave), targetPanels{end+1} = pSave; end
pROI = localFindPanelByTitle(fig,'3. Regions / ROI analysis');
if ~isempty(pROI), targetPanels{end+1} = pROI; end
pDisp = localFindDisplayPanel(fig);
if ~isempty(pDisp), targetPanels{end+1} = pDisp; end

for ip = 1:numel(targetPanels)
    p = targetPanels{ip};
    localAddItem(p);
    kids = findall(p,'Type','uicontrol');
    for k = 1:numel(kids)
        localAddItem(kids(k));
    end
end

    function localAddItem(h)
        try
            it = struct();
            it.h = h;
            it.type = get(h,'Type');
            it.units = get(h,'Units');
            set(h,'Units','normalized');
            it.position = get(h,'Position');
            set(h,'Units',it.units);
            it.visible = localGet(h,'Visible',[]);
            it.fontSize = localGet(h,'FontSize',[]);
            it.fontWeight = localGet(h,'FontWeight',[]);
            it.fontName = localGet(h,'FontName',[]);
            it.string = localGet(h,'String',[]);
            it.enable = localGet(h,'Enable',[]);
            S.items{end+1} = it;
        catch
        end
    end
end

function localRestore(S)
try
    for i = 1:numel(S.items)
        it = S.items{i};
        h = it.h;
        if isempty(h) || ~ishghandle(h), continue; end
        try
            oldUnits = get(h,'Units');
            set(h,'Units','normalized');
            set(h,'Position',it.position);
            set(h,'Units',oldUnits);
        catch
        end
        try, if ~isempty(it.visible), set(h,'Visible',it.visible); end, catch, end
        try, if ~isempty(it.fontSize), set(h,'FontSize',it.fontSize); end, catch, end
        try, if ~isempty(it.fontWeight), set(h,'FontWeight',it.fontWeight); end, catch, end
        try, if ~isempty(it.fontName), set(h,'FontName',it.fontName); end, catch, end
        try, if ~isempty(it.enable), set(h,'Enable',it.enable); end, catch, end
    end
catch
end
end

function val = localGet(h,prop,defaultVal)
val = defaultVal;
try, val = get(h,prop); catch, end
end

function p = localFindPanelByTitle(fig,titleStr)
p = [];
pan = findall(fig,'Type','uipanel');
for i = 1:numel(pan)
    try
        ttl = char(get(pan(i),'Title'));
        if strcmpi(strtrim(ttl),strtrim(titleStr))
            p = pan(i); return;
        end
    catch
    end
end
end

function p = localFindDisplayPanel(fig)
p = [];
pan = findall(fig,'Type','uipanel');
bestX = -Inf;
for i = 1:numel(pan)
    try
        ttl = lower(char(get(pan(i),'Title')));
        if ~isempty(strfind(ttl,'display controls')) || ~isempty(strfind(ttl,'seed-map display'))
            pos = get(pan(i),'Position');
            if numel(pos) == 4 && pos(1) > bestX
                bestX = pos(1);
                p = pan(i);
            end
        end
    catch
    end
end
end
