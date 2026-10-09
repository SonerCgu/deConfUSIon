function mapping=scmRebaseROIMapping(mapping,source,target)
% Keep the atlas grid fixed while placing a different physical acquisition.
offset=fusiScanSequence('offset',target,source);
switch mapping.kind
    case '3D'
        T=mapping.transform;g=T.scanGeometry;old=g.originalSize(g.permutation);
        new=target.spatialSize(g.permutation);delta=offset(g.permutation);
        if isfield(g,'flipAxes'),for axis=g.flipAxes,delta(axis)=old(axis)-new(axis)-delta(axis);end,end
        delta=delta.*g.originalSpacingUm(g.permutation)./g.atlasVoxelSizeUm;
        shift=eye(4);shift(4,1:3)=delta([2 1 3]);T.M=shift*T.M;
        if isfield(T,'warpA'),T.warpA=T.M;end
        T.scanGeometry.originalSize=target.spatialSize;mapping.transform=T;
    case '3DDirect'
        T=mapping.transform;M=scmROI('nativeMatrix',T);shift=eye(4);shift(4,1:3)=offset([2 1 3]);
        T.M=shift*M;T.warpA=T.M;if isfield(T,'scanGeometry'),T=rmfield(T,'scanGeometry');end
        mapping.transform=T;
    case '2D'
        mapping.sourceSlices=mapping.sourceSlices-offset(3);
        for k=1:numel(mapping.matrices)
            xy=offset([2 1]);if mapping.transpose(k),xy=fliplr(xy);end
            shift=eye(3);shift(3,1:2)=xy;mapping.matrices{k}=shift*mapping.matrices{k};
        end
    otherwise,error('deConfUSIon:AtlasScanMapping','Unsupported retained atlas mapping.');
end
end
