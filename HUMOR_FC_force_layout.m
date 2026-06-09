function HUMOR_FC_force_layout(fig)
% Stable/idempotent FC GUI layout fixer.
% Repeated calls produce the same layout. No timers, no callbacks, no wrappers.

try
    if nargin < 1 || isempty(fig) || ~ishghandle(fig)
        fig = gcf;
    end

    %% Box 4: Display / Save
    pSave = localFindPanelByTitle(fig,'4. Display / Save');
    if ~isempty(pSave) && ishghandle(pSave)
        try, set(pSave,'Units','normalized','Position',[0.015 0.005 0.970 0.405],'FontSize',11,'FontWeight','bold'); catch, end

        % General readable size for all Box 4 controls.
        kids = findall(pSave,'Type','uicontrol');
        for k = 1:numel(kids)
            try
                st = lower(char(get(kids(k),'Style')));
                if strcmp(st,'pushbutton')
                    set(kids(k),'FontSize',13,'FontWeight','bold');
                elseif strcmp(st,'text') || strcmp(st,'edit') || strcmp(st,'checkbox') || strcmp(st,'popupmenu')
                    set(kids(k),'FontSize',15);
                    try, set(kids(k),'FontWeight','bold'); catch, end
                end
            catch
            end
        end

        % Row 1: color and seed z-limit.
        localMoveText(pSave,'Color',[0.045 0.835 0.090 0.060],15);
        h = localFindPopupContaining(pSave,'blue');
        if localIsHandle(h), set(h,'Units','normalized','Position',[0.135 0.800 0.360 0.105],'FontSize',15); end
        localMoveText(pSave,'Seed z-limit',[0.550 0.835 0.190 0.060],15);
        localMoveEditExact(pSave,'1',[0.740 0.800 0.115 0.105],15);

        % Row 2: checkboxes.
        localMoveControlByString(pSave,'Show L/R',[0.045 0.675 0.240 0.080],15);
        localMoveControlByString(pSave,'Slice ROIs',[0.330 0.675 0.270 0.080],15);

        % Hide duplicate Pick/All, then show one clean pair above Labels.
        localHideAllButtons(pSave,'Pick');
        localHideAllButtons(pSave,'All');
        localShowFirstButton(pSave,'Pick',[0.660 0.615 0.130 0.070],13);
        localShowFirstButton(pSave,'All',[0.815 0.615 0.130 0.070],13);

        % Row 3: regions and labels.
        localMoveText(pSave,'Regions',[0.045 0.505 0.105 0.065],15);
        h = localFindPopupContaining(pSave,'both l/r');
        if localIsHandle(h), set(h,'Units','normalized','Position',[0.150 0.475 0.385 0.105],'FontSize',15); end
        localMoveText(pSave,'Labels',[0.575 0.505 0.090 0.065],15);
        h = localFindByTag(pSave,'FC_MatrixTickMode');
        if localIsHandle(h), set(h,'Units','normalized','Position',[0.665 0.475 0.280 0.105],'FontSize',15); end

        % Row 4: window controls.
        localMoveTextContains(pSave,'Window',[0.045 0.340 0.095 0.065],'Window',15);
        h = localFindPopupContaining(pSave,'whole');
        if localIsHandle(h), set(h,'Units','normalized','Position',[0.140 0.310 0.175 0.105],'FontSize',15); end
        localMoveText(pSave,'Start',[0.340 0.340 0.060 0.065],15);
        localMoveEditExact(pSave,'14.00',[0.405 0.310 0.075 0.105],15);
        localMoveEditExact(pSave,'14',[0.405 0.310 0.075 0.105],15);
        localMoveText(pSave,'End',[0.500 0.340 0.055 0.065],15);
        localMoveEditExact(pSave,'15.00',[0.555 0.310 0.075 0.105],15);
        localMoveEditExact(pSave,'15',[0.555 0.310 0.075 0.105],15);
        localMoveText(pSave,'Win',[0.650 0.340 0.050 0.065],15);
        localMoveEditExact(pSave,'3.00',[0.700 0.310 0.075 0.105],15);
        localMoveEditExact(pSave,'3',[0.700 0.310 0.075 0.105],15);

        % Apply / Use win separated.
        localRenameButton(pSave,'Apply win','Apply');
        localRenameButton(pSave,'Apply window','Apply');
        localHideDuplicateButtons(pSave,'Apply');
        localMoveButton(pSave,'Apply',[0.805 0.320 0.160 0.090],17);
        localMoveControlByString(pSave,'Use win',[0.805 0.245 0.223 0.068],15);

        % Bottom buttons.
        localMoveButton(pSave,'Export GA',[0.020 0.045 0.150 0.095],13);
        localRenameButton(pSave,'Reset view','Reset');
        localMoveButton(pSave,'Reset',[0.185 0.045 0.130 0.095],13);
        localMoveButton(pSave,'Region key',[0.330 0.045 0.165 0.095],13);
        localMoveButton(pSave,'Save',[0.515 0.045 0.115 0.095],13);
        localMoveButton(pSave,'Help',[0.650 0.045 0.115 0.095],13);
        localMoveButton(pSave,'Close',[0.785 0.045 0.165 0.095],13);
    end

    %% Seed Map bottom-right Display controls
    pDisp = localFindSeedDisplayPanel(fig);
    if ~isempty(pDisp) && ishghandle(pDisp)
        bg = localGet(pDisp,'BackgroundColor',[0.07 0.07 0.08]);
        fg = localGet(pDisp,'ForegroundColor',[1 1 1]);
        try, set(pDisp,'Units','normalized','Position',[0.625 0.000 0.365 0.360],'FontSize',11,'FontWeight','bold'); catch, end

        % Remove only old text labels in this panel, then recreate stable full-word labels.
        try, delete(findall(pDisp,'Type','uicontrol','Style','text')); catch, end

        ddOverlay  = localFindPopupContaining(pDisp,'seed');
        ddUnderlay = localFindPopupContaining(pDisp,'scm');
        if isempty(ddUnderlay), ddUnderlay = localFindPopupContaining(pDisp,'underlay'); end
        edits = findall(pDisp,'Type','uicontrol','Style','edit');
        [edZ, edAlpha, edGamma, edSharp] = localClassifySeedEdits(edits);

        localLabel(pDisp,[0.030 0.760 0.150 0.120],'Overlay',bg,fg,10);
        if localIsHandle(ddOverlay), set(ddOverlay,'Units','normalized','Position',[0.180 0.725 0.345 0.170],'FontSize',10); end
        localLabel(pDisp,[0.550 0.760 0.045 0.120],'Z',bg,fg,10);
        if localIsHandle(edZ), set(edZ,'Units','normalized','Position',[0.595 0.720 0.075 0.180],'FontSize',10); end
        localLabel(pDisp,[0.695 0.760 0.120 0.120],'Alpha',bg,fg,10);
        if localIsHandle(edAlpha), set(edAlpha,'Units','normalized','Position',[0.815 0.720 0.110 0.180],'FontSize',10); end

        localLabel(pDisp,[0.030 0.500 0.170 0.120],'Underlay',bg,fg,10);
        if localIsHandle(ddUnderlay), set(ddUnderlay,'Units','normalized','Position',[0.205 0.465 0.705 0.170],'FontSize',10); end

        localLabel(pDisp,[0.030 0.230 0.185 0.120],'Gamma',bg,fg,10);
        if localIsHandle(edGamma), set(edGamma,'Units','normalized','Position',[0.215 0.195 0.125 0.170],'FontSize',10); end
        localLabel(pDisp,[0.530 0.230 0.220 0.120],'Sharpness',bg,fg,10);
        if localIsHandle(edSharp), set(edSharp,'Units','normalized','Position',[0.745 0.195 0.125 0.170],'FontSize',10); end
    end

    drawnow;
