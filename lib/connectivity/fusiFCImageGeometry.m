function fusiFCImageGeometry(ax,spacingUm,sz)
% Retain pixel coordinates for ROI selection while displaying physical aspect.
set(ax,'XLim',[.5 sz(2)+.5],'YLim',[.5 sz(1)+.5],'YDir','reverse');
if numel(spacingUm)>=2&&all(isfinite(spacingUm(1:2))&spacingUm(1:2)>0)
 set(ax,'DataAspectRatio',[1 spacingUm(2)/spacingUm(1) 1],'PlotBoxAspectRatioMode','auto');
 step=500;while step/spacingUm(2)>.5*sz(2),step=step/2;end
 fusiDrawScaleBar(ax,spacingUm,step,true);
 % Limit ruler density to about eight ticks per axis; use millimetres.
 steps=[.1 .2 .5 1 2 5 10 20];extent=max((sz([2 1])-1).*spacingUm([2 1]))/1000;
 tickStep=steps(find(steps>=extent/8,1));if isempty(tickStep),tickStep=20;end
 xt=1:1000*tickStep/spacingUm(2):sz(2);yt=1:1000*tickStep/spacingUm(1):sz(1);
 set(ax,'Visible','on','XTick',xt,'YTick',yt,'XTickLabel',compose('%g',(xt-1)*spacingUm(2)/1000), ...
  'YTickLabel',compose('%g',(yt-1)*spacingUm(1)/1000),'XColor',[.8 .8 .8],'YColor',[.8 .8 .8], ...
  'XTickLabelRotation',0,'YTickLabelRotation',0,'FontSize',11,'TickDir','out','Box','off');
 ax.XAxis.Exponent=0;ax.YAxis.Exponent=0;
 xlabel(ax,'Horizontal (mm)');ylabel(ax,'Depth (mm)');
else
 set(ax,'DataAspectRatio',[1 1 1],'Visible','on','FontSize',11);xlabel(ax,'Column (px)');ylabel(ax,'Row (px)');
end
end
