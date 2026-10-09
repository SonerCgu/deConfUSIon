function dialog=fusiExportSavedDialog(files,seconds)
% Nonmodal confirmation; explicit folder opening only when clicked.
if ischar(files)||isstring(files),files=cellstr(files);end
if nargin<2,seconds=[];end
dialog=figure('Name','Export saved','NumberTitle','off','MenuBar','none','ToolBar','none', ...
    'Color','k','Position',[200 200 700 245],'Resize','off','Tag','FUSIExportSaved');
message=[{'Saved successfully:'}; files(:)];
if ~isempty(seconds),message{end+1}=sprintf('Completed in %.1f seconds.',seconds);end
uicontrol(dialog,'Style','text','Units','normalized','Position',[.025 .28 .95 .68], ...
    'String',message,'HorizontalAlignment','left','BackgroundColor','k','ForegroundColor','w','FontSize',11);
folder=fileparts(files{1});setappdata(dialog,'ExportFolder',folder);
uicontrol(dialog,'Style','pushbutton','Units','normalized','Position',[.025 .05 .45 .17], ...
    'String','Open saved folder','Tag','FUSIExportOpenFolder','BackgroundColor',[.12 .5 .25], ...
    'ForegroundColor','w','Callback',@(~,~)winopen(folder));
uicontrol(dialog,'Style','pushbutton','Units','normalized','Position',[.53 .05 .445 .17], ...
    'String','Close','Callback',@(~,~)delete(dialog));
end
