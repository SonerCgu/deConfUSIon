function Y=scmWarpMappedSeries(X,mapping,targetShape)
% Reapply the already chosen geometry without changing atlas/ROI state.
switch mapping.kind
    case '3D',Y=fusiWarpAtlasForDisplay(X,mapping.transform,true);
    case '3DDirect',Y=fusiWarpAtlasForDisplay(X,mapping.transform);
    case '2D'
        n=size(X,ndims(X));shape=[targetShape n];Y=nan(shape,'single');
        output=imref2d(targetShape(1:2));
        for z=1:numel(mapping.sourceSlices)
            depth=1;if ndims(X)==4,depth=size(X,3);end
            if mapping.sourceSlices(z)<1||mapping.sourceSlices(z)>depth,continue;end
            transform=affine2d(mapping.matrices{z});
            for t=1:n
                if ndims(X)==4,A=X(:,:,mapping.sourceSlices(z),t);else,A=X(:,:,t);end
                if mapping.transpose(z),A=A';end
                Y(:,:,z,t)=imwarp(single(A),transform,'linear','OutputView',output);
            end
        end
        if targetShape(3)==1,Y=reshape(Y,targetShape(1),targetShape(2),n);end
    otherwise,error('deConfUSIon:BaselineAtlasMapping','The active atlas mapping is unavailable. Reload the atlas transform.');
end
assert(isequal(size(Y,[1 2 3]),targetShape)||targetShape(3)==1&&ndims(Y)==3&&isequal(size(Y,[1 2]),targetShape(1:2)), ...
    'deConfUSIon:BaselineAtlasMapping','The updated PSC and atlas display grids differ.');
end