catch ME
    try, fprintf('HUMOR_FC_force_layout warning: %s\n',ME.message); catch, end
end
end

function tf = localIsHandle(h)
tf = ~isempty(h) && ishghandle(h);
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

function p = localFindSeedDisplayPanel(fig)
p = []; bestX = -Inf;
pan = findall(fig,'Type','uipanel');
for i = 1:numel(pan)
    try
        ttl = lower(char(get(pan(i),'Title')));
        if ~isempty(strfind(ttl,'display controls')) || ~isempty(strfind(ttl,'seed-map display'))
            oldUnits = get(pan(i),'Units');
            set(pan(i),'Units','normalized');
            pos = get(pan(i),'Position');
            set(pan(i),'Units',oldUnits);
            if numel(pos) == 4 && pos(1) > bestX
                bestX = pos(1); p = pan(i);
            end
        end
    catch
    end
end
end

function h = localFindPopupContaining(parent,word)
h = [];
pp = findall(parent,'Type','uicontrol','Style','popupmenu');
for i = 1:numel(pp)
    try
        s = get(pp(i),'String');
        if iscell(s), flat = strjoin(s,' '); else, flat = char(s); end
        if ~isempty(strfind(lower(flat),lower(word)))
            h = pp(i); return;
        end
    catch
    end
end
end

function h = localFindByTag(parent,tagStr)
h = [];
cc = findall(parent,'Type','uicontrol');
for i = 1:numel(cc)
    try
        if strcmpi(char(get(cc(i),'Tag')),tagStr)
            h = cc(i); return;
        end
    catch
    end
