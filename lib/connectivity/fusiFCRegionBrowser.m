function f=fusiFCRegionBrowser(names,labels,counts,titleText)
% Readable abbreviation/full-name key, available before FC is calculated.
if nargin<4,titleText='FC region names';end
names=cellstr(string(names(:)));labels=double(labels(:));counts=double(counts(:));
f=figure('Name',titleText,'Tag','FCRegionKey','NumberTitle','off','MenuBar','none','ToolBar','none', ...
 'Color',[.08 .10 .13],'Position',[180 130 900 610]);
setappdata(f,'deConfUSIonNoMaximize',true);
uicontrol(f,'Style','text','Position',[20 566 860 24],'String','Search abbreviation or full name (e.g. cortex, MOp, fimbria)', ...
 'BackgroundColor',f.Color,'ForegroundColor','w','FontSize',12,'HorizontalAlignment','left');
search=uicontrol(f,'Style','edit','Position',[20 526 860 34],'Tag','FCRegionKeySearch','FontSize',12);
table=uitable(f,'Position',[20 66 860 445],'ColumnName',{'ID','Region','Voxels','Analysis'}, ...
 'ColumnWidth',{70 510 75 170},'FontSize',12,'RowName',[],'Tag','FCRegionKeyTable');
uicontrol(f,'Style','pushbutton','String','Close','Position',[750 16 130 34],'FontSize',12, ...
 'BackgroundColor',[.55 .15 .18],'ForegroundColor','w','Callback',@closeKey);
status=repmat({'Tissue'},numel(names),1);
for k=1:numel(names)
 if ~isempty(regexpi(names{k},'\<ventricles?\>|\<ventricular (system|space|cavity)|cerebral aqueduct|choroid plexus','once')),status{k}='Excluded (CSF)';end
end
fusiLiveSearch(search,@update);update('');
    function update(query)
        keep=fusiRegionSearchMatch(names,names,query);
        table.Data=[num2cell(labels(keep)) names(keep) num2cell(counts(keep)) status(keep)];
    end
    function closeKey(~,~),delete(f);end
end
