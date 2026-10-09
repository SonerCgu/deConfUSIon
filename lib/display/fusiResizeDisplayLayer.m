function resized=fusiResizeDisplayLayer(layer,shape,method,bounds)
% Display layers share the same first/last pixel centers and ROI coordinates.
if nargin<3,method='linear';end
if nargin<4 || isempty(bounds),bounds=struct('xData',[1 size(layer,2)],'yData',[1 size(layer,1)]);end
native=isequal(bounds.xData,[1 size(layer,2)]) && isequal(bounds.yData,[1 size(layer,1)]);
if native && isequal(size(layer,[1 2]),shape),resized=layer;return;end
persistent grids
if isempty(grids),grids={};end
key=[shape bounds.yData bounds.xData];hit=[];
for k=1:numel(grids),if isequal(grids{k}.key,key),hit=k;break;end;end
if isempty(hit)
 [y,x]=ndgrid(linspace(bounds.yData(1),bounds.yData(2),shape(1)),linspace(bounds.xData(1),bounds.xData(2),shape(2)));
 if numel(grids)>=4,grids(1)=[];end
 grids{end+1}=struct('key',key,'x',x,'y',y);
else,x=grids{hit}.x;y=grids{hit}.y;end
resized=zeros([shape size(layer,3)],'like',single(layer));
for channel=1:size(layer,3)
 plane=single(layer(:,:,channel));
 if min(size(plane))<2,plane=repmat(plane,1+(size(plane,1)==1),1+(size(plane,2)==1));end
 resized(:,:,channel)=interp2(plane,x,y,method,0);
end
if islogical(layer),resized=resized>=.5;end
end
