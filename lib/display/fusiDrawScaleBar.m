function handles=fusiDrawScaleBar(ax,spacingUm,lengthUm,enabled)
% A single calibrated horizontal bar in the current image's pixel grid.
entry=getappdata(ax,'FUSIScaleBarState');handles=gobjects(0);
key={spacingUm,lengthUm,enabled,ax.XLim,ax.YLim,ax.YDir};
if ~isempty(entry)&&isequal(entry.key,key)&&all(isgraphics(entry.handles))
 handles=entry.handles;return;
end
if ~isempty(entry),handles=entry.handles(isgraphics(entry.handles));end
if ~enabled || numel(spacingUm)<2 || any(~isfinite(spacingUm(1:2)) | spacingUm(1:2)<=0)
 if ~isempty(handles),delete(handles);end;setappdata(ax,'FUSIScaleBarState',[]);handles=gobjects(0);return;
end
validateattributes(lengthUm,{'numeric'},{'scalar','finite','positive'});
xl=ax.XLim;yl=ax.YLim;dx=lengthUm/spacingUm(2);
if dx>.85*diff(xl)
 if ~isempty(handles),delete(handles);end;setappdata(ax,'FUSIScaleBarState',[]);handles=gobjects(0);return;
end % Never mislabel a truncated physical bar.
x=xl(2)-.06*diff(xl)-[dx 0];
if strcmp(ax.YDir,'reverse'),y=yl(2)-.09*diff(yl);ty=y-.025*diff(yl);else,y=yl(1)+.09*diff(yl);ty=y+.025*diff(yl);end
if numel(handles)~=2
 delete(handles);handles=gobjects(2,1);
 handles(1)=line(ax,x,[y y],'Color','w','LineWidth',3,'Tag','SCM_PhysicalRuler','HitTest','off','HandleVisibility','off');
 handles(2)=text(ax,mean(x),ty,sprintf('%g %cm',lengthUm,181),'Color','w','BackgroundColor','k', ...
    'FontSize',12,'HorizontalAlignment','center','VerticalAlignment','bottom','Interpreter','none', ...
    'Tag','SCM_PhysicalRuler','HitTest','off','HandleVisibility','off');
else
 set(handles(1),'XData',x,'YData',[y y]);set(handles(2),'Position',[mean(x) ty 0],'String',sprintf('%g %cm',lengthUm,181));
end
setappdata(ax,'FUSIScaleBarState',struct('key',{key},'handles',handles));
end
