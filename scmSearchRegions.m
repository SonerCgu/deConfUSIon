function regions=scmSearchRegions(opt,z,include)
% Image coordinates: X = column, Y = row. Never infer anatomical laterality.
[ny,nx]=size(include); b=double(opt.boundsXY(:)');
assert(numel(b)==4 && all(isfinite(b)&b==round(b)) && b(1)>=1 && b(2)<=nx && b(3)>=1 && b(4)<=ny && b(1)<=b(2) && b(3)<=b(4), ...
    'deConfUSIon:SearchBounds','Bounds must be integer X start/end, Y start/end inside the image.');
[X,Y]=meshgrid(1:nx,1:ny);
base=logical(include)&X>=b(1)&X<=b(2)&Y>=b(3)&Y<=b(4);
regions=struct('name','Search','role','Search','mask',base,'polygonXY',[]);
if ~opt.bilateral, return; end
assert(isscalar(opt.splitX)&&isfinite(opt.splitX)&&opt.splitX>=1&&opt.splitX<nx, ...
    'deConfUSIon:SearchBounds','Split X must lie between the first and last image columns.');
names={'Image-left','Image-right'}; roles={'Target','Control'};
if ~opt.leftIsTarget, roles=fliplr(roles); end
for k=1:2
    p=opt.polygons{z,k};
    if isempty(p)
        if k==1, m=X<=opt.splitX; else, m=X>opt.splitX; end
    else
        assert(size(p,2)==2&&size(p,1)>=3&&all(isfinite(p(:))), ...
            'deConfUSIon:SearchBounds','A region needs at least three finite polygon vertices.');
        m=inpolygon(X,Y,p(:,1),p(:,2));
    end
    regions(k)=struct('name',names{k},'role',roles{k},'mask',base&m,'polygonXY',p);
end
assert(~any(any(regions(1).mask&regions(2).mask)), ...
    'deConfUSIon:SearchOverlap','Left/right search regions overlap. Redraw them or reset to the split.');
end
