function fusiLightSuiteStyle(fig)
% Public MATLAB graphics properties only; no Java/tab-strip overrides.
fig.Color=[.035 .045 .045];setappdata(fig,'deConfUSIonNoMaximize',true);
for h=reshape(findall(fig,'Type','uipanel'),1,[])
    set(h,'BackgroundColor',[.045 .055 .055],'ForegroundColor',[.82 .92 .87]);
    setappdata(h,'PreserveColors',true);
end
for h=reshape(findall(fig,'Type','uicontrol'),1,[])
    set(h,'FontName','Arial','ForegroundColor',[.84 .93 .89]);
    switch h.Style
        case 'text'
            if isprop(h.Parent,'BackgroundColor'),h.BackgroundColor=h.Parent.BackgroundColor;
            else,h.BackgroundColor=h.Parent.Color;end
        case {'edit','popupmenu','listbox'},h.BackgroundColor=[.075 .095 .09];
        case {'pushbutton','togglebutton'},h.BackgroundColor=[.08 .21 .16];
        otherwise,h.BackgroundColor=[.045 .055 .055];
    end
    setappdata(h,'PreserveColors',true);
end
for h=reshape(findall(fig,'Type','uitable'),1,[])
    set(h,'BackgroundColor',[.055 .075 .065;.08 .11 .09], ...
        'ForegroundColor',[.85 .95 .89],'FontName','Arial','FontSize',11);
end
for h=reshape(findall(fig,'Type','axes'),1,[])
    set(h,'Color',[0 0 0],'XColor',[.65 .8 .73],'YColor',[.65 .8 .73]);
end
end
