function [mapped,details]=fusiMapBModeSlices(rgb,shape,selection)
% Extract panels and map each once onto its explicitly assigned Doppler slice.
shape=double(shape(:)');shape(end+1:3)=1;
assert(numel(shape)==3&&all(isfinite(shape)&shape>=1&shape==fix(shape)), ...
    'deConfUSIon:BModeMapping','Invalid Doppler grid.');
assert(isreal(rgb)&&size(rgb,3)==3&&ndims(rgb)<=4,'deConfUSIon:BModeMapping','Expected B-mode RGB image planes.');
boxes=[];
if strcmp(selection.kind,'montage')
    assert(size(rgb,4)==1,'deConfUSIon:BModeMapping','Select one montage image, not a volume of montages.');
    b=double(selection.bounds(:)');rows=selection.rows;cols=selection.cols;trim=selection.trim;
    assert(numel(b)==4&&all(isfinite(b)&b==fix(b))&&b(1)>=1&&b(2)>=1&& ...
        b(3)<=size(rgb,2)&&b(4)<=size(rgb,1)&&b(3)>b(1)&&b(4)>b(2), ...
        'deConfUSIon:BModeMapping','Image area must be [left top right bottom] within the snapshot.');
    assert(isscalar(rows)&&isscalar(cols)&&isscalar(trim)&&all(isfinite([rows cols trim]))&&all([rows cols trim]==fix([rows cols trim]))&& ...
        rows>=1&&cols>=1&&trim>=0&&rows*cols<=4096,'deConfUSIon:BModeMapping','Invalid montage rows, columns or border trim.');
    G=mean(rgb(b(2):b(4),b(1):b(3),:),3);
    yEdges=gridEdges(mean(G,2),rows)+b(2)-1;
    xEdges=gridEdges(mean(G,1),cols)+b(1)-1;
    boxes=zeros(rows*cols,4);k=0;
    for r=1:rows
        for c=1:cols
            k=k+1;boxes(k,:)=[xEdges(c)+1+trim yEdges(r)+1+trim xEdges(c+1)-1-trim yEdges(r+1)-1-trim];
        end
    end
    if strcmp(selection.order,'column-major')
        indices=reshape(1:rows*cols,cols,rows)';boxes=boxes(indices(:),:);
    else
        assert(strcmp(selection.order,'row-major'),'deConfUSIon:BModeMapping','Unknown panel order.');
    end
    assert(all(boxes(:,3)>=boxes(:,1)&boxes(:,4)>=boxes(:,2)), ...
        'deConfUSIon:BModeMapping','Grid cells are too small for this border trim.');
    nonblank=false(1,size(boxes,1));
    for k=1:size(boxes,1)
        p=panel(k);h=size(p,1);w=size(p,2);
        p=p(1+floor(h*.1):max(1,h-floor(h*.1)),1+floor(w*.1):max(1,w-floor(w*.1)),:);
        nonblank(k)=any(p(:)>.01);
    end
    count=selection.count;
    assert(isscalar(count)&&isfinite(count)&&count==fix(count)&&count>=1&&count<=size(boxes,1), ...
        'deConfUSIon:BModeMapping','Panel count must be between 1 and the grid capacity.');
else
    assert(strcmp(selection.kind,'planes'),'deConfUSIon:BModeMapping','Choose montage panels or individual image planes.');
    count=size(rgb,4);nonblank=true(1,count);
end
indices=selection.sliceIndices;
if isempty(indices),indices=1:min(count,shape(3));indices(end+1:count)=0;end
indices=double(indices(:)');used=indices(indices>0);
assert(numel(indices)==count&&all(isfinite(indices)&indices==fix(indices)&indices>=0&indices<=shape(3))&& ...
    numel(unique(used))==numel(used)&&~isempty(used),'deConfUSIon:BModeMapping', ...
    'Enter one Doppler slice per panel, from 1 to %d; 0 skips a panel. Do not assign a slice twice.',shape(3));
assert(prod(shape)*12<=512*1024^2,'deConfUSIon:BModeMemory','Mapped B-mode volume is too large for a display underlay.');
mapped=zeros([shape(1:2) 3 shape(3)],'single');sliceMap=zeros(1,shape(3));
for k=1:count
    z=indices(k);if z==0,continue;end
    mapped(:,:,:,z)=fusiResizeDisplayLayer(panel(k),shape(1:2),'linear');sliceMap(z)=k;
end
selection.sliceIndices=indices;
details=struct('selection',selection,'panelBoxes',boxes,'nonblankPanels',nonblank, ...
    'panelCount',count,'sliceMap',sliceMap,'validSlices',sliceMap>0);

    function p=panel(index)
        if strcmp(selection.kind,'montage')
            box=boxes(index,:);p=rgb(box(2):box(4),box(1):box(3),:);
        else
            p=rgb(:,:,:,index);
        end
    end
end

function edges=gridEdges(profile,count)
profile=double(profile(:));n=numel(profile);residual=profile-movmedian(profile,11);
threshold=max(.035,max(residual)*.22);edges=[0 zeros(1,count-1) n+1];
for k=1:count-1
    middle=round(k*n/count+.5);indices=max(2,middle-2):min(n-1,middle+2);
    assert(~isempty(indices),'deConfUSIon:BModeMapping','Too many panels for the image size.');
    [strength,best]=max(residual(indices));
    if strength>threshold,edges(k+1)=indices(best);else,edges(k+1)=middle;end
end
assert(all(diff(edges)>0),'deConfUSIon:BModeMapping','Panel separators overlap. Check the crop and grid.');
end