end
end

function localMoveText(parent,str,pos,fs)
h = findall(parent,'Type','uicontrol','Style','text','String',str);
if ~isempty(h)
    set(h(1),'Units','normalized','Position',pos,'Visible','on','FontSize',fs,'FontWeight','bold','HorizontalAlignment','left');
end
end

function localMoveTextContains(parent,word,pos,newStr,fs)
hh = findall(parent,'Type','uicontrol','Style','text');
for i = 1:numel(hh)
    try
        s = char(get(hh(i),'String'));
        if ~isempty(strfind(lower(s),lower(word)))
            set(hh(i),'String',newStr,'Units','normalized','Position',pos,'Visible','on','FontSize',fs,'FontWeight','bold','HorizontalAlignment','left');
            return;
        end
    catch
    end
end
end

function localMoveControlByString(parent,str,pos,fs)
h = findall(parent,'Type','uicontrol','String',str);
if ~isempty(h)
    set(h(1),'Units','normalized','Position',pos,'Visible','on','FontSize',fs);
    try, set(h(1),'FontWeight','bold'); catch, end
end
end

function localMoveEditExact(parent,str,pos,fs)
hh = findall(parent,'Type','uicontrol','Style','edit');
for i = 1:numel(hh)
    try
        s = strtrim(char(get(hh(i),'String')));
        if strcmp(s,str)
            set(hh(i),'Units','normalized','Position',pos,'Visible','on','FontSize',fs,'FontWeight','bold');
            return;
        end
    catch
    end
end
end

function localMoveButton(parent,str,pos,fs)
h = findall(parent,'Type','uicontrol','Style','pushbutton','String',str);
if ~isempty(h)
    set(h(1),'Units','normalized','Position',pos,'Visible','on','FontSize',fs,'FontWeight','bold');
end
end

function localRenameButton(parent,oldStr,newStr)
h = findall(parent,'Type','uicontrol','Style','pushbutton','String',oldStr);
if ~isempty(h)
    set(h(1),'String',newStr);
end
end

function localHideAllButtons(parent,str)
h = findall(parent,'Type','uicontrol','Style','pushbutton','String',str);
if ~isempty(h)
    try, set(h,'Visible','off'); catch, end
end
end

function localShowFirstButton(parent,str,pos,fs)
h = findall(parent,'Type','uicontrol','Style','pushbutton','String',str);
if ~isempty(h)
    set(h(1),'Units','normalized','Position',pos,'Visible','on','FontSize',fs,'FontWeight','bold');
end
end

function localHideDuplicateButtons(parent,str)
h = findall(parent,'Type','uicontrol','Style','pushbutton','String',str);
if numel(h) > 1
    try, set(h(2:end),'Visible','off'); catch, end
end
end

function localLabel(parent,pos,str,bg,fg,fs)
uicontrol('Parent',parent,'Style','text','Units','normalized', ...
    'Position',pos,'String',str,'BackgroundColor',bg,'ForegroundColor',fg, ...
    'FontName','Arial','FontWeight','bold','FontSize',fs, ...
    'HorizontalAlignment','left');
end

function [edZ, edAlpha, edGamma, edSharp] = localClassifySeedEdits(edits)
edZ = []; edAlpha = []; edGamma = []; edSharp = [];
if isempty(edits), return; end
n = numel(edits); pos = zeros(n,4); vals = nan(n,1); hasDot = false(n,1);
for i = 1:n
    try, pos(i,:) = get(edits(i),'Position'); catch, end
    try
        s = char(get(edits(i),'String'));
        vals(i) = str2double(s);
        hasDot(i) = ~isempty(strfind(s,'.'));
    catch
    end
end
idxZ = find(isfinite(vals) & ~hasDot,1,'first');
if ~isempty(idxZ), edZ = edits(idxZ); end
dec = find(isfinite(vals) & hasDot);
if numel(dec) >= 3
    [~,o] = sortrows([-pos(dec,2), pos(dec,1)]);
    dec = dec(o); edAlpha = edits(dec(1));
    lower = dec(2:end); [~,ox] = sort(pos(lower,1)); lower = lower(ox);
    edGamma = edits(lower(1));
    if numel(lower) >= 2, edSharp = edits(lower(2)); end
else
    rem = setdiff(1:n,idxZ); [~,ord] = sortrows([-pos(rem,2), pos(rem,1)]); rem = rem(ord);
    if numel(rem) >= 1, edAlpha = edits(rem(1)); end
    if numel(rem) >= 2, edGamma = edits(rem(2)); end
    if numel(rem) >= 3, edSharp = edits(rem(3)); end
end
end
