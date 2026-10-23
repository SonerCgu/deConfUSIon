function [xy,onImage,inRecording]=fusiImagePointer(ax,fig,shape,point,ray)
% Pick the image plane, independent of image transparency and annotation hits.
% Optional figure-pixel point and axes ray allow deterministic geometry checks.
if nargin<4,point=get(fig,'CurrentPoint');end
if nargin<5,ray=get(ax,'CurrentPoint');end
xy=[NaN NaN];onImage=false;inRecording=false;
position=getpixelposition(ax,true);
if numel(point)~=2||any(~isfinite(point))|| ...
        any(point<position(1:2))||any(point>position(1:2)+position(3:4)),return;end
if ~isequal(size(ray),[2 3])||any(~isfinite(ray(:))),return;end
direction=ray(2,:)-ray(1,:);
if abs(direction(3))<eps,return;end
intersection=ray(1,:)-ray(1,3)/direction(3)*direction;
xy=intersection(1:2);
onImage=xy(1)>=ax.XLim(1)&&xy(1)<=ax.XLim(2)&&xy(2)>=ax.YLim(1)&&xy(2)<=ax.YLim(2);
% Pixel centres are integers; the outer half of an edge pixel is selectable.
inRecording=onImage&&all(xy>=[.5 .5])&&all(xy<[shape(2) shape(1)]+.5);
end
