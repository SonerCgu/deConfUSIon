function gaPublicationTheme(ax,theme)
% Apply the chosen export theme after renderers and legends finish drawing.
if ~isgraphics(ax,'axes'),return;end
bg=[1 1 1];fg=[0 0 0];if strcmpi(theme,'Dark'),bg=[0 0 0];fg=[1 1 1];end
canvas=ancestor(ax,'uipanel');if ~isempty(canvas),set(canvas,'BackgroundColor',bg);end
set(ax,'Color',bg,'XColor',fg,'YColor',fg,'ZColor',fg);
for name={'XColorMode','YColorMode','ZColorMode'}
    if isprop(ax,name{1}),set(ax,name{1},'manual');end
end
for name={'XAxis','YAxis','ZAxis'}
    rulers=get(ax,name{1});
    for ruler=rulers(:)'
        set(ruler,'Color',fg);
        if isprop(ruler,'SecondaryLabel')
            set(get(ruler,'SecondaryLabel'),'Color',fg,'FontName',get(ax,'FontName'), ...
                'FontUnits','points','FontSize',get(ax,'FontSize'),'FontWeight',get(ax,'FontWeight'));
        end
    end
end
labels=[get(ax,'XLabel');get(ax,'YLabel');get(ax,'ZLabel');get(ax,'Title')];
for tag={'GA_ROI_PLabel','GA_TitrationPValue','GA_InjectionLabel'}
    labels=[labels;findall(ax,'Tag',tag{1})]; %#ok<AGROW>
end
set(labels,'Color',fg,'FontUnits','points','FontName',get(ax,'FontName'), ...
    'FontSize',get(ax,'FontSize'),'FontWeight',get(ax,'FontWeight'));
lg=[];try,lg=get(ax,'Legend');catch,end
if ~isempty(lg)&&isgraphics(lg),set(lg,'TextColor',fg,'Color','none','EdgeColor','none');end
end
