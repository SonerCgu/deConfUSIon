function fusiRegionBoundaryOverlay(ax,L,shown,key,xData,yData)
if nargin<5,xData=[1 size(L,2)];yData=[1 size(L,1)];end
state=getappdata(ax,'FUSIRegionBoundaryState');
if isempty(state),state=struct('entries',{{}},'handle',gobjects(0),'lastKey',[]);end
cacheKey={key,xData,yData,size(L),logical(shown)};
if isequal(state.lastKey,cacheKey),return;end
if ~isempty(state.handle)&&isgraphics(state.handle),set(state.handle,'Visible','off','Tag','AtlasRegionBoundaryPool');end
if shown&&~isempty(L)
 coords=[];
 for k=1:numel(state.entries)
  if isequal(state.entries{k}.key,cacheKey),coords=state.entries{k}.coords;break;end
 end
 if isempty(coords)
  [x,y]=fusiRegionBoundarySegments(L);
  x=xData(1)+(x-1)*diff(xData)/max(1,size(L,2)-1);y=yData(1)+(y-1)*diff(yData)/max(1,size(L,1)-1);
  coords=struct('x',x,'y',y);
  if numel(state.entries)>=12,state.entries(1)=[];end
  state.entries{end+1}=struct('key',{cacheKey},'coords',coords);
 end
 if isempty(state.handle)||~isgraphics(state.handle)
  state.handle=line(ax,NaN,NaN,'Color','w','LineWidth',.65,'HitTest','off');
 end
 set(state.handle,'XData',coords.x,'YData',coords.y,'Visible','on','Tag','AtlasRegionBoundary');
end
state.lastKey=cacheKey;setappdata(ax,'FUSIRegionBoundaryState',state);
end
