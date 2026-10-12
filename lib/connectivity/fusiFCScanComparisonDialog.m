function pair=fusiFCScanComparisonDialog(names,current)
pair=[];C=deConfUSIon_ui('palette');
f=figure('Name','Compare FC scans','NumberTitle','off','MenuBar','none','ToolBar','none', ...
    'Color',C.background,'Position',[220 220 650 245],'WindowStyle','modal','Resize','off','CloseRequestFcn',@cancel);
guard=onCleanup(@()deleteIfValid(f)); %#ok<NASGU>
make('text','Reference scan A',[20 201 610 24]);a=make('popupmenu',names,[20 166 610 30]);a.Value=current;
make('text','Comparison scan B',[20 126 610 24]);b=make('popupmenu',names,[20 91 610 30]);b.Value=find((1:numel(names))~=current,1);
make('text','Each scan uses its own selected period. Difference = B minus A; this is descriptive, not a significance test.',[20 43 610 40]);
h=make('pushbutton','Cancel',[340 8 130 30]);h.BackgroundColor=C.danger;h.Callback=@cancel;
h=make('pushbutton','Compare scans',[490 8 140 30]);h.BackgroundColor=C.success;h.Callback=@accept;
uiwait(f);
    function h=make(style,str,pos)
        h=uicontrol(f,'Style',style,'String',str,'Position',pos,'FontSize',11,'BackgroundColor',C.background, ...
            'ForegroundColor',C.text,'HorizontalAlignment','left');
    end
    function accept(varargin),if a.Value~=b.Value,pair=[a.Value b.Value];uiresume(f);end,end
    function cancel(varargin),pair=[];uiresume(f);end
end
function deleteIfValid(f),if isgraphics(f),delete(f);end,end
