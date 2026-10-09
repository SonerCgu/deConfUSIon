function [regions,accepted]=scmAtlasRegionSelectionDialog(catalog,selected,multiple,titleText)
% Search and tick regions without losing selections when the list is filtered.
if nargin<3,multiple=true;end
if nargin<4,titleText='Choose atlas regions';end
regions=catalog([]);accepted=false;ids=[];if ~isempty(selected),ids=[selected.id];end
C=deConfUSIon_ui('palette');
f=figure('Name',titleText,'Tag','SCMAtlasRegionSelection','NumberTitle','off', ...
    'MenuBar','none','ToolBar','none','Color',C.background,'Position',[220 120 780 580], ...
    'WindowStyle','modal','CloseRequestFcn',@cancel);
guard=onCleanup(@()deleteValid(f)); %#ok<NASGU>
setappdata(f,'deConfUSIonNoMaximize',true);
control('text','Search abbreviation or full name',[20 530 360 25],[]);
search=control('edit','',[20 492 740 32],@refresh);search.Tag='AtlasSelectionSearch';
fusiLiveSearch(search,@refreshQuery);
allTissue=control('checkbox','All labelled brain tissue (no named region restriction)',[20 452 740 30],@allChanged);
allTissue.Tag='AtlasSelectionAllTissue';allTissue.Value=isempty(ids)&&multiple;
if ~multiple,set(allTissue,'Visible','off');end
table=uitable(f,'Position',[20 115 740 326],'ColumnName',{'Use','Abbreviation','Full name','Voxels'}, ...
    'ColumnEditable',[true false false false],'ColumnFormat',{'logical','char','char','numeric'}, ...
    'ColumnWidth',{45 115 425 85},'FontSize',11,'CellEditCallback',@tick,'Tag','AtlasSelectionTable');
control('pushbutton','Select visible',[20 70 135 32],@selectVisible);
control('pushbutton','Clear selections',[165 70 135 32],@clearSelections);
status=control('text','',[315 70 445 32],[]);status.Tag='AtlasSelectionStatus';
cancelButton=control('pushbutton','Cancel',[490 20 120 34],@cancel);cancelButton.BackgroundColor=C.danger;
use=control('pushbutton','Use regions',[620 20 140 34],@accept);use.BackgroundColor=C.success;use.Tag='AtlasSelectionApply';
visible=[];refresh();setappdata(f,'AtlasSelectionReady',true);uiwait(f);
% Nested figure callbacks retain their shared workspace and its onCleanup.
% Explicitly remove the modal window when Apply or Cancel resumes uiwait.
deleteValid(f);
    function h=control(style,str,pos,cb)
        h=uicontrol(f,'Style',style,'String',str,'Position',pos,'FontSize',11, ...
            'BackgroundColor',C.background,'ForegroundColor',C.text,'HorizontalAlignment','left','Callback',cb);
    end
    function refresh(varargin)
        state=getappdata(search,'FUSILiveSearchState');refreshQuery(state.query);
    end
    function refreshQuery(query)
        visible=find(fusiRegionSearchMatch({catalog.acronym},{catalog.name},query));
        rows=cell(numel(visible),4);
        for row=1:numel(visible)
            c=catalog(visible(row));rows(row,:)={ismember(c.id,ids),c.acronym,c.name,c.voxelCount};
        end
        table.Data=rows;
        updateStatus();
    end
    function updateStatus()
        hidden=nnz(~ismember(ids,[catalog(visible).id]));
        status.String=sprintf('%d selected (%d hidden by search) | %d visible',numel(ids),hidden,numel(visible));
        names={catalog(ismember([catalog.id],ids)).displayName};
        status.TooltipString=strjoin(names,newline);use.TooltipString=['Apply every checked region, including selections hidden by the search filter.' newline strjoin(names,newline)];
        if allTissue.Value,status.String='All labelled brain tissue will be searched.';end
    end
    function tick(~,event)
        id=catalog(visible(event.Indices(1))).id;
        if event.NewData,ids=unique([ids id],'stable');else,ids(ids==id)=[];end
        if ~multiple&&event.NewData
            ids=id;rows=table.Data;rows(:,1)=num2cell([catalog(visible).id]'==id);table.Data=rows;
        end
        % MATLAB already committed the checkbox to Data. Replacing the table
        % inside its edit callback resets editing/focus and can lose clicks.
        allTissue.Value=0;updateStatus();
    end
    function selectVisible(~,~)
        if multiple,ids=unique([ids [catalog(visible).id]],'stable');elseif ~isempty(visible),ids=catalog(visible(1)).id;end
        allTissue.Value=0;refresh();
    end
    function clearSelections(~,~),ids=[];allTissue.Value=0;refresh();end
    function allChanged(~,~),refresh();end
    function accept(~,~)
        if ~multiple&&numel(ids)~=1,status.String='Select exactly one seed region.';return;end
        if ~allTissue.Value&&isempty(ids),status.String='Tick at least one region, or select All labelled brain tissue.';return;end
        if ~allTissue.Value,regions=catalog(ismember([catalog.id],ids));end
        accepted=true;uiresume(f);
    end
    function cancel(~,~),uiresume(f);end
end
function deleteValid(f),if isgraphics(f),delete(f);end,end
