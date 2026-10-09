function scmCandidateTableColors(tbl,colors,preserve)
% Repaint the legacy candidate table without changing its viewport or data.
if nargin<3 || ~preserve
    set(tbl,'BackgroundColor',colors);return;
end
% R2023b's legacy table resets its viewport even for BackgroundColor edits.
% Isolate its Java bridge here; no downloaded findjobj dependency is needed.
% If a future renderer has no bridge, keep the checkbox/status responsive
% and defer row recoloring to the next explicit sort/filter refresh.
try
    pane=getappdata(tbl,'CandidateScrollPane');
    if isempty(pane)
        fig=ancestor(tbl,'figure');
        peer=matlab.graphics.internal.getFigureJavaFrame(fig);
        pane=findPane(peer.getFigurePanelContainer);
        if isempty(pane),return;end
        setappdata(tbl,'CandidateScrollPane',pane);
    end
    view=pane.getViewport;point=view.getViewPosition;jt=view.getView;
    widths=zeros(1,jt.getColumnCount);
    for k=1:numel(widths),widths(k)=jt.getColumnModel.getColumn(k-1).getWidth;end
    cells=zeros(0,2);rows=jt.getSelectedRows;cols=jt.getSelectedColumns;
    for r=reshape(rows,1,[])
        for c=reshape(cols,1,[])
            if jt.isCellSelected(r,c),cells(end+1,:)=[r c];end %#ok<AGROW>
        end
    end
catch
    return;
end
cb=get(tbl,'CellSelectionCallback');set(tbl,'CellSelectionCallback',[]);
guard=onCleanup(@()restoreCallback(tbl,cb));
set(tbl,'BackgroundColor',colors);drawnow nocallbacks;
jt=view.getView;
for k=1:numel(widths)
    column=jt.getColumnModel.getColumn(k-1);
    column.setPreferredWidth(widths(k));column.setWidth(widths(k));
end
jt.clearSelection;
for k=1:size(cells,1)
    javaMethodEDT('changeSelection',jt,int32(cells(k,1)),int32(cells(k,2)),k>1,false);
end
javaMethodEDT('setViewPosition',view,point);drawnow nocallbacks;
end

function pane=findPane(component)
pane=[];
if isa(component,'javax.swing.JScrollPane') && isa(component.getViewport.getView,'javax.swing.JTable')
    pane=component;return;
end
try
    children=component.getComponents;
catch
    return;
end
for k=1:numel(children)
    pane=findPane(children(k));if ~isempty(pane),return;end
end
end

function restoreCallback(tbl,callback)
if isgraphics(tbl),set(tbl,'CellSelectionCallback',callback);end
end
