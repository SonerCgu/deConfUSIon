function fusiRegionListDialog(labels,info)
[catalog,~]=fusiAtlasRegionCatalog(labels,info);
f=figure('Name','Atlas region abbreviations','NumberTitle','off','Color','k', ...
 'MenuBar','none','ToolBar','none','Position',[200 160 720 540],'Tag','AtlasRegionList');
setappdata(f,'deConfUSIonNoMaximize',true);
rows=cell(numel(catalog),3);
for k=1:numel(catalog),rows(k,:)={catalog(k).id,catalog(k).acronym,catalog(k).name};end
uicontrol(f,'Style','text','String','Search abbreviation or full name','Units','normalized','Position',[.02 .925 .40 .045], ...
 'BackgroundColor','k','ForegroundColor','w','HorizontalAlignment','left','FontSize',12);
search=uicontrol(f,'Style','edit','String','','Units','normalized','Position',[.43 .925 .43 .05], ...
 'FontSize',12,'Tag','AtlasRegionSearch','Callback',@filterRegions,'KeyReleaseFcn',@filterRegions);
uicontrol(f,'Style','pushbutton','String','Clear','Units','normalized','Position',[.88 .925 .10 .05], ...
 'Tag','AtlasRegionSearchClear','Callback',@clearSearch);
count=uicontrol(f,'Style','text','String','','Units','normalized','Position',[.02 .87 .96 .04], ...
 'BackgroundColor','k','ForegroundColor',[.75 .8 .85],'HorizontalAlignment','left','Tag','AtlasRegionSearchCount');
table=uitable(f,'Units','normalized','Position',[.02 .03 .96 .82],'Data',rows, ...
 'ColumnName',{'Label ID','Abbreviation','Brain region'},'ColumnWidth',{75 130 445}, ...
 'FontSize',13,'ForegroundColor','w','BackgroundColor',[.08 .08 .08;.14 .14 .14], ...
 'Tag','AtlasRegionAbbreviationTable');
filterRegions();
    function filterRegions(~,~)
        words=split(lower(strtrim(string(search.String))));words=words(strlength(words)>0);
        text=lower(string(rows(:,2))+' '+string(rows(:,3)));keep=true(size(text));
        for word=words(:)',keep=keep&contains(text,word);end
        table.Data=rows(keep,:);count.String=sprintf('%d of %d regions',nnz(keep),size(rows,1));
    end
    function clearSearch(~,~),search.String='';filterRegions();end
end
