function [left,right,xy]=scmSearchSideMasks(opt,shape)
% Explicit image-side partition shared by preview, ROI search and ranking.
ny=shape(1);nx=shape(2);[X,~]=meshgrid(1:nx,1:ny);
if isfield(opt,'midlineXY')&&~isempty(opt.midlineXY)
    points=double(opt.midlineXY);
    assert(isequal(size(points),[2 2])&&all(isfinite(points(:)))&&abs(diff(points(:,2)))>=.5, ...
        'deConfUSIon:SearchMidline','Draw a midline between two points with different Y positions.');
    assert(all(points(:,1)>=.5&points(:,1)<=nx+.5&points(:,2)>=.5&points(:,2)<=ny+.5), ...
        'deConfUSIon:SearchMidline','Both midline endpoints must lie inside the image.');
    points=sortrows(points,2);boundary=interp1(points(:,2),points(:,1),(1:ny)','linear','extrap');
    left=bsxfun(@le,X,boundary);
    y=[.5;ny+.5];xy=[interp1(points(:,2),points(:,1),y,'linear','extrap') y];
else
    assert(isscalar(opt.splitX)&&isfinite(opt.splitX)&&opt.splitX>=1&&opt.splitX<nx, ...
        'deConfUSIon:SearchBounds','Split X must lie between the first and last image columns.');
    left=X<=opt.splitX;xy=[opt.splitX+.5 .5;opt.splitX+.5 ny+.5];
end
right=~left;
end
