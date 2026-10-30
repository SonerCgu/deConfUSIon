function selected = fusiDatasetPickerDialog(keys,labels,files,activeKey)
% Scrollable, searchable Studio dataset picker with no item-count limit.
selected = '';
if isempty(keys), return; end
keys = keys(:); labels = labels(:); files = files(:);
visible = (1:numel(keys))';
searchText = lower(string(labels) + " " + string(files));
C = deConfUSIon_ui('palette');
f = figure('Name','Browse all datasets','NumberTitle','off','MenuBar','none','ToolBar','none', ...
    'Color',C.background,'Units','pixels','Position',[180 140 1000 620], ...
    'WindowStyle','modal','Tag','StudioDatasetPicker','CloseRequestFcn',@cancel,'KeyPressFcn',@keyPress);
guard = onCleanup(@()deleteIfValid(f)); %#ok<NASGU>
setappdata(f,'deConfUSIonNoMaximize',true);
control('text','Search dataset name or file path',[.025 .925 .95 .045],'StudioDatasetSearchLabel',[]);
search = control('edit','',[.025 .865 .95 .055],'StudioDatasetSearch',[]);
count = control('text','',[.025 .805 .95 .04],'StudioDatasetCount',[]);
list = control('listbox',labels,[.025 .245 .95 .55],'StudioDatasetList',@selectionChanged);
set(list,'Min',0,'Max',1);
details = control('text','',[.025 .09 .95 .14],'StudioDatasetDetails',[]);
control('pushbutton','Cancel',[.67 .02 .14 .055],'StudioDatasetCancel',@cancel);
use = control('pushbutton','Use dataset',[.825 .02 .15 .055],'StudioDatasetUse',@accept);
set(use,'BackgroundColor',C.success,'FontWeight','bold');
idx = find(strcmp(keys,activeKey),1);
if isempty(idx), idx = 1; end
set(list,'Value',idx);
fusiLiveSearch(search,@filterList);
filterList('');
uiwait(f);
deleteIfValid(f);

    function h = control(style,label,pos,tag,callback)
        bg = C.background;
        if any(strcmp(style,{'edit','listbox'})), bg = C.input; end
        if strcmp(style,'pushbutton'), bg = C.button; end
        h = uicontrol(f,'Style',style,'String',label,'Units','normalized','Position',pos, ...
            'FontName',C.font,'FontSize',12,'ForegroundColor',C.text,'BackgroundColor',bg, ...
            'HorizontalAlignment','left','Tag',tag);
        if ~isempty(callback), set(h,'Callback',callback); end
    end

    function filterList(query)
        previous = '';
        if ~isempty(visible), previous = keys{visible(get(list,'Value'))}; end
        words = split(lower(strtrim(string(query))));
        words = words(strlength(words)>0);
        keep = true(size(keys));
        for word = words(:)', keep = keep & contains(searchText,word); end
        visible = find(keep);
        set(count,'String',sprintf('%d of %d datasets | Newest first',numel(visible),numel(keys)));
        if isempty(visible)
            set(list,'Value',1,'String',{'No matching datasets'},'Enable','off');
            set(details,'String',''); set(use,'Enable','off');
            return;
        end
        row = find(strcmp(keys(visible),previous),1);
        if isempty(row), row = 1; end
        set(list,'Value',1,'String',labels(visible),'Enable','on');
        set(list,'Value',row);
        set(use,'Enable','on');
        showDetails();
    end

    function selectionChanged(~,~)
        showDetails();
        if strcmp(get(f,'SelectionType'),'open'), accept(); end
    end

    function showDetails()
        if isempty(visible), return; end
        idx = visible(get(list,'Value'));
        set(details,'String',{labels{idx};files{idx}},'TooltipString',files{idx});
        set(list,'TooltipString',labels{idx});
    end

    function accept(~,~)
        if isempty(visible), return; end
        selected = keys{visible(get(list,'Value'))};
        uiresume(f);
    end

    function cancel(~,~)
        selected = ''; uiresume(f);
    end

    function keyPress(~,ev)
        if strcmp(ev.Key,'escape'), cancel();
        elseif any(strcmp(ev.Key,{'return','enter'})), accept(); end
    end
end

function deleteIfValid(f)
if isgraphics(f), delete(f); end
end
