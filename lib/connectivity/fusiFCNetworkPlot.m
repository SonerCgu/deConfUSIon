function [g,h]=fusiFCNetworkPlot(ax,R,names,threshold,limit,cmap,columns)
% Undirected signed region network; threshold is descriptive, not a p-value.
if nargin<7,columns={};end
rect=~isempty(columns);
if rect
 [a,b]=find(isfinite(R)&abs(R)>=threshold&abs(R)>0);values=R(sub2ind(size(R),a,b));
 b=b+size(R,1);allNames=[names(:);columns(:)];
else
 [a,b]=find(triu(isfinite(R)&abs(R)>=threshold&abs(R)>0,1));values=R(sub2ind(size(R),a,b));allNames=names(:);
end
g=graph(a,b,values,numel(allNames));cla(ax);
labels=regexprep(allNames,'\s*\[[^\]]*\]\s*$','');labels=strrep(labels,'_',' ');
h=plot(ax,g,'Layout','circle','NodeLabel',{},'NodeColor',[.22 .65 .64], ...
 'MarkerSize',7,'NodeFontSize',11,'NodeLabelColor',[.95 .95 .95]);
if ~isempty(values),h.EdgeCData=g.Edges.Weight;h.EdgeColor='flat';h.LineWidth=.6+3*abs(g.Edges.Weight);end
colormap(ax,cmap);caxis(ax,[-limit limit]);axis(ax,'off');axis(ax,'equal');
% GraphPlot rotates circle labels radially; horizontal labels are easier to
% compare and do not run into the title for region/slice names.
hold(ax,'on');
for k=1:numel(labels)
 x=h.XData(k);y=h.YData(k);alignment='center';dx=0;
 if x>.2,alignment='left';dx=.06;elseif x<-.2,alignment='right';dx=-.06;end
 dy=0;if abs(x)<=.2,dy=.10*sign(y);end
 text(ax,x+dx,y+dy,labels{k},'Color',[.95 .95 .95],'FontSize',11,'Rotation',0, ...
  'HorizontalAlignment',alignment,'Interpreter','none','Tag','FCNetworkNodeLabel');
end
hold(ax,'off');xlim(ax,[-1.65 1.65]);ylim(ax,[-1.35 1.35]);
setappdata(ax,'FUSIFCNetwork',struct('R',R,'names',{names},'columnNames',{columns},'threshold',threshold,'edgeR',values));
end
