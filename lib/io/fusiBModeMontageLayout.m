function layout=fusiBModeMontageLayout(rgb,nSlices,metadata)
% Suggest a rendered montage's image area and separators, never slice positions.
if nargin<3,metadata=struct();end
G=mean(single(rgb(:,:,:,1)),3);[ny,nx]=size(G);
border=[reshape(G(1:min(3,ny),:),[],1);reshape(G(max(1,ny-2):end,:),[],1); ...
    reshape(G(:,1:min(3,nx)),[],1);reshape(G(:,max(1,nx-2):end),[],1)];
background=median(border(isfinite(border)));
active=abs(G-background)>.12;
ys=find(mean(active,2)>.20);xs=find(mean(active,1)>.20);
if isempty(ys)||isempty(xs),bounds=[1 1 nx ny];
else,bounds=[xs(1) ys(1) xs(end) ys(end)];end
area=G(bounds(2):bounds(4),bounds(1):bounds(3));
rows=gridCount(mean(area,2));cols=gridCount(mean(area,1));
% Real layout metadata is useful; a rendered figure's 1x1 refers to the
% screenshot image object, not to its embedded anatomical panels.
if rows==1&&cols==1&&isfield(metadata,'vendor_grid_rows')&&isfield(metadata,'vendor_grid_cols')
    r=double(metadata.vendor_grid_rows);c=double(metadata.vendor_grid_cols);
    if isscalar(r)&&isscalar(c)&&all(isfinite([r c]))&&r*c>1&&r*c<=4096
        rows=max(1,round(r));cols=max(1,round(c));
    end
end
layout=struct('kind','montage','bounds',bounds,'rows',rows,'cols',cols, ...
    'trim',1,'order','row-major','count',rows*cols,'sliceIndices',[]);
% Only trailing empty padding is omitted. Internal black panels keep their
% place so that a dark anatomical slice cannot shift every following slice.
[~,details]=fusiMapBModeSlices(rgb,[1 1 max(1,rows*cols)],layout);
last=find(details.nonblankPanels,1,'last');
if ~isempty(last),layout.count=last;end
layout.sliceIndices=zeros(1,layout.count);
n=min(nSlices,layout.count);layout.sliceIndices(1:n)=1:n;
end

function count=gridCount(profile)
profile=double(profile(:));residual=profile-movmedian(profile,11);
threshold=max(.035,max(residual)*.22);count=1;best=0;
for candidate=2:min(30,floor(numel(profile)/8))
    strength=zeros(1,candidate-1);
    for k=1:candidate-1
        middle=round(k*numel(profile)/candidate+.5);
        indices=max(2,middle-2):min(numel(profile)-1,middle+2);
        strength(k)=max(residual(indices));
    end
    score=sum(strength)-threshold*.5*(candidate-1);
    if mean(strength>threshold)>=.85&&score>best,best=score;count=candidate;end
end
end
