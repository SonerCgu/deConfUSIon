function bounds=fusiLightSuiteDisplayBounds(texture,geometry)
% Fit all slices once, retaining both reference tissue and the acquired field.
occupied=any(texture~=0,3);rows=find(any(occupied,2));columns=find(any(occupied,1));
bounds=[.5 geometry.nativeSize(2)+.5;.5 geometry.nativeSize(1)+.5];
if ~isempty(rows)&&~isempty(columns)
    step=[diff(geometry.xData)/max(1,size(texture,2)-1) diff(geometry.yData)/max(1,size(texture,1)-1)];
    tissue=[geometry.xData(1)+([columns(1) columns(end)]-1)*step(1); ...
        geometry.yData(1)+([rows(1) rows(end)]-1)*step(2)];
    tissue=tissue+step(:)*[-.5 .5];
    bounds(:,1)=min(bounds(:,1),tissue(:,1));bounds(:,2)=max(bounds(:,2),tissue(:,2));
end
% A small border keeps edge voxels and the recording outline fully visible.
bounds=bounds+[-2 2;-2 2];
end
