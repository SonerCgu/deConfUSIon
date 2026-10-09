function fusiRegionAnnotations(ax,L,info,shown,key,xData,yData)
% Cache per-slice positions and reuse text objects during atlas browsing.
if nargin<6,xData=[1 size(L,2)];yData=[1 size(L,1)];end
previous=getappdata(ax,'FUSIRegionAnnotationKey');
if isequal(previous,{key,logical(shown)}),return;end
state=getappdata(ax,'FUSIRegionAnnotationState');
if isempty(state),state=struct('entries',{{}},'handles',gobjects(0),'info',[],'catalog',[]);end
state.handles=state.handles(isgraphics(state.handles));
if ~isempty(state.handles),set(state.handles,'Visible','off','Tag','AtlasRegionAbbreviationPool');end
setappdata(ax,'FUSIRegionAnnotationKey',{key,logical(shown)});
if shown&&~isempty(L)&&isstruct(info)&&isfield(info,'name')
 if ~isequal(state.info,info)
  [state.catalog,~]=fusiAtlasRegionCatalog(1:numel(info.name),info);
  state.info=info;state.entries={};
 end
 positions=[];cacheKey={key,xData,yData,size(L)};
 for k=1:numel(state.entries)
  if isequal(state.entries{k}.key,cacheKey),positions=state.entries{k}.positions;break;end
 end
 if isempty(positions)
  positions=labelPositions(L,state.catalog,numel(info.name),xData,yData);
  if numel(state.entries)>=12,state.entries(1)=[];end
  state.entries{end+1}=struct('key',{cacheKey},'positions',positions);
 end
 for k=1:numel(positions.x)
  if k>numel(state.handles)
   state.handles(k)=text(ax,0,0,'','Color','w','BackgroundColor','k','FontSize',10, ...
    'FontWeight','bold','HorizontalAlignment','center','Interpreter','none', ...
    'Clipping','on','HitTest','off','Margin',1);
  end
  set(state.handles(k),'Position',[positions.x(k) positions.y(k) 0], ...
   'String',positions.acronym{k},'Visible','on','Tag','AtlasRegionAbbreviation');
 end
end
setappdata(ax,'FUSIRegionAnnotationState',state);
end
function positions=labelPositions(L,catalog,n,xData,yData)
positions=struct('x',[],'y',[],'acronym',{{}});if isempty(catalog),return;end
eligible=false(n,1);eligible([catalog.id])=true;
ids=abs(double(L));valid=isfinite(ids)&ids>=1&ids<=n&ids==round(ids);
valid(valid)=eligible(ids(valid));[yy,xx]=find(valid);if isempty(xx),return;end
pixel=find(valid);group=ids(pixel)+n*(xx>floor((size(L,2)+1)/2));
counts=accumarray(group,1,[2*n 1]);
sumX=accumarray(group,double(xx),[2*n 1]);sumY=accumarray(group,double(yy),[2*n 1]);
distance=(xx-sumX(group)./counts(group)).^2+(yy-sumY(group)./counts(group)).^2;
closest=accumarray(group,distance,[2*n 1],@min,Inf);candidate=find(distance==closest(group));
chosen=accumarray(group(candidate),candidate,[2*n 1],@min,0);chosen=chosen(counts>=8&chosen>0);
nameByID=cell(n,1);nameByID([catalog.id])={catalog.acronym};
positions.x=xData(1)+(xx(chosen)-1)*diff(xData)/max(1,size(L,2)-1);
positions.y=yData(1)+(yy(chosen)-1)*diff(yData)/max(1,size(L,1)-1);
positions.acronym=nameByID(ids(pixel(chosen)));
end
