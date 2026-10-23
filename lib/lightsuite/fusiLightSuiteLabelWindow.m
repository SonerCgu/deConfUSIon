function id=fusiLightSuiteLabelWindow(fig,context,position)
% Keep independent LightSuite windows identifiable, including on the taskbar.
id=fusiLightSuiteIdentity(context);if ~isgraphics(fig),return;end
if ~isappdata(fig,'LightSuiteBaseTitle'),setappdata(fig,'LightSuiteBaseTitle',fig.Name);end
fig.Name=[getappdata(fig,'LightSuiteBaseTitle') ' | ' id.label];
setappdata(fig,'LightSuiteIdentity',id);
if nargin<3,return;end
header=findall(fig,'Tag','LightSuiteIdentityHeader');
if isempty(header)
    header=uicontrol(fig,'Style','text','Units','normalized','Position',position, ...
        'Tag','LightSuiteIdentityHeader','FontSize',12,'FontWeight','bold','HorizontalAlignment','left');
end
set(header,'String',id.label,'BackgroundColor',fig.Color,'ForegroundColor',[.55 .86 1], ...
    'TooltipString',sprintf('Recording: %s\nProject: %s',id.sourceFile,id.projectFolder));
end
