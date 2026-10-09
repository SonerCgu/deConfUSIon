function layout=fusiVolumeStackLayout(count,timeRows,tileSize,viewport,columns,automatic,gap,rise)
% Compact separated slabs. A long diagonal is split into readable strips.
width=tileSize(1);height=tileSize(2);gap=gap/100;rise=rise/100;
columns=min(count,columns);
if automatic && count>6
    candidates=1:min(10,count);scores=zeros(size(candidates));
    for j=1:numel(candidates)
        nc=candidates(j);nr=ceil(count/nc)*timeRows;
        span=[width*(1+(nc-1)*(1+gap)),height*(nr*(1.2+(nc-1)*rise)-.2)];
        scores(j)=min(viewport./span);
    end
    [~,j]=max(scores);columns=candidates(j);
end
strips=ceil(count/columns);origins=zeros(count*timeRows,2);
for ti=1:timeRows
    for k=1:count
        column=mod(k-1,columns);row=(ti-1)*strips+floor((k-1)/columns);
        origins((ti-1)*count+k,:)=[column*width*(1+gap), ...
            row*height*(1.2+(columns-1)*rise)-column*rise*height];
    end
end
layout=struct('columns',columns,'strips',strips,'origins',origins,'count',count,'timeRows',timeRows);
end
